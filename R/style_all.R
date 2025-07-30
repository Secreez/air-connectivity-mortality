source(here::here("R", "00_load_libs.R"))

styler::style_dir(
  path = here::here(),
  scope = "tokens",
  strict = TRUE
)
