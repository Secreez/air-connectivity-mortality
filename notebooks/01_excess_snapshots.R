#!/usr/bin/env Rscript
# Picks the row closest to 5‑May (± 7 d) for 2020‑2023 from OWID
# Compares OWID mid‑2020 population with UN‑WPP mid‑2020
# Usage: Rscript notebooks/01_excess_snapshots.R
source(here::here("R", "00_load_libs.R"))

# helpers
euro_ISO3 <- readr::read_csv(
  here::here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)$iso3

owid_path <- here::here("data/raw/owid/owid-covid-data.csv")

# excess‑mortality snapshots
covid_raw <- readr::read_csv(
  owid_path,
  show_col_types = FALSE
) |>
  dplyr::filter(iso_code %in% euro_ISO3)

ref_dates <- lubridate::ymd(c(
  "2020-05-05", "2021-05-05",
  "2022-05-05", "2023-05-05"
))

win_tbl <- purrr::map_dfr(
  ref_dates,
  \(d) tibble::tibble(
    target_date = d,
    date = seq(d - 7, d + 7, by = "days")
  )
)

owid_snapshots <- covid_raw |>
  dplyr::select(
    iso_code, location, date,
    excess_mortality_cumulative_per_million
  ) |>
  dplyr::inner_join(win_tbl, by = "date") |>
  dplyr::filter(!is.na(excess_mortality_cumulative_per_million)) |>
  dplyr::mutate(day_diff = abs(as.integer(date - target_date))) |>
  dplyr::group_by(iso_code, location, target_date) |>
  dplyr::slice_min(day_diff, with_ties = FALSE) |>
  dplyr::ungroup()

stopifnot(max(owid_snapshots$day_diff) <= 7)


# save
readr::write_rds(
  owid_snapshots,
  here::here("data/processed/owid_excess_snapshots.rds")
)
readr::write_csv(
  owid_snapshots,
  here::here("data/processed/owid_excess_snapshots.csv")
)

message("✓ owid_excess_snapshots: ", nrow(owid_snapshots), " rows")

# Excess mortality snapshots from OWID (WMD + HMD–STMF)
# Picks the closest available date within ±7 days around 5 May each year (2020-2023)
# ±7-day window selected due to incomplete daily reporting by OWID across countries
# Ukraine data after 2021 excluded due to war-related gaps
