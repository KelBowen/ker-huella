# ----------------------------------------
# SCRIPT: 20_enrich_pfaf.R
#
# PURPOSE:
# - Enrich Ker-Huella plants from PFAF
# - Cache enrichment results in DuckDB
#
# NOTES:
# - Only fetches missing plants unless force_refresh = TRUE
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(rvest)
library(xml2)
library(tibble)

cat("\n========================================\n")
cat("STAGE 23: PFAF ENRICHMENT\n")
cat("========================================\n\n")

# ----------------------------------------
# CONFIG
# ----------------------------------------

force_refresh <- FALSE
delay_seconds <- 2
test_limit <- NA_integer_

# ----------------------------------------
# CONNECT
# ----------------------------------------

con <- connect_db()

# ----------------------------------------
# HELPERS
# ----------------------------------------

table_exists <- function(con, table_name) {
  table_name %in% DBI::dbListTables(con)
}

fetch_pfaf_page <- function(latin_name) {
  query <- gsub(" ", "+", latin_name)
  url <- paste0("https://pfaf.org/user/Plant.aspx?LatinName=", query)
  
  log_step(paste("Fetching:", url))
  
  page <- tryCatch(
    read_html(url),
    error = function(e) {
      log_step(paste("❌ Failed:", latin_name))
      NULL
    }
  )
  
  list(page = page, url = url)
}

extract_section <- function(page, section_name) {
  if (is.null(page)) return(NA_character_)
  
  nodes <- tryCatch(
    page %>%
      html_nodes(xpath = paste0("//*[contains(text(), '", section_name, "')]")),
    error = function(e) NULL
  )
  
  if (is.null(nodes) || length(nodes) == 0) return(NA_character_)
  
  text <- tryCatch(
    nodes %>%
      xml_parent() %>%
      html_text(trim = TRUE),
    error = function(e) NA_character_
  )
  
  paste(text, collapse = " ")
}

build_empty_reference_row <- function(latin_name) {
  tibble(
    latin_name = latin_name,
    source_url = NA_character_,
    edible_uses = NA_character_,
    medicinal_uses = NA_character_,
    other_uses = NA_character_,
    hazards = NA_character_,
    cultivation = NA_character_,
    habitat = NA_character_,
    extracted_at = Sys.time()
  )
}

fetch_one_plant <- function(latin_name) {
  Sys.sleep(delay_seconds)
  
  res <- fetch_pfaf_page(latin_name)
  
  if (is.null(res$page)) {
    return(build_empty_reference_row(latin_name))
  }
  
  row <- tibble(
    latin_name = latin_name,
    source_url = res$url,
    edible_uses = extract_section(res$page, "Edible Uses"),
    medicinal_uses = extract_section(res$page, "Medicinal Uses"),
    other_uses = extract_section(res$page, "Other Uses"),
    hazards = extract_section(res$page, "Known Hazards"),
    cultivation = extract_section(res$page, "Cultivation"),
    habitat = extract_section(res$page, "Habitat"),
    extracted_at = Sys.time()
  )
  
  return(row)
}

# ----------------------------------------
# LOAD SEED PLANTS
# ----------------------------------------

if (!table_exists(con, "seed_plants")) {
  disconnect_db(con)
  stop("❌ seed_plants not found. Run Stage 03.")
}

seed_plants <- dbReadTable(con, "seed_plants") %>%
  select(latin_name) %>%
  filter(!is.na(latin_name) & latin_name != "") %>%
  distinct()

log_step(paste("Seed plants:", nrow(seed_plants)))

if (!is.na(test_limit)) {
  seed_plants <- seed_plants %>% head(test_limit)
}

# ----------------------------------------
# LOAD CACHE
# ----------------------------------------

if (table_exists(con, "plant_reference_raw")) {
  cached_reference <- dbReadTable(con, "plant_reference_raw") %>%
    select(latin_name) %>%
    distinct()
} else {
  cached_reference <- tibble(latin_name = character())
}

# ----------------------------------------
# DETERMINE FETCH SET
# ----------------------------------------

plants_to_fetch <- if (force_refresh) {
  seed_plants
} else {
  anti_join(seed_plants, cached_reference, by = "latin_name")
}

log_step(paste("Plants to fetch:", nrow(plants_to_fetch)))

# ----------------------------------------
# FETCH
# ----------------------------------------

new_reference <- if (nrow(plants_to_fetch) > 0) {
  bind_rows(lapply(plants_to_fetch$latin_name, fetch_one_plant))
} else {
  tibble()
}

log_step(paste("Fetched rows:", nrow(new_reference)))

# ----------------------------------------
# SAVE CACHE
# ----------------------------------------

reference_final <- if (force_refresh) {
  new_reference
} else if (table_exists(con, "plant_reference_raw")) {
  existing <- dbReadTable(con, "plant_reference_raw")
  distinct(bind_rows(existing, new_reference), latin_name, .keep_all = TRUE)
} else {
  new_reference
}

dbWriteTable(con, "plant_reference_raw", reference_final, overwrite = TRUE)

log_step(paste("Total cached rows:", nrow(reference_final)))

disconnect_db(con)

cat("\n✅ PFAF enrichment complete\n")