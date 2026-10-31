# CISTERN v5 — SOCIAL SIMULATION LAYER (design only, no code)

Status: DESIGN v1, 2026-09-07. Consumes DESIGN-SPEC §3 (layers), the domain
sim (`src/cistern-domain.el`), RPG-LAYER (stat blocks, banks, copy chain,
width degradation), STORY-ENGINE (hooks, pending-event read rule, bank
format), V4-SPEC §2 (dialogue: the institutional-traffic register ruling),
and the v5 sibling designs — COMBAT (goblins are first-class domain
entities; stream 4 is theirs) and COMEDY-DIRECTOR (beat insertion slots
after social-eval). Everything below lands red-first per R10. No code in
this doc.

Owner intent, restated once: just about any object or NPC should be
capable of thoughts of various kinds — private for player review, muttered
for other NPCs to hear, or truly silent urges visible only through the
entity's ACTIONS. Anthropomorphism is A-OK for just about anything.
Romance between workers and the environment, workers and animals, workers
and enemies, workers and pests, workers and inanimate objects — or
romance between just about any two individual things in the game. Nothing
here disturbs the sim's determinism or the five protected soars.

Governing constraints, binding on every section:

- Five soars: S1 inspector standard · S2 pressure voice · S3
  popups-at-act · S4 purge economy · S5 non-modal ceremony.
- 95-col width contract on every rendered surface (L-076 discipline).
- Copy-table rule Q11: player-facing strings live in `cistern--copy`;
  bank copy lives in bank `:copy` sections; one resolution chain
  (`cistern--story-copy-key`), resolved at load, never per render.
- Batch-testable: every rule is a pure integer function of
  (state, banks, pending events, stream position).
- least-active-decisions: two new state hashes, one new stream position,
  one new eval slot. Nothing else on `cistern-st`.
- Tone: anthropomorphism is DEADPAN. The institution treats a toilet's
  feelings as a maintenance line-item, never wacky. No heroes, no
  exclamation, no whimsy outside the register.

---

## 1. THE PERSONA LAYER

### 1.1 Entity census — who thinks

Every entity with a stable identity gets a persona. The id protocol is
one defconst total order (workers < goblins < fixtures < tanks <
structures) that also sorts romance pair keys (§2.1):

| Species | Id form | Identity source |
|-----------|----------------|-----------------------------------------------|
| worker | glyph symbol α–θ | `cistern--worker-glyph` (Q14 — one helper, no new names) |
| goblin | symbol `g<N>` | COMBAT `hostiles` plist (stable ids, read-only) |
| fixture | `(:toilet X Y)` | the toilets hash key |
| tank | `(:tank X Y)` | the tanks hash key |
| structure | `(:structure X Y)` | a map cell key — ore veins, the manifold, wall segments |

Structures are persona-eligible only when a bank entry grants the species
content (§4.4): the manifold and specific wall segments CAN think, but
ship bank-optional — no default structure persona exists until a bank
provides one. Pests are a reserved species id; the persona/romance
machinery accepts them the day a sibling design lands the entities, and
nothing in this doc needs them to.

### 1.2 Persona shape

One new state hash: `personas` — entity-id → plist

    (:species S :quirks (Q...) :ledger (ENTRY...) :urge U :urge-tick T)

- `:quirks` — 1–3 ids drawn from the quirk bank at persona spawn, stream
  5, pinned draw order: one count draw (d6: 1–2 → 1 quirk, 3–4 → 2,
  5–6 → 3), then that many bank selector draws over the species-filtered
  bank (§4.4). Spawn points: workers at `cistern--new-game` (after
  story-generate), goblins at hostile spawn (COMBAT's hook calls the
  domain persona-spawn), fixtures/tanks at build time, structures at
  first bank-granted sighting.
- `:ledger` — newest-first list of `(TICK CHANNEL COPY-KEY)`, PRIVATE
  thoughts only, cap 3, FIFO eviction. Private lives are short, like
  visits.
- `:urge` — the silent-urge flag (§1.5), stamped with `:urge-tick`;
  cleared by social-eval one tick later. Nothing else clears it.

Mood is DERIVED, never stored — one pure banding function per species
over state that already exists (§1.3). No mood field anywhere: a mood
that must be remembered is a thought, and thoughts have a channel.

