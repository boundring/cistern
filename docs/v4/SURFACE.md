# Cistern v4 — SURFACE UPGRADES (DESIGN)

> STATUS: DESIGN 2026-09-07 — no code. Six components S1–S6 mapped to the
> owner's five requirements (order below is build order: a row may depend on
> an earlier row, never a later one).
>
> Sources: owner requirements (verbatim, this file's provenance);
> docs/ux/TOP-30.md + TOP-30-R2.md (shipped surface); docs/FAILURE-LEDGER.md
> L-076 (glyph-width pin — all glyph work routes through it).

## 0. Binding constraints (every directive inherits these)

| # | Constraint | Application in this doc |
|---|---|---|
| C1 | **95-col contract.** No permanent render row exceeds 95 columns; the header block-height constant is shared by renderer and `cistern-view--cell-at` (R2-Q02 pattern). New rows (§4 hint coaching) reuse the already-reserved hint row — zero geometry change. | §1, §3, §4 |
| C2 | **Copy-table rule.** Every new player-facing string lands in `cistern--copy` (cistern-domain.el) with a named key at design time. Briefing prose stays prose (R2-Q08 precedent). | each § lists its keys |
| C3 | **L-076 pin route.** No new glyph ships outside the pinned/measured ranges; every new glyph passes the `tests/test-gui-probe.el` advance probe. Selection rule stated once in §3.1 and cited everywhere. | §3 |
| C4 | **Five SOARS protected.** S1 inspector standard / S2 pressure voice / S3 popups-at-act / S4 purge ledger / S5 non-modal ceremony. Each component names its interaction below. | per-section PROTECT lines |
| C5 | **Least-active decisions.** Each component states the chosen minimal design and the rejected heavier alternative in one line. Determinism untouched unless the domain must change; input coaching never enters sim state. | per-section "least active" lines |
| C6 | **Batch-testable except GUI-only.** Geometry/color math, table shape, keymaps, copy presence: batch. Anything needing real font resolution or frame parameters follows the L-076 probe pattern (registered test, SKIPPED message in batch, real assertion on a frame). | §6 |

---

## S1. LOG HISTORY & NAVIGATION — the L buffer becomes an event browser

**Owner requirement (1):** longer, easily navigable history; notice, review, re-review any event.

### S1.1 Domain: log entries gain tick stamps (the only domain change)

Log entries are `(LINE . SEVERITY)` (Q13). Extend to **`(LINE SEVERITY TICK)`** —
`cistern--log` / `cistern--log-sev` stamp `(cistern-st-tick st)` at append time.
The uncapped ring stays exactly as shipped.

Readers to update in the same change (complete list — grep-verified):
- `cistern-view--log-tail` — reads entry fields by nth; the collapsed triple
  `(LINE SEVERITY COUNT)` is unchanged (collapse projects entry → 2-list first).
- `cistern-view--collapse-log` input projection.
- `cistern.el` restart-dedup `(caar (cistern-st-log …))` — still the LINE field, fine.
- Q15 boot-line pick `(car (car (last log)))` — still LINE.

**Least-active decision:** stamping the tick at append is one table-shape change;
the rejected alternative (a parallel tick list or parsing ticks back out) needs
more moving parts for the same result.

### S1.2 Browser buffer: `cistern-log-mode` (define-derived-mode special-mode)

`cistern-log` (`cistern.el:295-309`) keeps: read-only, oldest-first, uncapped,
`q` closes (R2-Q13). It gains:

- **Persistent severity faces:** each line propertized through
  `cistern-view--palette-faces` (Q13 enums → faces) — the L buffer currently
  drops the face; the entry carries it, so rendering it is free.
- **Tick prefix:** every line begins with a fixed-width dim `T%-4d` prefix
  (ASCII digits — no fontset involvement, columns align by construction).
- **Jump-to-source:** lines matching `"AT (\([0-9]+\),\([0-9]+\))"` (breach and
  relief formats — regex parse at browser-build time, no domain change) get the
  `(x,y)` span text-propertized with `cistern-source-cell`. `RET` on the line:
  set the game cursor to that cell (new use-case `cistern--cmd-cursor-goto`,
  routing through the input adapter like every cursor move), pop back to
  `*cistern*`, refresh, and leave point on the game cursor cell. Returning with
  `L` re-opens; the browser rebuilds only when the log has grown
  (`cistern-log--built-for` = ring length), so point survives the round trip.
- **Staleness:** `g` rebuilds from current state (covers auto-run having
  ticked under the browser — S5 non-modal: opening the log pauses nothing).

### S1.3 Keymap spec (`cistern-log-mode-map`)

| Key | Binding | Note |
|---|---|---|
| `n` / `p` | next / previous log entry (≡ `next-line`/`previous-line`; entries are one line each) | the plain walk; explicit aliases so `n`/`p` mean *next/prev event* here, not their game-buffer verbs |
| `C-n` / `C-p` / `C-f` / `C-b` | native line/char motion — **not rebound**, documented as the emacs power layer | teaching §4 |
| `C-s` / `C-r` | `isearch-forward` / `isearch-backward` | native in read-only buffers; documented, not rebound |
| `/` | `isearch-forward` (alias of C-s) | |
| `g` | `beginning-of-buffer` + rebuild from state | |
| `G` | `end-of-buffer` | |
| `M-<` / `M->` | native first/last — documented, not rebound | |
| `RET` | `cistern-log-jump-to-source` (only on coordinate lines) | |
| `SPC` / `DEL` | scroll-up / scroll-down (native in special-mode) | |
| `q` | `quit-window` (R2-Q13, unchanged) | |

**Copy-table keys (C2):** `log-header` (`— press q to close —`, already
hardcoded at `cistern.el:304` — relocated into the table by this directive),
`log-jump-none` (`NO CELL ON THIS LINE`), `log-hint` (briefing mention only).

**PROTECT:** S5 — the browser is another buffer, the game never blocks; S2 —
severity faces come from the same palette as everywhere else.

**Least-active:** reuse the shipped Q16/R2-Q13 buffer; no tabulated-list, no
tabulated columns — fixed-width text prefix + text properties is the whole
feature. Rejected: a tabulated-list rewrite (columns buy nothing for prose lines).

### S1.4 Acceptance (fail-first)

- A1.1 **FAIL if** after 13+ events the `*cistern log*` buffer's first line is
  not the oldest entry *with its tick prefix* (extends Q16's probe).
- A1.2 **FAIL if** a breach line in the browser does not render with the
  error-severity face on every re-open, for the life of the game (extends Q13).
- A1.3 **FAIL if** `RET` on a `BREACH … AT (x,y)` line leaves the game cursor
  anywhere but (x,y) in the next game render; **FAIL if** `RET` on a
  coordinate-free line changes the cursor at all (must post `log-jump-none`).
- A1.4 **FAIL if** point in the log buffer is not preserved across an
  `RET → L` round trip when no new events occurred.
- A1.5 **FAIL if** the browser keymap lacks any table row above; **FAIL if**
  `n`/`p` in the browser run game verbs (keymap shadowing probe).
- A1.6 **FAIL if** browser line length (tick prefix + text) exceeds 95 for any
  shipped copy at max format width (breach line with tick 99999).

---

## S2. THEME-CONTRAST FACES — derive the palette from the running theme

**Owner requirement (2):** color theory applied automatically against whatever
theme emacs displays.

### S2.1 Pure derivation function (testable, no Emacs runtime calls)

```
cistern--derive-palette BG → PALETTE
  BG      : "#RRGGBB"            ; resolved by the caller (color-name-to-rgb)
  PALETTE : alist (ROLE . "#RRGGBB")
```

Algorithm (pure math, spec'd exactly so tests and implementation agree):

1. Linearize BG's sRGB channels (c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4),
   relative luminance `L_bg = 0.2126R + 0.7152G + 0.0722B` (WCAG 2.x).
2. Each palette ROLE specifies `(HUE SAT CLASS)` where CLASS ∈:
   - `recessive` (wall, floor, pipe-dead, dim) — target ratio **4.5:1**, chosen
     at the *smallest* luminance meeting it (stay recessive on the theme);
   - `standard` (door, ore, tank-ok, tank-high, worker, tutorial) — **4.5:1**;
   - `emphatic` (pipe-live, toilet, toilet-busy, header, celebration) — **7.0:1**;
   - `alert` (hazard, toilet-down, tank-full) — **7.0:1**, red-family hue.
3. Contrast ratio R needs foreground luminance `L_f`:
   - dark theme (`L_bg < 0.5`): lighter side, `L_f = R·(L_bg + 0.05) − 0.05`;
   - light theme: darker side, `L_f = (L_bg + 0.05)/R − 0.05`.
   Invert WCAG linearization → channel values; apply ROLE's hue/sat in HSL;
   emit "#RRGGBB".
4. Ratio target stated once: **every glyph color ≥ 4.5:1 against the frame
   background; emphasis/alert roles target 7:1** (WCAG AA / AAA text bars —
   glyphs *are* the text here).

**Ratio target guard:** if a role's target is unreachable (saturation clash,
extreme bg), clamp sat toward 0 and retry once, then emit the best-effort value
and still pass ratio for greys; test asserts the clamp path exists (bg = pure
red #FF0000, alert-red role must still land ≥ 4.5).

### S2.2 Derived vs fixed faces

- **Derived (19):** wall, floor, door, ore, pipe-live, pipe-dead, toilet,
  toilet-busy, toilet-down, tank-ok, tank-high, tank-full, hazard, worker,
  worker-sick, header, dim, tutorial, + every future glyph face (rule, not
  list: *any new face takes its color from a role, never a literal*).
- **Fixed:** `cistern-cursor` (`:inverse-video` — theme-agnostic by
  construction; contrast is the theme's own job for inverse video).
- **Weights/bold flags are face specs, not derived** — only `:foreground` is
  computed.

Role table maps each face → role; the S2 palette alist replaces the hardcoded
`:foreground "…"` literals in the `defface`s at mode init.

### S2.3 Application & regeneration triggers

1. **Mode init:** `cistern-mode` calls `cistern--apply-palette` — resolves
   `(frame-parameter frame 'background-color)` → hex, derives, applies each
   face frame-scoped (`set-face-attribute FACE frame :foreground …`). The game
   already owns its frame (`cistern--own-frame`, L-076), so frame-scoping never
   touches the user's other frames or their face customizations elsewhere.
2. **Theme hook:** `add-hook 'enable-theme-functions` (Emacs 29+) →
   `cistern--theme-refresh` (re-derive + re-apply on the game frame when
   `*cistern*` is live).
3. **Drift guard:** `cistern--refresh` compares the frame's background-color
   against the cache (`cistern--palette-cache` = `(BG . PALETTE)`); a mismatch
   re-derives before rendering. One string compare per render — covers
   `custom-set-faces`/`load-theme` paths the hook misses. **The view stays
   pure:** the check lives in the driver's refresh, never in a projection fn.

**Least-active:** frame-scoped `set-face-attribute` over a face-remap stack per
face (19 remap registrations vs one frame the game already owns).

### S2.4 Acceptance (fail-first)

- A2.1 **FAIL if** `cistern--derive-palette "#101010"` returns any role color
  whose WCAG ratio against `#101010` (computed in the test by the same
  linearization) is below its class target (4.5 / 7.0).
- A2.2 **FAIL if** the same fails for a light bg (`#F5F5F5`), a mid bg
  (`#808080`), pure black, pure white, pure red — the polarity switch and the
  sat clamp are both covered.
- A2.3 **FAIL if** the derivation function calls any frame/buffer/color-resolver
  (source-integrity probe: no `frame-parameter`/`color-name-to-rgb` in it).
- A2.4 **FAIL if** any `defface` in `cistern-view.el` still carries a literal
  `:foreground` (grep probe) — except `cistern-cursor`.
- A2.5 **GUI (L-076 probe pattern):** on a frame, set a dark bg then a light bg
  between renders → `face-attribute` of `cistern-wall` flips polarity and the
  measured contrast of every glyph face vs the live frame bg meets its target;
  batch: registered + SKIPPED message, suite green.
- A2.6 **FAIL if** a user theme change while the game is closed is not picked
  up by the next `cistern` launch (cache is not persisted across sessions).

**PROTECT:** S2 pressure voice — colors change, the idle line's *words* stay
byte-identical (`LINES NOMINAL — THE STRUCTURE DOES NOT CARE` is asserted in
Q11's string-equality test, untouched). S1 inspector — faces change, line
text does not.

---

## S3. GLYPH VOCABULARY EXPANSION — terrain, hazards, events

**Owner requirement (3):** more varied glyphs for terrain/gameplay, pop-in
must never disturb wall/ground alignment.

### S3.1 The L-076 selection rule (C3 — cited by every glyph below)

A glyph may enter `cistern--tile-table` (or any overlay set) only if **all** of:

1. Its codepoint is in a **pin-covered or L-076-measured range**: ASCII
   (U+0020–007E), box-drawing + geometric shapes (U+2500–25FF), dashes
   (U+2010–2015), middle dot (U+00B7), Greek (U+03B1–03C9). Anything
   East-Asian-ambiguous outside these (≡ U+2261, ❖, ✓…) is rejected by rule,
   not by luck.
2. **Batch gate:** the tile-table test asserts every glyph string is
   `length=1` and its char is in the allowed charset (pure, runs everywhere).
3. **GUI gate (L-076 probe pattern):** `cistern-test-gui-cell-width` already
   measures every unique rendered glyph's `font-at` advance == cell width; the
   probe's coverage line (`cistern.el` test) is extended with each new glyph so
   the probe cannot pass while a new glyph silently falls back. Registered in
   batch, SKIPPED without display — the canonical suite stays green.

Fidelity guarantee: the fontset pin covers the whole range for the game frame
when it engages; when it cannot engage (terminal), new glyphs from the same
ranges behave exactly like the shipped ▓▒◆ do today — no worse. Pop-in safety:
glyphs render into fixed 1-column cells under the pinned fontset; the Q25
particle placement contract (floor-only) and z-order are unchanged, so a new
tile or marker appearing can never shift a wall row.

### S3.2 New tile kinds (table additions — sole-source table, R3b)

| kind | glyph | U+ | passable | buildable | firebreak | loop role | legend line (copy key `legend-<kind>`) |
|---|---|---|---|---|---|---|---|
| `rubble` | `▚` | 259A | nil | nil | t | map-gen debris fields: impassable texture that shapes routing and firebreaks; `d` clears to floor (cost 2, same demolish verb) | `▚ rubble — impassable (d clears)` |
| `flood` | `░` | 2591 | nil | nil | nil | breach may flood adjacent floor; impassable while wet, decays like hazard (`decay-pct` roll) but **never counts toward the contam limit** — it steals ticks, not health; `c` dries it | `░ flood — dries or decon (c)` |
| `manifold` | `╬` | 256C | nil | nil | t | map-gen anchor: any pipe orthogonally adjacent to a manifold is **live with unlimited headroom** (no tank needed, no purge income). Procgen places 0–2; severed-pressure logic treats manifold-adjacent pipes as backed | `╬ manifold — free pipe anchor` |
| `cache` | `?` | 003F (ASCII) | t | nil | nil | story-event outcome: first worker to walk over it banks an alloy bonus (popup at the act, S3), tile becomes floor, logs `'success` | `? cache — worker picks up` |
| `event` | `!` | 0021 | t | nil | nil | story-event *countdown marker*: stands 3 ticks on the cell where an event will land (see S5.5), then resolves to `cache` / `flood` / `rubble`; each standing tick logs nothing (silent — S2 voice), the resolution logs | `! event incoming` |

`cache` (`?` U+003F) and `event` (`!` U+0021) are both trivially in-range and
**transient
cell kinds** (they exist in the map vector, spawn/despawn through domain
functions like hazard does — no overlay machinery).

Domain touchpoints (one sweep): `cistern--tile-table` (5 entries),
`cistern--add-hazard`-style spawners for flood, event resolution in the tick
path, procgen tables (rubble clusters, manifolds), passability consumers
(worker walk + build refusal), `cistern-view--kind-faces` +
`cistern-view--kind-descriptions` (S1 inspector: each new kind gets its
inspector line — wall/ore pattern), legend generator (already table-driven,
Q12 + R2-Q01 wrap).

New faces: `cistern-rubble` (grey recessive role), `cistern-flood`
(cyan emphatic), `cistern-manifold` (orange emphatic), `cistern-cache` /
`cistern-event` (yellow standard) — all through S2 roles.

### S3.3 Non-tile glyph expansion

- **Worker status = faces, not glyphs (decided by L-076).** The Greek letter is
  the worker's *identity* (Q14: log, map, inspector name the same glyph) — a
  per-status glyph would break identity pairing. Status becomes color:
  existing `cistern-worker` / `cistern-worker-sick` plus new `cistern-worker-mining`
  and `cistern-worker-commuting` (derived roles). Zero new width risk.
- **Story-event markers:** the `!` countdown tile and `?` cache tile (S3.2) are
  the markers; popup glyphs `* ! §` are unchanged (S3 SOAR — popups stay at the
  act, on floor cells only, Q25 contract).
- **Rejected:** combining diacritics for worker states (width-unmeasurable),
  U+2261-style symbols outside pinned ranges.

### S3.4 Acceptance (fail-first)

- A3.1 **FAIL if** any glyph in `cistern--tile-table` (or the new face/status
  sets) is `length≠1` or its char is outside the S3.1 allowed charset (batch).
- A3.2 **GUI (L-076 probe pattern): FAIL if** any new glyph measures
  advance ≠ cell width on a graphic frame — probe coverage line extended
  before the glyph ships; batch: registered + SKIPPED.
- A3.3 **FAIL if** a breach-driven flood pops in and any subsequent row's
  wall-column x-positions differ from the pre-flood render (render-diff probe
  at fixed seed — batch on the string level: columns of row y+1 identical
  before/after flood spawn at (x,y)).
- A3.4 **FAIL if** the legend misses any new kind, lists a glyph twice, or any
  legend/help row exceeds 95 cols (extends Q12/R2-Q01 probes).
- A3.5 **FAIL if** a worker pathing tick can enter `rubble`/`flood`, or a build
  can arm on `manifold` (table-driven refusal probe).
- A3.6 **FAIL if** any new inspector line for the new kinds does not name
  state + fix verb (S1 inspector standard), or any new string appears outside
  `cistern--copy` (source grep, R2-Q03 pattern).

**PROTECT:** S1 inspector — new kinds extend `cistern-view--kind-descriptions`,
zero regression on existing lines (Q20 probe re-run). S4 purge ledger —
flood decon cost reuses `cistern-cost-decon`; the purge inspector rate line is
untouched.

---

## S4. EMACS KEYBIND TEACHING LAYER

**Owner requirement (4):** pair game verbs with standard emacs bindings;
teach progressively.

### S4.1 What stays single-key (roguelike convention — untouched)

`SPC`/`RET` tick · arrows+mouse move · `t`/`p`/`K` arm builds · `d` demolish ·
`c` decon · `x` purge · `r` auto-run · `u` disarm · `L` log · `n` new game ·
`?` help · `q` quit. **Everything ships one-key; the emacs layer is additive
aliases on top.** This is the central least-active decision: no rebinding, only
addition (keymap probe A4.1 pins it).

### S4.2 The pairing table (new driver bindings — all `interactive` commands
routing through existing use cases)

| Verb | Emacs binding | Game meaning | Reuse |
|---|---|---|---|
| cursor south / north | `C-n` / `C-p` | move down/up | aliases of `cistern-cursor-south/north` |
| cursor east / west | `C-f` / `C-b` | move right/left | aliases |
| row home / row end | `C-a` / `C-e` | cursor to x=0 / x=w−1 (y kept) | new commands, pure geometry |
| map home / map end | `M-<` / `M->` | cursor to (0,0) / (w−1,h−1) | new commands |
| next / prev structure | `M-f` / `M-b` | jump cursor to next/prev structure in scan order (toilets, tanks, manifolds; wraps) — the "word motion" reading of the grid | new use-case `cistern--cmd-cursor-scan` (doubles as QoL §S5.2) |
| cancel | `C-g` | disarm armed verb (≡ `u`, ESC) | alias of `cistern-disarm` |
| search capacity | `C-s` | cursor to nearest toilet with tank headroom (else nearest toilet; else hint `log-jump-none`-style refusal) — the game's "isearch" | new use-case, manhattan scan (Q20 geometry) |
| log search | `C-s` / `/` in the browser | isearch (S1.3) | native |
| repeat last build | `.` | re-arm the last armed verb (roguelike repeat; emacs `C-x z` noted in the briefing, not bound) | driver-side last-verb echo |

`C-g` note: in a GUI frame ESC/C-g both reach `cistern-disarm`; in `-nw`
frames C-g is the quit prefix — the copy teaches `u` as the everywhere-cancel
(R2-Q08 precedent) and C-g/ESC as the GUI layer. No `-nw` binding surgery.

### S4.3 Teaching mechanism — the Q17/R2-Q06 hint surface, fed by a coach table

Driver-side ephemeral counter alist `cistern--teach-seen` (NOT sim state —
coaching is input-layer, determinism untouched, C5). When a player performs an
action whose emacs pair exists, the 3rd such use posts a one-hint-lifetime
coach through the existing Q17 hint slot:

| trigger (3rd use) | hint (copy key `teach-*`) |
|---|---|
| arrow move | `C-n/C-p/C-f/C-b MOVE TOO` |
| arm (t/p/K) | `C-g CANCELS — OR U/ESC` |
| u disarm | `C-g IS THE EMACS CANCEL` |
| manual tick spam (SPC ×10 in 20 ticks) | `r RUNS THE TICKS — C-u r SLOW` |
| log open | `C-s SEARCHES THE LOG / n/p WALK IT` |

Each fires once per game (alist reset on `cistern-new-game`). Copy keys land in
`cistern--copy` (C2); the coach table lives beside the keymap
(`cistern--teach-pairs`), consumed by the driver on command exit, rendered by
the existing hint row (R2-Q06 lifetime — one non-cursor command clears it;
reserved row means zero layout shift, C1).

### S4.4 Briefing as progressive emacs tutorial (`?`, `cistern-help`)

Reordered, four sections, basics before power (no content deleted, only
regrouped + grown):
1. **THE CONCEPT / THE LOOP** — unchanged (the game first).
2. **GLYPHS** — regenerated *from the tile table* (one source, Q12 spirit)
   instead of the current hand-typed lines that already drifted from the table.
3. **CONTROLS — THE BASICS** — the single-key layer verbatim (current CONTROLS).
4. **CONTROLS — THE POWER LAYER** — the S4 table: "every one of these already
   worked in emacs; here they run the sector." Plus the LOG BROWSER rows
   (S1.3) — `n/p walk · C-s search · RET jump to source · g refresh · q close`.
   Frame: "you already know these" — the teaching claim is the pairing, not a
   new language.

**Least-active:** no interactive tutorial mode, no key-chord detection — the
briefing, the hint line, and the help line carry it. Rejected: a `C-h m`-style
dynamic describe (Emacs already provides `describe-mode` for free — mention it
in the briefing instead of building one).

### S4.5 Acceptance (fail-first)

- A4.1 **FAIL if** any pre-v4 keymap binding changes or is shadowed
  (`test-r2-keymap` extension: old-map keys ∩ new map = identical actions).
- A4.2 **FAIL if** `C-n/C-p/C-f/C-b/C-a/C-e/M-</M->/C-g/C-s/.` produce a cursor
  position other than the table's definition (driven batch: move to a corner,
  assert `cistern-st-cursor`).
- A4.3 **FAIL if** the 3rd arrow move does not post the `teach-arrows` hint in
  that tick's capture, or the hint appears twice in a game, or it survives the
  next non-cursor command (R2-Q06 lifetime probe).
- A4.4 **FAIL if** `cistern-help` output lacks the POWER LAYER section, any
  §S1.3 log-browser key, or the GLYPHS section disagrees with the tile table
  (generated, not literal — grep probe for hardcoded glyph list).
- A4.5 **FAIL if** any teach hint or new help line exceeds 95 cols.
- A4.6 **FAIL if** `.` repeats when no verb was armed yet, or repeats a
  *disarmed* verb after ESC (repeat only re-arms the last *successful* arm).

**PROTECT:** S5 — the coach posts through the existing transient hint (non-modal,
consumed by next actionable command); S3 popups untouched.

---

## S5. ROGUELIKE QoL — genre conveniences, feasibility-stated

**Owner requirement (5).** Each item: what, feasibility in the current
architecture, verdict.

| # | Feature | Design | Feasibility / verdict |
|---|---|---|---|
| 5.1 | **Repeat-last-command (`.`)** | Last *successfully armed* verb re-arms at the current cursor (`.` → same as re-pressing t/p/K). Driver-side echo var; the arm itself routes through the normal use case, so a refused re-arm refuses with the standard Q18 hint. | Trivial — one driver var + one command. SHIP. |
| 5.2 | **Look mode** | The inspector (Q20/R2-Q07) *is* look mode: the cursor is the look cursor and every tile names state + fix. | No new surface needed. VERDICT: nothing to build — §S4's `M-f/M-b` structure jump is the missing mobility, not a new mode. |
| 5.3 | **Score screen on death/complete** | Q22/Q23 shipped the panel. Addition: the death panel gains one dim line `L — FULL HISTORY` (copy key `death-log-hint`); the uncapped log survives post-mortem, so the run's whole story is reviewable from the panel. | Copy + one view line. SHIP. |
| 5.4 | **Message-history quick-jump** | S1.3's browser (`n`/`p`, `C-s`, `RET` jump-to-source) plus game-side `M-f/M-b`. | Covered by S1. No separate work. |
| 5.5 | **Countdown warnings** | Migrant arrival: `!`-style anticipation without a tile — domain logs `MIGRANT IN %d` ('info) at 3 ticks out (copy key `migrant-in-fmt`); pressure line already anticipates (Q08/Q10); S3.2's `!` tile is the visible form for *event* countdowns. | One domain log call + copy. SHIP. |
| 5.6 | **Auto-explore** | No fog-of-war — the map is fully visible from tick one; exploration is not a loop the game has. The real need (finding things) is `M-f/M-b` + `C-s`. | INFEASIBLE-AS-SPECIFIED, need already covered. Rejected. |
| 5.7 | **Vi-keys h/j/k/l** | Out of register — this game teaches *emacs*. | Rejected (one line in the briefing notes the arrows/C-n/C-p pairing instead). |

### S5 — Acceptance (fail-first)

- A5.1 **FAIL if** `.` after a successful `p` arm does not re-arm pipe (header
  shows `ARMED: PIPE`), or fires with no prior arm.
- A5.2 **FAIL if** the death panel lacks the full-history line, or `L` from the
  condemned frame shows an empty browser (log survived).
- A5.3 **FAIL if** the migrant countdown is absent at T−3, present twice, or
  its line exceeds 95 cols.

**PROTECT:** S3 popups — cache pickup pays via the existing popup-at-act path;
S4 purge ledger untouched; S5 non-modal — the browser never pauses or gates the
game.

---

## 6. BUILD ORDER & TEST NOTES

Dependency-ordered (a row depends only on earlier rows):

1. **S1.1** log entry shape (domain) — unlocks S1.2/S1.3 and the tick-prefixed
   browser; readers updated in the same pass (list in S1.1 is complete).
2. **S2** palette derivation + triggers — independent of S1; unlocks S3's new
   faces and A2.5.
3. **S3** glyphs (needs S2 roles + S3.1 rule; probe coverage line grows with it).
4. **S4** keybind layer + coach (needs S1's browser keys for the briefing).
5. **S5** QoL (5.1, 5.5, 5.3 — all independent increments; 5.5 wants S3's `!`
   for symmetry but ships without it).

Test split (C6):
- **Batch:** A1.1–A1.6, A2.1–A2.4, A2.6, A3.1, A3.3–A3.6, A4.1–A4.6, A5.1–A5.3,
  plus the copy-table greps (R2-Q03 pattern) and the 95-col row probe
  (R2-Q01 pattern) re-run over all new permanent rows.
- **GUI-only (L-076 probe pattern — registered, SKIPPED in batch, real
  assertion on a frame):** A2.5 (face/bg contrast on a live frame), A3.2
  (advance == cell width for every new glyph). Both extend
  `tests/test-gui-probe.el`; both were RED-able pre-fix in L-076's run and
  must be re-RED-able the same way (drop the pin → probe fails; restore → passes).

New copy keys shipped by this doc (C2 ledger): `log-header`, `log-jump-none`,
`legend-rubble`, `legend-flood`, `legend-manifold`, `legend-cache`,
`legend-event`, `teach-arrows`, `teach-cancel`, `teach-auto-run`,
`teach-log`, `log-hint`, `death-log-hint`, `migrant-in-fmt`, plus any inspector/
description strings for the five new kinds (keyed `desc-<kind>`,
`insp-<kind>`), all in the Q11 Blame! register.
