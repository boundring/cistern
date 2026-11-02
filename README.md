# CISTERN

**EMPLOYEE ONBOARDING DOSSIER — TWO GENERATIONS, ONE PROJECT**

[![TypeScript](https://img.shields.io/badge/TypeScript-5.9.3-3178c6)](package.json)
[![three.js](https://img.shields.io/badge/three.js-r160%20vendored-8a4fbe)](vendor/three.module.min.js)
[![Tests](https://img.shields.io/badge/tests-124%2F124%20node--test-2ea043)](tests/)
[![License](https://img.shields.io/badge/license-AGPL--3.0--or--later-39413A)](LICENSE)

Two generations of Cistern live in this repository. The **current** generation
is the browser-native HD-2D port: a three.js r160 voxel diorama of the 34x16
starter town, TypeScript 5.9.3 compiled by `tsc` alone — no bundler, no
runtime network fetch, vendored assets. The **previous** generation is the
Emacs Lisp sanitation game, under `legacy/lisp-game/` and the `legacy/lisp-game`
branch.

The port is not a re-imagining of the town. It replays the *same* baked donor
data and the *same* pinned-seed world laws as the donor Godot build: town
template, tile and prop tables, copy tables, townsfolk sim and open-world
relief law are ports, checked against golden vectors baked from the donor.

## Run it

```sh
npm install          # typescript 5.9.3 (dev dependency, the only one)
npm run bake         # vendor/cistern donors -> src/generated/donors.ts
npm run build        # tsc -> out/
npm run typecheck    # tsc --noEmit
python3 -m http.server 8000   # serve the repo root, then open http://127.0.0.1:8000/
```

## Test it

```sh
npm test             # build + node --test tests/  -> 124/124
```

The suite is headless, no display, no wall-clock: golden vectors in
`tests/golden/` (noise, rng, scatter, town, townsfolk, walk, world) are the
donor's own values, baked by the Godot probes in `tools/godot-probe/`.

## Smoke it

```sh
npm run smoke        # build + headless-Chromium acceptance run
```

Requires Node >= 22 (built-in `fetch`/`WebSocket`), python3, and a
Chromium-family browser on PATH (`chromium` or `google-chrome-stable`). The
runner serves the repo root on a loopback port, launches its own isolated
headless Chromium (throwaway profile, CDP `--remote-debugging-port=0`; it never
touches your browser) and drives the page over the DevTools protocol. It
asserts the baked donors against the goldens, the live `window.game.state()`
grid and copy, the intent dispatch surface, the townsfolk transcript, the v3
world state, the NPC pixel probe (a figure must read as shaded 3D, not a flat
quad) and same-origin-only networking. Screenshots land in `out/`.

## How the world law is verified

Parity with the donor is the spine of this build, and it is measured.

- **Noise** — `src/core/noise.ts` is a port of Godot's `FastNoiseLite`
  (simplex-smooth, FBM). The golden is the donor's own samples: 864/864 rows
  match **bit-exactly** under `Math.fround`.
- **World law** — `src/core/world.ts` is a pure function of (grid coords,
  pinned seeds): the domain-warped biome masks, ridged mountain chains,
  terraced plateaus, the tectonic cross-axis uplift, rift lake basins, the
  river valley carve, the tributary channels and the village flat are the
  donor's, ported whole. `stepsAtCell` matches the donor exactly at every
  golden point; the biome and uplift residuals sit at the float32 floor
  (the tectonic-axis `fround` fix took the WBIOME residual from 1.4e-6 to
  1.5e-8).
- **Townsfolk** — `src/core/townsfolk.ts` + `src/core/sim.ts` port the donor
  sim exactly: keyed placement stream, Fisher–Yates order, two-step pacing,
  one shared wander stream in strict tick action order. The 200-tick golden
  transcript must be reproduced byte-identically.

Measurement scripts: `tools/measure.mjs` (residuals against
`tests/golden/world.txt`, exactness and desert census) and `tools/diff-law.mjs`
(blast-radius diff of two world-law builds over the whole footprint).

Two trims are documented, not hidden: the donor's road/rail corridors are
dropped (the probe applies the same trim, so the golden compares like for
like), and the village disc is relocated under the town.

## Generations

| Generation | Surface | Where |
|---|---|---|
| **Web port** (current) | Browser HD-2D voxel diorama, three.js r160, TypeScript | this tree: `src/`, `tools/`, `docs/v3/` |
| **Emacs Lisp** (previous) | Single-buffer TUI: route need to capacity or the sector is condemned | `legacy/lisp-game/` and the `legacy/lisp-game` branch |

The Lisp generation keeps its own README, player guide (`PLAYING.md`),
documentation map and media under `legacy/lisp-game/`; playable with Emacs
27.1+, frozen as history.

## Specification

`docs/v3/` holds the frozen v3 contract set:

| Document | What it fixes |
|---|---|
| [ARCHITECTURE.md](docs/v3/ARCHITECTURE.md) | module map, dependencies, the five v3 commitments |
| [TEST-SPEC.md](docs/v3/TEST-SPEC.md) | the executable test contract: every expected value |
| [REQUIREMENTS-MATRIX.md](docs/v3/REQUIREMENTS-MATRIX.md) | one row per operator ask, with thresholds |
| [WORKING-SESSION-LIST.md](docs/v3/WORKING-SESSION-LIST.md) | the ordered delivery sessions and their owners |
| [LIBRARY-REFERENCE.md](docs/v3/LIBRARY-REFERENCE.md) | the public API surface |

The v3 work plan is tracked in `docs/v3/WORKING-SESSION-LIST.md`; the previous
generation's roadmap lives in `legacy/lisp-game/docs/ROADMAP.md`.

## Provenance

This project is vibe-coded — written end to end by AI agents under operator
direction. The operator retains all creative control: every design decision,
prompt and accepted change passes through their hand. Contributions are
welcome on the same terms; issues and patches are reviewed and shaped by the
operator before they land.

Six modules in `src/core/` were written by a local model rather than by hand,
each under a spec that named the donor file and the expected values, and each
with its own suite in `tests/`:

| Module | Model | Attempts |
|---|---|---|
| `src/core/town.ts` | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | 1 |
| `src/core/townsfolk.ts` | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | 1 |
| `src/core/job-executor.ts` | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | 2 |
| `src/core/sim.ts` | `unsloth/Qwen-AgentWorld-35B-A3B-GGUF` | 3 |
| `src/core/shop-stock.ts` | `unsloth/Qwen-AgentWorld-35B-A3B-GGUF` | 3 |
| `src/core/game-actions.ts` | `unsloth/Qwen-AgentWorld-35B-A3B-GGUF` | 3 |

Every one of them was reviewed before it landed, and the `src/core/town.ts`
and `src/core/townsfolk.ts` changes are pure insertions — nothing shipped was
removed.

Licensed **AGPL-3.0-or-later** ([LICENSE](LICENSE)), matching the hngh project.
