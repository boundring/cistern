/**
 * SKELETON -- no implementation. Target path: src/core/noise.ts
 * Owning slice: A -- core-noise-port
 *
 * Responsibility: own the port of Godot's FastNoiseLite (the donor's noise
 * engine: TYPE_SIMPLEX_SMOOTH, FBM fractal, lacunarity 2.0, gain 0.5) as a
 * float32-faithful TypeScript class, so that the world law reads noise
 * samples identical to the donor's. It must NOT own the heightmap law, the
 * biome composition, the world extensions, the renderer or the game layer;
 * it exposes exactly one noise primitive and nothing else.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice A").
 */

export interface NoiseOptions {
  seed: number;          // Godot FastNoiseLite seed (0..2147483647)
  frequency: number;     // cycles per unit, as the donor sets it (1.0/45.0 etc.)
  octaves: number;       // fractal octaves (FBM)
}

export class FastNoiseLite {
  constructor(opts: NoiseOptions) {
    throw new Error("not implemented: FastNoiseLite");
  }
  /** Godot get_noise_2d(x, y) -> [-1, 1]; float32-identical to the donor. */
  getNoise2D(x: number, y: number): number {
    throw new Error("not implemented: FastNoiseLite.getNoise2D");
  }
}
