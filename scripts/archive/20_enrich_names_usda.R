# ----------------------------------------
# STAGE: ENRICHMENT
# STEP: ENGLISH NAMES (USDA)
#
# SOURCE:
# - USDA Plants database (or equivalent API)
# - https://plants.usda.gov/
#
# PURPOSE:
# - Populate English common names
#
# INPUT:
# - plants.latin_name
#
# OUTPUT:
# - plant_names.english_name
#
# NOTES:
# - First naming layer
# - One primary name per plant (Phase 1)
# ----------------------------------------


library(DBI)
library(duckdb)
library(here)
library(readr)
library(dplyr)
library(stringr)

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# --------------------------------------------------
# STEP 1 — Load USDA dataset
# --------------------------------------------------

usda <- read_csv(
  here("data", "raw", "usda_plants.txt"),
  show_col_types = FALSE
)

# --------------------------------------------------
# STEP 2 — Rename columns
# --------------------------------------------------

usda_clean <- usda %>%
  rename(
    scientific_name = `Scientific Name with Author`,
    common_name = `Common Name`
  )

# --------------------------------------------------
# STEP 3 — Clean Latin names
# --------------------------------------------------

clean_latin_name <- function(x) {
  x <- str_replace(x, " [A-Z][a-z]*\\.?$", "")
  x <- str_replace(x, "\\(.*\\)", "")
  x <- str_trim(x)
  
  parts <- str_split(x, " ")
  
  sapply(parts, function(p) {
    if (length(p) >= 2) {
      paste(p[1], p[2])
    } else {
      p[1]
    }
  })
}

usda_clean <- usda_clean %>%
  mutate(
    latin_clean = clean_latin_name(scientific_name)
  )

# --------------------------------------------------
# STEP 4 — SIMPLE + SAFE deduplication
# --------------------------------------------------

usda_names <- usda_clean %>%
  filter(!is.na(common_name), common_name != "") %>%
  select(latin_clean, common_name) %>%
  distinct()

# ✅ force rename HERE (guaranteed)
usda_names <- usda_names %>%
  rename(english_name = common_name)

# ✅ verify before join (CRITICAL)
print(names(usda_names))

# --------------------------------------------------
# STEP 5 — Load plants
# --------------------------------------------------

plants <- dbReadTable(con, "plants")

plants_clean <- plants %>%
  mutate(
    latin_clean = clean_latin_name(latin_name)
  )

# --------------------------------------------------
# STEP 6 — EXPLICIT MATCH (FINAL FIX)
# --------------------------------------------------

plant_names <- plants_clean %>%
  rowwise() %>%
  mutate(
    english_name = usda_names$english_name[
      match(latin_clean, usda_names$latin_clean)
    ][1]
  ) %>%
  ungroup() %>%
  select(plant_id, english_name) %>%
  mutate(
    french_name = NA_character_
  )


# --------------------------------------------------
# STEP 7 — Save
# --------------------------------------------------

dbExecute(con, "DROP TABLE IF EXISTS plant_names")
dbWriteTable(con, "plant_names", plant_names, overwrite = TRUE)

# --------------------------------------------------
# STEP 8 — Verify
# --------------------------------------------------

print(dbGetQuery(con, "SELECT * FROM plant_names LIMIT 20"))

dbDisconnect(con, shutdown = TRUE)
