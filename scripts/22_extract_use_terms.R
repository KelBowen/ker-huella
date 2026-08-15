# ----------------------------------------
# SCRIPT: 22_extract_use_terms.R
#
# PURPOSE:
# - Extract controlled vocabulary terms
#   from parsed PFAF uses
#
# INPUT:
# - plant_reference_uses
#
# OUTPUT:
# - plant_reference_use_terms
#
# NOTES:
# - One source description may produce
#   multiple use terms
# - Preserves source lineage
# - Supports Power BI analytics
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(tidyr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 22: EXTRACT USE TERMS\n")
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

log_step(
  paste(
    "Input rows:",
    nrow(df)
  )
)

# ----------------------------------------
# DICTIONARIES
# ----------------------------------------

medicinal_terms <- c(
  
  "alterative",
  "analgesic",
  "anodyne",
  "anthelmintic",
  "antibacterial",
  "antifungal",
  "anti-inflammatory",
  "antirheumatic",
  "antiseptic",
  "aperient",
  "astringent",
  "carminative",
  "cholagogue",
  "demulcent",
  "depurative",
  "diaphoretic",
  "digestive",
  "diuretic",
  "emetic",
  "emmenagogue",
  "expectorant",
  "febrifuge",
  "haemostatic",
  "laxative",
  "refrigerant",
  "sedative",
  "stimulant",
  "tonic",
  "vulnerary"
  
)

utility_terms <- c(
  
  "tannin",
  "timber",
  "fibre",
  "fiber",
  "dye",
  "fuel",
  "shelterbelt",
  "erosion",
  "green manure",
  "mulch",
  "compost",
  "wildlife",
  "repellent",
  "mosquito",
  "plant feed",
  "hedging",
  "basketry",
  "veneer",
  "carving",
  "adhesive",
  "fungicide"
  
)

edible_terms <- c(
  
  "leaf",
  "flower",
  "fruit",
  "seed",
  "root",
  "rhizome",
  "shoot",
  "young shoot",
  "stem",
  "bark",
  "sap",
  "nut",
  "kernel",
  "bulb",
  "tuber"
  
)

# ----------------------------------------
# EXTRACT TERMS
# ----------------------------------------

extract_terms <- function(
    description,
    dictionary
) {
  
  matches <- dictionary[
    str_detect(
      str_to_lower(description),
      fixed(
        dictionary,
        ignore_case = TRUE
      )
    )
  ]
  
  unique(matches)
  
}

# ----------------------------------------
# PROCESS ROWS
# ----------------------------------------

results <- list()

row_id <- 1

for (i in seq_len(nrow(df))) {
  
  row <- df[i, ]
  
  description <- row$description
  use_type <- row$use_type
  
  terms <- character()
  
  if (use_type == "medicinal") {
    
    terms <- extract_terms(
      description,
      medicinal_terms
    )
    
  } else if (use_type == "utility") {
    
    terms <- extract_terms(
      description,
      utility_terms
    )
    
  } else if (use_type == "edible") {
    
    terms <- extract_terms(
      description,
      edible_terms
    )
    
  }
  
  if (length(terms) > 0) {
    
    for (term in terms) {
      
      results[[row_id]] <- tibble(
        
        latin_name = row$latin_name,
        
        use_type = use_type,
        
        use_term = term,
        
        source_description = description
        
      )
      
      row_id <- row_id + 1
      
    }
    
  }
  
}

# ----------------------------------------
# BUILD OUTPUT
# ----------------------------------------

plant_reference_use_terms <- bind_rows(
  results
) %>%
  distinct()

log_step(
  paste(
    "Extracted terms:",
    nrow(plant_reference_use_terms)
  )
)

# ----------------------------------------
# SAVE
# ----------------------------------------

dbWriteTable(
  con,
  "plant_reference_use_terms",
  plant_reference_use_terms,
  overwrite = TRUE
)

log_step(
  "✅ Table saved: plant_reference_use_terms"
)

# ----------------------------------------
# QA
# ----------------------------------------

print(
  plant_reference_use_terms %>%
    count(
      use_type,
      use_term,
      sort = TRUE
    ) %>%
    head(25)
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 22 COMPLETE"
)