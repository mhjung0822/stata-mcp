*! mcp_setup  v0.3.1  06oct2026
*!
*! Stata-MCP 설정 진입점 (구 mcp_set 흡수) — help DB 를 GitHub 에서 받아
*! 드론 jar 옆에 배치하고, 제어판 메뉴 등록 + 설정 링크(기동/제거)를
*! 출력한다. net install 직후 1회 실행, 이후 설정 허브로도 사용.
*!
*! Usage:
*!   mcp_setup             // help DB 다운로드(없으면) + mcp_menu,install + 설정 메뉴
*!   mcp_setup, updatedb   // help DB 갱신만 (다이얼로그 [Update help DB] 버튼용) — 메뉴/허브 생략
*!   mcp_setup, update     // 최신 버전으로 재설치 (net install ..., replace) — 드론 로드 전에만 (재시작 후 연결 전)
*!   mcp_setup, updatecheck(off|on)  // 연결 시 새 버전 확인 + 연결 횟수 집계 끄기/켜기
*!
*! help DB (~32MB) 는 pkg 에 번들하지 않고 여기서 온디맨드로 받는다 —
*! net install 을 가볍게 유지하기 위함. 파일은 stata-drone.jar 옆에 둔다
*! (드론 HelpDb/HelpDbV2 의 첫 탐색 위치).

cap program drop mcp_setup
program mcp_setup
    version 17.0
    syntax [, UPDATEDB UPDATE UPDATECHECK(string)]

    local base "https://raw.githubusercontent.com/mhjung0822/stata-mcp/main/release"

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
        di as text "[Setup] 설치 완료 — {bf:Stata 를 재시작}한 뒤 mcp_connect 로 다시 연결하세요."
        exit
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

    * ─── updatecheck(off|on): 드론 jar 옆 stata_mcp.properties 의 UPDATE_CHECK 기록 ──
    * 드론(UpdateCheck)이 기동 시 같은 파일을 읽는다. 다른 줄은 보존 (mcp_watchdog 와 같은 방식).
    if `"`updatecheck'"' != "" {
        local v = lower(strtrim(`"`updatecheck'"'))
        if !inlist("`v'", "on", "off") {
            di as error "[Setup] updatecheck() 는 on 또는 off"
            exit 198
        }
        local props `"`jardir'stata_mcp.properties"'
        tempname in out
        tempfile tmp
        local wrote = 0
        quietly {
            file open `out' using `"`tmp'"', write text replace
            capture confirm file `"`props'"'
            if !_rc {
                file open `in' using `"`props'"', read text
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
    local ndl = 0
    local nskip = 0
    local nfail = 0
    foreach f of local files {
        local dest `"`jardir'`f'"'
        * updatedb 없고 이미 있으면 skip
        if "`updatedb'" == "" {
            capture confirm file `"`dest'"'
            if !_rc {
                di as text "  skip (있음): `f'"
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
    di as text "[Setup] help DB — 다운로드 `ndl', skip `nskip', 실패 `nfail'"
    if `nfail' > 0 {
        di as error "[Setup] 일부 실패 — 인터넷/방화벽 확인 후 'mcp_setup, updatedb' 로 재시도하세요."
    }

    * updatedb = help DB 갱신만 (다이얼로그 [Update help DB] 버튼) — 메뉴 등록/허브 생략
    if "`updatedb'" != "" {
        di as text "[Setup] help DB 갱신 완료."
        exit
    }

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
    di as text "{bf:[Stata-MCP] Setup}"
    di as text "  help DB 갱신:        {stata mcp_setup, updatedb:mcp_setup, updatedb}"
    di as text "  최신 버전 재설치:    {stata mcp_setup, update:mcp_setup, update}"
    di as text "  서버·드론 기동:      {stata mcp_connect:mcp_connect}"
    di as text "  제거:               {stata mcp_uninstall:mcp_uninstall}"
    di as text ""
end
