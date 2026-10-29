# Phase 2 finding: do the chef's "rainy" days match real weather?

**Data:** 88 program days joined to Environment Canada daily precipitation (Toronto City station, 6158355). A "wet day" = 1 mm or more of precipitation. All 88 program days had a weather reading.

## Result: the label does not track rain

| | Actually wet (>= 1 mm) | Actually dry |
|---|---|---|
| Chef said rainy | 4 | 8 |
| Chef said nothing | 20 | 56 |

- Only **4 of the 12** rainy days were wet. **7 of the 12 had 0.0 mm.**
- The chef missed **20 of the 24** real wet days.

## Real rain barely changes turnout

Days without the chef's label, compared within day type:

| Day type | Dry: avg served / waste | Wet: avg served / waste |
|---|---|---|
| Mon-Thu | 810 / 30 (34 days) | 819 / 32 (11 days) |
| Fri-Sun | 1125 / 143 (22 days) | 1155 / 171 (9 days) |

Wet days served about the same number of meals as dry days.

## But the "rainy" days really were slow

The 12 labelled days served roughly 25-30% below their day-type normal (e.g. Fridays 808-835 vs a Fri-Sun average of ~1,125) and averaged 305 meals wasted vs 80. Something cut turnout on those days. It just was not rain.

## What this means

- Read the note as **"low-turnout day (cause unknown)"**, not "rainy".
- A weather-based prep rule (cook less when rain is forecast) is **not supported** by this data.
- These 12 days can't be predicted from a forecast, so the prep rule in Phase 4 needs a buffer that handles surprise low (and high) days, not a rain adjustment.

## Caveats

- The station is downtown, not North York, and rain can be very local. But 7 of the 12 labelled days had zero precipitation downtown, which makes heavy rain at the site unlikely.
- Daily totals don't show *when* it rained. Rain only during the evening serving window would still count, but a rain-free day can't hide it.
- 12 labelled days is a small sample.

## Questions for the program

- What did the chef mean by "rainy"? Was the note written on the day or later?
- Was anything else happening on those 12 days (events, cold, schedule changes)?
