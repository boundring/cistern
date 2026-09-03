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
