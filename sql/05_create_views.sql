-- Views replacing the CTE chains repeated across the analysis scripts.
-- Run once after 04_build_food_protein_calorie_table.sql.
--
--   v_protein_density  -> replaces the g_100kcal / protein_100kcal chain
--                         repeated in 06, 07, 08, 09
--   v_aa_pivot         -> replaces the aa_pivot CTE in 10, 11, 12
--   v_aa_ratios        -> replaces the aa_ratios CTE in 10, 11
--
-- v_aa_ratios is defined on top of v_aa_pivot, so the pivot logic exists
-- in exactly one place.


-- ---------------------------------------------------------------------
-- v_protein_density
-- ---------------------------------------------------------------------
-- Collapses two-step CTE chain into one view. The intermediate
-- grams_food_per_100kcal is kept as an output column rather than being
-- inlined, since 06-09 reference it and it documents the derivation.
--
-- NULLIF guards division by zero for zero-calorie entries; those rows
-- return NULL for both derived columns rather than erroring.

CREATE VIEW v_protein_density AS
SELECT
    fdc_id,
    food_name,
    food_category,
    protein_g_per_100g,
    calories_per_100g,
    (10000.0 / NULLIF(calories_per_100g, 0)) AS grams_food_per_100kcal,
    (protein_g_per_100g * (10000.0 / NULLIF(calories_per_100g, 0)) / 100.0)
        AS protein_per_100kcal
FROM food_protein_calories;


-- ---------------------------------------------------------------------
-- v_aa_pivot
-- ---------------------------------------------------------------------
-- Pivots the long/narrow food_nutrient table into one row per food with
-- protein and the nine essential amino acid groups as columns.
-- Amino acids are published in grams; * 1000 converts to mg to match the
-- WHO/FAO/UNU reference pattern used in v_aa_ratios.
--
-- HAVING drops foods without a scoreable profile: leucine must be
-- present, and protein must be > 0 (also prevents division by zero in
-- every ratio downstream).
--
-- Used directly by 12_pasta_fix.sql, which needs raw lysine_mg and no
-- ratios.

CREATE VIEW v_aa_pivot AS
SELECT
    fdc_id,
    MAX(CASE WHEN nutrient_id = 1003 THEN amount END) AS protein_g,
    MAX(CASE WHEN nutrient_id = 1221 THEN amount END) * 1000 AS histidine_mg,
    MAX(CASE WHEN nutrient_id = 1212 THEN amount END) * 1000 AS isoleucine_mg,
    MAX(CASE WHEN nutrient_id = 1213 THEN amount END) * 1000 AS leucine_mg,
    MAX(CASE WHEN nutrient_id = 1214 THEN amount END) * 1000 AS lysine_mg,
    MAX(CASE WHEN nutrient_id = 1215 THEN amount END) * 1000 AS methionine_mg,
    MAX(CASE WHEN nutrient_id = 1216 THEN amount END) * 1000 AS cystine_mg,
    MAX(CASE WHEN nutrient_id = 1217 THEN amount END) * 1000 AS phenylalanine_mg,
    MAX(CASE WHEN nutrient_id = 1218 THEN amount END) * 1000 AS tyrosine_mg,
    MAX(CASE WHEN nutrient_id = 1211 THEN amount END) * 1000 AS threonine_mg,
    MAX(CASE WHEN nutrient_id = 1210 THEN amount END) * 1000 AS tryptophan_mg,
    MAX(CASE WHEN nutrient_id = 1219 THEN amount END) * 1000 AS valine_mg
FROM food_nutrient
WHERE nutrient_id IN (1003,1210,1211,1212,1213,1214,1215,1216,1217,1218,1219,1221)
GROUP BY fdc_id
HAVING MAX(CASE WHEN nutrient_id = 1213 THEN amount END) IS NOT NULL
   AND MAX(CASE WHEN nutrient_id = 1003 THEN amount END) > 0;


-- ---------------------------------------------------------------------
-- v_aa_ratios
-- ---------------------------------------------------------------------
-- Scores each amino acid against the WHO/FAO/UNU (2007) adult reference
-- pattern (mg amino acid per g protein). ratio = 1.0 means the food's
-- protein exactly meets the requirement for that amino acid; below 1.0
-- means it falls short.
--
-- Methionine/cystine and phenylalanine/tyrosine are summed before
-- scoring, per the reference pattern.
--
-- NOTE ON COLUMN SET: this view carries the raw *_mg columns through
-- alongside the ratios. The original CTE in 10_amino_scores.sql dropped
-- them (it only needed protein_g and leucine_mg), but 11 unpivots
-- ratios *and* their corresponding mg values, so it needs both.
-- Carrying them here lets one view serve both scripts; 10 simply
-- selects fewer columns.

CREATE VIEW v_aa_ratios AS
SELECT
    fdc_id,
    protein_g,
    histidine_mg,
    isoleucine_mg,
    leucine_mg,
    lysine_mg,
    methionine_mg,
    cystine_mg,
    phenylalanine_mg,
    tyrosine_mg,
    threonine_mg,
    tryptophan_mg,
    valine_mg,
    (histidine_mg / protein_g) / 15.0                          AS ratio_histidine,
    (isoleucine_mg / protein_g) / 30.0                         AS ratio_isoleucine,
    (leucine_mg / protein_g) / 59.0                            AS ratio_leucine,
    (lysine_mg / protein_g) / 45.0                             AS ratio_lysine,
    ((methionine_mg + cystine_mg) / protein_g) / 22.0          AS ratio_methionine_cystine,
    ((phenylalanine_mg + tyrosine_mg) / protein_g) / 38.0      AS ratio_phenylalanine_tyrosine,
    (threonine_mg / protein_g) / 23.0                          AS ratio_threonine,
    (tryptophan_mg / protein_g) / 6.0                          AS ratio_tryptophan,
    (valine_mg / protein_g) / 39.0                             AS ratio_valine
FROM v_aa_pivot;
