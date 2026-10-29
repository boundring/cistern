/**
 * Minimal ambient declarations for the vendored three.js r160 core module
 * (`vendor/three.module.min.js`). `@types/three` cannot be installed (only the
 * TypeScript compiler is an authorized network install), so this file declares
 * exactly the API surface cistern-web uses — no more.
 *
 * The importmap in index.html maps "three" -> "./vendor/three.module.min.js";
 * tsc resolves the types through this ambient declaration.
 */
declare module "three" {
  export const ACESFilmicToneMapping: number;
  export const NoToneMapping: number;
  export const SRGBColorSpace: string;
  export const LinearSRGBColorSpace: string;
  export const DoubleSide: number;
  export const BackSide: number;
  export const FrontSide: number;
  export const PCFSoftShadowMap: number;
  export const AdditiveBlending: number;

  export class Vector2 {
    constructor(x?: number, y?: number);
    x: number;
    y: number;
    set(x: number, y: number): this;
  }

  export class Vector3 {
    constructor(x?: number, y?: number, z?: number);
    x: number;
    y: number;
    z: number;
    set(x: number, y: number, z?: number): this;
    setScalar(s: number): this;
    copy(v: Vector3): this;
    add(v: Vector3): this;
    sub(v: Vector3): this;
    multiplyScalar(s: number): this;
    normalize(): this;
    length(): number;
    distanceTo(v: Vector3): number;
    lerp(v: Vector3, t: number): this;
    clone(): Vector3;
    applyMatrix4(m: Matrix4): this;
  }

  export class Color {
    constructor(r?: number | string, g?: number, b?: number);
    r: number;
    g: number;
    b: number;
    set(r: number | string, g?: number, b?: number): this;
    setHex(hex: number): this;
    copy(c: Color): this;
    multiplyScalar(s: number): this;
    lerp(c: Color, t: number): this;
    clone(): Color;
    getHexString(): string;
  }

  export class Matrix4 {
    constructor();
    makeScale(x: number, y: number, z: number): this;
    makeTranslation(x: number, y: number, z: number): this;
    makeRotationX(r: number): this;
    makeRotationY(r: number): this;
    makeRotationZ(r: number): this;
    setPosition(x: number | Vector3, y?: number, z?: number): this;
    clone(): Matrix4;
  }

  export class Euler {
    constructor(x?: number, y?: number, z?: number, order?: string);
    x: number;
    y: number;
    z: number;
  }

  export class BufferAttribute {
    constructor(array: ArrayLike<number>, itemSize: number, normalized?: boolean);
    count: number;
    itemSize: number;
    needsUpdate: boolean;
  }

  export class Float32BufferAttribute extends BufferAttribute {
    constructor(array: ArrayLike<number>, itemSize: number, normalized?: boolean);
  }

  export class Uint16BufferAttribute extends BufferAttribute {
    constructor(array: ArrayLike<number>, itemSize: number, normalized?: boolean);
  }

  export class Uint32BufferAttribute extends BufferAttribute {
    constructor(array: ArrayLike<number>, itemSize: number, normalized?: boolean);
  }

  export class BufferGeometry {
    constructor();
    setAttribute(name: string, attr: BufferAttribute): this;
    setIndex(index: number[] | BufferAttribute): this;
    getAttribute(name: string): BufferAttribute | undefined;
    computeVertexNormals(): void;
    dispose(): void;
    attributes: Record<string, BufferAttribute>;
  }

  export class BoxGeometry extends BufferGeometry {
    constructor(w?: number, h?: number, d?: number);
  }
  export class PlaneGeometry extends BufferGeometry {
    constructor(w?: number, h?: number, wSeg?: number, hSeg?: number);
  }
  export class SphereGeometry extends BufferGeometry {
    constructor(radius?: number, widthSeg?: number, heightSeg?: number);
  }
  export class RingGeometry extends BufferGeometry {
    constructor(inner?: number, outer?: number, thetaSeg?: number, phiSeg?: number);
  }

  export class Material {
    transparent: boolean;
    opacity: number;
    side: number;
    depthWrite: boolean;
    visible: boolean;
    dispose(): void;
  }

  export interface MaterialParameters {
    color?: number | Color;
    vertexColors?: boolean;
    flatShading?: boolean;
    side?: number;
    transparent?: boolean;
    opacity?: number;
    wireframe?: boolean;
    map?: Texture | null;
    depthWrite?: boolean;
    blending?: number;
  }

