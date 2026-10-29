# cistern-web v3 -- skeleton tree

Skeletons for the v3 build, mirroring the target repo path below
`docs/v3/skeleton/`. No file here contains implementation.

## Rules

- Each stub is moved to the target path by its owning session; the stub is
  deleted when the real file lands.
- A stub states its target path, its owning slice, its responsibility (what
  the finished file owns and must NOT own) and the frozen signatures.
- Signatures are verbatim from `CONTRACT.md` or from the real source module.
  A reader diffing a stub against the real module sees only missing bodies,
  never a renamed or reshaped symbol.
- **No tsconfig change is needed.** `tsconfig.json` includes only
  `src/**/*.ts` (and `tsconfig.core.json` only `src/core/**` and
  `src/types/**`), so everything under `docs/v3/skeleton/**` is outside the
  build. The `.mjs` and `.gd` stubs are inert.
- The stubs are therefore not type-checked in place: their relative imports
  (`./core/town.js`, `../types/donors.js`, `three`) only resolve once the
  file has been moved to its target path. That is why the import lines are
  kept verbatim from the real module -- a stub diffed against the real file
  shows only the missing bodies.

## Tree

```
docs/v3/skeleton/
  README.md
  src/core/terrain.ts        frozen constants
  src/core/noise.ts          A
  src/core/world.ts          B
  src/core/walk.ts           C
  src/core/scatter.ts        donor hash-scatter
  src/render/voxel.ts        D
  src/render/world.ts        D
  src/render/figures.ts      C
  src/render/camera.ts       E
  src/render/inspector.ts    E
  src/types/game.ts          integration
  src/game.ts                integration
  src/render/scene.ts        integration
  src/main.ts                integration
  tools/smoke.mjs            smoke
  tools/godot-probe/probe_noise.gd   donor probe
  tools/godot-probe/probe_world.gd   donor probe
  tests/noise.test.mjs       A
  tests/world.test.mjs       B
  tests/walk.test.mjs        C
  tests/figures.test.mjs     C
  tests/voxel.test.mjs       D
  tests/worldrender.test.mjs D
  tests/camera.test.mjs      E
  tests/inspector.test.mjs   E
```

## Ownership

| Slice | Owns |
|---|---|
| A -- core-noise-port | `src/core/noise.ts`, `tests/noise.test.mjs`, `tools/godot-probe/probe_noise.gd` |
| B -- core-world-law | `src/core/world.ts`, `tests/world.test.mjs`, `tools/godot-probe/probe_world.gd` |
| C -- core-walk-math | `src/core/walk.ts`, `tests/walk.test.mjs` |
| C -- render-figures-rig | `src/render/figures.ts`, `tests/figures.test.mjs` |
| D -- render-world-terrain | `src/render/voxel.ts`, `src/render/world.ts`, `tests/voxel.test.mjs`, `tests/worldrender.test.mjs` |
| E -- render-camera | `src/render/camera.ts`, `tests/camera.test.mjs` |
| E -- render-inspector | `src/render/inspector.ts`, `tests/inspector.test.mjs` |
| donor hash-scatter | `src/core/scatter.ts` (already ported; consumed unchanged) |
| frozen constants | `src/core/terrain.ts` (complete; imports only) |
| integration | `src/types/game.ts`, `src/game.ts`, `src/render/scene.ts`, `src/main.ts` |
| smoke | `tools/smoke.mjs` |

## What a stub contains

- A header comment: the target repo path, the owning slice, and one paragraph
  of **Responsibility** naming what the finished file owns and what it must
  NOT own.
- The **frozen signatures** as declaration-only TypeScript: exported
  interfaces, exported type aliases, exported constants with their real
  values, and exported functions/methods whose bodies are
  `throw new Error("not implemented: <name>")`.
- The eight **test stubs** (`.mjs`) use a different convention: every case
  is registered as a node:test **todo** and carries one visible assertion
  with the expected value or tolerance already written out, plus a single
  marked placeholder line where the computation goes:

  ```
  test("<canonical name>", { todo: "not implemented -- S<session>" }, () => {
    const actual = undefined; // TODO(S<session>): <what to compute>
    assert.equal(actual, <expected>, "<what the assertion proves>");
  });
  ```

  The tolerances are the ones the canonical test names state: 1e-5 for
  `biomeWeights`, 1e-6 for `tectonicUplift` and `warpSample`, exact equality
  for the integer relief steps (`stepsAtCell`) and for the noise golden
  samples (the port is bit-exact against the donor). The 1e-5 / 1e-6
  residuals are the donor's single-precision storage (see the precision
  note in `src/core/world.ts`); tightening them to order 1e-7 is an
  optional S02 refinement, available only after the world law rounds the
  axis constants and the returned biome weights to float32.

  They import the compiled build through a **guarded dynamic import**
  (`await import("../../../../out/core/noise.js").catch(() => null)`),
  because `out/` is gitignored and absent in a fresh checkout -- a static
  import would make the file fail to load instead of reporting todo. Each
  header states the static import the file takes once promoted to
  `tests/<name>.test.mjs` (the skeleton's path carries four `..` segments,
  the promoted file's carries one).
- In the **`.ts` stubs**: no algorithm bodies, no loops, no conditionals, no
  arithmetic beyond constant initialisers. (The `.mjs` test stubs are the
  exception -- they carry golden-file parsing and the assertion
  scaffolding, but no test logic of their own.)
- `src/core/terrain.ts` is the exception: it is already complete apart from
  comments, so its stub carries every constant with its real value.
- The `.gd` probes carry the donor-probe responsibility, the golden file
  they produce, the regeneration recipe, and the corridor-trim and
  village-relocation rules -- and no GDScript logic.
- `tools/smoke.mjs` carries the acceptance list and the frozen assertion
  names -- and no implementation.
