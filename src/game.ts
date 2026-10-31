import * as THREE from "three";
import { DONORS } from "./generated/donors.js";
import { TOWN_SEED } from "./core/town.js";
import { copyForTile } from "./core/copy.js";
import { TownScene } from "./render/scene.js";
import { OrbitCamera, DEFAULT_PITCH, DEFAULT_DISTANCE } from "./render/camera.js";
import { Inspector } from "./render/inspector.js";
import { TownSim } from "./core/sim.js";
import { WorldHeightmap } from "./core/world.js";
import { WorldView } from "./render/world.js";
import { VoxelFigures } from "./render/figures.js";
import { ScatterHash, SCATTER_SEED } from "./core/scatter.js";
import {
  TOWN_H,
  TOWN_W,
  TOWN_X,
  TOWN_Y,
  WORLD_H,
  WORLD_W,
  MARGIN_X,
  MARGIN_Z,
  FOOTPRINT_H,
  FOOTPRINT_W,
  VILLAGE_X,
  VILLAGE_Y,
} from "./core/terrain.js";
import type { TownModel } from "./core/town.js";
import type { GameApi, GameState, Intent, IntentResult, Selection } from "./types/game.js";

const TAP_PIXELS = 6;
const DRAG_SPEED = 0.005;
/** dispatch({type:"tick", n}) upper bound: a runaway n must not freeze the
 * render loop (fail closed at the API boundary). */
const TICK_MAX = 10000;
/** The v3 open world is four times the v2 footprint: the donor's fog density
 * (0.016) would swallow the whole map, so the world reads at its own scale. */
const WORLD_FOG_DENSITY = 0.0065;
/** Ambient world villagers: the donor's hash-scatter law, floor identity 21. */
const VILLAGER_SCATTER_ID = 21;
const VILLAGER_DENSITY = 0.02;
const VILLAGER_MIN_DIST = 7;
const VILLAGER_MAX_DIST = 30;
/** Figure id space for the world villagers (the sim owns 1..n). */
const VILLAGER_ID_BASE = 1000;

/** Single owner of GameState: builds the world, the scene, the camera and the
 * inspector, wires pointer input, and implements the `window.game` agent
 * test surface. */
export class Game implements GameApi {
  private readonly scene: TownScene;
  private readonly orbit: OrbitCamera;
  private readonly inspector: Inspector;
  private readonly sim: TownSim;
  private readonly field: WorldHeightmap;
  private readonly world: WorldView;
  private readonly figures: VoxelFigures;
  /** Town cell each figure last stood on, so a move is detected. */
  private readonly figureCells = new Map<number, string>();
  private selection: Selection | null = null;
  private readonly startedAt = performance.now();

  constructor(
    private readonly town: TownModel,
    canvas: HTMLCanvasElement,
    panel: HTMLElement,
  ) {
    this.field = new WorldHeightmap();
    const villageHeight = this.field.villageHeight();
    this.scene = new TownScene(canvas, town, DONORS, {
      townOffsetX: TOWN_X,
      townOffsetZ: -TOWN_Y,
      townGroundY: villageHeight,
      fogDensity: WORLD_FOG_DENSITY,
    });
    this.world = new WorldView(this.field, {
      playableW: WORLD_W,
      playableH: WORLD_H,
      marginX: MARGIN_X,
      marginZ: MARGIN_Z,
      townOriginX: TOWN_X,
      townOriginY: TOWN_Y,
      townW: TOWN_W,
      townH: TOWN_H,
      seed: SCATTER_SEED,
    });
    this.figures = new VoxelFigures({ stepDurationMs: 400 });
    this.scene.scene.add(this.world.group);
    this.scene.scene.add(this.figures.group);

    this.orbit = new OrbitCamera(
      this.scene.camera,
      new THREE.Vector3(VILLAGE_X, villageHeight + 0.5, -VILLAGE_Y),
    );
    this.orbit.set(-0.6, DEFAULT_PITCH, DEFAULT_DISTANCE);
    this.orbit.apply();
    this.inspector = new Inspector(panel, DONORS);
    this.sim = new TownSim(town);
    this.spawnWorldVillagers();
    this.syncEntities();
    this.wireInput(canvas);
  }

