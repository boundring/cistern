/**
 * v3-core-town-map — the cistern overlay on the port's town map module.
 *
 * The module under test is src/core/town.ts, imported from the compiled
 * build (out/core/town.js). HNGH_FILL_MODULE points at the file the fill
 * funnel wrote, so the same suite can also run against a workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/town.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  TOWN_SEED,
  TOWN_FLAVOR_KEY,
  DEFAULT_SPEED,
  DIR8,
  parseTown,
  CISTERN_NETWORK_KINDS,
  cisternCellAt,
  cisternNeighbours,
  cisternFlood,
  cisternConnectedTanks,
  cisternManifoldLive,
  cisternPipeLive,
  cisternHasOre,
} = await import(modulePath);

const GRID_3X2 = {
  width: 3,
  height: 2,
  cells: ["pipe", "toilet", "tank", "ore", null, "manifold"],
};
const GRID_PIPE_MANIFOLD_TANK = { width: 3, height: 1, cells: ["pipe", "manifold", "tank"] };
const GRID_PIPE_TANK_TANK = { width: 3, height: 1, cells: ["pipe", "tank", "tank"] };

/** Flood result as a plain object, order-independent, Map or object alike. */
function floodEntries(flood) {
  const entries = flood instanceof Map ? [...flood.entries()] : Object.entries(flood);
  return Object.fromEntries(entries.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
}

test("cistern cell kinds are a closed vocabulary", () => {
  assert.deepEqual([...CISTERN_NETWORK_KINDS], ["pipe", "toilet", "tank"]);
});

test("cell lookup is row-major and bounds safe", () => {
  assert.equal(cisternCellAt(GRID_3X2, 0, 0), "pipe");
  assert.equal(cisternCellAt(GRID_3X2, 1, 0), "toilet");
  assert.equal(cisternCellAt(GRID_3X2, 2, 0), "tank");
  assert.equal(cisternCellAt(GRID_3X2, 0, 1), "ore");
  assert.equal(cisternCellAt(GRID_3X2, 1, 1), null);
  assert.equal(cisternCellAt(GRID_3X2, 2, 1), "manifold");
  assert.equal(cisternCellAt(GRID_3X2, 3, 0), null);
  assert.equal(cisternCellAt(GRID_3X2, -1, 0), null);
  assert.equal(cisternCellAt(GRID_3X2, 0, 2), null);
});

test("neighbour order is east, west, south, north", () => {
  assert.deepEqual(cisternNeighbours(1, 1), [[2, 1], [0, 1], [1, 2], [1, 0]]);
});

test("flood distances follow network cells only", () => {
  assert.deepEqual(floodEntries(cisternFlood(GRID_3X2, 0, 0)), {
    "0,0": 0,
    "1,0": 1,
    "2,0": 2,
  });
  assert.deepEqual(floodEntries(cisternFlood(GRID_3X2, 1, 1)), {
    "1,1": 0,
    "1,0": 1,
    "0,0": 2,
    "2,0": 2,
  });
});

test("connected tanks are the tanks in the flood, sorted by x then y", () => {
  assert.deepEqual(cisternConnectedTanks(GRID_PIPE_MANIFOLD_TANK, 0, 0), []);
  assert.deepEqual(cisternConnectedTanks(GRID_PIPE_TANK_TANK, 0, 0), [
    [1, 0],
    [2, 0],
  ]);
});

test("manifold liveness needs a pipe touching a manifold", () => {
  assert.equal(cisternManifoldLive(GRID_PIPE_MANIFOLD_TANK, 0, 0), true);
  assert.equal(cisternManifoldLive(GRID_3X2, 0, 0), false);
});

test("pipe liveness is tank or manifold", () => {
  assert.equal(cisternPipeLive(GRID_PIPE_MANIFOLD_TANK, 0, 0), true);
  assert.equal(cisternPipeLive(GRID_PIPE_TANK_TANK, 0, 0), true);
});

test("ore lookup", () => {
  assert.equal(cisternHasOre(GRID_3X2, 0, 1), true);
  assert.equal(cisternHasOre(GRID_3X2, 0, 0), false);
});

test("the frozen template surface is unchanged", () => {
  assert.equal(TOWN_SEED, 0xc1577eed);
  assert.equal(TOWN_FLAVOR_KEY, (6 << 8) | 2);
  assert.equal(DEFAULT_SPEED, 100);
  assert.deepEqual(Object.keys(DIR8).sort(), ["e", "n", "ne", "nw", "s", "se", "sw", "w"]);
  assert.throws(() => parseTown(["short", "row"], {}, [], [], []), /expected 16 rows/);
});
