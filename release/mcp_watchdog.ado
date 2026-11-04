*! mcp_watchdog  v0.1.1  20oct2026
*!
*! Stata 종료 시 서버 자동 종료 설정 (마지막 Stata 가 끝나면 grace 초 뒤 종료).
*!   1) stata_mcp.properties (server jar 옆) 에
*!      enabled / grace-seconds 를 기록 → 서버 재시작 후에도 유지
*!   2) 떠 있는 브릿지에 POST /api/watchdog → 재시작 없이 즉시 반영
*!
*! Usage:
*!   mcp_watchdog                            // enabled=1, grace=1 (기본)
*!   mcp_watchdog, grace(120)                // 유예 120초
*!   mcp_watchdog, enabled(0)                // 자동 정리 끄기 (서버 상주)
*!   mcp_watchdog, grace(60) enabled(1) bridgeport(8090)
*!
*! 다이얼로그(db mcp) 의 Auto-shutdown [Apply] 버튼이 이 명령을 호출한다.

cap program drop mcp_watchdog
program mcp_watchdog
    version 17.0
    syntax [, GRace(integer 1) ENabled(integer 1) BRIDGEPORT(integer 8080)]

    if `grace' < 0 | `grace' > 3600 {
        di as error "mcp_watchdog: grace() must be between 0 and 3600 seconds"
        exit 198
    }
    if `enabled' != 0 & `enabled' != 1 {
        di as error "mcp_watchdog: enabled() must be 0 or 1"
        exit 198
    }
    local en = cond(`enabled', "true", "false")
    * Windows cmd 는 /dev/null 을 경로로 해석해 명령이 깨짐 → OS 분기 (mcp_server 와 동일)
    local devnul = cond("`c(os)'" == "Windows", "nul", "/dev/null")

    * ─── properties 경로 = server jar 옆 ─────────────────────────────────
    capture findfile stata-mcp-server.jar
    if _rc {
        di as error "mcp_watchdog: stata-mcp-server.jar not found in adopath"
        exit 601
    }
    local jarpath `"`r(fn)'"'
    local jardir : subinstr local jarpath "stata-mcp-server.jar" ""
    local props `"`jardir'stata_mcp.properties"'

    * ─── read-modify-write: 두 키만 교체, 나머지 줄(라이선스 등) 보존 ──────
    * quietly 블록 — file open(write replace)·copy 가 SFI 실행 컨텍스트에서
    * "(file S_*.n not found)" 정보성 잡음을 찍는 것 억제 (macOS 실측)
    tempname in out
    tempfile tmp
    local wrote_en = 0
    local wrote_gr = 0
    quietly {
        file open `out' using `"`tmp'"', write text replace
        capture confirm file `"`props'"'
        if !_rc {
            file open `in' using `"`props'"', read text
            file read `in' line
            while r(eof) == 0 {
                if strpos(`"`macval(line)'"', "stata.mcp.watchdog.enabled") == 1 {
                    file write `out' "stata.mcp.watchdog.enabled=`en'" _n
                    local wrote_en = 1
                }
                else if strpos(`"`macval(line)'"', "stata.mcp.watchdog.grace-seconds") == 1 {
                    file write `out' "stata.mcp.watchdog.grace-seconds=`grace'" _n
                    local wrote_gr = 1
                }
                else {
                    file write `out' `"`macval(line)'"' _n
                }
                file read `in' line
            }
            file close `in'
        }
        if !`wrote_en'  file write `out' "stata.mcp.watchdog.enabled=`en'" _n
        if !`wrote_gr'  file write `out' "stata.mcp.watchdog.grace-seconds=`grace'" _n
        file close `out'
        copy `"`tmp'"' `"`props'"', replace
    }

    * ─── 라이브 적용 (서버 안 떠 있으면 조용히 무시 — properties 는 이미 기록) ─
    * stdout 을 실제 tempfile 로 리다이렉트 — /dev/null 로 보내면 Stata 가 출력
    * 캡처 파일을 못 찾아 "(file S_*.n not found)" 잡음을 찍는다 (macOS 실측,
    * mcp_server/mcp_connect 의 status 체크와 동일한 검증된 패턴)
    tempfile resp
    capture shell curl -s --max-time 2 -X POST "http://127.0.0.1:`bridgeport'/api/watchdog?enabled=`en'&graceSeconds=`grace'" > "`resp'" 2>`devnul'

    if `enabled' {
        di as text "[Watchdog] Stata 종료 시 자동 정리 ON — 유예 `grace'초 (기록 + 서버 즉시 반영)"
    }
    else {
        di as text "[Watchdog] 자동 정리 OFF — Stata 를 꺼도 서버 상주 (기록 + 서버 즉시 반영)"
    }
end
