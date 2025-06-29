#!/bin/bash
set -euo pipefail
shopt -s failglob

RAW=data/raw
FLIGHTS="$RAW/flight_data"
OURAIRPORTS="$RAW/OurAirports"
OWID="$RAW/owid"

log_time() {
  END=$(date +%s)
  ELAPSED=$((END-START))
  echo "$1 took ${ELAPSED} seconds."
}

echo "Checking data dependencies..."
START=$(date +%s)

if ! find "$FLIGHTS/201912" -name '*.csv.gz' -print -quit | grep -q . && \
   ! find "$FLIGHTS/202003" -name '*.csv.gz' -print -quit | grep -q .; then
  echo "ERROR: No .csv.gz files found..."
  exit 1
fi

if [ ! -f "$OURAIRPORTS/airports.csv" ]; then
  echo "ERROR: airports.csv not found in $OURAIRPORTS"
  exit 1
fi

if [ ! -f "$OWID/owid-covid-data.csv" ]; then
  echo "ERROR: owid-covid-data.csv not found in $OWID"
  exit 1
fi

log_time "Data dependency check"

echo "Checking/Installing R packages..."
START=$(date +%s)
Rscript R/00_load_libs.R
log_time "R package check/install"

echo "Running data preprocessing (01-03)..."
START=$(date +%s)
Rscript notebooks/01_excess_snapshots.R || { echo "ERROR: 01_excess_snapshots.R failed"; exit 1; }
Rscript notebooks/02_flight_filter.R     || { echo "ERROR: 02_flight_filter.R failed"; exit 1; }
Rscript notebooks/03_merge_exposure.R    || { echo "ERROR: 03_merge_exposure.R failed"; exit 1; }
log_time "Preprocessing scripts"

echo "Rendering the Quarto project..."
START=$(date +%s)
quarto render
log_time "Quarto render"

echo "All done. Manuscript and notebooks built successfully."
echo "Open _manuscript/index.html in your browser to view the main manuscript."