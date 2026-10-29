# LIBRARY-REFERENCE — cistern-web v3

Appendix for the v3 build: the three.js surface the code actually touches,
the donor GDScript it mirrors, and the external references it was written
against.

---

## 1. three.js r160 — the API surface the build uses

The build vendors **three.js r160** at `vendor/three.module.min.js`
(670,681 bytes, MIT, upstream `Copyright 2010-2023 Three.js Authors`; the
minified bundle carries `const t="160"` as its revision marker). It is
resolved through the importmap in `index.html`:

```html
<script type="importmap">
{ "imports": { "three": "./vendor/three.module.min.js" } }
</script>
<script type="module" src="./out/main.js"></script>
```

`@types/three` cannot be installed (only the TypeScript compiler is an
authorized network install), so `src/types/three.d.ts` declares **exactly** the
API surface this build uses, as an ambient `declare module "three"`. Every
import site uses `import * as THREE from "three"`.

### 1.1 The used surface

| API | Where the build uses it | Note |
|---|---|---|
| `BufferGeometry` | `src/render/voxel.ts`, `src/render/figures.ts`, `src/render/world.ts`, `src/render/scene.ts` | One merged geometry per terrain mesh, per voxel model, per figure part, per slab kind. `setAttribute` attaches the per-vertex `position` / `normal` / `color` attributes. |
| `Float32BufferAttribute` | `src/render/figures.ts:101`, `src/render/scene.ts:108-110`, `src/render/voxel.ts:62-63`, `src/render/world.ts:217-218` | Carries `position` (item 3) and the baked `color` (item 3) attributes. |
| `PlaneGeometry` | `src/render/world.ts:243` | The single water plane, sized `FOOTPRINT_SPAN_X + 200` by `FOOTPRINT_SPAN_Z + 200` so it reaches past the footprint into the sea. |
| `Mesh` | `src/render/figures.ts:120`, `src/render/scene.ts`, `src/render/world.ts` | A mesh is a geometry plus one unlit material. |
| `MeshBasicMaterial` | `src/render/figures.ts:119`, `src/render/scene.ts:157-160`, `src/render/world.ts:98,244-248` | Unlit: all lighting is baked into vertex colours. `vertexColors: true` everywhere; `side: THREE.DoubleSide` on the town diorama and the terrain mesh; the water plane sets `transparent: true`, `opacity: 0.55`, `depthWrite: false`. |
| `Color` | `src/render/scene.ts:64-75,151,194`, `src/render/world.ts:88,245` | Theme background and fog colour from `reference.ron`'s palette; per-instance tint via `base.clone().multiplyScalar(...)`; a reused scratch colour in the scatter path (no per-frame allocation). |
| `Group` | `src/render/figures.ts` (`group`), `src/render/world.ts` (`group`), `src/render/scene.ts` | The transform node for each subsystem; `game.ts` adds the world group and the figures group to the scene. |
| `InstancedMesh` | `src/render/scene.ts:185,222`, `src/render/world.ts:327` | One instance buffer per tile kind, per prop kind and per scatter model. `setMatrixAt(index, m)` positions an instance; `setColorAt(index, c)` tints it; `instanceMatrix.needsUpdate = true` and `instanceColor.needsUpdate = true` upload the buffers. `instanceColor` is nullable, so the code guards it. |
| `Matrix4.makeTranslation` | `src/render/scene.ts:191,225`, `src/render/world.ts:334` | The only matrix operation the build performs — a translation per instance. |
| `Euler` / `rotation` | `src/render/figures.ts:223,239,246-249`, `src/render/world.ts:251` | The `Euler` **class** is never constructed; only `Object3D.rotation` is read and written (`rotation.y` for facing, `rotation.x` for the limb swing and the water plane). |
| `Vector3` | `src/game.ts:95,201`, `src/render/camera.ts:14,18,24`, `src/render/figures.ts:253` | The orbit target, the figure world position returned by `positionOf`, and the projection source for `entityScreenPos`. |
| `MathUtils.clamp` | `src/render/camera.ts:30-31` | The only `MathUtils` member called: clamps pitch and distance. |
| `PerspectiveCamera` | `src/render/scene.ts`, `src/render/camera.ts`, `src/render/figures.ts` | The orbit camera; `updateProjectionMatrix()` is called on resize; `lookAt` is called by `OrbitCamera.apply()`. |
| `Scene` | `src/render/scene.ts` | Holds the background colour and the fog; `scene.add(...)` receives the world group and the figures group. |
| `WebGLRenderer` | `src/render/scene.ts:144-148,259,265,282` | Constructed with `{ canvas, antialias: true }`; `setPixelRatio(min(devicePixelRatio, 2))`; `setSize(w, h)` on resize; `render(scene, camera)` per frame; `getContext()` for the pixel probe. |
| `Raycaster` | `src/render/scene.ts:129,312-313` | `setFromCamera(new THREE.Vector2(nx, ny), camera)` then `intersectObjects(this.meshes, false)[0]` for tile picking. `camera.updateMatrixWorld()` is called in `OrbitCamera.apply()` because the raycaster reads `matrixWorld` directly. |
| `ACESFilmicToneMapping` | `src/render/scene.ts:145` | `renderer.toneMapping = THREE.ACESFilmicToneMapping`. |
| `LinearSRGBColorSpace` | `src/render/scene.ts:147` | `renderer.outputColorSpace = THREE.LinearSRGBColorSpace` — raw passthrough, because the vertex colours are authored bytes, not sRGB-decoded values. |

