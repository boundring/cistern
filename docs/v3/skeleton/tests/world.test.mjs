// SKELETON -- no implementation. Target path: tests/world.test.mjs
// Owning slice: B (core-world-law), session S02
//
// Responsibility: own the golden test for the ported terrain law -- compare
// the port against tests/golden/world.txt at every golden point, check the
// donor's derived quantities (biome weights, tectonic uplift, the warp sample,
// the water table, the river curves), and pin the two documented web-side
// extensions (the ocean band, the ordered classification) plus the
// pure-function and grid-size invariants. It must NOT own the law itself, nor
// any other slice's tests.
//
// Golden file: tests/golden/world.txt, baked by tools/godot-probe/probe_world.gd.
// Line formats:
//   "WSTEP  <isx> <isz> <steps>"  40 rows -- DONOR SUB-VOXEL coordinates
//                                  (isx = gx*SUB + SUB/2, SUB = 8), so the cell
//                                  under the sample is (isx-4)/8, (isz-4)/8
//   "WBIOME <fx> <fz> <mtn> <plateau> <rim>"  20 rows (float weights)
//   "WUPLIFT <fx> <fz> <value>"                12 rows
//   "WRIFT   <fx> <fz> <value>"                12 rows (the SALT_WARP noise)
//   "WTABLE  <value>"                           1 row (0.5)
//
// IMPORT PATH: the modules under test are the COMPILED build,
// out/core/world.js and out/core/terrain.js. This skeleton lives at
// docs/v3/skeleton/tests/, so the real build is four levels up:
// "../../../../out/core/world.js" -- promoted to tests/world.test.mjs the
// imports become the static
//   import { WorldHeightmap, riverX, riverHalfWidth } from "../out/core/world.js";
//   import { TABLE_STEPS, VOXEL, ... } from "../out/core/terrain.js";
// Here they are guarded dynamic imports so the skeleton suite stays green
// before `npm run build:core` has produced out/ (out/ is gitignored build
// output and does not exist in a fresh checkout).
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const worldMod = await import("../../../../out/core/world.js").catch(() => null);
const terrainMod = await import("../../../../out/core/terrain.js").catch(() => null);

const here = dirname(fileURLToPath(import.meta.url));
const GOLDEN = join(here, "..", "..", "..", "..", "tests", "golden", "world.txt");

/** The donor golden; empty when the file is not present yet. */
function readGolden() {
  try {
    return readFileSync(GOLDEN, "utf8");
  } catch {
    return "";
  }
}

const lines = readGolden().split("\n").filter((l) => l.startsWith("W"));
const nums = (l) => l.split(/\s+/).slice(1).map(Number);
const wsteps = lines.filter((l) => l.startsWith("WSTEP ")).map(nums);
const wbiome = lines.filter((l) => l.startsWith("WBIOME ")).map(nums);
const wuplift = lines.filter((l) => l.startsWith("WUPLIFT ")).map(nums);
const wrift = lines.filter((l) => l.startsWith("WRIFT ")).map(nums);
const wtable = Number((lines.find((l) => l.startsWith("WTABLE ")) ?? "WTABLE 0").split(/\s+/)[1]);

test("stepsAtCell matches the donor EXACTLY at every golden point", { todo: "not implemented — S02" }, () => {
  // EXACT (integer) equality, no tolerance:
  //   stepsAt(isx, isz) === steps        for all 40 "WSTEP" rows (the donor law)
  //   stepsAtCell(gx, gy) === steps      for the 34 golden cells the web law
  //                                     covers (gx in [-32,99], gy in [-14,45])
  //   stepsAtCell(gx, gy) === 2          for the 6 golden cells in the ocean
  //                                     band -- TABLE_STEPS - 2, the
  //                                     documented web extension. The donor
  //                                     has no ocean and says 2 at (70,47),
  //                                     which coincides, and 18/3/3/17/7 at
  //                                     (100,20), (15,75), (72,67), (44,58),
  //                                     (66,120).
  const actual = undefined; // TODO(S02): world.stepsAt(isx, isz) and world.stepsAtCell(gx, gy) per golden row
  assert.equal(actual, 7, "WSTEP 276 132 7 -> steps 7 (cell 34, 16)");
});

test("biomeWeights matches the donor within 1e-5", { todo: "not implemented — S02" }, () => {
  // Tolerance 1e-5 on each of the three weights, against the 20 "WBIOME" rows.
  // Measured residual of the current port: 1.401e-6 -- the donor stores its
  // Vector2 axes and its returned Vector3 in single precision, the port
  // computes in doubles.
  const actual = undefined; // TODO(S02): world.biomeWeights(fx, fz).mtn / .plateau / .rim per golden row
  assert.ok(Math.abs(actual - 0.0165228471159935) < 1e-5, "WBIOME 20 20 mtn");
});

