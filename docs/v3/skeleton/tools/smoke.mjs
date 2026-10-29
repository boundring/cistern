// SKELETON -- no implementation. Target path: tools/smoke.mjs
// Owning slice: smoke (acceptance)
//
// Responsibility: own the CI-equivalent acceptance run -- the node-side
// structural and golden cross-checks on the baked donors, the static server,
// the isolated headless Chromium over CDP, the state assertions on
// window.game, the NPC-region pixel probe, the deliverable screenshots and
// the same-origin / offline network enforcement. It must NOT own game
// behaviour: it only observes the running page.
//
// Acceptance list (the checks this file must perform):
//   A. node-side: out/generated/donors.js exists and is importable.
//   B. node-side: slab/tile/prop ids resolve; copy table non-empty; tilePng
//      entries are PNG data URIs; the baked town template matches
//      tests/golden/town.txt up to FLAVOR grass; the scatter seed appears in
//      tests/golden/rng.txt.
//   C. the page is served from the repo root and fires loadEventFired.
//   D. window.game appears within 15s (the test surface is installed).
//   E. state assertions (assert on state, never pixel goldens).
//   F. dispatch: inspect / orbit / zoom / tick / reset all succeed and the
//      selection text matches DONORS.copy.
//   G. townsfolk: rendered count == the donor spawn count; nobody despawns;
//      ticks advance the event stream.
//   H. v3 world: counts.figures >= townsfolk + 1; trees, rocks and items > 0.
//   I. NPC-region pixel probe: the figure region is shaded 3D geometry.
//   J. screenshots: 1280x800 and 375x667, plus the three v3 deliverables.
//   K. network: every request same-origin; cross-origin requests hard-blocked;
//      the game still plays with the NIC emulated offline.
//
// The frozen assertion names below are the check labels this file must keep.
// The names are data only -- the file performs no work until it is
// implemented at the target path.

/** v2 checks that must stay green. */
export const V2_ASSERTIONS = [
  "donors.js present and importable",
  "tile and prop ids all resolve to a slab and a layer",
  "copy table is non-empty",
  "tilePng entries are PNG data URIs",
  "baked town template matches golden/town.txt up to FLAVOR grass",
  "scatterSeed present in golden/rng.txt",
  "page served from the repo root, loadEventFired fires",
  "window.game appears within 15s",
  "state.seed equals the baked townSeed",
  "state dims are 34x16 and state.tiles has 544 entries",
  "every state tile equals the golden tile",
  "counts.floor + counts.structure equals 544",
  "dispatch(inspect) returns the golden tile and non-empty copy text",
  "state().selection.text equals dispatch(inspect).selection.text",
  "dispatch orbit / zoom / reset all succeed",
  "rendered townsfolk equals the donor spawn count",
  "state.townsfolk length equals the donor spawn count (never despawns)",
  "dispatch(tick) advances the sim event stream",
  "screenshots at 1280x800 and 375x667 are written and not blank",
  "every network request is same-origin",
  "the game still plays with the NIC emulated offline",
];

/** v3 state assertions, with their pinned world numbers. */
export const V3_STATE_ASSERTIONS = [
  "state.world.playableW === 68",
  "state.world.playableH === 32",
  "state.world.footprintW === 136",
  "state.world.footprintH === 64",
  "state.world.villageX === 34",
  "state.world.villageY === 16",
  "state.world.townX === 17",
  "state.world.townY === 8",
  "state.world.townW === 34",
  "state.world.townH === 16",
  "state.counts.townsfolk === donor spawn count",
  "state.counts.figures >= state.counts.townsfolk + 1",
  "state.counts.trees > 0",
  "state.counts.rocks > 0",
  "state.counts.items > 0",
];

/** The NPC-region pixel probe assertion (a flat quad must fail it). */
export const NPC_PROBE_ASSERTIONS = [
  "probe.fig.samples > 0",
  "probe.fig.distinct >= 5",
  "probe.fig.variance >= 500",
];

/** The three deliverable screenshots. */
export const DELIVERABLE_SHOTS = [
  "out/v3-default.png -- the default framing over the open world",
  "out/v3-wide.png -- the wide map (zoom distance 120)",
  "out/v3-close.png -- a close-up on one townsfolk (zoom distance 4)",
];
