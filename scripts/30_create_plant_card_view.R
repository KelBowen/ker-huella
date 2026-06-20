# ----------------------------------------
# STAGE: OUTPUT
#
# PURPOSE:
# - Create unified plant view for Power BI and downstream queries
# - Combine operational data + PFAF enrichment + parsed uses
# - Expose aggregated parsing outputs for BI consumption
#
# SCOPE:
# - Input:
#     seed_plants
#     plant_locations
#     locations
#     plant_reference_raw
#     plant_reference_uses
#
# - Output:
#     plant_card_view (view)
#
# USAGE:
# source("scripts/30_create_plant_card_view.R")
#
# NOTES:
# - Replaces legacy Phase 1 plant_card_view
# - Safely handles the case where plant_card_view already exists
#   as either a TABLE or a VIEW
# - This is the main consumption layer for Power BI
# ----------------------------------------

source("scripts/00_setup.R")

cat("\n========================================\n")
cat("STAGE 30: CREATE PLANT CARD VIEW (PHASE 2)\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# CHECK REQUIRED TABLES
# ----------------------------------------

required_tables <- c(
  "seed_plants",
  "plant_locations",
  "locations",
  "plant_reference_raw",
  "plant_reference_uses"
)

missing <- setdiff(required_tables, dbListTables(con))

if (length(missing) > 0) {
  disconnect_db(con)
  stop("❌ Missing tables: ", paste(missing, collapse = ", "))
}

# ----------------------------------------
# RESET EXISTING OBJECT SAFELY
# ----------------------------------------

object_info <- dbGetQuery(con, "
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'main'
  AND table_name = 'plant_card_view'
")

if (nrow(object_info) > 0) {
  object_type <- object_info$table_type[1]
  
  if (object_type == 'BASE TABLE') {
    dbExecute(con, 'DROP TABLE plant_card_view')
    cat('✅ Dropped existing TABLE: plant_card_view\n')
  } else if (object_type == 'VIEW') {
    dbExecute(con, 'DROP VIEW plant_card_view')
    cat('✅ Dropped existing VIEW: plant_card_view\n')
  }
} else {
  cat("ℹ No existing plant_card_view found\n")
}

# ----------------------------------------
# CREATE VIEW
# ----------------------------------------

dbExecute(con, "
CREATE VIEW plant_card_view AS

WITH location_agg AS (
    SELECT 
        pl.latin_name,
        string_agg(DISTINCT l.location_name, ', ' ORDER BY l.location_name) AS locations
    FROM plant_locations pl
    LEFT JOIN locations l 
        ON pl.location_id = l.location_id
    GROUP BY pl.latin_name
),

use_flags AS (
    SELECT 
        latin_name,
        MAX(CASE WHEN use_type = 'edible' THEN 1 ELSE 0 END) AS edible_flag,
        MAX(CASE WHEN use_type = 'medicinal' THEN 1 ELSE 0 END) AS medicinal_flag
    FROM plant_reference_uses
    GROUP BY latin_name
),

use_summary AS (
    SELECT
        latin_name,
        string_agg(DISTINCT use_subtype, ', ' ORDER BY use_subtype) AS use_subtypes,
        string_agg(DISTINCT plant_part, ', ' ORDER BY plant_part) AS plant_parts_detected,
        SUM(CASE WHEN use_type = 'edible' THEN 1 ELSE 0 END) AS edible_use_count,
        SUM(CASE WHEN use_type = 'medicinal' THEN 1 ELSE 0 END) AS medicinal_use_count,
        COUNT(*) AS total_use_count
    FROM plant_reference_uses
    GROUP BY latin_name
)

SELECT 
    sp.latin_name,
    sp.common_name,
    sp.status_name,
    sp.plant_type_name,

    COALESCE(la.locations, '') AS locations,

    COALESCE(pr.edible_uses, '') AS edible_uses,
    COALESCE(pr.medicinal_uses, '') AS medicinal_uses,
    COALESCE(pr.hazards, '') AS hazards,

    COALESCE(us.use_subtypes, '') AS use_subtypes,
    COALESCE(us.plant_parts_detected, '') AS plant_parts_detected,
    COALESCE(us.edible_use_count, 0) AS edible_use_count,
    COALESCE(us.medicinal_use_count, 0) AS medicinal_use_count,
    COALESCE(us.total_use_count, 0) AS total_use_count,

    COALESCE(uf.edible_flag, 0) AS edible_flag,
    COALESCE(uf.medicinal_flag, 0) AS medicinal_flag

FROM seed_plants sp

LEFT JOIN location_agg la 
    ON sp.latin_name = la.latin_name

LEFT JOIN plant_reference_raw pr 
    ON sp.latin_name = pr.latin_name

LEFT JOIN use_flags uf 
    ON sp.latin_name = uf.latin_name

LEFT JOIN use_summary us
    ON sp.latin_name = us.latin_name
")

cat("✅ plant_card_view created\n\n")

# ----------------------------------------
# VERIFY
# ----------------------------------------

cat("Schema:\n")
print(dbGetQuery(con, "PRAGMA table_info('plant_card_view')"))

cat("\nRow count:\n")
print(dbGetQuery(con, "SELECT COUNT(*) AS n FROM plant_card_view"))

cat("\nPreview:\n")
print(dbGetQuery(con, "
SELECT 
    latin_name,
    common_name,
    locations,
    use_subtypes,
    plant_parts_detected,
    edible_flag,
    medicinal_flag
FROM plant_card_view
LIMIT 10
"))

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

cat("\n========================================\n")
cat("STAGE 30 COMPLETE ✅\n")
cat("========================================\n")