### 1.2 Declared locally but unused

`src/types/three.d.ts` declares more than the build consumes. These symbols
are in the ambient declaration file and appear **nowhere** in `src/`,
`tools/` or `index.html`:

- **Constants:** `SRGBColorSpace`, `NoToneMapping`, `FrontSide`, `BackSide`,
  `PCFSoftShadowMap`, `AdditiveBlending`.
- **Classes:** `AmbientLight`, `DirectionalLight`, `CanvasTexture`,
  `LineBasicMaterial`, `LineSegments`, `MeshLambertMaterial`, `RingGeometry`,
  `SphereGeometry`, `Uint16BufferAttribute`, `Uint32BufferAttribute`.
- **Used only as supertypes, never instantiated:** `BufferAttribute` (the
  base of `Float32BufferAttribute`), `Material` (the base of
  `MeshBasicMaterial`), `Object3D` (the base of `Group` / `Mesh`), `Texture`
  (the base of `CanvasTexture`).

Three further declarations are declared with members the build never calls:
`Euler` (never constructed — only `Object3D.rotation` is used),
`MathUtils.lerp`, `MathUtils.degToRad` and `MathUtils.radToDeg` (only
`MathUtils.clamp` is called), and `InstancedMesh.getMatrixAt` (the build
writes matrices but never reads them back).

Two of these matter for a reader expecting a stock three.js setup:

- `SRGBColorSpace` is declared but the build deliberately uses
  `LinearSRGBColorSpace` instead — the vertex colours are already linear
  bytes.
- `NoToneMapping` is declared but the build uses `ACESFilmicToneMapping`; the
  donor's `reference.ron` sets `tonemap: true`.

### 1.3 Manual pages (r160)

`threejs.org/docs/#api/en/...` tracks the current release, so for r160 use
the pinned tag under `mrdoob/three.js` at `r160`. Both forms are listed; all
`threejs.org` anchors below were checked live and return 200.

