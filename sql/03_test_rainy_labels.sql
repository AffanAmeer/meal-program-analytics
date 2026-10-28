-- Does the chef's "rainy" label match real precipitation?
-- Run:  duckdb meals.duckdb < sql/03_test_rainy_labels.sql

-- A. Label vs reality in a 2x2 table (a "confusion matrix").
--    Good labels put most rows on chef=TRUE/wet=TRUE and chef=FALSE/wet=FALSE.
SELECT rainy_note AS chef_said_rainy,
       is_wet_day AS actually_wet,
       COUNT(*)   AS days
FROM v_daily
GROUP BY ALL
ORDER BY 1 DESC, 2 DESC;

-- B. Average precipitation on days the chef did and didn't call rainy.
SELECT rainy_note AS chef_said_rainy,
       COUNT(*) AS days,
       ROUND(AVG(precip_mm), 1) AS avg_precip_mm,
       ROUND(AVG(leftover_waste)) AS avg_waste
FROM v_daily
GROUP BY rainy_note;

-- C. Every chef-labelled rainy day, with the real numbers, to eyeball.
SELECT date, weekday, precip_mm, temp_mean_c, meals_served, leftover_waste
FROM v_daily
WHERE rainy_note
ORDER BY date;

-- D. Real wet days the chef did NOT label rainy: did waste go up anyway?
--    Compare within day type, because Fri-Sun always serves more.
SELECT is_fri_to_sun,
       is_wet_day,
       COUNT(*) AS days,
       ROUND(AVG(meals_served)) AS avg_served,
       ROUND(AVG(leftover_waste)) AS avg_waste
FROM v_daily
WHERE NOT rainy_note
GROUP BY ALL
ORDER BY 1, 2;
