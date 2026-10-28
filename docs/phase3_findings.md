# Phase 3 findings: waste, shortages and volunteers

**Data:** 88 program days (2023-2025), from `v_daily` in `meals.duckdb`.
**Queries:** `sql/04_demand_and_waste.sql`, `05_trends.sql`, `06_weather.sql`, `07_volunteers.sql`.

## How the comparison works

Demand depends on two things found in Phase 1: **day type** (Mon-Thu vs Fri-Sun) and whether it is one of the **last 10 program days**. Crossing them gives 4 segments, each with 12-34 days. Every number below compares days **within a segment**, never against an all-days average.

**Stockout days (7).** On these days served = made, so true demand was *at least* that number ("censored" data). They are left out of demand averages and studied on their own.

**"Low-turnout note" days (12).** The chef labelled these "rainy", but Phase 2 showed the label doesn't match real rain. We treat them as surprise slow days, cause unknown.

## 1. Normal demand per segment (stockout days left out)

| Segment | Days | Avg made | Median served | 90th pct served | Avg waste |
|---|---|---|---|---|---|
| Mon-Thu | 29 | 800 | 760 | 812 | 43 |
| Mon-Thu, last 10 | 18 | 954 | 916 | 948 | 82 |
| Fri-Sun | 22 | 1,222 | 1,053 | 1,144 | 206 |
| Fri-Sun, last 10 | 12 | 1,433 | 1,251 | 1,291 | 205 |

## 2. Where the waste comes from

- **Fri-Sun is 72% of all waste** (7,000 of 9,709 meals) on 42% of the days.
- **The 12 low-turnout note days are 38% of all waste** (305 wasted per day vs 80 on other days).
- **On ordinary days (no stockout, no note), Fri-Sun is still over-cooked by ~170-190 meals a day.** Mon-Thu is only ~30 over.

| Ordinary days | Avg made | Median served | Made above median |
|---|---|---|---|
| Mon-Thu | 799 | 770 | 29 |
| Mon-Thu, last 10 | 961 | 926 | 35 |
| Fri-Sun | 1,235 | 1,067 | 168 |
| Fri-Sun, last 10 | 1,437 | 1,251 | 186 |

So the kitchen's Fri-Sun plan is too high even when nothing unusual happens. That waste is avoidable without any forecasting.

## 3. Why the program ran out

All 7 stockouts were in regular days (none in the last 10), 4 on Mon-Thu and 3 on Fri-Sun. 5 of the 7 were prepped below that segment's median. The other 2 were within 10 meals of it (770 vs 760, 1,060 vs 1,053). **Every stockout day was prepped below the segment's 90th percentile.** Volunteers were not the cause: every stockout day had enough volunteers.

**Takeaway:** shortages come from prep that is *inconsistent* (Fri-Sun regular prep ranged from 970 to 1,370), not from demand spikes. The same segment both ran out and wasted 200+ meals on other days.

## 4. How far above normal do busy days go?

Served minus the segment median, ordinary busy days only:

| Segment | 75th pct above | 90th pct above | Most above |
|---|---|---|---|
| Mon-Thu | +28 | +52 | +72 |
| Mon-Thu, last 10 | +27 | +32 | +42 |
| Fri-Sun | +44 | +91 | +140 |
| Fri-Sun, last 10 | +36 | +40 | +50 |

These are the candidate buffers for Phase 4.

## 5. Trends

- **Year over year: flat.** Totals were 26.3k, 27.3k, 27.0k served, and the waste rate was 10.3%, 11.2%, 10.8%. Segment medians move by 0-90 meals with no consistent direction. With 3 years of data, **pool all years** and don't project a trend.
- **Across the program:** the last-10 jump is a sudden step (Mon-Thu median 754 in the middle vs 926 in the last 10; Fri-Sun 1,049 vs 1,251). The first 10 days ran slightly above the middle (790 vs 754 Mon-Thu), but only 8-14 days per group, so it's not strong enough to plan around.

## 6. Weather

- Phase 2 found real rain barely changes turnout. `06_weather.sql` adds a temperature check (correlation and temperature bands, compared within segment). **Pending:** it needs `weather_daily.csv`, which only exists on the Mac. Fill this in after running it.

## 7. Volunteers

- **The show-up rate is steady at ~87%** (85-89% across every year and day type).
- **Short-staffed days are mostly the same surprise slow days:** 10 of the 13 short-staffed days carry the low-turnout note. Show-up was 70% on those days vs 90% on ordinary days. Whatever kept guests away also kept volunteers away.
- Back-check: if sign-ups were fixed at N, with each day's real show-up rate, how many past days would have been short?

| Needed | Sign-ups | Short days |
|---|---|---|
| 12 (Mon-Thu) | 15 (about today's avg) | 7 of 51 |
| 12 | **16** | 5 of 51 |
| 12 | 17 | 3 of 51 |
| 17 (Fri-Sun) | 22 (about today's avg) | 6 of 37 |
| 17 | **23** | 4 of 37 |
| 17 | 24 | 1 of 37 |

## Answers to the decision questions (to be tested in Phase 4)

1. **Meals per day:** plan by segment, starting from the 90th percentile of past demand: about **810 Mon-Thu, 950 Mon-Thu last 10, 1,145 Fri-Sun, 1,290 Fri-Sun last 10**. That is about the same as today on Mon-Thu, but 80-140 fewer meals a day on Fri-Sun. Quick check on the 81 non-stockout days: waste would drop from 9,709 to about 6,700 (-31%). But 8 days would have run short by 128 meals in total, and the 7 stockout days can't be scored because their real demand is unknown. Phase 4 tests this properly, including smaller and bigger buffers.
2. **Buffer:** the 90th-percentile plan already builds in a buffer of +30 to +90 over the median, biggest on regular Fri-Sun. Every past stockout day was prepped below this level. Because demand on those days is censored, we can't prove the plan would have been enough, only that it would have put more food out.
3. **Sign-ups:** recruit **16 for Mon-Thu and 23 for Fri-Sun** (about 1 more than today). Most remaining short days are the surprise slow days, when fewer guests come anyway.

## Caveats

- 88 days, and segments of 12-34 days. Percentiles from 12 days are rough.
- Stockout demand is a floor, so true Mon-Thu and Fri-Sun regular demand may be slightly higher than shown.
- The volunteer back-check assumes the show-up rate wouldn't change with a different number of sign-ups.
- The low-turnout days can't be predicted from this data. They are the waste the plan can't remove.

## Questions for the program

- Were people turned away on stockout days, and was it recorded? That would show true demand.
- What happened on the 12 noted days that kept both guests and volunteers home?
- Do coordinators know volunteer no-shows before cooking starts? If so, a low show-up count could be an early warning to hold back part of the batch.
