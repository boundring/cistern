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

---

## L-015 (2026-09-04, run: impl-phase3 — Pair 3, R6 auto-run timer)

- Attempt: Red test `tests/test-r6-timer.el :: cistern-test-r6-timer`
  (red commit `6fc0513`; red run: `void-function
  cistern-input-auto-run-toggle`, exit 255). Green = the timer
  machinery in `src/cistern-input.el`: the D2 handle defvar
  `cistern--auto-run-timer` (form lives in the ADAPTER, not the
  driver file — see pin 1), `cistern-input-auto-run-toggle` (st)
  scheduling/cancelling the 0.2s chain link, and
  `cistern-input--auto-run-callback` (one `cistern--do-tick` +
  reschedule; D1 exception — the callback alone reads the driver's
  `cistern--st`); driver gains the `'r'` binding and the thin
  interactive `cistern-auto-run-toggle` command. No real timers in
  tests — schedule/cancel captured via `cl-letf` stubs (§5.2).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 14 TESTS PASSED, exit 0. R1/R2
  regressions re-run green standalone. R9 gate clean (non-comment
  grep + batch tick); `cistern-run-10` absent from all of src/ (grep
  and obarray pin).
- Evidence: red run above (exit 255); green run `R6-TIMER-OK` (exit
  0); full suite `ALL 14 TESTS PASSED` (exit 0).
- Pinned readings / deviations:
  1. The D2 handle defvar's FORM lives in cistern-input.el, not
     cistern.el: an adapter-side callback that reschedules must
     update the handle, and adapter→driver references are outward
     dependencies; driver→adapter is the correct inward direction.
     D2's substance (timer plumbing, never game state, never enters
     cistern-st, documented exception to the one-global rule) is
     intact — only the defvar form's home file moved.
  2. REPEAT-t deviation from plan 02 §1 Pair 3: the schedule records
     REPEAT nil and the callback explicitly reschedules each fire
     (one-shot self-rescheduling chain). The pair directive's test
     item ("the callback, invoked directly, advances exactly one
     tick AND reschedules itself") is only observable with an
     explicit reschedule record, and REPEAT t + an explicit
     reschedule would stack a fresh repeating timer per fire.
     Semantics match the plan's intent: 0.2s cadence, toggle-off
     cancels, condemned ends the run.
  3. The toggle takes ST per the adapter convention (L-014) but does
     not use it — the handle and cadence are not per-state; the
     signature keeps the adapter's (st …) uniformity and D1's
     "only the callback reads the global" boundary honest.
  4. Condemned-sector stop is silent (no new log line — the
     condemned message belongs to the tick command; Pair 4's render
     surfaces the condemned state).
- Lesson: plan text written before the pair directive ("REPEAT t")
  lost to the directive's observable test contract — when a plan
  detail and a test item conflict, the test item wins and the
  deviation is ledgered with the stacking rationale, not silently
  reconciled.
- Change for next attempt: Pair 4's render must (a) keep
  `cistern-view--header-lines` truthful (L-014), (b) wire
  `cistern--refresh` into the auto-run callback's per-fire path (the
  callback currently advances state without a repaint — the driver
  owns buffer mutation, so the refresh lands with the view), and (c)
  remember the REWARDS-DESIGN §4 advance-particles pointer already
  in the callback docstring is 4b's, not Pair 4's.

---

## L-016 (2026-09-04, run: impl-phase3 — Pair 4, R7 glyphs + full render)

- Attempt: Red test `tests/test-r7-glyphs.el :: cistern-test-r7-glyph`
  (red commit `fbd9d66`; red run: `void-function
  cistern-view--cell-glyph`, exit 255). Green = the full view
  projection in `src/cistern-view.el` (faces ported from legacy
  :604-621 + new `cistern-pipe-live`/`cistern-pipe-dead`; table-driven
  legend/inspector/faces; worker identity glyphs moved here per
  L-012 finding 1; `cistern-view--render` = pure propertized string
  with the 3-line header contract intact), the driver's
  `cistern--refresh` wired into every state-mutating command (entry,
  new-game, skip-tutorial, tick, 4 cursor commands, click handler,
  arm-and-build, demolish, decon, purge) and into the auto-run
  callback's per-fire path via the driver-registered
  `cistern-input--refresh` closure, and the domain query functions
  the projection needed: `cistern--toilet-state` (busy/usable/down
  enum), `cistern--tank-load`, `cistern--tank-load-total`,
  `cistern--toilets-backed-p` — hash access stays in the domain; the
  view touches state only through queries + grid primitives (D6).
  L-012 finding 1 RESOLVED: `cistern--worker-glyphs` +
  `cistern--worker-glyph` deleted from the domain;
  `cistern-view--worker-glyph` renders identity from the stable
  creators-list index; `cistern--accident` logs
  "BREACH — CREATOR #%d OVERFLOWED AT (x,y)" — the domain log carries
  the index, no glyph string. `cistern-version` moved to the domain
  constants block (the view header reads it inward).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 15 TESTS PASSED, exit 0. R1/R2/R6
  regressions re-run green standalone (cell-at geometry unchanged).
  R9 gate clean. No tile glyph literals and no pcase/cl-case/case in
  view source (test-pinned).
