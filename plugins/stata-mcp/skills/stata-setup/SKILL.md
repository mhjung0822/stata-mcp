---
name: stata-setup
description: |
  슬래시 명령어 /stata-setup 전용. 사용자가 /stata-setup 슬래시 명령어를 입력할 때만 트리거됨.
  Stata 세션 환경 확인(env·pwd·마운트)과 세션 지침 로드를 위해 정해진 순서대로 즉시 실행한다.
  자연어 Stata 요청에는 트리거하지 말 것 — 명시적인 /stata-setup 호출에만 반응.
---

# stata-setup

`/stata-setup` 호출 시 아래 순서대로 즉시 실행:

1. `StataMCP:getStataEnv` 실행
2. `StataMCP:getStataPwd` 실행
3. 시스템 프롬프트에 마운트 폴더가 있고 Stata pwd 와 다르면 AskUserQuestion 으로 사용자확인:
   - question: "stata 작업 경로를 cowork 경로로 변경할까요?"
   - options: ["네", "아니오"]
   - "네" 선택 시: `executeStata("cd \"<마운트경로>\"")` 실행 → 결과만 알림 (추가 질문 없이)
   - "아니오" → 현재 pwd 유지
4. `stata-instruction` 스킬이 설치돼 있으면 Skill 도구로 호출해 세션 작업 지침을 로드 (사용자가 직접 둔 스킬 — 없으면 이 단계를 건너뛰고, CLAUDE.md 등 사용자 지침이 있으면 그것을 따른다)
5. 변수 창 — AskUserQuestion:
   - question: "변수 창을 열까요?"
   - options: ["네", "아니오"]
   - "네": 내장 브라우저 패널이 있는 환경(Claude Code 브라우저 패널·코워크 브라우저 패널)이면 `openVarsPage(launch=false)` 로 URL 을 받아 **그 패널에 직접 연다**. 패널이 없는 환경(일반 채팅)이면 `openVarsPage(launch=true)` 로 기본 브라우저에 연다
   - "아니오": URL 만 한 줄 안내 (나중에 `/stata-vars` 로 열 수 있다고 덧붙임)
   - Stata 자체 Variables 창(`window manage forward variables`)과 다른 것 — 그 명령은 쓰지 않는다

1·2번 결과는 원문을 그대로 출력하지 않고 **한 줄 요약**으로만 보인다 — 예: `Stata 19.5 MP (8 core) · macOS · 작업폴더 /Users/…`.
`adopath`·sysdir 목록·이론 한계값(max_N_theory 등)·byteorder 같은 항목은 화면에 쓰지 않는다 (툴 응답은 컨텍스트에 남으므로 세션 중 필요할 때 참조만). 3번(마운트 확인)·4번(지침 로드)·5번(변수 창)은 정의된 동작을 수행한다.

## 도구 지침 요약 (v0.12.30) — 이 세션 내내 기억할 것

- **변수 창** (`http://127.0.0.1:<bridgeport>/vars`, `openVarsPage`): 사용자가 체크박스·Y/X 태그로 변수를 고르는 서버 페이지.
  "선택한/체크한/태그한 변수", "변수 창에서 고른 변수" 라고 하거나 변수명 없이 분석을 청하면 **먼저 `getSelectedVariables`** 호출.
  규칙 — 추측 금지: ① "선택한 변수" = `variables`(체크된 것). 비어 있고 태그만 있으면 Y ∪ X ② 역할이 필요 없는 요청
  (summarize·tabulate·correlate·describe·그래프·order/drop 같은 관리)은 그 목록을 varlist 로 ③ 모형 요청(regress·logit·xtreg …)은
  `roles.y` = 결과변수, `roles.x` = 설명변수. Y 가 없거나 모형이 받는 수와 다르면 어느 변수가 결과변수인지 **질문** ④ 둘 다 비면
  변수 창에서 고르거나 변수명을 말해 달라 안내하고 멈춤 ⑤ `missing` 이 있으면 한 줄 알리고 남은 것으로 진행.
  페이지는 MCP 로 실행한 명령 뒤 자동 갱신되고, Stata 창에 직접 친 명령은 페이지 새로고침 버튼으로 반영된다.

- **자연어 Stata 질의는 StataMCP 우선**: 자체 지식으로 먼저 답하지 말 것.
  문법·옵션·구문은 `getHelp`, 실제 계산·추정·요약·변수 생성은 `executeStata` 로
  실행해 반환값을 근거로 답한다(자체 계산으로 수치 생성 금지). 장시간(~30초+)은
  `executeStataAsync`. 데이터 변형·삭제 명령(drop/replace/clear/save 덮어쓰기 등)은
  실행 전 사용자 확인. "문법/설명만" 요청이면 실행하지 말고 `getHelp` 조회만.
- **확인되지 않은 정보는 추측 금지**: 도구 호출로 확인(이미 조회한 값은 재사용), 실패 시 "확인 불가" 명시.
- **작업 중 pwd 변경**: executeStata 응답에 `pwdChange` 가 있으면 사용자가 작업폴더를 옮긴 것.
  `pwdChange.to` 가 마운트 폴더와 다르면 마운트로 되돌릴지 질문.
- **데이터 컨텍스트 갱신**: 데이터 구조·내용 변경(use/merge/drop/generate/replace/reshape 등)
  후, 또는 변수·관측치 정보가 필요한데 없거나 오래됐으면 `/stata-data-context` 를 호출해 갱신.
- **장기 명령**(bootstrap/simulate/mi impute 등 ~30초 이상 예상): `executeStataAsync` 로
  던지고 턴을 끝낸다(폴링 금지). 실행 중 다른 Stata 툴은 즉시 `busy`. 완료 결과는 push 로
  들어온다 — push 듣기가 켜져 있으면 「[push] 새 결과 #n — 요청」 메시지로 저절로, 아니면
  사용자가 `/stata-pull` 로 회수. 빈 응답의 `asyncRunning`/`runningForSeconds` 는 사용자가
  물을 때 진행 상황 답변용.
- **push 저장소**: pull 은 삭제가 아니라 **읽음 표시** — 결과는 보존된다.
  `history [키워드]` = 시간순 목차·검색 (cmd+output+note 부분일치), `note <id> <텍스트>` =
  자연어 메모 (검색 대상 — async 결과를 pull 한 뒤 메모를 달아두면 나중에 찾기 쉬움),
  `<id>` = 전문 재조회, `consume`/`delete <id>` = 삭제, `save [id]`/`load <경로>` =
  JSON 스냅샷으로 세션 간 이어가기.
- **단건 조회는 `getMacro(name, type)` 하나**: 맨이름(`'b'`)이면 local/global/스칼라/행렬을
  전부 프로브해 있는 것을 다 반환, stored 는 풀 표기(`'e(r2)'`, `'e(cmd)'`, `'e(V)'`).
  getScalar/getMatrix 는 v0.11.0 에서 폐지됨.
- **문법이 불확실하거나 응답 `rc`≠0**: `getHelp` 로 확인 후 자가수정. 약어(`'su'`) 자동 해석,
  다단어(`'random effects'`)는 키워드 검색. async 실행 중에도 즉답.
- **사용자 인터랙션**: 다음 단계가 여러 가지일 때는 단순 질문보다 AskUserQuestion 으로 선택지 제공.
- `executeStata` 응답의 `rc`: 0=성공, 그 외 = Stata 에러 코드 (output 은 에코 포함 로그 원형).
