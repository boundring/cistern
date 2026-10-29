// SKELETON -- no implementation. Target path: tests/noise.test.mjs
// Owning slice: A (core-noise-port), session S01
//
// Responsibility: own the golden test for the FastNoiseLite port -- it must
// compare the port against tests/golden/noise.txt bit-exactly, prove the port
// is deterministic, and prove that the seed and the octave count actually
// change the value (so a stubbed or constant noise cannot pass). It must NOT
// own the port itself, nor any other slice's tests.
//
// Golden file: tests/golden/noise.txt, baked by tools/godot-probe/probe_noise.gd
// (one line per sample: "NOISE <tag> <x> <y> <value>"; 6 configs x 144
// lattice points = 864 rows). The donor probe prints String.num_scientific,
// so the file round-trips the donor's float32 samples exactly.
//
// IMPORT PATH: the module under test is the COMPILED build, out/core/noise.js.
// This skeleton lives at docs/v3/skeleton/tests/, so the real build is four
// levels up: "../../../../out/core/noise.js" -- when this file is promoted to
// tests/noise.test.mjs the import becomes the static
//   import { FastNoiseLite } from "../out/core/noise.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build:core` has produced out/ (out/ is gitignored build
// output and does not exist in a fresh checkout).
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const mod = await import("../../../../out/core/noise.js").catch(() => null);

const here = dirname(fileURLToPath(import.meta.url));
const GOLDEN = join(here, "..", "..", "..", "..", "tests", "golden", "noise.txt");

/** The donor golden; empty when the file is not present yet. */
function readGolden() {
  try {
    return readFileSync(GOLDEN, "utf8");
  } catch {
    return "";
  }
}

const samples = readGolden()
  .split("\n")
  .filter((line) => line.startsWith("NOISE "))
  .map((line) => {
    const [, tag, x, y, v] = line.split(" ");
    return { tag, x: Number(x), y: Number(y), v: Number(v) };
  });

// Donor sibling noises (world_heightmap.gd): salt -> frequency denominator and
// fractal octaves; seed = abs(SCATTER_SEED + salt) % 2147483647 with
// SCATTER_SEED = 0x0C157E2026 (measured seeds 360587568..360587573).
const SCATTER_SEED = 0x0c157e2026;
const CONFIGS = {
  WARP: { salt: 242, denom: 45.0, octaves: 2, seed: 360587568 },
  MTN: { salt: 243, denom: 64.0, octaves: 2, seed: 360587569 },
  PLATEAU: { salt: 244, denom: 52.0, octaves: 2, seed: 360587570 },
  RIDGE: { salt: 245, denom: 26.0, octaves: 3, seed: 360587571 },
  TERRACE: { salt: 246, denom: 30.0, octaves: 2, seed: 360587572 },
  HILL: { salt: 247, denom: 20.0, octaves: 4, seed: 360587573 },
};
const seedFor = (salt) => Math.abs(SCATTER_SEED + salt) % 2147483647;

test("ported FastNoiseLite matches the donor probe bit-exact", { todo: "not implemented — S01" }, () => {
  // 864 golden samples; the port must reproduce the donor's float32 exactly.
  // Measured against the current golden: 864/864 rows equal as doubles
  // (Math.fround equal too), max abs error 0.
  const actual = undefined; // TODO(S01): mod.FastNoiseLite({seed, frequency, octaves}).getNoise2D(x, y) per golden row
  assert.equal(actual, -0.031104128807783127, "first golden row: NOISE WARP 0.3 -1.1");
});

test("the port is deterministic across repeated calls", { todo: "not implemented — S01" }, () => {
  // The same (seed, frequency, octaves, x, y) must return the identical number
  // on every call: strict equality between two calls on one instance.
  const actual = undefined; // TODO(S01): two calls of getNoise2D(x, y) on one instance
  assert.equal(actual, -0.031104128807783127, "NOISE WARP 0.3 -1.1 repeated");
});

test("octave count changes the value", { todo: "not implemented — S01" }, () => {
  // WARP (seed 360587568, frequency 1/45) at (0.3, -1.1):
  //   octaves 2 -> -0.031104128807783127
  //   octaves 3 ->  0.019175102934241295
  const actual = undefined; // TODO(S01): the same sample at octaves 2 and octaves 3
  assert.equal(actual, 0.019175102934241295, "WARP octaves 3 at (0.3, -1.1)");
});

test("seed changes the value", { todo: "not implemented — S01" }, () => {
  // At (0.3, -1.1) with frequency 1/45 and octaves 2:
  //   seed 360587568 (salt 242, WARP) -> -0.031104128807783127
  //   seed 360587569 (salt 243, MTN) ->  0.04789840802550316
  const actual = undefined; // TODO(S01): the same sample under two different seeds
  assert.equal(actual, 0.04789840802550316, "MTN seed at (0.3, -1.1)");
});
