# Phase 4: back-testing the prep rule and the sign-up rule

**Queries:** `sql/08_backtest_prep.sql` (meals), `sql/09_backtest_signups.sql` (volunteers).
**Output for Tableau:** `data/clean/backtest_tradeoff.csv`.

## The question

Phase 3 suggested cooking by segment instead of the chef's current amounts. A back-test asks: **if the kitchen had used that rule on past days, would it have wasted less without running out more often?**

## How the test works

**The rule:** prep = normal demand for the segment + a buffer of X%, rounded to the nearest 10.
- *Segment* = Mon-Thu or Fri-Sun, crossed with "last 10 program days" (4 segments, as in Phase 3).
- *Normal demand* = the median meals served on past **ordinary** days (no stockout, no low-turnout note).

**Why ordinary days only:** the plan is for a normal day. The low-turnout days can't be predicted (Phase 2-3), so letting them into the median pulls the forecast down and makes the kitchen run short on normal days. Stockout days are left out because their "served" number is only a floor. Both kinds of day are still scored in the test.

**Out-of-sample:** the rule only gets to see years *before* the one it's tested on, like a real kitchen planning ahead.
- 2024 is tested with a rule built from 2023.
- 2025 is tested with a rule built from 2023 + 2024.
- 2023 has nothing before it, so it's not tested. That leaves **59 test days**.

**Scoring each test day:**
- **Ordinary or low-turnout day:** real demand = meals served, so we know exactly what would have happened. Waste = prep minus demand, or short = demand minus prep.
- **Stockout day (5 in the test years):** real demand is unknown, only "at least what the chef made". If the plan cooked *less or the same*, it would surely have run out too. If it cooked *more*, we can't tell whether that was enough, so it is counted as **unknown**, not as a win.

The chef's real results on the same 59 days are scored the same way. Their 5 stockouts count as 5 short days.

## Result 1: the trade-off

| Plan | Meals cooked | Waste | Waste vs chef | Short days | Meals short | Unknown |
|---|---|---|---|---|---|---|
| **Chef (actual)** | 60,960 | 6,698 | | 5 (stockouts) | not recorded | |
| Median + 0% | 56,200 | 2,611 | -61% | 26 | 833 | 4 |
| Median + 3% | 57,950 | 3,651 | -45% | 14 | 263 | 5 |
| **Median + 5%** | 58,900 | 4,413 | **-34%** | **5** | **135** | 5 |
| Median + 8% | 60,690 | 5,950 | -11% | 1 | 12 | 5 |
| Median + 10% | 61,850 | 7,008 | +5% | 0 | 0 | 5 |
| Median + 15% | 64,660 | 9,608 | +43% | 0 | 0 | 5 |
| p90 (Phase 3 draft) | 58,770 | 4,241 | -37% | 9 | 233 | 5 |

Waste is counted on the 54 non-stockout test days, since waste on a stockout day is unknown.

**How to read it:** each extra % of buffer buys fewer short days and costs more waste. With no buffer the kitchen runs short on almost half the days. Around +5% the curve bends: shortages fall to the chef's level while waste is still a third lower. Past +10% the plan wastes more than the chef does today.

**Median + 5% is the recommended rule:**
- **34% less waste** (about 2,300 meals fewer over 59 days, ~39 a day).
- **Same number of short days as the chef (5)**, and those were small: 10 to 52 meals short, ~27 on average, about 1-4% of that day's demand.
- **On all 5 of the chef's stockout days the plan would have cooked 20-120 more meals.** We can't prove that was enough, but it's more food on exactly the days that ran out.
- **Steady across years:** -35% waste in 2024 and -33% in 2025.

**Median + 8% is the safety-first option:** 1 short day (12 meals) in 59, but only 11% less waste. Which one to pick is a values call for the program: how bad is running ~30 meals short, versus throwing out ~770 more meals a year? If the kitchen can keep a small backup (e.g. ~30 quick meals), +5% is the better fit.

**Phase 3's p90 draft** wastes about the same as +5% but runs short 9 times. It was pulled down by the low-turnout days, which is why this phase builds the forecast from ordinary days.

## Result 2: where the savings come from

Median + 5% vs the chef, by segment (59 test days):

| Segment | Days | Chef avg prep | Plan avg prep | Chef waste | Plan waste | Plan short days |
|---|---|---|---|---|---|---|
| Fri-Sun | 16 | 1,220 | 1,135 | 2,791 | 1,449 | 3 |
| Fri-Sun, last 10 | 9 | 1,437 | 1,310 | 1,922 | 782 | 0 |
| Mon-Thu | 23 | 785 | 790 | 770 | 637 | 2 |
| Mon-Thu, last 10 | 11 | 950 | 980 | 1,215 | 1,545 | 0 |

