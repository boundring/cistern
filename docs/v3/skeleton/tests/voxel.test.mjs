// SKELETON -- no implementation. Target path: tests/voxel.test.mjs
// Owning slice: D (voxel models), session S04
//
// Responsibility: own the test for the voxel model library -- mergeBoxes'
// face emission and per-face shading, and the shape/size contract of each
// model (broadleaf, pine, boulder, and the three item models). It must NOT
// own the figure rig (slice E), the world renderer (slices F/G), or any
// other slice's tests.
//
// Source of truth: src/render/voxel.ts -- mergeBoxes emits six quads per box
// (36 vertices, top / bottom / +z / -z / +x / -x), with the top at the base
// colour, the sides at SIDE_SHADE 0.78 and the bottom at BOTTOM_SHADE 0.62.
// The model constants are TRUNK (0.42, 0.3, 0.2), LEAF (0.24, 0.55, 0.28),
// LEAF_DARK (0.19, 0.46, 0.26), PINE (0.18, 0.42, 0.27), STONE (0.55, 0.55,
// 0.58), CRYSTAL (0.4, 0.8, 0.85), BERRY (0.8, 0.25, 0.2), BUSH (0.26, 0.5,
// 0.3).
//
// IMPORT PATH: the module under test is the COMPILED build,
// out/render/voxel.js. This skeleton lives at docs/v3/skeleton/tests/, so the
// real build is four levels up: "../../../../out/render/voxel.js" -- promoted
// to tests/voxel.test.mjs the import becomes the static
//   import { mergeBoxes, broadleafModel, pineModel, boulderModel,
//            crystalModel, berryModel, branchModel } from "../out/render/voxel.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build` has produced out/ (out/ is gitignored build output
// and does not exist in a fresh checkout; out/render/*.js also imports
// "three", which Node resolves from the workspace node_modules -- the browser
// uses the vendored r160 copy).
import test from "node:test";
import assert from "node:assert/strict";

const mod = await import("../../../../out/render/voxel.js").catch(() => null);

test("mergeBoxes emits six faces per box", { todo: "not implemented — S04" }, () => {
  // One box -> 6 quads -> 36 vertices (position attribute count 36), and the
  // geometry is non-indexed.
  const actual = undefined; // TODO(S04): mergeBoxes with a single box
  assert.equal(actual, 36, "vertices for one box");
});

test("mergeBoxes shades sides and bottom darker than the top", { todo: "not implemented — S04" }, () => {
  // The first six vertices are the top quad and carry the base colour
  // unchanged; the bottom quad carries base * 0.62; the four side quads
  // carry base * 0.78. For a base of (1, 1, 1) the side colour is 0.78 and
  // the bottom colour is 0.62.
  const actual = undefined; // TODO(S04): read the top, bottom and side vertex colours
  assert.equal(actual, 0.62, "bottom shade");
});

test("broadleafModel is trunk plus three canopy boxes", { todo: "not implemented — S04" }, () => {
  // Four boxes -> 144 vertices; the bounding box is about 0.7 wide and 1.0
  // tall; the model colour is LEAF.
  const actual = undefined; // TODO(S04): broadleafModel() geometry bounds and colour
  assert.equal(actual, 144, "vertices for the broadleaf");
});

test("pineModel is trunk plus three stacked boxes", { todo: "not implemented — S04" }, () => {
  // Four boxes -> 144 vertices; three canopy boxes stacked at y 0.45, 0.80
  // and 1.13 with widths 0.62, 0.45 and 0.26; total height 1.29.
  const actual = undefined; // TODO(S04): pineModel() geometry bounds and colour
  assert.equal(actual, 1.29, "pine height");
});

test("boulderModel is two or three offset boxes", { todo: "not implemented — S04" }, () => {
  // Three offset stone boxes -> 108 vertices; the bounding box is about
  // 0.55 x 0.40 x 0.45.
  const actual = undefined; // TODO(S04): boulderModel() geometry bounds and colour
  assert.equal(actual, 108, "vertices for the boulder");
});

test("item models are small", { todo: "not implemented — S04" }, () => {
  // Every item model is well under a metre: crystal 4 boxes (144 vertices,
  // 0.185 x 0.345 x 0.145), berry 4 boxes (144 vertices, 0.22 x 0.225 x
  // 0.22), branch 3 boxes (108 vertices, 0.30 x 0.095 x 0.10). The largest
  // single extent must not exceed 0.35.
  const actual = undefined; // TODO(S04): the bounding boxes of crystalModel, berryModel and branchModel
  assert.ok(actual <= 0.35, "largest item extent");
});
