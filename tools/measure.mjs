/**
 * Residual probe for the world-law change (workspace tool, not a repo file).
 *
 *   node tools/measure.mjs [path-to-world.js]
 *
 * Prints the measured residuals the remote brief names: the WBIOME and
 * WUPLIFT max abs errors against tests/golden/world.txt, the exactness of
 * the 40 WSTEP rows, the village base height, and the desert census over
 * the 136x64 footprint.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const worldPath = process.argv[2] ?? join(root, "out/core/world.js");

const { WorldHeightmap } = await import(pathToFileURL(worldPath).href);
const terrain = await import(pathToFileURL(join(root, "out/core/terrain.js")).href);
const { TABLE_STEPS, VOXEL, WORLD_W, WORLD_H, MARGIN_X, MARGIN_Z, VILLAGE_X, VILLAGE_Y } = terrain;

const lines = readFileSync(join(root, "tests/golden/world.txt"), "utf8")
  .split("\n")
  .map((l) => l.trim())
  .filter((l) => l.startsWith("W"));
const nums = (l) => l.split(/\s+/).slice(1).map(Number);
const wsteps = lines.filter((l) => l.startsWith("WSTEP ")).map(nums);
const wbiome = lines.filter((l) => l.startsWith("WBIOME ")).map(nums);
const wuplift = lines.filter((l) => l.startsWith("WUPLIFT ")).map(nums);
const wrift = lines.filter((l) => l.startsWith("WRIFT ")).map(nums);

const w = new WorldHeightmap();

let maxM = 0, maxP = 0, maxR = 0;
for (const [fx, fz, m, p, r] of wbiome) {
  const bw = w.biomeWeights(fx, fz);
  maxM = Math.max(maxM, Math.abs(bw.mtn - m));
  maxP = Math.max(maxP, Math.abs(bw.plateau - p));
  maxR = Math.max(maxR, Math.abs(bw.rim - r));
}
const biomeMax = Math.max(maxM, maxP, maxR);

let maxU = 0;
for (const [fx, fz, v] of wuplift) maxU = Math.max(maxU, Math.abs(w.tectonicUplift(fx, fz) - v));

if (process.env.PER_ROW) {
  console.log("-- per-row uplift error --");
  for (const [fx, fz, v] of wuplift) {
    const a = w.tectonicUplift(fx, fz);
    console.log(`  WUPLIFT ${fx} ${fz}  port ${a}  golden ${v}  err ${(a - v).toExponential(3)}`);
  }
  console.log("-- per-row biome error (max of the three) --");
  for (const [fx, fz, m, p, r] of wbiome) {
    const bw = w.biomeWeights(fx, fz);
    const e = Math.max(Math.abs(bw.mtn - m), Math.abs(bw.plateau - p), Math.abs(bw.rim - r));
    console.log(`  WBIOME ${fx} ${fz}  err ${e.toExponential(3)}`);
  }
}

let maxWarp = 0;
for (const [fx, fz, v] of wrift) maxWarp = Math.max(maxWarp, Math.abs(w.warpSample(fx, fz) - v));

let stepMiss = 0;
for (const [isx, isz, steps] of wsteps) if (w.stepsAt(isx, isz) !== steps) stepMiss++;

// Desert census over the footprint: the raw rule vs the classified kind.
let rawDesert = 0, kindDesert = 0;
const desertCells = [];
for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
  for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
    const steps = w.stepsAtCell(gx, gy);
    const fx = gx + 0.5, fz = gy + 0.5;
    const rule =
      w.warpSample(fx, fz) >= 0.25 && steps >= 6 && steps <= 9 &&
      Math.hypot(fx - VILLAGE_X, fz - VILLAGE_Y) >= 30;
    if (rule) rawDesert++;
    if (w.kindAt(gx, gy) === "desert") { kindDesert++; desertCells.push([gx, gy]); }
  }
}
const xs = desertCells.map((c) => c[0]), ys = desertCells.map((c) => c[1]);

console.log(`world.js              ${worldPath}`);
console.log(`WBIOME max abs err    ${biomeMax.toExponential(6)}  (mtn ${maxM.toExponential(3)} plateau ${maxP.toExponential(3)} rim ${maxR.toExponential(3)})`);
console.log(`WUPLIFT max abs err   ${maxU.toExponential(6)}`);
console.log(`WRIFT   max abs err   ${maxWarp.toExponential(6)}`);
console.log(`WSTEP exact misses    ${stepMiss} / ${wsteps.length}`);
console.log(`villageHeight         ${w.villageHeight()}`);
console.log(`macroSteps(village)   ${w.macroSteps(VILLAGE_X, VILLAGE_Y)}`);
console.log(`village base          ${Math.max(w.macroSteps(VILLAGE_X, VILLAGE_Y), TABLE_STEPS + 2.0)} * ${VOXEL}`);
console.log(`desert raw-rule cells ${rawDesert}`);
console.log(`desert kind cells     ${kindDesert}${kindDesert ? `  x ${Math.min(...xs)}..${Math.max(...xs)}  y ${Math.min(...ys)}..${Math.max(...ys)}` : ""}`);
