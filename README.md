# Protein Completeness Analysis: USDA Food Data

SQL analysis of protein quality in the USDA SR Legacy food database, built to
answer a practical question: which foods actually deliver usable protein,
which ones fall short due to amino acid limitations, and how do you fix a
shortfall by pairing foods?

## The story

Grams of protein on a label don't tell the whole story. Protein synthesis
requires all nine essential amino acids in roughly the right proportions; a
food low in even one of them caps how much of its total protein the body can
actually use. This project:

1. Scores every food's amino acid completeness against the WHO/FAO/UNU
   adult reference pattern
2. Identifies which amino acid is the limiting factor for foods I eat
   regularly (egg, whey, oats, pasta, chicken breast, rice)
3. Quantifies the shortfall: e.g. 100g of uncooked pasta has 13.04g of
   protein, but only 50% of it is usable as a complete protein due to a
   lack of lysine.
4. Finds a real-world fix by searching for foods that supply enough of
   the missing amino acid to make the deficient food's protein fully
   usable. Using the above example, pasta requires approx. 289mg of
   lysine to make all 13g of its protein complete. A small amount of
   edamame, soy beans, or red peppers can be added to pasta to fill the
   gap.
5. Applies the same fix-finding approach a second and third time: peanut
   butter's lysine shortfall is closed by greek yogurt, and yogurt's own
   shortfall — limited by both tryptophan and histidine at once — is
   closed in turn by almonds or a cracker/bread product.

The result: a practical, personal answer to "how do I make sure I'm getting
complete protein from what I actually eat," backed by USDA data rather than
generic nutrition advice.

## Key findings

## Key findings

- **Oats**: 92.2% usable protein, limited by a 59.1mg lysine shortfall
- **Rice**: 80.3% usable protein, limited by a 60.5mg lysine shortfall
- **Uncooked pasta**: 50.8% usable protein, limited by a 288.8mg lysine shortfall — 50g prepared edamame (372.5mg lysine) closes the gap, bringing pasta to 100% usable protein. The same fix can be used for rice
- **Peanut butter**: 68.1% usable protein, limited by a 314.8mg lysine shortfall — greek yogurt (≥390mg lysine per 100g) closes the gap at realistic serving sizes
- **Greek yogurt**: limited by both tryptophan and histidine simultaneously — almonds, crackers, or bread close both shortfalls at once

## Data source

USDA FoodData Central, SR Legacy dataset —
https://fdc.nal.usda.gov/download-datasets.html

## Repository structure

```
protein-analysis/
├── README.md
├── METHODOLOGY.md          -- scoring formulas, reference pattern, limitations
├── DATA_SCHEMA.md          -- table/view definitions and relationships
├── sql/
│   ├── 01_create_schema.sql
│   ├── 02_create_tables.sql
│   ├── 03_load_data.sql
│   ├── 04_build_food_protein_calorie_table.sql
│   ├── 05_create_views.sql
│   ├── 06_protein_per_100_cal.sql
│   ├── 07_protein_outliers.sql
│   ├── 08_protein_quartiles.sql
│   ├── 09_protein_serving.sql
│   ├── 10_amino_scores.sql
│   ├── 11_amino_acid_primary_bottleneck.sql
│   ├── 12_pasta_fix.sql
│   ├── 13_pb_fix.sql
│   └── 14_yogurt_fix.sql
├── exports/                -- category-filtered versions used to generate results/
│   ├── 06_protein_per_100_cal_export.sql
│   └── 10_amino_scores_export.sql
└── results/
    ├── protein_per_100kcal.csv
    ├── protein_outliers.csv
    ├── amino_scores.csv
    ├── primary_bottleneck.csv
    ├── pasta_fix.csv
    ├── pb_fix.csv
    └── yogurt_fix.csv
├── presentation/
│   └── fixing_the_protein_gap.pdf    
```

## SQL techniques demonstrated

- **CTEs** — multi-step transformations (raw nutrient pivot → amino acid
  ratios → limiting amino acid → usable protein) built as readable,
  named stages rather than nested subqueries
- **Window functions** — `DENSE_RANK()`, `NTILE()`, `ROW_NUMBER()`,
  and `AVG()`/`STDDEV()` with `PARTITION BY`, used for ranking, quartile
  bucketing, per-category outlier detection, and per-food amino acid
  ranking without collapsing rows
- **Views** — shared pivot/scoring logic (`v_protein_density`,
  `v_aa_pivot`, `v_aa_ratios`) factored out of what was originally
  duplicated CTE logic across multiple scripts
- **Joins** — staging-table joins to build the derived nutrition table,
  and fan-out joins (e.g. food-to-portion) used deliberately to compare
  across real-world serving sizes
- **Pivoting / unpivoting** — `MAX(CASE WHEN...)` conditional aggregation
  to reshape long/narrow nutrient data into columns, and the reverse
  (`UNION ALL`) to rank amino acids as rows within each food
- **External reference data** — WHO/FAO/UNU (2007) amino acid
  requirements incorporated as scoring constants, not sourced from the
  USDA data itself

## How to run

1. Download the USDA SR Legacy CSVs and update the file paths in
   `sql/03_load_data.sql` to point to your local copy
2. Run scripts `01` through `05` in order to build the schema, load raw
   data, build the derived table, and create the views
3. Run `06` through `14` for the analysis (or the versions in `exports/`
   to reproduce the CSVs in `results/`)

## Presentation

A non-technical walkthrough of the findings: [presentation/fixing_the_protein_gap.pdf](presentation/fixing_the_protein_gap.pdf)   

## Limitations

See `METHODOLOGY.md` for the full list. The short version: this is an
amino acid score, not a digestibility-corrected score (PDCAAS/DIAAS) —
real usable protein is likely somewhat lower than what's reported here,
especially for plant sources.

## About this project

Built as a personal tool to plan meals around complete protein intake.
