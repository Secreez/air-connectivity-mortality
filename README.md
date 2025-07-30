# Early Air Connectivity & Excess Mortality

*Exploratory correlation study for a BSc thesis (University of Salzburg)*

## Research question

> Among continental EUROCONTROL member states, is a higher volume of direct inbound flights from China/Hong Kong/Macao (Dec 2019 & Mar 2020) associated with higher cumulative excess mortality on 5 May 2020?

We join EUROCONTROL IFR data with OWID’s excess‑mortality series and:
- build country‑level exposure metrics (Dec 19, Mar 20, Dec+Mar; flights per million),  
- compute Spearman ρ for 2020–2023 snapshots,  
- run quick robustness checks (population normalisation, full‑series filter).

Everything is reproducible with **R ≥ 4.4**, **Quarto CLI ≥ 1.6**, and a LaTeX engine (TinyTeX).

## Repository map

```

bachelor-thesis/
├─ data/
│  ├─ raw/                      # original CSV (NOT in Git: \~2 GB EUROCONTROL flights)
│  ├─ processed/                # tidy RDS/CSV created by the pipeline
│  ├─ derived/                  # final data for the manuscript
│  └─ figures/                  # PNGs for the manuscript
├─ R/                           # analysis and package loader
│  ├─ style_all.R
│  ├─ 00_load_libs.R
│  ├─ 01_excess_snapshots.R
│  ├─ 02_flight_filter.R
│  ├─ 02b_flight_opensky.R
│  ├─ 03_merge_exposure.R
│  ├─ 04_population_qc.R
│  ├─ 05_descriptive_plots.R
│  └─ 06_correlation.R
├─ thesis.qmd                   # main manuscript (Quarto)
├─ thesis_ref.bib               # references
├─ _quarto.yml                  # project configuration
└─ README.md                    # you are here

```

Scripts **01–03** create analysis data; notebooks **04–06** generate tables/plots; **thesis.qmd** pulls results into the write‑up.

## System requirements

- **R** ≥ 4.4  
- **Quarto CLI** ≥ 1.6 (`quarto --version`)  
- **LaTeX**: TinyTeX (the build script can install TinyTeX for you)

## Prepare data files (required)

> EUROCONTROL IFR monthly CSV drops are **not** included and must be obtained under EUROCONTROL terms.

Place files exactly like this:

```

data/raw/
├── flight_data/
│   ├── 201912/          # all Dec 2019 IFR CSVs (keep as *.csv.gz)
│   └── 202003/          # all Mar 2020 IFR CSVs (keep as *.csv.gz)
├── OurAirports/
│   └── airports.csv
├── owid/
│   └── owid-covid-data.csv
└── Opensky/
    └── flightlist_x_x.csv

```

**Do not unzip or rename** the EUROCONTROL `.csv.gz` files.

## Quick start

Open a terminal in the project root and run:

```bash
# Optional one-time LaTeX setup if you don't have it:
INSTALL_TINYTEX=1 ./build.sh

# Build everything (HTML site + PDF):
./build.sh
```

What happens:

* The script checks required files/folders,
* restores exact R packages via **renv** (`renv.lock`),
* runs preprocessing notebooks,
* renders the manuscript site **and** the PDF.

**Targets you can use:**

```bash
./build.sh all    # default; site + PDF
./build.sh pdf    # just the PDF (thesis.qmd)
./build.sh html   # just the HTML site + notebooks
./build.sh clean  # remove caches and previous outputs
```

## View results

* **Site (HTML):** `_manuscript/index.html`
* **PDF:** `_manuscript/thesis.pdf`
* **Build logs:** `_manuscript/logs/`

> **Note:** Don’t use RStudio’s “Render” button. Always use `./build.sh` so data checks and `renv::restore()` run.

## Reproducibility

* Package versions and sources are pinned in **`renv.lock`**.
* The build script runs `renv::restore()` automatically; no manual installs needed.
* Quarto caching (`freeze: auto`) accelerates full‑project renders; it is *not* a substitute for the lockfile.

## Data sources

| Dataset                                                    | Licence        | Link                                                                                                                                         |
| ---------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| EUROCONTROL ATM flight records (research release)          | © EUROCONTROL¹ | [https://www.eurocontrol.int](https://www.eurocontrol.int)                                                                                   |
| Crowdsourced air traffic data – The OpenSky Network (2020) | Custom²        | [https://zenodo.org/records/7923702](https://zenodo.org/records/7923702)                                                                     |
| Excess mortality (HMD‑STMF + WMD via OWID)                 | CC‑BY‑4.0      | [https://ourworldindata.org/excess-mortality-covid](https://ourworldindata.org/excess-mortality-covid)                                       |
| UN World Population Prospects 2024 (mid‑2020 snapshot)     | CC‑BY‑3.0 IGO  | [https://population.un.org/wpp/](https://population.un.org/wpp/) — R pkg: [https://github.com/PPgp/wpp2024](https://github.com/PPgp/wpp2024) |
| OurAirports reference                                      | CC0            | [https://ourairports.com](https://ourairports.com)                                                                                           |

¹ EUROCONTROL data are not redistributed here; copy monthly drops into `data/raw/flight_data/YYYYMM/` before rendering.
² OpenSky data are for research only; redistribution of raw files is not permitted.

## Licence & reuse

* **Code:** MIT (see `LICENSE`).
* **Text & figures:** CC‑BY 4.0 unless stated otherwise.
* Processed data inherit upstream licences; please attribute sources when reusing.

*Last updated: 2025‑07‑27*
Maintainer: Maximilian Elixhauser — [maximilian.elixhauser@stud.plus.ac.at](mailto:maximilian.elixhauser@stud.plus.ac.at)
