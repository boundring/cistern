# CISTERN v6 — ECOLOGY & SELF-BALANCE LAYER (design only, no code)

Status: DESIGN v1, 2026-09-08. Ambient predator ecology (the rat fix) and
the self-balancing sweep over v5's hand-tuned valves. Consumes COMBAT v5
(bestiary, entity struct, spawn table, phase order, matrix machinery),
RPG-LAYER v4 (stat schema, stream discipline, band vocabulary), the domain
sim (`src/cistern-domain.el` — `cistern--phase-hostiles`, `cistern--combat-const`,
the copy table), V5-SPEC §0/§4 carried guards, and FAILURE-LEDGER L-094/L-108
(the review authority's structural findings; L-108 #5 names the const blocks
as the natural first split — this layer's consts form their own block, which
is that split's first shovel, not its scope).

Owner intent, restated once:

1. Rats always immediately collect on pipes and gnaw through them. The
   player needs AUTOMATIC countermeasures — ambient threats that scare
   rats away (cats, dogs, other animals).
2. Wherever the game has chances to BALANCE ITSELF, take them. Self-
   balancing mechanics replace hand-tuned valves. Keep anti-patterns
   out of the gameplay.

Governing constraints, verbatim binding on every section:

- Least-active-decisions: reuse the entity struct, the dossier roll, the
  margin-band + matrix pipeline, the retreat machinery, the `idle` scratch
  slot, the armed-verb refusal pattern, the copy table. New state fields:
  ZERO (§5.3).
- Copy through `cistern--copy`, Nihei register, new `(ecology . ...)`
  subsection, keys prefixed `ecology-` (§4). Everything batch-testable.
- PROTECT carried from V5-SPEC §0: five soars, 95-col width contract
  (bank templates ≤ 60 raw chars), L-076 pin route for every new glyph,
  deterministic-envelope guards (bladder-window ≥ 22 UNTOUCHED), comedy-
  violence contrast rule, rewards-eval sole drainer (ecology pushes
  events, drains nothing).
- ANTI-PATTERN GUARD (owner brief): no hidden rubber-banding. Every loop
  below obeys three rules: the feedback signal is a PURE READ of live
  state (no accumulators, no history the player cannot see); every move
  the ecology makes is announced through the copy table; every formula
  lives in ONE pinned const block. The player can always answer "why did
  that happen" from the log.

---

## 1. The rat problem, diagnosed — and the menagerie

### 1.1 Why rats rush the pipes (current loop, pinned facts)

The v5 rat is a bullet the player must intercept by hand:

- **Spawn**: `cistern--maybe-infestation` fires S3 every 20 ticks at
  DC = 14 − severed lines (min 8) — and the rat is BORN at a dead pipe
  (`cistern--dead-pipe-cell`), i.e. spawned at its own target. Damage
  does not repel rats; it summons them closer.
- **Behavior** (`cistern--rat-behavior`): step toward the nearest
  dead-then-any pipe; standing on it, gnaw for 3 ticks → severed line
  (L-040 split). The bestiary pins "flee-nothing (fights to the end)".
- **Counter-pressure**: the ONLY automatic threat is worker auto-defense
  (dmg-minor vs DEF 10 + GRIT mod, rat HP 4 ≈ two hits) — which requires
  a worker standing adjacent to the pipe being defended. Crabs repel no
  one. There is no fear response anywhere in the rat's loop.

So in any stretch where no worker happens to be next to the joint, the
gnaw completes. The player's countermeasure is babysitting. That is the
defect: the rat's loop has an input (pipes) and no negative feedback.

### 1.2 The fix: FACTION `feral`, two ambient assets

One new faction on the EXISTING entity struct — no second creature
system. Predators are full entities: stable id, 4d6-drop-lowest × 4
dossier from stream 4 (the institutional ruling — ALL fauna audits on
the same maintenance form), ATK = FLOW mod, DEF = 10 + GRIT mod, HP =
kind-base + GRIT mod. They strike through the SHARED pipeline
(`dmg-minor` matrix, band promotion, miss-logs-nothing).

| kind | faction | glyph | HP base | behavior loop (priority order) |
|------|---------|-------|---------|-------------------------------|
| **vent cat** `k` | feral | `k` | 6 | hunt: step toward nearest rat or leech (coordinate-order tie) → adjacent: one attack roll (dmg-minor) → patience: idle ≥ `feral-patience` → walk to nearest edge, despawn (retreat machinery reused) |
| **sector dog** `d` | feral | `d` | 8 | maintenance round: step toward nearest rat (no attack — the dog never kills) → quiet: idle ≥ `dog-patience` → walk to nearest edge, despawn |

- **The cat culls.** Rat HP 4 vs dmg-minor band 1–3 → a catch in ~2
  adjacent ticks. Kills grant NO XP (`cistern--enemy-damage` already
  gates the grant on a worker killer); the kill logs once (§4).
- **The dog deters.** It is the scheduled countermeasure the owner asked
  for: it runs regardless of rat pressure (§2.1 dog schedule), flushes
  rats to the edges, and never draws a strike roll. Cats handle the
  vent-hunt (leeches included); the dog handles ground flight.
- **Cats do not audit charters.** Feral entities never target workers or
  goblins (either charter); neither charter targets them: auto-defense
  targeting extends its guild filter to `feral`, FOCUS on a feral entity
  refuses via `ecology-refusal` and consumes NO draw (the C5 pattern,
  §6 EC5). A cat walking through a raid is nobody's problem. Comedy may
  disagree; that is the comedy pass's business, not this layer's.
- **Glyphs** `k`/`d`: single ASCII cells, distinct from the tile table,
  particle palette, worker α–θ, and enemy `g G r c e s`; both route the
  L-076 gui probe as an acceptance test (§6 EC13).

---

## 2. The predator-prey loop — the self-balancing valve

### 2.1 The loop, one paragraph

Rat pressure summons cats; cats press rats back down; when the food runs
out the cats leave. No spawn table of fixed counts — the player's neglect
is the attractant, and the countermeasure dissolves when the neglect
ends.

### 2.2 The feedback signal — RAT PRESSURE

    P  =  2 × (live rats)  +  (severed lines)

A pure read of live state, evaluated at the draw point. No accumulator,
no history: if the log and the map show N rats and M severed lines, the
player can compute P by hand. Every number that drives the loop is
already player-visible.

### 2.3 Response function — cat arrival

Every 20 ticks (`feral-every`, the infestation cadence), while feral
count < `feral-max` 2, ONE d20 on stream 4:

    DC = clamp(20 − P, 6, 21)

- P = 0 → DC 21 → unreachable. A clean sector draws no cats.
- P = 6 → DC 14. P = 10 → DC 10. P ≥ 14 → DC 6 (near-certain).
- Success: one vent cat dossier (12 d6) rolled at the pinned tail slot
  (§5.2), spawned at `cistern--edge-spawn-cell`, `feral-arrival` event +
  `ecology-cat-arrival` log.

The DC floor of 6 is the anti-plague guarantee's other half: even at
maximum pressure, two cats is the whole response — the valve cannot
overshoot into a vacuum (§2.5).

**The dog is NOT part of the valve.** The sector dog is institutional
routine, not feedback: one maintenance round every `dog-every` 240
ticks, unconditional, consuming NO arrival draw (its 12-d6 dossier only).
It exists so that automatic countermeasures run even when P is small —
the loop self-balances the cull; the schedule self-balances nothing, on
purpose. The valve answers "are there too many rats"; the round answers
"is the Sector inspected".

### 2.4 Food ceiling — predator departure

Predators are on the food clock, using the EXISTING `idle` scratch slot
(the fixer loop's):

- +1 per tick with no catch AND no prey within `feral-forage` 4
  (Chebyshev); a catch resets idle to 0. Dog: no catch possible; prey
  within 4 resets.
- idle ≥ `feral-patience` 60 (cat) / `dog-patience` 40 (dog) → the
  entity retreats (existing retreat machinery: walk to nearest edge,
  despawn) + `feral-depart` event + `ecology-depart` log.

This is what makes it a LOOP and not a valve with a sticky output:
predators cannot outlive the food for more than ~60 ticks.

### 2.5 The equilibrium band and its two floors

    rat band  =  clamp(severed lines, 0, rat-band-max 3)

**The ecology holds the infestation at the size of the neglect** — about
one rat per severed line, never more than 3 in steady state:

- **Anti-plague (ceiling).** Stacked mechanical caps: `feral-max` 2 cats
  culling + flight (§2.6) draining rats to the edges + `hostiles-max` 8
  as the hard shared cap. Rats can spike above the band ONLY while
  severed ≥ 3 AND cats sit at their cap — that transient IS the
  escalation window the infestation events and story hooks already
  sell; the loop closes it without player intervention.
- **Anti-extinction (vacuum floor).** Three stacked mechanisms, so the
  ecology can never collapse into a rat-free game:
  1. The infestation DC floor of 8 (existing) — while neglected, rats
     keep spawning.
  2. Even at 0 severed (DC 14), one draw per 20 ticks returns a rat in
     ~57 ticks expectation.
  3. Predator patience 60: at zero food the cull STOPS within ~60
     ticks. A rat-free sector decays back toward rat-full on its own.

Stable states of the loop (each observable in the log):

| State | Condition | Loop behavior |
|-------|-----------|---------------|
| NEGLECTED | severed ≥ 3 | P high → cats arrive → rats flee/die → P falls |
| MAINTAINED | severed 0–2 | P small → no cats; dog round still sweeps |
| RECOVERED | rats 0 | cats idle out ≤ 60 ticks → depart → valve resets to DC 21 |

### 2.6 Rat flight — the instinct (no draw)

The rat's loop gains a priority-0 rule, mechanical like the leech drain
(NOT rolled, consumes NO stream draw):

- If any feral entity is within Chebyshev 2 (`feral-scent`), the rat
  steps DIRECTLY AWAY (tie: coordinate-order first step that increases
  distance); gnawing is suspended while fleeing.
- A fleeing rat reaching a map edge despawns + `ecology-vermin-routed`
  log.

Flight is why cats suppress without exterminating: most rats leave
before the second hit lands, which feeds the vacuum floor — the cull
rarely needs to be lethal. This is also the owner's literal ask
delivered: the rat's fear response, absent in v5, now exists and is
automatic.

---

## 3. The self-balancing sweep — every valve audited

The owner's rule: wherever the game can balance itself, it does. For each
valve: the signal, the response, the equilibrium, and the failure mode
experienced when the loop works vs when it is broken. Valves that are
correctness invariants stay PINNED (§3.6) and are named as such so no
future pass "improves" them.

### 3.1 Raid size — the wealth valve (replaces the act-only clamp)

- **Was**: raider count `clamp(pop − 1, 1, 3)` act II / `clamp(pop − 1,
  2, 4)` act III — a function of act and pop only; a destitute sector
  and a hoarded one drew identical raids.
- **Signal**: `W = (total tank load) + 2 × (banked alloy)` — pure state
  read (`cistern--tank-load-total` + the alloy field).
- **Response**: `n = clamp(1 + floor(W / 15), 1, min(act-cap, pop − 1))`
  — act caps survive as the CEILING; wealth picks inside it. The
  raid-open log gains `ecology-raid-claim` ("CLAIM VALUE ASSESSED — %d
  UNITS — RAID SCALE SET") — the warband's raid is explicitly a
  repossession sized to the loot, in their own doctrine.
- **Equilibrium**: raid size tracks recoverable wealth. Hoarding alloy
  buys bigger raids; spending it on pipes and fixtures starves them.
- **Working**: the player who dumps wealth into infrastructure faces
  shrinking warbands; the stockpiler funds their own siege. **Broken**:
  would-be rubber-banding is ruled out by construction — the signal
  cannot know whether the player is succeeding, only what lies unspent;
  and the assessment is announced, never hidden.

### 3.2 Guild effort — triage scales to damage rate

- **Was**: `guild-every` 40 / `guild-max` 3, fixed regardless of how
  many lines were down.
- **Signal**: severed-line count (existing `cistern--severed-count`).
- **Response**: arrival draw cadence 20 while severed ≥ 3 (else 40);
  restorations per visit 5 while severed ≥ 4 (else 3). The v5 constants
  become the FLOORS of the response, not the response. Escalation and
  de-escalation log once per transition edge (`ecology-guild-escalate`).
- **Equilibrium**: guild presence ≈ damage rate. The guild is the
  contamination-pressure response the owner sketched: the sector's
  neglect summons institutional repair at proportional effort.
- **Working**: a collapse pileup brings multiple fixer visits; a tidy
  sector sees the guild rarely. **Broken**: guild overwhelms — but that
  state is precisely the "fix it yourself" alarm, and it is visible
  (the escalation line names the count).

### 3.3 Comedy pacing — the tension gap

- **Was**: `cistern--comedy-dry-gap` 60 fixed.
- **Signal**: tension `T = [raid open] + [contam ≥ 12] + [severed ≥ 1]`
  — 0..3, pure state read.
- **Response**: `gap = 60 + 40·T` (60 / 100 / 140 / 180). The calm-40
  window after violent anchors is UNCHANGED — it is the comedy-violence
  contrast invariant (CY12), not a pacing valve.
- **Equilibrium**: comedy rate is inversely proportional to tension.
  Quiet sectors banter; war zones go silent — the contrast rule stops
  being only a suppression and becomes a gradient.
- **Working / broken**: no hard failure exists — worst case is a long
  quiet stretch, which is the intended read of a tense sector. The gap
  lives in the comedy tracker plist (batch-assertable, §6 EC12).

### 3.4 Migrant gate — the recovery valve

- **Was**: `cistern-migrant-every` 40, fixed — a death spiral had no
  recovery gradient; pop 1 waited the same 40 ticks as pop 7.
- **Signal**: live pop vs the cap.
- **Response**: interval 20 while pop ≤ 3 (REPLACEMENTS PRIORITY —
  `ecology-gate-valve`, logged ONCE per transition edge, de-escalation
  via `ecology-gate-normal`), 40 at pop ≥ 4. `cistern-pop-cap` 8 stays
  a hard ceiling — the valve accelerates refill, never overfills.
- **Equilibrium**: workforce loss auto-recovers toward staffing while
  the sector survives. **Working**: two deaths inside an act no longer
  compound into an unwinnable staffing hole. **Broken**: none observed;
  the log names the cadence change, so it cannot read as a silent rescue.

### 3.5 The marquee: the predator-prey loop (§2)

Replaces the hand-tuned "predator spawn table" this layer would
otherwise have needed. It is listed here for completeness of the audit —
its signal, response, equilibrium and floors are §2's whole subject.

### 3.6 PINNED — correctness invariants, NOT self-balanced

The bladder-window inequality is a correctness proof, not a difficulty
dial, and stays byte-identical:

    window(w) = (120 − seek_eff(w))/2 − use_ticks_eff_max  ≥  22

No loop in this layer writes bladder, bladder rate, seek thresholds
beyond the existing clamp, use ticks, purge rate, or costs — P4 verbatim,
extended: NO ECOLOGY EFFECT WRITES A WORKER NUMBER EITHER (cats cull
fauna, not composure). Equally pinned:

- **P1 contamination hard valve** — raid draw suppressed while
  contam ≥ limit − 2 (18). The loss condition is not a resource the
  ecology may negotiate; combat never lands the killing blow on a dying
  sector.
- **`raid-span` 40** — bounded exposure, like an act window.
- **`hostiles-max` 8 / `cistern-pop-cap` 8** — hard ceilings; the valves
  modulate rates, never caps.
- **`spread-pct` 3 / `decay-pct` 2** — the hazard field's physics.
- **Act windows 120/240**; **comedy calm 40** (contrast invariant);
  **raid DC act scaling 8→5** (act is the schedule, wealth is the size).
- **`feral-scent` 2** — a species fixture, not a valve.

Ruling: a quantity may be self-balanced only when a wrong value degrades
PACING; a quantity whose wrong value can make the game UNWINNABLE or
break a proof is pinned.

---

## 4. The player-visible ecology — the institution notices nothing unusual

The Sector does not have wildlife; it has FERAL ASSETS. The ecology is
logged exactly like a purge or a restoration — same severity faces, same
deadpan. All strings through the new `(ecology . ...)` copy subsection
(≤ 60 raw chars each):

    ecology-cat-arrival    . "FERAL ASSETS ON SITE — VENT CAT — CULL AUTHORIZED"
    ecology-dog-arrival    . "SECTOR DOG — MAINTENANCE ROUND IN PROGRESS"
    ecology-vermin-routed  . "VERMIN ROUTED AT (%d,%d) — FLIGHT LOGGED"
    ecology-cat-catch      . "FERAL CULL LOGGED AT (%d,%d) — VERMIN DOWN"
    ecology-depart         . "FERAL ASSET DEPARTS — FORAGE LOGGED INSUFFICIENT"
    ecology-refusal        . "FERAL ASSETS ARE NOT COMMANDABLE — STANDING ORDER 9"
    ecology-raid-claim     . "CLAIM VALUE ASSESSED — %d UNITS — RAID SCALE SET"
    ecology-guild-escalate . "GUILD TRIAGE ESCALATED — %d LINES DOWN"
    ecology-gate-valve     . "GATE CADENCE DOUBLED — REPLACEMENTS PRIORITY"
    ecology-gate-normal    . "GATE CADENCE RESTORED — STAFFING NOMINAL"

- **Arrivals**: cats announce with the rat pressure implicit (the player
  who just watched three lines sever reads the cause); the dog announces
  the round as pure routine. `feral-arrival` / `feral-depart` events
  feed the hook machine's closed grammar (`(event feral-arrival)` — the
  "the Sector has a cat now" premise hook; `(event feral-depart)` — the
  quiet close).
- **The warband losing interest**: the wealth valve makes raid shrinkage
  legible — a player who spent down sees `ecology-raid-claim` name a
  small claim; a routed warband reads as before (`combat-raid-routed`).
- **The inspector**: animals ride the EXISTING `combat-inspect-fmt`
  (glyph, kind, state · HP · DEF · ATK) — no new query path (S1). The
  state word is the only new surface: cats read `ON PATROL`, dogs
  `ON ROUND`, anything past `feral-patience` − 10 reads `DEPARTING`.
  No "last catch" timestamp — the idle state already says it (S1:
  inspector as teacher, not telemetry).
- **Anti-pattern guard, surfaced**: every §3 loop's moves are these log
  lines. A player can reconstruct the whole ecology from the log alone:
  cats came because rats came; rats came because lines severed; the
  guild doubled its rounds; the gate doubled its cadence. Nothing about
  the balancing is invisible; nothing about it is announced with
  meta-language ("DIFFICULTY ADJUSTED" never appears — the institution
  files the weather, it does not explain it).

---

## 5. Determinism & integration

### 5.1 Stream: NO new stream — stream 4, tail-pinned

The combat family owns fauna. Predators reuse the entity struct, the
dossier roll, the margin-band pipeline and the `combat-pos` field; a new
stream would buy a new state field, a new hygiene test, and zero
behavioral difference. **Stream 7+ stays free.** The one non-negotiable
is ORDER: ecology draws append at the hostiles phase TAIL (below), so
every v5 fixture sequence (S1–S6, behaviors, auto-defense) holds
byte-identical, and ecology-OFF runs are byte-identical to the v5 sim
(the `cistern-combat-enabled` precedent: a `cistern-ecology-enabled`
defvar, default nil).

### 5.2 Phase order — one branch, one tail segment, zero new phases

`creators → hostiles → hazards → migration → check` unchanged. Inside
the hostiles phase:

    ...existing: P3 span check → S1–S6 spawn draws →
       per hostile, list order (predators dispatch a new cond branch:
       feral behavior; rats gain the flight check at priority 0) →
       auto-defense (guild+feral filtered) → routed-close check →
    TAIL (ecology, only when enabled):
       1. cat arrival: if (tick % feral-every = 0) and feral < feral-max:
          one d20 vs clamp(20 − P, 6, 21); on success 12-d6 dossier +
          edge spawn                      ← stream-4 draws, in THIS order
       2. dog schedule: if (tick % dog-every = 0): 12-d6 dossier +
          edge spawn (no arrival draw)

The arrival draw is consumed every cadence tick even at DC 21 (the
infestation precedent: the draw is the tick's heartbeat, the branch is
the decision). Migration phase gains only the §3.4 cadence read inside
its existing every-N check.

### 5.3 State — the full footprint

- **New state fields: ZERO.** Predators are `cistern--enemy` entries
  (faction `feral`, kinds `cat`/`dog`) in the EXISTING `hostiles` list;
  `idle` is the food clock; `gnaw`/`drain` unused by predators. The
  count cap check for predator spawns reads the feral subset, not
  `hostiles-max` (pests and predators do not compete for the same cap —
  the shared 8 remains the pests' ceiling).
- **New consts** (one block, `cistern--ecology-const`, beside the combat
  block — L-108 #5's split boundary): `feral-max 2, feral-every 20,
  feral-patience 60, feral-forage 4, feral-scent 2, dog-every 240,
  dog-patience 40, rat-band-max 3, raid-wealth-step 15, gate-cadence
  40/20, guild-every-escalated 20, guild-max-escalated 5,
  comedy-gap-base 60, comedy-gap-step 40, comedy-gap-max 180`.
- **Events**: `feral-arrival`, `feral-depart` pushed to the pending
  list, NON-DRAINING (rewards-eval sole drainer, asserted per EC9).
- **Verbs**: FOCUS on feral refuses (`ecology-refusal`, no draw); no
  new verbs — the ecology requires no management by design.

### 5.4 Batch-testable equilibrium (the soak contract)

Deterministic by construction: same seed ⇒ same pressure ⇒ same cats.
The soak drives `cistern--do-tick` headless with `cistern-ecology-enabled`
t, seed 20260830, a pinned forced-severing schedule (scripted `p`
equivalents at pinned ticks to exercise the band), and samples state
every tick. §6 EC1–EC3 are the equilibrium assertions; EC8 the
byte-identity pair (ecology on × 2, and ecology off vs the v5 sim).

---

## 6. Acceptance criteria (fail-first) + the constants ledger

### 6.1 Criteria

**EC1 pressure response.** Soak with 3 forced severed lines: a vent cat
arrives within 120 ticks (DC 14 at P ≥ 6); a parallel clean-sector soak
(0 rats, 0 severed, 600 ticks) logs ZERO cat arrivals — fails while no
pressure-driven spawn path exists.

**EC2 equilibrium band.** 3000-tick soak with the pinned severing
schedule: rat count within ±1 of `clamp(severed, 0, 3)` for ≥ 80% of
sampled ticks, and never exceeding 4 — fails while the ecology cannot
hold the band or overshoots it.

**EC3 anti-extinction floor.** Same soak: every 100-tick window with
severed ≥ 1 contains ≥ 1 tick with rat count ≥ 1; a forced rat
extinction is followed by a respawn within 200 ticks (pinned draws) —
fails while rats can go permanently extinct.

**EC4 flight.** A rat within Chebyshev 2 of a feral entity steps away
that tick consuming NO stream draw; a fleeing rat at a map edge despawns
with `ecology-vermin-routed` — fails while rats ignore predators.

**EC5 feral guard.** Auto-defense never selects faction `feral`;
FOCUS on a feral entity refuses via `ecology-refusal` consuming NO
draw; no verb sequence can reduce a feral entity's hp — extends C5,
fails while targeting is unfiltered.

**EC6 dog schedule.** A dog arrives every exactly-240 ticks, consumes
NO arrival draw (its 12-d6 dossier only), flushes rats to edges, and
departs after 40 quiet ticks — fails while the dog is draw-driven,
absent, or lethal.

**EC7 food ceiling.** A cat with no catch for 60 ticks departs; a catch
resets its idle counter; departure consumes the retreat path — fails
while predators are permanent.

**EC8 determinism.** Two runs, seed 20260830, 300 ticks, ecology on:
identical state hashes including `combat-pos`, `hostiles`, `raid`;
ecology-off run byte-identical to the v5 sim — fails while ecology
draws are unseeded, out of order, or leak into layer-off runs.

**EC9 stream hygiene.** No ecology symbol calls `cistern--rand` or
touches streams 0–3, 5, 6; `feral-*` event pushes drain nothing —
extends C10, fails on any cross-stream touch.

**EC10 wealth valve.** Same act, same pop, high-W vs low-W states yield
more vs fewer raiders; the raid-open log carries the assessed claim;
CB6's P1 boundary assert (no draw at contam ≥ 17) still green — fails
while raid size is wealth-blind or the valve touches P1.

**EC11 migrant recovery.** Pop 3 → cadence 20 with ONE transition log
line; pop ≥ 4 → cadence 40; pop-cap 8 never exceeded — fails while the
gate is fixed or chatty.

**EC12 tension gap.** Tracker gap reads 60 / 100 / 140 / 180 at tension
0/1/2/3; CY-S1/S2 suppression windows and CY12 unchanged — fails while
the gap is a constant or the calm window moved.

**EC13 width + glyphs.** All §4 copy ≤ 60 raw chars, rendered ≤ 95;
`k`/`d` pass the L-076 gui probe (batch-skipped) — fails while any line
overflows or a glyph renders off-cell.

**EC14 copy sweep.** Every §4 string fetched through `cistern--copy`;
grep-level check finds no new ecology literal in view/game — fails
while lines are hardcoded.

### 6.2 The constants ledger — what the valves replaced

| Constant (v5 pin) | Was | Now |
|---|---|---|
| raider count `clamp(pop−1, act-cap)` | act + pop only | `clamp(1 + floor(W/15), 1, min(act-cap, pop−1))` — wealth valve, announced |
| `guild-every` 40 | fixed | 20 while severed ≥ 3; 40 = floor |
| `guild-max` 3 | fixed | 5 while severed ≥ 4; 3 = floor |
| `cistern--comedy-dry-gap` 60 | fixed | `60 + 40·T`, cap 180; 60 = floor |
| `cistern-migrant-every` 40 | fixed | 20 while pop ≤ 3; 40 = ceiling |
| predator spawn table | did not exist | pressure DC `clamp(20 − P, 6, 21)` — born self-balancing |

**Stays pinned (invariants, §3.6):** the bladder family and the
window(w) ≥ 22 inequality; P1's hard valve (contam ≥ 18); `raid-span`
40; `hostiles-max` 8; `cistern-pop-cap` 8; `spread-pct`/`decay-pct`;
act windows 120/240; comedy calm 40; raid DC act scaling 8→5;
`feral-scent` 2.

### 6.3 Soar protection (carried, per soar)

- **S1 inspector standard** — animals ride `combat-inspect-fmt`; no new
  query paths; the state word is the only addition.
- **S2 pressure voice** — ecology logs are info-severity; they never
  join the PRESSURE family or inherit its faces.
- **S3 popups-at-act** — no ecology popups; the log is the surface.
- **S4 purge economy** — no ecology effect writes alloy, score, or
  purge (the wealth valve READS wealth; it never writes it).
- **S5 non-modal ceremony** — nothing modal; the dog's round is a log
  line, not an event screen.
- **Comedy-violence contrast** — predation is NOT a violent anchor; no
  suppression change; cat copy may not punchline a worker death (the
  CY12 scan is unchanged and covers the new subsection).

### 6.4 Explicitly deferred

1. **Feral personas** on the social census (a cat with a quirk file) —
   the social pass owns the census total order; this layer guarantees
   the attach point (stable id + dossier), nothing more.
2. **Monitor-lizards and further menagerie** — two species cover the
   loop (cull + deter); a third adds a dossier and a cond branch to a
   working valve. Add when a pressure the two don't cover exists.
3. **Cat-vs-warband interactions** — cats do not audit charters (§1.2);
   if the comedy pass wants a cat sitting on a raider, that is bank
   copy, not behavior.
4. **Comedy `:when` predicates for feral presence** — the closed when-
   table would gain one name; engine untouched; defer to the comedy
   pass.
