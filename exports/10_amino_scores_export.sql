-- Export version of 10_amino_scores.sql, trimmed to a consistent
-- set of categories (meats, seafood, grains, legumes, vegetables) used
-- across this portfolio's result exports.
--

WITH aa_limiting AS (
    SELECT
        fdc_id,
        protein_g,
        leucine_mg,
        LEAST(ratio_histidine, ratio_isoleucine, ratio_leucine, ratio_lysine,
              ratio_methionine_cystine, ratio_phenylalanine_tyrosine,
              ratio_threonine, ratio_tryptophan, ratio_valine) AS limiting_ratio
    FROM v_aa_ratios
),
usable_protein AS (
    SELECT
        fdc_id,
        protein_g,
        limiting_ratio,
        LEAST(limiting_ratio, 1.0) AS usable_fraction,
        protein_g * LEAST(limiting_ratio, 1.0) AS usable_protein_g
    FROM aa_limiting
)
SELECT
    fpc.food_name,
    fpc.food_category,
    u.protein_g AS labeled_protein_g_per_100g,
    ROUND(u.limiting_ratio, 3) AS limiting_ratio,
    ROUND(u.usable_fraction * 100, 1) AS usable_pct,
    ROUND(u.usable_protein_g, 2) AS true_usable_protein_g
FROM usable_protein u
JOIN food_protein_calories fpc ON u.fdc_id = fpc.fdc_id
WHERE
       fpc.food_category LIKE '%Beef%'
    OR fpc.food_category LIKE '%Pork%'
    OR fpc.food_category LIKE '%Poultry%'
    OR fpc.food_category LIKE '%Lamb%'
    OR fpc.food_category LIKE '%Finfish%'
    OR fpc.food_category LIKE '%Shellfish%'
    OR fpc.food_category LIKE '%Seafood%'
    OR fpc.food_category LIKE '%Cereal Grains%'
    OR fpc.food_category LIKE '%Legumes%'
    OR fpc.food_category LIKE '%Vegetables%'
ORDER BY fpc.food_category, u.protein_g DESC;