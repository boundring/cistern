// SKELETON -- no implementation. Target path: tests/worldrender.test.mjs
// Owning slice: D (render world terrain + scatter), sessions S06 and S07
//
// Responsibility: own the test for the world renderer -- the terrain mesh
// footprint and town hole, the town skirt, the baked vertex colours, the
// water plane and its deterministic animation, and the hash-scatter law
// behind the instanced props. It must NOT own the terrain law itself (slice
// B), the voxel model library (slice D's model half), or any other slice's
// tests.
//
// Source of truth: src/render/world.ts and src/core/terrain.ts --
// FOOTPRINT_SPAN_X = WORLD_W + MARGIN_X*2 = 136, FOOTPRINT_SPAN_Z = 64,
// FOOTPRINT_CX = 34.5, FOOTPRINT_CZ = -16.5, the terrain colour law is
// base/255 * (TERRAIN_AMBIENT 0.62 + TERRAIN_DIRECTIONAL 0.38 * max(dot(n, sun),
// 0)) with the sun from TERRAIN_SUN_DIR (length 0.9982985525382675), side
// faces multiply by TERRAIN_SIDE_SHADE 0.72, and the water animation is
// y = tableHeight + 0.02*sin(1.1t) + 0.012*sin(2.3t + 1.7),
// x = 0.03*sin(0.63t), z = 0.03*cos(0.47t).
//
// IMPORT PATH: the modules under test are the COMPILED build,
// out/render/world.js, out/core/world.js and out/core/terrain.js. This
// skeleton lives at docs/v3/skeleton/tests/, so the real build is four levels
// up: "../../../../out/render/world.js" -- promoted to
// tests/worldrender.test.mjs the imports become the static
//   import { WorldView } from "../out/render/world.js";
//   import { WorldHeightmap } from "../out/core/world.js";
//   import { TERRAIN_COLOR, ... } from "../out/core/terrain.js";
// Here they are guarded dynamic imports so the skeleton suite stays green
// before `npm run build` has produced out/ (out/ is gitignored build output
// and does not exist in a fresh checkout; out/render/*.js also imports
// "three", which Node resolves from the workspace node_modules -- the browser
// uses the vendored r160 copy).
import test from "node:test";
import assert from "node:assert/strict";

const renderMod = await import("../../../../out/render/world.js").catch(() => null);
const worldMod = await import("../../../../out/core/world.js").catch(() => null);
const terrainMod = await import("../../../../out/core/terrain.js").catch(() => null);

test("the terrain mesh covers the whole footprint", { todo: "not implemented — S06" }, () => {
  // The mesh spans the whole 136 x 64 footprint: every cell outside the town
  // hole contributes a top quad, so counts.cells is
  // FOOTPRINT_W * FOOTPRINT_H - TOWN_W * TOWN_H = 136 * 64 - 34 * 16 = 8160,
  // and the geometry's bounding box reaches x -34..102, z -48..16.
  const actual = undefined; // TODO(S06): the rendered cell count and geometry bounds
  assert.equal(actual, 8160, "rendered cells");
});

test("cells inside the town footprint are skipped", { todo: "not implemented — S06" }, () => {
  // The town hole is gx 17..50, gy 8..23; no terrain vertex lies strictly
  // inside the town rectangle in x/z (x 17..51, z -24..-8).
  const actual = undefined; // TODO(S06): count the vertices strictly inside the town rectangle
  assert.equal(actual, 0, "vertices strictly inside the town hole");
});

test("the town edge gets a skirt", { todo: "not implemented — S06" }, () => {
  // The skirt wall rises from the neighbouring cell to the village pad:
  // 100 skirt quads, whose 300 upper vertices sit at villageHeight()
  // = 0.8706156071791282 (stored as float32 0.8706156015396118).
  const actual = undefined; // TODO(S06): the skirt quad count and the village-height vertices
  assert.equal(actual, 300, "vertices at the village height");
});

test("vertex colours follow TERRAIN_COLOR and the baked lighting law", { todo: "not implemented — S06" }, () => {
  // colour = TERRAIN_COLOR[kind] / 255 * (0.62 + 0.38 * max(dot(n, sun), 0)).
  // e.g. the plains top quad of cell (0, 0) is
  // (0.35384212241721785, 0.48382494289701217, 0.2744081765684546) before
  // the float32 attribute store and (0.3538421094417572, 0.4838249385356903,
  // 0.2744081914424896) in it; the water top quad of cell (-34, -16) is
  // (0.25274437315515563, 0.37550592583051684, 0.33217831900391875) before
  // the store and (0.2527443766593933, 0.3755059242248535, 0.3321783244609833)
  // in it.
  const actual = undefined; // TODO(S06): the baked colour of a known top quad
  assert.ok(Math.abs(actual - 0.35384212241721785) <= 1e-6, "plains top colour");
});

test("side faces are shaded by TERRAIN_SIDE_SHADE", { todo: "not implemented — S06" }, () => {
  // A side face uses the same lighting law multiplied by TERRAIN_SIDE_SHADE
  // 0.72, e.g. the east face of the rim cell (-10, -10) is
  // (0.2084222526012927, 0.2084222526012927, 0.2296898365020752) before the
  // float32 attribute store and (0.20842225849628448, 0.20842225849628448,
  // 0.2296898365020752) in it.
  const actual = undefined; // TODO(S06): the baked colour of a known side face
  assert.ok(Math.abs(actual - 0.2084222526012927) <= 1e-6, "rim east face colour");
});

test("water sits at tableHeight() and spans past the footprint", { todo: "not implemented — S06" }, () => {
  // The water plane is FOOTPRINT_SPAN + 200 = 336 x 264, centred on
  // (FOOTPRINT_CX, FOOTPRINT_CZ) = (34.5, -16.5) and lying at
  // tableHeight() = 0.5.
  const actual = undefined; // TODO(S06): the water mesh position and size
  assert.equal(actual, 0.5, "water height === tableHeight()");
});

test("water animation is deterministic in elapsedSeconds", { todo: "not implemented — S06" }, () => {
  // update(t) is a pure function of the elapsed seconds: two calls with the
  // same t leave the water at the same place. At t = 0 the surface is at
  // y = 0.5 + 0.02*sin(0) + 0.012*sin(1.7) = 0.5118999777254296,
  // x = 0.03*sin(0) = 0, z = 0.03*cos(0) = 0.03.
  const actual = undefined; // TODO(S06): update(0) twice, then update(2.5)
  assert.equal(actual, 0.5118999777254296, "water surface height at t = 0");
});

test("scatter counts follow the donor hash-scatter law", { todo: "not implemented — S07" }, () => {
  // counts.trees 906 = broadleaf 428 + pine 478, counts.rocks 503,
  // counts.items 25 = crystal 8 + berry 6 + branch 11. Recomputing the
  // ScatterHash presence test over the footprint with the donor densities
  // (trees 0.16 on plains/hills/plateau/village, pines 0.12 on mountain/rim,
  // rocks 0.14 on mountain/rim, items 0.05 on plains/desert/village) must
  // reproduce those numbers exactly.
  const actual = undefined; // TODO(S07): recount the scatter with the hash law
  assert.equal(actual, 906, "tree count");
});

test("trees rocks and items are instanced voxel models", { todo: "not implemented — S07" }, () => {
  // Six InstancedMesh children carry the props: broadleaf 428 (144 verts),
  // pine 478 (144), boulder 503 (108), crystal 8 (144), berry 6 (144),
  // branch 11 (108).
  const actual = undefined; // TODO(S07): the instanced meshes and their counts
  assert.equal(actual, 6, "instanced meshes");
});
