import * as THREE from "three";
import type { Donors, TileAsset, ThemeData } from "../types/donors.js";
import type { TownModel } from "../core/town.js";
import type { SlabMesh } from "../core/slab.js";
import { decodeSlab, meshSlab, plateSlab } from "../core/slab.js";
import { ScatterHash, kindHash } from "../core/scatter.js";
import { BillboardEntities } from "./billboards.js";

/**
 * Tile kinds absent from tiles.ron (rubble, grass, soil, stream_water,
 * conduit) render through the floor slab fallback the file documents:
 * tile id "floor" -> slab "tile_floor", layer floor.
 */
const FLOOR_FALLBACK: TileAsset = { slab: "tile_floor", layer: "floor" };

/** Deco prop roster in variant order (0, 1, 2). */
const PROP_IDS = ["prop_crystal", "prop_star", "prop_coins"] as const;

const VOXELS_PER_CELL = 16;
/** Deco jitter is +-0.5 cell; the archived lane reads it as +-3 voxels. */
const JITTER_VOXELS = 3;
/** Per-cell tint read: base lightness +-5% via jitter.x (color-per-mass law). */
const TINT_SPAN = 0.05;
/** Donor ambient light floor (archived lane AMBIENT_FLOOR). */
const AMBIENT_FLOOR = 0.30;

/** One scattered deco placement (offsets in voxels). */
interface PropSpot {
  gx: number;
  gy: number;
  ox: number;
  oz: number;
}

/** bake coords (x east, y north, z up) -> three.js (x, z, -y): the
 * rotateX(-PI/2) mapping, baked into the arrays so the ambient BufferGeometry
 * surface (no rotateX) suffices. Normals take the same rotation. */
function bakeToXz(m: SlabMesh): { pos: Float32Array; nor: Float32Array } {
  const pos = new Float32Array(m.positions.length);
  const nor = new Float32Array(m.normals.length);
  for (let i = 0; i < pos.length; i += 3) {
    pos[i] = m.positions[i];
    pos[i + 1] = m.positions[i + 2];
    pos[i + 2] = -m.positions[i + 1];
    nor[i] = m.normals[i];
    nor[i + 1] = m.normals[i + 2];
    nor[i + 2] = -m.normals[i + 1];
  }
  return { pos, nor };
}

/** Mean vertex color of a slab mesh: the base the per-cell tint reads against. */
function meanColor(m: SlabMesh): THREE.Color {
  let r = 0;
  let g = 0;
  let b = 0;
  const c = m.colors;
  for (let i = 0; i < c.length; i += 3) {
    r += c[i];
    g += c[i + 1];
    b += c[i + 2];
  }
  const n = c.length / 3;
  return new THREE.Color(r / n, g / n, b / n);
}

/**
 * Baked donor lighting term (the archived lane's TERRAIN_FS: lit = colour *
 * (ambient_floor + directional_strength * max(dot(n, sun_dir), 0))). The
 * renderer runs unlit (MeshBasicMaterial), so the term is folded into the
 * vertex colours here; normals are read in BAKE coords against the theme
 * sun_dir, which is also authored in bake coords.
 */
function bakeLighting(
  m: SlabMesh,
  theme: ThemeData,
): Float32Array {
  const [sx0, sy0, sz0] = theme.sunDir;
  const len = Math.hypot(sx0, sy0, sz0);
  const sx = sx0 / len;
  const sy = sy0 / len;
  const sz = sz0 / len;
  const out = new Float32Array(m.colors.length);
  for (let i = 0; i < m.colors.length; i += 3) {
    const d = m.normals[i] * sx + m.normals[i + 1] * sy + m.normals[i + 2] * sz;
    const l = AMBIENT_FLOOR + theme.directionalStrength * Math.max(d, 0);
    out[i] = m.colors[i] * l;
    out[i + 1] = m.colors[i + 1] * l;
    out[i + 2] = m.colors[i + 2] * l;
  }
  return out;
}

function slabGeometry(m: SlabMesh, theme: ThemeData): THREE.BufferGeometry {
  const { pos, nor } = bakeToXz(m);
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute("normal", new THREE.Float32BufferAttribute(nor, 3));
  geo.setAttribute("color", new THREE.Float32BufferAttribute(bakeLighting(m, theme), 3));
  return geo;
}

function resolveAsset(donors: Donors, tileId: string): TileAsset {
  return donors.tiles[tileId] ?? FLOOR_FALLBACK;
}

/** The HD-2D voxel diorama: one InstancedMesh per tile kind plus the deco
 * props, themed background/fog/lights, and pointer picking. */
export class TownScene {
  /** Orbit target for the app's OrbitCamera (contract superset). */
  readonly camera: THREE.PerspectiveCamera;
  readonly counts = { floor: 0, structure: 0, props: 0 };
  /** Entity billboards (townsfolk), driven by the game layer. */
  readonly entities = new BillboardEntities();

  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly meshes: THREE.InstancedMesh[] = [];
  private readonly raycaster = new THREE.Raycaster();
  private readonly canvas: HTMLCanvasElement;
  private readonly town: TownModel;
  /** Terrain-top height per tile id, in world units (16 voxels = 1). */
  private readonly groundByKind = new Map<string, number>();