| Class / constant | Manual (current) | Pinned r160 source |
|---|---|---|
| `BufferGeometry` | https://threejs.org/docs/#api/en/core/BufferGeometry | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/core/BufferGeometry.html |
| `BufferAttribute` | https://threejs.org/docs/#api/en/core/BufferAttribute | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/core/BufferAttribute.html |
| `Object3D` | https://threejs.org/docs/#api/en/core/Object3D | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/core/Object3D.html |
| `Raycaster` | https://threejs.org/docs/#api/en/core/Raycaster | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/core/Raycaster.html |
| `PlaneGeometry` | https://threejs.org/docs/#api/en/geometries/PlaneGeometry | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/geometries/PlaneGeometry.html |
| `Group` | https://threejs.org/docs/#api/en/objects/Group | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/objects/Group.html |
| `Mesh` | https://threejs.org/docs/#api/en/objects/Mesh | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/objects/Mesh.html |
| `InstancedMesh` | https://threejs.org/docs/#api/en/objects/InstancedMesh | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/objects/InstancedMesh.html |
| `MeshBasicMaterial` | https://threejs.org/docs/#api/en/materials/MeshBasicMaterial | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/materials/MeshBasicMaterial.html |
| `Scene` | https://threejs.org/docs/#api/en/scenes/Scene | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/scenes/Scene.html |
| `Fog` / `FogExp2` | https://threejs.org/docs/#api/en/scenes/FogExp2 | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/scenes/FogExp2.html |
| `PerspectiveCamera` | https://threejs.org/docs/#api/en/cameras/PerspectiveCamera | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/cameras/PerspectiveCamera.html |
| `WebGLRenderer` | https://threejs.org/docs/#api/en/renderers/WebGLRenderer | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/renderers/WebGLRenderer.html |
| `Vector3` | https://threejs.org/docs/#api/en/math/Vector3 | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/math/Vector3.html |
| `Matrix4` | https://threejs.org/docs/#api/en/math/Matrix4 | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/math/Matrix4.html |
| `Color` | https://threejs.org/docs/#api/en/math/Color | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/math/Color.html |
| `Euler` | https://threejs.org/docs/#api/en/math/Euler | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/math/Euler.html |
| `MathUtils` | https://threejs.org/docs/#api/en/math/MathUtils | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/math/MathUtils.html |
| `ACESFilmicToneMapping`, `NoToneMapping`, `SRGBColorSpace` | https://threejs.org/docs/#api/en/constants/Renderer | https://github.com/mrdoob/three.js/blob/r160/docs/api/en/constants/Renderer.html |

`SRGBColorSpace` is documented under **Core** and **Textures** rather than
**Renderer**: https://threejs.org/docs/#api/en/constants/Core

---

## 2. Donor GDScript mirrored

**Every donor file is READ-ONLY.** Nothing under
`/mnt/2tb/@home/bricker/Projects/etc/cistern` may be edited, moved or written
to. Where the build needs a donor file at build time, it copies the closure
into a scratch project under `/tmp` and runs the probe there. The web repo
keeps its own byte-identical vendored copies of the small content files under
`vendor/cistern/` (md5-verified against the donor):

```
1a689c95544d7b5ed007907f4e477547  vendor/cistern/scripts/view/scatter_hash.gd
1c152e755134fa88d446dcb747d24fa0  vendor/cistern/scripts/sim/town_map.gd
b6ec496cca808bb3bfa2beee6e40392b  vendor/cistern/content/themes/reference.ron
097a322c164bb42204304451e7364479  vendor/cistern/content/tiles.ron
b0798eb09d31d756cfe270453a3fc291  vendor/cistern/content/copy.ron
```

Each md5 matches the corresponding donor file exactly.

### 2.1 The ported and mirrored files

