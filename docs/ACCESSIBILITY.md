# Accessibility audit — Just Nurikabe

This audit and its fixes are on branch `a11y-audit`, 2026-10-03. Tag
`pre-a11y-audit` marks `main` before the work. Nothing here has been
uploaded. The method is the one in `../shikaku/docs/ACCESSIBILITY.md`:
- common tasks
- `performAccessibilityAudit` per screen
- WCAG ratios computed from `Design/Theme.swift`
- Dynamic Type at AX5
- a code review for motion, targets and announcements

Nurikabe ships on iPhone and iPad, in light and dark.

## Findings

🔴 blocks a common task · 🟠 puts a feature claim at risk · 🟡 friction · 🟢 polish

The board was already playable with VoiceOver: each cell is an element with a
1-based position, and a double-tap cycles its mark. Nothing here blocked a
common task.

| # | Sev | Finding | Status |
|---|---|---|---|
| 1 | 🟠 | **Moves were slow and silent.** Reaching "dot" took two double-taps, and the result was never spoken. Clue cells never said that their island was complete. | **Fixed.** Cells have the custom actions "Sea", "Dot" and "Clear" (through a new `onSet`; lesson boards don't pass it, so they keep their own input rules). Every move is spoken, double-taps included, with what it caused: "Row 2, column 3: sea. The 4 is complete", or the rule it broke. Clues read "number 4, island complete". |
| 2 | 🟠 | Nothing was announced: hint rungs, the finish. | **Fixed.** Each tap of Hint is spoken. The finish is announced with time, hints and the record line. |
| 3 | 🟠 | Hint text points at drawn marks ("the highlighted island", "the outlined cell"). | **Fixed.** `BoardSpeech.spokenHint` adds the region and, at the argument rung, the cells to make sea and the cells to dot. Five cells or fewer are listed; more are given as a span. Mistakes name their cells. |
| 4 | 🟠 | Contrast failures. Ochre text 2.5–2.7:1 in light. A finished numeral 2.3–2.4. Land-coloured text on an ochre chip 1.9–2.8. Dark error text on a card 4.2. | **Fixed.** `ochreText` (light 0x8A5A0E, 4.9 or more). `numeralDone` alpha 0.68 (4.4 or more, at large-text size). Chips now use ink text. `errorText` (dark 0xE87A63, 5.6). |
| 5 | 🟠 | Board outlines: ochre targets on land were 1.9–2.8:1, vermilion errors on sea 2.3–2.6:1. | **Fixed.** `ochreRing` (5.1 or more on land in both modes). Errors get a land-coloured inner ring. |
| 6 | 🟠 | Targets under 44 pt: the hint ✕ (about 32), technique chips on the finish card (about 28). | **Fixed.** Both are 44 pt. |
| 7 | 🟠 | Fixed font sizes: timer, finish time, Stats numbers. The timer was read as a clock time. | **Fixed.** `.numberFont(_:)` (`@ScaledMetric`). Times are spoken in words. |
| 8 | 🟡 | Reduce Motion was never read: the rule cards slid in. | **Fixed.** They fade in under Reduce Motion. The rest were already fades. |
| 9 | 🟡 | Locked Learn rows were faded to 55%, which put their subtitles under 4.5:1. Subtitles were cut at two lines. | **Fixed.** No fade, since the lock symbol and spoken state carry "locked". Subtitles wrap. |

Found by the automated audit after the review above, and fixed:

| # | Sev | Finding | Status |
|---|---|---|---|
| 10 | 🟠 | Disabled Undo/Redo were drawn at half of `textSoft` (2.3–3.1:1). | **Fixed.** Plain `textSoft`; the disabled trait says "dimmed". |
| 11 | 🟠 | List section headers and footers used the system grey, which only nearly passed over the paper ground. | **Fixed.** `listHeaderText()` (`textSoft`, 6.8:1) on every header and footer. |
| 12 | 🟠 | Text clipped at large sizes: the hint card, the finish card ("Next board", the record line) and Home's continue detail (`lineLimit(1)`). | **Fixed.** The cards grow vertically, the finish buttons stack at accessibility sizes, and the line limit is gone. |
| 13 | 🟠 | Small text links: "Show me" and "Hint" in lessons, and "Continue: …" on the Learn path. | **Fixed.** 44 pt labels. |

### Accepted, with reasons

- **Progress bars** (lesson steps, path progress) are reported as small hit
  areas, but they aren't controls. Filtered by element type.

- **Board numerals and the wordmark** are drawn to cell and logotype size,
  and are filtered in the audit by label. VoiceOver reads every cell in full.
- **Cells under 44 pt** on large boards. The board fills the space, and the
  cell actions don't depend on touch size.
- **System List screens** (Learn path, Settings, Statistics): Dynamic Type and
  clipping reports on standard rows are filtered on those screens only.
- **Unattributed Dynamic Type reports on board screens** (hint, finish,
  lesson), as in Kakuro and Hashi.
- **Washes** (region, broken rule) are colour, but the cell labels speak
  them, and outlines carry the targets and errors.

### Strengths (kept)

- A per-cell `accessibilityChildren` grid with a board summary.
- Learn rows combined into one element with a state value.
- Tool buttons were already 56×44.
- DEBUG scenes (`-NurikabeScreenshotScene`) made every screen reachable for
  the audit.

## Tests

- `NurikabeTests/BoardSpeechTests.swift`: positions, cell lists and spans,
  mark names, spoken times.
- `NurikabeUITests/AccessibilityAuditTests.swift`: one audit per screen:
  - Home
  - board with hint
  - win
  - Learn path
  - lesson
  - Settings
  - Statistics
  - Home at AX5

  All are launched through the existing DEBUG scene flags.

## Result

`xcodebuild test` (iPhone 16 Pro, iOS 18.5), 2026-10-03: 87 unit tests and
8 audit screens pass with the filters above.

## Follow-up (found on Ginga, same template)

- At AX5 the hint card grew until the board and tools left the screen. The
  panel now scrolls at accessibility sizes, capped at 40% of the height.
- The per-size Stats headers (`Section(TechniqueContent.name(size))`) still
  used the system grey. They now use `listHeaderText()`.

Suite rerun after both, 2026-10-03: all unit tests and 8 audit screens pass.

## Accessibility Nutrition Labels

These become claimable once this branch ships:
- VoiceOver
- Voice Control
- Larger Text (with the numeral exception)
- Sufficient Contrast
- Dark Interface
- Differentiate Without Color Alone
- Reduced Motion

## 1.1 (2026-11-08): New board sheet

- The size segments say "locked" in words on a free copy (the 🔒 glyph stays
  for the eye), and the chosen difficulty row carries `.isSelected`.
  `testNewBoardSheetSpeaksLockAndSelection` checks both on a locked launch
  (any screenshot scene or `-NurikabeScreenshotUnlock` unlocks the app).
- Its audit reports are accepted in that test only: Dynamic Type / clipped
  text from the system Form and the bar's Cancel/Start (the AX5 screenshot from
  `testNewBoardSheetAtLargestTextSize` shows every row and header scaling with
  nothing cut), and one contrast report on the SIZE header, measured at 7.1:1
  (7.2:1 from the colours). The audit attaches that header to the report in
  some runs and leaves it unattached in others, which made the test flaky
  until 2026-11-11; both forms are accepted, for that label only.
- Touch strokes now compare against the board as it was when the stroke
  began, so the island-closed haptic and the spoken move result (VoiceOver
  double-taps arrive as one-cell strokes) report what the stroke changed.
