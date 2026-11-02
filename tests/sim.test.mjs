/**
 * v3-core-town-state — the cistern alloy/waste ledger on the town state.
 *
 * The module under test is src/core/sim.ts, imported from the compiled build
 * (out/core/sim.js). HNGH_FILL_MODULE points at the file the fill funnel
 * wrote, so the same suite can also run against a workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/sim.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  ENERGY_ACT,
  TownSim,
  CISTERN_TANK_CAP,
  CISTERN_USE_LOAD,
  CISTERN_PURGE_RATE,
  CISTERN_START_ALLOY,
  CISTERN_CONTAM_LIMIT,
  createCisternState,
  cisternRegisterTank,
  cisternWaste,
  cisternDepositWaste,
  cisternPurge,
  cisternMine,
  cisternToiletUsable,
} = await import(modulePath);

// A hand-built 6x6 floor town: enough shape for TownSim, no donor .gd needed.
function flatTown() {
  const width = 6;
  const height = 6;
  const tiles = new Array(width * height).fill("floor");
  return {
    width,
    height,
    tiles,
    spawn: [0, 0],
    entrance: [5, 0],
    well: [0, 5],
    shopDoors: [],
    shopInteriors: [],
    shopNames: [],
    shopFixtures: [],
  };
}

test("a fresh state is empty", () => {
  const state = createCisternState();
  assert.equal(state.alloy, 20);
  assert.equal(state.earned, 0);
  assert.equal(state.purged, 0);
  assert.equal(state.contam, 0);
  assert.deepEqual(state.tankLoad, {});
});

test("the economy constants are the archive constants", () => {
  assert.equal(CISTERN_TANK_CAP, 60);
  assert.equal(CISTERN_USE_LOAD, 10);
  assert.equal(CISTERN_PURGE_RATE, 3);
  assert.equal(CISTERN_START_ALLOY, 20);
  assert.equal(CISTERN_CONTAM_LIMIT, 20);
});

test("registering a tank creates a zero load entry", () => {
  const state = cisternRegisterTank(createCisternState(), 5, 2);
  assert.equal(state.tankLoad["5,2"], 0);
  assert.equal(state.alloy, 20);
  assert.equal(state.earned, 0);
  assert.equal(state.purged, 0);
  assert.equal(state.contam, 0);
});

test("waste is the sum of the tank loads", () => {
  let state = cisternRegisterTank(createCisternState(), 5, 2);
  state = cisternRegisterTank(state, 3, 2);
  state = { ...state, tankLoad: { ...state.tankLoad, "5,2": 30, "3,2": 10 } };
  assert.equal(cisternWaste(state), 40);
});

test("a deposit fills the least loaded connected tank", () => {
  let state = cisternRegisterTank(createCisternState(), 5, 2);
  state = cisternRegisterTank(state, 3, 2);
  state = { ...state, tankLoad: { ...state.tankLoad, "5,2": 30, "3,2": 10 } };

  const result = cisternDepositWaste(state, [
    [5, 2],
    [3, 2],
  ], false);

  assert.equal(result.outcome, "stored");
  assert.equal(result.message, "WASTE STORED");
  assert.equal(result.state.tankLoad["3,2"], 20);
  assert.equal(result.state.tankLoad["5,2"], 30);
  assert.equal(result.state.alloy, 20);
  assert.equal(result.state.contam, 0);
});

test("a deposit with no tank but a live manifold is relief", () => {
  const result = cisternDepositWaste(createCisternState(), [], true);
  assert.equal(result.outcome, "relief");
  assert.equal(result.message, "MANIFOLD RELIEF");
  assert.equal(result.state.contam, 0);
  assert.equal(result.state.alloy, 20);
  assert.deepEqual(result.state.tankLoad, {});
});

test("a deposit with no tank and no manifold spills", () => {
  const result = cisternDepositWaste(createCisternState(), [], false);
  assert.equal(result.outcome, "spilled");
  assert.equal(result.message, "SEVERED LINE — WASTE SPILLED");
  assert.equal(result.state.contam, 1);
  assert.equal(result.state.alloy, 20);
  assert.deepEqual(result.state.tankLoad, {});
});

test("a purge converts three waste into one alloy", () => {
  let state = cisternRegisterTank(createCisternState(), 5, 2);
  state = { ...state, tankLoad: { ...state.tankLoad, "5,2": 30 } };

  const result = cisternPurge(state, 5, 2);

  assert.equal(result.outcome, "purged");
  assert.equal(result.gained, 10);
  assert.equal(result.message, "TANK PURGED — RECOVERED 10 ALLOY");
  assert.equal(result.state.alloy, 30);
  assert.equal(result.state.earned, 0);
  assert.equal(result.state.purged, 1);
  assert.equal(result.state.tankLoad["5,2"], 0);
});

test("a purge refuses a missing tank and an empty tank", () => {
  const missing = cisternPurge(createCisternState(), 1, 1);
  assert.equal(missing.outcome, "not_a_tank");
  assert.equal(missing.message, "CURSOR NOT ON A TANK");
  assert.equal(missing.gained, 0);

  const empty = cisternPurge(cisternRegisterTank(createCisternState(), 5, 2), 5, 2);
  assert.equal(empty.outcome, "already_clear");
  assert.equal(empty.message, "TANK ALREADY CLEAR");
  assert.equal(empty.gained, 0);
});

test("mining yields one alloy at the rate", () => {
  const below = cisternMine(createCisternState(), 0, 3);
  assert.equal(below.mined, false);
  assert.equal(below.mineTicks, 1);
  assert.equal(below.state.alloy, 20);

  const at = cisternMine(createCisternState(), 2, 3);
  assert.equal(at.mined, true);
  assert.equal(at.mineTicks, 0);
  assert.equal(at.state.alloy, 21);
  assert.equal(at.state.earned, 1);
});

test("a toilet is usable with headroom or a live manifold", () => {
  let state = cisternRegisterTank(createCisternState(), 5, 2);
  assert.equal(cisternToiletUsable(state, [[5, 2]], false), true);

  state = { ...state, tankLoad: { ...state.tankLoad, "5,2": 60 } };
  assert.equal(cisternToiletUsable(state, [[5, 2]], false), false);
  assert.equal(cisternToiletUsable(state, [[5, 2]], true), true);
});

test("the town state surface is unchanged", () => {
  assert.equal(ENERGY_ACT, 100);
  assert.equal(typeof TownSim, "function");
  for (const method of ["walk", "actorAt", "townsfolk", "tick"]) {
    assert.equal(typeof TownSim.prototype[method], "function", `TownSim.${method}`);
  }

  const sim = new TownSim(flatTown(), 0xc1577eed);
  sim.tick();
  assert.equal(sim.turn, 1);
  assert.ok(sim.events.length > 0);
  // The transcript format is "<seq> t=<turn> <text>" and the run opens at
  // turn 0: tick() arms the run before it increments the turn, so the first
  // line is the run_started line at t=0. The donor golden vector
  // (tests/golden/townsfolk.txt) opens the same way.
  for (const line of sim.events) {
    assert.match(line, /^\d+ t=\d+ \S/);
  }
  assert.match(sim.events[0], /^1 t=0 run_started seed=\d+$/);
});
