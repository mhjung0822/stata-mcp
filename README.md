# Stata MCP — Stata × Claude · ChatGPT

> **English summary** — Stata MCP is an **AI assistant for Stata**: an MCP (Model Context Protocol) server that connects **Stata** with **Claude** and **ChatGPT**.
> Ask for an analysis in chat and it runs in your own Stata on the same data — regressions, data management, graphs, do-files; send results you ran yourself back to the AI to interpret and continue.
> You keep using Stata as usual and bring in the AI only when you need it. Requires Stata 17+ (19 recommended) and Claude Desktop.
> Full English docs: [README.en.md](README.en.md) · [USAGE.en.md](USAGE.en.md) · [Demo videos](https://www.youtube.com/@Stata-MCP)

Stata MCP는 Claude·ChatGPT가 **Stata(결과 창·데이터 브라우저·그래프 등)에서 같은 데이터로 함께 작업**하게 해 주는 도구입니다. **분석 명령과 결과를 서로 주고받는** 방식으로, 대화로 분석을 요청하면 내 Stata에서 바로 실행되고, Stata에서 직접 돌린 결과도 AI에 보내 해석과 다음 작업을 이어 갈 수 있습니다. 연결된 상태에서도 Stata는 평소처럼 직접 사용할 수 있고, 필요할 때만 AI의 도움을 받으면 됩니다.

[![Stata MCP — AI assistant for Stata: Stata 와 Claude 가 같은 데이터로 함께 작업하는 화면 (Claude and Stata working on the same data)](images/hero.png)](https://www.youtube.com/@Stata-MCP)

▶ [데모 영상 보기 (YouTube 채널)](https://www.youtube.com/@Stata-MCP)

설치는 3단계입니다: **① Stata 측 설치 → ② 서버 기동 → ③ Claude 등록 (확장 + 스킬)**.
ChatGPT 데스크톱 앱에서도 연결할 수 있습니다 — 6장 참고.

설치 후 사용법·문제 해결은 [USAGE.md](USAGE.md) 참고.

---

## 1. 사전 요구 사항

| 항목 | 버전 |
|------|------|
| Stata | 17 이상 (19 권장) |
| Claude Desktop | 최신 — [다운로드](https://claude.ai/download) |

---

## 2. Stata 측 설치

Stata 에서 한 줄:

```stata
net install stata-mcp, from("https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/release") replace
```

jar 2종 + ado/dlg 가 자동 다운로드됩니다. 설치는 이게 전부입니다 — 도움말 DB(~32MB)는 다음 장의 `mcp_connect` 가 처음 연결할 때 받을지 물어봅니다 (y 권장, 인터넷 연결 필요).

업데이트는 **Stata 를 새로 켠 뒤, `mcp_connect` 로 연결하기 전에**:

```stata
mcp_setup, update
mcp_setup, updatedb
```

- `mcp_setup, update` — 최신 버전으로 재설치. 오류가 나면 위의 설치 명령(`net install ...`)을 다시 실행하세요
- `mcp_setup, updatedb` — 도움말 DB 도 최신으로 (제어판 [Update help DB] 버튼과 동일)

> 업데이트를 적용하려면 **Stata 를 다시 재시작**한 뒤 `mcp_connect` 로 연결하세요.

> Claude 확장 프로그램(`.mcpb`)은 위 업데이트와 별개입니다. 새 버전이 나오면 4-1장의 파일을 다시 받아 같은 방법으로 설치하세요.

> 포트를 바꾸려면 (기본 8080/8001) jar 옆 `stata_mcp.properties` 의 `BRIDGE_PORT`/`DRONE_PORT` 수정 — 파일은 첫 기동 시 자동 생성.

---

## 3. 서버 기동

```stata
mcp_connect
```

MCP 서버와 드론이 한 번에 기동됩니다. 첫 실행이면 도움말 DB 다운로드를 물어봅니다 — `y` 입력(권장).

> Stata 를 종료하면 서버도 자동으로 함께 종료됩니다. 명령 대신 GUI 제어판(`db mcp`)으로도 켤 수 있습니다 — [USAGE.md](USAGE.md) 참고.

> 연결할 때 새 버전이 있는지 한 번 확인하고, 있으면 결과 창에 안내가 나옵니다 (Stata 를 재시작한 뒤 연결하기 전에 `mcp_setup, update` 실행). 이때 연결 횟수만 익명으로 집계됩니다. 끄려면 `mcp_setup, updatecheck(off)`. 지원이 끝난 버전은 연결되지 않고 안내가 나옵니다.

> ⚠️ **`Java 17 이상이 필요합니다` 안내가 나오거나, `java.lang.UnsupportedClassVersionError` 가 붉게 출력되며 드론이 시작되지 않으면** — Stata 내장 Java 가 구버전인 경우입니다. Stata 에서 `update all` 로 최신 업데이트 후 **Stata 재시작** → `mcp_connect` 재실행. 상세는 [USAGE.md](USAGE.md) 문제 해결 참고.

---

## 4. Claude 등록 (코워크)

> Windows 에서 코워크 자체가 켜지지 않는 등 환경 문제는 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 참고.

### 4-1. 확장 프로그램 설치 (MCP 연결)

1. 자신의 OS 에 맞는 파일 **하나만** 다운로드:
   - Mac: [`stata-mcp-mac.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/stata-mcp-mac.mcpb)
   - Windows: [`stata-mcp-win.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/stata-mcp-win.mcpb)
     - 설치가 안 되거나 도구가 나타나지 않으면 [`stata-mcp-win-java.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/stata-mcp-win-java.mcpb) 를 대신 설치하세요. 두 개를 동시에 설치하지는 마세요.
2. Claude Desktop 왼쪽 아래 **이름**을 클릭 → **설정** → 왼쪽 목록의 **데스크톱 앱 → 확장 프로그램**을 엽니다.

   <img src="images/claude-ext-1.png" alt="Claude 설정 - 확장 프로그램 화면" width="640">

3. 받은 `.mcpb` 파일을 이 화면에 **끌어다 놓습니다**. 끌어다 놓기가 안 되면 화면 아래 **고급 설정** → **확장 프로그램 설치**를 누르고, 받은 파일을 선택한 뒤 **열기**(Mac 은 **미리보기**로 표시될 수 있음)를 누릅니다.

   <img src="images/claude-ext-2.png" alt="고급 설정 - 확장 프로그램 설치 버튼" width="640">

   <img src="images/claude-ext-3.png" alt="받은 .mcpb 파일 선택" width="640">

4. 확인 창의 이름이 **Stata MCP (Mac)** (Windows 는 **Stata MCP (Windows)**) 인지 확인하고 오른쪽 위 **설치**를 누릅니다.

   <img src="images/claude-ext-4.png" alt="설치 확인 창" width="640">

5. Claude Desktop 재시작

> 화면은 Mac 기준입니다. 3장에서 서버(`mcp_connect`)를 먼저 띄워 두어야 도구가 동작합니다. 업데이트는 새 `.mcpb` 파일로 같은 방법으로 다시 설치.

### 4-2. 스킬 등록 (슬래시 명령)

1. [`stata-skills-all.zip` 다운로드](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/stata-skills-all.zip)
2. 받은 zip 의 **압축을 풀면** 스킬별 zip 11개가 나옵니다
3. Claude Desktop → **설정 → 스킬** → 업로드 → 압축 푼 **스킬별 zip** 들을 업로드 (묶음 zip 을 그대로 올리지 마세요)
4. 한 번 올리면 같은 계정의 모든 기기에 자동 적용됩니다

스킬 구성과 사용법은 [USAGE.md](USAGE.md) 참고.

---

## 5. 연결 테스트

Stata 와 Claude Desktop 을 모두 **완전 종료**한 상태에서 시작합니다 — Claude 는
창만 닫으면 백그라운드에 남으므로, Windows 는 트레이 아이콘 우클릭 → **Quit**,
Mac 은 **⌘Q** 로 종료하세요. 이후 순서대로:

```
1. Stata 실행 → mcp_connect
2. Claude Desktop 실행
```

이후 새 대화(또는 코워크 세션)에서:

```
Stata 버전 알려줘
```

버전·에디션(예: StataNow/MP 19.5)이 답으로 오면 설치 완료입니다.

안 되면 순서대로 확인하세요:

1. Stata 결과창 — `mcp_connect` 출력에 `Ready for commands` 가 있는지 (없으면 3장 서버 기동)
2. Claude 도구 목록 — Stata MCP 확장이 보이는지 (안 보이면 Claude Desktop 완전 종료 후 재실행)

사용법 전반은 [USAGE.md](USAGE.md) 참고 — 시작 순서, 제어판, push 알림, 도움말 조회, 문제 해결. 드문 환경 이슈는 [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## 6. ChatGPT 데스크톱 앱에서 연결 (선택)

Claude 대신 ChatGPT 데스크톱 앱에서도 같은 Stata 에 연결할 수 있습니다. 확장 파일은 필요 없고, 주소만 등록하면 됩니다.

1. ChatGPT 데스크톱 앱 왼쪽 아래 **프로필**을 클릭 → **설정** → 왼쪽 목록의 **통합 → 플러그인**을 엽니다.

   <img src="images/chatgpt-mcp-1.png" alt="ChatGPT 설정 - 플러그인 화면" width="640">

2. 위쪽 **MCP** 탭을 누르고, 오른쪽 위 **추가** → **MCP 서버 추가**를 누릅니다.

   <img src="images/chatgpt-mcp-2.png" alt="MCP 탭 - 추가 - MCP 서버 추가" width="640">

3. 아래와 같이 입력하고 오른쪽 아래 **저장**을 누릅니다.
   - **이름**: `Stata-mcp` (원하는 이름으로 바꿔도 됩니다)
   - **유형**: **스트리밍 가능한 HTTP** 선택
   - **URL**: `http://127.0.0.1:8080/mcp`
   - 기본 token 환경 변수·헤더·환경 변수의 헤더 칸은 **비워 둡니다**

   <img src="images/chatgpt-mcp-3.png" alt="맞춤형 MCP에 연결 - 입력 예" width="640">

4. 새 대화에서 `Stata 버전 알려줘` 를 입력해 버전이 답으로 오면 연결 완료입니다.

> 화면은 Mac 기준입니다. 3장의 `mcp_connect` 로 서버를 먼저 띄워 두어야 도구가 동작합니다. 포트를 바꿨다면(2장 참고) URL 의 `8080` 을 바꾼 포트로 입력하세요. 4-2장의 스킬 묶음은 Claude 용입니다.


---

## 이용 안내

- 연결할 때마다 연결 횟수가 익명으로 집계됩니다. 끄려면 `mcp_setup, updatecheck(off)`.
- 이 서비스는 사정에 따라 종료되거나 변경될 수 있습니다.

---

## 라이선스

Copyright (c) 2026 [JasonTG, Inc.](https://www.jat.co.kr/) and mhjung0822

개인 및 비영리 기관의 비상업적 연구·교육 목적으로 무료로 제공됩니다. 그 밖의 사용과 허가 없는 재배포·수정·판매는 금지됩니다. 소프트웨어는 "있는 그대로" 제공되며, 사용 및 분석 결과에 대해 어떠한 보증이나 책임도 지지 않습니다. 이용 조건은 새 버전에서 변경될 수 있습니다. 전문은 [LICENSE](LICENSE) 참고.

Stata는 StataCorp LLC의 등록상표입니다. 이 프로젝트는 독립적으로 개발된 도구로, StataCorp LLC와 제휴·보증 관계가 없습니다.
