-- Export version of 06_protein_per_100_cal.sql, trimmed to a consistent
-- set of categories (meats, seafood, grains, legumes, vegetables) used
-- across this portfolio's result exports.
--

SELECT
food_name,
food_category,
protein_per_100kcal,
DENSE_RANK() OVER (ORDER BY protein_per_100kcal DESC) AS protein_rank
FROM v_protein_density
WHERE
       food_category LIKE '%Beef%'
    OR food_category LIKE '%Pork%'
    OR food_category LIKE '%Poultry%'
    OR food_category LIKE '%Lamb%'
    OR food_category LIKE '%Finfish%'
    OR food_category LIKE '%Shellfish%'
    OR food_category LIKE '%Seafood%'
    OR food_category LIKE '%Cereal Grains%'
    OR food_category LIKE '%Legumes%'
    OR food_category LIKE '%Vegetables%'
ORDER BY protein_per_100kcal DESC;