# Cistern v6 — CONTROLS OVERHAUL

> DESIGN ONLY — no code.  Curator: design-controls.  Grounding:
> `src/cistern.el:66-113` (keymap), `src/cistern.el:377-431` (arm flow),
> `src/cistern-game.el` (`cistern--do-tick` pinned eval chain, L-027
> drainer contract), `docs/ux/TOP-30.md` (shipped R1 UX), the five
> SOARS (S1 inspector, S2 pressure voice, S3 popups-at-act, S4 purge
> ledger, S5 non-modal ceremony).

## 1. ADVERSARIAL REVIEW — what a hostile newcomer trips over

Findings A1–A10, ordered by how fast they cost a run.  Evidence cites
the shipped keymap (`cistern.el:66-113`) and the help text
(`cistern.el:630-691`).

| # | Finding | Evidence | Why it bites |
|---|---------|----------|--------------|
| A1 | **Alphabet soup: x / c / d.** Three destructive-or-restorative verbs with no family resemblance: `x` purge, `c` decon, `d` demolish. Nothing teaches which one applies to tanks vs hazard vs your own plumbing; the split (purge = tank only, decon = hazard/flood only, demolish = player-placed only) is invisible until a refusal log line. | keymap `x`,`c`,`d`; `cistern--cmd-demolish` refuses "NOT YOURS TO DEMOLISH" on terrain; PLAYING.md says "`d` clears it to floor" for rubble — one key, two costs, two semantics, three help entries. | A panicked player hits `d` on a hazard (refused), then `c` on their own dead pipe (refused), then reads the log. The clock never stopped. |
| A2 | **`K` for tank breaks the build family.** `t` toilet, `p` pipe — both lowercase initials — then `K` UPPERCASE for tank for no stated reason. The shift is a hidden case-mode, the worst kind of surprise for a single-key map. | keymap line 77 `K`; help "K build tank". | Newcomers try `t`, `p`, then guess `b` or `T` (which is something else entirely — see A3). |
| A3 | **`T` vs `C-t` split brain.** `T` cycles the armed fixture type; `C-t` skips the tutorial. Same letter, two unrelated powers, one of them on a Ctrl chord. In Emacs `C-t` is transpose-chars muscle memory; skipping the tutorial from a chord nobody would guess means `?` is mandatory reading. | keymap lines 89-90; help "T cycle fixture type / C-t skip tutorial". | The tutorial-skip is effectively ?-gated knowledge — the exact "requires the ? briefing" class. |
| A4 | **`H` for RALLY reads like a Vim-adjacent accident.** Shifted h sits next to where a h-j-k-l player expects fast movement, not a sector-wide worker order. The R2 tripwire keeps `hjkl` unbound, but `H` is the worst kind of adjacent: looks like a typo of an unbound key. | keymap line 86 `H`; COMBAT §4.5 pinned the letter, the tripwire pinned the neighbors. | Combat arrives and the player must already know the one capital letter on the left of the home row. |
| A5 | **`u` disarm means nothing and is one of THREE disarms.** `u`, ESC, and C-g all disarm. `u` invites "undo" reflexes — but there is no undo; demolish is the undo. Two of three bindings duplicate each other's job; the third lies. | keymap lines 92-93, 110; help "u cancel armed verb (ESC on GUI)". | A player who mis-builds hunts for undo, finds `u` (a disarm), and concludes the game has no undo — correct, but the journey costs ticks. |
| A6 | **`n` = new game with zero friction, and `n` means "next" in the log browser.** One unadorned keypress nukes a live run; the same key walks log entries one buffer over. No modal (S5 forbids one), so nothing catches the reflex. | keymap line 95 `n` = `cistern-new-game`; log-mode map `n`/`p` walk entries. | The most destructive verb sits on a browsing reflex key. |
| A7 | **`C-s` is capacity-jump in the game buffer and isearch in the log browser.** Same chord, two behaviors in two sibling buffers. The game-buffer use is defensible (it IS the grid's isearch) but is never framed that way; the help calls it "jump to nearest wired toilet". | keymap line 111; log browser help line "C-s search". | Emacs players fire C-s expecting a prompt; the cursor teleports instead. One framing sentence fixes this; today it is a jump-scare. |
| A8 | **Arm-then-place is a state machine you can't see.** `t` builds at the cursor AND keeps the verb armed for click-to-place (`cistern--arm-and-build` arms on success); a refused build does not arm. So one key means: place-here (success), armed-elsewhere (success elsewhere), refused (nothing armed, hint posted). Three outcomes, visible only via the header badge and a one-tick hint. | `cistern.el:402-416`; Q19 badge "ARMED: PIPE — CLICK PLACES, ESC CANCELS". | Keyboard-only players don't know a verb is still armed; their next "aim" click places a pipe. The armed state is invisible except in the badge they were never taught to read. |
| A9 | **Help claims `C-x z` repeats — it doesn't.** The briefing's power-layer section says "(emacs C-x z repeats, too)" but `C-x z` is not bound in `cistern-mode-map`; only `.` repeats. One false promise in the primary onboarding surface. | `cistern.el:688`; keymap lines 98-113 (no C-x z). | The player who trusts the briefing is wrong the first time they try it. |
| A10 | **Discoverability is one flat `?` wall.** Every binding lives behind `?`, grouped basics/power, but there is no in-game surface that reveals a *family* (all build keys, all combat keys) at the moment of need. The 3rd-use coach (S4.3) teaches individual verbs but never organizes them; the armed badge and hint slot are per-event. | `cistern--teach-pairs` (one hint per verb, one lifetime); `?` text is a single static block. | A player in a raid wants "what are my combat keys NOW"; the answer is ?-scrolling. |

**What already works (protect, do not touch):** the Emacs pairing layer
(C-n/p/f/b, C-a/e, M-<>, M-f/b) is genuinely idiomatic and was praised
in R1/R2 as "you already know these"; SPC/RET tick is roguelike-normal;
the 3rd-use coach and the Q17 hint slot are the right channels.  The
overhaul below reuses both rather than replacing them.

## 2. THE OVERHAULED KEYMAP

### 2.1 Layout principle: verb families, case as discipline

Single keys stay single (this is a roguelike at heart and `t`/`p` are
hot-path).  The overhaul fixes A1–A10 with three rules instead of a new
meta-layer:

- **K1 — Family by letter.** Build family is lowercase initials
  (`t` toilet, `p` pipe, `k` tank); field ops are lowercase initials
  (`c` clean, `d` demolish, `x` eXtract/purge); combat keeps `f` focus.
- **K2 — CAPITAL = sector-wide or destructive.** `R` rally, `N` new
  game.  Lowercase keys are local and repeatable; capitals change the
  whole sector or erase the run.  One sentence, teachable forever.
- **K3 — Mode/authoring lives under `C-c` (the special-mode prefix).**
  Everything that is not a game verb — tutorial skip, remap, rules
  authoring — lives under the mode's own prefix.  Nothing on a Ctrl
  chord that Emacs already means something by.

### 2.2 The map

| Group | Key | Verb | vs v5 |
|-------|-----|------|-------|
| Time | `SPC` / `RET` | advance one tick | unchanged |
| Time | `r` | auto-run 5 tps | unchanged |
| Time | `C-u r` | auto-run 1 tps | unchanged |
| Motion | arrows, `C-n/p/f/b` | cursor move | unchanged |
| Motion | `C-a` / `C-e` | row home / end | unchanged |
| Motion | `M-<` / `M->` | map corners | unchanged |
| Motion | `M-f` / `M-b` | next/prev structure | unchanged |
| Motion | `C-s` | capacity search (framed as "the grid's isearch" in help) | binding unchanged; copy fix (A7) |
| Build | `TAB` (alias `T`) | cycle armed fixture type | moves to TAB; `T` kept as alias (A2/A3) |
| Build | `t` | build toilet (at cursor; stays armed for click) | unchanged |
| Build | `p` | lay pipe | unchanged |
| Build | `k` | build tank | was `K` (A2) |
| Build | `.` | repeat last build | unchanged |
| Build | `C-x z` | repeat (real Emacs repeat, bound to repeat-arm) | NEW — makes the help's claim true (A9) |
| Field | `d` | demolish / clear rubble (help names both, costs differ) | binding unchanged; copy fix (A1) |
| Field | `c` | decontaminate hazard / dry flood | unchanged |
| Field | `x` | purge tank (pays) | unchanged — purge ledger is SOAR S4 |
| Combat | `f` | focus hostile | unchanged |
| Combat | `R` | rally workers | was `H` (A4); capital = sector-wide order (K2) |
| Mode | `C-g` / `<ESC>` | disarm | unchanged; **`u` removed** (A5) |
| Mode | `L` | log browser | unchanged |
| Mode | `?` | briefing | unchanged |
| Mode | `N` | new game | was `n` (A6); capital = destructive (K2) |
| Mode | `q` | quit window | unchanged |
| Power | `C-c C-t` | skip tutorial | was `C-t` (A3) |
| Power | `C-c C-r` | remap keys (§3) | NEW |
| Power | `C-c C-a` | automation rules browser (§4) | NEW |
| Power | `C-c C-e` | edit `data/rules.el` + reload (§4) | NEW |

### 2.3 Migration notes

- **No dead aliases.** Old bindings that moved (`K`, `H`, `n`, `C-t`)
  are unbound, full stop.  Two live maps = doubled collision surface in
  §3.  The migration path is the remap UI: "your old fingers: `C-c C-r`,
  rebind, done."
- **The coach teaches the move, once per game.** The existing
  3rd-use machinery (`cistern--teach-note`) gains four one-shot entries
  posted through the Q17 hint slot on first use of a *moved* binding's
  family: first `k` use posts `TANK IS k NOW — TAB CYCLES TYPE`, first
  `R` use posts `RALLY IS R — SECTOR-WIDE`, first `N` use posts
  `RESTART IS N — CAPITALS CHANGE THE SECTOR`, and a first-session
  banner line `KEYS CHANGED IN V6 — ? FOR THE NEW MAP`.  Copy through
  the table (Q11 rule), Nihei register.
- **`T` stays as TAB's alias** on purpose: it is not a moved binding
  (same verb), so no collision cost — and it respects that `T`-fingers
  are trained since v4-11.
- **A8 is softened, not solved, by design.** The armed model is
  load-bearing (L-010 pin 4, Q19 badge); the overhaul keeps it but the
  first-session coach line and the badge phrasing (`ARMED: PIPE —
  CLICK PLACES, ANY MOVE-AWAY KEEPS IT`) name the state machine in
  place.  Rejected alternative: at-cursor-only building with no arming
  — that deletes click-to-place, a shipped R1 surface.

**Least-active:** three rules + six moved keys; no prefix menus, no
which-key dependency, no second keymap.  Rejected: a full C-c prefix
keymap for game verbs (hot-path cost per build for zero legibility
gain).

## 3. THE REMAP SYSTEM

### 3.1 Key-table data shape (pure data, driver-owned)

The keymap is no longer hand-built `define-key` soup.  One defconst
table of `(VERB-NAME . KBD-STRING)` pairs — verbs are stable symbols,
keys are strings — plus one pure merge function:

```
cistern--key-table-default   ; the §2.2 map, as data
cistern--keys-override       ; runtime overrides from the remap UI (nil until loaded)
cistern--key-table-merge (table overrides) -> merged table   ; pure
cistern--keymap-from-table (table) -> sparse keymap           ; pure (no interactive)
cistern--key-collision-p (table verb new-key) -> REFUSAL-REASON or nil  ; pure
```

Domain-pure or driver?  **Driver-owned, pure-shaped.**  Keys have no
sim meaning; the table must not live in `cistern-st`.  But every
function above takes its inputs as arguments and returns values —
batch-testable without a buffer, per the D1 parameter-pin pattern the
input adapter already uses.  `cistern-mode-map` is built once from the
merged table at load and rebuilt on remap; `describe-mode` (C-h m) then
documents the live map for free — no second help surface to maintain.

Invariants (batch-asserted, §7):
- Every verb in the default table is bound in the produced keymap.
- No two verbs share a key in any merged table.
- No verb may be unbound: an override value of nil or `""` is refused
  (`REFUSAL-REASON 'must-keep-key`).  Simpler and safer than allowing
  disabled verbs; the Q17 hint machinery assumes every verb reachable.

### 3.2 Remap UX

`C-c C-r` (`cistern-remap`, interactive, non-modal):
1. `completing-read` over the verb table — prompt shows current key
   and one-line description, e.g. `Verb: build-pipe (p — lay pipe)`.
2. `read-key-sequence` — "New key for build-pipe (was p): ".
3. Collision check (§3.3).  Refusal posts through the Q17 hint slot
   and re-prompts; nothing is committed until clean.
4. Commit: update `cistern--keys-override`, rebuild the map, refresh.
   The coach posts one table-copy line — copy-table key
   `remap-reassigned`, Nihei register (`REASSIGNED — PIPE RESPONDS
   ON THE NEW KEY`), the exact wording owned by the copy-table sweep.

Rejected alternative: an in-buffer editable key table.  It is a second
UI to render, validate, and test; completing-read is free.

### 3.3 Collision detection (spec'd check)

`cistern--key-collision-p` runs against the WOULD-BE merged table
(current table minus the verb being remapped, plus the new binding) and
refuses when:

- **R1 live shadow:** the key is already bound to a *different* verb →
  refuse with `KEY IN USE — <VERB-NAME> HOLDS IT — REBIND IT FIRST`
  (hint slot; copy-table key `remap-collision`).  No auto-swap, no
  chained rebind — the player decides the order.
- **R2 no-op:** the key equals the verb's current key → refuse
  quietly (`remap-noop`), no hint spam, re-prompt.
- **R3 prefix clash:** the key is a prefix of an existing longer
  binding or vice-versa (matters for `C-c ...` power bindings) → refuse
  with `remap-prefix`, same channel.
- **R4 reserved:** the key would bind a game verb onto `C-c` itself or
  onto the tick keys' chord-space guard — refuse with `remap-reserved`.

Pure predicate: returns the refusal keyword or nil; the interactive
command owns prompting and hint posting.  All four branches
batch-tested on constructed tables (§7).

### 3.4 Persistence beside the banks

Same pattern as `cistern--ensure-story-bank` (the V4-15 install
wiring): a data file, an example constant, first-run copy.

- File: `data/keys.el`; example source `cistern--keys-example`
  (mirrors `cistern--bank-example`); loader `cistern--ensure-keys`
  copies the example on first run if absent, then loads.
- File content is exactly an override table:
  `(defconst cistern-keys-custom '((build-pipe . "p") (rally . "H") ...))`
  — same defconst-per-file discipline the banks use.
- Load order: `cistern` entry point → ensure-keys → merge → build map.
  Overrides merge ON TOP of the default table; unknown verb names in
  the file are ignored with one log line (`keys-unknown-verb`), so a
  v7 rename cannot brick loading.
- The remap UI writes the file on every successful commit
  (single `write-region`), so persistence is automatic — no separate
  "save" step to forget.

**Least-active:** one file, one merge fn, four pure predicates;
rejected: a custom.el fragment in user-emacs-directory (breaks the
repo's self-contained data/ convention and the batch tests' ability to
exercise the real file), and key translation tables (overkill).

## 4. THE AUTOMATION SYSTEM — the player's servant

Player-defined rules of the form **condition → action**, authored as
data, evaluated deterministically inside the tick pipeline.  The
servant invariant governs everything below: **an automation can never
do anything the player could not do manually** — same verbs, same
costs, same refusals, same log.  There is no automation-only code
path; the rule engine's action half is a lookup table from action
symbol to the EXISTING `cistern--cmd-*` use cases.

### 4.1 Rule data shape

A rule is a plist, stored in ST (§6 determinism), authored in
`data/rules.el`:

```
(:id purge-main
 :when (tank-load-ge 85)        ; condition term; may BIND a target cell
 :then (purge)                  ; action form
 :cooldown 0                    ; ticks between fires (default 0)
 :during-raid 'hold             ; 'hold | 'run (default hold, §5.3)
 :enabled t
 :stats (:fires 0 :refused 0 :last-fire nil))   ; maintained by the evaluator
```

`:when` selects AND binds: conditions that name a cell (`tank-full`,
`hazard-at`, `severed-pipe`) bind `(X . Y)` as the action target;
otherwise the action targets its own selector (`:then (purge :target
:bound)` default; `:target (x . y)` pins a cell; `:target 'any` lets
the action's own use-case pick).  Rules are list-ordered; list order
is the tie-break everywhere.

### 4.2 Condition vocabulary — reads only, existing query functions

Every condition compiles to a call the domain already answers.  No new
state reads; a condition that cannot be expressed today does not ship
until its query exists.  Pinned set:

| Form | Reads | Binds |
|------|-------|-------|
| `(tank-load-ge PCT)` | `cistern--tank-load` vs tank cap | the tank's cell |
| `(tank-load-total-ge UNITS)` | `cistern--tank-load-total` | — |
| `(tank-full)` | load ≥ cap | the tank's cell |
| `(pressure-rising)` | the Q08 gradient predicate (≥0.85 × Σ cap) | the max-load tank |
| `(contam-ge N)` / `(contam-le N)` | `cistern-st-contam` | — |
| `(hazard-count-ge N)` / `(hazard-at)` | cell scan; binds nearest hazard | the hazard cell |
| `(severed-count-ge N)` / `(severed-pipe)` | `cistern--severed-count` / dead-pipe scan | the pipe cell |
| `(worker-at-risk)` | bladder ≥ burst−10, per the pinned rate constants | the worker's cell |
| `(raid-open)` / `(raid-closed)` | `cistern-st-raid` state | — |
| `(event KIND)` | pending event kinds, read WITHOUT draining (story's own `:condition` reader, `cistern--story-condition-p` shape) | the event's cell, if it carries one |
| `(alloy-ge N)` / `(pop-ge N)` | `cistern-st-alloy` / creator count | — |
| `(tick-ge N)` | `cistern-st-tick` | — |

Compound conditions: `(and ...)` / `(or ...)` / `(not ...)`, depth ≤ 3
— enough to say "tank full AND alloy ≥ 5", not enough to write a
program.  No time travel, no negation over events beyond what the
pending list holds this tick.

### 4.3 Action vocabulary — the player's verbs, verbatim

| Form | Executes | Cost/refusal path |
|------|----------|-------------------|
| `(build-toilet)` / `(build-pipe)` / `(build-tank)` | `cistern--cmd-build` at the bound or pinned cell | catalog price, placement verdict, all existing refusals |
| `(demolish)` | `cistern--cmd-demolish` | fee, refund rules, in-use refusal |
| `(decon)` | `cistern--cmd-decon` | fee; hazard/flood only |
| `(purge)` | `cistern--cmd-purge` | pays per S4 ledger — untouched |
| `(rally)` | `cistern--cmd-rally` | walks are the sim's, as manual rally |
| `(focus)` | `cistern--cmd-focus` | guild-refusal included |

NOT in the vocabulary, and structurally unreachable: tick advance,
event drain, alloy grants, story/comedy/social/dialogue state, tutorial
skips, new game, anything touching the view.  The evaluator is a
closed lookup table of six entries; there is no `eval` of user code in
the sim path.

**The tick-advance subtlety, pinned:** a manual build advances exactly
one tick (place⇒one-tick coupling, L-010); an automated build happens
WITHIN the automation eval — it advances no extra tick and clears no
armed verb.  The automation is inside the clock, not a player.

### 4.4 Evaluation point in the tick pipeline

New slot in `cistern--do-tick`, PINNED ORDER:

```
tutorial-advance → sim-tick → AUTOMATION-EVAL → story-eval → social-eval
→ comedy-eval → dialogue-eval → rewards-eval (sole drainer, L-027)
```

Rationale, pinned:
- **After sim-tick** — automation reasons over the same post-sim state
  the narrative evals read; no double-advance, no mid-sim mutation.
- **Before story-eval** — so an automated purge fires its
  `automation-fired` event THIS tick and story/social/comedy see it
  (the machine's purge gets its comedy beat like a manual one).  The
  alternative (after narrative) would make automation acts invisible to
  the act that just rendered — a coaching lie (the S1 lesson).
- **Never drains pending events** — reads them via the same
  read-without-drain path story uses; rewards-eval stays the SOLE
  drainer (L-027).  Automation pushes its own events onto the pending
  list: `(automation 'fired RULE-ID ACTION)` and
  `(automation 'refused RULE-ID REASON)` — read by rewards-eval (score
  hooks later) and by meta-rules (§5).
- **No RNG anywhere.**  Zero stream draws in automation-eval; rule
  firing is a pure function of state.  The §5.6-style guard asserts
  rng positions tick-for-tick vs a rules-free run of the same seed.

### 4.5 Rate limits

- **≤ 1 automation action per tick, sector-wide.**  First eligible
  rule in list order with a legal target fires; the rest wait.  The
  cap is THE spam guard — no per-verb budget needed.
- **Per-rule cooldown** (`:cooldown`, default 0 ticks) applies to
  successful fires; a level-trigger rule (condition still true) re-fires
  after its cooldown, which is the desired shape for purge-at-85%:
  drain every tick the tank stays hot.
- **Refusal cooldown:** a refused action sets `:last-fire` with a
  refusal and silences the rule for 10 ticks (`automation-refusal-pause`,
  pinned constant).  No retry loops.

### 4.6 Failure story

Refusal → the rule's `:refused` count increments, ONE log line through
the copy table (`automation-refused`: `RULE purge-main REFUSED —
INSUFFICIENT ALLOY — RULE HELD 10 TICKS`, Nihei register), 10-tick
hold.  Refusals are data (`:stats`), not spam.  A rule that can never
succeed (its action is structurally illegal for its binding, e.g.
`(focus)` with no hostile at the bound cell) logs once and holds like
any refusal — same path, no special case.

### 4.7 The servant invariant, spec'd

Every automation action executes the identical use-case function the
manual path executes, with the same arguments the player would give.
Test (§7): for each of the six actions, drive two states — manual
invocation vs automation-eval of a one-rule file — from an identical
seed, and assert the state delta is IDENTICAL except for the manual
path's tick advance and armed-verb side effects.  Negative test: the
evaluator exposes no function that advances the tick, drains events,
or touches story state — a grep-able structural check in the source
integrity gate plus the delta test.

### 4.8 UI: the rules browser (`C-c C-a`)

A read-only temp buffer in the `cistern-log-mode` pattern: one line per
rule — `ID  WHEN  THEN  fires/refused  held?` — plus a header how-to
line from the copy table.  Keys: `e` toggle enable, `RET` jump to the
rule's `data/rules.el` line, `g` re-read the file, `q` close.  Rules
are authored in the FILE, not the browser (authoring is elisp — the
audience that writes banks writes rules).  `C-c C-e` opens
`data/rules.el`; on window-close the driver reloads and diffs the rule
set into ST, posting `RULES RELOADED — 3 ACTIVE` through the log.

**Least-active:** rules as plain plists in one data file, six-entry
action table, one eval slot.  Rejected: a rule DSL with its own
parser/targeter (the use cases already are the targeters), and
interactive rule construction (a modal editor in a non-modal game).

## 5. META-AUTOMATION — rules about rules

A second data layer that adjusts automations, never creates them.
Same shape, different vocabulary and a harder ceiling.

### 5.1 Meta-rule shape

```
(:id conserve-alloy
 :when (raids-recent-ge 2)      ; condition over AUTOMATION PERFORMANCE + sector state
 :tune (purge-main :threshold 90)   ; OR (:enable purge-main nil)
 :enabled t
 :stats (:fires 0 :last-fire nil))
```

One meta-rule adjusts exactly ONE parameter of exactly ONE rule:
`:threshold` (a numeric literal in the rule's condition), `:cooldown`,
or `:enabled` (t/nil).  Meta-eval runs ONCE PER 10 TICKS
(`meta-eval-every`, pinned) at the head of automation-eval — meta is
slow control, not a reflex.

### 5.2 Conditions over automation performance

| Form | Reads |
|------|-------|
| `(rule-fires-ge ID N)` / `(rule-refused-ge ID N)` | the rule's `:stats` counters, optionally windowed `(rule-fires-ge purge-main 5 :since 200)` over the rolling stat window |
| `(rule-disabled ID)` | the rule's `:enabled` |
| `(sector:contam-ge N)` / `(sector:raid-window-ge N)` | sector stats; `raid-window-ge` counts raid-open events in the last 40 ticks (the comedy dampener window, already tracked) |

### 5.3 Guard-rails, pinned bands

- **No creation.**  A meta-rule can only address a rule id that exists
  in `data/rules.el`.  A meta-rule naming an unknown id is refused at
  load (one log line, `meta-unknown-rule`) and never fires.  No
  meta-rule may add, delete, or rewrite a condition/action — `:tune`
  carries only `:threshold`/`:cooldown`/`:enabled`.
- **Pinned bands:** every tunable parameter ships a `(MIN . MAX)`
  band.  Initial bands: `tank-load-ge` threshold 50–95; `contam-ge`/
  `-le` thresholds 1–`cistern-contam-limit`; `severed-count-ge` 1–4;
  `cooldown` 0–20.  A tune outside the band CLAMPS to the band edge
  and logs ONCE per clamp (`TUNING CLAMPED — purge-main FLOOR 50`,
  copy-table key `meta-clamped`).  Bands are constants in the domain;
  they are not authorable.
- **Meta ≤ meta:** meta-rules cannot tune other meta-rules.  One level
  of control; recursion is where deadlocks are born.
- **Conflict rule:** two meta-rules tuning the same parameter — the
  LAST meta-rule in file order wins that tick (deterministic, no
  negotiation machinery).

### 5.4 Raids and the comedy-violence contrast

Per-rule `:during-raid` (default `'hold`): while a raid is open, held
rules suspend (condition true but evaluation suppressed) and resume at
raid close.  The default is the design statement — during the
Inheritors' visit the sector's fate is hands-on, and the contrast rule
(the comedy layer's S1 suppression) already goes quiet under fire;
the automation layer follows the same instinct.  `:during-raid 'run`
is the explicit, per-rule opt-in for players who want the thermostat
running under fire.  Meta-rules themselves default to `'hold` under
the same flag.  Story never reads meta-rules; comedy may READ
automation-fired events like any event (one new bank entry, the
self-toggling thermostat whimsey, optional — bank content, not
engine).

**Least-active:** ten-tick cadence, three tunable parameters, band
clamps.  Rejected: a general rewrite-expression meta-language (that
is a second rules engine — this is a settings robot).

## 6. DETERMINISM / INTEGRATION

- **Rules live in state.**  New ST slot `(automation nil)` holding the
  compiled rule list + meta-rule list + per-rule `:stats`.  Loaded
  from `data/rules.el` at new-game and at `C-c C-e` reload (a rules
  reload mid-game bumps the automation slot only; the sim does not
  know the file).  Same seed + same rules file ⇒ byte-identical runs.
- **Pure evaluation.**  `cistern--automation-eval (st)` — state in,
  state + intents out, zero stream draws, zero global reads.  The
  meta layer runs inside it on the pinned 10-tick cadence.  Everything
  in §4/§5 is a function of `cistern-st` fields only.
- **Drainer contract intact.**  Automation reads pending events via
  the story-style read-without-drain helper; pushes its own events;
  rewards-eval remains the SOLE drainer (L-027).  Guard test: run a
  rules-file soak and a rules-empty soak of the same seed and assert
  every rng position (`rng`, `particle-rng`, `rpg-pos`, story/social/
  comedy positions) is tick-for-tick identical — the automation layer
  is invisible to the streams.
- **Tick pipeline pin.**  The §4.4 order is a doctest-shaped pin:
  one test asserts automation-eval's events are visible to story-eval
  in the SAME tick (a rule that fires the tick a burst happens gets
  narrated), and that rewards-eval is still the only drainer.
- **Copy-table rule (Q11).**  All new strings — coach lines, remap
  refusals, automation fired/refused/held, meta-clamped, browser
  header — go through `cistern--copy`, Nihei register.  Coaching copy
  for the copy-table: the browser header and the four migration lines
  from §2.3.
- **The five SOARS, protected explicitly:**
  - S1 inspector standard — no rules surface changes any inspector
    line; byte-identical with the automation layer disabled.
  - S2 pressure voice — pressure-derived conditions READ the Q08
    predicate; they never emit copy; the RISING/CRITICAL lines stay
    byte-identical.
  - S3 popups-at-act — automated purges pay through the SAME
    popup-at-act mechanism as manual purges (same use case ⇒ same
    popup).
  - S4 purge ledger — `cistern--cmd-purge` is invoked, not re-implemented;
    the Q07 economy guard test applies unchanged to automated purges.
  - S5 non-modal ceremony — the rules browser and remap are temp
    buffers; no keypress anywhere blocks input; commit-first rules
    reload.
- **Batch-testability.**  Rule files are data; `cistern--automation-eval`
  is headless like the other evals; the scenario harness gains a
  `:rules FILE` step so driven scenarios can exercise automation
  without the GUI.  The remap table functions are pure (§3.1).
- **Input coaching stays out of sim state** (C5): migration coach
  lines and remap refusals are driver-ephemeral; only rules and their
  stats enter ST.

## 7. ACCEPTANCE CRITERIA — fail-first, per component

Each criterion fails before its component exists.  Batch unless marked
GUI-probe.

**Keymap (§2)**
- KM1: `cistern-mode-map` has `k`→tank, `TAB`/`T`→cycle-type, `R`→rally,
  `N`→new-game, `C-c C-t`→tutorial-skip; `K`, `H`, `n`, `C-t`, `u` are
  UNBOUND.  (Fails: today's map is the inverse.)
- KM2: `C-x z` runs `cistern-repeat-arm`.  (Fails: unbound today — A9.)
- KM3: batch render of the `?` briefing contains the case rule
  sentence, the isearch framing for C-s, and no `%%` escapes.
- KM4 (coach): first `k` press in a fresh game posts the
  `TANK IS k NOW` hint for exactly one render.

**Remap (§3)**
- RM1: `cistern--keymap-from-table` over the default table binds every
  verb exactly once; two verbs sharing a key in ANY table is an error
  at merge time.
- RM2: collision — remapping `build-toilet` onto `p` refuses with the
  named-verb reason; onto its own key refuses noop; `C-c` and a
  `C-c`-prefix refuse `remap-reserved`/`remap-prefix`.
- RM3: persistence round-trip — write override file, fresh load, keymap
  reflects the override; an unknown verb name in the file is skipped
  with one log line and does not brick the load.
- RM4: nil/empty-string override refused (`must-keep-key`).

**Automation (§4)**
- AU1 (pipeline): drive 30 ticks with a `tank-load-ge 85 → purge` rule
  over a seeded scenario; assert the exact fire-tick list, and that
  automation-fired events appear in the pending list the same tick and
  are drained only by rewards-eval.
- AU2 (servant invariant): for each of the six actions, manual-path vs
  automation-path delta identity from identical seeds (§4.7), minus the
  manual tick advance and armed-verb clearing.
- AU3 (cap): two eligible rules, one full tank — exactly one fires per
  tick, list order decides, the second fires next tick.
- AU4 (failure): rule whose action refuses (alloy < cost) — ONE log
  line, `:refused` = 1, no fire for 10 ticks, no retry loop over 40
  ticks.
- AU5 (vocabulary ceiling): source-integrity check that the action
  table names exactly the six use cases, and a state-delta test that
  no automation call changes `tick`, drains events, or touches story
  state.
- AU6 (soak): the deterministic auto-player soak re-run with a
  rules file survives ≥ the manual-strategy tick count.

**Meta (§5)**
- MM1: `raids-recent-ge 2 → :threshold 90` clamps at band floor/ceiling
  and logs the clamp once; the rule's threshold moves within 50–95
  only.
- MM2: a meta-rule naming an unknown rule id never fires and logs once
  at load; a meta-rule cannot create a rule (structural: `:tune` has
  no add/delete form).
- MM3: two meta-rules tuning one parameter — last-in-file wins,
  deterministic across replays.
- MM4: `:during-raid 'hold` (default) — a rule whose condition holds
  through an open raid fires zero times during it and resumes at close.

**Determinism (§6)**
- DT1: same seed, rules vs no rules — every stream position identical
  tick-for-tick; disabled-automation run byte-identical to v6-pre.
- DT2: automation-eval twice in one tick (forced) is idempotent given
  the cap — second call fires nothing.

**SOAR probes (once each, per house convention)**
- SP1–S5: inspector lines byte-identical without rules; pressure voice
  untouched; automated purge popup at the act; automated purge alloy
  delta matches the 1-per-3 ledger; the rules browser and remap never
  block input.

## 8. GENRE-APPROPRIATE QoL (summary)

Beyond the overhaul proper: TAB fixture cycling (completion reflex);
a real `C-x z` repeat; the case rule (`CAPITALS CHANGE THE SECTOR`)
as the one-sentence keymap philosophy; migration coaching through the
existing one-lifetime hint channel; the rules browser doubling as the
automation review surface; log-browser conventions (read-only temp
buffer, RET jump, q close) reused for rules and remap review.
Skipped, deliberately: a which-key-style popup (the `?` briefing plus
the coach cover it; a popup layer is new surface), a command-name
M-x-style palette (M-x already works for every interactive command —
nothing to build).
