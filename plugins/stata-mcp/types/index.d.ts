export type Listen = {
  on: boolean          // 이 세션이 듣는 중 — 푸쉬앱을 열면 켜짐, 「푸쉬앱 꺼 줘」·/stata-push 로 꺼짐
  via: string          // 받는 길 (http / MCP 서버 이름)
  got: number          // Claude 에게 넘긴 이벤트 수
  error: string
  lid: string          // 이 대화의 표지 — 서버가 「받는 대화」를 가름 (다시 불러와도 같게 state 에)
  handedOff: boolean   // 다른 대화가 push 앱을 켜서 멈춤
  told: boolean        // 그 사실을 Claude 맥락에 한 번 붙였는지 (코워크는 띠·토스트가 안 보임)
}

declare module 'claude-code' {
  interface PluginState {
    'stata-mcp': { listen: Shaped<Listen> }
  }
}
