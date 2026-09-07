# CISTERN v4 — RPG Simulation Layer (design only, no code)

Status: v1 design, 2026-09-07. D&D-style statistical layer, reworded into
the Tsutomu Nihei institutional register. Consumes DESIGN-SPEC §3 (layers),
the domain sim (`src/cistern-domain.el`), REWARDS-DESIGN (child streams,
no-fake-wins), and the matrix format agreed with `docs/v4/STORY-ENGINE.md`
(§6.3/§8.2: one load-time hash keyed `(matrix-id . band)`, outcome = effect
plist).

Governing constraints, verbatim from the owner brief:

- Stats MODULATE the existing bladder/sickness/contamination rules; they
  never replace them.
- Worker performance depends on their ACCESS to and PREFERENCE for one
  type of toilet or another.
- D&D-style rules apply statistical odds and random number rolls to the
  simulation.
- Least-active-decisions; everything batch-testable; copy through the
  copy table; PROTECT the five soars (S1 inspector, S2 pressure voice,
  S3 popups at the act, S4 purge ledger, S5 non-modal ceremony); 95-col
  width contract.

---

## 1. Worker stat blocks — maintenance-dossier fields

Four stats (owner cap ≤ 6; four is the fewest that covers every named
effect slot without a filler stat). Each is a rolled dossier field with
exactly one primary mechanical coupling to an EXISTING sim number, plus a
role as check actor. No new sim counters beyond the three worker slots
(`:stats :xp :clearance`) and one stream position on state.

| Field | Register reading | Primary coupling (exact) | Check actor |
|-------|------------------|--------------------------|-------------|
| FLOW | rated throughput | mining: healthy ore-ticks = clamp(3 − mod, 2, 6); sick = 2 × healthy | — |
| GRIT | contamination resistance | sickness duration = clamp(30 − 4·mod, 18, 42) ticks | exposure (DC 12) |
| NERVE | bladder composure | seek threshold = clamp(60 − 5·mod, 50, 68) % | composure (DC 10) |
| ARCHIVE | memory of routes | movement: one stride roll per journey, below | stride (DC 16) |

Slot coverage note: the owner's five effect slots map as mining rate
(FLOW), sickness duration (GRIT), seek-threshold discipline (NERVE),
movement rate (ARCHIVE). The bladder rate modifier slot is resolved as
the NERVE threshold shift; the increment itself stays pinned at
`cistern-bladder-rate` = 2 for every worker (envelope proof, §5.4) —
changing the increment would shrink the worst-case window by 33%, a
guard the clamps cannot bound.

Direction of the NERVE coupling: high NERVE files the relief request
BEFORE the spike (lower effective seek threshold, bigger window); low
NERVE files late (threshold up to 68, window down to 26 ticks). Copy
sells it as composure, not cowardice.

### 1.1 Roll at spawn

`4d6-drop-lowest` analog per stat, from the RPG child stream
(seed ⊕ 3, §3.1): four d6 draws, drop the lowest, sum → score 3–18.
Modifier: `floor((score − 10) / 2)` — D&D standard, −4..+4, no extra
clamp (every consumer clamps locally, §1 table). All four workers spawn
at `cistern--new-game` and every migrant at `cistern--phase-migration`
rolls the same way, consuming the stream sequentially. Stats are fixed
for the worker's life except the Cl.III field cert (§4).

### 1.2 Inspector render (width-safe)

Worker clause appends one clearance segment and one stat segment after
the existing status:

    α — bladder 84% — CL.I — F+2 G+2 N-1 A+2 — working

Stat segment is 15 cols max (4 × 3-char signed mods, single spaces);
clearance segment 5 ("CL.II"). Degradation order (fail-first tested):
if the joined inspector line exceeds 95 cols, the stat segment is
dropped first, then nothing else changes — the base inspector is
byte-identical without a worker under the cursor. Toilet inspector
gains the type name (§2.3). Armed badge gains the selected type name.
All strings via `cistern--copy` (§8).

