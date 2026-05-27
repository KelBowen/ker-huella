
library(DBI)
library(duckdb)
library(here)

# connect
con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# read raw table
df <- dbReadTable(con, "raw_gbif_urtica_dioica")

# create plants table (minimal, no column references)
plants_df <- data.frame(
  plant_id = paste0("PL_", seq_len(nrow(df))),
  latin_name = df$scientific_name,
  accepted_name = df$scientific_name,
  family = df$family,
  genus = df$genus,
  stringsAsFactors = FALSE
)
``
# write table
dbExecute(con, "DROP TABLE IF EXISTS plants")
dbWriteTable(con, "plants", plants_df)

# verify
print(dbGetQuery(con, "SELECT * FROM plants"))

# close
dbDisconnect(con, shutdown = TRUE)

