# WORKING-SESSION-LIST — cistern-web v3

Twelve ordered sessions, each small enough for one local model in one sitting.
The canonical ids and their order are fixed:

| # | Session id | Owns |
|---|---|---|
| S01 | `core-noise-port` | `src/core/noise.ts` |
| S02 | `core-world-law` | `src/core/world.ts` |
| S03 | `core-walk-math` | `src/core/walk.ts` |
| S04 | `render-voxel-models` | `src/render/voxel.ts` |
| S05 | `render-figures-rig` | `src/render/figures.ts` |
| S06 | `render-world-terrain` | `src/render/world.ts` (terrain + water) |
| S07 | `render-world-scatter` | `src/render/world.ts` (scatter) |
| S08 | `render-camera` | `src/render/camera.ts` |
| S09 | `render-inspector` | `src/render/inspector.ts` |
| S10 | `integration-game-scene` | `src/types/game.ts`, `src/game.ts`, `src/render/scene.ts`, `src/main.ts` |
| S11 | `smoke-acceptance` | `tools/smoke.mjs` |
| S12 | `delivery-docs` | `docs/v3/**`, README, handoff |

Repo: `/mnt/2tb/@home/bricker/Projects/etc/cistern-web`. TypeScript strict,
`tsc` only, no bundler, three.js r160 vendored, offline at runtime, no
`Math.random`, no `Date.now`, no network fetch. Every session reads the frozen
interfaces in `/home/bricker/Work/sessions/2026-10-29-webgame-v3/CONTRACT.md`
and must not change them.

## Rules that bind every session

1. **The donor is read-only.** Nothing under
   `/mnt/2tb/@home/bricker/Projects/etc/cistern` may be edited, moved or
   written to. Every donor file is opened read-only.
2. **Golden files are donor truth, never hand-written.** They are baked from a
   headless Godot probe run against a scratch project under `/tmp` that holds a
   *copy* of the donor's `.gd` closure. The probe's header comment carries the
   exact regeneration recipe; keep it accurate.
3. **Assert on state, never on pixel goldens.**
4. **The orchestrator commits.** Sessions do not run `git commit`, `git add`,
   `git checkout` or `git stash`. The orchestrator commits with explicit
   pathspecs.
5. **Do not touch `out/`** — it is build output.
6. **Determinism:** integer-only state, pinned seeds, no wall-clock reads.

### Build and test commands

| Command | What it does |
|---|---|
| `npm run typecheck` | `tsc --noEmit -p tsconfig.json` — the whole `src/` tree. |
| `npm run build` | `tsc -p tsconfig.json` → `out/`. Required before any render-side test. |
| `npm run build:core` | `tsc -p tsconfig.core.json` → `out/core/**`, `out/types/**`. |
| `npm test` | `npm run build:core && node --test tests/`. Compiles **only** `src/core/**` and `src/types/**`. |
| `node --test tests/<name>.test.mjs` | one file. Needs `out/` populated first. |
| `npm run smoke` | `npm run build && node tools/smoke.mjs` — the CI-equivalent headless-Chromium run. |

`tsconfig.core.json` includes only `src/core/**/*.ts` and `src/types/**/*.ts`,
so `npm test` does **not** compile `src/render/**`. Sessions S04–S11 must run
`npm run build` before their test file will resolve `../out/render/*.js`.

### The donor probe recipes

**Noise (S01)** — no donor files needed; Godot's `FastNoiseLite` is built in.

```
scratch=/tmp/gp-noise
mkdir -p "$scratch"
printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
cp tools/godot-probe/probe_noise.gd "$scratch/"
godot --headless --path "$scratch" --import
godot --headless --path "$scratch" -s probe_noise.gd > tests/golden/noise.txt
```

**World law (S02)** — an eight-file donor closure, copied into the scratch
project, never edited in place:

