# TEST-SPEC — cistern-web v3 test contract

The executable contract for the v3 open world. Every expected value below was
read out of the real source (`src/core/*.ts`, `src/render/*.ts`,
`src/types/game.ts`, `tools/smoke.mjs`) or measured against the compiled
build, so the implementing session can write the assertion without guessing.

**Scope.** Eight test modules, 51 test cases:

| Module | Target path | Cases | Session |
|---|---|---|---|
| `noise.test.mjs` | `tests/noise.test.mjs` | 4 | S01 core-noise-port |
| `world.test.mjs` | `tests/world.test.mjs` | 11 | S02 core-world-law |
| `walk.test.mjs` | `tests/walk.test.mjs` | 5 | S03 core-walk-math |
| `voxel.test.mjs` | `tests/voxel.test.mjs` | 6 | S04 render-voxel-models |
| `figures.test.mjs` | `tests/figures.test.mjs` | 8 | S05 render-figures-rig |
| `worldrender.test.mjs` | `tests/worldrender.test.mjs` | 9 | S06 render-world-terrain (7 cases), S07 render-world-scatter (2 cases) |
| `camera.test.mjs` | `tests/camera.test.mjs` | 4 | S08 render-camera |
| `inspector.test.mjs` | `tests/inspector.test.mjs` | 4 | S09 render-inspector |

Runnable skeletons for all 51 live in `docs/v3/skeleton/tests/`. They carry
the exact test names, the exact expected values and the `TODO(S<session>)`
markers; each is registered as a node:test `todo`, so the suite runs green
before the implementation lands.

## How to run

```bash
# 1. The pre-existing golden tests (rng, scatter, slab, town, townsfolk)
#    plus the eight new modules once they are implemented.
npm test

# 2. The skeletons: 51 cases, every one reported as todo, exit 0.
node --test docs/v3/skeleton/tests/

# 3. The end-to-end smoke run (both viewports + the NPC pixel probe).
npm run smoke
```

`npm test` runs `npm run build:core && node --test tests/`, so it compiles
`src/core/**` and `src/types/**` only. The four render-side modules
(`voxel`, `figures`, `worldrender`, `camera`, `inspector`) import from
`out/render/**`, which `npm run build` (the full `tsconfig.json`) produces;
`npm run smoke` builds it. A session implementing a render-side module should
run `npm run build` before its test.

The charter calls the pre-existing suite "13 golden tests". That number is
the v1 baseline: commit `28f382f` carried 13 cases across four files
(`rng` 2, `scatter` 2, `slab` 4, `town` 5). The later townsfolk commit
`fca2df7` added 5 more, so HEAD carries **18** cases across five files —
`rng` 2, `scatter` 2, `slab` 4, `town` 5, `townsfolk` 5 — all green, and all
of them must stay green. (The count difference is a charter wording
artefact, not a regression: nothing in `tests/` was deleted.)

The skeletons live under `docs/v3/skeleton/tests/`, so their relative import
paths carry four `..` segments (`../../../../out/core/noise.js`). When a
skeleton is promoted to `tests/<name>.test.mjs`, the path becomes the repo's
house style, e.g. `import { FastNoiseLite } from "../out/core/noise.js";`.

### Name reconciliation

The canonical test names in this spec are authoritative, and the skeletons use
them verbatim. Three modules already in `tests/` carry **different** case
names from an earlier slice; promoting the skeletons over them means renaming
those cases, not changing this spec:

| Module | Canonical name (this spec) | Name currently in `tests/` |
|---|---|---|
| noise | `ported FastNoiseLite matches the donor probe bit-exact` | same |
| noise | `the port is deterministic across repeated calls` | (folded into the bit-exact case as a per-row `Object.is` check) |
| noise | `octave count changes the value` | (not present) |
| noise | `seed changes the value` | (not present) |
| noise | — | `golden parsed: 6 configs x 144 lattice samples` (extra) |
| noise | — | `golden coordinates match the rebuilt lattice` (extra) |
| world | `stepsAtCell matches the donor EXACTLY at every golden point` | `stepsAt matches the donor EXACTLY at every golden point` |
| world | `the playable grid is 4.00x the authored town` | (not present) |
| world | — | `golden coverage: the probe printed the full point set` (extra) |
| world | — | `web extension: the ocean band is exactly two cells wide on every side` (extra) |
| walk | `walkPhase is distance * TAU / STRIDE` | `walkPhase(d) === d * TAU / STRIDE at fixed distances` |
| walk | `walkPose derives swing and bob from the phase` | `walkPose(phase): swing = sin(phase), bob = |sin(phase)|, phase echoed` |
| walk | `idlePose is a slow deterministic bob` | `idlePose deterministic, swing 0, |bob| <= IDLE_AMP` |
| walk | `idlePose stays inside IDLE_AMP` | (folded into the idle case) |
| walk | `the walk phase golden matches the recorded vector` | `golden walk vector matches` |
| walk | — | `STRIDE is 1 and idle constants are sane` (extra) |

