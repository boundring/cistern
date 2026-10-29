/**
 * Shared game-API contract: `window.game` is the agent test surface required
 * by the charter. Every module in `src/` that touches the API codes against
 * these types so the render, game and test layers cannot drift apart.
 */

/** What the inspector shows for one selected town cell. */
export interface Selection {
  /** Town cell x, 0 <= x < width. */
  x: number;
  /** Town cell y, 0 <= y < height. */
  y: number;
  /** Wire tile id at that cell (frozen 14-id vocabulary). */
  tile: string;
  /** Copy-table key resolved for that tile id. */
  copyKey: string;
  /** Copy-table display text for `copyKey` (the same text the panel shows). */
  text: string;
}

/** View state (floats are fine here; this is not game state). */
export interface CameraState {
  /** Orbit azimuth, radians. */
  yaw: number;
  /** Orbit pitch above the ground plane, radians. */
  pitch: number;
  /** Orbit distance in town cells. */
  distance: number;
}

/** Serializable, integer-only game state plus the current selection. */
export interface GameState {
  /** Pinned seed the town was built from. */
  seed: number;
  width: number;
  height: number;
  /**
   * Row-major wire tile ids, index = y * width + x. Row strings are the
   * dressed town (template + FLAVOR grass), matching the donor golden vector.
   */
  tiles: string[];
  /** Currently inspected cell, or null when nothing is selected. */
  selection: Selection | null;
  /** Live ambient townsfolk, in sim actor order. */
  townsfolk: { id: number; x: number; y: number; speed: number }[];
  /** Length of the sim's canonical event transcript. */
  eventCount: number;
  camera: CameraState;
  counts: {
    /** Cells drawn from a floor-layer slab (incl. fallbacks). */
    floor: number;
    /** Cells drawn from a structure-layer slab (wall/gate/settlement). */
    structure: number;
    /** Scattered prop instances. */
    props: number;
    /** Rendered entity billboards. */
    townsfolk: number;
  };
}

/** The one defined intent family `dispatch` accepts. */
export type Intent =
  | { type: "inspect"; x: number; y: number }
  | { type: "orbit"; yaw?: number; pitch?: number }
  | { type: "zoom"; distance: number }
  /** Advance the ambient sim n ticks (default 1). */
  | { type: "tick"; n?: number }
  | { type: "reset" };

export type IntentResult =
  | { ok: true; state: GameState }
  | { ok: false; error: string };

export interface GameApi {
  dispatch(intent: Intent): IntentResult;
  state(): GameState;
}

declare global {
  interface Window {
    game: GameApi;
  }
}
