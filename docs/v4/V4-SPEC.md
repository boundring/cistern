# CISTERN v4 — CONSOLIDATED SPEC (story engine × RPG layer × surface upgrades)

Status: SPEC v1, 2026-09-07. Consolidates docs/v4/STORY-ENGINE.md,
docs/v4/RPG-LAYER.md, docs/v4/SURFACE.md into one implementable, wave-ordered
build plan, and closes the owner-required gap: procedurally generated,
BRANCHING DIALOGUE TREES for inter-NPC communication (§2). No code in this
doc; every directive lands red-first per R10.

Carried constraints, binding on every directive below (PROTECT block):
- **Five soars**: S1 inspector standard · S2 pressure voice · S3 popups-at-act
  · S4 purge ledger · S5 non-modal ceremony.
- **Width contract**: no permanent render row exceeds 95 cols (C1).
- **Copy-table rule**: every player-facing string in `cistern--copy`
  (hand copy) or bank `:copy` (generated data), resolved through the
  STORY-ENGINE §4.4 chain — one table, no literals in view/game/input.
- **L-076 pin route**: no new glyph outside pinned/measured ranges; every
  glyph passes the advance probe (SURFACE §3.1 rule, cited per directive).
- **Deterministic envelope guards** (§5.6): bladder-window ≥ 22 ticks,
  story/RPG/dialogue never touch sim LCG or particle-rng, rewards-eval stays
  the sole drainer of `cistern-st-rewards-events`.

---

## 1. INTEGRATION OVERVIEW

### 1.1 Per-tick event flow (one diagram, one call site each)

Story-eval, rpg-eval hooks, and dialogue-eval each insert exactly ONE call
into the existing tick path; rewards-eval remains last and stays the sole
drainer of pending events (L-027 wiring untouched).

```
cistern--do-tick (game layer)
  │
  ├─ sim phases (bladder, movement, mining, hazards, migration …)
  │     └─ sim + RPG event checks (§3.4 RPG-LAYER: exposure DC12 /
  │        composure DC10 / stride DC16 on their firing events)
  │        emit tick events → (push EVENT cistern-st-rewards-events)
  │
  ├─ cistern--story-eval st            ; NEW, one call (STORY-ENGINE §8.1)
  │     reads pending events, DRAINS NOTHING
  │     rolls stream 2 only when a hook opens (tier draw, then roll)
  │     → story intents (log/banner/popup/tile-place)
  │
  ├─ cistern--dialogue-eval st         ; NEW, one call (§2.5)
  │     reads resolved-hook state + cast, draws stream 2 AFTER story-eval
  │     (pinned call order), drains nothing
  │     → dialogue intents (log lines only, §2.6)
  │
  ├─ cistern--rewards-eval st nil      ; EXISTING, sole event drainer
  │     appends story+dialogue intents to the stored intent 2-list
  │
  └─ view reads the STORED intents once per render (no new query paths)
        story/dialogue lines carry tick stamps into the S1 browser (§2.6)
```

Ordering rules (pinned): story-eval reads post-tick state and runs before
dialogue-eval, which reads story-eval's state transitions (an act rollover
this tick un-gates dialogue nodes); dialogue-eval runs before rewards-eval
so dialogue lines ride the same intent batch. Neither new eval ever drains
`cistern-st-rewards-events` — mechanically asserted (§5.6 guard).

### 1.2 Stream allocation table (owner of each id)

| Stream (seed ⊕ id) | Owner | Consumes | Position on state |
|---|---|---|---|
| 0 | reserved | REWARDS ledger | — |
| 1 | story GENERATION | premise, cast, hook scheduling — once at new-game | consumed once; not held |
| 2 | story RUNTIME (incl. dialogue) | tier draws, hook rolls, effect cells, tree selection, branch rolls (§2.4) | `:roll-pos` in story plist |
| 3 | RPG | stat spawn draws (4d6-drop-lowest), d20 checks | `rpg-pos` |
| 4+ | free | — | — |
| ⊕ 0x6A6E | gen-bank script ONLY | bank generation composition | outside the runtime space |

