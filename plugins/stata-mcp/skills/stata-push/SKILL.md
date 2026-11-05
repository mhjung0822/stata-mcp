---
name: stata-push
description: |
  슬래시 명령어 /stata-push 전용. 사용자가 /stata-push 슬래시 명령어를 입력할 때만 트리거됨.
  인자 없음 = StataMCP:openPushPage 로 push 앱을 브라우저 패널에 열고 듣기를 켠다 (사용자가 앱에서 보낸 결과·새 push 를
  받아 정리). off (끄기·stop) = 듣기를 끈다. 자연어 Stata 요청에는 트리거하지 말 것 — 명시적인 /stata-push 호출에만 반응.
---

# stata-push

인자에 따라 아래 둘 중 하나를 즉시 실행한다.

## `/stata-push` (인자 없음) — push 앱 열기 + 듣기

1. `StataMCP:openPushPage()` 를 부른다
2. 반환된 `pageUrl` 을 **내장 브라우저 패널에 연다** (Claude Code 브라우저 패널 · 코워크 브라우저 패널).
   패널이 없는 곳에서만 `openPushPage(launch=true)` 로 새 탭에 연다
3. 결과에 "The Stata push mod is now listening" 안내가 붙어 있으면 여기서 끝 — Stata push mod 가 듣다가 보내기·새 push 를
   「[push] …」 메시지로 이 대화에 넣어 준다. 사용자에게는 한 줄만:
   "push 앱을 열었습니다 — 보내기를 누르거나 새 push 가 오면 이 대화로 들어옵니다"
4. 그 안내가 없으면 (mod 가 없는 설치) 반환된 `waitUrl` 로 **백그라운드** 명령을 건다: `curl -s --max-time 1900 "<waitUrl>"`
   - 사용자에게는 같은 한 줄만 알리고 턴을 끝낸다 (기다리며 폴링하지 않는다)
   - 대기 명령이 끝나면 (출력 = `{events:[{event, ids, request?}]}`): `ids` 마다 `StataMCP:getPushResults("<id>")` 로 전문을
     가져와 정리한다 (`send` = 사용자가 골라 보낸 것 — 여러 개면 함께 읽고 한 번에 / `new` = 새 push·async 완료 — 짧게 /
     `request` 가 있으면 그 요청대로). 끝나면 같은 대기 명령을 다시 백그라운드로 건다
   - `{timeout: true}` 이면 아무 말 없이 다시 건다
   - 연결 오류로 끝나면 (서버 꺼짐) 다시 걸지 말고 한 줄: "Stata MCP 서버 연결이 끊겼습니다 — Stata 에서 mcp_connect 후 /stata-push"
5. 백그라운드 명령을 걸 수 없는 곳(채팅)에서는 대기 대신 `StataMCP:pushListen` 을 불러 push 인앱 카드를 띄운다 — 카드가 받은 push 를
   알려 주고, 사용자가 카드의 [채팅에 붙이기] 를 누르면 「[push] …」 메시지가 온다

「[push] #3 #4 …」 메시지를 받으면: 그 id 들을 `getPushResults("<id>")` 로 가져와 정리한다 (`— <요청>` 이 붙어 있으면 그 요청대로).
출력은 `/stata-pull` 과 같은 형식: 첫 줄 `#id · rc · note`, 이어서 output 요약 (외부 지식·추론 추가 금지, 해석은 사용자가 원할 때).

## `/stata-push off` (또는 `끄기` · `stop`) — 듣기 끄기

- `push_listen` 도구가 있으면 `push_listen(on=false)` 를 부른다. 없으면 백그라운드 대기 명령을 멈춘다
- 한 줄: "push 듣기를 껐습니다"
