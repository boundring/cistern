# CISTERN v6 — CONSOLIDATED SPEC (world × ecology × controls × logs)

Status: SPEC v1, 2026-09-08. Consolidates docs/v6/WORLD.md, docs/v6/ECOLOGY.md,
docs/v6/CONTROLS.md, docs/v6/LOGS.md into one implementable, wave-ordered build
plan. No code in this doc; every directive lands red-first per R10.

Carried constraints, binding on every directive below (PROTECT block):
- **Five soars**: S1 inspector standard · S2 pressure voice · S3 popups-at-act
  · S4 purge economy · S5 non-modal ceremony.
- **C1' layout contract (SUPERSEDES the 95-col contract)**: no permanent render
  row exceeds the LIVE window body width; ONE layout object is the single
  source for header block height, map viewport origin, and click mapping; the
  geometry probe (WO1.2 round-trip) is the standing guard. 95 cols survives
  only as the template-authoring ceiling (≤ 60 raw chars) and the reference
  width legacy copy must render un-clipped at.
- **Copy-table rule** (Q11): every new player-facing string lands in
  `cistern--copy` under a named key at design time — the `(ecology . …)`,
  `(world . …)`, `(summary . …)`/`(logs . …)`, and keys/automation subsections.
  No literals in view/game/input. Loader gains a duplicate-key error (R-3).
