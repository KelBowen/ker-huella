
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
🌿 Lessons Learned — Data Source Evaluation
✅ Objective
The goal was to identify reliable data sources for:

plant taxonomy
plant names (common names, multilingual)
plant uses


🌐 Wikidata
✅ Why it was considered

large global knowledge graph
multilingual support
rich semantic structure

❌ Issues encountered

Entity ambiguity

multiple entities per plant (species, subspecies, articles, extracts)


Unreliable matching

exact string matching failed due to naming variations


Inconsistent schema for names

aliases vs labels not consistently populated


Poor coverage of common names
Complex querying (SPARQL) required
High effort for low reliability

📌 Conclusion

Wikidata is not suitable for reliable plant name enrichment or use extraction in this pipeline.


🌿 Open Plantbook API
✅ Why it was considered

plant-specific API
structured data model
supports common names and multilingual aliases

❌ Issues encountered

Requires authenticated API access
PID-based lookup required search step first
Inconsistent dataset coverage
Sparse or missing records for many plants
Additional API complexity (token + search + detail)

📌 Conclusion

Suitable in principle, but too complex and inconsistent for this use case compared to dataset alternatives.


🌾 USDA PLANTS Dataset
✅ Why it was selected

curated government dataset
consistent schema
includes:

scientific names
common names


available as downloadable dataset (no API required)

✅ Advantages observed

High data quality
Deterministic processing
Easy integration
Reliable common names
No dependency on external services

⚠️ Limitations

primarily US-focused
English-only common names
no detailed “uses” information

📌 Conclusion

USDA PLANTS is the most reliable source for plant name enrichment in this pipeline.


📄 Wikipedia
✅ Why it was selected

high coverage of plant species
structured narrative content
includes:

uses
medicinal properties
culinary applications



✅ Advantages observed

Consistent page-per-plant model
Simple API endpoint
Good coverage of general uses
No entity resolution complexity

⚠️ Limitations

unstructured text
requires parsing / interpretation
variability in content detail

📌 Conclusion

Wikipedia is the most practical source for plant usage information.


🔬 Dryad
✅ Why it was considered

repository of scientific datasets
high-quality research data

❌ Issues encountered

No standard schema across datasets
Not suitable for pipeline ingestion
Requires manual dataset selection
Inconsistent coverage

📌 Conclusion

Best suited for advanced enrichment (traits, research data), not for core pipeline use.


🌍 OECD Data Explorer
✅ Why it was considered

structured environmental and agricultural data

❌ Issues encountered

No species-level plant data
Macro-level indicators only
Not aligned with plant-level modelling

📌 Conclusion

Not suitable for plant-level data; useful only for contextual analytics.


✅ ✅ Key Technical Lessons
1. ❗ Exact string matching is unreliable

scientific names vary across datasets
must use cleaning + normalization


2. ❗ APIs are not always the best solution

introduce:

instability
rate limits
complexity


datasets are often more reliable


3. ✅ Separate concerns by data layer

























LayerSourceTaxonomyGBIFNamesUSDAUsesWikipediaAdvanced enrichmentDryad

4. ✅ Prefer deterministic pipelines

reproducible results are more important than “smart” automation


5. ✅ Simplicity beats completeness initially

better to have:

partial but reliable data
than:
complete but inconsistent data




✅ ✅ Final Architecture
GBIF → taxonomy backbone
USDA → plant names
Wikipedia → plant uses
Dryad → (future enrichment)
OECD → (context layer)


✅ ✅ Final takeaway

A multi-source approach with clearly defined roles is more robust than relying on a single “universal” dataset.
