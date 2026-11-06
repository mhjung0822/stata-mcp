cap program drop llm
program llm
    version 17.0

    // `syntax` 가 콤마를 옵션 시작으로 해석하기 때문에,
    // > 뒤의 명령에 vce(robust) 같은 옵션이 들어가면 unknown option 에러.
    // → syntax 호출 전에 > 위치를 먼저 분리하고, 앞부분에만 syntax 적용.
    local input `"`0'"'

    local has_cmd 0
    local cmd_str ""
    local pre `"`input'"'

    if strpos(`"`input'"', ">") > 0 {
        local has_cmd 1
        local cmd_str = strtrim(substr(`"`input'"', strpos(`"`input'"', ">") + 1, .))
        local pre     = strtrim(substr(`"`input'"', 1, strpos(`"`input'"', ">") - 1))
    }

    local 0 `"`pre'"'
    syntax [anything] [, R E KEEP CLEAR NOTE(string) REQuest(string)]

    if strtrim("`anything'") != "push" {
        di as error "Usage: llm push [, r e keep clear note(text) req(text)] [> command]"
        exit 198
    }

    local _clear_flag = cond("`clear'" != "", "1", "0")

    if `has_cmd' {
        // 1. 순수 명령어(base_cmd) 및 전체 명령어(cmd_str) 파싱
        local base_cmd "`cmd_str'"
        if regexm("`cmd_str'", "^(bysort|bys|by)[ ]+[^:]+:[ ]*(.*)") {
            local base_cmd = regexs(2)
        }
        // base_cmd에서 첫 단어만 추출
        local base_cmd = word("`base_cmd'", 1)

        // 2. 자바에게 인자(base_cmd, cmd_str, clear_flag, note, request)를 넘기며 실행 위임
        javacall com.stata_mcp.drone.StataMcpUtils executeAndPush, args("`base_cmd'" "`cmd_str'" "`_clear_flag'" `"`note'"' `"`request'"') jars(stata-drone.jar)
    }
    else {
        local _mcp_mode "both"
        if "`r'" != "" local _mcp_mode "r"
        if "`e'" != "" local _mcp_mode "e"

        local _mcp_cmd ""
        javacall com.stata_mcp.drone.StataMcpUtils pushReturnValues, args("`_clear_flag'" `"`note'"' `"`request'"') jars(stata-drone.jar)
    }

    if "`keep'" == "" {
        ereturn clear
    }

end
