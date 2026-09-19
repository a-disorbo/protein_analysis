-- Given that peanut butter's protein is lysine-limited (see
-- 11_amino_acid_primary_bottleneck.sql), search yogurts
-- for lysine-rich candidates that could pair with peanut butter to make its
-- protein fully usable (protein complementarity in practice).
--
-- lysine_mg comes from v_aa_pivot (05_create_views.sql) rather than a
-- locally-recomputed pivot.
--
-- 350mg per 100g threshold: chosen as a level high enough that a realistic
-- or even small portion (e.g. ~50 to 100g) would supply enough lysine to 
-- close a typical (20g) or even generous serving of peanut butter deficit.
-- 
-- 100g of peanut butter requires 314.8mg of lysine. A realistic PB serving 
-- is approximately 20g, so the actual lysine shortfall to close scales down 
-- proportionally: 314.8mg x 0.20 ~= 63mg.

SELECT
fpc.food_name,
fpc.food_category,
a.lysine_mg
FROM v_aa_pivot a
JOIN food_protein_calories fpc
ON a.fdc_id = fpc.fdc_id
WHERE fpc.food_name LIKE '%Yogurt%'
AND a.lysine_mg >= 350
