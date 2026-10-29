/**
 * SKELETON -- no implementation. Target path: src/types/game.ts
 * Owning slice: integration (orchestrator)
 *
 * Responsibility: own the shared game-API contract -- the Selection the
 * inspector renders (with its optional terrain and figure rows), the camera
 * view state, the pixel-probe statistics, the serializable integer-only
 * GameState (town plus the v3 world block and the render counts), the Intent
 * family dispatch accepts, and the GameApi surface `window.game` exposes to
 * the harness. It must NOT own any behaviour, no rendering, no scene wiring
 * and no copy text: every other module codes against these types so the
 * layers cannot drift apart.
 *
 * Signatures are verbatim from src/types/game.ts (the orchestrator owns
 * this file; CONTRACT.md states the inspector reads the optional
 * terrain/figure fields defensively because they may be absent).
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
    steps: number;
    height: number;
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
