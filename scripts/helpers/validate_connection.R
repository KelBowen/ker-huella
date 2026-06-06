

con <- DBI::dbConnect(
  duckdb::duckdb(),
  dbdir = here::here("database", "ker_huella.duckdb")
)

DBI::dbGetQuery(con, "
  SELECT plant_id, english_name, substr(wikipedia_summary, 1, 100)
  FROM plant_card_view
  LIMIT 5
")
