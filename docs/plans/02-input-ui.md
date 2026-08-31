# Phase 3 execution plan — Interface adapters: input (arrows + mouse + 'r') and view (glyphs, celebrations)

Expansion of `docs/ROADMAP.md` Phase 3 against `docs/DESIGN-SPEC.md` §3/§4/§5,
the Phase 3 handoff brief, and `docs/rewards-notes.md` TURN 3. A fresh
worker with this plan, the spec, and the brief needs no re-discovery.

**Assumed at start:** Phases 1–2 landed (`cistern-domain.el` tile table +
procgen + connection pure functions; `cistern-game.el` verbs incl. demolish,
`cistern--do-tick`, `cistern--rewards-eval` placeholder). `cistern.el` is
still legacy-shaped (hjkl bound, `cistern-run-10` possibly already removed by
Phase 2). Planning only — no game code in this plan.

---

## 1. Task breakdown — ordered red/green pairs

Per ROADMAP fail-first order: **commit all four red tests before any green**
(roadmap: "Green: implement 1–4"). Each green turns one already-red test.
Commit messages per spec §5.1: red = `test: R# failing — <name>`, green =
`R#: <what>`. All tests run in `emacs -Q --batch`; adapter/view tests load
their adapter file (which depends only inward); keymap test loads `cistern.el`
headless (define-key/define-derived-mode/defface/propertize all work in
batch — legacy selftest precedent, cistern.el:937-1035).

### Pair 1 — R2: arrow-key-only keymap

- **Failing test** `test-r2-keymap` in `tests/test-r2-keymap.el`
  - Asserts `(lookup-key cistern-mode-map "h")` (and j/k/l) is nil; the four
    arrows are bound to `cistern-cursor-north/south/west/east`; grep-level
    check that no `define-key` maps hjkl to a cursor command anywhere in
    `cistern.el`.
  - Red because legacy keymap (:795-798) binds hjkl and the help line (:742)
    advertises `[hjkl/arrows]`.
- **Verbatim acceptance (R2):** "keymap test asserts no binding for
  \"h\",\"j\",\"k\",\"l\" as movement and the four arrow keys are bound to
  cursor commands; grep-level test asserts no
  `cistern-cursor-north/south/west/east` aliasing to hjkl remains."
- **Red commit:** `test: R2 failing — keymap has no hjkl movement; arrows bound to cursor commands`
- **Min implementation:** `cistern-input.el` `cistern-input-cursor-move (st
  dir)` delegating to the Phase-2 cursor-move use case; driver keymap
  (:787-809 rewritten) binds arrows + SPC/RET + verbs + `r`/`n`/`?`/`T`/`q`,
  no hjkl; help line text updated to arrows+mouse.
- **Green commit:** `R2: arrow-only movement keymap, hjkl removed`

### Pair 2 — R1: click-to-move / click-to-place

- **Failing test** `test-r1-click-moves-cursor`, `test-r1-armed-verb-places`
  in `tests/test-r1-click.el`
  - Builds a seeded state headless; simulates `(cistern-input-click st x y)`
    — no mouse event objects, the adapter call only. Asserts cursor equals
    (x,y); with pipe verb armed, asserts a pipe at (x,y) and alloy reduced by
    the pipe cost; cross-assert (R6) tick advanced by exactly 1 on the
    verb-click (see Pinned decision D3).
- **Verbatim acceptance (R1):** "batch test simulates the input-adapter call
  for a click at (x,y) and asserts cursor equals (x,y); with pipe verb armed,
  asserts a pipe placed at (x,y) and alloy reduced by the pipe cost."
- **Red commit:** `test: R1 failing — input-adapter click move/place`
- **Min implementation:** `cistern-input.el` `cistern-input-click (st x y)`
  (cursor move via click-move use case; if verb armed → build use case at
  (x,y) then exactly one tick) and `cistern-input-arm-verb (st verb)`;
  driver: `(defvar cistern-mode-mouse-map)` with `<mouse-1>` → 3-line
  interactive handler that converts the event to (x,y) via the pure
  `cistern-view--cell-at` and calls the adapter.
