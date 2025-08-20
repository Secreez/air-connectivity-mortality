#!/usr/bin/env bash
set -euo pipefail

mkdir -p data/processed data/derived _manuscript

TARGET="${1:-all}"            # pdf | html | all | clean
: "${INSTALL_TINYTEX:=0}"

# Preflight
command -v quarto  >/dev/null 2>&1 || { echo "✗ Quarto CLI not found in PATH"; exit 127; }
command -v Rscript >/dev/null 2>&1 || { echo "✗ Rscript not found in PATH"; exit 127; }
# (Optional) warn if Elsevier extension missing
if [[ ! -d "_extensions/elsevier" && ! -d "_extensions/quarto-journals/elsevier" ]]; then
  echo "i Elsevier extension not found. Run:  quarto add quarto-journals/elsevier"
fi

# 1) Restore renv if present
if [[ -f renv.lock ]]; then
  Rscript --vanilla -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org"); renv::restore(prompt=FALSE)'
fi

# 2) Optional TinyTeX for PDF
if [[ "$INSTALL_TINYTEX" == "1" ]]; then
  Rscript --vanilla -e 'if (!requireNamespace("tinytex", quietly=TRUE)) install.packages("tinytex", repos="https://cloud.r-project.org"); if (!tinytex::is_tinytex()) tinytex::install_tinytex()'
fi

# 3) Preprocessing (skip if file absent)
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

# 4) Render
case "$TARGET" in
  clean)
    rm -rf _manuscript _freeze .quarto/_freeze .knit_cache cache .Rproj.user
    ;;
  pdf)
    # Use Elsevier PDF format (as defined in _quarto.yml under format: elsevier-pdf)
    quarto render thesis.qmd --to elsevier-pdf
    ;;
  html)
    # Keep your site-style HTML (or switch to --to elsevier-html if you added it)
    quarto render thesis.qmd --to html
    ;;
  all)
    # Builds all formats listed in _quarto.yml (html + elsevier-pdf)
    quarto render
    ;;
  *)
    echo "Usage: ./build.sh [all|pdf|html|clean]"; exit 2;;
esac

echo "✔ Build complete → _manuscript/"
