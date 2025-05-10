library(dplyr)
library(readr)
library(wpp2024)

# your vector of Eurocontrol ISO‑3 codes
euro_ISO3 <- c("AUT", "BEL", "CZE", ...)

# 1 ─ OWID 2020 mid‑year (unchanged) -------------------------------------
owid_pop20 <- read_csv(
  here::here("data/raw/owid/owid-covid-data.csv"),
  show_col_types = FALSE,
  col_select = c(iso_code, date, population)
) %>%
  filter(
    iso_code %in% euro_ISO3,
    lubridate::year(date) == 2020
  ) %>%
  group_by(iso_code) %>%
  slice_max(date, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    iso3 = iso_code,
    pop_owid = population
  )

# 2 ─ UN WPP 2020 mid‑year ----------------------------------------------
wpp_pop20 <- totalPop %>% # <- NEW name in wpp2024
  filter(
    year == 2020,
    iso3 %in% euro_ISO3
  ) %>% # iso3 column already present
  transmute(iso3,
    pop_wpp = pop
  )

# 3 ─ compare ------------------------------------------------------------
pop_chk <- owid_pop20 %>%
  inner_join(wpp_pop20, by = "iso3") %>%
  mutate(
    abs_diff = pop_owid - pop_wpp,
    pct_diff = abs_diff / pop_wpp * 100
  )

pop_chk %>%
  summarise(
    max_abs = max(abs(abs_diff)),
    max_pct = max(pct_diff)
  ) %>%
  knitr::kable(caption = "Largest OWID vs UN‑WPP difference (Eurocontrol states)")
