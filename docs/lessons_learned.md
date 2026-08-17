# Ker-Huella Lessons Learned v2 Master Edition

## Purpose

This document captures technical, architectural, and project-management lessons learned during the evolution of Ker-Huella.

The objective is not merely to record mistakes, but to preserve successful patterns, architectural decisions, and reasoning so future development remains consistent with established project principles.

---

# Part I – Foundational Engineering Lessons

## 1. Always Inspect Source Schema

Never assume a dataset's structure.

Always inspect:

```r
names(df)
```

and:

```sql
PRAGMA table_info(table_name)
```

before writing transformation logic.

### Why

Many early failures were caused by assumptions about:

- column names
- field types
- naming conventions

rather than actual business logic problems.

---

## 2. Do Not Assume Naming Standards

Different sources use different conventions.

Examples:

### GBIF

```text
scientificName
acceptedScientificName
taxonKey
```

### Ker-Huella

```text
latin_name
common_name_en
```

### Lesson

Inspect first. Normalize later.

Never assume a source follows your preferred convention.

---

## 3. Occurrence Data Is Not Entity Data

GBIF occurrence records are observations.

They are not plant entities.

Occurrence data contains:

```text
duplicates
taxonomic inconsistencies
missing values
observation bias
```

### Lesson

Transform occurrences into:

```text
unique plant entities
```

before building the plant model.

---

## 4. Debug By Simplifying First

When troubleshooting:

### Do

```text
remove fields
remove joins
reduce scope
build minimum working example
```

### Don't

```text
add additional complexity
```

A smaller reproducible failure is easier to diagnose.

---

## 5. Zero-Length Errors Usually Indicate Data Issues