# CONTRACT — cistern-web v3 (frozen interfaces)

Repo: `/mnt/2tb/@home/bricker/Projects/etc/cistern-web` (TS strict, tsc only, no bundler,
three r160 vendored, offline, no `Math.random` anywhere).

The five slices below run in parallel. **Every interface in this file is frozen** —
code against it verbatim; if you believe an interface is wrong, say so in your report
instead of changing it (the orchestrator owns the integration files).

## File ownership (disjoint — do not touch another slice's files)

| File | Slice |
|---|---|
| `src/core/noise.ts` | A (noise port) |
| `src/core/world.ts` | B (world law) |
| `src/core/walk.ts`, `src/render/figures.ts` | C (figures) |
| `src/render/world.ts`, `src/render/voxel.ts` | D (world renderer) |
| `src/render/camera.ts`, `src/render/inspector.ts` | E (camera + inspector) |
| `src/core/terrain.ts` (written, frozen) | orchestrator |
| `src/game.ts`, `src/render/scene.ts`, `src/main.ts`, `index.html`, `src/types/game.ts` | orchestrator (integration) |
| `tools/smoke.mjs`, `tools/godot-probe/*`, `tests/golden/*`, `tests/*.test.mjs` | owner of that test (see below) |

Test files are per-slice and must not collide:
`tests/noise.test.mjs` + `tests/golden/noise.txt` (A),
`tests/world.test.mjs` + `tests/golden/world.txt` (B),
`tests/walk.test.mjs` + `tests/golden/walk.txt` (C).

## Frozen: `src/core/terrain.ts` (already written — import from it, never redefine)

```ts
export const SUB = 8;            // donor sub-voxels per cell
export const VOXEL = 0.125;      // world units per relief step
export const TABLE_STEPS = 4;    // global water table (relief steps)
export const MAX_STEPS = 40;
export const WORLD_W = 68;       // playable cells (4.00x the 34x16 town)
export const WORLD_H = 32;
export const MARGIN_X = 34;      // donor MARGIN_FRAC 0.5
export const MARGIN_Z = 16;
export const FOOTPRINT_W = 136;  // WORLD_W + 2*MARGIN_X
export const FOOTPRINT_H = 64;   // WORLD_H + 2*MARGIN_Z
export const VILLAGE_X = 34;     // village disc centre (world cell coords)
export const VILLAGE_Y = 16;
export const TOWN_X = 17;        // town origin in world cell coords
export const TOWN_Y = 8;
export const TOWN_W = 34;
export const TOWN_H = 16;
export type TerrainKind = "plains"|"hills"|"plateau"|"mountain"|"rim"|"village"|"shore"|"desert"|"water";
export const TERRAIN_COLOR: Record<TerrainKind, readonly [number,number,number]>;
export const TERRAIN_SIDE_SHADE = 0.72;
export const TERRAIN_AMBIENT = 0.62;
export const TERRAIN_DIRECTIONAL = 0.38;
export const TERRAIN_SUN_DIR: readonly [number,number,number];
export const WATER_COLOR: readonly [number,number,number];
export const WATER_FLOOR_COLOR: readonly [number,number,number];
```

World cell coordinates: `gx` east (0..WORLD_W), `gy` south (0..WORLD_H); the vista
footprint runs `gx -MARGIN_X .. WORLD_W+MARGIN_X-1`. three.js space: a cell spans
`x in [gx, gx+1)`, `z in [-gy-1, -gy]` (the town diorama already uses this mapping:
cell `(gx,gy)` -> `x = gx`, `z = -gy`).

## Frozen: slice A — `src/core/noise.ts`

```ts
export interface NoiseOptions {
  seed: number;          // Godot FastNoiseLite seed (0..2147483647)
  frequency: number;     // cycles per unit, as the donor sets it (1.0/45.0 etc.)
  octaves: number;       // fractal octaves (FBM)
}
export class FastNoiseLite {
  constructor(opts: NoiseOptions);
  /** Godot get_noise_2d(x, y) -> [-1, 1]; float32-identical to the donor. */
  getNoise2D(x: number, y: number): number;
}
```

Godot's `FastNoiseLite` is the donor's noise engine (`godot/` uses
`noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH`, `fractal_type` default FBM,
lacunarity 2.0, gain 0.5). Port it from the **actual source**:
`https://raw.githubusercontent.com/godotengine/godot/master/thirdparty/fastnoise_lite/fast_noise_lite.h`
(network is available for research; the game itself stays offline). Godot's fork
computes in 32-bit floats — reproduce that with `Math.fround` at the same
places, or the port will drift from the donor.

## Frozen: slice B — `src/core/world.ts`

