#!/usr/bin/env bash
set -euo pipefail
shopt -s failglob

# --- directories -------------------------------------------------------------
RAW=data/raw
FLIGHTS="$RAW/flight_data"
OURAIRPORTS="$RAW/OurAirports"
OWID="$RAW/owid"

# --- helper ------------------------------------------------------------------
timestamp() { date "+%Y-%m-%d %H:%M:%S"; }
step()       { echo -e "\n[$(timestamp)] $*"; }
timer_start(){ _t0=$(date +%s); }
timer_end()  { echo "-> done in $(( $(date +%s) - _t0 )) s"; }

# -----------------------------------------------------------------------------#
step "1 Checking data dependencies"
timer_start

# flight CSVs Dec‑2019 + Mar‑2020
if ! find "$FLIGHTS/201912" -name '*.csv.gz' -print -quit | grep -q . ||
   ! find "$FLIGHTS/202003" -name '*.csv.gz' -print -quit | grep -q .; then
  echo "✗ flight .csv.gz dumps missing in $FLIGHTS/{201912,202003}"
  exit 1
fi

# OurAirports & OWID
for f in "$OURAIRPORTS/airports.csv" "$OWID/owid-covid-data.csv"; do
  [[ -f "$f" ]] || { echo "✗ missing $f"; exit 1; }
done
timer_end

# -----------------------------------------------------------------------------#
step "2 Ensuring R package stack (renv / tinytex)"
timer_start
Rscript R/00_load_libs.R 
Rscript -e 'if (!tinytex::is_tinytex()) tinytex::install_tinytex()'
timer_end

# -----------------------------------------------------------------------------#
step "3 Running preprocessing notebooks"
timer_start
Rscript notebooks/01_excess_snapshots.R
Rscript notebooks/02_flight_filter.R


if [[ -f notebooks/02b_flight_opensky.R ]]; then
  Rscript notebooks/02b_flight_opensky.R
else
  echo " 02b_flight_opensky.R not found – skipping OpenSky coverage audit"
fi

Rscript notebooks/03_merge_exposure.R
timer_end

# -----------------------------------------------------------------------------#
step "4 Rendering Quarto (HTML + PDF)"
timer_start
quarto render
timer_end

# -----------------------------------------------------------------------------#
step "✔ Build complete"
echo "  ↪ HTML: _output/thesis.html"
echo "  ↪  PDF: _output/thesis.pdf"
