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
# OUTPUT:
# - pipelinreae_run_metadata
# - pipeline_data_quality
# - pipeline_data_quality_view
# - pipeline_last_run
# - pipeline_status_card_view
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

if (!DBI::dbIsValid(con)) {
  stop("❌ Invalid database connection")
}

log_step("Tables available:")
print(dbListTables(con))

# ----------------------------------------
# RUN METADATA
# ----------------------------------------

run_timestamp <- Sys.time()
run_id <- format(run_timestamp, "%Y%m%d%H%M%S")

pipeline_stage <- "30_validate_pipeline_quality"

run_notes <- "Phase 2 pipeline validation"

# ----------------------------------------
# HELPERS
# ----------------------------------------

table_exists <- function(con, table_name) {
  table_name %in% dbListTables(con)
}

safe_read <- function(con, table_name) {
  
  if (!table_exists(con, table_name)) {
    return(NULL)
  }
  
  tryCatch(
    DBI::dbReadTable(con, table_name),
    error = function(e) NULL
  )
}

safe_query <- function(con, query) {
  
  tryCatch(
    DBI::dbGetQuery(con, query),
    error = function(e) data.frame(n = NA)
  )
}

count_missing <- function(df, cols) {
  
  if (is.null(df) || nrow(df) == 0) {
    return(0)
  }
  
  existing_cols <- intersect(cols, names(df))
  
  if (length(existing_cols) == 0) {
    return(0)
  }
  
  df %>%
    mutate(across(all_of(existing_cols), ~ is.na(.) | . == "")) %>%
    filter(if_any(all_of(existing_cols), identity)) %>%
    nrow()
}

calc_completeness_pct <- function(row_count, missing_count) {
  
  if (row_count == 0) {
    return(0)
  }
  
  round(
    ((row_count - missing_count) / row_count) * 100,
    1
  )
}

calc_quality_status <- function(score, row_count) {
  
  if (row_count == 0) {
    return("Not available")
  }
  
  if (score >= 90) {
    return("Good")
  }
  
  if (score >= 60) {
    return("Partial")
  }
  
  "Needs enrichment"
}

