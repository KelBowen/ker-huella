library(DBI)
library(duckdb)
library(here)

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

df <- dbReadTable(con, "raw_gbif_plants")

# keep rows with a usable scientific name
df <- df[!is.na(df$scientificName) & df$scientificName != "", ]

# one row per taxonKey where available, otherwise one row per scientificName
df_with_key <- df[!is.na(df$taxonKey), ]
plants_unique <- df_with_key[!duplicated(df_with_key$taxonKey), ]

# simple plants table
plants_df <- data.frame(
  plant_id = paste0("PL_", seq_len(nrow(plants_unique))),
  latin_name = plants_unique$scientificName,
  accepted_name = plants_unique$acceptedScientificName,
  family = plants_unique$family,
  genus = plants_unique$genus,
  taxon_key = plants_unique$taxonKey,
  
  english_name = plants_unique$genericName,
  
  created_at = Sys.time(),
  stringsAsFactors = FALSE
)

dbExecute(con, "DROP TABLE IF EXISTS plants")
dbWriteTable(con, "plants", plants_df, overwrite = TRUE)

print(dbGetQuery(con, "SELECT COUNT(*) AS n FROM plants"))
print(dbGetQuery(con, "SELECT * FROM plants"))

dbDisconnect(con, shutdown = TRUE)