Quirks remain PRESENTATION + CHECK-CONTEXT only (the STORY §3.3 ruling,
extended): a quirk selects thought-copy variants and matrix context. A
quirk NEVER offsets a sim constant. The quirk bank kind gains one
optional field `:species` (worker|goblin|fixture|tank|structure|any);
absent = any. The loader validates it (fail-first, load-time error).

### 1.3 Mood — the derived enum

| Species | Bands | Sources (existing reads only) |
|-----------|-------------------------------|------------------------------------------------|
| worker | NOMINAL / STRAINED / CRITICAL | bladder ≥ 100 STRAINED; ≥ 110 or sick CRITICAL |
| fixture | NOMINAL / STRAINED / CRITICAL | `cistern--toilet-state`: busy; backed-up; severed |
| tank | NOMINAL / STRAINED / CRITICAL | load: < 50% / ≥ 50% / ≥ 85% of `cistern-tank-cap` |
| goblin | mapped from COMBAT `:state` | one defconst — combat owns facts, social banding |
| structure | always NOMINAL | the manifold does not stress; it IS stress |

Mood gates thought selection (§1.4) and the inspector word (§4.5). It
never touches a sim number.

### 1.4 Thought generation — one trigger table

`cistern--social-thoughts st` (game layer, §4.2 slot) runs once per
tick. Inputs: the pending rewards-events (READ, never drained — the
story-eval ruling, L-027 untouched) and post-tick state. The trigger
table is one domain const; rows are (event × species × mood → thought
class):

| # | Event | Species | Mood gate | Thought class |
|-------------------------------------------|----------|----------|-----------------|
| 1 | breach at (X,Y) | fixture within Chebyshev 3 | any | fixture-flood |
| 2 | breach at (X,Y) | worker witness (≤ 3) | any | nerve-flood |
| 3 | bladder crosses 110 | worker self | CRITICAL | nerve-pressure |
| 4 | relief served | fixture used | any | fixture-served |
| 5 | tank load crosses 85% | tank | CRITICAL | tank-strain |
| 6 | purge executed at tank | tank | any | tank-purged |
| 7 | adjacent entity destroyed (demolish, death) | any | any | loss |
| 8 | goblin death within 6 of a guild goblin | goblin (guild) | any | guild-mourning |
| 9 | warband mock (§3.2) | goblin (warband) | any | faction-mock |
| 10 | romance stage transition (§2.4) | both partners | any | romance-stage |
| 11 | worker idles adjacent to an attached entity | worker | NOMINAL | fond-proximity |

Selection is deterministic: all rows whose event fired this tick, capped
— ≤ 1 thought per entity per tick, ≤ 4 thought generations sector-wide
per tick, over-cap kept in row order (no tie-break draws). CONTENT is
one stream-5 draw selecting the bank entry for (thought-class, species,
mood), quirk-tagged variants preferred when the entity carries a
matching quirk. No polling, no timers, no idle chatter: no trigger row,
no thought.

### 1.5 The three delivery channels

- **PRIVATE.** Appended to the persona `:ledger` as
  `(TICK 'private KEY)`. Rendered ONLY by the inspector when the cursor
  rests on the entity (§4.5). Player-only by construction: no other
  surface reads the ledger, and other NPCs never read each other's
  ledger (they hear mutters, not thoughts).
- **MUTTERED.** Rendered into the faced log as quoted speech — the ONE
  sanctioned quotation in the register (owner override of the
  no-quotation ruling, scoped to muttering):
  `WORKER α MUTTERS — "FIXTURE 5, YOUR LOAD IS NOTED"`. Goblins and
  workers quote; fixtures, tanks and structures do not speak — they
  FILE: `FIXTURE (12,5) FILES A CAPACITY COMMENT`. Every muttered line
  simultaneously pushes `(:social 'mutter :speaker E :key K)` into the
  pending events the story engine reads without draining — muttering is
  a coordination event hooks can open on (the dialogue engine's
  inter-NPC traffic, V4-SPEC §2.1, is the same register).
- **SILENT URGE.** NO text anywhere. Sets `:urge`, cleared next tick.
  The urge becomes ACTION through pinned mappings, all through existing
  primitives:
  - fixture urge → render flash: the view derives a blink of the busy
    countdown from `:urge` (a render toggle; deterministic, state-free).
  - worker urge → ONE extra idle step via the existing
    `cistern--shuffle`, only when the worker has NO journey. Pathing
    targets, seating, and the bladder envelope are unreachable by
    construction.
  - goblin urge → a flag COMBAT may read (§3); social itself emits one
    particle via `cistern--field-spawn` with a PINNED constant velocity
    (no draw — the particle stream is untouched).
  - structure urge → none. The manifold communicates exclusively through
    its state; an urge with no available action is suppressed silently —
    thinking without saying is legal.

