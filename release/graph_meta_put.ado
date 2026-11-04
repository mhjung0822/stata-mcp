*! graph_meta_put v0.7.0  2026-04-30
*! Stata 그래프 객체 트리 → JSON 직렬화
*! Usage: graph_meta_put, name(<graph_name>) [frame(<work_frame>) spec_path(<file>)]
*! 결과:
*!   - spec_path() 주어지면 → Mata fopen/fput 으로 file 에 JSON dump (macro 한도 회피)
*!   - 생략 시 → $mcp_graph_spec global macro 에 set (작은 spec 빠른 path, ≤ 165 KB)
*! frame() 미지정 시 `_mcp_ss' 디폴트. Java 호출 시 `_mcp_ss_<rand>' 형태로
*! 매번 다르게 전달해 사용자 frame 이름 충돌을 회피.
*!
*! 안전장치 (v0.5.0):
*!     - file dump 모드에서 fopen 후 fh 를 Stata scalar `__mcp_spec_fh' 에 등록.
*!     - mata abort 시 program 측이 cap fclose 로 dangling fh 강제 close.

version 17.0


// ================================================================
// Mata struct + JSON 유틸 (ado 로드 시 실행)
// ================================================================

mata:

struct serset_meta {
    real   scalar    id, nobs, size
    string rowvector vars
}

struct legend_meta {
    string rowvector labels
    real   rowvector plot_map
}

struct plot_meta {
    real   scalar  serset_id
    string scalar  class_name
}

struct twoway_meta {
    real   scalar             n_plots
    struct plot_meta rowvector plots
}

struct over_group {
    string scalar    var
    real   rowvector levels
    string rowvector labels
}

struct graph_meta {
    string scalar    name, class_name, family, cmd, user_cmd, timestamp
    string scalar    title, subtitle, note
    string rowvector xtitles, ytitles
    struct legend_meta scalar legend_
    real   scalar              nss
    struct serset_meta rowvector sersets
    real   scalar    panel_n, panel_rows, panel_cols
    string rowvector panel_paths
    struct twoway_meta scalar twoway_
    real   scalar              n_over
    struct over_group rowvector over_groups
    real   scalar              nofill   // bar/hbar 의 nofill 옵션 (1=ON, 0=OFF)
}

// ---- JSON escape / primitive ----
string scalar _mcp_json_esc(string scalar s)
{
    string scalar bs
    bs = char(92)
    s = subinstr(s, bs,       bs + bs,     .)
    s = subinstr(s, char(34), bs + char(34), .)
    s = subinstr(s, char(10), bs + "n",    .)
    s = subinstr(s, char(13), bs + "r",    .)
    s = subinstr(s, char(9),  bs + "t",    .)
    return(s)
}

string scalar _mcp_json_q(string scalar s)
    return(`"""' + _mcp_json_esc(s) + `"""')

string scalar _mcp_json_num(real scalar x)
    return(missing(x) ? "null" : strofreal(x))

string scalar _mcp_json_arr_str(string rowvector v)
{
    string rowvector q
    real scalar i, n
    n = cols(v)
    if (n == 0) return("[]")
    q = J(1, n, "")
    for (i = 1; i <= n; i++) q[i] = _mcp_json_q(v[i])
    return("[" + invtokens(q, ",") + "]")
}

string scalar _mcp_json_arr_real(real rowvector v)
{
    string rowvector q
    real scalar i, n
    n = cols(v)
    if (n == 0) return("[]")
    q = J(1, n, "")
    for (i = 1; i <= n; i++) q[i] = _mcp_json_num(v[i])
    return("[" + invtokens(q, ",") + "]")
}

