/**
 * SKELETON -- no implementation. Target path: src/render/figures.ts
 * Owning slice: C -- render-figures-rig
 *
 * Responsibility: own the voxel character rig -- the box hierarchy
 * root > body (bob) > { torso, head, armL, armR, legL, legR } with the limbs
 * pivoting at their top -- the per-figure garment tint from the donor
 * billboard palette and the scatter hash, the interpolation of a figure from
 * one cell to the next, and the per-frame walk cycle, idle bob and facing
 * update. It must NOT own the walk math (it consumes src/core/walk.ts), the
 * scatter hash itself, the terrain law, the world renderer, the camera or
 * the game layer.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice C").
 */

import * as THREE from "three";

export type FigureKind = "player" | "townsfolk" | "villager";
export interface FigureOptions { stepDurationMs?: number; }
export class VoxelFigures {
  readonly group: THREE.Group;
  constructor(opts?: FigureOptions) {
    throw new Error("not implemented: VoxelFigures");
  }
  spawn(id: number, kind: FigureKind, x: number, y: number, ground: number): void {
    throw new Error("not implemented: VoxelFigures.spawn");
  }
  /** new cell; the figure interpolates over stepDurationMs and turns to face it */
  moveTo(id: number, x: number, y: number, ground: number): void {
    throw new Error("not implemented: VoxelFigures.moveTo");
  }
  /** per-frame: walk cycle, idle bob, facing */
  update(elapsedMs: number, camera: THREE.PerspectiveCamera): void {
    throw new Error("not implemented: VoxelFigures.update");
  }
  /** world position of a figure (for camera focus / pixel probes) */
  positionOf(id: number): THREE.Vector3 | null {
    throw new Error("not implemented: VoxelFigures.positionOf");
  }
  count(): number {
    throw new Error("not implemented: VoxelFigures.count");
  }
  remove(id: number): void {
    throw new Error("not implemented: VoxelFigures.remove");
  }
}
