#!/usr/bin/env Rscript
# CN / HK / MO  ➜  Eurocontrol states – OpenSky vs. EUROCONTROL
# expects 3 plain CSVs  (Dec-19, Feb-20, Mar-20)    in  data/raw/Opensky/
# needs flights_country.rds (EUROCONTROL pipeline) in data/processed/
# outputs   data/processed/opensky/{cn2eu_long,cn2eu_wide}.{csv,rds}
# writes 3 figures into  data/figures/

source(here::here("R", "00_load_libs.R"))

options(
  readr.num_threads      = max(1, parallel::detectCores() - 1),
  dplyr.summarise.inform = FALSE
)

## look up
euro_map <- readr::read_csv(here::here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)
euro_iso2 <- euro_map$iso2

airports <- readr::read_csv(
  here::here("data/raw/OurAirports/airports.csv"),
  col_select     = c(icao_code, iso_country),
  show_col_types = FALSE
) |> tidyr::drop_na(icao_code)

china_icao <- airports |>
  dplyr::filter(iso_country %in% c("CN", "HK", "MO")) |>
  dplyr::pull(icao_code)

eu_icao <- airports |>
  dplyr::filter(iso_country %in% euro_iso2) |>
  dplyr::pull(icao_code)

all_iso3 <- euro_map |> dplyr::distinct(iso3)

## helper func
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
    dplyr::filter(
      origin %in% china_icao,
      destination %in% eu_icao
    ) |>
    dplyr::left_join(airports, by = c(destination = "icao_code")) |>
    dplyr::left_join(euro_map, by = c(iso_country = "iso2")) |>
    dplyr::count(
      year = lubridate::year(day),
      month = lubridate::month(day),
      iso3,
      name = "n_flights"
    )
}

## regex csv:
opensky_dir <- here::here("data/raw/Opensky")
files <- list.files(
  opensky_dir,
  pattern    = "^flightlist_\\d{8}_\\d{8}\\.csv$",
  full.names = TRUE
)

if (length(files) == 0) {
  stop(
    "No plain .csv files found in ", opensky_dir,
    "\n id you unzip the datasets into that folder?"
  )
}

opensky_long <- purrr::map_dfr(files, count_cn_eu)

## pad and pivot table
opensky_wide <- opensky_long |>
  dplyr::right_join(all_iso3, by = "iso3") |>
  dplyr::mutate(month_lbl = sprintf("%04d-%02d", year, month)) |>
  dplyr::select(iso3, month_lbl, n_flights) |>
  tidyr::pivot_wider(
    names_from  = month_lbl, # 2019-12 / 2020-02 / 2020-03
    values_from = n_flights,
    values_fill = 0
  ) |>
  dplyr::arrange(iso3)

## save
out_dir <- here::here("data/processed/opensky")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

readr::write_rds(opensky_long, file.path(out_dir, "cn2eu_long.rds"))
readr::write_csv(opensky_long, file.path(out_dir, "cn2eu_long.csv"))
readr::write_rds(opensky_wide, file.path(out_dir, "cn2eu_wide.rds"))
readr::write_csv(opensky_wide, file.path(out_dir, "cn2eu_wide.csv"))

message("✓ Saved: ", nrow(opensky_long), " rows total")

## compare with EUROCONTROL march 2020 data
euro_march <- readr::read_rds(here::here("data/processed/flights_country.rds")) |>
  dplyr::select(
    iso2 = iso_country,
    euro_mar20 = total_inbound_flights_mar20
  ) |>
  dplyr::left_join(dplyr::select(euro_map, iso2, iso3), by = "iso2")

opensky <- opensky_wide |>
  dplyr::rename(
    opensky_dec19 = `2019-12`,
    opensky_feb20 = `2020-02`,
    opensky_mar20 = `2020-03`
  )

march_tbl <- euro_march |>
  dplyr::full_join(dplyr::select(opensky, iso3, opensky_mar20), by = "iso3") |>
  dplyr::mutate(dplyr::across(
    c(euro_mar20, opensky_mar20),
    ~ tidyr::replace_na(.x, 0L)
  ))

## who misses
missing_tbl <- march_tbl |>
  dplyr::mutate(
    euro_any = euro_mar20 > 0,
    os_any   = opensky_mar20 > 0
  ) |>
  dplyr::select(iso3, euro_any, os_any) |>
  dplyr::filter(xor(euro_any, os_any))

print(missing_tbl, n = nrow(missing_tbl))

## plots
fig_dir <- here::here("data/figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

## scatter
p_scatter <- ggplot2::ggplot(
  march_tbl,
  ggplot2::aes(opensky_mar20, euro_mar20)
) +
  ggplot2::geom_point(size = 2) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  ggplot2::geom_smooth(method = "lm", se = FALSE, linewidth = .4) +
  ggplot2::labs(
    title = "OpenSky vs EUROCONTROL — March 2020",
    x = "OpenSky flights (Mar 2020)",
    y = "EUROCONTROL flights (Mar 2020)"
  ) +
  ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = .03)) +
  ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = .03))

ggplot2::ggsave(
  filename = file.path(fig_dir, "A_scatter_opensky_vs_euro_mar2020.png"),
  plot = p_scatter,
  width = 6.5, height = 5, dpi = 300
)

## grouped bar
march_long <- march_tbl |>
  tidyr::pivot_longer(
    c(euro_mar20, opensky_mar20),
    names_to  = "source",
    values_to = "n"
  ) |>
  dplyr::mutate(
    source = dplyr::recode(
      source,
      euro_mar20    = "EUROCONTROL",
      opensky_mar20 = "OpenSky"
    )
  )

p_bars <- ggplot2::ggplot(
  march_long,
  ggplot2::aes(
    forcats::fct_reorder(iso3, n, .fun = sum), n,
    fill = source
  )
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(.7), width = .65) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(values = c("#56B4E9", "#E69F00")) +
  ggplot2::labs(
    title = "Direct CN/HK → EU flights, March 2020",
    x = NULL, y = "# flights (Mar 2020)", fill = NULL
  )

ggplot2::ggsave(
  filename = file.path(fig_dir, "B_bar_opensky_vs_euro_mar2020.png"),
  plot = p_bars,
  width = 7, height = 7, dpi = 300
)

## February bar (OpenSky only)
feb_tbl <- opensky |>
  dplyr::filter(opensky_feb20 > 0)

p_feb <- ggplot2::ggplot(
  feb_tbl,
  ggplot2::aes(
    forcats::fct_reorder(iso3, opensky_feb20),
    opensky_feb20
  )
) +
  ggplot2::geom_col(fill = "#56B4E9") +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Direct CN/HK → EU flights (OpenSky), February 2020",
    x = NULL, y = "# flights (Feb 2020)"
  )

ggplot2::ggsave(
  filename = file.path(fig_dir, "C_bar_opensky_feb2020.png"),
  plot = p_feb,
  width = 6.5, height = 6, dpi = 300
)


## corr
spearman_test <- stats::cor.test(march_tbl$euro_mar20,
  march_tbl$opensky_mar20,
  method = "spearman", exact = FALSE
)
pearson_test <- stats::cor.test(march_tbl$euro_mar20,
  march_tbl$opensky_mar20,
  method = "pearson"
)

cat(
  "\nSpearman ρ :", round(spearman_test$estimate, 2),
  "(p =", format.pval(spearman_test$p.value, digits = 3), ")",
  "\nPearson  r :", round(pearson_test$estimate, 2),
  "(p =", format.pval(pearson_test$p.value, digits = 3), ")\n"
)
