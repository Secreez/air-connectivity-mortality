#!/usr/bin/env bash
set -euo pipefail
mkdir -p logs

log_and_run () {
  local label="$1"; shift
  echo "$label"
  "$@" 2>&1 | tee "logs/${label}.log"
  local status=${PIPESTATUS[0]}
  if [[ $status -ne 0 ]]; then
    echo " $label FAILED (exit $status) — see logs/${label}.log"
    exit $status
  fi
}

log_and_run "style_all" Rscript style_all.R

echo " Cleaning processed outputs"
rm -rf data/processed/* data/figures/* notebooks/*_cache

# ...

echo "Pipeline finished without errors."
