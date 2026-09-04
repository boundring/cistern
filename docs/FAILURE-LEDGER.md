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