// ---- bar/hbar/box/hbox/dot single Y + over-only legend 보정 ----
// Stata 가 single-Y over-only 케이스에서 .legend.labels 를 over[0].labels 로 잘못 채움.
// over_groups[0].labels == legend.labels 이면 single-Y 케이스이므로 legend 를 비운다.
// (caller 가 family 가드 — pie 는 slice 라벨이 over[0].labels 라 정상, 제외)
// NOTE: Mata struct argument 는 by-value 라 함수 안 통째 교체 (legend_.labels = J(...))
//       caller 에 안 보임. 글로벌 _mcp_gm 을 직접 참조 (다른 mata helper 와 동일 패턴).
void _mcp_gm_fix_over_legend()
{
    external struct graph_meta scalar _mcp_gm
    real scalar nL, nO, i
    string rowvector og0, lbl
    nO = length(_mcp_gm.over_groups)
    nL = length(_mcp_gm.legend_.labels)
    if (nO == 0 | nL == 0) return
    og0 = _mcp_gm.over_groups[1].labels
    lbl = _mcp_gm.legend_.labels
    if (length(og0) != nL) return
    for (i = 1; i <= nL; i++) {
        if (og0[i] != lbl[i]) return
    }
    // 동일 → single-Y over-only 케이스. legend 비우기.
    _mcp_gm.legend_.labels   = J(1, 0, "")
    _mcp_gm.legend_.plot_map = J(1, 0, .)
}

// ---- serset 단일 채움 (frame 내부에서 호출) ----
void _mcp_gm_fill_serset(struct graph_meta scalar gm, real scalar idx, real scalar sid)
{
    real matrix V
    st_view(V, ., .)
    gm.sersets[idx].id   = sid
    gm.sersets[idx].nobs = rows(V)
    gm.sersets[idx].vars = st_varname(1..cols(V))
    gm.sersets[idx].size = rows(V) * cols(V) * 10
}

// ---- compound quote (`"..."') 벗기기 ----
string scalar _mcp_unwrap_cq(string scalar s)
{
    real scalar L
    L = strlen(s)
    if (L >= 4 & substr(s, 1, 2) == "`" + char(34) &
                 substr(s, L-1, 2) == char(34) + "'") {
        return(substr(s, 3, L - 4))
    }
    return(s)
}

// ---- k:"v" 형태 pair helper ----
string scalar _mcp_json_kv(string scalar key, string scalar val)
{
    string scalar q
    q = char(34)
    return(q + key + q + ":" + val)
}

// ---- twoway_meta → JSON ----
string scalar _mcp_twoway_to_json(struct twoway_meta scalar tw)
{
    string rowvector plot_items
    real scalar i
    if (tw.n_plots == 0) return("{" + _mcp_json_kv("n_plots", "0") + "," + _mcp_json_kv("plots", "[]") + "}")
    plot_items = J(1, tw.n_plots, "")
    for (i = 1; i <= tw.n_plots; i++) {
        plot_items[i] = "{" +
            _mcp_json_kv("serset_id",  _mcp_json_num(tw.plots[i].serset_id))    + "," +
            _mcp_json_kv("class_name", _mcp_json_q(tw.plots[i].class_name))     +
            "}"
    }
    return("{" +
        _mcp_json_kv("n_plots", _mcp_json_num(tw.n_plots)) + "," +
        _mcp_json_kv("plots", "[" + invtokens(plot_items, ",") + "]") +
        "}")
}

