-- Buckets foods into quartiles by protein content, separately for
-- per-100g and per-100kcal measures, so a food's ranking can be compared
-- across both bases within its own category. Reads density figures from
-- v_protein_density (05_create_views.sql) instead of recomputing them.
--
-- Window functions:
--   AVG(...) OVER (PARTITION BY food_category) -- category benchmark, kept per row
--   NTILE(4) OVER (PARTITION BY food_category ORDER BY ...) -- splits each
--     category into 4 equal-sized groups by the ORDER BY column;
--     quartile 4 = top 25% of that category for that metric.
--
-- Caveat: a food_category with fewer than 4 foods produces sparse or
-- degenerate quartiles (e.g. every row lands in quartile 1) -- check
-- category sizes before treating quartile labels as meaningful.

WITH avg_protein AS (
SELECT
fdc_id,
food_name,
food_category,
protein_g_per_100g,
calories_per_100g,
grams_food_per_100kcal,
protein_per_100kcal,
AVG(protein_g_per_100g) OVER (PARTITION BY food_category) as category_avg_per_100g,
AVG(protein_per_100kcal) OVER (PARTITION BY food_category) as category_avg_per_100kcal
FROM v_protein_density)

SELECT
food_name,
food_category,
protein_g_per_100g,
category_avg_per_100g,
calories_per_100g,
protein_per_100kcal,
category_avg_per_100kcal,
NTILE(4) OVER (PARTITION BY food_category ORDER BY protein_g_per_100g) AS protein_100g_quartile,
NTILE(4) OVER (PARTITION BY food_category ORDER BY protein_per_100kcal) AS protein_100kcal_quartile
FROM avg_protein
ORDER BY protein_per_100kcal DESC, food_category;
