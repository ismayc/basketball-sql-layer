-- Per-player shot production, 2023-24 (all 218,701 shots).
-- Data layer of shot-quality-study/output/player_table.csv re-expressed in
-- SQL: fga / pts / pps per player, plus two window-function columns the
-- polars version computes separately — league-relative points and a rank
-- among 300+ FGA qualifiers.
-- Reconciled column-for-column against the committed polars output.
WITH shots AS (
    SELECT
        CAST(PLAYER_ID AS BIGINT)                                 AS player_id,
        PLAYER_NAME                                               AS player_name,
        CASE WHEN SHOT_TYPE = '3PT Field Goal' THEN 3 ELSE 2 END  AS shot_value,
        CAST(SHOT_MADE_FLAG AS INTEGER)                           AS made
    FROM read_csv('shot-quality-study/data/shotdetail_2023.csv',
                  all_varchar = true)
),
per_player AS (
    SELECT
        player_id,
        any_value(player_name)  AS player_name,
        COUNT(*)                AS fga,
        SUM(made * shot_value)  AS pts
    FROM shots
    GROUP BY player_id
)
SELECT
    player_id,
    player_name,
    fga,
    pts,
    pts / CAST(fga AS DOUBLE)                                     AS pps,
    -- points above a league-average shooter on the same volume
    pts - fga * (SUM(pts) OVER () / CAST(SUM(fga) OVER () AS DOUBLE))
                                                                  AS pts_above_league,
    CASE WHEN fga >= 300
         THEN RANK() OVER (PARTITION BY fga >= 300
                           ORDER BY pts / CAST(fga AS DOUBLE) DESC)
    END                                                           AS pps_rank_300fga
FROM per_player
ORDER BY pps DESC, fga DESC;