```
scratch=/tmp/gp-world
mkdir -p "$scratch/scripts/view" "$scratch/scripts/world"
printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
cp <donor>/godot/scripts/view/{tile_table,scatter_hash,slab_def,prefab_factory,slab_assembler,hd2d_heightmap,world_heightmap}.gd "$scratch/scripts/view/"
cp <donor>/godot/scripts/world/world_level.gd "$scratch/scripts/world/"
cp tools/godot-probe/probe_world.gd "$scratch/"
godot --headless --path "$scratch" --import
godot --headless --path "$scratch" -s probe_world.gd > tests/golden/world.txt
```

The closure is eight `.gd` files: `world_level.gd` names `PrefabFactory`, which
names `SlabAssembler`; every class resolves through `class_name`, and nothing
in the closure reads `content/`.

`godot` 4.7.2 is installed at `/usr/bin/godot`.

---

## S01 — `core-noise-port`

**Scope.** Creates `src/core/noise.ts`: a port of Godot's `FastNoiseLite`
restricted to the path the donor's world law uses — `TYPE_SIMPLEX_SMOOTH`
(OpenSimplex2S), `FRACTAL_FBM`, lacunarity 2.0, gain 0.5, weighted strength 0,
no offset, no domain warp. Every float32 operation is reproduced with
`Math.fround` at the same point the engine does it, so the port is bit-exact
against the donor probe. It must not own the world law, the constants, or any
renderer. Also owns `tests/noise.test.mjs`, `tests/golden/noise.txt` and
`tools/godot-probe/probe_noise.gd`.

**Inputs.** `src/types/three.d.ts` is not needed here. Read
`src/core/terrain.ts` for nothing (the noise module is seed-driven) — read it
only to learn `SCATTER_SEED`'s provenance. The donor's sibling-noise table is
`godot/scripts/view/world_heightmap.gd:73-78`: salts 242–247 over
`TileTable.SCATTER_SEED`, frequencies `1/45, 1/64, 1/52, 1/26, 1/30, 1/20`,
octaves `2, 2, 2, 3, 2, 4`, seed `abs(SCATTER_SEED + salt) % 2147483647`. The
upstream header the port mirrors is Godot's
`thirdparty/misc/FastNoiseLite.h` (v1.1.0, `namespace fastnoiselite`).
Depends on the golden `tests/golden/noise.txt` and the probe
`tools/godot-probe/probe_noise.gd`.

**Test command.**

```
npm run typecheck
npm run build:core && node --test tests/noise.test.mjs
npm test
```

Golden regeneration (donor read-only, scratch copy):

```
godot --headless --path /tmp/gp-noise --import
godot --headless --path /tmp/gp-noise -s probe_noise.gd > tests/golden/noise.txt
```

**Done when.** The canonical cases pass:
`ported FastNoiseLite matches the donor probe bit-exact`,
`the port is deterministic across repeated calls`,
`octave count changes the value`,
`seed changes the value`. All 864 golden rows (6 configs x a 12x12 lattice,
`x = 0.3 + 1.7i`, `y = -1.1 + 2.3j`) match under `Math.fround`, max absolute
error 0. The golden is printed at full float32 precision, not truncated.

**Note (correction of an earlier report — read this before touching the port).**
The ported FastNoiseLite **is** bit-exact against the donor probe; there is no
float32 drift to fix, and no defect lives in S01. An earlier report of a
3e-7 drift and a failing bit-exactness assertion was an artefact of the
donor probe's *printing*: it emitted `String.num(v, 9)` — nine **decimals**,
not nine significant digits — which truncated small magnitudes and so
destroyed the donor's float32 bits inside `tests/golden/noise.txt`.
`tools/godot-probe/probe_noise.gd` now prints `String.num_scientific(v)`, the
shortest round-tripping form, and `tests/golden/noise.txt` was regenerated
from a scratch Godot project at full precision (e.g.
`NOISE WARP 0.3 -1.1 -0.031104128807783127`). Verified state: 864/864 rows
bit-identical, max absolute error 0, `npm test` 37/37 green.

The consequence for the plan: **the `biomeWeights` tolerance cannot be
tightened on the strength of an S01 fix**, because the residual that limits it
is not noise drift. It is the donor's single-precision storage of the tectonic
axis vectors, and it belongs to S02 — see that session's note.

---

## S02 — `core-world-law`

