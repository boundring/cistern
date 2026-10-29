/**
 * The open-world renderer (v3 slice D).
 *
 * One merged, vertex-coloured terrain geometry over the whole vista
 * footprint (the authored town is a hole with a skirt), one translucent
 * water plane at the global table, and hash-scattered voxel props drawn
 * as InstancedMesh per model kind. All lighting is baked into vertex
 * colours (the donor's TERRAIN_FS law) so the terrain renders unlit.
 */

import * as THREE from "three";

import {
  MARGIN_X,
  MARGIN_Z,
  TERRAIN_AMBIENT,
  TERRAIN_COLOR,
  TERRAIN_DIRECTIONAL,
  TERRAIN_SIDE_SHADE,
  TERRAIN_SUN_DIR,
  VOXEL,
  WATER_COLOR,
  VILLAGE_X,
  VILLAGE_Y,
  WORLD_H,
  WORLD_W,
  type TerrainKind,
} from "../core/terrain.js";
import { ScatterHash } from "../core/scatter.js";
import {
  berryModel,
  broadleafModel,
  boulderModel,
  branchModel,
  crystalModel,
  pineModel,
  type VoxelModel,
} from "./voxel.js";

export interface TerrainField {
  stepsAtCell(gx: number, gy: number): number;
  kindAt(gx: number, gy: number): TerrainKind;
  tableHeight(): number;
  villageHeight(): number;
}

export interface WorldViewOptions {
  playableW: number;
  playableH: number;
  marginX: number;
  marginZ: number;
  townOriginX: number;
  townOriginY: number;
  townW: number;
  townH: number;
  /** ScatterHash seed. */
  seed: number;
}

/** Scatter floor identities (one per class, donor scatter-hash law). */
const FLOOR_TREES = 11;
const FLOOR_ROCKS = 12;
const FLOOR_ITEMS = 13;
const FLOOR_PINES = 14;
/** Per-band densities (fraction of eligible cells). */
const TREE_DENSITY: Partial<Record<TerrainKind, number>> = { plains: 0.16, hills: 0.16, plateau: 0.16, village: 0.16 };
const PINE_DENSITY: Partial<Record<TerrainKind, number>> = { mountain: 0.12, rim: 0.12 };
const ROCK_DENSITY: Partial<Record<TerrainKind, number>> = { mountain: 0.14, rim: 0.14 };
const ITEM_DENSITY: Partial<Record<TerrainKind, number>> = { plains: 0.05, desert: 0.05, village: 0.05 };

interface Placement {
  x: number;
  y: number;
  z: number;
  tint: number;
}

export class WorldView {
  readonly group = new THREE.Group();
  readonly counts = { cells: 0, trees: 0, rocks: 0, items: 0 };

  private readonly field: TerrainField;
  private readonly opts: WorldViewOptions;
  private readonly water: THREE.Mesh;
  private readonly waterBaseY: number;
  // scratch, reused every update() — no per-frame allocation
  private readonly scratchMat = new THREE.Matrix4();
  private readonly scratchColor = new THREE.Color();

