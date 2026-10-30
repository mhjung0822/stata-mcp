# 기타 환경 이슈

자주 겪지는 않지만 특정 환경에서 나타나는 문제들입니다. 일반적인 사용 문제는 [USAGE.md](USAGE.md)의 "문제 해결" 참고.

---

## Windows 에서 코워크 자체가 활성화되지 않을 때

최신 Claude Desktop 은 대부분의 PC 에서 별도 설정 없이 코워크가 동작합니다.
**코워크 자체가 켜지지 않는 일부 환경**에서만 아래를 확인하세요.

**현재 상태 확인** — cmd 에서:

```
systeminfo | findstr Hyper
```

- `하이퍼바이저가 검색되었습니다` 한 줄 → 가상화 문제 아님 (다른 원인)
- `펌웨어에 가상화 사용: 아니요` → BIOS 에서 하드웨어 가상화를 켜야 합니다 (아래)
- 모두 `예` 인데 위 한 줄이 없으면 → "가상 머신 플랫폼" 활성화 후 재부팅 필요 (아래)

**가상 머신 플랫폼 켜기** — 관리자 PowerShell 에서 실행 후 **재부팅**:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
```

**BIOS 하드웨어 가상화** — 위를 해도 안 되면 BIOS 에서 가상화(Intel VT-x / AMD SVM)가
꺼져 있는 경우입니다. 작업 관리자 → 성능 → CPU 의 "가상화" 항목이 "사용 안 함"이면
부팅 시 BIOS 에 진입해 해당 항목을 켜세요 (제조사별 진입 키 상이 — 보통 F2/Del).

## 코워크에서 Stata 커넥터가 안 보일 때

1. **Stata 쪽 서버가 떠 있는지 먼저** — Stata 에서 `mcp_connect` 실행 후 다시 시도
2. 로그인 직후에는 커넥터가 몇 분간 안 보일 수 있습니다 — 잠시 후 새 세션으로 재시도
3. 그래도 안 보이면 Claude Desktop 을 완전히 종료(트레이 → Quit) 후 재실행

## 확장(mcpb)을 쓸 수 없는 환경 — 설정 파일 수동 등록

Claude Desktop 의 설정 파일(`claude_desktop_config.json`)에 직접 등록하는 방법이
있습니다. **Claude Code 를 열고 아래를 붙여넣으면** 등록을 대신 처리해 줍니다:

```
https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/AGENT_INSTALL.md
이 문서 읽고 Stata MCP 설치해줘.
```

(이 경로는 Node 22 이상이 필요합니다 — 확장 설치가 되는 환경이면 확장을 쓰세요)

## Claude Code 에서 쓰기

터미널의 Claude Code 에서도 쓰려면 별도 등록이 필요합니다 — 한 줄 (Mac·Windows 동일, Node 불필요):

```
claude mcp add --transport http StataMCP http://127.0.0.1:8080/mcp --scope user
```

`claude mcp list` 로 확인 — Stata 에서 `mcp_connect` 로 서버가 떠 있으면 `✓ Connected` 로 표시됩니다.
