/**
 * Godot 4.7 RandomNumberGenerator port: PCG32 with Godot's seeding
 * sequence, bit-exact against tests/golden/rng.txt (headless Godot 4.7.2
 * probe). All 64-bit state is BigInt; every emitted value is a JS number.
 */

const MULT = 6364136223846793005n;
const PCG_DEFAULT_INC_64 = 1442695040888963407n;
const M64 = (1n << 64n) - 1n;
const M32 = 0xFFFFFFFFn;

export class GodotRng {
  private s = 0n;
  private inc = 0n;

  /** int64 or uint64 seed, wrapped to uint64 like Godot's `seed` setter. */
  constructor(seed: bigint | number) {
    // pcg32_srandom_r(state=seed, initseq=PCG_DEFAULT_INC_64).
    this.inc = ((PCG_DEFAULT_INC_64 << 1n) | 1n) & M64;
    this.step();
    this.s = (this.s + (BigInt.asUintN(64, BigInt(seed)) & M64)) & M64;
    this.step();
  }

  /** pcg32_random_r: one XSH-RR output; advances the LCG state. */
  private step(): number {
    const old = this.s;
    this.s = (old * MULT + this.inc) & M64;
    const x = (((old >> 18n) ^ old) >> 27n) & M32;
    const rot = (old >> 59n) & 31n;
    // rotor with rot===0 degenerating to identity ((32-0)&31 === 0).
    return Number(((x >> rot) | (x << ((32n - rot) & 31n))) & M32);
  }

  /** uint32 output as a JS number. */
  randi(): number {
    return this.step();
  }

  /** float32 in [0,1): Godot's split-proto/exponent recipe. */
  randf(): number {
    const proto = this.step();
    if (proto === 0) return 0;
    const sig = (this.step() | 0x80000001) >>> 0;
    return Math.fround(Math.fround(sig) * Math.pow(2, -32 - Math.clz32(proto)));
  }

  /** pcg32_boundedrand_r with rejection sampling. */
  randiRange(from: number, to: number): number {
    if (from > to) throw new Error(`randi_range: from ${from} is greater than to ${to}`);
    const bound = to - from + 1;
    const threshold = ((0 - bound) >>> 0) % bound;
    for (;;) {
      const r = this.step();
      if (r >= threshold) return from + (r % bound);
    }
  }

  /** C++ `randf() * (p_to - p_from) + p_from` with float32 rounding. */
  randfRange(from: number, to: number): number {
    return Math.fround(Math.fround(Math.fround(this.randf()) * Math.fround(to - from)) + Math.fround(from));
  }
}

/** djb2 over Unicode code points, masked to uint32 per step. */
export function godotStringHash(s: string): number {
  let h = 5381;
  for (const ch of s) h = (h * 33 + ch.codePointAt(0)!) >>> 0;
  return h;
}
