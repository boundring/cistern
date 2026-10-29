/**
 * The open-world relief law, ported WHOLE from the donor:
 *   godot/scripts/view/world_heightmap.gd (iteration 3) over its parent
 *   godot/scripts/view/hd2d_heightmap.gd.
 * A pure function of (grid coords, pinned seeds). The two documented trims
 * (contract):
 *   1. NO engineered corridors — the donor's road/rail grading grid, the
 *      corridor damping of the tectonic uplift and the shore guarantee it
 *      drives are dropped (the web build has no roads). stepsAt() here is
 *      the donor's steps_at with those three pieces removed.
 *   2. The village disc sits at VILLAGE_X/VILLAGE_Y (the town sits on it)
 *      instead of the donor's 96x96-world WorldLevel.VILLAGE (44.5, 58.5).
 * Everything else — constants, salts, basins, river functions, channels,
 * the parent's ring-hamlet town flat at town_center_for(w, h, margin_z) —
 * is the donor's, verbatim.
 *
 * Web-side extensions live ONLY in the cell-level helpers below (never
 * inside stepsAt, which stays donor-identical):
 *   - Ocean: the outermost TWO cells of the footprint on every side
 *     (gx <= -MARGIN_X+1 or gx >= WORLD_W+MARGIN_X-2 or
 *      gy <= -MARGIN_Z+1 or gy >= WORLD_H+MARGIN_Z-2)
 *     render as ocean floor: stepsAtCell returns TABLE_STEPS - 2 there. The
 *     sea itself is a plane at the table height, drawn by the renderer.
 *   - Desert (deterministic thresholds, chosen here): a cell is desert when
 *     warpSample(fx,fz) >= 0.25 (the donor's warp noise, high), stepsAtCell
 *     is 6..9 (low relief: above the shore band, below the plateau floor)
 *     and the cell centre is >= 30 cells from the village centre (far from
 *     the starter area). Over the 136x64 footprint this paints a 133-cell
 *     band west of the river bend plus east-bank patches.
 *   - kindAt classification order (first match wins): water (below the
 *     table) > shore (at/just above the table) > village (inside the
 *     village flat) > desert > mountain (biome mtn > 0.5) > plateau
 *     (biome plateau > 0.5) > rim (biome rim > 0.5 AND steps >= 11, so the
 *     low rim stays grassland) > hills (steps > 6) > plains.
 */
import { FastNoiseLite } from "./noise.js";
import {
  SUB,
  VOXEL,
  TABLE_STEPS,
  MAX_STEPS,
  WORLD_W,
  WORLD_H,
  MARGIN_X,
  MARGIN_Z,
  VILLAGE_X,
  VILLAGE_Y,
} from "./terrain.js";
import type { TerrainKind } from "./terrain.js";
import { SCATTER_SEED } from "./scatter.js";

export interface BiomeWeights {
  mtn: number;
  plateau: number;
  rim: number;
}

// ---- donor constants (world_heightmap.gd) ----
const VILLAGE_FLAT_RADIUS = 13.0;
const VILLAGE_FLAT_CORE = 6.0;
const RIVER_CARVE = 5.0; // valley half-width, cell units
const TECTONIC_AXIS = { x: 0.6, y: -0.8 };
const AXIS_PERP = { x: 0.8, y: 0.6 };
const AXIS_ANISO_U = 0.55; // freq multiplier ALONG the axis
const AXIS_ANISO_V = 1.2; // freq multiplier ACROSS the axis
const BASIN_ASPECT = 1.7;
const UPLIFT_STEPS = 2.2;
const UPLIFT_SPAN = 52.0;
/** Rift lake basins (cell centres, radius/depth), axis-elongated. */
const BASINS = [
  { cx: 15, cy: 75, r: 11.5, d: 4.2 },
  { cx: 64, cy: 20, r: 10.0, d: 3.2 },
  { cx: 72, cy: 67, r: 9.0, d: 3.0 },
] as const;
/** Salt offsets over SCATTER_SEED — world demo family (240..249). */
const SALT_WARP = 242;
const SALT_MTN = 243;
const SALT_PLATEAU = 244;
const SALT_RIDGE = 245;
const SALT_TERRACE = 246;
const SALT_HILL = 247;
// Parent (hd2d_heightmap.gd) town-flat discipline, unchanged.
const TOWN_FLAT_RADIUS = 5.0;
const TOWN_FLAT_CORE = 2.0;
// Web desert thresholds (see file comment).
const DESERT_WARP_MIN = 0.25;
const DESERT_MAX_STEPS = 9;
const DESERT_VILLAGE_DIST = 30.0;
/** Relief steps above which the rim ring reads as bare stone, not grassland. */
const RIM_STONE_STEPS = 11;

