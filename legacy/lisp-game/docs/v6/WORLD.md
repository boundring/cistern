# Cistern v6 — WORLD & INTERFACE (DESIGN)

> STATUS: DESIGN 2026-09-08 — no code. Four components W1–W4 mapped to the
> owner's requirements: (1) reflow to the window, (2) larger varied maps,
> (3) the overworld with mine navigation, (4) the Dwarf-Fortress take.
>
> Sources: owner requirements (verbatim, this file's provenance);
> docs/v4/SURFACE.md C1–C6 (constraints inherited), S2/S3 (palette, glyph
> rule); docs/FAILURE-LEDGER.md L-076 (glyph pin), L-011 (soak perf note),
> L-099 (write protocol); docs/ux/TOP-30-R2.md R2-Q02 (geometry
> single-source); docs/REWARDS-DESIGN.md §5 (theme-as-level-parameter,
> signed off); docs/v5/V5-SPEC.md §1.2 (stream table 0–6), COMBAT §1
> (factions).

## 0. Binding constraints (every directive inherits these)

| # | Constraint | Application in this doc |
|---|---|---|
| C1' | **Layout contract (supersedes the 95-col contract).** No permanent render row exceeds the live window body width; the header block stays 3 + ≤1 badge lines; ONE layout object is the single source for header block height, map viewport origin, and click mapping (R2-Q02 generalized: one object, two consumers). W1 §1 specifies the replacement. | §1 |
| C2 | **Copy-table rule.** Every new player-facing string lands in `cistern--copy` with a named key at design time. Briefing prose stays prose. | per-section key lists |
| C3 | **L-076 pin route.** No new glyph outside the pinned/measured ranges (ASCII; geometric U+25A0–25FF; Greek U+0391–03A9); every new glyph passes the gui-probe advance probe. | §1, §3 |
| C4 | **Five SOARS protected.** S1 inspector / S2 pressure voice / S3 popups-at-act / S4 purge ledger / S5 non-modal ceremony. Cross-level ceremonies route through the announcement surface (§4.4) — never a modal, on any level. | per-section PROTECT |
| C5 | **Least-active decisions.** Each component states the chosen minimal design and the rejected heavier alternative in one line. | per-section |
| C6 | **Batch-testable except GUI-only.** Layout math, gen tables, state shapes: batch with synthetic sizes. Anything needing a real frame follows the L-076 probe pattern (registered, SKIPPED in batch). | §1.5, §6 |

---

## W1. REFLOW LAYOUT — one layout object, derived from the live window

**Owner requirement (1):** the interface could be LARGER, to suit a larger
screen — reflow the view to suit the window being used.

### W1.1 The layout object (the R2-Q02 lesson, generalized)

R2-Q02's lesson was one constant (header block height) shared by the renderer
and `cistern-view--cell-at`. v6 generalizes: every derived geometry number is
computed ONCE into a layout object, consumed by BOTH consumers.

```
cistern-view--layout (body-cols body-lines map-w map-h) → LAY, a plist:
  :map-origin   (LINE . COL) where the map's (0 0) renders — after header
  :map-cols     map columns visible this refresh  = min(map-w, fits)
  :map-lines    map rows visible                  = min(map-h, fits)
  :cam          (X . Y) map cell at viewport top-left (clamped camera, W1.2)
  :header-lines 3 + (badge-row-p ? 1 : 0)          — R2-Q02 count, unchanged
  :legend-rows  wrapped legend line count (R2-Q01 rule, width from window)
  :help-row     t if the 2-row help fits at body-cols, else row A only
```

The function is PURE — window measurements are the caller's arguments
(`(window-body-width)` / `(window-body-height)` in the driver, synthetic
integers in batch tests). No layout state is stored anywhere: every refresh
recomputes from the live window, so resize and click remap are the SAME
computation, never a stored-pixel drift.

**Bounds:** the header block and help rows always render in full (they are
the contract, C1'); the MAP viewport absorbs whatever the window offers —
min 34×16 (the classic sector fits at today's minimum window), max the
window body itself. A window too small for 34×16 keeps full map rows and
lets the header elide (W1.4); the map is never clipped below full sector.

**Least-active:** one pure function + zero stored geometry. Rejected: a
layout-state cache with invalidation hooks (a second source of truth —
exactly the drift R2-Q02 fixed).

### W1.2 Viewport camera (why a layout needs a camera at all)

With v5's fixed 34×16 sector the map always fits. W2's larger maps may not;
the viewport then shows a camera window. The camera is DERIVED, not stored:

```
cam = clamp(cursor − viewport/2, 0, map-dim − viewport)
```

cursor-centered, clamped to the map bounds, recomputed at every render —
zero new state, deterministic from (cursor, window). The cursor is always
on screen by construction; moving the cursor pans the view. Edge-hysteresis
cameras and scroll offsets are rejected (state, tests, and drift for nothing
the cursor-centered rule doesn't already give).

### W1.3 Click geometry and resize (single source, both consumers)

- `cistern-view--cell-at` becomes `(st lay line col)` — it reads origin,
  camera and column offsets ONLY from LAY, then adds the click's line/col.
  `cistern-click` computes LAY the same way the renderer just did. One
  producer shape, two consumers: the R2-Q02 invariant, kept by a batch
  assertion that both call sites derive LAY from the same function (A-WO1.2).
- Resize mid-game: the driver registers `window-size-change-functions`;
  the callback re-derives LAY and re-renders. Nothing else survives a
  resize — because nothing was stored, nothing can go stale. Clicks after a
  resize remap automatically (same LAY).
- Cell-width changes (font/theme pin, L-076): the existing theme-refresh
  hook re-runs `cistern--pin-glyph-fontset`; the pin is keyed by cell width
  (`cistern--pin-font-cache`), so a resize that changes the cell width
  re-measures exactly as a theme change does today. No new machinery.

### W1.4 Header strip reflow — segments elide by priority, never overflow

The 95-col contract assumed a fixed width; the layout contract makes the
strip adaptive. The header's segments become an ORDERED list — most
important first — and the strip builder walks it, keeping segments that fit
the live `body-cols` and eliding the rest, deepest-priority first:

| order | segment | today's row | elide rule |
|---|---|---|---|
| 1 | tick · clock · level name | row 1 | never (identity) |
| 2 | goals count · pressure verdict | rows 1–2 | shortens before vanishing |
| 3 | armed / auto-run badge | reserved row | coexists as today (R2-Q02) |
| 4 | help verbs (2 rows) | rows 3–4 | row A only, then `[?]` alone |
| 5 | legend | post-map row | wraps (R2-Q01), then `[L]` pointer |

Permanent-row count is FIXED (3 + ≤1 badge + ≤2 help + ≤2 legend rows) —
elision changes segment CONTENT, never the block height, so
`:header-lines` stays truthful (L-014) and geometry never shifts under a
badge or a narrow window. The pressure line's words are S2-protected copy:
elision may drop the idle line in a too-narrow window but never rewrites it.

### W1.5 Test strategy — batch synthetic sizes + GUI probes

- **Batch (pure LAY):** `cistern-test-layout` drives
  `cistern-view--layout` with synthetic `(body-cols body-lines map-w map-h)`
  tuples — wide (map fits), narrow (34×16 minimum), tiny (header elides),
  larger-than-map (no camera shift), larger-than-window (camera clamps to
  bounds). Every tuple asserts: header-lines truthful, map viewport bounds,
  camera clamp.
- **Batch (consumer agreement):** render LAY for a synthetic size, then
  `cell-at` every map cell's rendered (line col) through the SAME LAY —
  round-trip must return the original (x y). This is the R2-Q02 guard,
  now exhaustive instead of constant-equality.
- **GUI probe (L-076 pattern):** registered test, SKIPPED in batch —
  opens a real frame, resizes it through three sizes, asserts the buffer
  re-rendered at each size and a synthetic click at a rendered glyph maps
  back to the right cell.

---

## W2. LARGER, VARIED MAPS — size classes and themes as generation parameters

**Owner requirement (2):** new games should permit LARGER and more varied maps.

### W2.1 Size classes

`cistern--new-game` gains a size class; the domain is already size-generic
(`cistern-st-w`/`-h` fields, `in-bounds-p`/`idx` read them — only the
`cistern-w`/`cistern-h` constants and procgen tables assume 34×16).

| class | w×h | cells | vs standard | why this bound |
|---|---|---|---|---|
| standard | 34×16 | 544 | 1× | today's tuned "one breach from condemnation" envelope; default |
| large | 51×24 | 1224 | 2.25× | roomier plumbing puzzles, same pop cap; tick cost inaudible |
| vast | 68×32 | 2176 | 4× | the ceiling (see performance envelope) |

**Performance envelope (L-011 soak note):** the soak ran 600 ticks in 48s
at 544 cells — cost dominated by per-tick O(w×h) full-map scans
(`cistern--kind-cells`, phase-hazards' hazard walk, severed/free-toilet
scans). Vast is 4× the cells ⇒ ~4× per-tick cost; at the pinned 5 tps
auto-run that stays well inside interactive. **We ship NO indexes.** The
upgrade path is recorded, not built: if a class beyond vast ever lands,
first index the recurring scans (hazard-position list, toilet/tank position
caches maintained at place/demolish), because those are the only scans that
grow with the map — entity scans already grow with population, not area.

**Least-active:** a size argument threaded into the existing procgen.
Rejected: per-class procgen engines, or position indexes built now for a
size class nobody plays.

### W2.2 Sector themes — the REWARDS-DESIGN §5 parameter, shipped

The signed-off precedent: a theme is a LEVEL PARAMETER — deterministic,
table-driven; the seed varies layout *within* the theme. v6 turns that
one-line promise into the theme table:

| theme | procgen knobs (table row, data not code) | play shape |
|---|---|---|
| standard | today's tables verbatim | the tuned default |
| wet | +2 flood seeds, spread-pct ×2 for this sector, +1 cache | flooding is the puzzle |
| collapsed | rubble-cluster count ×3, narrower corridors (more wall density) | digging is the puzzle |
| gallery | fewer walls, +2 caches, +1 manifold anchor | flow/pipeline elegance |

One `cistern--sector-themes` defconst: rows of (name . plist) with knob
values read by `cistern--gen-map`. A theme never adds tile kinds, faces, or
special-case code — it only shifts the quantities procgen already draws
(the S3.2 kinds supply the vocabulary). Wet's spread multiplier is the one
new domain constant, scoped per-sector by the level's theme row.

**Signature:** `(cistern-new-game &optional seed size theme)` — all three
default (nil → seed 1, standard, standard), so today's invocations are
byte-identical. seed → (size, theme) are inputs, never derived from the
seed: the owner chooses the shape of the puzzle, the seed lays it out
(same split as REWARDS §5). Tests: same seed + different theme ⇒ different
map hash, same bounds; same theme + different seed ⇒ different map, same
knob inventory (e.g. wet always seeds the same flood count).

---

## W3. THE OVERWORLD — one Structure, many levels

**Owner requirement (3):** an overworld with navigation into and out of
mines. The existing sectors become MINE levels; a second map layer — the
Structure's surface gallery — sits above them.

### W3.1 The overworld map

Own generation parameters (fixed size 40×12 — a wide gallery strip, one
screen at the standard window; overworld gen draws the sim LCG at new-game
time, after the mine level, order pinned in W5). Own tile vocabulary, added
to the tile table under the S3.1 rule (glyphs: ASCII or the measured
U+25A0–25FF / U+0391–03A9 ranges; each passes the gui-probe):

| kind | glyph | passable | loop role |
|---|---|---|---|
| gantry | `=` U+003D | yes | overworld walkway (wall-equivalent above, floor-equivalent below) |
| elevator | `▼` U+25BC | yes | the descend point; paired with the mine's ascend marker `▲` U+25B2 |
| gate | `Π` U+03A0 | yes | migrant arrivals (today's "MIGRANT WAITS AT THE GATE" gains a home) |
| settlement | `Λ` U+039B | yes | the guild office and the story acts' stage |
| nest | `Ψ` U+03A8 | no | the warband's lair — raid staging |

Legend/inspector lines and copy keys follow the S3.2 sweep pattern
(`legend-<kind>`, `desc-<kind>`, `insp-<kind>`); faces from S2 roles
(gantry/gate/settlement recessive-standard, elevator standard-emphasis,
nest alert). The mine level's elevator-return tile reuses `▲`.

**Least-active:** five tile-table rows + one gen function. Rejected: a
separate overworld renderer or a third map kind — the view projects tiles,
it does not care which level they came from.

### W3.2 Navigation verbs and the level record

**Verbs:** `>` descends when the cursor stands on an overworld `elevator`;
`<` ascends when the cursor stands on a mine's `▲`. Both route through the
adapter chain like every verb; refusal copy via the existing refuse path
(`nav-no-elevator`, `nav-no-shaft` keys). Clicking an elevator arms the
descend like any tile verb (the `.` repeat arm carries it, S5 precedent).

**State shape — one cistern-st, levels inside it:**

```
cistern-st gains:  :levels   alist  ((overworld L1) (mine-1 L2) …)
                   :cur-level  the key of the level on screen
cistern--level:    id, w, h, map, workers, hostiles, toilets, tanks,
                   hazard, event-tiles, contam, particles, cursor
st stays global:   seed, tick, alloy, log, story, personas, relationships,
                   rewards-events, goals (the starter card is the MINE's)
```

The level record is exactly the per-level subset the sim already threads;
`cistern--do-tick` and every query function take an explicit level once the
callers pass `(cistern-st-cur st)`. Personas stay global (they are bound to
worker ids, and workers are per-level — a persona's thoughts travel with
its worker's level; the trigger table already reads positions through the
worker, so no change). The log is global and level-tagged: entries gain a
level name in the browser prefix, and `log-jump-to-source` switches
`:cur-level` when the source cell lives elsewhere — announcements with
jump-to-location, cross-level (§4).

**What crosses levels:** by default only the cursor (the player's
attention). Workers, fixtures, contamination, hostiles are PER-LEVEL —
an unattended mine does not empty itself because you looked away. Actors
cross only as authored events: a raid warband marches overworld →
descends via the elevator nearest the nest (authored path, W3.3); story
acts summon the player to the settlement (§4.4 ceremony).

### W3.3 What the sim does while you are on another level

**AMBIENT-LITE, chosen over both full-sim and pause:**

- **Runs off-level:** the three tile-level rolls — hazard spread/decay,
  flood growth, contamination accrual. The Structure does not care where
  you are looking (S2 voice).
- **Pauses off-level:** worker movement, toilet use, migration, raids,
  story act clocks, social/comedy evals. A worker cannot die where you
  cannot see — the fairness rule; no off-screen deaths, no invisible
  XP. Events that DID run log normally with the level tag.
- **Cost:** one level's full tick + one ambient pass over the other
  levels' hazard lists (a list walk, not a map scan — hazards are already
  enumerated). Bounded by W2's vast ceiling.

**Faction homes (coordinates with COMBAT §1):** the warband spawns at the
overworld `nest` and stages raids from it — a raid opens with warband
marching overworld to the nearest elevator, descending, then the existing
raid lifecycle runs in the mine, unchanged. The guild fixer is based at the
`settlement`; `cistern--maybe-guild` spawns him walking from the
settlement into the active mine. `cistern--edge-spawn-cell` gains a
level-aware variant (overworld spawns anchor to nest/gate tiles; mine
spawns keep edge behavior).

**S5 cross-level ceremonies:** popups-at-act and celebration overlays are
non-modal today (S5 soar); they render on the level where they fired. An
off-level fire logs with the level tag and the log browser's jump
switches you there when you choose — ceremony by announcement, never by
modal, on any level (C4).

**Least-active:** ambient = the three existing hazard-phase rolls applied
per level. Rejected: full off-level sim (unseen deaths + every stream's
draw order depends on level visit order for entities, not just tiles).

---

## W4. THE DWARF FORTRESS RIP-OFF LIST — taken, and where we differ

**Owner requirement (4):** ripping off DF for most of it is fine, but we'd
prefer a NICER interface. Each taken feature maps to an emacs-buffer idiom;
the "different" column is the nicer-interface claim, not a feature list.

| DF feature | We take it as | Emacs-buffer idiom | We differ |
|---|---|---|---|
| Multi-level forts | W3 levels | one buffer, `>`/`<` swaps the projected level; log jump switches levels | no level-switch screen: the swap is one re-render of the same buffer, cursor remembered per level |
| Z-levels / vertical traversal | elevators as the shafts (W3.1) | tile-table kinds + nav verbs, not a 3D renderer | we never render stacked levels side-by-side — DF's cutaway view is the one DF idea we decline; one level, rendered well |
| Announcements | the log ring, level-tagged (W3.2) | `cistern-log-mode` buffer — isearch, severity faces, tick stamps (S1) | jump-to-source is a mouse click or RET on any line, and it works cross-level; DF's announcement screen is a modal queue — ours is a buffer you keep open |
| Jump-to-location | log-jump-to-source (shipped) | recenter + cursor move through the adapter | announces nothing twice: the log is uncapped history, not DF's dismiss-on-read |
| Unit list | `u` unit browser (new, S1.2 pattern) | second special-mode buffer, one row per worker/enemy: glyph, name, mood, hp, location | rows are table-driven from the same domain queries the inspector uses; sorting is emacs sort-columns, not DF's hardcoded screens |
| Look mode / inspector | already ours (S1 inspector) | cursor context pane, always visible | DF buries look behind `k`; ours is the cursor's constant shadow — no mode to enter, S1 soar |

**The nicer-interface summary (what we do instead of DF's UI):** the S2
derived palette (contrast math against the user's real theme, vs DF's
fixed 16 colors); the log browser as a first-class emacs buffer; the
persistent inspector; the reflow layout (W1) — DF is a fixed-tile bitmap,
we are a projection over a live window; the coach/emacs-binding layer
(S4); the copy table's deadpan Bureaucracy voice (Q11) vs DF's generated
moodlets.

**Least-active:** the unit browser reuses the log-browser's buffer pattern
verbatim (S1.2/S1.3), only the row builder differs. Rejected: tabulated-list
mode (the S1 ruling — prose rows and text properties win, columns buy
nothing).

---

## W5. DETERMINISM & INTEGRATION

### W5.1 Generation order (pinned)

`cistern--new-game seed size theme` generates, in order: (1) the mine
level — the existing `cistern--gen-map` path with the size class and theme
knobs; (2) the overworld — one new gen pass on the same sim LCG. Same
(seed, size, theme) ⇒ same two maps, same everything. No new stream id:
generation is a new-game-time draw on the sim LCG exactly like today's
gen (stream table 0–6 unchanged, V5-SPEC §1.2).

### W5.2 Tick order (pinned)

The existing eval chain (V5-SPEC §1.1) runs against the CURRENT level,
unchanged. Appended after it, one slot: `cistern--ambient-tick` — the
hazard-phase rolls per off-level, in level-id order (mine-1 before any
later mines; the overworld has no hazards and is skipped unless events
placed some). Ambient draws consume the sim LCG — deterministic given the
action sequence, and the action sequence now includes level switches.
Byte-identical games remain possible: a run that never leaves the mine
never draws ambient rolls (the overworld's hazard list is empty and its
ambient pass is a no-op).

### W5.3 Integration touchpoints (one sweep each)

- `cistern-st` + `cistern--level` struct (W3.2); every query function's
  `st` argument becomes an explicit level via `(cistern-st-cur st)` at the
  call boundary — the D6 query contract is unchanged for the view.
- Driver: `>`/`<` commands, resize hook (W1.3), unit browser (W4).
- View: LAY object (W1), level-name segment in header row 1, level tag in
  log lines and browser prefix.
- Copy table (C2): `nav-no-elevator`, `nav-no-shaft`, `unit-browser-header`,
  `legend-gantry/elevator/gate/settlement/nest`, `desc-*`/`insp-*` for the
  five kinds, `log-level-fmt`. All in the Q11 Blame! register.

---

## W6. ACCEPTANCE CRITERIA (fail-first) & BUILD ORDER

All batch unless marked GUI (C6). Namespaced WO1–WO6.

- **WO1.1** FAIL if `cistern-view--layout` at synthetic (120, 40) with a
  34×16 map does not show the whole sector with header-lines 3 (badge-row
  variant: 4), and at (80, 24) does not clamp the camera with the cursor
  cell inside the viewport.
- **WO1.2** FAIL if, for every cell of a rendered map at three synthetic
  sizes, `cell-at` of the cell's rendered position does not round-trip to
  the original (x y) through the SAME LAY object.
- **WO1.3** FAIL if any permanent row, rendered at a synthetic narrow
  width, exceeds that width (header elision covered; S2 pressure words
  asserted byte-identical when present).
- **WO1.4** GUI probe (L-076 pattern): FAIL on a real frame if resizing
  through three window sizes does not re-render each time, or a click at a
  rendered glyph maps to the wrong cell after resize.
- **WO2.1** FAIL if `(cistern--new-game 1 'vast)` bounds are not 68×32, or
  if a 600-tick vast soak exceeds 4× the standard soak's wall time.
- **WO2.2** FAIL if same-seed/different-theme map hashes collide, or if
  the wet theme's flood-seed count varies across seeds.
- **WO3.1** FAIL if `>` on the overworld elevator does not switch
  `:cur-level`, preserve both levels' map vectors, workers and hazard
  counts through a descend → tick → ascend round trip, and restore the
  overworld cursor at the elevator.
- **WO3.2** FAIL if an off-level hazard event does not log level-tagged,
  or if any worker moved, used a toilet, or died while its level was
  off-screen (ambient-lite = tile rolls only).
- **WO3.3** FAIL if a staged raid does not march nest → elevator → mine
  and run the existing raid lifecycle unchanged in the mine.
- **WO4.1** FAIL if the unit browser buffer does not open with one row per
  worker/enemy, or if `q` leaves the game non-modal (S5: the game kept
  running — verify a tick fired while the browser was open).
- **WO5.1** FAIL if two games with identical (seed, size, theme) and
  identical command sequences diverge in twin-soak hashes — including
  runs that interleave level switches (ambient draws are part of the
  trajectory), and runs that never switch (byte-identical to today's).

**Build order:** W1 → W2 → W5.1/5.2 → W3 → W4. W1 first because every
later surface renders through LAY; W3 last because it spends everything
W1/W2/W5 built. Each directive lands red-first per R10; sizes: W1 M,
W2 S (tables) + M (signature), W3 L (levels are the one structural
change), W4 S + M (unit browser), W5 S.
