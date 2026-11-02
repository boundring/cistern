/**
 * v3-core-townsfolk-needs — worker need state on the townsfolk module.
 *
 * The module under test is src/core/townsfolk.ts, imported from the compiled
 * build (out/core/townsfolk.js), where its "./rng.js" and "./town.js"
 * siblings sit next to it. HNGH_FILL_MODULE points at the file the fill
 * funnel wrote, so the same suite can also run against a workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/townsfolk.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  TOWNSFOLK_MIN_COUNT,
  TOWNSFOLK_MAX_COUNT,
  TOWNSFOLK_SLOW_SPEED,
  TOWNSFOLK_SLOW_ONE_IN,
  PLACEMENT_KEY,
  WANDER_KEY,
  TOWNSFOLK_BLIADER_START,
  TOWNSFOLK_BLIADER_RATE,
  TOWNSFOLK_BLIADER_SEEK,
  TOWNSFOLK_BLIADER_BURST,
  TOWNSFOLK_SICK_TICKS,
  populateTownsfolk,
  actTownsfolk,
  initialTownsfolkNeeds,
  advanceTownsfolkNeeds,
  townsfolkSeekThreshold,
  townsfolkSickDuration,
  townsfolkMineRate,
} = await import(modulePath);

test("the need constants are the archive constants", () => {
  assert.equal(TOWNSFOLK_BLIADER_START, 20);
  assert.equal(TOWNSFOLK_BLIADER_RATE, 2);
  assert.equal(TOWNSFOLK_BLIADER_SEEK, 60);
  assert.equal(TOWNSFOLK_BLIADER_BURST, 120);
  assert.equal(TOWNSFOLK_SICK_TICKS, 30);
});

test("a fresh worker is fine", () => {
  assert.deepEqual(initialTownsfolkNeeds(), { bladder: 20, sick: 0 });
});

test("one tick fills the bladder and heals the sickness", () => {
  const result = advanceTownsfolkNeeds({ bladder: 20, sick: 3 });
  assert.deepEqual(result.needs, { bladder: 22, sick: 2 });
});

test("sickness never goes below zero", () => {
  const result = advanceTownsfolkNeeds({ bladder: 20, sick: 0 });
  assert.equal(result.needs.sick, 0);
  assert.equal(result.needs.bladder, 22);
});

test("the urge is none, then seek_toilet, then burst", () => {
  const none = advanceTownsfolkNeeds({ bladder: 56, sick: 0 });
  assert.equal(none.needs.bladder, 58);
  assert.equal(none.urge, "none");

  const seek = advanceTownsfolkNeeds({ bladder: 58, sick: 0 });
  assert.equal(seek.needs.bladder, 60);
  assert.equal(seek.urge, "seek_toilet");

  const burst = advanceTownsfolkNeeds({ bladder: 118, sick: 0 });
  assert.equal(burst.needs.bladder, 120);
  assert.equal(burst.urge, "burst");

  const atBurst = advanceTownsfolkNeeds({ bladder: 120, sick: 0 });
  assert.equal(atBurst.urge, "burst");
});

test("the seek threshold is clamped", () => {
  assert.equal(townsfolkSeekThreshold(0), 60);
  assert.equal(townsfolkSeekThreshold(2), 50);
  assert.equal(townsfolkSeekThreshold(-2), 68);
});

test("the sickness duration is clamped", () => {
  assert.equal(townsfolkSickDuration(0), 30);
  assert.equal(townsfolkSickDuration(3), 18);
  assert.equal(townsfolkSickDuration(-3), 42);
});

test("the mine rate is clamped, hurt adds one and sickness doubles", () => {
  assert.equal(townsfolkMineRate(0, false, false), 3);
  assert.equal(townsfolkMineRate(5, false, false), 2);
  assert.equal(townsfolkMineRate(-5, false, false), 6);
  assert.equal(townsfolkMineRate(0, true, false), 4);
  assert.equal(townsfolkMineRate(0, false, true), 6);
  assert.equal(townsfolkMineRate(0, true, true), 8);
});

test("the population surface is unchanged", () => {
  assert.equal(TOWNSFOLK_MIN_COUNT, 6);
  assert.equal(TOWNSFOLK_MAX_COUNT, 10);
  assert.equal(TOWNSFOLK_SLOW_SPEED, 50);
  assert.equal(TOWNSFOLK_SLOW_ONE_IN, 2);
  assert.equal(PLACEMENT_KEY, (4 << 8) | 2);
  assert.equal(WANDER_KEY, (4 << 8) | 3);
  assert.equal(typeof populateTownsfolk, "function");
  assert.equal(typeof actTownsfolk, "function");
});
