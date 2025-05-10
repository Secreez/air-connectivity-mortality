source(here::here("R", "00_load_libs.R"))

# raw ingredients
iso_map <- read_csv(here("data", "eurocontrol_iso_map.csv"),
  show_col_types = FALSE
) # iso2 ↔ iso3
flights <- flows_pairwise # airport→airport pairs

# first 2 chars of an ICAO code
iso2_from_icao <- function(x) substr(x, 1, 2)

# check origin codes
origin_issues <- flights %>%
  mutate(origin_iso2 = iso2_from_icao(ADEP)) %>%
  filter(nchar(ADEP) < 2 | is.na(origin_iso2))

cat("\n=== ORIGIN issues (should be 0 rows) ===\n")
print(origin_issues)

# destination ISO-2 that fail to map to ISO-3
dest_map <- flights %>%
  mutate(dest_iso2 = iso2_from_icao(ADES)) %>%
  anti_join(iso_map, by = c("dest_iso2" = "iso2")) # ← rows with no match

cat("\n=== DESTINATION ISO-2 not in eurocontrol_iso_map ===\n")
print(dest_map %>%
  count(dest_iso2, sort = TRUE))

# summary counts
summary_tbl <- flights %>%
  mutate(
    origin_iso2 = iso2_from_icao(ADEP),
    dest_iso2 = iso2_from_icao(ADES)
  ) %>%
  summarise(
    total_pairs = n(),
    distinct_orig_iso2 = n_distinct(origin_iso2),
    distinct_dest_iso2 = n_distinct(dest_iso2),
    dests_missing_iso3 = sum(dest_iso2 %in% dest_map$dest_iso2)
  )

cat("\n=== QUICK SUMMARY ===\n")
print(summary_tbl)
