# ----------------------------------------
# STAGE: MODEL BUILD
# STEP: CREATE PLANT PARTS TABLE
#
# PURPOSE:
# - Define plant anatomical structure
# - Store harvestable parts (leaf, root, flower, etc.)
#
# INPUT:
# - plants table
#
# OUTPUT:
# - plant_parts table
#
# NOTES:
# - Supports part-level use tracking
# - Required for downstream uses and preparations
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)

# connect
con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# read plants table
plants <- dbReadTable(con, "plants")

# create plant parts table (simple initial version)
plant_parts <- data.frame(
  part_id = paste0("PART_", seq_len(nrow(plants))),
  plant_id = plants$plant_id,
  part_name = "whole plant",
  stringsAsFactors = FALSE
)

# write table
dbExecute(con, "DROP TABLE IF EXISTS plant_parts")
dbWriteTable(con, "plant_parts", plant_parts)

# verify
print(dbGetQuery(con, "SELECT * FROM plant_parts"))

# close
dbDisconnect(con, shutdown = TRUE)