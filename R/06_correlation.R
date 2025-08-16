#!/usr/bin/env Rscript
# Correlation between early flight exposure and excess mortality

# setup
source(here::here("R", "00_load_libs.R"))

FIG_DIR <- here::here("data", "figures")
DER_DIR <- here::here("data", "derived")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(DER_DIR, recursive = TRUE, showWarnings = FALSE)

analysis_df <- readRDS(here::here("data", "processed", "analysis_df.rds"))

# OWID population (latest in 2020 per ISO3)
pop_df <- readr::read_csv(
  here::here("data", "raw", "owid", "owid-covid-data.csv"),
  show_col_types = FALSE,
  col_select = c(iso_code, date, population)
) |>
  dplyr::filter(lubridate::year(date) == 2020) |>
  dplyr::group_by(iso_code) |>
  dplyr::slice_max(date, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::transmute(iso3 = iso_code, population = as.numeric(population))

# Keep countries with 4 snapshots (2020–2023), add population, derive flights per million
corr_df <- analysis_df |>
  dplyr::semi_join(
    analysis_df |> dplyr::count(iso3) |> dplyr::filter(n == 4),
    by = "iso3"
  ) |>
  dplyr::left_join(pop_df, by = "iso3") |>
  dplyr::mutate(flights_pm = total_inbound_flights_combined / (population / 1e6))

stopifnot(!anyNA(corr_df$flights_pm))

# Confounder: share aged 65+ (latest in 2020)
age_df <- readr::read_csv(
  here::here("data", "raw", "owid", "owid-covid-data.csv"),
  show_col_types = FALSE,
  col_select = c(iso_code, date, aged_65_older)
) |>
  dplyr::filter(lubridate::year(date) == 2020) |>
  dplyr::group_by(iso_code) |>
  dplyr::slice_max(date, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::transmute(iso3 = iso_code, aged65 = as.numeric(aged_65_older))

corr_df <- dplyr::left_join(corr_df, age_df, by = "iso3")

# We don't stop if aged65 has NAs; it's not used in the baseline table
if (anyNA(corr_df$aged65)) {
  say(
    "i Note: aged65 has missing values for ",
    sum(is.na(corr_df$aged65)),
    "country(ies); baseline Spearman does not use it."
  )
}

# bootstrapped Spearman by year
BOOT_R <- suppressWarnings(as.integer(Sys.getenv("BOOT_R", "5000")))
if (is.na(BOOT_R) || BOOT_R < 100) BOOT_R <- 5000

boot_rho <- function(data, idx, xvar) {
  with(
    data[idx, ],
    stats::cor(
      get(xvar),
      excess_mortality_cumulative_per_million,
      method = "spearman",
      use = "complete.obs"
    )
  )
}

spearman_by_year <- function(xvar, B = BOOT_R) {
  corr_df |>
    dplyr::group_by(target_date) |>
    dplyr::group_modify(function(d, key) {
      ok <- stats::complete.cases(
        d[[xvar]],
        d$excess_mortality_cumulative_per_million
      )
      dd <- d[ok, ]
      n <- nrow(dd)

      # Guard against degenerate cases
      if (n < 3 ||
        stats::sd(dd[[xvar]]) == 0 ||
        stats::sd(dd$excess_mortality_cumulative_per_million) == 0) {
        return(tibble::tibble(
          rho = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
          p = NA_real_, n = n
        ))
      }

      rho <- stats::cor(dd[[xvar]],
        dd$excess_mortality_cumulative_per_million,
        method = "spearman"
      )
      pval <- stats::cor.test(dd[[xvar]],
        dd$excess_mortality_cumulative_per_million,
        method = "spearman", exact = FALSE
      )$p.value

      set.seed(42)
      ci <- if (n >= 4) {
        boot::boot(dd, boot_rho, R = B, xvar = xvar) |>
          (\(b) stats::quantile(b$t, c(.025, .975), na.rm = TRUE))()
      } else {
        c(NA_real_, NA_real_)
      }

      tibble::tibble(
        rho = as.numeric(rho),
        ci_lo = as.numeric(ci[1]),
        ci_hi = as.numeric(ci[2]),
        p = as.numeric(pval),
        n = n
      )
    }) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      variable = xvar,
      year = lubridate::year(target_date)
    )
}

vars <- c(
  "total_inbound_flights_dec19",
  "total_inbound_flights_mar20",
  "total_inbound_flights_combined",
  "flights_pm"
)

spearman_res <- purrr::map_dfr(vars, spearman_by_year) |>
  dplyr::mutate(variable = dplyr::recode(
    variable,
    total_inbound_flights_dec19 = "Dec 2019",
    total_inbound_flights_mar20 = "Mar 2020",
    total_inbound_flights_combined = "Combined",
    flights_pm = "Flights / M pop"
  ))

readr::write_csv(spearman_res, file.path(DER_DIR, "spearman_res.csv"))
saveRDS(spearman_res, file = file.path(DER_DIR, "spearman_res.rds"))
saveRDS(corr_df, file = file.path(DER_DIR, "corr_df.rds"))

say("✓ Saved: spearman_res.rds and corr_df.rds to ", DER_DIR)

# quartile gap (2020 snapshot)
snap20 <- corr_df |>
  dplyr::filter(target_date == as.Date("2020-05-05")) |>
  dplyr::arrange(total_inbound_flights_combined)

q <- stats::quantile(
  snap20$total_inbound_flights_combined,
  probs = c(0.25, 0.75),
  na.rm = TRUE
)

low_med <- stats::median(
  snap20$excess_mortality_cumulative_per_million[
    snap20$total_inbound_flights_combined <= q[[1]]
  ],
  na.rm = TRUE
)
high_med <- stats::median(
  snap20$excess_mortality_cumulative_per_million[
    snap20$total_inbound_flights_combined >= q[[2]]
  ],
  na.rm = TRUE
)

abs_gap <- round(high_med - low_med)
ratio <- if (abs(low_med) < 1e-9) NA_real_ else round(abs(high_med) / abs(low_med), 1)

quart_out <- tibble::tibble(
  q25 = unname(q[[1]]),
  q75 = unname(q[[2]]),
  low_med = as.numeric(low_med),
  high_med = as.numeric(high_med),
  abs_gap = as.numeric(abs_gap),
  ratio = as.numeric(ratio),
  n_low = sum(snap20$total_inbound_flights_combined <= q[[1]], na.rm = TRUE),
  n_high = sum(snap20$total_inbound_flights_combined >= q[[2]], na.rm = TRUE)
)

saveRDS(quart_out, file.path(DER_DIR, "quartile_gap_2020.rds"))
readr::write_csv(quart_out, file.path(DER_DIR, "quartile_gap_2020.csv"))

say(
  "✓ Quartile gap (2020): +", abs_gap, " deaths/million (top − bottom); ratio ~ ",
  ifelse(is.na(ratio), "NA (low≈0)", ratio), "×"
)


# Spearman rho over time (line plot)
pal_rho <- c(
  "Dec 2019" = "#E69F00",
  "Mar 2020" = "#56B4E9",
  "Combined" = "#009E73",
  "Flights / M pop" = "#CC79A7"
)

p_rho <- ggplot2::ggplot(
  spearman_res,
  ggplot2::aes(x = target_date, y = rho, colour = variable, group = variable)
) +
  ggplot2::geom_line(linewidth = 1.1) +
  ggplot2::geom_point(size = 2.4) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey30") +
  ggplot2::scale_colour_manual(values = pal_rho, name = NULL) +
  ggplot2::scale_x_date(date_labels = "%Y") +
  ggplot2::labs(x = NULL, y = "Spearman \u03C1") +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top")

ggplot2::ggsave(
  filename = file.path(FIG_DIR, "rho_timeseries.png"),
  plot = p_rho, width = 6, height = 4, dpi = 300, bg = "transparent"
)

say("✓ Saved figure: ", file.path(FIG_DIR, "rho_timeseries.png"))


# Scatter: combined flights vs EM (2020-05-05)
p20 <- corr_df |>
  dplyr::filter(target_date == as.Date("2020-05-05")) |>
  ggplot2::ggplot(ggplot2::aes(
    x = total_inbound_flights_combined,
    y = excess_mortality_cumulative_per_million
  )) +
  ggplot2::geom_point(size = 3, alpha = 0.8, colour = "#009E73") +
  ggrepel::geom_text_repel(ggplot2::aes(label = iso3), max.overlaps = 12, size = 3) +
  ggplot2::scale_x_log10(labels = scales::comma) +
  ggplot2::scale_y_continuous(labels = scales::comma) +
  ggplot2::labs(
    x = "Direct scheduled passenger flights (Dec 2019 + Mar 2020, log-scale)",
    y = "Excess deaths / million (to 5 May 2020)"
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  filename = file.path(FIG_DIR, "scatter_2020.png"),
  plot = p20, width = 5.6, height = 4, dpi = 300, bg = "transparent"
)

say("✓ Saved figure: ", file.path(FIG_DIR, "scatter_2020.png"))


# Scatter panels: Dec 2019 vs Mar 2020
snapshots <- corr_df |>
  dplyr::filter(target_date == as.Date("2020-05-05")) |>
  dplyr::select(
    iso3, excess_mortality_cumulative_per_million,
    flights_dec19 = total_inbound_flights_dec19,
    flights_mar20 = total_inbound_flights_mar20
  ) |>
  tidyr::pivot_longer(
    dplyr::starts_with("flights_"),
    names_to = "month",
    values_to = "inbound_flights"
  ) |>
  dplyr::mutate(
    month = factor(
      dplyr::recode(month,
        flights_dec19 = "Dec 2019",
        flights_mar20 = "Mar 2020"
      ),
      levels = c("Dec 2019", "Mar 2020")
    )
  ) |>
  dplyr::filter(inbound_flights > 0)

stats_lbl <- snapshots |>
  dplyr::group_by(month) |>
  dplyr::summarise(
    rho = stats::cor(
      inbound_flights,
      excess_mortality_cumulative_per_million,
      method = "spearman"
    ),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    label = sprintf("\u03C1 \u2248 %.2f", rho),
    x = max(snapshots$inbound_flights, na.rm = TRUE) * 0.9,
    y = min(snapshots$excess_mortality_cumulative_per_million, na.rm = TRUE) * 0.9
  )

gg_pp <- ggplot2::ggplot(
  snapshots,
  ggplot2::aes(x = inbound_flights, y = excess_mortality_cumulative_per_million)
) +
  ggplot2::geom_point(size = 3, alpha = 0.8, colour = "#009E73") +
  ggrepel::geom_text_repel(
    data = \(d) d |> dplyr::filter(iso3 %in% c("ESP", "ITA", "GBR", "DEU", "BEL", "FRA", "NLD")),
    ggplot2::aes(label = iso3), size = 3
  ) +
  ggplot2::geom_text(
    data = stats_lbl,
    ggplot2::aes(x = x, y = y, label = label),
    hjust = 1, vjust = 0, size = 3, fontface = "bold", colour = "grey30"
  ) +
  ggplot2::scale_x_log10(
    breaks = c(1, 3, 10, 30, 100, 300, 1000),
    labels = scales::comma,
    expand = ggplot2::expansion(mult = c(.05, .02))
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::comma,
    expand = ggplot2::expansion(mult = .03)
  ) +
  ggplot2::facet_wrap(~month, nrow = 1) +
  ggplot2::labs(
    x = "Direct scheduled passenger flights (log-scale)",
    y = "Excess deaths / million (to 5 May 2020)"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    strip.text = ggplot2::element_text(face = "bold"),
    panel.spacing = grid::unit(1, "cm")
  )

ggplot2::ggsave(
  filename = file.path(FIG_DIR, "scatter_dec_mar.png"),
  plot = gg_pp, width = 7.3, height = 3.8, dpi = 300, bg = "transparent"
)

say("✓ Saved figure: ", file.path(FIG_DIR, "scatter_dec_mar.png"))

# Caterpillar plot: Spearman ρ (±95% bootstrap CI) by year & metric
pal_cater <- c(
  "Dec 2019" = "#E69F00",
  "Mar 2020" = "#56B4E9",
  "Combined" = "#009E73"
)

if (!"year" %in% names(spearman_res)) {
  spearman_res <- spearman_res |>
    dplyr::mutate(year = lubridate::year(target_date))
}

gg_cater <- spearman_res |>
  dplyr::filter(variable %in% c("Dec 2019", "Mar 2020", "Combined")) |>
  dplyr::mutate(variable = factor(variable, levels = c("Combined", "Dec 2019", "Mar 2020"))) |>
  ggplot2::ggplot(ggplot2::aes(x = year, y = rho, colour = variable)) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey30") +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = ci_lo, ymax = ci_hi),
    width = 0.15, linewidth = 0.9,
    position = ggplot2::position_dodge(width = 0.4)
  ) +
  ggplot2::geom_point(size = 3, position = ggplot2::position_dodge(width = 0.4)) +
  ggplot2::scale_colour_manual(values = pal_cater, name = NULL) +
  ggplot2::labs(x = NULL, y = "Spearman \u03C1 (\u00B1 95% CI)") +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top")

