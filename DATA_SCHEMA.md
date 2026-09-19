# Data Schema

Three layers: raw USDA staging tables loaded verbatim from the SR Legacy CSV
export, one derived table built from them, and a set of views that centralize
logic previously duplicated as CTEs across the analysis scripts.

```
  RAW (USDA SR Legacy export)      DERIVED              VIEWS (05_create_views.sql)
  ───────────────────────────      ───────              ───────────────────────────

  food_category
       │ id
       │
       ▼ food_category_id
  food ──────────── fdc_id ──► food_protein_calories ──► v_protein_density
       │                            (built in 04)             used by 06, 07, 08, 09
       │ fdc_id
       ├──────────► food_nutrient ──────────────────────► v_aa_pivot
       │                                                       used by 12, 13, 14
       │                                                       │
       │                                                       ▼
       │                                                  v_aa_ratios
       │                                                       used by 10, 11
       │
       └──────────► food_portion
                         │
                         └── joined in 08
```

`v_aa_ratios` is built on top of `v_aa_pivot`, not on the raw tables directly —
querying `v_aa_ratios` alone returns everything both views produce.

`fdc_id` is the join key throughout. Foreign keys are **not** enforced on the
staging tables — the USDA CSVs are loaded in bulk and treated as trusted input.
Relationships below marked "logical" exist in the data but are not declared as
constraints.

---

## Raw staging tables

### `food`

One row per food item. The master record.

| Column | Type | Notes |
|---|---|---|
| `fdc_id` | INT | **PK.** USDA FoodData Central identifier |
| `data_type` | VARCHAR(50) | Dataset of origin, e.g. `sr_legacy_food` |
| `description` | VARCHAR(500) | Food name as published by USDA |
| `food_category_id` | INT | Logical FK → `food_category.id` |
| `publication_date` | DATE | USDA publication date |

USDA descriptions are long and comma-heavy (e.g. `Chicken, broiler or fryers,
breast, skinless, boneless, meat only, raw`). Exact-match filtering on
`description` requires the full string; this is why the analysis scripts use
`LIKE` with complete names rather than short keywords.

### `food_category`

Category lookup.

| Column | Type | Notes |
|---|---|---|
| `id` | INT | **PK.** Referenced by `food.food_category_id` |
| `code` | VARCHAR(10) | USDA category code |
| `description` | VARCHAR(255) | e.g. `Legumes and Legume Products` |

Category names are matched with `LIKE '%vegetable%'` in `12_pasta_fix.sql`
rather than by `id`, since the relevant categories aren't known in advance.
`14_yogurt_fix.sql` matches three categories the same way
(`'%Cereal Grains%'`, `'%Baked Products%'`, `'%Nut%'`), combined with `OR`
inside parentheses so the amino acid thresholds apply across all three.
`13_pb_fix.sql` matches on `food_name LIKE '%Yogurt%'` instead of category.

### `food_nutrient`

**Long/narrow format** — one row per (food, nutrient) pair, not one column per
nutrient. This is the single most important structural fact about the dataset: a
food with 30 recorded nutrients occupies 30 rows here. Every analysis script that
needs multiple nutrients side by side must pivot this table.

| Column | Type | Notes |
|---|---|---|
| `id` | INT | **PK** |
| `fdc_id` | INT | Logical FK → `food.fdc_id` |
| `nutrient_id` | INT | USDA nutrient code — see table below |
| `amount` | DECIMAL(10,3) | Value per 100 g. **Units vary by `nutrient_id`** |
| `derivation_id` | INT | How the value was obtained (measured vs. calculated) |

Nutrient codes used in this project:

| Code | Nutrient | Unit in source |
|---|---|---|
| 1003 | Protein | g |
| 1008 | Energy | kcal |
| 1210 | Tryptophan | g |
| 1211 | Threonine | g |
| 1212 | Isoleucine | g |
| 1213 | Leucine | g |
| 1214 | Lysine | g |
| 1215 | Methionine | g |
| 1216 | Cystine | g |
| 1217 | Phenylalanine | g |
| 1218 | Tyrosine | g |
| 1219 | Valine | g |
| 1221 | Histidine | g |

Amino acids are stored in grams and converted to milligrams (`* 1000`) in the
pivot CTEs, to match the units of the WHO/FAO/UNU reference pattern.

**Pivot pattern**, used in `04`, `10`, `11`, `12`, `13`, `14`:

```sql
MAX(CASE WHEN nutrient_id = 1003 THEN amount END) AS protein_g
```

`MAX` is an aggregate chosen for convenience — each `(fdc_id, nutrient_id)` pair
is expected to be unique, so `MAX` simply extracts the one non-null value per
group and collapses the rest to a single row.

### `food_portion`

Serving-size conversions. Enables per-serving figures instead of per-100 g.

