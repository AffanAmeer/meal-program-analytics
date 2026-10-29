-- Phase 4, part 1: back-test the meal prep rule against what the chef actually cooked.
-- Run from the project folder AFTER 04 (needs the v_analysis view):
--     duckdb meals.duckdb < sql/08_backtest_prep.sql
--
-- THE RULE:  prep = (normal demand for this segment) + (a buffer of X%)
--            "normal demand" = median meals served on past ORDINARY days in that segment
--                              (no stockout, no low-turnout note).
--
-- WHY ORDINARY DAYS ONLY: the plan is for a normal day. The low-turnout days can't be seen
-- coming (Phase 2/3), so letting them into the median drags the forecast down and makes the
-- kitchen run short on normal days. Stockout days are left out because their served number
-- is only a floor (censored). Both kinds of days are still SCORED in the test below.
--
-- WHY OUT-OF-SAMPLE: if we built the rule from all 3 years and then scored it on the same
-- 3 years, it would look better than it really is (it has already "seen the answers").
-- So we pretend to stand at the start of each year and only use the years before it:
--     test 2024 -> rule built from 2023 only
--     test 2025 -> rule built from 2023 + 2024
-- 2023 can't be tested (nothing before it). That leaves 59 test days.

-- 1. Training numbers: for each test year and segment, what did the EARLIER years look like?
--    FILTER (WHERE ...) lets one query compute the median on ordinary days and the
--    Phase 3 p90 (all non-stockout days, the way Phase 3 did it) side by side.
CREATE OR REPLACE TEMP TABLE train_stats AS
SELECT t.test_year,
       a.segment,
       COUNT(*) FILTER (WHERE NOT a.rainy_note)                         AS train_days,
       MEDIAN(a.meals_served) FILTER (WHERE NOT a.rainy_note)           AS train_median,
       QUANTILE_CONT(a.meals_served, 0.9)                               AS train_p90
FROM (SELECT UNNEST([2024, 2025]) AS test_year) t
JOIN v_analysis a
  ON a.year < t.test_year            -- only the past
 AND NOT a.stockout
GROUP BY ALL;

-- Look at what the rule learned. Note how few days some segments have when testing 2024.
SELECT test_year, segment, train_days, ROUND(train_median) AS train_median, ROUND(train_p90) AS train_p90
FROM train_stats
ORDER BY test_year, segment;

-- 2. The plans to compare. Each plan gives one prep number per test year and segment.
--    Prep is rounded to the nearest 10, since a kitchen plans in round numbers.
--    "median + X%" = the rule with different buffer sizes.
--    "p90"         = Phase 3's draft rule (90th percentile of past demand).
CREATE OR REPLACE TEMP TABLE plans AS
SELECT 'median + ' || b.buffer_pct || '%'          AS plan,
       b.buffer_pct,
       s.test_year, s.segment,
       ROUND(s.train_median * (1 + b.buffer_pct / 100.0) / 10) * 10 AS prep
FROM train_stats s
CROSS JOIN (SELECT UNNEST([0, 3, 5, 8, 10, 15]) AS buffer_pct) b
UNION ALL
SELECT 'p90 (Phase 3 draft)', NULL, test_year, segment,
       ROUND(train_p90 / 10) * 10
FROM train_stats;

-- 3. Score every plan on every test day.
--    Ordinary day (no stockout): demand = served, so we know exactly what would have happened.
--        waste = prep - demand if prep was more, short = demand - prep if prep was less.
--    Stockout day: demand was AT LEAST what the chef made. Two cases:
--        prep <= chef's amount -> the plan would have run out too (short for sure).
--        prep >  chef's amount -> can't tell: more food would have gone out, but we don't
--                                 know if it was enough. Counted as "unknown", not as a win.
CREATE OR REPLACE TEMP TABLE scored AS
SELECT p.plan, p.buffer_pct, a.date, a.year, a.segment, a.rainy_note, a.stockout,
       p.prep,
       a.meals_made                                                   AS chef_made,
       a.meals_served,
       CASE WHEN NOT a.stockout THEN GREATEST(p.prep - a.meals_served, 0) END AS waste,
       CASE WHEN NOT a.stockout THEN GREATEST(a.meals_served - p.prep, 0) END AS meals_short,
       CASE WHEN NOT a.stockout THEN a.meals_served > p.prep
            WHEN p.prep <= a.meals_made THEN TRUE
            ELSE NULL END                                             AS ran_short   -- NULL = unknown
FROM plans p
JOIN v_analysis a
  ON a.year = p.test_year AND a.segment = p.segment;

