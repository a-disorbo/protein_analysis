-- Bulk load of USDA SR Legacy CSVs into the staging tables from 02.
-- Download the CSVs from https://fdc.nal.usda.gov/download-datasets.html
-- and update the four file paths below to point to your local copy
-- before running.

LOAD DATA LOCAL INFILE './data/sr_legacy_food/food.csv'
INTO TABLE food
CHARACTER SET utf8
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(fdc_id, data_type, description, food_category_id, publication_date);

LOAD DATA LOCAL INFILE './data/sr_legacy_food/food_nutrient.csv'
INTO TABLE food_nutrient
CHARACTER SET utf8
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, fdc_id, nutrient_id, amount, derivation_id);

-- food_portion.csv has more columns than the table needs. Columns not
-- being kept (measure unit id, data points, footnote, min year acquired)
-- are captured into throwaway @-variables so MySQL can still parse the
-- row without requiring a matching table column for each CSV field.
LOAD DATA LOCAL INFILE './data/sr_legacy_food/food_portion.csv'
INTO TABLE food_portion
CHARACTER SET utf8
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, fdc_id, seq_num, amount, @measure_unit_id, portion_description, modifier, gram_weight, @data_points, @footnote, @min_year_acquired);

LOAD DATA LOCAL INFILE './data/sr_legacy_food/food_category.csv'
INTO TABLE food_category
CHARACTER SET utf8
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, code, description);