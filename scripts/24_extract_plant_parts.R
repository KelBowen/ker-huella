# ----------------------------------------
# SCRIPT: 24_extract_plant_parts.R
#
# PURPOSE:
# - Extract normalized plant parts
#   from PFAF parsed data
#
# INPUT:
# - plant_reference_uses
#
# OUTPUT:
# - plant_reference_parts
#
# NOTES:
# - One row per plant-part combination
# - Supports future harvest planning
# - Supports PlantParts model
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)

cat("\n========================================\n")
cat("STAGE 24: EXTRACT PLANT PARTS\n")
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
# CONTROLLED VOCABULARY
# ----------------------------------------

valid_parts <- c(
  "leaf",
  "flower",
  "seed",
  "fruit",
  "root",
  "rhizome",
  "bark",
  "stem",
  "shoot",
  "young shoot",
  "sap",
  "nut",
  "kernel",
  "bulb",
  "tuber",
  "whole plant"
)


# ----------------------------------------
# EXTRACT PARTS
# ----------------------------------------

plant_reference_parts <- df %>%
  filter(
    !is.na(plant_part),
    plant_part %in% valid_parts
  ) %>%
  select(
    latin_name,
    plant_part,
    use_type
  ) %>%
  group_by(
    latin_name,
    plant_part
  ) %>%
  summarise(
    first_seen_use_type = first(use_type),
    .groups = "drop"
  ) %>%
  mutate(
    source = "PFAF"
  ) %>%
  arrange(
    latin_name,
    plant_part
  )

# ----------------------------------------
# QA
# ----------------------------------------

log_step(
  paste(
    "Plant-part rows:",
    nrow(plant_reference_parts)
  )
)

print(
  
  plant_reference_parts %>%
    count(
      plant_part,
      sort = TRUE
    )
  
)

# ----------------------------------------
# QA
# ----------------------------------------

log_step(
  paste(
    "Plant-part rows:",
    nrow(plant_reference_parts)
  )
)

print(
  plant_reference_parts %>%
    count(
      plant_part,
      sort = TRUE
    )
)

# ----------------------------------------
# SAVE
# ----------------------------------------

dbWriteTable(
  con,
  "plant_reference_parts",
  plant_reference_parts,
  overwrite = TRUE
)

log_step(
  "✅ Table saved: plant_reference_parts"
)

# ----------------------------------------
# SAMPLE OUTPUT
# ----------------------------------------

print(
  head(
    plant_reference_parts,
    20
  )
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 24 COMPLETE"
)