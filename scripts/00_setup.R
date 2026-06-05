# Ker-Huella project setup
# ------------------------
# Purpose:
#   Shared setup for all ingestion / transformation scripts

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

# ---- Project options ----
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
  dbConnect(
    duckdb::duckdb(),
    dbdir = PATHS$db_file,
    read_only = read_only
  )
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



