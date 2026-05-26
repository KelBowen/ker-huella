# ker-huella
<b>Ker-Huella Green Thumbs and Potions</b>

Purpose. The Ker‑Huella plant dataset is intended to become a single, structured source of truth for the estate’s cultivated, wild and reference plants, with enough detail to support botanical identity, edible and herbal notes, garden management, and careful safety screening. The dataset is designed to connect plant identity with plant-part detail, uses, preparations and the physical location of each plant within the Ker‑Huella domain.

Intended uses. 
(1) PowerBI reporting for filtering, summary counts, harvest windows and location-based views; 
(2) R workflows for taxonomy normalisation, evidence aggregation and exploratory analysis; 
(3) Garden management for what is planted where, what needs attention and when parts are usually harvested; and 
(4) A carefully curated herbal reference layer that captures traditional/reference notes, linked sources and caution flags without trying to behave like a medical decision system.

<b>External Data Sources</b>
Recommended ingestion principle: normalise taxonomy first (WFO/GBIF/Wikidata), then enrich with practical/horticultural data (PFAF, Edible Plant Database/FFI) and evidence-linked references (PubMed, Dr. Duke). Preserve source notes for every curated field.
PlantaeDB
Description	Collaborative botanical knowledge base focused on plant taxonomy, scientifically-proven uses, active compounds, distribution, synonyms, common names, literature links and cross-links to other plant resources.
Access method	Public web interface; browse/search by scientific name, common name or compound. No official public Phase 1 API endpoint was identified in the retrieved source, so ingestion should be treated as manual lookup or carefully governed scraping only if terms permit. URL: https://plantaedb.com/
Key fields available	Scientific classification; images; description; synonyms; common names; distribution; linked databases; scientific literature; natural compounds; contributors.
Relevance to the project	Good aggregator for botanical identity, literature links and compound/context overview. Useful as a discovery layer, not as the sole authority of record.

Plants For A Future (PFAF)
Description	Long-running database for edible, medicinal and other useful plants with search filters by edible/medicinal uses, habitat, tolerances and growth conditions.
Access method	Public website search; downloadable Excel/CSV/SQLite database is available under licence. URLs: https://pfaf.org/user/default.aspx and https://plantsforafuture.com/temperate-plant-database/
Key fields available	Latin name; common name; family; habit; hardiness; height/width; soil; shade; moisture; edible uses; medicinal uses; other uses; known hazards; cultivation details; propagation; ratings.
Relevance to the project	High value for horticultural and practical-use metadata, especially for a garden management and edible-herb context.

Dr. Duke’s Phytochemical & Ethnobotanical Databases
Description	USDA-maintained ethnobotanical and phytochemical resource supporting plant, chemical, bioactivity and ethnobotany search.
Access method	Public search site plus downloadable raw CSV archive and preliminary data dictionary. URLs: https://phytochem.nal.usda.gov/ and https://catalog.data.gov/dataset/dr-dukes-phytochemical-and-ethnobotanical-databases-0849e
Key fields available	Plant names; chemicals; biological activities; ethnobotanical activities/uses; toxicity references/LD data; supporting publication references.
Relevance to the project	Best Phase 1 source for compound-level and ethnobotanical evidence pointers when a plant has traditional or research-linked herbal interest.

Edible Plant Database
Description	Structured edible plant platform with species pages and a documented REST API. The content states data are sourced from Food Plants International and enriched with community summaries/images.
Access method	Free REST API with API key after account sign-in; web browsing also available. URLs: https://edibleplantdb.org/ and https://edibleplantdb.org/api-docs
Key fields available	Scientific names; edible uses; cultivation details; nutrition data; lookalikes; photos; family; country distribution; search filters by edible part and geography.
Relevance to the project	Efficient for edible-use seeding, food-part indexing and quickly testing plant records in dashboards and API-driven workflows.

World Flora Online (WFO)
Description	Global collaborative flora and taxonomic backbone for known plants, intended to support plant conservation and provide accepted names, distributions, references and descriptions.
Access method	Public portal and downloadable/machine-readable backbone data; WFO documentation references the WFO PlantList API and machine-readable repositories. URLs: https://www.worldfloraonline.org/ and https://plant-list-docs.rbge.info/
Key fields available	Accepted names; synonyms; taxonomic status; references; distributions; descriptions; images; taxon identifiers.
Relevance to the project	Primary name-normalisation authority for accepted scientific names and synonyms in Phase 1.

GBIF
Description	Global Biodiversity Information Facility providing open biodiversity data, especially occurrence data and indexed taxonomic backbone services.
Access method	Official REST APIs at https://api.gbif.org/ with technical docs for species and occurrence services. URLs: https://techdocs.gbif.org/en/openapi/, https://techdocs.gbif.org/en/openapi/v1/species, https://techdocs.gbif.org/en/openapi/v1/occurrence
Key fields available	Taxon keys; scientific names; vernacular names; synonyms; descriptions; distributions; occurrence records; locality; coordinates; dataset provenance.
Relevance to the project	Useful for distribution, specimen/occurrence context and linking taxonomy to geospatial analysis.

PubMed
Description	Bibliographic database of biomedical literature with search, summary and record retrieval via E-utilities and FTP/XML distribution.
Access method	NCBI E-Utilities API and bulk XML/FTP download. URLs: https://eutilities.github.io/site/ and https://pubmed.ncbi.nlm.nih.gov/download/
Key fields available	PMID; title; abstract; authors; journal; publication date; MeSH terms; article type; links to full text where available.
Relevance to the project	Evidence layer for literature pointers, review status and later evidence scoring. In Phase 1 it should be stored as linked references, not as a clinical claim engine.

Wikidata
Description	Open structured knowledge graph that can provide multilingual common names, identifiers, taxonomic relationships and linked open data connections.
Access method	SPARQL endpoint, Special:EntityData JSON and REST API. URLs: https://query.wikidata.org/, https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service, https://www.wikidata.org/wiki/Wikidata:Data_formats and https://www.wikidata.org/wiki/Wikidata:REST_API
Key fields available	QID; labels/aliases; taxon identifiers; commons media links; external IDs; multilingual names; graph relationships.
Relevance to the project	Excellent identifier hub and multilingual enrichment layer, especially for English/French common names and cross-database linking.

Ker‑Huella local tables
Description	Project-owned authoritative tables for site-specific plant inventory, locations, harvest notes and curation status.
Access method	Direct database entry, spreadsheet import or app-based data entry. Internal only.
Key fields available	Local IDs; planting status; location; bed/zone; harvest windows; summary notes; cautions; provenance; review status.
Relevance to the project	This is the authoritative operational layer for garden management and the only place where local truth (what is actually planted at Ker‑Huella) should be maintained.