All draws slice mid-bits: `1 + (mod (ash pos -6) N)` (STORY-ENGINE §6.2 =
RPG-LAYER §3.1/§3.2 — one ruling, all engines). Dialogue draws from stream 2
through the SAME `:roll-pos` after story-eval's draws; no new position field.

### 1.3 Matrix loader ownership (one hash, one loader)

- ONE domain hash table keyed `(matrix-id . band 0..3)`, outcome plist
  `(:line-key K :effect E :arg A)`; lookup total by construction (loader
  guarantees 4 bands per matrix).
- ONE loader in domain: bank matrices are folded by `cistern--banks-load`
  from scenario `:entries`; RPG's `exposure-grit` / `composure-nerve` are a
  domain const written in the bank-entry shape, installed at domain load
  (§3, ruling 5). Matrix ids are unique across both sources (loader check).
- Story hook matrices keep STORY-ENGINE §6.1 sim-state band stats
  (`tolerance/integrity/standing`); RPG checks use worker stat mods clamped
  −2..+2; dialogue branch rolls use the participant's RPG stat (§2.4). Three
  stat tables, each engine names its own; the loader does not care.
- Story adds nat-20/nat-1 promotion nowhere: promotion is RPG-stream-only
  (STORY-ENGINE §6.2 parenthetical stands; dialogue follows the story
  convention — no promotion, §2.4).

### 1.4 Layer ownership summary (consolidated)

| Concern | Layer |
|---|---|
| story state, banks+loader, generation, band queries, matrix hash, dialogue node graphs, RPG stats/catalog/checks/XP, tile kinds | domain (pure, emacs-free) |
| story-eval, dialogue-eval, rpg cmd hooks (`T` cycle, build verdicts), new-game wiring | game |
| log browser, palette derivation application, inspector segments, glyphs/faces, legend, intents render | view |
| keybind aliases, coach hints, briefing | driver/input |
| bank files, gen-bank script | data/tools |

Domain never references view/driver; view never calls story-eval or
dialogue-eval; input owns nothing narrative (non-modal by construction).

---

## 2. BRANCHING DIALOGUE TREES — inter-NPC communication (the gap)

### 2.1 Register ruling first

STORY-ENGINE §1 says "no dialogue". That sentence scopes to prose-style
character speech. Inter-NPC communication renders as INSTITUTIONAL TRAFFIC:
filed requisitions, cross-shift reviews, routed complaints — same deadpan,
uppercase, no quotation, no first person, no exclamation:

    β FILES A PRESSURE COMPLAINT — ROUTED TO α — REVIEW DUE
    α ENDORSES β's REQUISITION — MARGIN NOTED

Speakers are named by `cistern--worker-glyph` (Q14) — dialogue never
invents names, so map, inspector, log, and dialogue agree on β being β.

### 2.2 What a dialogue tree is

One tree = one short inter-NPC exchange (2–4 lines) between cast members,
selected by tier and navigated by D&D-style rolls. It is GARNISH like every
story beat: a line of copy, zero mechanical effect (dialogue outcome effect
is always `none` — the §6.4 effects whitelist is NOT available to dialogue;
one-line guard-rail, §2.7).

Structure: a directed acyclic graph of NODES, depth ≤ 3 from the root.
- Root node: opens the conversation when its gates hold.
- Interior node: one participant states something, then one BRANCH —
  a roll that picks the next node per band.
- Leaf node: closing line, tree ends.

### 2.3 Node + bank shape (new bank kind `dialogue`)

`cistern--banks` gains a fifth slot: `:dialogues (...)`. New `:kind` value
`dialogue` routes through the existing uniform bank-file format
(STORY-ENGINE §4.2) — one file, one defconst, `:copy` + `:entries`:

