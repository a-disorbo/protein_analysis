-- Given that pasta's protein is lysine-limited (see
-- 11_amino_acid_primary_bottleneck.sql), search vegetable-category foods
-- for lysine-rich candidates that could pair with pasta to make its
-- protein fully usable (protein complementarity in practice).
--
-- lysine_mg comes from v_aa_pivot (05_create_views.sql) rather than a
-- locally-recomputed pivot.
--
-- 600mg/100g threshold: chosen as a level high enough that a modest,
-- realistic portion (e.g. ~50g) would supply enough lysine to close a
-- typical pasta-serving deficit.

SELECT
fpc.food_name,
fpc.food_category,
a.lysine_mg
FROM v_aa_pivot a
JOIN food_protein_calories fpc
ON a.fdc_id = fpc.fdc_id
WHERE fpc.food_category LIKE '%vegetable%'
AND a.lysine_mg >= 600
