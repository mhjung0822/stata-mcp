*! mcp_proc  v0.1.0  13oct2026
*!
*! Stata MCP 분석 세팅·절차의 판정 라이브러리 (서버 analysis 툴 전용).
*! 데이터는 st_view/st_data 로 읽기만 한다 — 변수·frame 을 만들지 않고 결과는 r() 로만.
*! 분석 표본 = vars() 의 변수가 모두 비결측인 행 (st_view selectvar 0, 시차 표기 허용).
*!
*!   mcp_proc sample, vars(<y x>)                r(N) 분석 표본 · r(N_all) 전체 · r(excluded) 결측 제외
*!   mcp_proc singleton <id>, vars(<y x>)        r(N) · r(n_g) 개체 수 · r(n_s) 관측 1회 개체 수 · r(pct_g) n_s/n_g×100 · gen(v) 표본의 singleton 관측 = 1
*!   mcp_proc timeinv <id>, x(<v>) vars(<y x>)   r(sd_w) 1×k (xtsum 과 같은 within SD) · r(timeinv) 개체 안 값이 하나뿐인 변수 (값 비교) · r(xnames)·r(sdw) 보고서 표용 (x 순서, 공백 구분)
*!   mcp_proc utest <id>, y(<y>) x(<x>) [means(<시변 x>)]  r(z) r(p) Wooldridge 개체효과 검정 · r(lm) r(p_lm) BP LM · r(N) r(n_g)
*!   mcp_proc secmp <A> <B>, alpha(#) [exclude(<v>)]  r(maxpct) r(maxpct_txt) r(maxvar) SE 최대 변화 · r(nflip) r(flip) α 기준 유의성이 바뀐 계수 (exclude 변수의 계수 — 시간 더미·TIC — 는 판정에서 뺌)
*!                                               · 추정값이 있는 계수(기준 범주·omitted 제외, _cons 포함) 순서대로 공백 목록 r(names) r(b) r(se1) r(se2) r(p1) r(p2)
*!                                               · r(N1) r(N2) 관측치 · r(G1) r(G2) 군집 수
*!   mcp_proc fvbase, x(<x>)                    r(n) · r(var#) r(lab#) 범주형의 "라벨 (ref. 기준 범주)"
*!   mcp_proc isint, x(<v>) vars(<y x>)          r(isint) 표본에서 값이 전부 정수인 변수
*!   mcp_proc nlev, x(<v>) vars(<y x>)           x 와 같은 순서로 r(nlev) 표본에서 서로 다른 값 수 · r(int) 값이 전부 정수면 1
*!   mcp_proc dupkey <id> <time>                 r(n_dup) id × time 중복 관측치 수 (문자열 id 허용) · r(N) 키 비결측 관측치 · r(examples) 중복 키 예시 (최대 3, "id × time (k행)")
*!   mcp_proc paneldiag <id> [<time>]            전체 자료 (키 비결측): r(N) r(n_g) 개체 수 · r(Ti_min) r(Ti_max) r(Ti_med) 개체당 관측 횟수
*!                                               · r(n_t) 시점 수 · r(tmin) r(tmax) · r(tdelta) 시점 간 최소 간격 · r(span) 범위 안 시점 수 · r(n_gap) 중간에 빠진 시점이 있는 개체 수
*!   mcp_proc xcheck <id>, x(<v>) vars(<y x>) [time(<t>)]  분석 표본: x 순서 r(nlev) 값 수 · r(isint) 정수값만(1/0) · r(vmin)·r(vmax) 범위 · r(single) 값이 하나뿐인 x · r(tover) 개체 안에서 x − time 이 일정한 x
*!                                               · r(nt) 표본의 시점 수 · r(nt1) nt − 1 · r(balanced) 모든 개체의 관측 횟수가 같고(time 이 있으면 = nt) 1
*!   mcp_proc wcb <est>, [exclude(<v>) alpha(#) rseed(#) reps(#)]
*!                                               저장 추정 <est>(xtreg, fe · regress)를 wild cluster bootstrap(Stata wildbootstrap)으로 다시 검정 — 결과창에 그 출력
*!                                               대상 = 기준·omitted·_cons·exclude 변수(시간 더미·TIC)를 뺀 계수. 결과: x 순서 공백 목록 r(names) r(b) r(pcl) cluster-robust p
*!                                               r(pwb) WCB p r(ll) r(ul) WCB CI · r(cll) r(cul) cluster-robust CI (b ± t(df)·se, 1 − α)
*!                                               · r(maxpct) r(maxpct_txt) r(maxvar) WCB 구간 폭 ÷ cluster-robust 구간 폭 − 1 (%, 절댓값이 가장 큰 것)
*!                                               · r(nflip) r(flip) α 기준 유의성이 바뀐 계수 "x (p a → b)" · r(cmd) 실행한 명령
*!   mcp_proc numstr <strvar>                    r(numeric) 비어 있지 않은 값이 모두 숫자면 1 · r(n_bad) 숫자가 아닌 값의 관측치 수 · r(examples) 그런 값 예시 (최대 3)
*!                                               · r(collide) 숫자로 바꾸면 서로 다른 값이 같아짐(앞자리 0 등) 1
*!   mcp_proc panelcand                          r(cands) "id time;id time;…" id × time 이 유일한 후보 쌍 (최대 3)
*!   mcp_proc files [, dir()]                     작업 폴더의 .dta 목록(*_long.dta 제외): r(n) r(files ;) r(Ns) r(ks) r(labels ;) r(nums) 파일명 숫자 · r(stub) r(target) r(exists)
*!   mcp_proc varcmp, files() [waves() dir()]     파일 간 변수 이름 대조(panel_build): r(waves) r(wavesrc) r(waves_ok) · 규칙 r(rule_a) r(rule_b)(자릿수, 0 = 안 씀) · r(baseline) r(match_a) r(match_b) r(match)
*!                                               · r(nstrip) r(prefixes) r(other_n) r(other_list) r(other_total) r(flags "w01>wflag") r(invariant) r(collide) r(idcands "stem:n1,n2;…") r(typeconf) r(n_common) r(stop) r(example)
*!   mcp_proc idcheck, files() cands()            ID 후보 유일성(열만 불러 isid): r(unique) r(types) r(nonunique)
*!   mcp_proc datainfo                           r(filename) c(filename) · r(setup) 저장된 세팅(char _dta[mcp_setup]) · r(changed) · r(svy) svyset 표시(char _dta[_svy_version])
cap program drop mcp_proc
program mcp_proc, rclass
    version 19
    gettoken sub 0 : 0, parse(" ,")
    if "`sub'" == "sample" {
        syntax , VARS(varlist numeric ts)
        mata: _mcp_proc_sample("`vars'")
        return scalar N        = `N'
        return scalar N_all    = `N_all'
        return scalar excluded = `N_all' - `N'
    }
    else if "`sub'" == "singleton" {
        syntax varname, VARS(varlist numeric ts) [GEN(name)]
        mata: _mcp_proc_singleton("`varlist'", "`vars'")
        if "`gen'" != "" {                                  // 표본에서 관측 1회뿐인 개체의 관측 = 1 (민감도 추정용)
            confirm new variable `gen'
            tempvar touse cnt
            mark `touse'
            markout `touse' `vars'
            quietly egen long `cnt' = total(`touse'), by(`varlist')
            quietly gen byte `gen' = `touse' & `cnt' == 1
        }
        local pct = cond(`n_g' > 0, 100 * `n_s' / `n_g', 0)
        display as text _n "Singletons (panels observed once in the sample)"
        display as text "    N = " as result %12.0fc `N' as text "    panels = " as result %9.0fc `n_g' ///
            as text "    singletons = " as result %9.0fc `n_s' as text " (" as result %4.1f `pct' as text "% of panels)"
        return scalar N   = `N'
        return scalar n_g = `n_g'
        return scalar n_s = `n_s'
        return scalar pct_g = `pct'
    }
    else if "`sub'" == "timeinv" {
        syntax varname, X(varlist numeric) VARS(varlist numeric ts)
        tempname sdw
        mata: _mcp_proc_timeinv("`varlist'", "`x'", "`vars'", "`sdw'")
        return matrix sd_w = `sdw'
        return local timeinv "`timeinv'"
        return local sdw "`sdwlist'"
        return local xnames "`x'"
    }
    else if "`sub'" == "utest" {                            // 개체효과 검정 — Pooled OLS 잔차 (Wooldridge 2010 10.4.4 · BP LM)
        syntax varname, Y(varname numeric ts) [X(string) MEANS(varlist numeric ts)]
        tempname hold
        tempvar touse e
        _estimates hold `hold', nullok restore              // 사용자 e() 보존
        quietly regress `y' `x'
        quietly gen byte `touse' = e(sample)
        local mx ""
        foreach v of local means {                          // CRE 기준: 시변 설명변수의 개체 평균 (표본 안)
            tempvar m
            quietly egen double `m' = mean(`v') if `touse', by(`varlist')
            local mx `mx' `m'
        }
        if "`mx'" != "" quietly regress `y' `x' `mx' if `touse'
        quietly predict double `e' if e(sample), residuals
        mata: _mcp_proc_utest("`varlist'", "`e'")
        display as text _n "Wooldridge test for unobserved effects (Wooldridge 2010, 10.4.4)"
        display as text "H0: no unobserved effect (Var(u_i) = 0)"
        display as text "    z = " as result %8.2f `z' as text "    p (one-sided) = " as result %6.4f 1 - normal(`z') ///
            as text "    N = " as result %9.0fc `N' as text "    panels = " as result %9.0fc `n_g'
        return scalar N    = `N'
        return scalar n_g  = `n_g'
        return scalar z    = `z'
        return scalar p    = 1 - normal(`z')
        return scalar lm   = `lm'
        return scalar p_lm = cond(`lm' > 0, chi2tail(1, `lm') / 2, 1)
    }
    else if "`sub'" == "secmp" {                            // 두 저장 추정의 SE 변화·유의성 변화 (singleton 민감도)
        syntax namelist(min=2 max=2) [, Alpha(real 0.05) EXclude(string)]
        gettoken a b : namelist
        tempname hold b1 v1 b2 v2
        _estimates hold `hold', nullok restore
        quietly estimates restore `a'
        matrix `b1' = e(b)
        matrix `v1' = e(V)
        local df1 = cond(missing(e(df_r)), 0, e(df_r))
        local N1 = e(N)
        local G1 = e(N_clust)
        quietly estimates restore `b'
        matrix `b2' = e(b)
        matrix `v2' = e(V)
        local df2 = cond(missing(e(df_r)), 0, e(df_r))
        local N2 = e(N)
        local G2 = e(N_clust)
        local skip ""                                       // exclude 변수(시간 더미·TIC)의 계수 — 표 목록엔 두고 최대 변화·유의성 변화 판정에선 뺌 (wcb 와 같은 기준)
        if "`exclude'" != "" {
            local cols : colfullnames `b1'
            foreach c of local cols {
                if "`c'" == "_cons" continue
                _ms_parse_parts `c'
                if `: list posof "`r(name)'" in exclude' local skip `skip' `c'
            }
        }
        mata: _mcp_proc_secmp("`b1'", "`v1'", "`b2'", "`v2'", `df1', `df2', `alpha', "`skip'")
        foreach s in names b se1 se2 p1 p2 {
            return local `s' "``s''"
        }
        foreach s in N1 N2 G1 G2 {
            return scalar `s' = ``s''
        }
        return scalar maxpct = `maxpct'
        return local maxpct_txt "`maxpct_txt'"
        return local maxvar "`maxvar'"
        return scalar nflip = `nflip'
        return local flip `"`flip'"'
    }
    else if "`sub'" == "fvbase" {                           // 범주형 설명변수의 기준 범주 → "라벨 (ref. 기준)"
        syntax , X(string)
        local n 0
        foreach t of local x {
            if strpos("`t'", "#") continue
            if !regexm("`t'", "^(i|ib[^.]*)[.]([A-Za-z_][A-Za-z0-9_]*)$") continue
            local v = regexs(2)
            quietly fvexpand `t'
            local base ""
            foreach e in `r(varlist)' {
                if regexm("`e'", "^([0-9]+)bn?[.]") local base = regexs(1)
            }
            if "`base'" == "" continue
            local bl : label (`v') `base'
            local lab : variable label `v'
            if `"`lab'"' == "" local lab `v'
            local ++n
            local var`n' `v'
            local lab`n' `"`lab' (ref. `bl')"'
        }
        forvalues j = 1/`n' {
            return local var`j' `var`j''
            return local lab`j' `"`lab`j''"'
        }
        return scalar n = `n'
    }
    else if "`sub'" == "isint" {
        syntax , X(varlist numeric) VARS(varlist numeric ts)
        mata: _mcp_proc_isint("`x'", "`vars'")
        return local isint "`isint'"
    }
    else if "`sub'" == "nlev" {
        syntax , X(varlist numeric) VARS(varlist numeric ts)
        mata: _mcp_proc_nlev("`x'", "`vars'")
        return local nlev "`nlev'"
        return local int  "`int'"
    }
    else if "`sub'" == "dupkey" {
        syntax varlist(min=2 max=2)
        gettoken id time : varlist
        confirm numeric variable `time'
        mata: _mcp_proc_dupkey("`id'", strtrim("`time'"))
        return scalar N     = `N'
        return scalar n_dup = `n_dup'
        return local examples `"`examples'"'
    }
    else if "`sub'" == "paneldiag" {                        // 패널 진단 — 선언 직후, 전체 자료 (판정만, 문장 없음)
        syntax varlist(min=1 max=2 numeric)
        gettoken id time : varlist
        mata: _mcp_proc_paneldiag("`id'", strtrim("`time'"))
        foreach s in N n_g Ti_min Ti_max Ti_med n_t tmin tmax tdelta span n_gap {
            return scalar `s' = ``s''
        }
    }
    else if "`sub'" == "xcheck" {                           // 변수 진단 — 분석 표본
        syntax varname(numeric), X(varlist numeric) VARS(varlist numeric ts) [TIME(varname numeric)]
        mata: _mcp_proc_xcheck("`varlist'", "`time'", "`x'", "`vars'")
        return local nlev   "`nlev'"
        return local isint  "`isint'"
        return local vmin   "`vmin'"
        return local vmax   "`vmax'"
        return local single "`single'"
        return local tover  "`tover'"
        return scalar nt       = `nt'
        return scalar nt1      = `nt1'
        return scalar balanced = `balanced'
    }
    else if "`sub'" == "wcb" {                              // FE 의 wild cluster bootstrap 민감도 (cluster 수가 적을 때)
        syntax name(name=est), [EXclude(string) Alpha(real 0.05) RSEED(string) REPS(integer 1000)]
        quietly estimates restore `est'
        local cmdline `"`e(cmdline)'"'
        tempname b V
        matrix `b' = e(b)
        matrix `V' = e(V)
        local df = cond(missing(e(df_r)), 0, e(df_r))
        local coefs ""
        local cols : colfullnames `b'
        foreach c of local cols {
            if "`c'" == "_cons" continue
            _ms_parse_parts `c'
            if r(omit) continue
            if !inlist("`r(type)'", "variable", "factor") continue
            if "`r(type)'" == "factor" & "`r(base)'" == "1" continue
            if `: list posof "`r(name)'" in exclude' continue
            local coefs `coefs' `c'
        }
        if "`coefs'" == "" {
            di as error "mcp_proc wcb: no coefficients to test"
            exit 198
        }
        local spec = ustrregexra(`"`cmdline'"', "\s*vce\([^)]*\)", "")
        if !strpos(`"`spec'"', ",") local spec `"`spec',"'
        local level = 100 * (1 - `alpha')
        local cmd `"wildbootstrap `spec' coefficients(`coefs') rseed(`rseed') reps(`reps') level(`level')"'
        `cmd'
        mata: _mcp_proc_wcb("`b'", "`V'", `df', `alpha')
        foreach s in names b pcl pwb ll ul cll cul {
            return local `s' "``s''"
        }
        return scalar maxpct = `maxpct'
        return local maxpct_txt "`maxpct_txt'"
        return local maxvar "`maxvar'"
        return scalar nflip = `nflip'
        return local flip `"`flip'"'
        return local cmd `"`cmd'"'
    }
    else if "`sub'" == "numstr" {                           // 문자열 변수를 숫자로 바꿀 수 있나 (destring 전 검사)
        syntax varname(string)
        mata: _mcp_proc_numstr("`varlist'")
        return scalar numeric = `numeric'
        return scalar n_bad   = `n_bad'
        return scalar collide = `collide'
        return local examples `"`examples'"'
    }
    else if "`sub'" == "panelcand" {
        syntax
        mata: _mcp_proc_panelcand()
        return local cands "`cands'"
    }
    else if "`sub'" == "datainfo" {
        syntax
        return local filename `"`c(filename)'"'
        return local setup `"`: char _dta[mcp_setup]'"'
        return scalar changed = c(changed)
        return local svy `"`: char _dta[_svy_version]'"'
    }
    else if "`sub'" == "files" {
        * 작업 폴더의 .dta 목록 — 파일은 열지 않고(describe using) 라벨만 첫 행 하나로 읽음. *_long.dta · *_long_N.dta(이 절차의 결과 파일)는 뺌.
        syntax [, DIR(string)]
        if `"`dir'"' == "" local dir `"`c(pwd)'"'
        local fl : dir `"`dir'"' files "*.dta", respectcase
        local fl : list sort fl
        local n 0
        local files
        local Ns
        local ks
        local labels
        local nums
        local stems
        tempname fr
        local cf = c(frame)
        foreach f of local fl {
            if regexm(`"`f'"', "_long(_[0-9]+)?\.dta$") continue
            local ++n
            capture describe using `"`dir'/`f'"', short
            local N = cond(_rc, ., r(N))
            local k = cond(_rc, ., r(k))
            local lab ""
            capture frame drop `fr'
            frame create `fr'
            capture frame `fr': use `"`dir'/`f'"' in 1/1, clear
            if !_rc {
                frame `fr': local lab : data label
            }
            frame change `cf'
            frame drop `fr'
            local stem = regexr(`"`f'"', "\.dta$", "")
            local stems `"`stems';`stem'"'
            local num "."
            local s `"`stem'"'
            while regexm(`"`s'"', "([0-9]+)") {
                local run = regexs(1)
                if strlen("`run'") <= 2 local num "`run'"
                local s = regexr(`"`s'"', "[0-9]+", " ")
            }
            local files `"`files';`f'"'
            local Ns "`Ns' `N'"
            local ks "`ks' `k'"
            local labels `"`labels';`lab'"'
            local nums "`nums' `num'"
        }
        local files = substr(`"`files'"', 2, .)
        local labels = substr(`"`labels'"', 2, .)
        local stems = substr(`"`stems'"', 2, .)
        mata: st_local("stub", _mcp_proc_prefix(st_local("stems")))
        local stub = regexr("`stub'", "[_-]*[wW]?[0-9]*[_-]*$", "")
        if "`stub'" == "" {
            mata: st_local("stub", pathbasename(st_local("dir")))
        }
        local target `"`dir'/`stub'_long.dta"'
        capture confirm file `"`target'"'
        return scalar exists = (_rc == 0)
        return scalar nums_ok = (`n' > 0 & !strpos(" `nums' ", " . "))
        return scalar n = `n'
        return local dir `"`dir'"'
        return local files `"`files'"'
        return local Ns "`Ns'"
        return local ks "`ks'"
        return local labels `"`labels'"'
        return local nums "`nums'"
        return local stub "`stub'"
        return local target `"`target'"'
    }
    else if "`sub'" == "varcmp" {
        * 파일 간 변수 이름 대조 — 차수 표식 판정(숫자만 벗김) · 다른 차수 변수 · 표식만 남는 이름 · 시불변 · ID 후보 · 형식 충돌.
        * files(): 파일 이름(따옴표 목록) · waves(): 파일 순서대로 차수 번호(비우면 변수 이름의 공통 숫자로 찾음)
        syntax , [FILES(string asis) LIST(string) WAVES(string) DIR(string)]
        if `"`dir'"' == "" local dir `"`c(pwd)'"'
        if `"`list'"' != "" {
            local files
            local rest `"`list'"'
            while `"`rest'"' != "" {
                gettoken one rest : rest, parse(";")
                if `"`one'"' != ";" local files `"`files' `"`one'"'"'
            }
        }
        mata: _mcp_vc_init()
        local i 0
        tempname fr
        local cf = c(frame)
        foreach f in `files' {
            local ++i
            capture frame drop `fr'
            frame create `fr'
            capture frame `fr': use `"`dir'/`f'"' in 1/1, clear
            if _rc {
                local rc = _rc
                frame change `cf'
                frame drop `fr'
                mata: _mcp_vc_clear()
                di as error `"mcp_proc varcmp: cannot open `f'"'
                exit `rc'
            }
            frame change `fr'
            mata: _mcp_vc_collect(`i')
            frame change `cf'
            frame drop `fr'
        }
        mata: _mcp_vc_run("`waves'")
        mata: _mcp_vc_clear()
        local specs                                // 파일 순서대로 "차수|파일" — 차수는 변수 토큰과 같은 꼴(두 자리 채움). 준 번호(1)와 변수 토큰(01)이 어긋나지 않게
        local i 0
        foreach f in `files' {
            local ++i
            local wi : word `i' of `waves_out'
            local specs `"`specs' `"`wi'|`f'"'"'
        }
        return local specs `"`specs'"'
        return scalar n_files = `i'
        return local waves "`waves_out'"
        return local wavesrc "`wavesrc'"
        return scalar waves_ok = `waves_ok'
        return scalar rule_a = `rule_a'
        return scalar rule_b = `rule_b'
        return scalar baseline = `baseline'
        return scalar match_a = `match_a'
        return scalar match_b = `match_b'
        return scalar match = `match'
        return scalar nnames = `nnames'
        return local nstrip "`nstrip'"
        return local prefixes "`prefixes'"
        return local other_n "`other_n'"
        return local other_list "`other_list'"
        return scalar other_total = `other_total'
        return local flags "`flags'"
        return local invariant "`invariant'"
        return local collide "`collide'"
        return local idcands "`idcands'"
        return local typeconf "`typeconf'"
        return scalar n_typeconf = `n_typeconf'
        return scalar n_common = `n_common'
        return local stop "`stop'"
        return local example "`example'"
    }
    else if "`sub'" == "idcheck" {
        * ID 후보의 유일성 — 후보 열만 파일마다 불러 isid. cands(): "stem:name1,name2,…;…" (varcmp r(idcands))
        syntax , [FILES(string asis) LIST(string) CANDS(string) DIR(string)]
        if `"`dir'"' == "" local dir `"`c(pwd)'"'
        if `"`list'"' != "" {
            local files
            local rest `"`list'"'
            while `"`rest'"' != "" {
                gettoken one rest : rest, parse(";")
                if `"`one'"' != ";" local files `"`files' `"`one'"'"'
            }
        }
        local unique
        local nonunique
        local types
        tempname fr
        local cf = c(frame)
        local ncand : word count `: subinstr local cands ";" " ", all'
        tokenize `"`: subinstr local cands ";" " ", all'"'
        forvalues c = 1/`ncand' {
            local spec ``c''
            gettoken stem names : spec, parse(":")
            local names = subinstr(substr("`names'", 2, .), ",", " ", .)
            local ok 1
            local ty ""
            local i 0
            foreach f in `files' {
                local ++i
                local v : word `i' of `names'
                if "`v'" == "" {
                    local ok 0
                    continue, break
                }
                capture frame drop `fr'
                frame create `fr'
                capture frame `fr': use `v' using `"`dir'/`f'"', clear
                if _rc {
                    local ok 0
                }
                else {
                    frame `fr': capture isid `v'
                    if _rc local ok 0
                    frame `fr': local ty : type `v'
                }
                frame change `cf'
                frame drop `fr'
                if !`ok' continue, break
            }
            if `ok' {
                local unique "`unique' `stem'"
                local types "`types' `ty'"
            }
            else local nonunique "`nonunique' `stem'"
        }
        return local unique "`unique'"
        return scalar n_unique = `: word count `unique''
        return local types "`types'"
        return local nonunique "`nonunique'"
    }
    else {
        di as error "mcp_proc: unknown subcommand `sub'"
        exit 198
    }
end

mata:
void _mcp_proc_sample(string scalar vars)
{
    real matrix V
    st_view(V=., ., tokens(vars), 0)
    st_local("N",     strofreal(rows(V), "%20.0f"))
    st_local("N_all", strofreal(st_nobs(), "%20.0f"))
}

// 표본 뷰: id + vars 를 한 뷰로 잡고 결측 행 제외 (복사 없음)
void _mcp_proc_singleton(string scalar id, string scalar vars)
{
    real matrix V, I, f
    st_view(V=., ., (id, tokens(vars)), 0)
    st_subview(I=., V, ., 1)
    f = uniqrows(I, 1)
    st_local("N",   strofreal(rows(I), "%20.0f"))
    st_local("n_g", strofreal(rows(f), "%20.0f"))
    st_local("n_s", strofreal(sum(f[., 2] :== 1), "%20.0f"))
}

void _mcp_proc_timeinv(string scalar id, string scalar x, string scalar vars, string scalar mname)
{
    real matrix V, I, X, p, info, mi, sdw, W
    real scalar k, j
    string rowvector xs
    string scalar ti
    xs = tokens(x)
    k  = cols(xs)
    st_view(V=., ., (id, xs, tokens(vars)), 0)
    st_subview(I=., V, ., 1)
    st_subview(X=., V, ., (2..k + 1))
    p = order(I, 1)
    info = panelsetup(I[p], 1)
    sdw = J(1, k, .)
    ti = ""
    for (j = 1; j <= k; j++) {
        // xtsum within = x_it - x̄_i + x̄ , 분모 N-1
        mi  = panelsum(X[p, j], info) :/ (info[., 2] - info[., 1] :+ 1)
        W   = X[p, j] - mi[_mcp_proc_expand(info)] :+ mean(X[., j])
        sdw[j] = sqrt(variance(W))
        // 판정은 값 비교로 — 개체 안 모든 값이 그 개체 첫 값과 같으면 시불변
        // (within SD 는 실수형 변수에서 반올림 오차로 0 이 안 될 수 있음: 8e-17)
        if (all(X[p, j] :== X[p, j][info[., 1]][_mcp_proc_expand(info)])) ti = ti + " " + xs[j]
    }
    st_matrix(mname, sdw)
    st_matrixcolstripe(mname, (J(k, 1, ""), xs'))
    st_local("timeinv", strtrim(ti))
    st_local("sdwlist", invtokens(strofreal(sdw, "%21.0g")))
}

// 개체효과 검정: e = Pooled OLS 잔차
//   Wooldridge (2010, 10.4.4) z = Σᵢ Σ_{t<s} eᵢₜeᵢₛ / sqrt(Σᵢ (Σ_{t<s} eᵢₜeᵢₛ)²) ~ N(0,1), 한쪽
//   Breusch–Pagan LM (불균형: Baltagi–Li 1990) = (Σᵢ(Σₜeᵢₜ)² / Σe² − 1)² · (ΣTᵢ)² / (2(ΣTᵢ² − ΣTᵢ)) ~ χ̄²(01)
void _mcp_proc_utest(string scalar id, string scalar e)
{
    real matrix V, info
    real colvector p, s, q, T, a
    st_view(V=., ., (id, e), 0)
    p    = order(V[., 1], 1)
    info = panelsetup(V[p, 1], 1)
    s = panelsum(V[p, 2], info)
    q = panelsum(V[p, 2]:^2, info)
    T = info[., 2] - info[., 1] :+ 1
    a = (s:^2 - q) / 2
    st_local("z",   strofreal(sum(a) / sqrt(sum(a:^2)), "%21.0g"))
    st_local("lm",  strofreal((sum(s:^2) / sum(q) - 1)^2 * sum(T)^2 / (2 * (sum(T:^2) - sum(T))), "%21.0g"))
    st_local("N",   strofreal(rows(V), "%20.0f"))
    st_local("n_g", strofreal(rows(info), "%20.0f"))
}

// 두 추정의 계수별 SE 비교 — 이름이 같은 계수끼리 (_cons·SE 0 제외). df 0 이면 정규 근사
void _mcp_proc_secmp(string scalar b1n, string scalar v1n, string scalar b2n, string scalar v2n,
                     real scalar df1, real scalar df2, real scalar alpha, string scalar skip)
{
    real rowvector b1, b2, s1, s2
    string colvector n1, n2
    string rowvector sk
    real scalar i, j, k, r, mx, nf, p1, p2
    string scalar mv, fl, nl, bl, sl1, sl2, pl1, pl2
    b1 = st_matrix(b1n); s1 = sqrt(diagonal(st_matrix(v1n)))'; n1 = st_matrixcolstripe(b1n)[., 2]
    b2 = st_matrix(b2n); s2 = sqrt(diagonal(st_matrix(v2n)))'; n2 = st_matrixcolstripe(b2n)[., 2]
    sk = tokens(skip)
    mx = 0; mv = ""; nf = 0; fl = ""
    nl = ""; bl = ""; sl1 = ""; sl2 = ""; pl1 = ""; pl2 = ""
    for (i = 1; i <= cols(b1); i++) {
        if (s1[i] == 0 | s1[i] >= .) continue
        j = 0
        for (k = 1; k <= rows(n2); k++) if (n2[k] == n1[i]) j = k
        if (j == 0) continue
        if (s2[j] == 0 | s2[j] >= .) continue
        p1 = (df1 > 0 ? 2 * ttail(df1, abs(b1[i] / s1[i])) : 2 * normal(-abs(b1[i] / s1[i])))
        p2 = (df2 > 0 ? 2 * ttail(df2, abs(b2[j] / s2[j])) : 2 * normal(-abs(b2[j] / s2[j])))
        nl = nl + " " + n1[i]
        bl = bl + " " + strofreal(b1[i], "%21.0g")
        sl1 = sl1 + " " + strofreal(s1[i], "%21.0g")
        sl2 = sl2 + " " + strofreal(s2[j], "%21.0g")
        pl1 = pl1 + " " + strofreal(p1, "%21.0g")
        pl2 = pl2 + " " + strofreal(p2, "%21.0g")
        if (n1[i] == "_cons") continue
        if (cols(sk) > 0 ? anyof(sk, n1[i]) : 0) continue
        r = abs(s2[j] / s1[i] - 1)
        if (r > mx) {
            mx = r
            mv = n1[i]
        }
        if ((p1 < alpha) != (p2 < alpha)) {
            nf++
            fl = fl + (fl == "" ? "" : ", ") + sprintf("%s (p %5.3f → %5.3f)", n1[i], p1, p2)
        }
    }
    st_local("maxpct", strofreal(100 * mx, "%21.0g"))
    st_local("maxpct_txt", (100 * mx < 0.01 ? "< 0.01%" : sprintf("%4.2f%%", 100 * mx)))
    st_local("maxvar", mv)
    st_local("nflip", strofreal(nf))
    st_local("flip", fl)
    st_local("names", strtrim(nl)); st_local("b", strtrim(bl))
    st_local("se1", strtrim(sl1)); st_local("se2", strtrim(sl2))
    st_local("p1", strtrim(pl1)); st_local("p2", strtrim(pl2))
}

// 개체 순번을 관측치 길이로 펼침 (panelsetup info 기준)
real colvector _mcp_proc_expand(real matrix info)
{
    real colvector g
    real scalar i
    g = J(info[rows(info), 2], 1, .)
    for (i = 1; i <= rows(info); i++) g[|info[i, 1] \ info[i, 2]|] = J(info[i, 2] - info[i, 1] + 1, 1, i)
    return(g)
}

void _mcp_proc_isint(string scalar x, string scalar vars)
{
    real matrix V, X
    string rowvector xs
    string scalar out
    real scalar j, k
    xs = tokens(x)
    k  = cols(xs)
    st_view(V=., ., (xs, tokens(vars)), 0)
    st_subview(X=., V, ., (1..k))
    out = ""
    for (j = 1; j <= k; j++) {
        if (all(X[., j] :== round(X[., j]))) out = out + " " + xs[j]
    }
    st_local("isint", strtrim(out))
}

// x 변수별 표본 안의 서로 다른 값 수 · 정수 여부 (보고서 주의의 이분형 종속변수 등 — 분석 때 판정)
void _mcp_proc_nlev(string scalar x, string scalar vars)
{
    real matrix V, X
    string rowvector xs
    string scalar nl, it
    real scalar j, k
    xs = tokens(x)
    k  = cols(xs)
    st_view(V=., ., (xs, tokens(vars)), 0)
    st_subview(X=., V, ., (1..k))
    nl = ""; it = ""
    for (j = 1; j <= k; j++) {
        nl = nl + " " + strofreal(rows(X) ? rows(uniqrows(X[., j])) : 0, "%20.0f")
        it = it + " " + (rows(X) & all(X[., j] :== round(X[., j])) ? "1" : "0")
    }
    st_local("nlev", strtrim(nl))
    st_local("int",  strtrim(it))
}

// id × time 중복 수 — 문자열 id 는 문자열 키로 비교 (변환 전 검사용)
void _mcp_proc_dupkey(string scalar id, string scalar time)
{
    real scalar n, u
    n = 0; u = 0
    if (st_isstrvar(id)) _mcp_proc_dupkey_str(id, time, n, u)
    else                 _mcp_proc_dupkey_num(id, time, n, u)
    st_local("N",     strofreal(n, "%20.0f"))
    st_local("n_dup", strofreal(n - u, "%20.0f"))
    st_local("examples", (n > u ? _mcp_proc_dupex(id, time) : ""))
}

// 중복 키 예시 — "id × time (k행)" 최대 3개 (값 그대로, 문자열 id 허용)
string scalar _mcp_proc_dupex(string scalar id, string scalar time)
{
    string colvector key, k
    real colvector t, ok, p
    real scalar i, j, c
    string scalar out
    t = st_data(., time)
    if (st_isstrvar(id)) key = st_sdata(., id)
    else                 key = strofreal(st_data(., id), "%21.0g")
    ok  = (key :!= "") :& (key :!= ".") :& (t :< .)
    k   = select(key, ok) :+ " × " :+ strofreal(select(t, ok), "%21.0g")
    p   = order(k, 1)
    k   = k[p]
    out = ""; c = 0; i = 1
    while (i <= rows(k) & c < 3) {
        j = i
        while (j < rows(k)) {
            if (k[j + 1] != k[i]) break
            j++
        }
        if (j > i) {
            out = out + (out == "" ? "" : "; ") + k[i] + " (" + strofreal(j - i + 1) + "행)"
            c++
        }
        i = j + 1
    }
    return(out)
}

// 패널 진단 — 키(id[, time]) 비결측 전체. 시점 간격 = 서로 다른 시점 사이의 최소 차이
void _mcp_proc_paneldiag(string scalar id, string scalar time)
{
    real matrix V, info
    real colvector p, T, u, lo, hi
    real scalar dt, n
    st_view(V=., ., (time == "" ? id : (id, time)), 0)
    p    = (time == "" ? order(V, 1) : order(V, (1, 2)))
    info = panelsetup(V[p, 1], 1)
    T    = info[., 2] - info[., 1] :+ 1
    st_local("N",      strofreal(rows(V), "%20.0f"))
    st_local("n_g",    strofreal(rows(info), "%20.0f"))
    st_local("Ti_min", strofreal(min(T), "%20.0f"))
    st_local("Ti_max", strofreal(max(T), "%20.0f"))
    st_local("Ti_med", strofreal(_mcp_proc_median(T), "%21.0g"))
    if (time == "") {
        st_local("n_t", "."); st_local("tmin", "."); st_local("tmax", ".")
        st_local("tdelta", "."); st_local("span", "."); st_local("n_gap", ".")
        return
    }
    u  = uniqrows(V[., 2])
    n  = rows(u)
    dt = (n > 1 ? min(u[|2 \ n|] - u[|1 \ n - 1|]) : 1)
    lo = V[p, 2][info[., 1]]
    hi = V[p, 2][info[., 2]]
    st_local("n_t",    strofreal(n, "%20.0f"))
    st_local("tmin",   strofreal(u[1], "%21.0g"))
    st_local("tmax",   strofreal(u[n], "%21.0g"))
    st_local("tdelta", strofreal(dt, "%21.0g"))
    st_local("span",   strofreal(round((u[n] - u[1]) / dt) + 1, "%20.0f"))
    st_local("n_gap",  strofreal(sum(round((hi - lo) :/ dt) :+ 1 :> T), "%20.0f"))
}

real scalar _mcp_proc_median(real colvector x)
{
    real colvector s
    real scalar n
    s = sort(x, 1)
    n = rows(s)
    return(mod(n, 2) ? s[(n + 1) / 2] : (s[n / 2] + s[n / 2 + 1]) / 2)
}

// 변수 진단 — 분석 표본 (id·time·x·vars 모두 비결측)
//   tover: 관측 2회 이상인 개체가 있고, 그 개체들 안에서 x − time 이 모두 일정한 x (시간 효과와 겹침)
void _mcp_proc_xcheck(string scalar id, string scalar time, string scalar x, string scalar vars)
{
    real matrix V, X, info
    real colvector I, t, p, T, D, g, multi
    string rowvector xs
    string scalar nl, sg, tv, iv, mn, mx
    real scalar k, j, nt, nv
    xs = tokens(x)
    k  = cols(xs)
    nv = (time == "" ? 1 : 2)
    st_view(V=., ., (time == "" ? (id, xs, tokens(vars)) : (id, time, xs, tokens(vars))), 0)
    st_subview(I=., V, ., 1)
    st_subview(X=., V, ., (nv + 1..nv + k))
    nl = ""; sg = ""; tv = ""; iv = ""; mn = ""; mx = ""
    for (j = 1; j <= k; j++) {
        nl = nl + " " + strofreal(rows(X) ? rows(uniqrows(X[., j])) : 0, "%20.0f")
        if (rows(X) & rows(uniqrows(X[., j])) == 1) sg = sg + " " + xs[j]
        iv = iv + " " + (rows(X) ? strofreal(all(X[., j] :== floor(X[., j]))) : "0")     // 정수값만인가 (코드 변수 판정)
        mn = mn + " " + (rows(X) ? strofreal(min(X[., j]), "%20.0g") : ".")
        mx = mx + " " + (rows(X) ? strofreal(max(X[., j]), "%20.0g") : ".")
    }
    st_local("isint", strtrim(iv)); st_local("vmin", strtrim(mn)); st_local("vmax", strtrim(mx))
    if (!rows(V)) {
        st_local("nlev", strtrim(nl)); st_local("single", ""); st_local("tover", "")
        st_local("nt", "0"); st_local("nt1", "0"); st_local("balanced", "0")
        return
    }
    p    = order(I, 1)
    info = panelsetup(I[p], 1)
    T    = info[., 2] - info[., 1] :+ 1
    g    = _mcp_proc_expand(info)
    if (time != "") {
        t  = V[., 2]
        nt = rows(uniqrows(t))
        multi = (T :> 1)[g]
        if (any(multi)) {
            for (j = 1; j <= k; j++) {
                D = X[p, j] - t[p]
                if (all(select(D :== D[info[., 1]][g], multi))) tv = tv + " " + xs[j]
            }
        }
        st_local("balanced", (all(T :== nt) ? "1" : "0"))
    }
    else {
        nt = .
        st_local("balanced", (all(T :== T[1]) ? "1" : "0"))
    }
    st_local("nlev",   strtrim(nl))
    st_local("single", strtrim(sg))
    st_local("tover",  strtrim(tv))
    st_local("nt",     strofreal(nt, "%20.0f"))
    st_local("nt1",    strofreal(nt - 1, "%20.0f"))
}

// wild cluster bootstrap 결과(e(wboot), e(wb_cns#)) 와 원래 추정(b, V, df)의 cluster-robust p 비교. df 0 이면 정규 근사
void _mcp_proc_wcb(string scalar bn, string scalar vn, real scalar df, real scalar alpha)
{
    real matrix W
    real rowvector b, se
    string colvector cn
    string scalar nm, names, bs, pcs, pws, lls, uls, cls, cus, fl, mv
    real scalar i, j, k, p1, p2, nf, q, w, mx
    W  = st_matrix("e(wboot)")
    b  = st_matrix(bn)
    se = sqrt(diagonal(st_matrix(vn)))'
    cn = st_matrixcolstripe(bn)[., 2]
    names = ""; bs = ""; pcs = ""; pws = ""; lls = ""; uls = ""; cls = ""; cus = ""; fl = ""; nf = 0
    mx = .; mv = ""
    q = (df > 0 ? invttail(df, alpha / 2) : invnormal(1 - alpha / 2))
    for (i = 1; i <= rows(W); i++) {
        nm = strtrim(subinstr(st_global("e(wb_cns" + strofreal(i) + ")"), "= 0", ""))
        j = 0
        for (k = 1; k <= rows(cn); k++) if (cn[k] == nm) j = k
        if (j == 0) continue
        p1 = (df > 0 ? 2 * ttail(df, abs(b[j] / se[j])) : 2 * normal(-abs(b[j] / se[j])))
        p2 = W[i, 3]
        names = names + " " + nm
        bs  = bs  + " " + strofreal(b[j], "%21.0g")
        pcs = pcs + " " + strofreal(p1, "%21.0g")
        pws = pws + " " + strofreal(p2, "%21.0g")
        lls = lls + " " + strofreal(W[i, 4], "%21.0g")
        uls = uls + " " + strofreal(W[i, 5], "%21.0g")
        cls = cls + " " + strofreal(b[j] - q * se[j], "%21.0g")
        cus = cus + " " + strofreal(b[j] + q * se[j], "%21.0g")
        w = ((W[i, 5] - W[i, 4]) / (2 * q * se[j]) - 1) * 100
        if (w < . & (mx >= . | abs(w) > abs(mx))) {
            mx = w
            mv = nm
        }
        if ((p1 < alpha) != (p2 < alpha)) {
            nf++
            fl = fl + (fl == "" ? "" : ", ") + sprintf("%s (p %5.3f → %5.3f)", nm, p1, p2)
        }
    }
    st_local("names", strtrim(names)); st_local("b", strtrim(bs)); st_local("pcl", strtrim(pcs))
    st_local("pwb", strtrim(pws)); st_local("ll", strtrim(lls)); st_local("ul", strtrim(uls))
    st_local("cll", strtrim(cls)); st_local("cul", strtrim(cus))
    st_local("maxpct", strofreal(mx)); st_local("maxvar", mv)
    st_local("maxpct_txt", (mx >= . ? "" : (mx >= 0 ? "+" : "") + strtrim(sprintf("%9.1f", mx)) + "%"))
    st_local("nflip", strofreal(nf)); st_local("flip", fl)
}

// 문자열 → 숫자 가능 여부. 숫자 = strtoreal 로 읽히는 값 (빈 값은 결측으로 둠)
void _mcp_proc_numstr(string scalar v)
{
    string colvector s, bad
    real colvector r, ne
    s   = strtrim(st_sdata(., v))
    r   = strtoreal(s)
    ne  = (s :!= "")
    bad = select(s, ne :& (r :>= .))
    st_local("numeric",  (rows(bad) ? "0" : "1"))
    st_local("n_bad",    strofreal(rows(bad), "%20.0f"))
    if (rows(bad)) bad = uniqrows(bad)
    st_local("examples", (rows(bad) ? invtokens((char(34) :+ bad[|1 \ min((rows(bad), 3))|] :+ char(34))', ", ") : ""))
    st_local("collide",  (rows(select(s, ne)) & !rows(bad) ? (rows(uniqrows(select(s, ne))) > rows(uniqrows(select(r, ne))) ? "1" : "0") : "0"))
}

void _mcp_proc_dupkey_num(string scalar id, string scalar time, real scalar n, real scalar u)
{
    real matrix V
    st_view(V=., ., (id, time), 0)
    n = rows(V)
    u = n ? rows(uniqrows(V)) : 0
}

void _mcp_proc_dupkey_str(string scalar id, string scalar time, real scalar n, real scalar u)
{
    string colvector s, key
    real colvector t, ok
    s  = st_sdata(., id)
    t  = st_data(., time)
    ok = (s :!= "") :& (t :< .)
    n  = sum(ok)
    if (!n) {
        u = 0
        return
    }
    key = select(s, ok) :+ char(1) :+ strofreal(select(t, ok), "%21.0g")
    u = rows(uniqrows(key))
}

// id × time 후보 쌍 — 이름·형식으로 후보를 고르고 유일성이 확인된 쌍만 (최대 3)
void _mcp_proc_panelcand()
{
    real scalar k, v, i, j, tried, n, u, found
    string scalar nm, fmt, out
    string colvector ids, times
    k = st_nvar()
    ids = J(0, 1, ""); times = J(0, 1, "")
    for (v = 1; v <= k; v++) {
        nm  = strlower(st_varname(v))
        fmt = st_varformat(v)
        if (st_isstrvar(v)) {
            if (_mcp_proc_isidname(nm)) ids = ids \ st_varname(v)
            continue
        }
        if (substr(fmt, 1, 2) == "%t" | _mcp_proc_istimename(nm)) times = times \ st_varname(v)
        else if (_mcp_proc_isidname(nm)) ids = ids \ st_varname(v)
    }
    if (rows(times) > 3) times = times[|1 \ 3|]
    if (rows(ids)   > 3) ids   = ids[|1 \ 3|]
    out = ""; found = 0; tried = 0
    for (i = 1; i <= rows(ids); i++) {
        if (found >= 3 | tried >= 9) break
        for (j = 1; j <= rows(times); j++) {
            if (found >= 3 | tried >= 9) break
            tried++
            n = 0; u = 0
            if (st_isstrvar(ids[i])) _mcp_proc_dupkey_str(ids[i], times[j], n, u)
            else                     _mcp_proc_dupkey_num(ids[i], times[j], n, u)
            if (n > 0 & n == u) {
                out = out + (out == "" ? "" : ";") + ids[i] + " " + times[j]
                found++
            }
        }
    }
    st_local("cands", out)
}

real scalar _mcp_proc_isidname(string scalar nm)
{
    return(regexm(nm, "^(id|pid|hhid|pnum|caseid|personid|respid)$") | regexm(nm, "id$") | regexm(nm, "^id_") | regexm(nm, "code$"))
}

real scalar _mcp_proc_istimename(string scalar nm)
{
    return(regexm(nm, "^(t|yr|year|wave|time|period|month|quarter|date|round)$") | regexm(nm, "year$") | regexm(nm, "^wave"))
}

// ─────────────────────────────────────────────────────────────────────────────
// panel_build — 파일 목록 · 변수 이름 대조 (2026-10-31, docs/panel_build_design.md §3)
// ─────────────────────────────────────────────────────────────────────────────

// 파일 이름(확장자 뺀 것, ";" 구분)의 공통 앞부분
string scalar _mcp_proc_prefix(string scalar list)
{
    string rowvector t
    string scalar p
    real scalar i, n
    t = tokens(subinstr(list, ";", " "))
    if (cols(t) == 0) return("")
    p = t[1]
    for (i = 2; i <= cols(t); i++) {
        n = 0
        while (n < min((strlen(p), strlen(t[i]))) & substr(p, n + 1, 1) == substr(t[i], n + 1, 1)) n++
        p = substr(p, 1, n)
    }
    return(p)
}

void _mcp_vc_init()
{
    external real scalar _mcp_vc_nf
    _mcp_vc_nf = 0
}

void _mcp_vc_clear()
{
    external real scalar _mcp_vc_nf
    real scalar i
    for (i = 1; i <= _mcp_vc_nf; i++) {
        rmexternal("_mcp_vc_n" + strofreal(i))
        rmexternal("_mcp_vc_t" + strofreal(i))
    }
    _mcp_vc_nf = 0
}

// 지금 frame 의 변수 이름 · 저장 형식을 파일 i 몫으로 보관 (외부 변수 — 함수가 끝나도 남음)
void _mcp_vc_collect(real scalar i)
{
    external real scalar _mcp_vc_nf
    pointer(string colvector) scalar pn, pt
    real scalar k, v
    string colvector nm, ty
    k = st_nvar()
    nm = J(k, 1, ""); ty = J(k, 1, "")
    for (v = 1; v <= k; v++) {
        nm[v] = st_varname(v)
        ty[v] = st_vartype(v)
    }
    pn = crexternal("_mcp_vc_n" + strofreal(i)); *pn = nm
    pt = crexternal("_mcp_vc_t" + strofreal(i)); *pt = ty
    _mcp_vc_nf = max((_mcp_vc_nf, i))
}

// 자리 ⓐ — 앞 글자 바로 뒤 숫자 묶음의 첫 d 자리. 없으면 "". stripped = 그 숫자만 뺀 이름
string scalar _mcp_vc_tokA(string scalar s, real scalar d, string scalar stripped)
{
    string scalar L, D, R
    if (!regexm(s, "^([A-Za-z]+)([0-9]+)(.*)$")) return("")
    L = regexs(1); D = regexs(2); R = regexs(3)
    if (strlen(D) < d) return("")
    stripped = L + substr(D, d + 1, .) + R
    return(substr(D, 1, d))
}

// 자리 ⓑ — 맨 끝 숫자 묶음(정확히 d 자리, 앞의 _ 포함해 뺌). 없으면 ""
string scalar _mcp_vc_tokB(string scalar s, real scalar d, string scalar stripped)
{
    if (!regexm(s, "^(.*[^0-9_])(_?)([0-9]+)$")) return("")
    if (strlen(regexs(3)) != d) return("")
    stripped = regexs(1)
    return(regexs(3))
}

// 토큰이 그 파일의 차수인가(d 자리 비교) / 다른 파일의 차수인가
real scalar _mcp_vc_isown(string scalar tok, string scalar w2, real scalar d)
{
    if (d == 2) return(tok == w2)
    return(tok == strofreal(strtoreal(w2)))
}
real scalar _mcp_vc_isother(string scalar tok, string rowvector W2, real scalar me, real scalar d)
{
    real scalar j
    for (j = 1; j <= cols(W2); j++) {
        if (j == me) continue
        if (_mcp_vc_isown(tok, W2[j], d)) return(1)
    }
    return(0)
}

// 규칙(a 자릿수, b 자릿수; 0 = 안 씀)으로 이름 하나를 벗긴다. own: 자기 토큰이 있었나, other: 다른 차수 토큰이 있었나
string scalar _mcp_vc_strip(string scalar s, real scalar da, real scalar db, string rowvector W2, real scalar me,
                            real scalar own, real scalar other)
{
    string scalar t, out, tok
    own = 0; other = 0
    out = s
    t = ""
    if (da > 0) {
        tok = _mcp_vc_tokA(out, da, t)
        if (tok != "") {
            if (_mcp_vc_isown(tok, W2[me], da)) {
                out = t
                own = 1
            }
            else if (_mcp_vc_isother(tok, W2, me, da)) other = 1
        }
    }
    if (db > 0 & !other) {
        t = ""
        tok = _mcp_vc_tokB(out, db, t)
        if (tok != "") {
            if (_mcp_vc_isown(tok, W2[me], db)) {
                out = t
                own = 1
            }
            else if (_mcp_vc_isother(tok, W2, me, db)) other = 1
        }
    }
    return(out)
}

// 규칙으로 벗긴 뒤 "다른 파일에도 있는 이름" 수 (다른 차수 변수는 뺌)
real scalar _mcp_vc_match(real scalar da, real scalar db, string rowvector W2)
{
    external real scalar _mcp_vc_nf
    real scalar i, j, v, m, own, other
    transmorphic A, SETS
    pointer(string colvector) scalar p
    string colvector S, Sj
    string scalar out
    SETS = asarray_create("real", 1)
    for (i = 1; i <= _mcp_vc_nf; i++) {
        p = findexternal("_mcp_vc_n" + strofreal(i))
        S = J(0, 1, "")
        for (v = 1; v <= rows(*p); v++) {
            own = 0; other = 0
            out = _mcp_vc_strip((*p)[v], da, db, W2, i, own, other)
            if (!other) S = S \ out
        }
        asarray(SETS, i, S)
    }
    m = 0
    for (i = 1; i <= _mcp_vc_nf; i++) {
        A = asarray_create()
        for (j = 1; j <= _mcp_vc_nf; j++) {
            if (j == i) continue
            Sj = asarray(SETS, j)
            for (v = 1; v <= rows(Sj); v++) asarray(A, Sj[v], 1)
        }
        S = asarray(SETS, i)
        for (v = 1; v <= rows(S); v++) if (asarray_contains(A, S[v])) m++
    }
    return(m)
}

// 파일 i 의 자리 pos(1=ⓐ, 2=ⓑ) 에서 가장 많이 나오는 2자리 숫자와 그 수
string scalar _mcp_vc_mode(real scalar i, real scalar pos, real scalar count)
{
    pointer(string colvector) scalar p
    transmorphic A, loc
    real scalar v, c
    string scalar tok, t, best
    p = findexternal("_mcp_vc_n" + strofreal(i))
    A = asarray_create()
    for (v = 1; v <= rows(*p); v++) {
        t = ""
        tok = pos == 1 ? _mcp_vc_tokA((*p)[v], 2, t) : _mcp_vc_tokB((*p)[v], 2, t)
        if (tok == "") continue
        asarray(A, tok, asarray_contains(A, tok) ? asarray(A, tok) + 1 : 1)
    }
    best = ""; count = 0
    for (loc = asarray_first(A); loc != NULL; loc = asarray_next(A, loc)) {
        c = asarray_contents(A, loc)
        if (c > count) {
            count = c
            best = asarray_key(A, loc)
        }
    }
    return(best)
}

string scalar _mcp_vc_pad(string scalar w)
{
    real scalar r
    r = strtoreal(w)
    if (r == .) return(w)
    return(r < 10 ? "0" + strofreal(r) : strofreal(r))
}

string scalar _mcp_vc_join(string colvector v, string scalar sep, real scalar cap)
{
    real scalar i, n
    string scalar out
    out = ""
    n = min((rows(v), cap))
    for (i = 1; i <= n; i++) out = out + (i == 1 ? "" : sep) + v[i]
    return(out)
}

void _mcp_vc_run(string scalar wavesopt)
{
    external real scalar _mcp_vc_nf
    real scalar nf, i, j, v, base, mA1, mA2, mB1, mB2, da, db, ma, mb, mm, own, other, cntA, cntB, ok, nnames, ntot
    real scalar ncommon, isid, ns, no, untouched
    string rowvector W, W2, names, names2
    string scalar out, wsrc, stop, stem, ex, a, b
    string colvector nm, ty, nstrip, othern, flags, inv, coll, idc, tconf, otherl, pref
    transmorphic allS, cnt, strT, numT, stemname, flagseen, otherseen, prefA, loc
    pointer(string colvector) scalar p, pt
    nf = _mcp_vc_nf
    nnames = 0
    for (i = 1; i <= nf; i++) nnames = nnames + rows(*findexternal("_mcp_vc_n" + strofreal(i)))

    // ── 차수 번호 — 준 것이 있으면 그것, 없으면 변수 이름의 공통 숫자(같은 자리 최다) ──
    W = tokens(wavesopt)
    wsrc = "file"
    ok = 1
    if (cols(W) != nf) {
        W = J(1, nf, "")
        wsrc = "vars"
        for (i = 1; i <= nf; i++) {
            cntA = 0; cntB = 0
            a = _mcp_vc_mode(i, 1, cntA)
            b = _mcp_vc_mode(i, 2, cntB)
            W[i] = cntA >= cntB ? a : b
            if (W[i] == "") ok = 0
        }
    }
    W2 = J(1, nf, "")
    for (i = 1; i <= nf; i++) W2[i] = _mcp_vc_pad(W[i])
    for (i = 1; i <= nf; i++) for (j = i + 1; j <= nf; j++) if (W2[i] != "" & W2[i] == W2[j]) ok = 0
    if (!ok) wsrc = "none"
    st_local("waves_out", invtokens(W2))
    st_local("wavesrc", wsrc)
    st_local("waves_ok", strofreal(ok))
    st_local("nnames", strofreal(nnames))
    if (!ok) {
        st_local("rule_a", "0"); st_local("rule_b", "0"); st_local("baseline", "0"); st_local("match_a", "0"); st_local("match_b", "0"); st_local("match", "0")
        st_local("nstrip", ""); st_local("prefixes", ""); st_local("other_n", ""); st_local("other_list", ""); st_local("other_total", "0")
        st_local("flags", ""); st_local("invariant", ""); st_local("collide", ""); st_local("idcands", ""); st_local("typeconf", ""); st_local("n_typeconf", "0")
        st_local("n_common", "0"); st_local("stop", "nowave"); st_local("example", "")
        return
    }

    // ── 규칙 고르기 — 매칭을 늘리는 자리·자릿수만, 임계값 없음 ──
    base = _mcp_vc_match(0, 0, W2)
    mA1 = _mcp_vc_match(1, 0, W2); mA2 = _mcp_vc_match(2, 0, W2)
    mB1 = _mcp_vc_match(0, 1, W2); mB2 = _mcp_vc_match(0, 2, W2)
    da = 0; ma = base
    if (mA2 > ma) {
        da = 2; ma = mA2
    }
    if (mA1 > ma) {
        da = 1; ma = mA1
    }
    db = 0; mb = base
    if (mB2 > mb) {
        db = 2; mb = mB2
    }
    if (mB1 > mb) {
        db = 1; mb = mB1
    }
    mm = (da > 0 | db > 0) ? _mcp_vc_match(da, db, W2) : base
    if (da > 0 & db > 0 & mm < max((ma, mb))) {              // 둘을 같이 쓰면 오히려 줄면 큰 쪽만
        if (ma >= mb) db = 0
        else da = 0
        mm = max((ma, mb))
    }
    st_local("rule_a", strofreal(da)); st_local("rule_b", strofreal(db))
    st_local("baseline", strofreal(base)); st_local("match_a", strofreal(ma)); st_local("match_b", strofreal(mb)); st_local("match", strofreal(mm))

    // ── 고른 규칙으로 파일마다 벗기기 · 분류 ──
    allS = asarray_create()          // 벗긴 이름 → 들어 있는 파일 수
    strT = asarray_create(); numT = asarray_create()
    stemname = asarray_create()      // 벗긴 이름 → 파일별 원래 이름 (ID 후보용)
    flagseen = asarray_create()
    otherseen = asarray_create()
    prefA = asarray_create()
    nstrip = J(nf, 1, ""); othern = J(nf, 1, "")
    otherl = J(0, 1, ""); flags = J(0, 1, ""); coll = J(0, 1, "")
    ex = ""
    ntot = 0
    for (i = 1; i <= nf; i++) {
        p = findexternal("_mcp_vc_n" + strofreal(i)); pt = findexternal("_mcp_vc_t" + strofreal(i))
        nm = *p; ty = *pt
        cnt = asarray_create()
        ns = 0; no = 0
        for (v = 1; v <= rows(nm); v++) {
            own = 0; other = 0
            out = _mcp_vc_strip(nm[v], da, db, W2, i, own, other)
            if (other) {
                no++
                if (rows(otherl) < 60 & !asarray_contains(otherseen, nm[v])) {
                    asarray(otherseen, nm[v], 1)
                    otherl = otherl \ nm[v]
                }
                continue
            }
            if (own) {
                ns++
                if (da > 0 & regexm(nm[v], "^([A-Za-z]+)[0-9]")) asarray(prefA, regexs(1), 1)
                if (regexm(nm[v], "^([A-Za-z]+)[0-9]+$") & out == regexs(1)) {       // 표식만 남는 이름 → <글자>flag
                    out = out + "flag"
                    if (!asarray_contains(flagseen, out)) {
                        asarray(flagseen, out, 1)
                        flags = flags \ (nm[v] + ">" + out)
                    }
                }
            }
            if (own & ex == "" & !regexm(out, "flag$")) ex = nm[v] + " → " + out      // 카드의 예 — 플래그가 아닌 보통 변수로
            if (asarray_contains(cnt, out)) {
                if (rows(coll) < 40) coll = coll \ (nm[v] + "=" + out)
            }
            else asarray(cnt, out, 1)
            asarray(allS, out, asarray_contains(allS, out) ? asarray(allS, out) + 1 : 1)
            if (asarray_contains(stemname, out)) names = asarray(stemname, out)
            else names = J(1, nf, "")
            names[i] = nm[v]
            asarray(stemname, out, names)
            if (substr(ty[v], 1, 3) == "str") asarray(strT, out, 1)
            else asarray(numT, out, 1)
        }
        nstrip[i] = strofreal(ns); othern[i] = strofreal(no)
        ntot = ntot + no
    }
    // 공통 어간 · 시불변 · ID 후보 · 형식 충돌
    inv = J(0, 1, ""); idc = J(0, 1, ""); tconf = J(0, 1, "")
    ncommon = 0
    for (loc = asarray_first(allS); loc != NULL; loc = asarray_next(allS, loc)) {
        stem = asarray_key(allS, loc)
        if (asarray_contents(allS, loc) < nf) continue
        ncommon++
        names2 = asarray(stemname, stem)
        untouched = 1
        for (i = 1; i <= nf; i++) if (names2[i] != stem) untouched = 0
        if (untouched & rows(inv) < 60) inv = inv \ stem
        isid = untouched | _mcp_proc_isidname(strlower(stem))
        if (isid & rows(idc) < 20) idc = idc \ (stem + ":" + invtokens(names2, ","))
        if (asarray_contains(strT, stem) & asarray_contains(numT, stem) & rows(tconf) < 40) tconf = tconf \ stem
    }
    pref = J(0, 1, "")
    for (loc = asarray_first(prefA); loc != NULL; loc = asarray_next(prefA, loc)) pref = pref \ asarray_key(prefA, loc)
    // 멈춤 사유 — 규칙도 없고 원래 이름도 과반이 안 맞으면 이 workflow 대상이 아님 · 벗긴 뒤 한 파일 안 겹침
    stop = ""
    if (da == 0 & db == 0 & base * 2 < nnames) stop = "notoken"
    if (rows(coll) > 0) stop = "collide"
    st_local("nstrip", invtokens(nstrip')); st_local("prefixes", invtokens(sort(pref, 1)'))
    st_local("other_n", invtokens(othern')); st_local("other_list", _mcp_vc_join(otherl, " ", 60)); st_local("other_total", strofreal(ntot))
    st_local("flags", _mcp_vc_join(flags, " ", 40)); st_local("invariant", _mcp_vc_join(sort(inv, 1), " ", 60))
    st_local("collide", _mcp_vc_join(coll, " ", 40)); st_local("idcands", _mcp_vc_join(idc, ";", 20))
    st_local("typeconf", _mcp_vc_join(sort(tconf, 1), " ", 40)); st_local("n_typeconf", strofreal(rows(tconf)))
    st_local("n_common", strofreal(ncommon)); st_local("stop", stop); st_local("example", ex)
}

end
