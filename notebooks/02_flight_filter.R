#!/usr/bin/env Rscript
# Filters raw EUROCONTROL data to CN/HK/MO → EUROCONTROL flights,
# builds summary tables and a slim airport lookup.
# Usage: Rscript notebooks/02_flight_filter.R
source(here::here("R", "00_load_libs.R"))

# read
flights_2019_12 <- read_csv(
  here(
    "data", "raw", "flight_data", "201912",
    "Flights_20191201_20191231.csv.gz"
  ),
  show_col_types = FALSE
)
flights_2020_03 <- read_csv(
  here(
    "data", "raw", "flight_data", "202003",
    "Flights_20200301_20200331.csv.gz"
  ),
  show_col_types = FALSE
)

keep_cols <- c(
  "ECTRL ID", "ADEP", "ADES", "ICAO Flight Type",
  "ACTUAL OFF BLOCK TIME", "ACTUAL ARRIVAL TIME"
)

flights_dec19 <- flights_2019_12 %>%
  select(all_of(keep_cols)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

flights_mar20 <- flights_2020_03 %>%
  select(all_of(keep_cols)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

# airport reference (OurAirports)
airports_full <- read_csv(
  here("data", "raw", "OurAirports", "airports.csv"),
  show_col_types = FALSE
) %>%
  select(icao_code, iso_country, name,
    latitude_deg, longitude_deg,
    iata_code = any_of("iata_code")
  )

china_hk_macao_airports <- airports_full %>%
  filter(iso_country %in% c("CN", "HK", "MO")) %>%
  pull(icao_code)

eurocontrol_countries <- read_csv(
  here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
) %>% pull(iso2)

eurocontrol_airports <- airports_full %>%
  filter(iso_country %in% eurocontrol_countries) %>%
  pull(icao_code)

# bind & filter to direct CN/HK/MO → EUROCONTROL
flights_filtered <- bind_rows(
  dec19 = flights_dec19,
  mar20 = flights_mar20,
  .id = "month"
) %>%
  filter(
    ADEP %in% china_hk_macao_airports,
    ADES %in% eurocontrol_airports
  )

# country-level exposure table
flights_country <- flights_filtered %>%
  left_join(airports_full, by = c("ADES" = "icao_code")) %>%
  count(month, iso_country, name = "n_flights") %>%
  pivot_wider(
    names_from = month, values_from = n_flights,
    names_prefix = "total_inbound_flights_", values_fill = 0
  ) %>%
  mutate(
    total_inbound_flights_combined =
      total_inbound_flights_dec19 + total_inbound_flights_mar20
  )

stopifnot(!any(is.na(flights_country$iso_country))) # sanity

# airport-to-airport flow table
flows_pairwise <- flights_filtered %>%
  count(ADEP, ADES, name = "n_flights") %>%
  arrange(desc(n_flights))

# slim airport lookup (destinations + used origins)
needed_icaos <- union(
  unique(flights_filtered$ADEP),
  unique(flights_filtered$ADES)
)

airports_slim <- airports_full %>%
  filter(icao_code %in% needed_icaos)

# export
write_rds(flows_pairwise, here("data", "processed", "flows_pairwise.rds"))
write_rds(flights_country, here("data", "processed", "flights_country.rds"))
write_csv(flights_country, here("data", "processed", "flights_country.csv"))
write_rds(airports_slim, here("data", "processed", "airports.rds"))
write_rds(flights_filtered, here("data", "processed", "flights_filtered.rds"))

message("✓ flows_pairwise: ", nrow(flows_pairwise))
message("✓ flights_country: ", nrow(flights_country))
message("✓ airports_slim: ", nrow(airports_slim))
message("✓ flights_filtered: ", nrow(flights_filtered))