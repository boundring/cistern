/**
 * SKELETON -- no implementation. Target path: src/render/camera.ts
 * Owning slice: E -- render-camera
 *
 * Responsibility: own the free orbit camera -- yaw unbounded, pitch clamped,
 * distance clamped to the v3 range (DIST_MIN 3 for close-ups, DIST_MAX 140
 * for the whole world) -- and the orbit focus point, which moves in place so
 * held references stay valid. It must NOT own the scene, the world renderer,
 * the figures, the inspector, the input wiring or the game layer.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice E") and
 * src/render/camera.ts.
 */

import * as THREE from "three";

export class OrbitCamera {
  yaw = -0.6;
  pitch = 0.7;
  distance = 36;
  /** Orbit focus; mutate in place via setTarget so held references stay valid. */
  readonly target: THREE.Vector3;
  constructor(camera: THREE.PerspectiveCamera, target: THREE.Vector3) {
    throw new Error("not implemented: OrbitCamera");
  }
  /** Move the orbit focus (mutates in place). */
  setTarget(v: THREE.Vector3): void {
    throw new Error("not implemented: OrbitCamera.setTarget");
  }
  /** Absolute set; omitted axes keep their current value. */
  set(yaw?: number, pitch?: number, distance?: number): void {
    throw new Error("not implemented: OrbitCamera.set");
  }
  apply(): void {
    throw new Error("not implemented: OrbitCamera.apply");
  }
}
