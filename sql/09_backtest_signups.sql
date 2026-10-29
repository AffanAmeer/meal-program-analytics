-- Phase 4, part 2: back-test the volunteer sign-up rule.
-- Run from the project folder AFTER 04 (needs the v_analysis view):
--     duckdb meals.duckdb < sql/09_backtest_signups.sql
--
-- THE RULE:  sign-ups = volunteers needed / a cautious show-up rate, rounded UP.
--            "cautious" = a low percentile of past show-up rates. We test two:
--                p25 = 1 in 4 past days was worse,  p10 = 1 in 10 past days was worse.
-- Same out-of-sample set-up as 08: test 2024 with 2023's rates, test 2025 with 2023 + 2024's.
--
-- How a day is scored: we keep each day's REAL show-up rate and ask "if they had recruited
-- N people instead, how many would have come?"  FLOOR because 0.6 of a person doesn't show up.

-- 1. What the rule would have asked for, using only earlier years.
CREATE OR REPLACE TEMP TABLE signup_rule AS
SELECT t.test_year,
       a.volunteers_needed,
       ROUND(QUANTILE_CONT(a.showup_rate, 0.25), 3)                      AS train_p25_rate,
       CEIL(a.volunteers_needed / QUANTILE_CONT(a.showup_rate, 0.25))    AS signups_p25,
       ROUND(QUANTILE_CONT(a.showup_rate, 0.10), 3)                      AS train_p10_rate,
       CEIL(a.volunteers_needed / QUANTILE_CONT(a.showup_rate, 0.10))    AS signups_p10
FROM (SELECT UNNEST([2024, 2025]) AS test_year) t
JOIN v_analysis a ON a.year < t.test_year
GROUP BY t.test_year, a.volunteers_needed;

SELECT * FROM signup_rule ORDER BY test_year, volunteers_needed;

-- 2. Plans to compare on the 59 test days:
--      actual         = what the program really recruited each day
--      p25 / p10 rule = the rule above (changes by year as it learns)
--      fixed 16 / 23  = Phase 3's draft (16 Mon-Thu, 23 Fri-Sun)
CREATE OR REPLACE TEMP TABLE signup_scored AS
SELECT 'actual' AS plan, date, segment, rainy_note, volunteers_needed,
       volunteers_signed_up AS signups, volunteers_showed AS showed
FROM v_analysis WHERE year IN (2024, 2025)
UNION ALL
SELECT 'p25 rule', a.date, a.segment, a.rainy_note, a.volunteers_needed,
       r.signups_p25, FLOOR(r.signups_p25 * a.showup_rate + 1e-9)
FROM v_analysis a
JOIN signup_rule r ON r.test_year = a.year AND r.volunteers_needed = a.volunteers_needed
UNION ALL
SELECT 'p10 rule', a.date, a.segment, a.rainy_note, a.volunteers_needed,
       r.signups_p10, FLOOR(r.signups_p10 * a.showup_rate + 1e-9)
FROM v_analysis a
JOIN signup_rule r ON r.test_year = a.year AND r.volunteers_needed = a.volunteers_needed
UNION ALL
SELECT 'fixed 16 / 23', date, segment, rainy_note, volunteers_needed,
       CASE WHEN volunteers_needed = 12 THEN 16 ELSE 23 END,
       FLOOR(CASE WHEN volunteers_needed = 12 THEN 16 ELSE 23 END * showup_rate + 1e-9)
FROM v_analysis WHERE year IN (2024, 2025);

-- 3. Results. short_days_ordinary = short days that were NOT low-turnout note days
--    (those are the ones that matter most, because guests came as normal).
--    avg_spare = average volunteers above what was needed (the cost of being safe).
SELECT plan,
       COUNT(*)                                                         AS days,
       ROUND(AVG(signups), 1)                                           AS avg_signups,
       SUM(CASE WHEN showed < volunteers_needed THEN 1 ELSE 0 END)      AS short_days,
       SUM(CASE WHEN showed < volunteers_needed AND NOT rainy_note THEN 1 ELSE 0 END) AS short_days_ordinary,
       SUM(GREATEST(volunteers_needed - showed, 0))                     AS people_short,
       ROUND(AVG(showed - volunteers_needed), 1)                        AS avg_spare
FROM signup_scored
GROUP BY plan
ORDER BY plan;

-- 4. The p10 rule built from all 3 years: sign-ups to recruit next program.
SELECT volunteers_needed,
       ROUND(QUANTILE_CONT(showup_rate, 0.10), 3)                AS p10_rate,
       CEIL(volunteers_needed / QUANTILE_CONT(showup_rate, 0.10)) AS signups_next_program
FROM v_analysis
GROUP BY volunteers_needed
ORDER BY volunteers_needed;

-- 5. Save every sign-up plan's result on every test day, for Tableau (Phase 5).
COPY (SELECT * FROM signup_scored ORDER BY plan, date) TO 'data/clean/backtest_signups_daily.csv' (HEADER);
