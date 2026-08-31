# CISTERN — design notes, v2.0.0

This document explains what v2 is built from: the concept reduced to its
simplest form, the base principles it was rebuilt on, and how each
principle became code. It assumes the README for rules and controls.

---

## 1. The concept, unwrapped

Strip the theme away and CISTERN is three sentences:

1. **Workers convert time into income**, except when a biological need
   interrupts them.
2. **Sanitation is a flow network**: need is served at toilets, waste
   flows through pipes into tanks, and tanks convert waste back into
   income on purge.
3. **Unserved need becomes contamination**, which spreads until the
   sector is condemned.

Everything on screen is one of those three sentences wearing a costume.
A toilet is "a service point that only functions when connected to
capacity". A purge is "the converter". A migrant is "demand growth". The
theme (Nihei megastructure, sanitation terminals, silent infrastructure)
is applied *over* the mechanics, never instead of them.

## 2. Base principles the rebuild follows

v1 worked badly because it was written as a pile of globals with the
render layer reaching into simulation state. The rebuild started from
five constraints:

1. **One state object.** Every simulation function takes `st`
   (`cistern-st`) and returns nothing; every command takes `st` and
   mutates it. Exactly one module global exists: `cistern--st`, the live
   game. Consequence: the self-test and soak run multiple independent
   games in one batch session with zero interference.
2. **Determinism.** All randomness flows through `cistern--rand`, a 31-bit
   LCG carried *inside the state* (`cistern-st-rng`). Same seed, same
   game, byte for byte. The self-test asserts this directly (two games,
   seed 7, 50 ticks, identical alloy/contam/rng). Seeds print in the
   header so a run can be reproduced or shared.
3. **One search primitive.** `cistern--flood` is the only BFS in the
   file. Pathfinding, "which tanks does this toilet reach", and any
   future spatial query are all the same function with different
   passability predicates. One implementation, one place to fix bugs.
4. **Simulation never touches emacs.** The phases are pure functions of
   state. No buffers, no faces, no keymaps below §10. That is why the
   whole game verifies in `--batch` with no display.
5. **The view is a projection.** `cistern--render` reads state and
   inserts text; it never mutates anything except the point. If state is
   sane, the screen is sane.

## 3. The state

```
cistern-st
  w h map          — grid: flat vector of cell symbols (floor wall door
                     ore pipe toilet tank hazard)
  toilets tanks    — hashes: (X . Y) -> plist (:busy) / (:load)
  creators         — list of cistern--worker
  alloy tick contam over log cursor rng
  purges built-pipe built-toilet built-tank earned migrants
  tutorial         — index into the step table; t when done
```

Workers (`cistern--worker`) carry position, bladder, sickness, mining
counter, and — the field that kills v1's worst bug — `toilet`, the cell
they are seated on.

Cell kinds are data, not classes: one symbol per cell, one `pcase` in the
glyph table, one membership list per passability rule. Adding a cell kind
is three lines.

## 4. The rules, as the rebuild states them

**A toilet is a room, not a floor tile.** In v1, workers seated from an
adjacent cell and the "release" wrote plumbing state back to the wrong
tile — phantom toilets, permanently clogged rooms, fake severed lines.
v2 states the rule so the bug cannot exist: **entering the toilet cell IS
sitting down.** The seated worker occupies that cell; the release writes
to `worker.toilet`, which is by construction the same cell the map says
is a toilet. The self-test walks a worker through the whole loop and
asserts the plumbing hash never references a non-toilet cell.

**Movement never enters an occupied cell.** The creator phase maintains
an occupancy hash updated as each worker steps; the step chooser skips
blocked neighbors even when the BFS seeded the target. Two workers cannot
share a tile by construction — asserted over a 12-tick corridor rush.

**A worker can always leave their own tile.** BFS keeps the walker's
current cell passable ("own cell" exception), so contamination under your
feet is unpleasant, not a permanent statue. v1 stranded workers on
hazard tiles forever; the self-test strands one on purpose and asserts
they walk away.

**Contamination never destroys the resource base.** Hazards land on
`floor` only. Ore, pipes, toilets, tanks, walls are firebreaks. v1 let a
breach on an ore vein delete the income source permanently — unwinnable
by construction. The rebuild's rule makes every loss recoverable.

**Contamination is pressure, not scarring.** Spread 3%/tick onto clean
floor; decay 2%/tick back to floor. Stop the bleeding and the sector
self-heals; keep bleeding and it spreads faster than it fades. This
single pair of numbers converts v1's death spiral into recoverable
pressure.

**Sickness costs productivity, never mobility.** Sick workers mine at
half rate for 30 ticks but walk normally. v1 slowed them to half speed,
which meant they could not reach toilets — a breach made the *next*
breach likelier, a spiral the player could not fight. The rebuild
removes the death spiral and keeps the economic sting.

