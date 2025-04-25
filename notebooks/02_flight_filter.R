#!/usr/bin/env Rscript
source(file.path("R", "00_load_libs.R"))

## Load & Filter EUROCONTROL Flight Data
### Caution: register for R&D access to download the data:
flights_2019_12 <- read_csv("data/raw/flight_data/201912/Flights_20191201_20191231.csv.gz")
flights_2020_03 <- read_csv("data/raw/flight_data/202003/Flights_20200301_20200331.csv.gz")

col_subset <- c("ECTRL ID", "ADEP", "ADES", "ADEP Latitude", "ADEP Longitude",
                "ADES Latitude", "ADES Longitude", "ICAO Flight Type",
                "ACTUAL OFF BLOCK TIME", "ACTUAL ARRIVAL TIME")

flights_dec19 <- flights_2019_12 %>%
  select(all_of(col_subset)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

flights_mar20 <- flights_2020_03 %>%
  select(all_of(col_subset)) %>%
  filter(`ICAO Flight Type` %in% c("S", "N"))

# Load & Filter Airport Reference Data
## Load airport reference table (OurAirports)
airports <- read_csv(
  "data/raw/OurAirports/airports.csv",
  show_col_types = FALSE
) %>%
  select(icao_code, iso_country, name, iata_code = any_of("iata_code"))

## CN / HK / MO airports – origin set
china_hk_macao_airports <- airports %>%
  filter(iso_country %in% c("CN", "HK", "MO"), !is.na(icao_code)) %>%
  pull(icao_code)                               # vector of ICAO codes

## Eurocontrol member airports – destination set
eurocontrol_countries <- read_csv("data/eurocontrol_iso_map.csv",
                                  show_col_types = FALSE) %>%
  pull(iso2)

eurocontrol_airports <- airports %>%
  filter(iso_country %in% eurocontrol_countries, !is.na(icao_code)) %>%
  pull(icao_code)



## Subset Flight Data to CN/HK/MO → EUROCONTROL Routes
flights_filtered <- bind_rows(
  dec19 = flights_dec19,
  mar20 = flights_mar20,
  .id = "month"
) %>% # month = dec19 / mar20
  filter(
    ADEP %in% china_hk_macao_airports,
    ADES %in% eurocontrol_airports
  )

flights_dec19_filtered <- flights_filtered %>% filter(month == "dec19")
flights_mar20_filtered <- flights_filtered %>% filter(month == "mar20")

## Sanity Check: ICAO -> ISO Country -> Mapping
check_airports <- function(flights_df, airports_df, iso_map) {

  airport_check <- flights_df %>%
    left_join(airports_df,  by = c("ADES" = "icao_code")) %>%
    select(ADES, iso_country) %>%
    distinct()

  miss  <- airport_check %>% filter(is.na(iso_country))
  wrong <- airport_check %>% filter(!iso_country %in% iso_map$iso2)

  list(missing = miss, unmapped = wrong)
}

iso_map   <- read_csv("data/eurocontrol_iso_map.csv")

dec_check <- check_airports(flights_dec19_filtered, airports, iso_map)
mar_check <- check_airports(flights_mar20_filtered, airports, iso_map)

cat("Dec‑19  missing ICAO→ISO:", nrow(dec_check$missing), "\n")
cat("Dec‑19  unmapped ISO2   :", nrow(dec_check$unmapped), "\n\n")

cat("Mar‑20  missing ICAO→ISO:", nrow(mar_check$missing), "\n")
cat("Mar‑20  unmapped ISO2   :", nrow(mar_check$unmapped), "\n")

## Summarize Flight Exposure by Country
flights_country <- flights_filtered %>%
  left_join(airports, by = c("ADES" = "icao_code")) %>%
  group_by(month, iso_country) %>%
  summarise(n_flights = n(), .groups = "drop") %>%
  pivot_wider(names_from = month,
              values_from = n_flights,
              names_prefix = "total_inbound_flights_") %>%
  mutate(across(starts_with("total_inbound_flights_"),
                ~replace_na(.x, 0)),
         total_inbound_flights_combined =
           total_inbound_flights_dec19 +
           total_inbound_flights_mar20)

## write output
write_csv(flights_country,
          "data/processed/flights_country.csv") # ≈ 40 rows
write_rds(flights_country,
          "data/processed/flights_country.rds") # for fast R I/O
message("✓ flights_country written (", nrow(flights_country), " rows)")