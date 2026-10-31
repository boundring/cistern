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

// --- the three canonical cases the escalation review named ----------------
//
// The v3-core-noise-port escalation review (ESCALATION-REVIEW.md, section
// "v3-core-noise-port -> PARK") recorded that this file "carries 3 cases and
// is missing the canonical `the port is deterministic across repeated calls`,
// `octave count changes the value` and `seed changes the value`". The names
// and the expected values come from docs/v3/TEST-SPEC.md section 1 (the
// frozen contract table) and from the fill item's SPEC, which names the same
// four canonical cases.
//
// Every expected value below is either a row of this repo's donor golden
// (tests/golden/noise.txt, baked by tools/godot-probe/probe_noise.gd) or the
// value the frozen contract table pins for the WARP config. Nothing is
// invented: the golden carries the WARP lattice point (0.3, -1.1) with
// octaves 2, and the contract table pins the octaves-3 and the second-seed
// samples of the same config.

/** The golden row of one tag closest to a lattice point. */
function rowAt(tag, x, y) {
  let best = null;
  for (const s of samples) {
    if (s.tag !== tag) continue;
    const d = Math.abs(s.x - x) + Math.abs(s.y - y);
    if (best === null || d < best.d) best = { s, d };
  }
  return best;
}

const WARP = CONFIGS.WARP;
const WARP_FREQUENCY = 1 / WARP.denom;
// The golden row of the WARP config at the lattice point (0.3, -1.1).
const WARP_HIT = rowAt("WARP", 0.3, -1.1);
// The contract's pinned samples (TEST-SPEC section 1, table row 3 and 4):
// WARP at (0.3, -1.1) with octaves 3, and the same frequency and octaves
// with the MTN seed.
const WARP_OCTAVES_3 = 0.019175102934241295;
const OTHER_SEED = 0.04789840802550316;

test("the port is deterministic across repeated calls", () => {
  assert.ok(
    WARP_HIT !== null && WARP_HIT.d < 1e-9,
    "the golden must carry the WARP lattice point (0.3, -1.1)",
  );

  const noise = new FastNoiseLite({
    seed: seedFor(WARP.salt),
    frequency: WARP_FREQUENCY,
    octaves: WARP.octaves,
  });
  const first = noise.getNoise2D(0.3, -1.1);
  const second = noise.getNoise2D(0.3, -1.1);
  assert.equal(first, second, "two calls on one instance must be strictly equal");

  // A constant or stubbed port is self-consistent but wrong: the repeated
  // value must also be the donor's own sample.
  assert.equal(
    Math.fround(first),
    Math.fround(WARP_HIT.s.v),
    `the repeated call must equal the donor golden value ${WARP_HIT.s.v}`,
  );

  // A second instance built from the same options agrees with the first.
  const twin = new FastNoiseLite({
    seed: seedFor(WARP.salt),
    frequency: WARP_FREQUENCY,
    octaves: WARP.octaves,
  });
  assert.equal(twin.getNoise2D(0.3, -1.1), first, "two instances agree");
});

test("octave count changes the value", () => {
  const two = new FastNoiseLite({
    seed: seedFor(WARP.salt),
    frequency: WARP_FREQUENCY,
    octaves: 2,
  }).getNoise2D(0.3, -1.1);
  const three = new FastNoiseLite({
    seed: seedFor(WARP.salt),
    frequency: WARP_FREQUENCY,
    octaves: 3,
  }).getNoise2D(0.3, -1.1);

  assert.notEqual(two, three, "the octave count must change the sample");
  assert.equal(
    Math.fround(two),
    Math.fround(WARP_HIT.s.v),
    `octaves 2 must equal the donor golden value ${WARP_HIT.s.v}`,
  );
  assert.equal(
    Math.fround(three),
    Math.fround(WARP_OCTAVES_3),
    `octaves 3 must be ${WARP_OCTAVES_3}`,
  );
});

test("seed changes the value", () => {
  const a = new FastNoiseLite({
    seed: seedFor(WARP.salt),
    frequency: WARP_FREQUENCY,
    octaves: 2,
  }).getNoise2D(0.3, -1.1);
  const b = new FastNoiseLite({
    seed: seedFor(CONFIGS.MTN.salt),
    frequency: WARP_FREQUENCY,
    octaves: 2,
  }).getNoise2D(0.3, -1.1);

  assert.notEqual(a, b, "the seed must change the sample");
  assert.equal(
    Math.fround(a),
    Math.fround(WARP_HIT.s.v),
    `seed ${seedFor(WARP.salt)} must equal the donor golden value ${WARP_HIT.s.v}`,
  );
  assert.equal(
    Math.fround(b),
    Math.fround(OTHER_SEED),
    `seed ${seedFor(CONFIGS.MTN.salt)} must be ${OTHER_SEED}`,
  );
});
