# Phase 5: the Tableau Public dashboard

**Live dashboard:** https://public.tableau.com/app/profile/affan.ameer/viz/MealProgramPlanning/Dashboard1

**Goal:** one page a program lead can read in 30 seconds that answers the 3 decision questions:
1. How many meals should we cook each day?
2. How big a buffer, and what does it cost?
3. How many volunteers should we sign up?

**Data for Tableau:** `sql/10_tableau_exports.sql` writes 5 small CSVs to `data/tableau/`.
`sql/08` and `sql/09` now also save their day-by-day back-test scores (`data/clean/backtest_daily.csv`, `data/clean/backtest_signups_daily.csv`), which `10` uses.

| File | Rows | One row per | Used in |
|---|---|---|---|
| `dash_daily.csv` | 88 | program day | Sheet 1: demand by segment |
| `dash_segments.csv` | 8 | segment x plan (chef / +5%) | Sheet 2: where waste is saved |
| `dash_tradeoff.csv` | 8 | prep plan | Sheet 3: buffer trade-off |
| `dash_signups.csv` | 8 | sign-up plan x day type | Sheet 4: volunteer short days |
| `dash_targets.csv` | 4 | segment | Sheet 5: the answer card |

---

## Step 0. Check Tableau Public is installed

In Terminal:

```bash
ls /Applications | grep -i tableau
```

- If it prints something like `Tableau Public 2025.x.app`, you're set.
- If it prints nothing: go to **public.tableau.com**, sign up (free), click **Create > Download the app** (Tableau Public Desktop), open the `.dmg` and drag it into Applications. Then open it once and sign in.

## Step 1. Make the CSVs (Terminal)

```bash
cd ~/Downloads/meal-program-analytics        # go to the project folder (do this in every new window)
mkdir -p data/tableau                        # make the folder the dashboard files go in
duckdb meals.duckdb < sql/08_backtest_prep.sql      # re-run Phase 4 prep test; also saves backtest_daily.csv
duckdb meals.duckdb < sql/09_backtest_signups.sql   # re-run sign-up test; also saves backtest_signups_daily.csv
duckdb meals.duckdb < sql/10_tableau_exports.sql    # build the 5 dashboard CSVs
ls data/tableau                              # should list the 5 dash_*.csv files
```

The last query in `10` prints row counts. Expect **88, 8, 8, 8, 4**.

## Step 2. Connect the data (Tableau)

Each CSV is its own data source. Don't join them: they are at different levels (a day, a plan, a segment), and joining would repeat rows and inflate sums.

1. Open Tableau Public. Under **Connect > To a File**, click **Text file**. Pick `data/tableau/dash_daily.csv`.
2. On the Data Source page, check the preview: Date shows a calendar icon, Last10 and Volunteers Short show T|F. Good.
3. Click **Sheet 1** at the bottom.
4. For each of the other 4 files: top menu **Data > New Data Source > Text file**, pick the file. You'll see all 5 in the Data pane top-left. Click one to switch which file a sheet uses.

Tableau tidies the names (`meals_served` becomes **Meals Served**). The steps below use those names.

> If a number column lands under *Dimensions* (above the grey line) instead of *Measures*, right-click it > **Convert to Measure**. If **Program Day** or **Buffer Pct** lands under Measures, that's fine.

## Step 3. Build the 5 sheets

Rename each sheet by double-clicking its tab at the bottom.

### Sheet 1 "Demand by segment" (data: dash_daily)

Shows every day's real demand, grouped by segment, with the recommended prep as a line.

1. Drag **Segment** to **Columns**. Drag **Meals Served** to **Rows**.
2. Tableau draws one bar per segment (a SUM). We want every day as a dot: top menu **Analysis**, untick **Aggregate Measures**.
3. Marks card: change **Automatic** to **Circle**.
4. Drag **Day Status** to **Color**. Click Color > **Edit Colors**: Ordinary day = grey, Low-turnout day = orange, Ran out early = red. Set **Opacity** to ~70% so overlapping dots show.
5. Add the target line: click the **Analytics** tab (next to Data, top-left). Drag **Reference Line** onto the chart and drop it on **Per Cell**. Value: **Prep Target**, Average. Label: **Custom**, type `Cook <Value>`. Line: solid, dark blue.
6. Drag **Date**, **Meals Made** and **Leftover Waste** to **Tooltip** so hovering a dot tells the full story. Right-click Date on the Tooltip > **Exact Date**.
7. Right-click the y-axis > **Edit Axis** > title `Meals served (red dots = ran out, so real demand was higher)`.

*How to read it:* the line sits just above the cloud of grey (ordinary) dots in each segment. Orange dots far below are the low-turnout days no forecast can see. Red dots are floors, not true demand.

### Sheet 2 "Where the waste is saved" (data: dash_segments)

