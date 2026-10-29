/**
 * Shared game-API contract: `window.game` is the agent test surface required
 * by the charter. Every module in `src/` that touches the API codes against
 * these types so the render, game and test layers cannot drift apart.
 */

import type { TerrainKind } from "../core/terrain.js";

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
  /** The v3 open world under that cell (absent outside the world grid). */
  terrain?: {
    kind: TerrainKind;
    /** Relief steps at the cell (donor law). */
    steps: number;
    /** Terrain top height in world units. */
    height: number;
    /** True when the cell is below the water table. */
    water: boolean;
  };
  /** The figure standing on that cell, when one is there. */
  figure?: { id: number; kind: string };
}

/** View state (floats are fine here; this is not game state). */
export interface CameraState {
  /** Orbit azimuth, radians. */
  yaw: number;
  /** Orbit pitch above the ground plane, radians. */
  pitch: number;
  /** Orbit distance in world cells. */
  distance: number;
  /** Orbit target in world units. */
  target: { x: number; y: number; z: number };
}

/** Pixel statistics of a rendered screen region (the NPC-region probe). */
export interface PixelProbe {
  /** Mean luminance (0..255). */
  mean: number;
  /** Luminance variance (0..65025). */
  variance: number;
  /** Distinct colours counted (sampled). */
  distinct: number;
  /** Pixels sampled. */
  samples: number;
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
  /** The v3 open world the town sits in. */
  world: {
    /** Playable cells (the town is a 34x16 hole inside it). */
    playableW: number;
    playableH: number;
    /** Playable grid plus the donor's vista margin ring. */
    footprintW: number;
    footprintH: number;
    /** Village disc centre, in world cell coordinates. */
    villageX: number;
    villageY: number;
    /** Town origin in world cell coordinates. */
    townX: number;
    townY: number;
    /** Town size in cells. */
    townW: number;
    townH: number;
  };
  counts: {
    /** Cells drawn from a floor-layer slab (incl. fallbacks). */
    floor: number;
    /** Cells drawn from a structure-layer slab (wall/gate/settlement). */
    structure: number;
    /** Scattered prop instances. */
    props: number;
    /** Rendered figures (player + townsfolk + world villagers). */
    figures: number;
    /** Rendered townsfolk figures (the sim's ambient population). */
    townsfolk: number;
    /** Scattered voxel trees. */
    trees: number;
    /** Scattered voxel rocks. */
    rocks: number;
    /** Scattered voxel items. */
    items: number;
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
  /** Move the orbit target onto a town cell (the smoke frames a figure). */
  focus(x: number, y: number): void;
  /** Screen position (CSS pixels) of a rendered figure, or null. */
  entityScreenPos(id: number): { x: number; y: number } | null;
  /** Pixel statistics of a screen region, sampled from a fresh render. */
  probePixels(x: number, y: number, w: number, h: number): PixelProbe | null;
}

declare global {
  interface Window {
    game: GameApi;
  }
}
