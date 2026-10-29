-- does the chef's rainy label match real rain?
-- run: duckdb meals.duckdb < sql/03_test_rainy_labels.sql

-- label vs reality
SELECT rainy_note AS chef_said_rainy,
       is_wet_day AS actually_wet,
       COUNT(*)   AS days
FROM v_daily
GROUP BY ALL
ORDER BY 1 DESC, 2 DESC;

-- precip and waste by label
SELECT rainy_note AS chef_said_rainy,
       COUNT(*) AS days,
       ROUND(AVG(precip_mm), 1) AS avg_precip_mm,
       ROUND(AVG(leftover_waste)) AS avg_waste
FROM v_daily
GROUP BY rainy_note;

-- all rainy-labelled days, full numbers
SELECT date, weekday, precip_mm, temp_mean_c, meals_served, leftover_waste
FROM v_daily
WHERE rainy_note
ORDER BY date;

-- wet days not labelled, split by day type (fri-sun serves more)
SELECT is_fri_to_sun,
       is_wet_day,
       COUNT(*) AS days,
       ROUND(AVG(meals_served)) AS avg_served,
       ROUND(AVG(leftover_waste)) AS avg_waste
FROM v_daily
WHERE NOT rainy_note
GROUP BY ALL
ORDER BY 1, 2;
