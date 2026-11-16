---
name: stata-async
description: "/stata-async 전용 — 받은 명령을 executeStataAsync 로 비동기 실행하고 기다리지 않음 (해석·수정 없음). 자연어 요청에는 쓰지 않음."
---

# stata-async

`/stata-async $ARGUMENTS` 호출 시:

1. `$ARGUMENTS`를 그대로 `StataMCP:executeStataAsync`에 전달
2. 응답(`started` 또는 `busy`)을 코드 블록으로 감싸서 그대로 반환
3. `started` 면 마지막에 한 줄만 덧붙임: "완료되면 push 듣기가 켜져 있을 때는 저절로 들어오고, 아니면 `/stata-pull` 로 회수"
4. 완료를 기다리거나 폴링하지 말 것 — 던지고 즉시 턴을 끝냄

`$ARGUMENTS`를 수정, 정제, 평가하지 말 것. 출력은 Stata 결과창과 push 저장소로 간다.
