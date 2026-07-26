-- Season summary of the 69,767-stint dataset behind the stint-RAPM model:
-- coverage, pace bookkeeping, and the RAW home-court margin per 100
-- possessions. The stint-RAPM intercept (+2.2/100) is the opponent-adjusted
-- version of the same quantity; the raw margin here should land in the same
-- range. Reconciled against an independent polars re-derivation.
WITH stints AS (
    SELECT * FROM read_parquet('lineup-valuation-study/data/stints_2023.parquet')
)
SELECT
    COUNT(*)                                              AS n_stints,
    COUNT(DISTINCT game_id)                               AS n_games,
    SUM(home_pts)                                         AS home_pts,
    SUM(away_pts)                                         AS away_pts,
    SUM(poss_home) + SUM(poss_away)                       AS poss_total,
    -- margin per 100 possessions of one team's ball (average of the two
    -- sides' possession counts = possessions per team)
    100.0 * (SUM(home_pts) - SUM(away_pts))
        / ((SUM(poss_home) + SUM(poss_away)) / 2.0)       AS home_margin_100,
    AVG(elapsed)                                          AS mean_stint_secs,
    quantile_cont(elapsed, 0.5)                           AS median_stint_secs,
    AVG(CASE WHEN elapsed < 30 THEN 1.0 ELSE 0.0 END)     AS pct_under_30s
FROM stints;
