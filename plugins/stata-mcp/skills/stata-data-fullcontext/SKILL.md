---
name: stata-data-fullcontext
description: |
  슬래시 명령어 /stata-data-fullcontext 전용. 사용자가 /stata-data-fullcontext 슬래시 명령어를 입력할 때만 트리거됨.
  현재 Stata 데이터셋의 전체 컨텍스트를 파악하기 위해 정해진 순서대로 즉시 실행하며,
  실행 후 데이터셋 전체를 상세 요약하여 반환.
  자연어 Stata 데이터 요청에는 트리거하지 말 것 — 명시적인 /stata-data-fullcontext 호출에만 반응.
---

# stata-data-fullcontext

`/stata-data-fullcontext` 호출 시 아래 순서대로 즉시 실행:

1. `StataMCP:getObsCount` 실행
2. `StataMCP:getVariables` 실행
3. `StataMCP:executeStata` — cmd: `codebook` 실행

## 실행 후 상세 요약 출력

위 3개 결과를 바탕으로 아래 항목을 포함한 전체 요약을 출력:

- **데이터셋 개요**: 관측값 수, 변수 수
- **변수 목록**: 마크다운 테이블로 출력 (변수명, 타입, 변수 라벨, 척도, 값 라벨). 척도는 값 라벨 존재 여부·고유값 수·타입을 종합해 범주형/연속형/문자형으로 판단. 범주형 변수의 값 라벨이 한 줄을 초과하면 다음 행 값 라벨 열에만 이어서 표시하고 나머지 셀은 빈칸으로 둘 것. 값 라벨 5개 초과 시 `... 외 N개`로 표시. 값 라벨 열에는 값=라벨 매핑만 표시하고 라벨명(예: foreign, yesno 등)은 표시하지 말 것.
- **특이사항**: 결측값 비율이 높은 변수, 상수 변수 등 분석 시 주의할 점. 툴 결과에 없는 정보를 추론한 경우 해당 항목에 `[추론]` 태그를 붙일 것.