test("tectonicUplift matches the donor within 1e-6", { todo: "not implemented — S02" }, () => {
  // Tolerance 1e-6 against the 12 "WUPLIFT" rows. Measured residual: 3.329e-8.
  const actual = undefined; // TODO(S02): world.tectonicUplift(fx, fz) per golden row
  assert.ok(Math.abs(actual - 1.55692311020997876) < 1e-6, "WUPLIFT 34 16");
});

test("warpSample matches the donor warp noise within 1e-6", { todo: "not implemented — S02" }, () => {
  // Tolerance 1e-6 against the 12 "WRIFT" rows (the SALT_WARP noise).
  // Measured residual: 7.129e-29.
  const actual = undefined; // TODO(S02): world.warpSample(fx, fz) per golden row
  assert.ok(Math.abs(actual - 0.61534148454666138) < 1e-6, "WRIFT 34 16");
});

test("tableHeight matches the donor water table", { todo: "not implemented — S02" }, () => {
  // Exact: the golden "WTABLE" row and the frozen product
  // TABLE_STEPS (4) * VOXEL (0.125) = 0.5.
  const actual = undefined; // TODO(S02): world.tableHeight()
  assert.equal(actual, 0.5, "WTABLE 0.5 === TABLE_STEPS * VOXEL");
});

test("river functions are the donor's own curves", { todo: "not implemented — S02" }, () => {
  // Closed-form identities (the donor's river_x / river_halfw), tolerance
  // 1e-12:
  //   riverX(z)         = 66 + 10*sin(0.045z + 0.8) + 4*sin(0.013z + 2.0)
  //   riverHalfWidth(z) = 2 + 0.8*sin(0.031z + 1.3)
  const actual = undefined; // TODO(S02): riverX(z) and riverHalfWidth(z) at z = -16, 0, 7.3, 24, 48, 120
  assert.ok(Math.abs(actual - 76.81075061629795) < 1e-12, "riverX(0)");
});

test("web extension: the ocean band renders below the water table", { todo: "not implemented — S02" }, () => {
  // The four footprint corners: stepsAtCell === TABLE_STEPS - 2 === 2,
  // isWater === true, waterDepth === 2, kindAt === "water".
  const actual = undefined; // TODO(S02): world.stepsAtCell / isWater / waterDepth / kindAt at the four corners
  assert.equal(actual, 2, "ocean corner steps === TABLE_STEPS - 2");
});

test("web extension: classification is deterministic and ordered", { todo: "not implemented — S02" }, () => {
  // kindAt(VILLAGE_X, VILLAGE_Y) === "village" (and +3,-2 likewise); every
  // submerged cell is "water" and dry; the kind vocabulary is exactly
  // plains, hills, plateau, mountain, rim, village, shore, desert, water.
  const actual = undefined; // TODO(S02): world.kindAt over the whole footprint
  assert.equal(actual, "village", "kindAt(34, 16) === village");
});

test("villageHeight is the donor's clamped village base", { todo: "not implemented — S02" }, () => {
  // Exact: max(macroSteps(34, 16), TABLE_STEPS + 2.0) * VOXEL
  //      = 6.964924857433026 * 0.125 = 0.8706156071791282
  const actual = undefined; // TODO(S02): world.villageHeight() and world.macroSteps(34, 16)
  assert.equal(actual, 0.8706156071791282, "village base height");
});

test("the law is a pure function of the grid", { todo: "not implemented — S02" }, () => {
  // Two instances agree on every sampled point, and a 96x96 instance agrees
  // with another 96x96 instance.
  const actual = undefined; // TODO(S02): stepsAtCell(34, 16) from a second, independent WorldHeightmap instance
  assert.equal(actual, 7, "a second instance agrees: stepsAtCell(34, 16) === 7");
});

test("the playable grid is 4.00x the authored town", { todo: "not implemented — S02" }, () => {
  // WORLD_W * WORLD_H = 68 * 32 = 2176 = 4.00 * (TOWN_W * TOWN_H = 34 * 16 = 544)
  // FOOTPRINT_W * FOOTPRINT_H = 136 * 64 = 8704
  // the town sits centred on the village disc: TOWN_X + TOWN_W/2 = 34 = VILLAGE_X,
  // TOWN_Y + TOWN_H/2 = 16 = VILLAGE_Y
  const actual = undefined; // TODO(S02): the frozen grid constants and their products
  assert.equal(actual, 4, "2176 / 544 === 4.00");
});
