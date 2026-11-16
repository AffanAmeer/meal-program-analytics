"""Second, independent check of the Phase 4 back-test, plus robustness tests.

The main back-test lives in sql/08_backtest_prep.sql. This script rebuilds it
in pandas from the cleaned table (a separate implementation, so a bug in one
would show up as a mismatch), then asks how much the headline result depends
on choices made while looking at the data.

run: python3 scripts/04_robustness.py   (after 02_clean.py)
out: data/clean/robustness_checks.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
CLEAN = ROOT / "data/clean/meals_clean.csv"
OUT = ROOT / "data/clean/robustness_checks.csv"
TEST_YEARS = (2024, 2025)


def load():
    df = pd.read_csv(CLEAN, parse_dates=["date"])
    df["segment"] = np.where(df["is_fri_to_sun"], "Fri-Sun", "Mon-Thu")
    df["segment"] = df["segment"] + np.where(df["last10"], ", last 10", "")
    return df


def plan(df, buffer_pct, years=TEST_YEARS, drop_low_turnout=True):
    """Prep for each test day from earlier years only (same rule as sql/08)."""
    out = []
    for year in years:
        train = df[(df["year"] < year) & ~df["stockout"]]
        if drop_low_turnout:
            train = train[~train["rainy_note"]]
        median = train.groupby("segment")["meals_served"].median()
        test = df[df["year"] == year].copy()
        test["prep"] = (test["segment"].map(median) * (1 + buffer_pct / 100) / 10).round() * 10
        out.append(test)
    return pd.concat(out)


def score(t):
    """Waste and short days, scored the same way as sql/08."""
    ok = ~t["stockout"]
    waste = (t["prep"] - t["meals_served"]).clip(lower=0)
    short_meals = (t["meals_served"] - t["prep"]).clip(lower=0)
    surely_short = t["stockout"] & (t["prep"] <= t["meals_made"])
    unknown = t["stockout"] & (t["prep"] > t["meals_made"])
    return {
        "test_days": len(t),
        "waste": waste[ok].sum(),
        "short_days": int((short_meals[ok] > 0).sum() + surely_short.sum()),
        "unknown_days": int(unknown.sum()),
        # if real demand on a stockout day was exactly what the kitchen made,
        # every extra meal the plan cooked would have been wasted
        "extra_meals_on_unknown_days": (t["prep"] - t["meals_made"])[unknown].sum(),
    }


def chef(df, years=TEST_YEARS):
    t = df[df["year"].isin(years)]
    return {"waste": t.loc[~t["stockout"], "leftover_waste"].sum(), "short_days": int(t["stockout"].sum())}


def pct(new, old):
    return round(100 * (new - old) / old, 1)


def main():
    df = load()
    base = chef(df)
    rows = []

    def add(check, value, note):
        rows.append({"check": check, "value": value, "note": note})

    # 1. reproduce the headline
    s5 = score(plan(df, 5))
    add("waste_chef", base["waste"], "kitchen's actual waste on the 54 non-stockout test days")
    add("waste_plan_5pct", s5["waste"], "median + 5%, same days")
    add("waste_change_pct", pct(s5["waste"], base["waste"]), "headline result")
    add("short_days_plan_5pct", s5["short_days"], "confirmed short days")
    add("unknown_days_plan_5pct", s5["unknown_days"], "kitchen ran out; plan cooked more, outcome unknown")

    # 2. worst case for the 5 unknown days
    worst = s5["waste"] + s5["extra_meals_on_unknown_days"]
    add("waste_change_pct_worst_case", pct(worst, base["waste"]),
        "if every extra meal cooked on the kitchen's stockout days had been thrown out")

    # 3. buffer chosen without seeing 2025: pick on 2024, test on 2025
    chef24 = chef(df, (2024,))
    cands = [(b, score(plan(df, b, (2024,)))) for b in range(16)]
    fair = [(b, s) for b, s in cands if s["short_days"] <= chef24["short_days"]]
    best = min(fair, key=lambda bs: bs[1]["waste"])[0]
    s25 = score(plan(df, best, (2025,)))
    add("nested_buffer_picked_on_2024", best, "smallest-waste buffer with no more short days than the kitchen in 2024")
    add("nested_waste_change_pct_2025", pct(s25["waste"], chef(df, (2025,))["waste"]),
        "that buffer applied to 2025, which played no part in choosing it")

    # 4. keep the low-turnout days in the training median
    keep = score(plan(df, 5, drop_low_turnout=False))
    add("keep_low_turnout_waste_change_pct", pct(keep["waste"], base["waste"]), "median + 5% if slow days are not left out")
    add("keep_low_turnout_short_days", keep["short_days"], "shows why the slow days are left out of the median")

    # 5. how much could 59 days move by chance? paired bootstrap over test days
    t = plan(df, 5)
    t = t[~t["stockout"]]
    plan_w = (t["prep"] - t["meals_served"]).clip(lower=0).to_numpy()
    chef_w = t["leftover_waste"].to_numpy()
    rng = np.random.default_rng(2027)
    draws = []
    for _ in range(10_000):
        i = rng.integers(0, len(t), len(t))
        draws.append(100 * (plan_w[i].sum() / chef_w[i].sum() - 1))
    add("bootstrap_waste_change_pct_p2_5", round(np.percentile(draws, 2.5), 1), "95% interval, low end (bigger cut)")
    add("bootstrap_waste_change_pct_p97_5", round(np.percentile(draws, 97.5), 1), "95% interval, high end (smaller cut)")

    res = pd.DataFrame(rows)
    res.to_csv(OUT, index=False)
    print(res.to_string(index=False))


if __name__ == "__main__":
    main()
