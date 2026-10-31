# CISTERN — design and implementation notes

This document explains how `cistern.el` works: the data model, the tick
pipeline, the three search problems it solves per tick, and the rendering
approach. It assumes you read the README and are comfortable with elisp.

---

## 1. Shape of the system

CISTERN is deliberately boring in architecture: a handful of module-level
`defvar`s hold all mutable state, a pure simulation layer mutates them one
tick at a time, and a render pass projects that state into a buffer. There
are no timers, no async, no processes, no concurrency. Every interesting
thing happens between two `SPC` presses.

```
player key ──> cursor/build commands ──┐
                                       ├──> cistern--do-tick ──> cistern--render
SPC / r ───────────────────────────────┘
```

### State (module-level defvars)

| Variable             | Contents                                                  |
|----------------------|-----------------------------------------------------------|
| `cistern--map`       | flat `vector` of cell symbols, length `W*H` (34×16)       |
| `cistern--toilets`   | hash `(X . Y)` → plist `(:busy :user)`                    |
| `cistern--tanks`     | hash `(X . Y)` → plist `(:load)`                          |
| `cistern--creators`  | list of `cistern--cr` structs                             |
| `cistern--alloy`     | integer currency                                          |
| `cistern--tick`      | monotonic tick counter                                    |
| `cistern--contam`    | breach count (game ends at 20)                            |
| `cistern--cursor`    | `(X . Y)` of the build cursor                             |
| `cistern--log`       | newest-first message ring (capped at 12)                  |

Cells are symbols: `floor wall door ore pipe toilet tank hazard`. One symbol
per cell keeps the map trivially serializable and the render pass a single
`pcase`.

Creators are `cl-defstruct (cistern--cr ...)` instances with fields
`x y bladder sick mine use-t using`. Structs (vectors) rather than plists
because every tick reads and writes several fields per creator.

> **Ordering pitfall, documented because it cost a debug session:** the
> `cl-defstruct` form must appear *before* any function that `setf`s its
> accessors. With eager macroexpansion at load time, a `setf` compiled before
> the struct form expands into a call to the named setter `(setf accessor)`,
> which is void at runtime. The struct sits at the top of the file for this
> reason.

## 2. The map

The map is carved programmatically in `cistern--build-map` rather than from
ASCII art: border walls, an interior spine wall with two doors, a partition
wall with a third door, the west migrant gate, three ore veins, and the
starter plumbing (tank → pipe → pipe → toilet on the west wall). A flat
vector with manual index math (`cistern--idx`) over `(x y)` accessors —
small enough that a 2D array library would be heavier than the problem.

`cistern--neighbors` is the single definition of adjacency (4-orthogonal).

## 3. The tick pipeline

`cistern--do-tick` runs, in order:

1. **Creator ticks** (over a `copy-sequence` of the creator list, so
   accidents mid-loop cannot desync iteration).
2. **Hazard spread.**
3. **Migrant arrival.**
4. **Lose check** (`contam >= 20` sets `cistern--over`).

### Creator tick

For each creator:

- **Using a toilet:** decrement `use-t`; at zero, `cistern--finish-use`
  releases the toilet, zeroes the bladder, and deposits 10 units of waste
  into the connected tank with the lowest load. If the line was severed
  mid-use (no connected tank), the toilet tile itself becomes a hazard and
  contamination rises.
- Otherwise: `bladder += 3`, then branch:
  - `>= 100` → `cistern--accident`: hazard on (or beside) the creator,
    contamination +1, adjacent creators sickened (`sick = 30`).
  - `>= 70` → `cistern--seek-toilet`.
  - else → `cistern--seek-work`.

`cistern--seek-toilet` first checks the four orthogonal neighbors for a
*usable* toilet — one that is free, wired, and has tank headroom (see §4).
Adjacent means zero travel time is charged for the last step: the creator
seats themselves and `use-t` starts at 4. If nothing is adjacent, it walks
toward the nearest usable toilet. If nothing is usable anywhere, the creator
keeps working — which is exactly how a sector bleeds out.

`cistern--seek-work` mines if standing on ore (`mine` cycles 0→3, granting
1 alloy per cycle), otherwise walks toward the nearest ore. Isolated creators
shuffle randomly so the map never shows deadlocked statues.

## 4. Search: three small BFS problems per tick

All pathing is breadth-first over unit-cost cells. The grid is 544 cells and
there are at most 8 creators, so the O(n²) FIFO (`append`-based queue) is
 comfortably cheap and transparently correct — deliberate.

- `cistern--dist-map (tx ty blocked)` — BFS from the *target* outward,
  producing a distance hash. `blocked` is a hash of cells occupied by other
  creators (a creator never routes through a colleague). Hazard cells are
  never enterable. Toilet cells are enterable only when they are the target,
  which is how creators path *to* a toilet without cutting through others.
