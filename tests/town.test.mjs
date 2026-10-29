import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { dressedTown, parseTown, keyed, TOWN_SEED, TOWN_FLAVOR_KEY } from "../out/core/town.js";

const here = dirname(fileURLToPath(import.meta.url));

// --- vendor extraction (honest: the test builds its donors from the .gd source) ---

const gd = readFileSync(join(here, "../vendor/cistern/scripts/sim/town_map.gd"), "utf8");
const block = (name, open, close) => {
  const m = gd.match(new RegExp(`const ${name}\\b[^=]*=\\s*\\${open}([\\s\\S]*?)\\n?${close}`));
  if (!m) throw new Error(`vendor town_map.gd: cannot locate const ${name}`);
  return m[1];
};
const unescapeGd = (s) => s.replace(/\\(.)/g, "$1");
const stringsOf = (body) =>
  [...body.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((m) => unescapeGd(m[1]));

const townRows = stringsOf(block("STARTER_TOWN_ROWS", "[", "\\]"));
const glyphTiles = Object.fromEntries(
  [...block("GLYPH_TILES", "{", "\\}").matchAll(/"((?:[^"\\]|\\.)*)":\s*"([^"]*)"/g)]
    .map((m) => [unescapeGd(m[1]), m[2]]),
);
const shopNames = stringsOf(block("SHOP_NAMES", "[", "\\]"));
const shopFixtures = stringsOf(block("SHOP_FIXTURES", "[", "\\]"));
const shopInteriorCells = [...block("SHOP_INTERIOR_CELLS", "[", "\\]").matchAll(/Vector2i\((\d+),\s*(\d+)\)/g)]
  .map((m) => [Number(m[1]), Number(m[2])]);

assert.equal(townRows.length, 16, "vendor rows extracted");
assert.equal(townRows.every((r) => r.length === 34), true, "vendor row width");
assert.equal(Object.keys(glyphTiles).length, 22, "glyph table extracted");
assert.equal(shopNames.length, 6, "shop names extracted");
assert.equal(shopFixtures.length, 6, "shop fixtures extracted");
assert.equal(shopInteriorCells.length, 6, "shop interiors extracted");

// donors-shaped input built from the vendor source (not the generated module).
const DONORS = { townRows, glyphTiles, shopNames, shopFixtures, shopInteriorCells };

// --- golden vector ---

const townTxt = readFileSync(join(here, "golden/town.txt"), "utf8");
const townLine = townTxt.split("\n").find((l) => l.startsWith("VECT_TOWN "));
if (!townLine) throw new Error("missing VECT_TOWN in tests/golden/town.txt");
const VECT_TOWN = JSON.parse(townLine.slice("VECT_TOWN ".length));
const goldenRows = VECT_TOWN.rows.map((r) => r.split("|").slice(0, -1));

test("keyed() sub-key derivation pins the documented constants", () => {
  assert.equal(TOWN_SEED, 0xc1577eed);
  assert.equal(TOWN_FLAVOR_KEY, (6 << 8) | 2);
  const a = keyed(TOWN_SEED, TOWN_FLAVOR_KEY);
  assert.equal(a >= 0n && a < 0x7fffffffffffffffn, true, "keyed result clamped to 63 bits");
  assert.equal(keyed(TOWN_SEED, TOWN_FLAVOR_KEY), a, "pure function of seed+key");
});

test("parseTown matches the vendor parse on the authored template", () => {
  const m = parseTown(townRows, glyphTiles, shopNames, shopFixtures, shopInteriorCells);
  assert.deepEqual([...m.spawn], VECT_TOWN.spawn);
  assert.deepEqual([...m.entrance], VECT_TOWN.entrance);
  assert.deepEqual([...m.well], VECT_TOWN.well);
  assert.deepEqual(m.shopDoors, VECT_TOWN.shop_doors.reduce((acc, v, i) => {
    if (i % 2 === 0) acc.push([v, VECT_TOWN.shop_doors[i + 1]]);
    return acc;
  }, []));
  assert.deepEqual(m.shopInteriors, shopInteriorCells);
  assert.equal(m.shopNames.join("|"), VECT_TOWN.shop_names.join("|"));
  assert.equal(m.shopFixtures.join("|"), VECT_TOWN.shop_fixtures.join("|"));
});

test("parseTown fails fast on broken templates", () => {
  assert.throws(() => parseTown([...townRows.slice(0, 15)], glyphTiles, shopNames, shopFixtures, shopInteriorCells), /expected 16 rows/);
  const badGlyph = townRows.map((r, i) => (i === 0 ? "Z" + r.slice(1) : r));
  assert.throws(() => parseTown(badGlyph, glyphTiles, shopNames, shopFixtures, shopInteriorCells), /unknown glyph 'Z'/);
  const noSpawn = townRows.map((r) => r.replace("@", "."));
  assert.throws(() => parseTown(noSpawn, glyphTiles, shopNames, shopFixtures, shopInteriorCells), /no '@' player start/);
});

test("dressedTown tiles match VECT_TOWN exactly", () => {
  const m = dressedTown(DONORS);
  assert.equal(m.width, VECT_TOWN.width);
  assert.equal(m.height, VECT_TOWN.height);
  const gotRows = [];
  for (let y = 0; y < m.height; y++) gotRows.push(m.tiles.slice(y * m.width, (y + 1) * m.width));
  assert.deepEqual(gotRows, goldenRows);
  // dressing never moves markers or opens new ids
  assert.deepEqual([...m.spawn], VECT_TOWN.spawn);
  assert.deepEqual([...m.entrance], VECT_TOWN.entrance);
  assert.deepEqual([...m.well], VECT_TOWN.well);
  assert.equal(new Set(m.tiles).size <= new Set(Object.values(glyphTiles)).size, true);
});

test("dressing is a pure function of the seed", () => {
  assert.equal(
    dressedTown(DONORS).tiles.join("|"),
    dressedTown(DONORS, TOWN_SEED).tiles.join("|"),
  );
  const other = dressedTown(DONORS, 12345);
  assert.equal(other.width, 34);
  assert.equal(other.height, 16);
});
