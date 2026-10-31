// Definition of done for the S05 render-figures-rig slice.
//
// The module under test is the compiled build, `out/render/figures.js` (the
// full `npm run build` produces it; `npm test` only builds src/core). It is
// imported through HNGH_FILL_MODULE (absolute path) when the harness points
// at a workdir copy; the fallback is the repo build.
//
// Sources of truth (no number is invented here):
//   docs/v3/TEST-SPEC.md section 5      -- the canonical case table
//   docs/v3/skeleton/tests/figures.test.mjs -- the canonical case names
//   docs/v3/ARCHITECTURE.md section 3   -- the rig, palette and tint law
//   src/render/figures.ts               -- the frozen constants
//
// Canonical case names:
//   a figure is a box hierarchy root>body>limbs
//   limb pivots sit at the joint
//   figure height matches the frozen part sizes
//   the per-figure tint is deterministic in the figure id
//   the garment palette matches the donor billboard palette
//   spawn adds a figure and moveTo retargets it
//   positionOf returns the figure's world position
//   update advances the walk cycle with travelled distance

import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleUrl = process.env.HNGH_FILL_MODULE
  ? pathToFileURL(path.resolve(process.env.HNGH_FILL_MODULE)).href
  : new URL("../out/render/figures.js", import.meta.url).href;

const THREE = await import("three");
const { VoxelFigures } = await import(moduleUrl);

// --- frozen constants (TEST-SPEC section 5, ARCHITECTURE section 3) --------

const LEG_W = 0.16;
const LEG_H = 0.3;
const LEG_D = 0.16;
const TORSO_W = 0.34;
const TORSO_H = 0.32;
const TORSO_D = 0.22;
const HEAD_S = 0.22;
const ARM_W = 0.12;
const ARM_H = 0.3;
const ARM_D = 0.12;
const LIMB_AMP = 0.7;
const BOB_AMP = 0.05;
const DEFAULT_STEP_MS = 400;
const LEG_SHADE = 0.35;
const SIDE_SHADE = 0.78;
const BOTTOM_SHADE = 0.62;
const SKIN = [0.85, 0.68, 0.52];

/** The donor billboard palette (billboard_entities.gd) plus the web villager. */
const GARMENT = {
  player: [0.25, 0.55, 0.95],
  townsfolk: [0.4, 0.78, 0.62],
  villager: [0.8, 0.72, 0.45],
};

const near = (a, b, eps = 1e-6) => Math.abs(a - b) <= eps;
const nearColor = (actual, expected, eps = 1e-6) =>
  actual.length === expected.length &&
  actual.every((v, i) => near(v, expected[i], eps));

// --- rig helpers -----------------------------------------------------------

/** The root group of the single spawned figure. */
function rootOf(figures) {
  assert.equal(figures.group.children.length, 1, "exactly one figure is rigged");
  return figures.group.children[0];
}

/** The body group (the bob carrier) of a rig. */
function bodyOf(figures) {
  const root = rootOf(figures);
  assert.equal(root.children.length, 1, "the root holds exactly one body group");
  return root.children[0];
}

/** The six body children in rig order: torso, head, armL, armR, legL, legR. */
function partsOf(figures) {
  const body = bodyOf(figures);
  assert.equal(body.children.length, 6, "the body holds six boxes");
  return {
    body,
    torso: body.children[0],
    head: body.children[1],
    armL: body.children[2],
    armR: body.children[3],
    legL: body.children[4],
    legR: body.children[5],
  };
}

/** The vertex colours of one box face of a mesh. */
function faceColors(mesh, name) {
  const attr = mesh.geometry.getAttribute("color");
  assert.ok(attr, `the "${name}" box carries a colour attribute`);
  // BoxGeometry vertex order: +x, -x, +y (top), -y (bottom), +z, -z -- four
  // vertices each. The rig shades the third group as the top face.
  const groups = {
    top: [8, 9, 10, 11],
    bottom: [12, 13, 14, 15],
    side: [0, 1, 2, 3],
  };
  return groups[name].map((i) => [attr.getX(i), attr.getY(i), attr.getZ(i)]);
}

