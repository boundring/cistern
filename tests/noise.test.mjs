import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { FastNoiseLite } from "../out/core/noise.js";

const here = dirname(fileURLToPath(import.meta.url));
const golden = readFileSync(join(here, "golden/noise.txt"), "utf8");

// Donor world_heightmap.gd _sibling_noise over TileTable.SCATTER_SEED
// (0x0C157E2026): salt -> frequency denominator + fractal octaves.
const SCATTER_SEED = 0x0c157e2026;
const CONFIGS = {
  WARP: { salt: 242, denom: 45.0, octaves: 2 },
  MTN: { salt: 243, denom: 64.0, octaves: 2 },
  PLATEAU: { salt: 244, denom: 52.0, octaves: 2 },
  RIDGE: { salt: 245, denom: 26.0, octaves: 3 },
  TERRACE: { salt: 246, denom: 30.0, octaves: 2 },
  HILL: { salt: 247, denom: 20.0, octaves: 4 },
};
// int(absi(SCATTER_SEED + salt) % 2147483647); operands < 2^53, exact.
const seedFor = (salt) => Math.abs(SCATTER_SEED + salt) % 2147483647;

// probe_noise.gd lattice: x = i * 1.7 + 0.3, y = j * 2.3 - 1.1, i/j in 0..11.
const LATTICE_N = 12;
const lattice = [];
for (let i = 0; i < LATTICE_N; i++) {
  for (let j = 0; j < LATTICE_N; j++) {
    lattice.push({ x: i * 1.7 + 0.3, y: j * 2.3 - 1.1 });
  }
}

const samples = golden
  .split("\n")
  .filter((line) => line.startsWith("NOISE "))
  .map((line) => {
    const [, tag, x, y, v] = line.split(" ");
    return { tag, x: Number(x), y: Number(y), v: Number(v) };
  });

test("golden parsed: 6 configs x 144 lattice samples", () => {
  assert.equal(samples.length, 6 * LATTICE_N * LATTICE_N);
  const tags = [...new Set(samples.map((s) => s.tag))];
  assert.deepEqual(tags.sort(), Object.keys(CONFIGS).sort());
});

test("golden coordinates match the rebuilt lattice", () => {
  tags: for (const tag of Object.keys(CONFIGS)) {
    const mine = samples.filter((s) => s.tag === tag);
    for (let k = 0; k < lattice.length; k++) {
      assert.ok(Math.abs(mine[k].x - lattice[k].x) <= 1e-9, `${tag}[${k}].x`);
      assert.ok(Math.abs(mine[k].y - lattice[k].y) <= 1e-9, `${tag}[${k}].y`);
    }
  }
});

test("ported FastNoiseLite matches the donor probe bit-exact", () => {
  let maxErr = 0;
  let bitExact = true;
  for (const s of samples) {
    const cfg = CONFIGS[s.tag];
    if (!cfg) throw new Error(`unexpected golden tag ${s.tag}`);
    const noise = new FastNoiseLite({
      seed: seedFor(cfg.salt),
      frequency: 1 / cfg.denom,
      octaves: cfg.octaves,
    });
    const got = noise.getNoise2D(s.x, s.y);
    assert.ok(Number.isFinite(got), `${s.tag} ${s.x} ${s.y} finite`);
    assert.ok(Math.abs(got - s.v) <= 1e-6, `${s.tag} ${s.x} ${s.y}: got ${got}, want ${s.v}`);
    // %.9g round-trips float32 exactly, so fround equality is bit-exactness
    // against the engine float32.
    if (Math.fround(got) !== Math.fround(s.v)) bitExact = false;
    maxErr = Math.max(maxErr, Math.abs(got - s.v));
    // Determinism: the same call twice returns the same number.
    assert.ok(Object.is(noise.getNoise2D(s.x, s.y), got), `${s.tag} ${s.x} ${s.y} deterministic`);
  }
  assert.ok(bitExact, "port drifted from the donor float32");
  console.log(`noise golden: max abs err vs printed donor value = ${maxErr}`);
});
