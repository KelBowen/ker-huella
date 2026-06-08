
# ----------------------------------------
# STAGE: VALIDATION
# STEP: PIPELINE DATA QUALITY + STATUS CARD
#
# PURPOSE:
# - Assess pipeline health at the table level
# - Validate Phase 2 operational + enrichment pipeline
# - Track run metadata and timestamps
# - Create reporting views for BI consumption
#
# SCOPE:
# - Input tables:
#     seed_plants
#     locations
#     plant_locations
#     plant_reference_raw
#     plant_reference_uses
#
# - Output:
#     plant_card_view
#
# OUTPUT:
# - pipeline_run_metadata (table)
# - pipeline_data_quality (table)
# - pipeline_data_quality_view (view)
# - pipeline_last_run (view)
# - pipeline_status_card_view (view)
#
# NOTES:
# - Focused on completeness, not strict failure
# - Missing enrichment highlights backlog opportunities
# - Fully resilient to missing tables and schema drift
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 29: PIPELINE DATA QUALITY (PHASE 2)\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

log_step("Tables available:")
print(dbListTables(con))

# ----------------------------------------
# RUN METADATA
# ----------------------------------------

run_timestamp <- Sys.time()
run_id <- format(run_timestamp, "%Y%m%d%H%M%S")
run_stage <- "29_validate_pipeline"
run_notes <- "Phase 2 pipeline validation"

# ----------------------------------------
# HELPERS
# ----------------------------------------

table_exists <- function(con, table_name) {
  table_name %in% dbListTables(con)
}

safe_read <- function(con, table_name) {
  if (!table_exists(con, table_name)) return(NULL)
  
  tryCatch(
    dbReadTable(con, table_name),
    error = function(e) NULL
  )
}

safe_query <- function(con, query) {
  tryCatch(
    dbGetQuery(con, query),
    error = function(e) data.frame(n = NA)
  )
}

count_missing <- function(df, cols) {
  if (is.null(df) || nrow(df) == 0) return(0)
  
  existing_cols <- intersect(cols, names(df))
  if (length(existing_cols) == 0) return(0)
  
  df %>%
    mutate(across(all_of(existing_cols), ~ is.na(.) | . == "")) %>%
    filter(if_any(all_of(existing_cols), identity)) %>%
    nrow()
}

calc_completeness_pct <- function(row_count, missing_count) {
  if (row_count == 0) return(0)
  round(((row_count - missing_count) / row_count) * 100, 1)
}

calc_quality_status <- function(score, row_count) {
  if (row_count == 0) return("Not available")
  if (score >= 90) return("Good")
  if (score >= 60) return("Partial")
  return("Needs enrichment")
}

make_row <- function(name, df, cols, notes) {
  
  table_missing <- is.null(df)
  
  row_count <- if (table_missing) 0 else nrow(df)
  
  existing_cols <- if (table_missing) character(0) else intersect(cols, names(df))
  missing_cols <- if (table_missing) cols else setdiff(cols, names(df))
  
  missing <- count_missing(df, existing_cols)
  completeness <- calc_completeness_pct(row_count, missing)
  status <- calc_quality_status(completeness, row_count)
  
  tibble(
    run_id = run_id,
    run_timestamp = format(run_timestamp, "%Y-%m-%d %H:%M:%S"),
    table_name = name,
    row_count = row_count,
    required_columns = paste(cols, collapse = ", "),
    missing_columns = paste(missing_cols, collapse = ", "),
    missing_required_count = missing,
    completeness_pct = completeness,
    quality_score = completeness,
    quality_status = if (table_missing) "Not available" else status,
    notes = notes
  )
}

# ----------------------------------------
# LOAD TABLES
# ----------------------------------------

seed_plants <- safe_read(con, "seed_plants")
locations <- safe_read(con, "locations")
plant_locations <- safe_read(con, "plant_locations")
plant_reference_raw <- safe_read(con, "plant_reference_raw")
plant_reference_uses <- safe_read(con, "plant_reference_uses")
plant_card_view <- safe_read(con, "plant_card_view")

# ----------------------------------------
# BUILD QUALITY TABLE (FIXED SCHEMA ✅)
# ----------------------------------------

