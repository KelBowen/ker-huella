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
# - Gives a clear error if the BI DB is locked by another process
# ----------------------------------------

source("scripts/00_setup.R")

cat("\n========================================\n")
cat("STAGE 99: CREATE BI DATAMART COPY\n")
cat("========================================\n\n")

# ----------------------------------------
# DEFINE PATHS
# ----------------------------------------

source_db <- here::here("database", "ker_huella.duckdb")
bi_db <- here::here("database", "ker_huella_bi.duckdb")
tmp_bi_db <- here::here("database", "ker_huella_bi_tmp.duckdb")

# ----------------------------------------
# RELEASE ANY OPEN CONNECTIONS
# ----------------------------------------

cat("Releasing any existing database connections...\n")

try({
  DBI::dbDisconnect(con, shutdown = TRUE)
}, silent = TRUE)

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
# CLEAN TEMP FILE
# ----------------------------------------

if (file.exists(tmp_bi_db)) {
  unlink(tmp_bi_db, force = TRUE)
}

# ----------------------------------------
# COPY TO TEMP FIRST
# ----------------------------------------

cat("Creating temporary BI database copy...\n")

tmp_success <- file.copy(
  from = source_db,
  to = tmp_bi_db,
  overwrite = TRUE
)

if (!tmp_success || !file.exists(tmp_bi_db)) {
  stop("❌ Failed to create temporary BI database copy")
}

cat("✅ Temporary copy created\n")

# ----------------------------------------
# REPLACE BI DB
# ----------------------------------------

if (file.exists(bi_db)) {
  remove_success <- tryCatch(
    {
      unlink(bi_db, force = TRUE)
      !file.exists(bi_db)
    },
    warning = function(e) FALSE,
    error = function(e) FALSE
  )
  
  if (!remove_success) {
    stop(
      "❌ Could not replace BI database file. ",
      "The file is likely open or locked (for example by Power BI or sync software): ",
      bi_db
    )
  }
}

rename_success <- file.rename(tmp_bi_db, bi_db)

if (!rename_success || !file.exists(bi_db)) {
  stop(
    "❌ Failed to move temporary BI database into place: ",
    bi_db
  )
}

# ----------------------------------------
# VALIDATE COPY
# ----------------------------------------

bi_size <- file.info(bi_db)$size
cat("BI DB size:", bi_size, "bytes\n")

if (bi_size == 0) {
  stop("❌ BI database is empty — copy failed")
}

if (!is.na(source_size) && !is.na(bi_size) && bi_size != source_size) {
  warning("⚠️ BI database size differs from source (may still be valid)")
} else {
  cat("✅ BI database size matches source\n")
}

# ----------------------------------------
# SMOKE TEST
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

required_tables <- c(
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

cat("\n========================================\n")
cat("BI DATAMART READY ✅\n")
cat("========================================\n\n")
