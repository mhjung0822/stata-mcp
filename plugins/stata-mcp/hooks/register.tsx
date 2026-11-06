import { atom, read, update } from 'claude-code'
import type { Engine, Register, Timer } from 'claude-code'

import type { Listen } from '../types'

/**
 * Stata push 듣기 (Stata MCP 플러그인에 동봉, 2026-11-06).
 *
 * 평소엔 잠들어 있다 — 타이머·서버 호출·네트워크 0. Claude 가 openPushPage(「푸쉬앱 열어 줘」)를 부르면 그 세션에서
 * 듣기 시작: 서버 대기열을 긴 대기로 받아(이벤트가 오면 즉시, 없으면 20초 뒤 빈 결과 → 곧바로 다시) prompt.submit 으로
 * Claude 에게 넘긴다. 폴링 없음. 「푸쉬앱 꺼 줘」·/stata-push off (둘 다 push_listen on=false) · 띠 [끄기] 로 끔.
 * /stata-push 는 플러그인 스킬 하나 — mod 는 명령을 따로 등록하지 않음 (이름이 겹쳤음, 11-06).
 * 받는 대화 — 켤 때 이 대화의 표지(lid)를 서버에 claim. push 앱의 「여러 대화에서 받기」가 꺼져 있으면 마지막에 켠 대화만
 * 받고, 앞서 켠 대화는 서버가 handedOff 로 깨워 멈춘다 → 띠·토스트, 그리고 그 대화의 다음 말에 Claude 맥락으로 한 번 알림
 * (메시지를 넣으면 Claude 턴이 새로 열려 토큰을 쓰므로 넣지 않음).
 *
 * 받는 길 — ① http: 이 Mac 의 /api/push/wait (Code 탭. 자동 모드에선 mod 의 MCP 호출이 막혀 이 길만 됨)
 *           ② MCP: getPushResults("wait 50") — http 가 안 닿는 곳(코워크는 클라우드라 127.0.0.1 이 Mac 이 아님)
 * MCP 서버 이름은 이 플러그인의 것을 connect 로 받고, 안 되면 설치 방식별 후보를 차례로.
 */
const BASE = "http://127.0.0.1:8080"
// 20초 — 앱의 $.http.fetch 는 30초에 끊는다(실측 11-06). 서버가 그보다 먼저 답해야 서버에 끊긴 대기(유령)가 안 남음
const WAIT_SEC = 20
const CANDIDATES: [string, string][] = [
  ['StataMCP', 'getPushResults'],
  ['plugin:stata-mcp:StataMCP', 'getPushResults'],
  ['remote-devices', 'plugin_stata-mcp_StataMCP__getPushResults'],
]

const listen = atom({ plugin: 'stata-mcp', key: 'listen' } as const,
  { on: false, via: '', got: 0, error: '', lid: '', handedOff: false, told: false } as Listen, { shape: 'listen-2' })

let gen = 0                                       // 끄거나 다시 불러오면 이전 고리는 멈춤
let running = false
let lastTick = 0                                  // tick 이 마지막으로 돈 시각 — 타이머가 사라졌는지 판단용 (rearm)
let ownTool = ''                                  // 이 mod 가 등록한 push_listen 의 전체 이름
// 받았다는 확인 — 서버는 넘긴 묶음(seq)을 이 대화가 다음 대기에 ack 로 가져올 때까지 붙잡아 두고, 안 오면 다시 준다
let lastAck: number | null = null
let lastTarget: Target | null = null
let awaitingPrompt = false                        // prompt.submit 이 대화가 한가해지길 기다리는 중 — 고리는 살아 있음 (rearm 금지)
const delivered = new Map<number, number>()      // 최근 넘긴 push id → 시각: 서버의 재전달(ack 늦음·90초 만료)로 같은 묶음이 또 와도 메시지는 한 번만 (10분)

type Target = { kind: 'http' } | { kind: 'mcp', server: string, tool: string }
const textOf = (res: any) => String(res?.content?.find((b: any) => b.type === 'text')?.text ?? '')

