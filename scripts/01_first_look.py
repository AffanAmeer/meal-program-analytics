# Phase 1, step 1: first look at the raw data.
# Goal: answer "can I trust this file?" BEFORE doing any analysis.
# Run from the project folder:  python3 scripts/01_first_look.py

import pandas as pd

# 1. Load. parse_dates turns the text "2023-03-23" into a real date,
#    so we can later ask for weekday, year, gaps between days, etc.
df = pd.read_csv("data/raw/volunteer_meal_data.csv", parse_dates=["date"])

# 2. Shape and types: how many rows/columns, and did each column load as the type we expect?
print(df.shape)
print(df.dtypes)

# 3. Missing values per column.
print(df.isna().sum())

# 4. Rows per year, plus first and last date of each year.
df["year"] = df["date"].dt.year
print(df.groupby("year")["date"].agg(["min", "max", "count"]))

# 5. Accounting check: every meal made should be either served or wasted.
df["gap"] = df["meals_made"] - df["meals_served"] - df["leftover_waste"]
print((df["gap"] != 0).sum())

# 6. Impossible values: count rows where
#    - more volunteers showed than signed up
#    - more meals served than made
print((df["volunteers_showed"] > df["volunteers_signed_up"]).sum())
print((df["meals_served"] > df["meals_made"]).sum())

# 7. What do the notes actually say?
print(df["notes"].value_counts(dropna=False))
