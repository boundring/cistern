# CISTERN

**SECTOR 7 SANITATION DIVISION — EMPLOYEE ONBOARDING DOSSIER 7-C**

[![Emacs](https://img.shields.io/badge/Emacs-27.1%2B-7f5ab6)](README.md#run-it)
[![Tests](https://img.shields.io/badge/tests-140%2F140%20batch-2ea043)](docs/METHODS.md#4-the-test-harness)
[![Maps](https://img.shields.io/badge/maps-procedurally%20seeded-8a4fbe)](docs/METHODS.md#3-seeded-determinism)
[![License](https://img.shields.io/badge/license-AGPL--3.0--or--later-39413A)](LICENSE)

You run sanitation for one sector of a megastructure nobody finished
and nobody will: thirty-four by sixteen cells of corridor, vein and
wall. Workers mine ore (◆) for alloy. Their bladders fill as they work.
Wire every fixture (Ω) to a tank (▣) through pipe (─) before the
bladders win — a worker who cannot reach a working fixture breaches,
the breach becomes contamination (▒), contamination spreads, and at
**20 contamination the sector is condemned.**

The whole job in one sentence: **route need to capacity. Capacity you
did not connect is not capacity.**

THE STRUCTURE DOES NOT CARE.

## Proof of life

| What you are plugging into | Where |
|---|---|
| A rendered sector, player's eye | [docs/media/screenshots/](docs/media/screenshots/) |
| A live run, start to condemnation | [docs/media/cistern-demo.gif](docs/media/cistern-demo.gif) |
| The full player guide — controls, stats, terrain, screen reading | [PLAYING.md](PLAYING.md) |

## Run it

```sh
git clone https://github.com/boundring/cistern
emacs -Q -l src/cistern.el
M-x cistern
```

The game opens in the `*cistern*` buffer. `SPC` ticks the clock; the
three-step tutorial walks your first shifts; `C-t` skips it. Day one:
cursor onto a worker, read the inspector; when a tank fills, press `x`
to purge — free, and it pays alloy back. Then expand: pipe (`p`)
outward, a fixture (`t`) far, a tank (`K`) when load grows. Short runs win.

The batch test suite runs headless, no display:

```sh
emacs -Q --batch -l tests/run.el -f cistern-run-all-tests
```

The Sector Record (story engine) reads a bank file if one sits beside
the driver or on your load-path; the shipped example is
[data/banks/example.el](data/banks/example.el). Without a bank the
record stays silent and the game runs fine. The file is your problem.

## Architecture at a glance

Five layers, one state object threaded through every transition.
Dependencies point one way: inward — drivers → adapters → use cases →
domain. The domain imports nothing Emacs-y: no buffers, no windows, no
timers, no faces.

```
┌─ Frameworks & Drivers ─── cistern.el      (buffer, major mode, keymap, timer, command loop)
│
├─ Interface Adapters ───── cistern-view.el  (render projection: state → text/face)
│                           cistern-input.el (mouse events / keys → use-case calls)
│
├─ Use Cases ────────────── cistern-game.el  (game verbs: build/demolish/decon/purge/cursor;
│                                            tick orchestration; tutorial; scoring entry)
│
└─ Domain (pure) ────────── cistern-domain.el (state structs, RNG, grid, tile tables,
                                               procgen, sim rules, connection logic)
```

An external architecture review (hngh research line
*cistern-architecture-review*, 2026-09-08) found this layering
validates clean-architecture doctrine in Emacs Lisp — a testable core
independent of live frames — while noting the boundary is held by
convention, not the compiler. How it was built, the state object, and
the seeded-RNG design are documented in [docs/METHODS.md](docs/METHODS.md).

## Status wall

### Standing

- **Seeded procedural generation** — one integer seed derives the map
  and every child RNG stream; same seed, identical trajectory.
- **Per-worker stats** — FLOW, GRIT, NERVE, ARCHIVE roll 3–18 at the
  gate and stay for life; XP and clearance grow them.
- **Pipe / tank contamination sim** — connection logic, tank load,
  backups, purge economy, spreading contamination tiles.
- **Breach events** — an unserved worker breaches their tile;
  floods, sick workers, decontamination.
- **Condemnation ending** — the death panel: cause, ticks survived,
  relieves served, final score, `PRESS n TO RESTART`.
- **Headless test harness** — 140 entries, one canonical batch runner,
  no display, no wall-clock.

### What it is not

- **Not a package.** No MELPA, no ELPA-ready layout — load from the
  checkout, path-loaded `emacs -Q -l src/cistern.el`.
- **Not graphical.** A single-buffer TUI: text glyphs, faces derived
  from your theme, one buffer for map, inspector and log.
- **Not finished.** v5.0.0-dev under active development; semantics
  may shift between versions.
- **Not persistent.** No save games, no high-score tables, no sound —
  all explicitly deferred ([docs/DESIGN-SPEC.md §6](docs/DESIGN-SPEC.md)).
- **Licensed AGPL-3.0-or-later** ([LICENSE](LICENSE)), matching the
  hngh project ([§ Provenance](#provenance)).

## Documentation map

| Start here | Then | Evidence |
|---|---|---|
| [PLAYING.md](PLAYING.md) — play it | [docs/DESIGN-SPEC.md](docs/DESIGN-SPEC.md) — how it is built | [docs/PROCESS-RETRO.md](docs/PROCESS-RETRO.md) — how it was made |
| [docs/INDEX.md](docs/INDEX.md) — the full shelf | [docs/ROADMAP.md](docs/ROADMAP.md) — what landed when | [docs/FAILURE-LEDGER.md](docs/FAILURE-LEDGER.md) — every run that died |

[docs/METHODS.md](docs/METHODS.md) — the methods and architectural
patterns, for readers who want to understand how this game was created.

## Provenance

This codebase is 100% vibe-coded — written end to end by AI models
(mostly GLM-5.3-flash) under operator direction. The operator retains
all creative control: every design decision, prompt, and accepted
change passes through their hand. Contributions are welcome on the
same terms — issues and patches will be reviewed and shaped by the
operator before they land.

v5.0.0-dev · Requires Emacs 27.1+