/*
ECON 490 Team 14
Data citations:

Penn World Table 11.0
Feenstra, Robert C., Robert Inklaar, and Marcel P. Timmer (2015),
"The Next Generation of the Penn World Table" American Economic Review, 105(10), 3150-3182,
available for download at www.ggdc.net/pwt

Comparative Political Data Set, 1960-2023 Update
Armingeon, Klaus, Sarah Engler, Lucas Leemann, and David Weisstanner. 2025.
Supplement to the Comparative Political Data Set - Government Composition 1960-2023.
Zurich/Lueneburg/Lucerne: University of Zurich, Leuphana University Lueneburg, and University of Lucerne.
*/

clear all
set more off
set graphics off
set linesize 255

*************************
* Setup and project paths
*************************

* Insert your cd
cd "C:/Users/matth/OneDrive - UBC/ECON_V 490 006 2025W2 Seminar in Applied Economics - Team 14"

global proj_main "`c(pwd)'"   	// Root project folder
global datadir   "${proj_main}/1. Data"   // Raw-data folder
global processed "${datadir}/processed"     // Cleaned intermediate data
global log_dir   "${proj_main}/3. log-files"  // Final log output
global tabledir  "${proj_main}/4. Tables"   // Exported regression tables
global figdir    "${proj_main}/5. Figures"   // Exported figures

global raw_pwt      "${datadir}/pwt110.dta"                    // Penn World Table file
global raw_cpds     "${datadir}/CPDS_1960-2023_Update_2025.dta"  // CPDS government data

capture mkdir "${processed}"  // Create processed-data folder if needed
capture mkdir "${log_dir}"   // Create log folder if needed
capture mkdir "${tabledir}"   // Create tables folder if needed
capture mkdir "${figdir}"    // Create figures folder if needed

capture which xtserial
if _rc ssc install xtserial  // Install Wooldridge serial-correlation test if missing

capture which xttest3
if _rc ssc install xttest3  // Install modified Wald heteroskedasticity test if missing

capture which coefplot
if _rc ssc install coefplot // Install coefficient-plot package if missing

capture log close _all
log using "${log_dir}/Econometric File.log", text replace  // Start final log file

