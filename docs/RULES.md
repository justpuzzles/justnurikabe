# Nurikabe: authoritative rules

This is the spec the engine and the in-game rules tutorial both derive from.
Where sources disagree, the **House rule** line states what the engine implements.

## 1. The grid

- A square grid of `N × N` cells, `N ∈ {5, 7, 10}`.
- Some cells hold a number (a **clue**). Clue cells are always land.
- Every cell is either **land** (white, an island cell) or **sea** (shaded).

## 2. Islands

- An **island** is a group of orthogonally connected land cells.
- Every island contains **exactly one** clue, and its size equals that clue.
- So there are no unnumbered islands, and no island holds two clues.

## 3. The sea

- All sea cells form **one** orthogonally connected group.
- No 2×2 block may be entirely sea (no "pools").

## 4. Consequences the tutorial states outright

These follow from sections 2–3, but players miss them, so the rules screen says them:

- Two land cells that touch belong to the same island. So a cell touching two
  different clued islands must be sea.
- The total number of land cells is the sum of the clues. Everything else is sea.
- Islands may touch **diagonally**. Only orthogonal contact joins them.

## 5. House rules

- **Uniqueness:** every shipped board has exactly one solution, proven by
  `BacktrackingSolver` before the player sees it.
- **No guessing:** every shipped board is solvable by `LogicalSolver` under its
  tier's technique ceiling (see `TECHNIQUES.md`).
- **Clues are never 0.** Some variants allow them; this engine does not.
- **Marks:** the player can shade a cell (sea), dot it (known land), or leave it
  blank. Dots are a player aid; a solved board is judged on shading only.
