# SQL layer: the portfolio's headline tables in DuckDB

**Why.** The studies' pipelines are polars/tidyverse; a front office data
stack speaks SQL (the Suns' sibling postings name Snowflake). This layer
re-expresses the portfolio's headline aggregates as SQL run by <abbr title="An in-process analytical SQL engine that queries CSV and parquet files directly, with no server or load step.">DuckDB</abbr>
directly against the same raw CSV/parquet files the studies use — no load
step, no copies — and holds the SQL to the repo's standing reconcile
discipline.

<!-- terms -->
> **Terms used in this analysis.** Dotted-underlined terms anywhere below repeat these definitions on hover ([full glossary](../docs/glossary.md)).
>
> - **xPPS** — Expected points per shot - the model's fair price of a shot diet: what an average shooter would score on the same attempts, judged from location and shot type alone, before knowing what went in.
> - **FGA** — Field-goal attempts.
> - **RAPM** — Regularized adjusted plus-minus: a ridge regression crediting each player with net points per 100 possessions while adjusting for the other nine players on the floor.
> - **stint** — A stretch of game time with no substitution at either end - the unit of observation for the stint-level RAPM model.
> - **IRLS** — Iteratively reweighted least squares - the standard algorithm for fitting a logistic regression.
> - **ridge** — Ridge regression: least squares with an L2 penalty that keeps many-parameter models stable at the cost of a little bias.
> - **corner three** — A three-pointer from the corner, where the NBA line is roughly 3 ft closer than the arc - the geometry discount that makes it the cheapest three.
> - **DuckDB** — An in-process analytical SQL engine that queries CSV and parquet files directly, with no server or load step.
<!-- /terms -->

## Queries

| Query | Source data | Mirrors | Window functions |
|---|---|---|---|
| `01_player_shot_table.sql` | 218,701-shot 2023-24 shot detail | `shot-quality-study/output/player_table.csv` (data layer: fga/pts/pps) | league-relative points via `SUM() OVER ()`, `RANK()` among 300+ <abbr title="Field-goal attempts.">FGA</abbr> |
| `02_clock_buckets.sql` | same | `clock_decomposition.csv` (n, pps) | window aggregate over grouped rows for pps-vs-league |
| `03_league_structure.sql` | NBA 2024-25 + WNBA 2024/2025 shot detail | `wnba_league_structure.csv`, all 12 columns (<abbr title="A three-pointer from the corner, where the NBA line is roughly 3 ft closer than the arc - the geometry discount that makes it the cheapest three.">corner-three</abbr> rulebook finding) | — (`FILTER` aggregates; action-family precedence in a `CASE`) |
| `04_lineup_top10.sql` | 60 per-team lineup parquet files (Base + Advanced) | `lineup-valuation-study/output/2023-24/lineup_table.csv` | `RANK()` + `QUALIFY` for the top-10 |
| `05_stint_summary.sql` | 69,767-<abbr title="A stretch of game time with no substitution at either end - the unit of observation for the stint-level RAPM model.">stint</abbr> parquet | polars re-derivation (raw home margin +2.25/100 vs the <abbr title="Ridge regression: least squares with an L2 penalty that keeps many-parameter models stable at the cost of a little bias.">ridge</abbr> intercept's +2.2) | — |
| `06_draft_pick_curve.sql` | `draft-study/output/model_frame.csv` | polars re-derivation of the pick-value curve (empirical coin flip ≈ pick 29) | named `WINDOW`s: 9-pick centered + running cumulative |

## Reconciliation

`run_sql_checks.py` executes every query, writes its result to `output/`,
and gates:

- **01–04** against the committed polars outputs they mirror, column for
  column (observed diffs: exactly 0.0);
- **05–06**, which have no committed twin, against an independent polars
  re-derivation of the identical definition (observed ~2e-13).

Eleven checks; any failure exits non-zero. Wired into
`../run_all_checks.sh`. Unit tests (`tests/python/test_sql.py`) pin the
drift-prone pieces: the clock-bucket boundaries and the action-family
`CASE` are extracted from the query files themselves and replayed against
the python definitions they must keep matching.

## Scope

SQL owns the **data layer** here. Model-layer numbers — <abbr title="Expected points per shot - the model's fair price of a shot diet: what an average shooter would score on the same attempts, judged from location and shot type alone, before knowing what went in.">xPPS</abbr>, <abbr title="Regularized adjusted plus-minus: a ridge regression crediting each player with net points per 100 possessions while adjusting for the other nine players on the floor.">RAPM</abbr>,
logistic coefficients — deliberately stay in polars/R, where they are
already dual-implemented and reconciled; a fitted <abbr title="Iteratively reweighted least squares - the standard algorithm for fitting a logistic regression.">IRLS</abbr> does not belong in
SQL. That boundary (SQL for set logic and window aggregation, statistical
fitting in a real language) is the same division of labor a
Snowflake-backed front office runs.

## Run

```
python sql/run_sql_checks.py     # paths resolve to the repo root
```
