// Definition of done for the v3-render-voxel-models fill item.
//
// The module under test is the single file in the item workdir (`voxel.ts`),
// imported as TypeScript source -- Node >= 22.18 strips the types natively
// (this machine: v26.8.2), so the file is judged exactly as the local model
// wrote it. `HNGH_FILL_MODULE` points at it (absolute path); the fallback is
// `../workdir/voxel.ts`.
//
// Against the declaration-only skeleton stub every case below fails with
// "not implemented: <name>"; against a correct fill they all pass.
//
// Sources of truth (no number is invented here):
//   input/v3-docs/TEST-SPEC.md section 4          -- the canonical table
//   input/v3-docs/skeleton/tests/voxel.test.mjs   -- the canonical case names
//   input/v3-docs/ARCHITECTURE.md section 3        -- the per-face shading law
//   input/v3-docs/skeleton/src/render/voxel.ts    -- the frozen exports

import test from "node:test";
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const moduleUrl = process.env.HNGH_FILL_MODULE
  ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
  : new URL("../out/render/voxel.js", import.meta.url).href;

const {
  mergeBoxes,
  broadleafModel,
  pineModel,
  boulderModel,
  crystalModel,
  berryModel,
  branchModel,
} = await import(moduleUrl);

// --- frozen constants (TEST-SPEC section 4) --------------------------------

const VERTS_PER_BOX = 36; // six quads, six vertices each, non-indexed
const SIDE_SHADE = 0.78;
const BOTTOM_SHADE = 0.62;

const TRUNK = [0.42, 0.3, 0.2];
const LEAF = [0.24, 0.55, 0.28];
const PINE = [0.18, 0.42, 0.27];
const STONE = [0.55, 0.55, 0.58];
const CRYSTAL = [0.4, 0.8, 0.85];
const BERRY = [0.8, 0.25, 0.2];
const BUSH = [0.26, 0.5, 0.3];

const near = (a, b, eps = 1e-6) => Math.abs(a - b) <= eps;
const nearColor = (actual, expected, eps = 1e-6) =>
  actual.length === expected.length &&
  actual.every((v, i) => near(v, expected[i], eps));
const scaled = (base, factor) => base.map((v) => v * factor);

// --- geometry helpers ------------------------------------------------------

function attribute(geometry, name) {
  const a = geometry.getAttribute(name);
  assert.ok(a, `the geometry carries a "${name}" attribute`);
  return a;
}

function flat(geometry, name) {
  return Array.from(attribute(geometry, name).array);
}

function bboxOf(flatPositions) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < flatPositions.length; i += 3) {
    for (let a = 0; a < 3; a += 1) {
      const v = flatPositions[i + a];
      if (v < min[a]) min[a] = v;
      if (v > max[a]) max[a] = v;
    }
  }
  return { min, max, size: [max[0] - min[0], max[1] - min[1], max[2] - min[2]] };
}

function bbox(geometry) {
  return bboxOf(flat(geometry, "position"));
}

// The merged geometry keeps the boxes in order, 36 vertices each.
function boxesOf(geometry) {
  const p = flat(geometry, "position");
  const c = flat(geometry, "color");
  const boxes = [];
  for (let v = 0; v + VERTS_PER_BOX <= p.length / 3; v += VERTS_PER_BOX) {
    const points = p.slice(v * 3, (v + VERTS_PER_BOX) * 3);
    const colors = c.slice(v * 3, (v + VERTS_PER_BOX) * 3);
    boxes.push({ points, colors, bbox: bboxOf(points) });
  }
  return boxes;
}

// Six quads of six vertices, each classified by its own geometry: the top
// face lies on the box's highest y, the bottom face on its lowest y, the
// four side faces span the full height.
function facesOf(box) {
  const faces = [];
  for (let q = 0; q < 6; q += 1) {
    const ys = [];
    for (let v = 0; v < 6; v += 1) ys.push(box.points[(q * 6 + v) * 3 + 1]);
    const flatY = ys.every((y) => near(y, ys[0], 1e-6));
    let kind = "side";
    if (flatY) {
      if (near(ys[0], box.bbox.max[1], 1e-6)) kind = "top";
      else if (near(ys[0], box.bbox.min[1], 1e-6)) kind = "bottom";
    }
    const colors = [];
    for (let v = 0; v < 6; v += 1) {
      const i = (q * 6 + v) * 3;
      colors.push([box.colors[i], box.colors[i + 1], box.colors[i + 2]]);
    }
    faces.push({ kind, colors });
  }
  return faces;
}

function colorOf(flatColors, vertex) {
  const i = vertex * 3;
  return [flatColors[i], flatColors[i + 1], flatColors[i + 2]];
}

// The frozen type is a readonly [r, g, b] tuple; a three.js Color is
// accepted too, so the case judges the colour and not the container.
function modelColor(model) {
  const c = model.color;
  if (Array.isArray(c)) return Array.from(c);
  return [c.r, c.g, c.b];
}

