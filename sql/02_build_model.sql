-- run after scripts/03_get_weather.py: duckdb meals.duckdb < sql/02_build_model.sql

-- calendar
CREATE OR REPLACE TABLE dim_calendar AS
SELECT date,
       year,
       weekday,
       is_fri_to_sun,
       program_day,
       program_length,
       program_length - program_day + 1 AS days_left,   -- 1 = last day
       last10
FROM read_csv_auto('data/clean/meals_clean.csv');

-- fact
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
       demand_is_floor,     -- served is a floor here
       rainy_note           -- chef's label, to test
FROM read_csv_auto('data/clean/meals_clean.csv');

-- weather: wet = precip >= 1mm, rain/snow splits are blank so use precip
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

-- wide view, left join keeps days with missing weather
CREATE OR REPLACE VIEW v_daily AS
SELECT f.*,
       c.year, c.weekday, c.is_fri_to_sun, c.program_day, c.days_left, c.last10,
       w.temp_mean_c, w.precip_mm, w.rain_mm, w.snow_cm, w.is_wet_day
FROM fact_daily f
JOIN dim_calendar c USING (date)
LEFT JOIN weather w USING (date);

-- check join: 88 rows, how many lack weather
SELECT COUNT(*) AS program_days,
       COUNT(precip_mm) AS days_with_precip,
       COUNT(*) - COUNT(precip_mm) AS days_missing_precip
FROM v_daily;
