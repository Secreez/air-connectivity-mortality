# R/00_load_libs.R

cran_packages <- c(
  "styler", "tidyverse", "here", "countrycode",
  "ggrepel", "scales", "boot", "ppcor", "lubridate", "data.table",
  "glue"
)

github_specs <- c("PPgp/wpp2024")
pkg_from_gh <- function(spec) sub(".*/", "", spec)
github_pkgs <- vapply(github_specs, pkg_from_gh, character(1), USE.NAMES = FALSE)

all_pkgs <- c(cran_packages, github_pkgs)

load_or_stop <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf("Package '%s' is not installed. Run renv::restore() (or set INSTALL_MISSING=1).", pkg),
      call. = FALSE
    )
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

install_missing <- identical(tolower(Sys.getenv("INSTALL_MISSING", "0")), "1")
if (install_missing) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  missing_cran <- setdiff(cran_packages, rownames(installed.packages()))
  if (length(missing_cran)) install.packages(missing_cran)
  for (spec in github_specs) {
    pkg <- pkg_from_gh(spec)
    if (!requireNamespace(pkg, quietly = TRUE)) remotes::install_github(spec, upgrade = "never")
  }
}

invisible(lapply(all_pkgs, load_or_stop))

# runtime toggles & logging
quiet <- identical(tolower(Sys.getenv("QUIET", "0")), "1")
strict <- identical(tolower(Sys.getenv("STRICT", "0")), "1")
if (strict) options(warn = 2) # turns warnings into errors (!!!)

say <- function(...) if (!quiet) message(paste0(...))
sayf <- function(fmt, ...) if (!quiet) message(sprintf(fmt, ...))
warnf <- function(fmt, ...) warning(sprintf(fmt, ...), call. = FALSE)
dief <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

# sensible defaults
options(
  dplyr.summarise.inform = FALSE,
  readr.num_threads = max(1L, parallel::detectCores() - 1L)
)