// ---- graph_meta → JSON ----
string scalar _mcp_gm_to_json(struct graph_meta scalar gm)
{
    string scalar out
    string rowvector ss_items, vs, lbls, og_items, og_labels
    real   rowvector pm, og_levels
    real   scalar i

    // sersets 배열 (struct 필드 local 복사 후 pass)
    if (gm.nss == 0) {
        ss_items = J(1, 0, "")
    }
    else {
        ss_items = J(1, gm.nss, "")
        for (i = 1; i <= gm.nss; i++) {
            vs = gm.sersets[i].vars
            ss_items[i] = "{"                                                         +
                _mcp_json_kv("id",   _mcp_json_num(gm.sersets[i].id))       + "," +
                _mcp_json_kv("nobs", _mcp_json_num(gm.sersets[i].nobs))     + "," +
                _mcp_json_kv("size", _mcp_json_num(gm.sersets[i].size))     + "," +
                _mcp_json_kv("vars", _mcp_json_arr_str(vs))                 +
                "}"
        }
    }

    // over_groups 배열 (box/hbox/bar/hbar/dot/pie 등)
    if (gm.n_over == 0) {
        og_items = J(1, 0, "")
    }
    else {
        og_items = J(1, gm.n_over, "")
        for (i = 1; i <= gm.n_over; i++) {
            og_levels = gm.over_groups[i].levels
            og_labels = gm.over_groups[i].labels
            og_items[i] = "{"                                                  +
                _mcp_json_kv("var",    _mcp_json_q(gm.over_groups[i].var))     + "," +
                _mcp_json_kv("levels", _mcp_json_arr_real(og_levels))          + "," +
                _mcp_json_kv("labels", _mcp_json_arr_str(og_labels))           +
                "}"
        }
    }

    lbls = gm.legend_.labels
    pm   = gm.legend_.plot_map

    out = "{"                                                           +
        _mcp_json_kv("indexing",   _mcp_json_q("1-based"))              + "," +
        _mcp_json_kv("name",       _mcp_json_q(gm.name))                + "," +
        _mcp_json_kv("class_name", _mcp_json_q(gm.class_name))          + "," +
        _mcp_json_kv("family",     _mcp_json_q(gm.family))              + "," +
        _mcp_json_kv("cmd",        _mcp_json_q(gm.cmd))                 + "," +
        _mcp_json_kv("user_cmd",   _mcp_json_q(gm.user_cmd))            + "," +
        _mcp_json_kv("timestamp",  _mcp_json_q(gm.timestamp))           + "," +
        _mcp_json_kv("title",      _mcp_json_q(gm.title))               + "," +
        _mcp_json_kv("subtitle",   _mcp_json_q(gm.subtitle))            + "," +
        _mcp_json_kv("note",       _mcp_json_q(gm.note))                + "," +
        _mcp_json_kv("xtitles",    _mcp_json_arr_str(gm.xtitles))       + "," +
        _mcp_json_kv("ytitles",    _mcp_json_arr_str(gm.ytitles))       + "," +
        _mcp_json_kv("legend",
            "{" +
            _mcp_json_kv("labels",   _mcp_json_arr_str(lbls))           + "," +
            _mcp_json_kv("plot_map", _mcp_json_arr_real(pm))            +
            "}"
        )                                                               + "," +
        _mcp_json_kv("panel_n",     _mcp_json_num(gm.panel_n))          + "," +
        _mcp_json_kv("panel_rows",  _mcp_json_num(gm.panel_rows))       + "," +
        _mcp_json_kv("panel_cols",  _mcp_json_num(gm.panel_cols))       + "," +
        _mcp_json_kv("panel_paths", _mcp_json_arr_str(gm.panel_paths))  + "," +
        _mcp_json_kv("twoway_",     _mcp_twoway_to_json(gm.twoway_))    + "," +
        _mcp_json_kv("over_groups", "[" + invtokens(og_items, ",") + "]") + "," +
        _mcp_json_kv("nofill",     _mcp_json_num(gm.nofill))            + "," +
        _mcp_json_kv("sersets", "[" + invtokens(ss_items, ",") + "]")   +
        "}"

    return(out)
}

// ---- spec → file dump (macro 한도 회피) ----
void _mcp_write_spec(string scalar fname, struct graph_meta scalar gm)
{
    real scalar fh
    // fopen("w") 는 존재 시 error 602 → 선제 unlink
    if (fileexists(fname)) unlink(fname)
    fh = fopen(fname, "w")
    st_numscalar("__mcp_spec_fh", fh)
    fput(fh, _mcp_gm_to_json(gm))
    fclose(fh)
    st_numscalar("__mcp_spec_fh", 0)
}

end


// ================================================================
// graph_meta_put — 메인
// ================================================================

