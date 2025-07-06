#!/usr/bin/env Rscript
# CN/HK/MO Eurocontrol states OpenSky vs EUROCONTROL audit
# compares Dec-2019 (EU & OS) + Feb-2020 (OS only)
# Saves tidy OpenSky tables →  data/processed/opensky/
# Writes one PNG (Feb bar)
source(here::here("R", "00_load_libs.R"))

options(
  readr.num_threads      = max(1, parallel::detectCores() - 1),
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
      origin      = readr::col_character(),
      destination = readr::col_character(),
      day         = readr::col_datetime("%Y-%m-%d %H:%M:%S%z")
    ),
    na = c("", "NA"),
    progress = FALSE
  ) |>
    dplyr::mutate(day = lubridate::as_date(day)) |>
    dplyr::filter(origin %in% china_icao, destination %in% eu_icao) |>
    dplyr::left_join(airports, by = c(destination = "icao_code")) |>
    dplyr::left_join(euro_map, by = c(iso_country = "iso2")) |>
    dplyr::count(
      year  = lubridate::year(day),
      month = lubridate::month(day),
      iso3,
      name  = "n_flights"
    )
}

## parse all opensky flightlist files
opensky_dir <- here::here("data/raw/Opensky")
files <- list.files(
  opensky_dir,
  pattern    = "^flightlist_\\d{8}_\\d{8}\\.csv$",
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
    names_from  = month_lbl, # 2019-12  / 2020-02 / 2020-03
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

## EUROCONTROL Dec counts
euro_dec <- readr::read_rds(
  here::here("data/processed/flights_country.rds")
) |>
  dplyr::select(
    iso2     = iso_country,
    Dec19_eu = total_inbound_flights_dec19
  ) |>
  dplyr::left_join(
    dplyr::select(euro_map, iso2, iso3),
    by = "iso2"
  )

## cov. audit tables
coverage_tbl <- opensky_wide |>
  dplyr::rename(
    Dec19_os = `2019-12`,
    Feb20_os = `2020-02`
  ) |>
  dplyr::left_join(euro_dec, by = "iso3") |>
  dplyr::mutate(
    dplyr::across(where(is.numeric), \(x) tidyr::replace_na(x, 0L)),
    EU_only = Dec19_eu > 0 & Dec19_os == 0,
    OS_only = Dec19_eu == 0 & Dec19_os > 0
  ) |>
  dplyr::select(
    iso3,
    `Dec 2019 (EU)` = Dec19_eu,
    `Dec 2019 (OS)` = Dec19_os,
    `Feb 2020 (OS)` = Feb20_os,
    EU_only, OS_only
  ) |>
  dplyr::arrange(dplyr::desc(`Dec 2019 (EU)`))

knitr::kable(
  coverage_tbl,
  caption = "Direct CN/HK flights captured by EUROCONTROL (EU, Dec 2019) and OpenSky (OS, Dec 2019 & Feb 2020)."
)

## Feb 2020 bar plot
fig_dir <- here::here("data/figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

p_feb <- opensky_wide |>
  dplyr::rename(Feb20 = `2020-02`) |>
  dplyr::filter(Feb20 > 0) |>
  dplyr::mutate(iso3 = forcats::fct_reorder(iso3, Feb20)) |>
  ggplot2::ggplot(ggplot2::aes(iso3, Feb20)) +
  ggplot2::geom_col(fill = "#009E73", width = .65) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Direct CN/HK → EU flights (OpenSky), February 2020",
    x = NULL, y = "# flights"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(plot.title.position = "plot")

ggplot2::ggsave(
  file.path(fig_dir, "bar_opensky_feb2020.png"),
  p_feb,
  width = 6.5, height = 6, dpi = 300, bg = "transparent"
)
