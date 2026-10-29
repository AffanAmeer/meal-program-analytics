-- run: duckdb meals.duckdb < sql/05_trends.sql   (needs v_analysis from 04)

-- median served by segment and year, stockouts out
PIVOT (
    SELECT segment, year, MEDIAN(meals_served) AS median_served
    FROM v_analysis
    WHERE NOT stockout
    GROUP BY segment, year
)
ON year USING ROUND(FIRST(median_served))
ORDER BY segment;

-- same for meals made
PIVOT (
    SELECT segment, year, AVG(meals_made) AS avg_made
    FROM v_analysis
    GROUP BY segment, year
)
ON year USING ROUND(FIRST(avg_made))
ORDER BY segment;

-- totals by year
SELECT year,
       COUNT(*)                                              AS days,
       SUM(meals_made)                                       AS made,
       SUM(meals_served)                                     AS served,
       SUM(leftover_waste)                                   AS wasted,
       ROUND(100.0 * SUM(leftover_waste) / SUM(meals_made), 1) AS waste_rate_pct,
       SUM(CASE WHEN stockout THEN 1 ELSE 0 END)             AS stockout_days
FROM v_analysis
GROUP BY year
ORDER BY year;

-- first 10 / middle / last 10, stockouts and low-turnout days out
SELECT CASE WHEN is_fri_to_sun THEN 'Fri-Sun' ELSE 'Mon-Thu' END AS day_type,
       CASE WHEN program_day <= 10 THEN '1: first 10'
            WHEN last10            THEN '3: last 10'
            ELSE                        '2: middle' END       AS program_stage,
       COUNT(*)                                               AS days,
       ROUND(MEDIAN(meals_served))                            AS median_served
FROM v_analysis
WHERE NOT stockout AND NOT rainy_note
GROUP BY ALL
ORDER BY day_type, program_stage;
