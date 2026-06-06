# ----------------------------------------
# STAGE: INGESTION
# STEP: GBIF TAXONOMIC DATA INGESTION
#
# SOURCE:
# - GBIF (Global Biodiversity Information Facility)
# - API / dataset ingestion
#
# PURPOSE:
# - Retrieve plant taxonomic backbone data
# - Load raw plant records into staging tables
#
# INPUT:
# - External GBIF data
#
# OUTPUT:
# - Raw GBIF plant data (staging layer)
#
# NOTES:
# - Primary source of plant identity
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)
library(rgbif)
library(dplyr)

# connect
con <- dbConnect(duckdb(), dbdir = here("database", "ker_huella.duckdb"))

# read plant list
plant_list <- read.csv(
  here("data", "raw", "plant_list.csv"),
  stringsAsFactors = FALSE
)

# initialise collector
all_occ <- NULL

# loop through plants
for (i in seq_len(nrow(plant_list))) {
  
  plant_name <- plant_list$latin_name[i]
  
  print(paste("Querying GBIF for:", plant_name))
  
  occ <- tryCatch(
    occ_search(scientificName = plant_name, limit = 50),
    error = function(e) NULL
  )
  
  if (!is.null(occ) && !is.null(occ$data) && nrow(occ$data) > 0) {
    
    if (is.null(all_occ)) {
      all_occ <- occ$data
    } else {
      all_occ <- bind_rows(all_occ, occ$data)
    }
    
  }
}

# stop if nothing returned
if (is.null(all_occ)) {
  stop("No data returned from GBIF")
}

# write table
dbExecute(con, "DROP TABLE IF EXISTS raw_gbif_plants")
dbWriteTable(con, "raw_gbif_plants", all_occ)

# verify
result <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM raw_gbif_plants")
print(result)

# close
dbDisconnect(con, shutdown = TRUE)
