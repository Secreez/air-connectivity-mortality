#!/usr/bin/env Rscript
# Generates:
#   data/figures/bar_top10_destinations.png
#   data/figures/bar_origins_per_destination.png
#   data/figures/scatter_volume_vs_origins.png
#   data/derived/airport_spearman.rds

# setup
source("R/00_load_libs.R", chdir = TRUE)

# Output dirs
fig_dir <- here::here("data", "figures")
der_dir <- here::here("data", "derived")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(der_dir, recursive = TRUE, showWarnings = FALSE)

# Inputs
flights_country <- readRDS(here::here("data", "processed", "flights_country.rds"))
flight_exposure <- readRDS(here::here("data", "processed", "flight_exposure_mapped.rds"))
flows_pairwise <- readRDS(here::here("data", "processed", "flows_pairwise.rds"))
airports <- readRDS(here::here("data", "processed", "airports.rds"))
flights_filtered <- readRDS(here::here("data", "processed", "flights_filtered.rds"))

# Top 10 Destination Bar
top10 <- flights_country |>
  dplyr::slice_max(total_inbound_flights_combined, n = 10, with_ties = FALSE) |>
  tidyr::pivot_longer(
    dplyr::starts_with("total_"),
    names_to = "window",
    values_to = "flights"
  ) |>
  dplyr::mutate(
    window = dplyr::recode(window,
      total_inbound_flights_dec19 = "Dec 2019",
      total_inbound_flights_mar20 = "Mar 2020",
      total_inbound_flights_combined = "Combined"
    ),
    iso_country = forcats::fct_reorder(iso_country, flights, .fun = max)
  )

pal <- c("Dec 2019" = "#E69F00", "Mar 2020" = "#56B4E9", "Combined" = "#009E73")

