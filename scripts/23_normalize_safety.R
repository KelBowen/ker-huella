# ----------------------------------------
# SCRIPT: 23_normalize_safety.R
#
# PURPOSE:
# - Extract structured safety terms
#   from PFAF hazard information
#
# INPUT:
# - plant_reference_uses
#
# OUTPUT:
# - plant_reference_safety
#
# NOTES:
# - One hazard description may produce
#   multiple safety terms
# - Preserves source lineage
# - Deterministic classification only
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(tidyr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 23: NORMALIZE SAFETY\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# VALIDATE INPUT
# ----------------------------------------

if (!"plant_reference_uses" %in% dbListTables(con)) {
  
  disconnect_db(con)
  
  stop(
    "❌ plant_reference_uses not found. Run Stage 21 first."
  )
  
}

df <- dbReadTable(
  con,
  "plant_reference_uses"
)

hazards <- df %>%
  filter(
    use_type == "hazard"
  )

log_step(
  paste(
    "Hazard rows:",
    nrow(hazards)
  )
)

# ----------------------------------------
# SAFETY DICTIONARY
# ----------------------------------------

safety_dictionary <- tribble(
  
  ~match_term,      ~canonical_term,    ~safety_type,
  
  "deadly",         "deadly",           "severity",
  "fatal",          "deadly",           "severity",
  
  "toxic",          "toxic",            "toxicity",
  "poisonous",      "poisonous",        "toxicity",
  
  "allergy",        "allergenic",       "allergy",
  "allergenic",     "allergenic",       "allergy",
  
  "irritant",       "skin irritant",    "irritation",
  "dermatitis",     "skin irritant",    "irritation",
  
  "pregnancy",      "pregnancy risk",   "pregnancy",
  "pregnant",       "pregnancy risk",   "pregnancy",
  "abortifacient",  "pregnancy risk",   "pregnancy",
  
  "child",          "child risk",       "child risk",
  "children",       "child risk",       "child risk",
  
  "photosensitive", "photosensitive",   "photosensitivity",
  
  "narcotic",       "narcotic",         "neurological",
  "hallucinogenic", "hallucinogenic",   "neurological",
  
  "internal use",   "internal use",     "usage restriction",
  "external use",   "external use",     "usage restriction"
  
)

# ----------------------------------------
# EXTRACT TERMS
# ----------------------------------------

results <- list()

row_id <- 1

for (i in seq_len(nrow(hazards))) {
  
  description <- hazards$description[i]
  
  text_lower <- str_to_lower(description)
  
  matches <- safety_dictionary %>%
    filter(
      str_detect(
        text_lower,
        fixed(
          match_term,
          ignore_case = TRUE
        )
      )
    )
  
  if (nrow(matches) > 0) {
    
    for (j in seq_len(nrow(matches))) {
      
      results[[row_id]] <- tibble(
        
        latin_name = hazards$latin_name[i],
        
        safety_type = matches$safety_type[j],
        
        safety_term = matches$canonical_term[j],
        
        source_description = description,
        
        source = "PFAF"
        
      )
      
      row_id <- row_id + 1
      
    }
    
  }
  
}

# ----------------------------------------
# BUILD OUTPUT
# ----------------------------------------

plant_reference_safety <- bind_rows(
  results
) %>%
  distinct()

# ----------------------------------------
# QA
# ----------------------------------------

log_step(
  paste(
    "Safety rows:",
    nrow(plant_reference_safety)
  )
)

print(
  plant_reference_safety %>%
    count(
      safety_type,
      safety_term,
      sort = TRUE
    )
)

# ----------------------------------------
# SAVE
# ----------------------------------------

dbWriteTable(
  con,
  "plant_reference_safety",
  plant_reference_safety,
  overwrite = TRUE
)

log_step(
  "✅ Table saved: plant_reference_safety"
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 23 COMPLETE"
)