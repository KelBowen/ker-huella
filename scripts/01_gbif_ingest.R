# ----------------------------------------
# STAGE: INGESTION
# STEP: GBIF TAXONOMIC DATA INGESTION
#
# PURPOSE:
# - Retrieve plant taxonomic backbone data from GBIF
# - Load raw plant occurrence records into a staging table
#
# SCOPE:
# - Input:
#     data/raw/plant_list.csv
# - Output:
#     raw_gbif_plants (DuckDB table)
#
# USAGE:
# source("scripts/01_gbif_ingest.R")
#
# NOTES:
# - Legacy (Phase 1) ingestion step
# - Not the primary source of truth in Phase 2
# - Used as an optional reference / comparison layer
# - Requires scripts/00_setup.R for shared helpers
# ----------------------------------------

source("scripts/00_setup.R")

suppressPackageStartupMessages({
  library(rgbif)
  library(dplyr)
  library(readr)
  library(here)
})

# ---- connect using shared setup ----
con <- connect_db()

# ---- input file ----
input_file <- here("data", "raw", "plant_list.csv")

if (!file.exists(input_file)) {
  disconnect_db(con)
  stop("❌ plant_list.csv not found: ", input_file)
}

plant_list <- read.csv(input_file, stringsAsFactors = FALSE)

# ---- validate expected input schema ----
if (!"latin_name" %in% names(plant_list)) {
  disconnect_db(con)
  stop("❌ Input file must contain a 'latin_name' column.")
}

plant_list <- plant_list %>%
  mutate(latin_name = trimws(latin_name)) %>%
  filter(!is.na(latin_name) & latin_name != "") %>%
  distinct(latin_name)

log_step(paste("Loaded", nrow(plant_list), "plants from plant_list.csv"))

# ---- collector ----
all_occ <- list()

# ---- loop through plant list ----
for (i in seq_len(nrow(plant_list))) {
  
  plant_name <- plant_list$latin_name[i]
  log_step(paste("Querying GBIF for:", plant_name))
  
  occ <- tryCatch(
    occ_search(scientificName = plant_name, limit = 50),
    error = function(e) {
      log_step(paste("GBIF query failed for", plant_name, "->", conditionMessage(e)))
      NULL
    }
  )
  
  if (!is.null(occ) && !is.null(occ$data) && nrow(occ$data) > 0) {
    all_occ[[length(all_occ) + 1]] <- occ$data
    log_step(paste("Returned", nrow(occ$data), "rows for", plant_name))
  } else {
    log_step(paste("No GBIF data returned for", plant_name))
  }
  
  # polite rate limiting
  Sys.sleep(0.5)
}

# ---- combine results ----
if (length(all_occ) == 0) {
  disconnect_db(con)
  stop("❌ No data returned from GBIF for any plants.")
}

all_occ <- bind_rows(all_occ)

# ---- write staging table ----
dbExecute(con, "DROP TABLE IF EXISTS raw_gbif_plants")
dbWriteTable(con, "raw_gbif_plants", all_occ, overwrite = TRUE)

# ---- verify ----
result <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM raw_gbif_plants")
print(result)

# ---- close ----
disconnect_db(con)

log_step("GBIF ingestion complete ✅")