
# ----------------------------------------
# SCRIPT: run_pipeline.R
#
# PURPOSE:
# - Execute full Ker-Huella Phase 2 data pipeline
# - Orchestrate ingestion, enrichment, parsing, validation, and output
#
# SCOPE:
# - Input:
#     SharePoint export (seed_plants)
#     External PFAF data
#
# - Output:
#     plant_card_view (final dataset for Power BI)
#     pipeline validation tables/views
#
# USAGE:
# source("scripts/run_pipeline.R")
#
# NOTES:
# - This script is an orchestrator ONLY (no transformation logic)
# - Phase 1 pipeline has been fully deprecated and archived
# - All stages rely on shared setup (00_setup.R) for DB connectivity
#
# PIPELINE STAGES:
# 00 → Setup
# 03 → Operational ingestion (SharePoint)
# 20 → PFAF enrichment (cached)
# 21 → PFAF parsing (structured uses)
# 30 → Output view (plant_card_view)
# 29 → Validation (pipeline health + metrics)
# ----------------------------------------

cat("========================================\n")
cat("KER-HUELLA PIPELINE START (PHASE 2)\n")
cat("========================================\n\n")

pipeline_start <- Sys.time()

# ----------------------------------------
# STAGE 00: SETUP
# ----------------------------------------

cat("Stage 00: Setup\n")
source("scripts/00_setup.R")

# ========================================
# PHASE 2: OPERATIONAL + PFAF
# ========================================

cat("\n----------------------------------------\n")
cat("PHASE 2: OPERATIONAL + PFAF\n")
cat("----------------------------------------\n")

# ----------------------------------------
# STAGE 03: INGESTION
# ----------------------------------------

cat("\nStage 03: Ingest SharePoint Data\n")
source("scripts/03_ingest_operational_data.R")

# ----------------------------------------
# STAGE 20: ENRICHMENT (PFAF)
# ----------------------------------------

cat("\nStage 20: PFAF Enrichment\n")
source("scripts/20_enrich_pfaf.R")

# ----------------------------------------
# STAGE 21: STRUCTURING (PARSE USES)
# ----------------------------------------

cat("\nStage 21: Parse PFAF Uses\n")
source("scripts/21_parse_pfaf_uses.R")

# ----------------------------------------
# STAGE 30: OUTPUT
# ----------------------------------------

cat("\nStage 30: Create Plant Card View\n")
source("scripts/30_create_plant_card_view.R")

# ----------------------------------------
# STAGE 29: VALIDATION
# ----------------------------------------

cat("\nStage 29: Pipeline Validation\n")
source("scripts/29_validate_pipeline_quality.R")

# ----------------------------------------
# COMPLETE
# ----------------------------------------

pipeline_end <- Sys.time()
runtime <- round(difftime(pipeline_end, pipeline_start, units = "secs"), 1)

cat("\n========================================\n")
cat("KER-HUELLA PIPELINE COMPLETE ✅\n")
cat("========================================\n")
cat("Start time :", as.character(pipeline_start), "\n")
cat("End time   :", as.character(pipeline_end), "\n")
cat("Runtime    :", runtime, "seconds\n\n")
