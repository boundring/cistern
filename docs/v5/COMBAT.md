# CISTERN v5 — COMBAT LAYER (design only, no code)

Status: DESIGN v1, 2026-09-07. Violent emergent events; workers versus
pests and goblins, foe AND friend. Consumes RPG-LAYER v4 (stat schema,
band vocabulary, `(matrix-id . band)` matrix hash, stream discipline),
STORY-ENGINE v4 (hook machine §7, act windows §3.5, event tiers §7.5),
the domain sim (`src/cistern-domain.el` — phases, tile table, severed
split per L-040, flood primitives), SURFACE S3 (glyphs) and the
L-076 measured-glyph rule. Sibling contracts: docs/v5/SOCIAL.md (reads
combat entity facts; combat never reads social state to resolve
combat), docs/v5/COMEDY-DIRECTOR.md (suppresses on raid state).

Owner intent, restated once: emergent events should be VIOLENT. The
game has combat — workers against pests and enemies. Goblins exist in
both directions: a hostile warband that believes the pipes are theirs
by ancient right, and a friendly engineering guild of the same species
under a different charter. A pest or goblin is a FULL ENTITY — stable
id, stats, position, faction — able to enter relationships later
(romance itself is the social workstream's; this doc only guarantees
the attach point).

Governing constraints, verbatim from the owner brief:

- Combat MODULATES the existing sim: bladder/contamination/repair loops
  are the base game; combat layers on top and must never make the
  bladder window unwinnable (pressure valve, §5.4).
- Least-active-decisions: reuse the stat schema, the band pipeline,
  the hazard/severed machinery, the journey mechanism, the armed-verb
  pattern. New state = three fields + one struct (§5.1).
- Copy through `cistern--copy`, Nihei register. Everything
  batch-testable. PROTECT the five soars (§9). 95-col width contract.
- DESIGN ONLY — no code in this pass.

---

## 1. Factions and bestiary

Three factions, one dossier schema. Institutional ruling: ALL fauna —
pest, goblin, sponge — is audited on the same maintenance-dossier form
as the workers. Same 4d6-drop-lowest × 4 draws (FLOW GRIT NERVE
ARCHIVE, scores 3–18, modifier floor((s−10)/2)) from the combat
stream, so every entity in the sim reads its numbers the same way and
the social workstream can key off the identical schema.

Derived combat stats (one formula each, per entity):

    HP  = kind-base + GRIT mod      (hit points; 0 = dead, §3.4)
    DEF = 10 + GRIT mod             (what attack rolls must beat)
    ATK = FLOW mod                  (added to the attack d20)

| kind | faction | glyph | HP base | behavior loop (priority order) |
|------|---------|-------|---------|-------------------------------|
| warband | warband | `g` | 6 | strike → gnaw → steal → harass |
| fixer | guild | `G` | 6 | repair dead pipes for a fee; never attacks |
| rat | fauna | `r` | 4 | gnaw → flee-nothing (fights to the end) |
| crab | fauna | `c` | 5 | occupy a usable toilet; pinches adjacency |
| leech | fauna | `e` | 3 | attach to a worker; drain |
| sponge | fauna | `s` | 8 | immobile; absorbs tank contents; splits |

Glyphs: all ASCII (L-076 measured table: ASCII renders 7px / 0-dev on
Iosevka). Distinct from the tile table, the particle palette, and
α–θ. Caveat, per L-076 mechanism notes: ASCII is measured-safe but
EVERY new glyph still routes through the gui probe
(`font-at` advance == cell width) as an acceptance test (§6 C11);
final picking is the view pass's to confirm.

### 1.1 WAR — the warband (hostile goblins)

Name: **THE INHERITORS OF THE FIRST MAIN** (copy key
`combat-warband-intel`). Doctrine, in their own institutional register:
the pipes predate the Sector; the sanitation crews are trespassers;
every severed line is a restoration, every drawn-down tank a
repossession. They are not wrong about the pipes' age. They are wrong
about everything else.

Behavior loop, pinned priority (one stream draw assigns each
raider one objective at raid open):

1. **strike** — if an adjacent worker exists: attack roll (§3.2).
2. **gnaw** — step toward the nearest live pipe cell; standing on it,
   a 4-tick gnaw timer (no roll) converts the pipe to `hazard`
   (▒): the pipe is GONE, the usual hazard decay applies, downstream
   severance follows from the EXISTING connectivity computation
   (L-040 split untouched), and the player re-lays with `p` at the
   usual cost. No new tile state, no new severance rule.
