# Engineering notes — Just Nurikabe

Harness: `swiftc -O -o /tmp/nurikabe-enginecheck Nurikabe/Engine/*.swift Tools/EngineCheck/*.swift && /tmp/nurikabe-enginecheck`
(`NURIKABE_CORPUS=n`, `NURIKABE_CALIBRATE=1`, `NURIKABE_BAKE=1`, `NURIKABE_LESSONS=1`).

## What the harness proves on every run

- Every step of every trace in the generation corpus agrees with the board's known
  solution (soundness of all nine techniques, tested rather than argued).
- `BacktrackingSolver` agrees with a naive row-major enumerator on every 5×5 board.
- Baked fallbacks and every lesson position: valid, unique, solvable; lesson
  positions lowest-first (technique) or rule-decides-the-blanks (rules).
- Every technique appears in generated traces; generation is deterministic per seed.

## Generation (measured 2026-09-27)

Pipeline: random layout → **uniqueness repair** → **1-folding** → solve once with
the whole ladder → grade.

- **Random layouts are almost never unique** (0/20 at 10×10). Repair asks the
  backtracker for a rival solution and rules it out: move a clue onto a cell of its
  island that the rival leaves as sea (always possible — equal land totals mean the
  rival pays for its extra land with sea inside one of our islands), and every third
  round reshape instead (grow an island into rival land, or carve a 1, capped at 3).
- **Uniqueness comes from scattered 1-islands**, structurally. Every attempt to
  suppress 1s during layout (joining pools to islands, smallest-first growth, small
  size caps) collapsed 10×10 yield to ≤ 1/26 and made proofs cost ~65k nodes each.
  So 1s are removed *after* uniqueness instead: `dropOnes` bridges a 1 into its
  neighbouring island through one sea cell (the island grows by 2) and keeps the
  change only if the board stays unique. Deleting a 1 outright almost always makes a
  pool (a 1 is walled by sea). Two passes: 1s share 50% → ~31–39%.
- **Reachability pruning** in the backtracker cut 10×10 proofs ~10× (8k → ~800 nodes).
- Solve once with the whole ladder, grade, keep the nearest grade; 5×5/7×7 hit every
  tier, 10×10 hits sharp+ (it almost never grades gentle/steady, so it doesn't offer
  them — `BoardSize.tiers`). Averages: 5×5 0.03 s, 7×7 0.7 s, 10×10 ~1 s.

## Grading

`Difficulty.techniqueCeiling`: gentle ≤ T6, steady ≤ T7, sharp ≤ T8, deep/severe
need T9 and are split by score. Nothing solves with T1–T4 alone. Thresholds in
`DifficultyRater.thresholds` sit just above each lower floor's p90; recalibrate
with `NURIKABE_CALIBRATE=1` after any change.

## Traps found while building the app

- An engine type named `Group` shadows SwiftUI's `Group` everywhere the engine is
  imported → renamed `CellGroup`.
- A nested enum inside a `View` is MainActor-isolated under default isolation, so a
  `nonisolated` `Route` can't hold it → `PlaySource` is top-level.
- `path.removeLast(); path.append(next)` with the same destination type reuses the
  old view's @State unless the destination has `.id(value)`.
- idb's accessibility tree does not see into sheets; tap sheet controls by
  coordinate. Toolbar buttons are safer than form buttons in `.medium` sheets.
- `simctl launch` does not apply the scheme's StoreKit configuration, so the
  paywall shows no price there; that is expected.
- The icon script must be compiled, not interpreted, and draw into an opaque
  `noneSkipLast` CGContext (AppKit refuses a no-alpha bitmap context).

## Known limits (v1.0)

- VoiceOver reads the board as a summary (counts), not cell by cell.
- iPhone only, portrait.
- 1s remain about a third of clues on 7×7/10×10.
