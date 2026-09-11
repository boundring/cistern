# CISTERN — Documentation Index

Everything the repo knows, shelved. Start at the shelf that answers
your question; captions say which.

## The game

| Shelf | Contents |
|---|---|
| **Play it** | [PLAYING.md](../PLAYING.md) — install, controls, stats, win/lose, the screen |
| **Design spec** | [DESIGN-SPEC.md](DESIGN-SPEC.md) — the clean-architecture rewrite contract: layers, requirements, test strategy |
| **Rewards design** | [REWARDS-DESIGN.md](REWARDS-DESIGN.md) — score, goal cards, reputation, milestones, celebration · [rewards-notes.md](rewards-notes.md) — the working notes behind it |

## How it was made

| Shelf | Contents |
|---|---|
| **Methods** | [METHODS.md](METHODS.md) — methods, architecture patterns, seeded determinism, test harness, doc lineage |
| **Process retro** | [PROCESS-RETRO.md](PROCESS-RETRO.md) — what ran, what worked, what hurt, the standing rules |
| **Failure ledger** | [FAILURE-LEDGER.md](FAILURE-LEDGER.md) — append-only, one entry per dead/failed/retried run (L-001…L-112+) |
| **Roadmap** | [ROADMAP.md](ROADMAP.md) — dependency-ordered phases and what shipped in each |
| **Handoff template** | [HANDBRIEF-TEMPLATE.md](HANDBRIEF-TEMPLATE.md) — the brief a replacement session gets |

## Design lineage — the version waves

Each wave is a spec plus its design modules; newer waves build on the
pinned decisions of the older ones.

| Wave | Contents |
|---|---|
| **v4 — RPG layer** | [v4/](v4/) — V4-SPEC, RPG-LAYER (stats, XP, clearance), STORY-ENGINE (banks, hooks), SURFACE |
| **v5 — social & comedy** | [v5/](v5/) — V5-SPEC, COMBAT (the warband), COMEDY-DIRECTOR, SOCIAL, STALL-ANALYSIS |
| **v6 — world & ecology** | [v6/](v6/) — V6-SPEC, WORLD, ECOLOGY, CONTROLS, LOGS, HANDOFF (queue pointer at the Hngh intake) |

## Working papers

| Shelf | Contents |
|---|---|
| **UX rounds** | [ux/](ux/) — two adversarial cycles: TOP-20/TOP-30 directives, quality analyses, antagonist rulings, the copy table |
| **Rewrite plans** | [plans/](plans/) — the three phase plans that took the legacy 1140-line file to the layered package: core rewrite, input/UI, tutorial+rewards |
| **Playtest evidence** | [../playtest/](../playtest/) — scripted drivers and player-eye screen dumps (SMOKE-REPORT, SCREEN/ANTAG/LEG/R2 series) |

## Reading order for newcomers

1. [../README.md](../README.md) — the premise and how to run it.
2. [../PLAYING.md](../PLAYING.md) — play ten ticks.
3. [DESIGN-SPEC.md](DESIGN-SPEC.md) §1–3 — why it looks like this.
4. [METHODS.md](METHODS.md) — how it was built.
5. [PROCESS-RETRO.md](PROCESS-RETRO.md) and [FAILURE-LEDGER.md](FAILURE-LEDGER.md) — what it cost.