- **All of the savings are on Fri-Sun.** The plan cooks ~85-130 fewer meals a day there and halves the waste. This matches Phase 3: the chef over-cooks Fri-Sun.
- **Mon-Thu is a tie.** The chef already cooks close to normal demand there. The plan's main gain on regular Mon-Thu is consistency: it cooks 790 every day instead of anything from 670 to 860, which is where the chef's 4 Mon-Thu stockouts came from.
- **On Mon-Thu in the last 10 days the chef did better** (1,215 vs 1,545 waste, no stockouts either way). The chef's ~2-3% margin there worked. The rule's +5% is a little generous for that segment.
- **The low-turnout days waste the same under any plan** (2,316 plan vs 2,346 chef). No forecast sees them coming, so they are waste the rule can't remove. On ordinary days, waste drops by half (4,352 to 2,097).

## Result 3: prep targets for the next program

Built from all 3 years of ordinary days:

| Segment | Normal demand (median) | Prep at +5% | Prep at +8% |
|---|---|---|---|
| Mon-Thu | 770 | **810** | 830 |
| Mon-Thu, last 10 | 926 | **970** | 1,000 |
| Fri-Sun | 1,067 | **1,120** | 1,150 |
| Fri-Sun, last 10 | 1,251 | **1,310** | 1,350 |

Practical version: **cook ~810 Mon-Thu, ~1,120 Fri-Sun, and step up to ~970 / ~1,310 for the last 10 program days.** Mon-Thu in the last 10 days can stay at the chef's usual ~950 if they prefer, since the back-test showed that works.

## Result 4: the sign-up rule

**The rule:** sign-ups = volunteers needed / a cautious show-up rate, rounded up. "Cautious" = a low percentile of past show-up rates. Tested out-of-sample the same way (59 days). Each day keeps its real show-up rate, and we ask how many people would have come if N had signed up.

| Plan | Sign-ups asked (Mon-Thu / Fri-Sun) | Short days | Short on ordinary days | People short in total |
|---|---|---|---|---|
| Actual | ~15 / ~21 (varied) | 9 | 3 | 13 |
| p25 rule | 14 / 22 | 10 | 2 | 18 |
| **p10 rule** | 15 / 24 | **6** | **1** | 10 |
| Fixed 16 / 23 (Phase 3 draft) | 16 / 23 | 6 | 0 | 7 |

- **The p25 rule is too thin:** it asks for fewer people than the program already gets and does no better.
- **The p10 rule (plan for a 1-in-10 bad day) cuts short days by a third** and nearly removes short days when guests came as normal. It costs ~1 extra sign-up a day.
- **Phase 3's 16 / 23 did as well**, which confirms it. But 16 / 23 was picked by looking at all 3 years, so it had an unfair head start. The p10 rule reached the same range without peeking.
- **Built from all 3 years, the p10 rule says 16 Mon-Thu and 24 Fri-Sun.** That's the recommendation. 23 on Fri-Sun is a fair choice if recruiting is hard, since it tested the same on past days.
- The remaining short days are almost all low-turnout days, when fewer guests come anyway.

## Answers to the decision questions

1. **How many meals a day?** Normal demand for the segment + 5%: about **810 Mon-Thu, 1,120 Fri-Sun, 970 / 1,310 in the last 10 program days**. On past days this would have cut waste by about a third with no more shortage days than today.
2. **What buffer?** **5%** (about 40-60 meals). 3% runs short too often, 10% wastes more than today. Use 8% if any shortage is unacceptable.
3. **How many sign-ups?** **16 Mon-Thu and 24 Fri-Sun.**

## Caveats

- **Small training sets.** The 2024 test used only 3-9 days of 2023 per segment. The rule still did well, but the numbers are rough.
- **Censored days stay unknown.** On the 5 stockout days, the plan would have cooked more, but we can't prove it would have been enough.
- **"Short" in the back-test means even 10 meals short.** The chef's stockouts are "ran out early" days of unknown size. So 5 plan short days vs 5 chef stockouts is a fair-to-cautious comparison, not a perfect one.
- **The volunteer test assumes the show-up rate doesn't depend on how many sign up.** In real life a bigger list might mean a slightly lower rate.
- **2 years of tests, 59 days.** Good enough to compare rules, not to promise an exact saving. Phase 7 sets up a real-world test.
