/**
 * v3-core-shop-stock — what alloy buys.
 *
 * The module under test is src/core/shop-stock.ts, imported from the compiled
 * build (out/core/shop-stock.js). HNGH_FILL_MODULE points at the file the
 * fill funnel wrote, so the same suite can also run against a workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/shop-stock.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  SHOP_ITEMS,
  SHOP_PRICE,
  RESTOCK_TICKS,
  createShopStock,
  restockCycle,
  boughtThisCycle,
  recordPurchase,
  buyItem,
} = await import(modulePath);

test("the price table is the archive cost table", () => {
  assert.deepEqual(SHOP_PRICE, {
    toilet: 10,
    pipe: 2,
    tank: 15,
    decon: 3,
    clear: 2,
  });
  assert.deepEqual(SHOP_ITEMS, ["toilet", "pipe", "tank", "decon", "clear"]);
});

test("the restock clock is 100 turns", () => {
  assert.equal(RESTOCK_TICKS, 100);
  assert.equal(restockCycle(0), 0);
  assert.equal(restockCycle(99), 0);
  assert.equal(restockCycle(100), 1);
  assert.equal(restockCycle(250), 2);
});

test("a fresh stock is empty", () => {
  assert.deepEqual(createShopStock().purchases, []);
});

test("one unit per item per cycle", () => {
  const first = buyItem(createShopStock(), "toilet", 10, 100);
  assert.equal(first.ok, true);

  const second = buyItem(first.stock, "toilet", 20, 100);
  assert.equal(second.ok, false);
  assert.equal(second.reason, "sold_out");

  const other = buyItem(second.stock, "pipe", 20, 100);
  assert.equal(other.ok, true);
});

test("the next cycle restocks the item", () => {
  const first = buyItem(createShopStock(), "toilet", 10, 100);
  assert.equal(first.ok, true);

  const next = buyItem(first.stock, "toilet", 100, 100);
  assert.equal(next.ok, true);
});

test("an unaffordable purchase changes nothing", () => {
  const result = buyItem(createShopStock(), "tank", 10, 14);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "too_poor");
  assert.equal(result.alloy, 14);
  assert.deepEqual(result.stock.purchases, []);
});

test("the ledger records one row per purchase", () => {
  const stock = createShopStock();
  recordPurchase(stock, "toilet", 10);
  recordPurchase(stock, "pipe", 10);
  assert.deepEqual(stock.purchases, [
    { turn: 10, item: "toilet" },
    { turn: 10, item: "pipe" },
  ]);
});

test("a successful purchase charges the price", () => {
  const result = buyItem(createShopStock(), "pipe", 10, 20);
  assert.equal(result.ok, true);
  assert.equal(result.alloy, 18);
  assert.deepEqual(result.stock.purchases, [{ turn: 10, item: "pipe" }]);
});

test("the cycle helper agrees with the ledger", () => {
  const stock = createShopStock();
  assert.equal(boughtThisCycle(stock, "toilet", 10), false);
  recordPurchase(stock, "toilet", 10);
  assert.equal(boughtThisCycle(stock, "toilet", 10), true);
  assert.equal(boughtThisCycle(stock, "toilet", 99), true);
  assert.equal(boughtThisCycle(stock, "toilet", 100), false);
});
