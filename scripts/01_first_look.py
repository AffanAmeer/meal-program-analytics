# Phase 1, step 1: first look at the raw data.
# Goal: answer "can I trust this file?" BEFORE doing any analysis.
# Run from your project folder:  python3 01_first_look.py
# Fill in every line marked TODO. Hints are in the comments.

import pandas as pd

# 1. Load. parse_dates turns the text "2023-03-23" into a real date,
#    so we can later ask for weekday, year, gaps between days, etc.
df = pd.read_csv("data/raw/volunteer_meal_data.csv", parse_dates=["date"])

# 2. Shape and types: how many rows/columns, and did each column load as the type we expect?
print(df.shape)
print(df.dtypes)

# 3. Missing values per column.
# TODO: one line. Hint: df.isna() gives True/False per cell; what do you add on to count the Trues per column?

# 4. Rows per year, plus first and last date of each year.
df["year"] = df["date"].dt.year
# TODO: group by year and get min date, max date, and count of dates.
#       Hint: df.groupby("year")["date"].agg([...])

# 5. Accounting check: every meal made should be either served or wasted.
# TODO: create a column 'gap' = meals_made - meals_served - leftover_waste,
#       then print how many rows have gap != 0.

# 6. Impossible values: count rows where
#    - more volunteers showed than signed up
#    - more meals served than made
# TODO: two lines, each like  print((df[colA] > df[colB]).sum())

# 7. What do the notes actually say?
# TODO: one line. Hint: value_counts(dropna=False) so blanks are counted too.