```elisp
(:id dlg-pressure-review        ; unique across the dialogue kind
 :actors 2                      ; 1 = solo aside, 2 = pairwise
 :tier common|occasional|rare   ; static tier (see §2.4 for the roll)
 :act 2                         ; must hold: current act ≥ :act
 :gate (seal-creak . resolved)  ; (hook-id . state); state ∈ open|resolved;
                                ; resolved may add :as pass|fail
 :pair (stat nerve stat flow)   ; participant role selectors, see below
 :root t
 :line dlg-review-open          ; copy key (bank :copy or cistern--copy)
 :branch (:stat nerve :difficulty 10
          :matrix dlg-review-verdict      ; 4-band matrix, same machinery
          :next (dlg-review-cool dlg-review-wary dlg-review-warm
                                 dlg-review-endorsed)))  ; band 0..3
```

Non-root nodes: `(:id ID :line KEY :branch …)` — same shape, `:root nil`,
and every `:next` id names a node DECLARED LATER in the same file (the
declaration order IS the topological order — cycles are unloadable by
construction, no runtime search). Leaf: `(:id ID :line KEY)` — no `:branch`.

Participant selection: `:pair` lists role selectors consumed in order
against the cast (3.4 STORY-ENGINE pairwise rule). A selector is either
`(stat S)` — the cast member whose S (FLOW/GRIT/NERVE/ARCHIVE, RPG §1) is
highest, tie broken by cast order — or `(quirk Q)` — the cast member
carrying quirk Q. Two cast members minimum for `:actors 2`; a solo aside
(`:actors 1`) rolls against the sector via its matrix `:stat` default.

### 2.4 Roll, rarity, branch selection (reuse, nothing new)

- Tree selection: once per its cooldown window, one stream-2 draw →
  cumulative tier weights (60/30/10 common/occasional/rare act I, drifting
  per `cistern--story-tier-drift`, STORY-ENGINE §7.4) → which dialogue
  fires. Same machinery as hook `:events`.
- Branch selection: one stream-2 d20 (sliced, §1.2), stat = the selected
  participant's RPG stat mod clamped −2..+2 (this is the bridge that keys
  nodes on participant STATS), `margin = roll + stat − difficulty`
  (matrix `:difficulty`; no act-mods in dialogue), band 0..3 → `:next`
  index → next node. Rarity on the bands falls out of the distribution:
  band 3 (STRONG PASS) lines are the "rare" dialogue outcomes; the
  `:tier` gate on tree selection is the common/occasional/rare event mix
  the owner asked for. No nat-20 promotion (story convention, §1.3).
- Call order pinned: story-eval completes ALL its draws, then dialogue
  draws in file order (tree selection, then branch rolls depth-first).
  Both consume `:roll-pos`; sequence is fixture-pinnable like S4.
- One roll per branch, no re-rolls; one roll per opened tree total.

### 2.5 Firing rules (gates + budget)

Dialogue-eval (game layer, §1.1 slot) per tick, in order:
1. At most ONE tree opens per tick, and at most one conversation is open
   at a time (open trees finish before anything new opens).
2. A tree may open only when: current act ≥ `:act`; gate hook is in the
   gated state (`resolved` default — owner rule: nodes reference RESOLVED
   hooks; `:as pass|fail` may pin the verdict recorded in `:callbacks`);
   the `:pair` participants are alive and satisfy the STORY-ENGINE §3.4
   pairwise condition when the node declares one (default: both unseated
   this tick is NOT required — any pair, chosen deterministically).
3. Each tree carries `:cooldown N` (pinned default 60 ticks) and fires at
   most once per act unless `:once-per-game t` (loader-validated).

### 2.6 Delivery — non-modal, existing layers only

Dialogue emits ONLY `(:layer 'log :text … :face …)` intents — never banner
(the story banner budget stays ≤1/tick and dialogue cannot spend it), never
popup, never input. Lines carry severity `info` (existing Q13 enums — no
new face family; pair lines use the cast glyphs' worker faces where the
intent grammar allows it). The S1 browser shows them tick-stamped like any
other event — the owner's "delivery into the faced log/browser" is exactly
the S1 pipeline, no new surface.

### 2.7 Coherence guard-rails (loader + runtime, fail-first)

Loader errors (named, load-time) on:
- duplicate `:id` across dialogue entries; `:next` referencing an unknown
  or EARLIER-declared node (cycle kill); depth > 3 from any root;
