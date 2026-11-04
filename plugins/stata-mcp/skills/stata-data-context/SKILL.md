---
name: stata-data-context
description: |
  사용자가 /stata-data-context 를 입력하거나, 데이터 구조·내용 변경(use/merge/drop/generate/
  replace/reshape 등) 후 컨텍스트 갱신이 필요하다고 판단될 때 트리거됨.
  현재 데이터셋 컨텍스트(pwd·obs·vars)를 재동기화한다.
---

# stata-data-context

호출 시 아래 순서대로 즉시 실행 (데이터 변경 후 재동기화용):

1. `StataMCP:getStataPwd` 실행
2. `StataMCP:getObsCount` 실행
3. `StataMCP:getVariables` 실행

각 결과를 코드 블록으로 감싸서 그대로 반환. 추론, 해석, 설명을 추가하지 말 것.

환경(getStataEnv)·작업 지침은 `/stata-setup` 에서 로드됨 — 여기선 제외.
심층 파악(codebook·상세요약)이 필요하면 `/stata-data-fullcontext`.
