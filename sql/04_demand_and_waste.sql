-- Phase 3, part 1: how many meals are needed, where waste comes from, and why we ran out.
-- Run from the project folder AFTER 02_build_model.sql:
--     duckdb meals.duckdb < sql/04_demand_and_waste.sql

-- 0. Analysis view: v_daily plus a "segment" label.
--    Phase 1 showed demand depends on day type (Mon-Thu vs Fri-Sun) and whether it is one
--    of the last 10 program days. Crossing the two gives 4 segments, each with 12-34 days.
--    That is as fine as 88 rows can support, so every comparison below is WITHIN a segment.
CREATE OR REPLACE VIEW v_analysis AS
SELECT *,
       CASE WHEN is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END
       || CASE WHEN last10 THEN ', last 10' ELSE '' END AS segment
FROM v_daily;

-- 1. Demand per segment, stockout days LEFT OUT.
--    On the 7 stockout days meals_served = meals_made, so we only know demand was AT LEAST
--    that number (it is "censored"). Averaging them in would pull demand down, so we drop them
--    here and look at them separately in query 4.
--    median = the middle day, not dragged around by a few very slow days.
--    p90    = 9 in 10 days served this many meals or fewer.
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

-- 2. Where does the waste come from? All 88 days.
--    share_of_waste = this segment's waste as a % of all meals wasted.
SELECT segment,
       COUNT(*)                                                     AS days,
       SUM(leftover_waste)                                          AS total_waste,
       ROUND(100.0 * SUM(leftover_waste) / SUM(SUM(leftover_waste)) OVER (), 1) AS share_of_waste_pct,
       ROUND(100.0 * SUM(leftover_waste) / SUM(meals_made), 1)      AS waste_rate_pct,
       SUM(CASE WHEN stockout THEN 1 ELSE 0 END)                    AS stockout_days
FROM v_analysis
GROUP BY segment
ORDER BY total_waste DESC;

-- 3. How much waste came from the 12 surprise low-turnout days (the chef's "rainy" note)?
--    Phase 2 showed the note is not real rain, so we call it a low-turnout day.
SELECT CASE WHEN rainy_note THEN 'low-turnout note' ELSE 'other days' END AS day_kind,
       COUNT(*)                                                     AS days,
       SUM(leftover_waste)                                          AS total_waste,
       ROUND(100.0 * SUM(leftover_waste) / SUM(SUM(leftover_waste)) OVER (), 1) AS share_of_waste_pct,
       ROUND(AVG(leftover_waste))                                   AS avg_waste_per_day
FROM v_analysis
GROUP BY day_kind;

-- 3b. Waste on ORDINARY days only (no stockout, no low-turnout note).
--     This is over-prep the kitchen could have avoided with a better plan, since
--     nothing unusual happened on these days.
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

-- 4. The 7 stockout days next to their segment's normal demand.
--    A CTE (WITH ...) computes each segment's median once, then we join it to each stockout day.
--    gap_vs_median < 0 means the kitchen cooked LESS than a normal day's demand.
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

-- 5. Spread above normal: how far above the segment median did busy days go?
--    This is the raw material for the buffer in Phase 4.
--    "Upside" = served minus segment median, only on days that were above the median.
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
