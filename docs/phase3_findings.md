# Phase 3 findings: waste, shortages and volunteers

**Data:** 88 program days (2023-2025), from `v_daily` in `meals.duckdb`.
**Queries:** `sql/04_demand_and_waste.sql`, `05_trends.sql`, `06_weather.sql`, `07_volunteers.sql`.

## How we compared days

Demand in this data really comes down to two things we found in Phase 1: what kind of day it is (Mon-Thu vs Fri-Sun), and whether it's in the last 10 program days. Put those together and you get 4 groups, with 12 to 34 days in each. So every number below is compared inside its own group, not against some overall average that would mix busy weekends with quiet weekdays.

Two groups of days need handling separately. First, the 7 stockout days. On those days served equals made, so we only know demand was *at least* that high — the real demand is censored. We leave them out of the demand averages and look at them on their own. Second, the 12 "low-turnout note" days. The chef labelled these "rainy", but Phase 2 showed that label doesn't actually line up with real rain, so for now we're just treating them as surprise slow days, cause unknown.

## 1. Normal demand per group (stockout days left out)

| Segment | Days | Avg made | Median served | 90th pct served | Avg waste |
|---|---|---|---|---|---|
| Mon-Thu | 29 | 800 | 760 | 812 | 43 |
| Mon-Thu, last 10 | 18 | 954 | 916 | 948 | 82 |
| Fri-Sun | 22 | 1,222 | 1,053 | 1,144 | 206 |
| Fri-Sun, last 10 | 12 | 1,433 | 1,251 | 1,291 | 205 |

## 2. Where the waste is actually coming from

Fri-Sun is the big one here. It's 72% of all waste (7,000 out of 9,709 meals) on only 42% of the days.

The 12 low-turnout note days are also a huge chunk: 38% of all waste, at 305 wasted per day compared to 80 on other days.

But even if you take those note days out, Fri-Sun is still being overcooked. On ordinary days — no stockout, no note — Fri-Sun is about 170 to 190 meals over per day, while Mon-Thu is only about 30 over.

| Ordinary days | Avg made | Median served | Made above median |
|---|---|---|---|
| Mon-Thu | 799 | 770 | 29 |
| Mon-Thu, last 10 | 961 | 926 | 35 |
| Fri-Sun | 1,235 | 1,067 | 168 |
| Fri-Sun, last 10 | 1,437 | 1,251 | 186 |

In plain terms, the Fri-Sun plan is just too high even when nothing weird happens. That part of the waste could be cut without any forecasting at all.

## 3. Why the program ran out

All 7 stockouts happened on regular days, none in the last 10 — 4 on Mon-Thu and 3 on Fri-Sun. Five of the seven were prepped below that group's median. The other two were basically right at it, within 10 meals (770 vs 760, and 1,060 vs 1,053). And every single stockout day was prepped below the group's 90th percentile.

Volunteers weren't the problem here. Every stockout day had enough volunteers.

So shortages look less like demand suddenly spiking and more like prep being inconsistent. Fri-Sun regular prep ranged all the way from 970 to 1,370. The same group both ran out on some days and wasted 200+ meals on others.

## 4. How far above normal do busy days go?

This is served minus the group median, for ordinary busy days only:

| Segment | 75th pct above | 90th pct above | Most above |
|---|---|---|---|
| Mon-Thu | +28 | +52 | +72 |
| Mon-Thu, last 10 | +27 | +32 | +42 |
| Fri-Sun | +44 | +91 | +140 |
| Fri-Sun, last 10 | +36 | +40 | +50 |

These are the numbers we'll use as candidate buffers in Phase 4.

## 5. Trends

Year over year, it's basically flat. Totals served were 26.3k, 27.3k, and 27.0k, and the waste rate was 10.3%, 11.2%, and 10.8%. Group medians move by 0 to 90 meals with no consistent direction. With only 3 years to work with, it makes more sense to pool all the years together and not try to project a trend.

Across a single program, the last-10 jump is a sudden step, not a gradual climb — Mon-Thu median goes from 754 in the middle to 926 in the last 10, and Fri-Sun goes from 1,049 to 1,251. The first 10 days ran slightly above the middle (790 vs 754 Mon-Thu), but with only 8 to 14 days in each of those groups, that's not strong enough to actually plan around.

## 6. Weather

Phase 2 already found that real rain barely changes turnout. The `06_weather.sql` query adds a temperature check on top of that (correlation and temperature bands, compared within each group). That's still pending, because it needs `weather_daily.csv`, which only exists on the Mac right now. We'll fill this section in after running it.

## 7. Volunteers

The show-up rate is pretty steady at around 87% — 85 to 89% across every year and day type.

Short-staffed days are mostly the same surprise slow days we keep seeing: 10 of the 13 short-staffed days carry the low-turnout note. Show-up was 70% on those days vs 90% on ordinary days. Whatever kept guests away seems to have kept volunteers away too.

As a back-check, if sign-ups were fixed at a set number, and each day had its real show-up rate, how many past days would have been short?

| Needed | Sign-ups | Short days |
|---|---|---|
| 12 (Mon-Thu) | 15 (about today's avg) | 7 of 51 |
| 12 | **16** | 5 of 51 |
| 12 | 17 | 3 of 51 |
| 17 (Fri-Sun) | 22 (about today's avg) | 6 of 37 |
| 17 | **23** | 4 of 37 |
| 17 | 24 | 1 of 37 |

## Answers to the decision questions (to be tested properly in Phase 4)

1. **Meals per day:** plan by group, starting from the 90th percentile of past demand: about **810 Mon-Thu, 950 Mon-Thu last 10, 1,145 Fri-Sun, 1,290 Fri-Sun last 10**. That's roughly the same as today on Mon-Thu, but 80 to 140 fewer meals a day on Fri-Sun. A quick check on the 81 non-stockout days suggests waste would drop from 9,709 to about 6,700 (-31%). But 8 days would have run short by 128 meals in total, and the 7 stockout days can't be scored because their real demand is unknown. Phase 4 will test this properly, including smaller and bigger buffers.
2. **Buffer:** the 90th-percentile plan already builds in a buffer of +30 to +90 over the median, biggest on regular Fri-Sun. Every past stockout day was prepped below this level. Because demand on those days is censored, we can't prove the plan would have been enough — only that it would have put more food out.
3. **Sign-ups:** recruit **16 for Mon-Thu and 23 for Fri-Sun** (about 1 more than today). Most of the days that would still be short are the surprise slow days, when fewer guests come anyway.

## Caveats

- 88 days total, and groups of 12 to 34 days. Percentiles from 12 days are rough, so don't treat them as precise.
- Stockout demand is a floor, so true Mon-Thu and Fri-Sun regular demand may be slightly higher than what's shown here.
- The volunteer back-check assumes the show-up rate wouldn't change if you changed the number of sign-ups.
- The low-turnout days can't be predicted from this data. That's the waste this plan can't remove.

## Questions for the program

- Were people turned away on stockout days, and was that recorded anywhere? That would tell us true demand.
- What actually happened on those 12 noted days that kept both guests and volunteers home?
- Do coordinators know about volunteer no-shows before cooking starts? If so, a low show-up count could be an early warning to hold back part of the batch.
