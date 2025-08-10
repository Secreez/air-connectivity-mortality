#!/usr/bin/env Rscript
# Takes the country‐level flight exposures (from 02) and the OWID snapshots (from 01),
# maps ISO‐2 → ISO‐3, merge them together, QC for exactly four snapshots per country,
# and exports both:
# - analysis_df.{csv,rds} (full join: exposures + mortality)
# - flight_exposure_mapped.{csv,rds} (exposures only, plus ISO3)

# !/usr/bin/env Rscript
source(here::here("R", "00_load_libs.R"))

EXCLUDE_ISO3 <- c("UKR")

# read
flights_country <- readr::read_rds(here::here("data", "processed", "flights_country.rds"))
owid_snapshots <- readr::read_rds(here::here("data", "processed", "owid_excess_snapshots.rds"))
euro_map <- readr::read_csv(here::here("data", "eurocontrol_iso_map.csv"), show_col_types = FALSE)

# map ISO-2 → ISO-3, then drop excluded countries for the analysis panel
flight_exposure_mapped <- flights_country |>
  dplyr::left_join(euro_map, by = c(iso_country = "iso2")) |>
  dplyr::filter(!iso3 %in% EXCLUDE_ISO3)

# build analysis panel (4 rows per country; one per target_date)
analysis_df <- flight_exposure_mapped |>
  dplyr::left_join(owid_snapshots, by = c(iso3 = "iso_code")) |>
  dplyr::filter(!is.na(target_date))

# hard checks
stopifnot(dplyr::n_distinct(analysis_df$iso3) == 25)
stopifnot(all(table(analysis_df$iso3) == 4))

readr::write_rds(analysis_df, here::here("data", "processed", "analysis_df.rds"))
readr::write_csv(analysis_df, here::here("data", "processed", "analysis_df.csv"))
readr::write_rds(flight_exposure_mapped, here::here("data", "processed", "flight_exposure_mapped.rds"))
readr::write_csv(flight_exposure_mapped, here::here("data", "processed", "flight_exposure_mapped.csv"))

message("✓ analysis_df: ", nrow(analysis_df), " rows (25 countries × 4 years)")

# Rationale:
# May 5 was chosen as the annual reference point for excess-mortality snapshots, as it marks
# both the aftermath of the first major European COVID-19 wave (2020) and, notably, the official
# WHO declaration of the end of the public health emergency on 5 May 2023.
# This enables a four-year annual comparison, capturing the entire period of COVID-19 pandemic
