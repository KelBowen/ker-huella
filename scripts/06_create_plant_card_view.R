library(DBI)
library(duckdb)
library(here)

con <- dbConnect(
  duckdb(),
  dbdir = here("database", "ker_huella.duckdb")
)

sql <- "CREATE OR REPLACE VIEW plant_card_view AS
SELECT DISTINCT
    p.plant_id,
    p.latin_name,
    p.accepted_name,
    pn.english_name,
    pn.french_name,
    p.family,
    p.genus,
    u.use_category,
    u.use_description,
    pr.preparation_type
FROM plants p
LEFT JOIN plant_parts pp ON p.plant_id = pp.plant_id
LEFT JOIN uses u ON pp.part_id = u.part_id
LEFT JOIN preparations pr ON u.use_id = pr.use_id
LEFT JOIN plant_names pn ON p.plant_id = pn.plant_id"

dbExecute(con, sql)

print(dbGetQuery(con, "SELECT * FROM plant_card_view"))