**Scope.** Creates `src/core/world.ts`: the donor's
`godot/scripts/view/world_heightmap.gd` (iteration 3) ported **whole** as a
pure function of grid coordinates — biome weight masks, macro composition
(hills/plains, ridged chains, terraced plateaus, rim ring, rift basins),
tectonic cross-axis uplift, the global water table, the river valley carve,
the tributary channel carve, the village flat and the parent's ring-hamlet
flat. Two documented trims: no engineered corridors, and the village disc
relocated to `VILLAGE_X`/`VILLAGE_Y`. The two web-side extensions (the ocean
band, the desert band) and the ordered `kindAt` classification live **only**
in the cell-level helpers, never inside `stepsAt`. Also owns
`tests/world.test.mjs`, `tests/golden/world.txt` and
`tools/godot-probe/probe_world.gd`.

**Inputs.** `src/core/terrain.ts` — import, never redefine (`SUB`, `VOXEL`,
`TABLE_STEPS`, `MAX_STEPS`, `WORLD_W`, `WORLD_H`, `MARGIN_X`, `MARGIN_Z`,
`VILLAGE_X`, `VILLAGE_Y`). `src/core/noise.ts` — S01's output, consumed as the
six sibling noises. `src/core/scatter.ts` for `SCATTER_SEED`. Donor files, read
only: `godot/scripts/view/world_heightmap.gd` (the law),
`godot/scripts/view/hd2d_heightmap.gd` (the parent: `SUB`, `VOXEL`,
`MAX_STEPS`, `MARGIN_FRAC`, `TOWN_FLAT_RADIUS`, `TOWN_FLAT_CORE`,
`town_center_for`), `godot/scripts/world/world_level.gd` (`river_x`,
`river_halfw`, `channels()`, `VILLAGE`, `corridors()` — the last is dropped),
`godot/scripts/view/tile_table.gd` (`SCATTER_SEED`),
`godot/scripts/view/scatter_hash.gd`. Depends on `tests/golden/world.txt` and
the probe `tools/godot-probe/probe_world.gd`.

**Test command.**

```
npm run typecheck
npm run build:core && node --test tests/world.test.mjs
npm test
```

Golden regeneration (donor read-only, eight-file scratch closure):

```
godot --headless --path /tmp/gp-world --import
godot --headless --path /tmp/gp-world -s probe_world.gd > tests/golden/world.txt
```

**Done when.** The canonical cases pass:
`stepsAtCell matches the donor EXACTLY at every golden point` (all 40 `WSTEP`
rows, integer relief, exact equality),
`biomeWeights matches the donor within 1e-5`,
`tectonicUplift matches the donor within 1e-6`,
`warpSample matches the donor warp noise within 1e-6`,
`tableHeight matches the donor water table`,
`river functions are the donor's own curves`,
`web extension: the ocean band renders below the water table`,
`web extension: classification is deterministic and ordered`,
`villageHeight is the donor's clamped village base`,
`the law is a pure function of the grid`,
`the playable grid is 4.00x the authored town`.

**Note — operator ruling still required on the ocean band, but the asymmetry
named in the brief is no longer in the tree.** `src/core/world.ts:340-345`
currently reads

```
gx <= -MARGIN_X + 1 || gx >= WORLD_W + MARGIN_X - 2 ||
gy <= -MARGIN_Z + 1 || gy >= WORLD_H + MARGIN_Z - 2
```

— a symmetric two-cell band on every side. The earlier `-MARGIN_X+2` /
`-MARGIN_Z+2` form gave three cells on the west and south against two on the
east and north; that asymmetry was removed by an orchestrator edit, not by a
ruling. Two things still need an operator ruling:

