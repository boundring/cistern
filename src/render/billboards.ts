import * as THREE from "three";

/** billboard_entities.gd QUAD_SIZE: 0.8 world units per side. */
const QUAD_SIZE = 0.8;

/** billboard_entities.gd _color_for_kind -- the donor color law, ported
 * whole. Colors are raw numerics (working space) like the scene's vertex
 * colors: authored bytes under the LinearSRGB passthrough. */
const KIND_COLORS: Record<string, readonly [number, number, number]> = {
  player: [0.25, 0.55, 0.95],
  mook: [0.85, 0.3, 0.25],
  mook_drone: [0.85, 0.3, 0.25],
  townsfolk: [0.4, 0.78, 0.62],
};
const FALLBACK_COLOR: readonly [number, number, number] = [0.8, 0.8, 0.25];

/** Vertical yaw-only quads per entity (donor W3-2 billboard_entities.gd):
 * unshaded, double-sided, grounded on the cell's terrain top, and turned
 * toward the camera around world up only (the donor's BILLBOARD_FIXED_Y). */
export class BillboardEntities {
  readonly group = new THREE.Group();
  private readonly nodes = new Map<number, THREE.Mesh>();
  private readonly quad = new THREE.PlaneGeometry(QUAD_SIZE, QUAD_SIZE);
  private readonly materials = new Map<string, THREE.MeshBasicMaterial>();

  /** (Re)place one entity's billboard at its cell. */
  spawn(id: number, kind: string, x: number, y: number, ground: number): void {
    const old = this.nodes.get(id);
    if (old) {
      this.group.remove(old);
      this.nodes.delete(id);
    }
    const mesh = new THREE.Mesh(this.quad, this.materialFor(kind));
    mesh.position.set(x, ground + QUAD_SIZE * 0.5 + 0.1, -y);
    this.group.add(mesh);
    this.nodes.set(id, mesh);
  }

  moveEntity(id: number, x: number, y: number, ground: number): void {
    const mesh = this.nodes.get(id);
    if (!mesh) return;
    mesh.position.set(x, ground + QUAD_SIZE * 0.5 + 0.1, -y);
  }

  count(): number {
    return this.nodes.size;
  }

  /** The yaw-only half of BILLBOARD_FIXED_Y: face the camera horizontally,
   * keep the quad vertical. One call per frame before render. */
  faceCamera(camera: THREE.PerspectiveCamera): void {
    for (const mesh of this.nodes.values()) {
      mesh.rotation.y = Math.atan2(
        camera.position.x - mesh.position.x,
        camera.position.z - mesh.position.z,
      );
    }
  }

  private materialFor(kind: string): THREE.MeshBasicMaterial {
    let mat = this.materials.get(kind);
    if (!mat) {
      const [r, g, b] = KIND_COLORS[kind] ?? FALLBACK_COLOR;
      mat = new THREE.MeshBasicMaterial({
        color: new THREE.Color(r, g, b),
        side: THREE.DoubleSide,
      });
      this.materials.set(kind, mat);
    }
    return mat;
  }
}