| Donor file (read-only) | What it contributes | Consumed by |
|---|---|---|
| `godot/scripts/view/world_heightmap.gd` | The open-world relief law, iteration 3: the six sibling FastNoiseLite noises (salts 242–247 over `TileTable.SCATTER_SEED`, frequencies 1/45, 1/64, 1/52, 1/26, 1/30, 1/20; octaves 2, 2, 2, 3, 2, 4), the domain-warped biome weight masks, the macro composition (hills/plains, ridged chains, terraced plateaus, rim ring, rift basins, the graben floors), `tectonic_uplift`, `rift_bowl`, the global water table (`TABLE_STEPS = 4`), the river valley carve, the tributary channel carve, the village flat and the parent's ring-hamlet flat. | `src/core/world.ts` — `WorldHeightmap.stepsAt`, `macroSteps`, `biomeWeights`, `tectonicUplift`, `riftBowl`, `warpSample`, `tableHeight`, `villageHeight`, `isWater`, `kindAt`, `waterDepth`. |
| `godot/scripts/view/hd2d_heightmap.gd` | The parent of the law: `SUB = 8` sub-voxels per cell, `VOXEL = 0.125` world units per relief step, `MAX_STEPS = 40`, `MARGIN_FRAC = 0.5` (the margin ring is half the playable size per side), `TOWN_FLAT_RADIUS = 5.0` / `TOWN_FLAT_CORE = 2.0`, `PLAYABLE_AMP` / `FAR_AMP`, and `town_center_for(p_w, p_h, margin_z)`. | `src/core/terrain.ts` — the frozen constants (`SUB`, `VOXEL`, `MAX_STEPS`, `MARGIN_X`, `MARGIN_Z`). The parent's own `_noise` (frequency 1/12) is never sampled by the law and is not constructed. |
| `godot/scripts/view/scatter_hash.gd` | The per-cell deterministic decoration law: a FNV-style position hash of `(|gx|, |gy|, floor_identity)` mixed with the pinned seed, reseeding a fresh RNG per query so a result is a pure function of the cell and never of iteration order; `presence`, `variant`, `jitter`. | `src/core/scatter.ts` — `cellSeed`, `ScatterHash`. Consumed by `src/render/world.ts` (the scatter), `src/render/figures.ts` (the per-figure tint), `src/render/scene.ts` (the deco props and the per-kind tint) and `src/game.ts` (the world villagers). |
| `godot/scripts/view/billboard_entities.gd` | The figure palette: `_color_for_kind` gives `player` `Color(0.25, 0.55, 0.95)`, `townsfolk` `Color(0.40, 0.78, 0.62)`, `mook` / `mook_drone` `Color(0.85, 0.30, 0.25)`, and a default `Color(0.80, 0.80, 0.25)`. | `src/render/figures.ts` — the `GARMENT` table (`player [0.25, 0.55, 0.95]`, `townsfolk [0.4, 0.78, 0.62]`). The `villager` garment colour is a web-side addition; the donor has no villager kind. |
| `godot/scripts/view/prefab_factory.gd` and `godot/scripts/view/slab_assembler.gd` | The donor's box-assembly discipline: `SlabAssembler` holds the six-face table and the baked per-face sun tints (`+z 0.82`, `-z 0.60`, `±x 0.72`, top `1.0`, bottom `0.50`) and assembles tinted boxes into one `ArrayMesh`; `PrefabFactory` builds one cached `ArrayMesh` per prefab kind (`TREE_VARIANTS 3`, `PINE_VARIANTS 2`, `HOUSE_VARIANTS 5`, …) and instances them. | **The town diorama in `src/render/scene.ts` is not built from these.** It is built from the baked Cistern slab JSON (`vendor/cistern/assets/slabs/*.json`) through `src/core/slab.ts`, following the archived Rust HD lane's shading law (top `1.0`, side `0.78`), not the donor's `FACE_TINTS` table; `src/render/voxel.ts` and `src/render/figures.ts` use top `1.0` / side `0.78` / bottom `0.62`. What the build does carry over is the *discipline*: one merged geometry per model kind, instanced per cell, with the shading baked into vertex colours. These two donor files are in the probe closure only (see 2.2). |
| `godot/scripts/view/tile_table.gd` | `SCATTER_SEED = 0x0C157E2026`, the seed both the tile table and the L3 decoration scatter share. It also defines the 14-id wire tile vocabulary and the `SlabDef` table (layer, height, colour per tile id). | `src/core/scatter.ts` — `SCATTER_SEED`. The seed reaches the bake through the vendored stub `tools/godot-probe/tile_table_stub.gd` (which carries the same constant). The wire vocabulary reaches `src/core/town.ts` (the glyph parse) and `src/core/copy.ts` (the 14-tile copy-key map); the `SlabDef` colours are not ported — the web takes tile colours from `content/tiles.ron` and the baked slab JSON. |
| `godot/scripts/world/world_level.gd` | The river curves: `river_x(z) = 66.0 + 10.0*sin(0.045z + 0.8) + 4.0*sin(0.013z + 2.0)` and `river_halfw(z) = 2.0 + 0.8*sin(0.031z + 1.3)`; the three tributary channel polylines with their half-widths (`1.05`, `0.85`, `0.85`); `VILLAGE = Vector2(44.5, 58.5)`; and `corridors()`, the authored road/rail grading that the web build **drops**. | `src/core/world.ts` — `riverX`, `riverHalfWidth`, and the `CHANNELS` table. The village centre is relocated to `VILLAGE_X` / `VILLAGE_Y` (34, 16); the corridors are dropped, and the probe applies the same trim so the golden compares like for like. |
| `godot/scripts/sim/town_map.gd` | The authored 34x16 starter-town template (`STARTER_TOWN_ROWS`), the glyph-to-wire-tile map (`GLYPH_TILES`), the two quarantined seed draws (`TEMPLATE_SELECT_KEY = (1 << 8) | 2`, `TOWN_FLAVOR_KEY = (6 << 8) | 2`), the shop names and the fixture cells. | `src/core/town.ts` — the template parse and the FLAVOR dressing pass. The template is baked into `src/generated/donors.ts` by `tools/bake-donors.mjs`. |
| `content/themes/reference.ron` | The UI theme: the colour palette (`bg`, `panel`, `accent`, `text`, …), `post.fog_density = 0.016`, `density.deco_density = 12.0`, and the lighting `sun_dir`. | The baked donors — `src/generated/donors.ts` (`theme.palette`, `theme.fogDensity`, `theme.decoDensity`), consumed by `src/render/scene.ts` (background, fog, slab palette) and `src/render/world.ts` (the baked sun direction). **Note the path:** `reference.ron` lives at the *repository root* of the donor, `cistern/content/themes/reference.ron` — there is no `godot/content/` directory. |

