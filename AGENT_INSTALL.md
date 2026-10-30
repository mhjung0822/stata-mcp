# Stata MCP 설치 — 에이전트 실행 절차

> **이 문서는 Claude Code(에이전트)가 읽고 그대로 수행하는 문서입니다.**
> 사람이 읽는 설치 가이드는 [README.md](README.md) 입니다.
>
> **먼저 확인**: 플러그인(README.md 4-1) 이나 확장 프로그램(mcpb, CHAT.md)을 설치할 수 있는 환경이면
> 그쪽이 더 간단합니다 (Node 불필요) — 이 절차는 확장이 안 되는 환경의
> 설정 파일 수동 등록을 대행하는 것입니다.

---

## ⚠️ 먼저 — 설정 대상은 당신이 아니다

- 이 절차는 **Windows + Claude Desktop(채팅·코워크) 전용**입니다.
- 당신(Claude Code)은 **설치 도구로 불려온 것**입니다. 사용자는 Claude Code 를 쓰지 않습니다.
- **`claude mcp add` 를 실행하지 말 것.** 그건 당신 자신에게 등록하는 것이라 사용자에겐 아무 효과가 없습니다.
- 등록 대상은 **언제나 Claude Desktop 의 `claude_desktop_config.json`** 입니다.
- **묻지 말 것, 분기하지 말 것.** 대상은 고정입니다.
- macOS 라면 [README.md](README.md) 4장(확장 프로그램)을 안내하고 종료하세요.

구조: **Stata 안에서 도는 서버(:8080)** ↔ **Claude Desktop**. 당신이 할 일은 **둘을 잇는 config 등록**입니다.
서버는 당신이 못 켭니다 — Stata 안에서만 뜹니다(1단계).

---

## 1) 사전 확인

```
node -v        # 20+ 필요 (사내망 인증서 옵션 --use-system-ca 를 쓰려면 22+)
java -version  # 17+ 필요
```

**없거나 버전이 낮으면 아래 링크를 사용자에게 안내하고, 설치를 마칠 때까지 기다리세요.** 임의로 설치하지 말 것 (관리자 권한·사내 정책 문제).

| 없는 것 | 안내할 링크 |
|---|---|
| **Node.js** (또는 20 미만) | https://nodejs.org/ — LTS 버전. **사내망 PC 면 22+ 를 받게 하세요** (인증서 옵션이 Node 22+ 전용) |
| **Java** (또는 17 미만) | https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html |
| **Claude Desktop** | https://claude.ai/download |
| **Stata** | 별도 구매·설치 — 17 이상 (19 권장) |

설치 후엔 **새 터미널을 열어** 다시 확인하세요 — 기존 세션엔 PATH 갱신이 반영되지 않습니다.

## 2) Stata 측 — 사용자에게 붙여넣게 함

**당신은 Stata 를 직접 못 조작합니다.** 아래를 제시하고 사용자가 Stata 명령창에 붙여넣게 하세요:

```stata
net install stata-mcp, from("https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/release") replace
mcp_setup
mcp_connect
```

- `mcp_setup` — 도움말 DB 다운로드 + 메뉴 등록
- `mcp_connect` — 서버(:8080) + 드론 기동

각 단계 결과를 사용자에게 확인하고 진행하세요. **`mcp_connect` 까지 끝나야 서버가 뜹니다.**

## 3) config 등록 (핵심)

**⚠️ `%APPDATA%\Claude` 를 그냥 쓰지 마세요.** 스토어(MSIX) 설치 PC 에는 **그 폴더가 아예 없습니다.** 없는데 만들어서 쓰면 저장은 되지만 **앱이 절대 안 읽습니다** — 제일 잡기 어려운 실패입니다. (실측: 스토어 설치 PC 에서 `%APPDATA%\Claude` = 없음 / 일반 설치 PC = 있음)

**① 어느 설치인지 시스템에 물어보세요:**
```powershell
Get-AppxPackage -Name "*Claude*" | Select-Object -ExpandProperty PackageFamilyName
```

- **값이 나오면 (스토어/MSIX 설치)** → config 는 여기:
  ```
  %LOCALAPPDATA%\Packages\<PackageFamilyName>\LocalCache\Roaming\Claude\claude_desktop_config.json
  ```
  (예: `Claude_pzs8sxrjxfjjc` — 이 문자열은 PC 마다 다르니 반드시 위 명령으로 확인)
- **아무것도 안 나오면 (일반 설치)** → config 는 여기:
  ```
  %APPDATA%\Claude\claude_desktop_config.json
  ```

