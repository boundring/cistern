import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { STRIDE, IDLE_HZ, IDLE_AMP, walkPhase, walkPose, idlePose } from "../out/core/walk.js";

const here = dirname(fileURLToPath(import.meta.url));
const TAU = Math.PI * 2;

// Fixed sample sets — closed-form identities must hold everywhere, and the
// same samples are pinned in golden/walk.txt as a regression vector.
const DISTANCES = [0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.25, 3.0, 7.7, -0.4, 100.125];
const PHASES = [0, 0.3, Math.PI / 2, Math.PI, (3 * Math.PI) / 2, 2 * Math.PI, 12.34, -1.1, 1000.001];
const IDLE_TIMES = [0, 0.25, 0.5, 1, 2.5, 13.7, 1000];

test("STRIDE is 1 and idle constants are sane", () => {
  assert.equal(STRIDE, 1.0);
  assert.ok(IDLE_HZ > 1 && IDLE_HZ < 1.5, `IDLE_HZ ~1.2, got ${IDLE_HZ}`);
  assert.ok(IDLE_AMP > 0.01 && IDLE_AMP < 0.03, `IDLE_AMP ~0.02, got ${IDLE_AMP}`);
});

test("walkPhase(d) === d * TAU / STRIDE at fixed distances", () => {
  for (const d of DISTANCES) assert.equal(walkPhase(d), (d * TAU) / STRIDE, `phase(${d})`);
});

test("walkPose(phase): swing = sin(phase), bob = |sin(phase)|, phase echoed", () => {
  for (const p of PHASES) {
    const pose = walkPose(p);
    assert.equal(pose.phase, p);
    assert.equal(pose.swing, Math.sin(p), `swing(${p})`);
    assert.equal(pose.bob, Math.abs(Math.sin(p)), `bob(${p})`);
  }
});

test("idlePose deterministic, swing 0, |bob| <= IDLE_AMP", () => {
  for (const s of IDLE_TIMES) {
    const a = idlePose(s);
    const b = idlePose(s);
    assert.deepEqual(a, b, `idle(${s}) deterministic`);
    assert.equal(a.swing, 0);
    assert.ok(Math.abs(a.bob) <= IDLE_AMP, `|bob(${s})| <= IDLE_AMP`);
    assert.equal(a.bob, Math.sin(s * TAU * IDLE_HZ) * IDLE_AMP);
  }
});

test("golden walk vector matches", () => {
  const raw = readFileSync(join(here, "golden/walk.txt"), "utf8");
  const lines = raw.split("\n").filter((l) => l.startsWith("WALK "));
  assert.equal(lines.length, DISTANCES.length, "golden row count");
  lines.forEach((line, i) => {
    const [tag, d, phase, swing, bob] = line.trim().split(/\s+/);
    assert.equal(tag, "WALK");
    const p = walkPhase(Number(d));
    const pose = walkPose(p);
    const near = (a, b) => Math.abs(a - b) <= 1e-12;
    assert.ok(near(p, Number(phase)), `phase row ${i}`);
    assert.ok(near(pose.swing, Number(swing)), `swing row ${i}`);
    assert.ok(near(pose.bob, Number(bob)), `bob row ${i}`);
  });
});
