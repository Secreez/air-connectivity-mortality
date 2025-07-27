#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Build script for the thesis project (no profiles; always stable config)
# Usage: ./build.sh [all|pdf|html|clean]
#   TARGET : all (default) | pdf | html | clean
#   INSTALL_TINYTEX=1  # (optional) install TinyTeX if LaTeX is missing
# ------------------------------------------------------------------------------

# --- shell --------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'
shopt -s failglob

# --- helpers ------------------------------------------------------------------
timestamp()   { date "+%Y-%m-%d %H:%M:%S"; }
step()        { echo -e "\n[$(timestamp)] $*"; }
timer_start() { _t0=$(date +%s); }
timer_end()   { echo "→ done in $(( $(date +%s) - _t0 )) s"; }

# --- directories --------------------------------------------------------------
RAW="data/raw"
FLIGHTS="$RAW/flight_data"
OURAIRPORTS="$RAW/OurAirports"
OWID="$RAW/owid"

OUTDIR="_manuscript"
LOGDIR="$OUTDIR/logs"
mkdir -p "$LOGDIR"

# --- params -------------------------------------------------------------------
TARGET="${1:-all}"        # pdf|html|all|clean
: "${INSTALL_TINYTEX:=0}" # set to 1 to allow TinyTeX install

# --- 0. Preflight -------------------------------------------------------------
step "0 Preflight"
timer_start
command -v quarto >/dev/null 2>&1 || { echo "✗ Quarto CLI not found in PATH"; exit 127; }
[[ -f "_quarto.yml" || -f "quarto.yml" ]] || { echo "✗ _quarto.yml not found"; exit 1; }
timer_end

# --- 1. Data dependencies -----------------------------------------------------
step "1 Checking data dependencies"
timer_start
# Flight CSVs: Dec‑2019 + Mar‑2020
if ! find "$FLIGHTS/201912" -name '*.csv.gz' -print -quit | grep -q . \
|| ! find "$FLIGHTS/202003" -name '*.csv.gz' -print -quit | grep -q .; then
  echo "✗ flight .csv.gz dumps missing in $FLIGHTS/{201912,202003}"
  exit 1
fi
# OurAirports & OWID
for f in "$OURAIRPORTS/airports.csv" "$OWID/owid-covid-data.csv"; do
  [[ -f "$f" ]] || { echo "✗ missing $f"; exit 1; }
done
timer_end

# --- 2. R stack (renv / TinyTeX) ---------------------------------------------
step "2 Ensuring R package stack (renv / tinytex)"
timer_start
Rscript -e 'if (file.exists("renv.lock")) renv::restore(prompt = FALSE)'
Rscript R/00_load_libs.R || true

if [[ "$INSTALL_TINYTEX" == "1" ]]; then
  Rscript -e 'if (!tinytex::is_tinytex()) tinytex::install_tinytex()'
fi

# Non-fatal environment diagnostics
quarto check || true
timer_end

# --- 3. Preprocessing notebooks ----------------------------------------------
step "3 Running preprocessing notebooks"
timer_start
Rscript notebooks/01_excess_snapshots.R
Rscript notebooks/02_flight_filter.R

if [[ -f notebooks/02b_flight_opensky.R ]]; then
  Rscript notebooks/02b_flight_opensky.R
else
  echo "i  02b_flight_opensky.R not found – skipping OpenSky coverage audit"
fi

Rscript notebooks/03_merge_exposure.R
timer_end

# --- 4. Render Quarto ---------------------------------------------------------
step "4 Rendering Quarto ($TARGET)"
timer_start
logfile="$LOGDIR/render_$(date +%F_%H-%M-%S).log"

case "$TARGET" in
  clean)
    # Remove Quarto / knitr caches
    rm -rf _freeze .quarto/_freeze .knit_cache cache .Rproj.user
    # Remove generated outputs in _manuscript/, but keep logs/
    if [[ -d "$OUTDIR" ]]; then
      find "$OUTDIR" -mindepth 1 -maxdepth 1 ! -name 'logs' -exec rm -rf {} +
    fi
    ;;
  pdf)
    quarto render thesis.qmd --to pdf 2>&1 | tee "$logfile"
    ;;
  html)
    quarto render --to html 2>&1 | tee "$logfile"
    ;;
  all)
    # Render everything configured in _quarto.yml (HTML site + PDF)
    quarto render 2>&1 | tee "$logfile"
    ;;
  *)
    echo "Usage: ./build.sh [all|pdf|html|clean]"; exit 2;;
esac
timer_end

#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Build script for the thesis project (no profiles; always stable config)
# Usage: ./build.sh [all|pdf|html|clean]
#   TARGET : all (default) | pdf | html | clean
#   INSTALL_TINYTEX=1  # (optional) install TinyTeX if LaTeX is missing
# ------------------------------------------------------------------------------

# --- shell --------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'
shopt -s failglob

# --- helpers ------------------------------------------------------------------
timestamp()   { date "+%Y-%m-%d %H:%M:%S"; }
step()        { echo -e "\n[$(timestamp)] $*"; }
timer_start() { _t0=$(date +%s); }
timer_end()   { echo "→ done in $(( $(date +%s) - _t0 )) s"; }

