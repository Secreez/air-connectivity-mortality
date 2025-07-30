#!/usr/bin/env Rscript
# Compare OWID "population" vs WPP baseline anchored to start-2020.
# (wpp2024 pop1dt uses Dec-31 of year t, so year==2019 ≈ start-2020.)
# Outputs:
#   data/processed/pop_comparison_2020.csv
#   data/derived/pop_comparison_2020.rds
#   data/derived/pop_big_gaps_2020.{csv,rds}

source("R/00_load_libs.R", chdir = TRUE)

EURO_ISO <- readr::read_csv(
  here::here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)$iso3

DIFF_LIMIT <- 0.10
PROC_DIR <- here::here("data", "processed")
DER_DIR <- here::here("data", "derived")
dir.create(PROC_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(DER_DIR, showWarnings = FALSE, recursive = TRUE)

# WPP baseline: pop1dt[2019] ~ start-2020 level
suppressPackageStartupMessages(data(pop1dt, package = "wpp2024"))
pop_wpp20 <- pop1dt |>
  dplyr::filter(year == 2019) |>
  dplyr::mutate(
    iso3 = countrycode(
      name, "country.name", "iso3c",
      custom_match = c("Czechia" = "CZE", "Türkiye" = "TUR", "United Kingdom" = "GBR"),
      warn = FALSE
    )
  ) |>
  dplyr::filter(iso3 %in% EURO_ISO) |>
  dplyr::transmute(iso3, pop_wpp = pop * 1e3)

# OWID snapshot: constrain to 2020
pop_owid20 <- readr::read_csv(
  here::here("data", "raw", "owid", "owid-covid-data.csv"),
  col_select = c(iso_code, date, population),
  col_types = readr::cols(
    iso_code = readr::col_character(),
    date = readr::col_date(),
    population = readr::col_double()
  ),
  show_col_types = FALSE
) |>
  dplyr::filter(
    lubridate::year(date) == 2020,
    iso_code %in% EURO_ISO,
    !is.na(population)
  ) |>
  dplyr::group_by(iso3 = iso_code) |>
  dplyr::slice_max(date, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::transmute(iso3, pop_owid = population)

# Compare + persist
pop_comp <- dplyr::inner_join(pop_wpp20, pop_owid20, by = "iso3") |>
  dplyr::mutate(rel_diff = (pop_owid - pop_wpp) / pop_wpp)

readr::write_csv(pop_comp, file.path(PROC_DIR, "pop_comparison_2020.csv"))
saveRDS(pop_comp, file.path(DER_DIR, "pop_comparison_2020.rds"))

big_gaps <- pop_comp |>
  dplyr::filter(abs(rel_diff) > DIFF_LIMIT) |>
  dplyr::mutate(pct = scales::percent(rel_diff, accuracy = 0.1))

readr::write_csv(big_gaps, file.path(DER_DIR, "pop_big_gaps_2020.csv"))
saveRDS(big_gaps, file.path(DER_DIR, "pop_big_gaps_2020.rds"))

if (nrow(big_gaps) == 0) {
  say("✔ OWID and WPP within ±", round(DIFF_LIMIT * 100), "% for all EUROCONTROL states (start-2020 anchor).")
} else {
  msg <- paste0(
    "! Gap >", round(DIFF_LIMIT * 100),
    "% for: ", paste(big_gaps$iso3, collapse = ", "),
    " (table saved to data/derived/pop_big_gaps_2020.*)"
  )
  if (strict) stop(msg) else warning(msg)
}
