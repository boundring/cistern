/**
 * Animated 3D voxel figures replacing the v2 mint billboards. Each figure
 * is a box hierarchy root -> body -> { torso, head, armL, armR, legL, legR }
 * with limbs pivoting at the shoulder/hip (box offset half its height below
 * the pivot), so a pivot rotation swings the limb.
 *
 * Walk cycle: update() interpolates a moveTo over stepDurationMs and drives
 * the limbs from walkPose(walkPhase(travelledDistance)) — phase comes from
 * ground covered, so the stride always matches. Figures that did not move
 * idle with idlePose and face the camera around world up (the donor's
 * billboard law). Shading is unlit MeshBasicMaterial + per-vertex colours:
 * top face at base colour, sides at ~0.78x, bottom at ~0.62x, so figures
 * read as 3D without lights.
 */

import * as THREE from "three";
import { ScatterHash } from "../core/scatter.js";
import { idlePose, walkPhase, walkPose } from "../core/walk.js";

export type FigureKind = "player" | "townsfolk" | "villager";

export interface FigureOptions {
  /** interpolation time for one cell step (the app's tick cadence). */
  stepDurationMs?: number;
}

interface Limbs {
  body: THREE.Group;
  armL: THREE.Group;
  armR: THREE.Group;
  legL: THREE.Group;
  legR: THREE.Group;
}

interface Move {
  fromX: number;
  fromZ: number;
  fromGround: number;
  toX: number;
  toZ: number;
  toGround: number;
  startMs: number;
}

interface Figure {
  kind: FigureKind;
  root: THREE.Group;
  limbs: Limbs;
  move: Move | null;
  /** x/z of the settled cell (move target once the step is underway). */
  cellX: number;
  cellZ: number;
  ground: number;
}

/** Garment base colours, the donor billboard palette + world-side villager. */
const GARMENT: Record<FigureKind, [number, number, number]> = {
  player: [0.25, 0.55, 0.95],
  townsfolk: [0.4, 0.78, 0.62],
  villager: [0.8, 0.72, 0.45],
};
const SKIN: [number, number, number] = [0.85, 0.68, 0.52];
/** Legs/boots: fraction of the garment colour. */
const LEG_SHADE = 0.35;
const SIDE_SHADE = 0.78;
const BOTTOM_SHADE = 0.62;

const LEG_W = 0.16,
  LEG_H = 0.3,
  LEG_D = 0.16;
const TORSO_W = 0.34,
  TORSO_H = 0.32,
  TORSO_D = 0.22;
const HEAD_S = 0.22;
const ARM_W = 0.12,
  ARM_H = 0.3,
  ARM_D = 0.12;

/** Swing amplitude (radians) at full stride. */
const LIMB_AMP = 0.7;
/** Bob driver scale (world units) at full stride. */
const BOB_AMP = 0.05;

const DEFAULT_STEP_MS = 400;

/** BoxGeometry faces: +x,-x,+y,-y,+z,-z, 4 verts each. */
function shadedBox(
  w: number,
  h: number,
  d: number,
  [r, g, b]: [number, number, number],
): THREE.BufferGeometry {
  const geo = new THREE.BoxGeometry(w, h, d);
  const colors = new Float32Array(24 * 3);
  for (let v = 0; v < 24; v++) {
    const shade = v >= 8 && v < 12 ? 1 : v >= 12 && v < 16 ? BOTTOM_SHADE : SIDE_SHADE;
    colors[v * 3] = r * shade;
    colors[v * 3 + 1] = g * shade;
    colors[v * 3 + 2] = b * shade;
  }
  geo.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3));
  return geo;
}

/** +-4% deterministic tint from the scatter hash, floor identity 7. */
function tint(id: number): number {
  const j = new ScatterHash(7).jitter(id, 0);
  return 1 + j.x * 0.08;
}

const geoCache = new Map<string, THREE.BufferGeometry>();
function box(part: string, size: number[], color: [number, number, number]): THREE.Mesh {
  const key = `${part}|${size.join(",")}|${color.join(",")}`;
  let geo = geoCache.get(key);
  if (!geo) {
    geo = shadedBox(size[0], size[1], size[2], color);
    geoCache.set(key, geo);
  }
  const mat = new THREE.MeshBasicMaterial({ vertexColors: true });
  return new THREE.Mesh(geo, mat);
}

function limb(size: number[], color: [number, number, number], x: number, topY: number, z: number): THREE.Group {
  const pivot = new THREE.Group();
  pivot.position.set(x, topY, z);
  const m = box("limb", size, color);
  m.position.y = -size[1] / 2;
  pivot.add(m);
  return pivot;
}

/** Shortest signed angular difference a - b in (-pi, pi]. */
function angleDelta(a: number, b: number): number {
  let d = (a - b) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d <= -Math.PI) d += Math.PI * 2;
  return d;
}

export class VoxelFigures {
  readonly group = new THREE.Group();
  private readonly stepMs: number;
  private readonly figures = new Map<number, Figure>();

  constructor(opts?: FigureOptions) {
    this.stepMs = opts?.stepDurationMs ?? DEFAULT_STEP_MS;
  }

