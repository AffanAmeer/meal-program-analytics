# Meal Program Analytics

**Turning three years of meal records into cooking and volunteer targets a kitchen can actually use.**

**Live dashboard:** [Meal Program Planning on Tableau Public](https://public.tableau.com/app/profile/affan.ameer/viz/MealProgramPlanning/Dashboard1)  
**Decision memo:** [docs/decision_memo.md](docs/decision_memo.md)  
**Real-world test plan:** [docs/phase7_test_plan.md](docs/phase7_test_plan.md)

## Overview

A community meal program serves 800 to 1,400 dinners a night for about a month each year, and volunteers run it. Over three years, about 1 in 10 meals ended up in the bin. Even so, the kitchen ran out of food on 7 nights.

I used the program's daily records to answer three questions: how much food to cook, how much extra to keep as a buffer, and how many volunteers to sign up. Then I tested the answers on past years, using only the data the kitchen would have had at the time.

## Results at a glance

| Question | Answer |
|---|---|
| How much should we cook? | About 810 meals Monday to Thursday and 1,120 Friday to Sunday. In the last 10 program days, go up to about 970 and 1,310. |
| How much extra should we make? | 5% on top of a normal day, which is about 40 to 60 meals. Use 8% if running short is the bigger worry. |
| How many volunteers should sign up? | 16 Monday to Thursday and 24 Friday to Sunday. |

**How the cooking target is worked out:** the days are split into four groups (Monday to Thursday or Friday to Sunday, and inside or outside the last 10 program days). For each group, take the median meals served on past ordinary days, multiply by 1.05 (or 1.08), and round to the nearest 10. "Ordinary" means the food didn't run out and the day wasn't one of the unexplained slow days.

### What the back-test showed

Over 59 days in 2024 and 2025, the 5% rule would have cut waste by 34%, from 6,698 meals to 4,413. It would have run short on 5 days, the same number of times the kitchen actually ran out, and each of those shortfalls was small (10 to 52 meals).

The volunteer rule would have cut short-staffed days from 9 to 6.

These are results on past data, not a promise. The next step is to try the targets in a real program and see what happens, which is what the [test plan](docs/phase7_test_plan.md) sets up.

## What I found

**1. Most of the waste happens Friday to Sunday.**
Those days are 42% of the program but 72% of the waste. Even on a normal Friday to Sunday, the kitchen cooked about 170 to 190 more meals than people ate.

**2. The kitchen ran out on days it cooked less than usual.**
On all 7 days the food ran out, the kitchen had cooked less than it normally did for that kind of day. So the problem was uneven cooking, not sudden crowds.

**3. The chef's "rainy" notes weren't really about rain.**
Only 4 of the 12 "rainy" days had real rain (1 mm or more), and 7 had none at all. Days that actually were wet were just as busy as dry ones. The notes seem to mark slow days with no clear cause. Those days make up 38% of all waste, and nothing in the data predicts them.

**4. Weather and the year don't change much.**
Temperature and rain had almost no link to how many people came. Demand also stayed about the same from 2023 to 2025, so the targets don't adjust for either.

**5. Volunteers mostly show up, except on the slow days.**
About 87% of people who sign up come. But 10 of the 13 short-staffed days were the same unexplained slow days, when fewer guests came too.

## How I built it

| Phase | What I did | Where to look |
|---|---|---|
| 1. Data quality | Checked the 88 rows and 8 columns, flagged the days the food ran out and the last 10 program days, and logged every change. The raw file is never edited. | [scripts](scripts/), [cleaning log](data/clean/cleaning_log.csv) |
| 2. Data model | Built a DuckDB database with a daily table, a calendar table and a weather table from Environment Canada. Checked the "rainy" notes against real rainfall. | [sql](sql/), [rainy label test](docs/phase2_rainy_label_test.md) |
| 3. Analysis | Compared days only within their own group of four, so a quiet Tuesday is never judged against a busy Saturday. Looked at waste, shortages, trends, weather and volunteers. | [sql](sql/), [Phase 3 findings](docs/phase3_findings.md) |
| 4. Back-test | Tried the median plus buffers from 0% to 15%. Each year was tested using only earlier years: 2024 from 2023, and 2025 from 2023 and 2024. | [Phase 4 back-test](docs/phase4_backtest.md), [back-test results](data/clean/) |
| 5. Dashboard | Exported five small tables from SQL and built a one-page Tableau dashboard, one row per question. | [dashboard tables](data/tableau/), [Tableau guide](docs/phase5_tableau_guide.md) |
| 6. Memo | Wrote up the targets and the waste vs. shortage trade-off for the program lead. | [Decision memo](docs/decision_memo.md) |
| 7. Test plan | Planned a one-program trial of the targets: what to record each night (including people turned away when food runs out), what counts as success, when to switch to 8%, and a SQL file that compares the trial with the back-test. | [Phase 7 test plan](docs/phase7_test_plan.md), [nightly log](data/trial/nightly_log_template.csv) |

## Choices I made and why

**Days the food ran out don't count toward normal demand.**
When the food runs out, "meals served" only tells you how much food there was, not how many people wanted a meal. So those days are left out of the targets. In the back-test, if a plan cooked the same or less than the kitchen on one of those days, it counts as short. If it cooked more, it's marked "unknown", because we can't tell whether that would have been enough.

**The slow days are left out of the targets but kept in the test.**
A few very slow days drag the median down, and then the kitchen runs short on normal days. So the targets are built from ordinary days only, but every day, slow ones included, is used to score the rules.

**Weather was tested, not assumed.**
Temperature and rain had almost no link to turnout, so adding a weather adjustment would only make the plan more complicated.

**Each test year only sees the years before it.**
The 2024 targets come from 2023, and the 2025 targets from 2023 and 2024. A rule that has already seen the answers will always look better than it really is.

**Both 5% and 8% are shown.**
A smaller buffer wastes less, and a bigger one runs short less often. Which matters more is up to the program, so the memo and dashboard give both.

**All the numbers come from SQL.**
Tableau only draws what SQL exports, so the dashboard always matches the write-ups.

## Repository structure

```text
data/
  raw/                  Original meal records and weather downloads
  clean/                Cleaned data, cleaning log, back-test results
  tableau/              Five dashboard tables (dash_*.csv)
  trial/                Nightly log template for the real-world trial

scripts/                Python: first look, cleaning, weather download
sql/                    DuckDB: model, analysis, back-test, exports
docs/                   Findings for each phase, Tableau guide, decision memo
```

## How to reproduce

You need Python 3 with pandas, and the DuckDB command line tool. Run everything from the project folder.

### 1. Prepare the data

```bash
python3 scripts/01_first_look.py   # optional data quality checks
python3 scripts/02_clean.py        # clean the data and write the cleaning log
python3 scripts/03_get_weather.py  # download weather (reuses saved files)
```

### 2. Build the model and run the analysis

```bash
duckdb meals.duckdb < sql/02_build_model.sql
duckdb meals.duckdb < sql/04_demand_and_waste.sql
```

The second command creates the v_analysis view that the later files need.

### 3. Run the back-tests

```bash
duckdb meals.duckdb < sql/08_backtest_prep.sql
duckdb meals.duckdb < sql/09_backtest_signups.sql
```

### 4. Export the dashboard data

```bash
mkdir -p data/tableau
duckdb meals.duckdb < sql/10_tableau_exports.sql
```

SQL files 01, 03, 05, 06 and 07 are exploration queries. Run them after 04 to see the numbers behind the Phase 2 and Phase 3 findings.

### 5. After a real trial (optional)

Save the filled-in log as data/trial/nightly_log.csv, then run:

```bash
duckdb meals.duckdb < sql/11_trial_review.sql
```

## Tools

- **Python (pandas):** checking, cleaning and downloading the data
- **SQL (DuckDB):** the data model, the analysis, the back-tests and the dashboard exports
- **Tableau Public:** the one-page dashboard
- **Git and GitHub:** version control for the code, outputs and write-ups

## Limitations and next steps

- It's only 88 program days over three years, and each group has 12 to 34 days, so the targets are estimates, not exact numbers.
- On days the food ran out, nobody counted the people turned away, so real demand on those days is unknown.
- The slow days can't be predicted from this data, so their waste stays no matter which rule is used.
- The volunteer test assumes the same share of people show up when more sign up.
- The rules have only been tested on past records, not in a live program yet.

**Next step:** try the targets for one program, count the people turned away when food runs out, and compare the real waste and staffing with the back-test. The [test plan](docs/phase7_test_plan.md) covers how.