- Evidence: red run above (exit 255); green standalone exit 0; full
  suite `ALL 15 TESTS PASSED` (exit 0).
- Pinned readings:
  1. Refresh wiring shape (L-015 change item b): adapter defvar
     `cistern-input--refresh` (nil default) + the driver's toggle
     command registers `#'cistern--refresh` on each toggle
     (idempotent). Driver→adapter registration is inward; lazy
     registration keeps the callback a no-refresh no-op under the
     Pair-3 test's direct invocations (no test churn).
  2. Tile-table glyph literals: the view builds the glyph legend,
     help line, and all cell glyphs from the table; the pipe's
     box-drawing shapes are a view-local topology table (the tile
     table is one-glyph-per-kind; the connection VARIANT is R7's
     view job — plan 01 §1.3 note). The static probe asserts no
     QUOTED tile glyph literal in view source (L-013 probe-precision:
     a bare-char regex tripped the `1+` function call — probe refined
     to string-literal form, guard kept at full strength).
  3. The view's kind dispatch is a `cond` selecting CONNECTION
     variants (pipe/toilet/tank) with base glyphs/faces from tables —
     the greppable rule (test-pinned) is "no pcase/cl-case/case and
     no tile-glyph literals", not "no cond"; the tile table remains
     the sole glyph source (R3b).
  4. Legacy inspector's hardcoded "(4 alloy)" decon price dropped
     from the hazard description (it contradicted
     `cistern-cost-decon` = 3); prices are advertised via the
     format-driven help line.
  5. Header decorative ▓▓ glyphs replaced with plain text (the
     glyph-literal probe class); tutorial line renders only when the
     current step exists (empty Phase-2 table ⇒ no line, mechanism
     intact for 4a).
- One in-cycle RETRY, probe-only: the quoted-literal refinement
  above. One apply-patch misplacement (L-005 class) introduced
  duplicate cursor/click defuns mid-green — caught by the standing
  duplicate-defun grep before any test run, removed in the same
  cycle.
- Change for next attempt: Pair 5 plugs `cistern-view--celebration-overlay`
  into `cistern-view--map-rows` at the marked D5 precedence point
  (cursor > worker > particle > cell) — the overlay must be empty for
  the default outcome so render output stays byte-identical with the
  hook short-circuited (R5 render half). The projection-only greps
  extend to `cistern-view.el` hash-layout access at Pair 5 (plan 02
  §R9 backstop) — the new domain query functions are the sanctioned
  access path.

---

## L-017 (2026-09-04, run: impl-phase3 — Pair 5, R5 celebration hook)

- Attempt: Red test `tests/test-r5-hook.el :: cistern-test-r5-hook`
  (red commit `754ccaf`; red runs: first a test-authoring bug — a
  dotted-pair literal `(cons 999 . 999)` aborted the file load with
  end-of-file before any assert ran, then a missing defun-closing
  paren (the L-005/R6-RETRY class, caught by a paren-depth scan) —
  the REAL red: `particle glyph painted on the map row`, the Pair-4
  render ignoring celebration intents, exit 255). Green =
  `cistern-view--celebration-overlay` (st) in the view: reads
  `cistern--rewards-eval` exactly ONCE, returns (MAP-ALIST .
  BANNER-TEXT); the render binds it once, feeds the map alist into
  `cistern-view--map-rows` at the D5 precedence point (cursor >
  worker > particle > cell; a particle loses to cursor AND worker),
  and emits BANNER-TEXT into the reserved post-map row (between map
  and inspector; empty by default).  Overlay is transient by
  construction: state untouched, next frame restores; out-of-bounds
  intents clipped via `cistern--in-bounds-p`.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 16 TESTS PASSED, exit 0. R1/R2/R6/R7
  regressions re-run green standalone; cell-at geometry unchanged by
  the banner row (post-map row only). Projection-only backstop
  extended per the L-016 change item: zero gethash/maphash/
  cistern-st-toilets/cistern-st-tanks occurrences in
  cistern-view.el/cistern-input.el — the domain query functions are
  the sanctioned access path.
- Evidence: red run above (exit 255); green run `R5-HOOK-OK` (exit
  0); full suite `ALL 16 TESTS PASSED` (exit 0).
