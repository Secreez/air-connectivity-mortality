# Early Air Connectivity & Excess Mortality  

*Exploratory correlation study for a BSc thesis (University of Salzburg)*

## Research idea

> **Question** Did European countries that received **more direct flights from  
> Mainland China / Hong Kong in Dec 2019 & Mar 2020** suffer *higher* excess-
> mortality during the first COVID-19 wave (May 2020)?

We join EUROCONTROL IFR data with OWID’s excess-mortality series and:

* build country-level exposure metrics (Dec 19, Mar 20, Dec+Mar, flights / million);  
* compute Spearman ρ for 2020 – 2023 snapshots;  
* run quick robustness checks (population normalisation, full-series filter).

Everything is reproducible with **R ≥ 4.4** and **Quarto ≥ 1.6**.


## Repository map

```
bachelor-thesis/
├─ data/
│  ├─ raw/                      # original CSV (NOT in Git: \~2 GB EUROCONTROL flights)
│  ├─ processed/                # tidy RDS/CSV created by the pipeline
│  └─ figures/                  # PNGs for the manuscript
├─ notebooks/                   # analysis notebooks + tiny R scripts
│  ├─ 01\_excess\_snapshots.R
│  ├─ 02\_flight\_filter.R
│  ├─ 03\_merge\_exposure.R
│  ├─ 04\_population\_qc.qmd
│  ├─ 05\_descriptive\_plots.qmd
│  └─ 06\_correlation.qmd
├─ R/                           # helper functions & QA scripts
├─ thesis.qmd                   # main manuscript (Quarto)
├─ thesis\_ref.bib              # references
├─ \_quarto.yml                 # project configuration (pre-render, render list, theme…)
└─ README.md                    # you are here

```

Scripts **01-03** create the analysis data; notebooks **04-06** generate all
tables and plots; **thesis.qmd** pulls results into the write-up.

## How to run

All R packages are installed by `R/00_load_libs.R`.
If you start from a fresh machine:
(Careful, this will install all CRAN and GitHub dependencies, check the script!)

```r
source("R/00_load_libs.R") # downloads CRAN + GitHub deps, then library()
```

```bash
# clone repo, put EUROCONTROL CSVs under data/raw/, then…
quarto render
```

Quarto will:

1. run the three *Rscript* pre-processing steps and the code styler (see `_quarto.yml: pre-render`);
2. render the three notebooks to HTML (linked under **"Notebooks"**);
3. knit **thesis.html**.

## Data sources

| Dataset                                                    | Licence        | Link                                                                                                                                         |
| ---------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| EUROCONTROL ATM flight records (research release)          | © EUROCONTROL¹ | [https://www.eurocontrol.int](https://www.eurocontrol.int)                                                                                   |
| Excess-mortality (HMD-STMF + WMD via OWID)                 | CC-BY-4.0      | [https://ourworldindata.org/excess-mortality-covid](https://ourworldindata.org/excess-mortality-covid)                                       |
| UN World Population Prospects 2024 (mid-2020 snapshot)     | CC-BY-3.0 IGO  | [https://population.un.org/wpp/](https://population.un.org/wpp/) — R pkg: [https://github.com/PPgp/wpp2024](https://github.com/PPgp/wpp2024) |
| OurAirports reference                                      | CC0            | [https://ourairports.com](https://ourairports.com)                                                                                           |

¹EUROCONTROL data are not redistributed here; copy the CSV drops (“Research
Repository”) into `data/raw/flight_data/YYYYMM/` before rendering. If you have access to [the R&D programme](https://www.eurocontrol.int/dashboard/aviation-data-research).

## Reuse

Code is MIT-licensed (see `LICENSE`).
Figures and processed data inherit the licences of their upstream sources
please credit them when you reuse.

*Last updated 2025-06-04*   —  Maintainer: Maximilian Elixhauser
[maximilian.elixhauser@stud.plus.ac.at](mailto:maximilian.elixhauser@stud.plus.ac.at)