p_top10 <- ggplot2::ggplot(top10, ggplot2::aes(iso_country, flights, fill = window)) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = .75), width = .65) +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(labels = scales::comma) +
  ggplot2::scale_fill_manual(values = pal, name = NULL) +
  ggplot2::labs(
    title = "Top-10 EUROCONTROL destinations",
    subtitle = "Scheduled passenger IFR flights from China & Hong Kong (Dec 2019 and Mar 2020)",
    x = NULL, y = "Number of flights"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(
    legend.position = "top",
    legend.justification = "left",
    plot.title.position = "plot",
    axis.text.y = ggplot2::element_text(size = 9)
  )

ggplot2::ggsave(
  filename = file.path(fig_dir, "bar_top10_destinations.png"),
  plot = p_top10, width = 5.8, height = 4.4, dpi = 300, bg = "transparent"
)

# Panel: distinct origins per destination
top15 <- flows_pairwise |>
  dplyr::distinct(ADEP, ADES) |>
  dplyr::count(ADES, name = "n_origins") |>
  dplyr::slice_max(n_origins, n = 15, with_ties = FALSE) |>
  dplyr::pull(ADES)

combined_df <- flows_pairwise |>
  dplyr::filter(ADES %in% top15) |>
  dplyr::distinct(ADEP, ADES) |>
  dplyr::count(ADES, name = "n_origins") |>
  dplyr::left_join(airports, by = c(ADES = "icao_code")) |>
  dplyr::mutate(panel = "Combined", month = "Combined")

monthly_df <- flights_filtered |>
  dplyr::filter(ADES %in% top15) |>
  dplyr::distinct(month, ADEP, ADES) |>
  dplyr::count(month, ADES, name = "n_origins") |>
  dplyr::left_join(airports, by = c(ADES = "icao_code")) |>
  dplyr::mutate(
    month = dplyr::recode(month, dec19 = "Dec 2019", mar20 = "Mar 2020"),
    panel = "Monthly"
  )

plot_df <- dplyr::bind_rows(combined_df, monthly_df) |>
  dplyr::mutate(
    name  = forcats::fct_reorder(name, n_origins),
    month = factor(month, levels = c("Combined", "Dec 2019", "Mar 2020")),
    panel = factor(panel, levels = c("Combined", "Monthly"))
  )

pal_fill <- c("Combined" = "#009E73", "Dec 2019" = "#E69F00", "Mar 2020" = "#56B4E9")

panel_plot <- ggplot2::ggplot(plot_df, ggplot2::aes(n_origins, name, fill = month)) +
  ggplot2::geom_col(width = .6, position = ggplot2::position_dodge(width = .6)) +
  ggplot2::facet_grid(. ~ panel, scales = "fixed", space = "free_x") +
  ggplot2::scale_fill_manual(values = pal_fill, name = NULL) +
  ggplot2::scale_x_continuous(expand = c(0, 0)) +
  ggplot2::labs(
    title = "How many different CN/HK airports feed each EUROCONTROL destination?",
    x = "Unique origin airports", y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    strip.text = ggplot2::element_text(face = "bold"),
    axis.text.y = ggplot2::element_text(size = 7),
    legend.position = "top",
    panel.spacing.x = grid::unit(1.1, "cm")
  )

ggplot2::ggsave(
  filename = file.path(fig_dir, "bar_origins_per_destination.png"),
  plot = panel_plot, width = 6.3, height = 4.5, dpi = 300, bg = "transparent"
)

# Scatter: volume vs route diversity
dest_stats <- flows_pairwise |>
  dplyr::group_by(ADES) |>
  dplyr::summarise(
    total_flights = sum(n_flights),
    n_origins = dplyr::n_distinct(ADEP),
    .groups = "drop"
  ) |>
  dplyr::filter(total_flights > 0) |>
  dplyr::left_join(airports, by = c("ADES" = "icao_code")) |>
  dplyr::mutate(short_name = stringr::str_remove(name, " (International )?Airport$"))

air_cor <- suppressWarnings(stats::cor.test(
  dest_stats$total_flights,
  dest_stats$n_origins,
  method = "spearman", exact = FALSE
))
rho_air <- round(unname(air_cor$estimate), 2)
p_air <- format.pval(air_cor$p.value, digits = 2)

set.seed(42)
p_scatter <- ggplot2::ggplot(dest_stats, ggplot2::aes(x = total_flights, y = n_origins)) +
  ggplot2::geom_point(size = 3, alpha = .75, colour = "#56B4E9") +
  ggrepel::geom_text_repel(
    data = dest_stats |> dplyr::filter(total_flights > 200 | n_origins > 8),
    ggplot2::aes(label = short_name), size = 3, max.overlaps = 10
  ) +
  ggplot2::scale_x_log10(labels = scales::comma, expand = c(0.02, 0)) +
  ggplot2::labs(
    title = "Volume vs Route Diversity",
    subtitle = "Each dot = one EUROCONTROL destination airport",
    x = "Total direct flights (Dec 2019 + Mar 2020, log-scale)",
    y = "Distinct CN/HK origin airports",
    caption = glue::glue("Spearman ρ = {rho_air} (p {p_air}); n = {nrow(dest_stats)} airports")
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  filename = file.path(fig_dir, "scatter_volume_vs_origins.png"),
  plot = p_scatter, width = 6, height = 4.5, dpi = 300, bg = "transparent"
)

saveRDS(
  list(rho = unname(air_cor$estimate), p = air_cor$p.value, n = nrow(dest_stats)),
  file = file.path(der_dir, "airport_spearman.rds")
)

# Percentage change (countries with ≥ 5 Dec flights)
pct_df <- flight_exposure |>
  dplyr::transmute(
    country = country_name,
    dec = total_inbound_flights_dec19,
    mar = total_inbound_flights_mar20,
    pct = 100 * (mar - dec) / dec
  ) |>
  dplyr::filter(dec >= 5) |>
  dplyr::arrange(pct) |>
  dplyr::mutate(country = forcats::fct_reorder(country, pct))

p_collapse <- ggplot2::ggplot(
  pct_df,
  ggplot2::aes(x = pct, y = country, fill = pct > 0)
) +
  ggplot2::geom_col(width = .72, show.legend = FALSE) +
  ggplot2::scale_fill_manual(values = c(`TRUE` = "#56B4E9", `FALSE` = "#E69F00")) +
  ggplot2::scale_x_continuous(
    limits = c(-105, 5),
    breaks = seq(-100, 0, 25),
    labels = function(x) paste0(x, "%")
  ) +
  ggplot2::labs(
    title = "March collapse in direct CN/HK → EUROCONTROL flights",
    subtitle = "Countries with ≥ 5 flights in Dec 2019",
    x = "% change  (Mar 2020 vs Dec 2019)", y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  filename = file.path(fig_dir, "pct_change_filtered.png"),
  plot = p_collapse, width = 6.3, height = 4.5, dpi = 300, bg = "transparent"
)

saveRDS(pct_df, file = file.path(der_dir, "pct_df.rds"))
readr::write_csv(pct_df, file.path(der_dir, "pct_df.csv"))

# Full numeric table (all ≥ 5‑flight countries)
collapse_tbl <- pct_df |>
  dplyr::mutate(
    `Dec 2019` = scales::comma(dec),
    `Mar 2020` = scales::comma(mar),
    `% change` = sprintf("%+.0f %%", pct),
    `Δ flights` = scales::comma(mar - dec)
  ) |>
  dplyr::select(
    Country = country, `Dec 2019`, `Mar 2020`, `% change`, `Δ flights`
  )

saveRDS(collapse_tbl, file.path(der_dir, "collapse_tbl.rds"))
readr::write_csv(collapse_tbl, file.path(der_dir, "collapse_tbl.csv"))

# Top‑5 drops and increases table
# Make “Largest drop” (most negative pct) and “Largest increase” (most positive pct) true top‑5s
drops_tbl <- pct_df |>
  dplyr::filter(pct < 0) |>
  dplyr::arrange(pct) |>
  dplyr::slice_head(n = 5) |>
  dplyr::mutate(direction = "Largest drop")

incr_tbl <- pct_df |>
  dplyr::filter(pct >= 0) |>
  dplyr::arrange(dplyr::desc(pct)) |>
  dplyr::slice_head(n = 5) |>
  dplyr::mutate(direction = "Largest increase")

top_tbl <- dplyr::bind_rows(drops_tbl, incr_tbl) |>
  dplyr::mutate(
    `Dec 2019` = dec,
    `Mar 2020` = mar,
    `% change` = sprintf("%+.0f %%", pct),
    `Δ flights` = mar - dec
  ) |>
  dplyr::group_by(direction) |>
  dplyr::mutate(Rank = dplyr::row_number()) |>
  dplyr::ungroup() |>
  dplyr::select(
    direction, Rank,
    Country = country,
    `Dec 2019`, `Mar 2020`, `% change`, `Δ flights`
  )

saveRDS(top_tbl, file.path(der_dir, "top_tbl.rds"))
readr::write_csv(top_tbl, file.path(der_dir, "top_tbl.csv"))

# Origin‑airport bar (top 25)
origin_df <- flights_filtered |>
  dplyr::count(month, ADEP, name = "flights") |>
  dplyr::left_join(airports, by = c("ADEP" = "icao_code")) |>
  dplyr::group_by(ADEP) |>
  dplyr::mutate(total = sum(flights)) |>
  dplyr::ungroup() |>
  dplyr::arrange(dplyr::desc(total)) |>
  dplyr::slice_head(n = 25) |>
  dplyr::mutate(
    short_name = stringr::str_remove(name, " (International )?Airport$"),
    month = dplyr::recode(month, dec19 = "Dec 2019", mar20 = "Mar 2020"),
    short_name = forcats::fct_reorder(short_name, total)
  )

pal_window <- c("Dec 2019" = "#E69F00", "Mar 2020" = "#56B4E9")

p_orig <- ggplot2::ggplot(origin_df, ggplot2::aes(short_name, flights, fill = month)) +
  ggplot2::geom_col(position = "stack", width = .75) +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(labels = scales::comma) +
  ggplot2::scale_fill_manual(values = pal_window, name = NULL) +
  ggplot2::labs(
    title = "Inbound flight counts by CN/HK origin airport",
    subtitle = "Top 25 origins — December 2019 (orange) vs March 2020 (blue)",
    x = NULL, y = "Number of direct passenger flights"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(
    legend.position = "top",
    legend.justification = "left",
    axis.text.y = ggplot2::element_text(size = 8)
  )

ggplot2::ggsave(
  filename = file.path(fig_dir, "bar_origins_top25.png"),
  plot = p_orig, width = 6.3, height = 5.2, dpi = 300, bg = "transparent"
)

say("✓ Saved tables to ", der_dir, " and figures to ", fig_dir)
