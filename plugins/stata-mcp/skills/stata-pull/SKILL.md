---
name: stata-pull
description: |
  슬래시 명령어 /stata-pull 전용. 사용자가 /stata-pull 슬래시 명령어를 입력할 때만 트리거됨.
  Stata GUI에서 push된 결과 또는 async 완료 결과를 StataMCP:getPushResults를 통해 즉시 가져오며,
  결과를 파싱하여 내용을 정리하여 출력하며, 외부 지식 및 추론은 추가하지 않음.
  자연어 Stata push 결과 요청에는 트리거하지 말 것 — 명시적인 /stata-pull 호출에만 반응.
---

# stata-pull

`/stata-pull [mode]` 호출 시:

1. `StataMCP:getPushResults` 실행 — 인자 없으면 `mode=""` (안 읽은 것 중 최고참 pull),
   사용자가 인자를 줬으면 그대로 mode 로 전달
2. 결과 분기:
   - `empty: true` + `asyncRunning: true` → "async 실행 중: <cmd> (<runningForSeconds>초 경과)" 출력
   - `empty: true` + `asyncRunning: false` → "새 push 결과 없음" 출력
   - entry 수신 → 첫 줄에 `id / rc / note / durationMs` 요약, 이어서 `output` 을 코드 블록으로 그대로 출력
3. 에러 발생 시 에러 메시지를 코드 블록으로 감싸서 그대로 반환

mode 참고 (그대로 전달): `<id>` 재조회 / `consume` (pull+삭제) / `history [키워드]` (목차·검색) /
`delete <id>` / `note <id> <텍스트>` / `save [id]` / `load <경로>`.
pull 은 저장소에서 삭제하지 않고 읽음 표시만 한다 — 같은 결과는 `<id>` 로 언제든 재조회 가능.
