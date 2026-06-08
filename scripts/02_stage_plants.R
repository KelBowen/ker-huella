# ----------------------------------------
# STAGE: INGESTION
# STEP: PLANT STAGING & NORMALISATION
#
# PURPOSE:
# - Clean and normalise GBIF plant data
# - Create reference 'plants' table (legacy)
#
# SCOPE:
# - Input:
#     raw_gbif_plants
# - Output:
#     plants (reference table, NOT source of truth)
#
# NOTES:
# - Phase 1 legacy table
# - Do NOT use as canonical identity in Phase 2
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)

con <- connect_db()

# ---- check input exists ----
if (!"raw_gbif_plants" %in% dbListTables(con)) {
  disconnect_db(con)
  stop("❌ raw_gbif_plants not found. Run Stage 01 first.")
}

df <- dbReadTable(con, "raw_gbif_plants")

# ---- clean ----
df <- df[!is.na(df$scientificName) & df$scientificName != "", ]

# ---- dedup logic ----
df_with_key <- df[!is.na(df$taxonKey), ]
df_no_key <- df[is.na(df$taxonKey), ]

plants_key <- df_with_key[!duplicated(df_with_key$taxonKey), ]
plants_name <- df_no_key[!duplicated(df_no_key$scientificName), ]

plants_unique <- rbind(plants_key, plants_name)

# ---- safe field extraction ----
accepted_name <- if ("acceptedScientificName" %in% names(plants_unique)) {
  plants_unique$acceptedScientificName
} else {
  NA_character_
}

english_name <- if ("genericName" %in% names(plants_unique)) {
  plants_unique$genericName
} else {
  NA_character_
}

# ---- build table ----
plants_df <- data.frame(
  plant_id = paste0("PL_", seq_len(nrow(plants_unique))),
  latin_name = plants_unique$scientificName,
  accepted_name = accepted_name,
  family = plants_unique$family,
  genus = plants_unique$genus,
  taxon_key = plants_unique$taxonKey,
  english_name = english_name,
  created_at = Sys.time(),
  stringsAsFactors = FALSE
)

# ---- write ----
dbExecute(con, "DROP TABLE IF EXISTS plants")
dbWriteTable(con, "plants", plants_df, overwrite = TRUE)

# ---- verify ----
print(dbGetQuery(con, "SELECT COUNT(*) AS n FROM plants"))

disconnect_db(con)

log_step("Plant staging (GBIF) complete ✅")