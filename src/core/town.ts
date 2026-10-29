/**
 * The authored starter town (vendor/cistern/scripts/sim/town_map.gd): a
 * hand-authored 34x16 glyph template parsed fail-fast into wire tile ids,
 * plus the two quarantined seed draws — keyed template selection (one
 * draw, one template, kept for fidelity) and the FLAVOR plaza-grass pass.
 */

import type { Donors } from "../types/donors.js";
import { GodotRng } from "./rng.js";

/** town_map.gd TOWN_FLAVOR_KEY — stream 6, town role 2. */
export const TOWN_FLAVOR_KEY = (6 << 8) | 2;
/** TownState.PINNED_SEED. */
export const TOWN_SEED = 0xc1577eed;
/** town_state.gd DEFAULT_SPEED: one action per tick at the act threshold. */
export const DEFAULT_SPEED = 100;
/** The Dir8 wire strings (intent.rs vocabulary). */
export type Dir8 = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw";
/**
 * town_state.gd DIR8: (dx, dy) on the tile grid, y grows south, keyed by
 * the Dir8 wire string. The one piece of domain logic the wire vocabulary
 * carries -- shared by the sim and the townsfolk wander.
 */
export const DIR8: Record<Dir8, readonly [number, number]> = {
  n: [0, -1],
  ne: [1, -1],
  e: [1, 0],
  se: [1, 1],
  s: [0, 1],
  sw: [-1, 1],
  w: [-1, 0],
  nw: [-1, -1],
};
/** town_map.gd TEMPLATE_SELECT_KEY — stream 1, town role 2. */
const TEMPLATE_SELECT_KEY = (1 << 8) | 2;

const KEY_MIX = 0x6a09e667f3bcc909n;
const M63 = 0x7fffffffffffffffn;
const M64 = (1n << 64n) - 1n;

/** Signed 64-bit wraparound (GDScript ints). */
function i64(v: bigint): bigint {
  const u = v & M64;
  return u >= 1n << 63n ? u - (1n << 64n) : u;
}

/** town_map.gd keyed(): seed mixed with a sub-key, clamped to 63 bits. */
export function keyed(seed: number, key: number): bigint {
  return ((BigInt(seed) ^ i64(BigInt(key) * KEY_MIX)) & M63);
}

/** Coords are [x, y] tuples; tiles are row-major wire tile ids. */
export interface TownModel {
  width: number;
  height: number;
  tiles: string[];
  spawn: [number, number];
  entrance: [number, number];
  well: [number, number];
  shopDoors: [number, number][];
  shopInteriors: [number, number][];
  shopNames: string[];
  shopFixtures: string[];
}

const TEMPLATE_COLS = 34;
const TEMPLATE_ROWS = 16;
const FIXTURE_GLYPHS = ["=", "C", "Y", "D", "<", "A"];

function dup(glyph: string, x: number, y: number, what: string): Error {
  return new Error(`town template at ${x},${y}: '${glyph}' ${what} appears twice`);
}