| Column | Type | Notes |
|---|---|---|
| `id` | INT | **PK** |
| `fdc_id` | INT | Logical FK → `food.fdc_id` |
| `seq_num` | INT | Ordering when a food lists several portions |
| `amount` | DECIMAL(10,3) | Numeric part of the portion, e.g. `1` in "1 cup" |
| `portion_description` | VARCHAR(255) | e.g. `cup` |
| `modifier` | VARCHAR(255) | e.g. `cooked` |
| `gram_weight` | DECIMAL(10,2) | Grams for that portion |

**Cardinality:** one food may have many portions, so joining this table fans out
row counts. Intentional in `09_protein_serving.sql` — the goal there is to see
protein across every listed serving size — but it means output there is not
one-row-per-food.

The source CSV carries additional columns (measure unit id, data points,
footnote, min year acquired) that the table doesn't declare. These are read into
throwaway session variables at load time so each row still parses.

---

## Derived table

### `food_protein_calories`

Built by `04_build_food_protein_calorie_table.sql`. Flattens the pivot of protein
and calories into one row per food, with the category name resolved. This is the
table every analysis script joins against for human-readable names.

| Column | Type | Notes |
|---|---|---|
| `food_id` | INT | **PK**, auto-increment surrogate |
| `fdc_id` | INT | **UNIQUE.** Join key to all raw tables |
| `food_name` | VARCHAR(255) | From `food.description` |
| `food_category` | VARCHAR(120) | Resolved from `food_category.description` |
| `protein_g_per_100g` | DECIMAL(6,2) | `NOT NULL` — nutrient 1003 |
| `calories_per_100g` | DECIMAL(6,2) | Nullable — nutrient 1008 |

**The unique constraint on `fdc_id` is what makes this table safe to join
against.** Without it, a duplicate load would silently multiply rows in every
downstream query.

**Rows excluded by construction:**

- Foods with no matching `food_category` row (inner join)
- Foods with no rows in `food_nutrient` at all (inner join)
- Foods where protein (1003) was never recorded (`HAVING ... IS NOT NULL`)

Calories are allowed to be null; protein is not. A food without a protein value
has nothing to contribute to this project.

**Why a separate table rather than a view:** the pivot runs over the full
`food_nutrient` table, which is the largest input. Materializing it once means
every downstream script joins against a small, indexed table instead of
re-scanning the raw nutrient rows.

---

## Views

Defined in `05_create_views.sql`, run once after `04_build_food_protein_calorie_table.sql`.
These replace CTE chains that were originally duplicated verbatim across
multiple analysis scripts.

### `v_protein_density`

Replaces the two-step `g_100kcal` / `protein_100kcal` CTE chain previously
repeated in `06`, `07`, `08`, and `09`.

| Column | Notes |
|---|---|
| `fdc_id`, `food_name`, `food_category`, `protein_g_per_100g`, `calories_per_100g` | Passed through from `food_protein_calories` |
| `grams_food_per_100kcal` | `10000.0 / NULLIF(calories_per_100g, 0)` |
| `protein_per_100kcal` | `protein_g_per_100g * grams_food_per_100kcal / 100.0` |

### `v_aa_pivot`

Replaces the `aa_pivot` CTE previously duplicated in `10`, `11`, and `12`. Same
pivot and `HAVING` filter described under **Reshaping the nutrient data** above,
now defined once.

Used directly by `12_pasta_fix.sql`, `13_pb_fix.sql`, and `14_yogurt_fix.sql`,
each of which needs raw amino acid mg values and no ratios: `12` and `13` filter
on `lysine_mg`, `14` filters on both `tryptophan_mg` and `histidine_mg`
simultaneously (yogurt, unlike pasta or peanut butter, has two limiting amino
acids at once — see `11`'s ranked output for that food).

### `v_aa_ratios`

Built on top of `v_aa_pivot`. Replaces the `aa_ratios` CTE previously duplicated
in `10` and `11`.

**Column set note:** script `10`'s original CTE dropped every raw `*_mg` column
except `leucine_mg`, since `10` only needed the ratios. Script `11`'s original
CTE kept all of them, because it later reports each amino acid's raw mg value
alongside its ratio. The shared view keeps the fuller column set — the one `11`
needs — since `10` can simply select fewer columns from it; the reverse (basing
the view on `10`'s slimmer CTE) would have forced `11` to join back to
`v_aa_pivot` a second time just to recover the mg values.

| Column | Notes |
|---|---|
| `fdc_id`, `protein_g` | From `v_aa_pivot` |
| `histidine_mg` … `valine_mg` (9 columns) | Raw amino acid mg, passed through |
| `ratio_histidine` … `ratio_valine` (9 columns) | Each amino acid's mg-per-g-protein divided by its WHO/FAO/UNU requirement |

Scripts `10` and `11` now start their `WITH` clause at the CTE that consumes
these ratios (`aa_limiting` in `10`; the `UNION ALL` unpivot in `11`) rather than
recomputing the pivot and ratios locally.
