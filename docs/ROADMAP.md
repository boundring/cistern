# CISTERN — Dependency-Ordered Roadmap

Governs the Clean-Architecture rewrite per `docs/DESIGN-SPEC.md`
(requirements R1–R10, architecture §3, test strategy §5). Three expansion
workers each take one phase below and expand it into a detailed execution
plan (task breakdown, file-level work, fail-first test order) before any
implementation. Order: inward-out — domain → use-cases → adapters →
content. Every phase follows the roguelike-agentic loop
(`reference/roguelike-agentic.md`): attempt, harvest lessons into
`docs/FAILURE-LEDGER.md`, replace dead runs with failure-informed briefs
(per `docs/HANDBRIEF-TEMPLATE.md`).

No new architecture decisions are added here; anything ambiguous is
DEFERRED (spec §6).

---

## Phase 1 — Domain: tile tables, state, procgen

**Goal.** The pure domain layer exists and is headless-provable:
`cistern-domain.el` with the tile reference table (R3), state structs with
new fields stubbed, grid primitives, seed-driven procgen map generator —
and, because the tick pipeline is domain (spec §3.2 puts sim phases +
connection logic in `cistern-domain.el`, and Phase 1's own done-when runs
a full tick headless), the **whole pure sim core**: worker lifecycle, the
one flood primitive and connection functions, the four sim phases, and
`cistern--sim-tick` (four phases only — the tutorial-advance hook moves to
the game layer). Phase 2 is verbs + orchestration + content hooks on top,
not the phases themselves.

**Inputs.** Spec §3.1–3.4 (layer map, file layout, state ownership), §4
R3, §5.2 (determinism); legacy: state struct + LCG (cistern.el:72-99),
grid primitives (:104-119), fixed `cistern--build-map` to be generalized
(:200-231), cell-kind-as-data principle (DESIGN.md §3).

**Work items.**
1. `cistern-domain.el` skeleton: constants block (legacy :47-65 ported
   verbatim), `cistern-st`/worker structs (legacy :72-85 + score/objectives
   field placeholders per spec §3.4), LCG, grid primitives.
2. Reference tile table: per cell kind — glyph, passability, buildability,
   firebreak, connection appearance. Single source of truth (R3, R7
   legality half).
3. Procgen: seed → map. Tile-table-validated placement; ≥3 distinct layout
   signatures across ≥5 seeds; starter plumbing present in every map.
4. Connection semantics as pure functions (flood-fill over plumbing).

**Inherits.** R3 acceptance (variety signatures; table-only routing), R9
(domain loads and ticks headless), determinism rules §5.2.

**Fail-first order.**
1. Red: procgen-variety test (5 seeds → ≥3 signatures) — fails, no procgen.
2. Red: table-sourcing test (glyph choice + passability route through the
   tile table; no literal cell-kind pcase outside it) — fails, no table.
3. Green: table, then procgen; port selftest map-integrity block
   (legacy :941-950) against generated maps.
4. Green: determinism test (same seed ⇒ same map + same 50-tick
   trajectory, legacy :1028-1033 pattern).

**Lesson checkpoint.** After each red/green commit: did the table shape
survive contact with procgen? Harvest "table field added/renamed" and any
procgen tuning lessons to FAILURE-LEDGER.md. A run is dead per
roguelike-agentic if it starts editing legacy files, invents cell kinds
outside the table, or re-fails the same determinism assert twice — harvest,
close, re-brief.

**Handoff brief.**

```
# Handoff brief — <domain run id>
Mission: R3 + R9 domain slice — cistern-domain.el with tile reference
  table, seed-driven procgen, AND the pure sim core (worker lifecycle,
  flood/connection, four sim phases, cistern--sim-tick); failing tests
  red-first.
Repo state: cistern @ <commit>; docs/ and legacy/ present, no src yet.
Files to read: docs/DESIGN-SPEC.md §3, §4 R3/R9, §5; legacy/
  cistern-share/cistern-2.0.0/cistern.el lines 47-119, 200-258; legacy
  DESIGN.md §3.
Constraints: pure domain only — no buffer/window/face/timer calls;
  pin only tile-table shape + procgen seed contract; DEFERRED procgen
  algorithm internals, save format, everything not named above. Red
  commit before green. No files outside cistern-domain.el + tests/.
Done-when:
  - ≥5 seeds yield ≥3 distinct layout signatures (hash of wall/ore/
    plumbing positions), starter plumbing present in all.
  - Rendering glyph choice and passability both resolve through the
    tile table (no cell-kind literal pcase outside it).
  - Same seed ⇒ identical map and identical 50-tick trajectory.
  - emacs -Q --batch loads cistern-domain.el and runs a full tick
    with no display setup.
```

