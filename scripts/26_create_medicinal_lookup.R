# ----------------------------------------
# SCRIPT: 26_create_medicinal_lookup.R
#
# PURPOSE:
# - Create medicinal action lookup
#
# OUTPUT:
# - medicinal_action_lookup
#
# NOTES:
# - Provides user-friendly labels
# - Supports Power BI
# - Supports plant cards
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 26: MEDICINAL LOOKUP\n")
cat("========================================\n\n")

con <- connect_db()

medicinal_action_lookup <- tribble(
  
  ~use_term,          ~display_label,               ~body_system,
  
  "alterative",       "Detoxifying",               "General",
  
  "analgesic",        "Pain Relief",               "Pain Management",
  
  "anodyne",          "Pain Relief",               "Pain Management",
  
  "anthelmintic",     "Parasite Management",       "Digestive",
  
  "antibacterial",    "Antibacterial",             "Infection Control",
  
  "antifungal",       "Antifungal",                "Infection Control",
  
  "anti-inflammatory","Anti-inflammatory",         "Inflammation",
  
  "antirheumatic",    "Joint Support",             "Musculoskeletal",
  
  "antiseptic",       "Antiseptic",                "Infection Control",
  
  "aperient",         "Mild Laxative",             "Digestive",
  
  "astringent",       "Astringent",                "Digestive",
  
  "carminative",      "Reduces Digestive Gas",     "Digestive",
  
  "cholagogue",       "Supports Bile Flow",        "Digestive",
  
  "demulcent",        "Soothes Irritated Tissues", "Digestive",
  
  "depurative",       "Detoxifying",               "General",
  
  "diaphoretic",      "Promotes Sweating",         "Temperature Regulation",
  
  "digestive",        "Digestive Aid",             "Digestive",
  
  "diuretic",         "Diuretic",                  "Urinary",
  
  "emetic",           "Induces Vomiting",          "Digestive",
  
  "emmenagogue",      "Menstrual Support",         "Reproductive",
  
  "expectorant",      "Expectorant",               "Respiratory",
  
  "febrifuge",        "Reduces Fever",             "Temperature Regulation",
  
  "haemostatic",      "Stops Bleeding",            "Circulatory",
  
  "laxative",         "Laxative",                  "Digestive",
  
  "refrigerant",      "Cooling",                   "Temperature Regulation",
  
  "sedative",         "Sedative",                  "Nervous System",
  
  "stimulant",        "Stimulant",                 "Nervous System",
  
  "tonic",            "General Tonic",             "General",
  
  "vulnerary",        "Wound Healing",             "Skin & Healing"
  
)

dbWriteTable(
  con,
  "medicinal_action_lookup",
  medicinal_action_lookup,
  overwrite = TRUE
)

log_step(
  paste(
    "Lookup rows:",
    nrow(medicinal_action_lookup)
  )
)

disconnect_db(con)

log_step(
  "✅ Stage 26 COMPLETE"
)
