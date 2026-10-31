// Definition of done for the v3-render-camera fill item.
//
// The module under test is the single file in the item workdir (`camera.ts`).
// Node >= 22.18 strips TypeScript types natively, so the file is imported
// as-is -- the test runner never compiles it.
//
// The module is imported through HNGH_FILL_MODULE (absolute path, exported
// by run_tests.sh); the fallback is the sibling workdir copy.
//
// three.js is imported from the copy staged next to the module under test
// (<workdir>/node_modules/three/three.module.min.js), so the test and the
// module share one three instance.
//
// Against the declaration-only skeleton stub every case below fails with
// "not implemented: OrbitCamera"; against a correct fill they all pass.
//
// Canonical case names (input/v3-docs/TEST-SPEC.md section 7):
//   distance is clamped to the allowed range
//   pitch is clamped
//   setTarget moves the orbit focus
//   apply points the camera at the target

import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleUrl = process.env.HNGH_FILL_MODULE
  ? pathToFileURL(path.resolve(process.env.HNGH_FILL_MODULE)).href
  : new URL("../out/render/camera.js", import.meta.url).href;

/** The three.js build staged next to the module under test. */
async function loadThree() {
  try {
    return await import(
      new URL("./node_modules/three/three.module.min.js", moduleUrl).href
    );
  } catch (err) {
    if (err?.code !== "ERR_MODULE_NOT_FOUND") throw err;
    return await import("three");
  }
}

const THREE = await loadThree();
const { OrbitCamera } = await import(moduleUrl);

const EPS = 1e-9;
const near = (a, b, eps = EPS) => Math.abs(a - b) <= eps;

/** A camera + orbit pair with the frozen class defaults. */
function orbitAt(x, y, z) {
  const camera = new THREE.PerspectiveCamera();
  const target = new THREE.Vector3(x, y, z);
  return { camera, target, orbit: new OrbitCamera(camera, target) };
}

test("distance is clamped to the allowed range", () => {
  const { orbit } = orbitAt(1, 2, 3);

  assert.equal(orbit.distance, 36, "default distance");

  orbit.set(undefined, undefined, 1000);
  assert.equal(orbit.distance, 140, "clamped to DIST_MAX");

  orbit.set(undefined, undefined, 0.5);
  assert.equal(orbit.distance, 3, "clamped to DIST_MIN");

  orbit.set(undefined, undefined, 36);
  assert.equal(orbit.distance, 36, "an in-range distance is unchanged");
});

test("pitch is clamped", () => {
  const { orbit } = orbitAt(1, 2, 3);

  assert.equal(orbit.pitch, 0.7, "default pitch");

  orbit.set(undefined, 5);
  assert.equal(orbit.pitch, 1.35, "clamped to PITCH_MAX");

  orbit.set(undefined, -3);
  assert.equal(orbit.pitch, 0.18, "clamped to PITCH_MIN");
});

test("setTarget moves the orbit focus", () => {
  const { orbit } = orbitAt(1, 2, 3);
  const held = orbit.target;

  orbit.setTarget(new THREE.Vector3(9, 8, 7));

  assert.equal(orbit.target, held, "the focus object is mutated, never replaced");
  assert.equal(orbit.target.x, 9, "target x after setTarget");
  assert.equal(orbit.target.y, 8, "target y after setTarget");
  assert.equal(orbit.target.z, 7, "target z after setTarget");
});

test("apply points the camera at the target", () => {
  const { camera, target, orbit } = orbitAt(9, 8, 7);

  orbit.apply();

  // the camera sits exactly the orbit distance (36) from the target
  assert.ok(
    near(camera.position.distanceTo(target), 36),
    "camera distance to the target",
  );

  // the documented placement for the default orbit (yaw -0.6, pitch 0.7)
  assert.ok(near(camera.position.x, -6.547045837866568), "camera position x");
  assert.ok(near(camera.position.y, 31.191836740556877), "camera position y");
  assert.ok(near(camera.position.z, 29.72505389024704), "camera position z");

  // and it looks straight at the target
  const forward = camera.getWorldDirection(new THREE.Vector3());
  const toTarget = target.clone().sub(camera.position).normalize();
  assert.ok(near(forward.distanceTo(toTarget), 0), "the camera looks at the target");
});
