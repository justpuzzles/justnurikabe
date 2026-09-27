# Design — Just Nurikabe ("the chart")

## Where it sits in the family

Every "Just …" app shares a brand but must never look like a reskin of a sibling
(Guideline 4.3; Just Shikaku was rejected once). Reviewed 2026-09-27:

| App | Ground | Display type | Motif in the lockup | Accent |
|---|---|---|---|---|
| Just Kakuro | light washi paper | New York serif, bold, inline "Just Kakuro" | clue-cell diagonal struck through the K | indigo |
| Just Hashi | pale sea gradient | SF heavy, centred, spaced "J U S T" above | bridge glyph (two islands, a double bridge) under the name | navy |
| Just Shikaku | dark lacquer, dark only | SF bold, inline | green drag-line dash through the name | green / shu vermilion |
| Numeriqo | plain system | SF | none | system blue |
| **Just Nurikabe** | **full-bleed sea band over paper** | **SF Pro Expanded caps, "just" above** | **island strip: a row of sea with islands of 2, 1, 3** | **ochre (teaching)** |

### Family invariants (keep)

- A "Just ‹Name›" lockup with a motif drawn from the puzzle itself.
- Exactly one teaching accent; broken rules get their own colour, never the accent.
- Opaque surfaces: no blur, no translucency.
- A card-based Home with learn / daily / play, and the family's teaching vocabulary.

### Nurikabe's own (don't let a future sibling take these)

- **The sea band**: Home opens on a full-width indigo block with a faint chart
  graticule, reaching under the status bar. No sibling uses a coloured header block.
- **SF Pro Expanded** display type (titles, headings, the wordmark): the wide
  lettering of a chart title. Kakuro owns New York serif; Shikaku and Hashi use
  SF at normal width.
- **SF Rounded** clue numerals, on the board and in the icon.
- **The island strip** motif, and an icon that is a real, legal, unique 5×5 board
  (generator seed 10).

## Home layout (why it looks like this)

The first version stacked a wordmark 12 pt under the status bar straight into five
equal cards and left the bottom third empty. Now:

- The band gives the lockup about a third of the screen, with generous space above
  and below it; Stats and Settings live in the band's navigation bar.
- One **primary card** overlaps the band's lower edge by 40 pt. It reads "Learn to
  play" or "Keep learning" while the path is unfinished, and "Continue" after that.
- **Two tiles** below it: Today's chart and New board. At accessibility sizes they
  stack.
- **Slim rows** follow: Continue while learning, or Lessons once the path is done.

## Implementation traps

- The band colour `Theme.band` is **non-dynamic** on purpose. The navigation bar
  runs in the dark scheme (for a light status bar) while the band follows the app,
  so a dynamic token would resolve to two different indigos and leave a seam.
- A hidden toolbar background loses `toolbarColorScheme`, so the status bar turns
  dark on indigo. Keep the bar background visible and set it to `Theme.band`.
- iOS 26 wraps toolbar buttons in a Liquid Glass capsule: a pale pill on the
  band that also breaks the no-translucency rule. Home's Stats/Settings use
  `sharedBackgroundVisibility(.hidden)` behind `if #available(iOS 26, *)`.
  Pushed screens keep iOS 26's standard glass back/menu buttons on paper.
- The island strip is capped at 22 pt cells. A fixed-width decoration that grows
  with Dynamic Type pushed the whole Home off the left edge at AX sizes.
- `-NurikabeSeedMidPath` (DEBUG) seeds a mid-path player with a saved game and a
  streak, for screenshots and reviews.