ggplot2::ggsave(
  filename = file.path(FIG_DIR, "rho_caterpillar.png"),
  plot = gg_cater, width = 6, height = 4, dpi = 300, bg = "transparent"
)
say("✓ Saved figure: ", file.path(FIG_DIR, "rho_caterpillar.png"))


# Confounder test (sanity check): partial Spearman controlling for aged65
partial_by_year <- corr_df |>
  dplyr::group_by(target_date) |>
  dplyr::group_modify(\(.d, .key) {
    dd <- dplyr::filter(
      .d,
      stats::complete.cases(
        total_inbound_flights_combined,
        excess_mortality_cumulative_per_million,
        aged65
      )
    )

    n <- nrow(dd)
    if (n < 3 || stats::sd(dd$aged65) == 0) {
      return(tibble::tibble())
    }

    p <- ppcor::pcor.test(
      dd$total_inbound_flights_combined,
      dd$excess_mortality_cumulative_per_million,
      dd$aged65,
      method = "spearman"
    )

    tibble::tibble(
      year = lubridate::year(.key$target_date),
      rho_baseline = stats::cor(
        dd$total_inbound_flights_combined,
        dd$excess_mortality_cumulative_per_million,
        method = "spearman"
      ),
      rho_adj_age = as.numeric(p$estimate),
      p_adj_age = as.numeric(p$p.value),
      n = n
    )
  }) |>
  dplyr::ungroup()

