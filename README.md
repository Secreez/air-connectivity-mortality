# Early Air Connectivity & Excess Mortality

*Exploratory correlation study for a BSc thesis (University of Salzburg)*

## Research question

> Among continental EUROCONTROL states, did higher volumes of **direct inbound flights from China/Hong Kong** (Dec 2019 & Mar 2020) associate with higher **excess mortality** on **5 May 2020**?

We join EUROCONTROL IFR snapshots with OWID/WMD, then:

* build country-level exposure metrics (Dec-2019, Mar-2020, Dec+Mar; also flights-per-million),
* compute **Spearman ρ** for 2020–2023 with bootstrap CIs,
* run sensitivity checks (population scaling; complete 4-year mortality series; partial ρ by %≥65).

Everything is reproducible with **R ≥ 4.4**, **Quarto ≥ 1.6**, and a LaTeX engine.

## Requirements

* **R** ≥ 4.4
* **Quarto CLI** ≥ 1.6 (`quarto --version`)
* **LaTeX** (TinyTeX recommended)

> This repo **vendors** the Elsevier Quarto template in `_extensions/` (MIT). No manual install needed.
> If you clone without `_extensions/`, run: `quarto add quarto-journals/elsevier`.

## Data (bring your own)

EUROCONTROL IFR monthly CSV drops are **not** distributed here.

```
data/raw/
├── flight_data/
│   ├── 201912/          # all Dec 2019 *.csv.gz
│   └── 202003/          # all Mar 2020 *.csv.gz
├── OurAirports/         # reference airport list
│   └── airports.csv
└── owid/
    └── owid-covid-data.csv
```

> Keep EUROCONTROL files **compressed** (`*.csv.gz`) and original filenames.

## Quick start

```bash
# Optional: install TinyTeX if you don’t have LaTeX
INSTALL_TINYTEX=1 ./build.sh

# Build site + PDF (default)
./build.sh

# Or individual targets
./build.sh html      # Elsevier HTML
./build.sh pdf       # Elsevier PDF
./build.sh clean     # clear caches and outputs
```

What the script does:

1. checks data dependencies,
2. restores exact packages via **renv** (from `renv.lock`),
3. runs preprocessing scripts in `R/`,
4. renders **Elsevier** outputs (HTML + PDF).

### Render manually (optional)

```bash
quarto render thesis.qmd --to elsevier-html
quarto render thesis.qmd --to elsevier-pdf
```

## Repository map

```
bachelor-thesis/
├─ data/
│  ├─ raw/            # (you provide)
│  ├─ processed/      # created by scripts
│  ├─ derived/        # tables used in the paper
│  └─ figures/        # PNG/PDF figures
├─ R/
│  ├─ 00_load_libs.R
│  ├─ 01_excess_snapshots.R
│  ├─ 01b_vax_snap.R
│  ├─ 02_flight_filter.R
│  ├─ 02b_flight_opensky.R
│  ├─ 03_merge_exposure.R
│  ├─ 04_population_qc.R
│  ├─ 05_descriptive_plots.R
│  └─ 06_correlation.R
├─ thesis.qmd
├─ thesis_ref.bib
├─ _quarto.yml
├─ _extensions/       # vendored Elsevier template (MIT)
└─ build.sh
```

## Outputs

* **HTML site:** `_manuscript/index.html`
* **PDF:** `_manuscript/thesis.pdf`
* **Logs:** `_manuscript/logs/`

> Tip: avoid RStudio’s “Render” button. Use `./build.sh` so checks and `renv::restore()` run.

## Reproducibility

* Package versions are pinned in **`renv.lock`**.
* Quarto caching (`freeze: auto`) speeds re-runs but the lockfile is the source of truth.
* Scripts are idempotent; delete `data/processed`/`data/derived` to rebuild.

## Data sources

| Dataset                                                | Licence        | Link                                                                                                                                         |
| ------------------------------------------------------ | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| EUROCONTROL ATM flight records (research release)      | © EUROCONTROL¹ | [https://www.eurocontrol.int](https://www.eurocontrol.int)                                                                                   |
| OpenSky crowdsourced air-traffic data (2020)           | Research only² | [https://zenodo.org/records/7923702](https://zenodo.org/records/7923702)                                                                     |
| Excess mortality (HMD-STMF + WMD via OWID)             | CC-BY-4.0      | [https://ourworldindata.org/excess-mortality-covid](https://ourworldindata.org/excess-mortality-covid)                                       |
| UN World Population Prospects 2024 (mid-2020 snapshot) | CC-BY-3.0 IGO  | [https://population.un.org/wpp/](https://population.un.org/wpp/) (R pkg: [https://github.com/PPgp/wpp2024](https://github.com/PPgp/wpp2024)) |
| OurAirports reference                                  | CC0            | [https://ourairports.com](https://ourairports.com)                                                                                           |

¹ Not redistributed; copy monthly drops to `data/raw/flight_data/YYYYMM/`.
² Redistribution of raw OpenSky files is not permitted.

## License

* **Code:** MIT
* **Text & figures:** CC-BY 4.0
* **Processed data:** inherit upstream licences; attribute sources when reusing.

*Maintainer:* Maximilian Elixhauser — [maximilian.elixhauser@stud.plus.ac.at](mailto:maximilian.elixhauser@stud.plus.ac.at)
*Last updated:* 2025-10-10