- **Green commit:** `R1: mouse click-to-move and click-to-place via input adapter`

### Pair 3 — R6 timer half: 'r' auto-run

- **Failing test** `tests/test-r6-timer.el`
  - `test-auto-run-toggle-schedules`: toggle on records exactly one schedule
    call with SECONDS 0.2, REPEAT t, and the tick callback. Scheduling
    records via `cl-letf` stubs of `run-with-idle-timer`/`cancel-timer`
    capturing args into a list — **no real timers, no wall clock** (§5.2).
  - `test-auto-run-toggle-off-cancels`: second toggle records exactly one
    `cancel-timer` with the stored handle.
  - `test-auto-run-fire-advances-one-tick`: call the callback N times
    directly → `tick` advanced by exactly N; no multi-tick path.
  - `test-no-run-10`: `run-10` absent from obarray/selftest (inherited from
    Phase 2; may already pass — if so, it stays as a regression pin, not a
    new red).
- **Verbatim acceptance (R6, timer half):** "timer test asserts toggle on
  schedules a 0.2s idle timer and toggle off cancels it (adapter-level,
  batch-checked via timer bookkeeping)" — plus "each fire advances exactly
  one tick" (roadmap brief).
- **Red commit:** `test: R6 failing — auto-run timer scheduling records`
- **Min implementation:** `cistern-input.el` `cistern-input-auto-run-toggle
  (st)` + `cistern-input--auto-run-callback` (game tick use case only when
  not over; driver refresh); driver `cistern--auto-run-timer` handle var;
  `r` rebound to the toggle.
- **Green commit:** `R6: 'r' toggles 0.2s auto-run timer; one tick per fire`

### Pair 4 — R7: connected-vs-isolated pipe glyph+face

- **Failing test** `tests/test-r7-glyphs.el`
  - Seeded map; build a pipe→toilet→tank chain; render (or call
    `cistern-view--cell-glyph`) and assert: the chain-connected pipe's glyph
    AND face both differ from an isolated pipe's glyph AND face; a toilet's
    glyph/face differs between connected(usable) and severed; glyph/face
    lookup routes through the Phase-1 tile table — grep guard: no `pcase`
    over cell kinds or literal glyph strings in `cistern-view.el`.
- **Verbatim acceptance (R7, render half):** "headless test builds
  pipe→toilet→tank chain and asserts the connected pipe renders with the
  connected glyph/face while an isolated pipe renders with the isolated one"
  (legality half is Phase 1/2, inherited).
- **Red commit:** `test: R7 failing — connected vs isolated pipe glyph+face`
- **Min implementation:** `cistern-view.el` `cistern-view--cell-glyph (st x
  y)`: kind from state → glyph/variant from Phase-1 tile table; connection
  variant from the Phase-1 pure connection query (flood-fill
  connected-to-capacity); face = view-local enum→face map. Replace legacy
  `cistern--pipe-glyph` (:623-640) neighbour-membership cond and
  `cistern--glyph-face` (:642-661) pcase.
- **Green commit:** `R7: pipe/toilet connection state projected to glyph+face via tile table`

### Pair 5 — R5 render side: celebration hook

- **Failing test** `tests/test-r5-hook.el`
  - Default outcome: with fresh state and `cistern--rewards-eval` returning
    the pinned default outcome `(:score 0 :objectives nil :unlocks nil
    :celebrate nil)` with empty presentation intents (spec §4 R5; same
    shape and split as plans 01/03 — default green in Phase 2, consumption
    red until 4b), render output is byte-identical with the
    hook short-circuited vs enabled (hook renders nothing).
  - Overlay injection: inject a particle list (rewards-notes TURN 3 shape
    `{pos, vel, ttl, glyph, face, layer}`) into the stubbed state particle
    field → those cells' glyphs/faces are overridden for that frame only
    (map state unchanged; next render with the field gone restores); a
    particle with out-of-bounds pos is clipped from output.