quality_tbl <- bind_rows(
  make_row("seed_plants", seed_plants, c("latin_name"), "Operational source of truth"),
  make_row("locations", locations, c("location_id", "location_name"), "Location dimension"),
  make_row("plant_locations", plant_locations, c("latin_name", "location_id"), "Plant-location link"),
  make_row("plant_reference_raw", plant_reference_raw, c("latin_name"), "PFAF raw enrichment"),
  make_row("plant_reference_uses", plant_reference_uses, c("latin_name", "use_type"), "Structured uses"),
  make_row("plant_card_view", plant_card_view, c("latin_name"), "Final consumption layer")
)

# ----------------------------------------
# RELATIONSHIP CHECKS
# ----------------------------------------

missing_locations <- if (table_exists(con, "seed_plants") && table_exists(con, "plant_locations")) {
  safe_query(con, "
    SELECT COUNT(*) AS n
    FROM seed_plants sp
    LEFT JOIN plant_locations pl ON sp.latin_name = pl.latin_name
    WHERE pl.latin_name IS NULL
  ")
} else data.frame(n = NA)

missing_pfaf <- if (table_exists(con, "seed_plants") && table_exists(con, "plant_reference_raw")) {
  safe_query(con, "
    SELECT COUNT(*) AS n
    FROM seed_plants sp
    LEFT JOIN plant_reference_raw pr ON sp.latin_name = pr.latin_name
    WHERE pr.latin_name IS NULL
  ")
} else data.frame(n = NA)

missing_uses <- if (table_exists(con, "seed_plants") && table_exists(con, "plant_reference_uses")) {
  safe_query(con, "
    SELECT COUNT(*) AS n
    FROM seed_plants sp
    LEFT JOIN plant_reference_uses pu ON sp.latin_name = pu.latin_name
    WHERE pu.latin_name IS NULL
  ")
} else data.frame(n = NA)

log_step(paste("Plants without locations:", missing_locations$n))
log_step(paste("Plants without PFAF:", missing_pfaf$n))
log_step(paste("Plants without parsed uses:", missing_uses$n))

# ----------------------------------------
# SAVE METADATA
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
    format(run_timestamp, "%Y-%m-%d %H:%M:%S"),
    run_stage,
    run_notes
  )
)

# ----------------------------------------
# SAVE QUALITY TABLE
# ----------------------------------------

dbExecute(con, "DROP TABLE IF EXISTS pipeline_data_quality")
dbWriteTable(con, "pipeline_data_quality", quality_tbl, overwrite = TRUE)

# ----------------------------------------
# CREATE VIEWS
# ----------------------------------------

dbExecute(con, "
CREATE OR REPLACE VIEW pipeline_data_quality_view AS
SELECT * FROM pipeline_data_quality ORDER BY table_name
")

dbExecute(con, "
CREATE OR REPLACE VIEW pipeline_last_run AS
SELECT run_id, run_timestamp AS last_run_timestamp, run_stage
FROM pipeline_run_metadata
ORDER BY run_timestamp DESC
LIMIT 1
")

dbExecute(con, "
CREATE OR REPLACE VIEW pipeline_status_card_view AS
WITH quality_summary AS (
    SELECT
        COUNT(*) AS tables_checked,
        SUM(CASE WHEN quality_status = 'Good' THEN 1 ELSE 0 END) AS tables_good,
        SUM(CASE WHEN quality_status = 'Partial' THEN 1 ELSE 0 END) AS tables_partial,
        SUM(CASE WHEN quality_status = 'Needs enrichment' THEN 1 ELSE 0 END) AS tables_needs_enrichment,
        SUM(CASE WHEN quality_status = 'Not available' THEN 1 ELSE 0 END) AS tables_missing,
        ROUND(AVG(quality_score), 1) AS avg_quality_score,
        MIN(quality_score) AS min_quality_score,
        MAX(quality_score) AS max_quality_score
    FROM pipeline_data_quality
),
last_run AS (
    SELECT last_run_timestamp FROM pipeline_last_run
)
SELECT
    last_run.last_run_timestamp,
    quality_summary.*,
    CASE
        WHEN quality_summary.tables_missing > 0 THEN 'Incomplete pipeline'
        WHEN quality_summary.tables_needs_enrichment > 0 THEN 'Needs enrichment'
        WHEN quality_summary.tables_partial > 0 THEN 'Partial'
        ELSE 'Good'
    END AS pipeline_status
FROM quality_summary
CROSS JOIN last_run
")

# ----------------------------------------
# SUMMARY
# ----------------------------------------

log_step("✅ Pipeline validation complete")

print(dbGetQuery(con, "SELECT * FROM pipeline_status_card_view"))

disconnect_db(con)

