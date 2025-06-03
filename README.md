# Early Air Connectivity & Excess Mortality

### Exploratory correlation analysis for a Bachelor thesis (University of Salzburg)

## Project overview

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
│ ├─ 04_population_qc.qmd
│ ├─ 05_descriptive_plots.qmd 
│ └─ 06_correlation.qmd 
├─ R/ # QA scripts & functions
├─ thesis.qmd # main write-up (Quarto)
├─ thesis_ref.bib # references (BibTeX)
├─ _quarto.yml # Quarto config
├─ style_all.R # styler for all scripts
└─ README.md
```

Scripts **01-03** build the data; notebooks **04-05** make the figures and correlation tables.

## Quick start

```

```

> **Note:** EUROCONTROL flight CSVs (\~2 GB) are **not** tracked by Git.
> So, place them under `data/raw/flight_data/YYYYMM/` as described in *02_flight_filter.R*.

## Data sources

| Dataset                                                    | Licence        | Link                                                                                                                                         |
| ---------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| EUROCONTROL ATM flight records (research release)          | © EUROCONTROL¹ | [https://www.eurocontrol.int](https://www.eurocontrol.int)                                                                                   |
| Excess-mortality (HMD-STMF + WMD via OWID)                 | CC-BY-4.0      | [https://ourworldindata.org/excess-mortality-covid](https://ourworldindata.org/excess-mortality-covid)                                       |
| **UN World Population Prospects 2024 (mid-2020 snapshot)** | CC-BY-3.0 IGO  | [https://population.un.org/wpp/](https://population.un.org/wpp/) — R pkg: [https://github.com/PPgp/wpp2024](https://github.com/PPgp/wpp2024) |
| OurAirports reference                                      | CC0            | [https://ourairports.com](https://ourairports.com)                                                                                           |
| Natural-Earth vector shapes                                | Public Domain  | [https://www.naturalearthdata.com](https://www.naturalearthdata.com)                                                                         |

¹ EUROCONTROL data are not redistributed here; if you have access for R&D, copy the csv.gz drops into data/raw/flight_data/201912/ and ../202003 before rendering.

## Re-use

Code is MIT-licensed (see `LICENSE`).
Figures and processed data inherit the licences of their upstream sources—
please credit them when you reuse.

*Last updated: 03 June 2025*
*Maintainer: Maximilian Elixhauser – maximilian.elixhauser@stud.plus.ac.at*
