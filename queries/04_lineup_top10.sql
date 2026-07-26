-- Top 10 high-volume five-man lineups, 2023-24, by net points per 100
-- possessions. Mirrors lineup-valuation-study's descriptive table: the
-- Base/Advanced measure-type join (PLUS_MINUS lives in Base, POSS and
-- NET_RATING in Advanced), the POSS >= 1000 volume filter, and
-- net_100 = 100 * PLUS_MINUS / POSS — verified in the study to sit on
-- NBA NET_RATING's scale (slope 1.001). RANK() + QUALIFY does the top-10.
WITH base AS (
    SELECT GROUP_ID, TEAM_ID, TEAM_ABBREVIATION, GROUP_NAME, MIN, PLUS_MINUS
    FROM read_parquet(
        'lineup-valuation-study/data/raw/2023-24/lineups_base_*.parquet')
),
adv AS (
    SELECT GROUP_ID, TEAM_ID, POSS, NET_RATING
    FROM read_parquet(
        'lineup-valuation-study/data/raw/2023-24/lineups_advanced_*.parquet')
)
SELECT
    base.TEAM_ABBREVIATION,
    base.GROUP_NAME,
    base.MIN,
    adv.POSS,
    base.PLUS_MINUS,
    100.0 * base.PLUS_MINUS / adv.POSS                    AS net_100,
    adv.NET_RATING,
    RANK() OVER (ORDER BY 100.0 * base.PLUS_MINUS / adv.POSS DESC)
                                                          AS net_rank
FROM base
JOIN adv USING (GROUP_ID, TEAM_ID)
WHERE adv.POSS >= 1000
QUALIFY net_rank <= 10
ORDER BY net_rank;
