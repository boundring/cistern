# CISTERN v5 — COMEDY DIRECTOR (design only, no code)

Status: DESIGN v1, 2026-09-07. Consumes DESIGN-SPEC §3 (layers),
STORY-ENGINE (banks, pending-event read rule, copy chain, stream
discipline), RPG-LAYER §3 (mid-bits slice, one rule, all engines),
SURFACE (S1–S5 soar protection, 95-col contract), and the v5 sibling
designs — SOCIAL (stream 5, personas, romance stages, §4.2 tick slot)
and COMBAT (stream 4, `raid` state, violent event vocabulary). The
comedy director sits in SOCIAL §4.2's pinned slot. Everything below
lands red-first per R10. No code in this doc.

Owner intent, restated once: situational whimsy and slapstick for
CONTRAST — against the theme's dread and the violence of emergent
events. Borderline tongue-in-cheek, for Pat to notice. Something funny
at least once every 2–3 minutes of play, paced by real tracking of
in-game events, not a metronome.

Governing constraints, binding on every section:

- Five soars: S1 inspector standard · S2 pressure voice · S3
  popups-at-act · S4 purge economy · S5 non-modal ceremony (same list
  SOCIAL §0 pins). Comedy extends, never edits, those surfaces.
- The register is the product: institutional deadpan (Blame! register,
  STORY §1). No exclamation, no winks to the camera. The slapstick is
  in WHAT HAPPENS; the copy reports it like an incident form. A joke
  that needs an adverb does not ship.
- Every comedic beat is mechanically real: where a state change is
  possible, the beat makes one. Pure-flavor beats exist only where the
  honest footprint is a counter or a ttl (§2.2) — each is enumerated,
  never hand-waved.
- Batch-testable: the whole director is a pure function of
  (seed, banks, state); seed → beat schedule is a pinned fixture (§5.4).
- Width: every rendered line fits the 95-col capture (templates ≤ 60
  raw chars, the STORY §4.4 budget).

Final position on tick order, confirmed against STORY-ENGINE §1 and
SOCIAL §4.2: the pinned order is

    story-eval → social-eval → comedy-eval → dialogue-eval → rewards-eval

comedy-eval runs AFTER social-eval (it appends dry thoughts through
social's pinned helper and reads romance transitions social just
emitted) and BEFORE dialogue-eval (V4-16's pinned story→dialogue pair
stays adjacent; comedy is a third reader of the same pending events,
draining nothing — the L-027 rule: rewards-eval remains the sole
drainer). Comedy inherits STORY §1's one governing rule whole: it
NEVER consumes the sim LCG or the particle stream, NEVER changes core
sim outcomes (pathing, relief success, contamination arithmetic, purge
rate), draws only from its own child stream. The one sanctioned
exception class is §2.2's tiny-delta whitelist — bounded, enumerated,
envelope-proofed like RPG §5.4, and never touching the solvable
envelope's window inequality.

---

## 1. THE PACING TRACKER

### 1.1 The dual clock — ticks authoritative, wall-clock a backstop

One state field on `cistern-st`: `comedy`, a plist —

    (:pos P                ; stream-6 position, pos-in/pos-out
     :last-beat-tick T     ; tick of last DELIVERED beat (or session start)
     :due-p BOOL           ; budget expired under suppression — latched
     :recent (ID...)       ; last 3 delivered archetype ids, newest first
     :active (KIND . TTL)) ; one active multi-tick beat thread, or nil

Nothing else on state. Beat-internal tiny deltas live on the entities
they concern (§2.2), each named there.

**Clock A — ticks (sim-authoritative, deterministic).** The tracker
keeps `ticks-since = tick − :last-beat-tick` and compares it against a
mode-conditional budget — the pinned conversion of "2–3 real-world
minutes" into each pace:

| Mode           | Pace        | Budget (defconst)        | Reads as |
|----------------|-------------|--------------------------|----------|
| manual (`SPC`) | design 1 tps| `cistern--comedy-budget-manual` = 150 | 2.5 min |
| auto (`r`)     | pinned 5 tps| `cistern--comedy-budget-auto`   = 750 | 2.5 min |

The mode is existing state (the auto-run flag); no new sim input.
150 ticks at the design manual pace is 2.5 minutes; 750 at 5 tps is
the same. A fast manual player ticks faster and gets comedy sooner —
the guarantee is a CEILING, and the ceiling is what §1.5 asserts.

**Clock B — real-world minutes (driver-side, non-sim, backstop).** The
manual budget assumes ~1 tps; a player who reads, thinks, and ticks at
0.2 tps would stretch 150 ticks to 12 real minutes. The backstop lives
in the DRIVER (the S4 teaching-layer ruling: input-layer counters are
ephemeral and determinism-free): the driver notes the wall time of the
last rendered comedy line. If no comedy line has delivered in 2.5 real
minutes AND at least one tick advanced since the last backstop nudge,
the driver cycles one line from `cistern--comedy-nudges` (driver
defconst, 8 deadpan one-liners, no bank, no draws, no state) through
the existing hint slot (Q17/R2-Q06 lifetime). The backstop can never
fire a bank beat, consume stream 6, or mutate state — a nudge is
comedy, not a beat, and the §1.5 guarantee counts it only for Clock B
coverage. Rejected alternative: wall-clock-triggered bank beats (they
would consume stream draws at render-time-unpredictable points and
break the replay contract, the same class of leak SC10/A10 guard
against). The wall clock never enters `cistern-st`.

