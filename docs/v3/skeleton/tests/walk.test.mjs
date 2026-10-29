// SKELETON -- no implementation. Target path: tests/walk.test.mjs
// Owning slice: C (walk math), session S03
//
// Responsibility: own the test for the walk-phase math -- the closed-form
// phase identity, the pose derivation from a phase, the idle bob's
// determinism and amplitude bound, and the pinned regression vector from
// tests/golden/walk.txt. It must NOT own the walk math itself, nor the
// figure rig, nor any other slice's tests.
//
// Golden file: tests/golden/walk.txt, one line per sample:
//   "WALK <distance> <phase> <swing> <bob>"  (12 rows)
//
// IMPORT PATH: the module under test is the COMPILED build, out/core/walk.js.
// This skeleton lives at docs/v3/skeleton/tests/, so the real build is four
// levels up: "../../../../out/core/walk.js" -- promoted to tests/walk.test.mjs
// the import becomes the static
//   import { STRIDE, IDLE_HZ, IDLE_AMP, walkPhase, walkPose, idlePose } from "../out/core/walk.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build:core` has produced out/ (out/ is gitignored build
// output and does not exist in a fresh checkout).
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const mod = await import("../../../../out/core/walk.js").catch(() => null);

const here = dirname(fileURLToPath(import.meta.url));
const GOLDEN = join(here, "..", "..", "..", "..", "tests", "golden", "walk.txt");

/** The donor golden; empty when the file is not present yet. */
function readGolden() {
  try {
    return readFileSync(GOLDEN, "utf8");
  } catch {
    return "";
  }
}

// The recorded vector: the same 12 distances the golden pins.
const DISTANCES = [0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.25, 3.0, 7.7, -0.4, 100.125];
const walkRows = readGolden()
  .split("\n")
  .filter((l) => l.startsWith("WALK "))
  .map((l) => l.split(/\s+/).slice(1).map(Number));

test("walkPhase is distance * TAU / STRIDE", { todo: "not implemented — S03" }, () => {
  // Closed-form identity, exact equality (STRIDE is 1):
  //   walkPhase(d) === d * TAU / STRIDE, TAU = 2*PI
  // e.g. d = 0.25 -> 1.5707963267948966, d = 7.7 -> 48.38052686528282
  const actual = undefined; // TODO(S03): mod.walkPhase(d) for each of the 12 recorded distances
  assert.equal(actual, 1.5707963267948966, "walkPhase(0.25)");
});

test("walkPose derives swing and bob from the phase", { todo: "not implemented — S03" }, () => {
  // Closed-form identity, exact equality:
  //   pose.phase === phase, pose.swing === sin(phase), pose.bob === |sin(phase)|
  // e.g. phase = PI/2 -> swing 1, bob 1; phase = PI -> swing 1.2246467991473532e-16
  const actual = undefined; // TODO(S03): mod.walkPose(phase) for the sampled phases
  assert.equal(actual, 1, "walkPose(PI/2).swing === 1");
});

test("idlePose is a slow deterministic bob", { todo: "not implemented — S03" }, () => {
  // Closed-form identity:
  //   phase 0, swing 0, bob === sin(elapsedSeconds * TAU * IDLE_HZ) * IDLE_AMP
  // with IDLE_HZ = 1.2 and IDLE_AMP = 0.02; two calls at the same t are equal.
  // e.g. idlePose(1).bob === 0.019021130325903073, idlePose(0).bob === 0
  const actual = undefined; // TODO(S03): mod.idlePose(t) for the sampled times
  assert.equal(actual, 0.019021130325903073, "idlePose(1).bob");
});

test("idlePose stays inside IDLE_AMP", { todo: "not implemented — S03" }, () => {
  // Bound: |bob| <= IDLE_AMP (0.02) for every sampled time.
  const actual = undefined; // TODO(S03): the worst |bob| over the sampled idle times
  assert.ok(Math.abs(actual) <= 0.02, "|idlePose(t).bob| <= IDLE_AMP");
});

test("the walk phase golden matches the recorded vector", { todo: "not implemented — S03" }, () => {
  // Against tests/golden/walk.txt, tolerance 1e-12 on phase, swing and bob,
  // for all 12 "WALK" rows (the row count must equal 12).
  const actual = undefined; // TODO(S03): walkPhase + walkPose per golden row
  assert.ok(Math.abs(actual - 48.38052686528282) <= 1e-12, "WALK 7.7 phase");
});