Two further donor files are mirrored beyond the table above, both under
`godot/scripts/sim/`:

| Donor file (read-only) | What it contributes | Consumed by |
|---|---|---|
| `godot/scripts/sim/town_state.gd` | The energy/turn tick model over the armed actors, the strict `(y, x, id)` action order, walk legality, and the canonical `seq`-prefixed event transcript. | `src/core/sim.ts` — `TownSim` (documented in-file as a trimmed port; the player marker waits forever, and the servant/shop systems stay donor-only). |
| `godot/scripts/sim/townsfolk.gd` | The ambient townsfolk: two keyed sub-streams (`PLACEMENT_KEY = (4 << 8) | 2`, `WANDER_KEY = (4 << 8) | 3`), `MIN_COUNT 6` / `MAX_COUNT 10`, `SLOW_SPEED 50`, `SLOW_ONE_IN 2`, and the `AXIS_DIRS` walk set. | `src/core/townsfolk.ts` — `populateTownsfolk`, `actTownsfolk`. |

### 2.2 The scratch-project copy rule for probes

The goldens are baked from a headless Godot probe run against a **scratch
copy**, never against the donor repo, and never by editing the donor:

```
scratch=/tmp/gp-world
mkdir -p "$scratch/scripts/view" "$scratch/scripts/world"
printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
cp <donor>/godot/scripts/view/{tile_table,scatter_hash,slab_def,prefab_factory,slab_assembler,hd2d_heightmap,world_heightmap}.gd "$scratch/scripts/view/"
cp <donor>/godot/scripts/world/world_level.gd "$scratch/scripts/world/"
cp tools/godot-probe/probe_world.gd "$scratch/"
godot --headless --path "$scratch" --import
godot --headless --path "$scratch" -s probe_world.gd > tests/golden/world.txt
```

