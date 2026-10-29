# cistern-web

Browser-native HD-2D voxel diorama of Cistern's 34x16 starter town — three.js
r160, TypeScript compiled by `tsc` alone (no bundler), vendored assets, zero
runtime network fetches. The town is the SAME baked data the Godot build uses,
replayed through pinned-seed ports of the donor laws.

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
in `out/` (gitignored): `smoke-1280x800.png` and `smoke-375x667.png`.

## What the smoke run checks

1. Baked donors (`out/generated/donors.js`) structurally valid and matching the
   golden vectors in `tests/golden/` (town template matches up to the pinned
   FLAVOR grass dressing; scatter seed present in the Godot probe's seed set).
2. `window.game.state()` on the live page: pinned seed, 34x16 grid, every tile
   equal to the dressed golden town, floor+structure counts covering the map.
3. `window.game.dispatch(...)` intents: `inspect` resolves the copy table and
   `state()` reports the same text; `orbit`/`zoom`/`tick`/`reset` succeed.
4. The rendered townsfolk billboards equal the spawn count in the donor event
   stream (`tests/golden/townsfolk.txt`); ticks advance the sim transcript and
   nobody despawns (donor law).
5. Every network request the page makes is same-origin (no runtime fetch
   beyond the vendored three.js).
6. Non-blank screenshots at 1280x800 and 375x667 (pixels are human-facing
   evidence only; assertions are on state).

## Agent test surface (contract)

The page installs `window.game` (typed by `src/types/game.ts`):

```ts
interface GameApi {
  dispatch(intent: Intent): IntentResult;  // { ok: true, state } | { ok: false, error }
  state(): GameState;                      // serializable, integer-only
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

Billboards follow the donor W3-2 view law (`godot/scripts/view/
billboard_entities.gd`): 0.8-unit vertical quads, yaw-only camera facing,
grounded on the cell's terrain top + 0.5, color law per kind (townsfolk
`rgb(0.40, 0.78, 0.62)`). The page ticks the sim once every 400 ms for the
human viewer; `dispatch({type:"tick", n})` drives it deterministically.
Camera default distance is the donor 36; the smoke run keeps its own closer
framing (24) for the screenshots.

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
