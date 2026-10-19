-- Empirical pick-value curve from draft-study's model frame (569 drafted
-- college players, 2011-2022): P(rotation player within three seasons) by
-- overall pick, smoothed with a 9-pick centered window and accumulated with
-- a running window — the SQL twin of the study's "coin flip ≈ pick 28"
-- curve. Reconciled against a polars re-derivation of the same definition.
WITH by_pick AS (
    SELECT
        OVERALL_PICK           AS pick,
        COUNT(*)               AS n,
        SUM(rotation)          AS hits
    FROM read_csv('draft-study/output/model_frame.csv')
    GROUP BY OVERALL_PICK
)
SELECT
    pick,
    n,
    hits / CAST(n AS DOUBLE)                              AS hit_rate,
    SUM(hits) OVER w9 / CAST(SUM(n) OVER w9 AS DOUBLE)    AS hit_rate_9pick,
    SUM(n)    OVER cum                                    AS cum_players,
    SUM(hits) OVER cum / CAST(SUM(n) OVER cum AS DOUBLE)  AS cum_hit_rate
FROM by_pick
WINDOW
    w9  AS (ORDER BY pick ROWS BETWEEN 4 PRECEDING AND 4 FOLLOWING),
    cum AS (ORDER BY pick ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY pick;