/** WorldLevel.channels() ported verbatim (donor 96x96-world polylines). */
const CHANNELS = [
  {
    pts: [
      [16, 74],
      [22, 66],
      [30, 62],
      [40, 61],
      [52, 62],
      [58, 63.8],
      [60.5, 64.2],
    ],
    halfw: 1.05,
  },
  {
    pts: [
      [63, 20],
      [69, 20.5],
      [76, 21.5],
      [79, 23],
    ],
    halfw: 0.85,
  },
  {
    pts: [
      [71, 67],
      [66, 67],
      [62.5, 66],
      [60, 66],
    ],
    halfw: 0.85,
  },
] as const;

/** Donor WorldLevel.river_x: the river runs north-south on the east side. */
export function riverX(z: number): number {
  return 66.0 + 10.0 * Math.sin(0.045 * z + 0.8) + 4.0 * Math.sin(0.013 * z + 2.0);
}

/** Donor WorldLevel.river_halfw. */
export function riverHalfWidth(z: number): number {
  return 2.0 + 0.8 * Math.sin(0.031 * z + 1.3);
}

function clamp(x: number, lo: number, hi: number): number {
  return Math.min(Math.max(x, lo), hi);
}

/** Godot lerpf: a + (b - a) * t. */
function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** Godot smoothstep (edge0 < edge1 here always). */
function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
  return t * t * (3.0 - 2.0 * t);
}

/** Vector2(fx, fz).distance_to(Vector2(ox, oz)): sqrt of squared legs. */
function dist(fx: number, fz: number, ox: number, oz: number): number {
  const dx = fx - ox;
  const dz = fz - oz;
  return Math.sqrt(dx * dx + dz * dz);
}

/** donor: int(absi(SCATTER_SEED + salt) % 2147483647). */
function siblingSeed(salt: number): number {
  return Math.abs(SCATTER_SEED + salt) % 2147483647;
}

export class WorldHeightmap {
  private readonly pw: number;
  private readonly ph: number;
  private readonly mx: number;
  private readonly mz: number;
  private readonly townX: number;
  private readonly townY: number;
  private readonly townBaseH: number;
  // Mutable because the donor's _init orders the town base BEFORE the
  // village lands (the damping then measures from the origin) — our
  // relocation mirrors that order exactly.
  private villageX: number;
  private villageY: number;
  private readonly villageBaseH: number;
  private readonly warp: FastNoiseLite;
  private readonly mtn: FastNoiseLite;
  private readonly plateau: FastNoiseLite;
  private readonly ridge: FastNoiseLite;
  private readonly terr: FastNoiseLite;
  private readonly hill: FastNoiseLite;

  constructor(w: number = WORLD_W, h: number = WORLD_H) {
    this.pw = w;
    this.ph = h;
    this.mx = Math.max(1, Math.round(w * 0.5));
    this.mz = Math.max(1, Math.round(h * 0.5));
    this.warp = new FastNoiseLite({ seed: siblingSeed(SALT_WARP), frequency: 1.0 / 45.0, octaves: 2 });
    this.mtn = new FastNoiseLite({ seed: siblingSeed(SALT_MTN), frequency: 1.0 / 64.0, octaves: 2 });
    this.plateau = new FastNoiseLite({ seed: siblingSeed(SALT_PLATEAU), frequency: 1.0 / 52.0, octaves: 2 });
    this.ridge = new FastNoiseLite({ seed: siblingSeed(SALT_RIDGE), frequency: 1.0 / 26.0, octaves: 3 });
    this.terr = new FastNoiseLite({ seed: siblingSeed(SALT_TERRACE), frequency: 1.0 / 30.0, octaves: 2 });
    this.hill = new FastNoiseLite({ seed: siblingSeed(SALT_HILL), frequency: 1.0 / 20.0, octaves: 4 });
    this.townX = w * 0.5;
    this.townY = h + this.mz * 0.55;
    // Donor order: town base is sampled while the village disc still sits
    // at the origin (damping = 1 there); the relocation happens after.
    this.villageX = 0;
    this.villageY = 0;
    this.townBaseH = this.macroSteps(this.townX, this.townY);
    // Trim 2: the village disc sits under the town.
    this.villageX = VILLAGE_X;
    this.villageY = VILLAGE_Y;
    // The village never sits in a floodplain: clamp above the shore band.
    this.villageBaseH = Math.max(this.macroSteps(VILLAGE_X, VILLAGE_Y), TABLE_STEPS + 2.0);
  }

