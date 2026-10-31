# CISTERN — Methods

How this game was created, for readers who want to understand the
building, not just the building. Nothing here is invented: every claim
cites a file in this repo, and the numbers are the recorded ones.

## 1. The method: agentic, fail-first, ledger-backed

CISTERN was rewritten from a legacy 1140-line single file
(`legacy/cistern-share/cistern-2.0.0/cistern.el`) into a layered
package by a chain of AI sessions working under operator direction.
The method is pinned in [DESIGN-SPEC.md](DESIGN-SPEC.md) §1: fail-first,
lessons-into-ledger, failure-informed handoff.

- **Red/green pairs.** Every unit of work lands as a failing test,
  then the code that turns it green, then a commit. The commit boundary
  is the recovery point.
- **The failure ledger.** One append-only entry per dead, stalled, or
  wrong-basis run — attempt, outcome, evidence, lesson, concrete change
  for the next attempt ([FAILURE-LEDGER.md](FAILURE-LEDGER.md),
  L-001 onward). The ledger is the design artifact the next run reads.
- **Handoff briefs.** A replacement session gets the spec, the brief
  ([HANDBRIEF-TEMPLATE.md](HANDBRIEF-TEMPLATE.md)), and nothing it
  would have to re-discover: mission, repo state, ledger ids, done-when.
- **Independent verification.** After each phase a verifier re-runs
  the suite from scratch; false greens are cheap to catch this way.
- **Honest deviations.** A probe that passes on arrival is
  strengthened, never manufactured; plan-order deviations are ported
  and ledgered, not hidden.

The honest build story — what ran, what worked, what hurt, and the
standing process rules each incident produced — is
[PROCESS-RETRO.md](PROCESS-RETRO.md). Its headline numbers: the Phase 1
domain rewrite ran as one 46-minute session, 5 red/green pairs, 10
commits, zero clarification turns.
## 2. Architecture: five layers, one state object

The target architecture is a clean-architecture layer map
([DESIGN-SPEC.md](DESIGN-SPEC.md) §3.1). Dependencies point one way:
inward — drivers to adapters to use cases to domain. The domain
imports nothing Emacs-y: no buffers, no windows, no timers, no faces.

```
Frameworks & Drivers ──── cistern.el      (buffer, major mode, keymap, timer, command loop)
Interface Adapters ─────── cistern-view.el  (render projection: state → text/face)
                           cistern-input.el (mouse events / keys → use-case calls)
Use Cases ──────────────── cistern-game.el  (game verbs, tick orchestration, tutorial,
                                             objectives/scoring entry point)
Domain (pure) ──────────── cistern-domain.el (state structs, RNG, grid, tile tables,
                                              procgen, sim rules, connection logic)
```

The single state object: exactly one struct instance is threaded
through every sim function; use cases take state plus intent and
return state (and a log line); adapters are pure projections. The one
module global is the live game handle, held by the interactive layer
only — with a single pinned exception for the auto-run timer handle,
landed ledger-first (L-015).

An external review of this codebase (hngh research line
*cistern-architecture-review*, 2026-09-08) concluded that the
five-layer structure validates the viability of strict core/edge
separation in Emacs Lisp — a testable core independent of live Emacs
frames — with one honest caveat the repo shares: the boundary is held
by convention, naming discipline, and review, not by a compiler. The
review maps the layers onto core/domain, core/engine, and edge/*
doctrine and recommends port interfaces and runtime state guards where
a downstream project needs compiler-grade enforcement.

## 3. Seeded determinism

The sector is generated from one integer seed, and everything random
in the game descends from it.

- The state carries the game seed; child RNG streams derive from it
  as `seed XOR stream-id` (RPG stream 3, story stream 4, world stream
  5 — `src/cistern-domain.el`, `cistern--stream-init`). Sim outcomes
  and generation never share a stream.
- The same seed produces an identical trajectory: the suite asserts
  state equality after N ticks (`tests/domain-determinism.el`), and
  map integrity holds across seed sweeps
  (`tests/domain-map-integrity.el`).
- Before any change that could alter generative output, byte-identity
  anchors are captured — sha256 of the full state per seed — so the
  next run can prove a feature added zero LCG draws on standard maps
  (ledger L-112: seeds 1, 42, 20260830).
- The default seed is 20260830 (the code is the pinned reading; see
  the L-112 recovery block).

## 4. The test harness

The suite runs headless in batch — no display, no wall-clock:

```sh
emacs -Q --batch -l tests/run.el -f cistern-run-all-tests
```

- `tests/run.el` is the canonical runner (`cistern-run-all-tests`),
  adopted after an early run wasted cycles on ad-hoc entry-point
  discovery (PROCESS-RETRO P3). It loads the domain, the game layer,
  the bank generator, then every test file.
- The registry lists **140 entries** (verified 2026-09-11 with
  `(length cistern-test-entries)`): procgen variety, map integrity,
  tick headless-ness, determinism and draw-order, demolish, cursor and
  click, keymap and glyph contracts, rewards, tutorial scenarios, v4/
  v5/v6 waves, UX rounds, and source-integrity checks.
- Time-dependent behavior (auto-run) is tested via timer scheduling
  records, not wall-clock ([DESIGN-SPEC.md](DESIGN-SPEC.md) §5.2);
  no test depends on time, window size, or display.
- A soak runs a scripted competent player for extended ticks and must
  survive — the game has a competent-player acceptance bar, not just
  unit coverage.

## 5. The playtest capture harness

Player-eye evidence is captured by scripted drivers that launch the
game headlessly, drive it through real verbs, and dump the rendered
screen to text. Four probe suites live in `playtest/`:

| Suite | Drivers | Artifacts |
|---|---|---|
| smoke (`smoke.el`) | 16 steps: cursor, builds, clicks, demolish, purge, reliefs, completion | SCREEN-01…16 |
| antagonist (`antagonist.el`, `antagonist2.el`) | 14 violation and edge probes | ANTAG-01…14 |
| legibility (`legibility.el`) | 6 state faces: pressure, contamination, death, ceremony | LEG-01…06 |
| UX round 2 (`r2.el`) | 18 directives re-measured | R2-01…18 |

That is 54 scripted screen dumps, plus `UX-KEYS-REPORT.txt` and the
summary in `playtest/SMOKE-REPORT.md`. The pattern fed the UX cycles:
directives were batched (≤4), measured with render probes before
rulings, and each batch closed green against the suite (PROCESS-RETRO,
steering lessons 1 and 3).

## 6. Design-doc lineage

The rewrite plans and the version waves, in order:

- **plans/** — the three dependency-ordered phase plans that took the
  legacy file to the package: 01-core-rewrite (domain), 02-input-ui
  (adapters + driver), 03-tutorial-rewards (use cases + rewards).
- **v4/** — the RPG layer: worker stats, XP and clearance, the story
  engine (banks, hooks, acts), the surface contract. V4-SPEC pins the
  scope; RPG-LAYER and STORY-ENGINE own their subsystems.
- **v5/** — social and comedy: combat (the warband), the comedy
  director, social behaviors, and the stall analysis.
- **v6/** — world and ecology: size classes and themes, ecology,
  controls, the faced log system, and HANDOFF — the gentle-halt
  pointer that carries the v6 queue and the L-112 recovery block.
- [ROADMAP.md](ROADMAP.md) records what shipped in each phase;
  [INDEX.md](INDEX.md) shelves all of it.