### 1.6 Budget guards — thoughts never spam the log

- ≤ 1 thought per entity per tick; ≤ 4 thought generations sector-wide.
- ≤ 2 muttered log lines per tick, sector cap; over-budget mutters
  downgrade to private (row order — deterministic, no draws).
- Private ledger cap 3 per entity.
- Urges: ≤ 1 per entity per tick, ttl 1 tick.
- Muttered/filed lines carry severity `info` and reuse existing faces —
  no new face family (the Q13 grammar holds).

---

## 2. ROMANCE — the relationship graph

### 2.1 Pairs

One new state hash: `relationships` — SORTED-PAIR key → plist

    (:stage 0..3 :score N :since TICK :cross-faction BOOL)

Pair key = `(id-a . id-b)` with the two ids ordered by the §1.1 total
order (deterministic sort, no canonicalization draws). Any two DISTINCT
living entities may pair — worker↔toilet, goblin↔ore-vein, worker↔
hostile-goblin, tank↔tank. Faction is irrelevant to ELIGIBILITY (§3.3);
it is recorded (`:cross-faction`) only to route friction rows.

### 2.2 Stages — institutional rewording

| Stage | Register name | Reading |
|-------|----------------------------|-----------------------------------------------|
| 0 | FILED | an acquaintance is on record |
| 1 | CROSS-REFERENCED | familiar; proximity noted in the margins |
| 2 | CO-SIGNED | attached; the pair files jointly |
| 3 | ANNOTATED IN THE MARGINS | partners; the annotations are private |

Stage is monotonic per pair — no decay, no breakup. The institution does
not retroactively unfile paperwork; death closes the file (§2.6).

### 2.3 Progression — proximity, shared events, roll gates

Score accrues only from:

- **Proximity ticks:** both entities on the map and within Chebyshev 2
  → +1 per tick. Proximity is a READ of existing positions; nothing
  moves because of it.
- **Shared events** (+2 each, all reads of events that already fired):
  both within 3 of a breach that resolves; both purged by the same
  player purge action (the purge is a team-building exercise); both
  served by the same relief; co-targets of the same demolish. Points
  land in the tick the event fires — no deferred queues.

**Gates.** When score first reaches a stage threshold — 10 / 40 / 80
(`cistern--romance-thresholds`, one defconst) — one gate roll on stream
5: `margin = d20 + audit-mod − DC`, DC 8 / 12 / 16 (`cistern--romance-dcs`).
The audit-mod: a worker partner contributes its ARCHIVE modifier
(paperwork is a filing skill); non-worker pairs file blind (+0); a
co-signed pair gains +1 on later gates (the partnership files better
paperwork — diegetic flavor, zero sim effect). Band per the shared
`cistern--margin-band`: ≥ 2 advances; ≤ 1 stays and the gate re-arms at
score + 5 (one roll per subsequent crossing). Rolls fire only at
crossings, never per tick — a stalled courtship costs ≤ 1 draw per 5
score. Pairing itself (stage 0 FILED) needs no roll: the first score
point files the pair.

### 2.4 Stage transition outputs — every one a story beat + a batch fact

On advance, exactly three things happen:

1. One deadpan log line (§4.6): `α AND FIXTURE (12,5) ARE
   CROSS-REFERENCED — PROXIMITY ON RECORD`.
2. `(:social 'romance-stage :pair P :stage S)` pushed into the pending
   events the STORY-ENGINE reads without draining — a scenario hook may
   carry `(event romance-stage)` conditions in the existing grammar.
   Romance beats are story beats.
3. Thought-class `romance-stage` fires for both partners (§1.4 row 10).

Batch-testable by construction: a transition is pure integer math over
(score, gate draws) plus one hash mutation and one event push —
asserted headless with pinned fixtures (§5, §6).

### 2.5 Guard-rails

- **NO sim numbers.** Romance never touches bladder, costs, purge,
  pathing, movement, contamination, or combat stats. Its effects are
  diegetic: copy, thoughts, hooks, render. Pinned assertion: the state
  hash of every sim field is identical before and after a transition.
