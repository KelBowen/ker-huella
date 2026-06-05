
# Ker-Huella – Lessons Learned

## Data Engineering

### 1. Always inspect source schema
- Use:
  - `names(df)` in R
  - `PRAGMA table_info(table_name)` in DuckDB
- Do not assume column names or naming conventions.

---

### 2. Do not assume naming standards across sources
- GBIF returns camelCase:
  - `scientificName`
  - `acceptedScientificName`
  - `taxonKey`
- Not snake_case.

---

### 3. Occurrence data is not entity data
- GBIF occurrence data contains:
  - duplicates
  - inconsistent taxonomy
- Must transform into:
  - unique plant entities

---

### 4. Debug by simplifying first
- Remove fields
- Get a minimal working version
- Add fields back one at a time

---

### 5. Zero-length errors = schema or data issue
- Usually caused by:
  - incorrect column names
  - empty vectors
- Not a logic issue

---

### 6. Connection lifecycle matters
- Always create a fresh DuckDB connection
- Do not reuse stale connections

---

### 7. Never guess — inspect the data
- When stuck:
  - look at real values
  - not the code

---

## Workflow

### 8. Build pipelines incrementally
- Ingest → inspect → clean → model
- Not:
  - ingest → model immediately

---

### 9. Separate input data from code
- Use:
  - `plant_list.csv`
- Do not hardcode values inside scripts

---

## Current Architecture

