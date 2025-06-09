load_dependencies <- function() {
  cran_packages <- c(
    "styler", "tidyverse", "here", "countrycode", "ggrepel", "scales", "boot", "ppcor"
  )

  github_packages <- list(
    wpp2024 = "PPgp/wpp2024"
  )

  cran_missing <- cran_packages[!(cran_packages %in% installed.packages()[, "Package"])]
  if (length(cran_missing)) install.packages(cran_missing)

  for (pkg in names(github_packages)) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
      options(timeout = max(600, getOption("timeout")))
      devtools::install_github(github_packages[[pkg]])
    }
  }

  invisible(
    suppressPackageStartupMessages({
      lapply(c(cran_packages, names(github_packages)), library, character.only = TRUE)
    })
  )
}

load_dependencies()