  export class MeshBasicMaterial extends Material {
    constructor(params?: MaterialParameters);
    color: Color;
    vertexColors: boolean;
    flatShading: boolean;
  }

  export class MeshLambertMaterial extends Material {
    constructor(params?: MaterialParameters);
    color: Color;
    emissive: Color;
    vertexColors: boolean;
    flatShading: boolean;
  }

  export class LineBasicMaterial extends Material {
    constructor(params?: MaterialParameters);
    color: Color;
  }

  export class Texture {
    needsUpdate: boolean;
    magFilter: number;
    minFilter: number;
    generateMipmaps: boolean;
    colorSpace: string;
  }

  export class CanvasTexture extends Texture {
    constructor(canvas: HTMLCanvasElement | OffscreenCanvas);
  }

  export class Object3D {
    position: Vector3;
    rotation: Euler;
    scale: Vector3;
    visible: boolean;
    name: string;
    children: Object3D[];
    add(...objs: Object3D[]): this;
    remove(...objs: Object3D[]): this;
    traverse(fn: (o: Object3D) => void): void;
    updateMatrixWorld(force?: boolean): void;
    matrixWorld: Matrix4;
  }

  export class Group extends Object3D {
    constructor();
  }

  export class Mesh extends Object3D {
    constructor(geometry?: BufferGeometry, material?: Material | Material[]);
    geometry: BufferGeometry;
    material: Material | Material[];
  }

  export class LineSegments extends Object3D {
    constructor(geometry?: BufferGeometry, material?: Material | Material[]);
  }

  export class InstancedMesh extends Mesh {
    constructor(geometry: BufferGeometry, material: Material, count: number);
    count: number;
    instanceMatrix: { needsUpdate: boolean };
    instanceColor: { needsUpdate: boolean } | null;
    setMatrixAt(index: number, m: Matrix4): void;
    getMatrixAt(index: number, m: Matrix4): void;
    setColorAt(index: number, c: Color): void;
  }

  export class Scene extends Object3D {
    constructor();
    background: Color | null;
    fog: Fog | FogExp2 | null;
  }

  export class Fog {
    constructor(color: number | Color, near?: number, far?: number);
    color: Color;
    near: number;
    far: number;
  }

  export class FogExp2 {
    constructor(color: number | Color, density?: number);
    color: Color;
    density: number;
  }

  export class PerspectiveCamera extends Object3D {
    constructor(fov?: number, aspect?: number, near?: number, far?: number);
    fov: number;
    aspect: number;
    near: number;
    far: number;
    updateProjectionMatrix(): void;
    lookAt(x: number | Vector3, y?: number, z?: number): void;
  }

  export class AmbientLight extends Object3D {
    constructor(color?: number | Color, intensity?: number);
    intensity: number;
    color: Color;
  }

  export class DirectionalLight extends Object3D {
    constructor(color?: number | Color, intensity?: number);
    intensity: number;
    color: Color;
    position: Vector3;
    target: Object3D;
  }

  export class Raycaster {
    constructor();
    setFromCamera(coords: Vector2, camera: PerspectiveCamera): void;
    intersectObject(obj: Object3D, recursive?: boolean): Intersection[];
    intersectObjects(objs: Object3D[], recursive?: boolean): Intersection[];
    ray: { origin: Vector3; direction: Vector3 };
  }

  export interface Intersection {
    distance: number;
    point: Vector3;
    face: { normal: Vector3; materialIndex: number } | null;
    object: Object3D;
    instanceId?: number;
    index?: number;
  }

  export interface WebGLRendererParameters {
    canvas?: HTMLCanvasElement;
    antialias?: boolean;
    alpha?: boolean;
    preserveDrawingBuffer?: boolean;
  }

  export class WebGLRenderer {
    constructor(params?: WebGLRendererParameters);
    domElement: HTMLCanvasElement;
    shadowMap: { enabled: boolean; type: number };
    toneMapping: number;
    toneMappingExposure: number;
    outputColorSpace: string;
    setSize(w: number, h: number, updateStyle?: boolean): void;
    setPixelRatio(r: number): void;
    setClearColor(color: number | Color, alpha?: number): void;
    render(scene: Scene, camera: PerspectiveCamera): void;
    dispose(): void;
    info: { render: { triangles: number; calls: number } };
  }

  export const MathUtils: {
    clamp(v: number, lo: number, hi: number): number;
    lerp(a: number, b: number, t: number): number;
    degToRad(d: number): number;
    radToDeg(r: number): number;
  };
}
