-- run: duckdb meals.duckdb < sql/01_load_and_explore.sql

-- load clean csv
CREATE OR REPLACE TABLE meals AS
SELECT * FROM read_csv_auto('data/clean/meals_clean.csv');

-- first 5 rows, sanity check
SELECT date, weekday, meals_made, meals_served, leftover_waste
FROM meals
LIMIT 5;

-- stockout days only
SELECT date, weekday, meals_made, meals_served
FROM meals
WHERE stockout
ORDER BY date;

-- totals by year
SELECT year,
       COUNT(*)                     AS days,
       SUM(meals_made)              AS made,
       SUM(leftover_waste)          AS wasted,
       ROUND(AVG(waste_rate), 3)    AS avg_waste_rate
FROM meals
GROUP BY year
ORDER BY year;