3. **steal** — step toward the nearest tank with load > 0; standing
   on it, drains 5 units/tick from `:load` (min 0). The load is
   claimed, not dumped: it leaves the sim. Logged per drain burst.
4. **harass** — step toward the nearest non-limping worker (they
   prefer the strong; see the envelope guard, §5.3 P5).

Movement: 1 step/tick through the existing flood-distance field
(`cistern--dist-from`), same walkability as workers. No special
terrain. Retreat at raid close (§4.1): walk to the nearest map edge,
despawn on arrival or at raid end, whichever first.

### 1.2 The pests

| kind | behavior loop | what it breaks |
|------|--------------|----------------|
| **pipe-rat** `r` | gnaws pipes (3 ticks); prefers severed-line joints | severed; §4.3 |
| **clog-crab** `c` | occupies a usable toilet; pinches workers | ACCESS: one seat gone |
| **vent-leech** `e` | band ≥ 2 ATTACHES (`:grip`); drains 1 HP / 4 ticks | worker HP |
| **sump-sponge** `s` | immobile; absorbs 1 unit/tick; splits at 20 (cap P2) | tank contents |

Crab detail: `cistern--free-usable-toilets` excludes crab-occupied
cells — an ACCESS-reality read, not a new rule. Leech detail: the
drain is mechanical, not rolled; pain reaches composure only through
the existing matrices.

The sponge is the absurd-but-deadpan entry: reclassified as fauna by
standing order, its feeding is logged as natural. Copy key
`combat-sponge`. It is killable like everything else; destroying it
spills nothing.

**Driveability.** A clog-crab that takes ANY hit abandons its toilet
and retreats to the map edge (drive-off, despawn on arrival). The
other kinds are killable to 0 HP. A leech whose host dies is removed
with the body.

### 1.3 GUILD — the friendly goblins

Name: **GUILD OF THE OPEN FLANGE** (copy key `combat-guild-intel`).
Same species as the warband, rival guild, rival reading of the same
ancient right: the pipes are an engineering inheritance, and
inheritance is maintained, not seized. They are traders and fixers.

- **Behavior loop:** arrive at a map edge (§4.4) → walk to the nearest
  DEAD pipe → 2-tick restoration (no roll — guild work is certified)
  → the pipe returns to live state, `cistern-cost-pipe` − 1 alloy is
  deducted (their fee is cheaper than your repair; that is the whole
  trade) → repeat. Leaves after 3 restorations or 40 idle ticks.
- **Mechanically distinct from the warband, by construction:** they
  never attack, never gnaw, never steal; their behavior loop is the
  inverse operation (restoration), their arrival is beneficial, and
  they are the only faction the player is forbidden to attack (§3.5
  guard-rail). Their combat stats (HP/DEF/ATK) exist because the
  dossier form is universal — they are simply never rolled for
  offense. The warband ignores them entirely: no goblin-vs-goblin
  combat (deferred, §10); a rival clan arriving is story material,
  not a second war.
- Their loop is READ-ONLY on tanks, pipes, and alloy except the two
  pinned writes: restoring a dead pipe, and the −1 alloy fee.

### 1.4 Entity shape

One struct, one state list — least-active:

```
(cl-defstruct cistern--enemy
  id faction kind x y (stats nil) (hp 0)
  (gnaw 0) (drain 0) (grip nil))
```

- `id` — `g<N>`, sequential counter on state; stable for the entity's
  life. The social workstream keys personas on this id; nothing else
  may collide with it.
- `faction` ∈ `warband | guild | fauna`; `kind` from the §1 table.
- `stats` — the four scores, same schema as workers.
- `grip` — enemy id the leech is attached to (leech only).
- Spawned entities append to `hostiles`; iteration order is spawn
  order, never sorted. Removed on death, drive-off arrival, or
  retreat; never re-ordered in place.

---

## 2. Entity lifecycle — spawn logic (roll-driven, act-scaled)

All draws from stream 4 (§5.2). Spawns consume the stream in a pinned
call order: raid roll → per-raider stat blocks (12 d6 each, in spawn
order) → objective draws → later, per-tick behavior draws.

