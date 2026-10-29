// Bake the vendored Cistern donor copies into src/generated/donors.ts.
// Node ESM, no dependencies. Run: npm run bake
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const DONOR = "vendor/cistern";
const DEST = "src/generated/donors.ts";

function fail(msg) {
  throw new Error(`bake-donors: ${msg}`);
}

function read(rel) {
  try {
    return readFileSync(join(ROOT, rel), "utf8");
  } catch {
    return fail(`donor file missing: ${rel}`);
  }
}

// Unescape a GDScript string literal body (the escapes actually legal there).
function unescapeGd(body, what) {
  let out = "";
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c !== "\\") {
      out += c;
      continue;
    }
    const n = body[++i];
    if (n === "n") out += "\n";
    else if (n === "t") out += "\t";
    else if (n === "r") out += "\r";
    else if (n === '"') out += '"';
    else if (n === "'") out += "'";
    else if (n === "\\") out += "\\";
    else if (n === "u") {
      const hex = body.slice(i + 1, i + 5);
      if (!/^[0-9a-fA-F]{4}$/.test(hex)) fail(`${what}: bad \\u escape`);
      out += String.fromCharCode(parseInt(hex, 16));
      i += 4;
    } else fail(`${what}: unsupported escape \\${n}`);
  }
  return out;
}

// Capture the first balanced bracket group at or after `open` (inclusive).
// Donor literals carry no brackets inside strings.
function extractBalanced(src, open, what) {
  const start = src.indexOf(open);
  if (start < 0) fail(`${what} not found`);
  // `open` may already end with the opening bracket (e.g. "tiles: {").
  let i = "{[(".includes(open[open.length - 1]) ? start + open.length - 1 : start + open.length;
  for (;;) {
    while (i < src.length && !"{[(".includes(src[i])) i++;
    if (i >= src.length) fail(`${what}: no bracket after ${JSON.stringify(open)}`);
    const openIdx = i;
    const openCh = src[i];
    const closeCh = { "{": "}", "(": ")", "[": "]" }[openCh];
    let depth = 0;
    let j = i;
    for (; j < src.length; j++) {
      if (src[j] === openCh) depth++;
      else if (src[j] === closeCh && --depth === 0) break;
    }
    if (j >= src.length) fail(`${what}: unbalanced ${openCh}`);
    // Skip GDScript type parameters (Array[String], Array[Vector2i]).
    if (openCh === "[" && /^[A-Za-z0-9_]*$/.test(src.slice(openIdx + 1, j).trim())) {
      i = j + 1;
      continue;
    }
    return src.slice(openIdx, j + 1);
  }
}

// Evaluate a GDScript const integer expression (digits, hex, arithmetic).
function constInt(src, decl, file) {
  const m = src.match(new RegExp(`const\\s+${decl}\\s*:\\s*int\\s*=\\s*([^\\n#]+)`));
  if (!m) fail(`${file}: const ${decl} not found`);
  const expr = m[1].trim();
  if (!/^[-+~^|&()\s<>*/%0-9a-fA-Fx]+$/.test(expr) || !/[0-9a-fA-F]/.test(expr)) {
    fail(`${file}: const ${decl} is not a plain integer expression: ${expr}`);
  }
  // eslint-disable-next-line no-new-func -- vetted charset, trusted vendored donor
  return Function(`"use strict"; return (${expr});`)();
}

// Strip // line comments, respecting double-quoted strings (RON donors).
function stripRonComments(src, file) {
  let out = "";
  let inStr = false;
  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      out += c;
      if (c === "\\") out += src[++i] ?? fail(`${file}: dangling string escape`);
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') {
      inStr = true;
      out += c;
    } else if (c === "/" && src[i + 1] === "/") {
      while (i < src.length && src[i] !== "\n") i++;
    } else out += c;
  }
  return out;
}

// ---------------------------------------------------------------- town_map.gd
const townSrc = read(`${DONOR}/scripts/sim/town_map.gd`);
const townRows = [...extractBalanced(townSrc, "const STARTER_TOWN_ROWS", "town_map.gd: STARTER_TOWN_ROWS").matchAll(/"((?:\\.|[^"\\])*)"/g)]
  .map((m) => unescapeGd(m[1], "STARTER_TOWN_ROWS row"));
if (townRows.length !== 16) fail(`STARTER_TOWN_ROWS: expected 16 rows, got ${townRows.length}`);
for (const [y, row] of townRows.entries()) {
  if (row.length !== 34) fail(`STARTER_TOWN_ROWS row ${y}: expected 34 cols, got ${row.length}`);
}

