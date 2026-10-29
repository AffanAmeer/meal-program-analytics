-- Phase 5: export small, ready-to-chart tables for the Tableau Public dashboard.
-- Run from the project folder AFTER 04, 08 and 09 (needs v_analysis and the back-test CSVs):
--     duckdb meals.duckdb < sql/10_tableau_exports.sql
--
-- WHY EXPORT FROM SQL: Tableau Public can only read files (no DuckDB connection), and any
-- maths done in Tableau is hidden inside the workbook. Doing the numbers here keeps them in
-- one place we can check, and Tableau only has to draw them.
-- Each file is "long" (one row per thing to draw), because that is the shape Tableau
-- likes best: drag one column to colour, one to the axis, and the chart is done.

-- 1. dash_daily.csv: one row per program day (88 rows), for the "what happened" chart.
--    day_status gives each day ONE label so Tableau can colour by it.
--    prep_target = the recommended amount for that day's segment (median of ordinary
--    days + 5%, all 3 years), so the chart can show the target next to what was cooked.
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

-- 2. dash_tradeoff.csv: the Phase 4 buffer trade-off (8 plans), for the scatter chart.
--    'role' lets Tableau colour the chef, the recommended plan and the safety option
--    differently from the rest. 'label' is the short text shown next to each dot.
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

-- 3. dash_segments.csv: chef vs recommended plan in each segment (8 rows).
--    avg_prep and waste come from the out-of-sample back-test (59 test days);
--    next_program_target is the all-years number to actually cook next time.
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

-- 4. dash_signups.csv: the sign-up plans from the Phase 4 test (4 plans x 2 day types).
--    One row per plan and day type, so Tableau can show short days per plan and the
--    sign-ups each plan asked for.
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

-- 5. dash_targets.csv: the answer card. One row per segment with everything to plan
--    the next program: meals to cook (+5%, and +8% if no shortage is acceptable) and
--    sign-ups to ask for (p10 show-up rule, all 3 years).
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

-- 6. Check: each file's row count. Expect 88, 8, 8, 8, 4.
SELECT 'dash_daily' AS file, COUNT(*) AS rows FROM read_csv_auto('data/tableau/dash_daily.csv')
UNION ALL SELECT 'dash_tradeoff', COUNT(*) FROM read_csv_auto('data/tableau/dash_tradeoff.csv')
UNION ALL SELECT 'dash_segments', COUNT(*) FROM read_csv_auto('data/tableau/dash_segments.csv')
UNION ALL SELECT 'dash_signups',  COUNT(*) FROM read_csv_auto('data/tableau/dash_signups.csv')
UNION ALL SELECT 'dash_targets',  COUNT(*) FROM read_csv_auto('data/tableau/dash_targets.csv');