program define graph_meta_put
    syntax , name(string) [Frame(string) Spec_path(string) User_cmd(string)]

    if "`frame'" == "" local frame "_mcp_ss"

    local gname `"`name'"'
    local gcmd  `"`.`name'.command'"'
    local gtime `"`.`name'.time'"'
    local gucmd `"`user_cmd'"'

    mata: _mcp_gm = graph_meta()
    mata: _mcp_gm.name      = _mcp_unwrap_cq(st_local("gname"))
    mata: _mcp_gm.cmd       = _mcp_unwrap_cq(st_local("gcmd"))
    mata: _mcp_gm.user_cmd  = _mcp_unwrap_cq(st_local("gucmd"))
    mata: _mcp_gm.timestamp = _mcp_unwrap_cq(st_local("gtime"))

    _graph_meta_family `name'
    local fam `r(family)'
    mata: _mcp_gm.family = st_local("fam")

    _graph_meta_class_by_family "`fam'"
    local cls `r(class)'
    mata: _mcp_gm.class_name = st_local("cls")

    _graph_meta_title       `name'
    _graph_meta_subtitle    `name'
    _graph_meta_note        `name'
    _graph_meta_axes        `name'
    _graph_meta_sersets     `name' "`frame'"
    _graph_meta_panels      `name' "`fam'"
    _graph_meta_twoway      `name' "`fam'"
    _graph_meta_over_groups `name' "`fam'"
    // legend 는 over_groups 뒤에서 처리 — over[0] 라벨로 잘못 dump 되는 케이스 보정 위해
    _graph_meta_legend      `name' "`fam'"

    // nofill 옵션 detect (bar/hbar/box/hbox/dot 류) — cmd 안 word boundary 검색
    local _has_nofill = 0
    if inlist("`fam'", "bar", "hbar", "box", "hbox", "dot") {
        if regexm(`"`gcmd'"', "(^|[ ,()])nofill([ ,()]|$)") local _has_nofill = 1
    }
    mata: _mcp_gm.nofill = `_has_nofill'

    // 직렬화 — spec_path 있으면 file, 없으면 macro
    if `"`spec_path'"' != "" {
        cap scalar drop __mcp_spec_fh
        cap noisily mata: _mcp_write_spec(`"`spec_path'"', _mcp_gm)
        local rc = _rc
        if `rc' {
            cap mata: if (st_numscalar("__mcp_spec_fh") != 0) fclose(st_numscalar("__mcp_spec_fh"))
            cap scalar drop __mcp_spec_fh
            cap mata: mata drop _mcp_gm
            error `rc'
        }
        cap scalar drop __mcp_spec_fh
    }
    else {
        mata: st_global("mcp_graph_spec", _mcp_gm_to_json(_mcp_gm))
    }

    // struct 인스턴스 제거 (정의 자체는 ado scope)
    cap mata: mata drop _mcp_gm
end


// ================================================================
// family 정규화
// ================================================================

program _graph_meta_family, rclass
    args name
    local raw `.`name'.graphfamily'
    if "`raw'" == "twoway" {
        local fam "twoway"
    }
    else if "`raw'" == "by" {
        local rx ""
        cap local rx `.`name'.rescale_x'
        if _rc == 0 & "`rx'" != ""  local fam "combine"
        else                         local fam "by"
    }
    else if "`raw'" == "matrix" local fam "matrix"
    else if "`raw'" == "forest" local fam "forest"
    else if "`raw'" == "bar" {
        local rad ""
        cap local rad `.`name'.radius'
        local is_pie 0
        if "`rad'" != "" & "`rad'" != "." {
            if real("`rad'") != . & real("`rad'") > 0 local is_pie 1
        }
        if `is_pie' {
            local fam "pie"
        }
        else {
            local bs 0
            cap local bs `.`name'.box_signal'
            if "`bs'" == "" | "`bs'" == "." local bs 0
            local ds 0
            cap local ds `.`name'.dot_signal'
            if "`ds'" == "" | "`ds'" == "." local ds 0
            local hs 0
            cap local hs `.`name'.horiz_signal'
            if "`hs'" == "" | "`hs'" == "." local hs 0
            if      `bs' == 1 & `hs' == 1  local fam "hbox"
            else if `bs' == 1              local fam "box"
            else if `ds' == 1              local fam "dot"
            else if `hs' == 1              local fam "hbar"
            else                           local fam "bar"
        }
    }
    else {
        local fam "`raw'"
    }
    return local family "`fam'"
end


// ================================================================
// family → class 이름 매핑
// ================================================================

