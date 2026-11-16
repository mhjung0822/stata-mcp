---
name: stata-data-context
description: "/stata-data-context 를 입력했거나 데이터 구조·내용이 바뀐 뒤(use·merge·drop·generate·replace·reshape 등) — 데이터셋 컨텍스트(pwd·obs·vars)를 다시 맞춘다."
---

# stata-data-context

호출 시 아래 순서대로 즉시 실행 (데이터 변경 후 재동기화용):

1. `StataMCP:getStataInfo` 실행 — `what=["pwd","obs"]`
2. `StataMCP:getVariables` 실행

각 결과를 코드 블록으로 감싸서 그대로 반환. 추론, 해석, 설명을 추가하지 말 것.

환경(`getStataInfo` 의 env)·작업 지침은 `/stata-setup` 에서 로드됨 — 여기선 제외.
심층 파악(codebook·상세요약)이 필요하면 `/stata-data-fullcontext`.