  /** donor _edge_norm: 0 at the footprint centre, 1 at the playable bound. */
  private edgeNorm(fx: number, fz: number): number {
    return clamp(
      Math.max(
        (Math.abs(fx - this.pw * 0.5) / (this.mx + this.pw)) * 2.0,
        (Math.abs(fz - this.ph * 0.5) / (this.mz + this.ph)) * 2.0,
      ),
      0.0,
      1.0,
    );
  }

  /** donor biome_weights: domain-warped biome masks, village-damped. */
  biomeWeights(fx: number, fz: number): BiomeWeights {
    const w1 = this.warp.getNoise2D(fx, fz);
    const w2 = this.warp.getNoise2D(fx + 91.3, fz - 47.7);
    const wx = fx + 34.0 * w1;
    const wz = fz + 34.0 * w2;
    // Anisotropic sample frame: chains elongate along the tectonic axis.
    const u = wx * TECTONIC_AXIS.x + wz * TECTONIC_AXIS.y;
    const v = wx * AXIS_PERP.x + wz * AXIS_PERP.y;
    const m01 = (this.mtn.getNoise2D(u * AXIS_ANISO_U, v * AXIS_ANISO_V) + 1.0) * 0.5;
    const p01 = (this.plateau.getNoise2D(wx, wz) + 1.0) * 0.5;
    let wM = smoothstep(0.52, 0.88, m01);
    let wP = smoothstep(0.58, 0.9, p01) * (1.0 - wM);
    // Village environs stay open: plains/hills for the starter area.
    const damp = smoothstep(10.0, 30.0, dist(fx, fz, this.villageX, this.villageY));
    wM *= damp;
    wP *= damp;
    const wR = smoothstep(0.66, 1.02, this.edgeNorm(fx, fz));
    return { mtn: wM, plateau: wP, rim: wR };
  }

  /** donor tectonic_uplift: cross-axis tilt, fading under the rim belt. */
  tectonicUplift(fx: number, fz: number): number {
    const v = fx * AXIS_PERP.x + fz * AXIS_PERP.y;
    return UPLIFT_STEPS * clamp(v / UPLIFT_SPAN, -1.0, 1.0) * (1.0 - this.biomeWeights(fx, fz).rim);
  }

  /** donor rift_bowl: deepest basin bowl value at a point (0 = outside). */
  riftBowl(fx: number, fz: number): number {
    let best = 0.0;
    for (const b of BASINS) {
      const rx = fx - b.cx;
      const rz = fz - b.cy;
      const du = (rx * TECTONIC_AXIS.x + rz * TECTONIC_AXIS.y) / (b.r * Math.sqrt(BASIN_ASPECT));
      const dv = ((rx * AXIS_PERP.x + rz * AXIS_PERP.y) * Math.sqrt(BASIN_ASPECT)) / b.r;
      const e = Math.sqrt(du * du + dv * dv);
      best = Math.max(best, 1.0 - smoothstep(0.55, 1.0, e));
    }
    return best;
  }

