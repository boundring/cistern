# REQUIREMENTS-MATRIX — cistern-web v3

One row per operator ask. **Ask** is the ask as the operator stated it.
**Where it is owned** is the target file path in the canonical tree.
**Skeleton stub** is the stub under `docs/v3/skeleton/` that the owning
session promotes. **Defining test(s)** are the canonical test names.
**Smoke assertion** is the CI-equivalent check in `tools/smoke.mjs`, where one
exists.

### Legend

- **Status: implementation present in working tree, uncommitted; skeleton +
  spec committed** — the v3 code for this ask exists in the working tree of
  `/mnt/2tb/@home/bricker/Projects/etc/cistern-web`; the skeleton stub and
  the planning spec are committed with it by the orchestrator's
  explicit-pathspec commit.

  **Dated correction.** This status was written while the implementation was
  still uncommitted. The orchestrator then landed it in three commits:
  `2e96da3` (the v3 implementation, the planning set and the 25 skeleton
  stubs), `e43f2cc` (the three new golden test files) and `e6aa809` (the two
  donor probes). The implementation is therefore **committed as of
  2026-10-29 17:50**; `git status` for `src/`, `tests/` and `tools/` is
  clean. As of 2026-11-03 the suite files for A1–A3 and A7–A12 have landed (tests/{figures,voxel,camera,inspector}.test.mjs); only the A7/A12 world-render suite (`tests/worldrender.test.mjs`) is still unwritten, and A10 water animation remains unasserted.

  **Dated correction (2026-11-03, wave-4 phase C).** The three parallel browser
  economy surfaces were excised (see "Removed browser economy surfaces" below),
  which drops 31 test cases: the suite was 124 cases before and is **93**
  after, all green. The two coverage gaps named above are unchanged.
- **Status: spec only** — planning artefact; no implementation is claimed.
- A defining test marked **(spec only)** names a case that exists in the
  skeleton stub but whose test file has **not** landed in `tests/` yet.

### Operator-set acceptance thresholds

These numbers are the operator's, not derived by the build:

| Threshold | Value | Where it binds |
|---|---|---|
| NPC pixel probe, distinct colours | `>= 5` | `tools/smoke.mjs` — a flat billboard quad yields 2-3 distinct colours |
| NPC pixel probe, luminance variance | `>= 500` | `tools/smoke.mjs` — calibrated against a ~1542 figure region and a ~168 ground-only baseline |
| Playable grid ratio | `4.00x` the authored town | 68x32 = 2176 cells against 34x16 = 544 cells; exactly 4 |
| Vista footprint | `136 x 64` cells | `FOOTPRINT_W` x `FOOTPRINT_H` (68 + 2x34 by 32 + 2x16) |
| World state pin | `playableW 68`, `playableH 32`, `footprintW 136`, `footprintH 64`, `villageX 34`, `villageY 16`, `townX 17`, `townY 8`, `townW 34`, `townH 16` | `tools/smoke.mjs` state assertions |
| Camera range | `DIST_MIN 3`, `DIST_MAX 140` | `src/render/camera.ts`, for the larger world plus close-ups |
| Viewports | `1280x800` and `375x667` | `tools/smoke.mjs` `SHOTS` |

---

