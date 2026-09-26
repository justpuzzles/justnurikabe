# The technique ladder

Nine techniques, in teaching order. **The `Technique` enum's declaration order is
the source of truth** for the solver loop (lowest-tier applicable technique first,
never first-found), difficulty weights, hint escalation, the lesson sequence and
the practice menu. Change the order in one place only.

Every deduction is either **sea** (shade) or **land** (dot). A step carries the
cells it decides plus structured `ExplanationData` for the overlay; the engine
never holds English (that lives in `TechniqueContent.swift`).

Soundness is tested, not argued: the harness replays every step of every trace in
the generation corpus and checks each deduced cell against the board's known
solution.

## T1 `oneClue`: "Ones"

A 1 is a whole island. Every cell beside it is sea.

## T2 `twoClues`: "Between Two Islands"

A blank cell touching two different numbered islands would join them into one
island with two numbers. It is sea.

## T3 `completeIsland`: "Finished Island"

An island that already has as many cells as its number is finished. Every blank
cell beside it is sea. (T1 is the special case for 1s. It is kept separate so the
simplest argument gets its own lesson and fires first.)

## T4 `noPool`: "No Pools"

Three sea cells in a 2×2 block: the fourth must be land, or the sea would form a
pool.

## T5 `unreachable`: "Out of Reach"

A blank cell that no island can reach is sea. An island with number *n* and *k*
cells so far can add *n − k* more, so it reaches only cells within *n − k* steps,
and only along paths that don't touch another numbered island. Unnumbered land
cells on the path count as steps (they would join the island).

## T6 `islandEscape`: "Only Way Out"

An island that still needs cells, or a patch of land with no number yet, with
exactly one blank neighbour must grow into it. That neighbour is land.

## T7 `seaEscape`: "The Sea Must Connect"

A patch of sea with exactly one blank neighbour, while there is more sea to come
elsewhere, must flow out through it. That neighbour is sea.

## T8 `commonGround`: "Common Ground"

List every way an unfinished island could still be completed. A blank cell that
**every** completion uses is land. A blank cell that every completion touches but
none uses is sea (it borders the island whichever way it grows). Enumeration is
capped by island size and count, so the technique stays affordable. Beyond the
cap it simply does not fire.

## T9 `whatIf`: "What If"

Try one blank cell as land (or sea) and apply T1–T8 until they stop. If that leads
to an impossible board, the cell is the other colour. It is one step of
look-ahead, never a guess: the hint always shows the contradiction it found. This
is the tail technique and appears only in the hardest tier.

## Contradictions (used by T9 and the uniqueness solver)

- An island holding two numbers, or more cells than its number.
- An unfinished island, or unnumbered land, with no blank neighbour left.
- A patch of sea with no blank neighbour while more sea exists elsewhere.
- A 2×2 pool.
- More land or sea cells than the clues allow.
