---
name: stata-exec
description: |
  슬래시 명령어 /stata-exec 전용. 사용자가 /stata-exec 슬래시 명령어를 입력할 때만 트리거됨.
  StataMCP:executeStata를 통해 /stata-exec $ARGUMENTS를 즉시 직접 실행하며,
  어떠한 해석, 수정, 모델 추론도 수행하지 않음.
  자연어 Stata 요청에는 트리거하지 말 것 — 명시적인 /stata-exec 호출에만 반응.
---

# stata-exec

`/stata-exec $ARGUMENTS` 호출 시:

1. `$ARGUMENTS`를 그대로 `StataMCP:executeStata`에 전달
2. 출력 결과를 코드 블록으로 감싸서 그대로 반환
3. 에러 발생 시 에러 메시지를 코드 블록으로 감싸서 그대로 반환

`$ARGUMENTS`를 수정, 정제, 평가하지 말 것. 코드 블록 앞뒤에 어떠한 설명도 추가하지 말 것.
응답의 `rc` 는 0=성공, 그 외 = Stata 에러 코드. 오래 걸릴 명령(~30초+)은 `/stata-async` 사용.
