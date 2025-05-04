#!/usr/bin/env Rscript
# Picks the row closest to 5‑May (± 7 d) for 2020‑2023 from OWID
# Compares OWID mid‑2020 population with UN‑WPP mid‑2020
# Usage: Rscript notebooks/02_flight_filter.R

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

# ─────────────────────────────────────────────────────────────────────────────
# OPTIONAL QC: OWID vs UN‑WPP mid‑2020 population
# ─────────────────────────────────────────────────────────────────────────────
# does NOT feed into the main analysis!

if (interactive()) {
  library(dplyr)
  library(countrycode)
  library(wpp2024)

  # UN‑WPP mid‑2020 population (persons)
  data(pop1dt, package = "wpp2024") # long table, pop in *thousands*

  pop_wpp20 <- pop1dt |>
    filter(year == 2020) |>
    mutate(
      iso3 = countrycode(
        sourcevar = name,
        origin = "country.name",
        destination = "iso3c",
        custom_match = c(
          "Czechia" = "CZE",
          "Türkiye" = "TUR",
          "United Kingdom" = "GBR"
        )
      )
    ) |>
    filter(iso3 %in% euro_ISO3) |>
    transmute(iso3,
      pop_wpp = pop * 1e3
    ) # convert → persons

  # OWID population on 31‑Dec‑2020
  pop_owid20 <- readr::read_csv(
    owid_path,
    show_col_types = FALSE,
    col_select = c(iso_code, date, population)
  ) |>
    filter(
      lubridate::year(date) == 2020,
      iso_code %in% euro_ISO3
    ) |>
    group_by(iso3 = iso_code) |>
    slice_max(date, with_ties = FALSE) |>
    ungroup() |>
    transmute(iso3,
      pop_owid = population
    )

  # join & compare
  pop_comp <- pop_wpp20 |>
    inner_join(pop_owid20, by = "iso3") |>
    mutate(
      abs_diff = pop_owid - pop_wpp,
      rel_diff = abs_diff / pop_wpp
    ) |>
    arrange(desc(abs(rel_diff)))

  # flag any > 1 %
  big_gaps <- filter(pop_comp, abs(rel_diff) > 0.01)

  # write a tiny csv for appendix
  readr::write_csv(
    pop_comp,
    here::here("data/processed/pop_comparison_2020.csv")
  )
}

# Probably something like: 
# “OWID’s 2020 population snapshot differs by less than 10 % from UN WPP 2024 for 37 of 41 Eurocontrol member states; larger gaps for Cyprus, Ukraine, North Macedonia and a few micro‑states reflect boundary or census revisions. [SOURCE!] As the excess‑mortality indicator is already expressed per million using the same OWID denominator, we retained OWID populations for consistency. Re‑computing all correlations with WPP populations changed ρ by < 0.01 (Table X, Appendix).”



