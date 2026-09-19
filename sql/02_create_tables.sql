-- Raw staging tables matching the USDA SR Legacy CSV export schema 1:1.
-- Loaded via LOAD DATA LOCAL INFILE in 03_load_fda_data.sql, then
-- transformed into food_protein_calories in 04.

CREATE TABLE food (
    fdc_id             INT PRIMARY KEY,       -- USDA FoodData Central ID
    data_type          VARCHAR(50),           -- e.g. 'sr_legacy_food'
    description        VARCHAR(500),          -- food name as published by USDA
    food_category_id   INT,                   -- FK (logical, not enforced) -> food_category.id
    publication_date   DATE
);

CREATE TABLE food_category (
    id          INT PRIMARY KEY,
    code        VARCHAR(10),
    description VARCHAR(255)                  -- e.g. 'Legumes and Legume Products'
);

-- Long/narrow format: one row per (food, nutrient) pair rather than one
-- column per nutrient. This is what 04 and 09 pivot with MAX(CASE WHEN...)
-- to get protein, calories, and each amino acid into their own columns.
CREATE TABLE food_nutrient (
    id          INT PRIMARY KEY,
    fdc_id      INT,                          -- FK (logical) -> food.fdc_id
    nutrient_id INT,                          -- USDA nutrient code (1003 = protein, 1213 = leucine, etc.)
    amount      DECIMAL(10,3),                -- value per 100g, units vary by nutrient_id
    derivation_id INT                         -- FK (logical) -> food_nutrient_derivation.id, added in 10
);

-- Serving-size conversions (e.g. "1 cup" -> grams). Joined to
-- food_protein_calories in 09_protein_serving.sql to get protein per serving
-- instead of just per 100g.
CREATE TABLE food_portion (
    id                   INT PRIMARY KEY,
    fdc_id               INT,
    seq_num              INT,                 -- ordering when a food has multiple portion options
    amount               DECIMAL(10,3),       -- numeric part of the portion, e.g. 1 in "1 cup"
    portion_description  VARCHAR(255),        -- e.g. 'cup'
    modifier             VARCHAR(255),        -- e.g. 'cooked'
    gram_weight          DECIMAL(10,2)        -- grams for this portion
);
