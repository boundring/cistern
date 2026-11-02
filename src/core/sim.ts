/**
 * Trimmed port of vendor/cistern/scripts/sim/town_state.gd: the
 * energy/turn tick model over the armed actors, the strict (y, x, id)
 * action order, walk legality, and the canonical seq-prefixed event
 * transcript. Deliberate v2 trim (documented boundary, not a divergence):
 * the player marker waits forever -- no intent queue -- and the
 * servant/shop systems stay donor-only; the web consumes the ambient
 * townsfolk sub-stream the donor golden pins.
 */

import { TOWN_SEED, DEFAULT_SPEED, DIR8, type Dir8, type TownModel } from "./town.js";
import { populateTownsfolk, actTownsfolk, type TownsfolkDriver } from "./townsfolk.js";

/** Energy charged per action; an actor acts each time its energy reaches this. */
export const ENERGY_ACT = 100;

export const CISTERN_TANK_CAP: number = 60;
export const CISTERN_USE_LOAD: number = 10;
export const CISTERN_PURGE_RATE: number = 3;
export const CISTERN_START_ALLOY: number = 20;
export const CISTERN_CONTAM_LIMIT: number = 20;

export interface CisternState {
  alloy: number;
  earned: number;
  purged: number;
  contam: number;
  tankLoad: Record<string, number>;
}

export function createCisternState(): CisternState {
  return {
    alloy: CISTERN_START_ALLOY,
    earned: 0,
    purged: 0,
    contam: 0,
    tankLoad: {},
  };
}

export function cisternRegisterTank(state: CisternState, x: number, y: number): CisternState {
  const key = `${x},${y}`;
  const newTankLoad = { ...state.tankLoad };
  newTankLoad[key] = 0;
  return {
    ...state,
    tankLoad: newTankLoad,
  };
}

export function cisternWaste(state: CisternState): number {
  let total = 0;
  for (const load of Object.values(state.tankLoad)) {
    total += load;
  }
  return total;
}

export function cisternDepositWaste(state: CisternState, tanks: ReadonlyArray<readonly [number, number]>, manifoldLive: boolean): { state: CisternState; outcome: "stored" | "relief" | "spilled"; message: string } {
  // Collect valid connected tanks
  const validTanks: { key: string; tx: number; ty: number; load: number }[] = [];
  for (const [tx, ty] of tanks) {
    const key = `${tx},${ty}`;
    if (key in state.tankLoad) {
      validTanks.push({ key, tx, ty, load: state.tankLoad[key] });
    }
  }

  if (validTanks.length === 0) {
    if (manifoldLive) {
      return {
        state,
        outcome: "relief",
        message: "MANIFOLD RELIEF",
      };
    } else {
      return {
        state: {
          ...state,
          contam: state.contam + 1,
        },
        outcome: "spilled",
        message: "SEVERED LINE — WASTE SPILLED",
      };
    }
  }

  // Sort by load asc, then tx asc, then ty asc
  validTanks.sort((a, b) => {
    if (a.load !== b.load) {
      return a.load - b.load;
    }
    if (a.tx !== b.tx) {
      return a.tx - b.tx;
    }
    return a.ty - b.ty;
  });

  const best = validTanks[0];
  const bestKey = best.key;
  const newLoad = best.load + CISTERN_USE_LOAD;
  const newTankLoad = { ...state.tankLoad };
  newTankLoad[bestKey] = newLoad;

  return {
    state: {
      ...state,
      tankLoad: newTankLoad,
    },
    outcome: "stored",
    message: "WASTE STORED",
  };
}

export function cisternPurge(state: CisternState, x: number, y: number): { state: CisternState; outcome: "purged" | "not_a_tank" | "already_clear"; message: string; gained: number } {
  const key = `${x},${y}`;
  if (!(key in state.tankLoad)) {
    return {
      state,
      outcome: "not_a_tank",
      message: "CURSOR NOT ON A TANK",
      gained: 0,
    };
  }
  const load = state.tankLoad[key];
  if (load === 0) {
    return {
      state,
      outcome: "already_clear",
      message: "TANK ALREADY CLEAR",
      gained: 0,
    };
  }
  const gained = Math.floor(load / CISTERN_PURGE_RATE);
  const newTankLoad = { ...state.tankLoad };
  newTankLoad[key] = 0;

  return {
    state: {
      ...state,
      alloy: state.alloy + gained,
      purged: state.purged + 1,
      tankLoad: newTankLoad,
    },
    outcome: "purged",
    message: `TANK PURGED — RECOVERED ${gained} ALLOY`,
    gained,
  };
}

export function cisternMine(state: CisternState, mineTicks: number, rate: number): { state: CisternState; mined: boolean; mineTicks: number } {
  const newTicks = mineTicks + 1;
  if (newTicks >= rate) {
    return {
      state: {
        ...state,
        alloy: state.alloy + 1,
        earned: state.earned + 1,
      },
      mined: true,
      mineTicks: 0,
    };
  } else {
    return {
      state,
      mined: false,
      mineTicks: newTicks,
    };
  }
}

