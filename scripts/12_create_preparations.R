library(DBI)
library(duckdb)
library(here)

# connect
con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# read uses table
uses <- dbReadTable(con, "uses")

# create preparations table (simple initial version)
preparations <- data.frame(
  preparation_id = paste0("PREP_", seq_len(nrow(uses))),
  use_id = uses$use_id,
  preparation_type = "unspecified",
  stringsAsFactors = FALSE
)

# write table
dbExecute(con, "DROP TABLE IF EXISTS preparations")
dbWriteTable(con, "preparations", preparations)

# verify
print(dbGetQuery(con, "SELECT * FROM preparations"))

# close
dbDisconnect(con, shutdown = TRUE)