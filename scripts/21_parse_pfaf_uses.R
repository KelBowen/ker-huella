# ----------------------------------------
# SCRIPT: 21_parse_pfaf_uses.R
#
# PURPOSE:

# - Extract plant part + use subtype
#
# INPUT:
# - plant_reference_raw
#
# OUTPUT:
# - plant_reference_uses
#
# NOTES:
# - Produces structured knowledge for BI
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(tidyr)

cat("\n========================================\n")
cat("STAGE 21: PARSE PFAF USES\n")
cat("========================================\n\n")

con <- connect_db()

# ----------------------------------------
# CHECK INPUT
# ----------------------------------------

if (!"plant_reference_raw" %in% dbListTables(con)) {
  disconnect_db(con)
  stop("❌ plant_reference_raw not found. Run Stage 20 first.")
}

df <- dbReadTable(con, "plant_reference_raw")

log_step(paste("Raw rows:", nrow(df)))

# ----------------------------------------
# SAFETY CHECK
# ----------------------------------------

required_cols <- c("latin_name", "edible_uses", "medicinal_uses", "other_uses")

missing_cols <- setdiff(required_cols, names(df))

if (length(missing_cols) > 0) {
  disconnect_db(con)
  stop("❌ Missing columns: ", paste(missing_cols, collapse = ", "))
}

# ----------------------------------------
# HELPER: split sentences (IMPROVED)
# ----------------------------------------

split_sentences <- function(text) {
  if (is.na(text) || text == "") return(character(0))
  
  sentences <- str_split(text, "\\.|;|\\n|•|-")[[1]]
  sentences <- str_trim(sentences)
  
  sentences[
    sentences != "" &
      nchar(sentences) > 10 &
      !str_detect(sentences, regex("^edible uses$", TRUE)) &
      !str_detect(sentences, regex("^medicinal uses$", TRUE))
  ]
}

# ----------------------------------------
# HELPER: detect plant part (EXPANDED)
# ----------------------------------------

detect_plant_part <- function(text) {
  case_when(
    str_detect(text, regex("leaf|leaves", TRUE)) ~ "leaf",
    str_detect(text, regex("root", TRUE)) ~ "root",
    str_detect(text, regex("rhizome", TRUE)) ~ "rhizome",
    str_detect(text, regex("tuber", TRUE)) ~ "tuber",
    str_detect(text, regex("flower|blossom", TRUE)) ~ "flower",
    str_detect(text, regex("seed", TRUE)) ~ "seed",
    str_detect(text, regex("fruit|berry", TRUE)) ~ "fruit",
    str_detect(text, regex("bark", TRUE)) ~ "bark",
    str_detect(text, regex("sap", TRUE)) ~ "sap",
    str_detect(text, regex("shoot", TRUE)) ~ "shoot",
    str_detect(text, regex("whole plant", TRUE)) ~ "whole plant",
    TRUE ~ NA_character_
  )
}

# ----------------------------------------
# HELPER: detect use subtype (NEW ✅)
# ----------------------------------------

detect_use_subtype <- function(text, use_type) {
  
  if (use_type == "edible") {
    case_when(
      str_detect(text, regex("tea|infusion", TRUE)) ~ "tea",
      str_detect(text, regex("vegetable|cooked", TRUE)) ~ "vegetable",
      str_detect(text, regex("salad|raw", TRUE)) ~ "salad",
      str_detect(text, regex("fruit|sweet", TRUE)) ~ "fruit",
      str_detect(text, regex("spice|flavour", TRUE)) ~ "spice",
      TRUE ~ "other edible"
    )
    
  } else if (use_type == "medicinal") {
    case_when(
      str_detect(text, regex("infusion|tea", TRUE)) ~ "infusion",
      str_detect(text, regex("decoction", TRUE)) ~ "decoction",
      str_detect(text, regex("poultice|topical", TRUE)) ~ "topical",
      str_detect(text, regex("tincture", TRUE)) ~ "tincture",
      TRUE ~ "general medicinal"
    )
    
  } else {
    "other"
  }
}

# ----------------------------------------
# CORE FUNCTION
# ----------------------------------------

extract_use_type <- function(df, text_col, type_label) {
  
  tmp <- df %>%
    select(latin_name, all_of(text_col)) %>%
    filter(!is.na(.data[[text_col]]) & .data[[text_col]] != "")
  
  tmp <- tmp %>%
    mutate(sentences = lapply(.data[[text_col]], split_sentences)) %>%
    unnest(sentences)
  
  tmp <- tmp %>%
    mutate(
      description = str_trim(sentences),
      use_type = type_label,
      plant_part = detect_plant_part(description),
      use_subtype = detect_use_subtype(description, type_label)
    ) %>%
    select(latin_name, use_type, use_subtype, plant_part, description) %>%
    filter(description != "", nchar(description) > 10)
  
  return(tmp)
}

# ----------------------------------------
# RUN EXTRACTION
# ----------------------------------------

edible <- extract_use_type(df, "edible_uses", "edible")
medicinal <- extract_use_type(df, "medicinal_uses", "medicinal")
other <- extract_use_type(df, "other_uses", "other")

plant_reference_uses <- bind_rows(edible, medicinal, other)

log_step(paste("Parsed rows:", nrow(plant_reference_uses)))

# ----------------------------------------
# CLEANUP
# ----------------------------------------

plant_reference_uses <- plant_reference_uses %>%
  mutate(
    description = str_replace_all(description, "\\s+", " ")
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

log_step("✅ Table saved: plant_reference_uses")

print(head(plant_reference_uses, 10))

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step("✅ Parsing COMPLETE")