-- 4. The chef's actual results on the same 59 test days, scored the same way.
--    (prep = what they really made, so their stockout days count as short for sure.)
INSERT INTO scored
SELECT 'chef (actual)', NULL, date, year, segment, rainy_note, stockout,
       meals_made, meals_made, meals_served,
       CASE WHEN NOT stockout THEN leftover_waste END,
       CASE WHEN NOT stockout THEN 0 END,
       stockout
FROM v_analysis
WHERE year IN (2024, 2025);

-- 5. THE TRADE-OFF TABLE. One row per plan, test years only.
--    total_waste        = meals thrown out on the ordinary (non-stockout) test days
--    waste_vs_chef_pct  = change in that waste compared with the chef
--    short_days         = days the plan would surely have run out
--    meals_short        = how many meals short in total on ordinary days
--    stockout_days_unknown = chef's stockout days where the plan cooked more than the chef,
--                            so we can't say if it would have been enough
CREATE OR REPLACE TEMP TABLE tradeoff AS
WITH chef AS (SELECT SUM(waste) AS chef_waste FROM scored WHERE plan = 'chef (actual)')
SELECT plan, buffer_pct,
       COUNT(*)                                                   AS test_days,
       SUM(prep)                                                  AS meals_cooked,
       SUM(waste)                                                 AS total_waste,
       ROUND(100.0 * (SUM(waste) - ANY_VALUE(chef_waste)) / ANY_VALUE(chef_waste)) AS waste_vs_chef_pct,
       SUM(CASE WHEN ran_short THEN 1 ELSE 0 END)                 AS short_days,
       SUM(meals_short)                                           AS meals_short,
       SUM(CASE WHEN ran_short IS NULL THEN 1 ELSE 0 END)         AS stockout_days_unknown
FROM scored, chef
GROUP BY plan, buffer_pct
ORDER BY plan = 'chef (actual)' DESC, buffer_pct NULLS LAST;

SELECT * FROM tradeoff;

-- 6. Same table, ORDINARY days only (no stockout, no low-turnout note).
--    The low-turnout days waste food under any plan, since nobody can see them coming.
--    This shows how each plan does on the days a plan CAN control.
SELECT plan,
       COUNT(*)                                       AS ordinary_days,
       SUM(waste)                                     AS waste,
       ROUND(AVG(waste))                              AS avg_waste_per_day,
       SUM(CASE WHEN ran_short THEN 1 ELSE 0 END)     AS short_days,
       SUM(meals_short)                               AS meals_short
FROM scored
WHERE NOT stockout AND NOT rainy_note
GROUP BY plan, buffer_pct
ORDER BY plan = 'chef (actual)' DESC, buffer_pct NULLS LAST;

-- 7. The chosen plan (median + 5%) by segment, next to the chef. Where do the savings come from?
SELECT segment, plan,
       COUNT(*)                                       AS days,
       ROUND(AVG(prep))                               AS avg_prep,
       SUM(waste)                                     AS waste,
       SUM(CASE WHEN ran_short THEN 1 ELSE 0 END)     AS short_days,
       SUM(meals_short)                               AS meals_short,
       SUM(CASE WHEN ran_short IS NULL THEN 1 ELSE 0 END) AS unknown_days
FROM scored
WHERE plan IN ('chef (actual)', 'median + 5%')
GROUP BY ALL
ORDER BY segment, plan;

-- 8. The chef's 4 stockout days in the test years: would the chosen plan have cooked more?
SELECT s.date, s.segment,
       s.chef_made                AS chef_made_and_ran_out,
       s.prep                     AS plan_prep,
       s.prep - s.chef_made       AS extra_meals_from_plan
FROM scored s
WHERE s.plan = 'median + 5%' AND s.stockout
ORDER BY s.date;

-- 9. The prep targets for NEXT program, built from all 3 years of ordinary days.
SELECT segment,
       COUNT(*)                                            AS days_used,
       ROUND(MEDIAN(meals_served))                         AS normal_demand,
       ROUND(MEDIAN(meals_served) * 1.05 / 10) * 10        AS prep_plus_5pct,
       ROUND(MEDIAN(meals_served) * 1.08 / 10) * 10        AS prep_plus_8pct
FROM v_analysis
WHERE NOT stockout AND NOT rainy_note
GROUP BY segment
ORDER BY segment;

-- 10. Save the trade-off table for the Tableau dashboard (Phase 5).
COPY tradeoff TO 'data/clean/backtest_tradeoff.csv' (HEADER);

-- 11. Save every plan's score on every test day, also for Tableau (Phase 5).
COPY (SELECT * FROM scored ORDER BY plan, date) TO 'data/clean/backtest_daily.csv' (HEADER);
