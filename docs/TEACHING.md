# The learning path

Nurikabe's rules fit in four sentences, but players stall on them: "the sea is
one piece" and "no pools" are easy to read and hard to use. The path is built so
that nobody meets a whole board before they have *used* every rule once, and
nobody meets a technique before they have seen it argued on a real board.

## Shape

**Chapter 1 · The rules** (free, always):

| Step | Cards | Board task | Technique behind it |
|---|---|---|---|
| Numbers are islands | land vs sea; islands and their size; how to tap | paint the border of a finished island | `completeIsland` |
| One number per island | islands hold exactly one number; touching land is one island | decide a cell between two islands | `twoClues` |
| No pools | no 2×2 of sea | decide the fourth cell of a pool | `noPool` |
| One sea | the sea is connected | decide a sea patch's only exit | `seaEscape` |
| Your first chart | recap | solve a whole gentle 5×5, full hint ladder free | — |

**Chapter 2 · The techniques**: the nine rungs of `Technique`, in order. Each
lesson is five beats:

1. **Explanation** — name, one-sentence rule, 2–3 short paragraphs (why it's true,
   where to look).
2. **Worked example** — a real position with the argument's region washed ochre,
   the target cells outlined, and the argument written about *these* cells
   (`TechniqueContent.argument`). The player still makes the move.
3. **Your turn ×2** — two more positions with only the targets outlined. Hint
   reveals the region and the argument; Show me fills the answer.
4. **Done** — the lesson is recorded; practice on a whole board generated so the
   technique appears in its solve (`generate(featuring:)`), or go to the next.

Steps unlock in order (a technique lesson needs the one before it; chapter 2
needs chapter 1). Free: T1–T5 (`FeatureGate.freeLessonCeiling`), which is enough
for every gentle board.

## Where the positions come from

Hand-drawn lesson boards were error-prone from the first attempt (the very first
hand-typed test board broke a rule), so every position is **mined from generated
boards and baked** into `Engine/LessonBoards.swift`:

- **Rule positions** are cut *almost solved*: the full solution minus exactly the
  cells one step decides. The rule's technique must decide exactly those blanks
  (`targets == blanks`). For "one sea" this can't also be the lowest technique —
  on a finished board every missing sea cell is also Out of Reach — so rule
  positions only require that their rule applies.
- **Technique positions** are the solver's own state just before a step of that
  technique, where it is the **lowest** technique that applies. So no easier
  argument competes with the one being taught, and the targets are small (≤ 4
  cells; ≤ 6 for Out of Reach, which batches).

EngineCheck and `LessonTests` re-prove both properties, the uniqueness of every
lesson puzzle, and that every given mark agrees with the solution.

## Feedback rules (LessonSession, pinned by LessonSessionTests)

- Only target cells take marks; a tap elsewhere says so and changes nothing.
- A target marked with the wrong colour gets "Not sea/land." plus the rule.
- Correct targets finish the position; completion is recorded immediately, not
  on Continue.
- Show me fills the answer and still counts, so a stuck player is never trapped.

## In games: the hint ladder

Mistakes first (outlined red, with "Clear them"), then for the full game:
nudge (region only) → technique (name + rule) → argument (targets + the
sentence) → apply. Climbing one step's ladder counts as one hint. The free tier
stops at the mistakes check; the first whole puzzle in chapter 1 always gets the
full ladder.