1. **Mechanism.** `CONTRACT.md` describes the ocean as "cells whose
   `edge_norm` (the donor's own formula) is at the footprint edge sink below
   the water table". The implementation uses margin arithmetic instead, and
   the two are not the same rule.
2. **Width.** Two cells per side as implemented, or the contract's `edge_norm`
   formulation.

No golden pins the band. The only coverage is the four-corner check in
`tests/world.test.mjs` (`web extension: the ocean band renders below the water
table`), which passes under any band width of two or three cells, so the
current green suite does not settle it either way. Until the ruling lands, the
band is unpinned.

**Note — the `biomeWeights` residual is single-precision donor storage, not
port drift.** The donor keeps its tectonic axis in a `Vector2` (single
precision: `0.6` is stored as `0.6000000238418579`, `0.8` as
`0.800000011920929`) and returns its weights in a `Vector3`; the web port
computes in JS doubles. The domain warp then multiplies a noise sample by 34
and the smoothstep derivative reaches 4.2, so that single-precision storage
lands as ~1.4e-6 on a 0..1 weight. Measured against the golden's 20 `WBIOME`
rows: **1.4009e-6** worst residual with double axes, **1.5158e-8** with the
axis constants passed through `Math.fround` — a 92x collapse, confirming the
residual is donor-side storage. S02's actionable item is to fround the axis
constants in `biomeWeights`/`tectonicUplift`, after which the `biomeWeights`
tolerance can be tightened from 1e-5 toward 1e-7. The integer relief
(`stepsAt`) is already exact and is the real contract.

---

## S03 — `core-walk-math`

**Scope.** Creates `src/core/walk.ts`: the walk-phase and idle-pose math, and
nothing else. `STRIDE = 1` world unit per full walk cycle; `walkPhase(d) =
d * TAU / STRIDE`; `walkPose(phase)` yields `swing = sin(phase)`,
`bob = |sin(phase)|`; `idlePose(elapsedSeconds)` is a slow deterministic bob
(`IDLE_HZ = 1.2`, `IDLE_AMP = 0.02`) with `swing = 0`. It must not own the
figure rig, the renderer or the game layer. Also owns `tests/walk.test.mjs`
and `tests/golden/walk.txt`.

**Inputs.** No donor file: the walk math is a web-side design, not a donor
port, so the golden is a *recorded regression vector* of the closed-form
identities, not a Godot probe. Read `CONTRACT.md`'s "Frozen: slice C" block
for the exact signatures. Depends on `tests/golden/walk.txt` (12 `WALK`
rows: distance, phase, swing, bob).

**Test command.**

```
npm run typecheck
npm run build:core && node --test tests/walk.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`walkPhase is distance * TAU / STRIDE`,
`walkPose derives swing and bob from the phase`,
`idlePose is a slow deterministic bob`,
`idlePose stays inside IDLE_AMP`,
`the walk phase golden matches the recorded vector`. All 12 golden rows match
within 1e-12.

**Note.** There is no `tools/godot-probe/probe_walk.gd`; the walk golden was
never produced by a donor probe and must not be described as donor truth. It
is a regression vector for the web's own closed-form identities.

---

## S04 — `render-voxel-models`

**Scope.** Creates `src/render/voxel.ts`: the small box-geometry model
builders for the open-world scatter. `mergeBoxes(boxes)` emits six quads per
box (36 vertices, non-indexed) into one `BufferGeometry` carrying a per-vertex
`color` attribute with the structural shading law — top face at the base
colour, sides at `0.78`, bottom at `0.62`. Six models: `broadleafModel` (trunk
+ three canopy boxes), `pineModel` (trunk + three stacked boxes),
`boulderModel` (two or three offset boxes), and three item models
(`crystalModel`, `berryModel`, `branchModel`). It must not own the world
renderer, the figure rig or the game layer. Also owns `tests/voxel.test.mjs`.

**Inputs.** `src/core/terrain.ts` for `VOXEL` (the world-units scale).
`src/types/three.d.ts` for the three.js surface (`BoxGeometry`,
`BufferGeometry`, `Float32BufferAttribute`). The donor's shading discipline is
`godot/scripts/view/slab_assembler.gd` — read-only, as a reference for the
per-face tint idea; the **numeric** shading law used here is the archived Rust
HD lane's (top 1.0, side 0.78, bottom 0.62), not the donor's `FACE_TINTS`
table. Depends on nothing from S01–S03.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/voxel.test.mjs
npm test
```

(`npm run build` first: `npm test` compiles only `src/core/**`.)

**Done when.** The canonical cases pass:
`mergeBoxes emits six faces per box`,
`mergeBoxes shades sides and bottom darker than the top`,
`broadleafModel is trunk plus three canopy boxes`,
`pineModel is trunk plus three stacked boxes`,
`boulderModel is two or three offset boxes`,
`item models are small`.

---

## S05 — `render-figures-rig`

**Scope.** Creates `src/render/figures.ts`: the animated voxel figures that
replace the v2 flat billboards. The rig is a box hierarchy
`root -> body (bob) -> { torso, head, armL, armR, legL, legR }` with each limb
pivoting at its top, so a pivot rotation swings the limb. Frozen part sizes:
legs `0.16 x 0.30`, torso `0.34 x 0.32 x 0.22`, head `0.22` cube, arms
`0.12 x 0.30`. Colours: the donor billboard palette for the garment
(`player [0.25, 0.55, 0.95]`, `townsfolk [0.4, 0.78, 0.62]`), darker boots, a
skin tone for the head, and a per-figure tint from `ScatterHash` keyed by the
figure id. `update()` advances the walk cycle from travelled distance, idles
the stationary, and turns the figure to face its movement. It must not own
the walk math, the scatter hash, the terrain law, the world renderer or the
camera. Also owns `tests/figures.test.mjs`.

**Inputs.** `src/core/walk.ts` — S03's output (`walkPhase`, `walkPose`,
`idlePose`). `src/core/scatter.ts` — `ScatterHash`, for the deterministic
per-figure tint. `src/types/three.d.ts`. The donor palette, read-only:
`godot/scripts/view/billboard_entities.gd` — `_color_for_kind` gives `player`
`Color(0.25, 0.55, 0.95)`, `townsfolk` `Color(0.40, 0.78, 0.62)`. The `villager`
garment colour is a web-side addition (the donor has no villager kind). No
golden file; the assertions are structural.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/figures.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`a figure is a box hierarchy root>body>limbs`,
`limb pivots sit at the joint`,
`figure height matches the frozen part sizes`,
`the per-figure tint is deterministic in the figure id`,
`the garment palette matches the donor billboard palette`,
`spawn adds a figure and moveTo retargets it`,
`positionOf returns the figure's world position`,
`update advances the walk cycle with travelled distance`. The smoke's NPC
pixel probe (`distinct >= 5`, `variance >= 500`) must pass against a rendered
townsfolk — that probe is the acceptance that the figure reads as shaded 3D
geometry and not a flat quad.

