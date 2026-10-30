-- review a real trial vs back-test
-- run after 08 and 09: duckdb meals.duckdb < sql/11_trial_review.sql
-- new in trial: turned away counted, so demand ~ served + turned away

-- load log, same labels as back-test
CREATE OR REPLACE TEMP TABLE trial AS
WITH log AS (
    SELECT * REPLACE (TRY_CAST(turned_away AS INTEGER)        AS turned_away,
                      TRY_CAST(cancelled_same_day AS INTEGER) AS cancelled_same_day),
           LOWER(TRIM(CAST(ran_out AS VARCHAR))) IN ('yes', 'y', 'true', '1') AS ran_out_flag,
           ROW_NUMBER() OVER (ORDER BY date)                                   AS program_day,
           COUNT(*) OVER ()                                                    AS program_length
    FROM read_csv_auto('data/trial/nightly_log.csv')
)
SELECT *,
       ISODOW(date) >= 5                                   AS is_fri_to_sun,
       program_day > program_length - 10                   AS last10,
       CASE WHEN ISODOW(date) >= 5 THEN 'Fri-Sun' ELSE 'Mon-Thu' END
       || CASE WHEN program_day > program_length - 10 THEN ', last 10' ELSE '' END AS segment,
       meals_served + CASE WHEN ran_out_flag THEN COALESCE(turned_away, 0) ELSE 0 END AS demand_est,
       showed < volunteers_needed                          AS volunteers_short
FROM log;

-- did the kitchen cook the target? off-target = >20 meals away either way
SELECT segment,
       COUNT(*)                                            AS nights,
       ROUND(AVG(prep_target))                             AS avg_target,
       ROUND(AVG(meals_made))                              AS avg_cooked,
       COUNT(*) FILTER (WHERE ABS(meals_made - prep_target) > 20) AS off_target_nights
FROM trial
GROUP BY segment
ORDER BY segment;

-- was normal demand where expected? slow = served <80% of normal, no run out
CREATE OR REPLACE TEMP TABLE expected AS
SELECT segment, normal_demand FROM read_csv_auto('data/tableau/dash_targets.csv');

CREATE OR REPLACE TEMP TABLE trial_labeled AS
SELECT t.*, e.normal_demand,
       NOT t.ran_out_flag AND t.meals_served < 0.8 * e.normal_demand AS slow_night
FROM trial t JOIN expected e USING (segment);

SELECT segment,
       normal_demand                                       AS expected_normal,
       ROUND(MEDIAN(demand_est) FILTER (WHERE NOT slow_night)) AS trial_median_demand,
       ROUND(100.0 * MEDIAN(demand_est) FILTER (WHERE NOT slow_night) / normal_demand - 100, 1)
                                                           AS pct_diff,
       COUNT(*) FILTER (WHERE slow_night)                  AS slow_nights
FROM trial_labeled
GROUP BY segment, normal_demand
ORDER BY segment;

-- main comparison: trial vs back-test, waste on non-run-out nights only, short nights per 30
CREATE OR REPLACE TEMP TABLE scorecard AS
SELECT plan,
       COUNT(*)                                                        AS nights,
       ROUND(AVG(waste) FILTER (WHERE NOT stockout), 1)                AS waste_per_night,
       ROUND(100.0 * SUM(waste) FILTER (WHERE NOT stockout)
                   / SUM(prep) FILTER (WHERE NOT stockout), 1)         AS waste_pct_of_cooked,
       COUNT(*) FILTER (WHERE ran_short)                               AS short_nights,
       ROUND(30.0 * COUNT(*) FILTER (WHERE ran_short) / COUNT(*), 1)   AS short_nights_per_30,
       NULL::INTEGER                                                   AS people_turned_away
FROM read_csv_auto('data/clean/backtest_daily.csv')
WHERE plan IN ('chef (actual)', 'median + 5%', 'median + 8%')
GROUP BY plan
UNION ALL
SELECT 'TRIAL',
       COUNT(*),
       ROUND(AVG(leftover_waste) FILTER (WHERE NOT ran_out_flag), 1),
       ROUND(100.0 * SUM(leftover_waste) FILTER (WHERE NOT ran_out_flag)
                   / SUM(meals_made) FILTER (WHERE NOT ran_out_flag), 1),
       COUNT(*) FILTER (WHERE ran_out_flag),
       ROUND(30.0 * COUNT(*) FILTER (WHERE ran_out_flag) / COUNT(*), 1),
       SUM(COALESCE(turned_away, 0))
FROM trial;

SELECT * FROM scorecard ORDER BY plan;

-- every ran-out night, how big the gap really was
SELECT date, segment, prep_target, meals_made, meals_served, ran_out_time, turned_away,
       demand_est - meals_made                             AS est_meals_short
FROM trial
WHERE ran_out_flag
ORDER BY date;

-- volunteers by day type
SELECT CASE WHEN is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END AS day_type,
       COUNT(*)                                            AS nights,
       ROUND(AVG(signed_up), 1)                            AS avg_signed_up,
       ROUND(AVG(1.0 * showed / signed_up), 3)             AS showup_rate,
       COUNT(*) FILTER (WHERE volunteers_short)            AS short_nights,
       SUM(COALESCE(cancelled_same_day, 0))                AS cancelled_same_day
FROM trial
GROUP BY day_type
ORDER BY day_type;

-- save one row per night for a trial dashboard page
COPY (
    SELECT date, program_day, segment, prep_target, meals_made, meals_served, leftover_waste,
           ran_out_flag AS ran_out, turned_away, demand_est, slow_night,
           volunteers_needed, signed_up, showed, volunteers_short
    FROM trial_labeled
    ORDER BY date
) TO 'data/trial/trial_review_daily.csv' (HEADER);
