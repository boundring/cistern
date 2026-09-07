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

---

## L-027 (2026-09-06, run: impl-phase4 — 4b Pair 5, R5 M4 reputation + per-tick wiring)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m4-reputation` (red commit `62a5b9b`; red run:
  `void-function cistern-st-reputation`, 1/26, exit 1). Green:
  `reputation` + `rewards-outcome` slots on `cistern-st`;
  `cistern--reputation-tier` (§5: 0–39 T1 / 40–69 T2 / 70–100 T3 —
  the pay-forward function M3's card constructor consumes); M4
  deltas verbatim (+1 relief / −5 burst / −2 leak, clamped 0–100)
  consumed in `cistern--rewards-eval`; per-tick wiring.
- EVENT-TRANSPORT RECONCILIATION (the L-026 contract step, per the
  director's ruling): `cistern--rewards-eval` runs ONCE PER TICK
  inside `cistern--do-tick` — after the sim phases, BEFORE the
  tutorial advance (pinned). It STORES the outcome+intents into
  `cistern-st-rewards-outcome` (a cons `(outcome . intents)`);
  `cistern-view--celebration-overlay` READS the stored slot and
  NEVER calls rewards-eval. THE L-017 PIN "rewards-eval once per
  render" IS SUPERSEDED (recorded here per the ruling); the view
  still reads and never advances (spec §3.3). test-r5-hook's
  rewards-eval mocks migrated to stored-slot setfs; its
  celebration-overlay short-circuit mocks remain valid.
- M4 event-site mapping (sim phase → §5 event, all pushed onto the
  `rewards-events` state slot by the domain, drained once per tick
  by the rewards evaluation): relief = `cistern--finish-use`
  deposit path (waste deposited into a connected tank); leak =
  `cistern--finish-use` severed path (no connected tank → hazard +
  "SEVERED LINE"); burst = `cistern--accident`. Payloadless symbol
  events per the §5 vocabulary; payload lists (demolish) ride the
  same slot.
- Determinism: the 4a byte-identical tripwires stay green with the
  wired path active — reputation and the stored outcome are
  symmetric across replays and ride the full-state hash.
- Source-integrity entry (director decision 1, shared infra):
  `tests/test-source-integrity.el ::
  cistern-test-source-integrity` — reader-loads every src/*.el,
  walks top-level forms, asserts span ≤ 10000 chars (legitimate max
  8822 = the selftest defun; the L-026 incident form was 25k) and
  heads ∈ {defun defconst defvar defcustom defface defgroup
  define-derived-mode require provide cl-defstruct}. Joins the
  standing checklist: run it (or the canonical suite containing it)
  before every commit; check-parens is NOT sufficient.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 26 TESTS PASSED, exit 0.
- Incidents this pair (both caught by the integrity flow + direct
  probing, before any false green): (1) the finish-use edit left the
  deposit `puthash` writing into the rewards-events slot (nil) —
  symptom was `hash-table-p nil` at the first finish tick, located
  by direct `finish-use` invocation, fixed by restoring the tanks
  hash argument; (2) a rewards-outcome shape mismatch — the slot
  stores a CONS `(outcome . intents)` and every consumer (overlay,
  tests) reads `(cdr ...)`; an intermediate `(list outcome intents)`
  store wrapped the intents in an extra layer and the r5-hook
  migration briefly painted nothing.
- Change for next attempt: M5/M6 — dust/popup intents now FLOW
  per tick through the stored slot; the M6 particle field (domain
  state, TTL/vel/FIFO) replaces the transient intent spawns per the
  §4 trigger table. M5's relieve-pay needs the relief event site
  (already pinned here) plus the M4 reputation counters it updates.

---

## L-028 (2026-09-06, run: impl-phase4 — 4b Pair 6, R5 M5 relieve-pay + popups)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m5-relieve-pay` (red commit `0e5f075`; red run:
  `void-variable cistern-score-relief-base`, 1/27, exit 1). Green =
  M5 economy + single-frame popup intents: `finish-use` now emits a
  PAYLOAD relief event `(relief bladder% x y)` — the urgency (pre-
  zero bladder) and relief tile the pay rule needs; pay rules: base
  within the warning window (bladder ≥ 60), 2× at near-burst
  (bladder ≥ 100 — implementation-pinned: 10 ticks before burst),
  0 below the window; VR-8 tips: 1-in-8 relieves tip 2–3× base,
  drawn from the particle child stream (never the sim LCG); score
  accrues in the existing rewards-owned `score` slot; the stored
  outcome's :score carries the live total; popup intents `+N` at
  the relief tile, layer popup, face success (tips bonus).
- EVENT-PAYLOAD DECISION (ruling-sanctioned): §5's relief symbol
  cannot carry the urgency the pay rule needs; the event is now the
  payload list `(relief bladder% x y)` — within the established
  payload-list vocabulary (demolish precedent), NOT a reshape.
  `cistern--event-kind` normalizes symbol/list events for all
  consumers; M3 goal progress and M4 reputation counters now count
  payload reliefs too (the sim emits payload events only).
- Doc gaps (§6 fixture precedent, per the L-023 ruling pattern): the
  M5 row gives NO base number — base = 10, implementation-pinned
  (doc-era scale: the §2 M1 example's 100-coin economy); near-burst
  threshold 100 likewise. Both are fixture-pinned constants a
  designer tuning pass can move. "Below the window pays 0" is the
  pinned reading of "relief WITHIN warning window pays base".
- VR-8 determinism note: the child stream's low-3-bit cycle under
  the LCG recurrence (x → 5x+1 mod 8, 5 invertible mod 8) hits all
  8 residues exactly once per cycle — the 1/8 tip rate is exact by
  construction over a sweep, and the fixture window (8–14 tips per
  80 relieves) plus same-seed tip-count equality are asserted.
- Known artifact (ledgered, M6 owns the fix): the '+N' popup glyph
  is multi-char in a single map cell — the transient render row
  widens by the extra chars. The M6 particle field owns proper
  multi-cell popup placement, ttl=3, and vel (0,−1) drift; today's
  popups are single-frame intents at the spawn cell (M1-dust
  pattern, L-018 finding 2 boundary respected).
- Contract migrations: `cistern--rewards-eval`'s stored outcome
  :score is now LIVE (the accumulated score) — the Phase-2
  default-outcome tests stay green because a fresh state with no
  events still yields :score 0 verbatim. The 4a scenario tripwires
  stay green: relieves accrue score during the winning replay
  symmetrically (full-state hash), no scenario expect pins score.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 27 TESTS PASSED, exit 0.
- Change for next attempt: M6 criterion 1 (fixture equality at
  N = 0, 1, 3, 6) needs the particle field in domain state — the
  field's rng position (`particle-rng`) already exists; the popup
  entity's ttl=3/vel (0,−1) migrate from intents into field
  particles at that pair.
  RULING (director, 2026-09-06): "below the window pays 0" STANDS
  (correct minimal reading; a tuning constant if playtesting
  disagrees). No change.

---

## L-029 (2026-09-06, run: impl-phase4 — 4b Pair 7, R5 M6 particle field)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m6-particle-field` (red commit `7153588`; red run:
  `void-function cistern-st-particles`, 1/28, exit 1). Green covers
  §4 criteria 1–6 (criterion 7 ceremony-commit-first is M9's):
  (1) golden-fixture equality at N = 0, 1, 3, 6 over the full
  particle list — fixture generated from the §4 trigger row + the
  pinned draw order BEFORE implementation (L-023 provenance);
  (2) same-seed identity + ≥3 distinct fields across seeds 1–5;
  (3) TTL expiry — ttl-6 removed exactly at the 6th advance, empty
  after max-TTL + 1; (4) K=64 FIFO eviction — 70 spawns keep the
  newest 64; (5) advance-when-paused — N advances move pos/ttl while
  tick/alloy/reputation/sim-LCG stay frozen; (6) renderer purity —
  deterministic render, zero state mutation. Plus §4 failure mode 5:
  invalid field state (ttl < 0, |vel| > 1) raises in the advance.
- SCOPE decision (announced pre-commit): ONE pair — field + advance
  semantics + spawn migration + overlay migration together; no
  overlay-migration follow-up pair needed (the overlay change was
  ~15 lines once the field existed).
- Layer pin: the field (`particles` slot) and
  `cistern--advance-particles` live in DOMAIN (field mechanics
  beside the struct; sim counters untouched — criterion 5);
  spawning happens in the game layer's rewards-eval via
  `cistern--field-spawn` (K=64 FIFO, oldest evicted).
- ADVANCE CALL SITE (§4 key decision, pinned): `cistern--refresh`
  calls `cistern--advance-particles` before reading the field —
  one advance per redisplay. Auto-run frame = do-tick (advance-sim)
  + refresh (advance-particles); paused redisplay = refresh only —
  celebrations finish while the sim is frozen. do-tick itself does
  NOT advance (no double advance per frame).
- SPAWN-SITE MIGRATION list (particle-layer intent emission died
  here): M1 dust — 3–5 `sparkle` at the demolished tile, ttl 2–3,
  short vel, glyphs `·`/`.` (draw order per particle: glyph, ttl,
  vel-x, vel-y — pinned, fixture-bearing); M5 popup — one `popup`
  ttl 3, vel (0,−1) per paying relief (no draws — fixed by the §4
  row). The stored intents slot now carries ONLY non-particle
  intents (banner text, M3 MapCompleted); the overlay projects the
  FIELD for map glyphs and the stored slot for banners only.
- Known artifact carried from L-028: the '+N' popup glyph is
  multi-char in one map cell; the field now makes per-cell digit
  placement possible at a later polish pair if wanted.
- Incidents: several heredoc-authored test defects (malformed
  dotted conses `(cons 0 . -1)`, close-count slips in the M6 test,
  a mapcar nesting error) — all caught by check-parens + a reader
  form probe + the suite BEFORE any commit. Lesson: prefer
  file-based probes over inline --eval for any nontrivial elisp
  (three inline probe self-destructions this pair); the
  source-integrity entry now covers src/ per-form integrity and
  would flag the load-merge class instantly.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 28 TESTS PASSED, exit 0.
- Change for next attempt: M8 milestone ladder — thresholds over
  cumulative relieves (payload relief events already count via
  `cistern--event-kind`); unlock-once semantics want a persisted
  unlocked set (§5 "unlocks persist across maps" — a state-shape
  question to pin). M7 severity mapping can land independently.
  M9 last, registering the consumption test.

---

## L-030 (2026-09-06, run: impl-phase4 — 4b Pair 8, R5 M7 severity grammar)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m7-severity` (red commit `e87e307`; red run:
  `void-function cistern--event-severity`, 1/29, exit 1). Green =
  `cistern--event-severity` (game layer, pure, deterministic:
  relief → minor; burst, leak → major; map-complete →
  game-changing) + `cistern--severity-face` (minor → info, major →
  error; game-changing presents as the banner row, not a face) +
  faced log intents + the view's log-tail applying severity faces.
- Presentation routing (all EXISTING surfaces, none invented):
  minor/major lines ride the stored slot as `(:layer 'log :text
  LINE :face ENUM)` intents; `cistern-view--log-tail` faces the
  matching log line via the palette map (error → cistern-toilet-
  down, info → cistern-dim), unmatched lines stay dim. The
  game-changing banner keeps M3's structural treatment (reserved
  row); copy still DEFERRED (§6). "Cleared after N ticks" — the
  stored intents are replaced on the next evaluation, so the banner
  clears on the following tick (N=1, the timing constant deferred).
- Event-payload extension (demolish/relief precedent): burst and
  leak events now carry their LOGGED LINE as payload — `(burst
  "BREACH — CREATOR #N …")`, `(leak "SEVERED LINE AT …")` — so the
  faced log intent's text is exactly the domain's announcement
  (accident formats once, uses it for both log and payload; same for
  the severed branch). Relief's minor line: finish-use now logs
  "CREATOR RELIEVED AT (x,y)" and rewards-eval formats the identical
  text for the intent — the sync is asserted by the test (intent
  text must appear in the log).
- Tile-face reading (no route needed): "error face on tile" is the
  EXISTING hazard projection — the breached tile becomes a hazard
  and `cistern-view--cell-glyph` projects the `cistern-hazard` face
  (red bold). No tile-table change, no freshness state invented.
  The breaching worker occludes the tile at D5 precedence (worker >
  cell), so the assert uses the cell-glyph projection, not the
  rendered row.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 29 TESTS PASSED, exit 0.
- Change for next attempt: M8 milestone ladder — thresholds 5/15/30/
  50/100 over CUMULATIVE relieves; unlock-once needs an
  UnlockEmitted intent exactly once and a PERSISTED unlocked set.
  State-shape pin proposal (route for approval before the pair):
  `unlocks` — already a rewards-owned st slot (spec §3) — becomes
  the unlocked-id list, plus a `relieves` counter field (or reuse
  the goal-card progress mechanism with a card-less ladder). M9
  last: ceremony state, commit-first trophy, and registering the
  consumption test.

---

## L-031 (2026-09-06, run: impl-phase4 — 4b Pair 9, R5 M8 milestone ladder)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m8-milestones` (red commit `1c59b71`; red run:
  `void-function cistern-st-relieves`, 1/30, exit 1). Green =
  `relieves` cumulative counter slot (approved state-shape pin,
  L-031) + `cistern--milestone-ladder` (§2/§5 ordered
  {threshold . unlock} table: 5 big-cistern, 15 fast-flush,
  30 self-clean, 50 air-freshener, 100 golden-pipe) + the ladder
  consumed in `cistern--rewards-eval`: payload AND symbol relief
  events count (`cistern--event-kind` normalization); each crossing
  pushes the unlock id onto `cistern-st-unlocks` (membership guard =
  exactly-once) and emits `(unlock :id ID)` as an intent in
  threshold order; the outcome's :unlocks carries the cumulative
  set; the golden-pipe crossing sets the outcome's :celebrate flag
  (full-buffer celebrate; the K=64 field-fill choreography is M9's).
- State-shape ruling recorded (director): `unlocks` = the
  unlocked-id list; `relieves` = cumulative counter. DEFERRED per
  the same ruling (recorded in REWARDS-DESIGN §6 item 10): "unlocks
  persist across maps (ledger 2)" is untestable without multi-map
  mechanics — the unlock record persists in state; M9's ceremony
  commits next-map unlocks at trigger time; cross-map traversal is
  next-map-mechanics territory (post-4b). Same pattern as the M1
  dirt clause.
- Doc hygiene: REWARDS-DESIGN §6 now records the three
  ruling-deferred clauses (M2 bounded retry, M1 dirt puff, M8/M9
  cross-map persistence) — items 8-10.
- Incidents (authoring, caught pre-commit): the M8 test's own
  probes/rewrites produced three load-level paren defects (a
  mapcar nesting error, a close-count slip, and a missing defun
  close) — all caught by check-parens + a per-line depth trace +
  the reader probe. Runtime contract note: the stored outcome is a
  CONS `(outcome . intents)` — `(nth 1 …)` is the FIRST intent,
  `(cdr …)` is the intents list; the test's intent extraction used
  the wrong accessor twice before the suite went green. And
  `(plist-get i :id)` on the `(unlock :id ID)` intent must read the
  CDR's plist (the car is the event head) — fixed in the test.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 30 TESTS PASSED, exit 0.
- Change for next attempt: M9 closes 4b — ceremony state
  (commit-first trophy at MapCompleted, zero ticks), the
  full-buffer field fill (§4 M9 trigger row: up to 64 `sparkle`,
  ttl 6, glyphs * ! · § digits + centered banner), auto-run pause,
  any-key skip with no forfeit — AND registering
  `cistern-test-rewards-consumption` in tests/run.el (its M8/M5
  asserts are expected green already; the final celebration assert
  goes green with M9). The consumption test's M5 block still uses a
  bare 'relief symbol for the pay assert — migrate it to the
  payload vocabulary ((relief 70 3 3)) when registering, L-028.

---

## L-032 (2026-09-06, run: impl-phase4 — 4b Pair 10, R5 M9 ceremony; 4b CLOSED)

- Attempt: Red test `tests/test-4b-rewards.el ::
  cistern-test-4b-m9-ceremony` (red commit `85c9da2`; red run:
  `void-function cistern-st-trophies`, 1/32, exit 1) PLUS the
  L-009 consumption test REGISTERED in this pair's red commit per
  its contract — and it ran GREEN on first registration (its M8/M5
  asserts were satisfied by the landed M8/M5 work; the "final
  celebration assert" — :celebrate on the ladder-top crossing —
  went green with M8's celebrate flag). L-009's intentional-red
  cycle is CLOSED: the consumption test discriminated placeholder
  from consumption exactly as designed.
- Green: `trophies` slot (the completed map's seed list — §5
  "visited seeds"; persist-across-maps DEFERRED per the L-031
  ruling, REWARDS-DESIGN §6 item 10); commit-first — the goal
  evaluator pushes the trophy AT TRIGGER TIME (zero ticks) when it
  sets :completed; the ceremony fill spawns the buffer up to K=64
  ttl-6 static sparkles across the map, glyphs from the M9 row
  (* ! · § + digits), in the SAME evaluation; exactly-once via the
  :completed guard (no re-commit, no re-fill); no modal state —
  input works throughout, skipping forfeits nothing (asserted by
  behavior: cursor + tick + trophy survive); determinism asserted.
  The ttl-6 decay IS the ceremony duration — no separate timer.
- Ceremony duration/no-modal reading pinned: the ceremony never
  blocks input (state is committed before presentation; any player
  action just refreshes, advancing the field normally). Banner
  copy/centering remains DEFERRED (§6 open).
- Authoring incident: an inexact patch edit garbled the (b)
  full-buffer block mid-rewrite — caught by reading the edited
  region, fixed by line-precise rewrite; zero false greens.
- Outcome: GREEN. Canonical suite `emacs -Q --batch -l tests/run.el
  -f cistern-run-all-tests`: ALL 32 TESTS PASSED, exit 0. 4b is
  functionally complete; the phase proceeds to the verifier gate.
- Change for next attempt (closing-review input): the
  multi-char '+N' popup glyph still renders in one cell (carried
  from L-028; per-cell digit placement is now possible over the
  field); banner centering/copy remains §6-open; cross-map
  traversal (unlocks/trophies persistence) is next-map-mechanics
  territory (§6 item 10).

---

## L-033 (2026-09-06, run: review-phase4 — Phase 4 closing review)

- Attempt: phase-closing conformance/simplification review
  (HANDBRIEF-TEMPLATE six-item checklist). Small fixes committed
  directly: lexical-binding cookie moved onto line 1 of
  tests/test-source-integrity.el (a cookie on line 2 is ignored —
  the gate's finding); stale Phase-2-era docstrings/comments
  refreshed (cistern--rewards-default-outcome placeholder wording,
  cistern--rewards-eval docstring, the M3/M5 pair-era comments
  inside it, cistern--reputation-tier's false "card constructor
  consumes" claim — the pay-forward consumer is deferred with
  cross-map mechanics, REWARDS-DESIGN §6 item 10); the five
  duplicated event-kind counting sites consolidated into
  `cistern--count-events`; tests/test-4b-rewards.el's
  provide/ends-here footer moved to end of file (pairs 2-10 were
  appended after it); REWARDS-DESIGN §2 M7/M9 rows, §5 ceremony
  semantics and §5 event vocabulary updated to the pinned readings
  (N=1 banner clear, L-030; no-modal ceremony, L-032; actual event
  vocabulary relief/burst/leak/demolish). Ledger audit
  L-019..L-032: every "Change for next attempt" applied in-phase
  or carried (L-032's closing-review input is carried below);
  REWARDS-DESIGN §6 items 8-10 confirmed present for the routed
  rulings. Rewards-eval shape judged coherent as ONE straight-line
  evaluator — the M1-M9 blocks mirror the declarative doc's own
  order; no decomposition, no new helpers beyond the count
  consolidation. L-018 finding 2 verified APPLIED: the overlay
  mapping reads only :pos/:glyph/:face; vel/ttl live in the domain
  field alone. L-020 margin note verified intact: rewards garnish
  draws only the child stream, no scenario expect pins score or
  reputation, so the 118/120 razor margin stays sim-pure and the
  determinism tripwire remains the guard.
- Structural findings (NOT fixed in passing; each lists its owning
  phase):
  1. CARRIED from L-012 #2 / L-018 #1 (verified, still unsorted):
     `cistern-run-soak`'s purge-target maphash over
     `cistern-st-tanks` iterates unsorted. Phase 4 did not edit the
     soak (do-tick now also runs rewards-eval, but child-stream
     isolation keeps the sim trajectory unchanged). Owning phase:
     post-playtest tuning's first soak-touching change — sort the
     keys or record the exception L-011-cmd-build style.
  2. CARRIED from L-028 / L-032: the multi-char '+N' popup glyph
     renders in one cell. Owning phase: post-playtest presentation
     pass (per-cell digit placement over the field is now
     possible).
  3. The milestone unlock intent `(unlock :id ID)` carries no
     :layer and the view renders no unlock surface — M8's "status
     line + shop list" presentation is absent (the shop sink itself
     is REWARDS-DESIGN §3 S2, unimplemented). State carries the
     unlocks; only the surface is missing. Owning phase:
     post-playtest tuning, when S2 lands.

---

## L-034 (2026-09-06, run: smoke-prototype — live driver smoke test)

- Attempt: scripted interactive session through the REAL surface the
  32 headless entries never touch — `cistern' entry, buffer, mode,
  interactive commands, synthesized mouse events (playtest/smoke.el,
  batch Emacs; 10 exercises, SCREEN dumps in playtest/).
- Findings fixed (red test commit 54208e3, greens c1eddcc, f0124f4):
  1. The documented run line `emacs -Q -l src/cistern.el` died with
     file-missing: `load` never adds the loaded file's directory to
     load-path, so the sibling `require`s could not resolve.  Fixed
     by passing the explicit filename to each sibling require —
     a bare top-level `when` bootstrap was tried first and REJECTED
     by the L-026 source-integrity gate (non-defining top-level
     head), which is exactly what that gate is for.
  2. `cistern-help' (the `?' command) CRASHED with "Invalid
     function: 20": two `princ` calls passed the substitution value
     as princ's optional print-character function.  Any interactive
     press of `?' errored.  Also fixed in the same command: the
     controls block hardcoded stale prices (toilet 12 vs constant 10,
     decon 4 vs 3, demolish 3 now rendered from the constant).
- Verified NOT defects (pinned readings, confirmed against legacy
  source and spec): keyboard t/p/K builds advance no tick (R6 pins
  SPC/RET/click-with-verb only; legacy build commands never ticked);
  isolated pipe renders `·` (legacy cistern--pipe-glyph returns `·`
  with no plumbing neighbors); starter tank spawns with load 30
  (domain fixture); goal card completes at 2 relieves for a target
  of 3 (cistern--goal-target tier-1 scaling −25%); the header's
  "SEED %d" prints (cistern-st-rng st), the live LCG state, not
  (cistern-st-seed st) — VERBATIM legacy port (legacy :732), so
  cosmetically misleading but the pinned reading.
- Outcome: canonical suite `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests`: ALL 34 TESTS PASSED, exit 0 (32 + 2 new
  smoke regressions).  Full session log: playtest/SMOKE-REPORT.md.
- Change for next attempt: carry the L-032/L-033 presentation items
  unchanged; add one smoke input — the header should print the real
  seed (`cistern-st-seed st`) during the post-playtest presentation
  pass, since a player cannot reproduce a run from the LCG state
  currently displayed.

## L-035 (2026-09-07, run: impl-ux-r1 — Q01+Q02 header strip contract, score/rep rendered)

- Attempt: Red tests `tests/test-ux-r1.el :: cistern-test-ux-q01-header-strip`
  + `cistern-test-ux-q02-score-rep` (red commit `c812f3f`; red run:
  "strip segment SCORE  missing" / "cold strip shows SCORE 0",
  2/36, exit 1). Green `96cb46d`.
- Strip contract landed: fixed segment order `TICK ALLOY POP CONTAM
  SCORE GOALS REP`, values read from state (`cistern-st-score`,
  `cistern-st-reputation`, and Q04's `cistern-view--goal-counts` for
  `GOALS n/m` off the active card — `-/-` only while card-less).  One
  dim badge segment reserved after REP (`cistern-view--header-badges`,
  empty until Q19/Q29); render concatenates header + badges + "\n".
- Width decision (least-active, ledgered): the old title
  "CISTERN — SECTOR-7 — v3.0.0-dev" + SEED + the three new segments
  measures 99–104 cols — over the 95 budget at cold start.  Minimal
  reading that keeps every pinned segment: title compacted to
  "CISTERN — SECTOR-7"; version AND seed moved into the `?' briefing
  first line ("CISTERN v%s — sanitation protocol for Sector 7 — map
  seed %d").  This also resolves L-034's carried change: the briefing
  now prints the REAL seed (`cistern-st-seed`), not the LCG state the
  old header "SEED" segment displayed.
- Fixture lesson (test-side): the driven-relief helper must use
  `let*' — `let' evaluates the spot loop's initializer before `w' is
  bound (void-variable w); and Elisp "" is truthy, so the reserved
  slot asserts `equal ... ""`, not `null`.
- Outcome: GREEN. Canonical suite: ALL 36 TESTS PASSED, exit 0.
- Change for next attempt: Q03 starter card (already planned next in
  build order); watch replay-identity tests — the card now rides
  every new game's state.

## L-036 (2026-09-07, run: impl-ux-r1 — Q03 starter goal card + card-aliasing bug)

- Attempt: Red test `cistern-test-ux-q03-starter-card` (red commit
  `4d8972e`; red run: "starter goal card dealt at tick one", 1/37,
  exit 1). Green `b53f2f4`.
- Layer decision (least-active, ledgered): the directive pins the
  call to cistern-game.el, but `cistern--new-game' lives in the
  domain (innermost layer) — a game-layer issuance would either run
  after construction (not "one call") or invert the domain→game
  require edge.  Minimal reading: `cistern--cmd-set-goal-card` +
  `cistern--goal-kinds` relocated to cistern-domain.el UNCHANGED
  (same symbols, zero caller migration), and new-game issues
  `cistern--starter-card` (tier 2, serve 3, ceiling 5) with one call.
- REAL BUG CAUGHT BY THE SUITE (the lesson of this run): green broke
  `cistern-test-4a-deterministic` — replay identity 2a8a5617 vs
  c635170c.  Root cause: `cistern--cmd-set-goal-card` shallow-copied
  the card, so every state aliased the SHARED literal goal plists;
  the M3 evaluator's `plist-put ... :satisfied` then mutated those
  literals, leaking goal state across games and making
  `prin1-to-string` hashes mutation-history-dependent.  Fix
  (root-cause, not symptom): the setter deep-copies goals
  (`mapcar #'copy-sequence`), so each state owns its card.  The
  existing 4a-deterministic entry is the standing regression test.
- Outcome: GREEN. Canonical suite: ALL 37 TESTS PASSED, exit 0.
- Change for next attempt: Q04's driven same-tick assertion (its red
  was subsumed — the GOALS mechanics landed with the Q01 strip);
  then Q05 milestone announcements.

## L-037 (2026-09-07, run: impl-ux-r1 — Q05 milestone announcements + Q04 driven progress)

- Attempt: Red test `cistern-test-ux-q05-milestone-announce` (red
  commit `ff054e6`; red run: "milestone line in the log tail", 1/39,
  exit 1 — the ANTAG-12 silence reproduced headlessly). Green
  `00df336`.
- Unlock branch now announces at the tick of the act, commit-first
  (the unlock itself still commits to `cistern-st-unlocks` before
  any presentation): the formatted line enters the log via
  `cistern--log`, rides the log-tail as a faced `:layer 'log`
  intent (success face — milestone is good news in the M7 grammar),
  and rides the banner row as `:layer 'banner` — log line and banner
  present in the SAME frame.  The raw `(unlock :id ...)` intent is
  kept unchanged so 4b-m8's intent-shape asserts stay truthful.
- Copy routing (Q11 PROTECT): milestone display names live in
  `cistern--copy-milestones` in the domain — the one string table the
  docs pass reviews; format `MILESTONE — BIG CISTERN ONLINE`.
- Q04 note: `cistern-test-ux-q04-goal-progress` (driven first
  objective → `GOALS 1/1` in the same tick's strip) landed in the
  red commit already green — its plausible-bug surface (strip not
  reading the card) was first exposed by the Q01 red; retained as
  the same-tick freshness guard.
- Outcome: GREEN. Canonical suite: ALL 39 TESTS PASSED, exit 0.
- Change for next attempt: Q06/Q07 executable PROTECT guards, then
  batch 2 (Q08 pressure gradient before the Q09 domain split).

## L-038 (2026-09-07, run: impl-ux-r1 — Q06+Q07 executable PROTECT guards)

- Attempt: guard tests `cistern-test-ux-q06-popup-protect` +
  `cistern-test-ux-q07-purge-economy` (commit `f36acc0`).  No red:
  both constraints are already true of the mechanism (M5 popups,
  purge ledger) — these entries pin them so Q25 (particle placement)
  and Q30 (free regret window) cannot regress them silently.
- Q06 pins: a `+N` popup exists AT the relief cell in the overlay of
  the tick that produced the relief (SCREEN-13), and a cursor parked
  on that cell still occludes it (D5 z-order cursor > worker >
  popup > cell unchanged).
- Q07 pins: purge at a known 45-load tank changes alloy by exactly
  15 (1 per 3, no rounding drift), and the inspector line keeps
  "pays 1 alloy per 3" verbatim — the rate any future economy change
  (incl. Q30) must keep true.
- Outcome: GREEN. Canonical suite: ALL 41 TESTS PASSED, exit 0
  (34 baseline + 7 UX entries).
- Change for next attempt: batch 2 — Q08 gradient first (director-
  pinned Q08 → Q09 → Q10), all new copy through
  `cistern--copy-*` domain tables per Q11.

---
## L-039 (2026-09-07, run: impl-ux-r1-b2 — Q08 pressure gradient + Q11 copy table)

- Attempt: Red tests `cistern-test-ux-q08-pressure-gradient` +
  `cistern-test-ux-q11-copy-table` (red commit `dd427f1`; red run:
  "RISING at 0.9 cap with the fill %" + "one domain copy table
  exists", 2/43, exit 1). Green `4192f0e`.
- Gradient: middle tier fires at ≥ 0.85 × Σ tank-cap and names the
  most-loaded tank's fill % (`PRESSURE RISING — TANK 90%`); the raw
  ">100 units" branch is DELETED (101 units across two half tanks is
  not pressure — asserted: 51+50 stays NOMINAL).  No-hash backstop
  honored: the view reads `cistern--tank-capacity-total` /
  `cistern--tank-load-max` (r5-hook's projection backstop caught the
  first draft reading the tanks hash directly — the gate works).
- SEMANTIC RULING (least-active, ledgered): Q08's acceptance (0.9 ×
  cap → RISING, not CRITICAL) is unreachable with the legacy
  can't-seat predicate — a 54/60 tank already turns the toilet
  'down.  Backed-up therefore means "path exists AND tanks FULL to
  cap" (Q09's first half landed inside this green); the near-full
  51–59 band belongs to RISING — the line anticipates instead of
  lying.  DIRECTOR NOTE: the chain Q08 → Q09 was realized as one
  green pair (Q08's red came first; Q09's red for the severed half
  followed).
- Pacing quirk (pinned reading, for the docs pass): use-load 10 vs
  cap 60 makes the [85%,100%) band SKIPPABLE in a one-tank game —
  natural fills step 50 → 60; RISING is only observed from
  near-full states (the LEG-02 capture injects 55/60).  Threshold
  stays at the pinned 0.85.
- Form-span gate incident: rewards-eval grew past the 10k L-026
  limit with the Q05 block; `cistern--announce-unlock` was extracted
  (decomposition, not gate-dodging).
- Q11: single `cistern--copy` table in the domain now holds ALL new
  copy (milestones consolidated away from `cistern--copy-milestones`,
  pressure strings added); the idle pressure line stays byte-
  identical in the view.  The drift test checks each table string
  appears in cistern-domain.el and in NO other src file (substring
  overlaps inside the table's own file are fine — long strings
  contain the short ones).
- Outcome: GREEN. Canonical suite: ALL 43 TESTS PASSED, exit 0.
- Change for next attempt: Q09 severed half + Q10 re-branch.

## L-040 (2026-09-07, run: impl-ux-r1-b2 — Q09 severed/backed-up domain split)

- Attempt: Red test `cistern-test-ux-q09-domain-split` (red commit
  `f947497`; red run: "severed half of the split exists", 1/44,
  exit 1). Green `9f020ff`.
- Split complete: `cistern--toilets-severed-p` (down, NO tank
  reachable through plumbing) vs `cistern--toilets-backed-up-p`
  (down, path, tanks full).  The collapsed
  `cistern--toilets-backed-p` is RETIRED (clean cutover — its only
  consumer was the pressure line, already migrated).  Both flags
  exposed to the view as domain queries (D6).  M2 solvability and
  the 4a scenarios stay green: the split changes a predicate the
  view reads, not the sim.
- Outcome: GREEN. Canonical suite: ALL 44 TESTS PASSED, exit 0.
- Change for next attempt: Q10 re-branch + offender coords.

## L-041 (2026-09-07, run: impl-ux-r1-b2 — Q10 pressure re-branch + offender coords)

- Attempt: Red test `cistern-test-ux-q10-severed-rewire` (red
  commit `68461a9`; red run: "severed branch advises rewiring",
  1/45 — the ANTAG-05 lie reproduced: a severed toilet read
  CRITICAL/purge).  Green `e3815f1`.
- SEVERED branch: `LINES SEVERED — REWIRE (p) — TANK AT (5,2)` —
  names the tank cell to wire toward via `cistern--severed-remedy`
  (first severed toilet in coordinate order → `cistern--nearest-tank`
  over the flood-fill distance map); never purge advice.  BACKED-UP
  branch byte-identical (purge advice kept).  Pressure line and
  inspector now agree at the losing moment (both say lay pipe).
- Test-side lesson: the inspector half of the assert needs the
  cursor PARKED ON the severed toilet (ANTAG-05's actual setup) —
  the first draft forgot the cursor move.
- Outcome: GREEN. Canonical suite: ALL 45 TESTS PASSED, exit 0.
- Change for next attempt: Q12 dead pipe glyph + legend from table.

## L-042 (2026-09-07, run: impl-ux-r1-b2 — Q12 dead pipe glyph + legend from the table)

- Attempt: Red test `cistern-test-ux-q12-dead-pipe-glyph` (red
  commit `ca13298`; red run: "dead pipe carries the table's dead
  glyph", 1/46 — the unconnected pipe rendered "·", byte-identical
  to floor: ANTAG-06 confirmed).  Green `e4b693f`.
- Pipe tile row gains `:dead-glyph "╌"`; accessor
  `cistern--tile-dead-glyph` (base-glyph fallback for kinds without
  one).  The view's dead branch reads the table.  The legend is now
  GENERATED from the tile table: a kind with :dead-glyph lists the
  dead glyph ("╌ dead pipe") instead of its base glyph — the base
  never renders, and the floor's "·" can never be listed twice.
- Contract change landed on r7: "isolated pipe renders the
  tile-table glyph" now asserts the table's DEAD glyph (same
  table-driven guarantee, new glyph).
- Tooling lesson: `how-many` cannot match this multibyte glyph
  (returns 0 where string-match-p matches) — the test counts via
  split-string instead.
- Outcome: GREEN. Canonical suite: ALL 46 TESTS PASSED, exit 0.
- Change for next attempt: Q13+Q16 together (director: one
  migration, no double shape change).

## L-043 (2026-09-07, run: impl-ux-r1-b2 — Q13 severity on entries + Q16 uncapped log)

- Attempt: Red tests `cistern-test-ux-q13-severity-persists` +
  `cistern-test-ux-q16-full-log` (red commit `794e970`; red run:
  "breach renders red for every tail tick" + wrong-type on the
  first log entry, 2/48 — the intent re-match lost the breach's
  face on the very next tick, and the 12-cut destroyed the boot
  line).  Green `ccd6d08`.
- Log entries are now (LINE . SEVERITY-ENUM) conses: `cistern--log`
  pushes nil severity, `cistern--log-sev` carries it (relief info;
  breach/leak/condemnation error; milestone success).  The view's
  log-tail maps the entry enum through the palette — NO intent
  re-matching (the M7 intents still exist for the m7 contract).
  Q16: the 12-entry nbutlast is GONE (uncapped ring); `L` opens
  "*cistern log*" — oldest first, read-only — while the main screen
  keeps the 3-line tail.
- Migration sweep: game's log-contains expect, 4a scenarios,
  4a-tutorial's log-has, m7's two find-ifs, r7's (car ...) — all
  now unwrap (car entry).  Lesson: the first 4a edit dropped a
  `let*` closer (check-parens caught it); the second draft of the
  m7 patch left a lambda matching raw conses.
- Outcome: GREEN. Canonical suite: ALL 48 TESTS PASSED, exit 0.
- Change for next attempt: Q14 identity helper at the source.

## L-044 (2026-09-07, run: impl-ux-r1-b2 — Q14 shared worker-identity helper)

- Attempt: Red test `cistern-test-ux-q14-worker-identity` (red
  commit `e656e34`; red run: "shared helper exists in the domain",
  1/49).  Green `7f5600e`.
- The ONE identity helper — `cistern--worker-glyph` + the glyph
  table — is hosted in the DOMAIN (innermost layer), because the
  accident log must reach it; the view's private copy is deleted
  and the map/inspector/legend read the same helper.  This
  SUPERSEDES L-012 finding 1's view-only placement (binding
  directive; no format drift, no off-by-one).  Breach line:
  `BREACH — CREATOR β OVERFLOWED AT (x,y)` — CREATOR #N retired;
  the test pins log-glyph == map-glyph at the breach cell.
- r7's L-012 source greps rewritten to the Q14 contract (domain
  hosts the helper; the view carries no PRIVATE copy).
- Outcome: GREEN. Canonical suite: ALL 49 TESTS PASSED, exit 0.
- Change for next attempt: Q15 ranking + suppression (last of
  batch 2).

## L-045 (2026-09-07, run: impl-ux-r1-b2 — Q15 log consequence ranking + spam suppression)

- Attempt: Red test `cistern-test-ux-q15-log-ranking` (red commit
  `39ac671`; red run: "identical consecutive relief lines collapse",
  1/50 — twelve identical relief lines filled the tail two-wide
  beside the breach).  Green `4519963`.
- Tail = collapse-then-rank: (1) consecutive identical lines
  collapse to one with a silent ×N count (the count is the only
  new text — PROTECT #20 honored); (2) inside the recent window
  (12, the old log cap — ponytail-commented constant), majors
  (breach/condemnation, error severity) always make the tail,
  remaining slots fill by recency; (3) boot flavor ages out like
  any line.  Output order stays chronological; faces persist from
  the entries (Q13).
- Outcome: GREEN. Canonical suite: ALL 50 TESTS PASSED, exit 0
  (34 baseline + 16 UX entries).
- Change for next attempt: batch 3 (Q17–Q21 + Q16's L is done) —
  Q17 cursor-hint surface FIRST (Q18 refusals ride it); Q19 badge
  rides Q01's reserved slot; Q20 is extension-only (existing
  inspector lines byte-identical).

---
## L-046 (2026-09-07, run: impl-ux-r1-b3 — Q17 transient cursor-hint surface)

- Attempt: Red tests `cistern-test-ux-q17-cursor-hint` +
  `cistern-test-ux-q18-refusal-hints` as one dependency-chain red
  (red commit `2521b6e`; red run: void-function cistern-st-hint,
  2/52, exit 1). Greens `ac18656` (Q17), `1214908` (Q18).
- Transport (director-pinned, honored): a state slot — `hint` on
  `cistern-st` — posted by use-cases, read by the view (one row
  under the inspector, dim face, inspector pattern), drained ONCE
  by the driver's refresh after the insert
  (`cistern--cmd-consume-hint`) — the rewards-events pattern, no
  double consumption, no view mutation (the projection backstop
  stayed green).  Nil hint ⇒ empty string ⇒ byte-identical baseline
  render (no permanent layout shift).
- Lesson: headless tests that drive driver commands must assert the
  hint from the RENDERED frame (the refresh consumed it) — asserted
  via with-temp-buffer buffer-string in Q19.
- Outcome: GREEN. Canonical suite: ALL 53 TESTS PASSED, exit 0
  (after Q18's green).
- Change for next attempt: Q18 refusal copy rides the new surface.

## L-047 (2026-09-07, run: impl-ux-r1-b3 — Q18 refusal copy names the next action)

- Attempt: (shared red above). Green `1214908`.
- The two pinned refusal sites post through Q17 with fix-naming
  copy from the Q11 table: build-on-wall →
  `NO FLOOR THERE — AIM FOR OPEN FLOOR`; insufficient-alloy →
  `NEED %d ALLOY — PURGE (x) PAYS` (cost interpolated).  The LOG
  keeps the original lines byte-identical (CANNOT BUILD THERE /
  INSUFFICIENT ALLOY — %d REQUIRED) — history intact, the hint is
  the where-the-eyes-are layer.  Worker-in-the-way and
  out-of-sector refusals intentionally left hint-less (minimal
  reading: the directive names two sites).
- Outcome: GREEN. Canonical suite: ALL 52 TESTS PASSED, exit 0.
- Change for next attempt: Q19 armed badge + cancel.

## L-048 (2026-09-07, run: impl-ux-r1-b3 — Q19 armed verb visible, cancelable, taught)

- Attempt: Red test `cistern-test-ux-q19-armed-badge` (red commit
  `6bae400`; red run: "armed verb visible in the badge slot", 1/53).
  Green `64987c8`.
- Badge: Q01's reserved dim slot now fills when a verb is armed —
  `  ARMED: PIPE — CLICK PLACES, ESC CANCELS` (copy table
  badge-armed); unarmed strip unchanged (q01 still asserts the
  empty slot).  WIDTH CONFLICT ledgered: the pinned badge copy
  (~42 chars with the two-space lead) exceeds the 95-col budget on
  an armed cold strip (85 + 42 = 127).  Resolution: Q01's budget
  pins the STANDING strip; the armed strip is a transient state the
  player just caused (eyes on the cursor, not the strip) — the
  directive's example copy kept verbatim, the q01 test unchanged.
  Compaction rejected; flag to the director if the budget must win.
- ESC/u cancel: `cistern--cmd-disarm` (use-case-owned, mirroring
  cmd-arm-verb per L-010) + adapter `cistern-input-disarm` + driver
  `cistern-disarm`; bound to "u" AND <escape> — both verified
  unbound before (no meta-prefix collision: <escape> is the GUI
  escape-event key, "u" the terminal-friendly option).
- Taught: help line gains `t/p/K arm — click to place` (copy table
  help-arm) — the help line's first sanctioned change.
- Clean refuse: `cistern--cmd-build` now returns t/nil (was: return
  value unspecified — callers never used it); the driver's
  arm-and-build arms ONLY when the at-cursor build lands — a wall
  cursor posts the Q18 hint and leaves the verb unarmed.
- Outcome: GREEN. Canonical suite: ALL 53 TESTS PASSED, exit 0.
- Change for next attempt: Q20 inspector bearing (extension-only).

## L-049 (2026-09-07, run: impl-ux-r1-b3 — Q20 inspector bearing, extension only)

- Attempt: Red test `cistern-test-ux-q20-floor-bearing` (red commit
  `963d925`; red run: "floor cursor names the nearest structures",
  1/54).  Green `191d089`.
- Floor cursor only: `FLOOR — toilet Ω 3 west, tank ▣ 2 north` —
  nearest toilet AND nearest tank picked by manhattan distance in
  the domain (`cistern--nearest-structure`, ties broken in
  coordinate order for determinism); per-axis direction words over
  the shared geometry; glyph + name from the existing tables; the
  format skeleton (`FLOOR — %s`) rides the Q11 copy table.  All
  non-floor inspector lines byte-identical (the wall line is pinned
  exactly in the test) — the t-branch was split, not rewritten.
- Note (ledgered): bearing text is generated data (glyphs/names/
  compass words), not flavored copy — the skeleton lives in the
  table, the words stay in the view; the docs pass may pull the
  words in if it wants total coverage.
- Outcome: GREEN. Canonical suite: ALL 54 TESTS PASSED, exit 0.
- Change for next attempt: Q21 urgency coloring (last of batch 3).

## L-050 (2026-09-07, run: impl-ux-r1-b3 — Q21 urgency colored)

- Attempt: Red test `cistern-test-ux-q21-urgency-color` (red commit
  `d0c3ac4`; red run: "contam >= 75% renders red bold", 1/55 — the
  strip was uniformly cistern-header and the pressure line
  unconditionally dim).  Green `ac1debe`.
- Pressure line faces by state, mirroring the pressure-line cond
  (`cistern-view--pressure-face`): over/severed/backed-up → red
  bold (cistern-toilet-down), RISING → yellow (cistern-tank-high),
  NOMINAL → dim.  Colors, not new words — the strings are
  untouched.  CONTAM segment faces by fraction: yellow ≥ 50%, red
  bold ≥ 75%; the header now arrives already-faced from
  header-line (the render's wholesale propertize was dropped — it
  would have clobbered the segment face).
- Outcome: GREEN. Canonical suite: ALL 55 TESTS PASSED, exit 0
  (34 baseline + 21 UX entries).
- Change for next attempt: batch 4 (Q22–Q30) — Q22 snapshot before
  Q23 death panel; Q24 needs Q03 (landed); Q25/Q26 guards; Q27
  tutorial table; Q28 briefing proofread (%% escapes); Q29 auto-run
  badge rides the Q01 slot; Q30 regret window with the Q07 guard
  watching.

---
## L-051 (2026-09-07, run: impl-ux-r1-b4 — Q22 run-summary snapshot)

- Attempt: Red tests `cistern-test-ux-q22-run-summary` +
  `cistern-test-ux-q23-death-panel` + `cistern-test-ux-q24-goal-
  narration` as one dependency-chain red (red commit `9faf7f7`;
  red run: void-function cistern-st-summary, 3/58, exit 1).
  Greens `584881b` (Q22+Q23+Q24).
- Summary = a plist on `cistern-st` (`:ticks :relieves :score
  :trophies :cause`), banked by `cistern--phase-check` AT TRIGGER
  TIME — commit-first; the Q23 panel only ever reads it.  The
  directive said "one struct"; the plist follows the state's
  card/outcome convention (ledgered, least-active).
- Test lesson: injecting counts then driving 291 ticks doesn't work
  — the natural condemnation fires first and the driven counts are
  overwritten.  The test now drives to condemnation and asserts the
  summary MATCHES the run's counters.
- Outcome: GREEN. Canonical suite: ALL 58 TESTS PASSED, exit 0.
- Change for next attempt: Q23 panel consumes it.

## L-052 (2026-09-07, run: impl-ux-r1-b4 — Q23 death summary panel + restart-line suppression)

- Attempt: (shared red).  The banner layer on condemned renders the
  panel from the banked summary: `SECTOR CONDEMNED — CONTAMINATION
  LIMIT / TICKS n · RELIEVES n · SCORE n / PRESS n TO RESTART`
  (format skeleton in the Q11 copy table) — one frame carries
  cause, counts, restart.  Commit-first, any key skips, input live
  (PROTECT #17): the panel is presentation over live state.
- The FOUR duplicate post-over log lines: the driver's tick command
  logged "SECTOR CONDEMNED — PRESS n FOR NEW GAME" on EVERY
  post-over keypress.  Suppression: log only when the newest log
  line is not already that line — one restart line, silently (no
  new copy; the pressure line already says it).
- Mid-green incident: the Q24 block pushed rewards-eval past the
  L-026 10k form-span again — `cistern--narrate-goals` extracted
  (same decomposition as announce-unlock, L-039).  Also caught:
  pick-tail's recency fill took the OLDEST of the descending index
  stream (`last` of a descending list) and then an unbounded
  `cl-subseq` on short windows — both fixed; the L-017-era
  transient and M7 asserts flushed them out immediately.
- Outcome: GREEN. Canonical suite: ALL 58 TESTS PASSED, exit 0.
- Change for next attempt: Q25 particle placement contract.

## L-053 (2026-09-07, run: impl-ux-r1-b4 — Q25 particle placement contract)

- Attempt: Red test `cistern-test-ux-q25-particle-placement` (red
  commit `5f562d7`; red run: "no sparkle glyph collides with floor
  or digits", 1/60 — the M9 glyph set contained the floor dot "·"
  AND bare digits).  Green `cbd0a67`.
- Contract: ceremony sparkles spawn ONLY over plain floor cells —
  the fill loop draws coordinates until it lands on floor (abundant
  on the map; deterministic child stream, so replays stay
  byte-identical) — and the glyph set is `* ! §` (the floor dot and
  digits deleted).  LEG-06 holds: pipes, walls, toilets and tanks
  stay visible under the ceremony.  Popups unaffected (M5 layer).
- Outcome: GREEN. Canonical suite: ALL 60 TESTS PASSED, exit 0.
- Change for next attempt: Q26 executable non-modal guard.

## L-054 (2026-09-07, run: impl-ux-r1-b4 — Q26 non-modal guard executable)

- Attempt: guard test `cistern-test-ux-q26-non-modal-guard` (lands
  green with the Q25 commit — no red: the constraint was already
  true of the mechanism; this entry pins it for Q23/Q24's new
  ceremonies, per the directive "constraint made executable").
  Extends the 4b-m9 (e) skip-semantics pattern onto the death
  panel: during the panel a cursor move and a tick behave normally,
  the n keypress starts the new game (fresh deal verified), and the
  banked Q22 summary survives in the condemned state — nothing
  forfeited, nothing pending (commit-first).
- Outcome: GREEN. Canonical suite: ALL 60 TESTS PASSED, exit 0.
- Change for next attempt: Q27 tutorial table ships.

## L-055 (2026-09-07, run: impl-ux-r1-b4 — Q27 tutorial table ships)

- Attempt: Red tests `cistern-test-ux-q27-tutorial-table` +
  `cistern-test-ux-q28-briefing-proofread` (red commit `7ae7e15`;
  red run: "step 1 prompt visible on a new game", 2/62).  Green
  `bd9b579`.
- `cistern--tutorial-steps` ships its default table: 3 steps over
  real predicates — cursor onto a worker, purge a filling tank
  (purges > 0), the purge pays (alloy > 20).  Prompts from the Q11
  copy table, inspector-grade; the persistent prompt line is the
  EXISTING tutorial-line render (no log lines).  One gated step per
  tick (legacy advance semantics, unchanged).
- Contract change landed on 4a-tutorial: the "shipped table is
  empty" pin superseded — the table ships 3 steps; the
  no-side-effect invariant now holds via the step-gate (a tick
  whose predicate does not hold logs nothing).
- Test lesson: step 1 cannot be driven by parking the cursor on a
  worker's CURRENT cell (the wanderer moves during the same tick) —
  the drive parks the cursor on the spawn cell and waits for the
  wanderer to pass under it (deterministic seed, bounded).
  ALSO harvested: `cistern-test-ux--drive-relief` had lost its seat
  tick to an earlier fuzzy patch match — five tests failed at once;
  the fixture is load-bearing for the whole UX suite.
- Outcome: GREEN. Canonical suite: ALL 62 TESTS PASSED, exit 0.
- Change for next attempt: Q28 briefing proofread (same green).

## L-056 (2026-09-07, run: impl-ux-r1-b4 — Q28 briefing proofread)

- Attempt: (shared red).  The two `princ` literals carried literal
  `%%` (princ does not format — SCREEN-14's regression); now `60%`
  and `100%` print true.  The CONTROLS block gains the
  arm-then-click line (copy table help-arm, with Q19); the seed
  mention landed with Q01's briefing move and is now pinned by the
  test.  Asserts: 60% present, 100% present, NO `%%` anywhere,
  click-to-place present, seed present.
- Outcome: GREEN. Canonical suite: ALL 62 TESTS PASSED, exit 0.
- Change for next attempt: Q29 auto-run surfaced + pacing.

## L-057 (2026-09-07, run: impl-ux-r1-b4 — Q29 auto-run surfaced + pacing)

- Attempt: Red tests `cistern-test-ux-q29-auto-run` +
  `cistern-test-ux-q30-regret-window` (red commit `491bac6`; red
  run: wrong-number-of-arguments on the 1-arg toggle, 2/64).
  Green `29539fa`.
- Badge: while the chain is live the Q01 slot shows `  AUTO-RUN`
  (copy table).  The timer HANDLE stays out of state (D2 honored) —
  the adapter mirrors an on/off FLAG into `cistern-st-auto-run`.
  Pacing: prefix-arg slow mode schedules 1.0s chain links (1
  tick/second) beside the 0.2s default; the interval lives in an
  adapter defvar (`cistern-input--auto-run-interval`) — plumbing,
  never game state — and the callback's reschedule reads it, so
  slow mode stays slow across links.  Default 0.2 verified
  unchanged (r6's cl-letf asserts untouched).  Help line already
  mentions `r` (Q29 satisfied as-is).
- Outcome: GREEN. Canonical suite: ALL 64 TESTS PASSED, exit 0.
- Change for next attempt: Q30 free regret window (final directive).

## L-058 (2026-09-07, run: impl-ux-r1-b4 — Q30 free regret window)

- Attempt: (shared red: "place + immediate demolish: alloy
  unchanged").  Green `29539fa`.
- The window: `cistern-st-built-at` records the tick of placement
  per cell (set in cmd-build, cleared on demolish); demolishing
  while `built-at == current tick` refunds EVERYTHING — the
  demolish fee AND the full build cost — so the place+demolish
  cycle costs exactly nothing.  After any tick the M1 50% split
  returns (L-024 rounding preserved).  Ledgered reading: "refunds
  fully" = net zero over the cycle, which requires the fee back
  too; the directive's own acceptance ("alloy unchanged") pins it.
  Tick-1 affordability: the 20-alloy start always covers the
  demolish fee after the most expensive build (asserted).
- Contract updates: `cistern-test-demolish` A/B and `cistern-test-
  4b-m1-demolish-refund` all placed+demolished SAME-TICK — they now
  assert the regret window (net zero) and/or tick past the window
  before asserting the M1 50% rules; the ticked 50% path is
  additionally pinned by the new q30 ticked variant.
- Outcome: GREEN. Canonical suite: ALL 64 TESTS PASSED, exit 0
  (34 baseline + 30 UX entries).
- Change for next attempt: ROUND-1 END — closing summary + docs
  status marks.

## L-059 (2026-09-07, run: impl-ux-r1 — ROUND-1 END SUMMARY)

- All 30 directives SHIPPED (see docs/ux/TOP-30.md status marks).
  Canonical suite: ALL 64 TESTS PASSED, exit 0 (34 baseline + 30
  UX entries, tests/test-ux-r1.el, registered in tests/run.el).
  Ledger range this round: L-035..L-059 (25 entries).  Every
  directive: red commit first (except the three executable-PROTECT
  guards Q06/Q07/Q26, ledgered as pins), minimal green, suite green
  at every green boundary.
- PROTECT status: inspector purge rate + idle pressure line
  byte-identical (pinned by tests); popups at the act cell/tick
  (Q06 guard); purge economy exact (Q07 guard); self-teaching loop
  live (starter card + tutorial table); non-modal ceremony
  (Q26 guard extends 4b-m9's skip semantics to the death panel);
  Blame! register enforced by the Q11 copy table + drift test.
- Real bugs the process caught: card-literal aliasing breaking
  replay identity (L-036); view hash-layout access (r5 backstop,
  L-039); two form-span overruns (L-026 gate, L-039/L-052); the
  pressure line lying at the losing moment (Q09/Q10, the round's
  core fix); ANTAG-06's dead pipe indistinguishable from floor
  (Q12); M7 faces lost after one tick (Q13); ANTAG-12's silent
  milestones (Q05); the M1 fee trapping tick-1 mistakes (Q30).
- Change for next attempt (round 2 candidates, not directives):
  RISING band skippability in one-tank games (L-039 pacing note);
  armed-strip width if the 95 budget must win (L-048, director
  accepted as taken); live playtest re-run of ANTAG/LEG captures
  to refresh the docs' before/after evidence.

---
