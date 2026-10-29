import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ScatterHash, cellSeed, SCATTER_SEED } from "../out/core/scatter.js";

const here = dirname(fileURLToPath(import.meta.url));
const raw = readFileSync(join(here, "golden/scatter.txt"), "utf8");
const line = raw.split("\n").find((l) => l.startsWith("VECT_SCATTER "));
if (!line) throw new Error("missing VECT_SCATTER in tests/golden/scatter.txt");
const VECT_SCATTER = JSON.parse(line.slice("VECT_SCATTER ".length));

// JSON.parse rounds int64 cell_seed literals; keep the exact digits via regex.
const cellSeedStrs = [...line.matchAll(/"cell_seed":(-?\d+)/g)].map((m) => m[1]);

test("cellSeed matches VECT_SCATTER exactly; queries match per cell", () => {
  let k = 0; // golden row order: all floor identity 0 rows, then identity 1
  for (const [fidStr, rows] of Object.entries(VECT_SCATTER)) {
    const fid = Number(fidStr);
    for (const row of rows) {
      const want = BigInt(cellSeedStrs[k++]);
      assert.equal(
        cellSeed(row.gx, row.gy, fid),
        want,
        `cell_seed(${row.gx},${row.gy},floor ${fid})`,
      );
      const sh = new ScatterHash(fid);
      assert.equal(sh.presence(row.gx, row.gy, 0.12), row.presence_012, `presence 0.12 at ${row.gx},${row.gy}`);
      assert.equal(sh.presence(row.gx, row.gy, 0.5), row.presence_050, `presence 0.5 at ${row.gx},${row.gy}`);
      assert.equal(sh.variant(row.gx, row.gy, 3), row.variant_3, `variant 3 at ${row.gx},${row.gy}`);
      const j = sh.jitter(row.gx, row.gy);
      assert.ok(Math.abs(j.x - row.jitter[0]) <= 1e-9, `jitter.x at ${row.gx},${row.gy}: ${j.x} vs ${row.jitter[0]}`);
      assert.ok(Math.abs(j.y - row.jitter[1]) <= 1e-9, `jitter.y at ${row.gx},${row.gy}: ${j.y} vs ${row.jitter[1]}`);
    }
  }
  assert.equal(k, cellSeedStrs.length, "consumed every golden cell_seed row");
});

test("default seed is SCATTER_SEED and queries are pure per cell", () => {
  assert.equal(SCATTER_SEED, 0x0c157e2026);
  const a = new ScatterHash(0);
  const b = new ScatterHash(0, BigInt(SCATTER_SEED));
  for (const [gx, gy] of [[3, 7], [20, 11], [-4, 9]]) {
    assert.equal(a.presence(gx, gy, 0.5), b.presence(gx, gy, 0.5));
    assert.equal(a.variant(gx, gy, 3), b.variant(gx, gy, 3));
    const ja = a.jitter(gx, gy);
    const jb = b.jitter(gx, gy);
    assert.equal(ja.x, jb.x);
    assert.equal(ja.y, jb.y);
  }
});