| Ask | Where it is owned | Skeleton stub | Defining test(s) | Smoke assertion | Status | Notes |
|---|---|---|---|---|---|---|
| **A1** Animated voxel player model | `src/render/figures.ts` | `docs/v3/skeleton/src/render/figures.ts` | `a figure is a box hierarchy root>body>limbs` (spec only); `limb pivots sit at the joint` (spec only); `figure height matches the frozen part sizes` (spec only); `the per-figure tint is deterministic in the figure id` (spec only); `the garment palette matches the donor billboard palette` (spec only) | `state.counts.figures >= state.counts.townsfolk + 1`; NPC pixel probe `distinct >= 5` and `variance >= 500` | implementation present in working tree, uncommitted; skeleton + spec committed | The rig is `root -> body (bob) -> {torso, head, armL, armR, legL, legR}`, limbs pivoting at their top so a pivot rotation swings them. Frozen sizes: legs 0.16x0.30, torso 0.34x0.32x0.22, head 0.22 cube, arms 0.12x0.30. The walk cycle is procedural and keyed to travelled distance — no animation files. **The player figure is the operator's "visible player model" and its framing is a session-level choice (S10), not yet pinned by a test.** The `tests/figures.test.mjs` file has not landed; the five cases above exist only as skeleton stubs. |
| **A2** Animated voxel NPC (townsfolk) models | `src/render/figures.ts` | `docs/v3/skeleton/src/render/figures.ts` | `spawn adds a figure and moveTo retargets it` (spec only); `positionOf returns the figure's world position` (spec only); `update advances the walk cycle with travelled distance` (spec only) | NPC pixel probe `probe.fig.samples > 0`, `distinct >= 5`, `variance >= 500`; `state.counts.figures > state.counts.townsfolk` (the world villagers) | implementation present in working tree, uncommitted; skeleton + spec committed | The v2 verdict was that flat mint quads are not townsfolk; the acceptance that answers it is the pixel probe over the NPC region, not a state assertion. The garment colour is the donor's `townsfolk [0.4, 0.78, 0.62]`; `villager [0.8, 0.72, 0.45]` is a web-side addition. |
| **A3** Voxel items (scatter props as small voxel models) | `src/render/voxel.ts`, `src/render/world.ts` | `docs/v3/skeleton/src/render/voxel.ts`, `docs/v3/skeleton/src/render/world.ts` | `item models are small` (spec only); `trees rocks and items are instanced voxel models` (spec only) | `state.counts.items > 0` | implementation present in working tree, uncommitted; skeleton + spec committed | `src/render/voxel.ts` builds the crystal, berry-cluster and branch models; `src/render/world.ts` places them under the donor's hash-scatter law. |
| **A4** Larger open world (~4x playable grid) | `src/core/terrain.ts`, `src/core/world.ts` | `docs/v3/skeleton/src/core/terrain.ts`, `docs/v3/skeleton/src/core/world.ts` | `the playable grid is 4.00x the authored town` **(spec only — absent from the landed `tests/world.test.mjs`)**; `the law is a pure function of the grid`; `stepsAtCell matches the donor EXACTLY at every golden point` | `state.world.playableW === 68`, `playableH === 32`, `footprintW === 136`, `footprintH === 64`, `villageX === 34`, `villageY === 16`, `townX === 17`, `townY === 8`, `townW === 34`, `townH === 16` | implementation present in working tree, uncommitted; skeleton + spec committed | The law is the donor's `world_heightmap.gd` ported whole, as pure functions of grid coordinates with pinned seeds — no new noise algorithm. Two documented trims: no engineered corridors, and the village disc relocated to (34, 16). **Gap: the canonical case `the playable grid is 4.00x the authored town` is in the skeleton stub but not in the landed test file; the smoke's ten `state.world.*` pins cover the same numbers at run time.** |
| **A5** Desert biome | `src/core/world.ts` | `docs/v3/skeleton/src/core/world.ts` | `web extension: classification is deterministic and ordered` (asserts only that `desert` is in the legal vocabulary) | none | implementation present in working tree, uncommitted; skeleton + spec committed | **Not yet provable by a test.** The desert rule is `warpSample >= 0.25` and `stepsAtCell` in 6..9 and at least 30 cells from the village centre; no case asserts that a desert band *exists* or where it lies. The only assertion is vocabulary membership. Add a dedicated case (or extend the classification case) before this ask can be called proven. |
| **A6** Ocean biome | `src/core/world.ts`, `src/render/world.ts` | `docs/v3/skeleton/src/core/world.ts`, `docs/v3/skeleton/src/render/world.ts` | `web extension: the ocean band renders below the water table`; `web extension: the ocean band is exactly two cells wide on every side`; `water sits at tableHeight() and spans past the footprint` (spec only) | none | implementation present in working tree, uncommitted; skeleton + spec committed | The sea is a plane at `tableHeight()` spanning `FOOTPRINT_SPAN + 200` per axis, over lake floors. **Ruled (2026-10-31): the margin arithmetic stays and the width is fixed at two cells per side; the contract prose now says so.** The contract's `edge_norm` sentence is recorded as naming the band's purpose (the rim it must not drown), not the predicate. The width is pinned by `tests/world.test.mjs` (`web extension: the ocean band is exactly two cells wide on every side`) — no golden does, since the donor probe excludes the web-only extension. |
| **A7** Voxel trees | `src/render/voxel.ts`, `src/render/world.ts` | `docs/v3/skeleton/src/render/voxel.ts`, `docs/v3/skeleton/src/render/world.ts` | `broadleafModel is trunk plus three canopy boxes` (spec only); `pineModel is trunk plus three stacked boxes` (spec only); `scatter counts follow the donor hash-scatter law` (spec only) | `state.counts.trees > 0` | implementation present in working tree, uncommitted; skeleton + spec committed | Placed by the donor's hash-scatter law with a distinct floor identity per class and per-biome densities; one `InstancedMesh` per model kind with a per-instance deterministic tint. |
| **A8** Voxel rocks | `src/render/voxel.ts`, `src/render/world.ts` | `docs/v3/skeleton/src/render/voxel.ts`, `docs/v3/skeleton/src/render/world.ts` | `boulderModel is two or three offset boxes` (spec only) | `state.counts.rocks > 0` | implementation present in working tree, uncommitted; skeleton + spec committed | As A7. |
| **A9** Per-face donor-palette shading | `src/render/voxel.ts`, `src/render/figures.ts`, `src/core/slab.ts` | `docs/v3/skeleton/src/render/voxel.ts`, `docs/v3/skeleton/src/render/figures.ts` | `mergeBoxes emits six faces per box` (spec only); `mergeBoxes shades sides and bottom darker than the top` (spec only); `side faces are shaded by TERRAIN_SIDE_SHADE` (spec only) | none | implementation present in working tree, uncommitted; skeleton + spec committed | **Note the divergence:** the shading law the web build uses is the archived Rust HD lane's — top `1.0`, side `0.78`, bottom `0.62` — not the donor `slab_assembler.gd` `FACE_TINTS` table (`0.82 / 0.60 / 0.72 / 0.72 / 1.0 / 0.50`). The *discipline* (baked per-face tint, one merged geometry, unlit material) is the donor's; the numbers are the web lane's. |
| **A10** Deterministic water animation | `src/render/world.ts` | `docs/v3/skeleton/src/render/world.ts` | `water animation is deterministic in elapsedSeconds` (spec only) | none | implementation present in working tree, uncommitted; skeleton + spec committed | `update(elapsedSeconds)` moves the plane by a fixed sum of sines — `y += 0.02*sin(t*1.1) + 0.012*sin(t*2.3 + 1.7)`, `x = 0.03*sin(t*0.63)`, `z = 0.03*cos(t*0.47)`. No `Math.random`, no wall-clock read; the same `elapsedSeconds` always gives the same pose. **No smoke assertion covers the water animation** — it is provable only by the (spec-only) unit case. |
| **A11** Camera framing for the larger world plus close-ups | `src/render/camera.ts` | `docs/v3/skeleton/src/render/camera.ts` | `distance is clamped to the allowed range` (spec only); `pitch is clamped` (spec only); `setTarget moves the orbit focus` (spec only); `apply points the camera at the target` (spec only) | `dispatch({type:"zoom",distance:120})` succeeds (wide framing, `out/v3-wide.png`); `dispatch({type:"reset"})` + `orbit` + `zoom distance 4` succeeds (close framing, `out/v3-close.png`); the close-up must centre a townsfolk within 220 px of the frame centre | implementation present in working tree, uncommitted; skeleton + spec committed | `DIST_MIN 3`, `DIST_MAX 140`, pitch clamped to `[0.18, 1.35]`. **Ruled (2026-10-31): one default set — pitch `0.72`, distance `60`.** `src/render/camera.ts` exports `DEFAULT_PITCH`/`DEFAULT_DISTANCE`, the `OrbitCamera` fields take them, `Game` applies the same pair, and the smoke's `v3-default` shot restores them, so that screenshot is now the load framing. |
| **A12** Inspector covering terrain types and figures | `src/render/inspector.ts`, `src/types/game.ts` | `docs/v3/skeleton/src/render/inspector.ts`, `docs/v3/skeleton/src/types/game.ts` | `the terrain row renders kind steps and height` (spec only); `the terrain row renders the water case` (spec only); `the figure row renders kind and id` (spec only); `absent optional fields render empty strings` (spec only) | `dispatch(inspect)` returns the golden tile with non-empty copy text; `state().selection.text` equals it | implementation present in working tree, uncommitted; skeleton + spec committed | The two rows are the `[data-slot="terrain"]` and `[data-slot="figure"]` slots already in the panel markup; the selection's `terrain` and `figure` fields are optional and are read defensively. **The smoke asserts the tile and copy text only — it does not assert the terrain or figure rows**, so those two rows are provable only by the (spec-only) unit cases. |
| **A13** The 13 pre-existing golden tests stay green | `tests/rng.test.mjs`, `tests/scatter.test.mjs`, `tests/slab.test.mjs`, `tests/town.test.mjs`, `tests/townsfolk.test.mjs` | not in the skeleton tree — these files predate v3 | the pre-existing cases in those five files | the whole `npm test` run; `npm run smoke` runs the node-side golden cross-checks too | implementation present in working tree, uncommitted; skeleton + spec committed | **Count discrepancy, charter wording versus the tree.** The charter's "13 golden tests" is the count at the v1 commit (`28f382f`: rng 2 + scatter 2 + slab 4 + town 5 = 13). The v2 commit added the townsfolk file, so **18** cases across five files exist at HEAD (`d8ed1d9`), and all 18 are green. Nothing was deleted from those five files; the number is a charter artefact. The full suite is 93 cases, all green, after the 2026-11-03 economy excision (124 before it). |
| **A14** Golden tests for the ported heightmap values | `tests/world.test.mjs`, `tests/golden/world.txt`, `tools/godot-probe/probe_world.gd` | `docs/v3/skeleton/tests/world.test.mjs`, `docs/v3/skeleton/tools/godot-probe/probe_world.gd` | `stepsAtCell matches the donor EXACTLY at every golden point`; `biomeWeights matches the donor within 1e-5`; `tectonicUplift matches the donor within 1e-6`; `warpSample matches the donor warp noise within 1e-6`; `tableHeight matches the donor water table`; `river functions are the donor's own curves`; `villageHeight is the donor's clamped village base`; `the law is a pure function of the grid` | none | implementation present in working tree, uncommitted; skeleton + spec committed | The golden is baked from a headless Godot probe over the eight-file donor closure, copied into a scratch project under `/tmp`; the donor repo is read-only. **Name and tolerance notes:** the landed file spells the first case `stepsAt matches the donor EXACTLY at every golden point` (the canonical name says `stepsAtCell`), and carries an extra `golden coverage: the probe printed the full point set`. The residual was the donor's single-precision `Vector2` storage of the tectonic axes, not port drift; the port now reads those axes as float32 (`Math.fround`), which collapses the worst `biomeWeights` residual to 1.516e-8 and tightens the assertion from 1e-5 to 1e-7 (the case name keeps the older wording). |
| **A15** Golden tests for the walk-phase math | `tests/walk.test.mjs`, `tests/golden/walk.txt` | `docs/v3/skeleton/tests/walk.test.mjs` | `walkPhase is distance * TAU / STRIDE`; `walkPose derives swing and bob from the phase`; `idlePose is a slow deterministic bob`; `idlePose stays inside IDLE_AMP`; `the walk phase golden matches the recorded vector` | none | implementation present in working tree, uncommitted; skeleton + spec committed | **Name note:** none of the five canonical names is present verbatim in the landed file, which uses `STRIDE is 1 and idle constants are sane`, `walkPhase(d) === d * TAU / STRIDE at fixed distances`, `walkPose(phase): swing = sin(phase), bob = |sin(phase)|, phase echoed`, `idlePose deterministic, swing 0, |bob| <= IDLE_AMP` and `golden walk vector matches`. The assertions are equivalent; the titles differ. **Provenance note:** the walk golden is a recorded regression vector of the web's own closed-form identities, not donor truth — there is no `tools/godot-probe/probe_walk.gd`, and it must not be described as baked from Godot. |
| **A16** Smoke extension: both viewports plus a pixel-variance assertion over the NPC region | `tools/smoke.mjs` | `docs/v3/skeleton/tools/smoke.mjs` | none — the smoke asserts state and pixels directly, not via `node:test` | both viewport screenshots `out/smoke-1280x800.png` and `out/smoke-375x667.png`, each over 10,000 bytes; the NPC probe `probe.fig.samples > 0`, `probe.fig.distinct >= 5`, `probe.fig.variance >= 500`; the three deliverable screenshots `out/v3-default.png`, `out/v3-wide.png`, `out/v3-close.png` | implementation present in working tree, uncommitted; skeleton + spec committed | The probe takes a tight 32x48 box over a townsfolk's feet-anchored screen position and compares it against a same-size ground-only box beside it. The figure region must show 6+ distinct colours and high luminance variance where a flat quad would show 2-3 and almost none. **Not re-run by the author of this matrix** — the smoke takes several minutes and is the orchestrator's acceptance run; the handoff records `npm run smoke` passing, with the caveat that its ~277 ms/frame figure is headless software GL, not a Firefox-on-GPU number. The five screenshots above are present in `out/` from that run. |
| **A17** The six planning artifacts themselves (architecture, skeleton tree, test specs, session list, library/reference appendix, requirements matrix) | `docs/v3/ARCHITECTURE.md`, `docs/v3/skeleton/README.md`, `docs/v3/TEST-SPEC.md`, `docs/v3/WORKING-SESSION-LIST.md`, `docs/v3/LIBRARY-REFERENCE.md`, `docs/v3/REQUIREMENTS-MATRIX.md` | `docs/v3/skeleton/` (25 stubs + its README) | none — planning artefacts are not under test | none | spec only | All six exist: `ARCHITECTURE.md` and `TEST-SPEC.md` (committed in `2e96da3`), the skeleton tree (25 stub files plus its README, committed in `2e96da3`), and the three written by this session — `WORKING-SESSION-LIST.md`, `LIBRARY-REFERENCE.md` and `REQUIREMENTS-MATRIX.md`. Each stub names its target path, its owning slice, its responsibility and the frozen signatures, and each test stub throws `not implemented: <case>`. `tsconfig.json` includes only `src/**/*.ts`, so nothing under `docs/` is in the build. |

