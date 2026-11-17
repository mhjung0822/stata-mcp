*! mcp_connect  v0.4.0  17nov2026
*!
*! 별칭 — mcp_setup 이 연결까지 맡는다 (v0.4.0 에서 본체를 mcp_setup.ado 로 옮김).
*! 서버의 콘솔 Stata 띄우기("mcp_connect, name(…) bridgeport(…)")와 옛 문서 · 습관을 위해 남긴다.
*!
*! Usage (mcp_setup 과 같다):
*!   mcp_connect                 = mcp_setup
*!   mcp_connect, reset          = mcp_setup, reset
*!   mcp_connect, shutdown       = mcp_setup, shutdown
*!   mcp_connect, name(agent1) bridgeport(8090) droneport(9001)

cap program drop mcp_connect
program mcp_connect
    version 17.0
    syntax [, RESET SHUTDOWN NAME(string) BRIDGEPORT(integer 8080) DRONEPORT(integer 0)]
    mcp_setup, `reset' `shutdown' name(`"`name'"') bridgeport(`bridgeport') droneport(`droneport')
end