- `:gate` hook id not present in the loaded scenarios' hooks, or gating on
  a hook of a LATER act than the tree's own `:act`;
- unresolvable `:line` keys through the §4.4 copy chain;
- dialogue entry with an `:effect` key at all (guard-rail by syntax);
- `:pair` selectors referencing an unknown quirk id or an unknown stat.
Runtime guards (asserted by tests): a gated tree never fires while its
hook is `open`/`armed`; no dialogue line contradicts act state because act
advance force-resolves hooks BEFORE dialogue-eval runs (§1.1 order) — a
node's gate reads post-rollover state; and dialogue never advances any
stream but 2, never touches rewards events, never spawns tiles.

### 2.8 Acceptance (dialogue-specific; numbered D1..D6, land red-first)

- **D1** Fixture: with `:roll-pos` pinned and a 2-cast state, one
  dialogue-eval tick opens the pinned tree, yields the pinned node
  sequence, and advances stream 2 by exactly (1 tree draw + n branch
  rolls); `rpg-pos` and `cistern-st-rng` untouched.
- **D2** A tree whose gate hook is `armed`/`open` does not fire; after the
  hook resolves, it fires on the next eligible tick; a `:as fail` gate
  does not fire on a `pass` verdict.
- **D3** A bank with a cyclic `:next` (node referencing an earlier
  declaration), a depth-4 chain, an unknown gate hook, or a dialogue
  entry carrying `:effect` each fail `cistern--banks-load` with a named
  error; the example dialogue bank loads clean.
- **D4** Two branches of the same node with the same stat but different
  pinned draws land in different `:next` nodes; band 3 is reachable only
  on margin ≥ +5 (distribution check over 1000 draws, all four bands hit).
- **D5** Delivery: dialogue lines appear in the S1 browser with tick
  stamps and info faces; ≤1 dialogue line per tick; a dialogue line never
  occupies the banner row; input during dialogue acts normally (no modal).
- **D6** Determinism: two full runs of seed S produce byte-identical logs
  including dialogue lines; rng-position guard (§5.6) covers stream 2
  across story-eval + dialogue-eval.

---

## 3. CONFLICT RESOLUTION — one ruling per disagreement

