/**
 * Baked voxel slab -> triangle-soup mesh (the archived Rust HD lane's
 * law). Positions are in voxel units in bake coordinates: x east,
 * y north, z up. Vertex colour = palette[value-1]/255 shaded by face —
 * 1.0 for +z, 0.78 otherwise.
 */

import type { SlabJson } from "../types/donors.js";

export interface SlabVolume {
  /** [x, y, z] extents; index = (x*ny + y)*nz + z. */
  dims: [number, number, number];
  palette: [number, number, number][];
  /** 0 = empty, v = palette[v - 1]. */
  volume: Uint8Array;
}

export function decodeSlab(slab: SlabJson): SlabVolume {
  return {
    dims: [slab.side, slab.side + slab.depth, slab.side],
    palette: slab.palette,
    volume: Uint8Array.from(atob(slab.volumeB64), (c) => c.charCodeAt(0)),
  };
}

/**
 * Floor-layer re-orientation (Rust slab.rs `plate`): collapse the bake's
 * depth axis onto the image face at y = (side+depth)//2 - 1, extruded
 * through every thickness layer. dims become [side, side, depth].
 */
export function plateSlab(v: SlabVolume): SlabVolume {
  const [side, sidePlusDepth, imgSide] = v.dims;
  const depth = sidePlusDepth - side;
  const yMid = Math.floor(sidePlusDepth / 2) - 1;
  const out = new Uint8Array(side * side * depth);
  for (let x = 0; x < side; x++) {
    for (let row = 0; row < side; row++) {
      const face = v.volume[(x * sidePlusDepth + yMid) * imgSide + row]!;
      for (let z = 0; z < depth; z++) out[(x * side + row) * depth + z] = face;
    }
  }
  return { dims: [side, side, depth], palette: v.palette, volume: out };
}

export interface SlabMesh {
  positions: Float32Array;
  normals: Float32Array;
  colors: Float32Array;
  quadCount: number;
}

const SHADE_TOP = 1.0;
const SHADE_SIDE = 0.78;

/** Face directions in emission order: (axis, sign); +z is up. */
const FACES: ReadonlyArray<readonly [number, number]> = [
  [2, 1], [2, -1], [0, 1], [0, -1], [1, 1], [1, -1],
];

/** CCW corner offsets (seen from outside) for each face direction. */
const CORNERS: Record<string, ReadonlyArray<readonly [number, number, number]>> = {
  "2,1": [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]],
  "2,-1": [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]],
  "0,1": [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]],
  "0,-1": [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]],
  "1,1": [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]],
  "1,-1": [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]],
};

export function meshSlab(v: SlabVolume, opts?: { omitBottom?: boolean }): SlabMesh {
  const [nx, ny, nz] = v.dims;
  const vol = v.volume;
  const skipBottom = opts?.omitBottom === true;
  const exposed = (x: number, y: number, z: number): boolean =>
    x < 0 || y < 0 || z < 0 || x >= nx || y >= ny || z >= nz || vol[(x * ny + y) * nz + z] === 0;

  // Pass 1: count quads; pass 2: fill the exact-size buffers.
  let quadCount = 0;
  for (let x = 0; x < nx; x++) {
    for (let y = 0; y < ny; y++) {
      for (let z = 0; z < nz; z++) {
        if (vol[(x * ny + y) * nz + z] === 0) continue;
        for (const [axis, sign] of FACES) {
          if (skipBottom && axis === 2 && sign === -1) continue;
          const c = [x, y, z];
          c[axis] += sign;
          if (exposed(c[0]!, c[1]!, c[2]!)) quadCount++;
        }
      }
    }
  }

  const positions = new Float32Array(quadCount * 6 * 3);
  const normals = new Float32Array(quadCount * 6 * 3);
  const colors = new Float32Array(quadCount * 6 * 3);
  let vi = 0;

  for (let x = 0; x < nx; x++) {
    for (let y = 0; y < ny; y++) {
      for (let z = 0; z < nz; z++) {
        const value = vol[(x * ny + y) * nz + z]!;
        if (value === 0) continue;
        const [pr, pg, pb] = v.palette[value - 1]!;
        for (const [axis, sign] of FACES) {
          if (skipBottom && axis === 2 && sign === -1) continue;
          const c = [x, y, z];
          c[axis] += sign;
          if (!exposed(c[0]!, c[1]!, c[2]!)) continue;
          const shade = axis === 2 && sign === 1 ? SHADE_TOP : SHADE_SIDE;
          const r = (pr / 255) * shade;
          const g = (pg / 255) * shade;
          const b = (pb / 255) * shade;
          const n: [number, number, number] = [0, 0, 0];
          n[axis] = sign;
          for (const i of [0, 1, 2, 0, 2, 3]) {
            const o = CORNERS[`${axis},${sign}`]![i]!;
            positions[vi] = x + o[0];
            positions[vi + 1] = y + o[1];
            positions[vi + 2] = z + o[2];
            normals[vi] = n[0];
            normals[vi + 1] = n[1];
            normals[vi + 2] = n[2];
            colors[vi] = r;
            colors[vi + 1] = g;
            colors[vi + 2] = b;
            vi += 3;
          }
        }
      }
    }
  }

  return { positions, normals, colors, quadCount };
}