The five modules with no landed counterpart (`voxel`, `figures`,
`worldrender`, `camera`, `inspector`) are new files.

---

## 1. `tests/noise.test.mjs` — session S01

Golden: `tests/golden/noise.txt`, baked by `tools/godot-probe/probe_noise.gd`.
864 rows, one per sample: `NOISE <tag> <x> <y> <value>`; 6 configs x 144
lattice points (x = 0.3 + 1.7i, y = -1.1 + 2.3j for i, j in 0..11).

Config table (the donor's six sibling noises — salt, frequency denominator,
fractal octaves, and the seed `abs(SCATTER_SEED + salt) % 2147483647` with
`SCATTER_SEED = 0x0C157E2026`):

| tag | salt | denominator | octaves | seed |
|---|---|---|---|---|
| WARP | 242 | 45 | 2 | 360587568 |
| MTN | 243 | 64 | 2 | 360587569 |
| PLATEAU | 244 | 52 | 2 | 360587570 |
| RIDGE | 245 | 26 | 3 | 360587571 |
| TERRACE | 246 | 30 | 2 | 360587572 |
| HILL | 247 | 20 | 4 | 360587573 |

Frequency is `1 / denominator`.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `ported FastNoiseLite matches the donor probe bit-exact` | every golden row: `new FastNoiseLite({seed, frequency: 1/denom, octaves}).getNoise2D(x, y)` | equals the golden value **exactly** (`Math.fround(got) === Math.fround(v)`, and the double comparison is also equal); 864/864 rows, max abs error 0 | golden `NOISE` rows |
| 2 | `the port is deterministic across repeated calls` | the same instance and coordinates twice | the two results are strictly equal | closed-form identity |
| 3 | `octave count changes the value` | WARP at `(0.3, -1.1)`, octaves 2 vs 3 | `-0.031104128807783127` vs `0.019175102934241295` | measured from `out/core/noise.js` |
| 4 | `seed changes the value` | `(0.3, -1.1)`, frequency 1/45, octaves 2, seeds 360587568 vs 360587569 | `-0.031104128807783127` vs `0.04789840802550316` | measured from `out/core/noise.js` |

**Known state of the port (verified, not a defect).** The ported
FastNoiseLite reproduces the donor's float32 samples **bit-exactly at all 864
golden points** — max abs error 0, 0 mismatches under `Math.fround`. An
earlier mismatch report (16 of 864 samples) came from the *donor probe's*
printing: it emitted `String.num(v, 9)` — nine decimals, not nine
significant digits — which truncated small magnitudes and lost the donor's
float32 bits in the golden file. The probe now prints
`String.num_scientific(v)` (the shortest round-tripping form) and the golden
was regenerated at full float32 precision. **There is no float32 drift in the
port and no defect to fix in S01.** The golden comparison is exact equality,
not a tolerance.

The residual that *does* exist is in the world law's float fields, and it has
a different cause entirely — see section 2.

## 2. `tests/world.test.mjs` — session S02

Golden: `tests/golden/world.txt`, baked by `tools/godot-probe/probe_world.gd`.
Line formats:

- `WSTEP  <isx> <isz> <steps>` — 40 rows, **donor sub-voxel coordinates**
  (`isx = gx*SUB + SUB/2`, `SUB = 8`), so the cell under the sample is
  `(isx-4)/8, (isz-4)/8`.