quietly {

***********************************************
* Penn World Table cleaning and growth controls
***********************************************

use "${raw_pwt}", clear

keep countrycode country year cgdpe pop csh_i hc  // Keep only the PWT variables needed for growth accounting
keep if inrange(year, 1960, 2023)               // Keep the full common raw overlap used across PWT and CPDS (1960-2023).
drop if missing(countrycode) | missing(country) | missing(year)  // Drop unusable identifiers

replace country = "Ivory Coast" if countrycode == "CIV"  // Make country names the same for later merges
replace country = "Turkey" if countrycode == "TUR"     // Make country names the same for later merges

replace cgdpe = . if cgdpe <= 0  // To ensure gdp log doesn't cause errors
replace pop   = . if pop <= 0   // To ensure population log doesn't cause errors
replace csh_i = . if csh_i <= 0  // To ensure savings log doesn't cause errors
replace hc    = . if hc <= 0    // To ensure human cap log doesn't cause errors

generate gdp_per_capita = cgdpe / pop                  // GDP per capita level
generate gdp_per_capita_thousands = gdp_per_capita / 1000   // Easier descriptive unit
generate population_millions = pop                     // PWT population is already in millions
generate savings_share_percent = csh_i * 100           // Convert savings share to percent
generate human_capital_index = hc                      // Rename for ease of reading

label var gdp_per_capita_thousands "GDP per capita (thousand 2017 USD)"
label var population_millions "Population (millions)"
label var savings_share_percent "Savings share of GDP (%)"
label var human_capital_index "Human capital index"

generate log_gdp_per_capita = ln(gdp_per_capita)       // Log GDP per capita for growth accounting
generate log_population = ln(pop)                      // Log population for growth accounting
generate log_savings_share = ln(savings_share_percent) // Log savings share for growth accounting
generate log_human_capital = ln(human_capital_index)   // Log human capital for growth accounting

encode countrycode, generate(pwt_panel_id) // Numeric panel id for xtset
xtset pwt_panel_id year, yearly            // Telling Stata this is a country-year panel

generate annual_gdp_per_capita_growth = 100 * (log_gdp_per_capita - L1.log_gdp_per_capita)   // Annual log growth in percent
generate lag_log_gdp_per_capita = L1.log_gdp_per_capita                                       // Convergence control
generate population_growth = 100 * (log_population - L1.log_population)                      // Population growth in percent

label var annual_gdp_per_capita_growth "Annual GDP per capita growth (%)"
label var lag_log_gdp_per_capita "Lagged log GDP per capita"
label var log_savings_share "Log savings share of GDP"
label var log_human_capital "Log human capital"
label var population_growth "Population growth (%)"

keep countrycode country year gdp_per_capita_thousands population_millions ///
     savings_share_percent human_capital_index annual_gdp_per_capita_growth ///
     lag_log_gdp_per_capita log_savings_share log_human_capital population_growth 
	 // Keep only the final PWT variables that the later merge and regressions need

rename countrycode iso   // Standardize the country code name before merging

save "${processed}/pwt_growth_clean.dta", replace

**************************************
* CPDS cleaning and ideology variables
**************************************

use "${raw_cpds}", clear

keep year country iso gov_right1 gov_left1 gov_cent1 gov_gap gov_new prop pres fed
// Keep only CPDS variables needed to define ideology, institutions, and subsets

keep if inrange(year, 1960, 2023) // Keep the full common raw overlap used across PWT and CPDS (1960-2023).
drop if missing(iso) | missing(year) // Drop rows that cannot merge cleanly

replace iso = trim(iso) // Remove any stray spaces in the country code

generate government_ideology_score = (gov_right1 - gov_left1) / 100
// Positive values are more right-leaning governments; negative values are more left-leaning.

label var government_ideology_score "Government ideology score"

generate pr_democracy = .
replace pr_democracy = 1 if prop == 2  // CPDS code for proportional representation
replace pr_democracy = 0 if inlist(prop, 0, 1)  // Other democratic electoral systems
label define pr_system_lbl 0 "Mixed/majoritarian democracy" 1 "PR democracy"
label values pr_democracy pr_system_lbl
label var pr_democracy "Proportional representation democracy"

generate parliamentary_democracy = .
replace parliamentary_democracy = 1 if pres == 0  // Parliamentary democracies are the core paper sample
replace parliamentary_democracy = 0 if pres != 0 & pres != .
label define parl_lbl 0 "Presidential or mixed democracy" 1 "Parliamentary democracy"
label values parliamentary_democracy parl_lbl
label var parliamentary_democracy "Parliamentary democracy"

encode iso, generate(cpds_panel_id)  // Numeric panel identifier
xtset cpds_panel_id year, yearly      // Telling Stata this is CPDS panel before creating lags

* Raw year-to-year movement in governing ideology
generate ideology_shift = government_ideology_score - L1.government_ideology_score

* Main explanatory variable: the size of the shift, regardless of direction
generate ideology_shift_magnitude = abs(ideology_shift)

* Quadratic term used only for the non-linearity test
generate ideology_shift_squared = ideology_shift_magnitude^2

* Event version of the treatment for robustness checks
generate major_shift_event = 0
replace major_shift_event = 1 if ideology_shift_magnitude >= 1 & ideology_shift_magnitude != .

* Magnitude of leftward movement only
generate left_shift = 0
replace left_shift = abs(ideology_shift) if ideology_shift < 0 & ideology_shift != .

* Magnitude of rightward movement only
generate right_shift = 0
replace right_shift = ideology_shift if ideology_shift > 0 & ideology_shift != .

* Small shifts help show whether tiny cabinet drift matters
generate shift_small_event = 0
replace shift_small_event = 1 if ideology_shift_magnitude > 0 & ideology_shift_magnitude < 0.5

* Medium shifts sit between drift and major realignment
generate shift_medium_event = 0
replace shift_medium_event = 1 if ideology_shift_magnitude >= 0.5 & ideology_shift_magnitude < 1

* Large shifts are the main mechanism table variable
generate shift_large_event = 0
replace shift_large_event = 1 if ideology_shift_magnitude >= 1 & ideology_shift_magnitude != .

* Directional threshold events split left and right movement into small, medium, and large bins
generate small_left_event = 0
replace small_left_event = 1 if ideology_shift < 0 & ideology_shift > -0.5

generate medium_left_event = 0
replace medium_left_event = 1 if ideology_shift <= -0.5 & ideology_shift > -1

generate large_left_event = 0
replace large_left_event = 1 if ideology_shift <= -1 & ideology_shift != .

generate small_right_event = 0
replace small_right_event = 1 if ideology_shift > 0 & ideology_shift < 0.5

generate medium_right_event = 0
replace medium_right_event = 1 if ideology_shift >= 0.5 & ideology_shift < 1

generate large_right_event = 0
replace large_right_event = 1 if ideology_shift >= 1 & ideology_shift != .


label var ideology_shift "Change in government ideology score"
label var ideology_shift_magnitude "Ideology-shift magnitude"
label var ideology_shift_squared "Squared ideology-shift magnitude"
label var major_shift_event "Large ideology-shift event"
label var left_shift "Leftward ideology shift"
label var right_shift "Rightward ideology shift"
label var shift_small_event "Small ideology shift"
label var shift_medium_event "Medium ideology shift"
label var shift_large_event "Large ideology shift"
label var small_left_event "Small leftward ideology shift"
label var medium_left_event "Medium leftward ideology shift"
label var large_left_event "Large leftward ideology shift"
label var small_right_event "Small rightward ideology shift"
label var medium_right_event "Medium rightward ideology shift"
label var large_right_event "Large rightward ideology shift"

drop cpds_panel_id  // Drop temporary panel id before saving

save "${processed}/cpds_clean.dta", replace

*******************************************************
* Merge the panel and define the final analysis samples
*******************************************************

use "${processed}/cpds_clean.dta", clear

* First merge: attach PWT growth variables to the political panel
merge 1:1 iso year using "${processed}/pwt_growth_clean.dta"

display "CPDS-PWT merge summary"
tabulate _merge

/*
The merge issues arise not from variables, but from unmatched rows, from country-year observations. Rows unique to CPDS generally fall into two categories: democracies, or years where Penn World Table coverage was unuseable after cleaning. Rows unique to PWT on the other hand, consist of countries or territories outside the CPDS government composition sample.
*/

keep if _merge == 3  // Keep only matched CPDS-PWT country-years for the final panel
drop _merge        // Remove the merge flag

encode iso, generate(panel_id)   // Create the final panel id used throughout the regressions
xtset panel_id year, yearly      // Telling Stata that this is the final merged country-year panel

* Lag the political treatment so ideological movement predates the annual growth outcome
generate lag_ideology_shift_magnitude = L1.ideology_shift_magnitude
generate lag_ideology_shift_squared = lag_ideology_shift_magnitude^2
generate lag_major_shift_event = L1.major_shift_event
generate lag_shift_small_event = L1.shift_small_event
generate lag_shift_medium_event = L1.shift_medium_event
generate lag_shift_large_event = L1.shift_large_event
generate lag_left_shift = L1.left_shift
generate lag_right_shift = L1.right_shift
generate lag_small_left_event = L1.small_left_event
generate lag_medium_left_event = L1.medium_left_event
generate lag_large_left_event = L1.large_left_event
generate lag_small_right_event = L1.small_right_event
generate lag_medium_right_event = L1.medium_right_event
generate lag_large_right_event = L1.large_right_event

label var lag_ideology_shift_magnitude "Lagged ideology-shift magnitude"
label var lag_ideology_shift_squared "Squared lagged ideology-shift magnitude"
label var lag_major_shift_event "Lagged large ideology-shift event"
label var lag_shift_small_event "Lagged small ideology shift"
label var lag_shift_medium_event "Lagged medium ideology shift"
label var lag_shift_large_event "Lagged large ideology shift"
label var lag_left_shift "Lagged leftward ideology shift"
label var lag_right_shift "Lagged rightward ideology shift"
label var lag_small_left_event "Lagged small leftward shift"
label var lag_medium_left_event "Lagged medium leftward shift"
label var lag_large_left_event "Lagged large leftward shift"
label var lag_small_right_event "Lagged small rightward shift"
label var lag_medium_right_event "Lagged medium rightward shift"
label var lag_large_right_event "Lagged large rightward shift"

* Main dependent variable: annual growth follows the standard year-to-year panel-growth setup
generate growth_rate_annual = annual_gdp_per_capita_growth
label var growth_rate_annual "Annual GDP per capita growth (%)"

* Restrict the paper's final sample to parliamentary democracies
generate parliamentary_sample = parliamentary_democracy == 1

* Main regression sample: only rows with all core variables present, including the lagged political treatment
generate analysis_sample = parliamentary_sample == 1 ///
    & !missing(growth_rate_annual, lag_ideology_shift_magnitude, lag_log_gdp_per_capita, ///
               log_savings_share, log_human_capital, population_growth)

count if analysis_sample == 1
display "Main parliamentary annual-growth analysis sample size = " r(N)

levelsof iso if analysis_sample == 1, local(parl_country_list)
local parl_country_count : word count `parl_country_list'
display "Main parliamentary countries = " `parl_country_count'

summarize year if analysis_sample == 1
display "Main parliamentary analysis years run from " %4.0f r(min) " to " %4.0f r(max)

save "${processed}/main_democracy_panel.dta", replace

use "${processed}/main_democracy_panel.dta", clear

********************
* Summary Statistics
********************

preserve
keep if analysis_sample == 1                               // Restrict to the final paper sample
collapse (count) observations = growth_rate_annual, by(year)    // Count usable observations by year
gsort -observations -year                                 // Put the most populated and most recent year first
local representative_year = year[1]                       // Pick the year with the maximum usable observations
restore

display "Representative year for the summary table = " `representative_year'

preserve
keep if analysis_sample == 1 & year == `representative_year'  // Keep the representative cross-section only

* Save summary moments for the growth variable
quietly summarize growth_rate_annual
local mean_growth = r(mean)
local sd_growth   = r(sd)
local min_growth  = r(min)
local max_growth  = r(max)
local n_growth    = r(N)

* Save summary moments for GDP per capita
quietly summarize gdp_per_capita_thousands
local mean_gdp = r(mean)
local sd_gdp   = r(sd)
local min_gdp  = r(min)
local max_gdp  = r(max)
local n_gdp    = r(N)

* Save summary moments for population
quietly summarize population_millions
local mean_pop = r(mean)
local sd_pop   = r(sd)
local min_pop  = r(min)
local max_pop  = r(max)
local n_pop    = r(N)

* Save summary moments for savings
quietly summarize savings_share_percent
local mean_save = r(mean)
local sd_save   = r(sd)
local min_save  = r(min)
local max_save  = r(max)
local n_save    = r(N)

* Save summary moments for human capital
quietly summarize human_capital_index
local mean_hc = r(mean)
local sd_hc   = r(sd)
local min_hc  = r(min)
local max_hc  = r(max)
local n_hc    = r(N)

* Save summary moments for the main explanatory variable
quietly summarize lag_ideology_shift_magnitude
local mean_shift = r(mean)
local sd_shift   = r(sd)
local min_shift  = r(min)
local max_shift  = r(max)
local n_shift    = r(N)

restore

clear
set obs 6         // Build a small dataset that can be exported cleanly to Word
generate str40 variable_name = ""
generate mean = .
generate sd = .
generate min = .
generate max = .
generate n = .

replace variable_name = "Annual GDP per capita growth (%)" in 1
replace mean = `mean_growth' in 1
replace sd   = `sd_growth' in 1
replace min  = `min_growth' in 1
replace max  = `max_growth' in 1
replace n    = `n_growth' in 1

replace variable_name = "GDP per capita (thousand 2017 USD)" in 2
replace mean = `mean_gdp' in 2
replace sd   = `sd_gdp' in 2
replace min  = `min_gdp' in 2
replace max  = `max_gdp' in 2
replace n    = `n_gdp' in 2

replace variable_name = "Population (millions)" in 3
replace mean = `mean_pop' in 3
replace sd   = `sd_pop' in 3
replace min  = `min_pop' in 3
replace max  = `max_pop' in 3
replace n    = `n_pop' in 3

replace variable_name = "Savings share of GDP (%)" in 4
replace mean = `mean_save' in 4
replace sd   = `sd_save' in 4
replace min  = `min_save' in 4
replace max  = `max_save' in 4
replace n    = `n_save' in 4

replace variable_name = "Human capital index" in 5
replace mean = `mean_hc' in 5
replace sd   = `sd_hc' in 5
replace min  = `min_hc' in 5
replace max  = `max_hc' in 5
replace n    = `n_hc' in 5

replace variable_name = "Lagged ideology-shift magnitude" in 6
replace mean = `mean_shift' in 6
replace sd   = `sd_shift' in 6
replace min  = `min_shift' in 6
replace max  = `max_shift' in 6
replace n    = `n_shift' in 6

format mean sd min max %9.3f
format n %12.0fc

putdocx clear
putdocx begin
putdocx paragraph, halign(center)
putdocx text ("Table 1. Summary Statistics for the Representative Year `representative_year'"), bold
putdocx paragraph
putdocx text ("Representative year: `representative_year'. This year is used because it has the maximum number of usable observations in the final parliamentary-democracy analysis sample. The table reports the mean, standard deviation, minimum, maximum, and number of observations for the outcome and explanatory variables used in the paper, using non-logged variables only."), italic
putdocx table sumstats = data(variable_name mean sd min max n), varnames
putdocx save "${tabledir}/01_descriptive_statistics.docx", replace
// Export the representative-year summary table as a Word document

use "${processed}/main_democracy_panel.dta", clear

**********
* Figures
**********

* Bucket shift magnitudes so the descriptive figure compares no, small, medium, and large shifts
generate shift_size_group = .
replace shift_size_group = 0 if lag_ideology_shift_magnitude == 0 & analysis_sample == 1
replace shift_size_group = 1 if lag_ideology_shift_magnitude > 0 & lag_ideology_shift_magnitude < 0.5 & analysis_sample == 1
replace shift_size_group = 2 if lag_ideology_shift_magnitude >= 0.5 & lag_ideology_shift_magnitude < 1 & analysis_sample == 1
replace shift_size_group = 3 if lag_ideology_shift_magnitude >= 1 & analysis_sample == 1

label define shift_size_lbl 0 "No shift" 1 "Small shift" 2 "Medium shift" 3 "Large shift"
label values shift_size_group shift_size_lbl

preserve
keep if analysis_sample == 1 & !missing(shift_size_group, growth_rate_annual)
collapse (mean) mean_growth = growth_rate_annual (sd) sd_growth = growth_rate_annual (count) n_growth = growth_rate_annual, by(shift_size_group)
generate se_growth = sd_growth / sqrt(n_growth)
generate lb_growth = mean_growth - 1.96 * se_growth
generate ub_growth = mean_growth + 1.96 * se_growth
format mean_growth %4.2f

* First descriptive figure: annual growth falls as ideology shifts become larger, with uncertainty shown explicitly
twoway ///
    (rcap ub_growth lb_growth shift_size_group, lcolor(navy)) ///
    (scatter mean_growth shift_size_group, mcolor(navy) msymbol(circle) msize(medlarge) ///
        mlabel(mean_growth) mlabposition(12) mlabcolor(black) mlabsize(small)), ///
    xlabel(0 "No shift" 1 "Small shift" 2 "Medium shift" 3 "Large shift", angle(0)) ///
    xscale(range(-0.15 3.15)) ///
    ylabel(-2(1)6, angle(0) grid) ///
    xtitle("") ///
    ytitle("Mean annual GDP per capita growth (%)") ///
    title("Figure 1: Mean Annual GDP per Capita Growth by Ideology-Shift Size", size(small)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(fig01, replace)
restore

graph export "${figdir}/fig01_growth_by_shift_size.png", name(fig01) replace

preserve
keep if analysis_sample == 1
tempfile base_events event_years
save `base_events'

keep if lag_shift_large_event == 1
keep iso year
rename year event_year
save `event_years'

use `base_events', clear
joinby iso using `event_years'
generate event_time = year - event_year
keep if inrange(event_time, -2, 2)
collapse (mean) mean_growth = growth_rate_annual (sd) sd_growth = growth_rate_annual (count) n_growth = growth_rate_annual, by(event_time)
generate se_growth = sd_growth / sqrt(n_growth)
generate lb_growth = mean_growth - 1.96 * se_growth
generate ub_growth = mean_growth + 1.96 * se_growth

* Event-time figure shows whether weaker annual growth is concentrated around large political realignments
twoway ///
    (rcap ub_growth lb_growth event_time, lcolor(maroon)) ///
    (connected mean_growth event_time, lcolor(maroon) mcolor(maroon) msymbol(circle) lwidth(medthick)), ///
    xlabel(-2(1)2, angle(0)) ///
    ylabel(-2(1)6, angle(0) grid) ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    xtitle("Years relative to the year after a large ideology shift") ///
    ytitle("Mean annual GDP per capita growth (%)") ///
    title("Figure 2: Mean Annual GDP per Capita Growth over Event Time", size(small)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(fig02, replace)
restore

graph export "${figdir}/fig02_growth_around_large_shift.png", name(fig02) replace

* Build rolling political-instability measures for descriptive support figures
forvalues lag = 0/4 {
    capture drop ideology_score_l`lag'
    generate ideology_score_l`lag' = L`lag'.government_ideology_score
}

capture drop ideology_volatility_5y
egen ideology_volatility_5y = rowsd(ideology_score_l0 ideology_score_l1 ideology_score_l2 ideology_score_l3 ideology_score_l4)
label var ideology_volatility_5y "Five-year ideology volatility"

forvalues lag = 0/2 {
    capture drop shift_size_l`lag'
    generate shift_size_l`lag' = L`lag'.ideology_shift_magnitude
}

capture drop cumulative_shift_3y
egen cumulative_shift_3y = rowtotal(shift_size_l0 shift_size_l1 shift_size_l2)
label var cumulative_shift_3y "Three-year cumulative ideology movement"

capture drop wealth_group
xtile wealth_group = lag_log_gdp_per_capita if analysis_sample == 1 ///
    & !missing(ideology_volatility_5y, growth_rate_annual, lag_log_gdp_per_capita), nq(3)
label define wealth_lbl 1 "Lower-income country-years" 2 "Middle-income country-years" 3 "Higher-income country-years", replace
label values wealth_group wealth_lbl

drop ideology_score_l0 ideology_score_l1 ideology_score_l2 ideology_score_l3 ideology_score_l4
drop shift_size_l0 shift_size_l1 shift_size_l2

* Supportive scatter plot: political instability and annual growth
quietly regress growth_rate_annual ideology_volatility_5y if analysis_sample == 1 ///
    & !missing(ideology_volatility_5y, growth_rate_annual)
local fig03_slope = _b[ideology_volatility_5y]
local fig03_effect01 = 0.1 * `fig03_slope'

twoway ///
    (scatter growth_rate_annual ideology_volatility_5y if analysis_sample == 1 & wealth_group == 1 ///
        & !missing(ideology_volatility_5y, growth_rate_annual), ///
        mcolor(maroon%50) msymbol(circle) msize(vsmall)) ///
    (scatter growth_rate_annual ideology_volatility_5y if analysis_sample == 1 & wealth_group == 2 ///
        & !missing(ideology_volatility_5y, growth_rate_annual), ///
        mcolor(gold%50) msymbol(circle) msize(vsmall)) ///
    (scatter growth_rate_annual ideology_volatility_5y if analysis_sample == 1 & wealth_group == 3 ///
        & !missing(ideology_volatility_5y, growth_rate_annual), ///
        mcolor(forest_green%50) msymbol(circle) msize(vsmall)) ///
    (lfit growth_rate_annual ideology_volatility_5y if analysis_sample == 1 ///
        & !missing(ideology_volatility_5y, growth_rate_annual), ///
        lcolor(black) lwidth(medthick)), ///
    xlabel(0(.1)1.1, angle(0)) ///
    xtitle("Five-year ideology volatility") ///
    ytitle("Annual GDP per capita growth (%)") ///
    title("Figure 3: Annual Growth and Five-Year Ideology Volatility", size(small)) ///
    text(28 0.67 "Slope = `: display %4.2f `fig03_slope'' pp per 1.0 volatility", ///
        place(e) size(small) color(black)) ///
    text(25.2 0.67 "Per +0.1 volatility: `: display %4.2f `fig03_effect01'' pp", ///
        place(e) size(small) color(black)) ///
    legend(order(1 "Lower-income country-years" 2 "Middle-income country-years" 3 "Higher-income country-years" 4 "Fitted line") ///
        cols(1) ring(0) pos(11)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(fig03, replace)

graph export "${figdir}/fig03_political_instability_scatter.png", name(fig03) replace

* Histogram compares annual growth in high-instability and low-instability parliamentary country-years
quietly summarize ideology_volatility_5y if analysis_sample == 1, detail
local volatility_cutoff = r(p50)

quietly summarize growth_rate_annual if analysis_sample == 1, detail
local hist_lb = r(p1)
local hist_ub = r(p99)

quietly summarize growth_rate_annual if analysis_sample == 1 & ideology_volatility_5y >= `volatility_cutoff' ///
    & inrange(growth_rate_annual, `hist_lb', `hist_ub')
local high_instability_mean = r(mean)
local high_instability_sd = r(sd)
local high_instability_n = r(N)
local high_instability_se = `high_instability_sd' / sqrt(`high_instability_n')
local high_instability_lb = `high_instability_mean' - 1.96 * `high_instability_se'
local high_instability_ub = `high_instability_mean' + 1.96 * `high_instability_se'

quietly summarize growth_rate_annual if analysis_sample == 1 & ideology_volatility_5y < `volatility_cutoff' ///
    & inrange(growth_rate_annual, `hist_lb', `hist_ub')
local low_instability_mean = r(mean)
local low_instability_sd = r(sd)
local low_instability_n = r(N)
local low_instability_se = `low_instability_sd' / sqrt(`low_instability_n')
local low_instability_lb = `low_instability_mean' - 1.96 * `low_instability_se'
local low_instability_ub = `low_instability_mean' + 1.96 * `low_instability_se'

local hist_text_x = `hist_ub' - 0.35
local hist_text_y1 = 7.7
local hist_text_y2 = 7.1
local hist_text_y3 = 6.4
local hist_text_y4 = 5.8

twoway ///
    (histogram growth_rate_annual if analysis_sample == 1 & ideology_volatility_5y >= `volatility_cutoff' ///
        & inrange(growth_rate_annual, `hist_lb', `hist_ub'), ///
        width(0.5) percent color(maroon%80) lcolor(maroon)) ///
    (histogram growth_rate_annual if analysis_sample == 1 & ideology_volatility_5y < `volatility_cutoff' ///
        & inrange(growth_rate_annual, `hist_lb', `hist_ub'), ///
        width(0.5) percent color(navy%80) lcolor(navy)), ///
    xline(`high_instability_mean', lcolor(maroon) lpattern(dash)) ///
    xline(`low_instability_mean', lcolor(navy) lpattern(dash)) ///
    legend(order(1 "High ideology volatility" 2 "Low ideology volatility") cols(1) ring(0) pos(11)) ///
    xscale(range(`hist_lb' `hist_ub')) ///
    xtitle("Annual GDP per capita growth (%)") ///
    ytitle("Percent of country-years") ///
    title("Appendix Figure A1: Annual Growth by Political Instability Regime", size(small)) ///
    text(`hist_text_y1' `hist_text_x' "Mean (low): `: display %4.2f `low_instability_mean''", place(w) size(small) color(navy)) ///
    text(`hist_text_y2' `hist_text_x' "CI (low): [`: display %4.2f `low_instability_lb'', `: display %4.2f `low_instability_ub'']", place(w) size(small) color(navy)) ///
    text(`hist_text_y3' `hist_text_x' "Mean (high): `: display %4.2f `high_instability_mean''", place(w) size(small) color(maroon)) ///
    text(`hist_text_y4' `hist_text_x' "CI (high): [`: display %4.2f `high_instability_lb'', `: display %4.2f `high_instability_ub'']", place(w) size(small) color(maroon)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(figA1, replace)

graph export "${figdir}/figA1_growth_by_instability_regime.png", name(figA1) replace

}

**********************************
* Regression appropriateness tests
**********************************

* Explicit pooled model with country dummies to test whether country fixed effects matter jointly.
quietly regress growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.panel_id i.year if analysis_sample == 1, vce(cluster panel_id)
display "Joint significance test for country fixed effects"
testparm i.panel_id

* FE version for the Hausman comparison.
quietly xtreg growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe
estimates store fe_test

* RE version for the Hausman comparison.
quietly xtreg growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, re
estimates store re_test

* If FE is preferred, we keep country fixed effects in the main model.
display "Hausman test for country fixed effects"
hausman fe_test re_test, sigmamore

* This tests whether year dummies add explanatory power.
quietly xtreg growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe
display "Joint significance test for year fixed effects"
testparm i.year

* This checks whether the FE residuals are heteroskedastic across panels.
quietly xtreg growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe
display "Modified Wald test for heteroskedasticity"
xttest3

* This checks whether serial correlation is present in the panel errors.
display "Wooldridge test for serial correlation"
xtserial growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    if analysis_sample == 1

* The quadratic term is tested, but we keep it out unless it clearly helps the model and story.
quietly xtreg growth_rate_annual lag_ideology_shift_magnitude lag_ideology_shift_squared ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe
display "Test of the quadratic ideology-shift term"
test lag_ideology_shift_squared
local quadratic_p = r(p)
display "Quadratic ideology-shift term p-value = " %6.4f `quadratic_p'
display "Preferred specification keeps the quadratic term? No"

******************************
* Stepwise fixed-effects table
******************************

* Column 1: main explanatory variable only plus fixed effects.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store model1

* Column 2: add the convergence control.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude lag_log_gdp_per_capita ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store model2

* Column 3: add savings.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude lag_log_gdp_per_capita ///
    log_savings_share i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store model3

* Column 4: add human capital.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude lag_log_gdp_per_capita ///
    log_savings_share log_human_capital i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store model4

* Column 5: add population growth for the full preferred FE specification.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude lag_log_gdp_per_capita ///
    log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store model5

* Export the stepwise table that shows the main coefficient as controls are added.
quietly etable, estimates(model1 model2 model3 model4 model5) ///
    mstat(N) ///
    mstat(r2) ///
    keep(lag_ideology_shift_magnitude lag_log_gdp_per_capita log_savings_share ///
         log_human_capital population_growth) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 2. Stepwise Fixed-Effects Regressions of Annual Growth on Ideology Shifts") ///
    export("${tabledir}/02_stepwise_lagged_shift.docx", replace)

*****************
* Threshold table
*****************

* This tests whether or not the growth penalty comes from large shifts rather than minor cabinet drift
quietly xtpcse growth_rate_annual lag_shift_small_event lag_shift_medium_event lag_shift_large_event ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store threshold_model

quietly etable, estimates(threshold_model) ///
    mstat(N) ///
    mstat(r2) ///
    keep(lag_shift_small_event lag_shift_medium_event lag_shift_large_event ///
         lag_log_gdp_per_capita log_savings_share log_human_capital population_growth) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 3. Threshold Regressions for Small, Medium, and Large Ideology Shifts") ///
    export("${tabledir}/03_shift_thresholds.docx", replace)

********************************
* Fixed-effects robustness table
********************************

* Winsorize the key regression variables at the 1st and 99th percentiles for robustness
quietly {
foreach var in growth_rate_annual lag_ideology_shift_magnitude lag_log_gdp_per_capita ///
               log_savings_share log_human_capital population_growth {
    capture drop `var'_w
    quietly summarize `var' if analysis_sample == 1, detail
    generate `var'_w = `var'
    replace `var'_w = r(p1) if `var'_w < r(p1) & analysis_sample == 1
    replace `var'_w = r(p99) if `var'_w > r(p99) & analysis_sample == 1
}

label var lag_ideology_shift_magnitude_w "Winsorized lagged ideology-shift magnitude"
label var lag_log_gdp_per_capita_w "Winsorized lagged log GDP per capita"
label var log_savings_share_w "Winsorized log savings share of GDP"
label var log_human_capital_w "Winsorized log human capital"
label var population_growth_w "Winsorized population growth (%)"
label var growth_rate_annual_w "Winsorized annual GDP per capita growth (%)"
}

* Preferred FE specification
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store fe_main

* Winsorized version of the preferred FE specification
quietly xtpcse growth_rate_annual_w lag_ideology_shift_magnitude_w ///
    lag_log_gdp_per_capita_w log_savings_share_w log_human_capital_w population_growth_w ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store fe_winsor

* Remove the global financial crisis years to check sensitivity to extreme macro shocks
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1 & !inlist(year, 2008, 2009), het corr(ar1)
estimates store fe_nocrisis

* Event-style treatment to see whether the result is driven by discrete large shifts
quietly xtpcse growth_rate_annual lag_major_shift_event ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store fe_event

quietly etable, estimates(fe_main fe_winsor fe_nocrisis fe_event) ///
    mstat(N) ///
    mstat(r2) ///
    keep(lag_ideology_shift_magnitude lag_ideology_shift_magnitude_w lag_major_shift_event ///
         lag_log_gdp_per_capita lag_log_gdp_per_capita_w ///
         log_savings_share log_savings_share_w ///
         log_human_capital log_human_capital_w ///
         population_growth population_growth_w) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 4. Fixed-Effects Robustness Checks") ///
    export("${tabledir}/04_fe_robustness.docx", replace)

**************************************
* Granger-style reverse-causality test
**************************************

* Does past ideology movement help predict current growth once past growth is controlled for?
quietly xtreg growth_rate_annual ///
    L1.growth_rate_annual L2.growth_rate_annual ///
    L1.ideology_shift_magnitude L2.ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe vce(cluster panel_id)
estimates store granger_growth

display "Granger-style timing test: do lagged ideology shifts help predict current growth?"
test L1.ideology_shift_magnitude L2.ideology_shift_magnitude
local granger_shift_to_growth_p = r(p)
display "Lagged ideology-shift p-value in the growth equation = " %6.4f `granger_shift_to_growth_p'

* Does past growth help predict current ideology movement once past ideology movement is controlled for?
quietly xtreg ideology_shift_magnitude ///
    L1.ideology_shift_magnitude L2.ideology_shift_magnitude ///
    L1.growth_rate_annual L2.growth_rate_annual ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year if analysis_sample == 1, fe vce(cluster panel_id)
estimates store granger_shift

display "Granger-style timing test: does lagged growth help predict current ideology shifts?"
test L1.growth_rate_annual L2.growth_rate_annual
local granger_growth_to_shift_p = r(p)
display "Lagged growth p-value in the ideology-shift equation = " %6.4f `granger_growth_to_shift_p'

quietly etable, estimates(granger_growth granger_shift) ///
    mstat(N) ///
    mstat(r2) ///
    keep(L1.growth_rate_annual L2.growth_rate_annual ///
         L1.ideology_shift_magnitude L2.ideology_shift_magnitude ///
         lag_log_gdp_per_capita log_savings_share log_human_capital population_growth) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 5. Granger-Style Reverse-Causality Checks") ///
    export("${tabledir}/05_granger_reverse_causality.docx", replace)

***********************
* Directional extension
***********************

* split leftward and rightward movement into small, medium, and large bins.
quietly xtpcse growth_rate_annual ///
    lag_small_left_event lag_small_right_event ///
    lag_medium_left_event lag_medium_right_event ///
    lag_large_left_event lag_large_right_event ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store direction_model

quietly etable, estimates(direction_model) ///
    mstat(N) ///
    mstat(r2) ///
    keep(lag_small_left_event lag_small_right_event ///
         lag_medium_left_event lag_medium_right_event ///
         lag_large_left_event lag_large_right_event ///
         lag_log_gdp_per_capita log_savings_share ///
         log_human_capital population_growth) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 6. Directional Extension by Shift Size") ///
    export("${tabledir}/06_directional_extension.docx", replace)

* Distribution + box + mean/95% CI figure for the six directional bins.
quietly {
tempname b V
matrix `b' = e(b)
matrix `V' = e(V)

local b_small_left  = `b'[1, "lag_small_left_event"]
local se_small_left = sqrt(`V'["lag_small_left_event","lag_small_left_event"])
local p_small_left  = 2 * normal(-abs(`b_small_left' / `se_small_left'))

local b_small_right  = `b'[1, "lag_small_right_event"]
local se_small_right = sqrt(`V'["lag_small_right_event","lag_small_right_event"])
local p_small_right  = 2 * normal(-abs(`b_small_right' / `se_small_right'))

local b_medium_left  = `b'[1, "lag_medium_left_event"]
local se_medium_left = sqrt(`V'["lag_medium_left_event","lag_medium_left_event"])
local p_medium_left  = 2 * normal(-abs(`b_medium_left' / `se_medium_left'))

local b_medium_right  = `b'[1, "lag_medium_right_event"]
local se_medium_right = sqrt(`V'["lag_medium_right_event","lag_medium_right_event"])
local p_medium_right  = 2 * normal(-abs(`b_medium_right' / `se_medium_right'))

local b_large_left  = `b'[1, "lag_large_left_event"]
local se_large_left = sqrt(`V'["lag_large_left_event","lag_large_left_event"])
local p_large_left  = 2 * normal(-abs(`b_large_left' / `se_large_left'))

local b_large_right  = `b'[1, "lag_large_right_event"]
local se_large_right = sqrt(`V'["lag_large_right_event","lag_large_right_event"])
local p_large_right  = 2 * normal(-abs(`b_large_right' / `se_large_right'))

local star_small_left  = cond(`p_small_left' < 0.01, "**", cond(`p_small_left' < 0.05, "*", ""))
local star_small_right = cond(`p_small_right' < 0.01, "**", cond(`p_small_right' < 0.05, "*", ""))
local star_medium_left  = cond(`p_medium_left' < 0.01, "**", cond(`p_medium_left' < 0.05, "*", ""))
local star_medium_right = cond(`p_medium_right' < 0.01, "**", cond(`p_medium_right' < 0.05, "*", ""))
local star_large_left  = cond(`p_large_left' < 0.01, "**", cond(`p_large_left' < 0.05, "*", ""))
local star_large_right = cond(`p_large_right' < 0.01, "**", cond(`p_large_right' < 0.05, "*", ""))

preserve
keep if analysis_sample == 1
generate direction_size_group = .
replace direction_size_group = 1 if lag_small_left_event == 1
replace direction_size_group = 2 if lag_small_right_event == 1
replace direction_size_group = 3 if lag_medium_left_event == 1
replace direction_size_group = 4 if lag_medium_right_event == 1
replace direction_size_group = 5 if lag_large_left_event == 1
replace direction_size_group = 6 if lag_large_right_event == 1
keep if direction_size_group < .

set seed 490
generate x_jitter = direction_size_group + runiform() * 0.28 - 0.14

tempfile direction_raw direction_stats direction_means
save `direction_raw'

collapse ///
    (mean) mean_growth = growth_rate_annual ///
    (sd) sd_growth = growth_rate_annual ///
    (count) n_growth = growth_rate_annual ///
    (p10) p10_growth = growth_rate_annual ///
    (p25) q1_growth = growth_rate_annual ///
    (p50) median_growth = growth_rate_annual ///
    (p75) q3_growth = growth_rate_annual ///
    (p90) p90_growth = growth_rate_annual, ///
    by(direction_size_group)

generate se_growth = sd_growth / sqrt(n_growth)
generate ci_lb = mean_growth - 1.96 * se_growth
generate ci_ub = mean_growth + 1.96 * se_growth
save `direction_stats'

use `direction_raw', clear
merge m:1 direction_size_group using `direction_stats', nogen

local fig4_lb = -10
local fig4_ub = 10
local fig4_plot_lb = -11.2
local fig4_plot_ub = 11.2

tempfile direction_rawstats density_all
save `direction_rawstats'

clear
save `density_all', emptyok replace

forvalues g = 1/6 {
    use `direction_rawstats', clear
    keep if direction_size_group == `g' & inrange(growth_rate_annual, `fig4_lb', `fig4_ub')
    keep growth_rate_annual
    kdensity growth_rate_annual, generate(density_y density_val) n(200)
    quietly summarize density_val, meanonly
    generate direction_size_group = `g'
    generate x_left  = direction_size_group - (density_val / r(max)) * 0.30
    generate x_right = direction_size_group + (density_val / r(max)) * 0.30
    keep direction_size_group density_y x_left x_right
    append using `density_all'
    save `density_all', replace
}

use `direction_rawstats', clear
append using `density_all', force

twoway ///
    (scatter growth_rate_annual x_jitter if inrange(growth_rate_annual, `fig4_lb', `fig4_ub'), ///
        mcolor(gs8%20) msymbol(circle) msize(vsmall)) ///
    (rcap p10_growth p90_growth direction_size_group, lcolor(gs6) lwidth(thin)) ///
    (rbar q1_growth q3_growth direction_size_group, barwidth(0.18) fcolor("88 122 160") lcolor("47 79 113")) ///
    (rcap ci_ub ci_lb direction_size_group, lcolor(black) lwidth(medthick)) ///
    (scatter mean_growth direction_size_group, msymbol(circle) msize(medlarge) ///
        mfcolor(white) mlcolor(black) mlwidth(medthick)), ///
    xlabel(1 "Small left" 2 "Small right" 3 "Medium left" 4 "Medium right" 5 "Large left" 6 "Large right", angle(0)) ///
    ylabel(`fig4_lb'(2)`fig4_ub', angle(0) grid) ///
    yscale(range(`fig4_plot_lb' `fig4_plot_ub')) ///
    xtitle("") ///
    ytitle("Annual GDP per capita growth (%)") ///
    title("Figure 4: Annual Growth by Direction and Shift Size", size(small)) ///
    text(10.55 1 "`star_small_left'", place(c) size(medsmall) color(maroon)) ///
    text(10.55 2 "`star_small_right'", place(c) size(medsmall) color(maroon)) ///
    text(10.55 3 "`star_medium_left'", place(c) size(medsmall) color(maroon)) ///
    text(10.55 4 "`star_medium_right'", place(c) size(medsmall) color(maroon)) ///
    text(10.55 5 "`star_large_left'", place(c) size(medsmall) color(maroon)) ///
    text(10.55 6 "`star_large_right'", place(c) size(medsmall) color(maroon)) ///
    legend(order(1 "Raw observations" 2 "10th-90th percentile" 3 "Middle 50%" ///
                 5 "Mean" 4 "95% CI for mean") ///
        cols(1) ring(1) pos(3) size(vsmall)) ///
    note("Note: Categories are based on lagged ideology shifts." ///
         "Red * above the coresponding box plots indicates regression significance at the 5% level.", size(vsmall)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(fig04, replace)
restore

graph export "${figdir}/fig04_directional_coefficients.png", name(fig04) replace
}

***********************
* Appendix subset table
***********************

* All parliamentary democracies.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1, het corr(ar1)
estimates store subset_all

* PR parliamentary democracies only.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1 & pr_democracy == 1, het corr(ar1)
estimates store subset_pr

* Non-PR parliamentary democracies only.
quietly xtpcse growth_rate_annual lag_ideology_shift_magnitude ///
    lag_log_gdp_per_capita log_savings_share log_human_capital population_growth ///
    i.year i.panel_id if analysis_sample == 1 & pr_democracy == 0, het corr(ar1)
estimates store subset_nonpr

quietly etable, estimates(subset_all subset_pr subset_nonpr) ///
    mstat(N) ///
    mstat(r2) ///
    keep(lag_ideology_shift_magnitude lag_log_gdp_per_capita log_savings_share ///
         log_human_capital population_growth) ///
    varlabel ///
    showstars showstarsnote ///
    title("Table 7. Appendix Subset Comparison by Electoral System") ///
    export("${tabledir}/07_subset_appendix.docx", replace)

capture log close _all
