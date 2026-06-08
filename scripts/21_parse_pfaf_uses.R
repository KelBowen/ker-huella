# ----------------------------------------
# SCRIPT: 21_parse_pfaf_uses.R
#
# PURPOSE:
# - Parse PFAF raw text into structured plant uses
#
# INPUT:
# - plant_reference_raw
#
# OUTPUT:
# - plant_reference_uses
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(tidyr)

con <- connect_db()

# ----------------------------
# CHECK INPUT
# ----------------------------

if (!"plant_reference_raw" %in% dbListTables(con)) {
  disconnect_db(con)
  stop("❌ plant_reference_raw not found. Run Stage 23 first.")
}

df <- dbReadTable(con, "plant_reference_raw")

log_step(paste("Raw rows:", nrow(df)))

# ----------------------------
# SAFETY CHECK
# ----------------------------

required_cols <- c("latin_name", "edible_uses", "medicinal_uses", "other_uses")

missing_cols <- setdiff(required_cols, names(df))

if (length(missing_cols) > 0) {
  disconnect_db(con)
  stop("❌ Missing columns: ", paste(missing_cols, collapse = ", "))
}

# ----------------------------
# HELPERS
# ----------------------------

split_sentences <- function(text) {
  if (is.na(text) || text == "") return(character(0))
  
  sentences <- str_split(text, "\\.|;|\\n")[[1]]
  sentences <- str_trim(sentences)
  sentences[sentences != ""]
}

detect_plant_part <- function(text) {
  case_when(
    str_detect(text, regex("leaf|leaves", ignore_case = TRUE)) ~ "leaf",
    str_detect(text, regex("root", ignore_case = TRUE)) ~ "root",
    str_detect(text, regex("flower", ignore_case = TRUE)) ~ "flower",
    str_detect(text, regex("seed", ignore_case = TRUE)) ~ "seed",
    str_detect(text, regex("fruit", ignore_case = TRUE)) ~ "fruit",
    str_detect(text, regex("stem", ignore_case = TRUE)) ~ "stem",
    TRUE ~ NA_character_
  )
}

# ----------------------------
# CORE FUNCTION
# ----------------------------

extract_use_type <- function(df, text_col, type_label) {
  
  tmp <- df %>%
    select(latin_name, all_of(text_col)) %>%
    filter(!is.na(.data[[text_col]]) & .data[[text_col]] != "")
  
  tmp <- tmp %>%
    mutate(sentences = lapply(.data[[text_col]], split_sentences)) %>%
    unnest(sentences)
  
  tmp <- tmp %>%
    mutate(
      use_type = type_label,
      description = str_trim(sentences),
      plant_part = detect_plant_part(description)
    ) %>%
    select(latin_name, use_type, plant_part, description) %>%
    filter(description != "", nchar(description) > 5)
  
  return(tmp)
}

# ----------------------------
# RUN EXTRACTION
# ----------------------------

edible <- extract_use_type(df, "edible_uses", "edible")
medicinal <- extract_use_type(df, "medicinal_uses", "medicinal")
other <- extract_use_type(df, "other_uses", "other")

plant_reference_uses <- bind_rows(edible, medicinal, other)

log_step(paste("Parsed rows:", nrow(plant_reference_uses)))

# ----------------------------
# SAVE
# ----------------------------

dbWriteTable(
  con,
  "plant_reference_uses",
  plant_reference_uses,
  overwrite = TRUE
)

log_step("✅ Table saved: plant_reference_uses")

print(head(plant_reference_uses, 10))

disconnect_db(con)

log_step("✅ Parsing complete")