/** The top-face colour of a box (its base colour, unshaded). */
function baseColor(mesh) {
  const [c] = faceColors(mesh, "top");
  return c;
}

/** The topmost vertex y of a mesh, in its parent's coordinates. */
function topY(mesh) {
  const attr = mesh.geometry.getAttribute("position");
  let max = -Infinity;
  for (let i = 0; i < attr.count; i += 1) max = Math.max(max, attr.getY(i));
  return max + mesh.position.y;
}

/** The tint law: 1 + ScatterHash(7).jitter(id, 0).x * 0.08. */
function tintOf(id) {
  const jitter = new ScatterHash(7).jitter(id, 0);
  return 1 + jitter.x * 0.08;
}

// The scatter hash is the tint law's dependency (ARCHITECTURE section 3); it
// lives in the core build, which `npm run build` produces alongside the rig.
const { ScatterHash } = await import("../out/core/scatter.js");

// The canonical tints (TEST-SPEC section 5, case 4).
const TINT_7 = 1.010600848197937;
const TINT_8 = 0.9631864643096923;

// The canonical player garment for id 7 (TEST-SPEC section 5, case 5).
const PLAYER_7 = [
  0.2526502013206482, 0.5558304786682129, 0.960070788860321,
];

// --- the eight canonical cases --------------------------------------------

test("a figure is a box hierarchy root>body>limbs", () => {
  const figures = new VoxelFigures();
  figures.spawn(7, "player", 0, 0, 0);

  const root = rootOf(figures);
  assert.ok(root.isGroup, "the root is a group");

  const body = bodyOf(figures);
  assert.ok(body.isGroup, "the body is a group");

  const p = partsOf(figures);
  assert.ok(p.torso.isMesh, "the torso is a mesh");
  assert.ok(p.head.isMesh, "the head is a mesh");
  for (const name of ["armL", "armR", "legL", "legR"]) {
    assert.ok(p[name].isGroup, `${name} is a pivot group`);
    assert.equal(p[name].children.length, 1, `${name} holds one box mesh`);
    assert.ok(p[name].children[0].isMesh, `${name}'s child is a mesh`);
  }
});

test("limb pivots sit at the joint", () => {
  const figures = new VoxelFigures();
  figures.spawn(7, "player", 0, 0, 0);
  const p = partsOf(figures);

  // Arms pivot at the shoulder: x = +-(TORSO_W/2 + ARM_W/2) = +-0.23,
  // y = LEG_H + TORSO_H - ARM_H/2 = 0.47.
  assert.ok(near(p.armL.position.x, -(TORSO_W / 2 + ARM_W / 2)), "armL pivot x");
  assert.ok(near(p.armR.position.x, TORSO_W / 2 + ARM_W / 2), "armR pivot x");
  for (const arm of [p.armL, p.armR]) {
    assert.ok(near(arm.position.y, LEG_H + TORSO_H - ARM_H / 2), "arm pivot y");
    // the box hangs half its height below the pivot
    assert.ok(near(arm.children[0].position.y, -ARM_H / 2), "arm mesh offset");
  }

  // Legs pivot at the hip: x = +-TORSO_W/4 = +-0.085, y = LEG_H = 0.3.
  assert.ok(near(p.legL.position.x, -TORSO_W / 4), "legL pivot x");
  assert.ok(near(p.legR.position.x, TORSO_W / 4), "legR pivot x");
  for (const leg of [p.legL, p.legR]) {
    assert.ok(near(leg.position.y, LEG_H), "leg pivot y");
    assert.ok(near(leg.children[0].position.y, -LEG_H / 2), "leg mesh offset");
  }
});

