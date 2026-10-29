/**
 * SKELETON -- no implementation. Target path: src/render/scene.ts
 * Owning slice: integration (orchestrator)
 *
 * Responsibility: own the three.js scene -- the renderer, the HD-2D voxel
 * diorama (one InstancedMesh per tile kind plus the deco props), the themed
 * background, fog and lights, the world and figure groups the integration
 * adds, pointer picking, the resize path and the pixel probe. It must NOT
 * own the world law, the terrain renderer, the figure rig, the camera, the
 * inspector, the game state or the copy text.
 *
 * Signatures are taken from src/render/scene.ts (the orchestrator owns the
 * integration files; CONTRACT.md does not freeze this module's shape).
 */

import * as THREE from "three";
import type { Donors } from "../types/donors.js";
import type { TownModel } from "../core/town.js";
import type { PixelProbe } from "../types/game.js";

/** Where the town diorama sits in the open world, and how far the fog reaches. */
export interface TownSceneOptions {
  /** Town origin in world cell coordinates (east, south). */
  townOffsetX: number;
  townOffsetZ: number;
  /** World height of the town's walking surface (the village flat). */
  townGroundY: number;
  /** Fog density; the v3 world is four times the v2 footprint. */
  fogDensity: number;
}

/** The HD-2D voxel diorama: one InstancedMesh per tile kind plus the deco
 * props, themed background/fog/lights, and pointer picking. */
export class TownScene {
  /** Orbit target for the app's OrbitCamera (contract superset). */
  readonly camera: THREE.PerspectiveCamera;
  /** The three.js scene: the world view and the figures are added to it. */
  readonly scene: THREE.Scene;
  readonly counts: { floor: number; structure: number; props: number };
  /** The canvas this scene renders into. */
  readonly canvas: HTMLCanvasElement;
  constructor(
    canvas: HTMLCanvasElement,
    town: TownModel,
    donors: Donors,
    options: TownSceneOptions,
  ) {
    throw new Error("not implemented: TownScene");
  }
  groundHeight(x: number, y: number): number {
    throw new Error("not implemented: TownScene.groundHeight");
  }
  resize(w: number, h: number): void {
    throw new Error("not implemented: TownScene.resize");
  }
  render(): void {
    throw new Error("not implemented: TownScene.render");
  }
  probePixels(x: number, y: number, w: number, h: number): PixelProbe | null {
    throw new Error("not implemented: TownScene.probePixels");
  }
  pick(clientX: number, clientY: number): { x: number; y: number } | null {
    throw new Error("not implemented: TownScene.pick");
  }
}
