-- run: duckdb meals.duckdb < sql/07_volunteers.sql   (needs v_analysis from 04)

-- show-up rate by day type and year, pooled = total showed / total signed up
SELECT CASE WHEN is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END AS day_type,
       year,
       COUNT(*)                                                      AS days,
       ROUND(SUM(volunteers_showed) / SUM(volunteers_signed_up), 3)  AS pooled_showup_rate
FROM v_analysis
GROUP BY ROLLUP (day_type, year)
ORDER BY day_type NULLS LAST, year NULLS LAST;

-- bad days: p10 and p25 show-up rates (average would leave you short ~half the time)
SELECT volunteers_needed,
       ROUND(AVG(volunteers_signed_up), 1)        AS avg_signed_up,
       ROUND(AVG(showup_rate), 3)                 AS avg_rate,
       ROUND(QUANTILE_CONT(showup_rate, 0.25), 3) AS p25_rate,
       ROUND(QUANTILE_CONT(showup_rate, 0.10), 3) AS p10_rate,
       SUM(CASE WHEN volunteer_shortfall > 0 THEN 1 ELSE 0 END) AS short_days,
       COUNT(*)                                   AS days
FROM v_analysis
GROUP BY volunteers_needed
ORDER BY volunteers_needed;

-- sign-ups needed = needed / rate, rounded up
WITH rates AS (
    SELECT volunteers_needed,
           AVG(showup_rate)                 AS avg_rate,
           QUANTILE_CONT(showup_rate, 0.25) AS p25_rate,
           QUANTILE_CONT(showup_rate, 0.10) AS p10_rate
    FROM v_analysis
    GROUP BY volunteers_needed
)
SELECT volunteers_needed,
       CEIL(volunteers_needed / avg_rate) AS signups_at_avg_rate,
       CEIL(volunteers_needed / p25_rate) AS signups_at_p25_rate,
       CEIL(volunteers_needed / p10_rate) AS signups_at_p10_rate
FROM rates
ORDER BY volunteers_needed;

-- back-check: with N sign-ups, how many past days would have been short? assumes each day's rate stays as it was
WITH plan AS (
    SELECT 12 AS volunteers_needed, UNNEST([15, 16, 17]) AS signups
    UNION ALL
    SELECT 17, UNNEST([21, 22, 23, 24])
)
SELECT p.volunteers_needed, p.signups,
       COUNT(*) AS days,
       SUM(CASE WHEN FLOOR(p.signups * a.showup_rate + 1e-9) < p.volunteers_needed THEN 1 ELSE 0 END) AS short_days
FROM plan p
JOIN v_analysis a USING (volunteers_needed)
GROUP BY ALL
ORDER BY 1, 2;

-- did short-staffed days cause stockouts or more waste? within segment
SELECT segment,
       volunteer_shortfall > 0                    AS short_staffed,
       COUNT(*)                                   AS days,
       SUM(CASE WHEN stockout THEN 1 ELSE 0 END)  AS stockout_days,
       ROUND(AVG(leftover_waste))                 AS avg_waste
FROM v_analysis
GROUP BY ALL
ORDER BY segment, short_staffed;

-- short-staffed days vs low-turnout days
SELECT rainy_note                AS low_turnout_note,
       volunteer_shortfall > 0   AS short_staffed,
       COUNT(*)                  AS days,
       ROUND(AVG(showup_rate), 3) AS avg_showup_rate
FROM v_analysis
GROUP BY ALL
ORDER BY 1 DESC, 2 DESC;
