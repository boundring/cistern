# Phase 4 Execution Plan — Tutorial (4a) + Rewards Consumption (4b)

Expands ROADMAP Phase 4 into red/green pairs. Inputs: DESIGN-SPEC §4 R4/R5,
§5, §6; ROADMAP Phase 4a/4b briefs; `docs/REWARDS-DESIGN.md` (designer
deliverable, landed in-repo — 4b is unblocked; designer working notes at
`docs/rewards-notes.md`); legacy tutorial table `legacy/cistern-share/cistern-2.0.0/cistern.el:556-599`;
reference/roguelike-agentic.md; docs/HANDBRIEF-TEMPLATE.md.

Process for every pair: red test committed first (`test: R# failing — <name>`),
minimum implementation, green (`R#: <what>`). Lesson checkpoint after each
cycle per roguelike-agentic / spec §5.3. No git commits from the tutorial/rewards
run — the coherence pass commits; commits named below are message texts.

---

## Phase 4a — Fail-first tutorial (R4)

**Goal.** Two deterministic scripted scenarios on the retained predicate-table
mechanism: losing (bladder breach → contamination > 0 → lesson log line) and
winning (same seed, need served, contamination stays 0). Scenarios are DATA.

### Scenario-as-data shape (pinned here, mechanism from legacy :556-599)

```elisp
(cistern-tutorial-scenario
 :name "lose-breach"
 :seed 42
 :script                       ; ordered verbs applied headless, one per tick
  '((wait . 20)                ; let bladder climb
    (verb . purge)             ; wrong move — or simply omissions
    (wait . 40))               ; ...until breach fires
 :expect                       ; outcome predicates over final state
  '((contamination . (> 0))    ; breach happened
    (log-contains . "lesson")  ; lesson stated
    (over . t)))
```

