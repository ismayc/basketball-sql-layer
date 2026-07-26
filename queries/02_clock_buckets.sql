-- End-of-period shot economics, 2023-24: points per shot by seconds left in
-- the period. The observable half of shot-quality-study's clock
-- decomposition (the xPPS half needs the fitted model, which stays in
-- polars/R); n and pps reconcile against clock_decomposition.csv.
-- pps_vs_league is a window aggregate over the grouped result.
WITH shots AS (
    SELECT
        CAST(MINUTES_REMAINING AS INTEGER) * 60
            + CAST(SECONDS_REMAINING AS INTEGER)                  AS secs_left,
        CASE WHEN SHOT_TYPE = '3PT Field Goal' THEN 3 ELSE 2 END
            * CAST(SHOT_MADE_FLAG AS INTEGER)                     AS points
    FROM read_csv('shot-quality-study/data/shotdetail_2023.csv',
                  all_varchar = true)
),
bucketed AS (
    SELECT
        CASE WHEN secs_left <= 4  THEN '00-04s (rush)'
             WHEN secs_left <= 24 THEN '05-24s'
             WHEN secs_left <= 36 THEN '25-36s (2-for-1 window)'
             ELSE '37s+'
        END AS bucket,
        points
    FROM shots
)
SELECT
    bucket,
    COUNT(*)     AS n,
    AVG(points)  AS pps,
    AVG(points)
        - SUM(SUM(points)) OVER () / CAST(SUM(COUNT(*)) OVER () AS DOUBLE)
                 AS pps_vs_league
FROM bucketed
GROUP BY bucket
ORDER BY bucket;
