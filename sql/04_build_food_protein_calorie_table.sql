-- Builds food_protein_calories from the long/narrow food_nutrient table.
--
-- Technique: conditional aggregation (MAX(CASE WHEN nutrient_id = ... )).
-- food_nutrient has one row per (food, nutrient); this pivots the two
-- nutrients of interest (protein = 1003, calories = 1008) into their own
-- columns, one row per food.
--
-- JOIN behavior: both joins are INNER JOINs, so:
--   - a food with no matching food_category row is dropped
--   - a food with no rows in food_nutrient at all is dropped
--   - the HAVING clause additionally drops any food where protein (1003)
--     was never recorded, even if it had other nutrient rows
INSERT INTO food_protein_calories (fdc_id, food_name, food_category, protein_g_per_100g, calories_per_100g)
SELECT
    f.fdc_id,
    f.description,
    c.description,
    MAX(CASE WHEN n.nutrient_id = 1003 THEN n.amount END) AS protein_g_per_100g,
    MAX(CASE WHEN n.nutrient_id = 1008 THEN n.amount END) AS calories_per_100g
FROM food f
JOIN food_category c ON f.food_category_id = c.id
JOIN food_nutrient n ON f.fdc_id = n.fdc_id
WHERE n.nutrient_id IN (1003, 1008)
GROUP BY f.fdc_id, f.description, c.description
HAVING MAX(CASE WHEN n.nutrient_id = 1003 THEN n.amount END) IS NOT NULL;