---

## Removed browser economy surfaces (2026-11-03)

Three browser-side economy surfaces were parallel specifications of the donor's
economy, with no production importer. They were removed so the donor GDScript
is the single economy authority; browser economy will arrive through the donor
gateway rather than as a second implementation.

| Surface | Where it was | Status |
|---|---|---|
| `CisternState` economy (tank load, purge, contamination, alloy) | `src/core/sim.ts` | removed 2026-11-03 — donor GDScript is the economy authority; browser economy arrives via the donor gateway |
| `IntentView` / `checkCisternIntent` | `src/core/game-actions.ts` (deleted) | removed 2026-11-03 — donor GDScript is the economy authority; browser economy arrives via the donor gateway |
| `ShopStock` (stock, cycle purchases, alloy) | `src/core/shop-stock.ts` (deleted) | removed 2026-11-03 — donor GDScript is the economy authority; browser economy arrives via the donor gateway |

The donor's own economy semantics stay documented in
`docs/v3/LIBRARY-REFERENCE.md`, which names the donor files as the authority
and keeps the servant and shop systems donor-only.

---

## Coverage gaps

**Asks with no dedicated test:**

- **A5 (desert biome)** — the classification case asserts only that `desert` is
  a legal kind. Nothing asserts that a desert band exists or where it lies.
