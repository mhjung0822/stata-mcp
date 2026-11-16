---
name: stata-vars
description: "/stata-vars 전용 — openVarsPage 로 Stata MCP 변수 창을 연다 (해석 없음). 자연어 요청에는 쓰지 않음."
---

# stata-vars

`/stata-vars` 호출 시 아래 순서대로 즉시 실행:

1. 내장 브라우저 패널이 있는 환경(Claude Code 브라우저 패널·코워크 브라우저 패널)이면 `StataMCP:openVarsPage(launch=false)` → 반환된 `url` 을 **그 패널에 직접 연다**
2. 패널이 없는 환경(일반 채팅)이면 `StataMCP:openVarsPage(launch=true)` → `status` 가 `url_only` 면 `url` 을 한 줄로 안내
3. Stata 자체 Variables 창을 띄우는 `window manage forward variables` 는 쓰지 않는다 (다른 창 — 선택·태그 기능 없음)

변수 창에서 고른 변수를 분석에 쓸 때는 `getSelectedVariables` 를 호출한다 (규칙은 그 툴 설명과 `/stata-setup` 요약 참조).
