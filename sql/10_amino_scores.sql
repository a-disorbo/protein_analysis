-- Core methodology: for each food, finds its "limiting amino acid" and
-- the resulting usable (complete) protein, using the WHO/FAO/UNU (2007)
-- adult essential amino acid requirement pattern (mg amino acid per g
-- of protein):
--   histidine 15, isoleucine 30, leucine 59, lysine 45,
--   methionine+cystine 22, phenylalanine+tyrosine 38,
--   threonine 23, tryptophan 6, valine 39
--
-- The pivot and per-amino-acid ratio calculation (both amino acid mg
-- converted from the food_nutrient table, and each ratio = mg per g
-- protein / WHO-FAO-UNU requirement) are defined once in the view
-- v_aa_ratios (05_create_views.sql). This script picks up from there.
--
-- aa_limiting: LEAST(...) across all nine ratios finds the smallest --
--   this is the "limiting amino acid," the one in shortest supply
--   relative to what the body needs, which caps how much of the food's
--   total protein can actually be used to build new protein.
--
-- usable_protein: usable_fraction caps the limiting ratio at 1.0 (a
--   ratio above 1.0 doesn't mean "extra credit," it just means that
--   amino acid isn't limiting). usable_protein_g = total protein x that
--   fraction -- e.g. pasta's ~12g protein x a lysine-limited fraction
--   works out to roughly 6g of protein the body can actually build with.

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
ORDER BY u.protein_g DESC;