**The bladder window must exceed the worst walk.** Seek at 60%, breach
at 120%, rate 2%/tick: a 30-tick warning window against a worst-case
cross-room walk of ~14 ticks plus queueing. v1's numbers (70→100 at
3%/tick) gave a 10-tick window against a 14-tick walk — the opening
sector breached workers who had done nothing wrong. Tuning is stated as
this inequality, not as vibes.

## 5. The tick pipeline

```
cistern--do-tick
  ├─ phase-creators  seat/walk/mine/breach (occupancy updated per move)
  ├─ phase-hazards   spread 3% / decay 2%
  ├─ phase-migration gate spawn, deferred politely if blocked
  ├─ phase-check     condemn at the limit
  └─ tutorial-advance predicate table
```

Order matters: hazards spread *after* movement (using fresh occupancy,
so nothing spreads under a walker), and the tutorial runs last so its
predicates see the completed tick.

## 6. The tutorial is a table

Nine steps; each is `(PROMPT . PREDICATE)`. After every tick the current
predicate runs against the state; true advances the pointer. Steps are
order-free — if the player already did step 7's work, steps 5 and 6
resolve instantly and the table catches up. No scripting, no cutscenes,
no state machine beyond an index. `T` skips. The whole feature is ~40
lines and cannot desync from the rules because it *is* the rules,
observed.

## 7. The view

- **Header**: shift, tick, alloy, population, contamination, seed.
- **Keybar**: every command with its price. Nothing lives only in a
  manual.
- **Glyph legend**: one permanent line under the keybar. Pat's first
  complaint — "I don't know what the glyphs mean" — is answered on
  screen, every frame.
- **Inspector**: the line under the grid explains the cursor cell and
  any worker on it (bladder %, sick timer, toilet countdown). Toilets
  report their own diagnosis: *in use / wired and serviced / backed up:
  purge / severed: lay pipe*. This is the "view/inspect" function: not a
  mode, always on.
- **Pressure line**: one honest sentence about the system state.
- **Tutorial line** and the last three log lines.

Faces are foreground-only and chosen to read on both light and dark
themes. `cursor-type` is nil — the inverse-video cursor cell *is* the
cursor.

## 8. Verification

Two commands, both headless and deterministic:

- `cistern-run-selftest` — map integrity; the full toilet loop (walk in,
  seat, occupy, release, deposit, network intact, no phantom entries);
  back-up and purge economics; breach + decon; the no-statue rule; the
  no-stacking rule over a corridor rush; seed determinism across two
  parallel games.
- `cistern-run-soak` — 600 ticks under a scripted player that purges at
  ≥40, decons when the war chest allows, builds tanks/toilets toward
  population targets, and places builds **nearest the workforce**
  (growing the network east, the way a human spreads it). Survives with
  contamination at 19/20 — deliberately tense.

The soak is the answer to "is it actually fun/playable": a competent
player ends the run one breach from condemnation and alive — the game
holds pressure without tipping over.

## 9. Known ceilings (deliberate)

- **Recompute everything, every tick.** BFS per worker per candidate
  target. At 8 workers × 544 cells this is microseconds; a 200×120
  sector with 64 workers wants a shared Dijkstra and incremental hazard
  bookkeeping. Stated, not built.
- **No save files.** State is a struct of vectors, hashes, structs and
  ints — `prin1`/`read` with hash-table rebuilding is ~40 lines when
  wanted.
- **No sound, no animations.** Emacs is the medium; the tick is the beat.

## 10. v1 → v2 postmortem, for the record

| v1 bug | v1 root cause | v2 rule that excludes it |
|--------|---------------|--------------------------|
| Toilets clogged forever after first use; "toilets in other rooms"; fake severed lines | `finish-use` released the worker's *standing* tile, not the seated toilet; phantom plumbing entries accumulated | entering Ω = seating; release writes `worker.toilet`; self-test asserts hash ⊆ toilet cells |
| Workers shitting where they stand | bladder window (10 ticks) shorter than the walk (14); unserved need = instant breach | 60→120 window = 30 ticks; contamination only on floor; decay |
| Workers frozen mid-floor | hazard under a worker made their own cell impassable | own-cell always passable; hazards never spawn under workers |
| Two workers on one tile | target-seeded BFS bypassed occupancy on the last step | step chooser skips blocked cells; occupancy updated per move |
| Ore veins destroyed by breaches | hazards could replace ore | firebreak rule: hazards on floor only |
| Migrants spawning into occupied gate | no occupancy check at spawn | gate spawn checks occupancy, defers |
| "No idea what to do / what glyphs mean" | no tutorial, no legend, no inspector | 9-step predicate tutorial, permanent glyph line, always-on inspector |
