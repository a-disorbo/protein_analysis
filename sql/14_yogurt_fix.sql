-- Given that greek yogurt's protein is limited by BOTH tryptophan and
-- histidine (see 13_pb_fix.sql, which surfaced yogurt as a lysine fix
-- for peanut butter, then needed its own fix in turn), search cereal
-- grain, baked goods, and nut foods for candidates that supply enough
-- of both to make yogurt's protein fully usable.
--
-- tryptophan_mg / histidine_mg come from v_aa_pivot (05_create_views.sql)
-- rather than a locally-recomputed pivot.
--
-- Thresholds (90mg tryptophan, 60mg histidine per 100g) chosen so a
-- realistic/small portion of the matched food covers a typical yogurt-serving
-- deficit in both amino acids at once -- a single food needs to clear
-- BOTH bars, not just one, since yogurt is short on both.
--
-- Category filter grouped in parentheses so the amino acid thresholds
-- apply across all three categories, not just the first.

SELECT
fpc.food_name,
fpc.food_category,
a.tryptophan_mg,
a.histidine_mg
FROM v_aa_pivot a
JOIN food_protein_calories fpc
ON a.fdc_id = fpc.fdc_id
WHERE a.tryptophan_mg >= 90 AND a.histidine_mg >= 60
AND (
       fpc.food_category LIKE '%Cereal Grains%'
    OR fpc.food_category LIKE '%Baked Products%'
    OR fpc.food_category LIKE '%Nut%'
)