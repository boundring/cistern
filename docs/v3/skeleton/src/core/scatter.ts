/**
 * SKELETON -- no implementation. Target path: src/core/scatter.ts
 * Owning slice: donor hash-scatter (already ported in the repo; the world
 * renderer consumes it unchanged)
 *
 * Responsibility: own the donor's hash-scatter law
 * (vendor/cistern/scripts/view/scatter_hash.gd) -- the per-cell FNV-style
 * position hash, the fresh-RNG-per-query reseeding, the presence test, the
 * variant choice and the jitter -- so that decoration is a pure function of
 * the cell and a per-class floor identity, never of iteration order. It must
 * NOT own densities, biome bands, the renderer, the world law or the game
 * layer.
 *
 * Signatures are taken from src/core/scatter.ts (this module is not frozen
 * in CONTRACT.md; it is donor truth and must not be reshaped).
 */

/** TileTable.SCATTER_SEED. */
export const SCATTER_SEED = 0x0c157e2026;

/** Per-cell RNG seed: signed int64, may be negative. */
export function cellSeed(gx: number, gy: number, floorIdentity: number, seed?: bigint): bigint {
  throw new Error("not implemented: cellSeed");
}

export class ScatterHash {
  constructor(floorIdentity: number, seed?: bigint) {
    throw new Error("not implemented: ScatterHash");
  }
  presence(gx: number, gy: number, density: number): boolean {
    throw new Error("not implemented: ScatterHash.presence");
  }
  variant(gx: number, gy: number, n: number): number {
    throw new Error("not implemented: ScatterHash.variant");
  }
  jitter(gx: number, gy: number): { x: number; y: number } {
    throw new Error("not implemented: ScatterHash.jitter");
  }
}

/** TintTable-style kind salt: salt*131 + |hash(id)| % 10007. */
export function kindHash(id: string, salt: number): number {
  throw new Error("not implemented: kindHash");
}
