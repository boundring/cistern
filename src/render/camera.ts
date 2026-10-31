import * as THREE from "three";

const PITCH_MIN = 0.18;
const PITCH_MAX = 1.35;
const DIST_MIN = 3;
const DIST_MAX = 140;

/** The default orbit framing: the whole playable grid plus its margin ring. */
export const DEFAULT_PITCH = 0.72;
export const DEFAULT_DISTANCE = 60;

/** Free orbit around a target: yaw unbounded, pitch and distance clamped. */
export class OrbitCamera {
  yaw = -0.6;
  pitch = DEFAULT_PITCH;
  distance = DEFAULT_DISTANCE;
  /** Orbit focus; mutate in place via setTarget so held references stay valid. */
  readonly target: THREE.Vector3;

  constructor(
    private readonly camera: THREE.PerspectiveCamera,
    target: THREE.Vector3,
  ) {
    this.target = target;
  }

  /** Move the orbit focus (mutates in place). */
  setTarget(v: THREE.Vector3): void {
    this.target.copy(v);
  }
  /** Absolute set; omitted axes keep their current value. */
  set(yaw?: number, pitch?: number, distance?: number): void {
    if (yaw !== undefined) this.yaw = yaw;
    if (pitch !== undefined) this.pitch = THREE.MathUtils.clamp(pitch, PITCH_MIN, PITCH_MAX);
    if (distance !== undefined) this.distance = THREE.MathUtils.clamp(distance, DIST_MIN, DIST_MAX);
  }

  apply(): void {
    const cp = Math.cos(this.pitch);
    this.camera.position.set(
      this.target.x + this.distance * cp * Math.sin(this.yaw),
      this.target.y + this.distance * Math.sin(this.pitch),
      this.target.z + this.distance * cp * Math.cos(this.yaw),
    );
    this.camera.lookAt(this.target);
    // Raycaster.setFromCamera reads matrixWorld directly; keep it fresh even
    // when a pick lands before the next render.
    this.camera.updateMatrixWorld();
  }
}
