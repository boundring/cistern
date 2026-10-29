/**
 * Ambient townsfolk (vendor/cistern/scripts/sim/townsfolk.gd): keyed
 * placement and one shared wander stream. Two sub-streams keep
 * determinism -- PLACEMENT (count, Fisher-Yates cells, speeds) and
 * WANDER (one stream, drawn in strict tick action order). Key shape
 * `(4 << 8) | role` mirrors TOWN_FLAVOR_KEY in town.ts.
 */

import { GodotRng } from "./rng.js";
import { keyed, DEFAULT_SPEED } from "./town.js";
import type { TownModel } from "./town.js";
import type { SimActor, TownSim } from "./sim.js";

export const TOWNSFOLK_MIN_COUNT = 6;
export const TOWNSFOLK_MAX_COUNT = 10;
/** Acts every other tick at SLOW_ONE_IN odds (1-in-2). */
export const TOWNSFOLK_SLOW_SPEED = 50;
export const TOWNSFOLK_SLOW_ONE_IN = 2;
export const PLACEMENT_KEY = (4 << 8) | 2;
export const WANDER_KEY = (4 << 8) | 3;

const AXIS_DIRS = ["n", "e", "s", "w"] as const;
export type AxisDir = (typeof AXIS_DIRS)[number];

/** The one ambient-townsfolk driver: the shared wander stream. */
export interface TownsfolkDriver {
  wander: GodotRng;
}

export interface TownsfolkCell {
  x: number;
  y: number;
  speed: number;
}

/** townsfolk.gd populate(): open non-marker cells, count, Fisher-Yates
 * order, two-step pacing. Pure: the caller arms the actors. */
export function populateTownsfolk(
  town: TownModel,
  seed: number,
): { cells: TownsfolkCell[]; driver: TownsfolkDriver } {
  const placement = new GodotRng(BigInt.asUintN(64, keyed(seed, PLACEMENT_KEY)));
  const driver: TownsfolkDriver = {
    wander: new GodotRng(BigInt.asUintN(64, keyed(seed, WANDER_KEY))),
  };
  const skip = new Set(
    [town.spawn, town.well, town.entrance, ...town.shopDoors].map((c) => c.join(",")),
  );
  const candidates: [number, number][] = [];
  for (let y = 0; y < town.height; y++) {
    for (let x = 0; x < town.width; x++) {
      const t = town.tiles[y * town.width + x];
      if (t !== "floor" && t !== "grass" && t !== "rubble" && t !== "soil") continue;
      if (skip.has(`${x},${y}`)) continue;
      candidates.push([x, y]);
    }
  }
  const count = placement.randiRange(TOWNSFOLK_MIN_COUNT, TOWNSFOLK_MAX_COUNT);
  const cells: TownsfolkCell[] = [];
  for (let i = 0; i < count; i++) {
    const j = placement.randiRange(i, candidates.length - 1);
    const tmp = candidates[i];
    candidates[i] = candidates[j];
    candidates[j] = tmp;
    const speed =
      placement.randiRange(0, TOWNSFOLK_SLOW_ONE_IN - 1) === 0
        ? TOWNSFOLK_SLOW_SPEED
        : DEFAULT_SPEED;
    cells.push({ x: candidates[i][0], y: candidates[i][1], speed });
  }
  return { cells, driver };
}

/** townsfolk.gd act(): the four orthogonal steps that stay in bounds, off
 * wall/water and off every occupied cell; one shared-stream draw picks
 * among them, and an empty legal set draws nothing. */
export function actTownsfolk(sim: TownSim, actor: SimActor): void {
  const legal: AxisDir[] = [];
  for (const d of AXIS_DIRS) {
    const [dx, dy] = DIR_ORTHO[d];
    const toX = actor.x + dx;
    const toY = actor.y + dy;
    if (toX < 0 || toY < 0 || toX >= sim.town.width || toY >= sim.town.height) continue;
    const t = sim.town.tiles[toY * sim.town.width + toX];
    if (t === "wall" || t === "stream_water") continue;
    if (sim.actorAt(toX, toY)) continue;
    legal.push(d);
  }
  if (legal.length === 0) return;
  const dir = legal[sim.driver.wander.randiRange(0, legal.length - 1)];
  sim.walk(actor, dir);
}

/** The AXIS_DIRS slice of DIR8 (town_state.gd), restated here so the
 * townsfolk module has no runtime dependency on the sim module. */
const DIR_ORTHO: Record<AxisDir, readonly [number, number]> = {
  n: [0, -1],
  e: [1, 0],
  s: [0, 1],
  w: [-1, 0],
};
