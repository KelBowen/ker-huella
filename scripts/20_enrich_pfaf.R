# ----------------------------------------
# SCRIPT: 20_enrich_pfaf.R
#
# PURPOSE:
# - Enrich Ker-Huella plants from PFAF
# - Cache enrichment results in DuckDB
#
# NOTES:
# - Uses section-based extraction
# - Much cleaner than whole-page extraction
# ----------------------------------------

source("scripts/00_setup.R")

library(dplyr)
library(stringr)
library(rvest)
library(xml2)
library(tibble)

cat("\n========================================\n")
cat("STAGE 20: PFAF ENRICHMENT\n")
cat("========================================\n\n")

# ----------------------------------------
# CONFIG
# ----------------------------------------

force_refresh <- FALSE
delay_seconds <- 2
test_limit <- NA

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

# ----------------------------------------
# FETCH PAGE
# ----------------------------------------

fetch_pfaf_page <- function(latin_name) {
  
  query <- gsub(" ", "+", latin_name)
  
  url <- paste0(
    "https://pfaf.org/user/Plant.aspx?LatinName=",
    query
  )
  
  log_step(
    paste("Fetching:", latin_name)
  )
  
  page <- tryCatch(
    read_html(url),
    error = function(e) {
      
      log_step(
        paste("❌ Failed:", latin_name)
      )
      
      NULL
    }
  )
  
  list(
    page = page,
    url = url
  )
}

# ----------------------------------------
# CLEAN SECTION TEXT
# ----------------------------------------

clean_section_text <- function(text) {
  
  if (is.na(text)) {
    return(NA_character_)
  }
  
  text <- str_replace_all(
    text,
    "\\[\\d+\\]",
    ""
  )
  
  text <- str_replace_all(
    text,
    "Plants For A Future can not take any responsibility for any adverse effects from the use of plants\\.",
    ""
  )
  
  text <- str_replace_all(
    text,
    "Always seek advice from a professional before using a plant medicinally\\.",
    ""
  )
  
  text <- str_replace_all(
    text,
    "References.*",
    ""
  )
  
  text <- str_squish(text)
  
  text
}

# ----------------------------------------
# EXTRACT SUMMARY TABLE FIELD
# ----------------------------------------

extract_summary_field <- function(
    page,
    field_name
) {
  
  if (is.null(page)) {
    return(NA_character_)
  }
  
  tables <- html_table(
    html_elements(page, "table"),
    fill = TRUE
  )
  
  if (length(tables) == 0) {
    return(NA_character_)
  }
  
  summary_tbl <- tables[[1]]
  
  if (nrow(summary_tbl) == 0) {
    return(NA_character_)
  }
  
  match_row <- which(
    str_detect(
      summary_tbl[[1]],
      regex(field_name, TRUE)
    )
  )
  
  if (length(match_row) == 0) {
    return(NA_character_)
  }
  
  value <- summary_tbl[[2]][match_row[1]]
  
  value <- str_squish(value)
  
  if (
    is.na(value) ||
    value == ""
  ) {
    return(NA_character_)
  }
  
  value
  
}

# ----------------------------------------
# EXTRACT H2 SECTION
# ----------------------------------------

extract_h2_section <- function(page, heading) {
  
  if (is.null(page)) {
    return(NA_character_)
  }
  
  header <- html_nodes(
    page,
    xpath = paste0(
      "//h2[contains(., '",
      heading,
      "')]"
    )
  )
  
  if (length(header) == 0) {
    return(NA_character_)
  }
  
  header <- header[[1]]
  
  parent <- xml_parent(header)
  
  children <- xml_children(parent)
  
  idx <- which(
    sapply(
      children,
      function(x)
        identical(
          as.character(x),
          as.character(header)
        )
    )
  )
  
  if (length(idx) == 0) {
    return(NA_character_)
  }
  
  next_idx <- idx + 1
  
  if (next_idx > length(children)) {
    return(NA_character_)
  }
  
  content_node <- children[[next_idx]]
  
  txt <- html_text(content_node)
  
  clean_section_text(txt)
}