async function find($: Engine): Promise<Target | null> {
  try {
    const r = await $.http.fetch(`${BASE}/api/push/list`)
    if (r.ok) return { kind: 'http' }
  } catch {}
  const tries: [string, string][] = []
  try {
    const own = await $.mcp.connect('StataMCP')
    if (own.isConnected) tries.push([own.server, 'getPushResults'])
  } catch {}
  for (const [server, tool] of [...tries, ...CANDIDATES]) {
    try {
      const res = await $.mcp.call(server, tool, { mode: 'history' })
      if (!res.isError && textOf(res).trim().startsWith('{')) return { kind: 'mcp', server, tool }
    } catch {}
  }
  return null
}

/** 이벤트 묶음 → Claude 에게 보낼 글 (서버 지침의 "[push] #3 #4 — <요청>" 형식) */
function phrase(events: any[]): string {
  return events.map(e => {
    const ids = [...new Set<number>(e.ids ?? [])].map(i => '#' + i).join(' ')
    const head = e.event === 'new' ? `[push] 새 결과 ${ids}` : `[push] ${ids}`
    return e.request ? `${head} — ${e.request}` : `${head} 정리해 줘`
  }).join('\n')
}

async function claim($: Engine, t: Target, lid: string) {
  if (t.kind === 'http') await $.http.fetch(`${BASE}/api/push/claim`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ lid }) })
  else await $.mcp.call(t.server, t.tool, { mode: `claim ${lid}` })
}

/** 끌 때 — 마지막 확인을 넘기고, 확인 못 한 묶음은 서버가 「안 보냄」으로 되돌림 */
async function release($: Engine, t: Target, lid: string, ack: number | null) {
  if (t.kind === 'http') await $.http.fetch(`${BASE}/api/push/release`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ lid, ack }) })
  else await $.mcp.call(t.server, t.tool, { mode: `release ${lid}${ack != null ? ' ' + ack : ''}` })
}

let timer: Timer | null = null                   // 다음 tick — 훅 dispatch 와 무관하게 사는 타이머 (mod API: 오래 사는 일은 clock.after 로)
let target: Target | null = null
let claimed = false

function schedule($: Engine, my: number, ms: number) {
  if (my !== gen) return
  timer = $.clock.after(ms, () => { void tick($, my) })
}

/** 대기 한 번 = dispatch 하나, 끝에 다음 tick 을 건다. 훅 안에서 띄운 떠 있는 루프(while)는 그 훅의 dispatch 가 정리될 때
 *  같이 끊겼다(코워크 2~4분, 11-06 세 번 실측 — mod API 문서: dispatch 를 넘어 살 일은 clock.after/every 로). */
async function tick($: Engine, my: number) {
  if (my !== gen) return
  running = true
  lastTick = Date.now()
  const lid = (await read($, listen)).lid
  if (!target) {
    target = await find($)
    if (my !== gen) return
    if (!target) {
      await update($, listen, v => ({ ...v, via: '', error: 'Stata MCP 서버를 찾지 못함 — 30초 뒤 다시' }))
      return schedule($, my, 30_000)
    }
    const via = target.kind === 'http' ? 'http' : target.server
    await update($, listen, v => ({ ...v, via, error: '' }))
    lastTarget = target
    if (!claimed) { await claim($, target, lid); claimed = true }   // 켤 때 한 번 — 이 대화가 받는 곳
  }
  try {
    let raw: string
    if (target.kind === 'http') {
      const r = await $.http.fetch(`${BASE}/api/push/wait?timeout=${WAIT_SEC}&lid=${encodeURIComponent(lid)}`
        + (lastAck != null ? `&ack=${lastAck}` : ''))
      if (!r.ok) throw new Error(`http ${r.status}`)
      raw = r.text
    } else {
      raw = textOf(await $.mcp.call(target.server, target.tool,
        { mode: `wait ${WAIT_SEC} ${lid}${lastAck != null ? ' ' + lastAck : ''}` }))
    }
    if (my !== gen) return
    const body = JSON.parse(raw || '{}')
    if (body.handedOff) {                        // 다른 대화가 push 앱을 켬 — 여기는 멈춤
      gen++
      running = false
      timer = null
      await update($, listen, v => ({ ...v, on: false, via: '', error: '', handedOff: true, told: false }))
      await remember($, false, '')
      $.ui.toast('push 받기가 다른 대화로 넘어갔습니다 — 여기서 다시 받으려면 /stata-push')
      return
    }
    const events: any[] = body.events ?? []
    const now = Date.now()
    for (const [id, t] of delivered) if (now - t > 600_000) delivered.delete(id)
    const fresh = events.map(e => ({ ...e, ids: [...new Set<number>(e.ids ?? [])].filter(i => !delivered.has(i)) }))
                        .filter(e => e.ids.length > 0)
    if (fresh.length > 0) {
      await update($, listen, v => ({ ...v, got: v.got + fresh.length, error: '' }))
      // 대화 대기열에 들어가면 끝남 (Claude 가 답하는 중이면 그 뒤 차례) → 그때 확인
      awaitingPrompt = true
      let r: any
      try { r = await $.prompt.submit({ text: phrase(fresh) }) } finally { awaitingPrompt = false }
      if (r?.drop) await update($, listen, v => ({ ...v, error: `대화에 못 넣음: ${String(r.drop).slice(0, 80)}` }))
      else for (const e of fresh) for (const i of e.ids) delivered.set(i, Date.now())
    }
    if (typeof body.seq === 'number') lastAck = body.seq    // 다음 대기에 실어 「보냄」 확정
    schedule($, my, 0)
  } catch (err) {
    const msg = String(err)
    if (/aborted|no complete answer/i.test(msg)) return schedule($, my, 0)   // 통로가 끊음 — 바로 다시 (받은 것은 서버가 다시 줌)
    target = null                              // 서버가 다시 켜졌거나 끊김 — 다시 찾기
    await update($, listen, v => ({ ...v, error: msg.slice(0, 120) }))
    schedule($, my, 5_000)
  }
}

