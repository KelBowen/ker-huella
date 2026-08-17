# ----------------------------------------
# SCRIPT: 28_validate_images.R
#
# PURPOSE:
# - Validate Wikimedia Commons URLs
# - Test fallback hierarchy
# - Generate image coverage metrics
#
# INPUT:
# - plant_reference_images
#
# OUTPUT:
# - plant_reference_images_validated
# - qa_missing_images
#
# NOTES:
# - TEST VERSION
# - Limited to first 10 plants
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(DBI)
library(httr)
library(tibble)

cat("\n========================================\n")
cat("STAGE 28: VALIDATE IMAGES\n")
cat("========================================\n\n")

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# VALIDATE INPUT
# ----------------------------------------

if (!"plant_reference_images" %in%
    dbListTables(con)) {
  
  disconnect_db(con)
  
  stop(
    "❌ plant_reference_images not found."
  )
  
}
# ----------------------------------------
# LOAD DATA
# ----------------------------------------

images <- dbReadTable(
  con,
  "plant_reference_images"
)

log_step(
  paste(
    "Image candidates:",
    nrow(images)
  )
)

# ----------------------------------------
# OPTIONAL TEST MODE
# ----------------------------------------

# Uncomment for testing
#
# images <- images %>%
#   slice(1:10)
#
# log_step(
#   paste(
#     "Test plants:",
#     nrow(images)
#   )
# )


# ----------------------------------------
# CHECK PAGE EXISTS
# ----------------------------------------

check_page_exists <- function(url) {
  
  if (
    is.na(url) ||
    url == ""
  ) {
    return(FALSE)
  }
  
  Sys.sleep(0.25)
  
  result <- tryCatch({
    
    response <- httr::GET(
      
      url,
      
      httr::user_agent(
        "Ker-Huella/1.0"
      ),
      
      httr::timeout(10)
      
    )
    
    httr::status_code(
      response
    ) == 200
    
  },
  
  error = function(e) {
    
    FALSE
    
  })
  
  result
  
}

# ----------------------------------------
# VALIDATE ROW
# ----------------------------------------

validate_row <- function(df_row) {
  
  primary_exists <- check_page_exists(
    df_row$primary_url
  )
  
  species_exists <- check_page_exists(
    df_row$species_url
  )
  
  genus_exists <- check_page_exists(
    df_row$genus_url
  )
  
  selected_level <- case_when(
    
    primary_exists ~ "primary",
    
    species_exists ~ "species",
    
    genus_exists ~ "genus",
    
    TRUE ~ NA_character_
    
  )
  
  selected_url <- case_when(
    
    primary_exists ~ df_row$primary_url,
    
    species_exists ~ df_row$species_url,
    
    genus_exists ~ df_row$genus_url,
    
    TRUE ~ NA_character_
    
  )
  
  tibble(
    
    latin_name = df_row$latin_name,
    
    image_source =
      "Wikimedia Commons",
    
    primary_url =
      df_row$primary_url,
    
    species_url =
      df_row$species_url,
    
    genus_url =
      df_row$genus_url,
    
    primary_found =
      primary_exists,
    
    species_found =
      species_exists,
    
    genus_found =
      genus_exists,
    
    selected_level =
      selected_level,
    
    selected_source =
      ifelse(
        is.na(selected_url),
        NA,
        "Wikimedia Commons"
      ),
    
    selected_url =
      selected_url,
    
    reviewed = TRUE,
    
    notes = NA_character_
    
  )
  
}

# ----------------------------------------
# VALIDATE ALL
# ----------------------------------------

validated_images <- bind_rows(
  
  lapply(
    seq_len(nrow(images)),
    function(i) {
      
      if (i %% 25 == 0) {
        
        cat(
          sprintf(
            "\nProcessing %s of %s",
            i,
            nrow(images)
          )
        )
        
      }
      
      validate_row(
        images[i, ]
      )
      
    }
    
  )
  
)

cat("\n\n")

# ----------------------------------------
# QA SUMMARY
# ----------------------------------------

coverage <- validated_images %>%
  summarise(
    
    total_plants = n(),
    
    images_found = sum(
      !is.na(selected_url)
    ),
    
    missing_images = sum(
      is.na(selected_url)
    )
    
  ) %>%
  
  mutate(
    
    coverage_pct = round(
      images_found /
        total_plants * 100,
      1
    )
    
  )

print(coverage)

# ----------------------------------------
# FALLBACK ANALYSIS
# ----------------------------------------

fallback_summary <- validated_images %>%
  count(
    selected_level,
    sort = TRUE
  )

cat("\nSelection Levels\n")
print(fallback_summary)

# ----------------------------------------
# QA MISSING IMAGES
# ----------------------------------------

qa_missing_images <- validated_images %>%
  filter(
    is.na(selected_url)
  )

# ----------------------------------------
# SAVE OUTPUTS
# ----------------------------------------

dbWriteTable(
  con,
  "plant_reference_images_validated",
  validated_images,
  overwrite = TRUE
)

dbWriteTable(
  con,
  "qa_missing_images",
  qa_missing_images,
  overwrite = TRUE
)

# ----------------------------------------
# CLEANUP
# ----------------------------------------

disconnect_db(con)

log_step(
  "✅ Stage 28 TEST COMPLETE"
)