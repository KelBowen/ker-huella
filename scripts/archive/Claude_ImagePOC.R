################################################################################
# Ker-Huella Pipeline — Stage 08
# Script: 08_enrich_images_wikimedia.R
#
# PURPOSE
#   Enrich seed_plants with a representative photo URL for each plant.
#
#   Source responsibility (per Master Architecture, Section 5):
#     Wikidata is responsible for identifiers and linked-data connections,
#     including the P18 ("image") statement, which points to a file on
#     Wikimedia Commons. This script resolves P18 -> a Commons file title
#     -> a real, hotlinkable image URL + licensing metadata via the
#     Commons API.
#
#   This is NOT responsible for choosing "the best" picture of a plant,
#   ranking images, or deduplicating across plants. It only extracts and
#   preserves what Wikidata/Commons return. Any later selection logic
#   (e.g. "pick the primary image") belongs in a downstream parse/
#   normalize stage, consistent with:
#     Extract -> Preserve -> Parse -> Normalize -> Aggregate -> Report
#
# OUTPUT
#   Table: plant_reference_images_raw   (Reference Layer — derived,
#                                         traceable, fully rebuildable)
#
# KEY FIELDS
#   latin_name, wikidata_qid, commons_filename, image_url, thumb_url,
#   page_url, mime_type, license_short_name, artist, credit,
#   source, source_query, retrieved_at
#
# NOTES / LESSONS LEARNED APPLIED
#   - Inspect source schema before writing transformation logic
#     (seed_plants columns are checked, not assumed).
#   - Raw data is preserved: every P18 image found is written, even if a
#     plant has more than one, or none at all.
#   - Deterministic: no inference, no image scoring — pure API lookups.
#   - Wikimedia's API etiquette requires a descriptive User-Agent and
#     batched, rate-limited requests. Both are implemented below.
################################################################################


# =============================================================================
# CONFIG
# =============================================================================

# --- Database -----------------------------------------------------------
# Adjust to match the actual DuckDB path used by the rest of the pipeline.
DB_PATH <- Sys.getenv("KERHUELLA_DB_PATH", unset = "data/kerhuella.duckdb")

INPUT_TABLE  <- "seed_plants"
OUTPUT_TABLE <- "plant_reference_images_raw"

# --- Wikidata / Commons endpoints ---------------------------------------
WIKIDATA_SPARQL_ENDPOINT <- "https://query.wikidata.org/sparql"
COMMONS_API_ENDPOINT     <- "https://commons.wikimedia.org/w/api.php"

# Wikimedia requires a descriptive User-Agent identifying the tool and a
# contact point. Update the contact email before running in production.
USER_AGENT <- httr::user_agent(
  "KerHuellaPipeline/1.0 (https://ker-huella.local; contact: garden-admin@ker-huella.local)"
)

# --- Batching / rate limiting --------------------------------------------
SPARQL_BATCH_SIZE  <- 50   # taxon names per SPARQL VALUES clause
COMMONS_BATCH_SIZE <- 50   # file titles per Commons API call (API max is 50)
REQUEST_DELAY_SEC  <- 1    # pause between batched requests, be a good API citizen
THUMB_WIDTH_PX     <- 500  # requested thumbnail width

# --- Logging ---------------------------------------------------------------
LOG_PREFIX <- "[08_enrich_images_wikimedia]"

log_msg <- function(...) {
  cat(LOG_PREFIX, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", ..., "\n")
}


# =============================================================================
# CONNECT
# =============================================================================

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(duckdb)
  library(DBI)
})

log_msg("Connecting to DuckDB at", DB_PATH)
con <- dbConnect(duckdb(), dbdir = DB_PATH, read_only = FALSE)


# =============================================================================
# VALIDATE INPUT
# =============================================================================

# Lesson learned: never assume a table's structure — inspect it first.
if (!(INPUT_TABLE %in% dbListTables(con))) {
  dbDisconnect(con, shutdown = TRUE)
  stop(sprintf("Required input table '%s' was not found in %s", INPUT_TABLE, DB_PATH))
}

input_schema <- dbGetQuery(con, sprintf("PRAGMA table_info('%s')", INPUT_TABLE))
log_msg("Inspected schema of", INPUT_TABLE, "-", nrow(input_schema), "columns")