test("figure height matches the frozen part sizes", () => {
  const figures = new VoxelFigures();
  figures.spawn(7, "player", 0, 0, 0.5);
  const p = partsOf(figures);

  const total = LEG_H + TORSO_H + HEAD_S;
  assert.equal(total, 0.84, "the frozen parts sum to 0.84");

  const root = rootOf(figures);
  // The head's top sits 0.84 above the root's base.
  assert.ok(
    near(topY(p.head) - p.body.position.y, total, 1e-6),
    `figure height ${topY(p.head) - p.body.position.y}`,
  );
  // The root's origin sits on the ground the figure was spawned on.
  assert.equal(root.position.y, 0.5, "the root sits on the ground");

  // The boxes are the frozen sizes.
  const sizeOf = (mesh) => {
    const attr = mesh.geometry.getAttribute("position");
    const min = [Infinity, Infinity, Infinity];
    const max = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < attr.count; i += 1) {
      for (let a = 0; a < 3; a += 1) {
        const v = attr.array[i * 3 + a];
        if (v < min[a]) min[a] = v;
        if (v > max[a]) max[a] = v;
      }
    }
    return [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
  };
  assert.ok(nearColor(sizeOf(p.torso), [TORSO_W, TORSO_H, TORSO_D]), "torso size");
  assert.ok(nearColor(sizeOf(p.head), [HEAD_S, HEAD_S, HEAD_S]), "head size");
  assert.ok(nearColor(sizeOf(p.legL.children[0]), [LEG_W, LEG_H, LEG_D]), "leg size");
  assert.ok(nearColor(sizeOf(p.armL.children[0]), [ARM_W, ARM_H, ARM_D]), "arm size");
});

test("the per-figure tint is deterministic in the figure id", () => {
  assert.ok(near(tintOf(7), TINT_7, 1e-12), `tint of id 7 is ${tintOf(7)}`);
  assert.ok(near(tintOf(8), TINT_8, 1e-12), `tint of id 8 is ${tintOf(8)}`);

  // The same id always yields the same tint, on any rig, in any frame.
  const read = (id) => {
    const figures = new VoxelFigures();
    figures.spawn(id, "player", 0, 0, 0);
    const [c] = faceColors(partsOf(figures).torso, "top");
    return c;
  };
  assert.deepEqual(read(7), read(7), "the same id yields the same garment colour");
  assert.notDeepEqual(read(7), read(8), "a different id yields a different tint");

  // The tint stays inside the +-4% band around 1.
  for (const id of [7, 8]) {
    assert.ok(Math.abs(tintOf(id) - 1) <= 0.04, `tint of id ${id} is within +-4%`);
  }

  // The tint rides on the garment colour: the base colour equals the palette
  // scaled by the tint (stored as float32 vertex colours).
  const c = read(7);
  for (let i = 0; i < 3; i += 1) {
    assert.ok(
      near(c[i], Math.fround(GARMENT.player[i] * TINT_7)),
      `player garment channel ${i} is ${c[i]}`,
    );
  }
});

test("the garment palette matches the donor billboard palette", () => {
  const garmentOf = (id, kind) => {
    const figures = new VoxelFigures();
    figures.spawn(id, kind, 0, 0, 0);
    return partsOf(figures).torso;
  };

  // The canonical player figure (id 7).
  const player = baseColor(garmentOf(7, "player"));
  assert.ok(nearColor(player, PLAYER_7), `player garment is ${player}`);

  // Every kind scales the donor palette by the id's tint.
  for (const [kind, palette] of Object.entries(GARMENT)) {
    for (const id of [7, 8]) {
      const mesh = garmentOf(id, kind);
      const tint = tintOf(id);
      const top = baseColor(mesh);
      for (let i = 0; i < 3; i += 1) {
        assert.ok(
          near(top[i], Math.fround(palette[i] * tint)),
          `${kind} id ${id} channel ${i} is ${top[i]}`,
        );
      }
      // The side and bottom faces carry the frozen shade factors.
      const side = faceColors(mesh, "side")[0];
      const bottom = faceColors(mesh, "bottom")[0];
      for (let i = 0; i < 3; i += 1) {
        assert.ok(
          near(side[i], Math.fround(palette[i] * tint * SIDE_SHADE)),
          `${kind} id ${id} side channel ${i}`,
        );
        assert.ok(
          near(bottom[i], Math.fround(palette[i] * tint * BOTTOM_SHADE)),
          `${kind} id ${id} bottom channel ${i}`,
        );
      }
    }
  }

  // The head carries the skin colour, tinted; the legs the garment x 0.35.
  const figures = new VoxelFigures();
  figures.spawn(7, "player", 0, 0, 0);
  const p = partsOf(figures);
  const skin = baseColor(p.head);
  for (let i = 0; i < 3; i += 1) {
    assert.ok(
      near(skin[i], Math.fround(SKIN[i] * TINT_7)),
      `skin channel ${i} is ${skin[i]}`,
    );
  }
  const boot = baseColor(p.legL.children[0]);
  for (let i = 0; i < 3; i += 1) {
    assert.ok(
      near(boot[i], Math.fround(GARMENT.player[i] * TINT_7 * LEG_SHADE)),
      `leg channel ${i} is ${boot[i]}`,
    );
  }
});

