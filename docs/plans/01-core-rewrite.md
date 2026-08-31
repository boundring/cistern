# Execution plan — Phases 1 & 2 (domain, use cases)

Covers the inward-out core of the Cistern Clean-Architecture rewrite, per
`docs/DESIGN-SPEC.md` (§3 architecture, §4 R3/R5/R6/R8/R9, §5 test strategy)
and the Phase 1/Phase 2 sections of `docs/ROADMAP.md` (incl. their handoff
briefs). A fresh worker should need only this file, the spec, and the legacy
line ranges named below. Process: `reference/roguelike-agentic.md` — red
commit before green, lessons harvested to `docs/FAILURE-LEDGER.md` (§5.3
format), dead runs replaced with failure-informed briefs
(`docs/HANDBRIEF-TEMPLATE.md`).

Conventions for both phases:

- Code lands in `src/` (the Phase 1 brief says "no src yet" — that names the
  code dir); tests land in `tests/`. NO commits here — the coherence pass
  commits; workers stage nothing with `git commit` while siblings run.
  (Commit messages below name what each pair *would* be committed as, in
  order, so the coherence pass can red/green the history per R10.)
- Test invocation: `emacs -Q --batch -l src/cistern-domain.el -l src/cistern-game.el -f cistern-run-selftest`
  and, per pair, loading the pair's test file and calling its entry function.
- Legacy refs are into `legacy/cistern-share/cistern-2.0.0/` unless noted.

---

## Phase 1 — Domain: tile tables, state, procgen

### Scope correction discovered during expansion

The Phase 1 goal line names only tile table / state / grid / procgen, but its
own done-when requires "emacs -Q --batch loads cistern-domain.el and runs a
full tick", and spec §3.2 puts *sim phases + connection logic* in
`cistern-domain.el`. So Phase 1 lands the whole pure sim core (worker
lifecycle, four phases, flood/connection primitives) — the tick pipeline is
domain, and only verbs/tutorial/rewards are Phase 2. Plan accordingly; don't
leave the tick for Phase 2.

### 1.1 Red/green pairs, in order

**Pair 1 — R3(a), procgen variety.**
- Test: `tests/domain-procgen.el` :: `cistern-test-procgen-variety`.
  Asserts: `cistern--gen-map` (new) applied to 5 distinct seeds (20260830,
  1, 2, 3, 4) yields ≥3 distinct layout signatures, where a signature is a
  hash of wall/ore/plumbing (pipe+toilet+tank) positions — legacy map-hash
  pattern, cf. selftest determinism block cistern.el:1028-1033; and starter
  plumbing (tank–pipe–pipe–toilet chain) present in every generated map.
- Acceptance (spec §4 R3, verbatim): *"headless test generates maps from ≥5
  distinct seeds and asserts ≥3 distinct layout signatures (e.g., hash of
  wall/ore/plumbing positions)"*.
- Red commit: `test: R3 failing — procgen variety across seeds`.
- Minimum green: `src/cistern-domain.el` skeleton — constants block ported
  verbatim (cistern.el:47-65), worker struct (:72-73) + `cistern-st` (:75-85)
  with score/objectives/unlock placeholder fields (values nil — shape NOT
  pinned), LCG (:87-92), log (:94-99), grid primitives (:104-119) — plus
  `cistern--gen-map` (seed → map vector + toilets/tanks hashes) and
  `cistern--new-game` (cistern.el:247-258) calling it. Legacy
  `cistern--build-map` (:200-231) is the hardcoded layout being generalized;
  do not port it as-is.
- Green commit: `R3: seed-driven procgen, ≥3 signatures over 5 seeds`.

**Pair 2 — R3(b), table is the sole source.**
- Test: `tests/domain-tile-table.el` :: `cistern-test-table-sourcing`.
  Asserts: (a) `cistern--tile-glyph` and `cistern--tile-passable-p` both
  resolve through `cistern--tile-table` for every existing kind (floor wall
  door ore hazard pipe toilet tank); (b) static grep-level check on
  `src/cistern-domain.el`: no cell-kind-symbol pcase/case outside the table
  definition itself.
- Acceptance (spec §4 R3, verbatim): *"test asserts the tile table is the
  sole source consulted for glyph choice and passability (unit: rendering a
  cell and asking its passability both route through the table)"*.