| # | Conflict | Ruling |
|---|---|---|
| 1 | SURFACE S3.2 makes `cache`/`event` tiles "story-event outcome" tiles, but STORY-ENGINE §6.4's effects whitelist has no tile effect — the two docs name each other without a legal path between them. | Extend the §6.4 whitelist by exactly ONE effect: `tile-place` (`:arg` = kind ∈ `cache | event`, cell = stream-2-picked floor cell, resolution kind pinned in the same `:arg` — part of the trajectory). `flood`/`rubble` stay sim-only (breach-driven and map-gen/demolish respectively); story can never spawn them. `event` tile resolution to `cache` is alloy-grant-shaped; to `flood` is hazard-family. |
| 2 | SURFACE S3.2 says the `!` event tile "stands 3 ticks … (see S5.5)", but S5.5 rules migrant countdown is a log line with NO tile. | S5.5 stands. Migrants never get a tile; the `!` tile is exclusively the story-event marker (placed only via ruling 1's `tile-place`). The S3.2 cross-reference is read as pattern symmetry, not dependency. |
| 3 | Stream-id claims: both docs already agree (0 reserved, 1 story-gen, 2 story-runtime, 3 RPG; generator ⊕0x6A6E outside the space) but dialogue would be a silent third consumer. | Ruling 1.2 table stands unchanged; dialogue is a NAMED stream-2 consumer through the same `:roll-pos`, ordered after story-eval's draws (§2.4). No new position field, no stream 4 claim. |
| 4 | STORY-ENGINE §1 "No heroes, no dialogue" vs the owner's branching-dialogue requirement. | Register scoping (§2.1): "no dialogue" bans quoted character speech; inter-NPC communication renders as institutional traffic (filed requests, routed reviews) in the same deadpan register. §1 gains this footnote in implementation docs; no rewrite. |
| 5 | Matrix residence: RPG §3.5 declares matrices as a domain const; STORY-ENGINE §4.3 folds bank matrices — two creation sites for one `(matrix-id . band)` hash. | ONE hash, ONE domain loader (§1.3): bank matrices folded by `cistern--banks-load`; RPG's two matrices declared as a domain const in bank-entry shape, installed at domain load. Matrix-id uniqueness is a cross-source loader check. |
| 6 | Copy-table key collision: RPG §8 proposes `badge-type-fmt . "ARMED: %s"`, which duplicates the existing live key `badge-armed . "ARMED: %s"` (src/cistern-domain.el:815). | `badge-type-fmt` is DELETED from the RPG plan. The existing `badge-armed` row composes the type name as its `%s` argument when a type is armed (one key, one badge row — S1/C1 geometry untouched). `refusal-place` stays: distinct message, same refusal family. Namespacing rule for all new keys: story hand copy under `(story . …)` prefixed `story-`; bank copy prefixed by bank id; surface keys as SURFACE lists (`legend-`, `teach-`, `log-`, `desc-`, `insp-`, `migrant-in-fmt`); RPG keys minus the deleted one as §8 lists. |
| 7 | Two band-stat tables: STORY-ENGINE §6.1 sim-state bands (`tolerance/integrity/standing`, −2..+2) vs RPG §1 rolled worker stats (FLOW/GRIT/NERVE/ARCHIVE, mod −4..+4 clamped −2..+2 by consumers). | Both exist, engines own their own: hook matrices use §6.1 sim-state bands (hooks are about the sector); dialogue branch rolls use the participant's RPG stat mod (nodes are about workers — the bridge the owner asked for: "participant stats/quirks"). Quirk `:context` keeps its STORY-ENGINE §6.1 role (matrix context selector for hooks) and adds nothing to dialogue. |
| 8 | Act-modifiers: STORY-ENGINE margin formula has `:act-mods`; RPG §3.3 has none (deferred §10.4). | Not a bug — scope split stands: act-mods apply to story hook matrices and dialogue tree matrices; RPG physiology checks never take them. Dialogue `:difficulty` may therefore drift by act via its matrix's `:act-mods` if authored; RPG DCs stay flat. |

---

## 4. DIRECTIVE BUILD ORDER (wave-ordered, R10 discipline)

Same discipline as TOP-30: every directive lands a red test first, ships the
minimal change, names size (S/M/L) and PROTECT constraints. Waves are the
owner's orchestration: wave 1 surface foundations (no narrative deps) →
wave 2 narrative core → wave 3 dialogue + integration + QoL leftovers.
Every directive inherits the §0 PROTECT block; only directive-specific
PROTECT interactions are listed.

### WAVE 1 — surface foundations (no narrative dependencies)

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|---|---|---|---|---|
| V4-01 | Log entries gain tick stamps (S1.1) | `cistern--log`/`cistern--log-sev` append `(LINE SEVERITY TICK)`; update the complete reader list (SURFACE S1.1 grep list: `cistern-view--log-tail`, `cistern-view--collapse-log`, restart-dedup, Q15 boot-line) in the same commit | A1.1: after 13+ events the oldest entry carries the stamp; collapse triple unchanged; all listed readers pass existing tests | S | S1 inspector (text unchanged); C2 (no copy change) |
| V4-02 | Log browser `cistern-log-mode` (S1.2/S1.3) | derive from `special-mode` in cistern.el; severity faces via palette, `T%-4d` prefix, `(x,y)` span propertization, `cistern--cmd-cursor-goto` use-case, `g` rebuild; keymap exactly per S1.3 table | A1.2–A1.6 (faces persist, RET jump lands the cursor, point survives round-trip, keymap table complete, no shadowing, ≤95 cols at tick 99999) | M | S5 non-modal (browser never gates); C2 (`log-header`, `log-jump-none`, `log-hint` keys) |
| V4-03 | Palette derivation pure function (S2.1/S2.2) | `cistern--derive-palette BG → PALETTE` in domain-adjacent pure file; role table; ratio guard with sat clamp | A2.1–A2.4, A2.6 (targets on dark/light/mid/black/white/red bgs; no runtime calls; no literal `:foreground` except cursor) | M | S2 pressure voice (words untouched, faces derived) |
| V4-04 | Palette application triggers (S2.3) | mode init apply, `enable-theme-functions` hook, drift guard one string compare in driver refresh | A2.5 (GUI probe pattern: registered, SKIPPED in batch) + refresh guard assert | S | frame-scoped attributes only (`cistern--own-frame`) |
| V4-05 | New tile kinds: rubble/flood/manifold (S3.2 sim half) | 3 `cistern--tile-table` entries, `cistern--add-hazard`-style flood spawner + decay, procgen rubble/manifold placement, passability consumers, build refusal on manifold, legend rows | A3.1, A3.3, A3.4, A3.5 (batch render-diff: flood pop-in shifts no wall column; pathing refuses rubble/flood; legend complete) | L | C3 L-076 (▚ 259A, ░ 2591, ╬ 256C all in-range); S4 purge ledger (flood decon reuses `cistern-cost-decon`) |
| V4-06 | New faces for new kinds (S3.2/S2 bridge) | `cistern-rubble/flood/manifold/cache/event` deffaces from S2 roles; `cistern-view--kind-faces`/`-descriptions` + inspector lines via copy keys | A3.6 + A3.1 (faces role-derived, inspector lines name state + fix verb) | S | S1 inspector; C2 (`desc-`/`insp-`/`legend-` keys); C3 |
| V4-07 | Emacs keybind aliases + coach (S4.1–S4.3) | driver bindings per S4.2 table, `cistern--cmd-cursor-scan`, `cistern--teach-pairs`/`cistern--teach-seen`, Q17 hint posting | A4.1–A4.3 (old map ∩ new map = identical actions; driven positions match table; 3rd-use coach fires once) | M | S5 (hint slot non-modal); C5 (coach NOT sim state) |
| V4-08 | Briefing regen + help sections (S4.4) | GLYPHS section generated from tile table; four reordered sections; browser key rows | A4.4, A4.5 (no hardcoded glyph list; ≤95 cols) | S | C2 (teach/help copy) |
| V4-09 | QoL wave-1 items (S5.1, S5.3, S5.5) | `.` repeat-last-successful-arm (driver echo var); death-panel `L — FULL HISTORY` dim line (`death-log-hint`); migrant `MIGRANT IN %d` log at T−3 (`migrant-in-fmt`) | A5.1–A5.3 (repeat refuses with no prior arm / after ESC; browser survives condemnation; countdown exactly once) | S | S3 popups; S5 non-modal; C2 |

Wave-1 ordering constraint: V4-05 before V4-06 before V4-08 (faces →
generated briefing); V4-03 before V4-06 (roles must exist); V4-02 before
V4-07 (coach references browser keys). All else parallelizable.

### WAVE 2 — narrative core (RPG + story engine; depends only on wave 1 surfaces for render/read paths)

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|---|---|---|---|---|
| V4-10 | RPG stat blocks (RPG §1/§1.1) | worker slots `:stats :xp :clearance`; state slot `rpg-pos`; 4d6-drop-lowest from stream 3 at spawn+migration; modifier floor((s−10)/2); clamps per §1 table | A1, A2 (fixture seed 20260830 → α F15 G15 N9 A14, rpg-pos 1156891213; 1000 rolls in [3,18]) | M | S1 inspector (segments later, V4-12); stream-3-only (guard A10) |
| V4-11 | Toilet catalog (RPG §2) | `cistern--toilet-catalog` const (5 types, glyphs/costs/ticks/suits/placement); `:type` in toilets hash; `cmd-build` cost+placement verdict; `T` cycles armed type + badge | A3, A4, A5 (suit classification; use_ticks_eff 1/2/3; high-cistern 14 alloy + refusals via copy-table line) | M | C2 (`refusal-place`, `badge-type-fmt` DELETED per §3.6 — reuse `badge-armed`); C3 (t/u/¶/¤/Ω glyphs — L-076 probe lines extended) |
| V4-12 | RPG checks + matrices + XP/clearance + inspector render (RPG §3, §4, §1.2) | exposure/composure/stride hooks in existing loops; `cistern--rpg-const` block; matrix const in bank-entry shape installed into the shared hash; XP ledger + CL.II/III unlocks; inspector stat/clearance segments with width degradation | A6–A9, A11, A13 (band-2 exposure blocks auto-sick; composure spike +10 can early-burst; stride only adds; matrix shape; XP 12/30 gates; ≤95 cols or drop stat segment) | L | S2 pressure voice (composure copy); S3 popups (clearance-up at the act); matrix loader per §1.3 ruling 5 |
| V4-13 | Envelope guard (RPG §5.4) | batch soak guard: window(w) = (120 − seek_eff)/2 − use_ticks_eff_max ≥ 22 for every worker; clamp asserts | A12, A14 (guard fails while clamps unpinned; 300-tick determinism hash incl. rpg-pos/XP) | S | §5.6 envelope guard itself |
| V4-14 | Banks loader + copy chain + example bank (STORY §4, §10) | `cistern--banks` defvar; `cistern--banks-load` with §4.3 validation list; `cistern--story-copy-key` chain (cistern--copy first, bank :copy second, resolved at load); `data/banks/example.el` | S2 loader acceptance (named load-time errors on bad kind/dup id/3-band matrix/out-of-span window/off-whitelist effect/unresolvable key; example bank loads clean) | M | C2 copy-table rule operational for generated data; fail-first pattern |
| V4-15 | Story generation (STORY §3) | `cistern--story-generate` pure (seed, banks) → story plist; premise/cast/acts/hooks per §3; `cistern--cmd-new-game` calls it after starter card; goal-mod through existing validator | S1, S9 (fixture plist; ≥3 distinct premises over 5 seeds; stream 1 only, cistern-st-rng unchanged; goal-mod ≤3 goals via existing setter) | M | S5 (no banks = legal no-op state for tests) |
| V4-16 | Story-eval wiring + rolls + effects (STORY §6, §7.5, §8.1–§8.3) | ONE call before rewards-eval (cistern-game.el:249 site); tier draw then roll, pinned order; §6.4 effects whitelist incl. `tile-place` (§3.1); intents via existing grammar; ≤1 banner/tick | S4, S6 (pinned tier/band/outcome; stream 2 advances exactly 2 per opened hook; 95-col capture; keypress during banner acts; no story symbol in view/input files) | L | S3 popups; S5 non-modal; rewards-eval sole drainer (reads events, drains none) |
| V4-17 | Coherence: act gating, callbacks, missed (STORY §7.1–§7.4) | force-resolve at rollover; `:requires`/`:callbacks` variants + `-fallback` keys; escalation = data only | S5 (window-close ⇒ missed with failure-band copy; no act opens on unresolved; HELD/BREACHED callback words render; fallback variant) | M | S2 voice; no fourth escalation mechanism |
| V4-18 | gen-bank script (STORY §5) | `tools/gen-bank.el` batch; stream ⊕0x6A6E; sorted emission; self-validates via loader; fragment pools minimal (§5.5) | S3 (byte-identical reruns; output reloads clean; distinct id sets across seeds) | M | batch-only; no interactive entry point |
| V4-19 | Matrix loader consolidation (§1.3, §3.5) | single domain install fn folding bank matrices + RPG const into ONE `(matrix-id . band)` hash; cross-source id uniqueness check | A9 extended: unknown matrix-id errors; both sources resolve through one gethash; id collision = load error | S | — |

Wave-2 ordering: V4-10 → V4-11 → V4-12 (stats → catalog → checks);
V4-13 after V4-12; V4-14 → V4-15 → V4-16 → V4-17 (loader → generation →
eval → coherence); V4-18 after V4-14; V4-19 after V4-12 and V4-14.

### WAVE 3 — dialogue trees + story-surface integration + QoL leftovers

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|---|---|---|---|---|
| V4-20 | Dialogue bank kind + validation (§2.3, §2.7) | fifth `:banks` slot; `:kind dialogue` routing; node shape; DAG-by-declaration-order, depth ≤3, gate/pair/effect checks; example dialogue entries in example.el | D3 (cyclic :next, depth-4, unknown gate hook, `:effect` present each = named load error; example loads clean) | M | C2 (bank :copy dialogue keys); fail-first |
| V4-21 | dialogue-eval (§2.4–§2.6) | ONE game-layer call after story-eval; tree selection by tier weights + drift; branch rolls via participant RPG stat mod; `:roll-pos` shared, pinned order; cooldown/once gates; log-intent-only delivery | D1, D2, D4, D5, D6 (fixture node sequence; gate discipline; band distribution over 1000 draws; browser tick-stamped info faces; ≤1 line/tick; byte-identical logs) | L | S5 non-modal (never banner, never popup, never blocks); stream guard extended to dialogue (D6) |
| V4-22 | Story-surface integration: tiles into narration (§3.1) | `tile-place` effect wired: story hook outcome places `event` tile → silent 3-tick countdown → resolves to pinned `cache`/`flood`; cache pickup banks alloy via popup-at-act path, logs success | A3.2 pattern for `?`/`!`; resolution lands the pinned kind; popup fires at the act; silent countdown (no logs) | M | S3 popups (cache pays through existing path); C3 (`?` 003F, `!` 0021 ASCII); S4 purge ledger untouched |
| V4-23 | QoL narrative leftovers + final determinism sweep | `M-f/M-b` structure scan includes manifolds (V4-05); death-panel full-history line verified to include story+dialogue lines; §5.6 guard suite green across all streams | A4.2 scan positions; A5.2 with narrative lines present; §5.6 guards (rng positions tick-for-tick vs no-narrative run; rewards-eval sole drainer) | S | all five soars re-probed once |

### 4.1 Wave summary

| Wave | Directives | Count |
|---|---|---|
| 1 — surface foundations | V4-01..V4-09 | 9 |
| 2 — narrative core | V4-10..V4-19 | 10 |
| 3 — dialogue + integration | V4-20..V4-23 | 4 |
| **Total** | | **23** |

### 5. ACCEPTANCE CRITERIA + CARRIED GUARDS (consolidated)

Per-directive acceptance lives in the tables above; the three source docs'
fail-first suites remain the detailed reference (SURFACE §S1.4–S5,
RPG-LAYER §6 A1–A15, STORY-ENGINE §9 S1–S9) plus §2.8 D1–D6. Consolidated
deterministic-envelope guards, carried forward verbatim and asserted by
V4-13/V4-21/V4-23:

1. **Bladder window ≥ 22 ticks** — window(w) = (120 − seek_eff(w))/2 −
   use_ticks_eff_max ≥ 22 for every worker, every soak run (RPG §5.4;
   base 28, worst case 22, provable from clamps alone).
2. **Story/dialogue never touch sim LCG or particle-rng** — `cistern-st-rng`
   and particle-rng positions equal a no-narrative run's tick-for-tick
   (STORY-ENGINE S7); RPG symbols never call `cistern--rand` (A10);
   dialogue confined to stream 2 via `:roll-pos` (D6).
3. **Rewards-eval stays the sole drainer** — story-eval and dialogue-eval
   read `cistern-st-rewards-events` and drain nothing (L-027); one stored
   intent 2-list, one render read.

### 6. FIRST FIVE TO BUILD (recommended start)

1. **V4-01** log tick stamps — one table-shape change, unblocks the browser
   and every later narrative read path.
2. **V4-02** log browser — the delivery surface dialogue and story lines
   flow into (D5 depends on it).
3. **V4-03** palette derivation — pure function, batch-redable today,
   unblocks V4-04/V4-06.
4. **V4-10** RPG stat blocks — unblocks the whole wave-2 chain and the
   dialogue stat bridge (§2.4); independent of V4-01..03.
5. **V4-14** banks loader + example bank — unblocks generation (V4-15) and
   the dialogue bank kind (V4-20); pure domain, no surface deps.

(1–3 are strictly sequential per the wave-1 ordering note; 4 and 5 are
parallel-safe against all of them.)
