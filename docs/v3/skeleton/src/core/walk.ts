/**
 * SKELETON -- no implementation. Target path: src/core/walk.ts
 * Owning slice: C -- core-walk-math
 *
 * Responsibility: own the walk-cycle math -- the phase identity (phase =
 * distance * TAU / STRIDE), the pose derivation (swing = sin(phase),
 * bob = |sin(phase)|) and the deterministic idle bob -- so that a figure's
 * animation always matches the ground it covers. It must NOT own the figure
 * rig, the renderer, the noise or the game layer; it is pure arithmetic
 * over distance and elapsed seconds.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice C"); IDLE_HZ and
 * IDLE_AMP are taken from src/core/walk.ts (the real module's exported
 * constants -- CONTRACT.md lists only STRIDE).
 */

/** World units covered by one full walk cycle. */
export const STRIDE = 1.0;
/** Idle bob frequency in Hz. */
export const IDLE_HZ = 1.2;
/** Idle bob amplitude in world units. */
export const IDLE_AMP = 0.02;

export interface WalkPose {
  /** cycle phase in radians */
  phase: number;
  /** sin(phase) -- limb swing driver */
  swing: number;
  /** |sin(phase)| -- body bob driver */
  bob: number;
}

/** phase = distance * TAU / STRIDE (radians, 0 at distance 0). */
export function walkPhase(distance: number): number {
  throw new Error("not implemented: walkPhase");
}

/** pose from a phase: swing = sin(phase), bob = |sin(phase)|. */
export function walkPose(phase: number): WalkPose {
  throw new Error("not implemented: walkPose");
}

/** idle pose: a slow deterministic bob. */
export function idlePose(elapsedSeconds: number): WalkPose {
  throw new Error("not implemented: idlePose");
}