```ts
import type { TerrainKind } from "./terrain.js";

export interface BiomeWeights { mtn: number; plateau: number; rim: number; }

export class WorldHeightmap {
  constructor(w?: number, h?: number);   // defaults WORLD_W / WORLD_H
  /** donor steps_at(sub-voxel coords) -> relief steps 0..MAX_STEPS */
  stepsAt(isx: number, isz: number): number;
  /** relief steps at a cell centre */
  stepsAtCell(gx: number, gy: number): number;
  /** donor _macro_steps(fx, fz) -> relief steps (float) */
  macroSteps(fx: number, fz: number): number;
  /** donor biome_weights(fx, fz) */
  biomeWeights(fx: number, fz: number): BiomeWeights;
  /** donor tectonic_uplift(fx, fz) */
  tectonicUplift(fx: number, fz: number): number;
  /** donor rift_bowl(fx, fz) */
  riftBowl(fx: number, fz: number): number;
  /** the domain-warp noise sample (SALT_WARP), [-1, 1] — the desert mask reads it */
  warpSample(fx: number, fz: number): number;
  /** water surface height in world units (donor table_height) */
  tableHeight(): number;
  /** the village flat's height in world units (donor _village_base_h * VOXEL) */
  villageHeight(): number;
  /** donor lake rule: playable ground below the water table */
  isWater(gx: number, gy: number): boolean;
  /** web-side classification of a cell */
  kindAt(gx: number, gy: number): TerrainKind;
  /** water-table depth of a cell in steps (0 = dry) */
  waterDepth(gx: number, gy: number): number;
}
export function riverX(z: number): number;        // donor WorldLevel.river_x
export function riverHalfWidth(z: number): number; // donor WorldLevel.river_halfw
```

The law is the donor's `godot/scripts/view/world_heightmap.gd` (iteration 3):
biome weight masks (domain-warped), macro composition (hills/plains, ridged chains,
terraced plateaus, rim ring, rift basins), tectonic cross-axis uplift, the global
water table, the river valley carve, the tributary channel carve, the village flat
and the parent ring-hamlet flat. Port it **whole**; the only trims are:

1. **No engineered corridors.** The donor's road/rail grading
   (`WorldLevel.corridors()`) belongs to the donor's 96x96 demo world and has no
   meaning in the web build (no roads). Drop the corridor grid, the corridor
   damping of the uplift and the shore guarantee it drives. The Godot probe must
   apply the same trim (override `_build_corridors` so the corridor grid stays
   zero) so the golden values compare like for like.
2. **Village disc relocated** to `VILLAGE_X/VILLAGE_Y` (the town sits on it);
   the donor's own `WorldLevel.VILLAGE` is 96x96-world data. The donor's
   `VILLAGE_FLAT_RADIUS = 13` / `VILLAGE_FLAT_CORE = 6` stay.

Everything else (constants, salts, basins, river functions, the parent's town flat
at `town_center_for(w, h, margin_z)`, `SUB`, `VOXEL`, `MAX_STEPS`) is the donor's,
verbatim. **No new noise algorithm**: the six sibling noises are the donor's
(`SALT_WARP 242`, `SALT_MTN 243`, `SALT_PLATEAU 244`, `SALT_RIDGE 245`,
`SALT_TERRACE 246`, `SALT_HILL 247`; seed `abs(SCATTER_SEED + salt) % 2147483647`;
frequencies/octaves as in the donor).

Web-side extensions (documented, applied on top of the law, never inside it):

- **Ocean**: the outermost two cells of the footprint on every side sink below
  the water table, so the sea meets the rim mountains. Keep the rim belt itself
  above water. (The donor's `edge_norm` formula describes the *purpose* of this
  band — the rim it must not drown — not the predicate that selects it; the
  implementation uses explicit footprint-edge margin arithmetic.)
- **Desert**: a dry band where the donor's warp noise (already ported) is high,
  the relief is low and the cell is far from the village. Same warped noise — no
  new algorithm.
- `kindAt` classification order (document it in the file): `water` (below the
  table) > `shore` (at/just above the table) > `village` (inside the village
  flat) > `desert` > `mountain` (biome mtn weight > 0.5) > `plateau` (biome
  plateau weight > 0.5) > `rim` (biome rim weight > 0.5 **and** steps >= 11, so
  the low rim stays grassland) > `hills` (steps > 6) > `plains`.

## Frozen: slice C — walk math + voxel figures

```ts
// src/core/walk.ts
export const STRIDE = 1.0;                  // world units per full walk cycle
export interface WalkPose { phase: number; swing: number; bob: number; }
/** phase = distance * TAU / STRIDE (radians, 0 at distance 0) */
export function walkPhase(distance: number): number;
/** pose from a phase: swing = sin(phase), bob = |sin(phase)| */
export function walkPose(phase: number): WalkPose;
/** idle pose: a slow deterministic bob */
export function idlePose(elapsedSeconds: number): WalkPose;
```

```ts
// src/render/figures.ts
export type FigureKind = "player" | "townsfolk" | "villager";
export interface FigureOptions { stepDurationMs?: number; }
export class VoxelFigures {
  readonly group: THREE.Group;
  constructor(opts?: FigureOptions);
  spawn(id: number, kind: FigureKind, x: number, y: number, ground: number): void;
  /** new cell; the figure interpolates over stepDurationMs and turns to face it */
  moveTo(id: number, x: number, y: number, ground: number): void;
  /** per-frame: walk cycle, idle bob, facing */
  update(elapsedMs: number, camera: THREE.PerspectiveCamera): void;
  /** world position of a figure (for camera focus / pixel probes) */
  positionOf(id: number): THREE.Vector3 | null;
  count(): number;
  remove(id: number): void;
}
```

