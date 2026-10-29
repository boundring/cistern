/**
 * Shared contract between the donor bake step and the app.
 *
 * `tools/bake-donors.mjs` generates `src/generated/donors.ts` implementing
 * exactly this shape; every module in `src/` imports data through these
 * types so the bake output and the app cannot drift apart silently.
 */

/** Baked voxel slab (assets/slabs/*.json, tools/tile_to_slab.py bake format). */
export interface SlabJson {
  /** Slab side in voxels (16 for every base-pack slab). */
  side: number;
  /** Bake thickness parameter; the volume's y extent is side + depth. */
  depth: number;
  /** "flat" | "dome" — bake-time profile; the volume already encodes it. */
  profile: string;
  /** Palette RGB triplets, 0-255. Volume value i maps to palette[i - 1]. */
  palette: [number, number, number][];
  /**
   * The bake volume flattened to bytes and base64-encoded (the raw
   * number[][][] literal would be ~1 MB of source per slab otherwise).
   * Index = (x * (side + depth) + y) * side + z, 0 = empty,
   * value i = palette[i - 1]. Decode with `slab.ts: decodeVolume`.
   */
  volumeB64: string;
  /** Bake-time greedy face count (stats only, not geometry). */
  quads: number;
}

/** Render layer a tile kind occupies (content/tiles.ron `layer`). */
export type Layer = "floor" | "structure" | "prop";

/** One tile asset row from content/tiles.ron. */
export interface TileAsset {
  /** Slab base name, e.g. "tile_floor"; looks up SLABS. */
  slab: string;
  layer: Layer;
}

/** Theme values transcribed from content/themes/reference.ron. */
export interface ThemeData {
  palette: Record<string, [number, number, number]>;
  /** post.fog_density */
  fogDensity: number;
  bloom: boolean;
  tonemap: boolean;
  /** density.deco_density, percent units (12.0). */
  decoDensity: number;
  /** lighting.directional_strength */
  directionalStrength: number;
  /** lighting.sun_dir */
  sunDir: [number, number, number];
  greeneryMult: number;
  conduitMult: number;
  streamMult: number;
}

/**
 * The generated donor bundle. `tools/bake-donors.mjs` emits
 * `src/generated/donors.ts` exporting one `DONORS: Donors`.
 */
export interface Donors {
  /** Slab JSON by base name ("tile_wall", "prop_star", ...). */
  slabs: Record<string, SlabJson>;
  /** content/tiles.ron tile rows (wire tile id -> slab + layer). */
  tiles: Record<string, TileAsset>;
  /** content/tiles.ron prop rows. */
  props: Record<string, TileAsset>;
  /** content/copy.ron rows (copy key -> display text). */
  copy: Record<string, string>;
  theme: ThemeData;
  /** Authored town template, 16 rows x 34 cols of glyph chars. */
  townRows: string[];
  /** Glyph -> wire tile id (town_map.gd GLYPH_TILES). */
  glyphTiles: Record<string, string>;
  /** 6 shop display names (town_map.gd SHOP_NAMES). */
  shopNames: string[];
  /** 6 shop fixture tile ids (town_map.gd SHOP_FIXTURES). */
  shopFixtures: string[];
  /** 6 shop interior cells (town_map.gd SHOP_INTERIOR_CELLS), [x, y]. */
  shopInteriorCells: [number, number][];
  /** Tile PNG data URIs (assets/tiles/*.png) keyed by tile id. */
  tilePng: Record<string, string>;
  /** Pinned constants from the donor sources. */
  constants: {
    /** TileTable.SCATTER_SEED */
    scatterSeed: number;
    /** TownState.PINNED_SEED */
    townSeed: number;
    /** town_map.gd TOWN_FLAVOR_KEY */
    townFlavorKey: number;
    /** voxel_slab_terrain.gd TINT_SALT */
    tintSalt: number;
  };
}
