-- Flags foods whose protein-per-100kcal is an outlier relative to other
-- foods in the same category (e.g. an unusually protein-dense vegetable).
-- Reads density figures from v_protein_density (05_create_views.sql)
-- instead of recomputing them.
--
-- Window functions: AVG(...) OVER (PARTITION BY food_category) and
-- STDDEV(...) OVER (PARTITION BY food_category) compute a per-category
-- mean/stddev without collapsing rows the way GROUP BY would -- every
-- food keeps its own row alongside its category's stats.
-- z_score = (value - category mean) / category stddev; |z| > 2 is the
-- standard "outlier" threshold (~top/bottom 2.5% under a normal
-- distribution).
--
-- Caveat: categories with very few foods produce unstable stddev
-- estimates, so a z-score from a 3-food category is less trustworthy
-- than one from a 50-food category.

WITH avg_and_stddev AS (
SELECT
fdc_id,
food_name,
food_category,
protein_g_per_100g,
calories_per_100g,
grams_food_per_100kcal,
protein_per_100kcal,
AVG(protein_per_100kcal) OVER (PARTITION BY food_category) as category_avg,
STDDEV(protein_per_100kcal) OVER (PARTITION BY food_category) as category_stddev
FROM v_protein_density),

z_scores AS (
SELECT
fdc_id,
food_name,
food_category,
protein_g_per_100g,
protein_per_100kcal,
category_avg,
category_stddev,
(protein_per_100kcal - category_avg) / NULLIF(category_stddev, 0) AS z_score_outliers
FROM avg_and_stddev)

SELECT
food_name,
food_category,
protein_g_per_100g,
protein_per_100kcal,
(protein_per_100kcal - category_avg) / NULLIF(category_stddev, 0) as z_score_outliers,
COUNT(*) OVER (PARTITION BY food_category) AS category_size
FROM z_scores
WHERE ABS(z_score_outliers) > 2
ORDER BY z_score_outliers DESC, protein_g_per_100g DESC;