  /** donor _macro_steps: the blended macro relief composition, in steps. */
  macroSteps(fx: number, fz: number): number {
    const bw = this.biomeWeights(fx, fz);
    const w1 = this.warp.getNoise2D(fx, fz);
    const w2 = this.warp.getNoise2D(fx + 91.3, fz - 47.7);
    const wx = fx + 34.0 * w1;
    const wz = fz + 34.0 * w2;
    const u = wx * TECTONIC_AXIS.x + wz * TECTONIC_AXIS.y;
    const v = wx * AXIS_PERP.x + wz * AXIS_PERP.y;
    const h01 = (this.hill.getNoise2D(wx, wz) + 1.0) * 0.5;
    // Corridor trim: the donor multiplies the uplift by
    // (1 - min(corridor_damp, 0.85)); with no corridors the factor is 1.
    const uplift = this.tectonicUplift(fx, fz);
    const hills = 3.0 + h01 * 6.0 + uplift; // rolling plains and hills
    const r = 1.0 - Math.abs(this.ridge.getNoise2D(u * AXIS_ANISO_U, v * AXIS_ANISO_V));
    const mtn = 10.0 + r * r * 24.0; // ridged chains, 10..34 steps
    const t01 = (this.terr.getNoise2D(u * AXIS_ANISO_U, v * AXIS_ANISO_V) + 1.0) * 0.5;
    const t = 7.0 + t01 * 9.0; // undulating plateau, 7..16 steps
    const q = Math.floor(t / 3.0) * 3.0;
    const plateau = lerp(t, q, 0.6); // terraced with soft risers
    let h = lerp(hills, plateau, bw.plateau);
    h = lerp(h, mtn, bw.mtn);
    // Hilly grassland ring rising into rim mountains at the edge.
    const rim = 12.0 + h01 * 10.0;
    h = lerp(h, Math.max(h, rim), bw.rim * 0.9);
    // Rift lake basins: smooth depressions elongated along the axis.
    for (const b of BASINS) {
      const rx = fx - b.cx;
      const rz = fz - b.cy;
      const du = (rx * TECTONIC_AXIS.x + rz * TECTONIC_AXIS.y) / (b.r * Math.sqrt(BASIN_ASPECT));
      const dv = ((rx * AXIS_PERP.x + rz * AXIS_PERP.y) * Math.sqrt(BASIN_ASPECT)) / b.r;
      const e = Math.sqrt(du * du + dv * dv);
      const bowl = 1.0 - smoothstep(0.55, 1.0, e);
      h -= b.d * bowl;
      // Graben floor: water in the core, faulted shoulder, fades past the rim.
      const fwgt = 1.0 - smoothstep(1.0, 1.3, e);
      if (fwgt > 0.0) {
        const floorH = TABLE_STEPS - 0.8 + smoothstep(0.6, 1.2, e) * 10.0;
        h = Math.min(h, lerp(h, floorH, fwgt));
      }
    }
    return h;
  }

  /** donor steps_at (corridors/shore trimmed): relief steps 0..MAX_STEPS. */
  stepsAt(isx: number, isz: number): number {
    const fx = isx / SUB;
    const fz = isz / SUB;
    let h = this.macroSteps(fx, fz);
    // Ring-hamlet flat (vista town, parent discipline unchanged).
    const d = dist(fx, fz, this.townX, this.townY);
    if (d < TOWN_FLAT_RADIUS) {
      h = lerp(this.townBaseH, h, clamp((d - TOWN_FLAT_CORE) / (TOWN_FLAT_RADIUS - TOWN_FLAT_CORE), 0.0, 1.0));
    }
    // Village flat.
    const dv = dist(fx, fz, this.villageX, this.villageY);
    if (dv < VILLAGE_FLAT_RADIUS) {
      h = lerp(this.villageBaseH, h, clamp((dv - VILLAGE_FLAT_CORE) / (VILLAGE_FLAT_RADIUS - VILLAGE_FLAT_CORE), 0.0, 1.0));
    }
    // River valley carve: bathtub bed below the table, smooth banks.
    const dr = Math.abs(fx - riverX(fz));
    if (dr < RIVER_CARVE) {
      const k = clamp(
        (dr - riverHalfWidth(fz)) / (RIVER_CARVE - riverHalfWidth(fz)),
        0.0,
        1.0,
      );
      h = lerp(this.riverBedH(fz), h, k * k * (3.0 - 2.0 * k));
    }
    // Tributary channels (basin outlets) carve below the table.
    h = this.channelCarve(fx, fz, h);
    // donor roundi is half-away-from-zero; Math.round differs only on
    // negatives, which clampi/clamp to 0 identically either way.
    return clamp(Math.round(h), 0, MAX_STEPS);
  }

  /** Relief steps at a cell centre, with the web ocean band forced below the table. */
  stepsAtCell(gx: number, gy: number): number {
    if (
      gx <= -MARGIN_X + 1 ||
      gx >= WORLD_W + MARGIN_X - 2 ||
      gy <= -MARGIN_Z + 1 ||
      gy >= WORLD_H + MARGIN_Z - 2
    ) {
      return TABLE_STEPS - 2;
    }
    return this.stepsAt(gx * SUB + SUB / 2, gy * SUB + SUB / 2);
  }