program _graph_meta_class_by_family, rclass
    args fam
    if      "`fam'" == "twoway"   local cls "twowaygraph_g"
    else if "`fam'" == "by"       local cls "bygraph_g"
    else if "`fam'" == "combine"  local cls "combinegraph_g"
    else if "`fam'" == "matrix"   local cls "matrixgraph_g"
    else if "`fam'" == "forest"   local cls "fpgraph_g"
    else if "`fam'" == "pie"      local cls "piegraph_g"
    else if "`fam'" == "bar"      local cls "bargraph_g"
    else if "`fam'" == "hbar"     local cls "hbargraph_g"
    else if "`fam'" == "box"      local cls "boxgraph_g"
    else if "`fam'" == "hbox"     local cls "hboxgraph_g"
    else if "`fam'" == "dot"      local cls "dotchartgraph_g"
    else                          local cls ""
    return local class `cls'
end


// ================================================================
// title
// ================================================================

program _graph_meta_title
    args name
    local n 0
    cap local n `.`name'.title.text.arrnels'
    if _rc local n 0
    if "`n'" == "" local n 0
    local t ""
    forvalues i = 1/`n' {
        local line `"`.`name'.title.text[`i']'"'
        if `i' == 1 local t `"`line'"'
        else        local t `"`t'\n`line'"'
    }
    mata: _mcp_gm.title = _mcp_unwrap_cq(st_local("t"))
end


// ================================================================
// subtitle  (panel value label 등)
// ================================================================

program _graph_meta_subtitle
    args name
    local n 0
    cap local n `.`name'.subtitle.text.arrnels'
    if _rc local n 0
    if "`n'" == "" local n 0
    local t ""
    forvalues i = 1/`n' {
        local line `"`.`name'.subtitle.text[`i']'"'
        if `i' == 1 local t `"`line'"'
        else        local t `"`t'\n`line'"'
    }
    mata: _mcp_gm.subtitle = _mcp_unwrap_cq(st_local("t"))
end


// ================================================================
// note  (by/combine footer "Graphs by ..." 등)
// ================================================================

program _graph_meta_note
    args name
    local n 0
    cap local n `.`name'.note.text.arrnels'
    if _rc local n 0
    if "`n'" == "" local n 0
    local t ""
    forvalues i = 1/`n' {
        local line `"`.`name'.note.text[`i']'"'
        if `i' == 1 local t `"`line'"'
        else        local t `"`t'\n`line'"'
    }
    mata: _mcp_gm.note = _mcp_unwrap_cq(st_local("t"))
end


// ================================================================
// xtitles / ytitles
// ================================================================

program _graph_meta_axes
    args name
    mata: _mcp_gm.xtitles = J(1, 0, "")
    mata: _mcp_gm.ytitles = J(1, 0, "")
    forvalues i = 1/2 {
        // xaxis
        local hasx 0
        cap local hasx `.`name'.xaxis`i'.title.text.arrnels'
        if _rc | "`hasx'" == "" local hasx 0
        if `hasx' > 0 {
            local xt `"`.`name'.xaxis`i'.title.text[1]'"'
            mata: _mcp_gm.xtitles = (_mcp_gm.xtitles, _mcp_unwrap_cq(st_local("xt")))
        }
        // yaxis
        local hasy 0
        cap local hasy `.`name'.yaxis`i'.title.text.arrnels'
        if _rc | "`hasy'" == "" local hasy 0
        if `hasy' > 0 {
            local yt `"`.`name'.yaxis`i'.title.text[1]'"'
            mata: _mcp_gm.ytitles = (_mcp_gm.ytitles, _mcp_unwrap_cq(st_local("yt")))
        }
    }
end


// ================================================================
// legend (labels + plot_map)
// ================================================================