  dispatch(intent: Intent): IntentResult {
    switch (intent.type) {
      case "inspect": {
        const { x, y } = intent;
        // Integer check first: a fractional cell would index tiles[] to undefined.
        if (!(Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < this.town.width && y >= 0 && y < this.town.height)) {
          return { ok: false, error: `cell (${x}, ${y}) out of bounds` };
        }
        const tile = this.town.tiles[y * this.town.width + x];
        const { key, text } = copyForTile(tile, DONORS.copy);
        this.selection = {
          x,
          y,
          tile,
          copyKey: key,
          text,
          terrain: this.terrainAt(x, y),
          figure: this.figureAt(x, y),
        };
        this.inspector.show(this.selection);
        return { ok: true, state: this.state() };
      }
      case "orbit": {
        const yawBad = intent.yaw !== undefined && !Number.isFinite(intent.yaw);
        const pitchBad = intent.pitch !== undefined && !Number.isFinite(intent.pitch);
        if (yawBad || pitchBad) return { ok: false, error: "yaw/pitch must be finite numbers" };
        this.orbit.set(intent.yaw, intent.pitch);
        return { ok: true, state: this.state() };
      }
      case "zoom": {
        if (!Number.isFinite(intent.distance)) {
          return { ok: false, error: "distance must be a finite number" };
        }
        this.orbit.set(undefined, undefined, intent.distance);
        return { ok: true, state: this.state() };
      }
      case "tick": {
        const n = intent.n ?? 1;
        if (!(Number.isInteger(n) && n >= 0 && n <= TICK_MAX)) {
          return { ok: false, error: `tick n must be an integer in 0..${TICK_MAX}` };
        }
        for (let i = 0; i < n; i++) this.sim.tick();
        this.syncEntities();
        return { ok: true, state: this.state() };
      }
      case "reset": {
        this.selection = null;
        this.inspector.show(null);
        return { ok: true, state: this.state() };
      }
    }
  }

  state(): GameState {
    const target = this.orbit.target;
    return {
      seed: TOWN_SEED,
      width: this.town.width,
      height: this.town.height,
      tiles: this.town.tiles.slice(),
      selection: this.selection ? { ...this.selection } : null,
      townsfolk: this.sim.townsfolk(),
      eventCount: this.sim.events.length,
      camera: {
        yaw: this.orbit.yaw,
        pitch: this.orbit.pitch,
        distance: this.orbit.distance,
        target: { x: target.x, y: target.y, z: target.z },
      },
      world: {
        playableW: WORLD_W,
        playableH: WORLD_H,
        footprintW: FOOTPRINT_W,
        footprintH: FOOTPRINT_H,
        villageX: VILLAGE_X,
        villageY: VILLAGE_Y,
        townX: TOWN_X,
        townY: TOWN_Y,
        townW: TOWN_W,
        townH: TOWN_H,
      },
      counts: {
        ...this.scene.counts,
        figures: this.figures.count(),
        townsfolk: this.sim.townsfolk().length,
        trees: this.world.counts.trees,
        rocks: this.world.counts.rocks,
        items: this.world.counts.items,
      },
    };
  }

  /** Move the orbit target onto a town cell. */
  focus(x: number, y: number): void {
    this.orbit.setTarget(
      new THREE.Vector3(TOWN_X + x + 0.5, this.field.villageHeight(), -(TOWN_Y + y + 0.5)),
    );
    this.orbit.apply();
  }

  /** Screen position (CSS pixels) of a rendered figure, or null. */
  entityScreenPos(id: number): { x: number; y: number } | null {
    const pos = this.figures.positionOf(id);
    if (!pos) return null;
    const rect = this.scene.canvas.getBoundingClientRect();
    const ndc = pos.clone().project(this.scene.camera);
    return {
      x: rect.left + (ndc.x * 0.5 + 0.5) * rect.width,
      y: rect.top + (-ndc.y * 0.5 + 0.5) * rect.height,
    };
  }

  /** Pixel statistics of a screen region, sampled from a fresh render. */
  probePixels(x: number, y: number, w: number, h: number) {
    return this.scene.probePixels(x, y, w, h);
  }

  /** One frame: water, figures, camera, then the render. */
  frame(): void {
    const elapsed = (performance.now() - this.startedAt) / 1000;
    this.world.update(elapsed);
    this.figures.update(elapsed * 1000, this.scene.camera);
    this.orbit.apply();
    this.scene.render();
  }

  resize(w: number, h: number): void {
    this.scene.resize(w, h);
  }

  /** Mirror the sim's actors into the figure layer: the player marker wears
   * the donor's player colour, the townsfolk the mint one. */
  private syncEntities(): void {
    for (const actor of this.sim.actors) {
      const key = `${actor.x},${actor.y}`;
      const ground = this.field.villageHeight();
      const x = TOWN_X + actor.x + 0.5;
      const y = TOWN_Y + actor.y + 0.5;
      if (!this.figureCells.has(actor.id)) {
        this.figures.spawn(actor.id, actor.kind === "player" ? "player" : "townsfolk", x, y, ground);
        this.figureCells.set(actor.id, key);
      } else if (this.figureCells.get(actor.id) !== key) {
        this.figures.moveTo(actor.id, x, y, ground);
        this.figureCells.set(actor.id, key);
      }
    }
  }