**② 위 경로에 파일이 없으면 — 파일명으로 검색:**
```powershell
Get-ChildItem $env:USERPROFILE -Filter claude_desktop_config.json -Recurse -Force -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName
```
`claude_desktop_config.json` 은 Claude Desktop 전용 파일명이라 다른 앱 설정과 안 헷갈립니다.
**여러 개 나오면 전부에 병합하세요** — 아래 병합 규칙(다른 키 보존 + 백업)을 지키면 틀린 파일에 써도 무해합니다.

**③ 그래도 못 찾으면 — 사용자에게 요청:**
> "Claude Desktop → **Settings → Developer → Edit Config** 를 누르면 파일탐색기가 열립니다. 그 파일의 전체 경로를 알려주세요."

**병합 규칙 (반드시 지킬 것):**
- 파일이 있으면 **읽어서 파싱한 뒤 `mcpServers.StataMCP` 키만** 넣으세요. `preferences` 등 **다른 키를 절대 지우지 말 것.**
- 편집 전 `.bak` 백업.
- 파일이 없으면 새로 생성 (폴더도 없으면 생성).

**넣을 값:**
```json
{
  "mcpServers": {
    "StataMCP": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "mcp-remote", "http://127.0.0.1:8080/mcp"]
    }
  }
}
```

- `command` 는 **반드시 `cmd` + `/c`** — Windows 의 `npx` 는 배치파일(`npx.cmd`)이라 직접 spawn 이 안 됩니다.
- URL 은 **평문 http, 포트 8080** 이 맞습니다. `type: "http"` 로 바꾸지 마세요 — Claude Desktop 이 평문 http 를 거부합니다. **stdio 브릿지(mcp-remote)가 유일한 방법입니다.**

**사내망/보안 PC** — `npm` 이 `UNABLE_TO_VERIFY_LEAF_SIGNATURE` 나 `unable to verify the first certificate` 로 실패하면 TLS 검열입니다. 순서대로 시도:

1. `env` 추가 (Node 22+ 필요, **이걸로 대개 해결**):
   ```json
   "env": { "NODE_OPTIONS": "--use-system-ca" }
   ```
2. 회사 루트 CA 파일이 있으면: `"env": { "NODE_EXTRA_CA_CERTS": "C:\\path\\to\\corp-ca.pem" }`
3. 최후 수단 (보안↓, 사용자 동의 받고): `npm config set strict-ssl false`

미리 시험하려면 `npm view mcp-remote version` 이 되는지 보면 됩니다.

## 4) 재시작 — 사용자에게 안내

**Claude Desktop 을 완전 종료 후 재시작해야 합니다.** 창만 닫으면 반영 안 됩니다 — **트레이 아이콘 우클릭 → 종료** 후 실행하도록 안내하세요.

## 5) 검증

```
curl http://127.0.0.1:8080/status
```
- `{"bridge":"running"}` → 서버 정상. 아니면 Stata 에서 `mcp_connect` 재실행 요청.
- 재시작한 Claude Desktop 에서 **`StataMCP` 도구가 보이는지** 사용자에게 확인 요청.

## 6) 스킬 (선택)

슬래시 명령 스킬은 config 로 안 되고 **zip 업로드**뿐입니다. 필요하면 안내:
[`stata-skills-all.zip`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/chat/stata-skills-all.zip) → Claude Desktop **설정 → 스킬 → 업로드** (한 번 올리면 같은 계정 모든 기기에 적용)
(스킬은 StataMCP 도구를 호출하므로 위 3)의 config 등록이 되어 있어야 동작합니다)

---

## 알려진 함정

- **채팅의 MCP 연결은 이 config 방식이 유일**합니다. 확장 프로그램(.mcpb)은 코워크 전용이라 채팅에는 연결되지 않습니다 — **확장 설치로 채팅 MCP 를 살리려 시도하지 마세요.**
- **서버는 Stata 가 켭니다.** `mcp-remote` 는 순수 클라이언트라 서버를 안 켭니다. Stata 가 안 떠 있으면 도구도 안 뜹니다 — 이건 config 문제가 아닙니다.
- **낯선 경로가 로그에 보이면** 옛 커넥터 잔재일 수 있습니다. 활성 config 에 실제로 있는지부터 확인하세요 (백업 파일만 남아 유령 로그를 뿜은 사례 있음).
- **드론 jar 갱신 후엔 Stata 완전 재시작** 필요 (classloader 캐시 — `mcp_connect, reset` 으론 반영 안 됨).
- **도움말 DB 는 pkg 번들이 아닙니다** — `mcp_setup` 이 받습니다. 설치 후 반드시 실행.
