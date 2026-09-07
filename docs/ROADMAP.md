# CISTERN — Dependency-Ordered Roadmap

Governs the Clean-Architecture rewrite per `docs/DESIGN-SPEC.md`
(requirements R1–R10, architecture §3, test strategy §5). Execution ran
the roguelike-agentic loop (`reference/roguelike-agentic.md`): attempt,
harvest lessons into `docs/FAILURE-LEDGER.md`, replace dead runs with
failure-informed briefs (per `docs/HANDBRIEF-TEMPLATE.md`). Order:
inward-out — domain → use-cases → adapters → content. No new
architecture decisions were added here; anything ambiguous went to
DEFERRED (spec §6).

Every phase below is SHIPPED. Commit ranges name the work commits,
red-test-first per R10; closing-review commits end each phase. The
handoff briefs each phase carried are consumed; the ledger and the
phase records below are the history.

---

## Phase 1 — Domain: tile tables, state, procgen — SHIPPED

**Range.** `66f3940` (test: R3 failing — procgen variety) → `cf0121f`
(process retrospective, Phase 1 lessons applied).

**Goal, as shipped.** The pure domain layer, headless-provable:
`cistern-domain.el` with the reference tile table (R3), state structs,
grid primitives, seed-driven procgen — and, because the tick pipeline is
domain (spec §3.2 puts sim phases + connection logic here), the whole
pure sim core: worker lifecycle, the one flood primitive and connection
functions, the four sim phases, `cistern--sim-tick` (four phases only —
the tutorial-advance hook moved to the game layer).

**Accepted against.** R3 (≥5 seeds → ≥3 distinct layout signatures,
table-only glyph/passability routing), R9 (domain loads and ticks
headless), determinism §5.2 (same seed ⇒ same map and 50-tick
trajectory).

**Dead-run rule that held.** A run editing legacy files, inventing cell
kinds outside the table, or re-failing the same determinism assert twice
was dead: harvest, close, re-brief.

---

## Phase 2 — Use cases: verbs, tick pipeline, rewards-eval placeholder — SHIPPED

**Range.** `3d83c39` (test: R8 failing — demolish verb) → `07ff925`
(Phase 2 closing review).

**Goal, as shipped.** `cistern-game.el` verbs on domain state: build,
demolish (R8), decon, purge, cursor move/click-move; tick orchestration
(exactly-one-tick, R6 logic half; `cistern-run-10` deleted); tutorial-table
mechanism holder; `cistern--rewards-eval` placeholder (R5 interface, default
outcome pinned).

**Accepted against.** R8 (demolish → floor, hash entry gone, alloy
reduced, downstream toilets unusable; no dangling plumbing entries — the
v1 phantom-plumbing invariant), R6 (tick advances exactly 1, no
`run-10` symbol), R5 placeholder, R9 batch conformance. Commit policy
per PROCESS-RETRO P2: one red + one green per pair, ledger entry with
each green.

**Expected failure site that held.** Demolish connection-kill semantics
— a run letting plumbing hash entries dangle was dead.

---

## Phase 3 — Interface adapters: input and view — SHIPPED

**Range.** `4aeafad` (per-pair cadence note) → `02109a8` (Phase 3 closing
review).

**Goal, as shipped.** Input adapter: arrow-only movement + mouse
click-to-move/click-to-place + `r` auto-run timer (R1, R2, R6 UI half).
View adapter: connection-state pipe glyphs (shape AND face), celebration
render hook (R7, R5 render side). Driver: keymap without hjkl, timer
wiring, the single `cistern--st` global.

**Accepted against.** R1, R2 (hjkl unbound, arrows bound), R6 via timer
scheduling records (0.2s idle timer, cancel, one tick per fire), R7
(connected vs isolated pipe differ in glyph and face), R9 static
no-outward-reference check.

**Dead-run rule that held.** Adapter leakage — an adapter naming a domain
hash layout directly, or calling render — was dead; harvest, re-brief
with the projection-only rule named.

---

## Phase 4 — Content: fail-first tutorial, REWARDS-DESIGN consumption — SHIPPED

**Range.** `2db8778` (test: R4 failing — losing scenario) → `fe5f34a`
(Phase 4 closing review).

### 4a. Tutorial — SHIPPED (parallel with Phase 3)

Losing scenario: deterministic scripted run to a bladder breach,
contamination > 0, lesson log entry. Winning scenario: same seed class,
need served, contamination 0. Predicate-table mechanism retained; `T`
still skips.

**Dead-run rule that held.** Scenario desync — a scripted step invalid
under current rules — was a dead run; the failing step was named in the
re-brief.

### 4b. Rewards consumption — SHIPPED (doc landed at docs/REWARDS-DESIGN.md)

`docs/REWARDS-DESIGN.md` (designer notes at `docs/rewards-notes.md`)
consumed declaratively into `cistern--rewards-eval` and the view's
dancing-pixel celebrations: §2 MUST table (M1–M9), §4 particle field, §5
integration contract. Consumption only — no reward rules invented outside
the doc. A predicate the state could not express would have been
reported back, not worked around; the M2 generation property held on
arrival (L-025).

---

## Smoke and public surface — SHIPPED

**Range.** `54208e3` (test: smoke L-034 — run-line load and `?` briefing,
red) → `9ef36b3` (public README).

Path-loaded `emacs -Q -l src/cistern.el` works without a bare top-level
`when` bootstrap (L-034; every src/ top-level form must be a defining
head). The `?` briefing crash and stale prices found by the live smoke
run were fixed in `f0124f4`.

---

## UX Round 1 (Q01–Q30) — SHIPPED

**Range.** `c812f3f` (test: Q01+Q02 — header strip contract) → `3a681c5`
(ledger L-051..L-059, ROUND-1 END SUMMARY; TOP-20/TOP-30 marked SHIPPED).

Header strip `TICK ALLOY POP CONTAM SCORE GOALS REP` with reserved dim
badge slot (armed verb, auto-run); starter goal card from tick one;
milestone announcements; urgency-facing colors (CONTAM segment and
pressure line); pressure-line re-branch (RISING at 0.85× capacity,
severed lines named the tank to rewire toward); the Q11 copy table
`cistern--copy` in the domain (see `docs/ux/COPY-TABLE.md`); generated
legend with dead-pipe glyph; persistent faced log with ×N collapse and
`L` buffer; one-identity worker glyphs; transient hint surface naming
the fix; floor bearing; armed badge + ESC/u disarm; ceremony sparkles
over plain floor only; death panel on condemnation; 3-step tutorial over
real predicates; auto-run badge + prefix-arg slow mode; free regret
window (same-tick demolish refunds everything, M1 50% after a tick).
Directive ledger: `docs/ux/TOP-20.md`, `docs/ux/TOP-30.md`.

---

## Dependency graph

```
Phase 1 (domain) ──► Phase 2 (use cases) ──► Phase 3 (adapters) ──► 4a (tutorial, parallel)
                                                          └────────► 4b (rewards — unblocked;
                                                                     wants Phase 3 view at impl time)
```

All phases above shipped in that order. Expansion workers inherited: the
spec sections and legacy line ranges named in their phase, their handoff
brief, and the obligation to red-commit before green. Ambiguity went to
DEFERRED, never into code.
