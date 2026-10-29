/**
 * Golden test for the ported open-world law (src/core/world.ts).
 *
 * tests/golden/world.txt is the verbatim output of the donor probe
 * (tools/godot-probe/probe_world.gd): the donor law with the web's two
 * documented trims (no corridors, village disc at (34,16)), over the web's
 * 68x32 playable grid. stepsAt must match EXACTLY; the pure float fields
 * (biome weights, tectonic uplift, warp noise) must match within 1e-6.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { WorldHeightmap, riverX, riverHalfWidth } from "../out/core/world.js";
import {
  TABLE_STEPS,
  VOXEL,
  WORLD_W,
  WORLD_H,
  MARGIN_X,
  MARGIN_Z,
  VILLAGE_X,
  VILLAGE_Y,
} from "../out/core/terrain.js";

const golden = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), "golden", "world.txt"),
  "utf8",
);
const lines = golden.split("\n").filter((l) => l.startsWith("W"));

const wsteps = lines.filter((l) => l.startsWith("WSTEP ")).map((l) => l.split(/\s+/).slice(1).map(Number));
const wbiome = lines.filter((l) => l.startsWith("WBIOME ")).map((l) => l.split(/\s+/).slice(1).map(Number));
const wuplift = lines.filter((l) => l.startsWith("WUPLIFT ")).map((l) => l.split(/\s+/).slice(1).map(Number));
const wrift = lines.filter((l) => l.startsWith("WRIFT ")).map((l) => l.split(/\s+/).slice(1).map(Number));
const wtable = Number(lines.find((l) => l.startsWith("WTABLE ")).split(/\s+/)[1]);

test("golden coverage: the probe printed the full point set", () => {
  assert.equal(wsteps.length, 40);
  assert.equal(wbiome.length, 20);
  assert.equal(wuplift.length, 12);
  assert.equal(wrift.length, 12);
  assert.equal(lines.filter((l) => l.startsWith("WTABLE")).length, 1);
});

test("stepsAt matches the donor EXACTLY at every golden point", () => {
  const w = new WorldHeightmap();
  for (const [isx, isz, steps] of wsteps) {
    assert.equal(w.stepsAt(isx, isz), steps, `stepsAt(${isx}, ${isz})`);
  }
});

// The biome weights are the donor's float fields, but they amplify the
// golden's printed precision: the domain warp scales a noise sample by 34
// and the smoothstep derivative is up to 4.2, so a 5e-10 print residue
// lands as ~1.4e-6. The integer relief (stepsAt) is the exact contract.
test("biomeWeights matches the donor within 1e-5", () => {
  const w = new WorldHeightmap();
  let maxErr = 0;
  for (const [fx, fz, m, p, r] of wbiome) {
    const bw = w.biomeWeights(fx, fz);
    maxErr = Math.max(maxErr, Math.abs(bw.mtn - m), Math.abs(bw.plateau - p), Math.abs(bw.rim - r));
    assert.ok(Math.abs(bw.mtn - m) < 1e-5, `mtn at (${fx},${fz})`);
    assert.ok(Math.abs(bw.plateau - p) < 1e-5, `plateau at (${fx},${fz})`);
    assert.ok(Math.abs(bw.rim - r) < 1e-5, `rim at (${fx},${fz})`);
  }
  console.log(`biomeWeights max abs error: ${maxErr.toExponential(3)}`);
});

test("tectonicUplift matches the donor within 1e-6", () => {
  const w = new WorldHeightmap();
  let maxErr = 0;
  for (const [fx, fz, v] of wuplift) {
    maxErr = Math.max(maxErr, Math.abs(w.tectonicUplift(fx, fz) - v));
    assert.ok(Math.abs(w.tectonicUplift(fx, fz) - v) < 1e-6, `uplift at (${fx},${fz})`);
  }
  console.log(`tectonicUplift max abs error: ${maxErr.toExponential(3)}`);
});

test("warpSample matches the donor warp noise within 1e-6", () => {
  const w = new WorldHeightmap();
  let maxErr = 0;
  for (const [fx, fz, v] of wrift) {
    maxErr = Math.max(maxErr, Math.abs(w.warpSample(fx, fz) - v));
    assert.ok(Math.abs(w.warpSample(fx, fz) - v) < 1e-6, `warp at (${fx},${fz})`);
  }
  console.log(`warpSample max abs error: ${maxErr.toExponential(3)}`);
});

test("tableHeight matches the donor water table", () => {
  const w = new WorldHeightmap();
  assert.equal(w.tableHeight(), wtable);
  assert.equal(w.tableHeight(), TABLE_STEPS * VOXEL);
});

test("river functions are the donor's own curves", () => {
  // Donor: 66 + 10*sin(0.045z + 0.8) + 4*sin(0.013z + 2.0) / 2 + 0.8*sin(0.031z + 1.3)
  for (const z of [-16, 0, 7.3, 24, 48, 120]) {
    assert.ok(Math.abs(riverX(z) - (66 + 10 * Math.sin(0.045 * z + 0.8) + 4 * Math.sin(0.013 * z + 2.0))) < 1e-12);
    assert.ok(Math.abs(riverHalfWidth(z) - (2 + 0.8 * Math.sin(0.031 * z + 1.3))) < 1e-12);
  }
});

test("web extension: the ocean band renders below the water table", () => {
  const w = new WorldHeightmap();
  const corners = [
    [-MARGIN_X, -MARGIN_Z],
    [WORLD_W + MARGIN_X - 1, -MARGIN_Z],
    [-MARGIN_X, WORLD_H + MARGIN_Z - 1],
    [WORLD_W + MARGIN_X - 1, WORLD_H + MARGIN_Z - 1],
  ];
  for (const [gx, gy] of corners) {
    assert.equal(w.stepsAtCell(gx, gy), TABLE_STEPS - 2, `ocean at (${gx},${gy})`);
    assert.equal(w.isWater(gx, gy), true, `ocean water at (${gx},${gy})`);
    assert.equal(w.waterDepth(gx, gy), 2, `ocean depth at (${gx},${gy})`);
    assert.equal(w.kindAt(gx, gy), "water", `ocean kind at (${gx},${gy})`);
  }
  // The sea surface is the table: plane height, not cell heights.
  assert.equal(w.tableHeight(), TABLE_STEPS * VOXEL);
});

test("web extension: classification is deterministic and ordered", () => {
  const w = new WorldHeightmap();
  // The village centre is village ground.
  assert.equal(w.kindAt(VILLAGE_X, VILLAGE_Y), "village");
  assert.equal(w.kindAt(VILLAGE_X + 3, VILLAGE_Y - 2), "village");
  // Some cell in the footprint is submerged (river/lake) and classifies water.
  let submerged = 0;
  for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
    for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
      if (w.stepsAtCell(gx, gy) <= TABLE_STEPS - 1) {
        submerged++;
        assert.equal(w.kindAt(gx, gy), "water", `water at (${gx},${gy})`);
        assert.equal(w.waterDepth(gx, gy) > 0, true);
      } else {
        assert.equal(w.waterDepth(gx, gy), 0, `dry at (${gx},${gy})`);
      }
    }
  }
  assert.ok(submerged > 0, "the footprint holds water somewhere");
  // Every kind is a legal vocabulary word.
  const legal = new Set([
    "plains", "hills", "plateau", "mountain", "rim", "village", "shore", "desert", "water",
  ]);
  for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
    for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
      assert.ok(legal.has(w.kindAt(gx, gy)), `kind at (${gx},${gy})`);
    }
  }
});

test("villageHeight is the donor's clamped village base", () => {
  const w = new WorldHeightmap();
  assert.equal(
    w.villageHeight(),
    Math.max(w.macroSteps(VILLAGE_X, VILLAGE_Y), TABLE_STEPS + 2.0) * VOXEL,
  );
});

test("the law is a pure function of the grid", () => {
  const a = new WorldHeightmap();
  const b = new WorldHeightmap();
  for (let i = 0; i < 500; i++) {
    const isx = ((i * 7919) % 1000) - 280;
    const isz = ((i * 104729) % 700) - 140;
    assert.equal(a.stepsAt(isx, isz), b.stepsAt(isx, isz));
    const fx = isx / 8;
    const fz = isz / 8;
    assert.deepEqual(a.biomeWeights(fx, fz), b.biomeWeights(fx, fz));
    assert.equal(a.tectonicUplift(fx, fz), b.tectonicUplift(fx, fz));
    assert.equal(a.riftBowl(fx, fz), b.riftBowl(fx, fz));
    assert.equal(a.warpSample(fx, fz), b.warpSample(fx, fz));
  }
  // Non-default dimensions build independently and stay pure too.
  const c = new WorldHeightmap(96, 96);
  const d = new WorldHeightmap(96, 96);
  assert.equal(c.stepsAt(400, 400), d.stepsAt(400, 400));
});
