---
name: stata-instruction
description: |
  사용자가 /stata-instruction 을 입력하거나, /stata-setup 이 지침 로드를 위해 호출할 때 트리거됨.
  이 세션의 Stata 작업 지침(출력형식·분석 규칙·선호 등)을 로드한다.
  자연어 Stata 요청에는 트리거하지 말 것 — 위 두 경우에만 반응.
---

# stata-instruction — Stata MCP 작업 지침

이 스킬이 로드되면 아래를 이 세션의 **작업 지침**으로 간주해 이후 모든 Stata 작업·결과 제시에 따른다.

> **이 스킬은 사용자가 편집해서 쓰는 지침**입니다. stata-mcp 플러그인과 **별도로 설치**하므로 플러그인을 업데이트해도 편집분이 덮이지 않습니다. 아래는 **기본 예시** — 출력형식뿐 아니라 분석 규칙·자주 쓰는 옵션·해석 깊이·언어 등 세션 작업 선호를 자유롭게 추가/수정하세요 (옵션에서 직접 편집하거나 Claude 에게 수정 요청).

## 실행 형식
- Stata 명령 실행 전, 실행할 명령을 stata 코드블록으로 먼저 표시. 예:

  ```stata
  summarize price
  ```

- 실행 결과도 코드블록으로 전체 출력 (임의 생략 금지)
- 예외: list/browse 같은 데이터 행 출력은 Stata GUI 에서 확인 (응답에 포함 금지)

## 결과 해석
- raw output 은 전체 노출하되, **추가로** 해석·요약을 덧붙여 설명
  (통계 초중급 수준: 전문 용어 풀이, 유의성·효과 크기·해석 주의점 맥락 제공)

## 그래프 출력
- executeStata 응답에 `graphDrawn: true` 면 그래프를 그린 것 (PNG 자동 생성 없음)
- 이미지가 필요하면 `exportGraph(name)` (빈 name = 현재 그래프) → `graphPath` 를
  `[<graphFilename>](computer://<graphPath>)` 로 표시. 인라인 이미지는 안 띄움
- 그래프 분석 필요 시 AskUserQuestion("vision 토큰 사용") → "네" 면 `getGraphImage(path, maxDim:800)`.
  `getGraphImage` 비활성이면 알리고 보류

## 추정 결과 표기
- 모형이 여러 개면 각 모형을 별도 테이블로 (하나에 여러 종속변수 혼합 금지)
- 계수 + 표준오차 + 유의수준(*, **, ***) 형태로 표기

## 범주형 변수
- 추정 명령(reg, xtreg, logit 등)의 범주형 설명변수에는 `i.` prefix
  (value label 있거나 사용자가 범주형으로 정의한 경우). 연속형에 잘못 붙이지 않도록 주의
