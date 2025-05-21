#!/usr/bin/env Rscript
# Takes the country‐level flight exposures (from 02) and the OWID snapshots (from 01),
# maps ISO‐2 → ISO‐3, merge them together, QC for exactly four snapshots per country,
# and exports both:
# - analysis_df.{csv,rds} (full join: exposures + mortality)
# - flight_exposure_mapped.{csv,rds} (exposures only, plus ISO3)
# Usage: Rscript notebooks/03_merge_exposure.R
source(here::here("R", "00_load_libs.R"))

# read
flights_country <- read_rds(here("data", "processed", "flights_country.rds"))
owid_snapshots <- read_rds(here("data", "processed", "owid_excess_snapshots.rds"))

euro_map <- read_csv(
  here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)

# iso-2 → iso-3 mapping for flight exposure
flight_exposure_mapped <- flights_country |>
  left_join(euro_map, by = c(iso_country = "iso2"))

unmapped <- flight_exposure_mapped |> filter(is.na(iso3))
stopifnot(nrow(unmapped) == 0) # fail loud if any iso-2 not mapped

# merge in OWID snapshots (four per country)
analysis_df <- flight_exposure_mapped |>
  left_join(owid_snapshots, by = c(iso3 = "iso_code"))

bad_year_cov <- analysis_df |>
  count(iso3) |>
  filter(n != 4)
if (nrow(bad_year_cov) > 0) {
  warning(
    "Countries with <> 4 snapshots: ",
    paste(bad_year_cov$iso3, collapse = ", ")
  )
}

# export
write_rds(analysis_df, here("data", "processed", "analysis_df.rds"))
write_csv(analysis_df, here("data", "processed", "analysis_df.csv"))
write_rds(flight_exposure_mapped, here("data", "processed", "flight_exposure_mapped.rds"))
write_csv(flight_exposure_mapped, here("data", "processed", "flight_exposure_mapped.csv"))

message("✓ analysis_df: ", nrow(analysis_df), " rows")
message("✓ flight_exposure_mapped: ", nrow(flight_exposure_mapped), " rows")

# Rationale:
# May 5 was chosen as the annual reference point for excess-mortality snapshots, as it marks
# both the aftermath of the first major European COVID-19 wave (2020) and, notably, the official
# WHO declaration of the end of the public health emergency on 5 May 2023.
# This enables a four-year annual comparison, capturing the entire period of COVID-19 pandemic