  /** Water surface height, world units (one level for river, lakes, sea). */
  tableHeight(): number {
    return TABLE_STEPS * VOXEL;
  }

  /** The village flat's height in world units (donor _village_base_h). */
  villageHeight(): number {
    return this.villageBaseH * VOXEL;
  }

  /** donor lake rule: playable ground below the water table. */
  isWater(gx: number, gy: number): boolean {
    return this.stepsAtCell(gx, gy) <= TABLE_STEPS - 1;
  }

  /** Water-table depth of a cell in steps (0 = dry). */
  waterDepth(gx: number, gy: number): number {
    return Math.max(0, TABLE_STEPS - this.stepsAtCell(gx, gy));
  }

  /** Web-side classification of a cell (order documented in the file comment). */
  kindAt(gx: number, gy: number): TerrainKind {
    const steps = this.stepsAtCell(gx, gy);
    if (steps <= TABLE_STEPS - 1) return "water";
    if (steps <= TABLE_STEPS + 1) return "shore";
    const fx = gx + 0.5;
    const fz = gy + 0.5;
    if (dist(fx, fz, VILLAGE_X, VILLAGE_Y) < VILLAGE_FLAT_RADIUS) return "village";
    const bw = this.biomeWeights(fx, fz);
    if (
      this.warpSample(fx, fz) >= DESERT_WARP_MIN &&
      steps <= DESERT_MAX_STEPS &&
      dist(fx, fz, VILLAGE_X, VILLAGE_Y) >= DESERT_VILLAGE_DIST
    ) {
      return "desert";
    }
    if (bw.mtn > 0.5) return "mountain";
    if (bw.plateau > 0.5) return "plateau";
    // The donor's rim is a "hilly grassland ring rising into rim mountains":
    // only the high part of the ring is bare stone, the low part stays green.
    if (bw.rim > 0.5 && steps >= RIM_STONE_STEPS) return "rim";
    if (steps > 6) return "hills";
    return "plains";
  }

  /** The domain-warp noise sample (SALT_WARP), [-1, 1] — the desert mask reads it. */
  warpSample(fx: number, fz: number): number {
    return this.warp.getNoise2D(fx, fz);
  }

  /** donor _river_bed_h: the river bed, pinned below the table. */
  private riverBedH(fz: number): number {
    return Math.min(this.macroSteps(riverX(fz), fz) - 1.8, TABLE_STEPS - 2.5);
  }

  /** donor _poly_project: (total length, arc length at closest point, distance). */
  private polyProject(
    fx: number,
    fz: number,
    pts: readonly (readonly [number, number])[],
  ): [number, number, number] {
    let bestD = 1e9;
    let bestS = 0.0;
    let walked = 0.0;
    for (let i = 0; i < pts.length - 1; i++) {
      const ax = pts[i][0];
      const ay = pts[i][1];
      const abx = pts[i + 1][0] - ax;
      const aby = pts[i + 1][1] - ay;
      const l2 = abx * abx + aby * aby;
      const t = clamp(((fx - ax) * abx + (fz - ay) * aby) / l2, 0.0, 1.0);
      const cpx = ax + abx * t;
      const cpy = ay + aby * t;
      const d = Math.sqrt((fx - cpx) * (fx - cpx) + (fz - cpy) * (fz - cpy));
      if (d < bestD) {
        bestD = d;
        bestS = walked + Math.sqrt(l2) * t;
      }
      walked += Math.sqrt(l2);
    }
    return [walked, bestS, bestD];
  }

  /** donor _channel_carve: flat wet core, smooth banks, carve only lowers. */
  private channelCarve(fx: number, fz: number, h: number): number {
    let out = h;
    for (const ch of CHANNELS) {
      const [total, s, d] = this.polyProject(fx, fz, ch.pts);
      const halfw = ch.halfw;
      if (d >= halfw * 1.6) continue;
      const bed = lerp(TABLE_STEPS - 1.1, TABLE_STEPS - 2.4, s / total);
      if (d <= halfw) {
        out = Math.min(out, bed);
      } else if (bed < out) {
        const k = (d - halfw) / (halfw * 0.6);
        out = lerp(bed, out, k * k * (3.0 - 2.0 * k));
      }
    }
    return out;
  }
}