---

## 2. Toilet types — the fixture catalog

`cistern--toilet-catalog` — domain data, one entry per type, keyed by
type id. Placed toilets gain a `:type` in the toilets hash; the procgen
starter toilet is `long-drop`.

| id | glyph | cost | use-ticks | use-load | suits (primary / secondary) | placement |
|----|-------|------|-----------|----------|------------------------------|-----------|
| long-drop | `t` | 10 | 2 | 10 | GRIT / FLOW | floor, any |
| fall-shaft | `u` | 8 | 2 | 8 | FLOW / GRIT | floor, no orthogonally-adjacent toilet (shaft clearance) |
| high-cistern | `¶` | 14 | 1 | 10 | ARCHIVE / NERVE | floor, orthogonal to ≥ 1 wall (wall-mounted) |
| archive-stall | `¤` | 12 | 3 | 12 | NERVE / ARCHIVE | floor, orthogonal to ≥ 1 wall |
| hermetic-booth | `Ω` | 20 | 2 | 10 | NERVE / GRIT | floor, any |

Differentiators are numbers, suits, placement, cost — no special-case
behavior per type (deferred, §10). Glyphs must be single-cell and
distinct from the tile table and the particle palette; final glyph
picking is the view pass's to confirm.

`cistern-cost-toilet` (10) stays: it is long-drop's price. `cmd-build`
reads cost and placement verdict from the catalog; illegal placement
refuses via copy-table line (same verdict style as R7). Type selection:
`T` cycles the armed type in catalog order; the badge shows it.

### 2.1 ACCESS and PREFERENCE (exact split)

- ACCESS is the existing reality: `cistern--free-usable-toilets` —
  placed, wired to tank capacity, not busy, reachable. Nothing changes.
- PREFERENCE is derived, deterministic, never rolled: the worker's
  DOMINANT stat = highest score, tie broken by fixed order FLOW, GRIT,
  NERVE, ARCHIVE. Suit of a type for that worker: dominant == primary →
  SUITED; dominant == secondary → NEUTRAL; else → UNSUITED.
- Routing stays nearest-free-usable (base rule). Preference never
  chooses the target: a preference-routing rule could lengthen walks and
  break the solvable envelope (§5.4). Preference acts on performance at
  the fixture, not on the walk.

### 2.2 Performance couplings (exact)

- `use_ticks_eff = clamp(type-ticks − 1·[suited] + 1·[unsuited], 1, 4)`.
  Suited long-drop: 1 tick; neutral: 2; unsuited: 3. High-cistern
  suited: 1 (floor); unsuited: 2; archive-stall unsuited: 4 (ceiling).
- XP on relief: suited relief +1 XP; neutral/unsuited +0 (§4).
- Bladder while seated stays frozen and zeroes at finish-use — the
  discomfort is turnover time (toilet occupied longer) and lost XP, not
  extra waste. No further penalty; two couplings are enough to make the
  catalog a real decision.

---

## 3. Roll mechanics

### 3.1 Streams

RPG rolls draw from child stream id **3** (`seed ⊕ 3`), position held
explicitly on state as `rpg-pos` — pure pos-in/pos-out like the particle
stream, NEVER the sim LCG (`cistern--rand`), never streams 0/1/2.
Stream 0 is reserved (REWARDS ledger); stream 1 = story generation,
stream 2 = story runtime (STORY-ENGINE §6.3); streams 4+ free.

