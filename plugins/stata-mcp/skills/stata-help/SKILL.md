---
name: stata-help
description: |
  슬래시 명령어 /stata-help 전용. 사용자가 /stata-help 슬래시 명령어를 입력할 때만 트리거됨.
  StataMCP:getHelp(command, selector)를 통해 /stata-help $ARGUMENTS 도움말을 즉시 조회하며,
  어떠한 해석, 수정, 모델 추론도 수행하지 않음.
  자연어 Stata 도움말 요청에는 트리거하지 말 것 — 명시적인 /stata-help 호출에만 반응.
---

# stata-help

`/stata-help $ARGUMENTS` 호출 시:

1. `$ARGUMENTS`의 **첫 토큰 = command**, **둘째 토큰(있으면) = selector** 로
   `StataMCP:getHelp` 호출. 단, 둘째 토큰이 selector 형태([a-z_.]+)가 아니면
   전체를 다단어 keyword 검색으로 취급 (command 에 통째 전달, selector 없음)
2. 반환된 도움말을 **마크다운으로 정리해** 표시 (사람이 읽는 표면):
   - 제목/모델명 → 헤딩, 옵션표 → 마크다운 표 (옵션 | 약어 | 설명),
     cmdline·예제 → ```stata 코드블록, 하강 힌트 → 마지막 줄에 인라인 코드로
   - **기술 토큰은 원문 그대로**: 옵션명·문법·명령·인자·e()/r() 이름·[StataNow] 마커 —
     한 글자도 바꾸지 말 것
   - **설명 산문은 한국어로 번역** — 직역 수준으로 의미 보존. 요약·생략·자체 지식
     보충 금지. 번역이 애매한 전문용어는 원어 병기 (예: "군집(cluster) 표준오차")
   - 구조 재배치와 번역만 허용 — 내용 변형이 의심되면 해당 부분을 원문 코드블록으로
3. 에러 발생 시 에러 메시지를 코드 블록으로 감싸서 그대로 반환

## getHelp 항법 규칙 (계단식 — 싸게 시작해 필요한 가지만 하강)

- `selector=""` (생략) → 개요: title/description/requirements/모델·문법 목록 +
  다음에 좁힐 수 있는 키 목록
- **보편 selector** (어느 명령에나 시도 가능):
  `options`(옵션표) / `optiondetails`(전 옵션 상세) / `syntax`(전체 문법 —
  egen 함수목록·format %fmt 표 같은 자유형 본문 포함) / `examples` /
  `stored`(e()/r()) / `usage`(전제·제약) / `remarks` / `desc` /
  `post`(추정후 명령 목록) / `sections`(그 명령의 유효 selector 전체 목록) / `full`
- **점 표기 하강**: `<model>` (xtreg 의 `fe` 등) → `<model>.<group>` (`fe.se`) →
  `<model>.<option>` (`fe.vce` — 옵션 하나의 상세 설명 전문) /
  `post.<subcmd>` (`post.predict`) / `post.<subcmd>.<option>`
- **미존재 selector 는 에러가 아님** — 그 명령의 유효 selector 목록이 돌아온다.
  모르는 명령은 `""` → (필요시) `sections` → 해당 조각 순으로 탐색
- 옵션 행의 `[StataNow]` 마커 = 최신 추가 기능 (학습 데이터보다 새로움 —
  자기 기억과 충돌하면 도움말 쪽을 신뢰)
- SSC/커뮤니티 명령은 구조화 corpus 밖 — selector 무시되고 통짜 전문 반환

## $ARGUMENTS 예시

- `/stata-help xtreg` → 개요 (모델 목록 + 하강 키)
- `/stata-help xtreg fe` → FE 모델 cmdline + 옵션표
- `/stata-help xtreg fe.vce` → vce 옵션 상세 전문
- `/stata-help regress post.predict` → predict statistic 표
- `/stata-help egen syntax` → egen 함수 40여개 목록
- `/stata-help random effects` → 로컬 키워드 검색 (관련 명령 목록)

`$ARGUMENTS`를 수정, 정제, 평가하지 말 것. 코드 블록 앞뒤에 어떠한 설명도 추가하지 말 것.
`getHelp` 툴이 세션 툴 목록에 없으면 (구버전 서버) "MCP 서버가 getHelp 미지원 버전 — 서버 업데이트 필요" 안내 후 종료.
