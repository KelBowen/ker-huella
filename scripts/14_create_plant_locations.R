# ----------------------------------------
# STAGE: MODEL BUILD
# STEP: CREATE PLANT-LOCATION RELATIONSHIP
#
# PURPOSE:
# - Link plants to physical locations
# - Track where plants exist in the garden
#
# INPUT:
# - plants table
# - locations table
#
# OUTPUT:
# - plant_locations table
#
# NOTES:
# - Enables spatial tracking and garden management
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

plants <- dbReadTable(con, "plants")

# simple mapping (initial placeholder)
plant_locations <- data.frame(
  plant_id = plants$plant_id,
  location_id = "LOC_1",
  stringsAsFactors = FALSE
)

dbExecute(con, "DROP TABLE IF EXISTS plant_locations")
dbWriteTable(con, "plant_locations", plant_locations)

print(dbGetQuery(con, "SELECT * FROM plant_locations"))

dbDisconnect(con, shutdown = TRUE)