A **scenario** = `seed` + ordered `script` (wait/verb steps — verbs are the
Phase 2 use-case calls with pure signatures, no view, no cutscenes) + `expect`
predicate list (same shape as the legacy tutorial-step predicates: lambda over
state, non-nil advances/holds). Runner: `cistern-tutorial-run-scenario` in
`cistern-game.el` — seeds state from seed, replays script via the tick
pipeline, asserts every `expect` predicate headlessly. The predicate-table
advance mechanism (each step's predicate gates progress; `T` skips) is
retained unchanged for the interactive tutorial; scenarios are just
higher-level entries in that table tradition.

### Red/green pairs (ordered)

1. **Red: `tutorial-losing-scenario-reaches-breach`** — runner applies the
   losing script at seed 42; asserts final contamination > 0 and a log entry
   containing "lesson". *Verbatim accept (R4):* "batch test runs the scripted
   losing scenario to a breach with contamination > 0 and a 'lesson' log entry".
   Red commit: `test: R4 failing — tutorial-losing-scenario-reaches-breach`.
   Min impl: `cistern-tutorial-run-scenario` + the losing scenario data.
   Green commit: `R4: losing scenario data + headless scenario runner`.

2. **Red: `tutorial-winning-scenario-zero-contamination`** — same seed 42,
   winning script (build/purge to serve the same need); asserts
   contamination == 0 through and at end of script. *Verbatim accept:* "...then
   the scripted winning scenario where the same seed's need is served with
   contamination staying 0."
   Red commit: `test: R4 failing — tutorial-winning-scenario-zero-contamination`.
   Min impl: winning scenario data only (runner exists from pair 1).
   Green commit: `R4: winning scenario data, same-seed need served`.

3. **Red: `tutorial-predicate-table-retained`** — predicate-table advance
   still gates interactive steps: a state that satisfies step N's predicate
   advances the tutorial index exactly once and logs "TUTORIAL: OBJECTIVE
   COMPLETE" on final step; `T` still skips. *Verbatim accept (R4 tail):*
   "Retains the predicate-table mechanism." Plus handoff brief done-when:
   "Tutorial retains predicate-table advance mechanism; T still skips."
   Red commit: `test: R4 failing — tutorial-predicate-table-retained`.
   Min impl: port `cistern--tutorial-advance` semantics to the Phase 2
   tutorial-table holder in `cistern-game.el` (domain-pure; index in state).
   Green commit: `R4: predicate-table advance on rewritten stack`.

4. **Red: `tutorial-scenarios-deterministic`** — each scenario run twice at
   its seed yields identical state hash (spec §5.2 determinism applied to
   scenarios). Red commit: `test: R4 failing — tutorial-scenarios-deterministic`.
   Min impl: none expected (falls out of seeded state + pure verbs); if it
   fails, fix the leak (likely an unseeded RNG consumer), not the test.
   Green commit: `R4: scenario determinism verified` (or folded into pair 1
   fix if the leak was there).

### PINNED vs DEFERRED

- **Pinned:** scenario = seed + scripted verb list + expected predicates
  (data, not code); two scenarios exactly; predicate-table mechanism; `T`
  skip; headless runner name and behavior.
- **Deferred (spec §6):** tutorial chapters beyond the two scenarios,
  adaptive difficulty, any tutorial UI beyond the existing log/prompt
  projection, choosing which seed id ships (42 is a placeholder — the
  property is "exists a seed where both scenarios behave", not seed 42).

### Lesson checkpoint

Expected failure class (ROADMAP 4a): **scenario desync** — a scripted step
invalid under current rules (verb costs changed by Phase 2 tuning, breach
fires early/late). A scenario that stops reproducing its own breach is a dead
run: harvest divergence into `docs/FAILURE-LEDGER.md` (§5.3 format) with the
failing step named, re-brief per HANDBRIEF-TEMPLATE.md. Second expected
class: determinism leak (scenario results differ run-to-run) — trace the
unseeded consumer, never weaken the assert.

### Done-when

- Both scripted scenarios pass headless: breach + lesson entry (losing);
  same-seed need served at contamination 0 (winning).
- Predicate-table mechanism retained; `T` skips (interactive path testable
  headless via the advance function).
- Both scenarios deterministic at their seeds.
- R4 acceptance criterion verbatim-satisfiable in one batch invocation
  (`emacs -Q --batch -l cistern.el -f cistern-run-selftest` extended block).

---

## Phase 4b — REWARDS-DESIGN consumption (R5 full)

**Goal.** `cistern--rewards-eval` consumes the designer document's declarative
spec only — zero reward rules invented outside it. The doc is landed at
`docs/REWARDS-DESIGN.md` and is the contract; its §2 MUST table (M1–M9),
§4 dancing-pixels spec, §5 integration contract are binding acceptance
criteria. Baseline carried from Phase 2: the default outcome
`(:score 0 :objectives nil :unlocks nil :celebrate nil)` + empty
presentation-intents test is GREEN and stays green; 4b's consumption
re-shapes the outcome per the doc (same shape and split pinned in plans
01/02). Currency mapping: the doc's session "coins" are the sim's alloy —
one in-map currency, two names (spec §6).

### How consumption maps

| REWARDS-DESIGN section | Consumed into |
|---|---|
| §5 eval contract (consumes state + tick events → returns updated state + presentation intents) | `cistern--rewards-eval` signature in `cistern-game.el` (R5 interface pinned by spec §4 R5) |
| §2 M1–M9 acceptance criteria | one red test each (below) |
| Goal-card shape `{map_id, goals[], difficulty_tier}`, max 3 goals, all-satisfied ⇒ MapCompleted | goal evaluator, per-tick |
| Milestone ladder `{threshold, unlock}` ×5, UnlockEmitted exactly once, persists across maps | unlock evaluator over cumulative relieves |
| Reputation 0–100 (+1/−5/−2, clamped), tiers 0–39/40–69/70–100, pay-forward ±25% | reputation stat + next-card difficulty setter |
| §4 particle field (Particle shape, seed⊕stream-id RNG, K=64 FIFO, TTL≤6, trigger table, advance semantics, renderer purity) | domain field + adapter overlay |
| §4 seven fail-first test criteria | the M6 red/green pairs, verbatim |
| §6 deferred/open items | stay deferred; no pricing, no copy, no mood system |

Design decisions NOT in the doc (pricing, difficulty values, VR-8 curve,
banner copy) are DEFERRED per the doc's own §6 — placeholder constants with a
fixture, never invented mechanics.

### Red/green pairs (per MUST mechanic; test defends the doc's acceptance criterion verbatim)

- **M1 demolish tool.** Red `test: R5 failing — M1-demolish-refund`:
  demolish pipe worth 10 with 50% refund on 100 coins → 105, tile empty,
  contamination puff if dirty; refuses empty tile with error, no state change.
  Green `R5: M1 demolish consumption`. (Overlaps R8 — R8 owns removal
  mechanics; M1's red test pins the *refund* + refusal contract on top.)
- **M2 seeded generation.** Red `R5 — M2-solvability-validation`: same seed →
  identical map; ≥3 signatures over N seeds; solvability retried inside
  generation, bounded. Green `R5: M2 generation consumption`. (Shares R3's
  procgen tests; M2 adds the bounded-solvability retry predicate.)
- **M3 goal cards.** Red `R5 — M3-goal-card-completion`: satisfy all goals on
  a tick → MapCompleted; missing one → no; re-checked every tick. Green
  `R5: M3 goal evaluator`.
- **M4 reputation.** Red `R5 — M4-reputation-deltas`: +1 clean relieve, −5
  burst, −2 leak, clamped 0–100; next card consumes current reputation. Green
  `R5: M4 reputation`.
- **M5 relieve-pay + popup.** Red `R5 — M5-relieve-pay-popup`: pay within
  warning window, 2× near-burst, popup entity ttl=3 drifting up 1/tick,
  removed at 0; occasional VR-8 tip seeded. Green `R5: M5 pay + popup`.
- **M6 dancing pixels — the doc's seven verbatim criteria, in order** (each
  its own red/green pair; green commits `R5: M6 criterion <n>`):
  1. fixture equality at N = 0, 1, 3, 6 (full particle list);
  2. same-seed identity / 20-seed difference;
  3. TTL expiry — field empty after max-TTL + 1;
  4. K=64 FIFO eviction, deterministic under seed;
  5. advance-when-paused animates field, sim counters untouched;
  6. renderer purity — same inputs → same buffer, particles never mutate map;
  7. ceremony commit-first — trophy persisted at zero ceremony ticks
     (overlaps M9's red; one test may defend both, counted once).
  Also: RNG-stream fixture (first 100 stream values pinned) and invalid-state
  domain error (ttl<0, |vel|>1) per §4 failure modes 2 and 5.
- **M7 face flash + three-tier log.** Red `R5 — M7-severity-mapping`:
  relief→minor faced line; burst→major + error face on tile; MapCompleted→
  banner cleared after N ticks. Green `R5: M7 log/face tiers`.
- **M8 milestone ladder.** Red `R5 — M8-unlock-once`: thresholds
  5/15/30/50/100 crossed → UnlockEmitted exactly once; unlocked upgrade
  purchasable; persists across maps. Green `R5: M8 ladder`.
- **M9 ceremony.** Red `R5 — M9-ceremony-commit-first`: MapCompleted ⇒ trophy
  + next-map unlock committed at trigger time, zero ticks; ceremony = 6
  ticks, particle field + centered banner, auto-run pauses, any key skips,
  no forfeit. Green `R5: M9 ceremony`.

Order M6's stream fixture **before** M5/M6 spawn tests (both consume the
seeded stream). Order M9 after M6 (ceremony renders particles).

### Contract-mismatch death rule (ROADMAP 4b, binding)

If any doc predicate cannot be evaluated over the state object (a needed
field doesn't exist, a predicate needs data the sim never produces), that is
a **contract break**: the run is dead per roguelike-agentic. Harvest the
exact mismatch into `docs/FAILURE-LEDGER.md` (predicate, needed state,
available state) and route back to the designer workstream. Do NOT work
around — no shim predicates, no "close enough" thresholds, no new fields
invented to satisfy a predicate without designer sign-off. Reroute includes
pausing that mechanic's pair; unaffected pairs may continue.

### Lesson checkpoint

Harvest after each cycle. Expected failure classes: (a) predicate/state
mismatch (see death rule — ledger + designer reroute); (b) RNG stream
entanglement (particles consuming sim randomness → fixture test fails) — fix
is the seed⊕stream-id derivation, not test weakening; (c) celebration leaking
into sim time (advance-particles touching coins/reputation) — caught by
criterion 5.

### Done-when

- `cistern--rewards-eval` returns non-default outcomes driven solely by
  REWARDS-DESIGN.md rules for each documented trigger (M1–M9 green).
- All seven §4 test criteria green; RNG fixture pinned.
- Dancing-pixels celebration renders on a documented trigger via the view
  adapter (presentation intents from eval → overlay render, pure).
- No reward rule exists in code that is not traceable to a doc line.
- R5 acceptance: placeholder test's "doc can be loaded and drives the
  outcome" clause now passes; fresh state still returns the documented
  default outcome.

---

## Dependencies

- **4a waits on:** Phase 3's view contract existing **at implementation
  time** (scenarios exercise verbs headlessly, so planning/test-authoring
  can precede Phase 3; the runner green requires the Phase 2 tick pipeline
  and the Phase 3 contract). Loses nothing by planning now.
- **4b is UNBLOCKED now:** `docs/REWARDS-DESIGN.md` is landed in-repo (the
  ROADMAP "BLOCKED" note predates its landing). Only soft ordering: 4b's M6
  render criteria want the Phase 3 view adapter present at implementation
  time; the domain-side criteria (field, RNG, goals, reputation) depend only
  on Phases 1–2 state shapes.
- Both phases inherit: spec sections, legacy line ranges, handoff briefs in
  ROADMAP Phase 4, red-before-green obligation, and DEFERRED-not-coded for
  anything ambiguous (spec §6).
