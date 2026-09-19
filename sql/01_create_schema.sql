-- Core project tables: computed/derived data lives here, separate from the
-- raw USDA staging tables created in 02_create_tables_for_fda_data.sql.

CREATE DATABASE protein_project;
USE protein_project;

-- One row per food: protein and calorie content per 100g, built in
-- 04_build_food_protein_calorie_table.sql via conditional aggregation
-- off the raw food_nutrient table.
CREATE TABLE food_protein_calories (
    food_id             INT AUTO_INCREMENT PRIMARY KEY,
    fdc_id              INT NOT NULL,
    food_name           VARCHAR(255) NOT NULL,
    food_category       VARCHAR(120),
    protein_g_per_100g  DECIMAL(6,2) NOT NULL,
    calories_per_100g   DECIMAL(6,2),
    UNIQUE KEY uq_fdc_id (fdc_id)
);