---

## Phase 2 — Use cases: verbs, tick pipeline, rewards-eval placeholder

**Goal.** `cistern-game.el` implements the game verbs on domain state:
build, **demolish (R8)**, decon, purge, cursor move/click-move; tick
orchestration (exactly-one-tick, R6 logic half); tutorial-table mechanism
holder; `cistern--rewards-eval` placeholder (R5 interface).

**Inputs.** Spec §3.3 (dependency rules), §4 R5/R6/R8, §5.1; legacy: verbs
`cistern--cmd-build` (:498-525), `cistern--cmd-decon` (:527-538, hazard
only), `cistern--cmd-purge` (:540-551), `cistern--do-tick` + phases
(:422-493), `cistern-run-10` to be deleted (:846-851), selftest verb
blocks (:981-1001).

**Work items.**
1. Port verbs with pure signatures (state + intent → state + log).
2. New demolish verb: removes pipe/toilet/tank, clears hash state, kills
   downstream connection, costs alloy, distinct from decon (R8).
3. Tick orchestration: game-layer `cistern--do-tick` = over-guard +
   Phase 1's `cistern--sim-tick` (which owns creators→hazards→migration→
   check) + tutorial advance; no multi-tick entry point.
4. `cistern--rewards-eval` (state) → default empty outcome; the full
   doc-§5 signature (state, tick events) → (updated state, presentation
   intents) is consumed in 4b (R5 placeholder interface).
5. Extended selftest/soak entry points keep legacy names.

**Inherits.** R8 acceptance, R6 tick-advances-exactly-1 + no run-10
symbol, R5 placeholder test, R9 batch conformance.

**Fail-first order.**
1. Red: demolish test (place tank → demolish → cell floor, hash entry
   gone, alloy reduced, downstream toilets unusable) — fails, no verb.
2. Red: exactly-one-tick test + no-`cistern-run-10` assertion — fails.
3. Red: rewards-eval default-outcome test — fails, no function.
4. Green: implement 1–3; port legacy selftest verb blocks green against
   new layer; soak still passes headless.

**Lesson checkpoint.** Harvest into FAILURE-LEDGER.md after each cycle:
connection-kill semantics of demolish (the v1 phantom-plumbing bug class,
DESIGN.md §4) is the expected failure site — a run that lets plumbing hash
entries dangle is dead; harvest the lesson, re-brief with the hash-cleanup
invariant named.

**Handoff brief.**

```
# Handoff brief — <use-cases run id>
Mission: R6/R8/R5-placeholder — cistern-game.el verbs + tick
  orchestration + rewards-eval placeholder; red-first tests.
Repo state: cistern @ <commit>; Phase 1 domain landed (cistern-domain.el).
Files to read: docs/DESIGN-SPEC.md §3.3, §4 R5/R6/R8, §5; legacy
  cistern.el lines 498-551, 422-493, 846-851, 937-1001; legacy DESIGN.md
  §4 (phantom-plumbing rule), §10.
Constraints: use cases never touch buffers/faces/keymaps — state in,
  state out. Demolish costs the implementation-seed constant (3, pricing
  DEFERRED); Phase 2 ships no refund — the refund contract is
  REWARDS-DESIGN M1 (50%), consumed in 4b. Red commit before green. No
  view/input/driver files; no legacy file edits.
Commit policy (PROCESS-RETRO P2): one red commit + one green commit
  per pair; FAILURE-LEDGER entry appended before or with each green.
Done-when:
  - Demolish restores cell to floor, clears plumbing hash entry,
    costs alloy, downstream toilets become unusable; decon unchanged.
  - A tick command advances tick by exactly 1; no cistern-run-10
    symbol exists in the tree.
  - cistern--rewards-eval exists, returns the documented default
    outcome for a fresh state.
  - Legacy selftest/soak patterns pass headless against the new layers.
```