- **Cap:** ≤ 2 attachments per entity (stages ≥ 2 count; FILED is
  unlimited — everyone is filed). A third attachment is refused at gate
  time WITHOUT consuming a draw (refusal is not a roll).
- **No triangle state.** Relationships are pairwise only; no n-ary or
  shared state exists to explode.
- **Bounded cadence.** Re-arm +5 caps a stuck gate at one draw per 5
  score; the cap rule caps attachments at 2 per entity; sector-wide the
  relationship hash is O(entities²) worst case but grows only on
  proximity — no scan, no per-tick iteration over non-proximate pairs
  (gate checks fire on score-crossing events only).

### 2.6 Termination

When an endpoint ceases (worker death, goblin death or retreat, fixture
demolished, tank removed): the entry is deleted. If stage ≥ 2, one
closed-file log line (`THE FILE OF α AND FIXTURE (12,5) IS CLOSED —
SEE OBITUARY`) plus a `loss` thought to the survivor (§1.4 row 7). No
ghost state, no dangling pair keys — batch-asserted after any entity
removal.

---

## 3. CROSS-FACTION — goblins in the social fabric

### 3.1 Full personhood

Goblins — warband AND guild, per COMBAT — are full social entities:
personas at hostile spawn (§1.2), thought rows (§1.4), romance endpoints
(§2.1). Social READS faction, glyph and `g<N>` id from the `hostiles`
plists and WRITES nothing to combat state or `combat-pos`. A worker and
a HOSTILE goblin may pair like any other pair — star-crossed
maintenance romance is exactly the register, sold as a cross-
departmental liaison with a department nobody will acknowledge.

### 3.2 Faction friction — behavioral, diegetic

- On a cross-faction stage transition to stage ≥ 1, every warband goblin
  within Chebyshev 6 of the attached goblin fires `faction-mock`
  (§1.4 row 9), rendered as FILED OBJECTIONS — the warband does not
  heckle, it routes paperwork: `GOBLIN g2 OBJECTS TO g4's LIAISON —
  REVIEW DUE`. Mocks are coordination events (§1.5 muttered channel)
  and are capped by the §1.6 budgets like any mutter.
- A COMBAT raid whose target cell is the beloved entity's cell pushes
  `(:social 'star-crossed-raid :pair P :at (X . Y))` into the pending
  events — a story event: the social layer emits it, the story engine
  opens the beat, COMBAT resolves the raid. Social never modifies raid
  targeting; the read direction is combat → social only.
- Guild goblins carry no friction rows. The Guild of the Open Flange
  does not judge; it co-signs.

### 3.3 Hostility never blocks romance

Faction affects WHICH THOUGHTS fire and WHICH HOOKS OPEN — never
whether a pair may file. The warband's objection is paperwork, not a
veto. No social rule reads HP, targets, or attack state.

---

## 4. DETERMINISM & INTEGRATION

### 4.1 Streams

Stream **5** (seed ⊕ 5), position `social-pos` on state — pos-in/pos-out
like every child stream, mid-bits slice `(ash pos -6)` on every draw
(the STORY §6.2 = RPG §3.2 ruling, one rule, all engines). Allocation:
0 reserved · 1 story-gen · 2 story-runtime · 3 RPG · 4 COMBAT ·
5 SOCIAL · 6+ free. The bank generator's ⊕ 0x6A6E stream is outside the
space. Social code never touches the sim LCG, the particle stream, or
any other engine's position field — mechanically asserted (§5, SC10).

### 4.2 Tick wiring — one call site

Pinned order:

    story-eval → social-eval → comedy-eval → dialogue-eval → rewards-eval

- social-eval runs AFTER story-eval (it reads story-opened state and
  the pending-event list the story pass may have extended) and BEFORE
  dialogue-eval (dialogue reads un-gated nodes; a muttered event this
  tick is visible to it). COMEDY-DIRECTOR slots directly after
  social-eval so stage transitions and thoughts it reacts to are fresh.
- social-eval READS `cistern-st-rewards-events`, NEVER drains —
  rewards-eval stays the sole drainer (L-027 wiring untouched).
- Social emits ONLY `(:layer 'log ...)` intents, `(:social EVENT)`
  pushes, persona/relationship mutations, and field-spawn particles —
  never banner (the story banner budget is untouchable), never popup
  (S3), never input (S5).

### 4.3 State — the complete list of additions

