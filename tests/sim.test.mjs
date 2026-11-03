/**
 * v3-core-town-state — the town state surface (TownSim).
 *
 * The module under test is src/core/sim.ts, imported from the compiled build
 * (out/core/sim.js). HNGH_FILL_MODULE points at the file the fill funnel
 * wrote, so the same suite can also run against a workdir copy.
 *
 * The alloy/waste economy that used to live here was excised on 2026-11-03:
 * the donor GDScript is the economy authority, and browser economy arrives
 * through the donor gateway.
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

const { ENERGY_ACT, TownSim } = await import(modulePath);

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