/** 새 고리 — 이전 타이머는 버리고 처음(find·claim)부터 */
function loop($: Engine, my: number) {
  timer?.cancel(); timer = null
  target = null; claimed = false
  running = true; lastTick = Date.now()
  schedule($, my, 0)
}

/** 보험 — 켜져 있는데 tick 이 60초 넘게 안 돌았으면(타이머가 사라짐: 모듈 교체 등) 새 고리.
 *  prompt.submit·tool.call·ui.render 훅에서 부른다. 정상이면 tick 이 20초마다 lastTick 을 갱신해 아무 일도 안 함 */
async function rearm($: Engine) {
  if (!(await restore($))) return
  const v = await read($, listen)
  if (v.handedOff) return
  if (awaitingPrompt) return                       // 넘길 차례를 기다리는 중 — 죽은 게 아님
  if (running && Date.now() - lastTick < 60_000) return
  loop($, ++gen)
}

/** 켜짐·lid 를 $.store 에도 — 코워크는 대화가 몇 분 쉬면 hooks worker 를 버리고 다음 말에 새로 띄우며 그때 $.state 가 빈다(11-06 실측: 3분 뒤
 *  "꺼짐"). $.store 는 세션·리로드를 넘어 보존되므로 새 worker 의 session.start·rearm 이 여기서 되살린다. 키는 세션별 */
async function remember($: Engine, on: boolean, lid: string) {
  try {
    const k = `listen:${await $.session.id()}`
    if (on) await $.store.set(k, { on: true, lid, at: Date.now() }); else await $.store.delete(k)
  } catch {}
}
/** state 가 꺼져 있는데 store 에 켜짐이 남아 있으면 state 로 되돌린다. 켜져 있으면 true */
async function restore($: Engine): Promise<boolean> {
  const v = await read($, listen)
  if (v.on) return true
  let m: any = null
  try { m = await $.store.get(`listen:${await $.session.id()}`) } catch {}
  if (!m?.on) return false
  await update($, listen, x => ({ ...x, on: true, lid: m.lid || x.lid, handedOff: false, told: false, error: '' }))
  return true
}

async function start($: Engine) {
  await update($, listen, v => ({ ...v, on: true, error: '', handedOff: false, told: false,
    lid: v.lid || `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}` }))
  await remember($, true, (await read($, listen)).lid)
  if (running && timer) return                     // 이미 듣는 중 — 고리 하나만
  loop($, ++gen)
}