// The extents of a bbox as a sorted triple, so a test does not depend on
// which axis a model happens to be long in.
function sortedExtents(size) {
  return [...size].sort((a, b) => a - b);
}

function assertExtents(actual, expected, tol, label) {
  const got = sortedExtents(actual);
  const want = [...expected].sort((a, b) => a - b);
  got.forEach((v, i) => {
    assert.ok(
      Math.abs(v - want[i]) <= tol,
      `${label} extent ${i} is ${v}, expected ${want[i]} (tolerance ${tol})`,
    );
  });
}

// How far a box is from the canonical level L. L may be the box's bottom
// edge, its middle or its top edge, and it may be measured from the model's
// base or in absolute coordinates, so every reading is scored.
function levelScore(box, level, base) {
  const edges = [
    box.bbox.min[1],
    (box.bbox.min[1] + box.bbox.max[1]) / 2,
    box.bbox.max[1],
  ];
  return Math.min(
    ...edges.map((y) => Math.abs(y - level)),
    ...edges.map((y) => Math.abs(y - base - level)),
  );
}

// A box "is w wide" if either of its two ground-plane extents is w.
function isWidth(box, w, tol) {
  return near(box.bbox.size[0], w, tol) || near(box.bbox.size[2], w, tol);
}

// --- the six canonical cases ----------------------------------------------

test("mergeBoxes emits six faces per box", () => {
  const geometry = mergeBoxes([
    { x: 0, y: 0, z: 0, w: 0.4, h: 0.3, d: 0.2, color: [1, 1, 1] },
  ]);
  assert.equal(
    attribute(geometry, "position").count,
    36,
    "one box emits six quads -> 36 position vertices",
  );
  assert.equal(geometry.index, null, "the merged geometry is non-indexed");
  assert.equal(
    attribute(geometry, "color").count,
    36,
    "every vertex carries a baked colour",
  );
});

test("mergeBoxes shades sides and bottom darker than the top", () => {
  const geometry = mergeBoxes([
    { x: 0, y: 0, z: 0, w: 0.4, h: 0.3, d: 0.2, color: [1, 1, 1] },
  ]);
  const boxes = boxesOf(geometry);
  assert.equal(boxes.length, 1, "one box was merged");
  const faces = facesOf(boxes[0]);
  assert.equal(faces.length, 6, "a box is six quads");
  assert.equal(faces.filter((f) => f.kind === "top").length, 1, "one top quad");
  assert.equal(
    faces.filter((f) => f.kind === "bottom").length,
    1,
    "one bottom quad",
  );
  assert.equal(
    faces.filter((f) => f.kind === "side").length,
    4,
    "four side quads",
  );
  for (const face of faces) {
    const expected =
      face.kind === "top"
        ? [1, 1, 1]
        : face.kind === "bottom"
          ? scaled([1, 1, 1], BOTTOM_SHADE)
          : scaled([1, 1, 1], SIDE_SHADE);
    for (const color of face.colors) {
      assert.ok(nearColor(color, expected), `${face.kind} face colour`);
    }
  }
  // The frozen face layout puts the top quad first, and the top quad is the
  // one lying on the box's highest y.
  const positions = flat(geometry, "position");
  const maxY = bbox(geometry).max[1];
  for (let v = 0; v < 6; v += 1) {
    assert.ok(
      near(positions[v * 3 + 1], maxY, 1e-6),
      "the first six vertices are the top quad",
    );
  }
});

test("broadleafModel is trunk plus three canopy boxes", () => {
  const model = broadleafModel();
  const geometry = model.geometry;
  assert.equal(
    attribute(geometry, "position").count,
    144,
    "four boxes -> 144 vertices",
  );
  assert.ok(
    nearColor(modelColor(model), LEAF),
    "the representative colour is LEAF",
  );
  const boxes = boxesOf(geometry);
  assert.equal(
    boxes.length,
    4,
    "the broadleaf is a trunk plus three canopy boxes",
  );
  // The trunk is box 0, so the first 36 vertices carry the TRUNK colour,
  // shaded per face (top unchanged, sides 0.78, bottom 0.62).
  const trunk = boxes[0];
  for (let v = 0; v < 36; v += 1) {
    const color = colorOf(trunk.colors, v);
    assert.ok(
      nearColor(color, TRUNK) ||
        nearColor(color, scaled(TRUNK, SIDE_SHADE)) ||
        nearColor(color, scaled(TRUNK, BOTTOM_SHADE)),
      "the first 36 vertices carry the TRUNK colour",
    );
  }
  assert.ok(
    nearColor(colorOf(trunk.colors, 0), TRUNK),
    "the trunk's top quad keeps the base TRUNK colour",
  );
  const b = bbox(geometry);
  assertExtents(b.size, [0.7, 1.0, 0.625], 0.02, "broadleaf");
  assert.ok(near(b.size[1], 1.0, 0.02), `broadleaf height ${b.size[1]}`);
  assert.ok(
    near(Math.max(b.size[0], b.size[2]), 0.7, 0.02),
    `broadleaf width ${b.size[0]} x ${b.size[2]}`,
  );
});

