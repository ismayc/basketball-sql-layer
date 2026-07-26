"""Test fixtures: this repo's runner plus the sibling shot-quality model."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SIBLINGS = REPO.parent


def load_script(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def sqlchecks():
    return load_script(REPO / "run_sql_checks.py", "sql_checks")


@pytest.fixture(scope="session")
def shotq():
    return load_script(SIBLINGS / "shot-quality-study/python/02_model.py",
                       "shotq_model")
