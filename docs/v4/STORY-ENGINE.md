# CISTERN v4 — STORY GENERATION ENGINE (design only, no code)

Status: DESIGN v1, 2026-09-07. Consumed by the layered rewrite per
DESIGN-SPEC §3.3 (domain pure / game use-cases / view+input adapters /
driver) and REWARDS-DESIGN §5 (events, goal cards, intent routing).
Everything below survives the width contract (95 cols) and the copy-table
rule (Q11). PROTECTS: inspector standard (#10), pressure voice (#11),
popups-at-act (#13), purge economy (#14), non-modal ceremony (#17).

Owner intent, restated once: every session gets a procedurally generated
story from a bank of key words and scenario seeds (team-authored via
procedural scripts); D&D-style statistical rolls drive the storylines and
their events; character interactions run as lightweight procedural math
against PRE-HASHED MATRICES.

---

## 1. Register and the one governing rule

Voice: institutional deadpan (Blame! register). No heroes, no dialogue,
no exclamation. A story beat is a LINE the Sector's bureaucracy emits:
`SEALED PRESSURE LOGGED BEHIND WALL — WATCH ORDERED`. Checks are audits,
not saving throws (§6). Story copy is uppercase, terse, renderer-safe.

**The one governing rule — story is garnish, never sim:** story rolls
NEVER consume the sim LCG (`cistern-st-rng`), NEVER consume the particle
stream (`cistern-st-particle-rng`), and NEVER change core sim outcomes
(pathing, relief success, contamination arithmetic). Story randomness is
seed⊕stream child-stream randomness (REWARDS-DESIGN §4 discipline). The
trajectory stays a pure function of (seed, inputs); story simply makes
more of the trajectory exist. This is the same ruling REWARDS-DESIGN §1
made for rewards ("beating the game shouldn't rest on a whim of the RNG")
— beating the STORY also never rests on it: a missed story beat costs
nothing mechanical but its copy.

---

## 2. Layer ownership (one table)

| Concern | Layer | Shape |
|---|---|---|
| Story state (§3.6) | domain | one `cistern--story` field in `cistern-st` |
| Generation (§3) | domain | pure `(seed) → story plist`, streams only |
| Band stat queries (§6.1) | domain | pure `(st) → -2..+2`, read-only |
| Matrix lookup (§6.3) | domain | one `gethash` + band arithmetic |
| Banks: load + validate (§4) | domain | `(files) → cistern--banks`, load-time errors |
| Copy chain (§4.4) | domain | `cistern--copy` first, bank `:copy` second |
| Per-tick story-eval (§8.1) | game | `(st) → (st . story-intents)`, once per tick |
| New-game wiring (§3.1) | game | one call after starter card |
| Render routing (§8.3) | view | story intents ride EXISTING layers only |
| Bank files + generator (§5) | data/tools | pure data; batch script emits elisp |

Domain never references the view or driver; the view never calls
story-eval; input owns nothing (story is non-modal by construction).

---

## 3. Story spine — generation at new-game

### 3.1 Call

`cistern--cmd-new-game` (game layer), immediately after the starter goal
card is dealt, calls `(cistern--story-generate st)`. One call, pure:
`(cistern--story-generate st)` reads `(cistern-st-seed st)` and the
loaded banks, advances story stream 1 only, writes the story plist into
state. Same seed ⇒ byte-identical story (S1, §9).

### 3.2 Premise

One draw from the scenario bank (§4.2) selects the session's premise: a
hook set over three acts, a matrix set, a goal modifier, and the premise
copy key. The premise line is announced once at Act I open (log + banner,
§8.3) and never re-announced. Example (the test bank's premise):
`A SEALED SECTION REPORTS PRESSURE BEHIND THE EAST WALL`.

### 3.3 Cast

Two or three named workers star. Cast = (creators-list-index . quirk-id)
pairs drawn on stream 1 from the quirk bank (§4.3). Workers are named by
the existing shared identity helper (`cistern--worker-glyph`, Q14) —
story never invents names, so the map, the inspector, and every story
line agree on β being β.

Quirks are PRESENTATION + CHECK-CONTEXT only in v4: a quirk tags its
worker with (a) flavor copy on story beats involving them and (b) a
matrix context selector (§6.1). A quirk NEVER offsets a sim constant
(bladder rate, costs). Sim-param quirks are deferred (§11) — they would
couple story to balance and double the determinism surface for zero
procedural gain at this scale.

### 3.4 Character interactions = pairwise checks

"Complex character interactions with lightweight procedural math" is
implemented as pairwise beat conditions: when two cast workers satisfy a
hook's condition simultaneously (e.g. both past `cistern-bladder-seek`
while the nearest toilet is severed), the hook opens and resolves through
its matrix (§6) — one roll, one line, one whitelisted effect. No new sim
mechanics; interactions are READS of existing state, resolved by a
lookup. Cheap, deterministic, batch-assertable.

### 3.5 Acts and trigger windows

Three acts over the tick timeline; windows are pinned domain constants
(`cistern--story-act-ticks` — v4 pin: Act I 0–119, Act II 120–239, Act
III 240+; final pin at implementation, one defconst, testable). A session
ending early (condemnation, map completion) ends the story with it: the
death panel and ceremony are PROTECTED surfaces the story never touches.

- Act I — OPENING. Premise announced. Opening hooks (§7.1) arm.
- Act II — ESCALATION. Difficulty +`act-mods[1]`; rare-tier odds rise
  (§7.4); callbacks to Act I become available (§7.3).
- Act III — VERDICT. Highest modifier; the premise's terminal hook fires
  its verdict line regardless of play (resolved vs missed copy — both
  authored, so no premise can dangle, §7.2).

An act opens at its window floor only if the previous act is closed
(§7.2). Windows are trigger windows, not fences: a hook's own
`:window (a . b)` lives inside its act's span.

### 3.6 Story state (domain-owned, in `cistern-st`)

```
(story nil)  ; nil = no story (banks not loaded → generation is a no-op
             ; that logs nothing; new-game without banks is a legal state
             ; for tests). When set, a plist:
  (:premise-id ID
   :cast ((3 . quirk-worker-tight) (6 . quirk-structuralist))
   :act 1|2|3
   :hooks ((:id h :state dormant|armed|open|resolved|missed
            :resolved-as pass|fail|missed :tick N) ...)
   :callbacks (resolved hook-ids, visible to later acts)
   :roll-pos P)      ; stream-2 position, lives in state (like
                     ; particle-rng); generation used stream 1 once
```

No other story globals. Two state fields total (`story`, and the bank
registry `cistern--banks` defvar, §4.1) — least-active-decisions.

### 3.7 Story-specific goal modifiers

The premise's `:goal-mod` shapes the starter card at generation time:
either `:target-mod` ((kind . delta) applied via `cistern--goal-target`'s
existing tier arithmetic path) or `:swap-goal` (replace one goal kind
with another from `cistern--goal-kinds`). The card is re-set through the
EXISTING `cistern--cmd-set-goal-card` validator: still ≤3 goals, known
kinds only — story cannot smuggle a fourth goal or an unknown kind past
the fail-first check. Modifiers are announced as one line with the
premise (`WATCH ORDER AMENDED: %d SERVED`) so the card change is legible
on the same tick it commits (commit-first, Q26 discipline).

---

## 4. THE BANKS

### 4.1 Registry

`cistern--banks` (domain defvar, nil until loaded):
`(:scenarios (...) :quirks (...) :keywords (...) :flavor (...))` — each
slot a list of validated entry plists. Loading: `(cistern--banks-load
FILES)` in the driver before first new-game; each file is one
`defconst` of pure data (symbols, numbers, strings, lists — no
functions, no hash literals). The loader validates and folds entries
into the registry. Production ships generated bank files; the repo also
commits ONE small hand-checkable example bank for tests (§10).

### 4.2 Bank file format (uniform for all four kinds)

One file, one defconst, shape pinned:

```elisp
(defconst cistern-bank-scenarios-sealed
  '(:kind scenario :version "1" :generator "gen-bank 1.0 seed 8402"
    :copy ((story-sealed-premise . "SEALED PRESSURE BEHIND EAST WALL")
           ...)
    :entries (...)))
```

- `:kind` ∈ `scenario | quirk | keyword | flavor`. The loader routes on
  it; a mixed file is a load error.
- `:copy` — the bank's user-facing strings, keyed. See §4.4 for the
  copy-table rule reconciliation.
- `:entries` — kind-specific:

**scenario entry** (the story spine's payload):
```
(:id sealed-pressure
 :premise story-sealed-premise            ; copy key
 :acts 3
 :goal-mod (:target-mod ((relieves-served . 2)))
 :hooks ((:id seal-creak :act 1 :window (20 . 90)
          :condition (event leak) :requires nil
          :matrix pressure-verdict :resolve-copy story-seal-creak)
         (:id sealed-verdict :act 3 :window (240 . 99999)
          :condition (tick) :requires seal-creak
          :matrix pressure-verdict :resolve-copy story-sealed-verdict))
 :matrices ((:id pressure-verdict :difficulty 11 :stat integrity
             :act-mods (0 2 4)
             :outcomes ((:line-key k :effect none :arg nil) ...)))  ; 4
 :tiers (60 30 10)                        ; common/occasional/rare, act I
 :events ((:id ev-drip :tier occasional :trigger leak
           :matrix drip-verdict :copy-key story-drip)))
```

**quirk entry**: `(:id quirk-worker-tight :context tolerance
:copy-key story-quirk-tight)` — one matrix context tag + one flavor key.

**keyword entry**: `(:id kw-block :word "BLOCK-93" :class place)` —
generator-side naming tokens; class ∈ `place | sector | designation`.
Keywords appear ONLY inside generated `:copy` strings (the generator
substitutes them at generation time), never at runtime — runtime
rendering reads keys, never composes words (§4.4).

**flavor entry**: `(:id fl-condensation :when act-2 :copy-key
story-condensation)` — location flavor lines keyed to act openings.

### 4.3 Loader validation (fail-first, load-time errors)

`cistern--banks-load` walks every entry and ERRORS (named, load-time) on:
- unknown `:kind`, duplicate `:id` across a kind, empty `:entries`;
- a hook with `:act` outside 1..3, window outside its act span,
  `:requires` naming no hook of a STRICTLY EARLIER act (§7.3);
- a matrix with ≠4 outcomes, a `:stat` not in the pinned stat table
  (§6.1), `:act-mods` not length 3;
- an effect symbol outside the whitelist (§6.4);
- a `:premise`/`:resolve-copy`/`:copy-key` unresolvable through the copy
  chain (§4.4) AFTER folding the bank's own `:copy` in;
- a `:goal-mod` kind outside `cistern--goal-kinds` or producing a card
  the goal-card validator would reject (4 goals, unknown kind);
- tier weights that do not sum to 100 per act.

Malformed bank = load error, never a silent skip. This is the same
fail-first ruling as `cistern--cmd-set-goal-card`.

### 4.4 Copy chain (reconciling generated content with Q11)

Q11 PROTECT: "all new user-facing strings land in one string table in
the domain." Hand-authored story scaffolding (act banners, check framing
like `SYSTEM TOLERANCE CHECK — MARGIN %d`, verdict framing) lands in
`cistern--copy` under a `(story . ...)` section, exactly like every other
surface — one table, docs pass reviews it.

Bank-generated strings cannot live in a hand-authored defconst by
construction; they live in the bank's `:copy` section (generated DATA,
reviewed as data — same review surface, different file). One lookup
chain serves both, resolved ONCE at load, never per render:

`(cistern--story-copy-key KEY)` → `cistern--copy` story section first,
then bank `:copy` sections in load order, else load-time error. Every
key the loader sees is pre-resolved during validation, so per-tick cost
is an assq on a flat folded alist the loader built — no per-event
string hunting.

Width rule: rendering must survive 95 cols. Hand copy: authored ≤ the
existing surfaces' norms. Bank copy: generator keeps raw templates ≤60
chars (§5.4); the acceptance test asserts rendered story log/banner
lines fit the 95-col capture (S6).

---

## 5. Bank GENERATOR script

### 5.1 Interface

`tools/gen-bank.el`, batch only:
`emacs -Q --batch -l tools/gen-bank.el --eval '(cistern-gen-bank-run
:kind scenario :seed 8402 :count 4 :out "data/banks/scenarios-sealed.el")'`.
No interactive entry point. Exit 0 + silent on success; validation
failure of its own output = nonzero exit with the loader's error.

### 5.2 Determinism

The generator draws from `seed ⊕ 0x6A6E` (a fixed literal outside the
runtime stream-id space, §8.2) through the SAME `cistern--stream-next`
recurrence (required from cistern-domain — no second RNG). Same seed ⇒
byte-identical file. Entries are emitted SORTED by `:id` so regeneration
diffs are stable. Header comment records generator version + seed
(`:generator` field mirrors it).

### 5.3 Composition

Curated fragment pools live inside the script (NOT shipped as runtime
data): keyword fragments (place names in the register: BLOCK-93, SUMP
TERRACE), scenario skeletons (hook graphs over the pinned condition
grammar, one matrix per hook), quirk templates, flavor lines. The
script's job is combination under structural constraints — it composes
entries, substitutes keyword tokens into copy strings, and never emits
anything the loader would reject (it runs the loader on its own output
before writing; a rejected composition aborts the run).

### 5.4 Output hygiene

Pure data only (symbols/numbers/strings/lists); templates ≤60 raw chars;
keywords ≤10 display cols; every `%s` accounted for by the entry's
fields. Emitted file must load clean in `emacs -Q --batch` with the
domain and validate (that IS the post-check).

### 5.5 What is deferred (least-active-decisions)

The fragment pools ship with ~1 scenario skeleton, 4 quirk templates, 6
flavor lines — enough to prove the pipeline and seed the test bank.
Pool growth is content work, gated by nothing in the engine (§11).

---

## 6. D&D MECHANICS, REWORDED FOR THE REGISTER

### 6.1 Stats — banded, read-only, from existing state

No new per-worker stats. A "stat" is a band index (−2..+2) computed by a
pure domain query over the state the sim already keeps:

| Stat key | Register name | Formula (pinned at impl, one defconst each) |
|---|---|---|
| `tolerance` | SYSTEM TOLERANCE | ticks-to-burst of a cast worker: ≤6 → −2, ≤18 → 0, else +2 |
| `integrity` | STRUCTURAL INTEGRITY | severed-p → −2; backed-up → −1; tank load ≥85% → 0; else +2 |
| `standing` | INSTITUTIONAL STANDING | rep tier 1 → 0, tier 2 → +1, tier 3 → +2 (reads `cistern--reputation-tier`) |

The matrix's `:stat` selects which query runs; the quirk's `:context`
may override the matrix default (that is the whole quirk mechanic).

### 6.2 Roll and margin

One draw from stream 2 (`:roll-pos` in story state), through the pinned
mid-bits slice: `roll = 1 + (mod (ash pos -6) 20)`. The slice is a
shared ruling with RPG-LAYER §3.2 (their stream 3): the raw low bits of
the LCG recurrence cycle with short periods (low-bit d20s repeat
19,8,17,10), so every story draw — rolls, tier selection, effect cell
choice, generator composition — takes `(ash pos -6)` before the mod.
One rule, all draws, fixtures computed on the sliced value.
`margin = roll + stat − difficulty` where difficulty = matrix
`:difficulty` + `:act-mods[act−1]`. Band mapping pinned as domain
constants: margin ≤ −5 → CRITICAL FAILURE (band 0); −4..−1 → FAILURE
(1); 0..+4 → PASS (2); ≥ +5 → STRONG PASS (3). (RPG-LAYER adds
nat-20/nat-1 promotion pre-lookup on its stream — pre-lookup, so the
shared key shape and loader are untouched.)

### 6.3 PRE-HASHED MATRICES

"Pre-hashed": the loader (§4.3) folds every matrix into one domain hash
table keyed `(matrix-id . band)` at load time. Per-event cost is exactly
one band computation (two comparisons + an aref-free plist get) + one
`gethash` — no per-event hashing, no search. Lookup returns the
outcome plist `(:line-key K :effect E :arg A)`. A miss (matrix/band
absent post-validation is impossible — the loader guarantees 4 bands per
matrix) — lookup is total by construction.

### 6.4 Effects whitelist

Outcome `:effect` ∈ exactly:

| Effect | Verb | Notes |
|---|---|---|
| `none` | line only | the default; most beats |
| `log-line` | +1 log intent | variant copy (`:arg` = alt copy key) |
| `popup` | field popup | EXISTING popup mechanism at a named cell (Q06 channel) |
| `hazard-spawn` | `cistern--add-hazard` at stream-2-picked floor cell | the one contaminating effect; deterministic, part of the trajectory |
| `tank-load-delta` | ±N on one named tank's `:load` | pressure, not arithmetic: clamped 0..cap by the tank's own invariant |
| `alloy-grant` | +N alloy | reward direction only (no alloy theft — purge economy stays the lone alloy lever, Q07 PROTECT) |
| `beat-open` / `beat-resolve` | state machine moves (§7.1) | internal |

`hazard-spawn` and `tank-load-delta` are the only sim-visible effects;
both are pure functions of the seed's streams — the trajectory remains
replayable (S7). No effect touches workers' bladders, costs, or the
purge rate. Ever.

### 6.5 Check naming (register table)

Hand copy in `cistern--copy`: `SYSTEM TOLERANCE CHECK — MARGIN %d`,
`STRUCTURAL INTEGRITY AUDIT`, `INSTITUTIONAL STANDING REVIEW`, band
verdict lines. The MARGIN line is inspector-grade: it states the number,
the register states the verdict, nothing editorializes.

---

## 7. COHERENCE RULES

### 7.1 Beat state machine

Every hook: `dormant → armed → open → resolved|missed`.
- `armed` at its act open; `open` when `:condition` first holds inside
  `:window` (conditions: `(event KIND)` — a tick event of that kind;
  `(stat-band STAT OP N)` — a banded read; `(tick)` — terminal hooks).
- `open → resolved` exactly when its matrix is rolled (one roll per
  opening; no re-rolls). `armed → missed` when `:window` closes
  untriggered. A missed hook resolves with its matrix's FAILURE band
  outcome — copy exists for every terminal state, so no premise dangles.
- Terminal hook (`(tick)` condition, Act III) always fires its verdict.

### 7.2 Act gating — premises opened must resolve

An act opens only if every hook of the previous act is
`resolved|missed`. Enforcement is mechanical: at act rollover the
evaluator force-resolves any `armed`/`open` hook as `missed` (with its
failure-band copy), THEN opens the next act. The story can fall behind
the player; it can never fall apart.

### 7.3 Callbacks

A hook may carry `:requires` naming a hook of a strictly earlier act
(§4.3). Resolution reads the `:callbacks` list: requirement resolved →
the hook's resolve-copy renders its callback variant (the copy key's
format arg carries the earlier hook's verdict word: `HELD` / `BREACHED`).
Requirement missed → the hook still runs against its STANDALONE variant:
same matrix, `:arg` swapped to the fallback copy key (`-fallback` suffix
key the loader also validates). Callbacks are thus guaranteed-readable
in both branches — branching with no orphan text.

### 7.4 Stakes escalation

Exactly three escalators, all data: `:act-mods` difficulty bumps per act
(§6.2); tier weights shifting toward rare (`:tiers` is per the premise,
loader validates each act sums to 100 — scenario carries act-I weights
and pinned per-act shift constants in domain: `cistern--story-tier-drift`);
and the terminal verdict line. No fourth mechanism.

### 7.5 Sim events → story beats; event tiers

The per-tick event vocabulary (relief / burst / leak / demolish, plus
derived milestone/goal crossings inside rewards-eval) is the ONLY thing
that can open a beat: a hook's `(event KIND)` condition. So every story
beat traces to a real sim act — the story narrates the sanitation sim,
it does not compete with it.

Event tier selection (for hooks and `:events` alike): one stream-2
draw (sliced, §6.2) → cumulative weights (60/30/10 act I, drifting per
§7.4) → tier band. Tier selection and rolls draw from the same stream
in a pinned call order (tier draw, then roll) so the sequence is
fixture-pinnable (S4).

---

## 8. INTEGRATION & DETERMINISM

### 8.1 Tick wiring (one call site)

`cistern--do-tick` (game layer) currently ends
`(cistern--rewards-eval st nil)` (cistern-game.el:249). Story inserts
ONE call BEFORE it: `(cistern--story-eval st)`. Story-eval READS the
pending events (`cistern-st-rewards-events`) but NEVER drains them —
rewards-eval remains the sole drainer (L-027 wiring untouched). Story
returns `(st . story-intents)`; `do-tick` appends the intents to the
stored rewards-outcome's intent list before the view's next read — one
stored slot, one render read, zero new view query paths.

Story-eval runs exactly once per tick, after all sim phases (it reads
post-tick state: severed-p, tank loads, bladders). Its own ordering rule:
drain nothing, roll nothing unless a hook opens this tick.

### 8.2 Determinism rules

Stream ids pinned (0 reserved, REWARDS-DESIGN §4): **1 = generation**
(premise, cast, hook scheduling — consumed once at new-game), **2 =
runtime** (tier draws, rolls, hazard cells — `:roll-pos` in story
state). The generator's internal stream (`⊕ 0x6A6E`, §5.2) is outside
this space entirely. Sim LCG and particle stream are FORBIDDEN to story
code — asserted mechanically by S7 (rng positions unchanged across
story-eval).

### 8.3 Delivery — non-modal, existing layers only

Story intents reuse the intent grammar rewards-eval already emits
(cistern-game.el:362-436): `(:layer 'log :text … :face ENUM)`,
`(:layer 'banner :text …)`, popup particles via `cistern--field-spawn`.
Constraints pinned:
- ≤1 banner line per tick from story (rewards keeps its banners; the
  view's routing is untouched).
- Log lines carry severity enums the view already maps (Q13).
- Commit-first: every story effect (hazard, alloy, card mod) is applied
  to state at trigger time inside story-eval; delivery is presentation
  only. Any key keeps working — input is never blocked (Q26 guard).
- No new surface: no header segment, no modal, no dedicated story
  window. Premise and verdicts live in log + banner; pressure-flavored
  beats may reuse the popup channel at the acting cell (Q06).

### 8.4 Testability

Every rule is a pure function of (state, banks) or (seed, banks):
generation, band queries, roll/margin/band, matrix lookup, gating,
callbacks, tier selection. The example bank (§10) is small enough to
assert by hand in fixtures. New suite: `tests/test-story.el`, batch,
same harness as `test-4b-rewards.el`. Bank fixtures load from
`data/banks/example.el` — the only bank content shipped beyond the
generator's fragment pools.

---

## 9. ACCEPTANCE CRITERIA (fail-first; each lands red per R10)

| # | Component | Acceptance (failing-test phrasing) |
|---|---|---|
| S1 | Generation | Given seed S, `cistern--story-generate` returns a story plist equal to a pinned fixture (premise, cast pairs, hook states); across 5 distinct seeds ≥3 distinct premises; generation does not advance stream 2 and leaves `cistern-st-rng` unchanged. |
| S2 | Loader | A bank with an unresolvable copy key, a 3-band matrix, an out-of-span window, or an off-whitelist effect each fail `(cistern--banks-load …)` with a named error, in batch. The example bank loads clean. |
| S3 | Generator | `gen-bank` run twice with the same args writes byte-identical files; its output re-loads and validates through S2's loader; different seeds produce ≥2 distinct `:id` sets over 3 runs. |
| S4 | Checks | With `:roll-pos` at a pinned position and a pinned state, one story-eval tick yields the pinned (tier, band, outcome); the margin line matches `SYSTEM TOLERANCE CHECK — MARGIN %d` with the computed margin; stream-2 position advanced exactly 2 (tier draw + roll) for one opened hook. |
| S5 | Coherence | A hook whose window closes untriggered is force-resolved `missed` with its failure-band copy; an act never opens while the prior act has an unresolved hook; a `:requires` hook whose predecessor was missed renders the `-fallback` variant and the callback variant renders `HELD`/`BREACHED` from the recorded verdict. |
| S6 | Integration & non-modal | Driven tick: story log line + banner appear in the 95-col capture; all story lines fit width; during a story banner a keypress acts normally (no modal state, Q26 pattern); view symbol scan shows no story call in view/input files. |
| S7 | Determinism guard | Full N-tick run from seed S: `cistern-st-rng` and particle-rng positions equal a no-story run's positions tick-for-tick; state hash after N ticks equals the pinned fixture; two identical runs byte-match. |
| S8 | Copy rule | Static check: no story string literal outside `cistern--copy` (story section) and bank `:copy` sections; every bank key resolves through the §4.4 chain at load. |
| S9 | Goal mod | A premise with `:target-mod` yields a starter card whose target equals the tier-modified target + delta, still ≤3 goals, validated by the existing setter; invalid goal-mod is a load error (S2). |

---

## 10. EXAMPLE BANK (the one shipped content artifact)

`data/banks/example.el` — loadable by the test suite; also the loader's
first fixture. Size target: 1 scenario, 2 hooks, 1 matrix, 3 quirks,
2 flavor lines, 5 copy keys. Sketch (final values at implementation,
fixture-pinned):

```elisp
(defconst cistern-bank-example
  '(:kind scenario :version "1" :generator "hand (test fixture)"
    :copy
    ((story-sealed-premise . "PRESSURE LOGGED BEHIND EAST WALL")
     (story-seal-creak . "WATCH ORDERED — SEAM (%d,%d) UNDER OBSERVATION")
     (story-seal-creak-fallback . "SEAM (%d,%d) NOTED — NO WATCH ASSIGNED")
     (story-sealed-verdict . "SEAL VERDICT: %s — WATCH DISBANDED")
     (story-condensation . "CONDENSATION ON UPPER TERRACE — NOTED")))
  "…(entries omitted here; the fixture file carries the full shape of §4.2)…")
```

Nothing else is authored: the fragment pools in `tools/gen-bank.el` ship
minimal (§5.5), production banks come from the generator, and the docs
pass reviews bank `:copy` sections as data (§4.4).

---

## 11. DEFERRED (explicitly not pinned now)

1. Sim-param quirks (§3.3) — story-touchable bladder/cost constants.
   Return only if cast flavor proves insufficient without them.
2. Cross-session story (premises that recall previous maps' verdicts in
   later sessions) — needs a persistent story ledger; v4 stories die
   with their session like goal cards do.
3. Fragment pool growth, more scenario skeletons, named-settlement
   keyword classes — content, gated by nothing.
4. Story in the run-summary/death panel (Q22/Q23) — those panels are
   PROTECTED surfaces; a story epitaph line is a v5 question.
5. `contam`-reading hooks beyond `stat-band integrity` — the condition
   grammar is closed in v4; widening it is a loader change with new
   validation, not a free extension.
