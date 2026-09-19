-- Ranks foods by protein density per 100 kcal (rather than per 100g),
-- which better answers "which food gets me the most protein for the
-- calories" than a raw g-per-100g comparison does.
--
-- Density figures (grams_food_per_100kcal, protein_per_100kcal) come from
-- v_protein_density (05_create_views.sql) rather than being recomputed here.
-- Window function: DENSE_RANK() orders every food by that value, with
-- ties sharing a rank and no gaps in the rank sequence.

SELECT
food_name,
food_category,
protein_per_100kcal,
DENSE_RANK() OVER (ORDER BY protein_per_100kcal DESC) AS protein_rank
FROM v_protein_density
ORDER BY protein_per_100kcal DESC;
