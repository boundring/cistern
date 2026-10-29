/**
 * Walk-phase math: a figure's gait is a pure function of the ground it
 * covers (one stride = one full cycle), so the animation always matches
 * the distance travelled. Idle is a slow deterministic bob of elapsed
 * seconds — no wall clock, no Math.random.
 */

/** World units covered by one full walk cycle. */
export const STRIDE = 1.0;

/** Two pi, spelled out so the phase identity is literal. */
const TAU = Math.PI * 2;

/** Idle bob frequency in Hz. */
export const IDLE_HZ = 1.2;
/** Idle bob amplitude in world units. */
export const IDLE_AMP = 0.02;

export interface WalkPose {
  /** cycle phase in radians */
  phase: number;
  /** sin(phase) — limb swing driver */
  swing: number;
  /** |sin(phase)| — body bob driver */
  bob: number;
}

/** phase = distance * TAU / STRIDE (radians, 0 at distance 0). */
export function walkPhase(distance: number): number {
  return (distance * TAU) / STRIDE;
}

/** pose from a phase: swing = sin(phase), bob = |sin(phase)|. */
export function walkPose(phase: number): WalkPose {
  return { phase, swing: Math.sin(phase), bob: Math.abs(Math.sin(phase)) };
}

/** idle pose: swing 0, bob = sin(elapsed * TAU * IDLE_HZ) * IDLE_AMP. */
export function idlePose(elapsedSeconds: number): WalkPose {
  return {
    phase: 0,
    swing: 0,
    bob: Math.sin(elapsedSeconds * TAU * IDLE_HZ) * IDLE_AMP,
  };
}
