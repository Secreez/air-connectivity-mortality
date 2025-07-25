options(repos = c(CRAN = "https://cloud.r-project.org"))

load_dependencies <- function() {
  cran_packages <- c(
    "styler", "tidyverse", "here", "countrycode",
    "ggrepel", "scales", "boot", "ppcor", "lubridate", "data.table"
  )

  github_packages <- list(
    wpp2024 = "PPgp/wpp2024"
  )

  cran_missing <- setdiff(cran_packages, rownames(installed.packages()))
  if (length(cran_missing)) install.packages(cran_missing)

  for (pkg in names(github_packages)) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
      options(timeout = max(600, getOption("timeout")))
      devtools::install_github(github_packages[[pkg]])
    }
  }

  libs <- c(cran_packages, names(github_packages))
  invisible(
    suppressWarnings(
      suppressPackageStartupMessages(
        lapply(libs, require, character.only = TRUE)
      )
    )
  )
}

load_dependencies()
