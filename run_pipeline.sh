#!/usr/bin/env bash
set -euo pipefail

echo "Step 0: Format all R code..."
Rscript style_all.R

echo "Step 1: Clean up old outputs"
rm -rf data/processed/* data/figures/* notebooks/*_cache

echo "Step 2: Run data preparation scripts..."
Rscript notebooks/01_excess_snapshots.R
Rscript notebooks/02_flight_filter.R
Rscript notebooks/03_merge_exposure.R

echo "Step 3: Render analysis notebooks..."
quarto render notebooks/04_descriptive_plots.qmd
quarto render notebooks/05_correlation.qmd

echo "Step 4: Render full thesis..."
quarto render thesis.qmd

echo "Done! All outputs are up-to-date."
