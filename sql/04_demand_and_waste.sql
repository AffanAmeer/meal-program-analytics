-- run after 02_build_model.sql: duckdb meals.duckdb < sql/04_demand_and_waste.sql

-- segment = day type x last 10, all comparisons within segment
CREATE OR REPLACE VIEW v_analysis AS
SELECT *,
       CASE WHEN is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END
       || CASE WHEN last10 THEN ', last 10' ELSE '' END AS segment
FROM v_daily;

-- demand per segment, stockouts out (served is a floor there, would pull demand down)
SELECT segment,
       COUNT(*)                                       AS days,
       ROUND(AVG(meals_made))                         AS avg_made,
       ROUND(AVG(meals_served))                       AS avg_served,
       ROUND(MEDIAN(meals_served))                    AS median_served,
       ROUND(QUANTILE_CONT(meals_served, 0.9))        AS p90_served,
       MAX(meals_served)                              AS max_served,
       ROUND(STDDEV_SAMP(meals_served))               AS sd_served,
       ROUND(AVG(leftover_waste))                     AS avg_waste
FROM v_analysis
WHERE NOT stockout
GROUP BY segment
ORDER BY segment;

-- where waste comes from, all 88 days
SELECT segment,
       COUNT(*)                                                     AS days,
       SUM(leftover_waste)                                          AS total_waste,
       ROUND(100.0 * SUM(leftover_waste) / SUM(SUM(leftover_waste)) OVER (), 1) AS share_of_waste_pct,
       ROUND(100.0 * SUM(leftover_waste) / SUM(meals_made), 1)      AS waste_rate_pct,
       SUM(CASE WHEN stockout THEN 1 ELSE 0 END)                    AS stockout_days
FROM v_analysis
GROUP BY segment
ORDER BY total_waste DESC;

-- waste from the 12 low-turnout days (rainy note is not real rain)
SELECT CASE WHEN rainy_note THEN 'low-turnout note' ELSE 'other days' END AS day_kind,
       COUNT(*)                                                     AS days,
       SUM(leftover_waste)                                          AS total_waste,
       ROUND(100.0 * SUM(leftover_waste) / SUM(SUM(leftover_waste)) OVER (), 1) AS share_of_waste_pct,
       ROUND(AVG(leftover_waste))                                   AS avg_waste_per_day
FROM v_analysis
GROUP BY day_kind;

-- waste on ordinary days only
SELECT segment,
       COUNT(*)                                            AS days,
       ROUND(AVG(meals_made))                              AS avg_made,
       ROUND(MEDIAN(meals_served))                         AS median_served,
       ROUND(AVG(meals_made) - MEDIAN(meals_served))       AS made_above_median,
       ROUND(AVG(leftover_waste))                          AS avg_waste
FROM v_analysis
WHERE NOT stockout AND NOT rainy_note
GROUP BY segment
ORDER BY segment;

-- stockout days vs their segment median, gap < 0 = cooked below normal
WITH seg_normal AS (
    SELECT segment, MEDIAN(meals_served) AS median_served
    FROM v_analysis
    WHERE NOT stockout
    GROUP BY segment
)
SELECT a.date, a.weekday, a.segment,
       a.meals_made                              AS made_and_all_served,
       ROUND(s.median_served)                    AS segment_median,
       ROUND(a.meals_made - s.median_served)     AS gap_vs_median,
       a.volunteers_showed, a.volunteers_needed
FROM v_analysis a
JOIN seg_normal s USING (segment)
WHERE a.stockout
ORDER BY a.date;

-- spread above median, raw material for the phase 4 buffer
WITH seg_normal AS (
    SELECT segment, MEDIAN(meals_served) AS median_served
    FROM v_analysis
    WHERE NOT stockout
    GROUP BY segment
)
SELECT a.segment,
       ROUND(QUANTILE_CONT(a.meals_served - s.median_served, 0.75)) AS p75_above_median,
       ROUND(QUANTILE_CONT(a.meals_served - s.median_served, 0.90)) AS p90_above_median,
       ROUND(MAX(a.meals_served - s.median_served))                 AS max_above_median
FROM v_analysis a
JOIN seg_normal s USING (segment)
WHERE NOT a.stockout
GROUP BY a.segment
ORDER BY a.segment;
