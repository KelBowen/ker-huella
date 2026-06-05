library(DBI)
library(duckdb)
library(here)

# connect
con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# read plant_parts
parts <- dbReadTable(con, "plant_parts")

# create uses table (initial simple version)
uses <- data.frame(
  use_id = paste0("USE_", seq_len(nrow(parts))),
  part_id = parts$part_id,
  use_category = "reference",
  use_description = "No defined use yet",
  stringsAsFactors = FALSE
)

# write table
dbExecute(con, "DROP TABLE IF EXISTS uses")
dbWriteTable(con, "uses", uses)

# verify
print(dbGetQuery(con, "SELECT * FROM uses"))

# close
dbDisconnect(con, shutdown = TRUE)