/**
 * Blast-radius diff: the pristine world law vs the patched one.
 *
 *   node tools/diff-law.mjs out-pristine/core/world.js out/core/world.js
 *
 * Reports every cell whose integer relief or classification moved, over the
 * whole 136x64 footprint. The hidden callers (src/game.ts, src/render/world.ts)
 * read stepsAtCell and kindAt, so this is the change's real reach.
 */
import { pathToFileURL } from "node:url";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const [aPath, bPath] = process.argv.slice(2);

const A = await import(pathToFileURL(join(root, aPath)).href);
const B = await import(pathToFileURL(join(root, bPath)).href);
const T = await import(pathToFileURL(join(root, "out/core/terrain.js")).href);
const { WORLD_W, WORLD_H, MARGIN_X, MARGIN_Z, VILLAGE_X, VILLAGE_Y } = T;

const a = new A.WorldHeightmap();
const b = new B.WorldHeightmap();

let stepDiff = 0, kindDiff = 0;
const cells = [];
for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
  for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
    const sa = a.stepsAtCell(gx, gy), sb = b.stepsAtCell(gx, gy);
    const ka = a.kindAt(gx, gy), kb = b.kindAt(gx, gy);
    if (sa !== sb) { stepDiff++; cells.push(`steps ${gx},${gy}: ${sa} -> ${sb}`); }
    if (ka !== kb) { kindDiff++; cells.push(`kind  ${gx},${gy}: ${ka} -> ${kb}`); }
  }
}
console.log(`footprint cells      ${(WORLD_W + MARGIN_X * 2) * (WORLD_H + MARGIN_Z * 2)}`);
console.log(`stepsAtCell moved    ${stepDiff}`);
console.log(`kindAt moved         ${kindDiff}`);
for (const c of cells.slice(0, 40)) console.log(`  ${c}`);
if (cells.length > 40) console.log(`  ... ${cells.length - 40} more`);

// Desert census views: the brief says "50 desert cells over the footprint";
// report the counts under each reading so the number in the case is sourced.
let raw = 0, kind = 0, inGrid = 0, westOfRiver = 0;
for (let gy = -MARGIN_Z; gy < WORLD_H + MARGIN_Z; gy++) {
  for (let gx = -MARGIN_X; gx < WORLD_W + MARGIN_X; gx++) {
    const steps = b.stepsAtCell(gx, gy);
    const fx = gx + 0.5, fz = gy + 0.5;
    const rule =
      b.warpSample(fx, fz) >= 0.25 && steps >= 6 && steps <= 9 &&
      Math.hypot(fx - VILLAGE_X, fz - VILLAGE_Y) >= 30;
    if (rule) raw++;
    if (b.kindAt(gx, gy) === "desert") {
      kind++;
      if (gx >= 0 && gx < WORLD_W && gy >= 0 && gy < WORLD_H) inGrid++;
      if (fx < b.constructor.name.length) { /* noop */ }
      if (gx < 66) westOfRiver++;
    }
  }
}
console.log(`desert rule cells     ${raw}`);
console.log(`desert kind cells     ${kind}`);
console.log(`  inside playable grid ${inGrid}`);
console.log(`  west of x=66         ${westOfRiver}`);
