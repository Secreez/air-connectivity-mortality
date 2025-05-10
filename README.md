# Early Air Connectivity & Excess Mortality

### Exploratory correlation analysis for a Bachelor thesis (University of Salzburg)

## Project idea

> **Research question**
> *Did European countries that received more direct inbound flights from Mainland China, Hong Kong, and Macao in **Dec 2019 / Mar 2020** experience higher excess-mortality burdens during the first four pandemic years?*

We link EUROCONTROL flight records to Our World in Data’s excess-mortality series and produce:

- descriptive flight plots (barplot, choropleth, great-circle flow map)
- Spearman rank correlations for four May snapshots (2020-2023)
- robustness checks (flights / million, P-scores, small-state exclusion)

Everything is reproducible and tested in **R 4.5.0** package stack see: `...`

## Directory layout

This repository is organized as follows:

```         
bachelor-thesis/
├─ archive/ # old proposals & drafts
├─ data/ 
│ ├─ raw/ # untouched source files 
│ ├─ processed/ # tidy outputs (CSV/RDS) 
│ └─ figures/ # PNG/PDF figures used in the thesis 
├─ notebooks/ # analysis notebooks & build scripts 
│ ├─ 01_excess_snapshots.R 
│ ├─ 02_flight_filter.R 
│ ├─ 03_merge_exposure.R 
│ ├─ 04_descriptive_plots.qmd 
│ └─ 05_correlation.qmd 
├─ R/ # QA scripts & functions
├─ thesis.qmd # main write-up (Quarto)
├─ thesis_ref.bib # references (BibTeX)
├─ _quarto.yml # Quarto config
├─ run_pipeline.sh # bash script to run the pipeline
├─ style_all.R # styler for all scripts
└─ README.md
```

Scripts **01-03** build the data; notebooks **04-05** make the figures and correlation tables.

## Quick start

```bash
#!/usr/bin/env bash
set -euo pipefail # abort on any error

# clone and cd …

# DATA BUILD
Rscript notebooks/01_excess_snapshots.R
Rscript notebooks/02_flight_filter.R
Rscript notebooks/03_merge_exposure.R

# PLOTS & CORRELATIONS
quarto render notebooks/04_descriptive_plots.qmd
quarto render notebooks/05_correlation.qmd

# COMPILE THESIS
quarto render thesis.qmd
```

> **Note:** EUROCONTROL flight CSVs (\~2 GB) are **not** tracked by Git.\
> Place them under `data/raw/flight_data/YYYYMM/` as described in *02_flight_filter.R*.

## Main data sources

| dataset | license | link |
|---------------------------|---------------------------|------------------|
| EUROCONTROL ATM historical flights | © EUROCONTROL (research use) | <https://www.eurocontrol.int> |
| Excess-mortality (HMD STMF + WMD via OWID) | CC-BY 4.0 | <https://ourworldindata.org/excess-mortality-covid> |
| OurAirports reference | CC0 | <https://ourairports.com> |
| Natural-Earth shapes | Public Domain | <https://www.naturalearthdata.com> |

## Re-use

All code is released under the .. License Figures and processed CSVs inherit the licenses of their upstream data providers—please credit them when re-using.

*Last updated: 24 Apr 2025*
*Maintainer: Maximilian Elixhauser – maximilian.elixhauser@stud.plus.ac.at*
