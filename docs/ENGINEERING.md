# Engineering notes: Just Nurikabe (engine spike, in progress)

Harness: `swiftc -O -o /tmp/nurikabe-enginecheck Nurikabe/Engine/*.swift Tools/EngineCheck/*.swift && NURIKABE_CORPUS=3 /tmp/nurikabe-enginecheck`
(`NURIKABE_CALIBRATE=1` for score percentiles, `NURIKABE_BAKE=1` to re-bake fallbacks).

## Proven so far (2026-09-26)

- All 9 techniques fire in generated traces. Every step of every trace was replayed
  against the known solution with **zero unsound deductions**.
- Uniqueness: `BacktrackingSolver` agreed with a naive brute-force enumerator on
  every 5×5 board.
- Adding reachability pruning to the backtracker cut 10×10 proofs about 10× (from ~8k nodes).
- Uniqueness repair (`makeUnique`): moving clues onto cells the rival solution leaves
  as sea, else carving a 1-island. It took unique yield from 0/20 to about 15/27 on 10×10.
- Tiers: nothing solves with T1–T4 alone, so gentle's ceiling is T6. 10×10 offers
  steady and above only.

## Where it stands: layout tuning is unfinished

There's a trade-off between the 1-clue share and unique yield:

| Layout | 1s share | 7×7 unique | 10×10 unique |
|---|---|---|---|
| Original (35% new islands, caps 5/7/9, unlimited carves) | 34–46% (too many) | ~60% | ~55% |
| Current (grow small islands, 30% new, caps 5/6/7, ≤3 carves) | ~10–25% | 5/39 | 1/26 (unusable) |

**Next step:** find the middle. Candidates:
- raise `maxCarves` to 5–6
- more repair rounds
- let clue moves also target rival *land* cells adjacent to our islands
- reject only layouts with >25% 1s instead of shaping growth

Re-run the profiler pattern (layout, then `makeUnique`, then solve), then the corpus
with `NURIKABE_CALIBRATE=1`, and recalibrate `DifficultyRater.thresholds`.

## Not started

The Xcode project (copy Shikaku's `objectVersion 77` setup), Game, Teaching,
Store, Persistence, Design, the Swift Testing target, the icon, and
`TechniqueContent` prose. Nothing has been registered in App Store Connect.
