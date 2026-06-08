# ----------------------------------------
# STAGE: INGESTION
# STEP: SHAREPOINT OPERATIONAL DATA INGESTION
#
# PURPOSE:
# - Load and normalise operational plant data from SharePoint export
# - Create canonical seed_plants dataset
#
# SCOPE:
# - Input:
#     data/operational/seed_plants_export.csv
# - Output:
#     seed_plants
#     plant_status
#     plant_types
#     locations
#     plant_locations
#
# NOTES:
# - This is the primary source of truth for Phase 2
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(tidyr)
library(stringr)

con <- connect_db()

# ----------------------------
# LOAD DATA
# ----------------------------

input_file <- here::here("data", "operational", "seed_plants_export.csv")

if (!file.exists(input_file)) {
  disconnect_db(con)
  stop("❌ Input file not found: ", input_file)
}

plants_input <- read.csv(input_file, stringsAsFactors = FALSE)

log_step("✅ File loaded")
print(names(plants_input))

# ----------------------------
# RENAME COLUMNS
# ----------------------------

plants_input <- plants_input %>%
  rename(
    latin_name   = LatinName,
    common_name  = CommonName,
    status       = Status,
    plant_type   = PlantType,
    location_raw = Location,
    notes        = Notes,
    date_added   = DateAdded
  )

# ----------------------------
# CLEAN CORE TABLE
# ----------------------------

seed_plants <- plants_input %>%
  transmute(
    latin_name = str_trim(latin_name),
    common_name = str_trim(common_name),
    status_name = str_trim(status),
    plant_type_name = str_trim(plant_type),
    notes,
    date_added = as.Date(date_added)
  ) %>%
  filter(!is.na(latin_name) & latin_name != "") %>%
  distinct(latin_name, .keep_all = TRUE)

log_step(paste("✅ seed_plants created:", nrow(seed_plants)))

# ----------------------------
# FIX TYPOS
# ----------------------------

seed_plants <- seed_plants %>%
  mutate(
    plant_type_name = case_when(
      plant_type_name == "Rhyzome" ~ "Rhizome",
      TRUE ~ plant_type_name
    )
  )

# ----------------------------
# DIMENSIONS
# ----------------------------

plant_status <- seed_plants %>%
  select(status_name) %>%
  filter(!is.na(status_name)) %>%
  distinct() %>%
  mutate(status_id = row_number())

plant_types <- seed_plants %>%
  select(plant_type_name) %>%
  filter(!is.na(plant_type_name)) %>%
  distinct() %>%
  mutate(plant_type_id = row_number())

# ----------------------------
# LOCATION PARSING
# ----------------------------

plant_locations_raw <- plants_input %>%
  select(latin_name, location_raw) %>%
  filter(!is.na(location_raw) & location_raw != "")

plant_locations <- plant_locations_raw %>%
  mutate(
    location_clean = location_raw %>%
      str_replace_all("\\\\", "") %>%
      str_replace_all("[\\[\\]\"]", "")
  ) %>%
  separate_rows(location_clean, sep = ",") %>%
  mutate(
    location_name = str_trim(location_clean)
  ) %>%
  filter(location_name != "")

locations <- plant_locations %>%
  distinct(location_name) %>%
  mutate(location_id = row_number())

plant_locations_final <- plant_locations %>%
  left_join(locations, by = "location_name") %>%
  select(latin_name, location_id)

# ----------------------------
# FINAL JOIN
# ----------------------------

seed_plants_final <- seed_plants %>%
  left_join(plant_status, by = "status_name") %>%
  left_join(plant_types, by = "plant_type_name")

# ----------------------------
# WRITE TO DB
# ----------------------------

dbWriteTable(con, "seed_plants", seed_plants_final, overwrite = TRUE)
dbWriteTable(con, "plant_status", plant_status, overwrite = TRUE)
dbWriteTable(con, "plant_types", plant_types, overwrite = TRUE)
dbWriteTable(con, "locations", locations, overwrite = TRUE)
dbWriteTable(con, "plant_locations", plant_locations_final, overwrite = TRUE)

# ----------------------------
# SUMMARY
# ----------------------------

log_step("✅ FINAL COUNTS")
cat("Plants:", nrow(seed_plants_final), "\n")
cat("Locations:", nrow(locations), "\n")
cat("Plant-location links:", nrow(plant_locations_final), "\n")

disconnect_db(con)

log_step("✅ SharePoint ingestion complete")