make_row <- function(name, df, cols, notes) {
  
  table_missing <- is.null(df)
  
  row_count <- if (table_missing) 0 else nrow(df)
  
  existing_cols <- if (table_missing) {
    character(0)
  } else {
    intersect(cols, names(df))
  }
  
  missing_cols <- if (table_missing) {
    cols
  } else {
    setdiff(cols, names(df))
  }
  
  missing_required <- count_missing(df, existing_cols)
  
  completeness <- calc_completeness_pct(
    row_count,
    missing_required
  )
  
  status <- calc_quality_status(
    completeness,
    row_count
  )
  
  tibble(
    run_id = run_id,
    run_timestamp = format(run_timestamp, "%Y-%m-%d %H:%M:%S"),
    table_name = name,
    row_count = row_count,
    required_columns = paste(cols, collapse = ", "),
    missing_columns = paste(missing_cols, collapse = ", "),
    missing_required_count = missing_required,
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
# BUILD QUALITY TABLE
# ----------------------------------------

quality_tbl <- bind_rows(
  
  make_row(
    "seed_plants",
    seed_plants,
    c(
      "latin_name",
      "english_name",
      "french_name",
      "native",
      "status_name",
      "plant_type_name"
    ),
    "Operational source of truth"
  ),
  
  make_row(
    "locations",
    locations,
    c("location_id", "location_name"),
    "Location dimension"
  ),
  
  make_row(
    "plant_locations",
    plant_locations,
    c("latin_name", "location_id"),
    "Plant-location link"
  ),
  
  make_row(
    "plant_reference_raw",
    plant_reference_raw,
    c("latin_name"),
    "PFAF raw enrichment"
  ),
  
  make_row(
    "plant_reference_uses",
    plant_reference_uses,
    c("latin_name", "use_type"),
    "Structured uses"
  ),
  
  make_row(
    "plant_card_view",
    plant_card_view,
    c(
      "latin_name",
      "english_name",
      "french_name",
      "native",
      "locations",
      "native_status",
      "stewardship_status"
    ),
    "Final consumption layer"
  )
  
)

# ----------------------------------------
# RELATIONSHIP CHECKS
# ----------------------------------------

missing_native <- safe_query(
  con,
  "
  SELECT COUNT(*) AS n
  FROM seed_plants
  WHERE native IS NULL
  "
)

log_step(
  paste(
    'Plants missing native flag:',
    missing_native$n
  )
)

invalid_status <- safe_query(
  con,
  "
  SELECT COUNT(*) AS n
  FROM seed_plants
  WHERE status_name NOT IN (
    'Plantée',
    'Prévu',
    'Sauvage'
  )
  OR status_name IS NULL
  "
)

log_step(
  paste(
    'Plants with unexpected stewardship status:',
    invalid_status$n
  )
)

missing_locations <- safe_query(
  con,
  "
  SELECT COUNT(*) AS n
  FROM seed_plants sp
  LEFT JOIN plant_locations pl
    ON sp.latin_name = pl.latin_name
  WHERE pl.latin_name IS NULL
  "
)

log_step(
  paste(
    'Plants without locations:',
    missing_locations$n
  )
)

# ----------------------------------------
# SAVE METADATA
# ----------------------------------------

DBI::dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS pipeline_run_metadata (
    run_id VARCHAR,
    run_timestamp VARCHAR,
    run_stage VARCHAR,
    run_notes VARCHAR
  )
  "
)

DBI::dbExecute(
  con,
  sprintf(
    "INSERT INTO pipeline_run_metadata VALUES ('%s','%s','%s','%s')",
    run_id,
    format(run_timestamp, "%Y-%m-%d %H:%M:%S"),
    pipeline_stage,
    run_notes
  )
)
# ----------------------------------------
# SAVE QUALITY TABLE
# ----------------------------------------

DBI::dbExecute(
  con,
  "DROP TABLE IF EXISTS pipeline_data_quality"
)

DBI::dbWriteTable(
  con,
  "pipeline_data_quality",
  quality_tbl,
  overwrite = TRUE
)

# ----------------------------------------
# VIEWS
# ----------------------------------------

DBI::dbExecute(
  con,
  "
  CREATE OR REPLACE VIEW pipeline_data_quality_view AS
  SELECT *
  FROM pipeline_data_quality
  ORDER BY table_name
  "
)

DBI::dbExecute(
  con,
  "
  CREATE OR REPLACE VIEW pipeline_last_run AS
  SELECT
      run_id,
      run_timestamp AS last_run_timestamp,
      run_stage
  FROM pipeline_run_metadata
  ORDER BY run_timestamp DESC
  LIMIT 1
  "
)

DBI::dbExecute(
  con,
  "
  CREATE OR REPLACE VIEW pipeline_status_card_view AS
  WITH quality_summary AS (
      SELECT
          COUNT(*) AS tables_checked,
          SUM(CASE WHEN quality_status = 'Good' THEN 1 ELSE 0 END) AS tables_good,
          SUM(CASE WHEN quality_status = 'Partial' THEN 1 ELSE 0 END) AS tables_partial,
          SUM(CASE WHEN quality_status = 'Needs enrichment' THEN 1 ELSE 0 END) AS tables_needs_enrichment,
          SUM(CASE WHEN quality_status = 'Not available' THEN 1 ELSE 0 END) AS tables_missing,
          ROUND(AVG(quality_score),1) AS avg_quality_score
      FROM pipeline_data_quality
  )
  SELECT
      plr.last_run_timestamp,
      qs.*,
      CASE
          WHEN qs.tables_missing > 0 THEN 'Incomplete pipeline'
          WHEN qs.tables_needs_enrichment > 0 THEN 'Needs enrichment'
          WHEN qs.tables_partial > 0 THEN 'Partial'
          ELSE 'Good'
      END AS pipeline_status
  FROM quality_summary qs
  CROSS JOIN pipeline_last_run plr
  "
)

# ----------------------------------------
# SUMMARY
# ----------------------------------------

log_step("✅ Pipeline validation complete")

print(
  DBI::dbGetQuery(
    con,
    "SELECT * FROM pipeline_status_card_view"
  )
)

DBI::dbDisconnect(con, shutdown = TRUE)

cat("\n========================================\n")
cat("STAGE 29 COMPLETE ✅\n")
cat("========================================\n")