saveRDS(partial_by_year, file.path(DER_DIR, "partial_by_year.rds"))
readr::write_csv(partial_by_year, file.path(DER_DIR, "partial_by_year.csv"))
say("✓ Saved table: ", file.path(DER_DIR, "partial_by_year.{rds,csv}"))


# Appendix A: 2020 restricted sample (countries with 4-year series)
REF <- as.Date("2020-05-05")

boot_rho_restricted <- function(d, idx) {
  with(
    d[idx, ],
    stats::cor(total_inbound_flights_combined,
      excess_mortality_cumulative_per_million,
      method = "spearman"
    )
  )
}

FULL_SERIES <- corr_df |>
  dplyr::count(iso3) |>
  dplyr::filter(n == 4) |>
  dplyr::pull(iso3)

snap_2020 <- corr_df |>
  dplyr::filter(target_date == REF, iso3 %in% FULL_SERIES)

set.seed(42)
boot_out <- boot::boot(snap_2020, boot_rho_restricted, R = 5000)
ci <- stats::quantile(boot_out$t, c(0.025, 0.975), na.rm = TRUE)

rho_restricted <- tibble::tibble(
  year = 2020L,
  rho = round(boot_out$t0, 3),
  ci_lo = round(ci[[1]], 3),
  ci_hi = round(ci[[2]], 3),
  n = nrow(snap_2020)
)