program _graph_meta_legend
    args name fam
    local n 0
    cap local n `.`name'.legend.labels.arrnels'
    if _rc local n 0
    if "`n'" == "" local n 0
    mata: _mcp_gm.legend_.labels = J(1, `n', "")
    forvalues i = 1/`n' {
        local lbl `"`.`name'.legend.labels[`i']'"'
        mata: _mcp_gm.legend_.labels[`i'] = _mcp_unwrap_cq(st_local("lbl"))
    }

    local nm 0
    cap local nm `.`name'.legend.map.arrnels'
    if _rc local nm 0
    if "`nm'" == "" local nm 0
    mata: _mcp_gm.legend_.plot_map = J(1, `nm', .)
    forvalues i = 1/`nm' {
        local m `.`name'.legend.map[`i']'
        if "`m'" == "" local m .
        mata: _mcp_gm.legend_.plot_map[`i'] = `m'
    }

    // 보정: bar/hbar/box/hbox/dot 의 single Y + over-only 케이스에서 Stata 가
    // .legend.labels 를 over[0].labels 로 잘못 채워넣는 경우 → legend 비움.
    // pie 는 slice 라벨로 over[0].labels 가 정상이므로 제외.
    if inlist("`fam'", "bar", "hbar", "box", "hbox", "dot") {
        mata: _mcp_gm_fix_over_legend()
    }
end


// ================================================================
// sersets (id, nobs, vars, size)
// ================================================================

program _graph_meta_sersets
    args name fname
    if "`fname'" == "" local fname "_mcp_ss"

    // 1) .<name>.sersets[] 등록 ID 수집 (기존 path).
    local nss 0
    cap local nss `.`name'.sersets.arrnels'
    if _rc local nss 0
    if "`nss'" == "" local nss 0

    local sid_list ""
    forvalues i = 1/`nss' {
        local sid `.`name'.sersets[`i'].id'
        local sid_list `sid_list' `sid'
    }

    // 2) plot iterate — .sersets[] 미등록 plot serset 보강 (mband / mspline 등 — Stata 가
    //    자체 computed data 의 serset 을 graph object .sersets[] 에 등록 안 함. plot 의
    //    `.serset.id` reference 로만 노출. plot.serset.id 직접 수집 → 누락 ID dedup append.).
    local np 0
    cap local np `.`name'.n_views'
    if _rc local np 0
    if "`np'" == "" local np 0
    forvalues j = 1/`np' {
        local psid .
        cap local psid `.`name'.plotregion1.plot`j'.serset.id'
        if !_rc & "`psid'" != "" & "`psid'" != "." {
            if !`: list psid in sid_list' {
                local sid_list `sid_list' `psid'
            }
        }
    }

    // 3) 통합 ID 목록으로 dump.
    local n_total : list sizeof sid_list
    mata: _mcp_gm.nss = `n_total'
    mata: _mcp_gm.sersets = J(1, `n_total', serset_meta())

    local i = 0
    foreach sid of local sid_list {
        local ++i
        cap frame drop `fname'
        cap frame create `fname'
        frame `fname' {
            serset `sid'
            qui serset use, clear
            mata: _mcp_gm_fill_serset(_mcp_gm, `i', `sid')
        }
    }
end


// ================================================================
// panels (by/combine 전용 — 하위 그래프 경로 수집)
// ================================================================

