*! mcp_setup  v0.4.0  17nov2026
*!
*! Stata-MCP 단일 진입점 — 설치 · 연결 · 업데이트를 이 명령 하나로 (구 mcp_set · mcp_connect 흡수).
*! mcp_connect 는 이 명령을 부르는 별칭으로 남는다 (서버의 콘솔 Stata 띄우기 · 옛 문서용).
*!
*! Usage:
*!   mcp_setup, install    // 첫 설치 — help DB · 서버 실행 파일(각각 판이 다르면) 받기 + 메뉴 등록 → 이어서 연결
*!   mcp_setup             // 연결 — 서버 + 드론 기동 (네트워크 안 탐. help DB 가 없으면 1회 제안)
*!   mcp_setup, reset      // 드론 · 서버 내렸다 다시 연결
*!   mcp_setup, shutdown   // 이 Stata 의 드론 종료 (서버는 마지막 Stata 가 빠지면 스스로 종료)
*!   mcp_setup, name(agent1) bridgeport(8090) droneport(9001)   // 연결 옵션
*!   mcp_setup, updatedb   // help DB 만, 판과 무관하게 새로 (다이얼로그 [Update help DB] 버튼용) — 메뉴/허브 생략
*!   mcp_setup, update     // 패키지 재설치(net install ..., replace) 뒤 install 과 같이 받는다 — 드론 로드 전에만 (재시작 후 연결 전)
*!   mcp_setup, updatecheck(off|on)  // 연결 시 새 버전 확인 + 연결 횟수 집계 끄기/켜기
*!   mcp_setup, server     // (Go 서버 채널) 서버 실행 파일만 받아 ~/.stata_mcp/bin 에 둔다
*!
*! 채널: 아래 base(받는 주소) 줄은 패키징 때 채널에 맞게 바뀐다 (원본 = 정식). channel 은 go — Java 서버 판은 v0.13.7 로 얼림(배포 저장소 java 브랜치).
*!   go   = 서버가 Go 실행 파일. 패키지(pkg)에는 없고 여기서 받아 고정 자리에 둔다 (help DB 와 같은 방식).
*!   java = 서버가 jar (패키지에 포함). 고정 자리에 남은 Go 실행 파일이 있으면 치운다.
*!
*! help DB (~32MB) 는 pkg 에 번들하지 않고 여기서 온디맨드로 받는다 —
*! net install 을 가볍게 유지하기 위함. 파일은 stata-drone.jar 옆에 둔다
*! (드론 HelpDb/HelpDbV2 의 첫 탐색 위치).

