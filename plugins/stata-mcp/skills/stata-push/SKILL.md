---
name: stata-push
description: "/stata-push 전용 — 인자 없음 = push 앱을 지금 상태 그대로 연다, on = 열고 자동 받기를 켠다, off = 자동 받기를 끈다. 자연어 요청에는 쓰지 않음."
---

# stata-push

인자에 따라 아래 셋 중 하나를 즉시 실행한다.

## `/stata-push` (인자 없음) · `/stata-push on` — push 앱 열기

1. 인자 없음 = `StataMCP:openPushPage()` (지금 상태 그대로 연다) · `on` (또는 `켜기`) = `StataMCP:openPushPage(listen=true)` (「자동 받기」를 켠다)
2. 반환된 `pageUrl` 을 **내장 브라우저 패널에 연다** (Claude Code 브라우저 패널 · 코워크 브라우저 패널).
   패널이 없는 곳에서만 `openPushPage(launch=true)` 로 새 탭에 연다
2-1. 결과의 `autoReceive` 가 false 면 (`waitUrl` 없음) 대기를 걸지 않고 한 줄만:
   "push 앱을 열었습니다 — 결과는 목록에 모입니다. 'push 결과 가져와' 하시면 정리합니다 (자동으로 받으려면 /stata-push on)"
3. 자동 받기가 켜져 있고 셸이 이 PC 의 `127.0.0.1` 에 닿으면 (Claude Code) 반환된 `waitUrl` 로 **백그라운드** 명령을 건다: `curl -s --max-time 1900 "<waitUrl>"`
   - 사용자에게는 한 줄만: "push 앱을 열었습니다 — 보내기를 누르거나 새 push 가 오면 이 대화로 들어옵니다" 하고 턴을 끝낸다 (기다리며 폴링하지 않는다)
   - 대기 명령이 끝나면 (출력 = `{events:[{event, ids, request?}]}`): `ids` 마다 `StataMCP:getPushResults("<id>")` 로 전문을
     가져와 정리한다 (`send` = 사용자가 골라 보낸 것 — 여러 개면 함께 읽고 한 번에 / `new` = 새 push·async 완료 — 짧게 /
     `request` 가 있으면 그 요청대로). 끝나면 같은 대기 명령을 다시 백그라운드로 건다
   - `{timeout: true}` 이면 아무 말 없이 다시 건다 · `{stopped: true}` 이면 (사용자가 「자동 받기」를 끔) 다시 걸지 않고 한 줄로 알린다
   - 연결 오류로 끝나면 (서버 꺼짐) 다시 걸지 말고 한 줄: "Stata MCP 서버 연결이 끊겼습니다 — Stata 에서 mcp_connect 후 /stata-push"
4. 자동 받기가 켜져 있고 셸이 클라우드라 닿지 않고 (코워크·채팅) 결과에 `relayWaitUrl` 이 있으면, 백그라운드로 중계 대기 루프를 건다:
   `while :; do r=$(curl -s --max-time 60 "<relayWaitUrl>"); case "$r" in *push*) echo "$r"; break;; esac; done`
   - 사용자에게는 위와 같은 한 줄만 알리고 턴을 끝낸다
   - 루프가 끝나면 `StataMCP:getPushResults("events")` 로 쌓인 이벤트를 받아 3번과 같이 정리하고, 같은 루프를 다시 건다
   - 대화가 몇 분 쉬면 셸과 함께 루프가 사라진다 — 사용자가 다시 말을 걸면 먼저 `getPushResults("events")` 로 확인하고 루프를 다시 건다
     (Stata 도구 응답에 `push` 필드가 있어도 같은 뜻)

「[push] #3 #4 …」 메시지를 받으면: 그 id 들을 `getPushResults("<id>")` 로 가져와 정리한다 (`— <요청>` 이 붙어 있으면 그 요청대로).
출력은 `/stata-pull` 과 같은 형식: 첫 줄 `#id · rc · note`, 이어서 output 요약 (외부 지식·추론 추가 금지, 해석은 사용자가 원할 때).

## `/stata-push off` (또는 `끄기` · `stop`) — 듣기 끄기

- `StataMCP:getPushResults("off")` 로 「자동 받기」를 끄고, 백그라운드 대기 명령(curl 대기 · 중계 루프)을 멈춘다 — 이후 결과는 목록에만 쌓인다
- 한 줄: "push 듣기를 껐습니다"