program _graph_meta_panels
    args name fam

    mata: _mcp_gm.panel_n     = 0
    mata: _mcp_gm.panel_rows  = 0
    mata: _mcp_gm.panel_cols  = 0
    mata: _mcp_gm.panel_paths = J(1, 0, "")

    if !inlist("`fam'", "by", "combine") exit 0

    local np 0
    cap local np `.`name'.n'
    if _rc | "`np'" == "" local np 0

    local rows 0
    cap local rows `.`name'.rows'
    if _rc | "`rows'" == "" local rows 0

    local cols 0
    cap local cols `.`name'.cols'
    if _rc | "`cols'" == "" local cols 0

    mata: _mcp_gm.panel_n    = `np'
    mata: _mcp_gm.panel_rows = `rows'
    mata: _mcp_gm.panel_cols = `cols'
    mata: _mcp_gm.panel_paths = J(1, `np', "")

    forvalues i = 1/`np' {
        local path "`name'.graphs[`i']"
        mata: _mcp_gm.panel_paths[`i'] = st_local("path")
    }
end


// ================================================================
// twoway plots (serset_id + class_name 필드 추론)
// ================================================================

program _graph_meta_twoway
    args name fam

    mata: _mcp_gm.twoway_.n_plots = 0
    mata: _mcp_gm.twoway_.plots   = J(1, 0, plot_meta())

    if "`fam'" != "twoway" exit 0

    local np 0
    cap local np `.`name'.n_views'
    if _rc | "`np'" == "" local np 0

    mata: _mcp_gm.twoway_.n_plots = `np'
    mata: _mcp_gm.twoway_.plots   = J(1, `np', plot_meta())

    forvalues j = 1/`np' {
        local sid .
        cap local sid `.`name'.plotregion1.plot`j'.serset.id'
        if _rc | "`sid'" == "" local sid .

        local zv ""
        cap local zv `.`name'.plotregion1.plot`j'.zvar'
        local x2 ""
        cap local x2 `.`name'.plotregion1.plot`j'.x2var'
        local y2 ""
        cap local y2 `.`name'.plotregion1.plot`j'.y2var'

        local cls "yxview"
        if "`zv'" != "" & "`zv'" != "." {
            if real("`zv'") != . local cls "zyx2view_g"
        }
        else if "`x2'" != "" & "`x2'" != "." {
            if real("`x2'") != . local cls "yxyxview_g"
        }
        else if "`y2'" != "" & "`y2'" != "." {
            if real("`y2'") != . local cls "y2xview_g"
        }

        mata: _mcp_gm.twoway_.plots[`j'].serset_id  = `sid'
        mata: _mcp_gm.twoway_.plots[`j'].class_name = "`cls'"
    }
end


// ================================================================
// over_groups (box/hbox/bar/hbar/dot/pie — over() 변수의 value labels)
// ================================================================

program _graph_meta_over_groups
    args name fam

    // 초기화 — 비대상 family 면 빈 배열로 두고 종료
    mata: _mcp_gm.n_over = 0
    mata: _mcp_gm.over_groups = J(1, 0, over_group())

    if !inlist("`fam'", "box", "hbox", "bar", "hbar", "dot", "pie") exit

    // cmd 에서 over(...) 변수 모두 추출
    local cmd `"`.`name'.command'"'
    local rest `"`cmd'"'
    local overs ""
    while strpos(`"`rest'"', "over(") > 0 {
        local pos = strpos(`"`rest'"', "over(")
        local rest = substr(`"`rest'"', `pos' + 5, .)
        local end = strpos(`"`rest'"', ")")
        if `end' == 0 continue, break
        local seg = substr(`"`rest'"', 1, `end' - 1)
        // strip option after comma
        local pcomma = strpos("`seg'", ",")
        if `pcomma' > 0 local seg = substr("`seg'", 1, `pcomma' - 1)
        local v = strtrim("`seg'")
        local overs `"`overs' `v'"'
        local rest = substr(`"`rest'"', `end' + 1, .)
    }

    // 유효 over 필터 (변수 존재 + 레벨 존재) — 사전 카운트 후 한 번에 할당
    // (struct rowvector 는 (x, y) concat 이 transmorphic 만 받아 incremental 확장 불가)
    local valid ""
    foreach v of local overs {
        cap confirm variable `v'
        if _rc continue
        cap levelsof `v', local(_l)
        if _rc continue
        local nL : word count `_l'
        if `nL' == 0 continue
        local valid `"`valid' `v'"'
    }

    local n : word count `valid'
    if `n' == 0 exit

    mata: _mcp_gm.n_over = `n'
    mata: _mcp_gm.over_groups = J(1, `n', over_group())

    local idx 0
    foreach v of local valid {
        local ++idx
        levelsof `v', local(L)
        local nL : word count `L'
        mata: _mcp_gm.over_groups[`idx'].var    = "`v'"
        mata: _mcp_gm.over_groups[`idx'].levels = J(1, `nL', .)
        mata: _mcp_gm.over_groups[`idx'].labels = J(1, `nL', "")

        // string variable 인 경우 levels 는 ordinal index, labels 는 string 값.
        // (numeric variable 은 levels = 실제 값, labels = value label 또는 숫자)
        cap confirm string variable `v'
        local _is_str = !_rc

        local k 0
        foreach lev of local L {
            local ++k
            if `_is_str' {
                // string over_var: levels = ordinal index (k), labels = string 값
                // st_local 사용 — macro substitution 시 compound quote 가 strip 되어
                // bare name 으로 인식 ('Australia not found' 회피).
                mata: _mcp_gm.over_groups[`idx'].levels[`k'] = `k'
                mata: _mcp_gm.over_groups[`idx'].labels[`k'] = st_local("lev")
            }
            else {
                local lbl : label (`v') `lev'
                mata: _mcp_gm.over_groups[`idx'].levels[`k'] = `lev'
                mata: _mcp_gm.over_groups[`idx'].labels[`k'] = st_local("lbl")
            }
        }
    }
end
