// SKELETON -- no implementation. Target path: tests/figures.test.mjs
// Owning slice: E (figures rig), session S05
//
// Responsibility: own the test for the voxel figure rig -- the root>body>limbs
// hierarchy, the frozen part sizes and joint pivots, the deterministic
// per-figure tint, the donor-matched garment palette, and the spawn/move/
// position/update behaviour of the walk cycle. It must NOT own the walk math
// (slice C owns that), nor the voxel model library (slice D owns that), nor
// any other slice's tests.
//
// Source of truth: src/render/figures.ts (frozen constants LEG_H 0.3,
// TORSO_H 0.32, HEAD_S 0.22, ARM_W 0.12, LEG_W 0.16, LIMB_AMP 0.7,
// BOB_AMP 0.05, DEFAULT_STEP_MS 400, LEG_SHADE 0.35, SIDE_SHADE 0.78,
// BOTTOM_SHADE 0.62) and the donor palette in
// cistern/godot/scripts/view/billboard_entities.gd (player 0.25/0.55/0.95,
// townsfolk 0.40/0.78/0.62, default 0.80/0.80/0.25).
//
// IMPORT PATH: the module under test is the COMPILED build,
// out/render/figures.js. This skeleton lives at docs/v3/skeleton/tests/, so
// the real build is four levels up: "../../../../out/render/figures.js" --
// promoted to tests/figures.test.mjs the import becomes the static
//   import { VoxelFigures } from "../out/render/figures.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build` has produced out/ (out/ is gitignored build output
// and does not exist in a fresh checkout; out/render/*.js also imports
// "three", which Node resolves from the workspace node_modules -- the browser
// uses the vendored r160 copy).
import test from "node:test";
import assert from "node:assert/strict";

const mod = await import("../../../../out/render/figures.js").catch(() => null);

test("a figure is a box hierarchy root>body>limbs", { todo: "not implemented — S05" }, () => {
  // group.children[0] is a Group (the root); root.children[0] is a Group (the
  // body); body.children holds exactly six boxes: torso, head, armL, armR,
  // legL, legR -- two Meshes and four Groups.
  const actual = undefined; // TODO(S05): walk the spawned figure's hierarchy
  assert.equal(actual, 6, "body child count");
});

test("limb pivots sit at the joint", { todo: "not implemented — S05" }, () => {
  // The pivot Group carries the joint position; the mesh inside hangs from
  // it. Arms pivot at x = +-(TORSO_W/2 + ARM_W/2) = +-0.23, y = LEG_H +
  // TORSO_H - ARM_H/2 = 0.47; legs pivot at x = +-TORSO_W/4 = +-0.085, y = LEG_H
  // = 0.3, with the mesh offset -LEG_H/2 = -0.15 below the pivot.
  const actual = undefined; // TODO(S05): read the four limb pivots and their mesh offsets
  assert.equal(actual, -0.23, "left arm pivot x");
});

test("figure height matches the frozen part sizes", { todo: "not implemented — S05" }, () => {
  // Total height = LEG_H + TORSO_H + HEAD_S = 0.3 + 0.32 + 0.22 = 0.84, and
  // the head top sits at LEG_H + TORSO_H + HEAD_S = 0.84 above the root.
  const actual = undefined; // TODO(S05): the figure's topmost vertex y minus the root y
  assert.equal(actual, 0.84, "figure height");
});

test("the per-figure tint is deterministic in the figure id", { todo: "not implemented — S05" }, () => {
  // tint(id) = 1 + ScatterHash(7).jitter(id, 0).x * 0.08, so id 7 gives
  // 1.010600848197937 and id 8 gives 0.9631864643096923; two figures with the
  // same id get the same tint, and the tint stays a +-4% band around 1.
  const actual = undefined; // TODO(S05): the tint of the spawned figure, twice
  assert.equal(actual, 1.010600848197937, "tint of figure id 7");
});

test("the garment palette matches the donor billboard palette", { todo: "not implemented — S05" }, () => {
  // The donor billboard_entities.gd colours: player (0.25, 0.55, 0.95),
  // townsfolk (0.40, 0.78, 0.62). The web adds villager (0.80, 0.72, 0.45).
  // The garment vertex colour is the palette scaled by the per-figure tint,
  // e.g. player id 7 -> (0.2526502013206482, 0.5558304786682129,
  // 0.960070788860321).
  const actual = undefined; // TODO(S05): the garment colour of a player figure
  assert.equal(actual, 0.2526502013206482, "player garment r");
});

test("spawn adds a figure and moveTo retargets it", { todo: "not implemented — S05" }, () => {
  // count() goes 0 -> 1 on spawn, and moveTo(id, x, y, ground) sets the new
  // destination; the figure's position then advances along that segment.
  const actual = undefined; // TODO(S05): count() before/after spawn, then moveTo
  assert.equal(actual, 1, "figure count after spawn");
});

test("positionOf returns the figure's world position", { todo: "not implemented — S05" }, () => {
  // positionOf(id) returns the root's world position; for
  // spawn(id, "player", 3, 5, 0.5) it is (3, 0.5, -5) -- the web maps world
  // y to -z. An unknown id returns null.
  const actual = undefined; // TODO(S05): positionOf of the spawned figure
  assert.equal(actual, -5, "figure z is -worldY");
});

test("update advances the walk cycle with travelled distance", { todo: "not implemented — S05" }, () => {
  // With DEFAULT_STEP_MS 400 and a step from (0, 0) to (1, 0): at 100 ms the
  // travelled distance is 0.25, so the phase is PI/2, swing 1, and the limbs
  // sit at +-LIMB_AMP 0.7 (legL +0.7, legR -0.7, armL -0.7, armR +0.7) with
  // the body bobbing by BOB_AMP 0.05.
  const actual = undefined; // TODO(S05): advance the figures to 100 ms and read the limb angles
  assert.equal(actual, 0.7, "legL rotation.x at quarter phase");
});