  /**
   * World villagers: the donor's hash-scatter law places them on open ground
   * around the village, standing idle until the town draws them in.
   */
  private spawnWorldVillagers(): void {
    const scatter = new ScatterHash(VILLAGER_SCATTER_ID);
    for (let gy = 0; gy < WORLD_H; gy++) {
      for (let gx = 0; gx < WORLD_W; gx++) {
        if (gx >= TOWN_X && gx < TOWN_X + TOWN_W && gy >= TOWN_Y && gy < TOWN_Y + TOWN_H) continue;
        const kind = this.field.kindAt(gx, gy);
        if (kind !== "plains" && kind !== "hills" && kind !== "village") continue;
        const d = Math.hypot(gx - VILLAGE_X, gy - VILLAGE_Y);
        if (d < VILLAGER_MIN_DIST || d > VILLAGER_MAX_DIST) continue;
        if (!scatter.presence(gx, gy, VILLAGER_DENSITY)) continue;
        const id = VILLAGER_ID_BASE + gy * WORLD_W + gx;
        this.figures.spawn(id, "villager", gx + 0.5, gy + 0.5, this.world.heightAt(gx, gy));
        this.figureCells.set(id, `${gx},${gy}`);
      }
    }
  }

  /** The terrain under a town cell, for the inspector. */
  private terrainAt(x: number, y: number): Selection["terrain"] {
    const gx = TOWN_X + x;
    const gy = TOWN_Y + y;
    return {
      kind: this.field.kindAt(gx, gy),
      steps: this.field.stepsAtCell(gx, gy),
      height: this.field.villageHeight(),
      water: this.field.isWater(gx, gy),
    };
  }

  /** The figure standing on a town cell, when there is one. */
  private figureAt(x: number, y: number): Selection["figure"] | undefined {
    for (const actor of this.sim.actors) {
      if (actor.x === x && actor.y === y) {
        return { id: actor.id, kind: actor.kind === "player" ? "player" : "townsfolk" };
      }
    }
    return undefined;
  }

  /** Drag orbits (pointer capture), wheel/pinch zooms, tap picks. A gesture
   * that moved >= TAP_PIXELS never registers as a pick. */
  private wireInput(canvas: HTMLCanvasElement): void {
    const pointers = new Map<number, { x: number; y: number }>();
    let dragId: number | null = null;
    let moved = 0;
    let lastX = 0;
    let lastY = 0;
    let pinchDist = 0;

    canvas.addEventListener("pointerdown", (e) => {
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointers.size === 1) {
        dragId = e.pointerId;
        moved = 0;
        lastX = e.clientX;
        lastY = e.clientY;
        canvas.setPointerCapture(e.pointerId);
      } else {
        dragId = null; // second finger: this gesture is a pinch, not a drag
        const [a, b] = [...pointers.values()];
        pinchDist = Math.hypot(a.x - b.x, a.y - b.y);
      }
    });

    canvas.addEventListener("pointermove", (e) => {
      const prev = pointers.get(e.pointerId);
      if (!prev) return;
      prev.x = e.clientX;
      prev.y = e.clientY;
      if (pointers.size >= 2) {
        const [a, b] = [...pointers.values()];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (pinchDist > 0 && d > 0) {
          this.orbit.set(undefined, undefined, this.orbit.distance * (d / pinchDist));
        }
        pinchDist = d;
        return;
      }
      if (e.pointerId !== dragId) return;
      const dx = e.clientX - lastX;
      const dy = e.clientY - lastY;
      lastX = e.clientX;
      lastY = e.clientY;
      moved += Math.abs(dx) + Math.abs(dy);
      this.orbit.set(this.orbit.yaw - dx * DRAG_SPEED, this.orbit.pitch + dy * DRAG_SPEED);
    });

    canvas.addEventListener("pointerup", (e) => {
      const wasDrag = e.pointerId === dragId;
      pointers.delete(e.pointerId);
      pinchDist = 0;
      if (pointers.size === 1) {
        // Pinch ended over one remaining finger: it becomes a fresh drag
        // anchor but inherits TAP_PIXELS so it can never count as a tap.
        dragId = [...pointers.keys()][0];
        const p = pointers.get(dragId)!;
        lastX = p.x;
        lastY = p.y;
        moved = TAP_PIXELS;
      } else {
        dragId = null;
      }
      if (wasDrag && moved < TAP_PIXELS) {
        const hit = this.scene.pick(e.clientX, e.clientY);
        if (hit) this.dispatch({ type: "inspect", x: hit.x, y: hit.y });
      }
    });

    canvas.addEventListener("pointercancel", (e) => {
      pointers.delete(e.pointerId);
      dragId = null;
      pinchDist = 0;
    });

    canvas.addEventListener(
      "wheel",
      (e) => {
        e.preventDefault();
        this.orbit.set(undefined, undefined, this.orbit.distance * (1 + e.deltaY * 0.001));
      },
      { passive: false },
    );
  }
}