- Red commit: `test: R3 failing — tile table sole source`.
- Minimum green: `cistern--tile-table` defconst, one entry per kind with
  plist fields `(:glyph :passable :buildable :firebreak :conn)`; the two
  accessors; procgen's placement and `cistern--walkable-p` (:141-147)
  refactored to consult the table (passability membership lists die).
- Green commit: `R3: reference tile table drives glyph + passability`.

**Pair 3 — R3 extended, map integrity across seeds.**
- Test: `tests/domain-map-integrity.el` ::
  `cistern-test-map-integrity-seeds`. Port of the legacy selftest
  map-integrity block (cistern.el:941-950) run over all 5 seeds, plus the
  invariants procgen must now guarantee per-seed: border walls; ≥1 migrant
  gate door on the border; ≥1 ore cell; starter plumbing chain intact AND
  connected (pipe→toilet→tank adjacency); every initial worker spawn cell
  (12,6) (14,7) (11,9) (15,6) (cistern.el:252) is passable floor-family —
  spawned-on-a-wall is the classic procgen/table contact bug.
- Acceptance (spec §4 R3(a) again + R9 batch conformance; this pair defends
  the same criterion's "table-validated placement" half).
- Red commit: `test: R3 failing — map integrity across seeds` (expected red:
  pair-1 procgen will not yet guarantee spawn validity / plumbing
  connectedness).
- Minimum green: procgen fixes only (reserve floor for spawns + starter
  chain before carving walls; validate every placed tile against
  `:buildable`/`:passable` from the table).
- Green commit: `R3: map integrity invariants hold across seeds`.

**Pair 4 — R9, domain ticks headless.**
- Test: `tests/domain-tick.el` :: `cistern-test-tick-headless`. In batch, no
  display: fresh state from seed, one full tick (`cistern--sim-tick` — see
  naming pin below), assert tick counter = 1 and no error.
- Acceptance (spec §4 R9, verbatim): *"batch check loads `cistern-domain.el`
  and `cistern-game.el` in an `emacs -Q --batch` session with no
  buffer/display setup and runs a full tick"* (domain half; game half lands
  Phase 2).
- Red commit: `test: R9 failing — domain full tick headless`.
- Minimum green: port worker lifecycle (cistern.el:236-258 spawn/glyph) +
  the ONE flood primitive and connection logic (:124-195: `cistern--flood`,
  `cistern--walkable-p`, `cistern--occupied-cells`, `cistern--dist-from`,
  `cistern--connected-tanks`, `cistern--toilet-usable-p`,
  `cistern--free-usable-toilets`) + the four sim phases (creators :422-441,
  hazards :443-467, migration :469-479, check :481-485) + `cistern--sim-tick`
  (:487-493 minus `cistern--tutorial-advance` — that hook moves to the game
  layer in Phase 2; domain tick runs exactly 4 phases).
- Green commit: `R9: full sim tick in pure domain`.

**Pair 5 — §5.2 determinism (R3+R9).**
- Test: `tests/domain-determinism.el` :: `cistern-test-determinism`. Same
  seed twice ⇒ identical map hash AND identical 50-tick trajectory (alloy,
  contam, rng state — legacy pattern cistern.el:1028-1033).
- Acceptance (spec §5.2, verbatim): *"Same seed ⇒ identical trajectory
  (state hash after N ticks), as legacy cistern.el:1028-1033. This now
  covers procgen: same seed ⇒ same map."*
- Red commit: `test: R9 failing — determinism`.
- Minimum green: kill whatever nondeterminism surfaces. Known suspect:
  hash-table iteration order in Elisp is unspecified —
  `cistern--connected-tanks`/`cistern--free-usable-toilets` already sort
  their outputs (:177, :195) and hazard phase scans by index (:447-452);
  if any new procgen/sim code iterates a hash where order can affect state,
  sort or index-scan it.
- Green commit: `R9: same seed ⇒ same map and 50-tick trajectory`.

### 1.2 File-level work items — `src/cistern-domain.el`

Ported from legacy (with line refs):
- Constants block: :47-65 verbatim (including costs and purge rate).
- `cistern--worker` struct: :72-73 verbatim.
- `cistern-st` struct: :75-85 + placeholder fields `score`, `objectives`,
  `unlocks` (nil defaults; shape DEFERRED to REWARDS-DESIGN).
- LCG `cistern--rand`: :87-92 verbatim (determinism lives here).
- Log: :94-99 verbatim.
- Grid primitives `cistern--in-bounds-p/--idx/--cell/--set-cell/--neighbors`:
  :104-119 verbatim.
