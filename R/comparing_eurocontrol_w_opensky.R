#!/usr/bin/env Rscript
# OpenSky 2019-20  >  CN/HK/MO ➜ Eurocontrol-state flight counts
# read every flightlist_YYYYMMDD_YYYYMMDD.csv.gz
# count direct flights CN/HK/MO ➜ EU-41  (one row per country-month)
# save long + wide tables
# quick March-2020 comparison with EUROCONTROL
source(here::here("R", "00_load_libs.R"))


options(
  readr.num_threads      = max(1, parallel::detectCores() - 1),
  dplyr.summarise.inform = FALSE
)


## static lookups
euro_map <- read_csv(here("data/eurocontrol_iso_map.csv"),
  show_col_types = FALSE
)
euro_iso2 <- euro_map$iso2

airports <- read_csv(
  here("data/raw/OurAirports/airports.csv"),
  col_select     = c(icao_code, iso_country),
  show_col_types = FALSE
) |>
  drop_na(icao_code)

china_icao <- airports |>
  filter(iso_country %in% c("CN", "HK", "MO")) |>
  pull(icao_code)

eu_icao <- airports |>
  filter(iso_country %in% euro_iso2) |>
  pull(icao_code)

## counting function
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
  ) |>
    mutate(day = as_date(day)) |>
    filter(
      origin %in% china_icao,
      destination %in% eu_icao
    ) |>
    left_join(airports, by = c(destination = "icao_code")) |>
    left_join(euro_map, by = c(iso_country = "iso2")) |>
    {
      \(d) { # anonymous wrapper
        stopifnot(!any(is.na(d$iso3)))
        d # return the data
      }
    }() |>
    count(
      year = year(day),
      month = month(day),
      iso3,
      name = "n_flights"
    )
}

## run all files in the OpenSky directory
opensky_dir <- here("data/raw/Opensky")
files <- list.files(
  opensky_dir,
  pattern     = "^flightlist_\\d{8}_\\d{8}\\.csv\\.gz$",
  full.names  = TRUE
)

opensky_long <- map_dfr(files, count_cn_eu)

opensky_wide <- opensky_long |>
  mutate(month_lbl = sprintf("%04d-%02d", year, month)) |>
  dplyr::select(iso3, month_lbl, n_flights) |>
  tidyr::pivot_wider(
    names_from = month_lbl,
    values_from = n_flights,
    values_fill = 0
  ) |>
  dplyr::arrange(iso3)

## saving both long and wide tables
out_dir <- here("data/processed/opensky")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

write_rds(opensky_long, file.path(out_dir, "cn2eu_long.rds"))
write_csv(opensky_long, file.path(out_dir, "cn2eu_long.csv"))
write_rds(opensky_wide, file.path(out_dir, "cn2eu_wide.rds"))
write_csv(opensky_wide, file.path(out_dir, "cn2eu_wide.csv"))

message("✓ Saved: ", nrow(opensky_long), " rows total")

## quick match comparison with EUROCONTROL
euro_march <- readr::read_rds(here::here("data/processed/flights_country.rds")) |>
  dplyr::select(
    iso2 = iso_country,
    euro_mar20 = total_inbound_flights_mar20
  ) |>
  dplyr::left_join(
    dplyr::select(euro_map, iso2, iso3),
    by = "iso2"
  )

opensky <- opensky_wide |>
  dplyr::rename(
    opensky_mar20 = `2020-03`,
    opensky_feb20 = `2020-02`,
    opensky_dec19 = `2019-12`
  )

march_tbl <- euro_march |>
  dplyr::full_join(
    dplyr::select(opensky, iso3, opensky_mar20),
    by = "iso3"
  ) |>
  dplyr::mutate(
    dplyr::across(
      c(euro_mar20, opensky_mar20),
      ~ tidyr::replace_na(.x, 0L)
    )
  )

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
  here::here("data/figures/A_scatter_opensky_vs_euro_mar2020.png"),
  p_scatter,
  width = 6.5, height = 5, dpi = 300
)

## grouped bars
march_long <- march_tbl |>
  tidyr::pivot_longer(
    c(euro_mar20, opensky_mar20),
    names_to  = "source",
    values_to = "n"
  ) |>
  dplyr::mutate(source = dplyr::recode(
    source,
    euro_mar20    = "EUROCONTROL",
    opensky_mar20 = "OpenSky"
  ))

p_bars <- ggplot2::ggplot(
  march_long,
  ggplot2::aes(
    forcats::fct_reorder(iso3, n, .fun = sum),
    n,
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
  here::here("data/figures/B_bar_opensky_vs_euro_mar2020.png"),
  p_bars,
  width = 7, height = 7, dpi = 300
)

## February bar (OpenSky only)
feb_tbl <- opensky |>
  dplyr::select(iso3, opensky_feb20) |>
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
  here::here("data/figures/C_bar_opensky_feb2020.png"),
  p_feb,
  width = 6.5, height = 6, dpi = 300
)

## summary stats
spearman_test <- stats::cor.test(
  march_tbl$euro_mar20,
  march_tbl$opensky_mar20,
  method = "spearman", exact = FALSE
)

pearson_test <- stats::cor.test(
  march_tbl$euro_mar20,
  march_tbl$opensky_mar20,
  method = "pearson"
)

cat(
  "\nSpearman ρ :", round(spearman_test$estimate, 2),
  "(p =", format.pval(spearman_test$p.value, digits = 3), ")"
)

cat(
  "\nPearson  r :", round(pearson_test$estimate, 2),
  "(p =", format.pval(pearson_test$p.value, digits = 3), ")\n"
)

# OpenSky’s March-2020 sample aligns closely with EUROCONTROL’s comprehensive IFR records (Pearson r = 0.92, p ≈ 5.8 × 10⁻¹¹).
# Rank agreement is moderate-to-strong as well (Spearman ρ = 0.67, p ≈ 2 × 10⁻⁴),
# indicating that the ADS-B feed reproduces the broad exposure hierarchy but still omits a non-trivial share of low-volume flights.
