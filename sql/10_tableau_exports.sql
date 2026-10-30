-- export small tables for tableau
-- run after 04, 08, 09: duckdb meals.duckdb < sql/10_tableau_exports.sql
-- export from sql: tableau only reads files, numbers stay checkable here

-- daily, one row per program day
CREATE OR REPLACE TEMP TABLE targets AS
SELECT segment,
       ROUND(MEDIAN(meals_served))                       AS normal_demand,
       ROUND(MEDIAN(meals_served) * 1.05 / 10) * 10      AS prep_target,
       ROUND(MEDIAN(meals_served) * 1.08 / 10) * 10      AS prep_target_8pct
FROM v_analysis
WHERE NOT stockout AND NOT rainy_note
GROUP BY segment;

COPY (
    SELECT a.date, a.year, a.weekday, a.program_day, a.days_left, a.segment,
           CASE WHEN a.is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END AS day_type,
           a.last10,
           CASE WHEN a.stockout   THEN 'Ran out early'
                WHEN a.rainy_note THEN 'Low-turnout day'
                ELSE 'Ordinary day' END                  AS day_status,
           a.meals_made, a.meals_served, a.leftover_waste,
           ROUND(a.waste_rate, 3)                        AS waste_rate,
           t.prep_target,
           a.volunteers_needed, a.volunteers_signed_up, a.volunteers_showed,
           ROUND(a.showup_rate, 3)                       AS showup_rate,
           a.volunteers_showed < a.volunteers_needed     AS volunteers_short
    FROM v_analysis a
    JOIN targets t USING (segment)
    ORDER BY a.date
) TO 'data/tableau/dash_daily.csv' (HEADER);

-- buffer tradeoff, 8 plans
COPY (
    SELECT plan,
           buffer_pct,
           CASE WHEN plan = 'chef (actual)'  THEN 'Chef today'
                WHEN plan = 'median + 5%'    THEN 'Recommended'
                WHEN plan = 'median + 8%'    THEN 'Safety-first option'
                ELSE 'Other plans' END                   AS role,
           CASE WHEN plan = 'chef (actual)'  THEN 'Chef today'
                WHEN plan LIKE 'p90%'        THEN 'p90 draft'
                ELSE '+' || buffer_pct || '%' END        AS label,
           test_days, meals_cooked, total_waste, waste_vs_chef_pct,
           short_days, meals_short, stockout_days_unknown
    FROM read_csv_auto('data/clean/backtest_tradeoff.csv')
) TO 'data/tableau/dash_tradeoff.csv' (HEADER);

-- chef vs recommended by segment, 8 rows
COPY (
    SELECT d.segment,
           CASE WHEN d.plan = 'chef (actual)' THEN 'Chef today' ELSE 'Recommended (+5%)' END AS plan,
           COUNT(*)                                      AS test_days,
           ROUND(AVG(d.prep))                            AS avg_prep,
           SUM(d.waste)                                  AS waste,
           SUM(CASE WHEN d.ran_short THEN 1 ELSE 0 END)  AS short_days,
           ANY_VALUE(t.normal_demand)                    AS normal_demand,
           ANY_VALUE(t.prep_target)                      AS next_program_target
    FROM read_csv_auto('data/clean/backtest_daily.csv') d
    JOIN targets t USING (segment)
    WHERE d.plan IN ('chef (actual)', 'median + 5%')
    GROUP BY d.segment, d.plan
    ORDER BY d.segment, d.plan
) TO 'data/tableau/dash_segments.csv' (HEADER);

-- sign-up plans, 4 plans x 2 day types
COPY (
    SELECT plan,
           CASE WHEN plan = 'p10 rule' THEN 'Recommended'
                WHEN plan = 'actual'   THEN 'Today'
                ELSE 'Other plans' END                   AS role,
           CASE WHEN volunteers_needed = 12 THEN 'Mon-Thu' ELSE 'Fri-Sun' END AS day_type,
           volunteers_needed,
           COUNT(*)                                      AS test_days,
           ROUND(AVG(signups), 1)                        AS avg_signups,
           SUM(CASE WHEN showed < volunteers_needed THEN 1 ELSE 0 END) AS short_days,
           SUM(CASE WHEN showed < volunteers_needed AND NOT rainy_note THEN 1 ELSE 0 END) AS short_days_ordinary,
           SUM(GREATEST(volunteers_needed - showed, 0))  AS people_short
    FROM read_csv_auto('data/clean/backtest_signups_daily.csv')
    GROUP BY ALL
    ORDER BY plan, day_type
) TO 'data/tableau/dash_signups.csv' (HEADER);

-- answer card, one row per segment
COPY (
    WITH signup_target AS (
        SELECT volunteers_needed,
               CEIL(volunteers_needed / QUANTILE_CONT(showup_rate, 0.10)) AS signups_target
        FROM v_analysis
        GROUP BY volunteers_needed
    )
    SELECT t.segment, t.normal_demand, t.prep_target, t.prep_target_8pct,
           ANY_VALUE(a.volunteers_needed)                AS volunteers_needed,
           ANY_VALUE(s.signups_target)                   AS signups_target
    FROM targets t
    JOIN v_analysis a USING (segment)
    JOIN signup_target s ON s.volunteers_needed = a.volunteers_needed
    GROUP BY ALL
    ORDER BY t.segment
) TO 'data/tableau/dash_targets.csv' (HEADER);

-- check row counts: expect 88, 8, 8, 8, 4
SELECT 'dash_daily' AS file, COUNT(*) AS rows FROM read_csv_auto('data/tableau/dash_daily.csv')
UNION ALL SELECT 'dash_tradeoff', COUNT(*) FROM read_csv_auto('data/tableau/dash_tradeoff.csv')
UNION ALL SELECT 'dash_segments', COUNT(*) FROM read_csv_auto('data/tableau/dash_segments.csv')
UNION ALL SELECT 'dash_signups',  COUNT(*) FROM read_csv_auto('data/tableau/dash_signups.csv')
UNION ALL SELECT 'dash_targets',  COUNT(*) FROM read_csv_auto('data/tableau/dash_targets.csv');