| # | Spawn | Fires | Draw | Result |
|---|-------|-------|------|--------|
| S1 | raid open | act II/III window open (§4.1) | d20 ≥ raid-dc (8 / 5) | warband raid |
| S2 | ambush | worker isolated (§4.2) | d20 ≥ 13 | 2 rats at isolated plumbing |
| S3 | infestation | every 20 ticks | d20 ≥ 14 − severed (min 8) | 1 rat at a dead pipe |
| S4 | leech drop | flood tile open ≥ 20 ticks | d20 ≥ 12 | 1 leech at the flood |
| S5 | sponge bud | flood open ≥ 20 ticks, alt draw | d20 ≥ 14 | 1 sponge on the flood |
| S6 | guild fixer | severed ≥ 2, none present, per 40 ticks | d20 ≥ 12 | 1 fixer at map edge |

Act scaling: raid DC drops with act (8 → 5) and raider count rises
(§4.1); infestation DC falls as severed lines accumulate — ignoring
damage breeds rats. S3/S4/S5 are checked in that pinned order once
per tick when their cadence fires.

---

## 3. Combat resolution — D&D-style on the existing core

### 3.1 One roll, one band, one lookup

The v4 pipeline is reused verbatim; no second band vocabulary:

    roll   = d20 (stream 4, mid-bits slice, §5.2)
    margin = roll + ATK − DEF
    band   = shared margin-band (≤−5 → 0, −4..−1 → 1, 0..+4 → 2,
             ≥+5 → 3) with nat-20/nat-1 promotion pre-lookup
    outcome = gethash (dmg-matrix-id . band) → effect plist

Damage matrices (domain const, load-time fold into the EXISTING
`cistern--matrix-hash` — one loader, one hash, A9 shape):

    dmg-minor:   0 (:dmg 0)  1 (:dmg 1)  2 (:dmg 1)  3 (:dmg 2)
    dmg-warband: 0 (:dmg 0)  1 (:dmg 1)  2 (:dmg 2)  3 (:dmg 3)

Band 0 is a MISS (damage 0, no log spam — misses log nothing).
Attacker → matrix: worker, rat, crab, leech, sponge → `dmg-minor`;
warband → `dmg-warband`. Two matrices, not six: the kind-specific
verbs below are post-lookup rules, not extra matrix ids.

### 3.2 Attack points (event-driven; the §3.4 RPG rule holds)

- A hostile adjacent to a worker strikes ONCE per tick, on the
  hostile's move (hostiles phase, §5.1). No attack while the worker
  is seated mid-use; crabs occupying a toilet are the counter — the
  seat is already unusable.
- A worker adjacent to a hostile auto-defends: one attack per tick,
  rolled in creators-list order after the hostiles phase. Target
  selection: the player's `focus` target first (§4.5), else the
  nearest adjacent hostile — ALWAYS filtered to exclude faction
  `guild` (§3.5). Seated workers do not attack.
- Kills and drive-offs grant the killing worker +1 XP (the §4 RPG
  ledger; clearance machinery untouched).

### 3.3 Worker injury — effects on EXISTING numbers only

Worker `hp` field (new, §5.1): max = 8 + GRIT mod, rolled at spawn
alongside the dossier. Damage subtracts from `hp`. Three injury
states, each named in the owner's terms:

| State | Trigger | Mechanical effect (existing numbers only) |
|-------|---------|------------------------------------------|
| **LIMP** | hp ≤ 60% | 1 step per 2 ticks; stride off; SUSPENDED on relief journeys (P5) |
| **SHAKEN** | hp ≤ 40% | NERVE −2 → seek_eff inside the EXISTING clamp [50,68] |
| **mining loss** | hp < max | mine rate +1 via the EXISTING clamp; never mobility |

