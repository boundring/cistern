/**
 * SKELETON -- no implementation. Target path: src/game.ts
 * Owning slice: integration (orchestrator)
 *
 * Responsibility: own the single owner of GameState -- build the world law,
 * the world view, the figures, the scene, the camera and the inspector, wire
 * the pointer and keyboard input, and implement the `window.game` agent test
 * surface (dispatch, state, focus, entityScreenPos, probePixels) together
 * with the per-frame update. It must NOT own the terrain law, the renderer,
 * the walk math, the copy text or the harness: it wires the parts together
 * and exposes the API.
 *
 * Signatures are taken from src/game.ts (the orchestrator owns the
 * integration files; CONTRACT.md does not freeze this module's shape).
 */

import type { TownModel } from "./core/town.js";
import type { GameApi, GameState, Intent, IntentResult, PixelProbe } from "./types/game.js";

/** Single owner of GameState: builds the world, the scene, the camera and the
 * inspector, wires pointer input, and implements the `window.game` agent
 * test surface. */
export class Game implements GameApi {
  constructor(town: TownModel, canvas: HTMLCanvasElement, panel: HTMLElement) {
    throw new Error("not implemented: Game");
  }
  dispatch(intent: Intent): IntentResult {
    throw new Error("not implemented: Game.dispatch");
  }
  state(): GameState {
    throw new Error("not implemented: Game.state");
  }
  focus(x: number, y: number): void {
    throw new Error("not implemented: Game.focus");
  }
  entityScreenPos(id: number): { x: number; y: number } | null {
    throw new Error("not implemented: Game.entityScreenPos");
  }
  probePixels(x: number, y: number, w: number, h: number): PixelProbe | null {
    throw new Error("not implemented: Game.probePixels");
  }
  frame(): void {
    throw new Error("not implemented: Game.frame");
  }
  resize(w: number, h: number): void {
    throw new Error("not implemented: Game.resize");
  }
}
