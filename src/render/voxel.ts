/**
 * Small voxel model builders for the open-world scatter (v3).
 *
 * Every model is a handful of boxes merged into one BufferGeometry with a
 * per-vertex "color" attribute carrying the donor's structural shading:
 * top faces at base colour, sides x0.78, bottom x0.62 (Hd2d slab law,
 * structural only — the material renders unlit). Sizes are world units.
 */

import * as THREE from "three";

export interface VoxelModel {
  geometry: THREE.BufferGeometry;
  /** Representative base colour (foliage / stone / item), for tint reference. */
  color: readonly [number, number, number];
}

export interface VoxelBox {
  x: number;
  y: number;
  z: number;
  w: number;
  h: number;
  d: number;
  color: readonly [number, number, number];
}

/** Donor structural face shading (slab sides / undersides). */
const SIDE_SHADE = 0.78;
const BOTTOM_SHADE = 0.62;

/** Merge axis-aligned boxes into one vertex-coloured, non-indexed geometry. */
export function mergeBoxes(boxes: VoxelBox[]): THREE.BufferGeometry {
  const pos: number[] = [];
  const col: number[] = [];

  // quad(corners CCW seen from outside, colour)
  const quad = (a: number[], b: number[], c: number[], d: number[], rgb: readonly [number, number, number]): void => {
    for (const v of [a, b, c, a, c, d]) {
      pos.push(v[0], v[1], v[2]);
      col.push(rgb[0], rgb[1], rgb[2]);
    }
  };

  for (const b of boxes) {
    const x0 = b.x - b.w / 2, x1 = b.x + b.w / 2;
    const y0 = b.y - b.h / 2, y1 = b.y + b.h / 2;
    const z0 = b.z - b.d / 2, z1 = b.z + b.d / 2;
    const top = b.color;
    const side: [number, number, number] = [b.color[0] * SIDE_SHADE, b.color[1] * SIDE_SHADE, b.color[2] * SIDE_SHADE];
    const bottom: [number, number, number] = [b.color[0] * BOTTOM_SHADE, b.color[1] * BOTTOM_SHADE, b.color[2] * BOTTOM_SHADE];
    // three.js space: cell (gx,gy) -> x east, z south; +y is up.
    quad([x0, y1, z1], [x1, y1, z1], [x1, y1, z0], [x0, y1, z0], top);        // top
    quad([x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], bottom);     // bottom
    quad([x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], side);       // +z
    quad([x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0], side);       // -z
    quad([x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1], side);       // +x
    quad([x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], side);       // -x
  }

  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("color", new THREE.Float32BufferAttribute(col, 3));
  return g;
}

const TRUNK: readonly [number, number, number] = [0.42, 0.3, 0.2];
const LEAF: readonly [number, number, number] = [0.24, 0.55, 0.28];
const LEAF_DARK: readonly [number, number, number] = [0.19, 0.46, 0.26];
const PINE: readonly [number, number, number] = [0.18, 0.42, 0.27];
const STONE: readonly [number, number, number] = [0.55, 0.55, 0.58];
const CRYSTAL: readonly [number, number, number] = [0.4, 0.8, 0.85];
const BERRY: readonly [number, number, number] = [0.8, 0.25, 0.2];
const BUSH: readonly [number, number, number] = [0.26, 0.5, 0.3];

/** Broadleaf: trunk + 3 offset canopy boxes, ~1.0 tall, ~0.7 wide. */
export function broadleafModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.175, z: 0, w: 0.14, h: 0.35, d: 0.14, color: TRUNK },
      { x: 0, y: 0.45, z: 0, w: 0.55, h: 0.3, d: 0.55, color: LEAF_DARK },
      { x: 0.06, y: 0.68, z: 0.04, w: 0.7, h: 0.28, d: 0.62, color: LEAF },
      { x: -0.04, y: 0.9, z: -0.02, w: 0.4, h: 0.2, d: 0.38, color: LEAF_DARK },
    ]),
    color: LEAF,
  };
}

/** Pine: trunk + 3 stacked shrinking boxes, ~1.3 tall. */
export function pineModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.15, z: 0, w: 0.12, h: 0.3, d: 0.12, color: TRUNK },
      { x: 0, y: 0.45, z: 0, w: 0.62, h: 0.35, d: 0.62, color: PINE },
      { x: 0, y: 0.8, z: 0, w: 0.45, h: 0.35, d: 0.45, color: PINE },
      { x: 0, y: 1.13, z: 0, w: 0.26, h: 0.32, d: 0.26, color: PINE },
    ]),
    color: PINE,
  };
}

/** Boulder: 2-3 offset stone boxes, ~0.5 wide. */
export function boulderModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.15, z: 0, w: 0.5, h: 0.3, d: 0.45, color: STONE },
      { x: 0.14, y: 0.3, z: 0.06, w: 0.3, h: 0.2, d: 0.28, color: STONE },
      { x: -0.16, y: 0.26, z: -0.1, w: 0.2, h: 0.14, d: 0.18, color: STONE },
    ]),
    color: STONE,
  };
}

/** Crystal shard, ~0.25 tall (item). */
export function crystalModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.05, z: 0, w: 0.14, h: 0.1, d: 0.14, color: CRYSTAL },
      { x: 0, y: 0.18, z: 0, w: 0.09, h: 0.16, d: 0.09, color: CRYSTAL },
      { x: 0.01, y: 0.3, z: 0, w: 0.05, h: 0.09, d: 0.05, color: CRYSTAL },
      { x: 0.09, y: 0.09, z: 0.05, w: 0.05, h: 0.08, d: 0.05, color: CRYSTAL },
    ]),
    color: CRYSTAL,
  };
}

/** Berry cluster: tiny bush with berries, ~0.25 wide (item). */
export function berryModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.08, z: 0, w: 0.22, h: 0.16, d: 0.22, color: BUSH },
      { x: -0.06, y: 0.19, z: 0.04, w: 0.06, h: 0.06, d: 0.06, color: BERRY },
      { x: 0.05, y: 0.18, z: -0.03, w: 0.05, h: 0.05, d: 0.05, color: BERRY },
      { x: 0.02, y: 0.2, z: 0.07, w: 0.05, h: 0.05, d: 0.05, color: BERRY },
    ]),
    color: BERRY,
  };
}

/** Fallen branch: long thin box + offshoot stub, ~0.3 long (item). */
export function branchModel(): VoxelModel {
  return {
    geometry: mergeBoxes([
      { x: 0, y: 0.035, z: 0, w: 0.3, h: 0.05, d: 0.06, color: TRUNK },
      { x: 0.06, y: 0.08, z: 0.02, w: 0.06, h: 0.05, d: 0.05, color: TRUNK },
      { x: -0.08, y: 0.07, z: -0.03, w: 0.05, h: 0.05, d: 0.05, color: TRUNK },
    ]),
    color: TRUNK,
  };
}
