# CISTERN — Design Spec for the Clean-Architecture Rewrite

Status: v1 of the spec, 2026-08-31. Governs the rewrite of
`legacy/cistern-share/cistern-2.0.0/cistern.el` (1140 lines) into a layered
Elisp package. Method: `reference/roguelike-agentic.md` (fail-first,
lessons-into-ledger, failure-informed handoff). Execution follows
`docs/FAILURE-LEDGER.md` + the handoff brief format defined in §5.

---

## 1. Product intent

CISTERN is a turn-based sanitation-management sim in the register of
Tsutomu Nihei's *Blame!*. Workers turn time into alloy. Their biological
need must be routed through a toilet→pipe→tank network. Contamination is
the clock. **Route need to capacity. Convert waste to income.
Contamination is the clock.**

### The three player complaints — design drivers

1. **"Why can't I demolish stuff?"** — No demolish verb exists. The only
   removal is `cistern--cmd-decon` (cistern.el:527), which cleans a
   hazard *tile*; a misplaced toilet, pipe, or tank is permanent. → R8.
2. **"Why is it always the same map?"** — `cistern--build-map`
   (cistern.el:200-231) hardcodes one layout (spine wall at x=8, cross wall
   y=8, three ore veins, one starter plumbing set); the displayed seed
   (cistern.el:251) drives only the simulation RNG, not the map. → R3.
3. **"What's the point? Make me care."** — No score, no objectives beyond
   survival, no unlocks, no celebration. The only feedback lines are the
   pressure line (cistern.el:709) and log. → R5, R4 (tutorial that shows
   losing *and* winning so the stakes are legible).

---

## 2. Current-state summary (legacy v2.0.0)

All references into `legacy/cistern-share/cistern-2.0.0/`.

| Fact | Evidence |
|---|---|
| One state object `cistern-st` threaded through every sim function; exactly one global `cistern--st` (live game, interactive layer only) | cistern.el:75-85, :785; header comment :24-30 |
| Deterministic seedable LCG inside state | cistern.el:87-92 (`cistern--rand`); seed default 20260830 at :251 |
| Tuning constants block (bladder seek 60% / burst 120% / rate 2%/tick; spread 3%, decay 2%; contam limit 20; pop cap 8; migrant every 40 ticks; costs 10/2/15/3; purge rate 3) | cistern.el:47-65 |
| Sim phases creators→hazards→migration→check | cistern.el:422, :443, :469, :481; pipeline in DESIGN.md §5 |
| Player verbs: build toilet/pipe/tank (`cistern--cmd-build` :498), decon cleans a hazard tile ONLY (:527), purge tank (:540). **No demolish verb exists.** | cistern.el §8 |
| `cistern-run-10` skips 10 ticks in one command, bound to `r` | cistern.el:846-851, keymap :804 |
| Cursor movement via arrow-key commands AND vim-style `hjkl` (keymap :795-798). **No mouse support.** | cistern.el:787-809 |
| Pipe connection glyphs via `cistern--pipe-glyph` (box-drawing by 4-neighbour plumbing membership); no distinction of connected-to-capacity vs dead pipe | cistern.el:623-640 |
| Tile placement legality: build only on `floor`, not on workers, needs alloy (cistern.el:503-510) — but nothing is stated about connection semantics at placement time | cistern.el:498-525 |
| Tutorial: 9-step `(PROMPT . PREDICATE)` table, index in state, advance checked after each tick | cistern.el:556-599 |
| Headless deterministic `cistern-run-selftest` (map integrity, toilet loop, purge economy, breach/decon/firebreak, no-statue, no-stacking, determinism) + `cistern-run-soak` (scripted competent player, 600 ticks) | cistern.el:937-1035, :1083-1137 |
| `cistern--build-map` produces an effectively fixed layout (walls/spine/doors/ore/starter plumbing all hardcoded); seed displayed but map static | cistern.el:200-231, :247-258 |
| v1→v2 postmortem: rules stated so the bug class cannot exist (entering toilet = seating; own-cell passable; hazards on floor only; occupancy per step) | DESIGN.md §4, §10 table |

---

## 3. Target architecture

### 3.1 Layer map