  constructor(field: TerrainField, opts: WorldViewOptions) {
    this.field = field;
    this.opts = opts;
    this.waterBaseY = field.tableHeight();

    const terrain = this.buildTerrain();
    const terrainMesh = new THREE.Mesh(
      terrain,
      new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide }),
    );
    this.group.add(terrainMesh);

    this.water = this.buildWater();
    this.group.add(this.water);

    this.scatter();
  }

  /** Terrain top height at a world cell, in world units. */
  heightAt(gx: number, gy: number): number {
    if (this.inTown(gx, gy)) return this.field.villageHeight();
    return this.field.stepsAtCell(gx, gy) * VOXEL;
  }

  /** Deterministic water animation; reuses scratch objects only. */
  update(elapsedSeconds: number): void {
    const t = elapsedSeconds;
    // sum of two sines, sub-voxel amplitude (~2-3 mm world units)
    this.water.position.y =
      this.waterBaseY + 0.02 * Math.sin(t * 1.1) + 0.012 * Math.sin(t * 2.3 + 1.7);
    this.water.position.x = 0.03 * Math.sin(t * 0.63);
    this.water.position.z = 0.03 * Math.cos(t * 0.47);
  }

  private inTown(gx: number, gy: number): boolean {
    const o = this.opts;
    return gx >= o.townOriginX && gx < o.townOriginX + o.townW
      && gy >= o.townOriginY && gy < o.townOriginY + o.townH;
  }

  /** Baked donor lighting: colour * (ambient + directional * max(dot(n, sun), 0)). */
  private lit(c: readonly [number, number, number], nx: number, ny: number, nz: number, shade = 1): [number, number, number] {
    // bake coords (x east, y north, z up) -> three (x, z, -y), like bakeToXz:
    // three.x = bake.x, three.y = bake.z, three.z = -bake.y
    const sx = TERRAIN_SUN_DIR[0], sy = TERRAIN_SUN_DIR[2], sz = -TERRAIN_SUN_DIR[1];
    const len = Math.hypot(sx, sy, sz);
    const dot = Math.max((nx * sx + ny * sy + nz * sz) / len, 0);
    const f = (TERRAIN_AMBIENT + TERRAIN_DIRECTIONAL * dot) * shade;
    // TERRAIN_COLOR is authored as 0-255 bytes; vertex colours are linear
    // floats (the slab baker divides by 255 the same way).
    return [(c[0] / 255) * f, (c[1] / 255) * f, (c[2] / 255) * f];
  }

  private buildTerrain(): THREE.BufferGeometry {
    const pos: number[] = [];
    const col: number[] = [];
    const f = this.field;

    const quad = (
      ax: number, ay: number, az: number,
      bx: number, by: number, bz: number,
      cx: number, cy: number, cz: number,
      dx: number, dy: number, dz: number,
      rgb: [number, number, number],
    ): void => {
      for (const v of [[ax, ay, az], [bx, by, bz], [cx, cy, cz], [ax, ay, az], [cx, cy, cz], [dx, dy, dz]]) {
        pos.push(v[0], v[1], v[2]);
        col.push(rgb[0], rgb[1], rgb[2]);
      }
    };

    const gx0 = -MARGIN_X, gx1 = WORLD_W + MARGIN_X;
    const gy0 = -MARGIN_Z, gy1 = WORLD_H + MARGIN_Z;

    for (let gy = gy0; gy < gy1; gy++) {
      for (let gx = gx0; gx < gx1; gx++) {
        if (this.inTown(gx, gy)) continue;
        const h = f.stepsAtCell(gx, gy) * VOXEL;
        const kind = f.kindAt(gx, gy);
        const base = TERRAIN_COLOR[kind];
        const x0 = gx, x1 = gx + 1;
        const z0 = -gy - 1, z1 = -gy;
        this.counts.cells++;

        // top face (normal +y)
        quad(x0, h, z1, x1, h, z1, x1, h, z0, x0, h, z0, this.lit(base, 0, 1, 0));

        // side faces where the neighbour is lower
        const sides: Array<[number, number, number, number, [number, number, number]]> = [
          // [x0a, zA, x0b, zB, lit colour] — south neighbour (+gy, face at z0)
          [x0, z0, x1, z0, this.lit(base, 0, 0, -1, TERRAIN_SIDE_SHADE)],
          // north neighbour (-gy, face at z1)
          [x1, z1, x0, z1, this.lit(base, 0, 0, 1, TERRAIN_SIDE_SHADE)],
          // east neighbour (+gx, face at x1)
          [x1, z0, x1, z1, this.lit(base, 1, 0, 0, TERRAIN_SIDE_SHADE)],
          // west neighbour (-gx, face at x0)
          [x0, z1, x0, z0, this.lit(base, -1, 0, 0, TERRAIN_SIDE_SHADE)],
        ];
        const neigh: Array<[number, number]> = [[gx, gy + 1], [gx, gy - 1], [gx + 1, gy], [gx - 1, gy]];
        for (let i = 0; i < 4; i++) {
          const [nx, ny] = neigh[i];
          const nh = this.inTown(nx, ny) ? f.villageHeight() : f.stepsAtCell(nx, ny) * VOXEL;
          if (nh >= h) continue;
          const [ax, az, bx, bz, rgb] = sides[i];
          // vertical quad from neighbour height up to this height, CCW from outside
          quad(ax, nh, az, bx, nh, bz, bx, h, bz, ax, h, az, rgb);
        }

        // town skirt: this cell borders the town hole — wall from the town pad
        // down to this cell's terrain so no gap shows
        if (this.bordersTown(gx, gy) && f.villageHeight() > h) {
          const vh = f.villageHeight();
          const skirt: Array<[number, number, number, number, [number, number, number]]> = [
            [x0, z0, x1, z0, this.lit(base, 0, 0, -1, TERRAIN_SIDE_SHADE)],
            [x1, z1, x0, z1, this.lit(base, 0, 0, 1, TERRAIN_SIDE_SHADE)],
            [x1, z0, x1, z1, this.lit(base, 1, 0, 0, TERRAIN_SIDE_SHADE)],
            [x0, z1, x0, z0, this.lit(base, -1, 0, 0, TERRAIN_SIDE_SHADE)],
          ];
          for (const [ax, az, bx, bz, rgb] of skirt) {
            if (!this.edgeFacesTown(gx, gy, ax, az, bz)) continue;
            quad(ax, h, az, bx, h, bz, bx, vh, bz, ax, vh, az, rgb);
          }
        }
      }
    }

    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute("color", new THREE.Float32BufferAttribute(col, 3));
    return g;
  }

  private bordersTown(gx: number, gy: number): boolean {
    const o = this.opts;
    return gx >= o.townOriginX - 1 && gx <= o.townOriginX + o.townW
      && gy >= o.townOriginY - 1 && gy <= o.townOriginY + o.townH;
  }

  /** Does the quad edge (a->b, both in world xz) lie on the town boundary? */
  private edgeFacesTown(gx: number, gy: number, ax: number, az: number, bz: number): boolean {
    const o = this.opts;
    if (az === bz) {
      // horizontal edge: the neighbour row is the town row?
      const ny = az === -gy - 1 ? gy + 1 : gy - 1;
      return ny >= o.townOriginY && ny < o.townOriginY + o.townH
        && gx >= o.townOriginX && gx < o.townOriginX + o.townW;
    }
    const nx = ax === gx ? gx - 1 : gx + 1;
    return nx >= o.townOriginX && nx < o.townOriginX + o.townW
      && gy >= o.townOriginY && gy < o.townOriginY + o.townH;
  }

  private buildWater(): THREE.Mesh {
    const g = new THREE.PlaneGeometry(FOOTPRINT_SPAN_X + 200, FOOTPRINT_SPAN_Z + 200);
    const m = new THREE.MeshBasicMaterial({
      color: new THREE.Color(WATER_COLOR[0] / 255, WATER_COLOR[1] / 255, WATER_COLOR[2] / 255),
      transparent: true,
      opacity: 0.55,
      depthWrite: false,
    });
    const mesh = new THREE.Mesh(g, m);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(FOOTPRINT_CX, this.waterBaseY, FOOTPRINT_CZ);
    return mesh;
  }

  private scatter(): void {
    const trees = new ScatterHash(FLOOR_TREES, BigInt(this.opts.seed));
    const rocks = new ScatterHash(FLOOR_ROCKS, BigInt(this.opts.seed));
    const items = new ScatterHash(FLOOR_ITEMS, BigInt(this.opts.seed));
    const pineHash = new ScatterHash(FLOOR_PINES, BigInt(this.opts.seed));

    const broadleaf: Placement[] = [];
    const pine: Placement[] = [];
    const boulder: Placement[] = [];
    const itemPlacements: Placement[][] = [[], [], []];

    const gx0 = -MARGIN_X, gx1 = WORLD_W + MARGIN_X;
    const gy0 = -MARGIN_Z, gy1 = WORLD_H + MARGIN_Z;
    const cx = VILLAGE_X, cy = VILLAGE_Y; // village centre: keep the town clear

    for (let gy = gy0; gy < gy1; gy++) {
      for (let gx = gx0; gx < gx1; gx++) {
        if (this.inTown(gx, gy)) continue;
        if (Math.abs(gx - cx) <= 1 && Math.abs(gy - cy) <= 1) continue;
        const kind = this.field.kindAt(gx, gy);
        if (kind === "water" || kind === "shore") continue;
        const h = this.heightAt(gx, gy);
        if (h < this.waterBaseY) continue; // lake bed: nothing grows

        const place = (hash: ScatterHash, density: number): Placement | null => {
          if (!hash.presence(gx, gy, density)) return null;
          const j = hash.jitter(gx, gy);
          return { x: gx + 0.5 + j.x, y: h, z: -(gy + 0.5) + j.y, tint: 1 + j.x * 0.16 };
        };

        const t = TREE_DENSITY[kind];
        if (t !== undefined) {
          const p = place(trees, t);
          if (p) broadleaf.push(p);
        }
        const pd = PINE_DENSITY[kind];
        if (pd !== undefined) {
          const p = place(pineHash, pd);
          if (p) pine.push(p);
        }
        const rd = ROCK_DENSITY[kind];
        if (rd !== undefined) {
          const p = place(rocks, rd);
          if (p) boulder.push(p);
        }
        const id = ITEM_DENSITY[kind];
        if (id !== undefined) {
          const p = place(items, id);
          if (p) itemPlacements[items.variant(gx, gy, 3)].push(p);
        }
      }
    }

    const broadleafModel_ = broadleafModel();
    const pineModel_ = pineModel();
    const boulderModel_ = boulderModel();
    const itemModels: VoxelModel[] = [crystalModel(), berryModel(), branchModel()];

    this.emitInstanced(broadleafModel_, broadleaf);
    this.emitInstanced(pineModel_, pine);
    this.emitInstanced(boulderModel_, boulder);
    for (let v = 0; v < 3; v++) this.emitInstanced(itemModels[v], itemPlacements[v]);

    this.counts.trees = broadleaf.length + pine.length;
    this.counts.rocks = boulder.length;
    this.counts.items = itemPlacements[0].length + itemPlacements[1].length + itemPlacements[2].length;
  }

  /** One InstancedMesh for a model: translation matrices + deterministic tint. */
  private emitInstanced(model: VoxelModel, spots: Placement[]): void {
    if (spots.length === 0) return;
    const mesh = new THREE.InstancedMesh(
      model.geometry,
      new THREE.MeshBasicMaterial({ vertexColors: true }),
      spots.length,
    );
    for (let i = 0; i < spots.length; i++) {
      const p = spots[i];
      this.scratchMat.makeTranslation(p.x, p.y, p.z);
      mesh.setMatrixAt(i, this.scratchMat);
      const t = Math.min(Math.max(p.tint, 0.7), 1.3);
      this.scratchColor.set(t, t, t);
      mesh.setColorAt(i, this.scratchColor);
    }
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    this.group.add(mesh);
  }
}

// footprint centre in three.js xz (computed once, constants only): the
// footprint spans cells -MARGIN_X .. WORLD_W+MARGIN_X on x and the mirrored
// band on z, where cell gy maps to three.js z in [-gy-1, -gy].
const FOOTPRINT_CX = WORLD_W / 2 + 0.5;
const FOOTPRINT_CZ = -(WORLD_H / 2) - 0.5;
const FOOTPRINT_SPAN_X = WORLD_W + MARGIN_X * 2;
const FOOTPRINT_SPAN_Z = WORLD_H + MARGIN_Z * 2;
