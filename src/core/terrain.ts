/**
 * The web world's pinned spec and terrain vocabulary (v3).
 *
 * Everything here is shared by the world law (core/world.ts), the world
 * renderer (render/world.ts) and the game layer. The numbers are the
 * donor's own constants (godot/scripts/view/hd2d_heightmap.gd and
 * world_heightmap.gd) plus the web's two documented extensions: the
 * expanded playable grid and the village disc placed under the town.
 */

/** Donor sub-voxels per cell axis (Hd2dHeightmap.SUB). */
export const SUB = 8;
/** World units per relief step (Hd2dHeightmap.VOXEL). */
export const VOXEL = 0.125;
/** Global water table, in relief steps (WorldHeightmap.TABLE_STEPS). */
export const TABLE_STEPS = 4;
/** Relief step clamp (Hd2dHeightmap.MAX_STEPS). */
export const MAX_STEPS = 40;

/**
 * Playable grid: 68 x 32 cells = 2176 cells, exactly 4.00x the authored
 * 34 x 16 town (544 cells). The donor's margin ring (MARGIN_FRAC 0.5)
 * gives the vista footprint the law composes the rim mountains into.
 */
export const WORLD_W = 68;
export const WORLD_H = 32;
export const MARGIN_X = 34;
export const MARGIN_Z = 16;
export const FOOTPRINT_W = WORLD_W + MARGIN_X * 2;
export const FOOTPRINT_H = WORLD_H + MARGIN_Z * 2;

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

/**
 * Base face colour per kind, 0-255 RGB. The donor's slabs are greyscale
 * stone, so these are the web's own natural palette (authored here, no
 * new asset licences). The per-face shading law below is the donor's.
 */
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
/**
 * Daylight exposure of the donor's baked lighting law (TERRAIN_FS:
 * colour * (ambient + directional * max(dot(n, sun), 0))). The donor's
 * own floor is 0.30 for the dark Cistern interior; the open world needs
 * the same law at daylight strength.
 */
export const TERRAIN_AMBIENT = 0.62;
export const TERRAIN_DIRECTIONAL = 0.38;
/** Donor theme sun_dir in bake coords (x east, y north, z up). */
export const TERRAIN_SUN_DIR: readonly [number, number, number] = [0.35, -0.5, 0.79];

/** Open water surface colour (the ocean and every lake below the table). */
export const WATER_COLOR: readonly [number, number, number] = [54, 96, 142];
/** Lake/river bed colour seen through the translucent surface. */
export const WATER_FLOOR_COLOR: readonly [number, number, number] = [86, 104, 92];
