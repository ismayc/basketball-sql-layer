"""Unit tests for the sql/ DuckDB layer.

The full reconciliation lives in sql/run_sql_checks.py (run by
run_all_checks.sh); these tests pin the pieces most likely to drift
silently: the CASE expressions embedded in the query files must keep
matching the python definitions they mirror, and every query must keep its
window-function claim.
"""
from __future__ import annotations

import re
from pathlib import Path

import duckdb
import polars as pl
import pytest

REPO = Path(__file__).resolve().parents[2]
QUERIES = sorted((REPO / "queries").glob("*.sql"))


def extract_case(path, anchor: str) -> str:
    """Pull the single CASE expression starting at `anchor` out of a query."""
    text = path.read_text()
    m = re.search(rf"(CASE WHEN {anchor}.*?END)", text, re.DOTALL)
    assert m, f"no CASE WHEN {anchor} found in {path.name}"
    return m.group(1)


def test_max_col_diff_flags_mismatch(sqlchecks):
    j = pl.DataFrame({"a": [1.0, 2.0], "a_right": [1.0, 2.5],
                      "b": [3, 4], "b_right": [3, 4]})
    assert sqlchecks.max_col_diff(
        j, [("a", "a_right"), ("b", "b_right")]) == pytest.approx(0.5)


def test_clock_bucket_boundaries_match_study_convention():
    # Same boundary convention as clock_decomposition in
    # shot-quality-study/python/02_model.py: <=4 rush, <=24, <=36, else.
    case = extract_case(REPO / "queries/02_clock_buckets.sql", "secs_left")
    rows = duckdb.sql(
        f"SELECT secs_left, {case} AS bucket "
        "FROM (VALUES (0), (4), (5), (24), (25), (36), (37), (600)) "
        "t(secs_left) ORDER BY secs_left").fetchall()
    assert [b for _, b in rows] == [
        "00-04s (rush)", "00-04s (rush)", "05-24s", "05-24s",
        "25-36s (2-for-1 window)", "25-36s (2-for-1 window)", "37s+", "37s+"]


def test_action_family_case_matches_python(shotq):
    # The dunk rate in 03_league_structure.sql must classify exactly like
    # action_family (putback and alley-oop take precedence over dunk).
    case = extract_case(REPO / "queries/03_league_structure.sql",
                        "ACTION_TYPE")
    samples = ["Tip Dunk Shot", "Putback Dunk Shot",
               "Running Alley Oop Dunk Shot", "Driving Dunk Shot",
               "Cutting Dunk Shot", "Dunk Shot", "Running Alley Oop Layup Shot",
               "Jump Shot", "Cutting Layup Shot", "Tip Layup Shot"]
    values = ", ".join(f"('{s}')" for s in samples)
    rows = duckdb.sql(f"SELECT ACTION_TYPE, {case} AS family "
                      f"FROM (VALUES {values}) t(ACTION_TYPE)").fetchall()
    for action, fam_sql in rows:
        assert (fam_sql == "dunk") == (shotq.action_family(action) == "dunk"), \
            f"{action}: SQL={fam_sql}, python={shotq.action_family(action)}"


def test_window_function_queries_keep_their_windows():
    assert len(QUERIES) == 6
    windowed = ["01_player_shot_table", "02_clock_buckets",
                "04_lineup_top10", "06_draft_pick_curve"]
    for stem in windowed:
        text = (REPO / "queries" / f"{stem}.sql").read_text()
        assert re.search(r"OVER\s*\(|QUALIFY|WINDOW", text), \
            f"{stem}.sql advertises window functions but uses none"


def test_committed_sql_validation_is_green():
    v = pl.read_csv(REPO / "output" / "sql_validation.csv")
    assert v.height >= 11 and v["passed"].all()
