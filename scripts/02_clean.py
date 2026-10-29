# Phase 1, step 2: build the clean table + a cleaning log.
# Rule: the raw file is never edited. We read it, add columns, check it,
# and write a NEW file. Every action goes into the log so anyone can audit it.
# Run from the project folder:  python3 scripts/02_clean.py

import pandas as pd

RAW = "data/raw/volunteer_meal_data.csv"
OUT = "data/clean/meals_clean.csv"
LOG = "data/clean/cleaning_log.csv"

log = []  # one dict per action; becomes the cleaning log at the end


def record(step, detail, rows_affected):
    """Write down what we did and how many rows it touched."""
    log.append({"step": step, "detail": detail, "rows_affected": int(rows_affected)})


df = pd.read_csv(RAW, parse_dates=["date"])
df = df.sort_values("date").reset_index(drop=True)  # program_day below depends on date order
record("load", f"read {RAW}", len(df))

# --- Checks that must pass. assert stops the script if a rule breaks,
# --- so a bad future file can't silently flow into the analysis.
assert df["date"].is_unique, "duplicate dates"
assert df.drop(columns="notes").notna().all().all(), "missing numeric values"
assert (df["meals_made"] == df["meals_served"] + df["leftover_waste"]).all(), "made != served + waste"
assert (df["volunteers_showed"] <= df["volunteers_signed_up"]).all()
assert (df["meals_served"] <= df["meals_made"]).all()
record("validate", "unique dates, no missing numbers, made = served + waste, no impossible values", len(df))

# --- Calendar columns. Program day matters more than calendar day, because
# --- the program starts on a different date each year.
df["year"] = df["date"].dt.year
df["weekday"] = df["date"].dt.day_name()
df["is_fri_to_sun"] = df["date"].dt.dayofweek >= 4  # Mon=0 ... Fri=4; matches the staffing rule
df["program_day"] = df.groupby("year").cumcount() + 1  # 1, 2, 3... within each year (file is sorted by date)
df["program_length"] = df.groupby("year")["date"].transform("count")
record("add_calendar", "year, weekday, is_fri_to_sun, program_day, program_length", len(df))

# --- Split the free-text notes into yes/no flags. Raw notes column is kept as-is.
notes = df["notes"].fillna("")
df["rainy_note"] = notes.str.contains("rainy")
record("flag_rainy", "rainy_note = notes mention 'rainy' (chef's label, check vs weather in Phase 2)", df["rainy_note"].sum())

# --- Stockout flag: the note says "ran out early". Check the numbers agree.
df["stockout"] = notes.str.contains("ran out early")
assert (df.loc[df["stockout"], "leftover_waste"] == 0).all(), "stockout day with waste"
assert (df.loc[~df["stockout"], "leftover_waste"] > 0).all(), "zero waste on a non-stockout day"
record("flag_stockout", "stockout = notes say 'ran out early'; all have waste 0, no other day does", df["stockout"].sum())

# --- Last-10 flag from the DATE, not the notes (rainy days lose the note).
df["last10"] = df["program_day"] > df["program_length"] - 10
assert df.loc[notes.str.contains("last 10"), "last10"].all(), "'last 10' note outside last 10 days"
record("flag_last10", "last10 = final 10 program days of each year (from date position)", df["last10"].sum())

# --- Demand. We do NOT guess the true demand on stockout days here.
# --- We only mark that served is a floor there. How to handle it is a Phase 3/4 decision.
df["demand_observed"] = df["meals_served"]
df["demand_is_floor"] = df["stockout"]
record("flag_censored_demand", "demand_observed = meals_served; demand_is_floor = True on stockout days", df["demand_is_floor"].sum())

# --- Simple rates for later questions.
df["showup_rate"] = df["volunteers_showed"] / df["volunteers_signed_up"]
df["waste_rate"] = df["leftover_waste"] / df["meals_made"]
df["volunteer_shortfall"] = (df["volunteers_needed"] - df["volunteers_showed"]).clip(lower=0)
record("add_rates", "showup_rate, waste_rate, volunteer_shortfall (0 if enough showed)", len(df))

record("summary", "0 rows dropped, 0 raw values changed; columns only added", len(df))

import os
os.makedirs("data/clean", exist_ok=True)
df.to_csv(OUT, index=False)
pd.DataFrame(log).to_csv(LOG, index=False)
print(pd.DataFrame(log).to_string(index=False))
