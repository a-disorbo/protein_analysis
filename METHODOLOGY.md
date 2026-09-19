# Methodology

## Data source

USDA FoodData Central, SR Legacy dataset. Four CSVs are loaded into staging
tables that mirror the USDA export schema 1:1:

| File | Table | Role |
|---|---|---|
| `food.csv` | `food` | One row per food item (`fdc_id`, description, category) |
| `food_category.csv` | `food_category` | Category lookup |
| `food_nutrient.csv` | `food_nutrient` | Long/narrow: one row per (food, nutrient) pair |
| `food_portion.csv` | `food_portion` | Serving-size to gram-weight conversions |

`food_portion.csv` carries more columns than the analysis needs; unused fields
are read into throwaway session variables at load time so the row still parses.

## Reshaping the nutrient data

`food_nutrient` is long/narrow — every nutrient value for every food is its own
row, identified by `nutrient_id`. Nearly all analysis here requires the opposite
shape, so the project pivots with conditional aggregation
(`MAX(CASE WHEN nutrient_id = ... THEN amount END)`), grouped by `fdc_id`.

This pivot is defined once, as the view `v_aa_pivot` (`05_create_views.sql`),
rather than repeated per script. `10`, `11`, and `12` all read from it.

Nutrient codes used:

| Code | Nutrient | | Code | Nutrient |
|---|---|---|---|---|
| 1003 | Protein | | 1214 | Lysine |
| 1008 | Energy (kcal) | | 1215 | Methionine |
| 1210 | Tryptophan | | 1216 | Cystine |
| 1211 | Threonine | | 1217 | Phenylalanine |
| 1212 | Isoleucine | | 1218 | Tyrosine |
| 1213 | Leucine | | 1219 | Valine |
| | | | 1221 | Histidine |

Amino acid amounts are published in grams and converted to milligrams (×1000) to
match the units of the scoring pattern below.

One script (`11_amino_acid_primary_bottleneck.sql`) runs the reverse operation —
unpivoting the nine ratio columns back into rows via `UNION ALL` — so that each
amino acid can be ranked as its own record within a food.

## Protein density

Two normalizations are computed, because they answer different questions:

- **Per 100 g** — taken directly from the USDA value. Answers "how protein-dense
  is this food by weight."
- **Per 100 kcal** — derived as `10000 / calories_per_100g` to get the grams of
  food equal to 100 kcal, then multiplied by protein content. Answers "how much
  protein does this food deliver for its calories," which is the more relevant
  question when total intake is calorie-bounded.

`NULLIF(calories_per_100g, 0)` guards against division by zero for
zero-calorie entries.

Both figures are computed once in the view `v_protein_density`
(`05_create_views.sql`); scripts `05`–`08` read from it rather than recomputing
the derivation locally.

## Amino acid scoring

Scoring uses the **WHO/FAO/UNU (2007)** adult essential amino acid requirement
pattern, expressed as mg of amino acid per gram of protein:

| Amino acid | Requirement (mg/g protein) |
|---|---|
| Histidine | 15 |
| Isoleucine | 30 |
| Leucine | 59 |
| Lysine | 45 |
| Methionine + cystine | 22 |
| Phenylalanine + tyrosine | 38 |
| Threonine | 23 |
| Tryptophan | 6 |
| Valine | 39 |

Methionine/cystine and phenylalanine/tyrosine are scored as pairs, per the
reference pattern, because cystine spares methionine and tyrosine spares
phenylalanine.

For each food and each amino acid:

```
ratio = (amino_acid_mg / protein_g) / requirement_mg_per_g
```

A ratio of 1.0 means the food's protein meets the reference requirement for that
amino acid. Below 1.0 means it falls short.

**Limiting amino acid** = the amino acid with the lowest ratio. Because protein
synthesis requires all essential amino acids simultaneously, the one in shortest
supply caps how much of the food's total protein can be used to build new
protein.

```
usable_fraction   = LEAST(limiting_ratio, 1.0)
usable_protein_g  = protein_g × usable_fraction
```

The cap at 1.0 matters: a ratio above 1.0 does not earn extra credit. A surplus
of one amino acid cannot substitute for a shortfall in another. For example, a
food that has a surplus leucine and a shortfall of lysine cannot convert excess
leucine into lysine.

`11_amino_acid_primary_bottleneck.sql` extends this by ranking all nine amino
acids per food (`ROW_NUMBER() OVER (PARTITION BY fdc_id ORDER BY ratio_value)`)
rather than reporting only the single worst, and computes two further values:

- `mg_needed_to_complete` — the milligrams of the bottleneck amino acid required
  to raise its ratio to 1.0, scaled by the food's protein content.