if (!("latin_name" %in% input_schema$name)) {
  dbDisconnect(con, shutdown = TRUE)
  stop(sprintf("'%s' is missing the required 'latin_name' column", INPUT_TABLE))
}

seed_plants <- dbGetQuery(con, sprintf(
  "SELECT DISTINCT latin_name FROM %s WHERE latin_name IS NOT NULL", INPUT_TABLE
))

latin_names <- trimws(unique(seed_plants$latin_name))
latin_names <- latin_names[nzchar(latin_names)]

if (length(latin_names) == 0) {
  dbDisconnect(con, shutdown = TRUE)
  stop(sprintf("No usable latin_name values found in %s", INPUT_TABLE))
}

log_msg("Validated input:", length(latin_names), "distinct latin_name values to look up")


# =============================================================================
# HELPERS
# =============================================================================

#' Split a vector into fixed-size chunks (deterministic order preserved).
chunk_vector <- function(x, size) {
  split(x, ceiling(seq_along(x) / size))
}

#' Escape a string for safe embedding inside a SPARQL string literal.
sparql_escape <- function(x) {
  gsub('"', '\\\\"', x, fixed = TRUE)
}

#' Build a SPARQL query that, for a batch of scientific names, returns the
#' Wikidata QID (via P225 = "taxon name") and any P18 ("image") value.
#' A plant with multiple images returns one row per image (OPTIONAL keeps
#' plants with zero images in the result set as well, with image = NA).
build_sparql_query <- function(names_chunk) {
  values_clause <- paste0('"', sparql_escape(names_chunk), '"', collapse = " ")
  sprintf('
    SELECT ?taxonNameInput ?item ?image WHERE {
      VALUES ?taxonNameInput { %s }
      ?item wdt:P225 ?taxonNameInput .
      OPTIONAL { ?item wdt:P18 ?image . }
    }
  ', values_clause)
}

#' Execute a SPARQL query against the Wikidata Query Service.
query_wikidata_sparql <- function(query) {
  resp <- httr::GET(
    url = WIKIDATA_SPARQL_ENDPOINT,
    query = list(query = query, format = "json"),
    httr::accept("application/sparql-results+json"),
    USER_AGENT
  )

  if (httr::status_code(resp) != 200) {
    log_msg("WARNING: Wikidata SPARQL request failed with status",
            httr::status_code(resp))
    return(NULL)
  }

  jsonlite::fromJSON(httr::content(resp, as = "text", encoding = "UTF-8"),
                      simplifyVector = FALSE)
}

#' Turn a Wikidata P18 "image" value (a Special:FilePath URL) into a
#' Commons "File:..." page title, which the Commons API expects.
#'   e.g. "http://commons.wikimedia.org/wiki/Special:FilePath/Salix%20triandra.jpg"
#'     -> "File:Salix triandra.jpg"
extract_commons_filename <- function(filepath_url) {
  if (is.null(filepath_url) || is.na(filepath_url) || !nzchar(filepath_url)) {
    return(NA_character_)
  }
  raw_name <- sub(".*/Special:FilePath/", "", filepath_url)
  decoded  <- utils::URLdecode(raw_name)
  paste0("File:", decoded)
}

#' Parse the SPARQL JSON response into a flat data frame:
#' latin_name | wikidata_qid | commons_filename
parse_sparql_results <- function(sparql_json) {
  bindings <- sparql_json$results$bindings

  if (length(bindings) == 0) {
    return(data.frame(
      latin_name = character(0), wikidata_qid = character(0),
      commons_filename = character(0), stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(bindings, function(b) {
    qid_uri <- if (!is.null(b$item)) b$item$value else NA_character_
    data.frame(
      latin_name        = if (!is.null(b$taxonNameInput)) b$taxonNameInput$value else NA_character_,
      wikidata_qid      = if (!is.na(qid_uri)) sub(".*/", "", qid_uri) else NA_character_,
      commons_filename  = extract_commons_filename(if (!is.null(b$image)) b$image$value else NA_character_),
      stringsAsFactors  = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Query the Commons API for imageinfo (real URL, thumbnail, license,
#' artist, credit) for a batch of "File:..." titles.
get_commons_imageinfo <- function(filenames_chunk) {
  resp <- httr::GET(
    url = COMMONS_API_ENDPOINT,
    query = list(
      action      = "query",
      titles      = paste(filenames_chunk, collapse = "|"),
      prop        = "imageinfo",
      iiprop      = "url|mime|extmetadata",
      iiurlwidth  = THUMB_WIDTH_PX,
      format      = "json"
    ),
    USER_AGENT
  )

  if (httr::status_code(resp) != 200) {
    log_msg("WARNING: Commons API request failed with status",
            httr::status_code(resp))
    return(NULL)
  }

  jsonlite::fromJSON(httr::content(resp, as = "text", encoding = "UTF-8"),
                      simplifyVector = FALSE)
}

#' Safely pull a scalar extmetadata field (they arrive as list(value=...)).
extmeta_value <- function(extmetadata, field) {
  if (is.null(extmetadata) || is.null(extmetadata[[field]])) return(NA_character_)
  val <- extmetadata[[field]]$value
  if (is.null(val)) NA_character_ else as.character(val)
}

#' Parse the Commons API imageinfo response into a flat data frame:
#' commons_filename | image_url | thumb_url | page_url | mime_type |
#' license_short_name | artist | credit
parse_commons_imageinfo <- function(commons_json) {
  pages <- commons_json$query$pages
  if (is.null(pages) || length(pages) == 0) {
    return(data.frame(
      commons_filename = character(0), image_url = character(0),
      thumb_url = character(0), page_url = character(0),
      mime_type = character(0), license_short_name = character(0),
      artist = character(0), credit = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(pages, function(pg) {
    info <- pg$imageinfo
    if (is.null(info) || length(info) == 0) return(NULL)
    ii <- info[[1]]
    em <- ii$extmetadata

    data.frame(
      commons_filename   = pg$title,
      image_url          = ifelse(is.null(ii$url), NA_character_, ii$url),
      thumb_url           = ifelse(is.null(ii$thumburl), NA_character_, ii$thumburl),
      page_url            = ifelse(is.null(ii$descriptionurl), NA_character_, ii$descriptionurl),
      mime_type            = ifelse(is.null(ii$mime), NA_character_, ii$mime),
      license_short_name  = extmeta_value(em, "LicenseShortName"),
      artist              = extmeta_value(em, "Artist"),
      credit              = extmeta_value(em, "Credit"),
      stringsAsFactors    = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(data.frame(
      commons_filename = character(0), image_url = character(0),
      thumb_url = character(0), page_url = character(0),
      mime_type = character(0), license_short_name = character(0),
      artist = character(0), credit = character(0),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}


# =============================================================================
# PROCESSING
# =============================================================================

# --- Step 1: Wikidata lookup (latin_name -> QID + Commons filename) --------
log_msg("Querying Wikidata for", length(latin_names), "taxon names in batches of", SPARQL_BATCH_SIZE)

name_chunks <- chunk_vector(latin_names, SPARQL_BATCH_SIZE)
wikidata_results_list <- vector("list", length(name_chunks))

for (i in seq_along(name_chunks)) {
  log_msg("SPARQL batch", i, "of", length(name_chunks))
  query <- build_sparql_query(name_chunks[[i]])
  result_json <- query_wikidata_sparql(query)

  wikidata_results_list[[i]] <- if (is.null(result_json)) {
    data.frame(latin_name = character(0), wikidata_qid = character(0),
               commons_filename = character(0), stringsAsFactors = FALSE)
  } else {
    parse_sparql_results(result_json)
  }

  Sys.sleep(REQUEST_DELAY_SEC)
}

wikidata_results <- do.call(rbind, wikidata_results_list)
log_msg("Wikidata returned", nrow(wikidata_results), "rows",
        "(", length(unique(wikidata_results$wikidata_qid[!is.na(wikidata_results$wikidata_qid)])), "distinct QIDs,",
        sum(!is.na(wikidata_results$commons_filename)), "with a P18 image )")

# --- Step 2: Commons imageinfo lookup (filename -> real URLs + license) ----
commons_filenames <- unique(wikidata_results$commons_filename[!is.na(wikidata_results$commons_filename)])

if (length(commons_filenames) == 0) {
  log_msg("No Commons filenames to resolve — no plants had a P18 image on Wikidata")
  images_df <- data.frame(
    commons_filename = character(0), image_url = character(0),
    thumb_url = character(0), page_url = character(0),
    mime_type = character(0), license_short_name = character(0),
    artist = character(0), credit = character(0),
    stringsAsFactors = FALSE
  )
} else {
  log_msg("Resolving", length(commons_filenames), "Commons files in batches of", COMMONS_BATCH_SIZE)

  file_chunks <- chunk_vector(commons_filenames, COMMONS_BATCH_SIZE)
  images_list <- vector("list", length(file_chunks))

  for (i in seq_along(file_chunks)) {
    log_msg("Commons batch", i, "of", length(file_chunks))
    commons_json <- get_commons_imageinfo(file_chunks[[i]])

    images_list[[i]] <- if (is.null(commons_json)) {
      data.frame(commons_filename = character(0), image_url = character(0),
                 thumb_url = character(0), page_url = character(0),
                 mime_type = character(0), license_short_name = character(0),
                 artist = character(0), credit = character(0),
                 stringsAsFactors = FALSE)
    } else {
      parse_commons_imageinfo(commons_json)
    }

    Sys.sleep(REQUEST_DELAY_SEC)
  }

  images_df <- do.call(rbind, images_list)
}

# --- Step 3: Join Wikidata results with resolved Commons metadata ----------
plant_reference_images_raw <- merge(
  wikidata_results, images_df,
  by = "commons_filename", all.x = TRUE
)

plant_reference_images_raw$source        <- "Wikidata P18 + Wikimedia Commons API"
plant_reference_images_raw$source_query  <- WIKIDATA_SPARQL_ENDPOINT
plant_reference_images_raw$retrieved_at  <- Sys.time()

# Reorder columns for readability / consistency with other reference tables
plant_reference_images_raw <- plant_reference_images_raw[, c(
  "latin_name", "wikidata_qid", "commons_filename", "image_url", "thumb_url",
  "page_url", "mime_type", "license_short_name", "artist", "credit",
  "source", "source_query", "retrieved_at"
)]

log_msg("Assembled", nrow(plant_reference_images_raw), "candidate image rows")


# =============================================================================
# QA
# =============================================================================

n_input           <- length(latin_names)
n_matched_wikidata <- length(unique(wikidata_results$latin_name[!is.na(wikidata_results$wikidata_qid)]))
n_with_image      <- length(unique(plant_reference_images_raw$latin_name[!is.na(plant_reference_images_raw$image_url)]))
n_no_wikidata     <- n_input - n_matched_wikidata
n_wikidata_no_image <- n_matched_wikidata - n_with_image

log_msg("QA summary:")
log_msg("  Input plants ..................", n_input)
log_msg("  Matched a Wikidata item ........", n_matched_wikidata)
log_msg("  Wikidata match, no P18 image ...", n_wikidata_no_image)
log_msg("  No Wikidata match at all .......", n_no_wikidata)
log_msg("  Resolved to a usable image URL .", n_with_image)

# Defensive check: every resolved image URL should be a genuine Commons/
# Wikimedia upload URL. Anything else indicates a parsing bug, not bad data.
bad_urls <- plant_reference_images_raw$image_url[
  !is.na(plant_reference_images_raw$image_url) &
  !grepl("^https://upload\\.wikimedia\\.org/", plant_reference_images_raw$image_url)
]
if (length(bad_urls) > 0) {
  log_msg("WARNING:", length(bad_urls), "image_url values do not look like genuine",
          "upload.wikimedia.org URLs — inspect before trusting this run")
}

# Duplicate check: same plant + same file should not appear twice.
dupe_check <- plant_reference_images_raw[
  !is.na(plant_reference_images_raw$commons_filename),
  c("latin_name", "commons_filename")
]
n_dupes <- sum(duplicated(dupe_check))
if (n_dupes > 0) {
  log_msg("WARNING:", n_dupes, "duplicate (latin_name, commons_filename) pairs found")
}


# =============================================================================
# SAVE
# =============================================================================

# Reference tables are rebuildable from source — overwrite rather than
# append, consistent with the rest of the reference layer.
log_msg("Writing", nrow(plant_reference_images_raw), "rows to", OUTPUT_TABLE)
dbWriteTable(con, OUTPUT_TABLE, plant_reference_images_raw, overwrite = TRUE)


# =============================================================================
# CLEANUP
# =============================================================================

dbDisconnect(con, shutdown = TRUE)
log_msg("Done.")