# --- directories --------------------------------------------------------------
RAW="data/raw"
FLIGHTS="$RAW/flight_data"
OURAIRPORTS="$RAW/OurAirports"
OWID="$RAW/owid"

OUTDIR="_manuscript"
LOGDIR="$OUTDIR/logs"
mkdir -p "$LOGDIR"

# --- params -------------------------------------------------------------------
TARGET="${1:-all}"        # pdf|html|all|clean
: "${INSTALL_TINYTEX:=0}" # set to 1 to allow TinyTeX install

# --- 0. Preflight -------------------------------------------------------------
step "0 Preflight"
timer_start
command -v quarto >/dev/null 2>&1 || { echo "✗ Quarto CLI not found in PATH"; exit 127; }
[[ -f "_quarto.yml" || -f "quarto.yml" ]] || { echo "✗ _quarto.yml not found"; exit 1; }
timer_end

# --- 1. Data dependencies -----------------------------------------------------
step "1 Checking data dependencies"
timer_start
# Flight CSVs: Dec‑2019 + Mar‑2020
if ! find "$FLIGHTS/201912" -name '*.csv.gz' -print -quit | grep -q . \
|| ! find "$FLIGHTS/202003" -name '*.csv.gz' -print -quit | grep -q .; then
  echo "✗ flight .csv.gz dumps missing in $FLIGHTS/{201912,202003}"
  exit 1
fi
# OurAirports & OWID
for f in "$OURAIRPORTS/airports.csv" "$OWID/owid-covid-data.csv"; do
  [[ -f "$f" ]] || { echo "✗ missing $f"; exit 1; }
done
timer_end

# --- 2. R stack (renv / TinyTeX) ---------------------------------------------
step "2 Ensuring R package stack (renv / tinytex)"
timer_start
Rscript -e 'if (file.exists("renv.lock")) renv::restore(prompt = FALSE)'
Rscript R/00_load_libs.R || true

if [[ "$INSTALL_TINYTEX" == "1" ]]; then
  Rscript -e 'if (!tinytex::is_tinytex()) tinytex::install_tinytex()'
fi

# Non-fatal environment diagnostics
quarto check || true
timer_end

# --- 3. Preprocessing notebooks ----------------------------------------------
step "3 Running preprocessing notebooks"
timer_start
Rscript notebooks/01_excess_snapshots.R
Rscript notebooks/02_flight_filter.R

if [[ -f notebooks/02b_flight_opensky.R ]]; then
  Rscript notebooks/02b_flight_opensky.R
else
  echo "i  02b_flight_opensky.R not found – skipping OpenSky coverage audit"
fi

Rscript notebooks/03_merge_exposure.R
timer_end

# --- 4. Render Quarto ---------------------------------------------------------
step "4 Rendering Quarto ($TARGET)"
timer_start
logfile="$LOGDIR/render_$(date +%F_%H-%M-%S).log"

case "$TARGET" in
  clean)
    # Remove Quarto / knitr caches
    rm -rf _freeze .quarto/_freeze .knit_cache cache .Rproj.user
    # Remove generated outputs in _manuscript/, but keep logs/
    if [[ -d "$OUTDIR" ]]; then
      find "$OUTDIR" -mindepth 1 -maxdepth 1 ! -name 'logs' -exec rm -rf {} +
    fi
    ;;
  pdf)
    quarto render thesis.qmd --to pdf 2>&1 | tee "$logfile"
    ;;
  html)
    quarto render --to html 2>&1 | tee "$logfile"
    ;;
  all)
    # Render everything configured in _quarto.yml (HTML site + PDF)
    quarto render 2>&1 | tee "$logfile"
    ;;
  *)
    echo "Usage: ./build.sh [all|pdf|html|clean]"; exit 2;;
esac
timer_end

# --- 5. Done ------------------------------------------------------------------
if [[ "$TARGET" == "clean" ]]; then
  step "✔ Clean complete"
  if compgen -G "${LOGDIR}/*.log" > /dev/null; then
    echo "↪ Logs kept in ${LOGDIR}/"
  else
    echo "↪ No logs found yet. Next builds will write to ${LOGDIR}/"
  fi
  exit 0
fi

step "✔ Build complete"
echo "↪ Site: ${OUTDIR}/index.html"
if [[ -f ${OUTDIR}/thesis.pdf ]]; then
  echo "↪  PDF: ${OUTDIR}/thesis.pdf"
elif [[ -f thesis.pdf ]]; then
  echo "↪  PDF: $(pwd)/thesis.pdf"
else
  echo "↪  PDF: (not found) – check render logs under ${LOGDIR}/"
fi


step "✔ Build complete"
echo "↪ Site: ${OUTDIR}/index.html"
if [[ -f ${OUTDIR}/thesis.pdf ]]; then
  echo "↪  PDF: ${OUTDIR}/thesis.pdf"
elif [[ -f thesis.pdf ]]; then
  echo "↪  PDF: $(pwd)/thesis.pdf"
else
  echo "↪  PDF: (not found) – check render logs under ${LOGDIR}/"
fi
