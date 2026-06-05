---
title: "pipeline"
output: html_document
---

flowchart TD

A[plant_list.csv] --> B[GBIF Ingest]
B --> C[plants table]

C --> D[USDA Names Enrichment]
D --> E[plant_names]

C --> F[Wikipedia Uses Enrichment]
F --> G[plant_uses]

C --> H[Domain Tables]
H --> I[plant_parts / plant_preparations]

E --> J[plant_card_view]
G --> J
I --> J

J --> K[Power BI Dashboard]