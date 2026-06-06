
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
# CONFIG
# --------------------------------------------------

algolia_url <- "https://yotvbfebjc-dsn.algolia.net/1/indexes/*/queries"
algolia_app_id <- "YOTVBFEBJC"
algolia_api_key <- "843a36372facc0f1836f53d1d5968aa8"

# --------------------------------------------------
# HELPER: clean Latin names
# keeps Genus + species only
# --------------------------------------------------

clean_latin_name <- function(x) {
  x <- as.character(x)
  x <- str_replace(x, "\\(.*?\\)", "")
  x <- str_replace(x, ",.*$", "")
  x <- str_trim(x)
  
  parts <- str_split(x, "\\s+")
  
  sapply(parts, function(p) {
    if (length(p) >= 2) {
      paste(p[1], p[2])
    } else if (length(p) == 1) {
      p[1]
    } else {
      NA_character_
    }
  })
}

# --------------------------------------------------
# HELPER: call Algolia eFlore search
# --------------------------------------------------

query_eflore_algolia <- function(query, hits_per_page = 20) {
  body <- list(
    requests = list(
      list(
        indexName = "Flore",
        params = paste0(
          "query=", URLencode(query, reserved = TRUE),
          "&hitsPerPage=", hits_per_page,
          "&facets=%5B%22referentiels%22%5D"
        )
      )
    )
  )
  
  resp <- tryCatch(
    request(algolia_url) |>
      req_headers(
        `X-Algolia-Application-Id` = algolia_app_id,
        `X-Algolia-API-Key` = algolia_api_key,
        `Content-Type` = "application/json"
      ) |>
      req_body_json(body) |>
      req_perform(),
    error = function(e) NULL
  )
  
  if (is.null(resp)) return(NULL)
  
  parsed <- tryCatch(
    fromJSON(resp_body_string(resp), simplifyVector = FALSE),
    error = function(e) NULL
  )
  
  parsed
}

# --------------------------------------------------
# HELPER: extract best French name from Algolia hits
# --------------------------------------------------

extract_best_french_name <- function(parsed, target_latin) {
  if (is.null(parsed)) return(NA_character_)
  if (is.null(parsed$results) || length(parsed$results) == 0) return(NA_character_)
  if (is.null(parsed$results[[1]]$hits) || length(parsed$results[[1]]$hits) == 0) return(NA_character_)
  
  hits <- parsed$results[[1]]$hits
  target_clean <- clean_latin_name(target_latin)
  
  candidates <- bind_rows(lapply(hits, function(h) {
    if (is.null(h$bdtfx)) return(NULL)
    
    sci <- h$bdtfx$scientific_name %||% NA_character_
    common <- h$bdtfx$common_name
    line_names <- h$bdtfx$line_names %||% NA_character_
    rank <- h$bdtfx$rank %||% NA_integer_
    
    first_common <- NA_character_
    if (!is.null(common) && length(common) > 0) {
      first_common <- common[[1]]
    }
    
    tibble(
      scientific_name = sci,
      latin_clean = clean_latin_name(sci),
      french_name = ifelse(!is.na(first_common) && first_common != "", first_common, line_names),
      rank = as.integer(rank)
    )
  }))
  
  if (nrow(candidates) == 0) return(NA_character_)
  
  # 1. Prefer exact cleaned Latin match
  exact <- candidates %>%
    filter(latin_clean == target_clean) %>%
    filter(!is.na(french_name), french_name != "")
  
  if (nrow(exact) > 0) {
    return(exact$french_name[1])
  }
  
  # 2. Fallback: any candidate with a usable French name
  fallback <- candidates %>%
    filter(!is.na(french_name), french_name != "")
  
  if (nrow(fallback) > 0) {
    return(fallback$french_name[1])
  }
  
  NA_character_
}

# --------------------------------------------------
# NULL-COALESCE OPERATOR
# --------------------------------------------------

`%||%` <- function(a, b) if (!is.null(a)) a else b

# --------------------------------------------------
# LOAD PLANTS
# --------------------------------------------------

plants <- dbReadTable(con, "plants") %>%
  mutate(
    latin_clean = clean_latin_name(latin_name)
  )

# --------------------------------------------------
# LOAD EXISTING plant_names
# --------------------------------------------------

plant_names <- tryCatch(
  dbReadTable(con, "plant_names"),
  error = function(e) NULL
)

if (is.null(plant_names)) {
  plant_names <- plants %>%
    transmute(
      plant_id,
      english_name = NA_character_,
      french_name = NA_character_
    )
}

if (!"english_name" %in% names(plant_names)) {
  plant_names$english_name <- NA_character_
}

if (!"french_name" %in% names(plant_names)) {
  plant_names$french_name <- NA_character_
}

plant_names <- plant_names %>%
  select(plant_id, english_name, french_name)

# --------------------------------------------------
# FETCH FRENCH NAMES
# --------------------------------------------------

french_rows <- lapply(seq_len(nrow(plants)), function(i) {
  plant_id <- plants$plant_id[i]
  latin_name <- plants$latin_clean[i]
  
  cat("Querying eFlore Algolia for:", latin_name, "\n")
  
  parsed <- tryCatch(
    query_eflore_algolia(latin_name),
    error = function(e) NULL
  )
  
  french_name <- tryCatch(
    extract_best_french_name(parsed, latin_name),
    error = function(e) NA_character_
  )
  
  # polite delay to avoid hammering the service
  Sys.sleep(0.2)
  
  data.frame(
    plant_id = plant_id,
    french_name_eflore = french_name,
    stringsAsFactors = FALSE
  )
})

french_names <- bind_rows(french_rows)

# --------------------------------------------------
# UPDATE plant_names
# --------------------------------------------------

plant_names_updated <- plant_names %>%
  left_join(french_names, by = "plant_id") %>%
  mutate(
    french_name = coalesce(french_name_eflore, french_name)
  ) %>%
  select(
    plant_id,
    english_name,
    french_name
  )

# --------------------------------------------------
# SAVE
# --------------------------------------------------

dbExecute(con, "DROP TABLE IF EXISTS plant_names")

dbWriteTable(
  con,
  "plant_names",
  plant_names_updated,
  overwrite = TRUE
)

# --------------------------------------------------
# VERIFY
# --------------------------------------------------

print(
  dbGetQuery(
    con,
    "SELECT * FROM plant_names LIMIT 20"
  )
)

# --------------------------------------------------
# CLOSE
# --------------------------------------------------

dbDisconnect(con, shutdown = TRUE)
