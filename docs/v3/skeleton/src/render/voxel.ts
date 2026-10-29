/**
 * SKELETON -- no implementation. Target path: src/render/voxel.ts
 * Owning slice: D -- render-world-terrain / voxel models
 *
 * Responsibility: own the small voxel model builders used by the world
 * scatter -- the box merger that bakes per-face shading into one
 * vertex-coloured geometry, and the model catalogue (broadleaf, pine,
 * boulder, and the small items: crystal, berry cluster, branch). It must NOT
 * own placement (that is the scatter law and the world renderer), the world
 * renderer, the figure rig, the camera or the game layer: it produces
 * geometries and their representative base colour, nothing more.
 *
 * Signatures are taken from src/render/voxel.ts (the model catalogue is not
 * frozen in CONTRACT.md; CONTRACT.md names the models and their shapes).
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

/** Merge axis-aligned boxes into one vertex-coloured, non-indexed geometry. */
export function mergeBoxes(boxes: VoxelBox[]): THREE.BufferGeometry {
  throw new Error("not implemented: mergeBoxes");
}

/** Broadleaf: trunk + 3 offset canopy boxes, ~1.0 tall, ~0.7 wide. */
export function broadleafModel(): VoxelModel {
  throw new Error("not implemented: broadleafModel");
}

/** Pine: trunk + 3 stacked shrinking boxes, ~1.3 tall. */
export function pineModel(): VoxelModel {
  throw new Error("not implemented: pineModel");
}

/** Boulder: 2-3 offset stone boxes, ~0.5 wide. */
export function boulderModel(): VoxelModel {
  throw new Error("not implemented: boulderModel");
}

/** Crystal shard, ~0.25 tall (item). */
export function crystalModel(): VoxelModel {
  throw new Error("not implemented: crystalModel");
}

/** Berry cluster: tiny bush with berries, ~0.25 wide (item). */
export function berryModel(): VoxelModel {
  throw new Error("not implemented: berryModel");
}

/** Fallen branch: long thin box + offshoot stub, ~0.3 long (item). */
export function branchModel(): VoxelModel {
  throw new Error("not implemented: branchModel");
}