test("pineModel is trunk plus three stacked boxes", () => {
  const model = pineModel();
  const geometry = model.geometry;
  assert.equal(
    attribute(geometry, "position").count,
    144,
    "four boxes -> 144 vertices",
  );
  assert.ok(
    nearColor(modelColor(model), PINE),
    "the representative colour is PINE",
  );
  const boxes = boxesOf(geometry);
  assert.equal(boxes.length, 4, "the pine is a trunk plus three canopy boxes");

  // The three canopy boxes are 0.62 / 0.45 / 0.26 wide and sit at y 0.45 /
  // 0.80 / 1.13, shrinking upwards; the fourth box is the trunk.
  const widths = [0.62, 0.45, 0.26];
  const levels = [0.45, 0.8, 1.13];
  const base = bbox(geometry).min[1];
  const used = new Set();
  const tiers = widths.map((width, i) => {
    const hits = boxes.filter(
      (b) => isWidth(b, width, 0.01) && !used.has(b),
    );
    assert.ok(
      hits.length > 0,
      `a canopy box is ${width} wide and sits at y ${levels[i]}`,
    );
    const tier = hits.reduce((best, b) =>
      levelScore(b, levels[i], base) < levelScore(best, levels[i], base)
        ? b
        : best,
    );
    assert.ok(
      levelScore(tier, levels[i], base) <= 0.02,
      `the ${width} wide canopy box sits at y ${levels[i]}`,
    );
    used.add(tier);
    return tier;
  });
  assert.equal(new Set(tiers).size, 3, "the three canopy boxes are distinct");
  const b = bbox(geometry);
  assert.ok(near(b.size[1], 1.29, 0.02), `pine height ${b.size[1]}`);
});

test("boulderModel is two or three offset boxes", () => {
  const model = boulderModel();
  const geometry = model.geometry;
  assert.equal(
    attribute(geometry, "position").count,
    108,
    "three boxes -> 108 vertices",
  );
  assert.ok(
    nearColor(modelColor(model), STONE),
    "the representative colour is STONE",
  );
  const boxes = boxesOf(geometry);
  assert.equal(boxes.length, 3, "the boulder is three boxes");
  const centres = boxes.map((b) =>
    b.bbox.min
      .map((v, i) => ((v + b.bbox.max[i]) / 2).toFixed(4))
      .join(","),
  );
  assert.ok(
    new Set(centres).size >= 2,
    "the boulder boxes are offset from each other",
  );
  assertExtents(bbox(geometry).size, [0.55, 0.4, 0.45], 0.02, "boulder");
});

test("item models are small", () => {
  const crystal = crystalModel();
  const berry = berryModel();
  const branch = branchModel();

  assert.equal(
    attribute(crystal.geometry, "position").count,
    144,
    "the crystal is four boxes -> 144 vertices",
  );
  assert.ok(
    nearColor(modelColor(crystal), CRYSTAL),
    "the crystal's representative colour is CRYSTAL",
  );
  assertExtents(
    bbox(crystal.geometry).size,
    [0.185, 0.345, 0.145],
    0.005,
    "crystal",
  );

  assert.equal(
    attribute(berry.geometry, "position").count,
    144,
    "the berry cluster is four boxes -> 144 vertices",
  );
  assert.ok(
    nearColor(modelColor(berry), BERRY),
    "the berry cluster's representative colour is BERRY",
  );
  assertExtents(bbox(berry.geometry).size, [0.22, 0.225, 0.22], 0.005, "berry");
  // The berry model's first box is the BUSH box, so its first vertex colour
  // is BUSH.
  const berryColors = flat(berry.geometry, "color");
  assert.ok(
    nearColor(colorOf(berryColors, 0), BUSH),
    "the berry model's first vertex colour is BUSH",
  );

  assert.equal(
    attribute(branch.geometry, "position").count,
    108,
    "the branch is three boxes -> 108 vertices",
  );
  assert.ok(
    nearColor(modelColor(branch), TRUNK),
    "the branch's representative colour is TRUNK",
  );
  assertExtents(bbox(branch.geometry).size, [0.3, 0.095, 0.1], 0.005, "branch");

  for (const [name, geometry] of [
    ["crystal", crystal.geometry],
    ["berry", berry.geometry],
    ["branch", branch.geometry],
  ]) {
    const size = bbox(geometry).size;
    assert.ok(
      Math.max(...size) <= 0.35,
      `the ${name}'s largest extent ${Math.max(...size)} stays under 0.35`,
    );
  }
});
