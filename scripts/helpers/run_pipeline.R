# ----------------------------------------
# KER HUELLA PIPELINE RUNNER
#
# PURPOSE:
# - Execute complete Phase 2 pipeline
# - Build operational inventory
# - Enrich from PFAF
# - Parse structured uses
# - Validate pipeline quality
# - Build BI consumption layer
# - Create BI datamart copy
#
# USAGE:
# source("scripts/helpers/run_pipeline.R")
# ----------------------------------------

cat("\n========================================\n")
cat("KER HUELLA PIPELINE\n")
cat("========================================\n\n")

pipeline_start <- Sys.time()

run_stage <- function(script_path) {
  
  cat("\n----------------------------------------\n")
  cat("Running:", script_path, "\n")
  cat("----------------------------------------\n\n")
  
  start_time <- Sys.time()
  
  tryCatch(
    
    {
      source(script_path)
      
      duration <- round(
        as.numeric(
          difftime(
            Sys.time(),
            start_time,
            units = "secs"
          )
        ),
        1
      )
      
      cat(
        "\n✅ Completed:",
        script_path,
        "(",
        duration,
        "seconds )\n"
      )
    },
    
    error = function(e) {
      
      cat(
        "\n❌ Pipeline failed in:",
        script_path,
        "\n"
      )
      
      stop(e)
    }
    
  )
  
}

# ----------------------------------------
# PHASE 2 PIPELINE
# ----------------------------------------

run_stage("scripts/03_ingest_operational_data.R")

run_stage("scripts/20_enrich_pfaf.R")

run_stage("scripts/21_parse_pfaf_uses.R")

run_stage("scripts/22_extract_use_terms.R")

run_stage("scripts/23_normalize_safety.R")

run_stage("scripts/24_extract_plant_parts.R")

run_stage("scripts/25_create_reference_view.R")

run_stage("scripts/26_create_medicinal_lookup.R")

run_stage("scripts/27_enrich_images.R")

run_stage("scripts/28_validate_images.R")

run_stage("scripts/29_create_plant_card_view.R")

run_stage("scripts/30_validate_pipeline_quality.R")

run_stage("scripts/99_create_bi_datamart.R")

# ----------------------------------------
# COMPLETE
# ----------------------------------------

pipeline_duration <- round(
  as.numeric(
    difftime(
      Sys.time(),
      pipeline_start,
      units = "secs"
    )
  ),
  1
)

cat("\n========================================\n")
cat("PIPELINE COMPLETE ✅\n")
cat("========================================\n\n")

cat(
  "Total runtime:",
  pipeline_duration,
  "seconds\n"
)