```
┌─ Frameworks & Drivers ─── cistern.el (buffer, major mode, keymap, timer, command loop)
│
├─ Interface Adapters ───── cistern-view.el   (render projection: state → text/face)
│                           cistern-input.el  (mouse events / keys → use-case calls)
│
├─ Use Cases ────────────── cistern-game.el   (game verbs: build/demolish/decon/purge/
│                                             cursor; tick orchestration; tutorial;
│                                             objectives scoring entry point)
│
└─ Domain (pure) ────────── cistern-domain.el (state structs, RNG, grid, tile tables,
                                              procgen, sim rules, connection logic;
                                              NO Emacs runtime calls beyond cl-lib/
                                              pure functions)
```

Dependencies point one way: inward. Drivers → adapters → use cases →
domain. The domain imports nothing Emacs-y (no `buffer`, no `window`, no
timers, no faces). Use cases take state + intent, return state (and a log
line); they never touch buffers. Adapters are pure projections and
translations.

### 3.2 Elisp file layout

| File | Layer | Contents |
|---|---|---|
| `src/cistern-domain.el` | domain | constants, `cistern-st`/worker structs, LCG, grid primitives, **tile tables** (R3/R7), procgen map generator, sim phases (`cistern--sim-tick`), connection/legality rules |
| `src/cistern-game.el` | use cases | `cistern--cmd-*` verbs (build, **demolish**, decon, purge, cursor move, click-move), `cistern--do-tick` orchestration (over-guard + `cistern--sim-tick` + tutorial advance), tutorial table, objectives/score hooks |
| `src/cistern-view.el` | adapter | glyph+face projection, pipe-connection glyphs, inspector, pressure line, header |
| `src/cistern-input.el` | adapter | translate mouse/keyboard events into use-case calls; auto-run timer callback (5 ticks/s) |
| `src/cistern.el` | driver | group, defcustoms, global live-state var, `cistern-mode` keymap, mouse keymap, `cistern` entry, help, autoload |
| `tests/*.el` | test | headless deterministic tests, one per requirement + extended selftest/soak |

Pin the minimum (least-active-decisions): the five file boundaries, the
single-state-object rule, the tile-table data shape (§3.4). Everything
else is DEFERRED (§6).

### 3.3 Dependency rules

- Domain and use-case files MUST NOT reference `cistern--st`, buffers,
  faces, keymaps, or timers. They receive and return state.
- The interactive layer owns exactly one global, `cistern--st` (unchanged
  from legacy cistern.el:785).
- Rendering is a pure function of state; the timer only calls
  `cistern-tick` + render.
- The driver owns one timer-handle defvar (`cistern--auto-run-timer`) as a
  documented exception: timer plumbing, never game state — it never enters
  `cistern-st`.
- Tests require only `cistern-domain.el` + `cistern-game.el` and run with
  `emacs --batch`.

### 3.4 State ownership

