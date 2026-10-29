import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { decodeSlab, plateSlab, meshSlab } from "../out/core/slab.js";

const here = dirname(fileURLToPath(import.meta.url));
const slabPath = (name) => join(here, `../vendor/cistern/assets/slabs/${name}.json`);

// Flatten the vendor's number[][][] literal into the bake law's base64 form:
// index = (x*(side+depth) + y)*side + z. (bake-donors.mjs does this for the app;
// the test must not import the generated module.)
function vendorSlab(name) {
  const j = JSON.parse(readFileSync(slabPath(name), "utf8"));
  const nx = j.side;
  const ny = j.side + j.depth;
  const nz = j.side;
  const bytes = new Uint8Array(nx * ny * nz);
  for (let x = 0; x < nx; x++) {
    for (let y = 0; y < ny; y++) {
      for (let z = 0; z < nz; z++) bytes[(x * ny + y) * nz + z] = j.volume[x][y][z];
    }
  }
  return {
    side: j.side,
    depth: j.depth,
    profile: j.profile,
    palette: j.palette,
    volumeB64: Buffer.from(bytes).toString("base64"),
    quads: j.quads,
  };
}

const load = (name) => decodeSlab(vendorSlab(name));

test("expected quad counts over the vendored bake volumes", () => {
  const cases = [
    ["tile_floor", { plate: true, omitBottom: false }, 704],
    ["tile_floor", { plate: true, omitBottom: true }, 448],
    ["tile_wall", { plate: false, omitBottom: false }, 1536],
    ["tile_gate", { plate: false, omitBottom: false }, 1344],
    ["tile_settlement", { plate: false, omitBottom: false }, 740],
    ["tile_gantry", { plate: true, omitBottom: false }, 572],
    ["prop_crystal", { plate: false, omitBottom: false }, 258],
  ];
  for (const [name, opts, want] of cases) {
    let v = load(name);
    if (opts.plate) v = plateSlab(v);
    const mesh = meshSlab(v, { omitBottom: opts.omitBottom });
    assert.equal(mesh.quadCount, want, `${name} quad count (plate=${opts.plate}, omitBottom=${opts.omitBottom})`);
    assert.equal(mesh.positions.length, want * 6 * 3, `${name} positions length`);
    assert.equal(mesh.normals.length, want * 6 * 3, `${name} normals length`);
    assert.equal(mesh.colors.length, want * 6 * 3, `${name} colors length`);
  }
});

test("every emitted colour is palette/255 shaded 1.0 or 0.78", () => {
  for (const name of ["tile_floor", "tile_wall", "prop_crystal"]) {
    const { palette } = load(name);
    const mesh = meshSlab(load(name));
    const isPaletteShade = (r, g, b) =>
      palette.some(([pr, pg, pb]) =>
        [1.0, 0.78].some((s) =>
          Math.abs(r - (pr / 255) * s) <= 1e-6 &&
          Math.abs(g - (pg / 255) * s) <= 1e-6 &&
          Math.abs(b - (pb / 255) * s) <= 1e-6,
        ),
      );
    for (let i = 0; i < mesh.colors.length; i += 3) {
      assert.ok(
        isPaletteShade(mesh.colors[i], mesh.colors[i + 1], mesh.colors[i + 2]),
        `${name} colour at vertex ${i / 3}`,
      );
    }
  }
});

test("top faces shade 1.0, all other faces 0.78 (synthetic volume)", () => {
  // 1x1x1 solid voxel with a distinct palette colour: 6 quads, 5 shaded.
  const slab = {
    side: 1, depth: 0, profile: "flat",
    palette: [[255, 128, 2]],
    volumeB64: Buffer.from([1]).toString("base64"),
    quads: 6,
  };
  const mesh = meshSlab(decodeSlab(slab));
  assert.equal(mesh.quadCount, 6);
  let top = 0;
  let side = 0;
  // per-vertex arrays: a quad is 6 vertices x 3 floats; read quad q's first vertex.
  for (let q = 0; q < 6; q++) {
    const base = q * 6 * 3;
    const [nx, ny, nz] = [mesh.normals[base], mesh.normals[base + 1], mesh.normals[base + 2]];
    const want = nx === 0 && ny === 0 && nz === 1 ? 1.0 : 0.78;
    if (want === 1.0) top++; else side++;
    assert.ok(Math.abs(mesh.colors[base] - want) <= 1e-6, `r of quad ${q}`);
    assert.ok(Math.abs(mesh.colors[base + 1] - (128 / 255) * want) <= 1e-6, `g of quad ${q}`);
    assert.ok(Math.abs(mesh.colors[base + 2] - (2 / 255) * want) <= 1e-6, `b of quad ${q}`);
  }
  assert.equal(top, 1);
  assert.equal(side, 5);
});

test("decodeSlab and plateSlab follow the bake index laws (synthetic volume)", () => {
  // side=2, depth=1: dims [2, 3, 2]; yMid = 3//2 - 1 = 0 is the image face.
  const b64 = Buffer.from([
    // x=0: y=0 -> [1,2], y=1 -> [0,0], y=2 -> [0,0]
    1, 2, 0, 0, 0, 0,
    // x=1: y=0 -> [3,4], y=1 -> [0,5], y=2 -> [0,0]
    3, 4, 0, 5, 0, 0,
  ]).toString("base64");
  const slab = {
    side: 2, depth: 1, profile: "flat",
    palette: [[10, 20, 30], [40, 50, 60], [70, 80, 90], [100, 110, 120], [130, 140, 150]],
    volumeB64: b64,
    quads: 0,
  };
  const v = decodeSlab(slab);
  assert.deepEqual(v.dims, [2, 3, 2]);
  assert.equal(v.volume.length, 12);
  assert.equal(v.volume[(0 * 3 + 0) * 2 + 1], 2, "decode index law");

  const p = plateSlab(v);
  assert.deepEqual(p.dims, [2, 2, 1]);
  // plate keeps [x][row][z]: out[(x*2+row)*1+0] = image face value at row.
  assert.deepEqual([...p.volume], [1, 2, 3, 4]);
});