---

## Phase 3 — Interface adapters: input (arrows+mouse+'r') and view (glyphs, celebrations)

**Goal.** Adapters translate Emacs events to use-case calls and project
state to text: input adapter with arrow-key-only movement + mouse
click-to-move/click-to-place + 'r' auto-run timer (R1, R2, R6 UI half);
view adapter with connection-state pipe glyphs and celebration hooks
(R7, R5 render side).

**Inputs.** Spec §3 (adapters), §4 R1/R2/R6/R7, §5.2 (timer testing via
scheduling records); legacy: keymap with hjkl to delete (:787-809),
cursor commands (:853-867), `cistern--pipe-glyph` (:623-640),
`cistern--glyph-face` (:642-661), render (:728-780).

**Work items.**
1. `cistern-input.el`: mouse-1 on grid cell → cursor move; with build
   verb armed → placement at cell, then exactly one tick (spec R6:
   "click-with-verb advance exactly one tick"); arrow keys only for
   movement; 'r' toggles a 5-ticks/s timer driving the tick use case.
2. `cistern-view.el`: projection through the Phase-1 tile table; pipe
   glyphs distinguish connected-to-capacity vs isolated (shape AND face);
   toilet connection state visible; celebration rendering hook reading
   rewards-eval outcome.
3. `cistern.el` driver: keymap (no hjkl), mouse map, timer wiring,
   single `cistern--st` global.

**Inherits.** R1, R2, R6 (timer scheduling records), R7 acceptance,
R9 static no-outward-reference check.

**Fail-first order.**
1. Red: keymap test (no hjkl movement bindings; arrows bound) — fails.
2. Red: click test (adapter call at (x,y) moves cursor; armed verb
   places + spends) — fails, no mouse.
3. Red: timer test (toggle schedules 0.2s timer; off cancels; callback
   advances exactly one tick per fire) — fails.
4. Red: pipe-glyph test (connected vs isolated glyph+face differ) — fails.
5. Green: implement 1–4; celebration hook renders the default (empty)
   outcome — full R5 rendering waits on Phase 4.

**Lesson checkpoint.** The expected failure class here is adapter leakage
(view reaching into sim state shapes, input calling render directly).
Any commit where an adapter names a domain hash layout directly is dead
per roguelike-agentic: harvest the leak into FAILURE-LEDGER.md, re-brief
with the projection-only rule named.

**Handoff brief.**

```
# Handoff brief — <adapters run id>
Mission: R1/R2/R6-UI/R7 — input and view adapters + driver; red-first.
Repo state: cistern @ <commit>; Phases 1–2 landed (domain + game).
Files to read: docs/DESIGN-SPEC.md §3, §4 R1/R2/R6/R7, §5.2; legacy
  cistern.el lines 623-680, 728-780, 787-867; docs/DESIGN-SPEC.md §6
  (celebration choreography DEFERRED).
Constraints: adapters are pure projection/translation — no sim rules in
  adapters; glyphs come from the Phase-1 tile table, never a local pcase.
  Timer behavior tested via scheduling records, not wall-clock. Red
  commit before green. No sim/verb changes in this phase.
Done-when:
  - hjkl unbound; arrows + mouse move cursor; click with armed verb
    places at the cell, spends alloy, and advances exactly one tick.
  - 'r' toggles a 0.2s timer; each fire advances exactly one tick;
    toggle-off cancels.
  - Connected vs isolated pipes render with different glyph AND face;
    toilet connection state visible.
  - No cistern-view/cistern-driver symbol referenced from domain or
    game files (R9 static check).
```

---

## Phase 4 — Content: fail-first tutorial, REWARDS-DESIGN consumption

**Goal.** Gameplay content on the finished stack: the two-scenario
fail-first tutorial (R4) and rewards/engagement consumption (R5 full).

**Inputs.** Spec §4 R4/R5, §6 (deferrals); legacy tutorial table
(:556-599); `docs/REWARDS-DESIGN.md` (landed in-repo — see 4b).

### 4a. Tutorial (unblocked — proceeds with Phase 3 in parallel)

Losing scenario: a deterministic scripted run where missing infrastructure
causes a bladder breach, then the lesson is stated. Winning scenario: same
seed, need served, contamination 0. Predicate-table mechanism retained
(legacy :556-599).

