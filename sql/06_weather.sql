-- Phase 3, part 3: does weather move demand once we compare within segment?
-- Run:  duckdb meals.duckdb < sql/06_weather.sql   (needs v_analysis from 04)
-- Phase 2 tested rain. This adds temperature and uses the segment median as the baseline.

-- 1. Each day's demand vs its segment's normal ("residual" = served - segment median).
--    CORR gives a correlation from -1 to 1. Near 0 = weather tells us nothing about demand.
WITH seg_normal AS (
    SELECT segment, MEDIAN(meals_served) AS median_served
    FROM v_analysis
    WHERE NOT stockout
    GROUP BY segment
),
resid AS (
    SELECT a.*, a.meals_served - s.median_served AS vs_normal
    FROM v_analysis a
    JOIN seg_normal s USING (segment)
    WHERE NOT a.stockout AND NOT a.rainy_note   -- surprise-slow days would swamp everything
)
SELECT COUNT(*)                                   AS days,
       ROUND(CORR(vs_normal, temp_mean_c), 2)     AS corr_with_temp,
       ROUND(CORR(vs_normal, precip_mm), 2)       AS corr_with_precip
FROM resid;

-- 2. Same idea in buckets, easier to explain than a correlation.
WITH seg_normal AS (
    SELECT segment, MEDIAN(meals_served) AS median_served
    FROM v_analysis
    WHERE NOT stockout
    GROUP BY segment
)
SELECT CASE WHEN a.temp_mean_c < 0 THEN '1: below 0 C'
            WHEN a.temp_mean_c < 5 THEN '2: 0 to 5 C'
            ELSE                        '3: 5 C and up' END     AS temp_band,
       COUNT(*)                                                 AS days,
       ROUND(AVG(a.meals_served - s.median_served))             AS avg_vs_normal,
       SUM(CASE WHEN a.rainy_note THEN 1 ELSE 0 END)            AS low_turnout_note_days
FROM v_analysis a
JOIN seg_normal s USING (segment)
WHERE NOT a.stockout
GROUP BY temp_band
ORDER BY temp_band;
