# ----------------------------------------
# STAGE: MODEL BUILD
# STEP: CREATE LOCATIONS TABLE
#
# PURPOSE:
# - Define physical garden locations (beds, zones, etc.)
#
# INPUT:
# - None (manual / structural table)
#
# OUTPUT:
# - locations table
#
# NOTES:
# - Represents real-world Ker-Huella garden structure
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# create locations table (manual curated list)
locations <- data.frame(
  location_id = c("LOC_1", "LOC_2", "LOC_3"),
  location_name = c(
    "Kitchen Garden",
    "North Hedge",
    "Wild Meadow"
  ),
  description = c(
    "Vegetable and herb growing area",
    "Boundary hedge with wild plants",
    "Unmanaged meadow area"
  ),
  stringsAsFactors = FALSE
)

# write table
dbExecute(con, "DROP TABLE IF EXISTS locations")
dbWriteTable(con, "locations", locations)

# verify
print(dbGetQuery(con, "SELECT * FROM locations"))

dbDisconnect(con, shutdown = TRUE)