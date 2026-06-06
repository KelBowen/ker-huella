
# ----------------------------------------
# HELPER: PIPELINE EXECUTION
#
# PURPOSE:
# - Execute full Ker-Huella pipeline in correct order
#
# USAGE:
# source("scripts/helpers/run_pipeline.R")
#
# NOTES:
# - Orchestrates all stages
# - Does not contain transformation logic itself
# ----------------------------------------



cat("========================================\n")
cat("KER-HUELLA PIPELINE START\n")
cat("========================================\n\n")

# ----------------------------------------
# STAGE 00: SETUP & CONNECTION
# ----------------------------------------
cat("Stage 00: Setup\n")
source("scripts/00_setup.R")

# ----------------------------------------
# STAGE 01: INGESTION
# ----------------------------------------
cat("\nStage 01: GBIF Ingestion\n")
source("scripts/01_gbif_ingest.R")

cat("Stage 02: Stage Plants\n")
source("scripts/02_stage_plants.R")

# ----------------------------------------
# STAGE 10: DATA MODEL BUILD
# ----------------------------------------
cat("\nStage 10: Create Plant Parts\n")
source("scripts/10_create_plant_parts.R")

cat("Stage 11: Create Uses\n")
source("scripts/11_create_uses.R")

cat("Stage 12: Create Preparations\n")
source("scripts/12_create_preparations.R")

cat("Stage 13: Create Locations\n")
source("scripts/13_create_locations.R")

cat("Stage 14: Create Plant Locations\n")
source("scripts/14_create_plant_locations.R")

# ----------------------------------------
# STAGE 20: ENRICHMENT
# ----------------------------------------
cat("\nStage 20: Enrich English Names (USDA)\n")
source("scripts/20_enrich_names_usda.R")

cat("Stage 21: Enrich French Names (eFlore Algolia)\n")
source("scripts/21_enrich_names_french_algolia.R")

cat("Stage 22: Enrich Uses (Wikipedia)\n")
source("scripts/22_enrich_uses_wikipedia.R")

# ----------------------------------------
# STAGE 30: OUTPUT
# ----------------------------------------
cat("\nStage 30: Create Plant Card View\n")
source("scripts/30_create_plant_card_view.R")

cat("\n========================================\n")
cat("KER-HUELLA PIPELINE COMPLETE ✅\n")
cat("========================================\n")
