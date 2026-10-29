# first look at the raw data, before any analysis
# run: python3 scripts/01_first_look.py

import pandas as pd

df = pd.read_csv("data/raw/volunteer_meal_data.csv", parse_dates=["date"])

print(df.shape)
print(df.dtypes)

print(df.isna().sum())

df["year"] = df["date"].dt.year
print(df.groupby("year")["date"].agg(["min", "max", "count"]))

# made should = served + wasted, anything else is a problem
df["gap"] = df["meals_made"] - df["meals_served"] - df["leftover_waste"]
print((df["gap"] != 0).sum())

# these two shouldn't happen
print((df["volunteers_showed"] > df["volunteers_signed_up"]).sum())
print((df["meals_served"] > df["meals_made"]).sum())

print(df["notes"].value_counts(dropna=False))
