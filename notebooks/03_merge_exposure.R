#!/usr/bin/env Rscript
# Takes the country‐level flight exposures (from 02) and the OWID snapshots (from 01),
# maps ISO‐2 → ISO‐3, merge them together, QC for exactly four snapshots per country,
# and export both:
# - analysis_df.{csv,rds} (full join: exposures + mortality)
# - flight_exposure_mapped.{csv,rds} (exposures only, plus ISO3)
# Usage: Rscript notebooks/03_merge_exposure.R
source(here::here("R", "00_load_libs.R"))

# Read in processed tables
flights_country <- read_rds(here::here("data", "processed", "flights_country.rds"))
owid_snapshots <- read_rds(here::here("data", "processed", "owid_excess_snapshots.rds"))
euro_map <- read_csv(
  here::here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)

# Merge flights → ISO3 mapping
flight_exposure_mapped <- flights_country %>%
  left_join(euro_map, by = c("iso_country" = "iso2"))

# warn if any iso2 didn’t match
bad_iso2 <- flight_exposure_mapped %>%
  filter(is.na(iso3)) %>%
  pull(iso_country) %>%
  unique()
if (length(bad_iso2) > 0) {
  warning("Unmapped iso3 for iso2: ", paste(bad_iso2, collapse = ", "))
}

# Merge in the OWID excess‐mortality snapshots
analysis_df <- flight_exposure_mapped %>%
  left_join(owid_snapshots, by = c("iso3" = "iso_code"))

# QC: ensure each iso3 has exactly 4 snapshots
year_counts <- analysis_df %>%
  count(iso3) %>%
  filter(n != 4)
if (nrow(year_counts) > 0) {
  warning(
    "Unexpected snapshot counts for iso3: ",
    paste(year_counts$iso3, collapse = ", ")
  )
}

# Export final analysis table
# so that your QMD can load either the full analysis_df *or* just the exposure
write_rds(
  analysis_df,
  here::here("data", "processed", "analysis_df.rds")
)
write_csv(
  analysis_df,
  here::here("data", "processed", "analysis_df.csv")
)
message("✓ analysis_df written (", nrow(analysis_df), " rows)")

write_rds(
  flight_exposure_mapped,
  here::here("data", "processed", "flight_exposure_mapped.rds")
)
write_csv(
  flight_exposure_mapped,
  here::here("data", "processed", "flight_exposure_mapped.csv")
)
message(
  "✓ flight_exposure_mapped written (",
  nrow(flight_exposure_mapped), " rows)"
)