---

## S06 — `render-world-terrain`

**Scope.** Creates the terrain and water half of `src/render/world.ts`: one
merged, vertex-coloured `BufferGeometry` over the whole 136x64 vista
footprint (top face per cell, side faces only where the neighbour is lower),
with cells inside the authored town footprint skipped and the town edge
skirted down to the neighbouring terrain height; vertex colours follow
`TERRAIN_COLOR` and the donor's baked lighting law
(`TERRAIN_AMBIENT`, `TERRAIN_DIRECTIONAL`, `TERRAIN_SUN_DIR`), side faces
multiplied by `TERRAIN_SIDE_SHADE`. Plus one translucent water plane at
`tableHeight()` spanning well past the footprint, animated deterministically
from `elapsedSeconds`. Structural relief only — no per-cell surface noise. It
must not own the scatter (that is S07), the terrain law, or the game layer.
Also owns the terrain and water cases of `tests/worldrender.test.mjs`.

**Inputs.** `src/core/terrain.ts` (all the constants above).
`src/core/world.ts` — S02's output, consumed through the `TerrainField`
shape (`stepsAtCell`, `kindAt`, `tableHeight`, `villageHeight`).
`src/types/three.d.ts`. Depends on nothing from S04 except that the water
plane and terrain mesh are drawn in the same group.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/worldrender.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`the terrain mesh covers the whole footprint`,
`cells inside the town footprint are skipped`,
`the town edge gets a skirt`,
`vertex colours follow TERRAIN_COLOR and the baked lighting law`,
`side faces are shaded by TERRAIN_SIDE_SHADE`,
`water sits at tableHeight() and spans past the footprint`,
`water animation is deterministic in elapsedSeconds`.

