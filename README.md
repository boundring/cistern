# cistern-web

Browser-native HD-2D voxel world around Cistern's 34x16 starter town — three.js
r160, TypeScript compiled by `tsc` alone (no bundler), vendored assets, zero
runtime network fetches. The town is the SAME baked data the Godot build uses,
replayed through pinned-seed ports of the donor laws; the v3 open world around
it is the donor's own terrain law, ported whole.

## Run

```sh
npm install          # typescript 5.9.3 (dev dependency, the only one)
npm run bake         # vendor/cistern donors -> src/generated/donors.ts
npm run build        # tsc -> out/
npm run typecheck    # tsc --noEmit
python3 -m http.server 8000   # serve the repo root, then open http://127.0.0.1:8000/
npm run smoke        # build + headless-Chromium CI-equivalent (see below)
```

Requires Node >= 22 (built-in `fetch`/`WebSocket`), python3, and a
Chromium-family browser on PATH (`chromium` or `google-chrome-stable`).
`npm run smoke` serves the repo root on a loopback port, launches its own
isolated headless Chromium (throwaway profile, CDP `--remote-debugging-port=0`;
it never touches your browser), and drives the page over the DevTools protocol:
`Page.navigate`, `Runtime.evaluate`, `Page.captureScreenshot`. Screenshots land
in `out/` (gitignored): `smoke-1280x800.png` and `smoke-375x667.png`, plus the
v3 deliverable shots `v3-default.png`, `v3-wide.png` and `v3-close.png`.

## What the smoke run checks

