// Definition of done for the v3-render-inspector fill item.
//
// The module under test is the single file in the item workdir
// (`inspector.ts`). Node >= 22.18 strips TypeScript types natively, so the
// file is imported as-is -- the test runner never compiles it.
//
// The module is imported through HNGH_FILL_MODULE (absolute path, exported by
// run_tests.sh); the fallback is the sibling workdir copy. The module may only
// use type-only imports, so nothing has to be staged next to it.
//
// Against the declaration-only skeleton stub every case below fails with
// "not implemented: Inspector"; against a correct fill they all pass.
//
// Canonical case names (input/v3-docs/TEST-SPEC.md section 8):
//   the terrain row renders kind steps and height
//   the terrain row renders the water case
//   the figure row renders kind and id
//   absent optional fields render empty strings

import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleUrl = process.env.HNGH_FILL_MODULE
  ? pathToFileURL(path.resolve(process.env.HNGH_FILL_MODULE)).href
  : new URL("../out/render/inspector.js", import.meta.url).href;

const { Inspector } = await import(moduleUrl);

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

/**
 * Minimal stand-in for the baked donors (the copy table and the tile
 * sprites). Every lookup resolves to an empty entry, so a missing key can
 * never throw -- the inspector has to read the donors defensively.
 */
function fakeDonors() {
  const entry = { src: "", text: "", sprite: "" };
  const table = new Proxy(
    { get: () => undefined },
    {
      get: (target, prop) =>
        prop in target
          ? target[prop]
          : typeof prop === "symbol"
            ? undefined
            : entry,
    },
  );
  return { copy: table, tiles: table, tilePng: table, sprites: table };
}

/** The text the inspector wrote into one panel slot. */
function slotText(panel, name) {
  const el = panel.querySelector(`[data-slot="${name}"]`);
  return el ? el.textContent : null;
}

test("the terrain row renders kind steps and height", () => {
  const panel = fakePanel();
  const inspector = new Inspector(panel, fakeDonors());

  inspector.show({
    terrain: { kind: "hills", steps: 7, height: 0.875, water: false },
  });

  assert.equal(
    slotText(panel, "terrain"),
    "hills — 7 steps (0.875 u)",
    "terrain row",
  );
});

test("the terrain row renders the water case", () => {
  const panel = fakePanel();
  const inspector = new Inspector(panel, fakeDonors());

  inspector.show({
    terrain: { kind: "water", steps: 3, height: 0.375, water: true },
  });

  assert.equal(
    slotText(panel, "terrain"),
    "water — 3 steps below the table",
    "water row",
  );
});

test("the figure row renders kind and id", () => {
  const panel = fakePanel();
  const inspector = new Inspector(panel, fakeDonors());

  inspector.show({ figure: { kind: "townsfolk", id: 12 } });

  assert.equal(slotText(panel, "figure"), "townsfolk #12", "figure row");
});

test("absent optional fields render empty strings", () => {
  const panel = fakePanel();
  const inspector = new Inspector(panel, fakeDonors());

  inspector.show({});

  assert.equal(slotText(panel, "terrain"), "", "absent terrain row");
  assert.equal(slotText(panel, "figure"), "", "absent figure row");
});
