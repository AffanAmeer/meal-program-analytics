"""Every number quoted in the README and decision memo, recomputed from the raw file.

These checks use pandas only, not the SQL, so they are a second, independent
calculation. If a data or code change moves a headline number, a test fails
and the write-ups need updating too.

run: python3 -m pytest tests/
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))


@pytest.fixture(scope="module")
def df():
    subprocess.run([sys.executable, str(ROOT / "scripts/02_clean.py")], cwd=ROOT, check=True,
                   stdout=subprocess.DEVNULL)
    raw = pd.read_csv(ROOT / "data/raw/volunteer_meal_data.csv", parse_dates=["date"])
    clean = pd.read_csv(ROOT / "data/clean/meals_clean.csv", parse_dates=["date"])
    assert len(raw) == len(clean)
    return clean


@pytest.fixture(scope="module")
def robustness():
    import importlib
    mod = importlib.import_module("04_robustness")
    df = mod.load()
    return mod, df


def test_totals(df):
    assert len(df) == 88
    assert df.groupby("year").size().to_dict() == {2023: 29, 2024: 30, 2025: 29}
    assert df["meals_made"].sum() == 90_320          # made, not served
    assert df["meals_served"].sum() == 80_611
    assert df["leftover_waste"].sum() == 9_709
    assert round(100 * df["leftover_waste"].sum() / df["meals_made"].sum()) == 11


def test_flags(df):
    assert df["stockout"].sum() == 7
    assert df["rainy_note"].sum() == 12


def test_fri_sun_share(df):
    assert round(100 * df["is_fri_to_sun"].mean()) == 42
    assert round(100 * df.loc[df["is_fri_to_sun"], "leftover_waste"].sum() / df["leftover_waste"].sum()) == 72


def test_slow_days_share_of_waste(df):
    assert round(100 * df.loc[df["rainy_note"], "leftover_waste"].sum() / df["leftover_waste"].sum()) == 38


def test_showup_rate(df):
    assert round(100 * df["volunteers_showed"].sum() / df["volunteers_signed_up"].sum()) == 87


def test_prep_targets(robustness):
    mod, df = robustness
    ordinary = df[~df["stockout"] & ~df["rainy_note"]]
    med = ordinary.groupby("segment")["meals_served"].median()
    plus5 = ((med * 1.05) / 10).round() * 10
    assert plus5.to_dict() == {"Fri-Sun": 1120, "Fri-Sun, last 10": 1310, "Mon-Thu": 810, "Mon-Thu, last 10": 970}


def test_signup_targets(df):
    p10 = df.groupby("volunteers_needed")["showup_rate"].quantile(0.10)
    signups = np.ceil(p10.index / p10.values)
    assert list(signups) == [16, 24]


def test_backtest_matches_sql(robustness):
    mod, df = robustness
    s = mod.score(mod.plan(df, 5))
    assert s["test_days"] == 59
    assert mod.chef(df)["waste"] == 6_698
    assert s["waste"] == 4_413
    assert s["short_days"] == 5 and s["unknown_days"] == 5
    sql = pd.read_csv(ROOT / "data/clean/backtest_tradeoff.csv").set_index("plan")
    for b in (0, 3, 5, 8, 10, 15):
        r = mod.score(mod.plan(df, b))
        assert r["waste"] == sql.loc[f"median + {b}%", "total_waste"]
        assert r["short_days"] == sql.loc[f"median + {b}%", "short_days"]


def test_training_never_sees_test_year(robustness):
    mod, df = robustness
    # change every 2025 number: the 2025 plan must not move
    before = mod.plan(df, 5, years=(2025,))["prep"].to_numpy()
    df2 = df.copy()
    df2.loc[df2["year"] == 2025, "meals_served"] *= 3
    after = mod.plan(df2, 5, years=(2025,))["prep"].to_numpy()
    assert (before == after).all()
