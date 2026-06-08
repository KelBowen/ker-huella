# ----------------------------------------
# STAGE: ENRICHMENT
# STEP: PLANT USES (Wikipedia)
#
# SOURCE:
# - Wikipedia
# - https://www.wikipedia.org/
#
# PURPOSE:
# - Populate plant uses / summaries
#
# INPUT:
# - plants.latin_name
#
# OUTPUT:
# - plant_uses.wikipedia_summary
#
# NOTES:
# - Provides general ethnobotanical context
# - Not a clinical or medical source
# ----------------------------------------

library(DBI)
library(duckdb)
library(here)
library(httr2)
library(jsonlite)
library(dplyr)
library(stringr)

# --------------------------------------------------
# CONNECT
# --------------------------------------------------

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

# --------------------------------------------------
# LOAD PLANTS
# --------------------------------------------------

plants <- dbReadTable(con, "plants")

# --------------------------------------------------
# CLEAN LATIN NAMES (same logic as before)
# --------------------------------------------------

clean_latin_name <- function(x) {
  x <- str_replace(x, " [A-Z][a-z]*\\.?$", "")   # remove author e.g. "L."
  x <- str_replace(x, "\\(.*\\)", "")            # remove parentheses
  x <- str_trim(x)
  
  parts <- str_split(x, " ")
  
  sapply(parts, function(p) {
    if (length(p) >= 2) {
      paste(p[1], p[2])
    } else {
      p[1]
    }
  })
}

plants <- plants %>%
  mutate(
    latin_clean = clean_latin_name(latin_name)
  )

# --------------------------------------------------
# FUNCTION: GET WIKIPEDIA SUMMARY
# --------------------------------------------------

get_wikipedia_summary <- function(title) {
  
  encoded <- URLencode(title, reserved = TRUE)
  
  url <- paste0(
    "https://en.wikipedia.org/api/rest_v1/page/summary/",
    encoded
  )
  
  resp <- tryCatch(
    request(url) |>
      req_perform(),
    error = function(e) NULL
  )
  
  # if request failed
  if (is.null(resp)) return(NA_character_)
  
  data <- fromJSON(resp_body_string(resp))
  
  # ensure summary exists
  if (!"extract" %in% names(data)) {
    return(NA_character_)
  }
  
  data$extract
}

# --------------------------------------------------
# FETCH SUMMARIES
# --------------------------------------------------

use_rows <- lapply(seq_len(nrow(plants)), function(i) {
  
  plant_id <- plants$plant_id[i]
  latin <- plants$latin_clean[i]
  
  print(paste("Fetching:", latin))
  
  summary <- tryCatch(
    get_wikipedia_summary(latin),
    error = function(e) NA_character_
  )
  
  data.frame(
    plant_id = plant_id,
    wikipedia_summary = summary,
    stringsAsFactors = FALSE
  )
})

plant_uses <- do.call(rbind, use_rows)

# --------------------------------------------------
# SAVE TO DATABASE
# --------------------------------------------------

dbExecute(con, "DROP TABLE IF EXISTS plant_uses")

dbWriteTable(
  con,
  "plant_uses",
  plant_uses,
  overwrite = TRUE
)

# --------------------------------------------------
# VERIFY
# --------------------------------------------------

print(
  dbGetQuery(
    con,
    "SELECT plant_id, substr(wikipedia_summary, 1, 120) AS preview
     FROM plant_uses
     LIMIT 10"
  )
)

# --------------------------------------------------
# CLOSE
# --------------------------------------------------

dbDisconnect(con, shutdown = TRUE)
