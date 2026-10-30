# Phase 7: Real-World Test Plan

**Goal:** use the targets for one full program and find out whether the back-test holds up with real guests.
**Review query:** [sql/11_trial_review.sql](../sql/11_trial_review.sql)
**Nightly log:** [data/trial/nightly_log_template.csv](../data/trial/nightly_log_template.csv)

## What to cook and how many to sign up

| Kind of night | Cook (5% buffer) | Cook (8% buffer) | Sign-ups |
|---|---:|---:|---:|
| Monday to Thursday | 810 | 830 | 16 |
| Monday to Thursday, last 10 program days | 970 | 1,000 | 16 |
| Friday to Sunday | 1,120 | 1,150 | 24 |
| Friday to Sunday, last 10 program days | 1,310 | 1,350 | 24 |

Start at 5%. Three ground rules keep the trial a fair test:

- **Cook the target every night.** No changes for the weather forecast or a hunch. Weather had no link to turnout, and the whole point is to see what a steady amount does.
- **Keep about 30 quick backup meals** (frozen or simple to make) for nights that run close.
- **Don't cut the target after one slow night.** Slow nights can't be predicted, and the targets already leave them out.

## What to record each night

One person fills in one row per night. Everything except the last few columns is already being written down.

| Column | What to write |
|---|---|
| date | The program night |
| prep_target | The target from the table above (so we can tell if it changed) |
| meals_made, meals_served, leftover_waste | Same as now |
| ran_out | yes or no |
| ran_out_time | The time the last meal went out, if it ran out |
| **turned_away** | **New.** Once food runs out, one volunteer at the door counts everyone who arrives and doesn't get a meal, until normal closing time. A tally on paper is fine. |
| volunteers_needed, signed_up, showed | Same as now |
| **cancelled_same_day** | **New.** Volunteers who cancelled on the day itself. This tests whether late cancellations warn us about a slow night. |
| notes | Anything unusual: an event nearby, a snowstorm, a switch to 8% |

The turned-away count matters most. Up to now, a night that ran out only told us "at least this many people came". With the count, demand on those nights is about meals served plus people turned away, and we finally learn how short the kitchen really was.

## What counts as success

These come from the back-test of the 5% rule over 59 past days, scaled to a 30-night program.

| Measure | Back-test (5%) | Kitchen before | Trial passes if |
|---|---:|---:|---|
| Waste per night (nights that didn't run out) | 82 | 124 | Under 100 |
| Waste as % of meals cooked | 8% | 12% | Under 10% |
| Nights the food ran out, per 30 | about 2.5 | about 2.5 | 3 or fewer |
| Size of each shortfall | 10 to 52 meals | not counted | No night over 50 turned away |
| Short-staffed nights, per 30 | about 3 | about 4.5 | 3 or fewer |
| Nights cooked within 20 meals of target | | | At least 9 in 10 |

The last line is a check on the trial itself. If the kitchen often cooks something other than the target, the results say nothing about the rule.

## When to switch or stop

Running out costs someone a meal, and waste costs food. So the trial reacts quickly to shortages and waits until the end to judge waste.

- **Switch one kind of night to 8%** if it runs out twice, or runs out once with more than 50 people turned away.
- **Switch everything to 8%** if the food runs out 3 times in the first two weeks, or more than 100 people are turned away on any one night.
- **Stop the trial and go back to the chef's judgement** if a kind of night still runs out twice after moving to 8%. That would mean demand has changed and the targets need rebuilding.
- **Add 2 sign-ups** to Monday to Thursday or Friday to Sunday if it is short-staffed on 2 nights that weren't slow.
- **Never lower a target during the program.** If waste looks high, that's a question for the review.

Write every switch in the notes column and change prep_target from that night on, so the review knows which buffer each night used.

## Comparing with the back-test

After the program, save the log as `data/trial/nightly_log.csv` and run:

```bash
duckdb meals.duckdb < sql/11_trial_review.sql
```

It answers four questions in order:

1. **Did the kitchen cook the targets?** Average cooked against target for each kind of night.
2. **Was normal demand where we expected?** The median demand on ordinary nights next to the numbers the targets came from. Within about 5% means the targets still fit. Further off means rebuild them before the next program.
3. **How did the trial score?** One table with the trial next to the old kitchen results and the 5% and 8% back-tests, on waste per night, waste %, nights run out and people turned away.
4. **How short was each night that ran out?** Every ran-out night with its turned-away count, and a volunteer summary with the show-up rate and same-day cancellations.

It also saves `data/trial/trial_review_daily.csv`, one row per night, if we want to add a trial page to the dashboard.

## How to read the result

- **Waste down and shortages small:** keep the rule. Add the trial nights to the history and rebuild the targets with [sql/08_backtest_prep.sql](../sql/08_backtest_prep.sql) before the next program.
- **Waste down but shortfalls over 50:** move to 8% for the kinds of night that ran out.
- **Waste no better than before:** check the first question. Usually that means the targets weren't followed, or a lot of slow nights.
- **Show-up rate much lower than 87%:** asking for more people may mean each one is less likely to come, which the back-test assumed wouldn't happen.

## Limits

One program is about 30 nights. With so few nights, 2 or 3 ran-out nights can happen by luck, so the size of each shortfall says more than the count. The slow nights will still waste around 300 meals each, whatever the targets are. This trial won't fix that, but the notes and cancellation counts may give the first clue about what causes them.
