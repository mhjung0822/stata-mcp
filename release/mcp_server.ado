*! mcp_server  v0.2.8  20oct2026
*!
*! Start / check / stop stata-mcp-server.jar located in the Stata
*! PERSONAL ado folder (resolved via `findfile`, so no path argument
*! is needed).
*!
*! Usage:
*!   mcp_server                    // detached background spawn (default)
*!   mcp_server, status            // GET http://127.0.0.1:<port>/status
*!   mcp_server, stop              // terminate any java process running the jar
*!   mcp_server, bridgeport(8090)  // override status check port (default 8080)
*!
*! Notes:
*! - On macOS/Linux uses `shell bash -c "... & disown"` — wrapping in bash
*!   with disown is required because Stata itself runs on a JVM, so plain
*!   `shell java ...` binds the new JVM into Stata's JVM hierarchy and the
*!   server cannot run independently. Disowning re-parents java to launchd.
*! - On Windows uses `winexec javaw` (asynchronous CreateProcess — no JVM
*!   hierarchy issue). `javaw` is the windowless Java launcher: same JVM as
*!   `java` but no console window pops up (server logs go to server-logs/ file).
*! - Server lifecycle is independent of Stata once spawned — kill explicitly
*!   via `mcp_server, stop` or `taskkill` / `pkill`.

