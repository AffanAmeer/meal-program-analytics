"""Download daily weather from Environment Canada for each program year.

Station: TORONTO CITY (stationID 31688, climate ID 6158355), the closest
long-running daily station to the program. Saves the raw files untouched in
data/raw/weather/ and one combined file in data/clean/weather_daily.csv.
Run from the project folder:  python3 scripts/03_get_weather.py
"""
import os
import pandas as pd

STATION_ID = 31688
YEARS = [2023, 2024, 2025]
URL = ("https://climate.weather.gc.ca/climate_data/bulk_data_e.html"
       "?format=csv&stationID={sid}&Year={year}&Month=1&Day=1&timeframe=2&submit=Download+Data")

os.makedirs("data/raw/weather", exist_ok=True)
frames = []
for year in YEARS:
    raw_path = f"data/raw/weather/toronto_city_{year}.csv"
    if not os.path.exists(raw_path):  # download once, then reuse the saved copy
        pd.read_csv(URL.format(sid=STATION_ID, year=year)).to_csv(raw_path, index=False)
    frames.append(pd.read_csv(raw_path))

w = pd.concat(frames)
# Keep only the columns we need and give them SQL-friendly names.
w = w.rename(columns={
    "Date/Time": "date",
    "Max Temp (°C)": "temp_max_c",
    "Min Temp (°C)": "temp_min_c",
    "Mean Temp (°C)": "temp_mean_c",
    "Total Rain (mm)": "rain_mm",
    "Total Snow (cm)": "snow_cm",
    "Total Precip (mm)": "precip_mm",
})[["date", "temp_max_c", "temp_min_c", "temp_mean_c", "rain_mm", "snow_cm", "precip_mm"]]
w["date"] = pd.to_datetime(w["date"])

# Report missing values instead of hiding them: some stations skip rain/snow splits.
print("Missing values per column:\n", w.isna().sum())
w.to_csv("data/clean/weather_daily.csv", index=False)
print(f"Saved {len(w)} days to data/clean/weather_daily.csv")
