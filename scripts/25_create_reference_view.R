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
# - medicinal_action_lookup
# - plant_reference_images_validated
#
# OUTPUT:
# - plant_reference_view
#
# NOTES:
# - One row per plant
# - Optimized for Power BI
# - Includes friendly medicinal labels
# - Includes body systems
# - Includes validated image URLs
# - Includes quality flags
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)

cat("\n========================================\n")
cat("STAGE 25: CREATE REFERENCE VIEW\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# VALIDATE TABLES
# ----------------------------------------

required_tables <- c(
  "plant_reference_use_terms",
  "plant_reference_safety",
  "plant_reference_parts",
  "medicinal_action_lookup",
  "plant_reference_images_validated"
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
      paste(
        missing_tables,
        collapse = ", "
      )
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

medicinal_lookup <- DBI::dbReadTable(
  con,
  "medicinal_action_lookup"
)

images <- DBI::dbReadTable(
  con,
  "plant_reference_images_validated"
) %>%
  select(
    latin_name,
    selected_url,
    selected_source,
    selected_level
  )

# ----------------------------------------
# EDIBLE PARTS
# ----------------------------------------

edible_parts <- use_terms %>%
  filter(
    use_type == "edible"
  ) %>%
  group_by(latin_name) %>%
  summarise(
    edible_parts = paste(
      sort(
        unique(use_term)
      ),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# MEDICINAL ACTIONS
# ----------------------------------------

medicinal_friendly <- use_terms %>%
  filter(
    use_type == "medicinal"
  ) %>%
  left_join(
    medicinal_lookup,
    by = "use_term"
  )

medicinal_actions <- medicinal_friendly %>%
  group_by(latin_name) %>%
  summarise(
    medicinal_actions = paste(
      sort(
        unique(display_label)
      ),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# BODY SYSTEMS
# ----------------------------------------

body_systems <- medicinal_friendly %>%
  group_by(latin_name) %>%
  summarise(
    body_systems = paste(
      sort(
        unique(body_system)
      ),
      collapse = "; "
    ),
    .groups = "drop"
  )

# ----------------------------------------
# UTILITY USES
# ----------------------------------------

utility_uses <- use_terms %>%
  filter(
    use_type == "utility"
  ) %>%
  group_by(latin_name) %>%
  summarise(
    utility_uses = paste(
      sort(
        unique(use_term)
      ),
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
      sort(
        unique(safety_term)
      ),
      collapse = "; "
    ),
    hazard_count = n(),
    .groups = "drop"
  )

# ----------------------------------------
# PLANT PARTS
# ----------------------------------------

plant_parts <- parts %>%
  group_by(latin_name) %>%
  summarise(
    plant_parts = paste(
      sort(
        unique(plant_part)
      ),
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
    body_systems,
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
  ) %>%
  full_join(
    images,
    by = "latin_name"
  )

# ----------------------------------------
# QUALITY FLAGS
# ----------------------------------------

plant_reference_view <- plant_reference_view %>%
  mutate(
    
    has_image =
      !is.na(selected_url),
    
    has_safety =
      !is.na(safety_flags),
    
    has_parts =
      !is.na(plant_parts),
    
    has_medicinal_actions =
      !is.na(medicinal_actions)
    
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

# ----------------------------------------
# QA
# ----------------------------------------

log_step(
  paste(
    "Reference rows:",
    nrow(
      plant_reference_view
    )
  )
)

print(
  plant_reference_view %>%
    summarise(
      has_image = sum(has_image),
      has_safety = sum(has_safety),
      has_parts = sum(has_parts),
      has_medicinal_actions =
        sum(has_medicinal_actions)
    )
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 25 COMPLETE"
)