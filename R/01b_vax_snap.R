#!/usr/bin/env Rscript
# 01b_extract_vax.R  – pull “people_fully_vaccinated_per_hundred”
# for each EUROCONTROL country closest to 5 May 2022 (± 7 days)
source(here::here("R", "00_load_libs.R"))

EURO_ISO3 <- read_csv(
  here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)$iso3

OWID_PATH <- here("data/raw/owid/owid-covid-data.csv")
STOP_GAP <- 7
REF_DATE <- ymd("2022-05-05")


vax_snap <- read_csv(
  OWID_PATH,
  col_types = cols_only(
    iso_code = col_character(),
    date = col_date(),
    people_fully_vaccinated_per_hundred = col_double()
  ),
  show_col_types = FALSE
) |>
  filter(
    iso_code %in% EURO_ISO3,
    date >= REF_DATE - STOP_GAP,
    date <= REF_DATE + STOP_GAP,
    !is.na(people_fully_vaccinated_per_hundred)
  ) |>
  group_by(iso_code) |>
  slice_min(abs(date - REF_DATE), with_ties = FALSE) |>
  ungroup() |>
  transmute(
    iso3     = iso_code,
    vax_2022 = people_fully_vaccinated_per_hundred
  )

proc_dir <- here("data/processed")
write_rds(vax_snap, file.path(proc_dir, "vax_snapshot.rds"))
write_csv(vax_snap, file.path(proc_dir, "vax_snapshot.csv"))

missing <- setdiff(EURO_ISO3, vax_snap$iso3)
if (length(missing)) {
  warning(
    "no vaccination row within ±", STOP_GAP,
    " d for: ", paste(missing, collapse = ", ")
  )
}

message("✓ vax_snapshot: ", nrow(vax_snap), " rows written")
