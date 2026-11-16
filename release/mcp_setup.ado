*! mcp_setup  v0.3.7  17nov2026
*!
*! Stata-MCP 설정 진입점 (구 mcp_set 흡수) — help DB 를 GitHub 에서 받아
*! 드론 jar 옆에 배치하고, 제어판 메뉴 등록 + 설정 링크(기동/제거)를
*! 출력한다. net install 직후 1회 실행, 이후 설정 허브로도 사용.
*!
*! Usage:
*!   mcp_setup             // 받을 것을 다 받는다 — help DB · 서버 실행 파일(각각 판이 다르면) + mcp_menu,install + 설정 메뉴
*!   mcp_setup, updatedb   // help DB 만, 판과 무관하게 새로 (다이얼로그 [Update help DB] 버튼용) — 메뉴/허브 생략
*!   mcp_setup, update     // 패키지 재설치(net install ..., replace) 뒤 위와 같이 다 받는다 — 드론 로드 전에만 (재시작 후 연결 전)
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
    syntax [, UPDATEDB UPDATE UPDATECHECK(string) SERVER]

    local base "https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/release"
    local channel "go"

    * ─── server: 서버 실행 파일만 (mcp_server 가 없을 때 부른다) ────────────
    if "`server'" != "" {
        _mcp_setup_server, base("`base'") channel("`channel'")
        exit
    }

    * ─── update: 최신 버전 재설치 (net install 과 같은 경로 — 외부 도구 불필요) ──
    if "`update'" != "" {
        * 드론 jar 가 이 세션에 로드돼 있으면 교체 불가 (mcp_connect 가 javacall 전에 표시)
        if "$MCP_DRONE_LOADED" == "1" {
            di as error "[Setup] 드론이 실행 중이라 업데이트할 수 없습니다."
            di as error "        Stata 를 재시작한 뒤, {bf:mcp_connect 로 연결하기 전에} mcp_setup, update 를 실행하세요."
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
        di as text "        (다음 mcp_connect 부터 적용)"
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

    * ─── 설정 허브 (구 mcp_set 흡수 — 클릭 링크, 서버·드론 기동 안 함) ────
    di as text ""
    if "`update'" != "" di as text "[Setup] 설치 완료 — {bf:Stata 를 재시작}한 뒤 mcp_connect 로 다시 연결하세요."
    di as text "{bf:[Stata-MCP] Setup}"
    di as text "  help DB 갱신:        {stata mcp_setup, updatedb:mcp_setup, updatedb}"
    di as text "  최신 버전 재설치:    {stata mcp_setup, update:mcp_setup, update}"
    di as text "  서버·드론 기동:      {stata mcp_connect:mcp_connect}"
    di as text "  제거:               {stata mcp_uninstall:mcp_uninstall}"
    di as text ""
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
