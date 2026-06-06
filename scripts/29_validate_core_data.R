# ----------------------------------------
# STAGE: VALIDATION
# STEP: CORE DATA VALIDATION
#
# PURPOSE:
# - Validate core pipeline outputs
# - Detect missing, duplicate, or inconsistent data
#
# INPUT:
# - plants
# - plant_names
# - plant_uses
#
# OUTPUT:
# - Console validation report (warnings/errors)
#
# NOTES:
# - Does not modify data
# - Should run before output stage
# ----------------------------------------

library(DBI)
library(dplyr)

cat("\n========================================\n")
cat("STAGE 15: VALIDATION\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- dbConnect(
  duckdb::duckdb(),
  dbdir = here::here("database", "ker_huella.duckdb"),
  read_only = TRUE
)

# ----------------------------------------
# LOAD TABLES
# ----------------------------------------

plants <- dbReadTable(con, "plants")
plant_names <- dbReadTable(con, "plant_names")
plant_uses <- dbReadTable(con, "plant_uses")

# ----------------------------------------
# VALIDATION 1: PLANTS EXIST
# ----------------------------------------

cat("Check 1: Plants table not empty...\n")

if (nrow(plants) == 0) {
  stop("❌ ERROR: plants table is empty")
} else {
  cat("✅ OK:", nrow(plants), "plants found\n")
}

# ----------------------------------------
# VALIDATION 2: UNIQUE LATIN NAMES
# ----------------------------------------

cat("\nCheck 2: Duplicate Latin names...\n")

dupes <- plants %>%
  group_by(latin_name) %>%
  filter(n() > 1)

if (nrow(dupes) > 0) {
  warning("⚠️ Duplicate Latin names found")
  print(head(dupes))
} else {
  cat("✅ OK: No duplicates\n")
}

# ----------------------------------------
# VALIDATION 3: ENGLISH NAMES COVERAGE
# ----------------------------------------

cat("\nCheck 3: English name coverage...\n")

missing_en <- plant_names %>%
  filter(is.na(english_name) | english_name == "")

pct_missing_en <- round(nrow(missing_en) / nrow(plants) * 100, 1)

cat("Missing English names:", nrow(missing_en), 
    "(", pct_missing_en, "%)\n")

if (pct_missing_en > 30) {
  warning("⚠️ High missing English name rate")
} else {
  cat("✅ OK\n")
}

# ----------------------------------------
# VALIDATION 4: FRENCH NAMES COVERAGE
# ----------------------------------------

cat("\nCheck 4: French name coverage...\n")

missing_fr <- plant_names %>%
  filter(is.na(french_name) | french_name == "")

pct_missing_fr <- round(nrow(missing_fr) / nrow(plants) * 100, 1)

cat("Missing French names:", nrow(missing_fr), 
    "(", pct_missing_fr, "%)\n")

if (pct_missing_fr > 50) {
  warning("⚠️ High missing French name rate")
} else {
  cat("✅ OK\n")
}

# ----------------------------------------
# VALIDATION 5: NAME LINKAGE
# ----------------------------------------

cat("\nCheck 5: plant_names linkage...\n")

missing_name_links <- plants %>%
  anti_join(plant_names, by = "plant_id")

if (nrow(missing_name_links) > 0) {
  warning("⚠️ Some plants missing name records")
  print(head(missing_name_links))
} else {
  cat("✅ OK: All plants linked to names\n")
}

# ----------------------------------------
# VALIDATION 6: USES COVERAGE
# ----------------------------------------

cat("\nCheck 6: Uses coverage...\n")

missing_uses <- plants %>%
  anti_join(plant_uses, by = "plant_id")

pct_missing_uses <- round(nrow(missing_uses) / nrow(plants) * 100, 1)

cat("Plants without uses:", nrow(missing_uses),
    "(", pct_missing_uses, "%)\n")

cat("✅ INFO: Not all plants are expected to have uses\n")

# ----------------------------------------
# VALIDATION 7: EMPTY STRINGS CHECK
# ----------------------------------------

cat("\nCheck 7: Empty strings...\n")

empty_strings <- plant_names %>%
  filter(
    english_name == "" |
      french_name == ""
  )

cat("Empty string rows:", nrow(empty_strings), "\n")

if (nrow(empty_strings) > 0) {
  warning("⚠️ Empty strings detected (prefer NA)")
} else {
  cat("✅ OK\n")
}

# ----------------------------------------
# SUMMARY
# ----------------------------------------

cat("\n========================================\n")
cat("VALIDATION COMPLETE ✅\n")
cat("========================================\n")

dbDisconnect(con)