- **A6 (ocean biome)** — closed by the 2026-10-31 ruling. The band's width is
  pinned by `tests/world.test.mjs` (`web extension: the ocean band is exactly
  two cells wide on every side`), which fails at a three-cell band; the
  mechanism is settled as margin arithmetic and the contract prose was
  amended to match.
- **A10 (deterministic water animation)** — provable only by the spec-only
  unit case; the smoke does not touch the water plane's pose.
- **A12 (inspector terrain and figure rows)** — the smoke asserts the tile and
  the copy text, not the two new rows.

**Suite coverage (2026-11-03):** A1, A2, A3, A7, A8, A9, A11, A12 have landed suites (tests/{figures,voxel,camera,inspector}.test.mjs). The only suite still unwritten is tests/worldrender.test.mjs (the A7/A12 world-render view); A10 water animation is unasserted. The suite is 93 cases, all green (124 before the 2026-11-03 economy excision).

**Canonical test names that differ from the landed titles** (the assertions
are equivalent; the strings are not):

| Module | Canonical | Landed |
|---|---|---|
| noise | `the port is deterministic across repeated calls` | folded into the bit-exact case as a per-row `Object.is` check |
| noise | `octave count changes the value` | absent |
| noise | `seed changes the value` | absent |
| world | `stepsAtCell matches the donor EXACTLY at every golden point` | `stepsAt matches the donor EXACTLY at every golden point` |
| world | `the playable grid is 4.00x the authored town` | absent |
| walk | all five canonical names | five differently-worded titles (see A15) |

