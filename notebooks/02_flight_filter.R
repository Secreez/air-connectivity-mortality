#!/usr/bin/env Rscript
source(here::here("R", "00_load_libs.R"))

# Read & filter the raw EUROCONTROL flight CSVs
flights_2019_12 <- read_csv(
  here::here("data", "raw", "flight_data", "201912", "Flights_20191201_20191231.csv.gz")
)
flights_2020_03 <- read_csv(
  here::here("data", "raw", "flight_data", "202003", "Flights_20200301_20200331.csv.gz")
)

col_subset <- c(
  "ECTRL ID", "ADEP", "ADES",
  "ADEP Latitude", "ADEP Longitude",
  "ADES Latitude", "ADES Longitude",
  "ICAO Flight Type",
  "ACTUAL OFF BLOCK TIME", "ACTUAL ARRIVAL TIME"
)

flights_dec19 <- flights_2019_12 %>%
  select(all_of(col_subset)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

flights_mar20 <- flights_2020_03 %>%
  select(all_of(col_subset)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

# Load & filter the OurAirports reference
airports <- read_csv(
  here::here("data", "raw", "OurAirports", "airports.csv"),
  show_col_types = FALSE
) %>%
  select(icao_code, iso_country, name, iata_code = any_of("iata_code"))

china_hk_macao_airports <- airports %>%
  filter(iso_country %in% c("CN", "HK", "MO")) %>%
  pull(icao_code)

eurocontrol_countries <- read_csv(
  here::here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
) %>%
  pull(iso2)

eurocontrol_airports <- airports %>%
  filter(iso_country %in% eurocontrol_countries) %>%
  pull(icao_code)

# Subset to direct CN/HK/MO → EUROCONTROL flights
flights_filtered <- bind_rows(
  dec19 = flights_dec19,
  mar20 = flights_mar20,
  .id  = "month"
) %>%
  filter(
    ADEP %in% china_hk_macao_airports,
    ADES %in% eurocontrol_airports
  )

flights_dec19_filtered <- filter(flights_filtered, month == "dec19")
flights_mar20_filtered <- filter(flights_filtered, month == "mar20")

# Sanity‐check ICAO→ISO mapping
iso_map <- read_csv(
  here::here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)

check_airports <- function(df) {
  df %>%
    left_join(airports, by = c("ADES" = "icao_code")) %>%
    distinct(ADES, iso_country) %>%
    { list(
        missing = filter(., is.na(iso_country)),
        wrong = filter(., !iso_country %in% iso_map$iso2)
      ) }
}

dec_check <- check_airports(flights_dec19_filtered)
mar_check <- check_airports(flights_mar20_filtered)

cat("Dec-19  missing ICAO→ISO:", nrow(dec_check$missing), "\n")
cat("Dec-19  unmapped ISO2   :", nrow(dec_check$wrong),   "\n\n")
cat("Mar-20  missing ICAO→ISO:", nrow(mar_check$missing), "\n")
cat("Mar-20  unmapped ISO2   :", nrow(mar_check$wrong),   "\n")

# Summarise by destination country
flights_country <- flights_filtered %>%
  left_join(airports, by = c("ADES" = "icao_code")) %>%
  count(month, iso_country, name = "n_flights") %>%
  pivot_wider(
    names_from  = month,
    values_from = n_flights,
    names_prefix = "total_inbound_flights_",
    values_fill = 0
  ) %>%
  mutate(
    total_inbound_flights_combined = total_inbound_flights_dec19 + total_inbound_flights_mar20
  )

# Export
write_rds(
  flights_country,
  here::here("data","processed","flights_country.rds")
)
write_csv(
  flights_country,
  here::here("data","processed","flights_country.csv")
)
message("✓ flights_country written: ", nrow(flights_country), " rows")

write_rds(
  airports,
  here::here("data","processed","airports.rds")
)
message("✓ airports written: ", nrow(airports), " rows")