export function cisternToiletUsable(state: CisternState, tanks: ReadonlyArray<readonly [number, number]>, manifoldLive: boolean): boolean {
  if (manifoldLive) {
    return true;
  }
  for (const [tx, ty] of tanks) {
    const key = `${tx},${ty}`;
    if (key in state.tankLoad) {
      const load = state.tankLoad[key];
      if (load + CISTERN_USE_LOAD <= CISTERN_TANK_CAP) {
        return true;
      }
    }
  }
  return false;
}

export interface SimActor {
  id: number;
  kind: "player" | "townsfolk";
  x: number;
  y: number;
  speed: number;
  energy: number;
}

export interface TownsfolkRow {
  id: number;
  x: number;
  y: number;
  speed: number;
}

function actsBefore(a: SimActor, b: SimActor): boolean {
  if (a.y !== b.y) return a.y < b.y;
  if (a.x !== b.x) return a.x < b.x;
  return a.id < b.id;
}

export class TownSim {
  /** Transcript of every event since construction, "%d t=%d %s" lines. */
  readonly events: string[] = [];
  turn = 0;
  seq = 0;
  readonly seed: number;
  /** Armed actors in donor insertion order: player marker, then townsfolk. */
  readonly actors: SimActor[] = [];
  readonly driver: TownsfolkDriver;
  readonly town: TownModel;
  private started = false;
  private nextId = 1;

  constructor(town: TownModel, seed: number = TOWN_SEED) {
    this.town = town;
    this.seed = seed;
    this.arm("player", this.town.spawn[0], this.town.spawn[1], DEFAULT_SPEED);
    const { cells, driver } = populateTownsfolk(this.town, seed);
    this.driver = driver;
    for (const c of cells) this.arm("townsfolk", c.x, c.y, c.speed);
  }

  /** Serializable townsfolk snapshot (ids/positions/pacing), in actor order. */
  townsfolk(): TownsfolkRow[] {
    return this.actors
      .filter((a) => a.kind === "townsfolk")
      .map(({ id, x, y, speed }) => ({ id, x, y, speed }));
  }

  /** Any armed actor standing on the cell (the wander's occupancy rule). */
  actorAt(x: number, y: number): boolean {
    return this.actors.some((a) => a.x === x && a.y === y);
  }

  /** One world tick: speed-scaled accrual, then act while someone is ready. */
  tick(): void {
    if (!this.started) this.start();
    this.turn += 1;
    for (const a of this.actors) a.energy += a.speed;
    const acted: number[] = [];
    for (;;) {
      const actor = this.nextReady();
      if (!actor) break;
      actor.energy -= ENERGY_ACT;
      acted.push(actor.id);
      if (actor.kind === "player") {
        // Empty intent stream = Wait (the v2 player never walks).
      } else {
        actTownsfolk(this, actor);
      }
    }
    this.emit(`turn_advanced actors=${acted.join(",")}`);
  }

  /** town_state.gd _walk, full fidelity: ONLY wall blocks; the rest deny. */
  walk(actor: SimActor, dir: Dir8): void {
    const [dx, dy] = DIR8[dir];
    const toX = actor.x + dx;
    const toY = actor.y + dy;
    if (toX < 0 || toY < 0 || toX >= this.town.width || toY >= this.town.height) {
      this.denied(actor, dir, "edge");
      return;
    }
    if (this.town.tiles[toY * this.town.width + toX] === "wall") {
      this.denied(actor, dir, "wall");
      return;
    }
    if (this.actorAt(toX, toY)) {
      this.denied(actor, dir, "occupied");
      return;
    }
    const fromX = actor.x;
    const fromY = actor.y;
    actor.x = toX;
    actor.y = toY;
    this.emit(`entity_moved id=${actor.id} from=${fromX},${fromY} to=${toX},${toY}`);
  }

  private arm(kind: SimActor["kind"], x: number, y: number, speed: number): SimActor {
    const actor: SimActor = { id: this.nextId, kind, x, y, speed, energy: 0 };
    this.nextId += 1;
    this.actors.push(actor);
    return actor;
  }

  /** First tick arms the run: run_started, then spawns in marker order. */
  private start(): void {
    this.started = true;
    this.emit(`run_started seed=${this.seed}`);
    for (const a of this.actors) {
      this.emit(`entity_spawn id=${a.id} kind=${a.kind} pos=${a.x},${a.y}`);
    }
  }

  /** Energy at the threshold, strictly ordered by position top-to-bottom /
   * left-to-right, then id. */
  private nextReady(): SimActor | null {
    let best: SimActor | null = null;
    for (const a of this.actors) {
      if (a.energy < ENERGY_ACT) continue;
      if (!best || actsBefore(a, best)) best = a;
    }
    return best;
  }

  private denied(actor: SimActor, dir: string, reason: string): void {
    this.emit(`move_denied id=${actor.id} dir=${dir} reason=${reason}`);
  }

  private emit(line: string): void {
    this.seq += 1;
    this.events.push(`${this.seq} t=${this.turn} ${line}`);
  }
}