**Where the code and the operator asks disagree** — collected for the
operator:

1. **Ocean band mechanism (A6) — ruled 2026-10-31.** The contract described
   the ocean as cells whose `edge_norm` is at the footprint edge sinking below
   the water table, while `src/core/world.ts` implements margin arithmetic.
   The ruling keeps the margin arithmetic (`gx <= -MARGIN_X + 1` /
   `gx >= WORLD_W + MARGIN_X - 2` / `gy <= -MARGIN_Z + 1` /
   `gy >= WORLD_H + MARGIN_Z - 2`, two cells per side on every side) and
   amends the contract prose to match. The `edge_norm` sentence is recorded as
   naming the band's purpose, not its predicate. The width is pinned by a unit
   test; no golden covers it.
2. **"13 pre-existing golden tests" (A13).** The tree carries 18 at HEAD;
   13 is the v1 count.
3. **Figure height — resolved 2026-11-03.** The contract's prose said a figure
   is "~0.75 tall"; the frozen part sizes (legs 0.30 + torso 0.32 + head 0.22)
   put it at 0.84, which is what the build renders. The contract's prose now
   says 0.84.
4. **Two camera defaults (A11) — ruled 2026-10-31.** Collapsed to one set:
   pitch `0.72`, distance `60`, exported from `src/render/camera.ts` and used
   by both the class fields and `Game`.
5. **Shading constants (A9).** The web build's per-face law is the Rust HD
   lane's, not the donor `slab_assembler.gd` table.
6. **The walk golden (A15).** Baked from the web's own identities, not from a
   donor probe; there is no `probe_walk.gd`.
