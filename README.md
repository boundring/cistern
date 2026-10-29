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
   `state()` reports the same text; `orbit`/`zoom`/`reset` succeed.
4. Every network request the page makes is same-origin (no runtime fetch
   beyond the vendored three.js).
5. Non-blank screenshots at 1280x800 and 375x667 (pixels are human-facing
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
  | { type: "reset" };
```

Headless harnesses play the game through exactly this surface over CDP
`Runtime.evaluate`.

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
