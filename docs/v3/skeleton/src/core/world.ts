/**
 * SKELETON -- no implementation. Target path: src/core/world.ts
 * Owning slice: B -- core-world-law
 *
 * Responsibility: own the port of the donor's terrain law
 * (godot/scripts/view/world_heightmap.gd, iteration 3) as pure functions of
 * grid coordinates -- biome weight masks, macro composition (hills/plains,
 * ridged chains, terraced plateaus, rim ring, rift basins), the tectonic
 * cross-axis uplift, the global water table, the river and tributary carves,
 * the village flat and the parent's ring-hamlet flat -- plus the two
 * documented web-side extensions (the ocean band and the desert band) and
 * the ordered cell classification. It must NOT own the noise implementation
 * (it consumes slice A's FastNoiseLite), the constants (it imports
 * src/core/terrain.ts), the renderer or the game layer.
 *
 * Trim the port must apply: no engineered corridors (the donor's road/rail
 * grading is dropped), and the village disc relocated to VILLAGE_X /
 * VILLAGE_Y. Everything else is the donor's, verbatim.
 *
 * Precision note (measured against the donor): Godot's Vector2/Vector3
 * components are single-precision in a standard build, so the donor's axis
 * constants and its returned biome weights are float32 values, while
 * JavaScript doubles are used here. The two rounding points are the axis
 * constants themselves -- the donor stores TECTONIC_AXIS / AXIS_PERP in a
 * Vector2 (single-precision: 0.6000000238418579 for 0.6,
 * 0.800000011920929 for 0.8) -- and the returned weights at the Vector3
 * boundary (biome_weights returns a Vector3, also single-precision).
 * Rounding only the axes gets the biome error to ~1.5e-8; rounding only the
 * returned weights does not help, because the axes still shift the sample
 * coordinates. Both together bring the worst biome-weight error from
 * 1.4e-6 to ~5e-18 and the uplift error from 3.3e-8 to ~4e-18.
 * tectonicUplift reads biome_weights(fx, fz).rim, so it inherits the same
 * float32 rim value and is fixed by the same change -- no separate fix.
 *
 * Assertion caveat: rounding the returned weights to float32 makes them the
 * values the donor actually stores, but the golden prints them with %.17f,
 * so a float32 value re-read from the golden still differs from the port's
 * double by about half a float32 ULP (~1e-9 absolute on a 0..1 weight).
 * The ~5e-18 figure is the port value rounded to float32 against the
 * golden read as float32. Until the rounding is applied, the honest
 * assertion is a tolerance of 1e-5 for biomeWeights and 1e-6 for
 * tectonicUplift and warpSample -- the residuals the current port actually
 * shows (1.401e-6 and 3.329e-8) -- with exact equality for the integer
 * stepsAt points. Order 1e-7 becomes available only after the rounding
 * change lands.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice B"); the real
 * source spells the constructor defaults as WORLD_W / WORLD_H.
 */

import type { TerrainKind } from "./terrain.js";

export interface BiomeWeights { mtn: number; plateau: number; rim: number; }

export class WorldHeightmap {
  constructor(w?: number, h?: number) {   // defaults WORLD_W / WORLD_H
    throw new Error("not implemented: WorldHeightmap");
  }
  /** donor steps_at(sub-voxel coords) -> relief steps 0..MAX_STEPS */
  stepsAt(isx: number, isz: number): number {
    throw new Error("not implemented: WorldHeightmap.stepsAt");
  }
  /** relief steps at a cell centre */
  stepsAtCell(gx: number, gy: number): number {
    throw new Error("not implemented: WorldHeightmap.stepsAtCell");
  }
  /** donor _macro_steps(fx, fz) -> relief steps (float) */
  macroSteps(fx: number, fz: number): number {
    throw new Error("not implemented: WorldHeightmap.macroSteps");
  }
  /** donor biome_weights(fx, fz) */
  biomeWeights(fx: number, fz: number): BiomeWeights {
    throw new Error("not implemented: WorldHeightmap.biomeWeights");
  }
  /** donor tectonic_uplift(fx, fz) */
  tectonicUplift(fx: number, fz: number): number {
    throw new Error("not implemented: WorldHeightmap.tectonicUplift");
  }
  /** donor rift_bowl(fx, fz) */
  riftBowl(fx: number, fz: number): number {
    throw new Error("not implemented: WorldHeightmap.riftBowl");
  }
  /** the domain-warp noise sample (SALT_WARP), [-1, 1] -- the desert mask reads it */
  warpSample(fx: number, fz: number): number {
    throw new Error("not implemented: WorldHeightmap.warpSample");
  }
  /** water surface height in world units (donor table_height) */
  tableHeight(): number {
    throw new Error("not implemented: WorldHeightmap.tableHeight");
  }
  /** the village flat's height in world units (donor _village_base_h * VOXEL) */
  villageHeight(): number {
    throw new Error("not implemented: WorldHeightmap.villageHeight");
  }
  /** donor lake rule: playable ground below the water table */
  isWater(gx: number, gy: number): boolean {
    throw new Error("not implemented: WorldHeightmap.isWater");
  }
  /** web-side classification of a cell */
  kindAt(gx: number, gy: number): TerrainKind {
    throw new Error("not implemented: WorldHeightmap.kindAt");
  }
  /** water-table depth of a cell in steps (0 = dry) */
  waterDepth(gx: number, gy: number): number {
    throw new Error("not implemented: WorldHeightmap.waterDepth");
  }
}
/** donor WorldLevel.river_x */
export function riverX(z: number): number {
  throw new Error("not implemented: riverX");
}
/** donor WorldLevel.river_halfw */
export function riverHalfWidth(z: number): number {
  throw new Error("not implemented: riverHalfWidth");
}
