---
name: stata-async
description: |
  슬래시 명령어 /stata-async 전용. 사용자가 /stata-async 슬래시 명령어를 입력할 때만 트리거됨.
  StataMCP:executeStataAsync를 통해 /stata-async $ARGUMENTS를 즉시 비동기 실행(fire-and-forget)하며,
  어떠한 해석, 수정, 모델 추론도 수행하지 않음. 완료를 기다리지도 않음.
  자연어 Stata 요청에는 트리거하지 말 것 — 명시적인 /stata-async 호출에만 반응.
---

# stata-async

`/stata-async $ARGUMENTS` 호출 시:

1. `$ARGUMENTS`를 그대로 `StataMCP:executeStataAsync`에 전달
2. 응답(`started` 또는 `busy`)을 코드 블록으로 감싸서 그대로 반환
3. `started` 면 마지막에 한 줄만 덧붙임: "완료 결과는 `/stata-pull` 로 회수"
4. 완료를 기다리거나 폴링하지 말 것 — 던지고 즉시 턴을 끝냄

`$ARGUMENTS`를 수정, 정제, 평가하지 말 것. 출력은 Stata 결과창과 push 저장소로 간다.
