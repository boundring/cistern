# CISTERN — Failure Ledger

Append-only, per DESIGN-SPEC §5.3 and `reference/roguelike-agentic.md`.
One entry per dead/failed/retried run.

---

## L-001 (2026-08-30, run: plan-core — planning phase)

- Attempt: Expand ROADMAP Phases 1–2 into `docs/plans/01-core-rewrite.md`
  (read sources, draft the execution plan).
- Outcome: STALL (upstream idle timeout mid-turn)
- Evidence: run died after reading all sources (spec, roadmap, legacy
  cistern.el, DESIGN.md), before writing the plan file; no partial write
  landed in `docs/plans/`.
- Lesson: On a mid-turn upstream timeout, if the session retains its read
  context, steer-resume once before declaring death and re-briefing — do
  not discard completed reads.
- Change for next attempt: Steering resumed the same run with retained
  context (no re-brief, no re-read); the run delivered
  `docs/plans/01-core-rewrite.md` the next turn. Apply to future runs:
  steer-resume is the first corrective, death-and-replacement the second.

---

## L-002 (2026-09-03, run: impl-phase1 — Pair 1, R3 procgen variety)

- Attempt: Red test `tests/domain-procgen.el :: cistern-test-procgen-variety`
  (red commit = load error, `src/cistern-domain.el` absent), then minimum
  green: domain skeleton + `cistern--gen-map` (border walls, seed-random
  spine/cross walls with random doors, seed-random ore, fixed starter
  plumbing placed last).
- Outcome: GREEN (after one RETRY inside the cycle).
  RETRY evidence: first green run failed "only 1 distinct layout signatures
  across 5 seeds" although debug dumps proved ore/wall positions differ per
  seed — the test's signature used `sxhash` on a long list of positions, and
  Emacs `sxhash` is depth-limited for lists: unequal lists sharing a long
  prefix hashed identically (`equal=nil`, `sxhash` equal — reproduced in
  batch). Fixed the test premise by hashing `prin1-to-string` of the
  positions via `secure-hash 'md5`.
- Lesson: never use `sxhash` for structural layout signatures over long
  lists — it is not discriminating at depth. Hash printed content
  (`secure-hash` over `prin1-to-string`) for map/trajectory signatures.
  Second lesson: procgen features placed unconditionally can overwrite
  fixed landmarks; starter plumbing placed after all random placement is
  what keeps the chain present on every seed (reservation discipline is
  formalized in Pair 3).
- Change for next attempt: all later signature checks (map hash in Pairs 3
  and 5) use `secure-hash` over printed content, never bare `sxhash`.

---

## L-003 (2026-09-03, run: impl-phase1 — Pair 2, R3 tile table sole source)

- Attempt: Red test `tests/domain-tile-table.el :: cistern-test-table-sourcing`
  (red commit; red run failed `Symbol's value as variable is void:
  cistern--tile-table`), then green: `cistern--tile-table` defconst (pinned
  shape, plist `(:glyph :passable :buildable :firebreak :conn)`),
  `cistern--tile-glyph` / `cistern--tile-passable-p` accessors, procgen ore
  placement and `cistern--walkable-p` routed through the table
  (`cistern--procgen-place` added; the passability membership list died).
- Outcome: GREEN on first implementation run; pair-1 test re-run green.
- Evidence: batch `emacs -Q --batch -l src/cistern-domain.el -l
  tests/domain-tile-table.el -f cistern-test-table-sourcing` exited silent;
  red run output captured above.
- Lesson: the pinned table shape survived first procgen contact with no
  field added/renamed — `:buildable` was already anticipated by plan 01 and
  sufficed for table-validated placement. The static no-pcase check reads
  forms with `read` after stripping the table defconst, so comments and
  strings can never false-positive.