On `cistern-st`: `personas` (hash), `relationships` (hash),
`social-pos` (integer). Nothing else. Both hashes are pure domain state;
every mutation happens inside the social eval or at the pinned spawn
hooks, so the trajectory stays a pure function of (seed, inputs) —
two runs of one seed produce byte-identical personas, relationships,
and `social-pos` (§5, SC11). Social-disabled runs (banks absent) are
legal no-ops: nil hashes, zero draws, byte-identical sim — COMBAT stays
solvable with social off, and vice versa.

### 4.4 Banks + generator

- New bank kind **`thought`**: entries
  `(:id :class C :species S :when mood|any :copy-key K)` where C is one
  of the closed class table: fixture-flood | nerve-flood |
  nerve-pressure | fixture-served | tank-strain | tank-purged | loss |
  guild-mourning | faction-mock | romance-stage | fond-proximity.
  Loader validation: class ∈ the closed table, species ∈ the §1.1
  census, mood ∈ the §1.3 bands or any, copy-key resolvable at load —
  fail-first, load-time error, same discipline as every bank kind.
- The **`quirk`** kind gains optional `:species` (§1.2). Persona draws
  filter the bank by species; an empty filtered bank is a load-time
  error only when a spawn actually needs it (a species with no bank
  content simply gets no personas — structures, §1.1).
- Romance copy: hand-authored stage-transition framing in the
  `cistern--copy` social section; generated variants in bank `:copy`
  sections — resolved through the ONE existing chain
  (`cistern--story-copy-key`, STORY §4.4), folded at load, never per
  render.
- `tools/gen-bank.el` gains `:kind thought` composition under the
  existing hygiene rules: templates ≤ 60 raw chars, pure-data output,
  sorted by `:id`, self-validated before write (STORY §5 unchanged).

### 4.5 Inspector + log render — width-safe

Persona inspector clause appended when the cursor rests on an entity:
mood word, first quirk word, latest private thought:

    α — bladder 84% — CL.I — F+2 G+2 N-1 A+2 — STRAINED — NERVE-FLOOD:
    "TANK 2, HOLD"

Degradation order (mirrors RPG §1.2, fail-first tested): the FULL line
must be ≤ 95 cols, else the thought is dropped, then the quirk word,
then the mood word — the base inspector without a persona under the
cursor is byte-identical to today's. Muttered/filed log lines: bank
templates ≤ 60 raw chars + format args fit 95 (the same budget the
story capture test enforces, S6-style). The private ledger is
player-only: no log line, no browser entry, no other-NPC read.

### 4.6 Copy additions (all through the table)

    social-mutter-fmt   . "WORKER %s MUTTERS — \"%s\""
    social-file-fmt     . "%s FILES A %s"
    social-stage-fmt    . "%s AND %s ARE %s — %s"
    social-stage-close  . "THE FILE OF %s AND %s IS CLOSED — SEE OBITUARY"
    social-objection    . "GOBLIN %s OBJECTS TO %s's LIAISON — REVIEW DUE"
    social-raid-filed   . "RAID FILED AGAINST %s's BELOVED — THE INSTITUTION NOTES IT"

Stage names are data (`cistern--romance-stage-names`), formatted through
`social-stage-fmt`. All uppercase, terse, renderer-safe — tone check
against S2: these extend the institutional families, no new faces.

### 4.7 Story-engine coordination

- Romance transitions ARE story events (§2.4): the existing hook
  condition grammar reads `(event romance-stage)` from the pending list
  unchanged — no new condition parser.
- ONE new story effect, social-side only: `proximity-nudge` (adds N
  score to a named pair — hooks can force proximity events). This is
  the single extension to the STORY §6.4 effects whitelist, which
  stays closed for sim effects; a nudge writes a SOCIAL number (score),
  never a sim number. Listed in the story matrix loader's validation
  table as a v5 kind.
- COMEDY-DIRECTOR appends ≤ 1 private thought per tick via the domain
  thought-push helper after social-eval; the §1.6 ledger cap is
  enforced inside the helper — comedy cannot exceed the budget by
  construction.

---

## 5. ACCEPTANCE CRITERIA (fail-first; each lands red per R10)