  constructor(canvas: HTMLCanvasElement, town: TownModel, donors: Donors) {
    this.canvas = canvas;
    this.town = town;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    // Raw passthrough like the donor lane: vertex colors are authored bytes.
    this.renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

    const bg = donors.theme.palette.bg;
    const bgColor = new THREE.Color(bg[0] / 255, bg[1] / 255, bg[2] / 255);
    this.scene.background = bgColor;
    // The ambient Scene type narrows fog to Fog; FogExp2 is valid at runtime.
    this.scene.fog = new THREE.FogExp2(bgColor, donors.theme.fogDensity) as unknown as THREE.Fog;

    const group = new THREE.Group();
    const material = new THREE.MeshBasicMaterial({
      vertexColors: true,
      side: THREE.DoubleSide,
    });

    // Per-kind cell lists, in row-major first-appearance order.
    const byKind = new Map<string, [number, number][]>();
    for (let gy = 0; gy < town.height; gy++) {
      for (let gx = 0; gx < town.width; gx++) {
        const id = town.tiles[gy * town.width + gx];
        let list = byKind.get(id);
        if (!list) {
          list = [];
          byKind.set(id, list);
        }
        list.push([gx, gy]);
        if (resolveAsset(donors, id).layer === "floor") this.counts.floor++;
        else this.counts.structure++;
      }
    }

    const matrix = new THREE.Matrix4();
    for (const [id, cells] of byKind) {
      const asset = resolveAsset(donors, id);
      const vol = decodeSlab(donors.slabs[asset.slab]);
      const plated = asset.layer === "floor" ? plateSlab(vol) : vol;
      this.groundByKind.set(id, plated.dims[2] / VOXELS_PER_CELL);
      const slab = meshSlab(plated, asset.layer === "floor" ? { omitBottom: true } : undefined);
      const mesh = new THREE.InstancedMesh(slabGeometry(slab, donors.theme), material, cells.length);
      const base = meanColor(slab);
      // Tint hash keyed by tile id: same id tints alike across the town.
      const tint = new ScatterHash(kindHash(id, donors.constants.tintSalt));
      for (let i = 0; i < cells.length; i++) {
        const [gx, gy] = cells[i];
        matrix.makeTranslation(gx * VOXELS_PER_CELL, 0, -gy * VOXELS_PER_CELL);
        mesh.setMatrixAt(i, matrix);
        const j = tint.jitter(gx, gy);
        mesh.setColorAt(i, base.clone().multiplyScalar(1 + TINT_SPAN * j.x));
      }
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
      group.add(mesh);
      this.meshes.push(mesh);
    }

    // Deco props over walkable ground (floor layer incl. fallbacks).
    const scatter = new ScatterHash(0);
    const propIds = PROP_IDS.filter((id) => donors.props[id]);
    if (propIds.length > 0) {
      const spots = new Map<string, PropSpot[]>();
      for (let gy = 0; gy < town.height; gy++) {
        for (let gx = 0; gx < town.width; gx++) {
          if (resolveAsset(donors, town.tiles[gy * town.width + gx]).layer !== "floor") continue;
          if (!scatter.presence(gx, gy, donors.theme.decoDensity / 100)) continue;
          const propId = propIds[scatter.variant(gx, gy, propIds.length)];
          const j = scatter.jitter(gx, gy);
          let list = spots.get(propId);
          if (!list) {
            list = [];
            spots.set(propId, list);
          }
          list.push({ gx, gy, ox: j.x * JITTER_VOXELS, oz: j.y * JITTER_VOXELS });
        }
      }
      for (const [propId, list] of spots) {
        const slab = meshSlab(decodeSlab(donors.slabs[donors.props[propId].slab]));
        const mesh = new THREE.InstancedMesh(slabGeometry(slab, donors.theme), material, list.length);
        for (let i = 0; i < list.length; i++) {
          const s = list[i];
          matrix.makeTranslation(
            s.gx * VOXELS_PER_CELL + s.ox,
            0,
            -s.gy * VOXELS_PER_CELL + s.oz,
          );
          mesh.setMatrixAt(i, matrix);
        }
        group.add(mesh);
        this.meshes.push(mesh);
        this.counts.props += list.length;
      }
    }

    group.scale.setScalar(1 / VOXELS_PER_CELL); // 1 voxel = 1/16 world unit
    group.updateMatrixWorld(true);
    this.scene.add(group);
    this.scene.add(this.entities.group);

    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 300);
  }

  /** Terrain top under a cell, in world units -- the billboard ground line. */
  groundHeight(x: number, y: number): number {
    return this.groundByKind.get(this.town.tiles[y * this.town.width + x]) ?? 0;
  }

  resize(w: number, h: number): void {
    this.renderer.setSize(w, h);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }

  /** Map a pointer event to a town cell, or null when nothing is hit. */
  pick(clientX: number, clientY: number): { x: number; y: number } | null {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return null;
    const nx = ((clientX - rect.left) / rect.width) * 2 - 1;
    const ny = -((clientY - rect.top) / rect.height) * 2 + 1;
    this.raycaster.setFromCamera(new THREE.Vector2(nx, ny), this.camera);
    const hit = this.raycaster.intersectObjects(this.meshes, false)[0];
    if (!hit) return null;
    // Undo the group scale (1/16) and the (gx, 0, -gy) cell offsets:
    // cell (gx, gy) spans world x [gx, gx+1), z [-gy-1, -gy).
    const x = Math.floor(hit.point.x);
    const y = Math.floor(-hit.point.z);
    if (x < 0 || y < 0 || x >= this.town.width || y >= this.town.height) return null;
    return { x, y };
  }
}
