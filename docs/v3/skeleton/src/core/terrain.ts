/**
 * SKELETON -- no implementation. Target path: src/core/terrain.ts
 * Owning slice: orchestrator (frozen constants)
 *
 * Responsibility: own the world's pinned numeric spec and the terrain
 * vocabulary -- sub-voxel resolution, relief steps, the playable grid, the
 * vista margin ring, the footprint, the village disc centre, the town
 * rectangle, the TerrainKind union, the per-kind base colours and the baked
 * lighting law (ambient + directional sun + side shade) -- and nothing
 * else. It must NOT own the heightmap law, the noise, the renderer or the
 * game layer: other modules import these constants from here, so they are
 * never redefined elsewhere.
 *
 * This is the one FROZEN module of the v3 plan: it is already complete
 * apart from comments, so this stub carries every exported constant with
 * its real value and the TerrainKind union. The finished file is this file
 * plus documentation comments; no behaviour is added here.
 *
 * Signatures and values are verbatim from CONTRACT.md ("Frozen:
 * src/core/terrain.ts") and src/core/terrain.ts.
 */

/** Donor sub-voxels per cell axis (Hd2dHeightmap.SUB). */
export const SUB = 8;
/** World units per relief step (Hd2dHeightmap.VOXEL). */
export const VOXEL = 0.125;
/** Global water table, in relief steps (WorldHeightmap.TABLE_STEPS). */
export const TABLE_STEPS = 4;
/** Relief step clamp (Hd2dHeightmap.MAX_STEPS). */
export const MAX_STEPS = 40;

/** Playable grid: 68 x 32 cells = 4.00x the authored 34 x 16 town. */
export const WORLD_W = 68;
export const WORLD_H = 32;
export const MARGIN_X = 34;
export const MARGIN_Z = 16;
export const FOOTPRINT_W = 136;
export const FOOTPRINT_H = 64;

/** Village disc centre, in world cell coordinates (the town sits on it). */
export const VILLAGE_X = 34;
export const VILLAGE_Y = 16;
/** The authored town's origin in world cell coordinates (34 x 16). */
export const TOWN_X = 17;
export const TOWN_Y = 8;
export const TOWN_W = 34;
export const TOWN_H = 16;

/** Terrain classification of a world cell (the law's shape, web-side names). */
export type TerrainKind =
  | "plains"
  | "hills"
  | "plateau"
  | "mountain"
  | "rim"
  | "village"
  | "shore"
  | "desert"
  | "water";

/** Base face colour per kind, 0-255 RGB. */
export const TERRAIN_COLOR: Record<TerrainKind, readonly [number, number, number]> = {
  plains: [98, 134, 76],
  hills: [84, 118, 64],
  plateau: [142, 130, 104],
  mountain: [126, 126, 134],
  rim: [98, 98, 108],
  village: [150, 126, 96],
  shore: [176, 160, 118],
  desert: [198, 172, 112],
  water: [70, 104, 92],
};

/** Side faces read darker than tops: structural relief, no surface noise. */
export const TERRAIN_SIDE_SHADE = 0.72;
/** Baked lighting law: colour * (ambient + directional * max(dot(n, sun), 0)). */
export const TERRAIN_AMBIENT = 0.62;
export const TERRAIN_DIRECTIONAL = 0.38;
/** Donor theme sun_dir in bake coords (x east, y north, z up). */
export const TERRAIN_SUN_DIR: readonly [number, number, number] = [0.35, -0.5, 0.79];

/** Open water surface colour (the ocean and every lake below the table). */
export const WATER_COLOR: readonly [number, number, number] = [54, 96, 142];
/** Lake/river bed colour seen through the translucent surface. */
export const WATER_FLOOR_COLOR: readonly [number, number, number] = [86, 104, 92];
