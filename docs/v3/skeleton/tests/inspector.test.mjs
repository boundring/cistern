// SKELETON -- no implementation. Target path: tests/inspector.test.mjs
// Owning slice: E (inspector), session S09
//
// Responsibility: own the test for the inspector panel -- the terrain row
// text, the water case, the figure row text, and the empty-string fallback
// for absent optional fields. It must NOT own the camera, the figures rig,
// the world renderer, or any other slice's tests.
//
// Source of truth: src/render/inspector.ts -- terrainLine() renders
// `${kind} — ${steps} steps (${height} u)` with an em dash (U+2014), or
// `water — ${steps} steps below the table` when the cell is under water;
// the figure row renders `${kind} #${id}`; absent terrain/figure fields
// render the empty string.
//
// IMPORT PATH: the module under test is the COMPILED build,
// out/render/inspector.js. This skeleton lives at docs/v3/skeleton/tests/,
// so the real build is four levels up: "../../../../out/render/inspector.js"
// -- promoted to tests/inspector.test.mjs the import becomes the static
//   import { Inspector } from "../out/render/inspector.js";
// Here it is a guarded dynamic import so the skeleton suite stays green
// before `npm run build` has produced out/ (out/ is gitignored build output
// and does not exist in a fresh checkout; out/render/inspector.js imports
// nothing external, so it loads standalone).
import test from "node:test";
import assert from "node:assert/strict";

const mod = await import("../../../../out/render/inspector.js").catch(() => null);

/**
 * Minimal stand-in for the panel DOM: the inspector only ever reads
 * querySelector("[data-slot=...]") and writes textContent, so a plain object
 * with those slots is enough.
 */
function fakePanel() {
  const slots = {};
  return {
    slots,
    hidden: false,
    querySelector(sel) {
      const name = sel.match(/\[data-slot="(.+)"\]/)?.[1];
      if (!name) return null;
      return (slots[name] ??= { textContent: "", src: "", hidden: false });
    },
  };
}

test("the terrain row renders kind steps and height", { todo: "not implemented — S09" }, () => {
  // show({terrain: {kind: "hills", steps: 7, height: 0.875, water: false}})
  // -> the terrain slot reads "hills — 7 steps (0.875 u)" (em dash U+2014).
  const actual = undefined; // TODO(S09): inspector.show(...) then read the terrain slot
  assert.equal(actual, "hills — 7 steps (0.875 u)", "terrain row");
});

test("the terrain row renders the water case", { todo: "not implemented — S09" }, () => {
  // show({terrain: {kind: "water", steps: 3, height: 0.375, water: true}})
  // -> "water — 3 steps below the table".
  const actual = undefined; // TODO(S09): inspector.show(...) then read the terrain slot
  assert.equal(actual, "water — 3 steps below the table", "water row");
});

test("the figure row renders kind and id", { todo: "not implemented — S09" }, () => {
  // show({figure: {kind: "townsfolk", id: 12}}) -> "townsfolk #12".
  const actual = undefined; // TODO(S09): inspector.show(...) then read the figure slot
  assert.equal(actual, "townsfolk #12", "figure row");
});

test("absent optional fields render empty strings", { todo: "not implemented — S09" }, () => {
  // show({}) with no terrain and no figure -> both optional slots read "".
  const actual = undefined; // TODO(S09): inspector.show({}) then read both slots
  assert.equal(actual, "", "absent terrain and figure rows");
});
