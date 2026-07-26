#!/bin/bash
# Unit tests + the SQL-vs-polars reconciliation gate. Requires the sibling
# study repos checked out next door (see clone_family.sh in
# ../basketball-analysis-tools). PY overrides the interpreter.
set -euo pipefail
cd "$(dirname "$0")"
PY=${PY:-.venv/bin/python}

echo "=== unit tests: Python (pytest) ==="
$PY -m pytest tests/python -q

echo
echo "=== DuckDB vs polars reconciliation ==="
$PY run_sql_checks.py | tail -1
