# GBIF ingestion - first pipeline
# -------------------------------
# Goal:
#   Pull one plant from GBIF and persist raw results into DuckDB

source(here::here("scripts", "00_setup.R"))

suppressPackageStartupMessages({
  library(rgbif)
  library(jsonlite)
})

log_step("Starting GBIF ingestion test")

# ---- Query plant ----
plant_name <- "Urtica dioica"

log_step(glue("Querying GBIF backbone for: {plant_name}"))
backbone <- rgbif::name_backbone(name = plant_name)

print(backbone)

# ---- Get occurrence data ----
log_step(glue("Querying GBIF occurrence data for: {plant_name}"))
occ <- rgbif::occ_search(
  scientificName = plant_name,
  limit = 50
)

occ_df <- occ$data

# ---- Clean names ----
occ_df <- occ_df |>
  janitor::clean_names()

# ---- Connect to DB ----
con <- connect_db()
on.exit(disconnect_db(con), add = TRUE)

# ---- Persist raw table ----
table_name <- "raw_gbif_urtica_dioica"

log_step(glue("Writing {nrow(occ_df)} rows to table: {table_name}"))
dbWriteTable(
  con,
  name = table_name,
  value = occ_df,
  overwrite = TRUE
)

# ---- Quick verification ----
row_count <- dbGetQuery(con, glue("SELECT COUNT(*) AS n FROM {table_name}"))
print(row_count)

log_step("GBIF ingestion test completed successfully.")