- Change for next attempt: plumbing membership (`memq '(toilet pipe tank)`,
  needed by Pair 4's flood) is NOT expressible via the pinned table fields
  without overloading `:conn`; keep it a list until R7 gives `:conn` its
  real representation.

---

## L-004 (2026-09-03, run: impl-phase1 — Pair 3, map integrity across seeds)

- Attempt: Red test `tests/domain-map-integrity.el ::
  cistern-test-map-integrity-seeds` (red commit). Red run failed with
  `Error: void-function (cistern--connected-tanks)` — the connectivity
  half of the flood/connection block had not been ported yet (plan 01
  schedules it under Pair 4's green, but this test asserts connectivity;
  the minimal `cistern--flood` / `--connected-tanks` / `--toilet-usable-p`
  port therefore landed in Pair 3's green). A second RETRY inside the
  cycle: the test itself used `(cdr p)` on spawn lists `(12 6)` → `y=(6)`,
  `wrong-type-argument number-or-marker-p (6)`; fixed to `(nth 1 p)`.
  Green = reservation discipline (`cistern--procgen-reserved-p`: 4 spawn
  cells + 4 starter chain cells, checked inside `cistern--procgen-place`
  and door carves) + minimal connection port. All 5 seeds green.
- Evidence: with reservation disabled via `cl-letf` probe, the pinned
  seed set {20260830,1,2,3,4} produced ZERO spawn-on-wall hits — the
  predicted "spawned-on-a-wall" contact bug is probabilistic (~13% across
  these 5 seeds given spine x∈9..32 and cross y∈3..12), not certain.
- Lesson: the invariant must hold by construction, not by the luck of the
  pinned seed set — reservation guarantees it for any future seed and any
  procgen re-tuning. Second lesson: tests are also run-death territory;
  `(car/cdr)` vs `(nth)` on coordinate lists cost one retry — assert
  helpers should unpack coordinates once.
- Change for next attempt: Pair 4 ports the movement half
  (`--walkable-p` consumers, occupancy, seek/step/shuffle) and the four
  phases; re-use `cistern--flood` as-is (single primitive, already
  landed).

---

## L-005 (2026-09-03, run: impl-phase1 — Pair 4, R9 domain tick headless)

- Attempt: Red test `tests/domain-tick.el :: cistern-test-tick-headless`
  (red commit; red run: `Symbol's function definition is void:
  cistern--sim-tick`). Green = verbatim port of worker lifecycle
  (:236-258), occupancy/dist-from/free-usable-toilets (:149-195),
  seek/step/shuffle/finish-use/add-hazard/accident (:262-420), four
  phases (:422-485), and `cistern--sim-tick` (:487-493 minus the
  tutorial hook). One RETRY inside the cycle: the apply-patch insertion
  landed the sim block after `cistern--toilet-usable-p`, duplicating
  `cistern--walkable-p` (Pair 2 already created the table-driven one) and
  leaving a stale trailing section; duplicate deleted before first run.
- Outcome: GREEN (tick counter = 1 after one `cistern--sim-tick`, = 21
  after 21; map-integrity regression re-run green).
- Evidence: batch `emacs -Q --batch -l src/cistern-domain.el -l
  tests/domain-tick.el -f cistern-test-tick-headless` exited 0, silent.
- Lesson: growing one file across five pairs makes duplicate-definition
  drift the top mechanical hazard — before committing, `grep '^defun'`
  for duplicates. Second: the tutorial hook's removal is clean because
  the phase list is explicit in `cistern--sim-tick`; keep it that way in
  Phase 2 (game layer wraps, domain never references tutorial state).
- Change for next attempt: Pair 5 must exercise determinism over the NEW
  procgen maps (not the legacy hardcoded layout) — sorted hash outputs
  already in place (`--connected-tanks`, `--free-usable-toilets`); audit
  any new hash iteration for state-affecting order.

---

## L-006 (2026-09-03, run: impl-phase1 — Pair 5, determinism)

- Attempt: Red test `tests/domain-determinism.el :: cistern-test-determinism`
  (red commit `test: R9 failing — determinism`). RED RUN UNEXPECTEDLY
  PASSED: same seed twice already gave identical map hash and identical
  50-tick trajectory (alloy, contam, rng, full map, worker states). Per
  protocol the premise was stopped and corrected before any green: the
  test now also runs `cistern-test-determinism-order`, which builds two
  logically identical states whose plumbing hashes are filled in opposite
  insertion orders (the plan 01 §1.5 suspect: hash-iteration-order leaks)
  and asserts identical trajectories. Two further in-cycle RETRYs were
  test-machinery only: `sxhash`-style depth issue avoided (L-002 lesson
  applied — secure-hash used from the start), but `equal<` does not exist
  in Emacs 31.1 batch → replaced with an explicit key-less comparator;
  the floor-triple scan originally required x=0 row starts (always border
  wall) → fixed to `(% i w) <= w-3`.
- Outcome: GREEN with NO implementation change — the verbatim port
  inherited legacy determinism; the order-stressor also passes because
  `cistern--connected-tanks` and `cistern--free-usable-toilets` sort
  their maphash outputs and every other choice scans by index or uses
  strict-< selection.
- Evidence: batch runs of both entry functions exited 0 (silent); the
  first red-run output was empty success, not a failure — recorded here
  verbatim as the honest R10 deviation for this pair: the failing-first
  ritual found no bug because none existed; the assert is retained as a
  permanent tripwire (plus a second entry for insertion-order robustness).
- Lesson: an expected-failure checkpoint can be green on arrival when the
  green minimum is a faithful port of proven code — the roguelike-agentic
  move is to strengthen the probe until it discriminates (here: state
  equivalence under opposite hash fill orders), then keep it. Do not
  manufacture a bug to satisfy the ritual.
- Change for next attempt: Phase 2 adds verbs (hash mutation via
  remhash/puthash); any new maphash iteration whose order feeds state
  must sort or index-scan — this tripwire pair will catch violations.

---

## L-007 (2026-09-04, run: impl-phase2 — Pair 1, R8 demolish)

- Attempt: Red test `tests/game-demolish.el :: cistern-test-demolish`
  (red commit `3d83c39`; red run: `Symbol's function definition is
  void: cistern--cmd-build` — the expected void-function red, game
  layer absent). Green = new `src/cistern-game.el` with
  `cistern-cost-demolish` (3), `cistern--cmd-build` ported verbatim
  from cistern.el:498-525, and `cistern--cmd-demolish` (legality =
  player-placed kinds only, in-use toilet refused, cell → floor,
  remhash from BOTH hashes, no refund). The demolish implementation
  itself was green on the first run; three RETRYs were all test-fixture
  bugs: (1) a paren mismatch aborted the load before the first red run;
  (2) the fixture floor-run finder checked plumbing-adjacency only for
  the run's LAST cell — a run adjacent to the starter plumbing merged
  the built network with the starter tank, so the demolish tank left the
  toilet still usable via the starter tank; fixed to exclude cells
  plumbing-adjacent for EVERY run cell; (3) two alloy-accounting asserts
  spanned a build call (toilet build costs 10), so "refusals cost
  nothing" compared across the build — capture moved inside the refuse
  attempt.
- Outcome: GREEN. Full canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 7 TESTS PASSED, exit 0.
- Evidence: red run output `Symbol's function definition is void:
  cistern--cmd-build` (exit 255); green run prints
  `CISTERN-DEMOLISH-OK` (exit 0); full suite `ALL 7 TESTS PASSED`.
- Lesson: fixture networks must be hydraulically isolated from procgen's
  starter plumbing — flood-fill merges any 4-adjacent plumbing cells, so
  a "closed" test network is only closed if every cell (not just the
  endpoint) is plumbing-adjacency-free; otherwise connection assertions
  pass/fail through the wrong network. Second: assert spans must not
  cross cost-charging calls (build) when asserting charge-free behavior.
- Change for next attempt: later verb tests (Pairs 4-5) reuse the
  plumbing-adjacency-free floor-run finder pattern verbatim; any new
  fixture network asserts its own isolation first
  (`cistern--toilet-usable-p` on the wired toilet before mutating it).

---

## L-008 (2026-09-04, run: impl-phase2 — Pair 2, R6 exactly one tick)

- Attempt: Red test `tests/game-tick.el :: cistern-test-exactly-one-tick`
  (red commit `e7e32ba`; red run: `Symbol's function definition is void:
  cistern--do-tick`). Green = `cistern--do-tick` orchestrator in
  `src/cistern-game.el` (over-guard + `cistern--sim-tick` +
  `cistern--tutorial-advance`) plus the tutorial mechanism holder
  (`cistern--tutorial-steps` returning `'()`, advance per
  cistern.el:589-599 minus the nine legacy steps). Implementation was
  green first run; two in-cycle RETRYs were test-machinery: (1) the
  file-level static check resolved the repo root via `load-file-name`,
  which is nil under `-f` after `-l` (it is only bound during load) —
  wrong-type-argument stringp nil; fixed by pinning the root in a
  defconst computed at load time, mirroring tests/run.el's pattern;
  (2) the no-`cistern-run-10` tripwire fired with a false positive —
  the green docstring itself contained the literal symbol as prose
  ("`cistern-run-10' is NOT ported"). Per the probe rules the probe was
  NOT weakened; the docstring was reworded so src/ now contains zero
  occurrences of the symbol.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 8 TESTS PASSED, exit 0.
- Evidence: red run `Symbol's function definition is void:
  cistern--do-tick` (exit 255); green prints `CISTERN-TICK-OK` (exit 0);
  full suite `ALL 8 TESTS PASSED`.
- Lesson: static tripwires over file text are load-bearing but blind to
  intent — prose in comments/docstrings trips them exactly like real
  code, so src/ files must never quote forbidden symbols, even to
  disclaim them. Second: `load-file-name`/`buffer-file-name` are only
  bound during load; any test needing its own location must compute it
  at load time into a defconst.
- Change for next attempt: later src/-tree static checks (R2 hjkl grep,
  R9 layer checks) use the same load-time-root defconst pattern, and
  src/ prose never quotes the forbidden symbol.

---

## L-009 (2026-09-04, run: impl-phase2 — Pair 3, R5 rewards placeholder)

- Attempt: Red tests `tests/game-rewards.el ::
  cistern-test-rewards-default` and `tests/game-rewards-consumption.el
  :: cistern-test-rewards-consumption` (red commit `62d4a69`; red runs:
  `cl-assertion-failed (fboundp 'cistern--rewards-eval)` and
  `Symbol's function definition is void: cistern--rewards-eval`).
  Green = `cistern--rewards-eval` placeholder in `src/cistern-game.el`
  returning (state unchanged, default outcome plist verbatim, empty
  intents) as a 3-list; a defconst pins the default outcome; NO
  consumption logic (goal cards, milestones, reputation, particles)
  pre-built — least-active-decisions.
- Registration decision (planned deviation, documented per plan 01
  §2.1 Pair 3): the consumption test stays INTENTIONALLY RED until
  Phase 4b — the REWARDS-DESIGN consumption is 4b's deliverable, so a
  lingering red is the required state, not a defect. It is therefore
  NOT registered in tests/run.el `cistern-test-entries`; the canonical
  runner stays green (ALL 9) for Pairs 4-5. The runner's file-load
  glob still loads the file (defuns only, no side effects), so the red
  is inert until 4b registers it.
- Outcome: GREEN for the placeholder; consumption red by design.
  Canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 9 TESTS PASSED, exit 0; consumption
  standalone still fails on the first M8 assert (`member 'big-cistern
  ...`), exactly as intended.
- Evidence: red runs above (exit 255); green prints
  `CISTERN-REWARDS-DEFAULT-OK` (exit 0); full suite `ALL 9 TESTS
  PASSED`; consumption run exits non-zero on the milestone assert.
- Lesson: the bloat guard (plan 01 §2.5) held — the placeholder is one
  defconst + one list-literal return, and the temptation to stub score
  math or milestone tables was declined; the default outcome must
  contain literally zero logic so 4b's consumption test can
  discriminate real implementation from stubs. Return-shape (3-list:
  state, outcome, intents) is pinned by the placeholder test and
  asserted by both tests, so 4b cannot silently reshape the contract.
- Change for next attempt: Phase 4b registers
  `cistern-test-rewards-consumption` in `cistern-test-entries` as part
  of its red/green pair; Pairs 4-5 must not "fix" the red consumption
  test.

---

## L-010 (2026-09-04, run: impl-phase2 — Pair 4, R1 cursor + click)

- Attempt: Red test `tests/game-cursor.el ::
  cistern-test-cursor-and-click` (red commit `e351d41`; red run:
  `void-function cistern--cmd-cursor`). Green = `(armed-verb nil)`
  slot added to the domain `cistern-st` struct (spec §3.4 pins
  armed-verb as state; the struct is domain-owned so the field lands
  there — smallest shape that makes "armed" legible),
  `cistern--cmd-cursor` (st dir) — legacy :862-867's in-bounds-refuse
  guard minus the render, with R2 arrow directions instead of dx/dy —
  and `cistern--cmd-click` (st x y): unarmed ⇒ cursor move, no tick;
  armed ⇒ place via cmd-build legality, on success clear the verb and
  advance exactly one tick via `cistern--do-tick`; refusal leaves
  state untouched. Implementation was green on the first run — no
  in-cycle RETRYs.
- Pinned ambiguities (spec is not explicit; minimal readings noted
  here per the plan's pin-and-note rule):
  1. Move-only clicks do NOT tick — R6 lists SPACE/RET/click-with-verb
     as the ticking actions; a bare cursor-move click is not among
     them. A click that places ticks exactly once (R6 cross-assert).
  2. A failed (illegal/unaffordable) armed click does not tick and
     does not clear the armed verb — "refused with state untouched".
  3. An armed click does not move the cursor — R1's cursor-move is the
     unarmed click's job; placement happens at the clicked cell.
  4. The armed verb clears on successful placement (spec §3.4 "set/
     cleared by use-cases" needs a clear site; after-place is the
     smallest). The keymap half that arms verbs is Phase 3.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 10 TESTS PASSED, exit 0.
- Evidence: red run `void-function cistern--cmd-cursor` (exit 255);
  green run `PASS cistern-test-cursor-and-click` inside the suite's
  `ALL 10 TESTS PASSED` (exit 0).
- Lesson: cmd-build's nil-on-refusal return (inherited from legacy,
  which logged and returned nil) made click's success detection a
  cell comparison — `(eq (cistern--cell st x y) verb)` — rather than
  a return-value check; safe precisely because cmd-build refuses
  non-floor cells, so cell==verb can only mean "just placed". Callers
  that need richer outcome info will need cmd-build to return a
  result value; that reshaping is 4b/5 territory if it appears.
- Change for next attempt: Pair 5's selftest port should exercise
  click-place through the same armed-verb path (no direct cmd-build
  bypass) so the tick-coupling invariant holds everywhere.

---

## L-011 (2026-09-04, run: impl-phase2 — Pair 5, R9 extended selftest/soak)

- Attempt: Red test `tests/game-selftest.el ::
  cistern-test-legacy-verb-blocks` (red commit `a0db103`; red run:
  `cl-assertion-failed (fboundp 'cistern-run-selftest)`). Green =
  `src/cistern-game.el` gains `cistern--cmd-decon` (:527-538, hazard
  only) and `cistern--cmd-purge` (:540-551) — both in Phase 2's verb
  set per plan 01 §2's goal line — plus `cistern-run-selftest`
  (legacy :937-1035 blocks ported onto src/ layers, with seed-42
  procgen landmarks; seating/decon/no-statue blocks pinned to
  guaranteed-floor reserved cells — spawn cells and starter-toilet
  floor neighbors — instead of legacy hardcoded coordinates) and
  `cistern-run-soak` (:1037-1137 verbatim, 600 ticks, 'one breach from
  condemnation' tuning intact). Extensions per spec §5.1: demolish
  legality with the armed-verb click path ONLY (L-010 change applied —
  pipe placed via `cistern--cmd-click`, assert place⇒exactly-one-tick),
  hash-cleanup invariant, procgen variety (5 seeds, ≥3 signatures,
  secure-hash over prin1-to-string per L-002), rewards default. One
  in-cycle RETRY, test-only: the "refusals are free" alloy assert
  spanned the armed toilet placement (L-007's accounting trap again) —
  capture moved inside the refuse attempt.
- Intentional deviation noted: the soak bot keeps direct
  `cistern--cmd-build` calls (verbatim :1083-1137); routing them
  through the armed-verb click path would double-tick each bot
  iteration (click ticks + loop tick) and change the surviving-run
  semantics. The place⇒one-tick coupling is asserted where it belongs:
  every player-driven click-place (selftest demolish-legality block,
  Pair 4's test).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 11 TESTS PASSED, exit 0. Standalone
  batch entries: `cistern-run-selftest` → CISTERN-SELFTEST-OK (exit
  0, 3.4s); `cistern-run-soak` → CISTERN-SOAK-OK tick=600 contam=1
  pop=8 alloy=417 (exit 0, 48s — the per-tick full-map scans; fine
  for a soak, noted for Phase 3 perf if invoked in-loop).
- Lesson: porting hardcoded-coordinate test blocks onto seed-driven
  procgen means replacing every magic coordinate with a
  procgen-guaranteed anchor (reserved cells: spawns, starter
  plumbing, west gate, or floor-neighbors found at runtime); a block
  that "works" for the test seed may be sitting on a wall for seed N.
  Second: the L-007 assert-span trap recurs under time pressure —
  any "this operation is free" assert must have its alloy capture
  immediately bracketing the operation.
- Change for next attempt: Phase 3's input adapter maps keys/mouse to
  the use-case verbs (cmd-cursor/cmd-click/cmd-build/…) — no new
  placement legality, and the tick coupling stays inside cmd-click
  where the tests pin it.

---

## L-012 (2026-09-04, run: review-phase2 — Phase 2 closing review)

- Attempt: phase-closing conformance/simplification review (six-item
  checklist). Small fixes committed directly: floor-run fixture
  consolidated 3 copies → 1 (`d5d4a23`), rewards-eval 3-list named in
  spec R5 / plan 01 §2.3 / REWARDS-DESIGN §5 wording (`9300307`), one
  stale comment fixed (`8b4555d`). All "Change for next attempt"
  directives in L-002..L-011 audited: applied or superseded except the
  two structural findings below.
- Structural findings (NOT fixed in passing; each lists its owning
  phase):
  1. Worker identity glyphs live in the domain layer outside the tile
     table (`cistern--worker-glyphs` vector, `cistern--worker-glyph`,
     consumed by the accident log line) — a presentation concept in the
     pure-sim layer, verbatim legacy port. Phase 3 (view): decide
     whether the view renders worker identity from a stable per-worker
     index and the domain log carries ids instead of glyphs.
  2. The soak bot's purge-target selection iterates
     `(cistern-st-tanks st)` unsorted — an undocumented exception to
     L-006's directive ("any new maphash iteration whose order feeds
     state must sort or index-scan"). Deterministic only under
     identical insertion history, which the seed-1 soak satisfies.
     Next soak-touching phase: sort the keys or record the exception
     explicitly, L-011-cmd-build style.
  3. The L-007 floor-run fixture (`cistern-test-game--floor-run`) lives
     in src/cistern-game.el (required by the spec §5.1-pinned
     selftest) and, since `d5d4a23`, is also consumed by
     tests/game-cursor.el and tests/game-demolish.el. Accepted inward
     dependency; if the selftest ever leaves src, move the fixture to
     a tests helper. Phase 3 note only.

---

## L-013 (2026-09-04, run: impl-phase3 — Pair 1, R2 arrow-only keymap)

- Attempt: Red test `tests/test-r2-keymap.el :: cistern-test-r2-keymap`
  (red commit `75ca226`; red run: `Cannot open load file:
  .../src/cistern.el` — the driver file is the deliverable, exit 255).
  Green = new driver `src/cistern.el` (`cistern-mode` + keymap per plan
  02 §2: SPC/RET tick, four arrows → cursor commands, t/p/K arm+build,
  d demolish, c/x decon/purge, T/n/?/q; NO hjkl; `r` unbound until Pair
  3) + input adapter `src/cistern-input.el`
  `cistern-input-cursor-move` (north/south/west/east → the use case's
  up/down/left/right). Runner glob extended to load `tests/test-*.el`.
  Render wiring deferred to Pair 4 per plan 02 §2 (driver commands
  mutate state only; no `cistern--refresh` yet).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 12 TESTS PASSED, exit 0. R9 gate re-run:
  domain+game batch load + full tick OK (`R9-TICK-OK tick=1`); grep
  over non-comment lines finds no driver/view/input symbol in
  cistern-domain.el / cistern-game.el.
- Evidence: red run above (exit 255); standalone green run
  `R2-KEYMAP-OK` (exit 0); full suite `ALL 12 TESTS PASSED` (exit 0).
- One in-cycle RETRY, probe-only: the grep-level hjkl tripwire matched
  `"K"` (the build-tank key) — Emacs `re-search-forward` char classes
  are case-insensitive by default, so `[hjkl]` matched uppercase K.
  Probe fixed by pinning `case-fold-search nil` (guard strengthened,
  never weakened, per L-008's probe rules). A second probe refinement
  in the R9 gate: `cistern--step-toward` contains the `cistern--st`
  substring, and game.el's header comment disclaims `cistern--st` in
  prose (the L-008 prose-blindness class) — the gate strips comment
  lines and uses symbol boundaries. Neither was adapter leakage; no
  §5 run-death trigger fired.
- Pinned readings (plan 02 §4 D-pins + this pair's notes):
  1. `d` = demolish at cursor via `cistern--cmd-demolish`, NOT armed —
     armed-verb is spec §3.4's "build verb" field and cmd-click only
     places toilet/pipe/tank; arming 'demolish would silently degrade
     every click to a cursor move. If armed-demolish-click is wanted,
     cmd-click gains the branch in Pair 2 as its own pinned decision.
  2. c/x stay immediate at-cursor use-case calls (D3's arm+build
     applies to build keys; arming c/x would poison cmd-click's memq
     guard the same way as (1)).
  3. Arming t/p/K = thin driver-owned setter + `cistern--cmd-build` at
     cursor (D3); no arm use-case exists in the game layer.
     `cistern-input-arm-verb` (Pair 2) is where the adapter formalizes
     it; the driver commands then route through it.
  4. `r` unbound in Pair 1 (run-10 stays dead; the auto-run toggle
     binding arrives with Pair 3's implementation).
- Lesson: static probes over source text fail on case and substring —
  any char-class probe pins `case-fold-search nil`, and any symbol
  probe needs boundaries plus comment stripping (second L-008 corollary:
  prose mentioning a symbol is not a reference, but probes can't tell).
- Change for next attempt: Pair 2's click adapter keeps the
  up/down/left/right direction vocabulary internal to the use case
  (north/south/west/east is the adapter's translation, this pair's
  only mapping); when `cistern-input-arm-verb` lands, migrate the
  driver's `cistern--arm-and-build` onto it (thin setter → adapter
  call) instead of keeping two arming sites.

---

## L-014 (2026-09-04, run: impl-phase3 — Pair 2, R1 mouse click)

- Attempt: Red test `tests/test-r1-click.el :: cistern-test-r1-click`
  (red commit `1d3423a`; red run: `void-function cistern-input-click`,
  exit 255). Green = `cistern-input-click`/`cistern-input-arm-verb` in
  the input adapter (both one-line delegations to use cases),
  `cistern--cmd-arm-verb` in the game layer (L-013's queued arming
  migration: arming is now a use-case call — L-010 pin 4; the driver's
  Pair-1 thin setter is GONE, `cistern--arm-and-build` routes through
  the adapter, and the R1 test grep-pins that src/cistern.el contains
  no setter and no direct `cistern--cmd-click` bypass), the driver
  mouse half (`<mouse-1>` bound in `cistern-mode-map` to
  `cistern-click`, which translates the event via the pure
  `cistern-view--cell-at` then calls the adapter), and the Pair-2
  slice of `src/cistern-view.el` (geometry only; glyph projection
  stays Pair 4).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 13 TESTS PASSED, exit 0. R2 regression
  standalone re-run green. R9 gate re-run: non-comment grep clean on
  domain/game; batch full tick OK (`R9-TICK-OK tick=1`).
- Evidence: red run above (exit 255); green runs `R1-CLICK-OK` (exit
  0) and `R2-STILL-OK`; full suite `ALL 13 TESTS PASSED` (exit 0).
- Pinned readings:
  1. `cistern-view--cell-at` takes (st line col), not the plan's
     "(line col)" — bounds-clamping needs the state's w/h, and an
     unarmed out-of-map click must be refused (cmd-click sets the
     cursor unchecked), not land the cursor off-grid. Plan signature
     amended accordingly; documented in the file header.
  2. `<mouse-1>` binds directly in `cistern-mode-map` per the pair
     directive, superseding plan 02 §2's separate
     `cistern-mode-mouse-map` defvar (one map, one place; the plan's
     separate map bought nothing).
  3. Clicks outside the map (header/log lines) are ignored by the
     handler (`when xy`), not cursor-moved.
  4. The handler's buffer-coordinate source is
     `posn-point` → `line-number-at-pos` + `current-column` under
     `truncate-lines`; glyph display-width quirks (ambiguous-width
     unicode columns) are a known ceiling — revisit only if real
     clicks land a cell off by columns (ponytail note in cistern.el).
  5. Adapter `cistern-input-arm-verb` arms only; the keyboard
     build-at-cursor half of D3 stays in the driver command (adapter
     translates, it does not bundle two use-case calls).
- Lesson: the arming migration was cheap precisely because L-013 had
  queued it as a named change-for-next-attempt with the target shape
  (use-case + adapter + no second site) pinned in advance — the green
  diff had no design decisions left to make mid-flight.
- Change for next attempt: Pair 3's auto-run toggle must read
  `cistern--st` ONLY inside its timer callback (D1's single
  exception); the toggle function itself takes st like every other
  adapter entry. Pair 4's render must keep `cistern-view--header-lines`
  truthful — the geometry helper and the render share that constant,
  so the first render is where a drifted origin would surface.