- **Fail-first order.** Red: scripted losing scenario reaches breach with
  contamination > 0 and a lesson log entry (fails — no scenarios); red:
  winning scenario serves the same need at contamination 0. Green: build
  both scenarios as data on the tutorial-table mechanism.
- **Lesson checkpoint.** Scenario desync (a scripted step invalid under
  current rules) is the expected failure — a scenario that stops
  reproducing its own breach is a dead run; harvest the divergence into
  FAILURE-LEDGER.md, re-brief with the failing step named.

- **Handoff brief.**

```
# Handoff brief — <tutorial run id>
Mission: R4 — two deterministic tutorial scenarios on the tutorial-table
  mechanism; red-first.
Repo state: cistern @ <commit>; Phases 1–3 landed.
Files to read: docs/DESIGN-SPEC.md §4 R4, §5; legacy cistern.el
  lines 556-599; legacy README.md "Why your first sector dies".
Constraints: scenarios are data (tables/predicates), no scripted
  cutscenes; pin scenario scripts only, DEFERRED further chapters and
  adaptive difficulty. Red commit before green.
Done-when:
  - Losing scenario runs deterministically to a breach: contamination
    > 0 and a lesson log entry appear.
  - Winning scenario (same seed class) serves the same need with
    contamination 0.
  - Tutorial retains predicate-table advance mechanism; T still skips.
```

### 4b. Rewards consumption (UNBLOCKED — doc landed at docs/REWARDS-DESIGN.md)

`REWARDS-DESIGN.md` is in-repo at `docs/REWARDS-DESIGN.md` (designer
notes at `docs/rewards-notes.md`). This worker consumes its declarative
spec — §2 MUST table (M1–M9), §4 dancing-pixels spec, §5 integration
contract — into `cistern--rewards-eval` and the view's dancing-pixels
celebrations. Soft ordering only: 4b's M6 render criteria want the Phase 3
view adapter present at implementation time; the domain-side criteria
(field, RNG, goals, reputation) depend only on Phases 1–2 state shapes.

- **Fail-first order.** Red: the doc drives a non-default outcome from
  `cistern--rewards-eval` for a documented trigger (the Phase 2
  consumption test turns green here); red: celebration render on
  trigger. Green: implement consumption only — no reward design of our
  own.
- **Lesson checkpoint.** If REWARDS-DESIGN.md's predicates cannot be
  evaluated over the state object, that is a contract break: run is dead,
  harvest the mismatch into FAILURE-LEDGER.md, and route it back to the
  designer workstream rather than patching around it.

- **Handoff brief (armed now — 4b unblocked).**

```
# Handoff brief — <rewards run id>
Mission: R5 full — consume docs/REWARDS-DESIGN.md into
  cistern--rewards-eval + view celebrations; red-first.
Repo state: cistern @ <commit>; Phases 1–3 landed; Phase 2 placeholder
  consumption test red by design.
Files to read: docs/REWARDS-DESIGN.md (§2 MUST, §4 particles, §5
  integration contract, §6 deferrals); docs/rewards-notes.md; docs/
  DESIGN-SPEC.md §4 R5, §6.
Constraints: consumption only — the designer doc owns all reward
  design; any predicate the state cannot express is reported back, not
  worked around. Red commit before green.
Done-when:
  - docs/REWARDS-DESIGN.md drives a non-default rewards-eval outcome
    for a documented trigger.
  - Celebration (dancing pixels) renders on that trigger.
  - No reward rules invented outside the consumed document.
```

---

## Dependency graph

```
Phase 1 (domain) ──► Phase 2 (use cases) ──► Phase 3 (adapters) ──► 4a (tutorial, parallel)
                                                          └────────► 4b (rewards — unblocked;
                                                                     wants Phase 3 view at impl time)
```

4a may start once Phase 3's view contract exists; 4b is unblocked (doc at
docs/REWARDS-DESIGN.md) with only the soft Phase 3 view ordering above.
Expansion workers inherit: the spec sections and
legacy line ranges named in their phase, their handoff brief above, and
the obligation to red-commit before green. Anything their expansion finds
ambiguous goes to DEFERRED, not into code.
