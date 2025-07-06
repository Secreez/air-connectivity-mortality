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
│  ├─ derived/                  # final data for the manuscript
│  └─ figures/                  # PNGs for the manuscript
├─ notebooks/                   # analysis notebooks + tiny R scripts
│  ├─ 01\_excess\_snapshots.R
│  ├─ 02\_flight\_filter.R
│  ├─ 02b\_flight\_opensky.R
│  ├─ 03\_merge\_exposure.R
│  ├─ 04\_population\_qc.qmd
│  ├─ 05\_descriptive\_plots.qmd
│  └─ 06\_correlation.qmd
├─ R/                           # package update scripts
├─ thesis.qmd                   # main manuscript (Quarto)
├─ thesis\_ref.bib              # references
├─ \_quarto.yml                 # project configuration (pre-render, render list, theme…)
└─ README.md                    # you are here

```

Scripts **01-03** create the analysis data; notebooks **04-06** generate all
tables and plots; **thesis.qmd** pulls results into the write-up.

## How to run

### Prepare data files (required for build)

Download/copy the following data to the correct locations in `data/raw/`:

* **EUROCONTROL flights:** Place all `.csv.gz` files from Dec 2019 and Mar 2020 into `data/raw/flight_data/201912/` and `data/raw/flight_data/202003/`
* **OurAirports:** Place `airports.csv` in `data/raw/OurAirports/`
* **OWID:** Place `owid-covid-data.csv` in `data/raw/owid/`
* **Opensky:** Place `flightlist_x_x.csv` in `data/raw/Opensky/`

*(EUROCONTROL files are NOT public—see instructions above.)*

### Build everything

Open a terminal (preferably Git Bash), navigate to the project folder, and run:

```bash
./build.sh
```

The script will:

* Check that all data files are present
* Install R package dependencies if needed
* Run all preprocessing steps and build the manuscript plus supplementary notebooks

### View results

After successful completion, open `_manuscript/index.html` in your web browser to view the main manuscript.
Supplementary HTML notebooks are also in `_manuscript/`.

**Do NOT use RStudio’s “Render” button or `quarto render` directly; always run the provided build script to ensure reproducibility and data checks.**

| Dataset                                                    | Licence        | Link                                                                                                                                         |
| ---------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| EUROCONTROL ATM flight records (research release)          | © EUROCONTROL¹ | [https://www.eurocontrol.int](https://www.eurocontrol.int)                                                                                   |
| Crowdsourced air traffic data from The OpenSky Network 2020| Custom²        | [https://zenodo.org/records/7923702](https://zenodo.org/records/7923702)                                                       |
| Excess-mortality (HMD-STMF + WMD via OWID)                 | CC-BY-4.0      | [https://ourworldindata.org/excess-mortality-covid](https://ourworldindata.org/excess-mortality-covid)                                       |
| UN World Population Prospects 2024 (mid-2020 snapshot)     | CC-BY-3.0 IGO  | [https://population.un.org/wpp/](https://population.un.org/wpp/) — R pkg: [https://github.com/PPgp/wpp2024](https://github.com/PPgp/wpp2024) |
| OurAirports reference                                      | CC0            | [https://ourairports.com](https://ourairports.com)                                                                                           |

¹EUROCONTROL data are not redistributed here; copy the CSV drops (“Research Repository”) into `data/raw/flight_data/YYYYMM/` before rendering. If you have access to [the R&D programme](https://www.eurocontrol.int/dashboard/aviation-data-research).
²OpenSky data is for research only. Redistribution of raw files is not permitted.
## Reuse

Code is MIT-licensed (see `LICENSE`).
Figures and processed data inherit the licences of their upstream sources
please credit them when you reuse.

*Last updated 2025-06-04*   —  Maintainer: Maximilian Elixhauser
[maximilian.elixhauser@stud.plus.ac.at](mailto:maximilian.elixhauser@stud.plus.ac.at)