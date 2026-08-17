# ----------------------------------------
# SCRIPT: 27_enrich_images.R
#
# PURPOSE:
# - Generate Wikimedia Commons image
#   references for all plants
#
# INPUT:
# - seed_plants
#
# OUTPUT:
# - plant_reference_images
#
# NOTES:
# - Wikimedia Commons primary source
# - Generates fallback URLs
# - No web validation performed
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(DBI)
library(stringr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 27: IMAGE ENRICHMENT\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# VALIDATE INPUT
# ----------------------------------------

if (!"seed_plants" %in% dbListTables(con)) {
  
  disconnect_db(con)
  
  stop(
    "❌ seed_plants not found."
  )
  
}

# ----------------------------------------
# LOAD PLANTS
# ----------------------------------------

plants <- dbReadTable(
  con,
  "seed_plants"
) %>%
  select(latin_name) %>%
  distinct() %>%
  filter(
    !is.na(latin_name),
    latin_name != ""
  )

log_step(
  paste(
    "Plants loaded:",
    nrow(plants)
  )
)

# ----------------------------------------
# BUILD COMMONS URL
# ----------------------------------------

build_commons_url <- function(name) {
  
  page_name <- name %>%
    str_squish() %>%
    str_replace_all(" ", "_")
  
  page_name <- paste0(
    toupper(substr(page_name, 1, 1)),
    substr(
      page_name,
      2,
      nchar(page_name)
    )
  )
  
  paste0(
    "https://commons.wikimedia.org/wiki/",
    page_name
  )
  
}

# ----------------------------------------
# BUILD IMAGE CANDIDATES
# ----------------------------------------

build_image_candidates <- function(
    latin_name
) {
  
  latin_name <- str_squish(
    latin_name
  )
  
  # --------------------------------------
  # PRIMARY NAME
  # --------------------------------------
  
  primary_name <- latin_name
  
  # --------------------------------------
  # SPECIES FALLBACK
  # --------------------------------------
  
  species_name <- latin_name
  
  if (
    str_detect(
      latin_name,
      regex("\\bvar\\.", TRUE)
    )
  ) {
    
    species_name <- str_trim(
      str_split(
        latin_name,
        regex("\\bvar\\.", TRUE)
      )[[1]][1]
    )
    
  }
  
  # --------------------------------------
  # GENUS FALLBACK
  # --------------------------------------
  
  genus_name <- word(
    latin_name,
    1
  )
  
  primary_url <- build_commons_url(
    primary_name
  )
  
  species_url <- build_commons_url(
    species_name
  )
  
  genus_url <- build_commons_url(
    genus_name
  )
  
  tibble(
    
    latin_name = latin_name,
    
    image_source =
      "Wikimedia Commons",
    
    primary_url =
      primary_url,
    
    species_url =
      species_url,
    
    genus_url =
      genus_url,
    
    selected_level =
      "primary",
    
    selected_source =
      "Wikimedia Commons",
    
    selected_url =
      primary_url,
    
    reviewed =
      FALSE,
    
    notes =
      NA_character_
    
  )
  
}

# ----------------------------------------
# BUILD IMAGE TABLE
# ----------------------------------------

plant_reference_images <- bind_rows(
  
  lapply(
    plants$latin_name,
    build_image_candidates
  )
  
)

# ----------------------------------------
# QA
# ----------------------------------------

image_summary <- plant_reference_images %>%
  summarise(
    
    total_plants = n(),
    
    image_candidates = sum(
      !is.na(selected_url)
    )
    
  )

print(
  image_summary
)

# ----------------------------------------
# SAVE
# ----------------------------------------

dbWriteTable(
  
  con,
  
  "plant_reference_images",
  
  plant_reference_images,
  
  overwrite = TRUE
  
)

# ----------------------------------------
# SAMPLE
# ----------------------------------------

print(
  head(
    plant_reference_images,
    20
  )
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 27 COMPLETE"
)