Healing: +1 hp per shift boundary (tick % 40 = 0). No cost, no roll —
deterministic recovery. Copy keys `combat-injury-limp`,
`combat-injury-shaken`. Bladder arithmetic is UNTOUCHED: no combat
effect adds bladder directly; pressure arrives only via the existing
composure matrix (bounded +10 spike) and via the world getting worse
(severed lines → longer walks, the base game's own lever).

### 3.4 Worker DEATH — spec (the sim currently has none)

At hp ≤ 0, in the same phase the damage landed:

1. The worker is removed from `creators`. Any journey is dropped; if
   mid-use, the toilet's `:busy` clears; any leech gripping them is
   removed with the body.
2. Identity does NOT shift: `cistern--worker-glyph` currently indexes
   position in the creators list — after a death the survivors would
   silently renumber (β becomes α). PIN: the worker struct gains a
   stable spawn-index at creation and the helper reads it; a death
   renames NOBODY (fail-first, §6 C4).
3. Log `combat-worker-death` (alert severity, faced log); the dead
   worker's service record is sealed, never re-issued.
4. Event `worker-death` joins the pending list → the STORY-ENGINE
   hook machine may open a mourning hook (§4.6). The engine's
   non-modal rules are untouched.
5. The population cap absorbs the loss: the migrant cadence
   (`cistern-migrant-every`) keeps firing while pop < cap, so the
   roster refills at the usual pace. No fee, no spawn roll beyond the
   §1.1 dossier draws. Death is permanent for the lost identity.
6. Combat itself pauses them no further: if pop would reach 0, the
   raid pressure valve (§5.3 P1) prevents the last worker from being
   hunted — the base game's own loss conditions stay the only way to
   lose.

### 3.5 Guard-rail — the guild is never attackable

- Worker auto-defense targeting EXCLUDES faction `guild` (the §3.2
  filter). No attack path — roll, splash, or retaliation — exists
  against them: hostile fire is not modeled goblin-vs-goblin, and
  workers only strike what targeting selects.
- The player's `focus` verb on a guild entity REFUSES with
  `combat-refusal-friendly`, same verdict style as R7 refusals. No
  state changes, no roll consumed (a refused verb consumes nothing —
  stream discipline, §5.2).
- The rail is fail-first testable: no sequence of player inputs can
  put a guild entity at 0 HP from worker action (§6 C5).

---

## 4. Violent emergent events

Each violent event is a story-hook the EXISTING hook machine can
open: combat pushes event kinds into the pending list story-eval
already reads (non-draining, STORY §8.1); new hook kinds are
scenario-bank hooks whose `:condition` is `(event KIND)` — the
loader's closed grammar (`event | tick`) is untouched; the KIND
vocabulary gains the §4.7 list.

### 4.1 Raids — warband strikes during act windows

At the act II and act III window floors (120, 240 — STORY §3.5
constants), one raid draw (S1). Success opens a raid: state field
`raid` = `(:open T0)`, n = clamp(pop − 1, 1, 3) raiders in act II,
clamp(pop − 1, 2, 4) in act III, each rolled per §2 and assigned an
objective (d20 mod 3 → gnaw/steal/harass). One `raid` event OPEN.
At most ONE raid per act window; raid span ≤ 40 ticks, then forced
withdrawal: `raid` = `(:last-end T)`, survivors retreat, one `raid`
event CLOSED, and if every raider was killed or driven off first, the
close carries `warband-routed` instead (a better story hook — the
workers held the main).

### 4.2 Ambushes at isolated plumbing

Per tick, if a worker stands adjacent to a pipe at flood-distance ≥ 6
from every other worker (isolation read through the EXISTING flood
primitive), one S2 draw. Success: 2 rats spawn adjacent, one `ambush`
event, copy `combat-ambush`. This is the "isolated plumbing" tax: the
base game already punishes lone long walks; ambush gives it teeth.

### 4.3 Pest infestations — escalating if ignored

S3 every 20 ticks: DC = 14 − (number of currently severed lines),
min 8. Ignored gnaw damage LOWERS the DC — the infestation compounds
exactly the way the base game's contamination does. S4/S5 make flood
tiles costly to ignore. Each success logs one `infestation` event;
copy `combat-infest`.

### 4.4 Guild arrival — the beneficial counterpart

S6: while ≥ 2 lines are severed and no fixer is present, one draw per
40 ticks. Arrival logs `guild-arrival`; their loop runs (§1.3);
departure logs `guild-depart`. The guild arriving mid-raid is legal
and delicious: they fix what the raid breaks, for a fee, without
being asked.

### 4.5 Player verbs — management-shaped, no twitch

Workers already auto-defend (§3.2); the player commands placement and
priorities. Two verbs, both riding the EXISTING armed-verb pattern
(arm → badge shows it → click resolves):

| Key | Verb | Resolve (click) | Effect |
|-----|------|-----------------|--------|
| `f` | FOCUS | on an enemy | `focus` = its id; defenders prefer it; cleared on death |
| `h` | RALLY | on a floor cell | non-seated workers set `journey` there; resume seek-work |

No new rolls, no per-worker stances, no health bars to babysit: the
player shapes WHERE the violence happens; the dice roll through the
same pipeline as every other check. Emacs aliases follow the S4
pairing table (C-h/C-f style, additive only) — a driver-pass note,
not combat scope.

### 4.6 Story hooks — new kinds for the hook machine

Event kinds combat emits into the pending list (rewards-eval ignores
foreign kinds; story-eval reads them):

    raid (OPEN + CLOSED lines) · ambush · infestation ·
    worker-death · warband-routed · guild-arrival

Hook-shape expectations (bank content, not engine changes):
`(event raid)` — the raid as premise spine; `(event worker-death)` —
the mourning hook, one-shot per session, resolve-copy per STORY §7.3
callback rules; `(event warband-routed)` — the triumph variant;
`(event ambush)` / `(event infestation)` — escalation beats. Matrices
for these hooks arrive through the normal bank pipeline; combat's own
damage matrices are domain consts, not banks. Comedy's suppression
window reads `raid` directly (sibling contract, already agreed).

### 4.7 Copy — through the table, Nihei register

New `cistern--copy` subsection `(combat . (...))`, keys prefixed
`combat-`:

    combat-raid-open      . "RAID — THE INHERITORS CLAIM THE MAIN — %d HOSTILE"
    combat-raid-close     . "RAID CLOSED — THE INHERITORS WITHDRAW — CLAIM NOT RECOGNIZED"
    combat-raid-routed    . "THE MAIN HOLDS — INHERITORS ROUTED — THE SECTOR REMAINS SERVED"
    combat-ambush         . "AMBUSH AT ISOLATED PLUMBING — (%d,%d)"
    combat-infest         . "INFESTATION — GNAWING LOGGED AT (%d,%d)"
    combat-gnaw           . "LINE SEVERED BY GNAW AT (%d,%d) — RE-LAY (p)"
    combat-tank-raid      . "TANK (%d,%d) DRAWN DOWN — %d UNITS CLAIMED"
    combat-injury-limp    . "WORKER %s INJURED — LIMP LOGGED — GAIT NORMALIZED ON RELIEF RUNS"
    combat-injury-shaken  . "WORKER %s SHAKEN — NERVE DEGRADED — WATCH THE THRESHOLD"
    combat-worker-death   . "WORKER %s LOST — SERVICE RECORD SEALED"
    combat-leech-grip     . "VENT-LEECH ATTACHED — WORKER %s — CUT IT OFF"
    combat-drive-off      . "CLOG-CRAB DRIVEN OFF — (%d,%d)"
    combat-sponge         . "SPONGE MASS RECLASSIFIED FAUNA — FEEDING LOGGED AS NATURAL"
    combat-guild-arrival  . "GUILD OF THE OPEN FLANGE ON SITE — RESTORATIONS AT %d ALLOY"
    combat-guild-fix      . "GUILD RESTORATION COMPLETE AT (%d,%d)"
    combat-guild-depart   . "GUILD DEPARTS — WORK ORDER CLOSED"
    combat-refusal-friendly . "GUILD STANDING — NO HOSTILE ACTION AGAINST CHARTERED ENGINEERS"
    combat-warband-intel  . "THE PIPES PREDATE THE SECTOR. SANITATION IS TRESPASS."
    combat-guild-intel    . "GUILD OF THE OPEN FLANGE — RESTORATIONS AT ONE ALLOY"
    badge-focus           . "ARMED: FOCUS"
    badge-rally           . "ARMED: RALLY"

---

## 5. Determinism & integration

### 5.1 Layer ownership — new state, exactly this much

| Concern | Layer | Shape |
|---------|-------|-------|
| Entity struct, brains, attack math, spawns | domain | pure integer math, explicit positions |
| Enemy movement, gnaw→hazard, tank drain | domain | existing primitives; no new tile kinds |
| Phase scheduling | domain | one new phase `cistern--phase-hostiles` |
| Targeting/verb refusal copy, all combat copy | domain copy table | §4.7 |
| `f`/`h` verbs, focus/rally click routing | game layer | existing armed-verb pattern |
| Glyphs + faces (`cistern-goblin`, `cistern-pest`, … via S2 roles) | view | render only |

New state fields (three, plus one struct):

    hostiles     ; list of cistern--enemy — the full entities
    combat-pos   ; stream-4 position (seed ⊕ 4), pos-in/pos-out
    raid         ; nil | (:open T0) | (:last-end T) — comedy reads this
    focus        ; enemy id or nil (the player's FOCUS designation)

Worker struct gains `hp` and a stable spawn-index (§3.4) — two fields,
one of which is a bug fix pinned by combat's arrival.

Phase order (pinned): `creators → hostiles → hazards → migration →
check`. Hostiles run after the workers move (so adjacency reads
post-move state) and before hazards (gnaw-made hazards participate in
the same tick's decay/spread). Story-eval and rewards-eval stay
exactly where they are.

### 5.2 Stream discipline

Child stream id **4** (`seed ⊕ 4`) — 0 reserved, 1 story-gen, 2
story-runtime, 3 RPG; 4 is the first free id. Position on state as
`combat-pos`, pure pos-in/pos-out like `rpg-pos` and the particle
position. Same recurrence, same mid-bits slice (`ash pos −6` before
the mod, RPG §3.2 ruling — one rule, all streams). NEVER the sim LCG,
never streams 0–3, never the social stream (5, sibling contract).
Pinned per-tick consumption order: S-spawn draws (§2 order) → per
hostile, in list order: one brain/objective draw if due, then attack
rolls → worker auto-defense rolls in creators order. Social layer
reads events only; combat never reads social state to resolve
combat. Two runs of one seed produce byte-identical state hashes
including `combat-pos`.

### 5.3 Balance guards — the pressure valve

The base game's win/loss must stay reachable exactly as before;
combat modulates pace, never the envelope.

- **P1 — contamination valve.** A raid may not OPEN while
  `contam ≥ cistern-contam-limit − 2` or pop ≤ 1: the base loss
  condition stays a pure base-game event; combat never lands the
  killing blow on a dying sector.
- **P2 — numeric caps.** Raiders ≤ pop − 1 (there is always someone
  left); live hostiles ≤ 8 (the pop cap, mirrored); sponge split
  respects the cap (excess unit banked, no split).
- **P3 — bounded raids.** Raid span ≤ 40 ticks, then forced
  withdrawal — exposure to violence is a bounded window, like an act
  window.
- **P4 — the envelope is untouchable.** No combat effect writes
  bladder, bladder rate, seek thresholds beyond the EXISTING clamp,
  use ticks, purge rate, or costs. Damage is HP; pressure arrives
  only through the composure matrix and through the base game's own
  lever (severed lines → longer walks).
- **P5 — limp vs the relief window.** Limping on a relief journey
  could blow the envelope (28-step walk at half speed beats every
  burst clock). PIN: limp is SUSPENDED on relief journeys — the gait
  normalizes until the worker is seated (copy sells it, §4.7). The
  §5.4 RPG envelope inequality is therefore UNCHANGED: A12 re-runs
  green with combat loaded. Mining and rally journeys limp normally
  (mining loss is already the punishment slot).
- **P6 — batch guard.** Soak assertion: with combat active, every
  worker's window(w) ≥ 22 (the §5.4 A12 guard, unmodified), hostiles
  cap ≤ 8, raid state ∈ the three legal shapes.

### 5.4 Width contract (95 cols)

All combat copy templates ≤ 60 raw chars (the bank rule, applied
voluntarily); log/banner lines render ≤ 95 (§6 C11). Entity glyphs
are single ASCII cells; the map's fixed-cell render contract (Q25,
L-076) is untouched — enemies render through the same overlay/z-order
path as workers, floor-only.

---

## 6. Acceptance criteria (fail-first)

Each lands as a red test before its implementing commit (R10).

**C1 entity spawn & dossier.** Given seed 20260830 and a pinned raid
draw, three warband entities exist with 4d6-drop-lowest stats
computed from stream 4 in the pinned call order, ids `g1..g3`,
spawn-appended to `hostiles` — fails while no entity struct exists.

**C2 attack pipeline.** An attack roll resolves through the SHARED
margin-band + promotion path and one `gethash` on
`(dmg-minor|dmg-warband . band)`; band 0 deals 0 and logs nothing;
the warband matrix's band 3 deals exactly 3 — fails while attack
math bypasses the matrix hash.

**C3 injury ladder.** A worker at hp ≤ 60% limps (1 step per 2 ticks,
no stride); at hp ≤ 40% is shaken (seek_eff recomputed inside
[50,68]); any damage < max worsens mine rate via the existing clamp;
+1 hp at each shift boundary — fails while hp has no couplings.

**C4 death & identity.** A worker at hp 0 is removed from creators,
their toilet freed, a `worker-death` event emitted — AND survivors
keep their glyphs (the stored spawn-index, not list position): the
test kills α and asserts β still renders β — fails while identity
is positional.

**C5 guild guard-rail.** Auto-defense never selects faction `guild`
(adjacent guild + hostile, worker strikes the hostile); `focus` on a
guild entity refuses via `combat-refusal-friendly` and consumes NO
stream draw; no verb sequence can reduce a guild entity's hp — fails
while targeting is unfiltered.

**C6 raids act-scaled & valved.** At tick 120 a d20 ≥ 8 opens one
raid of clamp(pop−1,1,3); contamination ≥ 18 or pop ≤ 1 suppresses
the draw entirely; raid state closes by tick open+40 — fails while
spawn is act-blind.

**C7 infestation escalation.** With 3 severed lines the S3 DC is 11
(14 − 3), floored at 8; a success spawns exactly one rat at a dead
pipe and emits one `infestation` event — fails while DC is static.

**C8 guild loop.** A fixer restores a dead pipe in 2 ticks, deducts
exactly 1 alloy, repeats ≤ 3 times, then departs; with alloy 0 they
wait 20 ticks and leave — fails while restoration is free or
unbounded.

**C9 player verbs.** `f` on a hostile sets `focus` and workers
prefer it; `h` on floor sends non-seated workers' journeys there and
seated/using workers are exempt; both follow the armed-badge pattern;
`u`/C-g disarms — fails while no verb exists.

**C10 stream hygiene.** Batch: no combat symbol calls `cistern--rand`
or touches streams 0–3, 5+; story-eval and combat each leave the
other's position untouched — extends A10.

**C11 glyph width.** Every combat glyph (`g G r c e s`) passes the
L-076 gui probe (`font-at` advance == cell width) on a graphic
display, probe skipped in batch like `cistern-test-gui-cell-width` —
fails while any glyph renders off-cell.

**C12 events feed the hook machine.** Each §4.7 event kind appears in
the pending list exactly when its condition fires; rewards-eval
ignores them; a scenario hook with `:condition (event raid)` opens,
resolves, and gates the next act per STORY §7.2 — fails while combat
events are invisible to story-eval.

**C13 determinism.** Two runs of seed 20260830, 300 ticks, combat
active: identical state hashes including `combat-pos`, `hostiles`
positions/hp, `raid`, and worker `hp` — fails while combat draws are
unseeded.

**C14 copy sweep.** Every §4.7 string is fetched through
`cistern--copy`; a grep-level check finds no new combat literal in
view/game — fails while lines are hardcoded.

**C15 pressure valve batch.** Soak with forced contamination ≥ 18:
zero raid opens; pop = 1: zero raid opens; A12's window guard still
asserts ≥ 22 for every worker — fails while combat can corner the
bladder window.

---

## 7. Worked example — one raid, seed 20260830, stream 4

Stream 4 fixtures (pinned, computed from the real recurrence; init
pos = 20260830 ⊕ 4 = 20260826). d20s: 17, 12, 13, 7, 4, 19, 17, 5, 3,
9, 9, 14, 16, 5, 12, … d6s: 3, 2, 3, 5, 2, 3, 1, 3, 1, 5, 1, 4, 6,
1, 4, 5, 6, 5, 4, 6, …

Pinned call order: raid roll → raider dossiers (12 d6 each, spawn
order) → objective draws (d20 mod 3: 0 gnaw / 1 steal / 2 harass) →
per-tick hostile moves and strikes (list order) → worker
auto-defense (creators order).

Pop 5 at tick 120; α (F+2 G+2 N−1 A+2): DEF 12, HP max 8 + 2 = 10,
mine rate 1.

| Tick | Event | Draw | Result |
|------|-------|------|--------|
| 120 | Act II opens; raid roll (S1) | d20 17 ≥ 8 | RAID OPEN; raiders = clamp(5−1,1,3) = 3 |
| 120 | g1–g3 dossiers: 12 d6 each (below) | 36 d6 | three stat blocks, see dossier ledger |

Dossier ledger (12 d6 each, drop-lowest per stat):

    g1: [3,2,3,5][2,3,1,3][1,5,1,4][6,1,4,5] → F11 G8  N10 A15 → F+0 G−1; HP 5, DEF 10, ATK +0
    g2: [6,1,4,5][6,5,4,6][6,2,5,4][6,3,5,1] → F15 G17 N15 A14 → F+2 G+3; HP 9, DEF 12, ATK +2
    g3: [2,4,2,5][2,4,2,5][6,2,5,1][2,4,2,5] → 11/11/11/11 → +0; HP 6, DEF 10, ATK +0
| 120 | objectives: d20 12, 13, 7 → mod 3 | 3 d20 | g1 gnaw, g2 steal, g3 harass |
| 127 | g1 reaches a live pipe; gnaw timer 4 | — | no roll |
| 128 | g2 on tank, drains 5/tick ×3 | — | 15 units claimed, `combat-tank-raid` |
| 131 | g1 gnaw completes | — | pipe → hazard ▒; downstream severs (EXISTING); `combat-gnaw` |
| 133 | g3 adjacent to α: strike | d20 4: 4+0−12 = −8 → band 0 | MISS — nothing logged |
| 134 | g3 strikes again | d20 19: +7 → band 3 | dmg-warband 3 → α hp 7; mine rate 1→2 |
| 134 | α auto-defends | d20 17: 17+2−10 = +9 → band 3 | dmg-minor 2 → g3 hp 4 |
| 135 | g3 strikes | d20 5: −7 → band 0 | MISS; α attacks: d20 3: −5 → band 0, MISS |
| 136 | g3 strikes | d20 9: −3 → band 1 | graze → α hp 6 → LIMP (relief runs exempt, P5) |
| 136 | α attacks | d20 9: +1 → band 2 | 1 dmg → g3 hp 3 |
| 137 | g3 hits | d20 14: +2 → band 2 | 2 dmg → hp 4 → SHAKEN (seek_eff 68; window 24) |
| 137 | α attacks | d20 16: +8 → band 3 | 2 dmg → g3 hp 1 |
| 138 | g3 strikes | d20 5 → band 0 | MISS; α: d20 12: +4 → band 2 → g3 hp 0, α +1 XP |
| 160 | Raid span cap (P3) | — | g1/g2 despawn; `raid` = (:last-end 160); α heals +1/shift |

Had α died at any strike: C4 fires — removal, sealed record, mourning
hook open on `worker-death`, migrant cadence refills the cap slot.
Had contamination hit 18 mid-raid, the raid would still close on
schedule (P3) but no NEW raid could open (P1). Draw ledger: stream 4
only; the sim LCG, particles, story streams, and α's `rpg-pos` are
untouched throughout (C10).

---

## 8. Soar protection

- **S1 inspector standard** — worker lines gain at most the same
  stat segment they already carry; enemy inspection reuses the
  existing inspector row pattern; the base inspector is byte-identical
  with no hostiles.
- **S2 pressure voice** — combat copy extends PRESSURE-family
  severity, never invents a tone; the idle line is untouched.
- **S3 popups-at-act** — raid/infestation announcements fire
  at-the-act through the existing popup path; no modal, ever (S5).
- **S4 purge economy** — gnaw/steal create repair demand (re-lay `p`,
  purge `x` pays); they never change costs or purge rates.
- **S5 non-modal ceremony** — the death panel and condemnation are
  protected surfaces; combat never touches them; a dead worker's
  mourning is a log line + story hook, not a modal.

---

## 9. Explicitly deferred

1. **Romance** — the social workstream's. Combat's obligation is the
   full entity (§1.4): stable `g<N>` id, persistent stats/position,
   faction visible — enough for a relationship to attach. Combat
   never reads social state to resolve (sibling contract).
2. Goblin-vs-goblin combat (the guild fights back) — data later; the
   brain table takes a faction-preference list without engine change.
3. Ranged attacks, enemy special abilities per act — the matrix
   format takes them as new matrix ids; no new engine.
4. Named goblins — bank content, not engine.
