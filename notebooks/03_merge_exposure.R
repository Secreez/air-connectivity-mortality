#!/usr/bin/env Rscript
source(file.path("R", "00_load_libs.R"))

## read processed inputs
flights_country <- read_csv("data/processed/flights_country.csv",
                            show_col_types = FALSE)
owid_snapshots <- read_csv("data/processed/owid_snapshots.csv",
                           show_col_types = FALSE)
euro_map <- read_csv("data/eurocontrol_iso_map.csv",
                     show_col_types = FALSE)

## merge flights + ISO map
flight_exposure_mapped <- flights_country |>
  left_join(euro_map,  by = c(iso_country = "iso2"))

if (anyNA(flight_exposure_mapped$iso3)) {
  warn <- flight_exposure_mapped |> filter(is.na(iso3)) |> pull(iso_country) |> unique()
  warning("Unmapped iso3 for: ", paste(warn, collapse = ", "))
}

## merge in mortality snapshots
analysis_df <- flight_exposure_mapped |>
  left_join(owid_snapshots, by = c(iso3 = "iso_code"))

## quick QC: every country exactly 4 rows?
dupes <- analysis_df |> count(iso3) |> filter(n != 4)
if (nrow(dupes) > 0) {
  warning("Uneven year coverage for: ",
          paste(dupes$iso3, collapse = ", "))
}

## write output
write_rds(analysis_df, "data/processed/analysis_df.rds")
message("analysis_df.rds written (", nrow(analysis_df), " rows)")
