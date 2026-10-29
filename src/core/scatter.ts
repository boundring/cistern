/**
 * The scatter-hash law (vendor/cistern/scripts/view/scatter_hash.gd):
 * every query reseeds a fresh GodotRng from a per-cell FNV-style position
 * hash, so decoration is a pure function of the cell and floor identity —
 * never iteration-order dependent.
 */

import { GodotRng, godotStringHash } from "./rng.js";

/** TileTable.SCATTER_SEED. */
export const SCATTER_SEED = 0x0c157e2026;

const M64 = (1n << 64n) - 1n;
const FNV_PRIME = 0x100000001b3n;

/** Signed 64-bit wraparound (GDScript ints). */
function i64(v: bigint): bigint {
  const u = v & M64;
  return u >= 1n << 63n ? u - (1n << 64n) : u;
}

/** Per-cell RNG seed: signed int64, may be negative. */
export function cellSeed(gx: number, gy: number, floorIdentity: number, seed: bigint = BigInt(SCATTER_SEED)): bigint {
  let h = i64(seed);
  h = i64(h * FNV_PRIME + BigInt(Math.abs(gx)));
  h = i64(h * FNV_PRIME + BigInt(Math.abs(gy)));
  h = i64(h * FNV_PRIME + BigInt(floorIdentity));
  return i64(h ^ (h >> 29n));
}

export class ScatterHash {
  private readonly floorIdentity: number;
  private readonly seed: bigint;

  constructor(floorIdentity: number, seed: bigint = BigInt(SCATTER_SEED)) {
    this.floorIdentity = floorIdentity;
    this.seed = seed;
  }

  private rngFor(gx: number, gy: number): GodotRng {
    return new GodotRng(BigInt.asUintN(64, cellSeed(gx, gy, this.floorIdentity, this.seed)));
  }

  presence(gx: number, gy: number, density: number): boolean {
    return this.rngFor(gx, gy).randf() < density;
  }

  variant(gx: number, gy: number, n: number): number {
    if (n <= 0) return 0;
    return this.rngFor(gx, gy).randiRange(0, n - 1);
  }

  jitter(gx: number, gy: number): { x: number; y: number } {
    const rng = this.rngFor(gx, gy);
    return { x: rng.randfRange(-0.5, 0.5), y: rng.randfRange(-0.5, 0.5) };
  }
}

/** TintTable-style kind salt: salt*131 + |hash(id)| % 10007. */
export function kindHash(id: string, salt: number): number {
  return salt * 131 + Math.abs(godotStringHash(id) % 10007);
}
