import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { GodotRng, godotStringHash } from "../out/core/rng.js";

const here = dirname(fileURLToPath(import.meta.url));
const golden = readFileSync(join(here, "golden/rng.txt"), "utf8");
const vect = (prefix) => {
  const line = golden.split("\n").find((l) => l.startsWith(prefix));
  if (!line) throw new Error(`missing ${prefix.trim()} in tests/golden/rng.txt`);
  return JSON.parse(line.slice(prefix.length));
};

const VECT_RNG = vect("VECT_RNG ");
const VECT_STRHASH = vect("VECT_STRHASH ");

const FLOAT_KINDS = new Set(["randf", "randf_range"]);
const DRAW = {
  randi: (r) => r.randi(),
  randf: (r) => r.randf(),
  randi_range_0_2: (r) => r.randiRange(0, 2),
  randi_range_0_6: (r) => r.randiRange(0, 6),
  randf_range: (r) => r.randfRange(-0.5, 0.5),
};

test("GodotRng sequences match VECT_RNG (fresh rng per sequence)", () => {
  for (const [seedStr, seq] of Object.entries(VECT_RNG)) {
    const seed = BigInt(seedStr);
    for (const [kind, expected] of Object.entries(seq)) {
      const rng = new GodotRng(seed);
      const draw = DRAW[kind];
      if (!draw) throw new Error(`unexpected golden kind ${kind}`);
      expected.forEach((want, i) => {
        const got = draw(rng);
        if (FLOAT_KINDS.has(kind)) {
          assert.ok(
            Math.abs(got - want) <= 1e-9,
            `seed ${seedStr} ${kind}[${i}]: got ${got}, want ${want}`,
          );
        } else {
          assert.equal(got, want, `seed ${seedStr} ${kind}[${i}]`);
        }
      });
    }
  }
});

test("godotStringHash matches VECT_STRHASH", () => {
  for (const [id, want] of Object.entries(VECT_STRHASH)) {
    assert.equal(godotStringHash(id), want, `hash of '${id}'`);
  }
});
