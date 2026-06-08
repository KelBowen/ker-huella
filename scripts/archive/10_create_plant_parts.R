
# ----------------------------------------
# STAGE: MODEL BUILD (LEGACY)
# STEP: CREATE PLANT PARTS TABLE
#
# PURPOSE:
# - Define simple plant parts reference (Phase 1 only)
#
# NOTES:
# - Not used in Phase 2 pipeline
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)

con <- connect_db()

if (!"plants" %in% dbListTables(con)) {
  disconnect_db(con)
  stop("❌ plants table not found")
}

plants <- dbReadTable(con, "plants")

plant_parts <- data.frame(
  part_id = paste0("PART_", seq_len(nrow(plants))),
  plant_id = plants$plant_id,
  part_name = "whole plant",
  stringsAsFactors = FALSE
)

dbExecute(con, "DROP TABLE IF EXISTS plant_parts")
dbWriteTable(con, "plant_parts", plant_parts)

print(dbGetQuery(con, "SELECT COUNT(*) FROM plant_parts"))

disconnect_db(con)

log_step("Plant parts (legacy) created ✅")
