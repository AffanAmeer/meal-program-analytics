-- Run from the project folder:  duckdb meals.duckdb < sql/01_load_and_explore.sql
-- Or open it interactively with:  duckdb meals.duckdb   then paste queries one at a time.

-- 1. Load the clean CSV into a table. read_csv_auto guesses column types.
CREATE OR REPLACE TABLE meals AS
SELECT * FROM read_csv_auto('data/clean/meals_clean.csv');

-- 2. SELECT: look at a few columns for the first 5 rows.
SELECT date, weekday, meals_made, meals_served, leftover_waste
FROM meals
LIMIT 5;

-- 3. WHERE: only the days the program ran out of food.
SELECT date, weekday, meals_made, meals_served
FROM meals
WHERE stockout
ORDER BY date;

-- 4. GROUP BY: one row per year with totals and average waste rate.
SELECT year,
       COUNT(*)                     AS days,
       SUM(meals_made)              AS made,
       SUM(leftover_waste)          AS wasted,
       ROUND(AVG(waste_rate), 3)    AS avg_waste_rate
FROM meals
GROUP BY year
ORDER BY year;

-- YOUR TURN (write these yourself, answers are checked in the chat):
-- A. Average meals_served on Fri-Sun vs Mon-Thu. (Hint: GROUP BY is_fri_to_sun)
-- B. How many days had a volunteer shortfall, per year?
-- C. Average leftover_waste on rainy_note days vs all other days.