1. Drag **Segment** to **Columns**, then **Plan** to Columns (to the right of Segment).
2. Drag **Waste** to **Rows**. You get pairs of bars, chef vs recommended, per segment.
3. Drag **Plan** to **Color**: Chef today = grey, Recommended (+5%) = blue.
4. Drag **Waste** to **Label** to print the totals on the bars.
5. Drag **Avg Prep**, **Short Days**, **Test Days** to **Tooltip**.
6. Right-click the **Plan** header above the bars > **Hide Field Labels for Columns**, and hide the Plan header too (right-click > untick **Show Header**) since colour already says it.
7. Y-axis title: `Meals wasted on test days (2024-25)`.

*How to read it:* the gap is all on Fri-Sun. Mon-Thu is a tie, and Mon-Thu last 10 is slightly worse under the plan.

### Sheet 3 "Buffer trade-off" (data: dash_tradeoff)

1. Drag **Short Days** to **Columns**, **Total Waste** to **Rows**.
2. If Tableau shows one dot (a SUM of everything), drag **Plan** to **Detail** so you get one dot per plan.
3. Marks: **Circle**. Drag **Role** to **Color**: Recommended = blue, Safety-first option = light blue, Chef today = grey (dark), Other plans = light grey.
4. Drag **Label** (the field) to **Label** on the Marks card.
5. Drag **Waste Vs Chef Pct**, **Meals Short**, **Buffer Pct** to **Tooltip**.
6. Axis titles: x = `Days the plan would have run short (of 59)`, y = `Meals wasted (54 non-stockout test days)`.
7. Optional: Analytics tab > **Reference Line** on the y-axis, Entire Table, value = a constant `6698`, label `Chef's waste today`. Anything above that line wastes more than today.

*How to read it:* down and to the left is better. Plans fall along a curve: less waste costs more short days. +5% is the bend: chef-level short days (5) with 34% less waste.

### Sheet 4 "Volunteer sign-ups" (data: dash_signups)

1. Drag **Plan** to **Rows**, **Short Days** to **Columns**. Horizontal bars.
2. Drag **Day Type** to **Color** (stacked: Mon-Thu + Fri-Sun = all short days).
3. Click **Plan** on Rows > **Sort** > by field **Short Days**, Sum, ascending.
4. Drag **Avg Signups** and **Short Days Ordinary** to **Tooltip**.
5. Right-click the plan names > **Edit Alias** to make them readable: actual = `Today (~15 / ~21)`, p10 rule = `Recommended: p10 rule (15 / 24)`, p25 rule = `p25 rule (14 / 22)`, fixed 16 / 23 = `Fixed 16 / 23`.
6. X-axis title: `Days with too few volunteers (of 59)`.

*How to read it:* the p10 rule takes short days from 9 to 6 for about one extra sign-up a day.

### Sheet 5 "Plan for next program" (data: dash_targets)

A small table: the answer card.

1. Drag **Segment** to **Rows**.
2. Drag **Prep Target** onto the chart area (the big empty space). It becomes a text table.
3. Drag **Prep Target 8Pct** and **Signups Target** onto the same area, onto the column header, so they sit side by side. (Tableau puts **Measure Names** on Columns and **Measure Values** on Text.)
4. Rename the column headers: in the Data pane, right-click each field > **Rename**: Prep Target = `Meals to cook (+5%)`, Prep Target 8Pct = `Safety-first (+8%)`, Signups Target = `Sign-ups to ask for`.
5. Format numbers: right-click **Measure Values** on the Marks card > **Format** > Numbers: Number (Custom), 0 decimals.
6. Make it big: **Format > Font** > worksheet font 14, bold the first column.

## Step 4. Assemble the dashboard

1. Bottom bar: click the **New Dashboard** icon (the middle icon, a grid).
2. Left panel **Size**: Fixed size, **1200 x 1100**.
3. Drag **Text** objects (left panel, **Objects**) and the sheets in this order. Drop each one under the last so they stack:

```
+------------------------------------------------------------+
| TITLE  + one-line summary (Text object)                    |
+------------------------------------------------------------+
| 1. How many meals a day?                                   |
| [Sheet 5 Plan for next program]  [Sheet 1 Demand by seg.]  |
+------------------------------------------------------------+
| 2. How big a buffer?                                       |
| [Sheet 3 Buffer trade-off]       [Sheet 2 Waste saved]     |
+------------------------------------------------------------+
| 3. How many volunteers?                                    |
| [Sheet 4 Volunteer sign-ups]     [Text: what it means]     |
+------------------------------------------------------------+
| Footnote: method + data (Text object)                      |
+------------------------------------------------------------+
```

To put two things side by side, drop the second one on the **right edge** of the first (a grey box shows where it will land). Leave **Show dashboard title** unticked (we write our own title as a Text object).

4. Hide legends you don't need: Tableau adds a legend for each Color. Keep Day Status (sheet 1) and Role (sheet 3). Click the others > **x**.

**Text to paste:**