const glyphBlock = extractBalanced(townSrc, "const GLYPH_TILES", "town_map.gd: GLYPH_TILES");
const glyphTiles = {};
for (const m of glyphBlock.matchAll(/"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"/g)) {
  glyphTiles[unescapeGd(m[1], "GLYPH_TILES key")] = unescapeGd(m[2], "GLYPH_TILES value");
}
if (Object.keys(glyphTiles).length === 0) fail("GLYPH_TILES: no entries parsed");
for (const [y, row] of townRows.entries()) {
  for (const ch of row) {
    if (!(ch in glyphTiles)) fail(`STARTER_TOWN_ROWS row ${y}: glyph ${JSON.stringify(ch)} missing from GLYPH_TILES`);
  }
}

function stringArray(decl) {
  const block = extractBalanced(townSrc, `const ${decl}`, `town_map.gd: ${decl}`);
  const rows = [...block.matchAll(/"((?:\\.|[^"\\])*)"/g)].map((m) => unescapeGd(m[1], decl));
  if (rows.length !== 6) fail(`${decl}: expected 6 entries, got ${rows.length}`);
  return rows;
}
const shopNames = stringArray("SHOP_NAMES");
const shopFixtures = stringArray("SHOP_FIXTURES");

const shopInteriorCells = [...extractBalanced(townSrc, "const SHOP_INTERIOR_CELLS", "town_map.gd: SHOP_INTERIOR_CELLS").matchAll(/Vector2i\((\d+),\s*(\d+)\)/g)]
  .map((m) => [Number(m[1]), Number(m[2])]);
if (shopInteriorCells.length !== 6) fail(`SHOP_INTERIOR_CELLS: expected 6 entries, got ${shopInteriorCells.length}`);

// ------------------------------------------------------------- pinned seeds
// SCATTER_SEED lives in TileTable; the vendored godot-probe stub carries the
// same pinned literal and is the in-repo witness.
const stubSrc = read("tools/godot-probe/tile_table_stub.gd");
const scatterSeed = constInt(stubSrc, "SCATTER_SEED", "tile_table_stub.gd");
const townFlavorKey = constInt(townSrc, "TOWN_FLAVOR_KEY", "town_map.gd");
// Not vendored; pinned upstream values (cistern godot/scripts/sim/town_state.gd
// TownState.PINNED_SEED, godot/scripts/view/voxel_slab_terrain.gd TINT_SALT).
// The golden town vector (probe_town.gd dressed(0xC1577EED)) cross-checks the seed.
const townSeed = 0xc1577eed;
const tintSalt = 112;

// ------------------------------------------------------------------ tiles.ron
const tilesRon = stripRonComments(read(`${DONOR}/content/tiles.ron`), "tiles.ron");
function ronTable(decl) {
  const block = extractBalanced(tilesRon, `${decl}: {`, `tiles.ron: ${decl} table`);
  const rows = {};
  for (const m of block.matchAll(/"([^"]+)"\s*:\s*\(\s*slab:\s*Some\("([^"]+)"\)\s*,\s*layer:\s*(\w+)\s*\)/g)) {
    rows[m[1]] = { slabPath: m[2], layer: m[3] };
  }
  if (Object.keys(rows).length === 0) fail(`tiles.ron: ${decl} table has no rows`);
  return rows;
}
const tilesRows = ronTable("tiles");
const propsRows = ronTable("props");

// ---------------------------------------------------------- slabs + tile PNGs
const slabDir = join(ROOT, DONOR, "assets/slabs");
const slabs = {};
for (const f of readdirSync(slabDir).sort()) {
  if (!f.endsWith(".json")) continue;
  const name = f.replace(/\.json$/, "");
  const raw = JSON.parse(readFileSync(join(slabDir, f), "utf8"));
  for (const key of ["side", "depth", "profile", "palette", "volume", "quads"]) {
    if (!(key in raw)) fail(`slab ${f}: missing key "${key}"`);
  }
  if (!Number.isInteger(raw.side) || !Number.isInteger(raw.depth)) fail(`slab ${f}: side/depth must be integers`);
  if (!Array.isArray(raw.palette) || raw.palette.length === 0) fail(`slab ${f}: empty palette`);
  const yExtent = raw.side + raw.depth;
  const flat = Buffer.alloc(raw.side * yExtent * raw.side);
  let o = 0;
  // Donor layout is volume[x][y][z] (y runs side+deep); the SlabJson index
  // law (x * (side + depth) + y) * side + z flattens it without reordering.
  for (const column of raw.volume) {
    if (!Array.isArray(column) || column.length !== yExtent) fail(`slab ${f}: volume x-column must hold ${yExtent} rows`);
    for (const row of column) {
      if (!Array.isArray(row) || row.length !== raw.side) fail(`slab ${f}: volume row must hold ${raw.side} cells`);
      for (const v of row) {
        if (!Number.isInteger(v) || v < 0 || v > raw.palette.length) fail(`slab ${f}: volume value out of palette range`);
        flat[o++] = v;
      }
    }
  }
  slabs[name] = {
    side: raw.side,
    depth: raw.depth,
    profile: raw.profile,
    palette: raw.palette,
    volumeB64: flat.toString("base64"),
    quads: raw.quads,
  };
}
if (Object.keys(slabs).length === 0) fail("no slab JSON files found");

