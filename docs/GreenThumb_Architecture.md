# Ker-Huella Master Architecture Document

**Version:** 1.0  
**Status:** Active Architecture Baseline  
**Last Updated:** August 2026

---

# 1. Executive Summary

## Purpose

Ker-Huella is a plant intelligence platform designed to support:

- Plant collection management
- Plant taxonomy management
- Ethnobotanical reference enrichment
- Harvest intelligence
- Plant knowledge discovery
- Analytics and reporting
- Power BI dashboards

The system is intentionally designed around a modular, deterministic architecture where each data source is responsible for a specific domain of knowledge.

---

## Core Goal

Create a single plant intelligence system that combines:

```text
Taxonomy
Names
Uses
Medicinal Information
Safety Information
Plant Parts
Harvest Intelligence
Analytics
```

while preserving:

```text
Traceability
Reproducibility
Source Lineage
Data Quality
```

---

# 2. Design Principles

## Separation of Concerns

Operational data and reference data are separate.

Operational truth:

```text
seed_plants
plant_inventory
harvests
locations
```

Reference enrichment:

```text
plant_reference_*
```

Reference data never becomes operational truth.

---

## Deterministic Processing

Prefer:

```text
Rules
Dictionaries
Controlled vocabularies
Explicit transformations
```

Avoid:

```text
Opaque inference
Non-deterministic classification
Untraceable automation
```

---

## Raw Data Preservation

Raw source data must be preserved.

Never overwrite source content with derived content.

The architecture follows:

```text
Extract
→ Preserve
→ Parse
→ Normalize
→ Aggregate
→ Report
```

---

## Incremental Architecture

Every stage must:

1. Receive validated input
2. Produce observable output
3. Be testable independently

---

## Traceability

Every normalized fact should be traceable to:

```text
Original source
Source record
Source description
```

---

# 3. High-Level System Architecture

```text
             ┌─────────┐
             │  GBIF   │
             └────┬────┘
                  │
                  ▼
             Taxonomy

             ┌─────────┐
             │ USDA    │
             └────┬────┘
                  │
                  ▼
              Names

             ┌─────────┐
             │Wikipedia│
             └────┬────┘
                  │
                  ▼
               Uses

             ┌─────────┐
             │  PFAF   │
             └────┬────┘
                  │
                  ▼
           Ethnobotanical
             Enrichment

                  │
                  ▼

            DuckDB Core

                  │
                  ▼

              Power BI
```

---

# 4. Data Layer Architecture

## Operational Layer

Represents owned and managed plant information.

### Examples

```text
seed_plants
plant_inventory
plant_locations
harvests
```

Characteristics:

```text
Authoritative
Mutable
Operational
User-maintained
```

---

## Reference Layer

Represents externally sourced plant knowledge.

### Examples

```text
plant_reference_raw
plant_reference_uses
plant_reference_use_terms
plant_reference_safety
plant_reference_parts
plant_reference_view
```

Characteristics:

```text
Derived
Enriched
Traceable
Rebuildable
```

---

# 5. Source Architecture

## GBIF

### Responsibility

```text
Scientific Names
Taxonomy
Taxonomic Relationships
Species Backbone
```

### Not Responsible For

```text
Common names
Uses
Medicinal information
```

---

## USDA

### Responsibility

```text
English common names
Name enrichment
```

### Not Responsible For

```text
Uses
Medicinal information
```

---

## Wikipedia

### Responsibility

```text
General plant-use information
Narrative enrichment
```

### Strengths

```text
Broad coverage
Simple access
Extensive content
```

---

## PFAF

### Responsibility

```text
Edible Uses
Medicinal Uses
Utility Uses
Safety Information
Plant Parts
```

### Strengths

```text
Ethnobotanical depth
Medicinal actions
Edible plant information
Utility uses
```

---

# 6. PFAF Pipeline Architecture

---

## Stage 20

### Script

```text
20_enrich_pfaf.R
```

### Purpose

Extract raw PFAF source content.

### Output

```text
plant_reference_raw
```

### Important Discovery

Known hazards are extracted from:

```text
Summary Table
```

not narrative content sections.

---

## Stage 21

### Script

```text
21_parse_pfaf_uses.R
```

### Purpose

Parse source narratives into structured records.

### Output

```text
plant_reference_uses
```

### Extracted Categories

```text
edible
medicinal
utility
hazard
```

---

## Stage 22

### Script

```text
22_extract_use_terms.R
```

### Purpose

Normalize controlled use vocabulary.

### Output