- Flood/connection block: :124-195 ported, with passability routed through
  the tile table (Pair 2 refactor of :141-147, :170-171).
- Worker lifecycle + sim phases: :236-258, :422-493 (tick minus tutorial
  hook); hazard/accident/seek helpers in :262-421 as needed by the phases.

New (no legacy counterpart):
- `cistern--tile-table` + `cistern--tile-glyph` / `cistern--tile-passable-p`
  (R3b; `:conn` field is data-only for now — per-connection-state glyph
  *choices* are the Phase 3 view's job, R7).
- `cistern--gen-map` (seed → map + starter plumbing), replacing
  `cistern--build-map` (:200-231); `cistern--new-game` (:247-258) retargeted
  to it.
- `cistern--sim-tick` (renamed from legacy `cistern--do-tick` internals —
  the `cistern--do-tick` name is re-pinned at the game layer in Phase 2).

NOT in this file (belongs elsewhere): verbs, tutorial, rewards, cursor,
keymap, glyphs-by-connection, faces, timers, `cistern--st` global.

### 1.3 Decisions PINNED this phase (least-active)

1. Tile-table data shape: single `cistern--tile-table`, one entry per kind
   (floor wall door ore hazard pipe toilet tank — exactly the legacy kinds,
   no new kinds), plist `(:glyph :passable :buildable :firebreak :conn)`.
2. Procgen seed contract: `cistern--gen-map st seed` is pure-in-observation
   (same seed ⇒ same map + same plumbing hashes); starter plumbing and the
   four legacy worker spawn cells are valid on every generated map.
3. Domain tick runs exactly the 4 legacy phases; the tutorial hook is added
   by the game layer (Phase 2), so domain never references tutorial state.
4. File/dir placement: `src/cistern-domain.el`, `tests/*.el` (from the
   roadmap brief: "no src yet").
5. Sim phases + connection logic live in domain (spec §3.2), hence the
   `cistern--sim-tick` name at this layer.

### 1.4 DEFERRED (do not decide in code, no matter how tempting)

- Procgen algorithm internals (room-and-corridor vs maze vs other) — spec
  §6: table + variety criterion are pinned, the generator is swappable.
- Map dimensions varying by seed/level (legacy 34×16 constants stay).
- Score/objectives/unlock field shape (REWARDS-DESIGN owns it, spec §6).
- `:conn` field's exact representation and any connection-glyph logic (R7
  rendering, Phase 3).
- Placement-legality verdict function over (kind, cell-kind) pairs (R7
  acceptance — Phase 2/game; table only carries `:buildable` now).
- Sprite/SVG rendering, faces, worker glyph assignment (view, Phase 3).
- Demolish, save/persistence, sound, performance work, package layout,
  defcustom surface, Emacs version beyond 27.1 (spec §6).

### 1.5 Lesson-collection checkpoints (roguelike-agentic)

Harvest to `docs/FAILURE-LEDGER.md` (§5.3 format) after EVERY red/green
cycle. Expected failure sites:
- **Table shape vs procgen contact** — the first placement loop almost
  always demands a field the table lacks ("table field added/renamed").
  Harvest it; the re-brief carries the corrected shape.