cap program drop mcp_setup
program mcp_setup
    version 17.0
    syntax [, INSTALL UPDATEDB UPDATE UPDATECHECK(string) SERVER ///
              RESET SHUTDOWN NAME(string) BRIDGEPORT(integer 8080) DRONEPORT(integer 0)]

    local base "https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/release"
    local channel "go"

    * ─── server: 서버 실행 파일만 (mcp_server 가 없을 때 부른다) ────────────
    if "`server'" != "" {
        _mcp_setup_server, base("`base'") channel("`channel'")
        exit
    }

    * ─── 연결 (옵션 없음 · reset · shutdown) — 받기 옵션이 없으면 여기서 끝 ──
    * 매일 치는 명령이라 네트워크를 타지 않는다. 판 확인은 install · update 와 드론의 업데이트 알림 몫.
    if "`install'`update'`updatedb'" == "" & `"`updatecheck'"' == "" {
        _mcp_setup_connect, `reset' `shutdown' name(`"`name'"') bridgeport(`bridgeport') droneport(`droneport')
        exit
    }

    * ─── update: 최신 버전 재설치 (net install 과 같은 경로 — 외부 도구 불필요) ──
    if "`update'" != "" {
        * 드론 jar 가 이 세션에 로드돼 있으면 교체 불가 (연결 때 javacall 전에 표시)
        if "$MCP_DRONE_LOADED" == "1" {
            di as error "[Setup] 드론이 실행 중이라 업데이트할 수 없습니다."
            di as error "        Stata 를 재시작한 뒤, {bf:연결하기 전에} mcp_setup, update 를 실행하세요."
            exit 608
        }
        di as text "[Setup] 최신 버전으로 재설치합니다..."
        net install stata-mcp, from("`base'") replace
        * 이어서 아래로 — help DB · 서버 실행 파일까지 한 번에 받는다
    }

    * ─── 드론 jar 위치 = help DB 배치 대상 ────────────────────────────────
    capture findfile stata-drone.jar
    if _rc {
        di as error "[Setup] stata-drone.jar 를 찾을 수 없습니다."
        di as error "        먼저 'net install stata-mcp' 로 패키지를 설치하세요."
        exit 601
    }
    local jarpath `"`r(fn)'"'
    local jardir : subinstr local jarpath "stata-drone.jar" ""

    * ─── updatecheck(off|on): ~/.stata_mcp/stata_mcp.properties 의 UPDATE_CHECK 기록 ──
    * 드론(UpdateCheck)이 기동 시 같은 파일을 읽는다. 다른 줄은 보존 (mcp_watchdog 와 같은 방식).
    * 새 파일이 아직 없으면 예전 자리(드론 jar 옆)의 내용을 바탕으로 쓴다 = 처음 쓸 때 옮겨짐.
    if `"`updatecheck'"' != "" {
        local v = lower(strtrim(`"`updatecheck'"'))
        if !inlist("`v'", "on", "off") {
            di as error "[Setup] updatecheck() 는 on 또는 off"
            exit 198
        }
        local old `"`c(pwd)'"'
        quietly cd ~
        local home `"`c(pwd)'"'
        quietly cd `"`old'"'
        capture mkdir `"`home'/.stata_mcp"'
        local props `"`home'/.stata_mcp/stata_mcp.properties"'
        local src `"`props'"'
        capture confirm file `"`props'"'
        if _rc local src `"`jardir'stata_mcp.properties"'
        tempname in out
        tempfile tmp
        local wrote = 0
        quietly {
            file open `out' using `"`tmp'"', write text replace
            capture confirm file `"`src'"'
            if !_rc {
                file open `in' using `"`src'"', read text
                file read `in' line
                while r(eof) == 0 {
                    if strpos(`"`macval(line)'"', "UPDATE_CHECK") == 1 {
                        file write `out' "UPDATE_CHECK=`v'" _n
                        local wrote = 1
                    }
                    else file write `out' `"`macval(line)'"' _n
                    file read `in' line
                }
                file close `in'
            }
            if !`wrote' file write `out' "UPDATE_CHECK=`v'" _n
            file close `out'
            copy `"`tmp'"' `"`props'"', replace
        }
        if "`v'" == "off" di as text "[Setup] 연결 시 새 버전 확인·연결 횟수 집계 OFF"
        else              di as text "[Setup] 연결 시 새 버전 확인·연결 횟수 집계 ON"
        di as text "        (다음 연결(mcp_setup)부터 적용)"
        exit
    }

    * ─── help DB 목록 ────────────────────────────────────────────────────
    local files stata_cmd_index.json stata_help_corpus.jsonl help_index_v2.json help_nodes_v2.jsonl

    di as text "[Setup] help DB → " as result `"`jardir'"'
    * 판 표시 — 받는 곳의 HELPDB_VERSION 과 깔린 것이 같고 파일이 다 있으면 받지 않는다 (help DB 는 32MB 인데 거의 안 바뀐다).
    * updatedb 는 판과 무관하게 새로 받는다. 받는 곳에 판 표시가 없으면(옛 배포) 없는 파일만 받는다.
    local hwant ""
    local hhave ""
    tempname hf
    tempfile hv
    capture copy `"`base'/HELPDB_VERSION"' `"`hv'"', replace
    if !_rc {
        file open `hf' using `"`hv'"', read text
        file read `hf' hwant
        file close `hf'
    }
    capture confirm file `"`jardir'HELPDB_VERSION"'
    if !_rc {
        file open `hf' using `"`jardir'HELPDB_VERSION"', read text
        file read `hf' hhave
        file close `hf'
    }
    local hwant = strtrim(`"`hwant'"')
    local hhave = strtrim(`"`hhave'"')
    local allthere = 1
    foreach f of local files {
        capture confirm file `"`jardir'`f'"'
        if _rc local allthere = 0
    }
    local ndl = 0
    local nskip = 0
    local nfail = 0
    if "`updatedb'" == "" & `allthere' & `"`hwant'"' != "" & `"`hwant'"' == `"`hhave'"' {
        di as text "[Setup] help DB — 이미 최신 (`hhave')"
    }
    else {
        foreach f of local files {
            local dest `"`jardir'`f'"'
            if "`updatedb'" == "" & `"`hwant'"' == "" {
                capture confirm file `"`dest'"'
                if !_rc {
                    local nskip = `nskip' + 1
                    continue
                }
            }
            di as text "  다운로드: `f' ..."
            capture copy `"`base'/`f'"' `"`dest'"', replace
            if _rc {
                di as error "  실패: `f'  (rc=`=_rc')"
                local nfail = `nfail' + 1
            }
            else {
                local ndl = `ndl' + 1
            }
        }
        di as text "[Setup] help DB — 다운로드 `ndl', 있음 `nskip', 실패 `nfail'"
        if `nfail' > 0 {
            di as error "[Setup] 일부 실패 — 인터넷/방화벽 확인 후 'mcp_setup, updatedb' 로 재시도하세요."
        }
        else if `"`hwant'"' != "" {
            quietly copy `"`hv'"' `"`jardir'HELPDB_VERSION"', replace
        }
    }

    * updatedb = help DB 갱신만 (다이얼로그 [Update help DB] 버튼) — 메뉴 등록/허브 생략
    if "`updatedb'" != "" {
        di as text "[Setup] help DB 갱신 완료."
        exit
    }

    * ─── 서버 실행 파일 (Go 서버 채널) · 반대 채널의 남은 파일 정리 ────────
    capture noisily _mcp_setup_server, base("`base'") channel("`channel'")

    * ─── 레거시 정리 — 라이선스 체계 폐기(v0.12.22)로 남은 ado 제거 ────────
    * net install 은 pkg 에서 빠진 옛 파일을 지우지 않으므로 여기서 정리.
    foreach f in mcp_set_license.ado mcp_get_license.ado mcp_edit_license.ado {
        capture confirm file `"`c(sysdir_plus)'m/`f'"'
        if !_rc {
            capture erase `"`c(sysdir_plus)'m/`f'"'
            if !_rc di as text "[Setup] 레거시 제거: `f'"
        }
    }

    * ─── 제어판 메뉴 등록 (profile.do) ───────────────────────────────────
    di as text "[Setup] 제어판 메뉴 등록..."
    capture mcp_menu, install
    if _rc {
        di as error "[Setup] 메뉴 등록 실패 — 수동으로 'mcp_menu, install' 실행하세요."
    }

    * ─── 설정 허브 (클릭 링크) ──────────────────────────────────────────
    di as text ""
    if "`update'" != "" di as text "[Setup] 설치 완료 — {bf:Stata 를 재시작}한 뒤 mcp_setup 으로 다시 연결하세요."
    di as text "{bf:[Stata-MCP] Setup}"
    di as text "  연결:               {stata mcp_setup:mcp_setup}"
    di as text "  다시 연결:          {stata mcp_setup, reset:mcp_setup, reset}"
    di as text "  연결 끊기:          {stata mcp_setup, shutdown:mcp_setup, shutdown}"
    di as text "  help DB 갱신:       {stata mcp_setup, updatedb:mcp_setup, updatedb}"
    di as text "  최신 버전 재설치:   {stata mcp_setup, update:mcp_setup, update}"
    di as text "  제거:               {stata mcp_uninstall:mcp_uninstall}"
    di as text ""

    * ─── install: 받은 뒤 바로 연결 (update 는 재시작이 필요해 연결하지 않음) ──
    if "`install'" != "" & "`update'" == "" {
        _mcp_setup_connect, name(`"`name'"') bridgeport(`bridgeport') droneport(`droneport')
    }
end

* 서버 실행 파일을 고정 자리(~/.stata_mcp/bin)에 맞춘다.
*   go 채널   — base 의 VERSION 과 고정 자리의 VERSION 이 다르면 실행 파일을 받아 둔다. 남은 서버 jar 는 치운다.
*   java 채널 — 고정 자리에 남은 Go 실행 파일을 치운다 (베타에서 정식으로 돌아온 경우).
* 실패해도 오류로 끝내지 않는다 — 서버는 Claude 플러그인이 띄울 수도 있다.
cap program drop _mcp_setup_server
program _mcp_setup_server
    version 17.0
    syntax , BASE(string) CHANNEL(string)
    * 고정 자리 — mcp_server.ado 의 _mcp_server_bin · 실행 파일 쪽 install.go 와 같은 자리.
    * 경로는 양 OS 모두 / 로 (Windows 의 Stata · winexec 도 받는다. 백슬래시는 매크로 앞에서 이스케이프로 읽힐 수 있다)
    local win = "`c(os)'" == "Windows"
    * 홈 폴더 — 환경 변수(USERPROFILE)로 읽으면 Windows 에서 한글 사용자 이름이 깨진다 (Stata 17 실측).
    * Stata 가 아는 ~ 로 가서 그 경로를 읽고 돌아온다.
    local old `"`c(pwd)'"'
    quietly cd ~
    local home `"`c(pwd)'"'
    quietly cd `"`old'"'
    local name = cond(`win', "stata-mcp-server.exe", "stata-mcp-server")
    local dir  `"`home'/.stata_mcp/bin"'
    local bin  `"`dir'/`name'"'
    local verfile `"`dir'/VERSION"'

    if "`channel'" != "go" {
        foreach f in `"`bin'"' `"`verfile'"' {
            capture confirm file `"`f'"'
            if !_rc {
                capture erase `"`f'"'
                if !_rc di as text "[Setup] Go 서버 파일 정리: `f'"
                else    di as text "[Setup] Go 서버 파일을 지우지 못했습니다 (실행 중일 수 있음): `f'"
            }
        }
        exit
    }

    * 판 비교 — 받는 곳의 VERSION 과 깔린 VERSION
    tempfile vnew
    capture copy `"`base'/VERSION"' `"`vnew'"', replace
    if _rc {
        di as text "[Setup] 서버 판을 확인하지 못했습니다 (인터넷 연결 확인) — 서버 파일은 그대로 둡니다."
        exit
    }
    local want ""
    local have ""
    tempname fh
    file open `fh' using `"`vnew'"', read text
    file read `fh' want
    file close `fh'
    capture confirm file `"`verfile'"'
    if !_rc {
        file open `fh' using `"`verfile'"', read text
        file read `fh' have
        file close `fh'
    }
    local want = strtrim(`"`want'"')
    local have = strtrim(`"`have'"')
    capture confirm file `"`bin'"'
    if !_rc & `"`want'"' == `"`have'"' {
        di as text "[Setup] 서버 — 이미 최신 (`have')"
    }
    else {
        capture mkdir `"`home'/.stata_mcp"'
        capture mkdir `"`dir'"'
        di as text "[Setup] 서버 다운로드: `name' (`want') ..."
        * 임시 이름으로 받아 "install" 로 한 번 실행한다 — 실행 파일이 고정 자리에 자신을 앉히고 VERSION 을 자기 판으로 적는다.
        *   · 판 표시를 실행 파일이 직접 적으므로, 받은 파일과 VERSION 이 어긋나지 않는다 (배포 직후에는 파일마다 반영 시각이 다르다)
        *   · Windows 에서 서버가 실행 중이어도 실행 파일 쪽이 옛 것을 비켜 놓고 교체한다
        local newf = cond(`win', `"`dir'/stata-mcp-server-new.exe"', `"`dir'/stata-mcp-server-new"')
        capture copy `"`base'/`name'"' `"`newf'"', replace
        if _rc {
            di as error "[Setup] 서버 파일을 받지 못했습니다 (rc=`=_rc') — 인터넷/방화벽 또는 `dir' 의 쓰기 권한을 확인한 뒤 'mcp_setup, server' 로 재시도하세요."
            di as error "        이대로도 Claude 를 켜면 플러그인이 서버를 띄웁니다."
            exit
        }
        if `win' {
            winexec "`newf'" install
            sleep 2500
        }
        else {
            quietly shell chmod +x "`newf'"
            quietly shell "`newf'" install
        }
        capture erase `"`newf'"'
        local got ""
        capture confirm file `"`verfile'"'
        if !_rc {
            file open `fh' using `"`verfile'"', read text
            file read `fh' got
            file close `fh'
        }
        local got = strtrim(`"`got'"')
        capture confirm file `"`bin'"'
        if _rc {
            di as error "[Setup] 서버 파일을 `bin' 에 두지 못했습니다 — 백신이 막았거나 쓰기 권한 문제일 수 있습니다."
            di as error "        이대로도 Claude 를 켜면 플러그인이 서버를 띄웁니다."
            exit
        }
        di as text "[Setup] 서버 → " as result `"`bin'"' as text " (`got')"
        if `"`got'"' != `"`want'"' {
            di as text "        받은 파일이 `got' 판입니다 (배포 직후에는 몇 분 늦게 반영됩니다) — 나중에 {stata mcp_setup, server:mcp_setup, server} 로 다시 받으세요."
        }
    }

    * Go 서버 채널에 남은 것 정리 — 정식에서 넘어온 서버 jar · 이전 베타가 ado 폴더에 두던 실행 파일
    capture findfile stata-mcp-server.jar
    if !_rc {
        capture erase `"`r(fn)'"'
        if !_rc di as text "[Setup] 남은 서버 jar 제거"
    }
    foreach f in stata-mcp-server stata-mcp-server.exe {
        capture erase `"`c(sysdir_plus)'s/`f'"'
    }
end

* 연결 — 서버 + 드론 기동 / reset / shutdown (구 mcp_connect 본체, v0.3.15 에서 옮김)
cap program drop _mcp_setup_connect
program _mcp_setup_connect
    version 17.0
    syntax [, RESET SHUTDOWN NAME(string) BRIDGEPORT(integer 8080) DRONEPORT(integer 0)]

    * Windows cmd 는 /dev/null 을 경로로 해석해 명령이 깨짐 → OS 분기 (mcp_server 와 동일)
    local devnul = cond("`c(os)'" == "Windows", "nul", "/dev/null")

    * ─── javapath: Stata 내장 JDK 바이너리 경로 파일 (mcpb 프록시용) ──────
    * Claude Desktop 의 launch 스크립트가 plus/jar/javapath 를 읽어 시스템
    * Java 없이 proxy.jar 를 실행한다. 환경변수는 이미 실행 중인 앱의
    * 프로세스 경계를 못 넘어 파일 채택. 내용이 달라졌을 때만 기록.
    * 개행 없이 1줄 — CRLF 가 섞이면 배치의 set /p 가 \r 를 붙여 경로가 깨짐.
    * 실패는 전부 무해 (프록시가 시스템 java 로 폴백).
    capture {
        local jh = c(java_home)
        if `"`jh'"' != "" {
            local last = substr(`"`jh'"', -1, 1)
            if "`last'" != "/" & "`last'" != "\" local jh `"`jh'/"'
            local jbin ""
            if "`c(os)'" == "Windows" {
                capture confirm file `"`jh'bin\javaw.exe"'
                if !_rc local jbin `"`jh'bin\javaw.exe"'
            }
            else {
                capture confirm file `"`jh'bin/java"'
                if !_rc local jbin `"`jh'bin/java"'
                else {
                    * macOS 번들 레이아웃 (zulu: <home>/Contents/Home/bin/java)
                    capture confirm file `"`jh'Contents/Home/bin/java"'
                    if !_rc local jbin `"`jh'Contents/Home/bin/java"'
                }
            }
            if `"`jbin'"' != "" {
                local jp `"`c(sysdir_plus)'jar/javapath"'
                local cur ""
                tempname jfh
                capture file open `jfh' using `"`jp'"', read text
                if !_rc {
                    file read `jfh' cur
                    capture file close `jfh'
                }
                if `"`macval(cur)'"' != `"`jbin'"' {
                    quietly {
                        file open `jfh' using `"`jp'"', write text replace
                        file write `jfh' `"`jbin'"'
                        file close `jfh'
                    }
                }
            }
        }
    }

    * ─── shutdown: 이 Stata 의 드론 종료 ───────────────────────────────────
    * 서버는 끄지 않는다 — 다른 Stata 가 붙어 있을 수 있음. 마지막 Stata 가 빠지면
    * 서버가 유예 후 스스로 종료한다.
    if "`shutdown'" != "" {
        di as text "[Drone] Shutdown requested..."
        capture javacall com.stata_mcp.drone.StataDrone stop, jars(stata-drone.jar)
        exit
    }

    * ─── Java 버전 체크 — 드론(javacall)·서버(Spring Boot 3) 모두 17+ 필요 ──
    * Stata 번들 JDK 가 17 미만(업데이트 안 된 구버전 설치본)이면 기동 전에 중단.
    * 드론은 Stata JVM 에서만 돌 수 있어 별도 JDK 설치로는 해결 불가 → Stata 업데이트 안내.
    * c(java_version) 이 비어 있으면(JVM 미초기화 등) 판정 없이 통과.
    local jv `"`c(java_version)'"'
    if `"`jv'"' != "" {
        gettoken jmaj jrest : jv, parse(".")
        if "`jmaj'" == "1" {
            * 1.8.0_x 형식
            gettoken dot jrest : jrest, parse(".")
            gettoken jmaj : jrest, parse(".")
        }
        capture confirm integer number `jmaj'
        if !_rc {
            if `jmaj' < 17 {
                di as error "[Stata-MCP] Stata 의 Java 가 `jv' 입니다 — Java 17 이상이 필요합니다."
                di as text  "  Stata 를 업데이트한 뒤 재시작하세요: {stata update all:update all}"
                exit 198
            }
        }
    }

    * ─── reset: 둘 다 끄고 다시 시작 ──────────────────────────────────────
    if "`reset'" != "" {
        di as text "[Reset] Stopping drone + server, then restarting..."
        capture javacall com.stata_mcp.drone.StataDrone stop, jars(stata-drone.jar)
        * 서버 재시작은 붙은 Stata 가 이 세션뿐일 때만 (다른 Stata 연결을 끊지 않게)
        _mcp_others, bridgeport(`bridgeport')
        if r(n) == 0 capture mcp_server, stop bridgeport(`bridgeport')
        sleep 1500
    }

    * ─── 서버 먼저 띄움 (mcp_server 가 idempotency 처리) ──────────────────
    di as text "[Server] starting..."
    mcp_server, bridgeport(`bridgeport')

    * 서버 준비 대기 (Spring Boot 부팅 시간)
    sleep 2000

    * ─── 드론 시작 (이 Stata 에서 이미 떠있으면 skip) ──────────────────────
    * 포트 응답으로 판정하면 다른 Stata 창의 드론을 자기 것으로 오인한다 (Windows 다중 창)
    * → 이 JVM 안의 드론 상태를 직접 묻는다.
    * 이 세션에 드론 jar 가 로드됨 — 이후 mcp_setup, update 가 jar 교체를 거부하는 근거
    * (Windows 는 파일 잠금, Mac 은 실행 중 JVM 의 jar 를 덮어쓰면 깨짐). 정책 차단돼도 로드는 됨
    global MCP_DRONE_LOADED 1
    capture javacall com.stata_mcp.drone.StataDrone running, jars(stata-drone.jar)
    local drone_up = (_rc == 0)

    if `drone_up' {
        di as text "[Drone] already running in this Stata — skip spawn"
    }
    else {
        di as text "[Drone] Starting Java Stata-MCP-Drone..."
        * droneport 0 = 드론이 8001 부터 빈 포트를 고른다
        capture noisily javacall com.stata_mcp.drone.StataDrone start, ///
            args("`bridgeport'" "`droneport'" `"`name'"') jars(stata-drone.jar)
        if _rc == 690 {
            * 원격 정책 차단 (StataDrone.RC_BLOCKED — 제공 종료·강제 업데이트).
            * 안내는 드론이 출력했다. 다른 Stata 가 없으면 먼저 띄운 서버까지 내리고 오류 없이 끝낸다.
            _mcp_others, bridgeport(`bridgeport')
            if r(n) == 0 capture mcp_server, stop bridgeport(`bridgeport')
            exit
        }
        if _rc exit _rc
    }

    * ─── 변수 창 안내 — 서버 로컬 페이지 (브라우저·Claude 앱 브라우저 패널 어디서나) ────
    di as text `"[Vars] {browse "http://127.0.0.1:`bridgeport'/vars":변수 창 열기}  http://127.0.0.1:`bridgeport'/vars"'

    * ─── help DB 선체크 — 없으면 1회 제안 ──────────────────────────────────
    * 거절하면 마커 파일을 남겨 매 연결마다 묻지 않는다. 나중엔 mcp_setup, updatedb.
    * 연결 자체는 이미 끝난 뒤라 다운로드 실패/거절이 연결을 막지 않는다.
    * 콘솔 Stata 는 건너뜀 — 서버가 띄운 콘솔은 입력이 없어 _request 에서 영원히 멈춘다
    capture confirm file `"`c(sysdir_plus)'jar/help_index_v2.json"'
    if _rc & "`c(console)'" != "console" {
        capture confirm file `"`c(sysdir_plus)'jar/helpdb_skip"'
        if _rc {
            di as text "[Setup] 도움말 DB가 없습니다 (~32MB, 최초 1회)."
            di as text "        지금 받으려면 y 입력, 건너뛰려면 그냥 엔터:"
            display _request(mcpyn)
            local yn = lower(strtrim(`"$mcpyn"'))
            capture macro drop mcpyn
            if "`yn'" == "y" {
                capture noisily mcp_setup, updatedb
                capture quietly mcp_menu, install
            }
            else {
                tempname sfh
                capture quietly {
                    file open `sfh' using `"`c(sysdir_plus)'jar/helpdb_skip"', write text replace
                    file write `sfh' "skip"
                    file close `sfh'
                }
                di as text "[Setup] 건너뜀 — 나중에 받으려면: {stata mcp_setup, updatedb:mcp_setup, updatedb}"
            }
        }
    }

end

* 서버에 붙은 "다른" Stata 수 → r(n). 서버가 없거나 응답이 없으면 0.
cap program drop _mcp_others
program _mcp_others, rclass
    syntax , BRIDGEPORT(integer)
    local devnul = cond("`c(os)'" == "Windows", "nul", "/dev/null")
    tempfile chk
    capture shell curl -s --max-time 1 http://127.0.0.1:`bridgeport'/api/drones > "`chk'" 2>`devnul'
    local line ""
    tempname fh
    capture file open `fh' using "`chk'", read text
    if !_rc {
        file read `fh' line
        capture file close `fh'
    }
    local n = 0
    if regexm(`"`line'"', `""count":([0-9]+)"') local n = real(regexs(1))
    * 이 세션의 드론은 이미 stop 했으므로 목록에 남은 수 = 다른 Stata 수
    return scalar n = `n'
end