function slabKey(slabPath) {
  const key = slabPath.replace(/^slabs\//, "").replace(/\.json$/, "");
  if (!(key in slabs)) fail(`tiles.ron: slab "${slabPath}" has no baked JSON`);
  return key;
}
const tiles = {};
for (const [id, row] of Object.entries(tilesRows)) {
  if (row.layer !== "floor" && row.layer !== "structure") fail(`tiles.ron: tile "${id}" has layer "${row.layer}" (expected floor|structure)`);
  tiles[id] = { slab: slabKey(row.slabPath), layer: row.layer };
}
const props = {};
for (const [id, row] of Object.entries(propsRows)) {
  if (row.layer !== "prop") fail(`tiles.ron: prop "${id}" has layer "${row.layer}" (expected prop)`);
  props[id] = { slab: slabKey(row.slabPath), layer: row.layer };
}

const tilePng = {};
for (const f of readdirSync(join(ROOT, DONOR, "assets/tiles")).sort()) {
  if (!f.endsWith(".png")) continue;
  const bytes = readFileSync(join(ROOT, DONOR, "assets/tiles", f));
  tilePng[f.replace(/\.png$/, "")] = `data:image/png;base64,${bytes.toString("base64")}`;
}
if (Object.keys(tilePng).length === 0) fail("no tile PNG files found");

// ------------------------------------------------------------------ copy.ron
const copySrc = stripRonComments(read(`${DONOR}/content/copy.ron`), "copy.ron");
let copy;
try {
  // RON tolerates a trailing comma on the last row; strict JSON does not.
  copy = JSON.parse(copySrc.replace(/,(\s*[}\]])/g, "$1"));
} catch (e) {
  fail(`copy.ron: not JSON after comment strip: ${e.message}`);
}
if (Object.keys(copy).length === 0) fail("copy.ron: no rows");

// ------------------------------------------------------------ reference.ron
const themeSrc = stripRonComments(read(`${DONOR}/content/themes/reference.ron`), "reference.ron");
function ronBlock(decl) {
  return extractBalanced(themeSrc, `${decl}: (`, `reference.ron: ${decl} block`);
}
function num(block, key, file) {
  const m = block.match(new RegExp(`${key}:\\s*(-?[\\d.]+)`));
  if (!m) fail(`reference.ron: ${file} key "${key}" not found`);
  return Number(m[1]);
}
function bool(block, key) {
  const m = block.match(new RegExp(`${key}:\\s*(true|false)`));
  if (!m) fail(`reference.ron: post key "${key}" not found`);
  return m[1] === "true";
}
const palette = {};
for (const m of ronBlock("palette").matchAll(/(\w+)\s*:\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/g)) {
  palette[m[1]] = [Number(m[2]), Number(m[3]), Number(m[4])];
}
if (Object.keys(palette).length === 0) fail("reference.ron: palette block has no rows");
const post = ronBlock("post");
const lighting = ronBlock("lighting");
const density = ronBlock("density");
const sunMatch = lighting.match(/sun_dir:\s*\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)/);
if (!sunMatch) fail('reference.ron: lighting key "sun_dir" not found');

const donors = {
  slabs,
  tiles,
  props,
  copy,
  theme: {
    palette,
    fogDensity: num(post, "fog_density", "post"),
    bloom: bool(post, "bloom"),
    tonemap: bool(post, "tonemap"),
    decoDensity: num(density, "deco_density", "density"),
    directionalStrength: num(lighting, "directional_strength", "lighting"),
    sunDir: [Number(sunMatch[1]), Number(sunMatch[2]), Number(sunMatch[3])],
    greeneryMult: num(lighting, "greenery_mult", "lighting"),
    conduitMult: num(lighting, "conduit_mult", "lighting"),
    streamMult: num(lighting, "stream_mult", "lighting"),
  },
  townRows,
  glyphTiles,
  shopNames,
  shopFixtures,
  shopInteriorCells,
  tilePng,
  constants: { scatterSeed, townSeed, townFlavorKey, tintSalt },
};

const out = [
  "// GENERATED by tools/bake-donors.mjs -- do not edit; run `npm run bake`.",
  'import type { Donors } from "../types/donors.js";',
  "",
  `export const DONORS: Donors = ${JSON.stringify(donors, null, 2)};`,
  "",
].join("\n");
mkdirSync(dirname(join(ROOT, DEST)), { recursive: true });
writeFileSync(join(ROOT, DEST), out);
console.log(
  `bake-donors: wrote ${DEST} (` +
    `${Object.keys(slabs).length} slabs, ${Object.keys(tiles).length} tiles, ${Object.keys(props).length} props, ` +
    `${Object.keys(copy).length} copy rows, ${townRows.length}x34 town, ${Object.keys(tilePng).length} tile PNGs)`
);