```text
plant_reference_use_terms
```

### Categories

```text
Medicinal Actions
Utility Uses
Edible Parts
```

---

## Stage 23

### Script

```text
23_normalize_safety.R
```

### Purpose

Normalize safety information.

### Output

```text
plant_reference_safety
```

### Categories

```text
toxicity
allergy
irritation
pregnancy
child risk
neurological
photosensitivity
usage restrictions
```

---

## Stage 24

### Script

```text
24_extract_plant_parts.R
```

### Purpose

Normalize plant-part references.

### Output

```text
plant_reference_parts
```

### Fields

```text
latin_name
plant_part
first_seen_use_type
source
```

---

## Stage 25

### Script

```text
25_create_reference_view.R
```

### Purpose

Create reporting-ready reference layer.

### Output

```text
plant_reference_view
```

### Consumer

```text
Power BI
Plant Cards
Reporting
```

---

# 7. Reference Table Specifications

---

## plant_reference_raw

### Purpose

Preserve source content.

### Source

```text
PFAF
```

### Characteristics

```text
Raw
Non-normalized
Rebuildable
```

### Key Fields

```text
latin_name
edible_uses
medicinal_uses
other_uses
hazards
cultivation
habitat
source_url
```

---

## plant_reference_uses

### Purpose

Parsed narratives.

### Key Fields

```text
latin_name
use_type
use_subtype
use_term
plant_part
description
```

---

## plant_reference_use_terms

### Purpose

Controlled vocabulary facts.

### Key Fields

```text
latin_name
use_type
use_term
source_description
```

---

## plant_reference_safety

### Purpose

Normalized safety facts.

### Key Fields

```text
latin_name
safety_type
safety_term
source_description
source
```

---

## plant_reference_parts

### Purpose

Normalized plant-part references.

### Key Fields

```text
latin_name
plant_part
first_seen_use_type
source
```

---

## plant_reference_view

### Purpose

Reporting layer.

### Key Fields

```text
latin_name
edible_parts
medicinal_actions
utility_uses
safety_flags
hazard_count
part_count
```

---

# 8. Controlled Vocabularies

## Plant Parts

```text
leaf
flower
fruit
seed
root
rhizome
stem
shoot
young shoot
bulb
tuber
bark
sap
nut
kernel
whole plant
```

---

## Medicinal Actions

```text
alterative
analgesic
anodyne
anthelmintic
antibacterial
antifungal
anti-inflammatory
antirheumatic
antiseptic
aperient
astringent
carminative
cholagogue
demulcent
depurative
diaphoretic
digestive
diuretic
emetic
emmenagogue
expectorant
febrifuge
haemostatic
laxative
refrigerant
sedative
stimulant
tonic
vulnerary
```

---

## Utility Uses

```text
dye
fuel
fibre
tannin
repellent
wildlife support
mulch
compost
shelterbelt
erosion control
green manure
basketry
adhesive
fungicide
veneer
carving
hedging
```

---

## Safety Terms

```text
toxic
poisonous
allergenic
skin irritant
pregnancy risk
child risk
deadly
photosensitive
narcotic
hallucinogenic
internal use
external use
```

---

# 9. Power BI Architecture

## Primary Reporting Source

```text
plant_reference_view
```

---

## Supporting Tables

```text
plant_reference_use_terms
plant_reference_safety
plant_reference_parts
```

---

## Example Measures

### Medicinal Action Count

```text
Count medicinal actions per plant
```

### Utility Use Count

```text
Count utility uses per plant
```

### Hazard Count

```text
Count safety records per plant
```

### Part Count

```text
Count plant parts per plant
```

---

# 10. Coding Standards

## Preferred Practices

```text
Verbose comments
Section headers
Single responsibility functions
Defensive validation
Logging
Deterministic processing
```

---

## Preferred Structure

```text
CONFIG

CONNECT

VALIDATE INPUT

HELPERS

PROCESSING

QA

SAVE

CLEANUP
```

---

# 11. Current Best Practices

1. Inspect before coding.
2. Profile before normalizing.
3. Never overwrite raw data.
4. Preserve source lineage.
5. Validate each stage independently.
6. Keep operational and reference data separate.
7. Normalize only after observing real data.
8. Favor deterministic logic.
9. Build pipelines incrementally.
10. Maintain controlled vocabularies centrally.

---

# 12. Future Roadmap

## Near Term

```text
Plant Cards
Reference Dashboards
Power BI Optimization
```

---

## Medium Term

```text
Harvest Intelligence
Harvest Forecasting