- Pinned readings:
  1. Intent shape (the contract 4b's particle field drops into): a
     plist (:pos (X . Y) :glyph S :face FACE-OR-PALETTE-ENUM :layer
     sparkle|popup|banner); banner intents carry :text instead of
     :pos. Faces resolve through `cistern-view--palette-faces`
     (success/warning/error/info/bonus → Emacs faces, plan 02 §3.2);
     unknown faces pass through (hand-built test intents use Emacs
     faces directly). Pos is the codebase's (X . Y) cons convention.
  2. §3.6's "rewards-eval once per render" is enforced by binding
     the overlay result once in `cistern-view--render`; the first
     green draft called the overlay function twice (map + banner) —
     caught in review of my own diff, fixed before any commit.
  3. Banner = plain text in the reserved row with the
     `cistern-header` face; ceremony copy/centering is DEFERRED to
     Phase 4 (plan 02 §4). Banner row always emitted (stable layout),
     empty for the default outcome.
  4. advance-particles wiring point stays pinned to the auto-run
     timer callback (§3.1; docstring pointer already in the callback)
     — nothing pre-built for Phase 4.
- Lesson: the two aborting red runs were authoring bugs that the
  fail-first discipline caught cheaply — a red run that dies at LOAD
  is not the requirement's red; re-check the test parses before
  reading anything into the failure. Paren-depth scan (python one
  count) found the missing closer in one shot after check-parens
  flagged it.
- Change for next attempt: Phase 4b replaces the hand-built intents
  with the real particle field per REWARDS-DESIGN §4 ({pos, vel, ttl,
  glyph, face, layer}, K=64 FIFO cap) — the overlay's intent→alist
  mapping is the consumption surface; extend it (vel/ttl handling
  happens in the domain/use-case field, NOT the view), and give the
  banner its centered-composition treatment then. Phase 4a's tutorial
  scenarios render through the unchanged `cistern-view--render`.

---

## L-018 (2026-09-04, run: review-phase3 — Phase 3 closing review)

- Attempt: phase-closing conformance/simplification review
  (HANDBRIEF-TEMPLATE six-item checklist). Small fixes committed
  directly: paren-balance line added to the standing checklist (L-017's
  two load-abort authoring bugs had no checklist item); stale
  "Phase 3 Pair 4 wires `cistern--refresh'" driver-header comment
  updated; plan 02 §2 annotated with the ledgered readings its text
  still contradicted (cell-at takes st — L-014 pin 1; timer-handle
  defvar form lives in the adapter — L-015 pin 1; only t/p/K arm,
  c/x immediate, field named `cistern-st-armed-verb` per spec §3.4 —
  L-013 pin 2; one keymap, no separate mouse map — L-014 pin 2);
  plan 03's "no commits from the run" header corrected to per-pair
  commits (PROCESS-RETRO P2 conflict class, the L-001-era lesson).
  Ledger audit L-013..L-017: every "Change for next attempt" applied
  in-phase or carried by design (L-017's → 4b). Deferred discipline:
  all D1-D6 pins trace to plan 02 §4 or a ledger entry; no
  undocumented pins found.
- Structural findings (NOT fixed in passing; each lists its owning
  phase):
  1. CARRIED from L-012 finding 2: the soak bot's purge-target
     selection (`cistern-run-soak`'s maphash over `cistern-st-tanks`)
     still iterates unsorted. Phase 3 verified genuinely untouched
     (the phase's only game-layer diff is `cistern--cmd-arm-verb`).
     Next soak-touching phase: sort the keys or record the exception
     L-011-cmd-build style. Fixing it in this review was refused —
     any change to selection order changes the soak trajectory.
  2. Phase 4b: the celebration intent shape pinned in
     `cistern-view--celebration-overlay`'s docstring (L-017 pin 1) is
     the contract the Particle field must drop into unchanged; if 4b's
     field needs :vel/:ttl handling, that lands in the domain
     use-case, never in the overlay mapping (L-017 change item).

---

## L-019 (2026-09-06, run: impl-phase4 — Pair 1, R4 losing scenario)

- Attempt: Red test `tests/test-4a-scenarios.el ::
     cistern-test-4a-losing-breach` (red commit `2db8778`; red run:
     `cl-assertion-failed (fboundp 'cistern-tutorial-run-scenario)`,
     1/17, exit 255→1). Green = `cistern-tutorial-run-scenario` +
     `cistern-tutorial-scenario-losing` + `cistern--scenario-expect-p`
     in `src/cistern-game.el`; scenario is data (seed + script +
     expect + lesson), verbs are Phase 2 use-case calls over ST.
- Scenario-shape desync caught while tuning (expected failure class
     per plan 03 §4a, harvested before it shipped): the obvious losing
     script — pure wait at seed 42 — DOES breach deterministically
     (tick 50, contam 3), but through the wrong mechanism: the starter
     toilet at (3,3) stays wired and reachable the whole run; workers
     breach because one toilet + a filling tank can't serve four
     seekers. That story's lesson would be "build more capacity", not
     the pinned "no reachable wired toilet" premise. The losing script
     was re-tuned to sever the starter line first (`cistern--cmd-demolish`
     at (4,2), verb step), making the breach a pure function of the
     bladder constants (20 + 2/tick → 120 at tick 50; wait 55 = margin,
     derived from cistern-bladder-* constants, not magic counts). Watch
     this class again in pair 2: the winning script's premise must be
     the same seed's need served, not a different failure avoided.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
     -f cistern-run-all-tests`: ALL 17 TESTS PASSED, exit 0.
- Evidence: red run above (exit 1); probe runs — severed-line script
     breaches at tick 50 with contam 4 and `same-hash: t` across two
     runs; green prints `CISTERN-4A-LOSING-OK` (exit 0); full suite
     `ALL 17 TESTS PASSED` (exit 0).
- Lesson: probe the scenario shape BEFORE writing the test — a
     breach that fires for the wrong reason passes the contamination
     assert while lying about the lesson. The expect predicates over
     state (contam > 0, log-contains) cannot discriminate breach
     mechanism; only the script's shape can.
- Change for next attempt: pair 2 (winning scenario) reuses the
     runner and expect interpreter unchanged — data only. The runner
     logs :lesson once when contam first exceeds 0 during waits; if the
     winning scenario ever carries a :lesson, the trigger needs
     revisiting (contam never rises there). Determinism pair (4) is
     expected to fall out; same-hash already holds for this scenario.

---

## L-020 (2026-09-06, run: impl-phase4 — Pair 2, R4 winning scenario)

- Attempt: Red test `tests/test-4a-scenarios.el ::
  cistern-test-4a-winning-clean` (red commit `ebf7575`; red run:
  `cl-assertion-failed (boundp 'cistern-tutorial-scenario-winning)`,
  1/18, exit 1). Green = `cistern-tutorial-scenario-winning` data
  only — runner and expect interpreter untouched (the existing
  `contamination`/`over` keys cover the acceptance; no new key).
  Contamination's counter is monotonic (only ever incremented:
  accident + severed-finish-use), so the final-state `(contamination
  . (= 0))` assert proves contamination stayed 0 through AND at end
  of the script — no mid-run sampling needed.
- L-019 watch item (same seed's need, not a different failure):
  honored. The winning premise IS the pure-wait breach mechanism —
  one wired toilet + a filling tank cannot serve seekers who wander
  east to mine before bladder-seek fires at tick 20. Winning script:
  purge the starter tank (anchor (5,2); clears the 30-load backup
  AND funds the build: +10 alloy → 30 budget) then grow the network
  outward along the seekers' return funnel — pipe (6,2), toilet
  (7,2), pipes (6,3)(6,4)(6,5), toilet (7,5). Every build cell is a
  floor neighbor grown from the reserved starter-plumbing anchors
  (L-011's derivation rule); the data is seed-42-tuned by design —
  plan 03 defers ship-seed choice ("exists a seed where both
  scenarios behave"; 42 is that seed). Horizon mirrors the losing
  scenario: 7 verbs then wait 55, same tick budget.
- Probe harvest (four rejected shapes before D landed, same desync
  class as L-019): (a) second toilet at the starter cluster (V3/V4)
  — toilets exist but workers still breach: the killer is RETURN
  TRAVEL (~25+ detoured ticks from the east mining cluster vs 30
  ticks from bladder-seek to burst), not queueing alone; (b) A-row
  (7,2)+(7,4) — one seat short, worker #1 stood at (7,6) bladder 118
  one step from a free toilet at t50; (c) standalone tank+toilet
  pairs — 25 alloy each, one station cannot buy the missing seat.
  D wins by putting the seat ON the funnel: workers pass (7,5)
  around t45, so the last seeker seats at bladder 118 instead of
  breaching at 120.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 18 TESTS PASSED, exit 0. Probe:
  contam 0, tank-total 40 (purge reset + four deposits = every
  original creator relieved), same-hash across two runs.
- Pinned reading: the winning scenario carries NO :lesson, and that
  is deliberate — R4's acceptance for the winning half is
  "contamination staying 0" on the same seed's need, not a log
  line; the losing scenario's lesson line carries the teaching
  moment. The runner's :lesson trigger (contam > 0 during waits,
  L-019) is therefore unexercised by this scenario by construction.
- Margin note (desync sensitivity): the last seat lands at bladder
  118 of 120 — zero slack. Deterministic at seed 42 (same-hash),
  but any Phase-2-style retune of costs, rates, or pathing breaks
  this scenario first. That is the plan's documented desync class:
  a scenario that stops reproducing its own clean run is a dead run
  — re-probe, re-tune the script data, never weaken the expect.

---

## L-021 (2026-09-06, run: impl-phase4 — Pair 3, R4 predicate table + T skip)

- Attempt: Red test `tests/test-4a-tutorial.el ::
  cistern-test-4a-tutorial` (red commit `9b7874f`). First red run
  was an authoring bug — registered `cistern-test-4a-tutorial` but
  the defun was named `cistern-test-4a-tut` (`void-function`,
  L-017's class: a red that dies on a naming mismatch is not the
  requirement's red) — renamed before committing. Real red run:
  `wrong-number-of-arguments` on `cistern--tutorial-steps`, 1/19,
  exit 1 — the mechanism had no injection point. Green =
  `cistern--tutorial-steps (&optional table)` (test-injection
  point, minimal pinned shape; view and shipped game call it
  no-arg, table stays empty), `cistern--tutorial-advance (st
  &optional table)` ported to legacy cistern.el:589-599 semantics,
  and the `cistern--cmd-skip-tutorial` use-case.
- Phase-2 deviation fixed in passing (this pair's min impl per plan
  03: "port cistern--tutorial-advance semantics"): the Phase 2
  advance logged OBJECTIVE on every step and NEVER set the index to
  `t` on completion. Legacy semantics restored: one gated step per
  tick, already-satisfied steps resolve instantly on their tick
  (order-free catch-up), completing the final step sets the index
  to `t` and logs "TUTORIAL COMPLETE — THE SECTOR IS YOURS";
  non-final steps log "TUTORIAL: OBJECTIVE COMPLETE".
- Driver migration (armed-verb precedent, L-010 pin 4 — state
  mutation belongs in use-cases): `cistern-skip-tutorial` setf'd
  `(cistern-st-tutorial cistern--st)` directly at src/cistern.el:76;
  now routes through `cistern--cmd-skip-tutorial`. The driver setf
  is pinned against regression by a static assert (driver source
  must not contain "(setf (cistern-st-tutorial").
- Interpretation pin (flagged for the director): "order-free
  catch-up" is read as ONE gated step per tick — plan 03's own
  wording ("advances the tutorial index exactly once") and the
  declared legacy pin both say per-tick single-step; "instant" means
  an already-satisfied step resolves without new player events on
  its tick, not multi-step catch-up in a single tick. If the
  director wants while-loop catch-up, it is a one-line change to
  advance + test — say so before pair 4.
  RULING (director, 2026-09-06): keep one gated step per tick —
  legacy's "the table catches up" means already-satisfied steps
  resolve without new player events on their successive ticks; a
  while-loop catch-up would be a new mechanism beyond the legacy
  port (least-active-decisions). No code change.
- Tooling lesson (second incident this phase): apply_patch
  fuzzy-matched a hunk and replaced the losing scenario's defconst
  header with a bogus `cistern--do-tick` line (and earlier mangled
  the steps signature into a body form). Both caught by re-reading
  the edited range before any run — generalize L-017's paren-scan
  lesson: after ANY inexact-match warning, re-read the whole edited
  region, not just the hunk tail.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 19 TESTS PASSED, exit 0.
- Evidence: red runs above (exit 1); green prints
  `CISTERN-4A-TUTORIAL-OK` (exit 0); full suite `ALL 19 TESTS
  PASSED` (exit 0); parens OK on all three touched files.
- Change for next attempt: pair 4 (scenario determinism) is
  unaffected — scenarios never touch the tutorial index path beyond
  the empty-table no-op. The view's `cistern-view--tutorial-line`
  still consumes the no-arg steps call — shape unchanged, renders
  nothing while the shipped table is empty.

---

## L-022 (2026-09-06, run: impl-phase4 — Pair 4, R4 scenario determinism)

- Attempt: `tests/test-4a-scenarios.el ::
  cistern-test-4a-deterministic` (commit `6fcff17`). R10 DEVIATION,
  recorded honestly: NO RED EVER FIRED. The determinism property
  genuinely holds on the rewritten stack — same-hash was probed in
  pairs 1-2 (L-006 class: green falls out of faithful use of the
  deterministic machinery, seeded procgen + LCG-in-state + pure
  verbs), and the strongest probe passed on arrival. Per the
  standing protocol the probe was strengthened until it
  discriminates instead of manufacturing a bug; the L-006 lesson
  (strengthen the probe, never manufacture) governs, and the
  fail-first red/green shape degenerates to test + ledger.
- The probe (permanent tripwire, all arms anchored to the scenario
  data): (1) replay identity — each scenario run twice at seed 42
  yields byte-identical final state (secure-hash over
  prin1-to-string of the WHOLE state per L-002: map vector, both
  hashes' keys+values, worker fields, counters, rng, log); (2)
  different-seed divergence (42 vs 43) for BOTH scenarios; (3)
  cross-scenario divergence at the same seed (losing ≠ winning);
  (4) chunking invariance — the losing script with the wait split
  30+25 hashes identical (semantically equivalent chunking is
  invisible); (5) order sensitivity — the losing script with the
  demolish verb AFTER the waits hashes different (the comparator
  sees step-execution order). Arms 2-5 quantify what the assert
  catches (L-004); a throwaway probe additionally confirmed the
  fingerprint flips on a single counter mutation.
- Outcome: PASS on arrival, kept as tripwire. Canonical suite
  `emacs -Q --batch -l tests/run.el -f cistern-run-all-tests`:
  ALL 20 TESTS PASSED, exit 0. Green = NO code change required
  (plan 03 pair 4 min impl: "none expected — falls out of seeded
  state + pure verbs"); no leak surfaced, so no game/domain fix.
- Lesson: determinism here is structural, not aspirational — one
  state object, LCG inside it, no wall-clock or unseeded consumer in
  the runner's path. The R10 risk to watch in later phases is NOT
  the scenarios themselves but any new consumer that touches state
  outside the seeded path (a future rewards garnish drawing from
  wall-clock, a view-cached value leaking into state) — the
  tripwire test will catch exactly that class.
- Change for next attempt: Phase 4b's seeded garnish must draw from
  the seed⊕stream-id child stream (REWARDS-DESIGN §4) — this
  tripwire covers the scenarios only; 4b's consumption test (still
  intentionally red, L-009) is the discriminator for rewards
  determinism.

---

## L-023 (2026-09-06, run: impl-phase4 — 4b Pair 1, R5 child stream + fixture)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-stream-fixture` (red commit `832a592`; red run:
  `void-function cistern--stream-init`, 1/21, exit 1). Green =
  `cistern--stream-init` (seed ⊕ stream-id) + `cistern--stream-next`
  (the domain LCG recurrence) in `src/cistern-domain.el` — both
  pure, explicit position in/out, no state, no emacs-runtime calls —
  plus a `seed` slot on `cistern-st`, set by `gen-map`.
- Contract check (director-requested, death-rule review): §4
  promises the "first 100 stream values pinned as a fixture" but
  NEITHER `REWARDS-DESIGN.md` nor `rewards-notes.md` contains the
  values. NOT ruled a contract break: §6 explicitly defers
  "implementation (with seeded fixtures)", and notes:218 states the
  fixture's purpose — drift detection ("so a stream change fails
  loudly", §4 failure mode 2). Doc-grounded resolution: the
  implementation pins the fixture as test literals, generated once
  from the §4-pinned derivation BEFORE the implementation existed
  (so the literals are not the implementation grading itself).
  FLAGGED to the director/designer: if the doc should pin specific
  values by fiat, the fixture mechanism makes any such pinning
  verifiable in one batch run.
- Derivation pins (doc-grounded, minimal): ⊕ = XOR (the doc's own
  operator); recurrence = the domain LCG
  (x·1103515245+12345 mod 2^31 — the only RNG in the codebase; the
  doc names no recurrence, so reusing the existing one is the only
  non-invented choice). Fixture pinned at (seed 42, stream-id 1) —
  42 is the plan-pinned scenario seed; the particle field's
  stream-id naming lands with the M6 field pair. STREAM-ID 0 IS
  RESERVED: it reproduces the sim LCG's own sequence (xor with 0 is
  identity), the one way garnish could silently consume sim
  randomness.
- State decision: `seed` slot added to `cistern-st` — §5's contract
  has `rewards-eval` consuming STATE ONLY, and the child stream
  derives from the game seed, so the seed must live in state.
  The FIELD's persistent stream position is deliberately NOT added
  this pair — it lands with the M6 field pair (plan 03 §4b pair-1
  scope: mechanism + fixture only). The 4a determinism tripwire
  stays green with the new slot (full-state hash carries it
  identically in both runs).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 21 TESTS PASSED, exit 0.
- Evidence: red run above (exit 1); fixture literals generated from
  the inline derivation formula independent of the API under test;
  green prints `CISTERN-4B-STREAM-OK` (exit 0); parens OK on both
  touched files; no duplicate defuns.
- Change for next attempt: M5/M6 spawn tests consume this stream —
  mod-scoping raw positions into range happens AT USE SITES; the
  fixture pins raw 31-bit positions only. The consumption test
  (L-009) stays unregistered until the M9 pair, where its final
  assert can go green.
  RULING (director, 2026-09-06): implementation-pinned fixture
  ACCEPTED — derivation is doc-pinned, purpose is drift detection,
  re-pinning by fiat adds nothing. No change.

---

## L-024 (2026-09-06, run: impl-phase4 — 4b Pair 2, R5 M1 demolish refund + dust)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m1-demolish-refund` (red commit `54f5b9b`; red
  run: `cl-assertion-failed` on the refund assert, alloy 15 vs 16 —
  no refund, 1/22, exit 1). Green = 50%-of-build-cost refund (FLOOR:
  pipe 1, toilet 5, tank 7 — rounding not doc-pinned, floor pinned
  here) in `cistern--cmd-demolish`, fee 3 unchanged, demolish log
  gains "— N REFUND"; dust: `cmd-demolish` pushes a payload event
  `(demolish X Y)` onto the new `rewards-events` state slot;
  `cistern--rewards-eval` converts pending events to 3–5
  `sparkle` intents at the demolished tile (count + glyphs drawn
  from the particle child stream, never the sim LCG) and drains the
  list. Intent shape is L-017's verbatim; ttl/vel stay out of
  intents — they belong to the field's particles at the M6 pair
  (L-018 finding 2).
- State additions (§5-shaped, pinned): `rewards-events` — §5's
  rewards-eval consumes "events emitted this tick", the overlay
  wiring calls it with nil events (L-017), so the verb-emitted
  events need a state transport; verb SIGNATURES unchanged (st x y
  → st+log) per the director's contract guardrail. `particle-rng` —
  §4's ParticleField.rng, the field's persistent child-stream
  position, needed now because dust draws must advance it;
  initialized in gen-map to (seed ⊕ 1).
- Contract findings (routed, not worked around):
  1. "Adjacent contamination puff if pipe was dirty" (M1 §2): the
     state has NO dirt concept on plumbing — the predicate is
     unexpressable over state. Per the death rule this clause is
     ROUTED to the director; the pair ships the three expressable
     clauses (refund, tile empty, refuse-free) + dust. Nearest
     existing mechanism if the ruling wants wiring: the severed-line
     spill (finish-use with no connected tank) already contaminates.
  2. M1's dust row says "gray face" but §4's face enum is closed
     (success/warning/error/info/bonus) — dust emits `info` (the
     neutral enum) pending ruling; adapter maps enum→face.
  3. The doc's illustrative refund arithmetic ("pipe worth 10 …
     leaves 105") uses doc-era prices; the invariant taken is the
     50% refund with the Phase-2 pinned costs.
- Contract-migration (changed contract, tests fixed not re-pinned):
  the R8-era "alloy reduced by exactly the demolish cost" asserts
  in `tests/game-demolish.el` (×2) and the `cistern-run-selftest`
  demolish block moved to the fee-minus-refund arithmetic. The
  losing scenario severs the starter pipe → its alloy trajectory
  shifts +1 deterministically; breach timing is bladder-driven and
  unaffected — the 4a determinism tripwire confirms byte-identical
  replays (ALL 22 includes it).
- Authoring incident (caught pre-commit by check-parens, the
  L-017/L-021 class): the selftest assert migration dropped the
  `let` close (5 opens, 4 closes) — paren scan found it in one
  shot; second green-run round also surfaced the event-shape
  mismatch below before the suite went green.
- Event-shape note (fix during green): §5's event vocabulary is
  BARE SYMBOLS (`relief` `burst` `leak` …) — the Phase-2 default
  test passes symbols and my first draft called `car` on them.
  rewards-eval now treats symbol events as payloadless and lists as
  payload-carrying (`demolish`).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 22 TESTS PASSED, exit 0.
- Evidence: red run above; green prints `CISTERN-4B-M1-OK`; the
  determinism arm (identical replay → identical dust) and the
  drained-on-read arm both green; sim-LCG-untouched and
  stream-position-advanced asserts green.
- Change for next attempt: M5/M6 spawn tests reuse
  `cistern--particle-draw` for stream-advancing draws from state —
  the field's particle LIST lands at the M6 pair; until then dust
  is single-frame intents via the existing overlay path (already
  consumes them unchanged). The consumption test (L-009) remains
  unregistered until the M9 pair.
  RULINGS (director, 2026-09-06): (1) "adjacent contamination puff
  if pipe was dirty" — unexpressable over state, DEFERRED per the
  death rule, recorded in the spec §6 deferred list as an open juice
  clause; severed-line spill noted as the natural mechanism if the
  owner ever wants it. Do not wire it now. (2) Dust face: `info`
  enum stands; gray-rendering, if wanted, lives in the view's
  palette table — the doc's "gray" was a prose hint, not a contract.
  (3) Refund arithmetic: 50% of the CURRENT pinned build costs
  (floor), as taken.

---

## L-025 (2026-09-06, run: impl-phase4 — 4b Pair 3, R5 M2 generation solvability)

- Attempt: `tests/test-4b-rewards.el ::
  cistern-test-4b-m2-solvability`. R10 DEVIATION, recorded honestly:
  NO RED EVER FIRED (second of the phase, cf. L-022). The doc's M2
  solvability property — every generated map has worker starts that
  reach the toilet — HOLDS on the existing generator with zero new
  code: bounded sweep over seeds 1–20 plus the plan-pinned 42, all
  valid (starter plumbing wired+usable via `cistern--toilet-usable-p`,
  every spawn cell passable and walkable-flood-connected to the
  starter toilet). Same-seed identity and ≥3 layout signatures are
  R3's tests (domain-determinism, domain-procgen) — shared per the
  mapping table, not re-litigated.
- ROUTED to the director (contract question, per instruction): the
  plan's mapping row says "M2 adds the bounded-solvability retry
  predicate" and the doc criterion says "validation retries inside
  generation, bounded (Brogue pattern)". Empirically the reservation
  discipline (walls/ore never overwrite reserved cells) already
  guarantees validity across the sweep — a retry loop would be dead
  code today. Recommendation: keep the property test as the
  permanent tripwire; implement the bounded retry only if a
  violating seed ever appears (the test names the seed; a violation
  is a live contract break and re-plans per the run-death protocol).
  Phase 1's R3 decisions are not re-opened by this pair.
- Probe lesson (the pair's real work): the "unreachable spawn"
  anomaly was MY probe bug, twice, chasing a phantom across three
  probes — `(cons (car p) (cdr p))` reconstructs the LIST `(12 6)`,
  not the DOT-CONS `(12 . 6)` the flood hash is keyed by; the
  corrected key (`(cons (nth 0 p) (nth 1 p))`) yields zero failures.
  The sim was never broken. Lesson: when a property as basic as
  worker pathing — demonstrated by every 4a scenario replay —
  appears violated, suspect the probe's key construction BEFORE the
  sim; the 4a byte-identical replays were standing evidence the
  workers reach toilets every run. (Same (X Y)-list vs (X . Y)-cons
  distinction the codebase's two conventions make load-bearing.)
- Authoring note: the test itself initially carried the same
  `(car p)/(cdr p)` bug and died on `wrong-type-argument` — an
  authoring red (L-017 class), fixed before commit.
- Outcome: PASS on arrival, kept as tripwire. Canonical suite
  `emacs -Q --batch -l tests/run.el -f cistern-run-all-tests`:
  ALL 23 TESTS PASSED, exit 0. Green = NO code change required.
- Change for next attempt: M3 goal cards — the consumption test
  (L-009) still fails on its FIRST M8 assert, so M3-M4 pairs
  register only their own tests; the consumption test remains
  unregistered until the M9 pair. Watch: goal-card shape
  `{map_id, goals[], difficulty_tier}` needs map_id — state has no
  map-id field; if the evaluator needs it, that is a §5 state-shape
  addition to pin in the ledger (or seed doubles as map id — route
  before inventing).
  RULINGS (director, 2026-09-06): (1) Bounded-retry predicate
  DEFERRED, do not implement — the doc's contract is "every
  generated map valid"; reservation discipline guarantees it by
  construction, so a retry loop today is unreachable code (deletion
  over addition). The property test is the permanent tripwire: a
  violating seed names itself and the bounded retry gets implemented
  THEN (documented upgrade path — add to spec §6 deferred list).
  (2) map_id: the SEED doubles as map_id (already state, already
  the scenario/procgen identity; themes are a level parameter riding
  the seed). A distinct id field is deferred until something needs
  to address two maps with the same seed.

---

## L-026 (2026-09-06, run: impl-phase4 — 4b Pair 4, R5 M3 goal cards)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m3-goal-cards` (red commit `f1ca294`; red run:
  `void-function cistern--cmd-set-goal-card`, 1/24, exit 1). Green:
  `goal-card` slot on `cistern-st` — §5 shape (:map-id :tier :goals
  :completed), goals carry :kind/:target/:window-ticks plus
  evaluator-written :satisfied (the observable goal state the
  director's criterion (2) needs); `cistern--cmd-set-goal-card`
  (validates max-3 + known kinds, signals error fail-first, stamps
  :map-id = seed per L-025 ruling); `cistern--goal-target` (§5
  pay-forward: Tier1 −25% / Tier3 +25% in the goal's own difficulty
  direction — relieves scale up, ceilings/burst-windows tighten —
  floor rounding, M1 precedent; the tier INPUT is a card-construction
  parameter here, M4's reputation feeds it, pinned); evaluator block
  in `cistern--rewards-eval` — progress accrues from relief/burst
  events, re-checked on EVERY call, all-satisfied ⇒ MapCompleted as
  a banner intent exactly once via the one-way :completed flag
  (commit-first, M9 consumes it).
- SPLIT DECISION (announced pre-commit): this pair = card shape +
  evaluator headless via direct rewards-eval calls; NO do-tick
  wiring. A per-tick rewards-eval call would drain the same
  pending-events slot the render-time call consumes — M1's dust
  would race the view for events. Reconciling event transport
  (per-frame intent persistence vs state-side fields) is the
  contract step for the M4/M5 wiring pair. "Re-checked every tick"
  currently means "every rewards-eval call".
- Deferred within the pair: window_ticks? is accepted in the shape
  but carries no semantics yet (needs M5's warning-window mechanics)
  — §6 deferral stands.
- Load-integrity incident (third of the phase, and the most
  instructive): the M1 refund edit left `cmd-demolish` one close
  short and the selftest assert migration carried a compensating
  extra close — the file was globally paren-balanced (check-parens
  PASSED, a paren-count scan PASSED) while the READER silently
  merged a dozen defuns into `cmd-demolish`'s body, making them
  unbound at load. check-parens validates LIST balance, not
  per-form integrity; a globally-balanced file can still be a
  structurally different program. The reliable detector is the
  reader itself: read all top-level forms and flag any form spanning
  multiple defuns. Fixed by matching the reader (+1 close at
  cmd-demolish's defun tail, −1 compensating close in the selftest
  assert), verified by a clean 30-form read.
- Tooling note: this Emacs rejects the 3-argument `plist-get`
  (calls the default argument as a function: `invalid-function 0`) —
  the L-006 conservative-API rule now has a concrete instance:
  `(or (plist-get p k) default)`, never `(plist-get p k default)`.
  A test-design error also surfaced in the same run: test (6) let
  the card complete BEFORE the ceiling violation; corrected so the
  violation precedes full satisfaction (the implementation's
  check-time completion was correct per the doc's "on a tick"
  wording — the test was fixed, never the code).
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 24 TESTS PASSED, exit 0.
- Change for next attempt: the M4/M5 pair wires rewards-eval into
  do-tick — decide the event transport FIRST (the render-drain race
  above is the constraint): either the view stops draining (intents
  persist per frame in state) or the tick path hands events straight
  through. M4 needs reputation (+1/−5/−2 clamped) — a reputation
  field rides the same state-shape addition. Suggest adding a
  reader-based form-integrity check to the canonical runner
  (director's call — runner is shared infrastructure).