# ----------------------------------------
# EMPTY ROW
# ----------------------------------------

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

# ----------------------------------------
# FETCH ONE PLANT
# ----------------------------------------

fetch_one_plant <- function(latin_name) {
  
  Sys.sleep(delay_seconds)
  
  res <- fetch_pfaf_page(latin_name)
  
  if (is.null(res$page)) {
    return(
      build_empty_reference_row(
        latin_name
      )
    )
  }
  
  tibble(
    latin_name = latin_name,
    
    source_url = res$url,
    
    edible_uses = extract_h2_section(
      res$page,
      "Edible Uses"
    ),
    
    medicinal_uses = extract_h2_section(
      res$page,
      "Medicinal Uses"
    ),
    
    other_uses = extract_h2_section(
      res$page,
      "Other Uses"
    ),
    
    hazards = extract_summary_field(
      res$page,
      "Known Hazards"
    ),
    
    cultivation = extract_h2_section(
      res$page,
      "Cultivation details"
    ),
    
    habitat = extract_h2_section(
      res$page,
      "Plant Habitats"
    ),
    
    extracted_at = Sys.time()
  )
}

# ----------------------------------------
# LOAD SEED PLANTS
# ----------------------------------------

if (!table_exists(con, "seed_plants")) {
  
  disconnect_db(con)
  
  stop(
    "❌ seed_plants not found. Run Stage 03."
  )
  
}

seed_plants <- dbReadTable(
  con,
  "seed_plants"
) %>%
  select(latin_name) %>%
  filter(
    !is.na(latin_name),
    latin_name != ""
  ) %>%
  distinct()

log_step(
  paste(
    "Seed plants:",
    nrow(seed_plants)
  )
)

if (!is.na(test_limit)) {
  seed_plants <- head(
    seed_plants,
    test_limit
  )
}

# ----------------------------------------
# LOAD CACHE
# ----------------------------------------

if (
  table_exists(
    con,
    "plant_reference_raw"
  )
) {
  
  cached_reference <- dbReadTable(
    con,
    "plant_reference_raw"
  ) %>%
    select(latin_name) %>%
    distinct()
  
} else {
  
  cached_reference <- tibble(
    latin_name = character()
  )
  
}

# ----------------------------------------
# DETERMINE FETCH SET
# ----------------------------------------

plants_to_fetch <- if (force_refresh) {
  
  seed_plants
  
} else {
  
  anti_join(
    seed_plants,
    cached_reference,
    by = "latin_name"
  )
  
}

log_step(
  paste(
    "Plants to fetch:",
    nrow(plants_to_fetch)
  )
)

# ----------------------------------------
# FETCH
# ----------------------------------------

new_reference <- if (
  nrow(plants_to_fetch) > 0
) {
  
  bind_rows(
    lapply(
      plants_to_fetch$latin_name,
      fetch_one_plant
    )
  )
  
} else {
  
  tibble()
  
}

log_step(
  paste(
    "Fetched rows:",
    nrow(new_reference)
  )
)

# ----------------------------------------
# SAVE CACHE
# ----------------------------------------

reference_final <- if (
  force_refresh
) {
  
  new_reference
  
} else if (
  table_exists(
    con,
    "plant_reference_raw"
  )
) {
  
  existing <- dbReadTable(
    con,
    "plant_reference_raw"
  )
  
  distinct(
    bind_rows(
      existing,
      new_reference
    ),
    latin_name,
    .keep_all = TRUE
  )
  
} else {
  
  new_reference
  
}

dbWriteTable(
  con,
  "plant_reference_raw",
  reference_final,
  overwrite = TRUE
)

log_step(
  paste(
    "Total cached rows:",
    nrow(reference_final)
  )
)

disconnect_db(con)

cat("\n✅ PFAF enrichment complete\n")