- `WBIOME <fx> <fz> <mtn> <plateau> <rim>` — 20 rows.
- `WUPLIFT <fx> <fz> <value>` — 12 rows.
- `WRIFT   <fx> <fz> <value>` — 12 rows (the SALT_WARP noise).
- `WTABLE  <value>` — 1 row, `0.50000000000000000`.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `stepsAtCell matches the donor EXACTLY at every golden point` | all 40 `WSTEP` rows | `stepsAt(isx, isz) === steps` **exactly** for every row (integer relief). `stepsAtCell(gx, gy) === steps` for the 34 golden cells the web law covers (`gx` in [-32, 99], `gy` in [-14, 45]); for the 6 golden cells in the web's ocean band `stepsAtCell === TABLE_STEPS - 2 === 2` — the donor says 2 at `(70,47)` and 18/3/3/17/7 at `(100,20)`, `(15,75)`, `(72,67)`, `(44,58)`, `(66,120)` because the donor has no ocean | golden `WSTEP` rows; the band is the documented web extension in `src/core/world.ts` (`stepsAtCell`) |
| 2 | `biomeWeights matches the donor within 1e-5` | the 20 `WBIOME` rows | each of `mtn`, `plateau`, `rim` within **1e-5**; measured worst residual of the current port 1.401e-6 | golden `WBIOME` rows |
| 3 | `tectonicUplift matches the donor within 1e-6` | the 12 `WUPLIFT` rows | within **1e-6**; measured worst residual 3.329e-8 | golden `WUPLIFT` rows |
| 4 | `warpSample matches the donor warp noise within 1e-6` | the 12 `WRIFT` rows | within **1e-6**; measured worst residual 7.129e-29 | golden `WRIFT` rows |
| 5 | `tableHeight matches the donor water table` | — | exactly `0.5`; equals both the golden `WTABLE` row and `TABLE_STEPS (4) * VOXEL (0.125)` | golden `WTABLE` row; `src/core/terrain.ts` |
| 6 | `river functions are the donor's own curves` | `z` in -16, 0, 7.3, 24, 48, 120 | within 1e-12 of `riverX(z) = 66 + 10*sin(0.045z + 0.8) + 4*sin(0.013z + 2.0)` and `riverHalfWidth(z) = 2 + 0.8*sin(0.031z + 1.3)`; `riverX(0) = 76.81075061629795`, `riverHalfWidth(0) = 2.7708465483337545` | closed-form identity (the donor's `river_x` / `river_halfw`) |
| 7 | `web extension: the ocean band renders below the water table` | the four footprint corners (-34,-16), (101,-16), (-34,47), (101,47) | `stepsAtCell === 2` (`TABLE_STEPS - 2`), `isWater === true`, `waterDepth === 2`, `kindAt === "water"` | frozen constants + the documented ocean extension |
| 8 | `web extension: classification is deterministic and ordered` | the whole footprint | `kindAt(34,16) === "village"` and `kindAt(37,14) === "village"`; submerged cells are `"water"` and dry; the vocabulary is exactly `plains, hills, plateau, mountain, rim, village, shore, desert, water` | the contract's documented classification order |
| 9 | `villageHeight is the donor's clamped village base` | — | exactly `max(macroSteps(34,16), TABLE_STEPS + 2.0) * VOXEL = 6.964924857433026 * 0.125 = 0.8706156071791282` | closed-form identity over `macroSteps` |
| 10 | `the law is a pure function of the grid` | two independent `WorldHeightmap` instances (and a 96x96 instance against another 96x96 instance) | identical results at every sampled point; no dependence on construction order or mutable state | closed-form identity (purity) |
| 11 | `the playable grid is 4.00x the authored town` | the frozen grid constants | `WORLD_W * WORLD_H = 68 * 32 = 2176` and `TOWN_W * TOWN_H = 34 * 16 = 544`, so `2176 / 544 === 4` exactly; `FOOTPRINT_W * FOOTPRINT_H = 136 * 64 = 8704`; the town sits centred on the village disc: `TOWN_X + TOWN_W/2 = 34 = VILLAGE_X`, `TOWN_Y + TOWN_H/2 = 16 = VILLAGE_Y` | frozen constants in `src/core/terrain.ts` |

**Why the float fields need a tolerance (and it is not noise drift).** The
donor stores its tectonic axis constants in a `Vector2` (single precision:
`0.6 -> 0.6000000238418579`, `0.8 -> 0.800000011920929`) and returns its biome
weights in a `Vector3` (also single precision); the web port computes in JS
doubles. The domain warp then scales a noise sample by 34 and the smoothstep
derivative reaches 4.2, so the donor's own single-precision storage lands as
about 1.4e-6 on a 0..1 weight. Reproduced with `Math.fround` on the axis
constants, the port's warped sample coordinates match the donor **exactly**
and the residual collapses to ~5e-18 — which confirms the residual is
single-precision storage on the donor side, not a drifting port. The integer
relief (`stepsAt`) is the exact contract; the float fields carry the stated
tolerances.

## 3. `tests/walk.test.mjs` — session S03

Frozen: `STRIDE = 1`, `IDLE_HZ = 1.2`, `IDLE_AMP = 0.02`, `TAU = 2*PI`.

Golden: `tests/golden/walk.txt`, 12 rows `WALK <distance> <phase> <swing>
<bob>`, at distances 0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.25, 3.0, 7.7, -0.4,
100.125.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `walkPhase is distance * TAU / STRIDE` | each of the 12 recorded distances | `walkPhase(d) === d * TAU / STRIDE` exactly; `walkPhase(0.25) = 1.5707963267948966`, `walkPhase(7.7) = 48.38052686528282` | closed-form identity |
| 2 | `walkPose derives swing and bob from the phase` | phases 0, 0.3, PI/2, PI, 3PI/2, 2PI, 12.34, -1.1, 1000.001 | `pose.phase === phase`, `pose.swing === sin(phase)`, `pose.bob === |sin(phase)|` exactly; at PI/2 swing 1 and bob 1 | closed-form identity |
| 3 | `idlePose is a slow deterministic bob` | times 0, 0.25, 0.5, 1, 2.5, 13.7, 1000 | `phase 0`, `swing 0`, `bob === sin(t * TAU * IDLE_HZ) * IDLE_AMP`; two calls at the same t are equal; `idlePose(1).bob = 0.019021130325903073`, `idlePose(0).bob = 0` | closed-form identity |
| 4 | `idlePose stays inside IDLE_AMP` | the same times | `|bob| <= IDLE_AMP` (0.02) | frozen bound |
| 5 | `the walk phase golden matches the recorded vector` | the 12 `WALK` rows | row count 12; phase, swing and bob within 1e-12 of the golden | golden `WALK` rows |

## 4. `tests/voxel.test.mjs` — session S04

Source: `src/render/voxel.ts`. `mergeBoxes` emits six quads per box (36
vertices, non-indexed): top, bottom, +z, -z, +x, -x. The top keeps the base
colour, the sides are `base * SIDE_SHADE (0.78)`, the bottom is
`base * BOTTOM_SHADE (0.62)`.

Model constants: `TRUNK (0.42,0.3,0.2)`, `LEAF (0.24,0.55,0.28)`,
`LEAF_DARK (0.19,0.46,0.26)`, `PINE (0.18,0.42,0.27)`, `STONE (0.55,0.55,0.58)`,
`CRYSTAL (0.4,0.8,0.85)`, `BERRY (0.8,0.25,0.2)`, `BUSH (0.26,0.5,0.3)`.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `mergeBoxes emits six faces per box` | one box | 6 quads, 36 position vertices, non-indexed | frozen face layout |
| 2 | `mergeBoxes shades sides and bottom darker than the top` | one box, base (1,1,1) | top vertices 1.0, side vertices 0.78, bottom vertices 0.62 | frozen `SIDE_SHADE` / `BOTTOM_SHADE` |
| 3 | `broadleafModel is trunk plus three canopy boxes` | `broadleafModel()` | 4 boxes, 144 vertices, bbox about 0.70 x 1.00 x 0.625, model colour `LEAF` | source constants |
| 4 | `pineModel is trunk plus three stacked boxes` | `pineModel()` | 4 boxes, 144 vertices, three canopy boxes at y 0.45 / 0.80 / 1.13, widths 0.62 / 0.45 / 0.26, total height 1.29, colour `PINE` | source constants |
| 5 | `boulderModel is two or three offset boxes` | `boulderModel()` | 3 boxes, 108 vertices, bbox about 0.55 x 0.40 x 0.45, colour `STONE` | source constants |
| 6 | `item models are small` | `crystalModel()`, `berryModel()`, `branchModel()` | crystal 4 boxes / 144 verts / bbox 0.185 x 0.345 x 0.145; berry 4 boxes / 144 verts / bbox 0.22 x 0.225 x 0.22; branch 3 boxes / 108 verts / bbox 0.30 x 0.095 x 0.10; the largest single extent <= 0.35 | source constants + the item-scale bound |

## 5. `tests/figures.test.mjs` — session S05

Source: `src/render/figures.ts`. Frozen: `LEG_H 0.3`, `TORSO_H 0.32`,
`HEAD_S 0.22`, `TORSO_W 0.34`, `ARM_W 0.12`, `ARM_H 0.3`, `LEG_W 0.16`,
`LIMB_AMP 0.7`, `BOB_AMP 0.05`, `DEFAULT_STEP_MS 400`, `LEG_SHADE 0.35`,
`SIDE_SHADE 0.78`, `BOTTOM_SHADE 0.62`, `SKIN (0.85,0.68,0.52)`.

Donor palette (`cistern/godot/scripts/view/billboard_entities.gd`): player
`(0.25, 0.55, 0.95)`, townsfolk `(0.40, 0.78, 0.62)`, default
`(0.80, 0.80, 0.25)`. The web adds villager `(0.80, 0.72, 0.45)`.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `a figure is a box hierarchy root>body>limbs` | one spawned figure | `group.children[0]` is a Group (root); `root.children[0]` is a Group (body); `body.children` holds exactly 6 boxes — torso and head as Meshes, armL/armR/legL/legR as Groups | frozen hierarchy |
| 2 | `limb pivots sit at the joint` | the four limbs | arm pivots at x = `+-(TORSO_W/2 + ARM_W/2)` = +-0.23, y = `LEG_H + TORSO_H - ARM_H/2` = 0.47; leg pivots at x = `+-TORSO_W/4` = +-0.085, y = `LEG_H` = 0.3; each limb's mesh hangs at y = `-size/2` below the pivot (legs -0.15) | frozen sizes + limb placement |
| 3 | `figure height matches the frozen part sizes` | one spawned figure | total height `LEG_H + TORSO_H + HEAD_S = 0.84`; the head top sits 0.84 above the root | frozen sizes |
| 4 | `the per-figure tint is deterministic in the figure id` | figures with ids 7 and 8 | `tint(id) = 1 + ScatterHash(7).jitter(id, 0).x * 0.08`: id 7 gives 1.010600848197937, id 8 gives 0.9631864643096923; the same id always gives the same tint; the tint stays within +-4% of 1 | frozen tint law over `src/core/scatter.ts` |
| 5 | `the garment palette matches the donor billboard palette` | a player figure (id 7) and a townsfolk figure | garment = palette x tint: player id 7 `(0.2526502013206482, 0.5558304786682129, 0.960070788860321)`; the untinted palette equals the donor's | donor `billboard_entities.gd` + frozen tint law |
| 6 | `spawn adds a figure and moveTo retargets it` | `spawn(id, kind, x, y, ground)` then `moveTo(id, x, y, ground)` | `count()` goes 0 -> 1; `moveTo` sets a new destination and the figure advances along that segment | frozen API |
| 7 | `positionOf returns the figure's world position` | `spawn(id, "player", 3, 5, 0.5)` | `positionOf(id)` = `(3, 0.5, -5)` — world y maps to -z; an unknown id returns `null` | frozen API + the world-to-three axis mapping |
| 8 | `update advances the walk cycle with travelled distance` | step from (0,0) to (1,0), `stepDurationMs 400`, sampled at 100 ms | travelled distance 0.25 -> phase PI/2 -> swing 1; `legL.rotation.x = +0.7`, `legR = -0.7`, `armL = -0.7`, `armR = +0.7` (`LIMB_AMP`); body bob `0.05` (`BOB_AMP`); root at (0.25, 0, 0) | frozen `update` law (`walkPhase(travelled)`) |

## 6. `tests/worldrender.test.mjs` — sessions S06 (terrain + water) and S07 (scatter)

Source: `src/render/world.ts`, `src/core/terrain.ts`.
`FOOTPRINT_SPAN_X = WORLD_W + MARGIN_X*2 = 136`, `FOOTPRINT_SPAN_Z = 64`,
`FOOTPRINT_CX = 34.5`, `FOOTPRINT_CZ = -16.5`.

Colour law (frozen): `colour = TERRAIN_COLOR[kind] / 255 * (TERRAIN_AMBIENT
0.62 + TERRAIN_DIRECTIONAL 0.38 * max(dot(n, sun), 0))`, sun from
`TERRAIN_SUN_DIR [0.35, -0.5, 0.79]` (normalised length
0.9982985525382675); side faces multiply by `TERRAIN_SIDE_SHADE 0.72`.
`TERRAIN_COLOR`: plains [98,134,76], hills [84,118,64], plateau [142,130,104],
mountain [126,126,134], rim [98,98,108], village [150,126,96], shore
[176,160,118], desert [198,172,112], water [70,104,92].

| # | Test name | Session | Input | Expected | Source of truth |
|---|---|---|---|---|---|
| 1 | `the terrain mesh covers the whole footprint` | S06 | a rendered `WorldView` over the 68x32 playable grid with margins | `counts.cells === 8160` (= 136*64 - 34*16, the town hole excluded); the terrain geometry's bounding box reaches x -34..102, y 0.25..4, z -48..16 | frozen footprint arithmetic + the terrain builder |
| 2 | `cells inside the town footprint are skipped` | S06 | the same mesh | zero vertices strictly inside the town rectangle (x 17..51, z -24..-8); the hole is gx 17..50, gy 8..23 | frozen town origin/size |
| 3 | `the town edge gets a skirt` | S06 | the same mesh | 100 skirt quads; their 300 upper vertices sit at `villageHeight() = 0.8706156071791282` (stored as float32 0.8706156015396118) | frozen skirt rule (`bordersTown` + `villageHeight`) |
| 4 | `vertex colours follow TERRAIN_COLOR and the baked lighting law` | S06 | the top quad of cell (0,0) (plains, h 0.75) and of cell (-34,-16) (water, h 0.25) | plains `(0.35384212241721785, 0.48382494289701217, 0.2744081765684546)` before the float32 attribute store and `(0.3538421094417572, 0.4838249385356903, 0.2744081914424896)` in it; water `(0.25274437315515563, 0.37550592583051684, 0.33217831900391875)` before the store and `(0.2527443766593933, 0.3755059242248535, 0.3321783244609833)` in it — the stored values are within 1e-6 of the law | closed-form lighting law over `TERRAIN_COLOR` |
| 5 | `side faces are shaded by TERRAIN_SIDE_SHADE` | S06 | the east face of the rim cell (-10,-10): the vertical quad at x = -9, z in {9, 10}, y from the east neighbour's height 2 up to the cell's height 2.125 | `(0.2084222526012927, 0.2084222526012927, 0.2296898365020752)` before the float32 store and `(0.20842225849628448, 0.20842225849628448, 0.2296898365020752)` in it — the same law times `TERRAIN_SIDE_SHADE` | closed-form lighting law |
| 6 | `water sits at tableHeight() and spans past the footprint` | S06 | the water mesh | a horizontal plane 336 x 264 (`FOOTPRINT_SPAN + 200`), centred on `(34.5, -16.5)`, at y = `tableHeight() = 0.5` | frozen footprint arithmetic + `tableHeight()` |
| 7 | `water animation is deterministic in elapsedSeconds` | S06 | `update(t)` at t = 0 and t = 2.5 | `y = 0.5 + 0.02*sin(1.1t) + 0.012*sin(2.3t + 1.7)`, `x = 0.03*sin(0.63t)`, `z = 0.03*cos(0.47t)`; at t = 0 that is `(0, 0.5118999777254296, 0.03)`; two calls with the same t give the same surface height | frozen animation law (pure function of `elapsedSeconds`) |
| 8 | `scatter counts follow the donor hash-scatter law` | S07 | a recount over the footprint using `ScatterHash` with floor identities 11 (trees), 14 (pines), 12 (rocks), 13 (items) and densities trees 0.16 on plains/hills/plateau/village, pines 0.12 on mountain/rim, rocks 0.14 on mountain/rim, items 0.05 on plains/desert/village | `counts.trees === 906` (broadleaf 428 + pine 478), `counts.rocks === 503`, `counts.items === 25` (crystal 8 + berry 6 + branch 11) — the recount reproduces the renderer's numbers exactly | the donor hash-scatter law over `src/core/scatter.ts` |
| 9 | `trees rocks and items are instanced voxel models` | S07 | the rendered props | 6 `InstancedMesh` children: broadleaf 428 instances (144 verts), pine 478 (144), boulder 503 (108), crystal 8 (144), berry 6 (144), branch 11 (108); instance colours set | frozen model set + the instanced emission |

## 7. `tests/camera.test.mjs` — session S08

Source: `src/render/camera.ts`. Frozen: `DIST_MIN 3`, `DIST_MAX 140`,
`PITCH_MIN 0.18`, `PITCH_MAX 1.35`, default orbit yaw -0.6, pitch 0.72,
distance 60 (the one default set: `DEFAULT_PITCH` / `DEFAULT_DISTANCE`, which
both the class fields and `Game` use).

Placement: `position = target + distance * (cos(pitch)*sin(yaw), sin(pitch),
cos(pitch)*cos(yaw))`, then `lookAt(target)`.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `distance is clamped to the allowed range` | `set(undefined, undefined, 1000)` / `(..., 0.5)` / `(..., 36)` | distance 140 (DIST_MAX) / 3 (DIST_MIN) / 36 unchanged | frozen clamps |
| 2 | `pitch is clamped` | `set(undefined, 5)` / `(undefined, -3)` | pitch 1.35 (PITCH_MAX) / 0.18 (PITCH_MIN) | frozen clamps |
| 3 | `setTarget moves the orbit focus` | `setTarget(new Vector3(9, 8, 7))` on a target of (1, 2, 3) | the target reads (9, 8, 7) and the same `Vector3` object is mutated in place (held references stay valid) | frozen `setTarget` semantics |
| 4 | `apply points the camera at the target` | `apply()` with the default orbit | the camera sits exactly `distance` (60) from the target and looks straight at it; with the target at (9, 8, 7) the position is `(-16.470086784880383, 47.563080318288385, 44.22952262518719)` | closed-form placement identity |

## 8. `tests/inspector.test.mjs` — session S09

Source: `src/render/inspector.ts`. `terrainLine()` renders
`` `${kind} — ${steps} steps (${height} u)` `` with an em dash (U+2014), or
`` `water — ${steps} steps below the table` `` when the cell is under water.
The figure row renders `` `${kind} #${id}` ``. Absent optional fields render
the empty string.

The panel is DOM-backed, so the test drives a minimal stand-in: an object with
`querySelector('[data-slot="..."]')` returning `{textContent, src, hidden}`
slots, plus a `hidden` flag on the panel itself.

| # | Test name | Input | Expected | Source of truth |
|---|---|---|---|---|
| 1 | `the terrain row renders kind steps and height` | `show({terrain: {kind: "hills", steps: 7, height: 0.875, water: false}})` | the terrain slot reads `hills — 7 steps (0.875 u)` | frozen `terrainLine` |
| 2 | `the terrain row renders the water case` | `show({terrain: {kind: "water", steps: 3, height: 0.375, water: true}})` | `water — 3 steps below the table` | frozen `terrainLine` |
| 3 | `the figure row renders kind and id` | `show({figure: {kind: "townsfolk", id: 12}})` | `townsfolk #12` | frozen row format |
| 4 | `absent optional fields render empty strings` | `show({})` (no terrain, no figure) | both optional slots read `""` | frozen defensive read |

---

## The four acceptance criteria

### A. Animated player and NPC models

1. **Hierarchy.** A figure is boxes in groups: `root -> body (bob) ->
   {torso, head, armL, armR, legL, legR}`; the limbs pivot at their top so a
   rotation swings them. Frozen sizes: legs 0.16 x 0.30, torso 0.34 x 0.32,
   head a 0.22 cube, arms 0.12 x 0.30; total height 0.84. Pinned by
   `tests/figures.test.mjs` cases 1-3.
2. **Deterministic walk phase.** `walkPhase(distance) = distance * TAU /
   STRIDE` with `STRIDE = 1`, so the phase is a pure function of the
   travelled distance; `walkPose` derives `swing = sin(phase)` and
   `bob = |sin(phase)|`. Pinned by `tests/walk.test.mjs` cases 1-2 and 5, and
   by `tests/figures.test.mjs` case 8 (at 100 ms of a 400 ms step the limbs
   sit at +-0.7).
3. **The NPC region is shaded 3D geometry, not a flat quad.** In
   `tools/smoke.mjs` the probe takes a tight 32x48 pixel box, feet-anchored,
   around an on-screen townsfolk, and compares it with a same-size
   ground-only box beside it. The gate is:
   - `probe.fig.samples > 0` — the probe must return samples;
   - `probe.fig.distinct >= 5` — a flat quad would read as one or two
     distinct luminance values;
   - `probe.fig.variance >= 500` — luminance variance over the region.
   The ground baseline is recorded in the same log line for comparison:
   `ground.distinct`, `ground.variance`, `ground.mean`. The calibration in
   `tools/smoke.mjs` (commented at the assertion) is a figure-region variance
   of about 1542 against a ground-only baseline of about 168, so the 500
   threshold is roughly 3x the ground baseline and about a third of the
   figure's own variance.

### B. The larger open world

- The playable grid is **68 x 32** world cells; the authored town is
  **34 x 16**. `68 * 32 = 2176` and `34 * 16 = 544`, so the playable grid is
  **exactly 4.00x** the authored town — the ratio is an integer, pinned by
  `tests/world.test.mjs` case 11.
- The **footprint is 136 x 64** cells (`WORLD_W + 2*MARGIN_X` by
  `WORLD_H + 2*MARGIN_Z`), which is what the terrain mesh covers and what the
  water plane extends past. Pinned by `tests/worldrender.test.mjs` cases 1
  and 6.
- The **town sits on the village disc at (34, 16)**: `TOWN_X = 17`,
  `TOWN_Y = 8`, `TOWN_W = 34`, `TOWN_H = 16`, so the town's centre is
  `(17 + 17, 8 + 8) = (34, 16) = (VILLAGE_X, VILLAGE_Y)`; the village flat
  has radius 13 and core 6 around that point, and the town hole is skipped by
  the terrain mesh. Pinned by `tests/world.test.mjs` cases 8 and 11 and
  `tests/worldrender.test.mjs` case 2.
- The smoke run asserts the same grid through the game state
  (`tools/smoke.mjs`): `playableW 68, playableH 32, footprintW 136,
  footprintH 64, villageX 34, villageY 16, townX 17, townY 8, townW 34,
  townH 16`.

### C. Donor parity of the terrain law

- **Relief is exact.** `stepsAt(isx, isz)` equals the donor's golden steps at
  every one of the 40 `WSTEP` points — integer equality, no tolerance.
  `stepsAtCell` reproduces the donor at the 34 golden cells the web law
  covers; the remaining 6 sit in the documented ocean band, where the web
  deliberately returns `TABLE_STEPS - 2 = 2` (the donor has no ocean).
- **Float fields are within tolerance.** `biomeWeights` within **1e-5**
  (measured worst residual 1.401e-6), `tectonicUplift` within **1e-6**
  (measured 3.329e-8), `warpSample` within **1e-6** (measured 7.129e-29).
- **The noise port is bit-exact.** All 864 golden noise samples match the
  donor's float32 exactly (max abs error 0). There is no float32 drift to
  fix: the earlier mismatch report was the donor probe's lossy
  `String.num(v, 9)` print, now `String.num_scientific` with the golden
  regenerated at full precision.
- **The residual's cause is donor single-precision storage**, not port
  drift: the donor holds its tectonic axis constants in a `Vector2` and its
  biome weights in a `Vector3` (both single precision), and the domain warp
  amplifies the difference. Reproducing the donor's single-precision axis
  constants makes the port's warped coordinates match exactly and collapses
  the residual to ~5e-18.

### D. Deterministic water animation

`update(elapsedSeconds)` is a pure function of the elapsed seconds:
`y = tableHeight + 0.02*sin(1.1t) + 0.012*sin(2.3t + 1.7)`,
`x = 0.03*sin(0.63t)`, `z = 0.03*cos(0.47t)`. Two calls with the same `t`
leave the surface at the same height; no `Math.random`, no wall-clock read.
Pinned by `tests/worldrender.test.mjs` case 7.

---

## Measured values this spec pins

Everything below was read from the source or measured against the compiled
build (`out/`, produced by `npm run build:core` / `npm run build`), not
inferred:

| Value | Where it came from |
|---|---|
| 864 golden noise samples, 6 configs x 144 lattice points | `tests/golden/noise.txt` |
| noise seeds 360587568..360587573 | `abs(0x0C157E2026 + salt) % 2147483647` |
| noise port bit-exact at 864/864, max abs error 0 | measured against the regenerated golden |
| `biomeWeights` residual 1.401e-6, `tectonicUplift` 3.329e-8, `warpSample` 7.129e-29 | measured by `tests/world.test.mjs` (its own console output) |
| `tableHeight` 0.5, `villageHeight` 0.8706156071791282, `macroSteps(34,16)` 6.964924857433026 | `out/core/world.js` |
| `riverX(0)` 76.81075061629795, `riverHalfWidth(0)` 2.7708465483337545 | `out/core/world.js` |
| grid 68x32, town 34x16, footprint 136x64, village (34,16) | `src/core/terrain.ts` |
| figure tint id 7 = 1.010600848197937, id 8 = 0.9631864643096923 | `ScatterHash(7).jitter(id, 0)` |
| player garment id 7 `(0.2526502013206482, 0.5558304786682129, 0.960070788860321)` | `out/render/figures.js` |
| terrain 8160 cells, 93264 vertices, bbox x -34..102, y 0.25..4, z -48..16 | `out/render/world.js` |
| 300 skirt vertices at the village height, 100 skirt quads | `out/render/world.js` |
| plains/water/rim face colours | the lighting law over `TERRAIN_COLOR`, cross-checked against the built geometry |
| water plane 336 x 264 at (34.5, 0.5, -16.5) | `out/render/world.js` |
| scatter 906 trees (428 + 478), 503 rocks, 25 items (8 + 6 + 11) | `out/render/world.js` and an independent `ScatterHash` recount |
| camera clamps 3/140 and 0.18/1.35, default position with target (1,2,3) | `out/render/camera.js` |
| inspector strings including the U+2014 em dash | `out/render/inspector.js` |