**Ordering.** S06 and S07 both edit `src/render/world.ts` and
`tests/worldrender.test.mjs`. They run **in sequence** — S06 first, S07
second — and each keeps its own region of both files.

---

## S07 — `render-world-scatter`

**Scope.** Adds the scatter half of `src/render/world.ts`: the donor's
hash-scatter law (`src/core/scatter.ts` `ScatterHash`) with a distinct floor
identity per class (trees, rocks, items), densities per biome band, and
variants chosen by `ScatterHash.variant`. Trees, rocks and items are the
small voxel models from S04 (broadleaf, pine, boulder, and the three item
models), drawn as one `InstancedMesh` per model kind with a per-instance
deterministic tint. It must not own the terrain or water mesh (S06), the
voxel models themselves (S04), or the terrain law. Also owns the scatter
cases of `tests/worldrender.test.mjs`.

**Inputs.** `src/core/scatter.ts` — `ScatterHash`, `presence`, `variant`,
`jitter`. `src/core/world.ts` — S02's output, for `kindAt` (the biome band
per cell). `src/render/voxel.ts` — S04's output, the model builders.
`src/core/terrain.ts`. Depends on S06 having landed the terrain mesh in the
same file.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/worldrender.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`scatter counts follow the donor hash-scatter law`,
`trees rocks and items are instanced voxel models`. The smoke's state
assertions must hold: `counts.trees > 0`, `counts.rocks > 0`,
`counts.items > 0`.

---

## S08 — `render-camera`

**Scope.** Keeps and finishes `src/render/camera.ts`: `OrbitCamera`, with
`DIST_MAX` raised to 140 and `DIST_MIN` dropped to 3 so the larger world can
be framed and a single figure can be closed up on; pitch clamped to
`[0.18, 1.35]`; `setTarget(v)` moves the orbit focus in place and `target`
is readable; `apply()` points the camera at the target and keeps
`matrixWorld` fresh for the raycaster. It must not own picking, the world or
the game layer. Also owns `tests/camera.test.mjs`.

**Inputs.** `src/types/three.d.ts` (`PerspectiveCamera`, `Vector3`,
`MathUtils.clamp`). `CONTRACT.md`'s "Frozen: slice E" block for the exact
signatures. No golden file; the assertions are closed-form.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/camera.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`distance is clamped to the allowed range`,
`pitch is clamped`,
`setTarget moves the orbit focus`,
`apply points the camera at the target`. The smoke must be able to frame the
world wide (`zoom distance 120`) and close (`zoom distance 4`) without the
close camera clipping geometry.

---

## S09 — `render-inspector`

**Scope.** Keeps and finishes `src/render/inspector.ts`: `Inspector.show(sel)`
fills the panel slots, including the two new rows `[data-slot="terrain"]` and
`[data-slot="figure"]`. The selection carries optional `terrain`
(`kind`, `steps`, `height`, `water`) and `figure` (`id`, `kind`) fields; the
inspector reads them **defensively** — they may be absent, and then the row
renders an empty string. It must not own the markup (S10) or the selection
type (`src/types/game.ts`, S10). Also owns `tests/inspector.test.mjs`.

**Inputs.** `src/types/game.ts` — the `Selection` shape, owned by S10.
`src/types/donors.ts` — the copy table and tile sprites. `index.html` — the
panel markup with the two slot names, owned by S10. No golden file; the
assertions are on rendered text.

**Test command.**

```
npm run typecheck
npm run build
node --test tests/inspector.test.mjs
npm test
```

**Done when.** The canonical cases pass:
`the terrain row renders kind steps and height`,
`the terrain row renders the water case`,
`the figure row renders kind and id`,
`absent optional fields render empty strings`.

---

## S10 — `integration-game-scene`