### 1.2 Suppression — what blocks comedy

The tracker evaluates, in pinned order, on every tick:

| # | Condition (pinned reads)                     | Effect            |
|---|----------------------------------------------|-------------------|
| S1| combat `raid` non-nil (open)                 | suppressed        |
| S2| ≤ 40 ticks since a violent anchor            | suppressed        |
| S3| contamination ≥ 15 (condemnation is 20)      | suppressed        |
| S4| story act-rollover tick ± 10, or a hook force-miss this tick | suppressed |
| S5| beat already active (`:active` non-nil)      | no new beat       |

**Violent anchors (S2)**, one defconst list: `worker-death`, `burst`,
`infestation`, and a raid close (combat's `(:last-end T)` — the raid
event's CLOSED framing). The cooldown is `cistern--comedy-calm` = 40
ticks from the anchor tick. A raid turn itself is comedy-free by S1;
the beat fires in the breath AFTER — see §1.3's latching, which makes
"the breath after" the default outcome rather than a special case.

**Density dampener.** ≥ 2 violent anchors within the last 60 ticks
sets a `tense` flag: every archetype flagged `:loud` has its weight
halved for the selection (§1.4). Quiet absurdity is what survives a
bad shift; the dampener is the only density mechanism — no other
counter is kept.

### 1.3 The forced-beat budget — expiry latches, it never lapses

When `ticks-since` reaches the budget (Clock A) while suppressed, the
tracker sets `:due-p = t` and stops — it does NOT reset the budget and
does NOT force delivery into a suppressed tick. The first tick where
every suppression row clears delivers the due beat. Consequences,
each deliberate:

- A raid that outlasts the budget ends with a beat in the breath
  after the raid closes (S2's 40-tick cooldown applies from the close,
  so the beat lands at cooldown expiry, not at the close tick — the
  moment of victory is the sector's, the joke comes after).
- Suppression can stretch a budget arbitrarily; the guarantee (§1.5)
  is asserted over CALM windows, and the README states it as "every
  2–3 minutes of calm shift time".
- `:due-p` consumes no draw while latched — selection happens on the
  delivery tick only, so the schedule stays a pure function of
  (seed, banks, state).

Spontaneous beats (not budget-forced) use the same eligibility path
with a low per-tick base rate: one stream-6 draw per eligible tick,
`beat-odds = 1/90` (manual) — at 5 tps auto the odds-draw is skipped
and ONLY the budget forces beats (auto-run's log is dense enough; the
budget owns that mode). One draw per tick maximum, one beat per tick
maximum (S5-row overlap impossible by construction).

### 1.4 Selection algorithm — pinned steps

On a delivery tick (budget-forced, spontaneous roll passed, or a
§3 priority slot), in pinned order:

1. **Eligibility filter.** An archetype is eligible iff its `:when`
   predicate holds over the pinned reads (§2.2 — all READS of
   existing state, the STORY §3.4 discipline), its id is not in
   `:recent` (anti-repeat window: the last 3 delivered beats), and
   its own per-archetype `:cooldown` has elapsed.
2. **Weight fold.** Weight = `:weight` × context mods: `:loud`
   archetypes ×0.5 under `tense` (§1.2). The pool is guaranteed
   non-empty by the fallback archetype (`:when t`, `:loud nil`).
3. **Archetype draw.** One mid-bits draw on stream 6
   (`sel = (ash pos -6) mod total-weight`, cumulative walk — the
   STORY §7.5 tier-selection shape, slice per RPG §3.2).
4. **Instance draws.** The entry's `:draws` spec pins how many
   follow and what each selects (cast member, fixture id, ±1
   outcome, mutter target) — per-entry, fixture-pinnable. Pinned
   call order: archetype draw, then instance draws left to right;
   no draw on any failure path.
5. **Commit + deliver.** The entry's footprint applies (§2.2),
   `:recent` updates (cap 3), `:last-beat-tick` = this tick,
   `:due-p` = nil. Delivery is the intent grammar (§5.3): log line,
   at most one banner (see the arbitration rule there), popup
   particles where the entry says so. Non-modal throughout (S5).

### 1.5 The guarantee — owner-facing, and what the test asserts

**The promise:** at the pinned paces, a comedy beat lands at least
once every 150 manual ticks / 750 auto ticks of CALM shift time
(§1.2's suppression may pause the clock; it can never cancel a due
beat). Plus the Clock B backstop: no 2.5 real minutes of active
manual play without a comedic line.

**The batch test (C1, §6) asserts exactly:**

1. Seed 20260830, 900-tick auto soak, example bank loaded: scanning
   the intent stream for log-layer intents whose copy key resolves in
   the `(comedy . ...)` section — the maximum gap between consecutive
   comedy lines is ≤ 750 ticks, and the gap is measured across, not
   within, suppression spans (the test recomputes the suppression
   spans from the same pinned rules and asserts every calm window of
   750 consecutive ticks contains ≥ 1 comedy line).
2. Manual pace (the same soak, budget-manual forced on): max calm
   gap ≤ 150 ticks.
3. The latching property: a run where a raid spans the budget expiry
   delivers its due beat within 5 ticks of the first calm tick after
   the 40-tick cooldown — never inside it.
4. Clock B (driver): with wall time cl-letf'd forward 3 minutes over
   a 10-tick manual session, exactly one nudge line posts; a second
   nudge does not post until another tick advanced.

---

## 2. THE WHIMSEY BANK

### 2.1 Format

One new bank kind **`whimsey`** (the STORY §4.2 shape, loader
validated — §5.1):

    (:id beat-pipe-complaint
     :when (pipes-long 6)          ; pinned predicate, §2.2 per entry
     :weight 10                    ; base selection weight
     :loud nil                     ; t = halved under tense (§1.2)
     :cooldown 200                 ; per-archetype tick cooldown
     :draws (cast 1 pipe 1)        ; pinned instance-draw order
     :thread nil                   ; t = multi-tick :active thread
     :footprint (complaint-count)  ; state deltas, whitelisted §5.2
     :copy-key comedy-pipe-complaint)

Copy lives in the `(comedy . ...)` section of `cistern--copy` (hand
copy) or the bank's `:copy` section (generated), through the existing
`cistern--story-copy-key` chain — one lookup rule, already pinned.

The violence-contrast rule is bank-wide (§2.3), not per-entry.

### 2.2 The twelve archetypes

Summary (weights are base, pre-dampener):

| # | id | trigger `:when` (pinned reads) | W | loud | footprint |
|---|----|--------------------------------|---|------|-----------|
| 1 | pipe-complaint | a routed pipe ≥ 6 long | 10 | nil | complaint counter |
| 2 | clog-blame | ≥ 2 guild goblins alive | 8 | nil | mutter via social |
| 3 | manifold-accent | ≥ 1 manifold attached | 6 | nil | accent ttl 60 |
| 4 | workers-comp | ≥ 1 pest persona | 7 | nil | +1 alloy |
| 5 | aesthetic-refusal | worker seeking, ≥ 2 usable fixtures | 5 | nil | REAL 1-tick refusal |
| 6 | formal-duel | rat within 1 of a cast worker | 6 | nil | rat −1, +1 XP |
| 7 | memo-rename | t (fallback family) | 5 | nil | place alias ttl 120 |
| 8 | inventory-audit | t (fallback family) | 6 | nil | ±1 alloy (drawn) |
| 9 | queue-etiquette | 2 workers within 2 cells | 6 | nil | 1 muttered thought |
| 10 | toilet-rivalry | ≥ 2 same-type toilets | 5 | nil | rivalry ttl 60, +1 waste once |
| 11 | successor-letter | demolish event this tick | 8 | nil | +1 alloy |
| 12 | safety-drill | t (fallback family) | 4 | nil | drill counter |

Detail — trigger, draws, footprint, copy pattern. Every footprint
delta is on the §5.2 whitelist; anything not listed there cannot be
authored.

**1. `pipe-complaint`.** A cast worker files Form 7-R against the
longest pipe on the route they last walked. Draws: cast 1 (worker),
pipe 1 (the longest routed pipe, ties break by scan order — no draw).
Footprint: `:complaints` counter ON THE PIPE (ad hoc property, capped
no); the 3rd complaint on one pipe logs `PIPE FLAGGED FOR REVIEW —
FORM 7-R ON FILE` (info face) and resets. Copy pattern:
`WORKER %s FILES A COMPLAINT AGAINST PIPE SEGMENT %d — FORM 7-R`.
Deadpan: the pipe is never quoted; the review is never scheduled.

**2. `clog-blame`.** Two guild goblins litigate whose fault the last
clog was. Draws: goblin 1, goblin 2 (two distinct guild goblins).
Thread: 3 log lines over 3 ticks (`:active`), each a footnote
escalation — `Goblin 2 cites Addendum C. The clog is not named.`
rendered as `GOBLIN %s CITES ADDENDUM %s — REVIEW PENDING`. Footprint:
the loser (instance draw 3) receives one muttered grudge through the
social mutter push — the feud persists as a THOUGHT, not a number.

**3. `manifold-accent`.** One attached manifold reports in a local
dialect for 60 ticks. Footprint: `:accent-ttl 60` on the manifold
entity. While ttl > 0 the manifold's own social thought-copy renders
through the accent table (one pinned vowel mapping in the copy
renderer, presentation only) and its inspector line may append
`DIALECT ACTIVE` (first to degrade, §5.5). Copy: `MANIFOLD %d ADOPTS
A LOCAL DIALECT — REPORTS UNCHANGED`.

**4. `workers-comp`.** A pest files a claim. Footprint: +1 alloy,
logged as a disbursement. Copy: `CLAIM %d APPROVED — ONE (1) ALLOY
DISBURSED TO %s`. The claim number is the tick; the institution pays
without investigating, which is the joke.

**5. `aesthetic-refusal` — the flagship real beat.** A seeking worker
is refused a usable fixture on aesthetic grounds. Footprint: the
chosen fixture is marked `:aesthetic-p` for exactly one tick; the
domain's `cistern--free-usable-toilets` filter drops it, so the
seating attempt this tick FAILS and the worker reroutes next tick by
the existing path — no new sim mechanic, one filter read. Eligibility
guard: armed only when ≥ 2 fixtures are free-and-usable, so a refusal
can never orphan a worker (the solvability envelope, RPG §5.4, is
untouched — the worker still has a seat). Draw: fixture 1 (which
fixture), worker is the seeking cast member (no draw). Copy:
`FIXTURE %d DECLINES WORKER %s — AESTHETIC GROUNDS. NO APPEAL.`

**6. `formal-duel`.** A rat and a cast worker duel with formal
apologies exchanged first. Draws: cast 1 (the adjacent worker); the
rat is the adjacent one (no draw). Thread: 2 lines (the apologies,
then the verdict). Footprint: the rat despawns (existing despawn
path), worker +1 XP (the RPG §4 ledger, the same +1 family as a
relief). Copy: `WORKER %s AND ONE (1) RAT EXCHANGE APOLOGIES — THE
CORRIDOR IS %s'S`.

**7. `memo-rename`.** The registry assigns a designation to a bounded
region (the corridor of the last relief, ties by scan order). Draws:
name 1 (from the keyword bank's place class — the STORY §4.2 keyword
reuse, zero new naming machinery). Footprint: `:place-names` alias on
state (ttl 120, shown as a parenthetical in the inspector for cells
inside the region — degrades first, §5.5). Copy: `REGION (%d,%d)-(%d,%d)
HEREBY %s — signage pending`.

**8. `inventory-audit`.** An audit of one (1) alloy. Draw: outcome 1
(±1, equal odds). Footprint: alloy delta — real, tiny, and the ONLY
comedy beat allowed to move alloy twice-signed. Copy, both bands:
`INVENTORY AUDIT — ONE (1) ALLOY %s` where %s ∈ {`LOCATED`,
`MISPLACED`}. The misplacement is never investigated further.

**9. `queue-etiquette`.** Two workers within 2 cells conduct a
formal after-you. Draws: worker 1, worker 2 (nearest pair). Footprint:
one muttered thought pushed through social's mutter path for worker 2
(the one who yields — instance draw 2), which OTHER goblins and
workers may hear per SOCIAL §1.5. The sim's walk order is untouched.
Copy: `WORKER %s DEFERS TO WORKER %s — THE DOOR REMAINS OPEN`.

**10. `toilet-rivalry`.** Two same-type fixtures enter formal
competition for 60 ticks. Draws: fixture 1, fixture 2. Footprint:
`:rival-ttl 60` on both; the next use of EITHER logs one jab line
from the other (`FIXTURE %d CONGRATULATES %d — THROUGH ITS TEETH`),
and the fixture with fewer uses at ttl expiry pays a one-shot
tank-load-delta +1 on its next use (it tries harder — the STORY §6.4
whitelisted effect family, once, bounded). Copy: `FIXTURES %d AND %d
ENTER COMPETITIVE REVIEW — JUDGED BY USAGE`.

**11. `successor-letter`.** On a demolish/rubble-clear event this
tick: the worker finds a predecessor's letter sealed in the debris.
Draw: cast 1 (the demolisher). Footprint: +1 alloy (`SEALED WITH THE
LETTER — ONE ALLOY`). The letter's content is the copy line and is
NEVER shown twice (the entry carries 3 letter variants, instance
draw 2 selects). This beat references the dread deadpan — it is
`loud nil` but respects §2.3: it never fires within the cooldown.

**12. `safety-drill`.** `UNSCHEDULED SAFETY DRILL — PLEASE CONTINUE`
banner + one popup particle. Nothing else happens; the nothing IS the
beat. Footprint: `:drills` counter on `comedy` state, tallied at each
act rollover as `%d UNSCHEDULED DRILLS THIS ACT` (info face). The
counter is the honest footprint of a beat whose joke is bureaucratic
theater.

### 2.3 The violence-contrast rule — copy discipline

Mechanical layer: §1.2's S1/S2 rows (raid open = none; 40-tick calm
after each violent anchor) and the `:loud` dampener. Copy layer,
three hard rules the docs pass reviews against:

1. **No joke on the moment of harm.** A comedy line never renders on
   a tick within the 40-tick calm of an anchor — mechanically
   guaranteed by S2, so no copy rule is needed to enforce timing.
2. **The dead are never punchlines.** A comedy beat never names the
   glyph of a dead worker, never quotes a death panel, never formats
   a burst as wit. The closest permitted register is the oblique
   institutional aside AFTER the calm — `THE CONTAMINATION REMAINS
   UNAVAILABLE FOR COMMENT` — and only from bank copy reviewed as
   data.
3. **Contrast by juxtaposition, not by interruption.** A comedy beat
   never takes the banner slot on a tick the story or combat claimed
   it (§5.3 arbitration), never accompanies a severity alert, and
   never spawns popup particles on a contaminated tile (floor-only,
   Q25, unchanged).

---

## 3. THOUGHT/ROMANCE COMEDY HOOKS

### 3.1 Channel split — slapstick public, dry private, feuds muttered

The three SOCIAL §1.5 channels map to three comedy registers, one
each, no mixing:

| Channel | Register | Owner | Example |
|---------|----------|-------|---------|
| log/banner | slapstick | whimsey bank (§2) | `WORKER %s FILES A COMPLAINT AGAINST PIPE %d` |
| private thought | dry | §3.2 injected thoughts | `AUDITED FOUR TIMES, NEVER THANKED` |
| muttered | feud/aside | bank threads + romance rival (§3.3) | the clog-blame loser's grudge |

The inspector's private-thought readout (SOCIAL §4.5) is where the
DRY jokes live — understatement, deadpan audit-language, the things a
worker would never say aloud. The log's slapstick stays in the bank.
A player who never inspects a worker sees a different, thinner comedy
diet than one who does — that asymmetry is the design, and it is why
the private channel is capped gently instead of fired like the bank.

### 3.2 Injected private thoughts — the dry channel

`cistern--comedy-eval` may append ONE comedic private thought per 60
ticks (`cistern--comedy-dry-gap`), via the SOCIAL-pinned domain
thought-push helper ONLY — comedy never writes `personas` directly.
Constraints, all pinned and tested (C8):

- ≤ 1 comedic thought per entity per tick (subsumed by SOCIAL §1.6's
  sector caps — comedy draws no extra budget, it competes by row
  order AFTER social's own generations).
- Never for a worker whose mood band is CRITICAL (sick, bursting,
  bladder ≥ 110) — dry humor does not punch at the desperate. Read:
  SOCIAL §1.3's derived mood.
- Content: one stream-6 draw over the `comedy-thought-*` copy family
  (bank `:copy`, ~8 entries at ship); quirk-tagged variants preferred
  when the persona carries a matching quirk (the SOCIAL §1.4 rule,
  reused).
- Delivery is private ONLY: no log line, no browser entry (SC5's
  channel assertions cover it).

### 3.3 Romance transitions — the prime slots

Every `(:social 'romance-stage :pair P :stage S)` event (SOCIAL §2.4)
that comedy-eval reads this tick arms a PRIORITY SLOT: a beat fires
within 10 ticks (draw: which tick, then which variant), superseding
the tracker's budget WITHOUT consuming or resetting it (`:last-beat-tick`
does not move — the priority slot is on top of the guarantee, never
in place of it). Suppression still holds: a raid outranks a wedding.

- **Stage 2 CO-SIGNED — the announcement.** Banner arbitration
  permitting (§5.3), one banner: `%s AND %s — PARTNERSHIP CO-SIGNED`.
  The pair's glyphs come from the pair key; the TOILET's rival (the
  §2.2 `toilet-rivalry` pair if one is active, else the nearest
  same-type fixture persona) receives one MUTTERED response through
  the social mutter push — `FIXTURE %d NOTES THE FILING` register.
- **Stage 3 ANNOTATED IN THE MARGINS.** One log line from the bank's
  stage-3 family (2 variants); the pair gains one shared dry thought
  (§3.2's path, bypassing the 60-tick gap ONCE — the annotation is
  the paperwork event of the season).
- **Stage 0/1 FILED / CROSS-REFERENCED.** Log-family lines only, low
  weight; the early stages are the player's discovery, not the
  director's.
- **Cross-faction pairs (SOCIAL §3):** the warband objection line is
  SOCIAL's; comedy adds NOTHING on top of an objection tick — the
  deadpan is already maximal there.

Termination (SOCIAL §2.6) is never comedic: closed files get the
obituary line and a `loss` thought, and the director stays silent —
the contrast rule applies to grief in all its forms.

---

## 4. THE STORY-FORWARD README — the Sector 7 onboarding dossier

### 4.1 The move

The README stops describing a game and becomes the in-universe
document the game implies: the ONBOARDING DOSSIER issued to a new
sanitation employee of Sector 7. Target 130–190 lines (current 26;
5–10× per the owner brief). PLAYING.md remains the canonical full
player guide — the dossier condenses, links, and never contradicts
it. No PLAYING.md fact is deleted; the migration list in §4.4 says
where each lands.

### 4.2 Section structure (build order = read order)

1. **Title block + classification line.** `# CISTERN` stays byte-1
   (links into it from elsewhere must hold); under it one line:
   `SECTOR 7 SANITATION DIVISION — EMPLOYEE ONBOARDING DOSSIER 7-C`.
2. **§1 THE STRUCTURE.** What the Structure is: vast, unfinished,
   nobody coming. 4–6 lines, zero mechanics. Sets dread before any
   joke; the contrast engine of the whole document.
3. **§2 TERMS OF EMPLOYMENT.** The loop as employment clauses: you
   run sanitation for one sector; workers mine ore for alloy; alloy
   buys pipe, fixtures, tanks; waste flows; contamination is the
   clock. Each clause is PLAYING.md's prose, reworded into contract
   register. Ends: `THE STRUCTURE DOES NOT CARE.` (the pressure-voice
   line, byte-identical).
4. **§3 YOUR PREDECESSORS.** Three flavor entries, one line each —
   a fate apiece (flourished, filed, filed under F). Pure dossier
   fiction; names the dread, earns one bracketed footnote joke (see
   §4.5 tone rules).
5. **§4 PERSONNEL DOSSIERS.** The stat blocks (FLOW/GRIT/NERVE/
   ARCHIVE, scores 3–18, life-long), clearance II/III, XP rules —
   PLAYING.md's "The dossiers" section reworded as personnel policy.
   The table of stat effects migrates 1:1.
6. **§5 REQUISITIONS — THE FIXTURE CATALOG.** The five-type catalog
   table verbatim (numbers byte-equal to PLAYING.md's), framed as a
   requisition form; placement refusals as "requisitions may be
   declined with a named reason."
7. **§6 TERRAIN AND WILDLIFE.** Rubble/flood/manifold/cache/event
   tiles; then the fauna: pests, rats, goblins (guild AND warband —
   friend and foe, per COMBAT), the fixture-persona curiosities
   (SOCIAL), one line each, deadpan field-guide register.
8. **§7 THE WARBAND SITUATION.** Raids: what they are, that they
   come, the defense verbs as "authorized responses." Combat
   mechanics stay in PLAYING.md/docs; the dossier carries posture,
   not numbers.
9. **§8 SECTOR RECORDS.** The story engine (premise banner, three
   acts, hooks that HOLD or BREACH) and one deadpan sentence on the
   whimsy: `THE SECTOR OCCASIONALLY FILES WHIMSEY REPORTS. READ THEM
   OR DO NOT.` Comedy is disclosed like a hazard.
10. **§9 EMPLOYMENT PROCEDURES (run + keys).** The run block and the
    key table, byte-accurate (§4.3), framed as procedures: build
    verbs, purge, decon, auto-run, the log browser, emacs pairings —
    PLAYING.md's "Keys" and "Build two ways" content, condensed to
    the table plus the two coach sentences.
11. **§10 READING THE SCREEN.** Strip, map, faced log, inspector,
    palette derivation — as "how to read your station."
12. **Closing + links.** Byte-accurate (§4.3); closes with the
    one-sentence summary migrated from PLAYING.md verbatim:
    **wire the fixtures to the tanks before the bladders win.**

### 4.3 Byte-accuracy contract (tested, C11)

These blocks migrate byte-identical — no reflow, no rewrap:

- The fenced run block: the three lines `git clone …`, `emacs -Q -l
  src/cistern.el`, and the fence itself.
- `Then `M-x cistern`, or see [PLAYING.md](PLAYING.md) for the full
  guide.` — verbatim, as §9's opening.
- The two doc links (`docs/DESIGN-SPEC.md`, `PLAYING.md`) — verbatim
  as the closing list, `v3.0.0-dev · Requires Emacs 27.1+` updated to
  the v5 version string in BOTH files in the same commit.
- The fixture catalog table's numeric cells (costs, use ticks, suits)
  and the stat-effect bullets.

The C11 test asserts these as string-equality on extracted blocks
(the Q11 string-equality discipline applied to the README).

### 4.4 Migration ledger (PLAYING.md → README dossier)

| PLAYING.md section | Lands in | Treatment |
|--------------------|----------|-----------|
| Run it (block)     | §9       | byte-accurate |
| The job            | §2       | reworded, all facts kept |
| The dossiers       | §4       | reworded, table 1:1 |
| The fixtures       | §5       | table verbatim |
| Terrain            | §6       | condensed, all five kinds named |
| First shifts       | §9       | the 3-step warmup as "day one" |
| Keys / emacs pairings | §9    | table verbatim + coach note |
| The story          | §8       | reworded |
| Rewards            | §2/§4    | score/purge-pay in §2; XP in §4 |
| Reading the screen | §10      | reworded |
| The log browser    | §9/§10   | keys in §9, reading in §10 |
| the one-sentence summary | closing | verbatim |

The dossier may omit detail PLAYING.md keeps (exact contamination
arithmetic, pop cap exceptions) but may not CONTRADICT it — the docs
pass reads them side by side (C11's spot-fact list).

### 4.5 Tone calibrations

- All-caps section headers; body prose in the institutional voice;
  second person ONLY as "you" the employee, never "you" the player.
- No exclamation marks anywhere, including footnotes.
- Humor budget: at most ONE bracketed footnote per section, dry, and
  never within three lines of a hazard statement. Example register:
  `[employees are reminded that the pipes are load-bearing, unlike
  the org chart.]`
- The contamination clock and the death panel are never joked about
  (the §2.3 rule extends to prose): dread paragraphs get zero
  footnotes.
- Numbers are never funny. Every mechanical number in the dossier is
  stated flat; a joke never carries a stat.

---

## 5. DETERMINISM & INTEGRATION

### 5.1 Streams

Stream **6** (seed ⊕ 6), position `comedy-pos` inside the `comedy`
state plist — pos-in/pos-out, mid-bits slice `(ash pos -6)` on every
draw (the one-rule-all-engines ruling). Allocation now:
0 reserved · 1 story-gen · 2 story-runtime · 3 RPG · 4 COMBAT ·
5 SOCIAL · 6 COMEDY · 7+ free. Comedy code never touches the sim LCG,
the particle stream, or another engine's position — asserted by C9,
the SC10/A10 shape.

### 5.2 The footprint whitelist — every state delta comedy may make

Fail-first enumerated; the loader and a batch guard reject any bank
entry whose `:footprint` names anything else:

    complaint-count   ; ad hoc pipe property, presentation counter
    accent-ttl        ; manifold entity, 60
    aesthetic-p       ; fixture entity, exactly 1 tick (§2.2 #5)
    rival-ttl         ; fixture entity, 60 (+1 waste once, STORY §6.4 family)
    place-names       ; comedy plist alias, ttl 120
    alloy-delta       ; ±1 (workers-comp +1, inventory-audit ±1, letter +1)
    xp-delta          ; +1 (formal-duel), RPG §4 ledger
    rat-despawn       ; existing despawn path
    drill-counter     ; comedy plist integer
    thought-push      ; via SOCIAL's pinned helper only
    mutter-push       ; via SOCIAL's pinned mutter path only

No bladder number, no purge rate, no contamination arithmetic, no
pathing, no spawn position — the envelope inequality (RPG §5.4) is
untouched: the aesthetic refusal is bounded by the ≥ 2-usable guard,
the alloy deltas are ±1 against a purge economy measured in dozens,
the XP delta uses the existing ledger family.

### 5.3 Delivery — non-modal, the intent grammar

Comedy emits the existing intent shapes (STORY §8.3's constraints,
extended): `(:layer 'log :text … :face 'info|'comedy)`,
`(:layer 'banner …)`, popup particles via `cistern--field-spawn`
(floor-only, Q25). Pinned:

- **One banner per tick, sector-wide.** Comedy takes the banner slot
  ONLY if story-eval and combat emitted none this tick — comedy-eval
  runs after both, so the arbitration is a read of their returned
  intents, deterministic by construction.
- **Log share ≤ 3 comedy lines per tick** (a 3-tick thread counts
  one per its ticks); story and social keep their budgets untouched.
- New face role `comedy` (S2-derived palette, standard emphasis —
  never an alert role; a joke must not look like a fire).
- The death panel, ceremony, condemnation sequence, and goal-card
  banner are PROTECTED surfaces comedy never touches (S3/S5).

### 5.4 Batch testability — the beat-schedule fixture

The director is a pure function of (seed, banks, state); the test
suite drives `cistern--comedy-eval` headless per tick over the soak
and asserts the EXACT schedule — `(tick archetype-id)` pairs — for
seed 20260830 and the example bank (the STORY §10 shape: 4 whimsey
entries + 2 thought entries is enough to pin every selection branch).
Two runs of one seed produce byte-identical `comedy` plists including
`comedy-pos` (C9). The Clock B driver backstop is the one deliberately
non-sim surface, tested by time injection (§1.5 item 4).

### 5.5 Width discipline

Bank copy templates ≤ 60 raw chars; format args bounded by the entry
(`:draws` selectors resolve to ≤ 8-char tokens — glyphs, `g<N>` ids,
short numerals). Inspector annotations comedy may add (`DIALECT
ACTIVE`, the `:place-names` alias) degrade FIRST, before SOCIAL's
thought/quirk/mood segments (SOCIAL §4.5's order extended: comedy
annotations → thought → quirk → mood → base). The rendered-line
capture test (C10) covers log, banner, and the maximal inspector
line at 95 cols.

### 5.6 Soar protection

- **S1 inspector standard** — comedy annotations degrade first and
  never widen the base inspector; the dry channel LIVES in the
  persona clause, making the inspector funnier without changing a
  base byte.
- **S2 pressure voice** — the `comedy` face role derives from the
  standard palette; PRESSURE-family lines are never comedic, and
  comedy lines never reuse alert faces.
- **S3 popups-at-act** — comedy popup particles reuse the field
  path, floor-only, and never fire on act-rollover ticks (S4 of
  §1.2 keeps those quiet anyway).
- **S4 purge economy** — the alloy whitelist is ±1 bounded; tank
  loads move once per rivalry, through the STORY §6.4 effect family,
  +1 only.
- **S5 non-modal** — everything is log/banner/particle/hint; the
  Clock B nudge is a hint-slot line; nothing waits on the player.

---

## 6. ACCEPTANCE CRITERIA (fail-first; each lands red per R10)

**C1 the guarantee.** Seed 20260830, 900-tick auto soak, example
bank: the intent stream's comedy lines satisfy every calm 750-tick
window ≥ 1 beat, max calm gap ≤ 750; forced-manual variant: max calm
gap ≤ 150; the raid-spanning variant delivers its latched beat within
5 ticks of calm; fails while the director does not exist.

**C2 the dual clock.** The auto-mode soak forces beats at 750-tick
budget boundaries and never at 150; the manual-mode run forces at
150 and never at 750; `:due-p` is nil whenever no suppression span
overlapped the budget; fails while the budget is mode-blind.

**C3 suppression.** With a raid open: zero comedy intents; a
`worker-death` event at tick T yields zero comedy intents for ticks
T..T+40 inclusive; contamination 15 suppresses; act rollover ±10
suppresses; the density dampener halves `:loud` weights (asserted on
the schedule fixture); fails while any rule is unwired.

**C4 selection.** Same seed + banks → byte-identical beat schedule;
anti-repeat: no archetype id twice within any 3 consecutive beats;
the fallback family covers a state where no other archetype is
eligible; per-archetype cooldown honored; fails while selection is
unpinned.

**C5 aesthetic refusal.** With the beat armed and ≥ 2 usable
fixtures: the marked fixture's seating attempt fails that tick, the
worker reroutes next tick, and no worker is ever left seatless (a
1-usable-fixture state never arms the beat — asserted across a 50-
seed sweep); fails while refusal is copy-only.

**C6 footprints commit.** Workers-comp grants +1 alloy; inventory-
audit lands exactly one ±1; successor-letter grants +1 on a demolish
event; the drill counter tallies in the act-rollover line; the
complaint counter flags on the third filing; every delta is on the
§5.2 whitelist (a bank entry naming anything else fails the loader);
fails while footprints are unpinned.

**C7 romance slots.** A pinned stage-2 transition produces the
CO-SIGNED banner (banner-free tick) within 10 ticks and exactly one
rival mutter through the social push; `:last-beat-tick` unchanged by
priority-slot beats; stage transitions during a raid produce zero
comedy intents; fails while slots are unwired.

**C8 the dry channel.** Comedy private thoughts: ≤ 1 per 60 ticks,
pushed only via the social helper, never for a CRITICAL-mood worker,
private-only (no log line, SC5's assertions hold); fails while the
channel spams or leaks.

**C9 stream hygiene + determinism.** No comedy symbol calls
`cistern--rand`, reads `particle-rng`/`rpg-pos`/`combat-pos`/
`social-pos`/`roll-pos`, or advances any position but `comedy-pos`;
two seed-20260830 300-tick runs produce identical hashes including
`comedy-pos` and every whitelisted footprint; fails on any leak.

**C10 copy + width.** Every comedy string resolves through the
`(comedy . ...)` table or bank `:copy` (A15's grep rule); rendered
log/banner lines ≤ 95 cols; the maximal inspector line degrades
comedy-annotation → thought → quirk → mood → byte-identical base;
fails while lines overflow or literals leak.

**C11 the README.** The run block, the M-x line, the two doc links,
and the fixture-catalog numeric cells are string-equal to the pre-v5
README (extracted-block assertion); dossier length 130–190 lines;
the §4.4 spot-fact list (contamination 20, pop cap 8, purge pay 1
alloy per 3 waste, thresholds 12/30 XP, budget numbers) all present;
fails while any block drifted.

**C12 contrast content.** Across the soak: no comedy intent within
40 ticks after any violent anchor (mechanical), and no comedy copy
key's rendered text contains the glyph of a worker who died in the
run (copy rule, string-scan over the bank); fails on either.

---

## 7. EXPLICITLY DEFERRED

1. More beat archetypes — the bank format (§2.1) is the whole
   contract; content growth touches nothing in this doc.
2. Comedy reacting to specific STORY hook content (callback gags) —
   needs the production scenario banks first.
3. Persistent grudges beyond the mutter channel — if the social
   ledger later wants queryable feuds, comedy supplies rows, never
   the schema.
4. Generated whimsey copy (the STORY §5 generator for the `whimsey`
   kind) — hand-authored example bank ships first; generation is a
   content pipeline, not an engine change.
