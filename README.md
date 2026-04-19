# Long-Term Growth Effects of Ideological Turnover in Parliamentary Democracies

This repository contains the final paper, poster, data files, replication code, log file, tables, and figures for an undergraduate applied economics research project on whether larger shifts in governing ideology are associated with weaker subsequent GDP per capita growth in parliamentary democracies.

The paper studies 21 parliamentary democracies from 1962 to 2023 and finds that larger lagged ideology shifts are associated with lower next-year GDP per capita growth. The strongest penalties appear in large ideological realignments rather than routine cabinet drift. The paper also includes robustness checks, a Granger-causality exercise, a directionality extension, and subsample comparisons by electoral system.

## Repository Overview

### Final Paper and Poster
- [`Matthew Lim_Long Term Growth Effect of Ideological Turnover in Parliamentary Democracies.pdf`](./Matthew%20Lim_Long%20Term%20Growth%20Effect%20of%20Ideological%20Turnover%20in%20Parliamentary%20Democracies.pdf): final paper
- [`Ideology Shift Poster.png`](./Ideology%20Shift%20Poster.png): final poster

### Data and replication folders
- [`1. Data`](./1.%20Data): raw and processed data used in the paper
- [`2. do-files`](./2.%20do-files): annotated Stata replication code
- [`3. log-files`](./3.%20log-files): final Stata log from the replication run
- [`4. Tables`](./4.%20Tables): exported regression tables and summary-statistics tables
- [`5. Figures`](./5.%20Figures): exported figures used in the paper

## Main Files

- [`2. do-files/Econometric File.do`](./2.%20do-files/Econometric%20File.do): main Stata do-file
- [`3. log-files/Econometric File.log`](./3.%20log-files/Econometric%20File.log): final compact log file
- [`4. Tables/01_descriptive_statistics.docx`](./4.%20Tables/01_descriptive_statistics.docx)
- [`4. Tables/02_stepwise_lagged_shift.docx`](./4.%20Tables/02_stepwise_lagged_shift.docx)
- [`4. Tables/03_shift_thresholds.docx`](./4.%20Tables/03_shift_thresholds.docx)
- [`4. Tables/04_fe_robustness.docx`](./4.%20Tables/04_fe_robustness.docx)
- [`4. Tables/05_granger_reverse_causality.docx`](./4.%20Tables/05_granger_reverse_causality.docx)
- [`4. Tables/06_directional_extension.docx`](./4.%20Tables/06_directional_extension.docx)
- [`4. Tables/07_subset_appendix.docx`](./4.%20Tables/07_subset_appendix.docx)

## Data Sources

The paper combines two main datasets:

1. **Penn World Table 11.0** for macroeconomic variables, including GDP per capita, savings, human capital, and population.
2. **Comparative Political Data Set 1960-2023** for cabinet ideology and institutional variables used to construct ideology-shift measures and sample restrictions.

Paper-ready data citations:

- Feenstra, Robert C., Robert Inklaar, and Marcel P. Timmer. 2025. *Penn World Table 11.0*. Groningen: Groningen Growth and Development Centre, University of Groningen. [https://doi.org/10.34894/FABVLR](https://doi.org/10.34894/FABVLR)
- Armingeon, Klaus, Sarah Engler, Lucas Leemann, and David Weisstanner. 2025. *Comparative Political Data Set 1960-2023*. Zurich/Lueneburg/Lucerne: University of Zurich, Leuphana University Lueneburg, and University of Lucerne. [https://cpds-data.org/data/](https://cpds-data.org/data/)

## Empirical Workflow

The Stata workflow:

1. Cleans and prepares Penn World Table growth variables.
2. Cleans the CPDS political and institutional variables.
3. Constructs ideology-shift, threshold, directional, and volatility measures.
4. Merges the economic and political data into the final panel.
5. Produces descriptive statistics and figures.
6. Runs fixed-effects, heteroskedasticity, serial-correlation, and nonlinearity diagnostics.
7. Estimates the main and extension regressions.
8. Exports the final tables, figures, and log file.

## Main Models

The project estimates:

- stepwise two-way fixed-effects growth regressions
- threshold regressions for small, medium, and large ideology shifts
- fixed-effects robustness checks using winsorisation, crisis exclusions, and event-style coding
- Granger-causality regressions
- directional regressions separating leftward and rightward shifts by size
- subset regressions by electoral system

For the main regression tables, the preferred estimator is a Prais-Winsten-style panel regression with panel-corrected standard errors that allow for heteroskedasticity across panels and AR(1) serial correlation within panels.

## How to Reproduce the Results

Open Stata in the repository root and run:

```stata
do "2. do-files/Econometric File.do"
```

This reproduces the processed data, exported tables, exported figures, and final log file used in the paper.

## Core References Used in the Paper

The paper's argument is situated in the political economy of growth, policy uncertainty, and ideology literature. Key references include:

- Alesina, Alberto, and Roberto Perotti. 1994. "The Political Economy of Growth: A Critical Survey of the Recent Literature." *World Bank Economic Review* 8 (3): 351-371.
- Alesina, Alberto, Sule Ozler, Nouriel Roubini, and Phillip Swagel. 1996. "Political Instability and Economic Growth." *Journal of Economic Growth* 1 (2): 189-211.
- Baker, Scott R., Nicholas Bloom, and Steven J. Davis. 2016. "Measuring Economic Policy Uncertainty." *Quarterly Journal of Economics* 131 (4): 1593-1636.
- Boix, Carles. 1997. "Political Parties and the Supply Side of the Economy: The Provision of Physical and Human Capital in Advanced Economies, 1960-90." *American Journal of Political Science* 41 (3): 814-845.
- Darby, Julia, Chengwei Li, and Vito A. Muscatelli. 2004. "Political Uncertainty, Public Expenditure and Growth." *European Journal of Political Economy* 20 (1): 153-179.
- Haini, Hazwan, and Pang Wei Loon. 2021. "Does Government Ideology Affect the Relationship Between Government Spending and Economic Growth?" *Economic Papers* 40 (3): 209-225.
- Potrafke, Niklas. 2011. "Does Government Ideology Influence Budget Composition? Empirical Evidence from OECD Countries." *Economics of Governance* 12 (2): 101-134.
- Tavares, Jose. 2004. "Does Right or Left Matter? Cabinets, Credibility and Fiscal Adjustments." *Journal of Public Economics* 88 (12): 2447-2468.

## Notes

- The paper uses annual GDP per capita growth as the dependent variable.
- The main political variable is lagged ideology-shift magnitude.
- The final log file was compacted so that the replication record remains readable while still preserving the key estimation workflow.
