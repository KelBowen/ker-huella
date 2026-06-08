# ----------------------------------------
# STAGE: DEPLOYMENT / DATAMART
# STEP: CREATE BI DATABASE COPY
#
# PURPOSE:
# - Create a stable, read-only copy of the DuckDB database
# - Provide a clean datamart layer for Power BI
#
# INPUT:
# - database/ker_huella.duckdb
#
# OUTPUT:
# - database/ker_huella_bi.duckdb
#
# NOTES:
# - Must run AFTER pipeline completes
# - Releases DB lock before copying
# - Ensures BI tools do not conflict with pipeline
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)

cat("\n========================================\n")
cat("STAGE 99: CREATE BI DATAMART COPY\n")
cat("========================================\n\n")

# ----------------------------------------
# DEFINE PATHS
# ----------------------------------------

source_db <- here::here("database", "ker_huella.duckdb")
bi_db <- here::here("database", "ker_huella_bi.duckdb")

# ----------------------------------------
# RELEASE ANY OPEN CONNECTIONS
# ----------------------------------------

cat("Releasing any existing database connections...\n")

# Attempt to close common connection variable
try({
  DBI::dbDisconnect(con, shutdown = TRUE)
}, silent = TRUE)

# Also attempt generic cleanup (defensive)
try({
  existing_cons <- DBI::dbListConnections(duckdb::duckdb())
  for (c in existing_cons) {
    try(DBI::dbDisconnect(c, shutdown = TRUE), silent = TRUE)
  }
}, silent = TRUE)

cat("✅ Connections released (if any existed)\n")

# ----------------------------------------
# VALIDATE SOURCE DB EXISTS
# ----------------------------------------

if (!file.exists(source_db)) {
  stop("❌ Source database not found: ", source_db)
}

source_size <- file.info(source_db)$size

cat("Source DB size:", source_size, "bytes\n")

# ----------------------------------------
# CREATE BI COPY
# ----------------------------------------

cat("Creating BI database copy...\n")

success <- file.copy(
  from = source_db,
  to = bi_db,
  overwrite = TRUE
)

if (!success) {
  stop("❌ Failed to copy database file")
}

# ----------------------------------------
# VALIDATE COPY
# ----------------------------------------

if (!file.exists(bi_db)) {
  stop("❌ BI database copy was not created")
}

bi_size <- file.info(bi_db)$size

cat("BI DB size:", bi_size, "bytes\n")

if (bi_size == 0) {
  stop("❌ BI database is empty — copy failed")
}

if (bi_size != source_size) {
  warning("⚠️ BI database size differs from source (may still be valid)")
} else {
  cat("✅ BI database size matches source\n")
}

# ----------------------------------------
# SMOKE TEST CONNECTION
# ----------------------------------------

cat("Verifying BI database contents...\n")

con_bi <- DBI::dbConnect(
  duckdb::duckdb(),
  dbdir = bi_db,
  read_only = TRUE
)

tables <- DBI::dbListTables(con_bi)

cat("Tables found in BI database:\n")
print(tables)

# Optional: check critical tables exist
required_tables <- c(
  "plants",
  "plant_names",
  "plant_card_view",
  "pipeline_data_quality",
  "pipeline_last_run"
)

missing_tables <- setdiff(required_tables, tables)

if (length(missing_tables) > 0) {
  warning("⚠️ Some expected tables are missing:")
  print(missing_tables)
} else {
  cat("✅ All key tables present\n")
}

DBI::dbDisconnect(con_bi, shutdown = TRUE)

# ----------------------------------------
# COMPLETE
# ----------------------------------------

cat("\n========================================\n")
cat("BI DATAMART READY ✅\n")
cat("========================================\n\n")