**Scope.** Owns the four integration files: `src/types/game.ts` (the
`Selection`, `GameState`, `Intent`, `PixelProbe` contract behind
`window.game`), `src/game.ts` (the single owner of mutable app state: builds
the world, the scene, the camera and the inspector; dispatches intents;
publishes `window.game.dispatch(intent)` and `window.game.state()`),
`src/render/scene.ts` (the authored town's HD-2D diorama — one `InstancedMesh`
per tile kind plus deco props, theme background and fog, pointer picking,
`probePixels`) and `src/main.ts` (wiring only: build the town, construct
`Game`, publish `window.game` before the first frame, resize listener,
animation loop, ambient tick). Also adds the two inspector row slots to
`index.html`. It must not own the law, the rig, the renderer or the camera.

**Inputs.** Everything upstream: `src/core/{town,copy,sim,townsfolk,world,scatter,terrain}.js`,
`src/render/{scene,camera,inspector,world,figures}.js`,
`src/generated/donors.js`, `src/types/donors.ts`. The `window.game` test
surface is the agent contract: `dispatch(intent)` and `state()` must exist
and agree with each other.

**Test command.**

```
npm run typecheck
npm run build
npm test
npm run smoke
```

**Done when.** The smoke's state assertions hold — `state.world` reports
`playableW 68`, `playableH 32`, `footprintW 136`, `footprintH 64`,
`villageX 34`, `villageY 16`, `townX 17`, `townY 8`, `townW 34`,
`townH 16`; `counts.figures >= counts.townsfolk + 1`; `counts.trees > 0`,
`counts.rocks > 0`, `counts.items > 0`; `dispatch(inspect)` returns the
golden tile with non-empty copy text and `state().selection.text` equals it.
The two inspector rows (`terrain`, `figure`) are present in the markup and
populated from the selection.

---

## S11 — `smoke-acceptance`

**Scope.** Owns `tools/smoke.mjs`: the CI-equivalent headless-Chromium run
over CDP. Node-side structural and golden cross-checks on the baked donors;
serve the repo root; load the page; assert the `window.game` test surface;
capture both viewports (1280x800 and 375x667); take the three deliverable
screenshots (`v3-default`, `v3-wide`, `v3-close`); and enforce that every
network request is same-origin and that the game still plays with the NIC
emulated offline. It must not own game behaviour — it only observes the
running page.

**Inputs.** `src/generated/donors.js` (the baked donors),
`tests/golden/{town,rng}.txt` (the node-side cross-checks),
`index.html` and `out/` (the served page). The NPC pixel probe reads
`window.game.entityScreenPos(id)` and `window.game.probePixels(x, y, w, h)`
from S10.

**Test command.**

```
npm run smoke
```

**Done when.** The whole smoke run exits zero. Its named assertions include:
`probe.fig.samples > 0`, `probe.fig.distinct >= 5`,
`probe.fig.variance >= 500`; `state.counts.figures >= state.counts.townsfolk + 1`;
`state.counts.trees > 0`, `state.counts.rocks > 0`, `state.counts.items > 0`;
the ten `state.world.*` numbers above; both viewport screenshots written and
not blank; the three deliverable screenshots; every request same-origin; the
game playable offline.

---

## S12 — `delivery-docs`

**Scope.** Owns the delivery surface: `docs/v3/**` (architecture, skeleton
tree, test spec, this session list, the library/reference appendix and the
requirements matrix), the repository `README.md` (run instructions, agent
test-surface contract, provenance table), and the session handoff at
`/home/bricker/Work/sessions/2026-10-29-webgame-v3/handoff/2026-10-29-webgame-v3.md`.
It must not touch implementation or test code.

**Inputs.** `CONTRACT.md` and `CHARTER.md`. The finished tree under `src/`,
`tests/`, `tools/`. The provenance rows the build must carry: three.js r160
(MIT), Cistern slabs and tiles (CC0 or operator-authored), the FastNoiseLite
port (ported, not copied).

**Test command.**

```
npm run typecheck
npm test
npm run smoke
```

**Done when.** The README's run instructions work from a clean checkout;
the provenance table names every vendored asset and its licence; the handoff
records Status, what is done, what is *not* verified, and the next concrete
action; the six planning artifacts under `docs/v3/` are consistent with the
code they describe.