- **L-076 pin route**: every new glyph passes the gui probe (`font-at` advance
  == cell width), batch-skipped: the five overworld tiles `= ▼ Π Λ Ψ` (+ the
  mine's `▲` return pairing) and the ecology animals `k d`. ASCII `[A]/[S]`
  log tags are in-range, no probe risk.
- **Deterministic-envelope guards**: bladder window(w) ≥ 22 byte-identical
  (P4 verbatim, extended: NO ECOLOGY EFFECT WRITES A WORKER NUMBER EITHER);
  stream table 0–6 unchanged, 7+ free; stream 4 tail-pinned for ecology;
  ambient-tick draws are sim-LCG trajectory; automation/summarizer/layout/key
  tables consume ZERO draws; overworld gen draws the sim LCG at new-game,
  mine-then-overworld order pinned (W5.1).
- **Rewards-eval sole drainer — SIX non-draining readers** (extends V5's
  five): story, dialogue, combat (hostiles phase), social, comedy, and the
  NEW automation-eval. Ecology's `feral-*` pushes and automation's
  fired/refused pushes drain nothing. Asserted per new eval (EC9, AU1, DT1).
- **Comedy-violence contrast** unchanged: calm-40 after violent anchors;
  predation is NOT a violent anchor; the dead are never punchlines (CY12 scan
  covers the new subsections).
- **The servant invariant**: an automation can never do anything the player
  could not do manually — six-action closed vocabulary on the existing
  `cistern--cmd-*` use cases, same costs, same refusals, same log.
- **The no-unseen-deaths fairness rule** (W3.3): off-level, the sim pauses
  workers, toilets, migration, raids, hostiles, and story/social/comedy
  clocks; only the three tile-level rolls run. No off-screen deaths, no
  invisible XP.

---

## 1. INTEGRATION OVERVIEW

### 1.1 Per-tick pipeline (one call site each, pinned)

```
cistern--do-tick  (runs against the CURRENT level; callers pass (st-cur st))
  │
  ├─ sim phases, PINNED ORDER (V5 §1.1, unchanged):
  │    creators → hostiles → hazards → migration → check
  │
  │    hostiles phase = combat's whole tick slot, with ONE ecology TAIL:
  │      · existing: P3 span check → S1–S6 spawn draws → per-hostile
  │        behavior, list order (NEW feral cond branch for cats/dogs; rats
  │        gain the priority-0 flight check, NO draw) → auto-defense
  │        (guild+feral filtered) → routed-close check
  │      · TAIL, only while `cistern-ecology-enabled`:
  │          1. cat arrival: tick % feral-every = 0 ∧ feral < feral-max
  │             → one d20 vs clamp(20 − P, 6, 21); on success 12-d6 dossier
  │             + edge spawn          (stream-4 draws, in THIS order)
  │          2. dog schedule: tick % dog-every = 0 → 12-d6 dossier + edge
  │             spawn, NO arrival draw
  │        (migration phase gains only the §3.4 cadence read inside its
  │         existing every-N check — no new phase anywhere)
  │
  ├─ cistern--automation-eval st   ; NEW ONE SLOT (V6-15), pinned AFTER sim
  │     phases, BEFORE story-eval — reasons over the same post-sim state the
  │     narrative evals read; its `automation-fired` events are visible to
  │     story/social/comedy in the SAME tick. Meta-eval runs at its HEAD on
  │     the pinned 10-tick cadence (V6-16). ≤ 1 action/tick, sector-wide.
  │     Zero stream draws. Reads pending events WITHOUT draining.
  │
  ├─ cistern--story-eval st        ; EXISTING
  ├─ cistern--social-eval st       ; EXISTING
  ├─ cistern--comedy-eval st       ; EXISTING
  ├─ cistern--dialogue-eval st     ; EXISTING
  ├─ cistern--rewards-eval st nil  ; EXISTING — SOLE EVENT DRAINER (L-027)
  │
  └─ cistern--ambient-tick st      ; NEW ONE SLOT (V6-07), appended after the
        ENTIRE eval chain (WORLD W5.2): the three tile-level rolls — hazard
        spread/decay, flood growth, contamination accrual — per OFF-level,
        in level-id order (mine-1 before any later mines; the overworld has
        no hazards and is a no-op unless events placed some). Consumes the
        sim LCG → part of the trajectory. Pushes its events for the NEXT
        tick's readers.
```

### 1.2 Ordering rules (pinned)

1. **Ecology is not a phase.** It is the hostiles phase's TAIL segment, gated
   by `cistern-ecology-enabled` (default nil, the `cistern-combat-enabled`
   precedent). Ecology-off runs are byte-identical to the v5 sim; with it on,
   the v5 fixture stream-4 sequences (S1–S6) hold byte-identical because
   ecology draws append at the tail.
2. **Automation-eval sits between the sim and the narrative.** After all sim
   phases (no mid-sim mutation, no double-advance), before story-eval (an
   automated purge gets its comedy beat the same tick, like a manual one).
   It never drains pending events; rewards-eval stays the sole drainer.
3. **Ambient-tick is last.** After rewards-eval: off-level ambient events
   land in the pending list for the NEXT tick's readers, and the sole
   drainer has already run this tick — nothing ambient pushes can be drained
   same-tick. Automation (earlier in the chain) therefore never sees
   same-tick off-level events: the servant acts on the level in view (R-4).
4. **LOGS has no slot — it is the append path.** Channel tagging happens at
   the log helpers (`cistern--log` / `cistern--log-sev` push `ambient`; new
   `cistern--log-story` pushes `story`), i.e. at each emitting site in every
   phase and eval above — no ordering constraint with any slot. Write
   budget: total ring appends per tick == v5's count (LG3); summary appends
   zero (derived, R-2 of LOGS).
5. **Level tagging is read-time, composing with channels for free** (R-6):
   the browser prefix and jump-to-source read the entry's LEVEL slot at
   render; the write path is untouched by it. `log-jump-to-source` switches
   `:cur-level` when the source cell lives elsewhere.
6. **The summary is computed, never stored**: `cistern--log-summarize` runs
   at browser build (filter 3), the banner row's default render, and is
   windowed by boundaries that are pure functions of the tick and the
   recorded act-open ticks — cadence windows are multiples of
   `cistern-summary-every` 60, cut by act boundaries. No window state.
7. **Byte-identity envelope**: a run that never leaves the mine draws zero
   ambient rolls (empty overworld hazard list, no-op pass), and with
   ecology off consumes zero tail draws — the full v5 trajectory is a legal
   v6 run (WO5.1, EC8).

---

## 2. CONFLICT RULINGS

One ruling each, least-active-decisions. These are binding where two input
docs would otherwise pull apart.

- **R-1 Contract supersession (C1 vs C1').** C1' supersedes the 95-col
  contract — expected and pinned. The live window body width is the binding
  bound; 95 cols demotes to the template-authoring ceiling and the reference
  width at which all legacy copy must render un-clipped. LOGS §0 and
  CONTROLS prose citing "95-col" re-read under C1' (the `[A]/[S]` tags' "fits
  95" arithmetic becomes "fits the live width"; the L-076 discipline it
  cited carries over unchanged).
- **R-2 Tile table.** WORLD's five overworld kinds (`gantry =`, `elevator
  ▼`, `gate Π`, `settlement Λ`, `nest Ψ`, with the mine's `▲` as the
  elevator pairing) are the ONLY v6 tile-table additions. ECOLOGY adds zero
  tiles: cats and dogs are ENTITIES whose glyphs `k`/`d` join the entity
  roster beside `g G r c e s`, distinct from the tile table, the particle
  palette, and worker α–θ. No third map kind; the view projects tiles
  regardless of level.
- **R-3 Copy-key collisions.** None found across the four docs — namespaces
  are disjoint (`ecology-*`; `nav-no-elevator/-no-shaft`, `unit-*`,
  `legend-/desc-/insp-<kind>`, `log-level-fmt`; `pressure-elsewhere`,
  `log-header-*`, `log-hint` extension, `summary-*` + `sector-nw/ne/sw/se`;
  `remap-*`, `automation-*`, `meta-*`, `keys-*`, coach lines). Guard, not
  trust: the copy loader gains a duplicate-key load error, landing with
  V6-05 (the first bulk copy sweep) and asserted in every wave's final
  grep sweep.
- **R-4 Ambient-tick vs automation-eval order.** Ambient-tick appends after
  rewards-eval; automation-eval sits before story-eval. Consequence, pinned
  as correct: off-level ambient events are visible to automation and the
  narrative evals one tick late. The servant acts on the level in view;
  off-level events are announced (level-tagged) and next-tick actionable.
  Level switches are part of the action trajectory (WO5.1 twin-soak).
- **R-5 `cistern-ecology-enabled` × level switch.** The ecology TAIL runs on
  the CURRENT level only. Off-level: no arrival draws, no flight, no food
  clock — a level's pressure P = 2·(its live rats) + (its severed lines) is
  frozen while unseen, because the hostiles phase does not run there. The
  equilibrium criteria EC1–EC3 are specified on the mine. Visiting the
  overworld consumes zero stream-4 draws; never-switch runs stay
  byte-identical to the v5 sim (EC8's off case).
- **R-6 Log entry shape vs the level tag.** LOGS R1 pins
  `(LINE SEVERITY TICK CHANNEL)`; WORLD requires level-tagged entries.
  Ruling: the shape gains ONE trailing slot — `(LINE SEVERITY TICK CHANNEL
  LEVEL)` — LEVEL = the emitting level's id, nil in single-level games
  (renders tagless; the v5-shaped 4-list is the nil-LEVEL special case).
  Readers projecting nth 0/1/2 (log-tail, collapse-log, restart-dedup, boot
  line) are unchanged; only the browser prefix and jump read LEVEL.
  Channel enum, routing table, and the write budget (LG3) are untouched.
- **R-7 Streams and ids.** No new stream id and no new rng position field
  anywhere in v6: stream 4 (tail-pinned) for ecology, the sim LCG for
  overworld gen and ambient rolls, zero draws for automation, the
  summarizer, layout, and key tables. Stream 7+ stays free. Entity ids
  stay the v5 protocol — feral entities are `cistern--enemy` entries with
  stable `g<N>`-style ids; the persona census order extends to `feral` at
  the attach point only (ECOLOGY §6.4 defers personas themselves).
- **R-8 Key space.** WORLD's `>`/`<` join the motion group as
  `nav-descend`/`nav-ascend` in the remap table (V6-14's data), lowercase =
  local navigation under K1 (they do not change the sector). No collision
  with CONTROLS §2.2: `C-c` power bindings, tick keys, and the moved family
  keys are all untouched by two unbound punctuation keys. Nav keys ride the
  keymap overhaul's data table from day one, so remap covers them for free.

---

## 3. DIRECTIVE BUILD ORDER (wave-ordered, R10 discipline)

Waves: **1** the surface everything renders on (layout, sizes, themes) →
**2** the world gets bigger and alive (levels, overworld, ecology) →
**3** the player's hands and eyes (controls, automation, three-channel logs).

### WAVE 1 — layout reflow + map size/themes

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V6-01 | LAY layout object + camera + click geometry (WORLD W1.1–W1.3) | pure `cistern-view--layout (body-cols body-lines map-w map-h)` → plist `:map-origin :map-cols :map-lines :cam :header-lines :legend-rows :help-row`; camera `clamp(cursor − viewport/2, 0, map-dim − viewport)` recomputed every render; `cistern-view--cell-at` becomes `(st lay line col)` reading ONLY LAY; `window-size-change-functions` callback re-derives and re-renders; ZERO stored geometry | WO1.1 (whole-sector at (120,40) + camera clamp at (80,24)); WO1.2 (cell round-trip through the SAME LAY at three synthetic sizes); WO1.4 (GUI probe: resize ×3, click remap) | M | C1' single source, two consumers; no layout-state cache (R2-Q02); theme-refresh cell-width pin reused, no new machinery |
| V6-02 | Header strip reflow — priority elision (W1.4) | header segments become an ORDERED list (tick/clock/level name → goals/pressure → badge → help → legend); strip builder keeps what fits, elides deepest-priority first; permanent-row count FIXED (3 + ≤1 badge + ≤2 help + ≤2 legend) so `:header-lines` stays truthful; pressure words S2-protected: dropped, never rewritten | WO1.3 (no permanent row exceeds a narrow synthetic width; pressure lines byte-identical when present) | S | S2 voice; L-014 (`:header-lines` truthful); C1' — elision changes content, never block height |
| V6-03 | Size classes + sector themes + new-game signature (W2) | `cistern--new-game (&optional seed size theme)`, defaults nil → seed 1/standard/standard (today's invocations byte-identical); classes standard 34×16 / large 51×24 / vast 68×32; one `cistern--sector-themes` defconst of (name . plist) rows read by `cistern--gen-map`; wet's spread multiplier the one new domain constant, scoped by theme row; NO position indexes | WO2.1 (vast bounds 68×32; 600-tick vast soak ≤ 4× standard wall time); WO2.2 (same seed + different theme ⇒ different hash, same bounds; wet flood-seed count seed-invariant) | M | L-011 perf envelope recorded, upgrade path (scan indexes) NOT built; size/threading only — no per-class procgen engines |

Wave-1 ordering: V6-01 → V6-02 (header elision rides LAY). V6-03 is
parallel-safe against V6-02 once V6-01 lands — vast maps need the camera
to be viewable, but gen itself is view-independent.

### WAVE 2 — overworld + ecology (the world gets bigger and alive)

Cross-wave dep: ALL of wave 2 renders through V6-01/02's LAY; V6-04's
struct is the gate for everything level-shaped below it.

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V6-04 | Level record + st restructure (WORLD W3.2 state shape) | `cistern-st` gains `:levels` alist + `:cur-level`; new `cistern--level` struct (id, w, h, map, workers, hostiles, toilets, tanks, hazard, event-tiles, contam, particles, cursor); every query/sim boundary passes `(cistern-st-cur st)`; st stays global for seed, tick, alloy, log, story, personas, relationships, rewards-events, goals | existing suite green on a single `mine-1` level; struct round trip (levels preserved through switch/switch-back) | L | D6 query contract unchanged for the view; personas global (bound to worker ids) |
| V6-05 | Overworld gen + tile vocabulary (W3.1, W5.1) | five tile-table rows `gantry =` / `elevator ▼` / `gate Π` / `settlement Λ` / `nest Ψ` (+ mine `▲` pairing); one overworld gen pass 40×12 on the sim LCG, AFTER the mine level (order pinned); copy keys `nav-no-elevator`, `nav-no-shaft`, `unit-browser-header`, `legend-/desc-/insp-` ×5, `log-level-fmt`; duplicate-key copy-loader guard lands here (R-3) | WO5.1 gen-order half (same (seed,size,theme) ⇒ same two maps); glyph gui probes | M | S3.1/S3.2 sweep pattern; faces from S2 roles (nest alert, elevator emphasis); C2 named-at-design-time |
| V6-06 | Navigation verbs + cross-level cursor (W3.2) | `>` descends on an overworld `elevator`, `<` ascends on a mine `▲`; both ride the existing adapter chain; refusal copy via the existing refuse path; clicking an elevator arms descend (`.` repeat arm carries it); `log-jump-to-source` switches `:cur-level` when the source is elsewhere | WO3.1 (`>`/`<` round trip: both levels' maps, workers, hazard counts preserved; overworld cursor restored at the elevator) | S | S5 non-modal — level swap is one re-render of the same buffer; cursor remembered per level |
| V6-07 | Ambient-lite tick + level-aware spawns (W3.3, W5.2) | ONE `cistern--ambient-tick` slot appended after rewards-eval: hazard spread/decay + flood + contamination per off-level, level-id order, overworld no-op; workers/toilets/migration/raids/story clocks PAUSED off-level (fairness rule); `cistern--edge-spawn-cell` gains a level-aware variant (overworld anchors nest/gate; mine keeps edge behavior) | WO3.2 (off-level hazard event logs level-tagged; ZERO worker movement/toilet/death off-screen); WO5.1 ambient-draw half | M | no-unseen-deaths fairness rule; ambient draws = trajectory (level switches included); cost = list walk, not map scan |
| V6-08 | Faction homes — warband march, guild settlement (W3.3) | raid opens with the warband spawning at the overworld `nest`, marching to the nearest elevator, descending, then the EXISTING raid lifecycle in the mine unchanged; `cistern--maybe-guild` spawns the fixer walking from the `settlement` into the active mine; actors cross levels only as authored events | WO3.3 (staged raid: nest → elevator → mine, existing lifecycle asserts green) | M | combat pipeline untouched below the spawn point; S5 (off-level ceremony = announcement + log tag) |
| V6-09 | Unit browser (W4) | `u` opens a second special-mode buffer reusing the log-browser pattern verbatim; one row per worker/enemy — glyph, name, mood, hp, location — from the same domain queries the inspector uses; `q` closes, game never blocked | WO4.1 (row-per-entity opens; `q` leaves the game non-modal — a tick fires while open) | S | S1 (rows table-driven from domain queries); S5 non-modal; rejected: tabulated-list |
| V6-10 | Feral entities + predator-prey valve (ECOLOGY §1–2, §5) | faction `feral` on the EXISTING entity struct; vent cat `k` (HP 6) / sector dog `d` (HP 8), stream-4 dossiers, ATK = FLOW mod, DEF = 10 + GRIT mod; shared strike pipeline (dmg-minor matrix); P = 2·(live rats) + severed; cat arrival every `feral-every` 20, d20 vs `clamp(20 − P, 6, 21)`, cap `feral-max` 2; dog every `dog-every` 240, NO arrival draw, never strikes; food clock on the existing `idle` slot (patience 60/40, forage 4); rat flight priority-0 within `feral-scent` 2, NO draw, edge despawn; feral filtered OUT of auto-defense, FOCUS refuses `ecology-refusal` no-draw; hostiles-phase TAIL gated by `cistern-ecology-enabled`; new consts in one `cistern--ecology-const` block; ZERO new state fields | EC1–EC9, EC13 (k/d glyphs) | L | stream 4 tail-pinned (v5 fixture order holds); ecology-off byte-identical; `feral-*` pushes non-draining; cats cull fauna, never write a worker number |
| V6-11 | Self-balancing sweep (ECOLOGY §3) | wealth valve: W = tank load total + 2·banked alloy, `n = clamp(1 + floor(W/15), 1, min(act-cap, pop − 1))`, raid-open log gains `ecology-raid-claim`; guild triage: cadence 20 while severed ≥ 3, restorations 5 while severed ≥ 4 (v5 numbers become FLOORS), edge-logged `ecology-guild-escalate`; comedy gap `60 + 40·T` cap 180, calm-40 unchanged; migrant gate 20 while pop ≤ 3, edge-logged `ecology-gate-valve`/`-normal` | EC10, EC11, EC12 | M | PINNED, not valves: P1 hard valve (contam ≥ 18), `raid-span` 40, `hostiles-max` 8, pop-cap 8, `spread-pct`/`decay-pct`, act windows 120/240, raid DC act scaling 8→5 — valves modulate rates, never caps; no hidden rubber-banding (announced, pure reads) |
| V6-12 | Ecology surfaces — copy + inspector (ECOLOGY §4) | `(ecology . …)` copy subsection, the ten §4 keys ≤ 60 raw chars; animals ride `combat-inspect-fmt` with state words `ON PATROL` / `ON ROUND` / `DEPARTING` (past patience − 10); `feral-arrival`/`feral-depart` events feed the hook machine's closed grammar | EC13 (width), EC14 (copy sweep — grep finds no ecology literal in view/game) | S | S1 (no new query path); S2 (info severity, never the PRESSURE family); comedy-violence contrast (predation not an anchor; CY12 scan covers the new subsection) |

Wave-2 ordering: V6-04 → V6-05 → V6-06 (struct → gen → verbs); V6-07 after
V6-04 (needs per-level hazard lists) and BEFORE V6-08 (spawns anchor to
nest/gate); V6-08 after V6-05 + V6-06 (march needs tiles + switches);
V6-09 after V6-04 (rows are per-level). Ecology V6-10 → V6-11 → V6-12
strictly sequential; V6-10 needs only V6-04 (per-level reads + the
level-aware edge spawn) — it is otherwise independent of V6-05..V6-09 and
may run parallel to them.

### WAVE 3 — controls overhaul + automation + meta + three-channel logs

Cross-wave deps: two independent lanes. Lane A (V6-13..17) needs nothing
from waves 1–2 except that nav verbs enter the remap data table (R-8) and
`(event KIND)` conditions read generically from the pending list (so
`feral-*` events are automatable for free once V6-10 lands). Lane B
(V6-18..21) needs V6-01 for the ELSEWHERE viewport helper
(`cistern-view--in-viewport-p` is inert on a whole-sector render and
activates under any viewport smaller than the map — LOGS §4.2's design).

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V6-13 | Keymap overhaul (CONTROLS §2) | three rules K1/K2/K3; six moved keys: `K`→`k`, cycle→`TAB` (`T` kept as alias), `H`→`R`, `n`→`N`, `C-t`→`C-c C-t`, `C-x z` bound for real; `u` removed (C-g/ESC disarm); four one-shot coach lines through the Q17 slot + first-session banner, copy-table keys | KM1 (`k`/`TAB`/`R`/`N`/`C-c C-t` bound; `K`/`H`/`n`/`C-t`/`u` UNBOUND); KM2 (`C-x z`); KM3 (briefing: case rule, C-s isearch framing, no `%%`); KM4 (coach fires once) | M | emacs pairing layer, SPC/RET tick, coach + hint channels untouched; A8 softened by copy, not machinery (L-010/Q19 intact) |
| V6-14 | Remap system (CONTROLS §3) | `cistern--key-table-default` (the §2.2 map as data, incl. `nav-descend`/`nav-ascend`); pure `cistern--key-table-merge` + `-keymap-from-table` + `-key-collision-p` (R1 live shadow / R2 noop / R3 prefix / R4 reserved); `data/keys.el` + `cistern--keys-example` + `cistern--ensure-keys`; `C-c C-r` completing-read flow writes the file on commit | RM1 (every verb bound exactly once; shared-key merge error); RM2 (all four refusal branches); RM3 (persistence round trip; unknown verb skipped with one log line); RM4 (`nil`/`""` → `must-keep-key`) | M | no second help surface (describe-mode); unknown-verb tolerance so a v7 rename cannot brick loading; driver-owned, never in `cistern-st` |
| V6-15 | Automation engine (CONTROLS §4) | new ST slot `(automation nil)`; rules as plists in `data/rules.el`; condition vocabulary = EXISTING queries only (read-without-drain, story's `cistern--story-condition-p` shape); closed SIX-entry action table → `cistern--cmd-build/demolish/decon/purge/rally/focus`; ONE slot pinned sim-phases → **automation-eval** → story-eval; ≤ 1 action/tick sector-wide; per-rule `:cooldown`; 10-tick refusal hold (`automation-refusal-pause`); `(automation fired/refused …)` pushes; automated build advances NO extra tick (inside the clock, L-010) | AU1 (pipeline: fire-tick list; events visible same tick, drained only by rewards-eval); AU2 (servant delta identity ×6); AU3 (cap + list order); AU4 (one refusal line, 10-tick hold, no retry); AU5 (vocabulary ceiling + no tick/drain/story mutation); AU6 (soak survival); DT1/DT2; SP1–S5 probes | L | servant invariant; zero stream draws (rng positions tick-for-tick vs rules-free run); drainer contract → SIX non-draining readers; S3 (same popup-at-act path), S4 (cmd-purge invoked, not re-implemented) |
| V6-16 | Meta-automation (CONTROLS §5) | meta-rules as a second plist list; `meta-eval-every` 10 ticks at the HEAD of automation-eval; `:tune` carries exactly `:threshold`/`:cooldown`/`:enabled` of exactly one existing rule id; pinned bands (thresholds 50–95 / 1–limit / 1–4, cooldown 0–20) with clamp-once logging (`meta-clamped`); unknown id refused at load (`meta-unknown-rule`); no creation/deletion; two tuners of one param → last in file wins; `:during-raid` hold/run, default hold | MM1 (band clamp + one clamp log); MM2 (unknown id never fires; no add/delete form structurally); MM3 (last-in-file deterministic); MM4 (hold through raid, resume at close) | M | meta ≤ meta (no recursion); story never reads meta; comedy may READ automation-fired events (bank content, not engine) |
| V6-17 | Rules browser (CONTROLS §4.8) | `C-c C-a` read-only temp buffer in the `cistern-log-mode` pattern — one line per rule `ID WHEN THEN fires/refused held?` + copy-table header; keys `e`/`RET`/`g`/`q`; `C-c C-e` opens `data/rules.el`; on close the driver reloads, diffs into ST, posts `RULES RELOADED — N ACTIVE` | batch: reload diff into ST + line render + `e` toggle; S5 probe (a tick fires while open) | S | S5 non-modal; authoring stays in the FILE; copy-table rule |
| V6-18 | Log channels + routing (LOGS §1, §5.1, R-6) | entry shape → `(LINE SEVERITY TICK CHANNEL LEVEL)` at the two push sites; `cistern--log-story` (channel `story`); reclassify the ~15 story call sites per the §1.1 routing table, one greppable commit; ZERO new `cistern-st` fields; LEVEL nil on single-level games | LG1 (every append carries a known channel enum); LG2 (premise/dialogue/comedy/milestone ONLY story; breach/gnaw/relief ONLY ambient); LG3 (300-tick soak append count == v5 baseline); LG4 (ring uncapped) | M | write budget == v5 (R4: no event logged twice; summary-eligible is a property, not a second write); S3/S5 intent paths untouched |
| V6-19 | Summarizer (LOGS §2) | pure `cistern--log-summarize (log st)` → ordered `(TICK SEV TEXT)` entries; windows pure in tick + recorded act-open ticks, cadence `cistern-summary-every` 60; quadrant clustering, FIXED clause order (breach → losses → raid → income → QUIET); `(summary . …)` copy section + `sector-nw/ne/sw/se` | LG5 (unit fixture + 300-tick fixture byte-exact); LG6 (clause order, open-vs-contained breach, quiet fallback, act prefix); LG7 (zero stream/rng consumption tick-for-tick) | M | R2: derived, never stored — zero appends; width probe (templates ≤ 60 raw, rendered ≤ live width) |
| V6-20 | Browser channels (LOGS §3.1) | additive keys `1`/`2`/`3`/`0` on the ONE `*cistern log*` buffer; per-channel `log-header-*` variants + `log-hint` extension; staleness gate becomes cons `(ring-length . channel)`; `3` re-derives the summary on build | LG8 (old ∩ new keymap identical actions; n/p//g/G/RET/q probe green); LG9 (filters isolate; 3 re-derives; 0 = v5 view); LG10 (RET jumps per channel incl. summary anchors; point survives same-channel round trip) | M | L-browser keymap ADDITIVE ONLY; S5 (never gates) |
| V6-21 | Tail tags + banner summary + ELSEWHERE (LOGS §3.2, §4) | tail pick rule extends (errors → ambient by recency → story in leftover slots); `[A] `/`[S] ` 3-col prefixes; banner row default = LATEST summary entry, dim + severity-faced, ceremony overrides; `cistern-view--in-viewport-p` + `pressure-elsewhere` suffix — first Tier-1 standing problem in row-major order outside the viewport, from LIVE state queries (no ring scans) | LG11 (cold: pure-ambient tail AND pressure lines byte-identical to v5); LG12 (ceremony overrides; summary shows when quiet); LG13 (ELSEWHERE inert on 34×16 whole-map render, activates under a forced smaller viewport) | M | S2 (suffix via copy table only, never edited); S3 (one banner row, zero geometry); S5; C1' width on every row |

Wave-3 ordering, lane A: V6-13 → V6-14 (the data table needs the final
verb set). V6-15 → V6-16 → V6-17 (engine → meta → UI; the meta layer runs
inside V6-15's slot). Lane B: V6-18 first (the shape is the backbone);
V6-19 parallel-safe after V6-18; V6-20 needs V6-18 and V6-19 (filter 3 has
content only once the summarizer exists); V6-21 needs V6-18 (tags) and
V6-19 (banner content). Lanes A and B are mutually independent and may run
concurrently.

### 3.1 Wave summary

| Wave | Theme | Directives | Count |
|------|-------|------------|-------|
| 1 | the surface everything renders on — LAY reflow + header elision + size/themes | V6-01..V6-03 | 3 |
| 2 | the world gets bigger and alive — levels + overworld + ecology | V6-04..V6-12 | 9 |
| 3 | the player's hands and eyes — controls + automation + meta + three-channel logs | V6-13..V6-21 | 9 |
| **Total** | | **V6-01..V6-21** | **21** |

---

## 4. ACCEPTANCE + CARRIED INVARIANTS (consolidated)

Per-directive acceptance lives in the §3 tables, cited by the source
namespaces (WO1–WO5 from WORLD §6, EC1–EC14 from ECOLOGY §6, KM/RM/AU/MM/
DT/SP from CONTROLS §7, LG1–LG13 from LOGS §6). Every criterion FAILS
before its directive's change and passes after. The guards below outlive
any one directive; they hold with each layer off OR on.

1. **Bladder-window envelope** — window(w) = (120 − seek_eff(w))/2 −
   use_ticks_eff_max ≥ 22, byte-identical (ECOLOGY §3.6; P4 extended: no
   ecology effect, automation action, or log-layer change writes bladder,
   bladder rate, seek thresholds beyond the existing clamp, use ticks,
   purge rate, costs — or ANY worker number).
2. **Rewards-eval sole drainer — SIX non-draining readers.** story,
   dialogue, combat (hostiles), social, comedy (V5's five) + automation-eval
   (V6-15). Ecology (`feral-*`, V6-10) and automation (fired/refused) PUSH
   to the pending list and drain nothing; meta-rules read through
   automation only. Asserted per new eval: EC9, AU1, DT1 — and a batch
   guard fails on any drain from a non-rewards slot.
3. **Stream isolation, zero new ids** — streams 0–6 unchanged, 7+ free.
   Ecology: stream 4 ONLY, tail-pinned (EC8/EC9). Overworld gen + ambient
   rolls: sim LCG (WO5.1 twin-soak, level switches in the trajectory).
   Automation, summarizer, layout, key tables: zero draws (DT1, LG7).
   Mid-bits slice rule unchanged for any position field (none are added).
4. **L-076 pin route, complete v6 glyph roster** — gui probe, batch-skipped:
   tiles `= ▼ Π Λ Ψ` (+ `▲` pairing), entities `k d`; `[A]/[S]` tags ASCII
   in-range. Every glyph distinct from the tile table, particle palette,
   worker α–θ, and enemy `g G r c e s`.
5. **C1' layout contract** — one LAY object, two consumers; the WO1.2
   round-trip probe is the standing guard, re-run per wave close. Every new
   rendered row (log tags, level names, summary banner, browser lines)
   fits the live body width.
6. **Copy-table rule** — every new key named at design time: §4 ECOLOGY ten,
   WORLD §5.3 list, LOGS §6.1 list, CONTROLS coach/remap/automation/meta
   set. Duplicate-key load error (R-3) + per-wave grep sweeps (EC14, KM3).
7. **The servant invariant** — AU2 delta identity (manual vs automation ×
   six actions) and AU5's structural ceiling; no `eval` of user code in the
   sim path.
8. **The no-unseen-deaths fairness rule** — WO3.2: off-level pauses
   workers, toilets, migration, raids, story clocks; ambient-lite = the
   three tile rolls only, level-id order, level-tagged logging.
9. **Five soars, re-probed per wave close** — S1 (animals ride
   `combat-inspect-fmt`; unit-browser rows from domain queries; inspector
   byte-identical with rules off), S2 (ecology logs info-severity, never
   the PRESSURE family; ELSEWHERE is a copy-table suffix), S3 (same
   popup-at-act path for automated purges; banner ceremony overrides the
   summary default), S4 (`cmd-purge` invoked, not re-implemented; the
   wealth valve READS wealth, never writes), S5 (nothing modal anywhere —
   level swap, browsers, remap are re-renders/temp buffers).
10. **Comedy-violence contrast** — calm-40 unchanged (EC12); predation is
    not a violent anchor; no comedy copy may punchline a worker death; the
    CY12 scan covers the `(ecology)` and `(summary)` subsections.
11. **Pinned, NOT self-balanced** (ECOLOGY §3.6, restated so no future pass
    "improves" them): P1 hard valve (contam ≥ 18), `raid-span` 40,
    `hostiles-max` 8, `cistern-pop-cap` 8, `spread-pct`/`decay-pct`, act
    windows 120/240, comedy calm 40, raid DC act scaling 8→5,
    `feral-scent` 2, the meta bands of CONTROLS §5.3. Ruling: a quantity
    may self-balance only when a wrong value degrades PACING; a quantity
    whose wrong value can make the game UNWINNABLE or break a proof is
    pinned.

### 4.1 First five to build

1. **V6-01** LAY layout object + camera + click geometry — every v6 surface
   renders through it; C1' exists only once it lands.
2. **V6-02** header strip reflow — closes the C1' contract (elision +
   truthful `:header-lines`), unlocking wave-2's level-name segment.
3. **V6-03** size classes + themes + new-game signature — maps get bigger
   before the world splits; W5.1's gen order builds on it.
4. **V6-04** level record + st restructure — the one structural change;
   gates V6-05..V6-10 (everything level-shaped).
5. **V6-05** overworld gen + tile vocabulary — first cross-level content;
   pins the mine-then-overworld LCG order the whole trajectory rests on.

(V6-01 → V6-02 strictly sequential; V6-03 parallel-safe after V6-01;
V6-04 sequential behind wave 1; V6-05 after V6-04. Lanes and interdeps per
the wave-ordering notes in §3.)