One state object (legacy pattern retained): `cistern-st` holds map vector,
toilets/tanks hashes, creators, alloy/tick/contam/over, log, cursor, RNG,
count, tutorial index, and new: score/objectives/unlock fields (shape
deferred to REWARDS-DESIGN consumption, §6). Cursor is in state so mouse
and keys mutate the same thing; an `armed-verb` field carries the currently
armed build verb for click-to-place. Seed drives procgen too (R3) — map
variety comes from the seed, not from hardcode. The rewards-owned state
shape (including REWARDS-DESIGN §4's particle field) is consumed from
`docs/REWARDS-DESIGN.md` in Phase 4b.

---

## 4. Requirements

Each requirement lands as a failing headless test first (§5). One
acceptance criterion each.

**R1 — Click-to-move / click-to-place (owner R1).** Left mouse click on a
grid cell moves the cursor there; clicking with an active build verb places
at that cell.
*Accept:* batch test simulates the input-adapter call for a click at (x,y)
and asserts cursor equals (x,y); with pipe verb armed, asserts a pipe
placed at (x,y) and alloy reduced by the pipe cost.

**R2 — Arrow keys and mouse only; no vim movement (owner R2).** `hjkl` are
not movement keys; `<up>/<down>/<left>/<right>` and mouse move the cursor.
*Accept:* keymap test asserts no binding for "h","j","k","l" as movement and
the four arrow keys are bound to cursor commands; grep-level test asserts no
`cistern-cursor-north/south/west/east` aliasing to hjkl remains.

**R3 — Reference tile tables drive procgen AND rendering (owner R3 + R5b).**
A single reference tile table defines, per cell kind: glyph, passability,
buildability, hazard-firebreak status, and variant/connection appearance.
Procgen generates maps by placing table-validated tiles; rendering reads
glyphs/variants from the same table. Seed produces varied maps.
*Accept:* (a) headless test generates maps from ≥5 distinct seeds and
asserts ≥3 distinct layout signatures (e.g., hash of wall/ore/plumbing
positions); (b) test asserts the tile table is the sole source consulted
for glyph choice and passability (unit: rendering a cell and asking its
passability both route through the table).

**R4 — Fail-first tutorial (owner R4).** Tutorial reworked into two
scenario walkthroughs: (1) a losing scenario — a bladder breach caused by
missing infrastructure plays out deterministically, then the lesson is
stated; (2) a winning scenario — the player builds/pipes/purges to handle
the same need. Retains the predicate-table mechanism.
*Accept:* batch test runs the scripted losing scenario to a breach with
contamination > 0 and a "lesson" log entry, then the scripted winning
scenario where the same seed's need is served with contamination staying 0.

**R5 — Rewards & engagement (owner R5c).** Score, objectives, unlocks, and
"dancing pixels" celebration feedback are implemented **as a consumer of
`docs/REWARDS-DESIGN.md`** (landed in-repo; its §2 MUST table, §4
dancing-pixels spec, and §5 integration contract are binding acceptance
criteria). `cistern-game.el` exposes `cistern--rewards-eval` with the
doc's §5 signature — (state, tick events) → (updated state, outcome,
presentation intents) as a 3-list. The placeholder default outcome
`(:score 0 :objectives nil :unlocks nil :celebrate nil)` with empty
presentation intents is pinned for the Phase 2 green test; the doc's rules
re-shape the outcome in Phase 4b. The view renders celebrations.
*Accept:* placeholder test asserts `cistern--rewards-eval` exists, returns
the default outcome for a fresh state (green in Phase 2), and a second
consumption test asserts the doc drives a non-default outcome —
intentionally red until Phase 4b.

**R6 — Exactly one tick per action; auto-run toggle (owner R6).**
`cistern-run-10` is removed. SPACE/RET/click-with-verb advance exactly one
tick. `r` toggles an auto-run timer stepping 5 ticks/second.
*Accept:* test asserts a tick command advances `tick` by exactly 1; asserts
no multi-tick command exists (selftest has no `run-10` symbol); timer test
asserts toggle on schedules a 0.2s idle timer and toggle off cancels it
(adapter-level, batch-checked via timer bookkeeping).

**R7 — Pipe-connection graphics and explicit placement legality (owner R7).**
Pipe glyphs clearly distinguish connected-to-capacity vs isolated segments
(glyph shape AND face differ). Placement legality is explicit and stated:
pipes may be placed on floor adjacent to plumbing or anywhere (connection is
by flood-fill, stated in help); toilets/tanks may be placed on floor only;
a toilet's connection state is visible in its glyph/face.
*Accept:* headless test builds pipe→toilet→tank chain and asserts the
connected pipe renders with the connected glyph/face while an isolated pipe
renders with the isolated one; legality test asserts each (kind, cell-kind)
pair returns a documented verdict from the placement-legality rule.

**R8 — Demolish verb (owner R5a).** New verb `demolish` removes a placed
pipe, toilet, or tank (not walls/doors/ore/gate), costs the
implementation-seed constant `cistern-cost-demolish` (3; final pricing
DEFERRED to REWARDS-DESIGN), kills connection state of the removed piece,
and is distinct from decon. Phase 2 ships no refund; the refund contract
is designed by REWARDS-DESIGN M1 (50%) and consumed in Phase 4b on top of
R8's removal mechanics.
*Accept:* headless test places a tank, demolishes it, asserts cell back to
floor, tank hash entry gone, alloy reduced by demolish cost, and toilets
that were fed through it become unusable.

**R9 — Clean Architecture conformance.** Layer dependency rules (§3.3) hold
mechanically.
*Accept:* batch check loads `cistern-domain.el` and `cistern-game.el` in an
`emacs -Q --batch` session with no buffer/display setup and runs a full
tick; a static check asserts no `cistern-view`/`cistern`-driver symbol is
referenced from domain or game files.

