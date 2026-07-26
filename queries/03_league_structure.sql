-- League shot-mix structure: NBA 2024-25 vs WNBA 2024/2025 — the table
-- behind the corner-three rulebook finding (WNBA's near-uniform arc halves
-- corner share of threes). All twelve columns of
-- shot-quality-study/output/wnba_league_structure.csv re-expressed in SQL,
-- including the action-family precedence (putback before alley-oop before
-- dunk, mirroring ACTION_FAMILIES in 02_model.py).
WITH shots AS (
    SELECT 'NBA 2024-25' AS league, *
    FROM read_csv('shot-quality-study/data/shotdetail_2024.csv',
                  all_varchar = true)
    UNION ALL
    SELECT 'WNBA 2024' AS league, *
    FROM read_csv('shot-quality-study/data/wnba_shotdetail_2024.csv',
                  all_varchar = true)
    UNION ALL
    SELECT 'WNBA 2025' AS league, *
    FROM read_csv('shot-quality-study/data/wnba_shotdetail_2025.csv',
                  all_varchar = true)
),
typed AS (
    SELECT
        league,
        SHOT_ZONE_BASIC                                           AS zone,
        CASE WHEN SHOT_TYPE = '3PT Field Goal' THEN 3 ELSE 2 END  AS shot_value,
        CAST(SHOT_MADE_FLAG AS INTEGER)                           AS made,
        CASE WHEN ACTION_TYPE LIKE '%Tip%'
               OR ACTION_TYPE LIKE '%Putback%'   THEN 'putback'
             WHEN ACTION_TYPE LIKE '%Alley Oop%' THEN 'alley_oop'
             WHEN ACTION_TYPE LIKE '%Dunk%'      THEN 'dunk'
             ELSE 'other'
        END                                                       AS family
    FROM shots
)
SELECT
    league,
    COUNT(*)                                                      AS n_shots,
    AVG(made * shot_value)                                        AS pps,
    AVG(made)                                                     AS make,
    AVG(CASE WHEN shot_value = 3 THEN 1.0 ELSE 0.0 END)           AS pct_three,
    AVG(CASE WHEN zone = 'Restricted Area' THEN 1.0 ELSE 0.0 END) AS pct_rim,
    AVG(CASE WHEN zone = 'Mid-Range' THEN 1.0 ELSE 0.0 END)       AS pct_midrange,
    AVG(made) FILTER (zone = 'Restricted Area')                   AS rim_make,
    AVG(made) FILTER (shot_value = 3)                             AS three_make,
    COUNT(*) FILTER (shot_value = 3
                     AND zone IN ('Left Corner 3', 'Right Corner 3'))
        / CAST(COUNT(*) FILTER (shot_value = 3) AS DOUBLE)        AS corner_share_of_3s,
    AVG(made) FILTER (shot_value = 3
                      AND zone IN ('Left Corner 3', 'Right Corner 3'))
                                                                  AS corner_3_make,
    AVG(CASE WHEN family = 'dunk' THEN 1.0 ELSE 0.0 END) * 1000   AS dunks_per_1000
FROM typed
GROUP BY league
ORDER BY league;
