🌿 Ker‑Huella Green Thumb & Potions
A structured plant data system for botanical identity, garden management, and herbal reference, built around reproducible pipelines and a multi-source data architecture.

📖 Overview
The Ker‑Huella dataset is a plant intelligence system designed to unify:

scientific plant identity
multilingual names (English + French)
plant parts, uses, and preparations
garden location tracking
safety and caution flags

It supports:

📊 Power BI analytics and dashboards
🧪 R-based data pipelines
🌱 garden management
📚 curated ethnobotanical reference (non-clinical)


🧠 Key Design Principles

Multi-source architecture (no single “perfect dataset”)
Taxonomy-first normalisation
Separation of concerns (identity, names, uses, locations)
Deterministic pipelines
Safety-first design (non-medical use)


🏗️ System Architecture
Plain TextGBIF            → plant identity (backbone)USDA            → English nameseFlore (Algolia)→ French namesWikipedia       → plant uses→ unified into:plantsplant_namesplant_usesplant_partsplant_locationsplant_card_viewShow more lines

🔗 Data Lineage
Plain TextGBIF → plants      ↓USDA → plant_names (EN)eFlore → plant_names (FR)Wikipedia → plant_uses→ plant_card_view (final output)Show more lines

⚙️ Pipeline Structure
Execution is modular and stage-based:
Rsource("scripts/helpers/run_pipeline.R")``Show more lines

Expanded pipeline (for reference)
R# Setup & ingestionsource("scripts/00_setup.R")source("scripts/01_gbif_ingest.R")source("scripts/02_stage_plants.R")# Model buildsource("scripts/10_create_plant_parts.R")source("scripts/11_create_uses.R")source("scripts/12_create_preparations.R")source("scripts/13_create_locations.R")source("scripts/14_create_plant_locations.R")# Enrichmentsource("scripts/20_enrich_names_usda.R")source("scripts/21_enrich_names_french_algolia.R")source("scripts/22_enrich_uses_wikipedia.R")# Outputsource("scripts/30_create_plant_card_view.R")Show less

📊 Data Model (Simplified)

































TablePurposeplantsCore plant identity (GBIF)plant_namesEnglish + French namesplant_partsPlant anatomyplant_usesUses (Wikipedia)plant_locationsGarden trackingplant_card_viewFinal dataset
➡️ Full schema:
/docs/Ker-Huella_Data_Spec_v2.docx

🌍 Data Sources
✅ Primary sources

GBIF — taxonomic backbone
https://plants.usda.gov/home — English names
Tela Botanica eFlore — enriched data
eFlore search backend (Algolia) — French names
https://www.wikipedia.org/ — plant uses


🧪 Evaluated / Not used

Open Plantbook
Perenual API
Flora API
FloreAPI (unofficial)
Static CSV vernacular datasets


🔜 Future enrichment sources

World Flora Online
Plants of the World Online
IPNI
Trefle

➡️ Full catalogue:
/docs/data_sources_reference_v2.docx

📁 Repository Structure
Plain Textscripts/  00–02   → ingestion  10–14   → data model build  20–22   → enrichment  30      → output  helpers/    run_pipeline.R    validate_connection.R  archive/docs/  Data Specification  Data Sources Reference  Design & Architecture Notesdatabase/outputs/README.mdShow more lines

⚠️ Safety & Scope
This dataset:

✅ includes ethnobotanical and traditional-use references
✅ includes caution and toxicity flags

It does NOT:

❌ provide medical advice
❌ provide dosage recommendations
❌ act as a clinical decision system


✅ Status

✅ Phase 1 model implemented
✅ Multi-source pipeline working
✅ French naming layer resolved (eFlore/Algolia)
✅ Documentation structured in /docs


🚀 Next Steps

Add data validation layer (15_… scripts)
Improve French name ranking logic
Add multi-name support
Integrate research sources (PFAF, Dr Duke, PubMed)
Expand cultural layer (Phase 2)