library(tidyverse)
library(lubridate)
library(here)

euro_map <- read_csv(
  here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)

euro_iso2 <- euro_map$iso2

airports <- read_csv(
  here("data/raw/OurAirports/airports.csv"),
  show_col_types = FALSE,
  col_select = c(icao_code, iso_country)
) %>%
  filter(!is.na(icao_code))

china_icao <- airports %>%
  filter(iso_country %in% c("CN", "HK", "MO")) %>%
  pull(icao_code)

eu_icao <- airports %>%
  filter(iso_country %in% euro_iso2) %>%
  pull(icao_code)

# count flights from OpenSky
count_cn_eu <- function(csv_path) {
  message("→  ", basename(csv_path))

  read_csv(
    csv_path,
    col_select = c(origin, destination, day),
    col_types = cols(
      origin      = col_character(),
      destination = col_character(),
      day         = col_datetime(format = "%Y-%m-%d %H:%M:%S%z")
    ),
    na = c("", "NA"),
    progress = FALSE
  ) %>%
    mutate(day = as_date(day)) %>% # keep only YYYY-MM-DD
    filter(
      !is.na(origin), !is.na(destination),
      origin %in% china_icao,
      destination %in% eu_icao
    ) %>%
    left_join(airports, by = c(destination = "icao_code")) %>% # iso_country
    left_join(euro_map, by = c(iso_country = "iso2")) %>% # country_name
    count(
      year    = year(day),
      month   = month(day), # numeric 1-12
      country_name,
      name    = "n_flights"
    )
}

# 3 months of OpenSky flight data runner
files <- c(
  here("data/raw/Opensky", "flightlist_20191201_20191231.csv"), # Dec-19
  here("data/raw/Opensky", "flightlist_20200201_20200229.csv"), # Feb-20
  here("data/raw/Opensky", "flightlist_20200301_20200331.csv") # Mar-20
)

opensky_counts <- map_dfr(files, count_cn_eu)

# save long table
write_csv(
  opensky_counts,
  here("data/processed/opensky_cn2eu_counts_2019-12_2020-02_2020-03.csv")
)
write_rds(
  opensky_counts,
  here("data/processed/opensky_cn2eu_counts_2019-12_2020-02_2020-03.rds")
)

# wide and combined table
opensky_wide <- opensky_counts %>%
  mutate(label = case_when(
    year == 2019 & month == 12 ~ "opensky_dec19",
    year == 2020 & month == 2 ~ "opensky_feb20",
    year == 2020 & month == 3 ~ "opensky_mar20",
    TRUE ~ NA_character_
  )) %>%
  select(label, country_name, n_flights) %>%
  pivot_wider(names_from = label, values_from = n_flights, values_fill = 0) %>%
  mutate(
    opensky_combined = opensky_dec19 + opensky_feb20 + opensky_mar20
  ) %>%
  left_join(select(euro_map, country_name, iso3), by = "country_name") %>%
  relocate(iso3, .before = 1)

write_csv(
  opensky_wide,
  here("data/processed/opensky_cn2eu_counts_wide.csv")
)
write_rds(
  opensky_wide,
  here("data/processed/opensky_cn2eu_counts_wide.rds")
)

cat("\n✓ Finished. Long, wide and QC outputs written to data/processed/ .\n")

# Now reading processed data
opensky <- read_rds(here("data/processed/opensky_cn2eu_counts_wide.rds"))
euro_march <- read_rds(here("data/processed/flights_country.rds")) %>%
  select(
    iso2 = iso_country,
    euro_mar20 = total_inbound_flights_mar20
  ) %>%
  left_join(read_csv(here("data/eurocontrol_iso_map.csv"), show_col_types = FALSE),
    by = "iso2"
  ) %>%
  select(iso3, euro_mar20)

# merge
march_tbl <- euro_march %>%
  full_join(select(opensky, iso3, opensky_mar20), by = "iso3") %>%
  mutate(across(starts_with(c("euro", "opensky")), ~ replace_na(., 0L)))

# Scatter Plot for March
p_scatter <- ggplot(
  march_tbl,
  aes(opensky_mar20, euro_mar20)
) +
  geom_point(size = 2) +
  geom_abline(
    slope = 1, intercept = 0,
    linetype = "dashed"
  ) +
  geom_smooth(method = "lm", se = FALSE, linewidth = .4) +
  labs(
    x = "OpenSky flights (Mar 2020)",
    y = "EUROCONTROL flights (Mar 2020)",
    title = "OpenSky vs EUROCONTROL – March 2020"
  ) +
  scale_x_continuous(expand = expansion(mult = .02)) +
  scale_y_continuous(expand = expansion(mult = .02))

print(p_scatter)

ggsave(here("figures", "A_scatter_opensky_vs_euro_mar2020.png"),
  p_scatter,
  width = 6.5, height = 5, dpi = 300
)

# Grouped Bars for March
march_long <- march_tbl %>%
  pivot_longer(
    cols = c(euro_mar20, opensky_mar20),
    names_to = "source", values_to = "n"
  ) %>%
  mutate(source = recode(source,
    euro_mar20 = "EUROCONTROL",
    opensky_mar20 = "OpenSky"
  ))

p_bars <- march_long %>%
  ggplot(aes(fct_reorder(iso3, n, .fun = sum), n,
    fill = source
  )) +
  geom_col(position = position_dodge(width = .7), width = .65) +
  coord_flip() +
  labs(
    x = NULL, y = "# flights (Mar 2020)",
    title = "Direct CN/HK → EU flights, March 2020",
    fill = NULL
  ) +
  scale_fill_manual(values = c("#3E8FB0", "#E69F00"))

print(p_bars)

ggsave(here("figures", "B_bar_opensky_vs_euro_mar2020.png"),
  p_bars,
  width = 7, height = 7, dpi = 300
)

# Feb Plot from Opensky only
feb_tbl <- opensky %>%
  select(iso3, opensky_feb20) %>%
  filter(opensky_feb20 > 0)

p_feb <- ggplot(
  feb_tbl,
  aes(
    fct_reorder(iso3, opensky_feb20),
    opensky_feb20
  )
) +
  geom_col(fill = "#56B4E9") +
  coord_flip() +
  labs(
    x = NULL, y = "# flights (Feb 2020)",
    title = "Direct CN/HK → EU flights (OpenSky only), February 2020"
  )

print(p_feb)

ggsave(here("figures", "C_bar_opensky_feb2020.png"),
  p_feb,
  width = 6.5, height = 6, dpi = 300
)
