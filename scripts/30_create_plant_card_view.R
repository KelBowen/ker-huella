
# --------------------------------------------------
# FINAL ASSEMBLY STEP
# Always runs last in pipeline
# Depends on all enrichment steps
# --------------------------------------------------

library(DBI)
library(duckdb)
library(here)

# --------------------------------------------------
# CONNECT
# --------------------------------------------------

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# --------------------------------------------------
# LOAD TABLES
# --------------------------------------------------

plants <- dbReadTable(con, "plants")
plant_names <- dbReadTable(con, "plant_names")
plant_uses <- dbReadTable(con, "plant_uses")

# --------------------------------------------------
# DEBUG INPUT STRUCTURE
# --------------------------------------------------

cat("\n--- plant_names columns ---\n")
print(names(plant_names))

cat("\n--- plant_uses columns ---\n")
print(names(plant_uses))

# --------------------------------------------------
# ENSURE REQUIRED COLUMNS
# --------------------------------------------------

# names
if (!"english_name" %in% names(plant_names)) {
  cat("WARNING: english_name missing → creating NA column\n")
  plant_names$english_name <- NA_character_
}

if (!"french_name" %in% names(plant_names)) {
  plant_names$french_name <- NA_character_
}

# uses
if (!"wikipedia_summary" %in% names(plant_uses)) {
  plant_uses$wikipedia_summary <- NA_character_
}

# --------------------------------------------------
# CLEAN EXISTING OBJECT (TABLE OR VIEW)
# --------------------------------------------------

try(dbExecute(con, "DROP VIEW plant_card_view"), silent = TRUE)
try(dbExecute(con, "DROP TABLE plant_card_view"), silent = TRUE)

# --------------------------------------------------
# BUILD FINAL TABLE (CONTROL COLUMN COLLISIONS)
# --------------------------------------------------

plant_card_view <- plants |>
  merge(
    plant_names[, c("plant_id", "english_name", "french_name")],
    by = "plant_id",
    all.x = TRUE,
    suffixes = c("", "_usda")
  ) |>
  merge(
    plant_uses[, c("plant_id", "wikipedia_summary")],
    by = "plant_id",
    all.x = TRUE
  )

# --------------------------------------------------
# RESOLVE DUPLICATE NAME COLUMNS
# --------------------------------------------------

# If both exist, prefer USDA version
if ("english_name_usda" %in% names(plant_card_view)) {
  plant_card_view$english_name <- plant_card_view$english_name_usda
  plant_card_view$english_name_usda <- NULL
}

# Remove GBIF / duplicate column if present
if ("english_name.x" %in% names(plant_card_view)) {
  plant_card_view$english_name.x <- NULL
}

if ("english_name.y" %in% names(plant_card_view)) {
  names(plant_card_view)[names(plant_card_view) == "english_name.y"] <- "english_name"
}

# --------------------------------------------------
# DEBUG FINAL STRUCTURE
# --------------------------------------------------

cat("\n--- plant_card_view columns ---\n")
print(names(plant_card_view))

# --------------------------------------------------
# SAVE TABLE
# --------------------------------------------------

dbWriteTable(
  con,
  "plant_card_view",
  plant_card_view,
  overwrite = TRUE
)

# --------------------------------------------------
# VERIFY (SAFE — NO COLUMN ASSUMPTION)
# --------------------------------------------------

print(
  dbGetQuery(
    con,
    "SELECT * FROM plant_card_view LIMIT 10"
  )
)

# --------------------------------------------------
# CLOSE
# --------------------------------------------------

dbDisconnect(con, shutdown = TRUE)