- **Procgen validity** — spawns/starter plumbing landing on carved walls
  (Pair 3's reason to exist); <3 signatures across 5 seeds (tune
  parameterization, don't grow a second hardcoded map).
- **Determinism** — hash-iteration-order leaks into sim choices.
- **Run-death triggers (kill the run, harvest, re-brief):** the run starts
  editing legacy files; the run invents cell kinds outside the table; the
  same determinism assert fails twice (re-fail = wrong basis, not bad luck).
- What the re-brief names: the failed assert name + ledger L-### id, the
  table shape correction, and the constraint that killed the predecessor
  (per HANDBRIEF-TEMPLATE "Failure context" + "Change for next attempt").

### 1.6 Done-when (verbatim from the roadmap Phase 1 handoff brief)

- ≥5 seeds yield ≥3 distinct layout signatures (hash of wall/ore/
  plumbing positions), starter plumbing present in all.
- Rendering glyph choice and passability both resolve through the
  tile table (no cell-kind literal pcase outside it).
- Same seed ⇒ identical map and identical 50-tick trajectory.
- emacs -Q --batch loads cistern-domain.el and runs a full tick
  with no display setup.

---

## Phase 2 — Use cases: verbs, tick pipeline, rewards-eval placeholder

Precondition: Phase 1 landed (`src/cistern-domain.el`, all five pairs green).

### 2.1 Red/green pairs, in order

**Pair 1 — R8, demolish.**
- Test: `tests/game-demolish.el` :: `cistern-test-demolish`. Asserts:
  place tank via `cistern--cmd-build`, demolish it via new
  `cistern--cmd-demolish`, assert cell back to `floor`, tank hash entry
  GONE, alloy reduced by the demolish cost, and a toilet that was fed
  through the removed tank becomes unusable (`cistern--toilet-usable-p`
  nil). Plus: demolish refuses wall/door/ore/gate; NO dangling plumbing
  entries — maphash both hashes asserting every key's map cell still is
  that kind (the legacy phantom-plumbing invariant, cistern.el:976-979,
  extended to removal).
- Acceptance (spec §4 R8, verbatim): *"headless test places a tank,
  demolishes it, asserts cell back to floor, tank hash entry gone, alloy
  reduced by demolish cost, and toilets that were fed through it become
  unusable."*
- Red commit: `test: R8 failing — demolish verb`.
- Minimum green: `src/cistern-game.el` with `cistern--cmd-build` ported
  (cistern.el:498-525, pure signature st+kind+x+y → st+log — needed to place
  the fixture) + `cistern--cmd-demolish`: legality check, cell→floor,
  `remhash` from the matching plumbing hash, alloy -= `cistern-cost-demolish`
  (new constant, documented; implementation-seed value 3 — pinned for
  testability, final pricing DEFERRED to REWARDS-DESIGN per spec §6/R8),
  refuses an in-use toilet (worker seated). Phase 2 ships NO refund; the
  refund contract is REWARDS-DESIGN M1 (50%) and is consumed in Phase 4b
  (plan 03's M1 pair). Disconnect-for-free comes from Phase 1: usability always
  flood-fills the live map (:179-187), so removal of the cell + hash entry
  is the whole job — anything more re-implements connection logic and is a
  smell.
- Green commit: `R8: demolish verb with hash-cleanup invariant`.

**Pair 2 — R6, exactly one tick.**
- Test: `tests/game-tick.el` :: `cistern-test-exactly-one-tick`. Asserts:
  one call to `cistern--do-tick` advances `tick` by exactly 1 (and the
  tutorial-advance hook runs — the tutorial table is empty now, so it
  no-ops); static check: no `cistern-run-10` symbol anywhere under `src/`.
- Acceptance (spec §4 R6, verbatim): *"test asserts a tick command advances
  `tick` by exactly 1; asserts no multi-tick command exists (selftest has no
  `run-10` symbol)"* (the timer half of R6 is the Phase 3 adapter).
- Red commit: `test: R6 failing — exactly one tick per action, no run-10`.
- Minimum green: `cistern--do-tick` in cistern-game.el = over-guard +
  `cistern--sim-tick` (domain) + `cistern--tutorial-advance`. Port the
  tutorial MECHANISM holder only: `cistern--tutorial-steps` (empty/nil for
  now), index in state (already in `cistern-st`, legacy :85), advance
  function per legacy :556-599 pattern minus the 9 legacy steps (content is
  Phase 4a). `cistern-run-10` (legacy :846-851) simply has no port — do not
  delete from legacy (read-only reference), just never write it in src/.
- Green commit: `R6: one tick per action, run-10 not ported`.

**Pair 3 — R5 placeholder, default outcome.**
- Test: `tests/game-rewards.el` :: `cistern-test-rewards-eval-default`.
  Asserts: `cistern--rewards-eval` exists and for a fresh state returns the
  documented default outcome `(:score 0 :objectives nil :unlocks nil
  :celebrate nil)`. SECOND test in the same file:
  `cistern-test-rewards-design-consumption` — asserts REWARDS-DESIGN.md
  loads and drives the outcome; this one is EXPECTED to stay red until
  Phase 4b (the doc is landed at `docs/REWARDS-DESIGN.md`) — that lingering
  red is the required state,
  not a defect.
- Acceptance (spec §4 R5, verbatim): *"placeholder test asserts
  `cistern--rewards-eval` exists, returns the default outcome for a fresh
  state (green in Phase 2), and a second consumption test asserts the doc
  drives a non-default outcome — intentionally red until Phase 4b."*
- Red commit: `test: R5 failing — rewards-eval placeholder`.
- Minimum green: `cistern--rewards-eval` returning the default plist
  verbatim.
- Green commit: `R5: rewards-eval placeholder, default outcome pinned`.

**Pair 4 — cursor + click-move (R1's use-case half).**
- Test: `tests/game-cursor.el` :: `cistern-test-cursor-and-click`. Asserts:
  `cistern--cursor-move` clamps to bounds and mutates state's cursor
  (legacy :862-867); `cistern--cmd-click st x y` with no armed verb sets
  cursor to (x,y) only; with a build verb armed on state (an `armed-verb`
  state field — smallest shape that makes "armed" legible), it places via
  `cistern--cmd-build` legality at (x,y).
- Acceptance (spec §4 R1, verbatim): *"batch test simulates the
  input-adapter call for a click at (x,y) and asserts cursor equals (x,y);
  with pipe verb armed, asserts a pipe placed at (x,y) and alloy reduced by
  the pipe cost."* (The input adapter that invokes it is Phase 3; this pair
  proves the use-case.)
- Red commit: `test: R1 failing — click-move and armed-verb place`.
- Minimum green: port `cistern--cursor-move` (:862-867, sans render), add
  `cistern--cmd-click`.
- Green commit: `R1: click-move use case with armed-verb placement`.

**Pair 5 — R9 game half + extended selftest/soak.**
- Test: `tests/game-selftest.el` :: `cistern-test-legacy-verb-blocks`. Port
  of the legacy selftest verb blocks — purge economy (:981-989),
  breach/decon (:991-1001) — plus the toilet loop (:952-979, whose
  maphash-invariant now also guards demolish) and soak (:1083-1137)
  exercised against `src/` layers; ends `(message "CISTERN-SELFTEST-OK")`.
  Keep the legacy entry-point names `cistern-run-selftest` and
  `cistern-run-soak` (spec §5.1 pins them).
- Acceptance (spec §4 R9, verbatim): *"batch check loads `cistern-domain.el`
  and `cistern-game.el` in an `emacs -Q --batch` session with no
  buffer/display setup and runs a full tick"*; plus §5.1: *"extended to the
  new rules (demolish legality, click-move, procgen variety, rewards
  defaults)"*.
- Red commit: `test: R9 failing — legacy selftest/soak on new layers`.
- Minimum green: port `cistern--cmd-decon` (:527-538, hazard-only — stays
  hazard-only per R8 "distinct from decon") and `cistern--cmd-purge`
  (:540-551); fix whatever layering delta the ported asserts expose.
- Green commit: `R9: extended selftest/soak green on domain+game layers`.

### 2.2 File-level work items — `src/cistern-game.el`

Ported from legacy (with line refs), all with pure signatures
(state + intent → state + log; NO `cistern--st` global, buffers, faces,
keymaps, timers — spec §3.3):
- `cistern--cmd-build`: :498-525.
- `cistern--cmd-demolish`: NEW (R8) — no legacy counterpart; demolition
  legality = player-placed kinds only (pipe/toilet/tank), refuses in-use
  toilet.
- `cistern--cmd-decon`: :527-538 verbatim semantics (hazard tiles ONLY).
- `cistern--cmd-purge`: :540-551.
- `cistern--cursor-move`: :862-867 minus the render call.
- `cistern--cmd-click`: NEW (R1 use-case half).
- `cistern--do-tick`: :487-493 shape, now an orchestrator calling
  `cistern--sim-tick` + tutorial advance.
- Tutorial mechanism: `cistern--tutorial-steps` + `cistern--tutorial-advance`
  (table pattern :556-599; content deferred to Phase 4a).
- `cistern--rewards-eval`: NEW placeholder (R5).
- `cistern-cost-demolish`: NEW constant (value 3 initially, documented;
  refund economics DEFERRED to REWARDS-DESIGN).
- `cistern-run-selftest` / `cistern-run-soak`: legacy names, :937-1035 /
  :1083-1137 ported and extended (demolish legality, click-move, procgen
  variety, rewards defaults).

NOT in this file: keymap/mouse/timer (input adapter, Phase 3), glyphs/faces
(view, Phase 3), tutorial scenario content (Phase 4a), score computation
(Phase 4b).

### 2.3 Decisions PINNED this phase (least-active)

1. Demolish semantics: cell → floor, `remhash` from toilets/tanks hash, no
   refund in Phase 2 (REWARDS-DESIGN M1's 50% refund is consumed in 4b),
   costs alloy via the implementation-seed `cistern-cost-demolish` (3;
   final pricing DEFERRED), player-placed kinds only, refuses an in-use
   toilet. Hash-cleanup invariant is testable, not optional.
2. Tick naming split: domain exposes `cistern--sim-tick` (4 phases, Phase 1);
   game exposes `cistern--do-tick` (over-guard + sim-tick + tutorial
   advance). Legacy's monolithic do-tick is thereby cutover'd, not aliased.
3. `cistern--rewards-eval` signature and default outcome: signature per
   REWARDS-DESIGN §5 — (state, tick events) → (updated state, presentation
   intents); fresh state with no events ⇒ unchanged state + the default
   outcome `(:score 0 :objectives nil :unlocks nil :celebrate nil)` with
   empty presentation intents. Smallest shape the placeholder test can
   pin; 4b consumption re-shapes per the doc (spec §4 R5; same shape and
   split named in plans 02/03).
4. Click-move contract: unarmed click = cursor move only; armed build verb =
   placement routed through cmd-build's existing legality (floor-only,
   worker-free, affordable). No second legality rule.
5. `cistern-run-10` is not ported; tick is exactly-1 everywhere.

### 2.4 DEFERRED (do not decide in code)

- Demolish final pricing; the Phase 2 verb ships no refund — the refund
  fraction is DESIGNED (REWARDS-DESIGN M1, 50%) and lands in 4b (spec §6).
- Score formula, objectives list, unlock tree, celebration triggers —
  REWARDS-DESIGN.md consumption (Phase 4b; its consumption test stays red).
- Auto-run timer ('r', 5 ticks/s) and any wall-clock behavior (Phase 3
  adapter; R6's timer half tested via scheduling records per §5.2).
- Keybindings, mouse handling, help text (Phase 3).
- Tutorial scenario content beyond the mechanism holder (Phase 4a).
- Decon scope changes (hazard-only stays; R8 keeps it distinct from
  demolish), sprite rendering, save/persistence, performance.

### 2.5 Lesson-collection checkpoints (roguelike-agentic)

Harvest to `docs/FAILURE-LEDGER.md` after every cycle. Expected failure
sites:
- **THE phantom-plumbing bug class (DESIGN.md §4)** — a demolish that
  removes the cell but leaves the hash entry, or leaves `worker.toilet`
  pointing at a demolished cell, or lets a seated worker's release write
  plumbing state for a dead toilet. A run whose demolish leaves ANY dangling
  plumbing hash entry is DEAD: harvest the lesson, re-brief naming the
  hash-cleanup invariant verbatim — "every key of `cistern-st-toilets` /
  `cistern-st-tanks` must map to a cell whose map symbol is still
  toilet/tank, at all times" (the legacy selftest assert :976-979 made
  load-bearing).
- **Reimplemented connection logic** — demolish "fixing" usability with a
  local connection check instead of removing cell+hash and letting the
  Phase 1 flood-fill decide; this drifts from the single-flood-primitive
  principle and dies on the next determinism/integrity assert.
- **Tick drift** — any code path advancing tick by ≠1 (batch loops,
  over-guard bypass) or a run-10 resurrection in disguise.
- **Rewards placeholder bloat** — a run that starts implementing score
  math instead of returning the default plist is out of scope (Phase 4b
  territory): stop it, harvest, re-brief.
- What the re-brief names: failed test + L-###, the hash-cleanup invariant
  for plumbing deaths, and "state in, state out" if layering leaked.

### 2.6 Done-when (verbatim from the roadmap Phase 2 handoff brief)

- Demolish restores cell to floor, clears plumbing hash entry,
  costs alloy, downstream toilets become unusable; decon unchanged.
- A tick command advances tick by exactly 1; no cistern-run-10
  symbol exists in the tree.
- cistern--rewards-eval exists, returns the documented default
  outcome for a fresh state.
- Legacy selftest/soak patterns pass headless against the new layers.

---

## Cross-phase notes for the coherence pass

- Commit order matters for R10: red commits must precede their green
  commits in history; the pair tables above give the exact sequence.
- `docs/FAILURE-LEDGER.md` is created on first harvest (append-only, §5.3
  format); ≥1 entry per abandoned/re-attempted run (R10 acceptance).
- After Phase 2, the only intentionally-failing test in the tree is
  `cistern-test-rewards-design-consumption` — that red is required until
  Phase 4b (doc landed at `docs/REWARDS-DESIGN.md`).