- **Verbatim acceptance:** R5 render half — "the view renders celebrations";
  Phase 3 ships the hook rendering the default (empty) outcome (roadmap
  fail-first #5). Full celebration consumption waits on Phase 4 /
  REWARDS-DESIGN.md.
- **Red commit:** `test: R5 failing — celebration overlay hook renders nothing on default outcome`
- **Min implementation:** `cistern-view--celebration-overlay (st)` →
  ((x y) . (glyph . face)) alist, clipped to map bounds, empty for default
  outcome; plug into the render pipeline (§3 below).
- **Green commit:** `R5: celebration overlay hook (dumb projection, default empty outcome)`

### R9 static check — inherited, re-verified after each green

Re-run the Phase-2 batch check after every green commit: load domain+game in
`emacs -Q --batch` with no buffer/display and run a full tick; static check
asserts no `cistern-view`/`cistern`-driver symbol referenced from domain or
game files ("verbatim acceptance (R9): a static check asserts no
`cistern-view`/`cistern`-driver symbol is referenced from domain or game
files"). Not a new red (it exists from Phase 2); it is the gate each green
must pass. One cheap backstop added alongside Pair 4's green: grep
`cistern-view.el`/`cistern-input.el` for direct hash-layout access
(`cistern-st-toilets`/`cistern-st-tanks`/`gethash` over state fields) — the
mechanical form of the projection-only rule (§5).

---

## 2. File-level work items

### `cistern-input.el` (adapter — translation only)

- `cistern-input-cursor-move (st dir)` — dir ∈ north/south/west/east →
  Phase-2 cursor-move use case.
- `cistern-input-click (st x y)` — cursor move; if `cistern-st-verb` armed →
  build use case at (x,y) + exactly one tick (R6). Takes **st as a
  parameter** (batch-testable); never touches buffers, never renders.
- `cistern-input-arm-verb (st verb)` — build keys (t/p/K/c/x) arm the verb in
  state AND keep legacy build-at-cursor behavior (Pinned D3).
- `cistern-input-auto-run-toggle (st)` + callback — 0.2s repeating idle
  timer; callback = exactly one tick + refresh. Single sanctioned exception
  to st-as-parameter: the timer callback reads the global `cistern--st`
  (fires outside any command context; Pinned D1).
- Timer testing contract: tests `cl-letf`-stub
  `run-with-idle-timer`/`cancel-timer` to record schedule/cancel args; the
  callback is invoked directly. No real timer is ever created in a test
  (§5.2 "timer scheduling records, not wall-clock").
- **Prohibited:** calling render, touching `cistern--st` outside the timer
  callback, naming domain hash layouts.

### `cistern-view.el` (adapter — projection only)

- `cistern-view--render (st)` → **returns a propertized string; pure
  function of state** (§3.3). The driver owns buffer mutation
  (`erase-buffer`/`insert`/`goto-char` in a thin `cistern--refresh`).
- `cistern-view--cell-glyph (st x y)` — kind + connection enum from state
  via domain/game query functions → (glyph . face) via Phase-1 tile table +
  view-local enum→face table. No `gethash`/`plist-get` into toilets/tanks
  hashes; if a needed query function is missing from Phase 1/2, that is a
  red blocker to harvest into the ledger — never a local pcase in the view.
- `cistern-view--cell-at (line col)` — pure buffer-geometry helper (map
  origin = fixed header-line count); used by the driver's mouse handler;
  batch-tested.
- `cistern-view--celebration-overlay (st)` — reads `cistern--rewards-eval`
  outcome + state particle field (stubbed); maps to per-cell overlay (§3).
- Port of legacy render (:728-780) into the pure composition: header, help
  line, glyph legend, map rows, banner row, inspector, pressure line,
  tutorial line, log tail.

### `cistern.el` (driver — mode/keymap/mouse map/timer wiring)

- Keymap rewrite of :787-809: SPC/RET tick; arrows → cursor commands; t/p/K/
  c/x → arm-verb(+build-at-cursor); `r` → auto-run toggle (run-10 stays
  dead); n/?/T/q unchanged. **No hjkl — asserted by Pair 1.**
- `cistern-mode-mouse-map`: `<mouse-1>` → handler: parse event →
  `cistern-view--cell-at` → `cistern-input-click`. Handler is ≤3 lines; only
  the pure translation is tested.
- `(defvar cistern--auto-run-timer)` — driver-owned timer handle (Pinned D2).
- `cistern--refresh`: erase buffer, insert `cistern-view--render` string,
  `goto-char (point-min)`.
- Exactly one game-state global `cistern--st` (§3.3), plus the timer handle
  exception (D2).
- Extend `cistern-run-selftest` with click-move + timer-bookkeeping blocks;
  extend `cistern-run-soak` with an auto-run-driven tick-count segment (§5.1
  / §5.2) — same batch invocation as legacy.

---

## 3. Celebration render contract

The view is a **dumb projection** — nothing more:

1. **Per redisplay, view reads, never advances.** The view reads the particle
   field from state each render; nothing is cached in the buffer (rewards-notes
   failure-mode 3). `advance-particles` is a *use case* called by the
   presentation layer's timer, not by the view (rewards-notes TURN 3, update
   semantics): when auto-running, the timer's step is tick-then-(later)
   advance-particles; when paused, an idle variant will call only
   advance-particles — the wiring point is pinned now (the timer callback),
   the call itself lands in Phase 4.
2. **Domain purity.** The domain stores face enum names only
   (`success`/`warning`/`error`/`info`/`bonus`, rewards-notes palette); the view maps
   enum→Emacs face. Domain never imports faces; the view never imports sim
   rules.
3. **Transient overlay, never occupies cells.** Particles/popups are rendered
   *after* the map loop (rewards-notes decision 4): they overwrite the cell's glyph
   for that frame only; map state is untouched; the next frame restores from
   state. Overlay precedence in the map loop's glyph selection: cursor →
   worker → particle overlay → cell glyph (matches legacy :749-765 cursor/
   worker precedence; particles sit above content, below cursor).
4. **Clip to viewport.** Overlay clipped to map bounds each frame; out-of-view
   particles keep ticking in the domain, cost nothing on screen, and resize
   never mutates particle state (rewards-notes "buffer resize" section).
5. **Banner row.** `layer:banner` particles render into a reserved row after
   the map rows, before the inspector (DF game-changing-announcement model,
   rewards-notes M7/M9) — never into the header; the header is drawn last, on top.
6. **Plug-in point (legacy :728-780).** Legacy map loop at :749-765 computes
   `(cistern--glyph-face st x y)` then overlays worker/cursor before
   `propertize`+insert. The rewrite's hook slots in exactly there: the
   cell's glyph/face is `overlay-of(x,y) || cell-glyph`, where the overlay
   alist comes from `cistern-view--celebration-overlay`, which calls
   `cistern--rewards-eval` (the pinned R5 interface) once per render. The
   banner row inserts between the map loop (:765) and the inspector (:766).

---

## 4. Decisions

### Pinned this phase (least-active-decisions)

- **D1** Adapter functions take `st` as a parameter; the auto-run timer
  callback is the single exception, reading the global `cistern--st`.
- **D2** `cistern--auto-run-timer` is a driver-owned handle defvar — timer
  plumbing, not game state; documented exception to the "exactly one global"
  rule (the rule counts game-state globals; a timer object never enters
  `cistern-st`).
- **D3** Build keys arm the verb in state (new field `cistern-st-verb`) AND
  build at cursor immediately (legacy keyboard flow preserved); click with
  armed verb = place at cell + **exactly one tick** (direct reading of R6
  "SPACE/RET/click-with-verb advance exactly one tick").
- **D4** View returns a propertized string; only the driver mutates the
  buffer ("rendering is a pure function of state", §3.3).
- **D5** Overlay precedence cursor > worker > particle > cell; banner in a
  reserved post-map row.
- **D6** View consumes connection/legality state via Phase-1/2 pure query
  functions returning enums — the projection-only rule's mechanical form.

- **DEFERRED (not pinned; do not let them into this phase's code)**

- Celebration spawn triggers, intensity, K=64 cap/FIFO eviction, golden
  fixtures, `advance-particles` implementation and its timer wiring
  (including paused-animation idle variant and debounce, rewards-notes
  open #2) — Phase 4 / docs/REWARDS-DESIGN.md (spec §6).
- Ceremony choreography: banner copy, 6-tick/skip semantics, commit-first
  trophy (rewards-notes TURN 3 decision 5, open #3) — Phase 4.
- M5 "+N" popup drift specifics beyond the overlay contract — Phase 4.
- Sprite/SVG rendering alternative (spec §6) — text glyphs assumed.
- Exact defface names/colors beyond a reasonable enum→face table.
- Mouse-drag, mouse-2/3, scroll-wheel bindings — not requested; YAGNI.
- Armed-verb status-line indicator polish.

---

## 5. Lesson-collection checkpoints (roguelike-agentic)

Expected failure class for this phase: **adapter leakage**. Run-death
triggers — a run doing any of these is dead immediately (call it off, harvest
into `docs/FAILURE-LEDGER.md` §5.3 format, emit replacement brief, never
nurse a corpse):

- **View reaches into sim state shapes** — `gethash`/`plist-get` over
  `cistern-st-toilets`/`cistern-st-tanks`, or any pcase over cell kinds /
  literal glyphs in the view instead of tile-table + query-function lookup.
- **Input calls render directly** — the input adapter invoking
  `cistern--render` or touching buffers; adapters translate, the driver
  renders (D1/D4).
- **Real timers or wall-clock in tests** — a test calling `run-with-idle-timer`
  un-stubbed or sleeping (§5.2). Dead on sight.
- **Scope deaths**: editing legacy files, changing sim/verb rules (Phase 3
  changes no sim behavior), or inventing cell kinds outside the tile table.
- **Re-failing the same assert twice** (roguelike-agentic: a run that
  re-fails the same determinism-style assert twice is dead).
- General triggers per `reference/roguelike-agentic.md`: stall, loop,
  error-without-recovery, operating on a faulty basis, or burning tokens
  re-discovering what this plan/brief should have carried.

**What the re-brief names** (per `docs/HANDBRIEF-TEMPLATE.md`): Mission
(the one requirement + its red test id); Repo state (commit hash, clean/
dirty); Files to read (spec §3.3, the R#'s §4 criterion, this plan, the
named legacy ranges); **Failure context = the L-### ledger entry with the
named leak and the fix** — e.g. "view used (gethash (cons x y)
(cistern-st-toilets st)) at tests/test-r7-glyphs.el red — use the
`cistern-domain-connection-state` enum query; projection-only rule applies";
Constraints (projection-only, red-first, no sim changes, no project-wide
validation); Done-when = the verbatim acceptance criterion.

---

## 6. Done-when (verbatim from the Phase 3 handoff brief, ROADMAP :207-215)

- hjkl unbound; arrows + mouse move cursor; click with armed verb places at
  the cell and spends alloy.
- 'r' toggles a 0.2s timer; each fire advances exactly one tick; toggle-off
  cancels.
- Connected vs isolated pipes render with different glyph AND face; toilet
  connection state visible.
- No cistern-view/cistern-driver symbol referenced from domain or game files
  (R9 static check).
