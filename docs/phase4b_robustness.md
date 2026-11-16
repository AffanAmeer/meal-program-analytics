# Phase 4b: how much should we trust the back-test?

**Script:** `scripts/04_robustness.py` (pandas, written separately from the SQL so the two check each other).
**Output:** `data/clean/robustness_checks.csv`.
**Tests:** `tests/test_headline_figures.py` recomputes every number in the README and memo from the raw file.

## Does the second calculation agree?

Yes. Rebuilding the back-test in pandas gives the same waste and short days as `sql/08_backtest_prep.sql` for every buffer from 0% to 15%. A test also changes every 2025 number and checks that the 2025 plan doesn't move, which confirms the rule only learns from earlier years.

## Where the 34% could be too rosy

The back-test itself only uses past years. But some choices (the four segments, leaving out slow days, the 5% buffer) were made after looking at all three years, including the two test years. That can make a result look better than it really is, so I checked each one.

| Check | Result | What it means |
|---|---:|---|
| Headline: median + 5% vs the kitchen | **-34%** waste (6,698 to 4,413) | Reproduced exactly |
| Worst case for the 5 days the kitchen ran out | **-29%** | Those days are left out of the waste total. If every extra meal the plan cooked on them had been thrown out, the cut is still 29%. |
| Buffer picked on 2024 only, then tested on 2025 | 5% picked, **-33%** in 2025 | Choosing the buffer while seeing the test years didn't change the answer. |
| Slow days kept in the median | -42% waste but **9 short days** | Leaving slow days out costs some waste but avoids running short. This backs up the choice. |
| Bootstrap over the 54 test days (10,000 resamples) | **-21% to -48%** (95% range) | With only 54 days, the true saving could be anywhere in this range. |

## The short-day comparison, stated carefully

The plan ran short on **5 days for certain** (10 to 52 meals each), the same count as the kitchen's 5 stockouts. On those 5 stockout days the plan would have cooked 20 to 120 more meals than the kitchen, but nobody counted the people turned away, so whether that was enough is **unknown**. So the fair summary is "5 confirmed short days, plus 5 days where the outcome can't be known", not "no more shortages than today".

## One more assumption

The "last 10 program days" segment needs the program's end date to be known when planning. If the end date can shift by a day, the first "last 10" day could get the lower target.

## Bottom line

The 34% cut holds up under every check, and a careful range is **about 20% to 50%**, with 29% to 34% the most likely span. Say "about a third" or "roughly 30%", and always call it a back-test on past records, not a measured result.
