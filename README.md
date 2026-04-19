# Long-Term Growth Effects of Ideological Turnover in Parliamentary Democracies

This repository contains the full working project for an ECON 490 seminar paper on whether ideological turnover in government is associated with weaker subsequent economic growth in parliamentary democracies.

The paper combines macroeconomic data from the Penn World Table with cabinet ideology and institutional data from the Comparative Political Data Set (CPDS). The main empirical finding is that larger lagged ideology shifts are associated with lower next-year GDP per capita growth, with the strongest penalties concentrated in larger ideological realignments. Additional specifications examine threshold effects, robustness, Granger causality, directionality, and heterogeneity by electoral system.

## Repository Contents

### Main paper
- [`8. Paper/Final Paper.docx`](./8.%20Paper/Final%20Paper.docx): final written paper

### Data
- [`1. Data/pwt110.dta`](./1.%20Data/pwt110.dta): Penn World Table 11.0
- [`1. Data/CPDS_1960-2023_Update_2025.dta`](./1.%20Data/CPDS_1960-2023_Update_2025.dta): Comparative Political Data Set
- [`1. Data/processed`](./1.%20Data/processed): cleaned intermediate files created by the Stata workflow

### Stata replication files
- [`2. do-files/Econometric File.do`](./2.%20do-files/Econometric%20File.do): annotated do-file that cleans the data, constructs the variables, runs the models, and exports the final tables and figures
- [`3. log-files/Econometric File.log`](./3.%20log-files/Econometric%20File.log): final log file from the compact replication run

### Output tables
- [`4. Tables`](./4.%20Tables): formatted regression and summary-statistics tables used in the paper

Current table set:
- `01_descriptive_statistics.docx`
- `02_stepwise_lagged_shift.docx`
- `03_shift_thresholds.docx`
- `04_fe_robustness.docx`
- `05_granger_reverse_causality.docx`
- `06_directional_extension.docx`
- `07_subset_appendix.docx`

### Output figures
- [`5. Figures`](./5.%20Figures): exported figures used in the paper

Current figure set:
- `fig01_growth_by_shift_size.png`
- `fig02_growth_around_large_shift.png`
- `fig03_political_instability_scatter.png`
- `fig04_directional_coefficients.png`
- `figA1_growth_by_instability_regime.png`

### Background literature and project materials
- [`6. Team 14 papers`](./6.%20Team%2014%20papers): papers collected for the literature review and project development
- [`7. Other relevant papers`](./7.%20Other%20relevant%20papers): supporting literature
- [`Meeting Minutes`](./Meeting%20Minutes): project planning records

## Empirical Workflow

The Stata workflow does the following:

1. Cleans and prepares the Penn World Table growth variables.
2. Cleans the CPDS government and institutional variables.
3. Constructs the ideology-shift, threshold, directional, and volatility measures.
4. Merges the macroeconomic and political data into the final panel.
5. Produces descriptive statistics and figures.
6. Runs the diagnostic tests for fixed effects, heteroskedasticity, serial correlation, and nonlinearity.
7. Estimates the main and extension models.
8. Exports the final regression tables, figures, and log file.

## Main Specifications

The project estimates a sequence of related models:

- Stepwise two-way fixed-effects regressions with annual GDP per capita growth as the dependent variable
- Threshold regressions for small, medium, and large ideology shifts
- Fixed-effects robustness checks using winsorisation, crisis exclusions, and event-style coding
- Granger-causality tests
- Directional regressions separating leftward and rightward shifts by size
- Subsample regressions by electoral system

For the main paper tables, the preferred estimator is a Prais-Winsten-style panel regression with panel-corrected standard errors that allow for heteroskedasticity across panels and AR(1) serial correlation within panels.

## How to Reproduce the Results

1. Open Stata.
2. Set the working directory to the repository root if needed.
3. Run:

```stata
do "2. do-files/Econometric File.do"
```

The do-file is set up to recreate the processed data, final tables, figures, and the final log file.

## Data Sources

- Feenstra, Robert C., Robert Inklaar, and Marcel P. Timmer. 2025. *Penn World Table 11.0*.
- Armingeon, Klaus, Sarah Engler, Lucas Leemann, and David Weisstanner. 2025. *Comparative Political Data Set 1960-2023*.

## Notes

- The repository reflects the final project structure used for the seminar submission.
- The root-level folders are organized to match the paper workflow: raw data, Stata scripts, logs, exported tables, exported figures, and final written outputs.
- The final log file was compacted so that the replication record stays readable while still preserving the core estimation and test workflow.
