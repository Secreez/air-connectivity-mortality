#!/usr/bin/env Rscript
source(file.path("R", "00_load_libs.R"))

## Load & Prepare Excess Mortality Data (OWID)

# Based on the OWID + WMD/HMD sources, many countries report mortality weekly or monthly.
# To create comparable annual snapshots for 2020–2023, we use a ±7-day window around **5 May**, keeping the **closest non-NA value**.
# Most matched dates fall on `30 April` or `03–07 May`, aligning with ISO Week 18 conventions.


# Load OWID dataset
covid_data <- read_csv("data/raw/owid/owid-covid-data.csv")

# Define target snapshot dates and ±7-day tolerance
target_dates <- ymd(c("2020-05-05", "2021-05-05", "2022-05-05", "2023-05-05"))
tolerance <- 7

# Build ±7-day windows for each target date
expanded_dates <- map_dfr(target_dates, function(date) {
  tibble(
    target_date = date,
    date = seq(date - tolerance, date + tolerance, by = "days")
  )
})

owid_snapshots <- covid_data %>%
  select(iso_code, location, date, excess_mortality_cumulative_per_million) %>%
  inner_join(expanded_dates, by = "date") %>%
  filter(!is.na(excess_mortality_cumulative_per_million)) %>%  # filter out NAs early!
  mutate(day_diff = abs(as.integer(date - target_date))) %>%
  group_by(iso_code, location, target_date) %>%
  slice_min(day_diff, with_ties = FALSE) %>%
  ungroup()

# Sanity Check
owid_snapshots %>%
  count(target_date)

owid_snapshots %>%
  summarise(
    min_date = min(date),
    max_date = max(date)
  )

owid_snapshots %>%
  filter(location %in% c("Germany", "France", "Italy")) %>%
  arrange(location, target_date) %>%
  select(location, target_date, date, day_diff, excess_mortality_cumulative_per_million)

# To enable a consistent cross-country comparison of cumulative excess mortality per million for the years 2020 to 2023, we defined 5 May as a fixed annual reference date. This date was chosen due to its symbolic significance in many countries as the period around which COVID-19 emergency measures were lifted or reevaluated, and it coincides with ISO Week 18, a recurring reporting point for many datasets.
# Since not all countries report mortality data exactly on 5 May, and reporting frequency varies (weekly, biweekly, monthly), we applied a ±7-day window around each year's reference date.
# For each country and year, the closest available non-missing value within this window was selected. This ensures temporal consistency while respecting national reporting lags.
# The absolute difference in days between the selected date and the reference date (day_diff) was recorded to assess potential deviations in timing and reporting alignment. Most matches were within a range of ±2–3 days, typically falling on dates such as 30 April, 3 May, or 7 May, which aligns well with reporting conventions across the EUROCONTROL zone.

## export
write_csv(owid_snapshots,
          "data/processed/owid_excess_snapshots.csv")
write_rds (owid_snapshots,
          "data/processed/owid_excess_snapshots.rds")
message("owid_excess_snapshots written (",
        nrow(owid_snapshots), " rows)")