**SC1 persona spawn.** Given seed 20260830 and stream 5, worker α's
persona is 2 quirks — bank selector draws 2 and 3 of the
species-filtered worker bank — and `social-pos` = 1083329933 after the
α + starter-toilet spawn pass; the test fails because no persona hash
exists. (Fixture values pinned from the real recurrence, §6 — draw
sequence d6=4, sel=2, sel=3, d6=3, sel=2, sel=2 → final pos
1083329933.)

**SC2 persona bounds.** For 1000 spawn rolls across 50 seeds: every
quirk count ∈ [1, 3], every selector resolves to a loaded bank id of
the right species, every `:ledger` is nil at spawn — fails while
personas are unspawned.

**SC3 mood banding.** A worker at bladder 99 is NOMINAL, at 100
STRAINED, at 110 CRITICAL; a tank at 84% is STRAINED, at 85% CRITICAL;
the manifold is NOMINAL at every tick of a soak run — fails while mood
is unstored/underived (the test also asserts no mood field exists on
the structs).

**SC4 trigger table firing.** With a breach event at (5,5): the fixture
at (7,6) gains one `fixture-flood` private thought, the worker at (6,5)
one `nerve-flood` thought, the worker at (9,9) nothing; the ledger cap
holds at 3 with FIFO eviction on the fourth; no thought fires on a tick
with no trigger row — fails while the table is unwired.

**SC5 channels.** A muttered thought renders exactly one
`social-mutter-fmt` log line AND pushes one `(:social 'mutter ...)`
event; a private thought renders ONLY in the inspector-at-cursor and
pushes nothing; a silent-urge fixture leaves the log byte-identical
while the view's `:urge` read flips — fails while channels are
unsplit.

**SC6 thought budget.** A tick with 6 eligible trigger rows generates
≤ 4 thoughts, kept in row order; a tick with 3 eligible mutters logs ≤
2 and downgrades the third to private WITHOUT consuming a stream draw —
fails while budgets are unpinned.

**SC7 romance progression.** With the §6 fixture: pair (α . toilet@12,5)
enters FILED on first proximity point without a roll, CROSS-REFERENCED
at score 10 (gate roll 10 → pass), CO-SIGNED at score 50 after two
re-armed failures at 40/45 (rolls 6/3, pass roll 11), ANNOTATED IN THE
MARGINS at score 80 (roll 15, co-signed +1 in the margin) — fails while
the graph doesn't exist.

**SC8 romance purity.** Around every stage transition: the hash of all
sim fields (bladders, tank loads, map, alloy, rng, particle-rng,
rpg-pos, combat-pos, story roll-pos) is identical before and after —
fails while romance can touch a sim number.

**SC9 romance caps + termination.** A third attachment offer at gate
time is refused with ZERO stream draws; demolishing the fixture at
stage 2 deletes the pair key, logs `social-stage-close` once (stage ≥ 2
only), grants the survivor one `loss` thought, and leaves no dangling
keys — fails while termination is unwired.

**SC10 stream hygiene.** Batch check: no social symbol calls
`cistern--rand`, reads `particle-rng`/`rpg-pos`/`combat-pos`/
`roll-pos`, or advances any position but `social-pos`; the particle
spawn from an urge uses a constant velocity (no draw) — fails while
any leak exists.

**SC11 determinism.** Two runs of seed 20260830, 300 ticks, produce
identical state hashes including `social-pos`, personas, and
relationships; a social-disabled run (banks unloaded) is byte-identical
to a pre-v5 sim run — fails while either diverges.

