---
name: stata-exec
description: "/stata-exec 전용 — 받은 명령을 executeStata 로 그대로 실행 (해석·수정 없음). 자연어 요청에는 쓰지 않음."
---

# stata-exec

`/stata-exec $ARGUMENTS` 호출 시:

1. `$ARGUMENTS`를 그대로 `StataMCP:executeStata`에 전달
2. 출력 결과를 코드 블록으로 감싸서 그대로 반환
3. 에러 발생 시 에러 메시지를 코드 블록으로 감싸서 그대로 반환

`$ARGUMENTS`를 수정, 정제, 평가하지 말 것. 코드 블록 앞뒤에 어떠한 설명도 추가하지 말 것.
응답의 `rc` 는 0=성공, 그 외 = Stata 에러 코드. 오래 걸릴 명령(~30초+)은 `/stata-async` 사용.
