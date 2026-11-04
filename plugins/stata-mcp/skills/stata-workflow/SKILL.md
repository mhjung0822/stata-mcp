---
name: stata-workflow
description: |
  슬래시 명령어 /stata-workflow 전용. 사용자가 /stata-workflow 슬래시 명령어를 입력할 때만 트리거됨.
  StataMCP:workflow 로 등록 절차(패널 분석 · 패널 데이터 생성)의 첫 화면을 즉시 띄우며, 어떠한 해석·수정·모델 추론도 수행하지 않음.
  자연어 분석 요청에는 트리거하지 말 것 — 명시적인 /stata-workflow 호출에만 반응.
---

# stata-workflow

`/stata-workflow [절차 또는 말한 값]` 호출 시 아래 순서대로 즉시 실행:

1. 인자가 등록 절차 이름(`panel_linear` · `panel_build`)이나 그 뜻("패널 분석", "패널 데이터 생성")이면 `procedure` 로 넘긴다. 그 밖의 인자는 사용자가 **그대로 말한 값**(종속변수 · 설명변수 · id · time)만 넘기고, 말하지 않은 것은 비워 둔다 — 절대 짐작하지 않는다. 인자가 없으면 `procedure` 없이 부른다 → 서버가 첫 질문 "어떤 작업을 할까요?"(패널 › 분석 / 데이터 생성)를 낸다.
2. 내장 브라우저 패널이 있는 환경(Claude Code 브라우저 패널·코워크 브라우저 패널)이면 `StataMCP:workflow(page=true, …)` → 반환된 `pageUrl` 을 **그 패널에 직접 연다**. 그 뒤 질문은 페이지가 묻고 사용자가 거기서 답한다 — 채팅으로 항목을 옮기지 않는다.
3. 패널이 없는 환경(일반 채팅)이면 `StataMCP:workflow(…)` → 결과가 `pending` 이면 서버 지침대로 `pending` 항목을 그대로(문구 · 선택지 · 설명 그대로) 묻고 답을 그대로 돌려준다. `stopped` 면 `message` 를 한 줄로 전한다. `panel` 이 있으면 "위 화면에서 진행해 주세요" 한 줄로 끝낸다.
4. 진행 중 사용자가 채팅에 "워크플로에서 …" 라고 쓰면 `workflow()` 로 지금 상자를 조회해 그 선택지에 맞춰 넘긴다. 애매하면 묻는다.

패널 데이터 생성은 Stata 에 데이터가 없어도 시작된다(작업 폴더의 .dta 를 읽음). 폴더가 다르면 사용자가 채팅에 폴더를 적으면 `executeStata` 로 `cd` 한 뒤 `workflow(procedure=panel_build)` 를 다시 부른다.
