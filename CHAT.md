# 채팅 화면에서 Stata MCP 쓰기

Claude Desktop 의 **채팅** 화면은 플러그인을 쓰지 않습니다. 채팅에서도 Stata 도구와 슬래시 명령을 쓰려면 아래 두 가지를 따로 설치합니다. 코워크·Claude Code 만 쓴다면 필요 없습니다 — [README.md](README.md) 4장의 플러그인으로 충분합니다.

## 1. 확장 프로그램 설치 (MCP 연결)

1. 자신의 OS 에 맞는 파일 **하나만** 다운로드:
   - Mac: [`stata-mcp-mac.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/claude-plugins/chat/stata-mcp-mac.mcpb)
   - Windows: [`stata-mcp-win.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/claude-plugins/chat/stata-mcp-win.mcpb)
2. Claude Desktop 왼쪽 아래 **이름**을 클릭 → **설정** → 왼쪽 목록의 **데스크톱 앱 → 확장 프로그램**을 엽니다.

   <img src="images/claude-ext-1.png" alt="Claude 설정 - 확장 프로그램 화면" width="640">

3. 받은 `.mcpb` 파일을 이 화면에 **끌어다 놓습니다**. 끌어다 놓기가 안 되면 화면 아래 **고급 설정** → **확장 프로그램 설치**를 누르고, 받은 파일을 선택한 뒤 **열기**(Mac 은 **미리보기**로 표시될 수 있음)를 누릅니다.

   <img src="images/claude-ext-2.png" alt="고급 설정 - 확장 프로그램 설치 버튼" width="640">

   <img src="images/claude-ext-3.png" alt="받은 .mcpb 파일 선택" width="640">

4. 확인 창의 이름이 **Stata MCP (Mac)** (Windows 는 **Stata MCP (Windows)**) 인지 확인하고 오른쪽 위 **설치**를 누릅니다.

   <img src="images/claude-ext-4.png" alt="설치 확인 창" width="640">

5. Claude Desktop 재시작

> 화면은 Mac 기준입니다. 서버(`mcp_connect`)를 먼저 띄워 두어야 도구가 동작합니다. 업데이트는 새 `.mcpb` 파일로 같은 방법으로 다시 설치.

## 2. 스킬 등록 (슬래시 명령)

1. [`stata-skills-all.zip` 다운로드](https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/claude-plugins/chat/stata-skills-all.zip)
2. 받은 zip 의 **압축을 풀면** 스킬별 zip 12개가 나옵니다
3. Claude Desktop → **설정 → Skills** → 업로드 → 압축 푼 **스킬별 zip** 들을 업로드 (묶음 zip 을 그대로 올리지 마세요)
4. 한 번 올리면 같은 계정의 모든 기기에 자동 적용됩니다

스킬 구성과 사용법은 [USAGE.md](USAGE.md) 참고.

## 3. 확인

새 대화에서 "Stata 버전 알려 줘" 라고 물어 도구가 호출되면 연결된 것입니다. 안 되면 [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
