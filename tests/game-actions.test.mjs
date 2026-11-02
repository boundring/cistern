/**
 * v3-game-actions — the player intents: purge and buy.
 *
 * The module under test is src/core/game-actions.ts, imported from the
 * compiled build (out/core/game-actions.js). HNGH_FILL_MODULE points at the
 * file the fill funnel wrote, so the same suite can also run against a
 * workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/game-actions.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  CISTERN_INTENT_KINDS,
  parseCisternIntent,
  describeCisternIntent,
  checkCisternIntent,
} = await import(modulePath);

// A world view: one loaded tank at (5,2), the archive price table, and one
// good already bought this cycle.
function makeView(overrides = {}) {
  const view = {
    alloy: 20,
    purgeRate: 3,
    tankLoadAt: (x, y) => (x === 5 && y === 2 ? 30 : undefined),
    priceOf: (item) =>
      ({ toilet: 10, pipe: 2, tank: 15, decon: 3, clear: 2 })[item],
    boughtThisCycle: (item) => item === "pipe",
    ...overrides,
  };
  return view;
}

test("the intent vocabulary is purge and buy", () => {
  assert.deepEqual(CISTERN_INTENT_KINDS, ["purge", "buy"]);
});

test("the parser accepts the two intents", () => {
  assert.deepEqual(parseCisternIntent("purge 12,9"), {
    kind: "purge",
    x: 12,
    y: 9,
  });
  assert.deepEqual(parseCisternIntent("buy toilet 3,4"), {
    kind: "buy",
    item: "toilet",
    x: 3,
    y: 4,
  });
});

test("the parser rejects anything else", () => {
  assert.equal(parseCisternIntent("dance 1,2"), null);
  assert.equal(parseCisternIntent("purge"), null);
  assert.equal(parseCisternIntent(""), null);
});

test("the intent text round-trips", () => {
  const intent = parseCisternIntent("buy toilet 3,4");
  const text = describeCisternIntent(intent);
  assert.deepEqual(parseCisternIntent(text), intent);
  assert.equal(text, "buy toilet 3,4");
});

test("a purge on a cell with no tank is refused", () => {
  const outcome = checkCisternIntent({ kind: "purge", x: 1, y: 1 }, makeView());
  assert.equal(outcome.ok, false);
  assert.equal(outcome.message, "CURSOR NOT ON A TANK");
});

test("a purge on an empty tank is refused", () => {
  const view = makeView({ tankLoadAt: () => 0 });
  const outcome = checkCisternIntent({ kind: "purge", x: 5, y: 2 }, view);
  assert.equal(outcome.ok, false);
  assert.equal(outcome.message, "TANK ALREADY CLEAR");
});

test("a purge of a loaded tank recovers alloy", () => {
  const outcome = checkCisternIntent({ kind: "purge", x: 5, y: 2 }, makeView());
  assert.equal(outcome.ok, true);
  assert.equal(outcome.message, "TANK PURGED — RECOVERED 10 ALLOY");
});

test("a buy of an unknown good is refused", () => {
  const outcome = checkCisternIntent(
    { kind: "buy", item: "wings", x: 3, y: 4 },
    makeView(),
  );
  assert.equal(outcome.ok, false);
  assert.equal(outcome.message, "NO SUCH WARE");
});

test("a buy of a good sold out this cycle is refused", () => {
  const outcome = checkCisternIntent(
    { kind: "buy", item: "pipe", x: 3, y: 4 },
    makeView(),
  );
  assert.equal(outcome.ok, false);
  assert.equal(outcome.reason, "shop_sold_out");
});

test("a buy the player cannot afford is refused", () => {
  const outcome = checkCisternIntent(
    { kind: "buy", item: "toilet", x: 3, y: 4 },
    makeView({ alloy: 9 }),
  );
  assert.equal(outcome.ok, false);
  assert.equal(outcome.message, "INSUFFICIENT ALLOY — 10 REQUIRED");
});

test("an affordable buy is allowed", () => {
  const outcome = checkCisternIntent(
    { kind: "buy", item: "toilet", x: 3, y: 4 },
    makeView(),
  );
  assert.equal(outcome.ok, true);
  assert.equal(outcome.message, "shop/bought");
});
