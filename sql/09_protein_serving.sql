-- Converts protein-per-100g into protein-per-serving using real-world
-- portion sizes (e.g. "1 cup cooked") instead of a flat 100g reference.
-- food_name, food_category, and protein_g_per_100g come from
-- v_protein_density (05_create_views.sql); no window-function output
-- from that view is used here.
--
-- JOIN: v_protein_density to food_portion on fdc_id. Fans out -- a food
-- with multiple listed portions returns one row per portion, which is
-- intentional: the point is to compare protein across every listed
-- serving size.

SELECT
p.food_name,
p.food_category,
CONCAT(CAST(f.amount AS CHAR), ' ', f.modifier) AS portion_description,
f.gram_weight as grams_per_portion,
ROUND((p.protein_g_per_100g * f.gram_weight / 100),2) as protein_per_portion,
p.protein_g_per_100g
FROM v_protein_density as p
JOIN food_portion as f
ON p.fdc_id = f.fdc_id
ORDER BY protein_per_portion desc
