-- Phase 2 model: one fact table, one calendar table, one weather table, joined on date.
-- Run from the project folder AFTER scripts/03_get_weather.py:
--     duckdb meals.duckdb < sql/02_build_model.sql

-- 1. Calendar table: one row per program day, describing WHEN it was.
--    Kept separate so every other table can join to it by date.
CREATE OR REPLACE TABLE dim_calendar AS
SELECT date,
       year,
       weekday,
       is_fri_to_sun,
       program_day,                              -- 1, 2, 3... within each year
       program_length,
       program_length - program_day + 1 AS days_left,   -- 1 = final program day
       last10
FROM read_csv_auto('data/clean/meals_clean.csv');

-- 2. Fact table: one row per program day, holding WHAT HAPPENED (the numbers).
CREATE OR REPLACE TABLE fact_daily AS
SELECT date,
       meals_made,
       meals_served,
       leftover_waste,
       waste_rate,
       volunteers_needed,
       volunteers_signed_up,
       volunteers_showed,
       showup_rate,
       volunteer_shortfall,
       stockout,
       demand_is_floor,     -- TRUE = served is a minimum, real demand was higher
       rainy_note           -- the chef's label, which we are about to test
FROM read_csv_auto('data/clean/meals_clean.csv');

-- 3. Weather table: Environment Canada daily data, Toronto City station.
--    A "wet day" uses the standard 1 mm cut-off: under 1 mm is a trace, not real rain.
--    This station leaves rain_mm and snow_cm blank, so precip_mm (rain + melted snow) is the measure.
CREATE OR REPLACE TABLE weather AS
SELECT CAST(date AS DATE) AS date,
       temp_mean_c,
       temp_max_c,
       temp_min_c,
       rain_mm,
       snow_cm,
       precip_mm,
       precip_mm >= 1 AS is_wet_day
FROM read_csv_auto('data/clean/weather_daily.csv');

-- 4. One wide view for analysis: fact + calendar + weather, joined on date.
--    LEFT JOIN keeps every program day even if a weather value is missing.
CREATE OR REPLACE VIEW v_daily AS
SELECT f.*,
       c.year, c.weekday, c.is_fri_to_sun, c.program_day, c.days_left, c.last10,
       w.temp_mean_c, w.precip_mm, w.rain_mm, w.snow_cm, w.is_wet_day
FROM fact_daily f
JOIN dim_calendar c USING (date)
LEFT JOIN weather w USING (date);

-- 5. Check the join: should print 88 rows and how many lack weather.
SELECT COUNT(*) AS program_days,
       COUNT(precip_mm) AS days_with_precip,
       COUNT(*) - COUNT(precip_mm) AS days_missing_precip
FROM v_daily;