async function stop($: Engine) {
  gen++
  running = false
  timer?.cancel(); timer = null
  const t = lastTarget, ack = lastAck, lid = (await read($, listen)).lid
  lastAck = null
  if (t && lid) { try { await release($, t, lid, ack) } catch {} }
  await update($, listen, v => ({ ...v, on: false, via: '', error: '' }))
  await remember($, false, '')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    try {
      ownTool = (await $.tool.register({
        name: 'push_listen',
        description: 'Stata push listening of this conversation. Opening the push app (openPushPage) turns it on by itself. '
          + 'on=false when the user asks to close/stop the push app ("푸쉬앱 꺼 줘", "push 앱 꺼 줘", /stata-push off). '
          + 'Without on, it only reports whether this conversation is receiving pushes — use it when the user asks '
          + '("push 켜져 있어?", "push 받는 중이야?") and relay the answer in one line.',
        inputSchema: { type: 'object', properties: { on: { type: 'boolean' } } },
      })).tool
    } catch {}
    if (await restore($)) void start($)            // 다시 불러온 세션·교체된 worker(코워크) — 켜져 있던 듣기를 이어감
    return next(e)
  })

  // 넘어간 대화 — 사용자가 다음 말을 걸 때 Claude 가 한 줄 알리게 (한 번만, 추가 턴 없음)
  on('prompt.submit', async ($, e, next) => {
    await rearm($)
    const v = await read($, listen)
    if (!v.handedOff || v.told) return next(e)
    await update($, listen, x => ({ ...x, told: true }))
    return next({ ...e, text: `${e.text}\n\n(Stata push mod: 이 대화의 push 받기는 다른 대화에서 push 앱을 켜서 넘어갔습니다. `
      + '답할 때 사용자에게 한 줄로 알리고, 여기서 다시 받으려면 /stata-push 라고 안내할 것.)' })
  }).catch(($, e, next) => next(e))

  // 잠든 동안 하는 일은 이것뿐 — 도구 이름을 한 번 비교하고 넘김
  on('tool.call', async ($, e, next) => {
    await rearm($)
    if (ownTool && e.tool === ownTool) {
      const arg = (e as any).on
      if (typeof arg !== 'boolean') {                // 상태만 — 켜고 끄지 않음
        const v = await read($, listen)
        const text = v.on
          ? `이 대화는 Stata push 를 받는 중입니다${v.via ? ` (${v.via})` : ''}${v.got ? ` — 지금까지 ${v.got}건` : ''}${v.error ? ` · 오류: ${v.error}` : ''}. 끄려면 /stata-push off`
          : v.handedOff
            ? '이 대화는 push 를 받지 않습니다 — 다른 대화에서 push 앱을 켜서 넘어갔습니다. 여기서 받으려면 /stata-push'
            : '이 대화는 push 를 받지 않습니다 (꺼짐). 받으려면 /stata-push'
        return { result: text } as any
      }
      const want = arg
      if (want) await start($); else await stop($)
      return { result: want ? 'Stata push 듣기를 켰습니다.' : 'Stata push 듣기를 껐습니다.' } as any
    }
    if (!e.tool.endsWith('openPushPage')) return next(e)
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError) return ran
    await start($)
    return { ...ran, context: [...(ran.context ?? []),
      'The Stata push mod is now listening in this session: it delivers push-app sends and new pushes to you as "[push] …" '
      + 'messages. Still open pageUrl in your in-app browser panel as usual (a new tab only where there is no panel); just do not '
      + 'start the background curl wait. To stop, call push_listen with on=false.'] }
  }).catch(($, e, next) => next(e))               // 이 훅이 실패해도 Claude 의 도구 호출은 막지 않음

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    await rearm($)
    const v = await read($, listen)
    if (!v.on) return next(e)                      // 꺼져 있으면 그리지 않음
    const { Box, Text, Button } = $.ui.resolve(e)
    return (
      <Box>
        <Text>Stata push </Text>
        <Text color={v.error ? 'red' : 'green'}>{v.error ? `● ${v.error}` : `● 받는 중${v.via ? ` (${v.via})` : ''}`}</Text>
        {v.got > 0 && <Text dimColor> · 넘긴 {v.got}건</Text>}
        <Text> </Text>
        <Button key="stop" label="끄기" onPress={() => void stop($)} />
      </Box>
    )
  })
}