A figure is box geometry in groups: `root -> body (bob) -> { torso, head, armL, armR,
legL, legR }`, limbs pivoting at their top so a rotation swings them. Sizes in
world units (a figure is 0.84 tall): legs 0.16 x 0.30, torso 0.34 x 0.32,
head 0.22 cube, arms 0.12 x 0.30. Colours: the donor billboard palette
(`player [0.25,0.55,0.95]`, `townsfolk [0.4,0.78,0.62]`) for the garment, darker
boots, a skin tone for the head; a per-figure tint from `ScatterHash` keyed by
the figure id (deterministic). `villager` is a world-side idle figure.

## Frozen: slice D — world renderer

```ts
// src/render/world.ts
export interface TerrainField {          // structurally satisfied by WorldHeightmap
  stepsAtCell(gx: number, gy: number): number;
  kindAt(gx: number, gy: number): TerrainKind;
  tableHeight(): number;
  villageHeight(): number;
}
export interface WorldViewOptions {
  playableW: number; playableH: number;
  marginX: number; marginZ: number;
  townOriginX: number; townOriginY: number;
  townW: number; townH: number;
  seed: number;                          // ScatterHash seed
}
export class WorldView {
  readonly group: THREE.Group;
  readonly counts = { cells: number; trees: number; rocks: number; items: number };
  constructor(field: TerrainField, opts: WorldViewOptions);
  /** terrain top height at a world cell, in world units */
  heightAt(gx: number, gy: number): number;
  /** deterministic water animation (call once per frame) */
  update(elapsedSeconds: number): void;
}
```

Terrain: one merged `BufferGeometry` for the whole footprint (top face per cell,
side faces only where the neighbour is lower), vertex-coloured with
`TERRAIN_COLOR` + the donor's baked lighting law (`TERRAIN_AMBIENT`,
`TERRAIN_DIRECTIONAL`, `TERRAIN_SUN_DIR`; side faces x `TERRAIN_SIDE_SHADE`).
Cells inside the town footprint are skipped (the town diorama draws them) and the
town's edge gets a skirt down to the neighbouring terrain height. Structural
relief only: no per-cell surface noise.

Water: one translucent plane at `tableHeight()` spanning well past the footprint
(ocean), plus the lake floors under it; `update()` bobs it deterministically from
`elapsedSeconds` (no `Math.random`, no wall-clock reads).

Scatter: the donor's hash-scatter law (`src/core/scatter.ts` `ScatterHash`,
already ported) with a distinct floor identity per class (trees / rocks / items),
densities per biome band, and variants chosen by `ScatterHash.variant`. Trees,
rocks and items are **small voxel models** built from boxes
(`src/render/voxel.ts`): broadleaf (trunk + 3 canopy boxes), pine (trunk + 3
stacked boxes), boulder (2-3 offset boxes), plus small items (crystal, berry
cluster, branch). Instanced per model + per-instance colour for variation.

## Frozen: slice E — camera + inspector

`src/render/camera.ts`: keep `OrbitCamera`; raise `DIST_MAX` to 140, drop
`DIST_MIN` to 3 (close-ups), and add

```ts
setTarget(v: THREE.Vector3): void;
target: THREE.Vector3;   // readable
```

`src/render/inspector.ts`: keep `Inspector.show(sel)`; render two extra rows
that already exist in the panel markup:
`[data-slot="terrain"]` and `[data-slot="figure"]` (the orchestrator adds the
markup — use these exact slot names). The selection carries:

The terrain row renders the selection's `kind` for a dry cell, and the literal
`water` for a cell whose `water` flag is set.

```ts
export interface Selection {
  x: number; y: number; tile: string; copyKey: string; text: string;
  terrain?: { kind: TerrainKind; steps: number; height: number; water: boolean };
  figure?: { id: number; kind: string };
}
```

(the orchestrator owns `src/types/game.ts`; the inspector reads the optional
fields defensively — they may be absent).

## Rules for every slice

- `npm run typecheck` must pass for your files (the orchestrator's integration may
  be mid-flight; if a file of theirs blocks the build, report it, do not edit it).
- New non-trivial logic needs a test (`tests/<slice>.test.mjs`, node:test, the
  repo's style: import from `../out/core/...`, `npm test` compiles with
  `npm run build` first).
- Golden files are donor truth: bake them from a **headless Godot probe**
  (`godot --headless --path <scratch> -s probe_x.gd`), never hand-written. The
  donor repo is READ-ONLY: copy the `.gd` closure into a scratch project under
  `/tmp` and document the regeneration recipe in the probe's header comment.
  `godot` 4.7.2 is installed at `/usr/bin/godot`.
- Never `Math.random`, never `Date.now()`, no network at runtime.
- TypeScript strict; `npm run build` = `tsc -p tsconfig.json`.
- Do not commit (the orchestrator commits). Do not touch `out/` (it is build output).