  spawn(id: number, kind: FigureKind, x: number, y: number, ground: number): void {
    if (this.figures.has(id)) this.remove(id);
    const t = tint(id);
    const g = GARMENT[kind];
    const garment: [number, number, number] = [g[0] * t, g[1] * t, g[2] * t];
    const leg: [number, number, number] = [garment[0] * LEG_SHADE, garment[1] * LEG_SHADE, garment[2] * LEG_SHADE];
    const skin: [number, number, number] = [SKIN[0] * t, SKIN[1] * t, SKIN[2] * t];

    const root = new THREE.Group();
    const body = new THREE.Group();
    root.add(body);

    const torso = box("torso", [TORSO_W, TORSO_H, TORSO_D], garment);
    torso.position.y = LEG_H + TORSO_H / 2;
    body.add(torso);

    const head = box("head", [HEAD_S, HEAD_S, HEAD_S], skin);
    head.position.y = LEG_H + TORSO_H + HEAD_S / 2;
    body.add(head);

    const shoulderY = LEG_H + TORSO_H - ARM_H / 2;
    const armL = limb([ARM_W, ARM_H, ARM_D], garment, -TORSO_W / 2 - ARM_W / 2, shoulderY, 0);
    const armR = limb([ARM_W, ARM_H, ARM_D], garment, TORSO_W / 2 + ARM_W / 2, shoulderY, 0);
    const legL = limb([LEG_W, LEG_H, LEG_D], leg, -TORSO_W / 4, LEG_H, 0);
    const legR = limb([LEG_W, LEG_H, LEG_D], leg, TORSO_W / 4, LEG_H, 0);
    body.add(armL, armR, legL, legR);

    root.position.set(x, ground, -y);
    this.group.add(root);
    this.figures.set(id, { kind, root, limbs: { body, armL, armR, legL, legR }, move: null, cellX: x, cellZ: -y, ground });
  }

  /** new cell; the figure interpolates over stepDurationMs and turns to face it. */
  moveTo(id: number, x: number, y: number, ground: number): void {
    const f = this.figures.get(id);
    if (!f) return;
    const toZ = -y;
    if (f.move) {
      // re-target mid-step from wherever interpolation stands
      const cur = this.sampled(f);
      f.move = { fromX: cur.x, fromZ: cur.z, fromGround: cur.ground, toX: x, toZ, toGround: ground, startMs: -1 };
    } else {
      f.move = { fromX: f.cellX, fromZ: f.cellZ, fromGround: f.ground, toX: x, toZ, toGround: ground, startMs: -1 };
    }
    f.cellX = x;
    f.cellZ = toZ;
    f.ground = ground;
  }

  private sampled(f: Figure): { x: number; z: number; ground: number } {
    if (!f.move) return { x: f.cellX, z: f.cellZ, ground: f.ground };
    const m = f.move;
    const t = m.startMs < 0 ? 0 : Math.min(1, (this.elapsed - m.startMs) / this.stepMs);
    return {
      x: m.fromX + (m.toX - m.fromX) * t,
      z: m.fromZ + (m.toZ - m.fromZ) * t,
      ground: m.fromGround + (m.toGround - m.fromGround) * t,
    };
  }

  private elapsed = 0;

  /** per-frame: walk cycle, idle bob, facing. */
  update(elapsedMs: number, camera: THREE.PerspectiveCamera): void {
    this.elapsed = elapsedMs;
    for (const f of this.figures.values()) {
      const m = f.move;
      if (!m) {
        const idle = idlePose(elapsedMs / 1000);
        f.limbs.body.position.y = idle.bob;
        this.setSwing(f, 0);
        // donor billboard law: face the camera around world up only
        const dx = camera.position.x - f.root.position.x;
        const dz = camera.position.z - f.root.position.z;
        if (dx !== 0 || dz !== 0) f.root.rotation.y = Math.atan2(dx, dz);
        continue;
      }
      if (m.startMs < 0) m.startMs = elapsedMs;
      const t = Math.min(1, (elapsedMs - m.startMs) / this.stepMs);
      const dx = m.toX - m.fromX;
      const dz = m.toZ - m.fromZ;
      const fullDist = Math.hypot(dx, dz);
      const travelled = fullDist * t;
      const pose = walkPose(walkPhase(travelled));
      f.root.position.set(m.fromX + dx * t, m.fromGround + (m.toGround - m.fromGround) * t, m.fromZ + dz * t);
      f.limbs.body.position.y = pose.bob * BOB_AMP;
      this.setSwing(f, pose.swing);
      // face movement direction, shortest way round
      if (fullDist > 0) {
        const target = Math.atan2(dx, dz);
        f.root.rotation.y += angleDelta(target, f.root.rotation.y);
      }
      if (t >= 1) f.move = null;
    }
  }

  private setSwing(f: Figure, swing: number): void {
    f.limbs.legL.rotation.x = swing * LIMB_AMP;
    f.limbs.legR.rotation.x = -swing * LIMB_AMP;
    f.limbs.armR.rotation.x = swing * LIMB_AMP;
    f.limbs.armL.rotation.x = -swing * LIMB_AMP;
  }

  /** world position of a figure (for camera focus / pixel probes). */
  positionOf(id: number): THREE.Vector3 | null {
    const f = this.figures.get(id);
    return f ? f.root.position.clone() : null;
  }

  count(): number {
    return this.figures.size;
  }

  remove(id: number): void {
    const f = this.figures.get(id);
    if (!f) return;
    this.group.remove(f.root);
    this.figures.delete(id);
  }
}
