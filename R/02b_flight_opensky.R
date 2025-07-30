#!/usr/bin/env Rscript
# CN/HK/MO Eurocontrol states OpenSky vs EUROCONTROL audit
# compares Dec-2019 (EU & OS) + Feb-2020 (OS only)
# Saves tidy OpenSky tables →  data/processed/opensky/
# Writes one PNG (Feb bar)

source(here::here("R", "00_load_libs.R"))

options(
  readr.num_threads = max(1, parallel::detectCores() - 1),
  dplyr.summarise.inform = FALSE
)

euro_map <- readr::read_csv(here::here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)

airports <- readr::read_csv(
  here::here("data/raw/OurAirports/airports.csv"),
  col_select = c(icao_code, iso_country),
  show_col_types = FALSE
) |>
  tidyr::drop_na(icao_code)

china_icao <- airports |>
  dplyr::filter(iso_country %in% c("CN", "HK", "MO")) |>
  dplyr::pull(icao_code)

eu_icao <- airports |>
  dplyr::filter(iso_country %in% euro_map$iso2) |>
  dplyr::pull(icao_code)

all_iso3 <- euro_map |> dplyr::distinct(iso3)

## helper function
count_cn_eu <- function(csv_path) {
  message("→  ", basename(csv_path))

  readr::read_csv(
    csv_path,
    col_select = c(origin, destination, day),
    col_types = readr::cols(
      origin = readr::col_character(),
      destination = readr::col_character(),
      day = readr::col_datetime("%Y-%m-%d %H:%M:%S%z")
    ),
    na = c("", "NA"),
    progress = FALSE
  ) |>
    dplyr::mutate(day = lubridate::as_date(day)) |>
    dplyr::filter(origin %in% china_icao, destination %in% eu_icao) |>
    dplyr::left_join(airports, by = c(destination = "icao_code")) |>
    dplyr::left_join(euro_map, by = c(iso_country = "iso2")) |>
    dplyr::count(
      year = lubridate::year(day),
      month = lubridate::month(day),
      iso3,
      name = "n_flights"
    )
}

## parse all opensky flightlist files
opensky_dir <- here::here("data/raw/Opensky")
files <- list.files(
  opensky_dir,
  pattern = "^flightlist_\\d{8}_\\d{8}\\.csv$",
  full.names = TRUE
)

if (length(files) == 0) {
  stop(
    "No plain .csv files found in ", opensky_dir,
    "\nDid you unzip the datasets into that folder?"
  )
}

opensky_long <- purrr::map_dfr(files, count_cn_eu)

opensky_wide <- opensky_long |>
  dplyr::right_join(all_iso3, by = "iso3") |>
  dplyr::mutate(month_lbl = sprintf("%04d-%02d", year, month)) |>
  dplyr::select(iso3, month_lbl, n_flights) |>
  tidyr::pivot_wider(
    names_from = month_lbl, # 2019-12 / 2020-02 / 2020-03
    values_from = n_flights,
    values_fill = 0
  ) |>
  dplyr::arrange(iso3)

## persist OpenSky tables
out_dir <- here::here("data/processed/opensky")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

readr::write_rds(opensky_long, file.path(out_dir, "cn2eu_long.rds"))
readr::write_csv(opensky_long, file.path(out_dir, "cn2eu_long.csv"))
readr::write_rds(opensky_wide, file.path(out_dir, "cn2eu_wide.rds"))
readr::write_csv(opensky_wide, file.path(out_dir, "cn2eu_wide.csv"))

message("✓ Saved: ", nrow(opensky_long), " rows total")

## EUROCONTROL snapshots
euro_snap <- readr::read_rds(
  here::here("data/processed/flights_country.rds")
) |>
  dplyr::select(
    iso2 = iso_country,
    Dec19_eu = total_inbound_flights_dec19,
    Mar20_eu = total_inbound_flights_mar20
  ) |>
  dplyr::left_join(dplyr::select(euro_map, iso2, iso3), by = "iso2")


## cov. audit tables
coverage_tbl <- opensky_wide |>
  dplyr::rename(
    Dec19_os = `2019-12`,
    Feb20_os = `2020-02`,
    Mar20_os = `2020-03`
  ) |>
  dplyr::left_join(euro_snap, by = "iso3") |>
  dplyr::mutate(
    dplyr::across(where(is.numeric), \(x) tidyr::replace_na(x, 0L)),
    OS_miss = Dec19_os == 0 & Feb20_os == 0 & Mar20_os == 0,
    EU_only = (Dec19_eu + Mar20_eu) > 0 & OS_miss,
    OS_only = (Dec19_eu + Mar20_eu) == 0 & (Dec19_os + Feb20_os + Mar20_os) > 0
  ) |>
  dplyr::select(
    iso3,
    `Dec 2019 (EU)` = Dec19_eu,
    `Mar 2020 (EU)` = Mar20_eu,
    `Dec 2019 (OS)` = Dec19_os,
    `Feb 2020 (OS)` = Feb20_os,
    `Mar 2020 (OS)` = Mar20_os,
    EU_only, OS_only
  ) |>
  dplyr::arrange(dplyr::desc(`Dec 2019 (EU)`))


out_derived <- here::here("data/derived")
dir.create(out_derived, showWarnings = FALSE, recursive = TRUE)

readr::write_rds(coverage_tbl, file.path(out_derived, "coverage_tbl.rds"))
readr::write_csv(coverage_tbl, file.path(out_derived, "coverage_tbl.csv"))

message("✓ Saved coverage_tbl (", nrow(coverage_tbl), " rows)")


fig_dir <- here::here("data/figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

top_opensky <- opensky_wide |>
  dplyr::rename(
    `Dec 2019` = `2019-12`,
    `Feb 2020` = `2020-02`,
    `Mar 2020` = `2020-03`
  ) |>
  dplyr::mutate(
    total = `Dec 2019` + `Feb 2020` + `Mar 2020`
  ) |>
  dplyr::filter(total > 0) |>
  dplyr::arrange(desc(total)) |>
  dplyr::slice_head(n = 10) |>
  tidyr::pivot_longer(
    cols = c(`Dec 2019`, `Feb 2020`, `Mar 2020`),
    names_to = "month", values_to = "flights"
  ) |>
  dplyr::mutate(
    iso3 = forcats::fct_reorder(iso3, -flights, .fun = sum) # sort by total
  )

ggplot(top_opensky, aes(x = iso3, y = flights, fill = month)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.65) +
  coord_flip() +
  scale_fill_manual(
    values = c(
      "Dec 2019" = "#E69F00",
      "Feb 2020" = "#56B4E9",
      "Mar 2020" = "#009E73"
    )
  ) +
  labs(
    title = "Top-10 destinations in OpenSky data",
    subtitle = "Direct flights from CN/HK to EUROCONTROL countries",
    y = "# flights", x = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "top",
    legend.justification = "left",
    plot.title.position = "plot",
    axis.text.y = element_text(size = 9)
  )

ggsave(
  file.path(fig_dir, "bar_opensky_top10_dec_feb_mar.png"),
  width = 6.5, height = 5.5, dpi = 300, bg = "transparent"
)
