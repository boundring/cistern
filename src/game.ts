import * as THREE from "three";
import { DONORS } from "./generated/donors.js";
import { TOWN_SEED } from "./core/town.js";
import { copyForTile } from "./core/copy.js";
import { TownScene } from "./render/scene.js";
import { OrbitCamera } from "./render/camera.js";
import { Inspector } from "./render/inspector.js";
import { TownSim } from "./core/sim.js";
import type { TownModel } from "./core/town.js";
import type { GameApi, GameState, Intent, IntentResult, Selection } from "./types/game.js";

const TAP_PIXELS = 6;
const DRAG_SPEED = 0.005;
/** dispatch({type:"tick", n}) upper bound: a runaway n must not freeze the
 * render loop (fail closed at the API boundary). */
const TICK_MAX = 10000;

/** Single owner of GameState: builds the scene, camera and inspector, wires
 * pointer input, and implements the `window.game` agent test surface. */
export class Game implements GameApi {
  private readonly scene: TownScene;
  private readonly orbit: OrbitCamera;
  private readonly inspector: Inspector;
  private readonly sim: TownSim;
  private readonly spawned = new Set<number>();
  private selection: Selection | null = null;

  constructor(
    private readonly town: TownModel,
    canvas: HTMLCanvasElement,
    panel: HTMLElement,
  ) {
    this.scene = new TownScene(canvas, town, DONORS);
    this.orbit = new OrbitCamera(
      this.scene.camera,
      new THREE.Vector3(town.width / 2, 0, -town.height / 2),
    );
    this.orbit.apply();
    this.inspector = new Inspector(panel, DONORS);
    this.sim = new TownSim(town);
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
        this.selection = { x, y, tile, copyKey: key, text };
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
      },
      counts: { ...this.scene.counts, townsfolk: this.scene.entities.count() },
    };
  }

  /** One frame: reposition the camera, then render. */
  frame(): void {
    this.orbit.apply();
    this.scene.entities.faceCamera(this.scene.camera);
    this.scene.render();
  }

  /** Mirror the sim's townsfolk into the billboard layer: spawn on first
   * sight, move afterwards (donor: entity_spawn / entity_moved). */
  private syncEntities(): void {
    for (const f of this.sim.townsfolk()) {
      const ground = this.scene.groundHeight(f.x, f.y);
      if (this.spawned.has(f.id)) {
        this.scene.entities.moveEntity(f.id, f.x, f.y, ground);
      } else {
        this.scene.entities.spawn(f.id, "townsfolk", f.x, f.y, ground);
        this.spawned.add(f.id);
      }
    }
  }

  resize(w: number, h: number): void {
    this.scene.resize(w, h);
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
