"""Rebuild every output from the raw CSVs in one go.

Uses the duckdb Python package, so the DuckDB command line tool isn't needed.
Run from anywhere: python3 scripts/run_all.py
"""
import os
import subprocess
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)  # every script and SQL file uses paths relative to the project folder

PY_STEPS = ["scripts/02_clean.py", "scripts/03_get_weather.py"]
SQL_STEPS = [
    "sql/02_build_model.sql",
    "sql/04_demand_and_waste.sql",
    "sql/08_backtest_prep.sql",
    "sql/09_backtest_signups.sql",
    "sql/10_tableau_exports.sql",
]

for step in PY_STEPS:
    print(f"-> {step}")
    subprocess.run([sys.executable, step], check=True, stdout=subprocess.DEVNULL)

os.makedirs("data/tableau", exist_ok=True)
con = duckdb.connect("meals.duckdb")
for step in SQL_STEPS:
    print(f"-> {step}")
    con.execute(Path(step).read_text())
con.close()

print("-> scripts/04_robustness.py")
subprocess.run([sys.executable, "scripts/04_robustness.py"], check=True)
print("done: outputs in data/clean and data/tableau")
