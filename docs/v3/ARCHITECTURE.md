# cistern-web v3 — Architecture

## 1. Scope

cistern-web v3 is the third build of the Cistern HD-2D web town. The operator's
verdict on v2 was blunt: *flat mint quads are not townsfolk; the flat plane is
not the world*. v3 answers that with five commitments:

1. **Animated 3D voxel models for the player and every NPC.** The player, the
   ambient townsfolk and the world-side villagers are box-geometry figures with
   a procedural walk cycle and an idle bob. No animation files, no skinning.
2. **Voxel items.** Scatter props (trees, rocks, small items) are built from
   boxes and drawn as instanced voxel models, not billboards or sprites.
3. **A ~4x larger open world, ported from the donor's deterministic terrain
   law.** The playable grid grows from the authored 34x16 town to 68x32 cells;
   the vista footprint (playable grid plus the donor's margin ring) is 136x64.
   The relief law is the donor's own `godot/scripts/view/world_heightmap.gd`,
   ported whole.
4. **A detailed environment.** Biome-banded scatter, per-face donor-palette
   shading, a global water table with river and lake basins, and a
   deterministic water surface.
5. **Camera and inspector coverage.** The camera frames the larger world and
   can close up on a single figure; the inspector reports the terrain kind and
   the figure standing on the selected cell.

The frozen interfaces live in
`/home/bricker/Work/sessions/2026-10-29-webgame-v3/CONTRACT.md`; the mission
and its constraints live in
`/home/bricker/Work/sessions/2026-10-29-webgame-v3/CHARTER.md`. Every signature
in this document is quoted from those files and from the source it describes;
where the two disagree, section 8 says so rather than choosing silently.

Non-goals for v3: no roads, no rail, no second settlement, no new noise
algorithm, no post-processing, no runtime network.

## 2. Module map

Slice owners are the v3 delivery slices: A (noise port), B (world law),
C (walk math + figures), D (world renderer), E (camera + inspector),
integration (the orchestrator's own files), plus the pre-existing donor
scatter port and the frozen constants file.

| Path | Slice | Responsibility | Upstream dependency | Downstream consumers |
|---|---|---|---|---|
| `src/core/terrain.ts` | frozen constants | Pinned spec and vocabulary: grid dims, margins, village/town placement, terrain kinds, palette, lighting law | none | `core/world`, `render/world`, `game`, `types/game` |
| `src/core/noise.ts` | A | `FastNoiseLite` port of Godot's engine (simplex smooth, FBM) with float32 semantics | none | `core/world` |
| `src/core/scatter.ts` | donor hash-scatter | Per-cell deterministic RNG (`ScatterHash`), floor identities, `SCATTER_SEED` | `core/rng` | `core/world`, `render/figures`, `render/world`, `render/scene`, `game` |
| `src/core/walk.ts` | C | Walk-phase and idle-pose math: phase from distance, swing/bob drivers | none | `render/figures` |
| `src/core/world.ts` | B | The open-world relief law: biome weights, macro composition, tectonic uplift, water table, river and channel carves, village and town flats, cell classification | `core/noise`, `core/terrain`, `core/scatter` | `game` (via `WorldHeightmap`), `render/world` (via the `TerrainField` shape) |
| `src/render/voxel.ts` | D | Box-geometry model builders (broadleaf, pine, boulder, crystal, berries, branch) and the merged vertex-coloured geometry they share | three r160 | `render/world` |
| `src/render/world.ts` | D | Footprint terrain mesh, water plane, hash-scattered instanced props | three r160, `core/terrain`, `core/scatter`, `render/voxel` | `game` |
| `src/render/figures.ts` | C | Animated voxel figures: rig, palette, walk/idle/facing, spawn/move/remove | three r160, `core/scatter`, `core/walk` | `game` |
| `src/render/camera.ts` | E | `OrbitCamera`: yaw/pitch/distance clamps, in-place target, `apply()` | three r160 | `game` |
| `src/render/inspector.ts` | E | Fills the panel slots from a `Selection`, including the optional terrain and figure rows | `types/donors`, `types/game` | `game` |
| `src/render/scene.ts` | integration | The authored town's HD-2D diorama: slab instances, deco props, theme, picking, `probePixels` | three r160, `types/donors`, `core/town`, `core/slab`, `core/scatter`, `types/game` | `game` |
| `src/types/game.ts` | integration | The `window.game` contract: `Selection`, `GameState`, `Intent`, `PixelProbe` | `core/terrain` | `game`, `render/inspector`, `render/scene`, `main` |
| `src/game.ts` | integration | Single owner of mutable app state: builds world, scene, camera, inspector; intent dispatch; `window.game` surface | three r160, `core/{town,copy,sim,world,scatter,terrain}`, `render/{scene,camera,inspector,world,figures}`, `types/game` | `main` |
| `src/main.ts` | integration | Wiring only: build the town, construct `Game`, publish `window.game`, resize, animation loop, ambient tick | `generated/donors`, `core/town`, `game` | the browser |
| `tools/smoke.mjs` | smoke | Headless-Chromium acceptance over CDP: viewports, state assertions, NPC pixel probe, screenshots, offline check | node >= 22, the built `out/` | CI-equivalent run |
| `tools/godot-probe/probe_noise.gd` | donor probe | Emits the donor's six sibling noise samples for the golden | donor GDScript closure | `tests/golden/noise.txt` |
| `tools/godot-probe/probe_world.gd` | donor probe | Emits the donor's law (with the same two trims) for the golden | donor GDScript closure | `tests/golden/world.txt` |
| `tests/noise.test.mjs` | A | Port-vs-donor noise assertions | `out/core/noise.js`, `tests/golden/noise.txt` | `npm test` |
| `tests/world.test.mjs` | B | Law-vs-donor assertions, extensions, purity | `out/core/world.js`, `tests/golden/world.txt` | `npm test` |
| `tests/walk.test.mjs` | C | Walk-phase identities and the walk golden | `out/core/walk.js`, `tests/golden/walk.txt` | `npm test` |
| `tests/figures.test.mjs` | C | Rig, palette and spawn/move/update assertions | `out/render/figures.js` | `npm test` |
| `tests/voxel.test.mjs` | D | Box merge and model-shape assertions | `out/render/voxel.js` | `npm test` |
| `tests/worldrender.test.mjs` | D | Terrain mesh, water and scatter-count assertions | `out/render/world.js` | `npm test` |
| `tests/camera.test.mjs` | E | Clamp and target assertions | `out/render/camera.js` | `npm test` |
| `tests/inspector.test.mjs` | E | Slot-filling assertions | `out/render/inspector.js` | `npm test` |

Dependency graph, in arrow form (build order, then the render chain):

```
core/terrain -> core/noise -> core/world -> render/world
core/walk    -> render/figures
core/scatter -> render/world + render/figures
render/*     -> render/scene -> game -> main
```

Strictly, `core/terrain` and `core/noise` are both leaves (neither imports the
other); `core/world` is the first module that consumes them, and it imports
both plus `core/scatter`.

Layering rule:

- `core/*` is pure and headless. No `three` import, no DOM, no `window`. Every
  module in `src/core/` is importable by a plain node test with no browser.
- `render/*` owns all three.js. Geometry, materials, meshes, cameras and the
  WebGL readback live here and nowhere else.
- `game.ts` is the only owner of mutable application state: the selection, the
  figure-to-cell map, the sim, the world, the scene, the camera, the
  inspector. Nothing else in the tree holds state that outlives a call.
- `main.ts` only wires: construct, publish, resize, loop, tick. It holds no
  state of its own beyond the DOM handles it grabs.

## 3. Voxel-figure rig design

Hierarchy, one group per joint:

```
root                (position: cell centre on the ground, rotation.y = facing)
└── body            (position.y = bob; the whole figure's vertical bounce)
    ├── torso       (0.34 x 0.32 x 0.22)
    ├── head        (0.22 cube)
    ├── armL/armR   (pivot groups at the shoulder)
    └── legL/legR   (pivot groups at the hip)
```

Each limb is a pivot `THREE.Group` positioned at the joint, with the box mesh
added as a child offset by half its height below the pivot
(`mesh.position.y = -size[1] / 2`). Rotating the pivot therefore swings the
limb about the joint instead of orbiting it around the limb's middle. The
torso and head are plain meshes positioned from the leg height upward.

Frozen part sizes (world units):

| Part | Size |
|---|---|
| Legs | 0.16 x 0.30 x 0.16 |
| Torso | 0.34 x 0.32 x 0.22 |
| Head | 0.22 cube |
| Arms | 0.12 x 0.30 x 0.12 |
| Total height | 0.30 + 0.32 + 0.22 = 0.84 |

The contract describes a figure as "~0.75 tall"; the frozen sizes sum to 0.84.
The sizes are the frozen part, so the number stands (see section 8).

Palette (donor billboard palette, plus the world-side villager):

| Role | Colour |
|---|---|
| Player garment | `[0.25, 0.55, 0.95]` (donor `billboard_entities.gd`) |
| Townsfolk garment | `[0.4, 0.78, 0.62]` (donor `billboard_entities.gd`) |
| Villager garment | `[0.8, 0.72, 0.45]` (web-side idle figure) |
| Boots / legs | garment x 0.35 |
| Skin (head) | `[0.85, 0.68, 0.52]`, tinted with the figure |

Per-figure deterministic tint: `ScatterHash` with floor identity 7, queried as
`jitter(id, 0)`, yields a scalar in `1 + j.x * 0.08` — a +/-4% lightness shift
keyed by the figure id. The same id always yields the same tint, on any
machine, in any frame.

Per-vertex face shading: each box carries its own vertex colours on an unlit
`MeshBasicMaterial({ vertexColors: true })`. The top face is the base colour,
the four side faces are 0.78x the base, and the bottom face is 0.62x. The same
law applies to the scatter voxel models in `render/voxel.ts`. No lights, no
shadows, no post-processing: form is carried entirely by baked vertex colour.

Composition of the figure API:

- `spawn(id, kind, x, y, ground)` builds the rig, applies the palette and the
  id-keyed tint, places the root at `x = cell x`, `z = -cell y`, `y = ground`,
  and registers it under `id`. Spawning an existing id removes the old one
  first.
- `moveTo(id, x, y, ground)` records a new target cell. If a step is already
  in flight, the move is re-targeted from the current interpolated position
  (never a jump). The step is interpolated over `stepDurationMs` (default 400
  ms; the game passes 400).
- `update(elapsedMs, camera)` runs per frame. A figure with a pending move
  interpolates position and ground height, drives the limbs from
  `walkPose(walkPhase(travelledDistance))`, and turns to face the movement
  direction by the shortest signed angular difference. A figure with no pending
  move idles (`idlePose`) and faces the camera around world up — the donor's
  billboard law.
- `positionOf(id)` returns a clone of the root's world position (camera focus
  and pixel probes read it) or null when the id is unknown.
- `remove(id)` detaches the root and drops the entry.
- `count()` reports the live figure count.

What "reads as a figure, not a flat quad" means operationally: a framed figure's
screen region must show **at least 5 distinct colours** and a **luminance
variance of at least 500**, measured against a same-size ground-only baseline
taken beside it. A flat billboard over ground yields 2-3 distinct colours and
low variance; a shaded 3D voxel figure yields many more. The shipped smoke
probes a feet-anchored box around the figure and a ground box 24 px to the
side, and fails the build if the figure box falls short. (Calibration in the
smoke: figure-region variance ~1542 against a same-size ground baseline of
~168, so 500 sits at roughly 3x the baseline and about a third of the figure
region's own variance. The probe box the smoke currently uses is 32x48 pixels
— an earlier draft used 48x72 — so the region size is the smoke's, not the
contract's.)

## 4. Terrain-port boundary

The line is: **the donor's law is ported whole and verbatim; the web's
extensions are applied on top of it, never inside it.** `stepsAt` in
`src/core/world.ts` is the donor's `steps_at` with two documented trims and
nothing else. The web-only behaviour lives in the cell-level helpers
(`stepsAtCell`, `kindAt`), so the donor's own function stays comparable
point-for-point.

### The law (ported whole)

- **Domain-warped biome weight masks.** `biomeWeights(fx, fz)` samples the warp
  noise twice (at `(fx, fz)` and `(fx + 91.3, fz - 47.7)`), offsets the sample
  point by `34 * w1` / `34 * w2`, and reads the mountain and plateau noises in
  an anisotropic frame aligned to the tectonic axis. Weights: mountain
  `smoothstep(0.52, 0.88, m01)`, plateau `smoothstep(0.58, 0.90, p01) *
  (1 - wM)`, both damped near the village by `smoothstep(10, 30, dv)`, rim
  `smoothstep(0.66, 1.02, edgeNorm)`.
- **Macro composition.** Hills/plains `3 + h01 * 6 + uplift`; ridged chains
  `10 + r*r*24` (10..34 steps); terraced plateaus `7 + t01*9` with the floor
  to a multiple of 3 blended at 0.6; a rim ring `12 + h01*10` blended at
  `bw.rim * 0.9`; rift basins subtracted with a graben floor that rises
  through a faulted shoulder.
- **Tectonic cross-axis uplift.** `UPLIFT_STEPS (2.2) * clamp(v /
  UPLIFT_SPAN (52), -1, 1) * (1 - rimWeight)`, where `v` is the perpendicular
  axis coordinate.
- **Global water table** at `TABLE_STEPS = 4` relief steps; `tableHeight()`
  returns `TABLE_STEPS * VOXEL` world units.
- **River valley carve** with a bathtub bed below the table and smooth banks
  over `RIVER_CARVE = 5` cells, and the **tributary channel carve** that
  connects every basin to the river so the water surface is one network.
- **Village flat** and the parent's **ring-hamlet town flat** at
  `town_center_for(w, h, margin_z)`, with the parent's own
  `TOWN_FLAT_RADIUS = 5` / `TOWN_FLAT_CORE = 2`.

Donor constants carried verbatim: `SUB = 8`, `VOXEL = 0.125`, `MAX_STEPS = 40`,
`TABLE_STEPS = 4`, `VILLAGE_FLAT_RADIUS = 13`, `VILLAGE_FLAT_CORE = 6`,
`RIVER_CARVE = 5`, `TECTONIC_AXIS = (0.6, -0.8)`, `AXIS_PERP = (0.8, 0.6)`,
`AXIS_ANISO_U = 0.55`, `AXIS_ANISO_V = 1.2`, `BASIN_ASPECT = 1.7`,
`UPLIFT_STEPS = 2.2`, `UPLIFT_SPAN = 52`, and the three rift basins
`(15, 75) r 11.5 d 4.2`, `(64, 20) r 10 d 3.2`, `(72, 67) r 9 d 3.0`.

Six sibling noises, the donor's own, seeded `abs(SCATTER_SEED + salt) %
2147483647` with `SCATTER_SEED = 0x0c157e2026` (donor `TileTable.SCATTER_SEED`):

| Salt | Name | Frequency | Octaves |
|---|---|---|---|
| 242 | warp | 1/45 | 2 |
| 243 | mountain | 1/64 | 2 |
| 244 | plateau | 1/52 | 2 |
| 245 | ridge | 1/26 | 3 |
| 246 | terrace | 1/30 | 2 |
| 247 | hill | 1/20 | 4 |

Storage precision matters here. The donor holds `TECTONIC_AXIS` and
`AXIS_PERP` in a `Vector2` and returns `biome_weights` in a `Vector3`; in a
standard Godot build both store single-precision components, so the donor's
axis constants are `0.6000000238418579` and friends rather than the doubles a
JavaScript port would use. The port currently computes the biome weights and
the tectonic uplift in double precision throughout; section 8 quantifies
what that costs and what closing the gap would buy.

### The two trims

1. **No engineered corridors.** The donor's road/rail grading
   (`WorldLevel.corridors()`) belongs to the donor's 96x96 demo world and has
   no meaning in the web build. Dropped: the corridor grid, the corridor
   damping of the uplift, and the shore guarantee the corridors drive. The
   Godot probe applies the same trim (its `TrimWorld` keeps the corridor grid
   sized and zeroed and forces the corridor damping to `0.0`), so the golden
   values compare like for like.
2. **Village disc relocated** to `VILLAGE_X / VILLAGE_Y` = (34, 16), under the
   town. The donor's own `WorldLevel.VILLAGE` is 96x96-world data at
   (44.5, 58.5). `VILLAGE_FLAT_RADIUS = 13` and `VILLAGE_FLAT_CORE = 6` are
   unchanged.

### Web-side extensions (on top of the law, never inside it)

- **Ocean band.** The outermost cells of the vista footprint render as ocean
  floor: `stepsAtCell` returns `TABLE_STEPS - 2` there, so the sea meets the
  rim mountains and the rim belt itself stays above water. The band is
  implemented as explicit margin arithmetic on the footprint edges, not as an
  `edgeNorm` threshold (the donor's `edge_norm` formula is present in the
  module and is what drives the rim weight).
- **Desert band.** A dry band where the donor's warp noise is high, the relief
  is low and the cell is far from the village: `warpSample >= 0.25`,
  `stepsAtCell <= 9`, and the cell centre at least 30 cells from (34, 16). The
  lower end of the relief band (6) is implied: the water and shore checks run
  first, so only cells at 6 steps or above can reach the desert test. Same
  warped noise, no new algorithm.

### Classification order (`kindAt`, first match wins)

`water` (steps <= `TABLE_STEPS - 1`) > `shore` (steps <= `TABLE_STEPS + 1`) >
`village` (inside the village flat) > `desert` > `mountain` (biome mtn weight >
0.5) > `plateau` (biome plateau weight > 0.5) > `rim` (biome rim weight > 0.5
**and** steps >= 11, so the low rim stays grassland) > `hills` (steps > 6) >
`plains`.

The `rim` step height condition is an addition of the world-law slice; the
contract lists rim by weight alone (section 8).

**The law must remain a pure function of grid coordinates plus pinned seeds.**
Two `WorldHeightmap` instances over the same grid return identical values, and
a non-default-sized instance (96x96) builds independently and stays pure. No
wall-clock, no randomness, no iteration-order dependence.

## 5. Animation-phase math contract

The gait is a function of the ground covered, never of frame rate.

| Symbol | Definition |
|---|---|
| `STRIDE` | 1.0 world unit per full walk cycle |
| `walkPhase(distance)` | `distance * TAU / STRIDE` (radians, 0 at distance 0) |
| `walkPose(phase)` | `{ phase, swing: sin(phase), bob: abs(sin(phase)) }` |
| `idlePose(elapsedSeconds)` | `{ phase: 0, swing: 0, bob: sin(elapsed * TAU * IDLE_HZ) * IDLE_AMP }` |
| `IDLE_HZ` | 1.2 |
| `IDLE_AMP` | 0.02 |

Limb amplitude is `LIMB_AMP = 0.7` radians at full stride; the body bob driver
scale is `BOB_AMP = 0.05` world units. Legs and arms swing in opposition:
`legL = +swing * LIMB_AMP`, `legR = -swing * LIMB_AMP`, `armR = +swing *
LIMB_AMP`, `armL = -swing * LIMB_AMP`. The bob is applied to the **body**
group's `position.y`, so the whole figure rises and falls while the limbs keep
their own pivots.

Facing is derived from movement direction: while a step is in flight the root
turns toward `atan2(dx, dz)` by the shortest signed angular difference; while
idle it turns to face the camera around world up (the donor's billboard law).

Invariants:

- No wall-clock reads inside the math. `elapsedSeconds` is passed in.
- Identical inputs give identical outputs, always.
- The phase is a function of distance travelled, never of frame rate: a figure
  that covers 1.0 world unit completes exactly one cycle, whatever the frame
  cadence.
- `idlePose` never swings a limb (`swing` is 0); only the bob moves.

## 6. Camera and inspector contract

### Camera

`OrbitCamera` keeps its shape and gains reach:

- `DIST_MIN = 3` (close-ups), `DIST_MAX = 140` (the larger world).
- Pitch clamp `PITCH_MIN = 0.18`, `PITCH_MAX = 1.35`; yaw is unbounded.
- `target` is a `readonly THREE.Vector3` field, mutated **in place**;
  `setTarget(v)` copies into it rather than replacing it, so a held reference
  to the target stays valid across calls.
- `apply()` positions the camera on the orbit sphere, looks at the target, and
  calls `updateMatrixWorld()` so a pick that lands before the next render
  still reads a fresh matrix.

Framing:

- **Default.** `Game` constructs the orbit at yaw -0.6, pitch 0.72 and
  distance 60, targeting the village centre at `(VILLAGE_X, villageHeight +
  0.5, -VILLAGE_Y)`. That distance is the framing that shows the 68x32
  playable grid together with its margin ring.
- **Close-up.** Distance 4 on a focused townsfolk gives the head-and-shoulders
  view; the smoke uses distance 4 for the close screenshot and distance 6 for
  the pixel probe. (The camera class's own field defaults are yaw -0.6, pitch
  0.7, distance 36 — see section 8.)

### Inspector

`Inspector.show(sel)` fills these panel slots, all null-tolerant so a missing
element never throws:

| Slot | Content |
|---|---|
| `[data-slot="tile"]` | the wire tile id |
| `[data-slot="key"]` | the copy-table key |
| `[data-slot="text"]` | the copy-table display text |
| `[data-slot="terrain"]` | the terrain row |
| `[data-slot="figure"]` | the figure row |

The terrain row has two exact forms, separated by an em dash (U+2014) with one
space on each side:

| Case | Rendered string | Example |
|---|---|---|
| Dry cell | `<kind> — <steps> steps (<height> u)` | `hills — 7 steps (0.875 u)` |
| Wet cell | `<kind> — <steps> steps below the table` | `water — 3 steps below the table` |

The separator is an em dash (U+2014) with one space on each side. The figure
row is `<kind> #<id>`, e.g. `townsfolk #12`.

The dry row takes `<kind>` from the selection's terrain field. The wet row
renders the literal `water`; see risk 6.

The `terrain` and `figure` fields on a selection are optional: the inspector
reads them defensively and renders an **empty string** when either is absent.
A null selection hides the panel.

## 7. Determinism and safety rules

- **Pinned seeds only.** The world noises are seeded
  `abs(SCATTER_SEED + salt) % 2147483647`; the scatter law is seeded from
  `SCATTER_SEED = 0x0c157e2026`; the town keeps its own pinned seed. Nothing
  reads the clock or the environment.
- **Integer-only game state.** `GameState` carries integers and ids; floats
  live in view state (camera), never in the serialised state.
- **No `Math.random`, no `Date.now`** anywhere in `src/` or `tools/`.
- **No runtime network.** three.js is vendored in-repo and loaded through an
  import map; the page fetches nothing cross-origin, and the smoke asserts it
  (including that the game keeps running with the NIC emulated offline).
- **three r160 only**, vendored at `vendor/three.module.min.js`; no second
  copy, no CDN.
- **No post-processing.** No bloom, no composer, no tone-mapping pass. All
  shading is baked into vertex colours at build time.
- **Explicit-pathspec commits only**; never `-A`, never a push. The
  orchestrator integrates; slices do not commit.
- **Desktop and mobile from day one.** The layout, camera and input must work
  at 375x667 and at 1280x800; the smoke renders and screenshots both.
- **Assertions are on state, never on pixel goldens.** A test asserts
  numbers, counts and ids. The one pixel assertion in the suite is a
  *threshold* on a live probe (distinct colours and luminance variance over an
  NPC region, against a ground baseline) — a shape test, not a golden image.

## 8. Open risks

1. **A golden's print precision can hide a port defect — and did once.** The
   donor probe originally printed its samples with `String.num(v, 9)`: nine
   *decimals*, not nine significant digits. Small magnitudes were truncated
   (4.645590088e-4 printed as `0.000464559`), so the golden file lost the
   donor's float32 bits. Against that golden, `tests/noise.test.mjs`'s
   bit-exactness assertion failed at 16 of 864 lattice samples, each by 1 to
   9 float32 ULP, and the failure was read as float32 drift in the port. The
   port was not drifting: re-formatting the port's own values with the same
   nine-decimal format reproduced the golden strings exactly at all 864
   points. The probe now prints `String.num_scientific(v)` — the shortest
   round-tripping form — the golden was regenerated from a scratch Godot
   project, and the port is **bit-exact against the donor at every golden
   point** (864/864, max absolute error 0). The standing risk is procedural:
   a golden is only as good as the precision it was printed at, so a future
   golden must be baked at round-tripping precision, and a bit-exactness
   failure should be diagnosed against the golden's format before the port is
   re-derived.
2. **The biome weights and the tectonic uplift are computed in double
   precision where the donor computes in single.** The residual is real but
   its cause is *not* the noise port. Measured against the donor's own
   `tests/golden/world.txt`: the worst biome-weight deviation is **1.401e-6**
   (at (15, 75): the donor reports `mtn = 0.38492926955223083`, the port
   `0.38493067049795376`) and the worst tectonic-uplift deviation is
   **3.329e-8**, while the warp sample agrees to 7.1e-29. The cause is that
   the donor's GDScript stores `TECTONIC_AXIS` and `AXIS_PERP` in a
   `Vector2` — whose components are single-precision in a standard Godot
   build (`0.6000000238418579` for 0.6, confirmed by a donor probe) — and
   returns `biome_weights` in a `Vector3`, also single-precision; the port
   uses JavaScript doubles for all of it. The domain warp amplifies the
   difference because the axis constants scale the sample coordinates before
   two smoothsteps shape the result. Reproducing the donor's storage
   precision — round the axis constants to float32, and round the returned
   biome weights to float32 at the `Vector3` boundary — drops the worst
   biome-weight error to **4.99e-18** and the uplift error to **4.12e-18**
   (the last bit of the printed decimal), with all 40 golden step points
   still exact. That change is not in the tree yet; until it lands, the
   assertions are tiered (biome weights against 1e-5, warp sample and
   tectonic uplift against 1e-6) and the 1e-5 threshold sits only about
   seven times above the measured worst case, so a genuine regression of
   that order would still pass. The integer relief (`stepsAt`) is not
   exposed to any of this — all 40 golden step points match the donor
   exactly, because the integer clamp absorbs differences this small.
3. **The ocean band's width is pinned by nothing — not by the contract, not
   by a golden.** The contract describes the extension only in prose ("cells
   whose `edge_norm` is at the footprint edge sink below the water table"),
   which fixes neither the width nor the mechanism. The world-law slice was
   handed explicit inequalities that were asymmetric — `gx <= -MARGIN_X+2` /
   `gy <= -MARGIN_Z+2` gave three ocean cells on the west and south while
   `WORLD_W+MARGIN_X-2` gave two on the east and north — and flagged it; the
   orchestrator then corrected the source to `-MARGIN_X + 1` / `-MARGIN_Z + 1`
   on the low sides, which makes the band symmetric at two cells per side
   (measured on the built law: 128 cells west, 128 east, 272 south, 272
   north). Two residual risks remain: no golden pins the band — the donor
   probe deliberately excludes the web-only ocean extension, because the
   golden pins the donor's law, not the web's extensions — and the
   implementation uses explicit margin arithmetic rather than the `edgeNorm`
   threshold the contract's wording implies. A future edit to either side
   would silently move the coastline with no test to catch it.
4. **Figure height: 0.84 versus the contract's "~0.75".** The frozen part
   sizes (legs 0.30, torso 0.32, head 0.22) sum to 0.84 world units. The
   contract's prose says a figure is ~0.75 tall. The sizes are frozen and the
   implementation keeps them, so the discrepancy is in the prose, not the
   build; the smoke's pixel probe and its 32x48 box were calibrated against
   the real 0.84 figure.
5. **Two different "default" camera framings.** `OrbitCamera`'s field
   defaults are yaw -0.6, pitch 0.7, distance 36, while `Game` immediately
   overrides them with pitch 0.72 and distance 60 for the world framing. The
   smoke restores the *class* defaults (yaw -0.6, pitch 0.7, distance 36) for
   the `v3-default` screenshot, so that screenshot is not the framing a user
   sees on load. The "whole playable grid plus margin ring" framing is the
   distance-60 one.
6. **Inspector strings: the wet row's kind is literal.** The wet branch
   renders the literal `water`, not the selection's `kind` field; the dry
   branch renders `<kind>` from the field. The two agree in practice because a
   cell whose `water` flag is set always classifies as `water`, but the
   contract's description of both rows as `<kind>` is not what the code does
   for the wet case.
7. **`kindAt`'s rim rule is stricter than the contract.** The contract orders
   the classes as `water > shore > village > desert > mountain > plateau > rim
   > hills > plains` with rim keyed on biome rim weight > 0.5. The
   implementation adds `steps >= 11` so the low rim reads as grassland rather
   than bare stone. The ordering is unchanged; the rim predicate is narrower.
