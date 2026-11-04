---
name: stata-graph-export
description: "Stata 메모리의 그래프를 PNG 파일로 export"
---

# stata-graph-export

## 지침
- 이미지 비전인식 및 분석은 사용자 요청이 있을 경우에만 진행
- 그래프 분석이 필요할 때 AskUserQuestion 으로 사용자 확인:
	1. question: "그래프를 Claude 가 인지하고 분석하도록 할까요?(vision 토큰 사용)"
	2. options: ["네", "아니오"]

## 실행
- `stata-graph-export [name]` 호출 시 아래 tool을 즉시 실행:
	1. `stata_mcp_java: exportGraph` 실행 — 인자 없으면 `name=""` (현재 그래프), 인자 있으면 그 이름 전달
- `exportGraph` 툴이 세션 툴 목록에 없으면 (구버전 서버) "MCP 서버가 exportGraph 미지원 버전 — 서버 업데이트 필요" 안내 후 종료

## 출력
- 성공 시 응답의 `graphPath` 파일 경로, 파일카드만 출력
- 에러(`error` 필드) 시 에러 JSON을 코드 블록으로 그대로 출력
- 어떠한 해석, 수정, 모델 추론도 수행하지 않음
