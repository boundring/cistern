/**
 * SKELETON -- no implementation. Target path: src/render/world.ts
 * Owning slice: D -- render-world-terrain
 *
 * Responsibility: own the open-world renderer -- one merged, vertex-coloured
 * terrain BufferGeometry over the whole vista footprint (top face per cell,
 * side faces only where the neighbour is lower, the town footprint skipped
 * and the town edge skirted), the translucent water plane with its
 * deterministic bob, and the hash-scatter placement of the voxel trees, rocks
 * and items with their live counts. It must NOT own the terrain law (it
 * consumes a TerrainField), the constants (it imports src/core/terrain.ts),
 * the voxel model catalogue, the figure rig, the camera or the game layer.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice D").
 */

import * as THREE from "three";
import type { TerrainKind } from "../core/terrain.js";

export interface TerrainField {          // structurally satisfied by WorldHeightmap
  stepsAtCell(gx: number, gy: number): number;
  kindAt(gx: number, gy: number): TerrainKind;
  tableHeight(): number;
  villageHeight(): number;
}
export interface WorldViewOptions {
  playableW: number; playableH: number;
  marginX: number; marginZ: number;
  townOriginX: number; townOriginY: number;
  townW: number; townH: number;
  seed: number;                          // ScatterHash seed
}
export class WorldView {
  readonly group: THREE.Group;
  readonly counts: { cells: number; trees: number; rocks: number; items: number };
  constructor(field: TerrainField, opts: WorldViewOptions) {
    throw new Error("not implemented: WorldView");
  }
  /** terrain top height at a world cell, in world units */
  heightAt(gx: number, gy: number): number {
    throw new Error("not implemented: WorldView.heightAt");
  }
  /** deterministic water animation (call once per frame) */
  update(elapsedSeconds: number): void {
    throw new Error("not implemented: WorldView.update");
  }
}
