# ----------------------------------------
# SCRIPT: 25_create_reference_view.R
#
# PURPOSE:
# - Create consolidated plant
#   reference view
#
# INPUT:
# - plant_reference_use_terms
# - plant_reference_safety
# - plant_reference_parts
#
# OUTPUT:
# - plant_reference_view
#
# NOTES:
# - One row per plant
# - Optimized for Power BI
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)

cat("\n========================================\n")
cat("STAGE 25: CREATE REFERENCE VIEW\n")
cat("========================================\n\n")

con <- connect_db()

# ----------------------------------------
# VALIDATE TABLES
# ----------------------------------------

required_tables <- c(
  "plant_reference_use_terms",
  "plant_reference_safety",
  "plant_reference_parts"
)

missing_tables <- setdiff(
  required_tables,
  DBI::dbListTables(con)
)

if (length(missing_tables) > 0) {
  
  disconnect_db(con)
  
  stop(
    paste(
      "❌ Missing tables:",
      paste(missing_tables, collapse = ", ")
    )
  )
  
}

# ----------------------------------------
# LOAD DATA
# ----------------------------------------

use_terms <- DBI::dbReadTable(
  con,
  "plant_reference_use_terms"
)

safety <- DBI::dbReadTable(
  con,
  "plant_reference_safety"
)

parts <- DBI::dbReadTable(
  con,
  "plant_reference_parts"
)

# ----------------------------------------
# EDIBLE PARTS
# ----------------------------------------

edible_parts <- use_terms %>%
  filter(use_type == "edible") %>%
  group_by(latin_name) %>%
  summarise(
    edible_parts = paste(
      sort(unique(use_term)),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# MEDICINAL ACTIONS
# ----------------------------------------

medicinal_actions <- use_terms %>%
  filter(use_type == "medicinal") %>%
  group_by(latin_name) %>%
  summarise(
    medicinal_actions = paste(
      sort(unique(use_term)),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# UTILITY USES
# ----------------------------------------

utility_uses <- use_terms %>%
  filter(use_type == "utility") %>%
  group_by(latin_name) %>%
  summarise(
    utility_uses = paste(
      sort(unique(use_term)),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# SAFETY
# ----------------------------------------

safety_flags <- safety %>%
  group_by(latin_name) %>%
  summarise(
    safety_flags = paste(
      sort(unique(safety_term)),
      collapse = "; "
    ),
    hazard_count = n(),
    .groups = "drop"
  )

# ----------------------------------------
# PARTS
# ----------------------------------------

plant_parts <- parts %>%
  group_by(latin_name) %>%
  summarise(
    plant_parts = paste(
      sort(unique(plant_part)),
      collapse = "; "
    ),
    part_count = n(),
    .groups = "drop"
  )

# ----------------------------------------
# BUILD VIEW
# ----------------------------------------

plant_reference_view <- edible_parts %>%
  full_join(
    medicinal_actions,
    by = "latin_name"
  ) %>%
  full_join(
    utility_uses,
    by = "latin_name"
  ) %>%
  full_join(
    safety_flags,
    by = "latin_name"
  ) %>%
  full_join(
    plant_parts,
    by = "latin_name"
  )

# ----------------------------------------
# SAVE
# ----------------------------------------

DBI::dbWriteTable(
  con,
  "plant_reference_view",
  plant_reference_view,
  overwrite = TRUE
)

log_step(
  paste(
    "Reference rows:",
    nrow(plant_reference_view)
  )
)

disconnect_db(con)

log_step(
  "✅ Stage 25 COMPLETE"
)