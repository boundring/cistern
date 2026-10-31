/**
 * Golden test for the ported open-world law (src/core/world.ts).
 *
 * tests/golden/world.txt is the verbatim output of the donor probe
 * (tools/godot-probe/probe_world.gd): the donor law with the web's two
 * documented trims (no corridors, village disc at (34,16)), over the web's
 * 68x32 playable grid. stepsAt must match EXACTLY; the pure float fields
 * (biome weights, tectonic uplift, warp noise) must match within their
 * tolerances.
 *
 * The biome weights now match to 1.5158e-8: the donor samples its biome
 * mask on a single-precision (float32) tectonic frame, so the port reads
 * the donor's float32 axes at that use site (see src/core/world.ts). The
 * asserted bound tightens from 1e-5 to 1e-7 with that change; the case
 * name keeps the requirements-matrix wording.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { WorldHeightmap, riverX, riverHalfWidth } from "../out/core/world.js";
import {
  SUB,
  TABLE_STEPS,
  MAX_STEPS,
  VOXEL,
  WORLD_W,
  WORLD_H,
  MARGIN_X,
  MARGIN_Z,
  FOOTPRINT_W,
  FOOTPRINT_H,
  VILLAGE_X,
  VILLAGE_Y,
  TOWN_X,
  TOWN_Y,
  TOWN_W,
  TOWN_H,
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

// A WSTEP row carries donor sub-voxel coordinates: isx = gx * SUB + SUB / 2,
// so the cell under the sample is (isx - SUB/2) / SUB.
const cellOf = (isx, isz) => [(isx - SUB / 2) / SUB, (isz - SUB / 2) / SUB];

// The web's ocean band: the outermost two cells of the footprint.
const inOceanBand = (gx, gy) =>
  gx <= -MARGIN_X + 1 ||
  gx >= WORLD_W + MARGIN_X - 2 ||
  gy <= -MARGIN_Z + 1 ||
  gy >= WORLD_H + MARGIN_Z - 2;

test("golden coverage: the probe printed the full point set", () => {
  assert.equal(wsteps.length, 40);
  assert.equal(wbiome.length, 20);
  assert.equal(wuplift.length, 12);
  assert.equal(wrift.length, 12);
  assert.equal(lines.filter((l) => l.startsWith("WTABLE")).length, 1);
});

test("stepsAtCell matches the donor EXACTLY at every golden point", () => {
  // EXACT (integer) equality, no tolerance:
  //   stepsAt(isx, isz) === steps     for all 40 "WSTEP" rows (the donor law)
  //   stepsAtCell(gx, gy) === steps   for the 34 golden cells the web law
  //                                    covers (inside the ocean band)
  //   stepsAtCell(gx, gy) === 2       for the 6 golden cells in the ocean
  //                                    band -- TABLE_STEPS - 2, the
  //                                    documented web extension. The donor
  //                                    has no ocean and says 2 at (70, 47),
  //                                    which coincides.
  const w = new WorldHeightmap();
  let land = 0;
  let ocean = 0;
  for (const [isx, isz, steps] of wsteps) {
    const [gx, gy] = cellOf(isx, isz);
    assert.ok(
      Number.isInteger(gx) && Number.isInteger(gy),
      `WSTEP ${isx} ${isz} is not on a cell centre (SUB ${SUB})`,
    );
    assert.equal(w.stepsAt(isx, isz), steps, `stepsAt(${isx}, ${isz})`);
    if (inOceanBand(gx, gy)) {
      ocean += 1;
      assert.equal(
        w.stepsAtCell(gx, gy),
        TABLE_STEPS - 2,
        `ocean band cell (${gx}, ${gy}) !== TABLE_STEPS - 2`,
      );
    } else {
      land += 1;
      assert.equal(w.stepsAtCell(gx, gy), steps, `stepsAtCell(${gx}, ${gy})`);
    }
  }
  assert.equal(land, 34, "34 golden cells are covered by the web law");
  assert.equal(ocean, 6, "6 golden cells sit in the web's ocean band");
});

// The biome weights are the donor's float fields. The donor samples its
// biome mask on a single-precision tectonic frame (a Vector2), so the port
// reads the donor's float32 axes at that use site: the residual collapses
// from 1.4009e-6 to 1.5158e-8 and the bound tightens from 1e-5 to 1e-7.
// (The case name keeps the requirements-matrix wording; the assertion is
// the tight bound.)
test("biomeWeights matches the donor within 1e-5", () => {
  const w = new WorldHeightmap();
  let maxErr = 0;
  for (const [fx, fz, m, p, r] of wbiome) {
    const bw = w.biomeWeights(fx, fz);
    maxErr = Math.max(maxErr, Math.abs(bw.mtn - m), Math.abs(bw.plateau - p), Math.abs(bw.rim - r));
    assert.ok(Math.abs(bw.mtn - m) < 1e-7, `mtn at (${fx},${fz})`);
    assert.ok(Math.abs(bw.plateau - p) < 1e-7, `plateau at (${fx},${fz})`);
    assert.ok(Math.abs(bw.rim - r) < 1e-7, `rim at (${fx},${fz})`);
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

// The desert band is a web extension, so it has no donor golden -- but it
// must exist and lie where its rule says, not merely be a legal kind word.
// The rule (src/core/world.ts): warpSample >= 0.25, stepsAtCell in 6..9, and
// at least 30 cells from the village centre.
test("web extension: the desert band exists and obeys its rule", () => {
  const w = new WorldHeightmap();
  const desert = [];
  for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
    for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
      const steps = w.stepsAtCell(gx, gy);
      const fx = gx + 0.5;
      const fz = gy + 0.5;
      const rule =
        w.warpSample(fx, fz) >= 0.25 &&
        steps >= 6 &&
        steps <= 9 &&
        Math.hypot(fx - VILLAGE_X, fz - VILLAGE_Y) >= 30;
      // The rule and the classification agree, cell for cell.
      assert.equal(w.kindAt(gx, gy) === "desert", rule, `desert rule at (${gx},${gy})`);
      if (rule) desert.push([gx, gy]);
    }
  }
  // 133 desert cells over the 136x64 footprint: a north-south strip on the
  // west edge, a patch west of the river, and east-bank patches.
  assert.equal(desert.length, 133, "desert cells over the footprint");
  const westBand = desert.filter(([gx]) => gx < 0);
  assert.equal(westBand.length, 83, "the west band");
  assert.ok(
    desert.every(
      ([gx, gy]) => Math.hypot(gx + 0.5 - VILLAGE_X, gy + 0.5 - VILLAGE_Y) >= 30,
    ),
    "every desert cell is at least 30 cells from the village centre",
  );
  // The starter area stays buildable: no desert around the village disc.
  assert.equal(w.kindAt(VILLAGE_X, VILLAGE_Y), "village");
  assert.equal(w.kindAt(VILLAGE_X - 5, VILLAGE_Y + 4), "village");
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

test("the playable grid is 4.00x the authored town", () => {
  // WORLD_W * WORLD_H = 68 * 32 = 2176 = 4.00 * (TOWN_W * TOWN_H = 34 * 16 = 544)
  // FOOTPRINT_W * FOOTPRINT_H = 136 * 64 = 8704
  // the town sits centred on the village disc: TOWN_X + TOWN_W/2 = 34 = VILLAGE_X,
  // TOWN_Y + TOWN_H/2 = 16 = VILLAGE_Y
  assert.equal(WORLD_W * WORLD_H, 2176, "68 * 32");
  assert.equal(TOWN_W * TOWN_H, 544, "34 * 16");
  assert.equal((WORLD_W * WORLD_H) / (TOWN_W * TOWN_H), 4, "2176 / 544 === 4.00");
  assert.equal(FOOTPRINT_W * FOOTPRINT_H, 8704, "136 * 64");
  assert.equal(FOOTPRINT_W, WORLD_W + MARGIN_X * 2, "the footprint spans the grid plus both margins");
  assert.equal(FOOTPRINT_H, WORLD_H + MARGIN_Z * 2, "the footprint spans the grid plus both margins");
  assert.equal(TOWN_X + TOWN_W / 2, VILLAGE_X, "the town is centred on the village disc in x");
  assert.equal(TOWN_Y + TOWN_H / 2, VILLAGE_Y, "the town is centred on the village disc in z");
  assert.equal(VILLAGE_X, 34, "the village disc sits at x = 34");
  assert.equal(VILLAGE_Y, 16, "the village disc sits at y = 16");

  // The law is instantiated on that grid: the village disc the town sits on
  // is at (34, 16) in the model's own grid.
  const w = new WorldHeightmap();
  assert.equal(
    w.kindAt(VILLAGE_X, VILLAGE_Y),
    "village",
    "the village disc sits at the frozen (34, 16) in the model's grid",
  );
  assert.ok(MAX_STEPS >= TABLE_STEPS, "the relief clamp is above the water table");
});
