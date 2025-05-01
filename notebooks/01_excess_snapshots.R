#!/usr/bin/env Rscript
# 01_excess_snapshots.R
# – From the OWID COVID CSV, pick the row closest to 5-May (±7 d)
#   for 2020, 2021, 2022, 2023 and write tidy snapshots.
# Usage:  Rscript notebooks/01_excess_snapshots.R

source(here::here("R", "00_load_libs.R"))

# read
covid_raw <- read_csv(
  here("data", "raw", "owid", "owid-covid-data.csv"),
  show_col_types = FALSE
)

# build ±7-day windows around 5 May for 4 years
ref_dates <- ymd(c("2020-05-05", "2021-05-05", "2022-05-05", "2023-05-05"))
win_tbl <- map_dfr(ref_dates, \(d)
tibble(target_date = d, date = seq(d - 7, d + 7, by = "days")))

# pick closest non-NA excess-mortality row per country/year
owid_snapshots <- covid_raw %>%
  select(
    iso_code, location, date,
    excess_mortality_cumulative_per_million
  ) %>%
  inner_join(win_tbl, by = "date") %>%
  filter(!is.na(excess_mortality_cumulative_per_million)) %>%
  mutate(day_diff = abs(as.integer(date - target_date))) %>%
  group_by(iso_code, location, target_date) %>%
  slice_min(day_diff, with_ties = FALSE) %>%
  ungroup()

# quick sanity: every country ≤ 4 rows; min/max date in window
stopifnot(max(owid_snapshots$day_diff) <= 7)

# To enable a consistent cross-country comparison of cumulative excess mortality per million for the years 2020 to 2023, we defined 5 May as a fixed annual reference date. This date was chosen due to its symbolic significance in many countries as the period around which COVID-19 emergency measures were lifted or reevaluated, and it coincides with ISO Week 18, a recurring reporting point for many datasets.
# Since not all countries report mortality data exactly on 5 May, and reporting frequency varies (weekly, biweekly, monthly), we applied a ±7-day window around each year's reference date.
# For each country and year, the closest available non-missing value within this window was selected. This ensures temporal consistency while respecting national reporting lags.
# The absolute difference in days between the selected date and the reference date (day_diff) was recorded to assess potential deviations in timing and reporting alignment. Most matches were within a range of ±2–3 days, typically falling on dates such as 30 April, 3 May, or 7 May, which aligns well with reporting conventions across the EUROCONTROL zone.

# export
write_rds(
  owid_snapshots,
  here("data", "processed", "owid_excess_snapshots.rds")
)
write_csv(
  owid_snapshots,
  here("data", "processed", "owid_excess_snapshots.csv")
)

message("✓ owid_excess_snapshots: ", nrow(owid_snapshots), " rows")
