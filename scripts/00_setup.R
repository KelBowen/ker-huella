# ----------------------------------------
# STAGE: SETUP
# STEP: ENVIRONMENT INITIALISATION
#
# PURPOSE:
# - Initialise project environment
# - Load required libraries
# - Establish database connection (DuckDB)
#
# INPUT:
# - None
#
# OUTPUT:
# - Active database connection
# - Environment ready for pipeline execution
#
# NOTES:
# - Must be run first in pipeline
# - No data transformations performed
# ----------------------------------------

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(glue)
  library(here)
  library(janitor)
  library(dplyr)
  library(readr)
  library(lubridate)
})

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

# ---- Paths ----
PATHS <- list(
  data_raw = here("data", "raw"),
  data_processed = here("data", "processed"),
  database = here("database"),
  outputs = here("outputs"),
  sql = here("sql"),
  db_file = here("database", "ker_huella.duckdb")
)

# ---- Ensure folders exist ----
ensure_project_dirs <- function() {
  dirs <- c(
    PATHS$data_raw,
    PATHS$data_processed,
    PATHS$database,
    PATHS$outputs,
    PATHS$sql
  )
  
  for (d in dirs) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
}

# ---- Database connection helper ----
connect_db <- function(read_only = FALSE) {
  ensure_project_dirs()
  
  if (!file.exists(PATHS$db_file)) {
    file.create(PATHS$db_file)
  }
  
  log_step(glue("Connecting to DB: {PATHS$db_file}"))
  
  con <- dbConnect(
    duckdb::duckdb(),
    dbdir = PATHS[["db_file"]],
    read_only = read_only
  )
  
  return(con)
}

# ---- Safe disconnect ----
disconnect_db <- function(con) {
  try(dbDisconnect(con, shutdown = TRUE), silent = TRUE)
}

# ---- Logging helper ----
log_step <- function(msg) {
  cat(glue("[{Sys.time()}] {msg}\n"))
}

# ---- Initialise project ----
ensure_project_dirs()
log_step("Project setup loaded successfully.")