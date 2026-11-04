*! mcp_analysis_setup  v0.1.0  14oct2026
*!
*! 데이터에 저장된 분석 세팅 (char _dta[mcp_setup]) 보기 · JSON 내보내기 · 가져오기 · 지우기.
*! 세팅은 analysis 툴이 실행 확인 때 기록한다 ("k=v|k=v…"). 다음에 그 데이터로 분석을 시작하면
*! "저장된 세팅이 있습니다 — … 이대로 할까요?" 로 확인한다. 데이터 파일에 남기려면 save 가 필요하다.
*!
*!   mcp_analysis_setup show
*!   mcp_analysis_setup export using "setup.json" [, replace]
*!   mcp_analysis_setup import using "setup.json"
*!   mcp_analysis_setup clear
cap program drop mcp_analysis_setup
program mcp_analysis_setup
    version 17
    gettoken sub 0 : 0, parse(" ,")

    if "`sub'" == "show" {
        syntax
        local s : char _dta[mcp_setup]
        if `"`s'"' == "" {
            di as text "저장된 분석 세팅이 없습니다."
            exit
        }
        mata: _mcp_anset_show(st_global("_dta[mcp_setup]"))
    }
    else if "`sub'" == "export" {
        syntax using/ [, REPLACE]
        local s : char _dta[mcp_setup]
        if `"`s'"' == "" {
            di as error "저장된 분석 세팅이 없습니다."
            exit 198
        }
        if "`replace'" == "" {
            capture confirm new file `"`using'"'
            if _rc {
                di as error `"파일이 이미 있습니다: `using' (덮어쓰려면 replace)"'
                exit 602
            }
        }
        mata: _mcp_anset_export(st_global("_dta[mcp_setup]"), st_local("using"))
        di as text `"분석 세팅을 내보냈습니다: `using'"'
    }
    else if "`sub'" == "import" {
        syntax using/
        confirm file `"`using'"'
        mata: st_local("s", _mcp_anset_import(st_local("using")))
        if `"`s'"' == "" {
            di as error "JSON 에서 세팅 항목을 찾지 못했습니다."
            exit 198
        }
        char _dta[mcp_setup] `s'
        di as text "분석 세팅을 데이터에 넣었습니다. 다음 분석 시작 때 확인합니다 (파일에 남기려면 save)."
        mata: _mcp_anset_show(st_global("_dta[mcp_setup]"))
    }
    else if "`sub'" == "clear" {
        syntax
        char _dta[mcp_setup]
        di as text "저장된 분석 세팅을 지웠습니다."
    }
    else {
        di as error "mcp_analysis_setup: show | export using <file> [, replace] | import using <file> | clear"
        exit 198
    }
end

mata:
// "k=v|k=v" → 2열 (키, 값)
string matrix _mcp_anset_pairs(string scalar s)
{
    string rowvector parts
    string matrix out
    real scalar i, e
    parts = tokens(s, "|")
    out = J(0, 2, "")
    for (i = 1; i <= cols(parts); i++) {
        if (parts[i] == "|") continue
        e = strpos(parts[i], "=")
        if (e > 1) out = out \ (strtrim(substr(parts[i], 1, e - 1)), strtrim(substr(parts[i], e + 1, .)))
    }
    return(out)
}

void _mcp_anset_show(string scalar s)
{
    string matrix p
    real scalar i
    p = _mcp_anset_pairs(s)
    for (i = 1; i <= rows(p); i++) printf("{txt}%12s : {res}%s\n", p[i, 1], p[i, 2])
}

void _mcp_anset_export(string scalar s, string scalar fn)
{
    string matrix p
    real scalar i, fh
    p = _mcp_anset_pairs(s)
    if (fileexists(fn)) unlink(fn)
    fh = fopen(fn, "w")
    fput(fh, "{")
    for (i = 1; i <= rows(p); i++) {
        fput(fh, `"  ""' + p[i, 1] + `"": ""' + subinstr(subinstr(p[i, 2], "\", "\\"), `"""', `"\""') + `"""' + (i < rows(p) ? "," : ""))
    }
    fput(fh, "}")
    fclose(fh)
}

// 평평한 JSON 객체의 "키": 문자열·숫자·참거짓 값을 모두 "k=v|k=v" 로 — 어떤 키를 쓸지는 서버가 코퍼스(saved_keys)로 거른다
string scalar _mcp_anset_import(string scalar fn)
{
    string colvector lines
    string scalar txt, out, k, v, re
    lines = cat(fn)
    txt = invtokens(lines', " ")
    re = `""([A-Za-z_][A-Za-z0-9_.]*)"\s*:\s*("((?:[^"\\]|\\.)*)"|(-?[0-9.]+)|(true|false))"'
    out = ""
    while (ustrregexm(txt, re)) {
        k = ustrregexs(1)
        v = ustrregexs(3) != "" ? ustrregexs(3) : (ustrregexs(4) != "" ? ustrregexs(4) : ustrregexs(5))
        txt = usubstr(txt, ustrpos(txt, ustrregexs(0)) + ustrlen(ustrregexs(0)), .)
        if (v == "true")  v = "yes"
        if (v == "false") v = "no"
        v = subinstr(subinstr(v, `"\""', `"""'), "\\", "\")
        v = subinstr(v, "|", " ")
        if (strtrim(v) != "") out = out + (out == "" ? "" : "|") + k + "=" + strtrim(v)
    }
    return(out)
}
end