1. Baked donors (`out/generated/donors.js`) structurally valid and matching the
   golden vectors in `tests/golden/` (town template matches up to the pinned
   FLAVOR grass dressing; scatter seed present in the Godot probe's seed set).
2. `window.game.state()` on the live page: pinned seed, 34x16 grid, every tile
   equal to the dressed golden town, floor+structure counts covering the map.
3. `window.game.dispatch(...)` intents: `inspect` resolves the copy table and
   `state()` reports the same text; `orbit`/`zoom`/`tick`/`reset` succeed.
4. The rendered townsfolk figures equal the spawn count in the donor event
   stream (`tests/golden/townsfolk.txt`); ticks advance the sim transcript and
   nobody despawns (donor law).
5. The v3 world state: the pinned grid (68x32 playable, 136x64 footprint, the
   village disc at (34, 16), the town at (17, 8)) and non-zero scatter counts
   (trees, rocks, items).
6. The NPC-region pixel probe: a framed townsfolk must read as a shaded 3D
   figure (distinct colours and luminance variance over a ground-only
   baseline), never a flat quad.
7. Every network request the page makes is same-origin (no runtime fetch
   beyond the vendored three.js).
8. Non-blank screenshots at 1280x800 and 375x667 (pixels are human-facing
   evidence only; assertions are on state).

## Agent test surface (contract)

The page installs `window.game` (typed by `src/types/game.ts`):

```ts
interface GameApi {
  dispatch(intent: Intent): IntentResult;  // { ok: true, state } | { ok: false, error }
  state(): GameState;                      // serializable, integer-only
  focus(x: number, y: number): void;       // move the orbit target onto a town cell
  entityScreenPos(id: number): { x: number; y: number } | null;
  probePixels(x: number, y: number, w: number, h: number): PixelProbe | null;
}
type Intent =
  | { type: "inspect"; x: number; y: number }
  | { type: "orbit"; yaw?: number; pitch?: number }
  | { type: "zoom"; distance: number }
  | { type: "tick"; n?: number }
  | { type: "reset" };
```

Headless harnesses play the game through exactly this surface over CDP
`Runtime.evaluate`.

## The ambient townsfolk (v2)

The town carries its pinned population: `src/core/townsfolk.ts` +
`src/core/sim.ts` port the donor sim (`godot/scripts/sim/townsfolk.gd` +
`town_state.gd`) exactly — keyed placement stream (`(4<<8)|2`: open
non-marker cells, Fisher–Yates order, two-step pacing) and one shared wander
stream (`(4<<8)|3`) drawn in strict tick action order over the donor's
energy/turn model (every tick each actor accrues `speed` energy; actors act
in `(y, x, id)` order while energy reaches 100). The golden vector
(`tests/golden/townsfolk.txt`) is the donor's own 200-tick ambient transcript,
captured by `tools/godot-probe/probe_townsfolk.gd` over the donor's own
classes; the TS port must reproduce it byte-identically
(`tests/townsfolk.test.mjs`).

Scope boundary (deliberate): the donor's full 200-tick golden additionally
couples townsfolk moves to a scripted player walk and two servants through
cell occupancy — those systems stay donor-only. The web consumes the ambient
sub-stream: the player marker arms at the spawn and waits. Placement is
identical to the donor golden fixture's townsfolk spawns (all ten cells).

In v2 the townsfolk were rendered as billboards, following the donor W3-2 view
law (`godot/scripts/view/billboard_entities.gd`): 0.8-unit vertical quads,
yaw-only camera facing, grounded on the cell's terrain top + 0.5. v3 replaces
them with the voxel figures below; the sim itself is untouched. The page ticks
the sim once every 400 ms for the human viewer; `dispatch({type:"tick", n})`
drives it deterministically.

## The v3 open world

The town used to float on a flat plane with billboard townsfolk. v3 puts it
inside the donor's own open-world relief law, ported whole from
`godot/scripts/view/world_heightmap.gd` (iteration 3) over its parent
`godot/scripts/view/hd2d_heightmap.gd`:

| | |
|---|---|
| Playable grid | **68 x 32 cells** — exactly 4.00x the authored 34 x 16 town (2176 cells) |
| Vista footprint | 136 x 64 cells (the donor's `MARGIN_FRAC 0.5` ring) |
| Village disc | centred on the town at world cell (34, 16); the donor's `VILLAGE_FLAT_RADIUS` 13 / core 6 |
| Water table | `TABLE_STEPS` 4 (world height 0.5), one level for the sea, the lakes and the river |
| Relief | 0.125 world units per step (the donor's `VOXEL`), 0..40 steps |

`src/core/world.ts` is a pure function of (grid coords, pinned seeds): the
domain-warped biome masks, the ridged mountain chains, the terraced plateaus,
the tectonic cross-axis uplift, the rift lake basins, the river valley carve,
the tributary channels and the village flat are all the donor's, verbatim. The
noise is the donor's too: `src/core/noise.ts` is a port of Godot's
`FastNoiseLite` (simplex-smooth, FBM), matched against a headless Godot probe
(`tools/godot-probe/probe_noise.gd`) so the port reproduces the donor's values.

Two documented trims: the donor's engineered road/rail corridors are dropped
(the web build has no roads — the probe applies the same trim, so the golden
compares like for like), and the village disc is relocated under the town (the
donor's own village sits in its 96 x 96 demo world). Two documented web
extensions live only in the cell helpers: the outermost two cells of the
footprint are ocean floor (the sea is a plane at the table height), and a dry
band where the donor's own warp noise runs high, the relief is low and the
cell is far from the village reads as desert.

The golden vector (`tests/golden/world.txt`) is the donor's own values, baked
by `tools/godot-probe/probe_world.gd` over the donor's classes; `stepsAt`
matches the donor exactly at every sampled point.

## The v3 voxel figures

The v2 billboards (flat mint quads) are gone. `src/render/figures.ts` builds
every figure — the player marker, the townsfolk and the world villagers — from
box geometry in groups (`root > body > { torso, head, armL/R, legL/R }`), with
the limbs on pivot groups so a rotation swings them. Per-face shading (top
base colour, sides 0.78, bottom 0.62) is baked into the vertex colours, the
way the donor's slabs are.

The gait is procedural and deterministic: `src/core/walk.ts` makes the phase a
pure function of the ground covered (`phase = distance * TAU / STRIDE`), so the
stride always matches the distance walked; idle figures bob on
`sin(elapsed * 1.2 Hz)`. The donor's billboard colour law is kept for the
garment (player `rgb(0.25, 0.55, 0.95)`, townsfolk `rgb(0.40, 0.78, 0.62)`).
Scatter props are small voxel models too (`src/render/voxel.ts`: broadleaf,
pine, boulder, crystal, berry, branch), placed by the donor's hash-scatter law
in biome bands.

## Data pipeline

`npm run bake` reads the vendored Cistern donors under `vendor/cistern/` and
writes `src/generated/donors.ts` (committed; regenerated whenever a donor
changes). It extracts: baked voxel slabs (volume flattened to `volumeB64`),
the `tiles.ron` tile/prop tables, `copy.ron`, the reference theme, the
authored 34x16 town template with its glyph table and shop metadata, tile PNGs
as data URIs, and the pinned constants (scatter seed, town seed, flavor key,
tint salt). Extraction fails loudly on any missing expected key; the output is
typed against `src/types/donors.ts` so drift breaks the build.

## Provenance

| Asset | Licence | Source |
|---|---|---|
| three.js r160 (`vendor/three.module.min.js`) | MIT | upstream three.js (vendored, core only) |
| Slabs, tile PNGs, `tiles.ron`, `copy.ron`, theme, town template, scatter-hash law | CC0 / operator-authored | Cistern repo (read-only donor), vendored under `vendor/cistern/` |
| Golden vectors (`tests/golden/*.txt`) | generated | headless Godot 4.7.2 probes in `tools/godot-probe/` |
| Godot Engine | probe tooling only, not shipped | used to generate the golden vectors |
| Townsfolk/billboard laws | ported, not copied | donor `townsfolk.gd`, `town_state.gd`, `billboard_entities.gd` (read-only donor) |
| Open-world relief law | ported, not copied | donor `world_heightmap.gd`, `hd2d_heightmap.gd`, `world_level.gd` (read-only donor) |
| Noise engine (`FastNoiseLite`) | ported, not copied | Godot's `thirdparty/fastnoise_lite` (MIT), matched against a Godot probe |
| Terrain palette, voxel figures and scatter models | operator-authored | written for this build (no new licences) |