**SC12 width + copy.** The maximal persona inspector line degrades per
§4.5 (thought → quirk → mood → byte-identical base) and never exceeds
95 cols; every muttered/filed line ≤ 95; a grep-level check finds no
new literal string in view/game for social surfaces (A15's rule) —
fails while lines are hardcoded or overflow.

---

## 6. WORKED EXAMPLE — worker α and the toilet at (12,5), seed 20260830

All stream-5 fixtures below are computed from the real recurrence
(`(1103515245·pos + 12345) mod 2^31`, sliced at bit 6) in one pinned
consumption order — spawn draws first, then gate rolls as the
courtship consumes them. The sim facts (α's stats) come from the RPG
§7 fixture: α is F+2 G+2 N−1 A+2, so the audit-mod is ARCHIVE = +2.

**Spawn (6 draws):** count d6 = 4 → 2 quirks, selectors 2, 3 (worker
bank) → α's persona; count d6 = 3 → 2 quirks, selectors 2, 2 (fixture
bank) → the (12,5) toilet's persona. `social-pos` = 1083329933 (SC1).

**Courtship.** α's shifts keep seating it at the (12,5) fixture;
proximity (Chebyshev ≤ 2) accrues +1 per tick from T11. Score = ticks
in proximity; each stage gate consumes exactly one d20 per crossing:

| Tick | Score | Event | Draw | Margin (DC) | Band | Stage after |
|------|-------|-----------------------|------|-------------|------|--------------------------|
| T11 | 1 | first proximity point | — | — | — | FILED (no roll) |
| T20 | 10 | gate 1 | 10 | +4 (DC 8) | 2 | CROSS-REFERENCED |
| T49 | 40 | gate 2 | 6 | −4 (DC 12) | 1 | stays; re-arm at 45 |
| T54 | 45 | gate 2 re-roll | 3 | −7 | 0 | stays; re-arm at 50 |
| T59 | 50 | gate 2 re-roll | 11 | +1 | 2 | CO-SIGNED |
| T89 | 80 | gate 3 | 15 | +2 (DC 16) | 2 | ANNOTATED IN THE MARGINS |

(Gate 3's margin carries the co-signed +1: T89 = 15 + 3 − 16. The
re-arm rule is not decoration — gate 2 failed twice before passing,
and the log says exactly that, deadpan:

    T11:  α AND FIXTURE (12,5) ARE FILED — PROXIMITY ON RECORD
    T20:  α AND FIXTURE (12,5) ARE CROSS-REFERENCED — PROXIMITY NOTED
    T59:  α AND FIXTURE (12,5) ARE CO-SIGNED — THE PAIR FILES JOINTLY
    T89:  α AND FIXTURE (12,5) ARE ANNOTATED IN THE MARGINS

Each of the three transitions also pushes `(:social 'romance-stage …)`
to the story engine (a hook may open; a `proximity-nudge` effect may
feed the next gate) and fires `romance-stage` thoughts for both
partners. Private ledger at T89 (α, cap 3, newest first): the
T89-stage thought, the T49–T54 failure window's `fond-proximity`, the
T20-stage thought — three lines, inspector-only:

    α — bladder 84% — CL.I — F+2 G+2 N-1 A+2 — NOMINAL —
    "FIXTURE (12,5) FILES WELL"

The toilet's own channel at the T59 co-signing is a FILE, not a quote:
`FIXTURE (12,5) FILES A JOINT-FILING NOTICE`. No sim number moved in
89 ticks of courtship except `social-pos`, two hashes, and the log —
which is the whole point, and SC8's assertion.

Draw ledger: 6 spawn draws + 5 gate draws = 11 advances; `social-pos`
closes at 1258535310; the sim LCG and every other stream untouched.

---

## 7. SOAR PROTECTION

- **S1 inspector standard** — the persona clause degrades by pinned
  order and the base inspector is byte-identical without a persona
  under the cursor (SC12); the inspector remains the teacher.
- **S2 pressure voice** — muttered/filed lines extend the existing
  institutional families, reuse the Q13 severity grammar, add no face.
- **S3 popups-at-act** — thoughts and romance never popup. Channels
  are log, ledger, and render toggle. Exhaustive list, enforced by the
  intent-grammar guard.
- **S4 purge economy** — "purged together" is a social READ of a purge
  event (+2 score); purge itself is untouched, unpriced, unprompted.
- **S5 non-modal ceremony** — nothing in this layer takes input or
  blocks a tick. The player's only romance surface is READING: the
  inspector, the log, the browser.

Determinism: the trajectory remains a pure function of (seed, inputs).
Social adds stream 5 draws on events only; a social-disabled run is
byte-identical to the pre-v5 sim (SC11), so the five soars and every
existing acceptance suite hold with the layer off OR on.

---

## 8. EXPLICITLY DEFERRED

1. Pest species content — the id protocol and pair machinery accept
   pests; the entities and their banks await the sibling that lands
   them.
2. Structure persona default content — the manifold thinks only when a
   bank says so; wall-segment banks are content work, gated by nothing.
3. Relationship decay and breakup — stages are monotonic; if the bank
   wants DRAMATIC UNFILING, that is a v6 mechanism, not a v5 flag.
4. NPC-initiated prompts to the player — the social layer never asks
   the player anything; comedy/story may narrate around it.
5. Romance effects beyond copy/thoughts/hooks — stat buffs from love
   are permanently out of scope (§2.5), not deferred.