test("spawn adds a figure and moveTo retargets it", () => {
  const figures = new VoxelFigures();
  assert.equal(figures.count(), 0, "no figures before the spawn");

  figures.spawn(7, "player", 0, 0, 0);
  assert.equal(figures.count(), 1, "the spawn registered the figure");

  // moveTo records a new destination and the figure advances along it.
  figures.moveTo(7, 1, 0, 0);
  const camera = new THREE.PerspectiveCamera();
  camera.position.set(0, 2, 6);
  figures.update(0, camera);
  figures.update(DEFAULT_STEP_MS / 4, camera);

  const p = figures.positionOf(7);
  assert.ok(near(p.x, 0.25, 1e-6), `the figure advanced to x ${p.x}`);
  assert.ok(near(p.z, 0, 1e-6), `the figure advanced to z ${p.z}`);

  // Re-targeting mid-step continues from the interpolated position, never a
  // jump.
  figures.moveTo(7, 2, 0, 0);
  figures.update(DEFAULT_STEP_MS / 4 + 1, camera);
  figures.update(DEFAULT_STEP_MS / 4 + 1 + DEFAULT_STEP_MS / 4, camera);
  const q = figures.positionOf(7);
  assert.ok(
    q.x > p.x && q.x < 2,
    `the re-targeted figure continues forward, at x ${q.x}`,
  );
});

test("positionOf returns the figure's world position", () => {
  const figures = new VoxelFigures();
  figures.spawn(7, "player", 3, 5, 0.5);

  const p = figures.positionOf(7);
  assert.ok(p !== null, "the spawned figure has a position");
  assert.equal(p.x, 3, "world x");
  assert.equal(p.y, 0.5, "the ground height is the world y");
  assert.equal(p.z, -5, "world y maps to -z");

  assert.equal(figures.positionOf(999), null, "an unknown id has no position");
});

test("update advances the walk cycle with travelled distance", () => {
  const figures = new VoxelFigures({ stepDurationMs: DEFAULT_STEP_MS });
  figures.spawn(7, "player", 0, 0, 0);
  figures.moveTo(7, 1, 0, 0);

  const camera = new THREE.PerspectiveCamera();
  camera.position.set(0, 2, 6);

  // The step starts on the first update; at 100 ms of a 400 ms step the
  // travelled distance is 0.25, so the phase is PI/2 and the swing is 1.
  figures.update(0, camera);
  figures.update(100, camera);

  const p = partsOf(figures);
  assert.ok(near(p.legL.rotation.x, LIMB_AMP), `legL swing ${p.legL.rotation.x}`);
  assert.ok(near(p.legR.rotation.x, -LIMB_AMP), `legR swing ${p.legR.rotation.x}`);
  assert.ok(near(p.armL.rotation.x, -LIMB_AMP), `armL swing ${p.armL.rotation.x}`);
  assert.ok(near(p.armR.rotation.x, LIMB_AMP), `armR swing ${p.armR.rotation.x}`);
  assert.ok(near(p.body.position.y, BOB_AMP), `body bob ${p.body.position.y}`);

  const root = rootOf(figures);
  assert.ok(near(root.position.x, 0.25, 1e-6), `root x ${root.position.x}`);
  assert.ok(near(root.position.z, 0, 1e-6), `root z ${root.position.z}`);
  assert.ok(near(root.position.y, 0, 1e-6), `root y ${root.position.y}`);

  // The figure turns to face the movement direction.
  assert.ok(
    near(root.rotation.y, Math.atan2(1, 0), 1e-6),
    `facing ${root.rotation.y}`,
  );
});
