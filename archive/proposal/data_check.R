library(tidyverse)

# Read flight and airport data
df <- read_csv("data/opensky/opensky_2020_02.csv.gz")
airports <- read_csv("data/airports.csv")

eurocontrol <- read_csv("C:/Users/b1090201/Downloads/flightlist_20200201_20200229.csv.gz")

glimpse(eurocontrol)

# Inspect the structure of the airports dataset
glimpse(airports)

# Official Eurocontrol membership (excluding Iceland, because 2025) based on your list:
# Belgium, France, Germany, Luxembourg, The Netherlands, United Kingdom,
# Ireland, Portugal, Greece, Malta, Türkiye, Cyprus, Hungary, Switzerland,
# Austria, Denmark, Norway, Slovenia, Sweden, Czech Republic, Italy, Romania,
# Bulgaria, Croatia, Monaco, Slovakia, Spain, North Macedonia, Republic of Moldova,
# Finland, Albania, Bosnia and Herzegovina, Poland, Ukraine, Serbia, Armenia,
# Lithuania, Montenegro, Latvia, Georgia, Estonia.
eurocontrol_countries <- c("BE", "FR", "DE", "LU", "NL", "GB", "IE", "PT", "GR", 
                            "MT", "TR", "CY", "HU", "CH", "AT", "DK", "NO", "SI", 
                            "SE", "CZ", "IT", "RO", "BG", "HR", "MC", "SK", "ES", 
                            "MK", "MD", "FI", "AL", "BA", "PL", "UA", "RS", "AM", 
                            "LT", "ME", "LV", "GE", "EE")

# Extract ICAO codes for China: includes mainland China ("CN") plus Hong Kong ("HK") and Macau ("MO")
china_airports <- airports %>%
  filter(iso_country %in% c("CN", "HK", "MO")) %>% 
  filter(!is.na(icao_code)) %>%
  pull(icao_code)

# Extract ICAO codes for the Eurocontrol zone of Europe
europe_airports <- airports %>%
  filter(iso_country %in% eurocontrol_countries) %>%  
  filter(!is.na(icao_code)) %>%
  pull(icao_code)

# Quick check on European ICAO codes
head(europe_airports)

## --- Flight Data Cleaning and Analysis --- ##

# Total number of flights before cleaning
total_flights <- nrow(df)

# Remove flights with missing origin or destination
df_cleaned <- df %>%
  filter(!is.na(origin) & !is.na(destination))

cleaned_flights <- nrow(df_cleaned)

cat("Total flights before cleaning:", total_flights, "\n")
cat("Total flights after cleaning:", cleaned_flights, "\n")
cat("Percentage of flights removed:", round((1 - cleaned_flights / total_flights) * 100, 2), "%\n")

# Summarize missing origins and destinations
df %>%
  summarise(
    missing_origin = sum(is.na(origin)),
    missing_destination = sum(is.na(destination))
  )

# Check uniqueness of airports before and after cleaning
cat("Unique airports before cleaning:", length(unique(df$origin)), "\n")
cat("Unique airports after cleaning:", length(unique(df_cleaned$origin)), "\n")

# Most common Top 10 destinations (Before cleaning)
df %>%
  count(destination, sort = TRUE) %>%
  head(10)

# Most common Top 10 destinations (After cleaning)
df_cleaned %>%
  count(destination, sort = TRUE) %>%
  head(10)

# Compare daily flight counts before & after cleaning
df %>%
  count(day) %>%
  ggplot(aes(x = day, y = n)) +
  geom_line(color = "red") +
  labs(title = "Daily Flight Counts (Raw Data)", x = "Date", y = "Number of Flights")

df_cleaned %>%
  count(day) %>%
  ggplot(aes(x = day, y = n)) +
  geom_line(color = "blue") +
  labs(title = "Daily Flight Counts (Cleaned Data)", x = "Date", y = "Number of Flights")

# Filter flights from China to the Eurocontrol zone of Europe using the dynamic ICAO lists
china_to_europe_flights <- df_cleaned %>%
  filter(origin %in% china_airports & destination %in% europe_airports)

# Check how many flights match this criteria
cat("Total flights from China to Eurocontrol zone:", nrow(china_to_europe_flights), "\n")


## uff.. 674 flights from China to Eurocontrol zone in February 2020.
# Ain't much. perhaps via lubridate aggregate openky data b month.. nromalize the monthly counts and nterpolate missing months between opensky and Eurocontrol
