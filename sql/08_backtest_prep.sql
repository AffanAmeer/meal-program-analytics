-- back-test prep rule vs chef
-- run after 04: duckdb meals.duckdb < sql/08_backtest_prep.sql
-- rule: prep = segment median on past ordinary days + buffer %, rounded to nearest 10
-- out-of-sample: 2024 from 2023 only, 2025 from 2023+2024, 59 test days
-- stockout days: prep <= chef = short for sure, prep > chef = unknown, not a win

-- training: earlier years only
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

SELECT test_year, segment, train_days, ROUND(train_median) AS train_median, ROUND(train_p90) AS train_p90
FROM train_stats
ORDER BY test_year, segment;

-- plans to compare
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

-- score every plan on every test day
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

-- chef on the same 59 test days, scored the same way
INSERT INTO scored
SELECT 'chef (actual)', NULL, date, year, segment, rainy_note, stockout,
       meals_made, meals_made, meals_served,
       CASE WHEN NOT stockout THEN leftover_waste END,
       CASE WHEN NOT stockout THEN 0 END,
       stockout
FROM v_analysis
WHERE year IN (2024, 2025);

-- tradeoff table
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

-- tradeoff, ordinary days only
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

-- median + 5% by segment vs chef
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

-- stockout days in test years: would +5% have cooked more?
SELECT s.date, s.segment,
       s.chef_made                AS chef_made_and_ran_out,
       s.prep                     AS plan_prep,
       s.prep - s.chef_made       AS extra_meals_from_plan
FROM scored s
WHERE s.plan = 'median + 5%' AND s.stockout
ORDER BY s.date;

-- prep targets for next program, all 3 years ordinary days
SELECT segment,
       COUNT(*)                                            AS days_used,
       ROUND(MEDIAN(meals_served))                         AS normal_demand,
       ROUND(MEDIAN(meals_served) * 1.05 / 10) * 10        AS prep_plus_5pct,
       ROUND(MEDIAN(meals_served) * 1.08 / 10) * 10        AS prep_plus_8pct
FROM v_analysis
WHERE NOT stockout AND NOT rainy_note
GROUP BY segment
ORDER BY segment;

-- save tradeoff for tableau
COPY tradeoff TO 'data/clean/backtest_tradeoff.csv' (HEADER);

-- save daily scores for tableau
COPY (SELECT * FROM scored ORDER BY plan, date) TO 'data/clean/backtest_daily.csv' (HEADER);