- `cistern--move-one` — reads the creator's own distance from that map and
  steps to the neighbor whose distance is exactly one less. Recomputing the
  dist map per creator per tick is the whole cost of the sim's "AI".
- `cistern--nearest-target` — runs the same dist map per candidate (≤3
  toilets, ≤3 ores) and picks the minimum distance. No A*, no caching; the
  naive version is already under a millisecond.

## 5. Plumbing: connectivity as a game verb

`cistern--connected-tanks` BFS-floods from a toilet across `toilet pipe
tank` cells and returns every reachable tank. That single function defines
three gameplay states:

| State        | Test                                                     | Player meaning                    |
|--------------|----------------------------------------------------------|-----------------------------------|
| Usable       | free ∧ some reachable tank has `load + 10 ≤ 60`          | creators will use it              |
| Wired-full   | wired ∧ every reachable tank lacks headroom              | "backed up" — red face, purge it  |
| Severed      | no reachable tank                                        | red face, builds are wasted       |

A toilet is only *usable* when the tank chain has room for one full use —
the `+10 ≤ cap` check, not a `load < cap` check, so a tank at 55 does not
accept a use that would silently overflow.

Pipe glyphs are drawn from a neighbor mask (`cistern--pipe-glyph`):
north/south/east/west membership in `pipe toilet tank` maps to `─ │ ┌ ┐ └ ┘
┼`. The map reads as plumbing rather than as a grid of identical `|`s for
the cost of one `cond`.

## 6. Hazards and sickness

`cistern--hazard-tick` snapshots the hazard list, then each hazard rolls a
6% chance to poison one adjacent `floor` tile. Only `floor` — not ore, pipe,
or wall — so infrastructure and veins act as firebreaks, and the player can
build through a contamination front.

Sickness is a 30-tick timer: sick creators move only on even ticks (the tick
pipeline enforces this by skipping their movement tick, not their bladder —
sick creators fall behind *and* fill up, which is the compounding pressure
that makes one ignored breach expensive).

## 7. Migration

Every 40 ticks, if population < 8, a creator spawns at the west gate
(cell `(1,7)`; the gate itself is the `(0,7)` door). There is no buyout and
no opt-out: the difficulty curve is the population curve. The tuning target
is that a two-toilet, two-tank sector with clean lines holds 8 creators with
purge-cadence slack, and anything less starts leaking around the third wave.

## 8. Rendering

`cistern--render` erases the buffer and reinserts everything each tick:

1. Header line — shift (tick/40), tick, alloy, population, contamination.
2. Keybar — every command with its cost, so nothing lives in a manual.
3. Grid — per cell, `cistern--glyph-face` returns `(glyph . face)`; creator
   glyphs override cell glyphs; the cursor cell is wrapped in an
   `inverse-video` face composed over the underlying cell face
   (`(list 'cistern-cursor face)`), so the cursor never hides what it points at.
4. Pressure line — one honest status sentence (`LINES NOMINAL — THE
   STRUCTURE DOES NOT CARE`).
5. Log — newest three messages, chronological.

Faces are foreground-only `defface`s chosen to read on both light and dark
themes. `truncate-lines` is on, `cursor-type` is nil (the inverse-video cell
*is* the cursor), and point is parked at `(point-min)`. The buffer is
`special-mode`-derived and read-only; renders bind `inhibit-read-only`.

There is no `font-lock`, no `overlay`, no timer: the render pass is a
pure function of state, which is what makes the batch self-test able to
exercise the whole sim without a display.

## 9. Self-test

`cistern-run-selftest` runs under `emacs --batch` and asserts:

- map integrity (dimensions, sealed border modulo the west gate, features),
- start plumbing is usable, backed-up when tanks are full, usable again
  after a purge that pays `cap/3` alloy,
- a forced breach at 99+3 bladder creates a hazard and raises contamination,
- decon clears a tile at cost,
- build debits alloy exactly,
- a creator one room away steps toward its ore target,
- 60 ticks run end-to-end without error.

It is the executable version of this document: if you change the sim and the
self-test still passes, the invariants above still hold.

## 10. Extension seams

- **New cell kinds:** add a symbol, a glyph/face branch in
  `cistern--glyph-face`, and its passability rule in `cistern--walkable-p`.
- **New sectors:** `cistern--build-map` is the only place geometry lives.
- **Persistence:** state is flat (vector + hashes + structs + ints); a
  `prin1`-to-file / `read` round-trip with hash-table rebuilding is ~40 lines.
- **Seeded runs:** `cistern--new-game` calls `(random t)`; pin a seed string
  via `(random "seed")` for race conditions.

The deliberate ceiling: everything is recomputed per tick and nothing is
cached. At 8 creators and 544 cells that is microseconds; if someone builds
a 200×120 sector with 64 creators, replace the per-creator dist maps with
one shared dijkstra from all toilets and add an incremental hazard list.
