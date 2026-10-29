-- back-test sign-up rule
-- run after 04: duckdb meals.duckdb < sql/09_backtest_signups.sql
-- rule: sign-ups = needed / cautious show-up rate, rounded up (p25 or p10)
-- out-of-sample, same as 08: 2024 from 2023, 2025 from 2023+2024
-- scoring: keep each day's real rate, floor the result

-- what the rule would have asked for, earlier years only
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

-- plans to compare on the 59 test days
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

-- results, ordinary short days = short days that weren't low-turnout days
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

-- p10 rule from all 3 years: sign-ups for next program
SELECT volunteers_needed,
       ROUND(QUANTILE_CONT(showup_rate, 0.10), 3)                AS p10_rate,
       CEIL(volunteers_needed / QUANTILE_CONT(showup_rate, 0.10)) AS signups_next_program
FROM v_analysis
GROUP BY volunteers_needed
ORDER BY volunteers_needed;

-- save daily scores for tableau
COPY (SELECT * FROM signup_scored ORDER BY plan, date) TO 'data/clean/backtest_signups_daily.csv' (HEADER);
