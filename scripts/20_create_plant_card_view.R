
library(DBI)
library(duckdb)
library(here)

# --------------------------------------------------
# CONNECT
# --------------------------------------------------

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# --------------------------------------------------
# LOAD TABLES
# --------------------------------------------------

plants <- dbReadTable(con, "plants")
plant_names <- dbReadTable(con, "plant_names")
plant_uses <- dbReadTable(con, "plant_uses")

# --------------------------------------------------
# CLEAN EXISTING OBJECT (FIXES VIEW/TABLE CONFLICT)
# --------------------------------------------------

dbExecute(con, "DROP VIEW IF EXISTS plant_card_view")
dbExecute(con, "DROP TABLE IF EXISTS plant_card_view")

# --------------------------------------------------
# BUILD FINAL VIEW TABLE
# --------------------------------------------------

plant_card_view <- plants |>
  merge(plant_names, by = "plant_id", all.x = TRUE) |>
  merge(plant_uses, by = "plant_id", all.x = TRUE)

# --------------------------------------------------
# SAVE TABLE
# --------------------------------------------------

dbWriteTable(
  con,
  "plant_card_view",
  plant_card_view,
  overwrite = TRUE
)

# --------------------------------------------------
# VERIFY OUTPUT
# --------------------------------------------------

print(
  dbGetQuery(
    con,
    "SELECT 
        plant_id,
        latin_name,
        english_name,
        substr(wikipedia_summary, 1, 120) AS summary_preview
     FROM plant_card_view
     LIMIT 10"
  )
)

# --------------------------------------------------
# CLOSE CONNECTION
# --------------------------------------------------

dbDisconnect(con, shutdown = TRUE)
