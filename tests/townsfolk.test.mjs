import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { dressedTown, TOWN_SEED, DIR8 } from "../out/core/town.js";
// Under test (v2): the ambient townsfolk port. Written BEFORE the
// implementation exists -- this file is the definition of done.
import {
  TownSim,
} from "../out/core/sim.js";
import {
  TOWNSFOLK_MIN_COUNT,
  TOWNSFOLK_MAX_COUNT,
  TOWNSFOLK_SLOW_SPEED,
  TOWNSFOLK_SLOW_ONE_IN,
} from "../out/core/townsfolk.js";

const here = dirname(fileURLToPath(import.meta.url));

// --- vendor extraction (same convention as town.test.mjs: the test builds
// --- its donors from the vendored .gd source, not the generated module) ---

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
    .map((m) => [unescapeGd(m[1]), unescapeGd(m[2])]),
);
const shopNames = stringsOf(block("SHOP_NAMES", "[", "\\]"));
const shopFixtures = stringsOf(block("SHOP_FIXTURES", "[", "\\]"));
const shopInteriorCells = [...block("SHOP_INTERIOR_CELLS", "[", "\\]").matchAll(/Vector2i\((\d+),\s*(\d+)\)/g)]
  .map((m) => [Number(m[1]), Number(m[2])]);

const DONORS = { townRows, glyphTiles, shopNames, shopFixtures, shopInteriorCells };
const town = dressedTown(DONORS);

// --- golden vector (tests/golden/townsfolk.txt, probe_townsfolk.gd over the
// --- donor's own TownState/Townsfolk: TownState.new() + 200 ambient ticks) ---

const tfTxt = readFileSync(join(here, "golden/townsfolk.txt"), "utf8");
const tfLine = tfTxt.split("\n").find((l) => l.startsWith("VECT_TOWNSFOLK "));
if (!tfLine) throw new Error("missing VECT_TOWNSFOLK in tests/golden/townsfolk.txt");
const VECT = JSON.parse(tfLine.slice("VECT_TOWNSFOLK ".length));
const goldenFolk = VECT.place.filter((p) => p.kind === "townsfolk");
const OPEN = new Set(["floor", "grass", "rubble", "soil"]);
const MARKERS = new Set([
  town.spawn.join(","), town.well.join(","), town.entrance.join(","),
  ...town.shopDoors.map((c) => c.join(",")),
]);

test("donor pacing constants pin the townsfolk.gd table", () => {
  assert.equal(TOWNSFOLK_MIN_COUNT, 6);
  assert.equal(TOWNSFOLK_MAX_COUNT, 10);
  assert.equal(TOWNSFOLK_SLOW_SPEED, 50);
  assert.equal(TOWNSFOLK_SLOW_ONE_IN, 2);
});

test("DIR8 carries the donor wire deltas", () => {
  assert.deepEqual(DIR8.n, [0, -1]);
  assert.deepEqual(DIR8.s, [0, 1]);
  assert.deepEqual(DIR8.e, [1, 0]);
  assert.deepEqual(DIR8.w, [-1, 0]);
});

test("placement is the pinned function of the seed: exact cells and speeds", () => {
  assert.equal(VECT.seed, TOWN_SEED, "probe ran at the pinned seed");
  const sim = new TownSim(town);
  const folk = sim.townsfolk();
  assert.equal(folk.length, goldenFolk.length, `count ${folk.length} != golden ${goldenFolk.length}`);
  assert.ok(folk.length >= TOWNSFOLK_MIN_COUNT && folk.length <= TOWNSFOLK_MAX_COUNT);
  folk.forEach((f, i) => {
    const g = goldenFolk[i];
    assert.deepEqual(
      { id: f.id, x: f.x, y: f.y, speed: f.speed },
      { id: g.id, x: g.x, y: g.y, speed: g.speed },
      `townsfolk #${i} drifted from the donor placement`,
    );
  });
  const seen = new Set();
  for (const f of folk) {
    assert.equal(OPEN.has(town.tiles[f.y * town.width + f.x]), true, `townsfolk on open tile at ${f.x},${f.y}`);
    assert.equal(MARKERS.has(`${f.x},${f.y}`), false, `townsfolk never on a marker cell (${f.x},${f.y})`);
    assert.equal(seen.has(`${f.x},${f.y}`), false, `townsfolk cells are distinct (${f.x},${f.y})`);
    seen.add(`${f.x},${f.y}`);
    assert.ok(f.speed === 100 || f.speed === TOWNSFOLK_SLOW_SPEED, `speed from the two-step table: ${f.speed}`);
  }
});

test("200-tick ambient transcript is byte-identical to the donor stream", () => {
  const sim = new TownSim(town);
  for (let i = 0; i < 200; i++) sim.tick();
  assert.equal(sim.events.length, VECT.events.length);
  for (let i = 0; i < VECT.events.length; i++) {
    assert.equal(sim.events[i], VECT.events[i], `event #${i} drifted from the donor transcript`);
  }
});

test("after the run everyone is inside, on legal ground, and nobody despawned", () => {
  const sim = new TownSim(town);
  for (let i = 0; i < 200; i++) sim.tick();
  const folk = sim.townsfolk();
  assert.equal(folk.length, goldenFolk.length, "townsfolk never despawn");
  for (const f of folk) {
    assert.ok(f.x >= 0 && f.y >= 0 && f.x < town.width && f.y < town.height, `in bounds: ${f.x},${f.y}`);
    const t = town.tiles[f.y * town.width + f.x];
    assert.notEqual(t, "wall");
    assert.notEqual(t, "stream_water");
  }
  const moved = sim.events.filter((e) => e.includes("entity_moved"));
  assert.ok(moved.length > 0, "ambient wander produces entity_moved events");
  const spawns = sim.events.filter((e) => e.includes("entity_spawn") && e.includes("kind=townsfolk"));
  assert.equal(spawns.length, folk.length, "one spawn event per townsfolk");
});
