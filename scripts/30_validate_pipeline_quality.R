# 30_validate_pipeline_quality.R
# ----------------------------------------
# PURPOSE:
# - Validate operational layer
# - Validate reference layer
# - Validate image enrichment
# - Generate QA metrics and reporting views
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(tibble)
library(DBI)

cat("\n========================================\n")
cat("STAGE 30: PIPELINE QUALITY VALIDATION\n")
cat("========================================\n\n")

con <- connect_db()

if (!DBI::dbIsValid(con)) {
  stop("❌ Invalid database connection")
}

run_timestamp <- Sys.time()
run_id <- format(run_timestamp, "%Y%m%d%H%M%S")
pipeline_stage <- "30_validate_pipeline_quality"
run_notes <- "Reference architecture validation"

table_exists <- function(con, table_name) {
  table_name %in% DBI::dbListTables(con)
}

safe_read <- function(con, table_name) {
  if (!table_exists(con, table_name)) return(NULL)
  tryCatch(DBI::dbReadTable(con, table_name), error = function(e) NULL)
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
  completeness <- calc_completeness_pct(row_count, missing_required)
  status <- calc_quality_status(completeness, row_count)
  
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

# LOAD TABLES
seed_plants <- safe_read(con, "seed_plants")
plant_reference_view <- safe_read(con, "plant_reference_view")
plant_reference_images_validated <- safe_read(con, "plant_reference_images_validated")
plant_card_view <- safe_read(con, "plant_card_view")
qa_missing_images <- safe_read(con, "qa_missing_images")

quality_tbl <- bind_rows(
  
  make_row(
    "seed_plants",
    seed_plants,
    c("latin_name"),
    "Operational source"
  ),
  
  make_row(
    "plant_reference_view",
    plant_reference_view,
    c(
      "latin_name",
      "medicinal_actions",
      "body_systems",
      "selected_url",
      "has_image",
      "has_safety",
      "has_parts",
      "has_medicinal_actions"
    ),
    "Power BI reference layer"
  ),
  
  make_row(
    "plant_reference_images_validated",
    plant_reference_images_validated,
    c(
      "latin_name",
      "selected_url",
      "selected_source",
      "selected_level"
    ),
    "Validated image layer"
  ),
  
  make_row(
    "plant_card_view",
    plant_card_view,
    c("latin_name"),
    "Presentation layer"
  ),
  
  make_row(
    "qa_missing_images",
    qa_missing_images,
    c("latin_name"),
    "Image remediation queue"
  )
)

DBI::dbExecute(con, '
CREATE TABLE IF NOT EXISTS pipeline_run_metadata (
run_id VARCHAR,
run_timestamp VARCHAR,
run_stage VARCHAR,
run_notes VARCHAR
)')

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

DBI::dbWriteTable(con,"pipeline_data_quality",quality_tbl,overwrite=TRUE)

DBI::dbExecute(con,
               "CREATE OR REPLACE VIEW pipeline_data_quality_view AS
 SELECT * FROM pipeline_data_quality ORDER BY table_name")

DBI::dbExecute(con,
               "CREATE OR REPLACE VIEW pipeline_last_run AS
 SELECT * FROM pipeline_run_metadata ORDER BY run_timestamp DESC LIMIT 1")

DBI::dbExecute(con,
               "CREATE OR REPLACE VIEW pipeline_reference_coverage_view AS
SELECT
COUNT(*) AS total_plants,
SUM(CASE WHEN has_image THEN 1 ELSE 0 END) AS image_count,
SUM(CASE WHEN has_medicinal_actions THEN 1 ELSE 0 END) AS medicinal_count,
SUM(CASE WHEN has_safety THEN 1 ELSE 0 END) AS safety_count,
SUM(CASE WHEN has_parts THEN 1 ELSE 0 END) AS parts_count,
ROUND(100.0 * SUM(CASE WHEN has_image THEN 1 ELSE 0 END)/COUNT(*),1) AS image_coverage_pct
FROM plant_reference_view")

DBI::dbExecute(con,
               "CREATE OR REPLACE VIEW pipeline_status_card_view AS
WITH quality_summary AS (
SELECT
COUNT(*) AS tables_checked,
SUM(CASE WHEN quality_status='Good' THEN 1 ELSE 0 END) AS tables_good,
SUM(CASE WHEN quality_status='Partial' THEN 1 ELSE 0 END) AS tables_partial,
SUM(CASE WHEN quality_status='Needs enrichment' THEN 1 ELSE 0 END) AS tables_needs_enrichment,
ROUND(AVG(quality_score),1) AS avg_quality_score
FROM pipeline_data_quality)
SELECT * FROM quality_summary")

print(DBI::dbGetQuery(con,'SELECT * FROM pipeline_reference_coverage_view'))

disconnect_db(con)
cat("\nSTAGE 30 COMPLETE ✅\n")
