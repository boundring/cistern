// SKELETON -- no implementation. Target path: tests/camera.test.mjs
// Owning slice: E (camera), session S08
//
// Responsibility: own the test for the orbit camera -- the distance and
// pitch clamps, the focus target, and the fact that apply() puts the camera
// exactly at the requested distance from the target while looking at it. It
// must NOT own the figure rig, the world renderer, or any other slice's
// tests.
//
// Source of truth: src/render/camera.ts -- DIST_MIN 3, DIST_MAX 140,
// PITCH_MIN 0.18, PITCH_MAX 1.35, the default orbit (yaw -0.6, pitch 0.7,
// distance 36) and the placement
//   position = target + distance * (cos(pitch) * sin(yaw),
//                                    sin(pitch),
//                                    cos(pitch) * cos(yaw)).
//
// IMPORT PATH: the module under test is the COMPILED build,
// out/render/camera.js. This skeleton lives at docs/v3/skeleton/tests/, so
// the real build is four levels up: "../../../../out/render/camera.js" --
// promoted to tests/camera.test.mjs the import becomes the static
//   import { OrbitCamera } from "../out/render/camera.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build` has produced out/ (out/ is gitignored build output
// and does not exist in a fresh checkout; out/render/*.js also imports
// "three", which Node resolves from the workspace node_modules -- the browser
// uses the vendored r160 copy).
import test from "node:test";
import assert from "node:assert/strict";

const mod = await import("../../../../out/render/camera.js").catch(() => null);

test("distance is clamped to the allowed range", { todo: "not implemented — S08" }, () => {
  // set(undefined, undefined, 1000) -> distance 140 (DIST_MAX);
  // set(undefined, undefined, 0.5) -> distance 3 (DIST_MIN);
  // set(undefined, undefined, 36) -> distance 36 unchanged.
  const actual = undefined; // TODO(S08): orbit.set(undefined, undefined, 1000).distance
  assert.equal(actual, 140, "clamped distance");
});

test("pitch is clamped", { todo: "not implemented — S08" }, () => {
  // set(undefined, 5) -> pitch 1.35 (PITCH_MAX);
  // set(undefined, -3) -> pitch 0.18 (PITCH_MIN).
  const actual = undefined; // TODO(S08): orbit.set(undefined, 5).pitch
  assert.equal(actual, 1.35, "clamped pitch");
});

test("setTarget moves the orbit focus", { todo: "not implemented — S08" }, () => {
  // setTarget copies into the existing target Vector3 (so held references
  // stay valid): after setTarget((9, 8, 7)) the target reads (9, 8, 7) and
  // the object identity is unchanged.
  const actual = undefined; // TODO(S08): orbit.setTarget(new Vector3(9, 8, 7)) then read orbit.target
  assert.equal(actual, 9, "target x after setTarget");
});

test("apply points the camera at the target", { todo: "not implemented — S08" }, () => {
  // After apply() the camera sits at distance from the target (36 by
  // default) and looks straight at it. With the default orbit and the
  // target at (1, 2, 3) the position is
  // (-6.547045837866568, 31.191836740556877, 29.72505389024704).
  const actual = undefined; // TODO(S08): orbit.apply() then read camera.position
  assert.ok(Math.abs(actual - 36) <= 1e-9, "camera distance to the target");
});
