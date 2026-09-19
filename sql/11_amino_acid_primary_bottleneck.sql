-- Extends the limiting-amino-acid logic from 10_amino_scores.sql to rank
-- ALL nine amino acids per food by how limiting each one is (not just
-- the single worst one), and estimates how much protein would become
-- usable if only the #1 bottleneck were fixed.
--
-- Ratios and raw mg values come from v_aa_ratios (05_create_views.sql).
--
-- aa_ranking: unpivots the nine ratio_* columns from v_aa_ratios into
--   rows (one row per food per amino acid) via UNION ALL -- the reverse
--   of the wide pivot done inside v_aa_pivot.
--   ROW_NUMBER() OVER (PARTITION BY fdc_id ORDER BY ratio_value ASC,
--   amino_acid ASC) ranks the 9 amino acids within each food from
--   most-limiting (rank 1) to least-limiting (rank 9). The secondary
--   sort on amino_acid makes rank order deterministic in the (unlikely)
--   case of an exact tie between two ratios.
--
-- Final SELECT:
--   - constraint_level labels ranks 1-3 as primary/secondary/tertiary
--     bottlenecks, everything else as 'Adequate'.
--   - mg_needed_to_complete: for the current bottleneck amino acid,
--     computes how many more mg would be needed to bring its ratio up
--     to 1.0 (fully meeting the requirement). The per-amino-acid CASE
--     branches multiply the shortfall (1 - ratio) by protein_g and the
--     amino acid's own WHO/FAO/UNU requirement value, since the mg
--     requirement scales with total protein content.
--   - if_primary_fixed_g: a correlated subquery back into aa_ranking
--     pulls the #2-ranked ratio for the same food, to show what usable
--     protein would be if the #1 bottleneck were solved and #2 became
--     the new limiting amino acid.
--
-- Filtered to a personal food list, limited to each food's top 3
-- constraints.

WITH aa_ranking AS (
    SELECT
        fdc_id,
        protein_g,
        leucine_mg,
        amino_acid,
        ratio_value,
        amino_acid_mg,
        ROW_NUMBER() OVER (PARTITION BY fdc_id ORDER BY ratio_value ASC, amino_acid ASC) AS limiting_rank
    FROM (
        SELECT fdc_id, protein_g, leucine_mg, 'histidine' AS amino_acid, ratio_histidine AS ratio_value, histidine_mg AS amino_acid_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'isoleucine', ratio_isoleucine, isoleucine_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'leucine', ratio_leucine, leucine_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'lysine', ratio_lysine, lysine_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'methionine_cystine', ratio_methionine_cystine, (methionine_mg + cystine_mg) FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'phenylalanine_tyrosine', ratio_phenylalanine_tyrosine, (phenylalanine_mg + tyrosine_mg) FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'threonine', ratio_threonine, threonine_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'tryptophan', ratio_tryptophan, tryptophan_mg FROM v_aa_ratios
        UNION ALL
        SELECT fdc_id, protein_g, leucine_mg, 'valine', ratio_valine, valine_mg FROM v_aa_ratios
    ) AS unpivoted
)
SELECT
    fpc.food_name,
    fpc.food_category,
    u.protein_g AS labeled_protein_g_per_100g,
    u.leucine_mg,
    u.limiting_rank,
    u.amino_acid AS limiting_amino_acid,
    ROUND(u.ratio_value, 3) AS amino_acid_ratio,
    ROUND(u.ratio_value * 100, 1) AS pct_of_standard,
    CASE
        WHEN u.limiting_rank = 1 THEN 'PRIMARY bottleneck'
        WHEN u.limiting_rank = 2 THEN 'Secondary bottleneck'
        WHEN u.limiting_rank = 3 THEN 'Tertiary constraint'
        ELSE 'Adequate'
    END AS constraint_level,
    ROUND(u.protein_g * LEAST(u.ratio_value, 1.0), 2) AS current_usable_protein_g,
    CASE
    WHEN u.amino_acid = 'histidine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 15.0, 1)
    WHEN u.amino_acid = 'isoleucine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 30.0, 1)
    WHEN u.amino_acid = 'leucine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 59.0, 1)
    WHEN u.amino_acid = 'lysine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 45.0, 1)
    WHEN u.amino_acid = 'methionine_cystine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 22.0, 1)
    WHEN u.amino_acid = 'phenylalanine_tyrosine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 38.0, 1)
    WHEN u.amino_acid = 'threonine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 23.0, 1)
    WHEN u.amino_acid = 'tryptophan' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 6.0, 1)
    WHEN u.amino_acid = 'valine' THEN ROUND((1.0 - LEAST(u.ratio_value, 1.0)) * u.protein_g * 39.0, 1)
END AS mg_needed_to_complete,
    ROUND(u.protein_g * LEAST(
        (SELECT ratio_value FROM aa_ranking ar2 WHERE ar2.fdc_id = u.fdc_id AND ar2.limiting_rank = 2 LIMIT 1),
        1.0
    ), 2) AS if_primary_fixed_g
FROM aa_ranking u
JOIN food_protein_calories fpc ON u.fdc_id = fpc.fdc_id
WHERE u.limiting_rank <= 3  -- Show top 3 constraints
  AND (food_name LIKE 'Egg, whole, cooked, fried'
     OR food_name LIKE '%Whey protein%'
     OR food_name LIKE 'Oats (Includes foods for USDA''s Food Distribution Program)'
     OR food_name LIKE 'Pasta, dry, enriched'
     OR food_name LIKE 'Chicken, broiler or fryers, breast, skinless, boneless, meat only, raw'
     OR food_name LIKE 'Rice, white, glutinous, unenriched, uncooked'
     OR food_name LIKE 'Peanut Butter, smooth (Includes foods for USDA\'s Food Distribution Program)'
     OR food_name LIKE 'Yogurt, Greek, plain, lowfat')
ORDER BY fpc.food_name, u.limiting_rank;