- `if_primary_fixed_g` — usable protein if the primary bottleneck were resolved
  and the second-ranked amino acid became the new constraint. A correlated
  subquery retrieves the rank-2 ratio for the same food.

## Complementary pairing

`12_pasta_fix.sql` inverts the question. Having established that pasta protein is
lysine-limited, it searches the dataset for foods whose lysine content is high
enough to close that gap in a realistic portion — filtering vegetable-category
foods at ≥600 mg lysine per 100 g.

The nutritional basis: digestion reduces dietary protein to free amino acids and
short peptides, which enter a common circulating pool. Amino acids are drawn from
that pool for synthesis without regard to which food they originated from, so a
lysine-rich food consumed alongside a lysine-limited one raises the lysine
available for synthesis overall.

**Peanut butter fix.** `13_pb_fix.sql` applies the same approach to a
lysine-limited food identified in `11`'s output: peanut butter, with a primary
lysine bottleneck of 314.8 mg per 100 g. Greek yogurt was identified as a
candidate pairing and confirmed against the dataset by filtering
`food_name LIKE '%Yogurt%'` at ≥350 mg lysine per 100 g. The threshold reflects
a realistic ~20 g peanut butter serving rather than the 100 g basis of the
reported deficit: at 20 g, the actual shortfall scales to roughly
314.8 × 0.20 ≈ 63 mg, which the 350 mg/100 g threshold covers well within a
modest yogurt portion.

**Yogurt fix.** Checking yogurt's own amino acid profile in `11`'s output
showed it is not limited by a single amino acid — it is constrained by both
tryptophan and histidine, ranked first and second. `14_yogurt_fix.sql`
searches for foods clearing both thresholds simultaneously (≥35 mg tryptophan
and ≥25 mg histidine per 100 g) across cereal grains, baked products, and
nuts, joined with `OR` inside parentheses so both amino acid conditions apply
across all three categories.

## Statistical methods

- **`DENSE_RANK()`** — ranks foods by protein per 100 kcal; ties share a rank
  with no gap in the sequence.
- **`AVG()` / `STDDEV()` over `PARTITION BY food_category`** — computes a
  per-category mean and standard deviation while preserving one row per food, so
  each food sits next to its own category's benchmark. `GROUP BY` would collapse
  this.
- **Z-scores** — `(value − category_mean) / category_stddev`, filtered at
  `ABS(z) > 2` to flag foods that are unusual *relative to their own category*
  rather than relative to the dataset as a whole.
- **`NTILE(4)` over `PARTITION BY food_category`** — assigns within-category
  quartiles separately for the per-100 g and per-100 kcal measures, so a food's
  standing can be compared across both bases.

## Limitations

These are modeling choices and data constraints, stated plainly:

1. **No digestibility correction is applied.** This is an amino acid score, not
   PDCAAS or DIAAS. Both of those multiply the amino acid score by a measured
   digestibility factor, which the USDA dataset does not supply. Real usable
   protein will generally be somewhat *lower* than reported here, and the gap is
   wider for plant sources than animal sources. The `usable_protein_g` column
   should be read as an upper bound under ideal digestion.

2. **"Usable protein" is a simplification.** The limiting-amino-acid model treats
   a single food in isolation. Actual utilization depends on total amino acid
   intake across a day and on non-protein factors (energy intake, training
   stimulus, individual requirement). The single-food figures are a comparison
   tool, not a prediction of what any individual will synthesize.

3. **The reference pattern is for adults generally.** WHO/FAO/UNU requirements
   are not adjusted for athletic populations, who may have elevated needs. No
   leucine threshold for maximal synthetic response is modeled; leucine is
   carried through the queries as a raw milligram value for reference only.

4. **Foods lacking amino acid data are excluded.** The pivot requires both
   protein and leucine to be present, dropping any food without a complete
   enough profile to score. Coverage is therefore uneven across categories.

5. **Inner joins drop rows silently.** Foods without a matching category, or
   without nutrient rows, do not appear in `food_protein_calories`. This is
   intentional but means the analyzed set is smaller than the raw dataset.

6. **Z-scores are unstable for small categories.** A category containing a
   handful of foods produces a standard deviation estimate that is not
   meaningful. Outliers from sparse categories deserve less weight than those
   from well-populated ones.

8. **Limiting amino acid ranking assumes ties are resolved deterministically.**
   `11_amino_acid_primary_bottleneck.sql` breaks ties in `ROW_NUMBER()` with a
   secondary sort on amino acid name (`ORDER BY ratio_value ASC, amino_acid ASC`),
   so an exact tie between two amino acids resolves the same way every run
   rather than depending on row-processing order. An exact tie is unlikely given
   that ratios are computed from measured, non-round USDA values, but the
   secondary sort costs nothing and makes output reproducible.