**R10 — Fail-first process conformance.** Every requirement above lands as
a failing test committed before its implementation; the roguelike-agentic
loop governs execution: attempt → harvest lessons into
`docs/FAILURE-LEDGER.md` → relaunch with a failure-informed handoff brief.
*Accept:* for each implemented R#, the git history contains the failing
test commit earlier than the implementing commit; the ledger contains ≥1
harvested lesson per abandoned/re-attempted run.

---

## 5. Test strategy

### 5.1 Fail-first cycles

Per requirement: (1) write the headless test capturing the acceptance
criterion; (2) commit it red (`test: R# failing — <name>`); (3) implement
the minimum that turns it green; (4) commit (`R#: <what>`). The legacy
pattern is the template: `cistern-run-selftest` (cistern.el:937-1035)
asserts gameplay rules headless; the rewrite keeps a `cistern-run-selftest`
and `cistern-run-soak` with the same names and headless/batch invocation
(`emacs -Q --batch -l cistern.el -f cistern-run-selftest`), extended to the
new rules (demolish legality, click-move, procgen variety, rewards
defaults).

### 5.2 Headless determinism

- Same seed ⇒ identical trajectory (state hash after N ticks), as legacy
  cistern.el:1028-1033. This now covers procgen: same seed ⇒ same map.
- No tests depend on time, window size, or display. Timer-dependent
  behavior (R6 auto-run) is tested via timer scheduling records, not
  wall-clock.
- Soak keeps its role: scripted competent player must survive; extended to
  exercise demolish + auto-run-driven tick counts.

### 5.3 Failure ledger — `docs/FAILURE-LEDGER.md`

Append-only, one entry per dead/failed/retried run (roguelike-agentic §2):

```
## L-### (date, run-id)
- Attempt: <requirement/test the run targeted>
- Outcome: FAIL | STALL | ERROR | WRONG-BASIS
- Evidence: <failing test name, exact error/artifact path>
- Lesson: <one actionable sentence>
- Change for next attempt: <concrete correction; what the handoff brief carries>
```

### 5.4 Handoff brief template — `docs/HANDBRIEF-TEMPLATE.md`

```
# Handoff brief — <run-id successor>
Mission: <one requirement + its failing test id>
Repo state: <commit hash, clean/dirty, files touched>
Failure context: <ledger entry ids L-###; the named failure and the fix>
Constraints: <layer rules, no project-wide validation, scope boundary>
Done-when: <the acceptance criterion, verbatim from DESIGN-SPEC §4>
```

A replacement session gets: this spec, the brief, and nothing it would
have to re-discover.

---

## 6. Deferred decisions (explicitly not pinned now)

- **REWARDS-DESIGN.md consumption (R5):** the doc is landed in-repo at
  `docs/REWARDS-DESIGN.md` and owns the rewards design: score formula,
  goal cards, reputation, milestone ladder, celebration/particle field
  (§4), and its own §6 deferrals (pricing, difficulty values, copy). The
  rewrite pins only the consumption interface (`cistern--rewards-eval` §5
  signature) and the Phase 2 default-outcome plist; 4b consumption may
  re-shape per the doc. Terminology: the doc's in-map "coins" are the
  sim's alloy — one currency, two names.
- Demolish final pricing. The implementation-seed cost constant (3) is
  pinned for testability; the refund fraction is designed (REWARDS-DESIGN
  M1, 50%) and lands in 4b, not Phase 2.
- Sprite/image-based rendering (SVG tiles) vs text glyphs — text glyphs
  assumed; revisit only if REWARDS-DESIGN demands richer celebration
  visuals.
- Save/persistence of games and high-score tables.
- Sound.
- Procgen algorithm internals (room-and-corridor vs maze vs others) — the
  tile table and seed-varied-layout acceptance criterion are pinned; the
  generator is swappable.
- Tutorial scripting beyond the two scenarios (more chapters, adaptive
  difficulty).
- Performance: legacy "recompute everything every tick" ceiling retained
  until soak shows otherwise (DESIGN.md §9).
- Package structure (single directory vs ELPA-ready layout), defcustom
  surface, Emacs minimum version beyond 27.1.
