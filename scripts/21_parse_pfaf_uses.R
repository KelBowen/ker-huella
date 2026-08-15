# ----------------------------------------
# SCRIPT: 21_parse_pfaf_uses.R
#
# PURPOSE:
# - Parse structured use information from PFAF
# - Extract use type, subtype, use term,
#   plant part, and source description
#
# INPUT:
# - plant_reference_raw
#
# OUTPUT:
# - plant_reference_uses
#
# NOTES:
# - Consumes clean Stage 20 output
# - Preserves source text lineage
# - Produces Power BI friendly records
# - Deterministic classification only
#
# USE TYPES:
# - edible
# - medicinal
# - utility
# - hazard
#
# STAGE:
# - Phase 2b (Structured Parsing)
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(tidyr)

cat("\n========================================\n")
cat("STAGE 21: PARSE PFAF USES\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# CHECK INPUT
# ----------------------------------------

if (!"plant_reference_raw" %in% dbListTables(con)) {
  
  disconnect_db(con)
  
  stop(
    "❌ plant_reference_raw not found. Run Stage 20 first."
  )
  
}

df <- dbReadTable(
  con,
  "plant_reference_raw"
)

log_step(
  paste(
    "Raw rows:",
    nrow(df)
  )
)

# ----------------------------------------
# VALIDATE INPUT
# ----------------------------------------

required_cols <- c(
  "latin_name",
  "edible_uses",
  "medicinal_uses",
  "other_uses",
  "hazards"
)

missing_cols <- setdiff(
  required_cols,
  names(df)
)

if (length(missing_cols) > 0) {
  
  disconnect_db(con)
  
  stop(
    paste(
      "❌ Missing columns:",
      paste(missing_cols, collapse = ", ")
    )
  )
  
}

# ----------------------------------------
# SPLIT SENTENCES
# ----------------------------------------

split_sentences <- function(text) {
  
  if (
    is.na(text) ||
    text == ""
  ) {
    return(character(0))
  }
  
  sentences <- str_split(
    text,
    "\\.|;|\\n|•"
  )[[1]]
  
  sentences <- str_trim(sentences)
  
  sentences <- sentences[
    sentences != "" &
      nchar(sentences) > 10
  ]
  
  sentences
  
}

# ----------------------------------------
# DETECT PLANT PART
# ----------------------------------------

detect_plant_part <- function(text) {
  
  case_when(
    
    str_detect(text, regex("young shoot", TRUE))
    ~ "young shoot",
    
    str_detect(text, regex("leaf|leaves", TRUE))
    ~ "leaf",
    
    str_detect(text, regex("root", TRUE))
    ~ "root",
    
    str_detect(text, regex("rhizome", TRUE))
    ~ "rhizome",
    
    str_detect(text, regex("tuber", TRUE))
    ~ "tuber",
    
    str_detect(text, regex("bulb", TRUE))
    ~ "bulb",
    
    str_detect(text, regex("flower|flowers|blossom", TRUE))
    ~ "flower",
    
    str_detect(text, regex("seed|seeds", TRUE))
    ~ "seed",
    
    str_detect(text, regex("fruit|fruits|berry|berries", TRUE))
    ~ "fruit",
    
    str_detect(text, regex("nut|nuts", TRUE))
    ~ "nut",
    
    str_detect(text, regex("kernel", TRUE))
    ~ "kernel",
    
    str_detect(text, regex("bark", TRUE))
    ~ "bark",
    
    str_detect(text, regex("sap", TRUE))
    ~ "sap",
    
    str_detect(text, regex("shoot", TRUE))
    ~ "shoot",
    
    str_detect(text, regex("stem", TRUE))
    ~ "stem",
    
    str_detect(text, regex("whole plant", TRUE))
    ~ "whole plant",
    
    TRUE
    ~ NA_character_
    
  )
  
}

# ----------------------------------------
# MEDICINAL ACTIONS
# ----------------------------------------

detect_medicinal_action <- function(text) {
  
  case_when(
    
    str_detect(text, regex("antiseptic", TRUE))
    ~ "antiseptic",
    
    str_detect(text, regex("antibacterial", TRUE))
    ~ "antibacterial",
    
    str_detect(text, regex("antifungal", TRUE))
    ~ "antifungal",
    
    str_detect(text, regex("anti-inflammatory", TRUE))
    ~ "anti-inflammatory",
    
    str_detect(text, regex("astringent", TRUE))
    ~ "astringent",
    
    str_detect(text, regex("anthelmintic", TRUE))
    ~ "anthelmintic",
    
    str_detect(text, regex("diuretic", TRUE))
    ~ "diuretic",
    
    str_detect(text, regex("expectorant", TRUE))
    ~ "expectorant",
    
    str_detect(text, regex("digestive", TRUE))
    ~ "digestive",
    
    str_detect(text, regex("laxative", TRUE))
    ~ "laxative",
    
    str_detect(text, regex("sedative|calming", TRUE))
    ~ "sedative",
    
    str_detect(text, regex("tonic", TRUE))
    ~ "tonic",
    
    TRUE
    ~ NA_character_
    
  )
  
}

# ----------------------------------------
# UTILITY ACTIONS
# ----------------------------------------

detect_utility_action <- function(text) {
  
  case_when(
    
    str_detect(text, regex("fungicide", TRUE))
    ~ "fungicide",
    
    str_detect(text, regex("repellent", TRUE))
    ~ "repellent",
    
    str_detect(text, regex("adhesive", TRUE))
    ~ "adhesive",
    
    str_detect(text, regex("dye", TRUE))
    ~ "dye",
    
    str_detect(text, regex("timber|wood", TRUE))
    ~ "timber",
    
    str_detect(text, regex("fibre|fiber", TRUE))
    ~ "fibre",
    
    str_detect(text, regex("nitrogen fixer", TRUE))
    ~ "nitrogen fixer",
    
    str_detect(text, regex("hedge|hedging", TRUE))
    ~ "hedging",
    
    str_detect(text, regex("fuel|firewood", TRUE))
    ~ "fuel",
    
    str_detect(text, regex("wildlife", TRUE))
    ~ "wildlife support",
    
    str_detect(text, regex("mulch|compost", TRUE))
    ~ "soil improvement",
    
    TRUE
    ~ NA_character_
    
  )
  
}

# ----------------------------------------
# EDIBLE TERM
# ----------------------------------------

detect_edible_term <- function(text) {
  
  detect_plant_part(text)
  
}

# ----------------------------------------
# HAZARD SUBTYPE
# ----------------------------------------

detect_hazard_subtype <- function(text) {
  
  case_when(
    
    str_detect(text, regex("poison|toxic", TRUE))
    ~ "toxic",
    
    str_detect(text, regex("allerg", TRUE))
    ~ "allergenic",
    
    str_detect(text, regex("dermatitis|skin|irritant", TRUE))
    ~ "skin irritant",
    
    str_detect(text, regex("pregnan", TRUE))
    ~ "pregnancy risk",
    
    str_detect(text, regex("children", TRUE))
    ~ "child risk",
    
    TRUE
    ~ "general hazard"
    
  )
  
}

# ----------------------------------------
# USE TERM
# ----------------------------------------

detect_use_term <- function(text, use_type) {
  
  case_when(
    
    use_type == "edible"
    ~ detect_edible_term(text),
    
    use_type == "medicinal"
    ~ detect_medicinal_action(text),
    
    use_type == "utility"
    ~ detect_utility_action(text),
    
    TRUE
    ~ NA_character_
    
  )
  
}

# ----------------------------------------
# USE SUBTYPE
# ----------------------------------------

detect_use_subtype <- function(text, use_type) {
  
  if (use_type == "edible") {
    
    case_when(
      
      str_detect(text, regex("tea|infusion", TRUE))
      ~ "tea",
      
      str_detect(text, regex("vegetable|cooked", TRUE))
      ~ "vegetable",
      
      str_detect(text, regex("salad|raw", TRUE))
      ~ "salad",
      
      str_detect(text, regex("fruit|sweet", TRUE))
      ~ "fruit",
      
      str_detect(text, regex("spice|seasoning|flavour", TRUE))
      ~ "spice",
      
      str_detect(text, regex("oil", TRUE))
      ~ "oil",
      
      str_detect(text, regex("drink|beverage", TRUE))
      ~ "beverage",
      
      TRUE
      ~ "other edible"
      
    )
    
  } else if (use_type == "medicinal") {
    
    case_when(
      
      str_detect(text, regex("infusion|tea", TRUE))
      ~ "infusion",
      
      str_detect(text, regex("decoction", TRUE))
      ~ "decoction",
      
      str_detect(text, regex("poultice|topical|external", TRUE))
      ~ "topical",
      
      str_detect(text, regex("tincture", TRUE))
      ~ "tincture",
      
      TRUE
      ~ "general medicinal"
      
    )
    
  } else if (use_type == "hazard") {
    
    detect_hazard_subtype(text)
    
  } else if (use_type == "utility") {
    
    case_when(
      
      str_detect(text, regex("fuel|firewood", TRUE))
      ~ "fuel",
      
      str_detect(text, regex("fibre|fiber", TRUE))
      ~ "fibre",
      
      str_detect(text, regex("dye", TRUE))
      ~ "dye",
      
      str_detect(text, regex("wood|timber", TRUE))
      ~ "timber",
      
      TRUE
      ~ "general utility"
      
    )
    
  } else {
    
    "other"
    
  }
  
}

# ----------------------------------------
# CORE EXTRACTION
# ----------------------------------------

extract_use_type <- function(
    df,
    text_col,
    type_label
) {
  
  tmp <- df %>%
    select(
      latin_name,
      all_of(text_col)
    ) %>%
    filter(
      !is.na(.data[[text_col]]) &
        .data[[text_col]] != ""
    )
  
  tmp <- tmp %>%
    mutate(
      sentences = lapply(
        .data[[text_col]],
        split_sentences
      )
    ) %>%
    unnest(sentences)
  
  tmp %>%
    mutate(
      
      description = str_trim(sentences),
      
      source_section = text_col,
      
      use_type = type_label,
      
      plant_part = detect_plant_part(
        description
      ),
      
      use_subtype = detect_use_subtype(
        description,
        type_label
      ),
      
      use_term = detect_use_term(
        description,
        type_label
      )
      
    ) %>%
    select(
      latin_name,
      source_section,
      use_type,
      use_subtype,
      use_term,
      plant_part,
      description
    ) %>%
    filter(
      description != "",
      nchar(description) > 10
    )
  
}

# ----------------------------------------
# RUN EXTRACTION
# ----------------------------------------

edible <- extract_use_type(
  df,
  "edible_uses",
  "edible"
)

medicinal <- extract_use_type(
  df,
  "medicinal_uses",
  "medicinal"
)

hazards <- extract_use_type(
  df,
  "hazards",
  "hazard"
)

utility <- extract_use_type(
  df,
  "other_uses",
  "utility"
)

plant_reference_uses <- bind_rows(
  edible,
  medicinal,
  hazards,
  utility
)

log_step(
  paste(
    "Parsed rows:",
    nrow(plant_reference_uses)
  )
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

plant_reference_uses <- plant_reference_uses %>%
  mutate(
    description = str_replace_all(
      description,
      "\\s+",
      " "
    )
  ) %>%
  distinct()

# ----------------------------------------
# SAVE
# ----------------------------------------

dbWriteTable(
  con,
  "plant_reference_uses",
  plant_reference_uses,
  overwrite = TRUE
)

log_step(
  "✅ Table saved: plant_reference_uses"
)

print(
  head(
    plant_reference_uses,
    10
  )
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Parsing COMPLETE"
)