- **Title:** `How much to cook, and how many volunteers to sign up`
- **Summary line:** `Back-tested on 59 program days (2024-25): cooking normal demand + 5% would have cut waste by 34% with the same number of short days as today. Sign up 16 volunteers Mon-Thu and 24 Fri-Sun.`
- **Section 1 header:** `1. How many meals a day? Cook the segment's normal demand + 5%.`
- **Section 2 header:** `2. How big a buffer? 5%: less waste than today, same short days. Use 8% if any shortage is unacceptable.`
- **Section 3 header:** `3. How many volunteers? Plan for a 1-in-10 bad show-up day: 16 Mon-Thu, 24 Fri-Sun.`
- **Section 3 side text:** `Sign-ups = volunteers needed / the 10th-percentile show-up rate, rounded up. On past days this cut short-staffed days from 9 to 6 for about one extra sign-up a day. Most remaining short days were low-turnout days, when fewer guests came anyway.`
- **Footnote:** `Data: 88 program days over 3 years. "Normal demand" = median meals served on ordinary days (no stockout, no low-turnout note). Back-test is out-of-sample: 2024 judged with a rule built from 2023, 2025 with 2023-24. On days the kitchen ran out, real demand is unknown, so those days are scored cautiously. Source and SQL: github.com/AffanAmeer/meal-program-analytics`

## Step 5. Publish and save

Tableau Public saves to the web, so everything you publish is public. The data here is just meal and volunteer counts, so that's fine for a portfolio.

1. **File > Save to Tableau Public As...** Sign in. Name: `Meal Program Planning`.
2. Your browser opens the published page. Check the layout looks the same as on your Mac.
3. On that page, click the settings (gear) and make sure **Allow access/download** is on if you want recruiters to see the workbook.
4. Click **Download** (bottom toolbar) > **Tableau Workbook** to get a `.twbx`. Move it to `~/Downloads/meal-program-analytics/tableau/meal_program_planning.twbx` (make the folder with `mkdir -p tableau` first).
5. Copy the page's URL. Send it to me and I'll add it to the README in Phase 6.

## Step 6. Push to GitHub (Terminal)

```bash
cd ~/Downloads/meal-program-analytics
git status                                # see what's new
git add sql/08_backtest_prep.sql sql/09_backtest_signups.sql sql/10_tableau_exports.sql \
        data/clean/backtest_daily.csv data/clean/backtest_signups_daily.csv \
        data/tableau docs/phase5_tableau_guide.md tableau
git commit -m "Phase 5: Tableau exports and dashboard"
git push
```

If you haven't downloaded the `.twbx` yet, drop `tableau` from the `git add` line.

---

## How to explain it in an interview

- **Why export CSVs from SQL instead of doing the maths in Tableau?** Tableau Public can only read files, not our DuckDB database. And keeping all the numbers in SQL means they live in one place that's version-controlled and checkable. Tableau's only job is to draw them. The dashboard numbers match the Phase 4 tables exactly.
- **Why 5 small files, not one big one?** Each chart is at a different level: a day, a plan, a segment. Mixing levels in one table forces repeated rows, and then a SUM in Tableau double-counts. One file per level keeps every SUM honest.
- **Why "long" tables?** One row per thing to draw (e.g. one row per segment *and* plan). Then a chart is "drag Plan to Color, Waste to Rows", with no reshaping in Tableau.
- **Why dots, not an average bar, in sheet 1?** An average hides the story. The dots show the cloud of normal days the target sits just above, the low-turnout outliers that cause unavoidable waste, and the stockout days whose numbers are floors.
- **Why a scatter for the buffer question?** The question is a trade-off between two costs, waste and shortages. A scatter puts one on each axis, so the "bend" where extra buffer stops paying off is visible at a glance.
- **How were stockout days handled in the trade-off?** Waste is only counted on the 54 non-stockout test days, since waste on a stockout day is unknown. A plan that cooked less than the chef on a stockout day counts as short for sure. One that cooked more is "unknown", not a win.
- **Why does Mon-Thu last 10 look worse under the plan?** The chef cooks with a ~2-3% margin there and it worked. The +5% rule is a little generous for that one segment. We show it rather than hide it, and the memo can say the kitchen may keep its usual ~950 there.
- **Why do some Fri-Sun days sit above the "Cook 1,120" line?** On purpose. The rule cooks for a typical day + 5%, not the busiest day ever. In the back-test that cost 3 short Fri-Sun days (small ones) and halved Fri-Sun waste. Cooking for the busiest day would bring back the over-prep we're trying to remove.
- **Why are the orange dots so far below every line?** Those are the low-turnout days. Nothing in the data (weather, weekday, the chef's note) predicts them in advance, so no plan can avoid that waste. That's why the forecast is built from ordinary days only.
- **"Fixed 16 / 23 also gets 6 short days. Why recommend the p10 rule?"** 16 / 23 was picked after looking at all 3 years, so it had already seen the answers. The p10 rule only used earlier years each time and still got to 6, so we trust it more. Built from all 3 years it says 16 / 24, nearly the same number, and now there's a method behind it instead of a guess.
- **Why does the answer card show both +5% and +8%?** The choice between them is a values call for the program, not a data question: +5% wastes about a third less but ran ~30 meals short on 5 of 59 days; +8% ran short once but saves only 11%. The dashboard gives both so the decision-maker can choose.
