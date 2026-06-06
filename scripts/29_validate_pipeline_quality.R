
# ----------------------------------------
# STAGE: VALIDATION
# STEP: PIPELINE DATA QUALITY VIEW
#
# PURPOSE:
# - Assess pipeline health at the table level
# - Generate a structured pipeline data quality table
# - Record run metadata including last_run_timestamp
# - Create DuckDB views for reporting
#
# OUTPUT:
# - pipeline_run_metadata (table)
# - pipeline_data_quality (table)
# - pipeline_data_quality_view (view)
# - pipeline_last_run (view)
#
# NOTES:
# - Focused on pipeline completeness, not hard failure
# - Missing data may indicate enrichment backlog, not broken logic
# ----------------------------------------

library(DBI)
library(dplyr)
library(tibble)
library(here)
library(duckdb)

cat("\n========================================\n")
cat("STAGE 29: PIPELINE DATA QUALITY\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# ----------------------------------------
# RUN METADATA
# ----------------------------------------

run_timestamp <- Sys.time()
run_id <- format(run_timestamp, "%Y%m%d%H%M%S")
run_stage <- "29_validate_pipeline_quality"
run_notes <- "Pipeline-level data quality refresh"

# ----------------------------------------
# HELPERS
# ----------------------------------------

safe_read <- function(con, table_name) {
  tryCatch(
    dbReadTable(con, table_name),
    error = function(e) NULL
  )
}

count_missing <- function(df, cols) {
  if (is.null(df) || nrow(df) == 0) return(0)
  
  missing_rows <- df %>%
    mutate(across(all_of(cols), ~ is.na(.) | . == "")) %>%
    filter(if_any(all_of(cols), identity))
  
  nrow(missing_rows)
}

calc_completeness_pct <- function(row_count, missing_required_count) {
  if (is.null(row_count) || row_count == 0) return(0)
  round(((row_count - missing_required_count) / row_count) * 100, 1)
}

calc_quality_score <- function(row_count, missing_required_count) {
  if (is.null(row_count) || row_count == 0) return(0)
  calc_completeness_pct(row_count, missing_required_count)
}

calc_quality_status <- function(score, row_count) {
  if (is.null(row_count) || row_count == 0) return("Needs enrichment")
  if (score >= 90) return("Good")
  if (score >= 60) return("Partial")
  return("Needs enrichment")
}

make_quality_row <- function(table_name, df, required_cols, notes, run_id, run_timestamp) {
  row_count <- if (is.null(df)) 0 else nrow(df)
  missing_required_count <- count_missing(df, required_cols)
  completeness_pct <- calc_completeness_pct(row_count, missing_required_count)
  quality_score <- calc_quality_score(row_count, missing_required_count)
  quality_status <- calc_quality_status(quality_score, row_count)
  
  tibble(
    run_id = run_id,
    run_timestamp = as.character(run_timestamp),
    table_name = table_name,
    row_count = row_count,
    required_columns = paste(required_cols, collapse = ", "),
    missing_required_count = missing_required_count,
    completeness_pct = completeness_pct,
    quality_score = quality_score,
    quality_status = quality_status,
    notes = notes
  )
}

# ----------------------------------------
# LOAD TABLES
# ----------------------------------------

plants <- safe_read(con, "plants")
plant_names <- safe_read(con, "plant_names")
plant_parts <- safe_read(con, "plant_parts")
uses_tbl <- safe_read(con, "uses")
preparations <- safe_read(con, "preparations")
locations <- safe_read(con, "locations")
plant_locations <- safe_read(con, "plant_locations")
plant_uses <- safe_read(con, "plant_uses")
plant_card_view <- safe_read(con, "plant_card_view")

# ----------------------------------------
# BUILD PIPELINE QUALITY TABLE
# ----------------------------------------

quality_tbl <- bind_rows(
  make_quality_row(
    "plants",
    plants,
    c("plant_id", "latin_name"),
    "Core plant identity table",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "plant_names",
    plant_names,
    c("plant_id"),
    "Language enrichment layer (English / French)",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "plant_parts",
    plant_parts,
    c("part_id", "plant_id"),
    "Plant anatomy structure",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "uses",
    uses_tbl,
    c("use_id", "part_id"),
    "Uses linked to plant parts",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "preparations",
    preparations,
    c("preparation_id", "use_id"),
    "Preparation methods linked to uses",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "locations",
    locations,
    c("location_id", "location_name"),
    "Garden location reference table",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "plant_locations",
    plant_locations,
    c("plant_id", "location_id"),
    "Plant-to-location relationship table",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "plant_uses",
    plant_uses,
    c("plant_id"),
    "Enriched uses layer",
    run_id,
    run_timestamp
  ),
  make_quality_row(
    "plant_card_view",
    plant_card_view,
    c("plant_id", "latin_name"),
    "Final integrated output",
    run_id,
    run_timestamp
  )
)

# ----------------------------------------
# SAVE RUN METADATA
# ----------------------------------------

dbExecute(con, "
CREATE TABLE IF NOT EXISTS pipeline_run_metadata (
    run_id VARCHAR,
    run_timestamp VARCHAR,
    run_stage VARCHAR,
    run_notes VARCHAR
)
")

dbExecute(
  con,
  sprintf(
    "INSERT INTO pipeline_run_metadata VALUES ('%s', '%s', '%s', '%s')",
    run_id,
    as.character(run_timestamp),
    run_stage,
    run_notes
  )
)

# ----------------------------------------
# SAVE PIPELINE QUALITY TABLE
# ----------------------------------------

dbExecute(con, "DROP TABLE IF EXISTS pipeline_data_quality")

dbWriteTable(
  con,
  "pipeline_data_quality",
  quality_tbl,
  overwrite = TRUE
)

# ----------------------------------------
# CREATE MAIN QUALITY VIEW
# ----------------------------------------

dbExecute(con, "DROP VIEW IF EXISTS pipeline_data_quality_view")

dbExecute(con, "
CREATE VIEW pipeline_data_quality_view AS
SELECT
    run_id,
    run_timestamp,
    table_name,
    row_count,
    required_columns,
    missing_required_count,
    completeness_pct,
    quality_score,
    quality_status,
    notes
FROM pipeline_data_quality
ORDER BY table_name
")

# ----------------------------------------
# CREATE LAST RUN VIEW
# ----------------------------------------

dbExecute(con, "DROP VIEW IF EXISTS pipeline_last_run")

dbExecute(con, "
CREATE VIEW pipeline_last_run AS
SELECT
    run_id,
    run_timestamp AS last_run_timestamp,
    run_stage,
    run_notes
FROM pipeline_run_metadata
ORDER BY run_timestamp DESC
LIMIT 1
")

# ----------------------------------------
# PRINT SUMMARY
# ----------------------------------------

cat("Pipeline data quality view created successfully.\n")
cat("Last run timestamp:", as.character(run_timestamp), "\n\n")

cat("Pipeline data quality:\n")
print(dbGetQuery(con, "SELECT * FROM pipeline_data_quality_view"))

cat("\nLast pipeline run:\n")
print(dbGetQuery(con, "SELECT * FROM pipeline_last_run"))

cat("\n========================================\n")
cat("PIPELINE DATA QUALITY COMPLETE ✅\n")
cat("========================================\n")

dbDisconnect(con, shutdown = TRUE)