/** Fail-fast port of TownMap.parse: never a fallback, a broken registry is a build bug. */
export function parseTown(
  rows: string[],
  glyphTiles: Record<string, string>,
  shopNames: string[],
  shopFixtures: string[],
  shopInteriorCells: [number, number][],
): TownModel {
  if (rows.length !== TEMPLATE_ROWS) {
    throw new Error(`town template: expected ${TEMPLATE_ROWS} rows, got ${rows.length}`);
  }
  for (let y = 0; y < TEMPLATE_ROWS; y++) {
    if (rows[y]!.length !== TEMPLATE_COLS) {
      throw new Error(`town template row ${y}: expected ${TEMPLATE_COLS} cols, got ${rows[y]!.length}`);
    }
  }

  const tiles: string[] = new Array(TEMPLATE_COLS * TEMPLATE_ROWS).fill("");
  let spawn: [number, number] = [-1, -1];
  let entrance: [number, number] = [-1, -1];
  let well: [number, number] = [-1, -1];
  const shopDoors: [number, number][] = [
    [-1, -1], [-1, -1], [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  ];
  const seenShops = new Set<string>();
  const seenFixtures = new Set<string>();

  for (let y = 0; y < TEMPLATE_ROWS; y++) {
    for (let x = 0; x < TEMPLATE_COLS; x++) {
      const glyph = rows[y]![x]!;
      const tile = glyphTiles[glyph];
      if (tile === undefined) throw new Error(`town template at ${x},${y}: unknown glyph '${glyph}'`);
      tiles[y * TEMPLATE_COLS + x] = tile;
      switch (glyph) {
        case "=":
        case "C":
        case "Y":
        case "D":
        case "<":
        case "A":
          if (seenFixtures.has(glyph)) throw dup(glyph, x, y, "fixture");
          seenFixtures.add(glyph);
          break;
        case "@":
          if (spawn[0] >= 0) throw dup("@", x, y, "player start");
          spawn = [x, y];
          break;
        case ">":
          if (entrance[0] >= 0) throw dup(">", x, y, "entrance");
          entrance = [x, y];
          break;
        case "o":
          if (well[0] >= 0) throw dup("o", x, y, "well");
          well = [x, y];
          break;
        case "1":
        case "2":
        case "3":
        case "4":
        case "5":
        case "6":
          if (seenShops.has(glyph)) throw dup(glyph, x, y, "shop");
          seenShops.add(glyph);
          shopDoors[Number(glyph) - 1] = [x, y];
          break;
      }
    }
  }

  if (spawn[0] < 0) throw new Error("town template: no '@' player start");
  if (entrance[0] < 0) throw new Error("town template: no '>' dungeon entrance");
  if (well[0] < 0) throw new Error("town template: no 'o' well");
  for (let id = 1; id <= 6; id++) {
    if (shopDoors[id - 1]![0] < 0) throw new Error(`town template: shop '${id}' missing`);
  }
  for (const glyph of FIXTURE_GLYPHS) {
    if (!seenFixtures.has(glyph)) throw new Error(`town template: fixture glyph '${glyph}' missing`);
  }

  if (shopInteriorCells.length !== 6) {
    throw new Error(`town template: expected 6 shop interiors, got ${shopInteriorCells.length}`);
  }
  for (let id = 1; id <= 6; id++) {
    const [cx, cy] = shopInteriorCells[id - 1]!;
    if (cx < 0 || cy < 0 || cx >= TEMPLATE_COLS || cy >= TEMPLATE_ROWS) {
      throw new Error(`town template: shop ${id} interior ${cx},${cy} is off-map`);
    }
    const fixture = shopFixtures[id - 1];
    if (fixture === undefined) throw new Error(`town template: shop ${id} has no fixture tile`);
    if (tiles[cy * TEMPLATE_COLS + cx] !== fixture) {
      throw new Error(
        `town template: shop ${id} interior ${cx},${cy} does not carry its fixture '${fixture}'`,
      );
    }
    for (let j = id + 1; j <= 6; j++) {
      const [jx, jy] = shopInteriorCells[j - 1]!;
      if (jx === cx && jy === cy) {
        throw new Error(`town template: shops ${id} and ${j} share interior ${cx},${cy}`);
      }
    }
    const [dx, dy] = shopDoors[id - 1]!;
    if (Math.abs(cx - dx) + Math.abs(cy - dy) !== 1) {
      throw new Error(
        `town template: shop ${id} interior ${cx},${cy} not adjacent to its door ${dx},${dy}`,
      );
    }
  }

  return {
    width: TEMPLATE_COLS,
    height: TEMPLATE_ROWS,
    tiles,
    spawn,
    entrance,
    well,
    shopDoors,
    shopInteriors: shopInteriorCells.map(([x, y]) => [x, y]),
    shopNames: [...shopNames],
    shopFixtures: [...shopFixtures],
  };
}

/** One keyed draw modulo the template count; one template, draw kept for fidelity. */
function templateChoice(seed: number): number {
  return new GodotRng(BigInt.asUintN(64, keyed(seed, TEMPLATE_SELECT_KEY))).randiRange(0, 0);
}

/** A cell qualifies when it and all 8 in-bounds neighbours are plain floor. */
function openPlaza(tiles: string[], width: number, height: number, x: number, y: number): boolean {
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const nx = x + dx;
      const ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) return false;
      if (tiles[ny * width + nx] !== "floor") return false;
    }
  }
  return true;
}

/** TownMap.dressed + _dress: the template, FLAVOR-dressed with plaza grass. */
export function dressedTown(donors: Donors, seed: number = TOWN_SEED): TownModel {
  templateChoice(seed);
  const m = parseTown(
    donors.townRows,
    donors.glyphTiles,
    donors.shopNames,
    donors.shopFixtures,
    donors.shopInteriorCells,
  );
  const flavor = new GodotRng(BigInt.asUintN(64, keyed(seed, TOWN_FLAVOR_KEY)));
  for (let y = 0; y < m.height; y++) {
    for (let x = 0; x < m.width; x++) {
      if (x === m.spawn[0] && y === m.spawn[1]) continue;
      if (m.tiles[y * m.width + x] !== "floor") continue;
      if (!openPlaza(m.tiles, m.width, m.height, x, y)) continue;
      if (flavor.randiRange(0, 6) === 0) m.tiles[y * m.width + x] = "grass";
    }
  }
  return m;
}