Eight donor `.gd` files form the closure: `world_level.gd` names
`PrefabFactory`, which names `SlabAssembler`; every class resolves through
`class_name`, and nothing in the closure reads `content/`. The noise probe
needs no donor files at all — Godot's `FastNoiseLite` is built in — so its
scratch project holds only `project.godot` and the probe.

Both probes carry their regeneration recipe in their header comment; keep it
accurate when the probe changes.

---

## 3. External references

### 3.1 Godot's FastNoiseLite source

The port mirrors **Godot's** fork of FastNoiseLite, not upstream Auburn's.
The header the port was written against:

- https://raw.githubusercontent.com/godotengine/godot/master/thirdparty/misc/FastNoiseLite.h
  — version 1.1.0, `namespace fastnoiselite`, with `Lookup<float>::Gradients2D`
  (128 unit gradients indexed by a prime hash) and `SingleOpenSimplex2S`.

The path named in `CONTRACT.md`
(`thirdparty/fastnoise_lite/fast_noise_lite.h`) returns **404**; the
`thirdparty/misc/` path above is the one that resolves and the one the port
matches.

Upstream (the algorithm Godot's fork derives from, for reference):
https://raw.githubusercontent.com/Auburn/FastNoiseLite/master/Cpp/FastNoiseLite.h

Licence: FastNoiseLite is MIT, and Godot's `thirdparty/` copies carry their
upstream notices. The web build **ports** the algorithm rather than copying
the file; the README's provenance table records it as "ported, not copied".

### 3.2 Godot's FastNoiseLite class documentation

- https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html
- https://docs.godotengine.org/en/4.7/classes/class_fastnoiselite.html

The class docs give the `noise_type`, `frequency`, `fractal_type`,
`fractal_lacunarity`, `fractal_gain` and `seed` properties the donor sets,
and the `TYPE_SIMPLEX_SMOOTH` / `FRACTAL_FBM` enumerations.

### 3.3 Godot 4.7 class reference

- https://docs.godotengine.org/en/4.7/classes/index.html
- https://docs.godotengine.org/en/stable/classes/index.html

The engine used to bake every golden is **4.7.2**
(`godot --version` → `4.7.2.stable.arch_linux.ed1daf0bf`), installed at
`/usr/bin/godot`.

### 3.4 The donor design document

- `/home/bricker/Projects/omp-work/PLANS/2026-10-28-cistern-web-charter.md`

The operator-approved charter for the Cistern web build: the v1 scope, the
frozen stack (TypeScript compiled by `tsc` alone, three.js r160 vendored with
an importmap, local-only hosting), the determinism rules, the read-only
donor rule, and the v1 acceptance list. It is the ancestor of
`/home/bricker/Work/sessions/2026-10-29-webgame-v3/CHARTER.md`, which extends
it with the v3 scope (animated voxel figures, voxel items, the ~4x world,
the detailed environment, the camera and inspector, the added tests).

### 3.5 Repository-internal references

| Document | Path |
|---|---|
| Frozen interface contract | `/home/bricker/Work/sessions/2026-10-29-webgame-v3/CONTRACT.md` |
| v3 mission and constraints | `/home/bricker/Work/sessions/2026-10-29-webgame-v3/CHARTER.md` |
| Session handoff (state of record) | `/home/bricker/Work/sessions/2026-10-29-webgame-v3/handoff/2026-10-29-webgame-v3.md` |
| Architecture | `docs/v3/ARCHITECTURE.md` |
| Test contract | `docs/v3/TEST-SPEC.md` |
| Skeleton tree | `docs/v3/skeleton/README.md` |
| Working session list | `docs/v3/WORKING-SESSION-LIST.md` |
| Requirements matrix | `docs/v3/REQUIREMENTS-MATRIX.md` |
