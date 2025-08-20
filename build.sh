#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-all}"          # pdf | html | all | clean
: "${INSTALL_TINYTEX:=0}"

# --- clean: do first, then exit ---------------------------------------------
if [[ "$TARGET" == "clean" ]]; then
  rm -rf _manuscript _freeze .quarto/_freeze .knit_cache cache .Rproj.user
  echo "✔ Clean complete."
  exit 0
fi

# --- create expected dirs ----------------------------------------------------
mkdir -p data/processed data/derived _manuscript

# --- preflight ---------------------------------------------------------------
command -v Rscript >/dev/null 2>&1 || { echo "✗ Rscript not found in PATH"; exit 127; }
command -v quarto  >/dev/null 2>&1 || { echo "✗ Quarto CLI not found in PATH"; exit 127; }
if [[ ! -d "_extensions/elsevier" && ! -d "_extensions/quarto-journals/elsevier" ]]; then
  echo "i Elsevier extension not found. Run:  quarto add quarto-journals/elsevier"
fi

# --- packages (renv / TinyTeX optional) -------------------------------------
if [[ -f renv.lock ]]; then
  echo "i Using renv.lock to restore package versions"
  Rscript --vanilla -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org"); renv::restore(prompt=FALSE)'
else
  echo "i No renv.lock found — enabling INSTALL_MISSING=1 so 00_load_libs.R can install required packages"
  export INSTALL_MISSING=1
fi

# --- preprocessing (skip missing files) -------------------------------------
for s in \
  R/01_excess_snapshots.R \
  R/02_flight_filter.R \
  R/02b_flight_opensky.R \
  R/03_merge_exposure.R \
  R/04_population_qc.R \
  R/05_descriptive_plots.R \
  R/06_correlation.R
do
  [[ -f "$s" ]] && Rscript --vanilla "$s"
done

# --- render ------------------------------------------------------------------
case "$TARGET" in
  pdf)
    quarto render thesis.qmd --to elsevier-pdf
    echo "↪ PDF: _manuscript/thesis.pdf"
    ;;
  html)
    quarto render thesis.qmd --to elsevier-html
    echo "↪ HTML: _manuscript/index.html"
    ;;
  all)
    # Render both formats declared for thesis.qmd in _quarto.yml
    quarto render thesis.qmd
    echo "↪ HTML: _manuscript/index.html"
    echo "↪  PDF: _manuscript/thesis.pdf"
    ;;
  *)
    echo "Usage: ./build.sh [all|pdf|html|clean]"; exit 2;;
esac

echo "✔ Build complete."
