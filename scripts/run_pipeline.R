# core setup 
source("scripts/00_setup.R")
source("scripts/01_gbif_ingest.R")
source("scripts/02_stage_plants.R")

# enrichment data 
source("scripts/06_enrich_names_usda.R")
source("scripts/07_enrich_uses_wikipedia.R")

# presentation and views
source("scripts/20_create_plant_card_view.R")