Draw procedure (pinned for BOTH docs — see §3.2 note):

    pos' = (1103515245·pos + 12345) mod 2^31     ; existing recurrence
    d20   = 1 + ((pos' >> 6) mod 20)
    d6    = 1 + ((pos' >> 6) mod 6)

### 3.2 Why the mid-bits slice

The recurrence is the glibc LCG; its low bits are weak. Verified on
stream 3: low-bit d20s cycle 19, 8, 17, 10, 19, 8, 17, 10 — a short
loop a player could learn. Slicing at bit 6 kills it. Flagged to the
story-engine design for adoption in its §6.3; the loader shape below is
unchanged either way.

### 3.3 Check procedure (D&D, matrix-shaped)

    roll   = d20 (§3.1)
    stat   = clamp(mod, −2, +2)                  ; shared stat band
    margin = roll + stat − DC                    ; no act-mods in v4
    band   = ≤−5 → 0 crit-fail | −4..−1 → 1 fail | 0..+4 → 2 success
             | ≥+5 → 3 crit-success
    D&D promotion: natural 20 promotes to band 3; natural 1 demotes to
    band 0 — applied pre-lookup, so one loader serves both docs.
    outcome = gethash (matrix-id . band) → effect plist   ; NO runtime
                                                              hashing

Band vocabulary and the `(matrix-id . band 0..3)` key shape are shared
with STORY-ENGINE; effect keys differ per matrix-id. `:rpg-pos` and the
story `:roll-pos` are separate state fields; each engine's eval touches
only its own.

### 3.4 Roll points — event-driven only

Rolls fire on EVENTS, never on routing, seating, mining, or purge. This
keeps REWARDS-DESIGN's no-fake-wins rule intact: core sim outcomes stay
deterministic given inputs; statistical odds modulate physiology.

| # | Check | Fires | DC | Actor |
|---|-------|-------|----|-------|
| 1 | stat generation | each spawn (4 stats × 4 d6) | — | — |
| 2 | exposure | per adjacent worker when a breach applies sickness (existing `cistern--accident` loop; replaces the automatic sick) | 12 | GRIT |
| 3 | composure | when an unseated worker's bladder crosses 100 (crossing tick only: prev < 100, now ≥ 100; impossible while seated) | 10 | NERVE |
| 4 | stride | first step-toward tick of each journey (contiguous walk toward one target; ends at seating or target change) | 16 | ARCHIVE |

Stride success: that tick moves 2 steps (no re-roll on the bonus step).
Stride only ever ADDS steps — a slow worker is still 1 step/tick, so
movement can only shorten walks, never lengthen them (§5.4). Shuffled
idle drift does not roll.

### 3.5 Effect matrices (domain const, load-time fold into one hash)

    exposure-grit:    0 (:sick +5)   ; base duration +5 ticks
                      1 (:sick 0)    ; base duration applies (30 − 4·mod)
                      2 (:sick 0)    ; NO sickness — beats base auto-sick
                      3 (:sick 0 :xp 1)
    composure-nerve:  0 (:spike +10)
                      1 (:spike +5)
                      2 (:spike 0)
                      3 (:spike 0 :xp 1)

`:spike` adds instantly to the worker's bladder mid-walk — a failed
composure check during a breach window can push a worker over 120 and
burst. Stride is a plain pass/fail (no matrix; promotion still applies
to the roll itself, though both extremes map to pass/fail the same way).

DCs and spikes live in one `cistern--rpg-const` block beside the
catalog — one place to tune.

---

## 4. Progression — CLEARANCE levels

XP ledger per worker (deterministic; no rolls):

- +1 per relief served
- +1 extra when the relief is on a SUITED type
- +1 per band-3 (crit-success) outcome of any check
- +1 per shift survived (every `cistern-migrant-every` = 40 ticks,
  granted at the boundary tick)

Levels: CL.I at 0 XP (spawn); CL.II at 12; CL.III at 30. XP is
worker-local; it does not touch score, coins, or reputation — the
rewards layer is untouched (S4 protected).

Unlocks (fixed, no player choice, deterministic):

- **CL.II — CROSS-CERT.** The worker is never UNSUITED again: worst
  case NEUTRAL on every type. Removes the use-ticks penalty and the
  discomfort ceiling.
- **CL.III — FIELD-CERT.** +2 to the worker's LOWEST stat (tie → fixed
  order FLOW, GRIT, NERVE, ARCHIVE). Every §1 clamp still binds — a
  NERVE −1 worker reaching CL.III gets NERVE +1 → threshold 60; a
  NERVE −4 roll can only climb to 68's opposite clamp 50, never past it.

Clearance-up logs one line and fires an at-the-act popup (S3 register);
no modal (S5). Copy keys in §8.

---

## 5. Integration

### 5.1 Layer ownership

| Concern | Layer | Shape |
|---------|-------|-------|
| Stat generation, suit classification, checks, matrix loader, XP/clearance | domain | pure functions, pos in/out; worker slots `:stats :xp :clearance`; state slot `rpg-pos` |
| Toilet catalog, placement verdicts, costs, `:type` in toilets hash | domain | data + one verdict function |
| Type cycling (`T`), build cost/placement enforcement | game | `cistern--cmd-cycle-toilet-type`; `cmd-build` consults catalog |
| Inspector stat/clearance/type segments, badge, degradation, popups | view | reads domain enums/numbers via accessors; all copy via `cistern--copy` |

No new layer edges; domain stays emacs-free (checks are integer math on
explicit positions).

### 5.2 Determinism

- Every draw is pos-in/pos-out on stream 3; `rpg-pos` is on state, so
  same seed ⇒ identical trajectory INCLUDING rolls — the headless
  determinism test extends unchanged (hash after N ticks covers stats,
  spikes, XP).
- Fixtures pinned: first 16 stat draws and first 20 d20s at
  (seed 20260830, stream 3) — the §6 worked example is one fixture.
- Guards: a static/batch check asserts RPG code never calls
  `cistern--rand` or the particle stream; symmetrically the story
  engine never touches stream 3 (STORY-ENGINE S7-style guard, mirrored).

### 5.3 Batch testability

Stat gen, suit classification, band computation, matrix lookups, XP
math, and the envelope inequality are all pure integer functions — each
gets a headless assert in `cistern-run-selftest` style, no state setup
beyond a synthetic worker.

### 5.4 Balance guards — the solvable envelope

Base window: bladder crosses seek 60 at rate 2 → burst 120 is 30 ticks
away; seating + use costs 2–4; walk budget 26–28 ticks. Stats must stay
inside a provable envelope:

| Quantity | Pinned / clamped | Bound |
|----------|------------------|-------|
| bladder rate | UNCHANGED, all workers | 2 %/tick |
| burst | UNCHANGED | 120 |
| seek_eff | clamp(60 − 5·NERVE-mod, 50, 68) | [50, 68] |
| use_ticks_eff | clamp(§2.2 formula, 1, 4) | [1, 4] |
| stride | adds steps only | walks never lengthen |

Envelope inequality, per worker w:

    window(w) = (120 − seek_eff(w))/2 − use_ticks_eff_max  ≥  22 ticks

Worst case: (120 − 68)/2 − 4 = 22 vs base 28 — a bounded −21%, provable
from the clamps alone, no stat roll can escape it. Best case:
(120 − 50)/2 − 1 = 34. Batch guard: for every worker in a soak run,
assert window(w) ≥ 22 and every §1/§5.4 clamp; the guard pins the clamp
table against regression rather than simulating maps, because stride
never lengthens walks and routing is untouched (§2.1) — map solvability
stays exactly the base game's problem: the player routes need to
capacity.

No-fake-wins conformance: rolls modulate physiology and pace only;
pathing, seating, purge, and procurement outcomes stay deterministic.

---

## 6. Acceptance criteria (fail-first phrasing)

Each lands as a red test before its implementing commit (R10 process).

**A1 stat generation.** Given seed 20260830 and stream 3, worker α's
stat block is FLOW 15, GRIT 15, NERVE 9, ARCHIVE 14 and `rpg-pos` =
1156891213 after spawn — the test fails because no stat block exists.

**A2 stat generation bounds.** For 1000 spawn rolls across 50 seeds,
every score ∈ [3, 18] and every modifier = floor((score−10)/2) — fails
while spawn leaves stats nil.

**A3 suit classification.** A FLOW-dominant worker (GRIT equal-scored;
the tie rule picks FLOW) is SUITED on fall-shaft (flow primary),
NEUTRAL on long-drop (flow secondary), UNSUITED on hermetic-booth
(nerve primary) — fails while suit is undefined.

**A4 use-ticks coupling.** A suited worker on long-drop occupies it 1
tick; neutral 2; unsuited 3 (seating through relief) — fails while
use_ticks_eff ignores type.

**A5 catalog build.** `cmd-build` on high-cistern costs 14 alloy, sets
`:type`, and refuses non-wall-adjacent floor with the copy-table
refusal; fall-shaft refuses beside an existing toilet — fails while
every toilet builds as long-drop at 10.

**A6 exposure check.** With a band-2 draw pinned, a worker adjacent to a
breach does NOT get sick (base sim auto-sicks — the test is red against
current behavior); with a band-0 draw it sick for base + 5 ticks.

**A7 composure check.** A worker walking with bladder crossing 100 and
a band-0 draw gains +10 bladder on the crossing tick and can burst
early; a band-2 draw leaves bladder untouched; no check fires while
seated or on non-crossing ticks.

**A8 stride.** A journey's first step-toward with a ≥ 16 total moves 2
steps that tick; only one stride per journey; shuffle never rolls;
stride can never reduce steps below 1.

**A9 matrix shape.** `exposure-grit` and `composure-nerve` resolve via
the shared `(matrix-id . band)` hash, bands 0..3, effect plists as
§3.5; unknown matrix-id errors fail-first.

**A10 stream hygiene.** Batch check: no RPG symbol calls `cistern--rand`
or reads the particle position; story-eval and RPG-eval each leave the
other's stream position untouched.

**A11 XP / clearance.** One relief = +1 XP; suited relief = +2; band-3
outcome = +1; shift boundary (tick % 40 = 0) = +1; XP 12 → CL.II (never
unsuited: an unsuited-type seating now uses neutral ticks); XP 30 →
CL.III (+2 to lowest stat) — fails while XP/clearance don't exist.

**A12 envelope guard.** For all workers of a soak run: window(w) ≥ 22,
seek_eff ∈ [50, 68], use_ticks_eff ∈ [1, 4] — fails while clamps are
unpinned.

**A13 inspector width.** The maximal worker inspector line (floor
bearing + who + clearance + stats) is ≤ 95 cols, or renders without the
stat segment per the §1.2 degradation order — fails while the line has
no stat segment OR overflows.

**A14 determinism.** Two runs of seed 20260830, 300 ticks each, produce
identical state hashes including `rpg-pos`, XP, and clearance — fails
while rolls are unseeded.

**A15 copy table.** Every new player-facing string (§8) is fetched
through `cistern--copy`; a grep-level check finds no new literal string
in view/game for RPG surfaces — fails while lines are hardcoded.

---

## 7. Worked example — worker α, ticks 0–126, seed 20260830

Stream 3 fixtures (pinned, computed from the real recurrence):
stat draws → FLOW [4,3,5,6]→15, GRIT [5,4,6,1]→15, NERVE [1,1,5,3]→9,
ARCHIVE [4,6,4,4]→14; `rpg-pos` after stats = 1156891213; then d20s:
9, 1, 10, 10, 6, 14, 14, 17, ...

α: F+2 G+2 N−1 A+2. Dominant = FLOW (ties GRIT at 15; fixed order).
seek_eff = clamp(60 + 5, 50, 68) = 65. Mining = 2 ore-ticks/alloy.
Stride needs roll + 2 ≥ 16. On the starter long-drop α is NEUTRAL
(flow is secondary) → use_ticks_eff 2.

| Tick | Event | Draw (roll) | Result |
|------|-------|-------------|--------|
| 0 | spawn, bladder 20, CL.I, XP 0 | — | — |
| 23 | bladder 66 ≥ 65 → seek, leg 1, 7 steps | #1 = 9 → 11 < 16 | single steps |
| 29 | seat (bladder 78), use_ticks 2 (neutral) | — | — |
| 31 | relief, urgency 78 | — | XP 1 |
| 40 | shift boundary | — | XP 2 |
| 64 | bladder 66 (33-tick cycle) → seek, leg 2 | #2 = 1 (nat 1) | stride fails |
| 70 | seat | — | — |
| 72 | relief, urgency 78 | — | XP 3 |
| 80 | shift boundary | — | XP 4 |
| 105 | bladder 66 → seek, leg 3, 18 steps (only free fixture across the sector) | #3 = 10 → 12 < 16 | single steps |
| 120 | shift boundary | — | XP 5 |
| 122 | bladder 100 crossing mid-walk → composure | #4 = 10 → 10−1−10 = −1 | band 1 FAIL: spike +5 → bladder 105; seats this tick |
| 124 | relief, urgency 105 — near-burst payload | — | XP 6, still CL.I (12 at CL.II) |
| 126 | β breaches adjacent → exposure | #5 = 6 → 6+2−12 = −4 | band 1 FAIL: sick 22 ticks (clamp(30 − 4·2, 18, 42)) — mining halves to 4 ore-ticks until T148 |

Envelope proof on the worst episode: from T105 (bladder 66) the burst
clock is (120 − 66)/2 = 27 ticks → T132. α walked 18 + used 2 = 20,
relief lands at T124 with 8 ticks spare. The composure fail's +5 spike
ate 2½ of them; a crit-fail (+10) or the same spike with a longer walk
is where A12's ≥ 22 guard earns its keep. The exposure fail then costs
productivity, never mobility — base rule preserved.

Draw ledger: stream 3 consumed 5 d20s + 16 d6s; `rpg-pos` advances
explicitly every time; the sim LCG is untouched throughout.

---

## 8. Copy table additions (Nihei register, all-caps deadpan)

    clearance-up      . "CLEARANCE II — %s CROSS-CERTIFIED"   ; %s = glyph
    clearance-up-3    . "CLEARANCE III — %s FIELD-CERTIFIED"
    composure-slip    . "COMPOSURE SLIP — WORKER %s — PRESSURE MOUNTING"
    composure-broken  . "COMPOSURE LOST — WORKER %s — PRESSURE CRITICAL"
    exposure-hold     . "CONTAMINATION EXPOSURE LOGGED — WORKER %s UNAFFECTED"
    exposure-fail     . "WORKER %s CONTAMINATED — DEGRADATION UNDERWAY"
    refusal-place     . "FIXTURE REJECTED THERE — %s"         ; verdict text
    badge-type-fmt    . "ARMED: %s"
    toilet-type-fmt   . "FIXTURE — %s — %s"                   ; type, state
    inspector-stat-fmt  . "F%+d G%+d N%+d A%+d"
    inspector-clear-fmt "CL.%s"

Tone check against S2 (pressure voice): composure lines extend the
existing PRESSURE family, same voice, same severity faces.

---

## 9. Soar protection

- **S1 inspector standard** — stats make the inspector a better teacher
  (dossier at the cursor); width-guarded degradation keeps the base
  lines byte-identical; no worker under the cursor ⇒ zero change.
- **S2 pressure voice** — composure lines are pressure-family copy;
  the spike is literally pressure.
- **S3 popups at the act** — clearance-up popups fire at the act.
- **S4 purge ledger** — untouched; XP never reads score/coins.
- **S5 non-modal ceremony** — clearance-up is a log line + popup; input
  never blocks.

---

## 10. Explicitly deferred

1. Per-type special behaviors (hermetic-booth containment, archive-stall
   XP aura) — catalog numbers must prove themselves first.
2. Stat-raising purchases / reroll items in the shop (REWARDS §3 SHOULD).
3. Preference-weighted toilet choice (needs an envelope re-proof).
4. Act-modifiers in the margin formula (story engine has them; RPG v4
   passes none).
5. Worker-to-worker stat contrast copy ("dossier review" surface).