cap program drop mcp_server
program mcp_server
    version 17.0
    syntax [, STATUS STOP BRIDGEPORT(integer 8080) DRONEPORT(integer 8001)]

    * stderr 버림 리다이렉트 — Windows cmd 는 /dev/null 을 경로로 해석해 명령
    * 전체가 깨진다 (멱등성 체크가 항상 빈손 → mcp_connect 때마다 서버 중복
    * 스폰되던 Windows 버그의 원인, 2026-08-04 실측)
    local devnul = cond("`c(os)'" == "Windows", "nul", "/dev/null")

    * ─── stop ──────────────────────────────────────────────────────────────
    if "`stop'" != "" {
        di as text "[Server] terminating stata-mcp-server.jar process..."
        * 정상 경로: 서버 자체 shutdown 엔드포인트 (전 OS 동일, 프로세스 매칭 불필요)
        quietly shell curl -s --max-time 2 -X POST http://127.0.0.1:`bridgeport'/api/shutdown
        * fallback: HTTP 가 안 받을 때만 의미 (이미 죽었으면 no-op)
        if "`c(os)'" == "Windows" {
            quietly shell taskkill /F /IM java.exe /FI "WINDOWTITLE eq *stata-mcp-server*"
        }
        else {
            quietly shell pkill -f stata-mcp-server.jar
        }
        exit
    }

    * ─── status ────────────────────────────────────────────────────────────
    if "`status'" != "" {
        di as text "[Server] GET http://127.0.0.1:`bridgeport'/status"
        shell curl -s --max-time 2 http://127.0.0.1:`bridgeport'/status
        di ""
        * 드론 상태 + 버전 + 라이선스 만료를 한 화면에 (제어판 Status 버튼용)
        tempfile dchk
        capture shell curl -s --max-time 2 -H "X-Stata-MCP: 1" http://127.0.0.1:`droneport'/status > "`dchk'" 2>`devnul'
        local dline ""
        tempname dfh
        capture file open `dfh' using "`dchk'", read text
        if !_rc {
            file read `dfh' dline
            capture file close `dfh'
        }
        if `"`dline'"' == "" {
            di as error "[Drone]  not running (port `droneport') — run mcp_connect in Stata"
        }
        else {
            local dver ""
            if regexm(`"`dline'"', `""version":"([^"]+)""')          local dver = regexs(1)
            di as text "[Drone]  v`dver' running (port `droneport')"
        }
        exit
    }

    * ─── start (default) ───────────────────────────────────────────────────
    * 멱등성: 이미 떠있으면 spawn skip (port 8080 점유 → 새 JVM 이 BindException
    * 으로 죽으면서 server-logs/ 에 잡음 쌓이는 거 방지)
    tempfile chk
    capture shell curl -s --max-time 1 http://127.0.0.1:`bridgeport'/status > "`chk'" 2>`devnul'
    tempname fh
    capture file open `fh' using "`chk'", read text
    if !_rc {
        file read `fh' line
        capture file close `fh'
        if strpos(`"`line'"', "running") > 0 {
            di as text "[Server] already running on port `bridgeport' — skip spawn"
            exit
        }
    }

    capture findfile stata-mcp-server.jar
    if _rc {
        di as error "mcp_server: stata-mcp-server.jar not found in adopath"
        di as error "Copy it to your PERSONAL ado folder (see INSTALL.md section 3)"
        di as error "Current adopath:"
        adopath
        exit 601
    }
    local jar "`r(fn)'"

    * ─── 스폰 자바 해석: Stata 내장 JDK 우선 → 시스템 java 폴백 ───────────
    * c(java_home) 은 Stata 가 자기 내장 JDK(또는 사용자가 set java_home 으로
    * 지정한 JDK)를 가리킨다 — 시스템 Java 미설치 머신도 서버 스폰 가능.
    local jbin ""
    capture {
        local jh = c(java_home)
        if `"`jh'"' != "" {
            local last = substr(`"`jh'"', -1, 1)
            if "`last'" != "/" & "`last'" != "\" local jh `"`jh'/"'
            if "`c(os)'" == "Windows" {
                capture confirm file `"`jh'bin\javaw.exe"'
                if !_rc local jbin `"`jh'bin\javaw.exe"'
            }
            else {
                capture confirm file `"`jh'bin/java"'
                if !_rc local jbin `"`jh'bin/java"'
                else {
                    capture confirm file `"`jh'Contents/Home/bin/java"'
                    if !_rc local jbin `"`jh'Contents/Home/bin/java"'
                }
            }
        }
    }

    if "`c(os)'" == "Windows" {
        * javaw = 콘솔 창 없는 Java 런처 (java 와 동일 JVM, 같은 bin 폴더).
        if `"`jbin'"' != "" winexec "`jbin'" -jar "`jar'"
        else                winexec javaw -jar "`jar'"
    }
    else {
        * bash -c "... & disown" 패턴이 필수.
        * Stata 자체가 JVM 위에서 돌아서, `shell java ...` 만 쓰면 새 JVM 이
        * Stata 의 JVM 위계 안에 묶여 독립 실행이 안 됨. bash 라는 비-Java
        * 중간 프로세스가 끼어들어 disown 으로 job table 에서 분리해야
        * java 가 orphan 되어 launchd 로 reparent → Stata 종료에도 생존.
        * FD 3+ 일괄 close 가 java 실행 전 선행 — Stata JVM 의 열린 FD
        * (특히 드론 8001 리스닝 소켓) 가 자식 java 에 상속되면, 드론 재시작
        * 시 8001 재바인드 실패 + 응답 없는 좀비 LISTEN 이 남는 사고 방지
        * (2026-08-03 실사고). 바깥 작은따옴표라 $fd 는 sh 를 그대로 통과,
        * Stata 단계에선 \$ 로 글로벌 매크로 확장 회피 (전달 경로 실기검증됨).
        * nohup + </dev/null — 서버는 띄운 Stata 와 같은 프로세스 그룹·터미널에 남는다. 콘솔 Stata 가
        * 띄운 뒤 그 터미널 창을 닫으면 SIGHUP 이 서버까지 닿아, 다른 Stata(GUI)가 붙어 있어도 서버가
        * 죽었다 (2026-10-20 실측). JVM 은 기동 시 무시 상태인 SIGHUP 을 그대로 둔다.
        * quietly — shell 의 잔여 빈 줄 출력 억제.
        local jrun "java"
        if `"`jbin'"' != "" local jrun `""`jbin'""'
        quietly shell bash -c 'for fd in {3..1023}; do eval "exec \$fd>&-"; done 2>/dev/null; nohup `jrun' -jar "`jar'" </dev/null >/dev/null 2>&1 & disown'
    }
    di as text "[Server] spawned (detached)"
end