saveRDS(rho_restricted, file.path(DER_DIR, "rho_restricted_2020.rds"))
readr::write_csv(rho_restricted, file.path(DER_DIR, "rho_restricted_2020.csv"))
say("✓ Saved table: ", file.path(DER_DIR, "rho_restricted_2020.{rds,csv}"))

# Appendix B: Vaccination (2022-05-05) by exposure quartile (2020 snapshot)
exposure_q <- corr_df |>
  dplyr::filter(target_date == REF) |>
  dplyr::mutate(q = dplyr::ntile(total_inbound_flights_combined, 4)) |>
  dplyr::select(iso3, q)

vacc22 <- readr::read_csv(
  here::here("data", "raw", "owid", "owid-covid-data.csv"),
  col_select = c(iso_code, date, people_fully_vaccinated_per_hundred),
  show_col_types = FALSE
) |>
  dplyr::filter(date == as.Date("2022-05-05")) |>
  dplyr::transmute(
    iso3 = iso_code,
    vacc = people_fully_vaccinated_per_hundred
  )

vacc_by_q <- dplyr::left_join(exposure_q, vacc22, by = "iso3") |>
  dplyr::group_by(q) |>
  dplyr::summarise(
    median_vacc = stats::median(vacc, na.rm = TRUE),
    n = dplyr::n(),
    .groups = "drop"
  )

saveRDS(vacc_by_q, file.path(DER_DIR, "vacc_by_exposure_quartile_2022.rds"))
readr::write_csv(vacc_by_q, file.path(DER_DIR, "vacc_by_exposure_quartile_2022.csv"))
say("✓ Saved table: ", file.path(DER_DIR, "vacc_by_exposure_quartile_2022.{rds,csv}"))
