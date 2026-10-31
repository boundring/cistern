# CISTERN v5 — CONSOLIDATED SPEC (combat × social × comedy director)

Status: SPEC v1, 2026-09-07. Consolidates docs/v5/COMBAT.md, docs/v5/SOCIAL.md,
docs/v5/COMEDY-DIRECTOR.md into one implementable, wave-ordered build plan.
No code in this doc; every directive lands red-first per R10.

Carried constraints, binding on every directive below (PROTECT block):
- **Five soars**: S1 inspector standard · S2 pressure voice · S3 popups-at-act
  · S4 purge economy · S5 non-modal ceremony.
- **Width contract**: no permanent render row exceeds 95 cols (L-076/Q25
  discipline); bank templates ≤ 60 raw chars.
- **Copy-table rule** (Q11): every player-facing string in `cistern--copy`
  (hand copy, under the `(combat . …)`, `(social . …)`, `(comedy . …)`
  subsections) or bank `:copy` (generated data), resolved through the one
  `cistern--story-copy-key` chain — no literals in view/game/input.
- **L-076 pin route**: every new glyph — including all enemy/pest glyphs
  (`g G r c e s`) — routes through the gui probe (`font-at` advance ==
  cell width) as an acceptance test; batch-skipped like
  `cistern-test-gui-cell-width`.
- **Deterministic-envelope guards** (§5.6 V4-SPEC, extended): bladder-window
  ≥ 22 ticks unchanged (A12/P6); NO new engine touches the sim LCG or the
  particle stream; each engine draws only from its own child stream; and
  rewards-eval stays the SOLE drainer of `cistern-st-rewards-events` — the
  pending list now has FIVE non-draining readers (story, dialogue, combat,
  social, comedy), and the read-only contract is asserted per new eval
  (CB10, SC10, CY9).
- **Comedy-violence contrast rule** (new in v5): suppression blocks beats
  mechanically near violence (raid open, 40-tick calm after each violent
  anchor), and copy never jokes on the moment of harm — the dead are never
  punchlines (COMEDY §2.3, tested by CY12).

---

## 1. INTEGRATION OVERVIEW

### 1.1 Per-tick eval order (one call site each, pinned)

Combat is a DOMAIN PHASE, not an eval-chain member (§2 ruling 1); social-eval
and comedy-eval insert exactly one call each into the existing eval chain.
The chain is pinned exactly as SOCIAL §4.2 and COMEDY-DIRECTOR §0 agree:

```
cistern--do-tick (game layer)
  │
  ├─ sim phases, PINNED ORDER (COMBAT §5.1):
  │    creators → hostiles → hazards → migration → check
  │
  │    hostiles phase = combat's whole tick slot (the "combat-eval"):
  │      · spawn draws S1–S6 in pinned order (stream 4)
  │      · per hostile, list order: behavior draw if due, then strikes
  │      · worker auto-defense rolls (creators order, guild-filtered)
  │      · gnaw→hazard, tank steal, guild restoration (existing primitives)
  │      · event pushes: raid (OPEN/CLOSED), ambush, infestation,
  │        worker-death, goblin-death, warband-routed, guild-arrival
  │        → pending list; DRAINS NOTHING
  │      (hazards then run with gnaw-made hazard cells participating in
  │       the same tick's decay/spread; L-040 split untouched)
  │
  ├─ cistern--story-eval st        ; EXISTING (V4-16) — reads events, drains nothing
  │
  ├─ cistern--social-eval st       ; NEW, ONE call (V5-12)
  │     reads pending events NON-DRAINING + post-tick state; draws stream 5
  │     → persona spawns, thoughts (11-row trigger table), romance gates,
  │       cross-faction friction; pushes (:social 'mutter | 'romance-stage |
  │       'star-crossed-raid …) events for the next readers
  │
  ├─ cistern--comedy-eval st       ; NEW, ONE call (V5-13…V5-17)
  │     reads pending events NON-DRAINING (romance-stage events are fresh
  │     here by construction); draws stream 6
  │     → pacing tracker, suppression, beat selection + delivery intents
  │
  ├─ cistern--dialogue-eval st     ; EXISTING (V4-21) — V4-16's story→dialogue
  │     adjacency holds; comedy slots BETWEEN them without breaking the pair
  │
  ├─ cistern--rewards-eval st nil  ; EXISTING — SOLE EVENT DRAINER (L-027)
  │
  └─ view reads the STORED intents once per render (no new query paths)
```

Ordering rules (pinned): the hostiles phase runs after the workers move
(adjacency reads post-move state) and before hazards. Social-eval runs after
story-eval (reads story-opened state and events story may have extended) and
before dialogue-eval (a muttered event this tick is visible to dialogue).
Comedy-eval runs after social-eval and before dialogue-eval — it appends dry
thoughts through social's pinned helper and reads the romance transitions
social just emitted. None of the three new slots ever drains the pending
list; rewards-eval remains the sole drainer (mechanically asserted per slot:
CB10, SC10, CY9). Social-disabled runs (banks absent) and combat-disabled
runs are legal no-ops: nil hashes, zero draws, byte-identical sim.

### 1.2 Stream allocation table (now 0–6)

| id | owner | position field |
|----|-------|----------------|
| 0 | reserved | — |
| 1 | story-gen (bank generation) | — (generator ⊕ 0x6A6E is outside the space) |
| 2 | story-runtime (story-eval + dialogue-eval via shared `:roll-pos`) | `roll-pos` |
| 3 | RPG (stat/check draws) | `rpg-pos` |
| 4 | COMBAT (spawns, behavior, attack rolls) | `combat-pos` |
| 5 | SOCIAL (quirks, thought content, romance gates) | `social-pos` |
| 6 | COMEDY (odds draw, archetype + instance draws, dry thoughts) | `comedy-pos` (inside the `comedy` plist) |
| 7+ | free | — |

All child streams: pos-in/pos-out on state, mid-bits slice `(ash pos -6)`
before the mod (RPG §3.2 ruling — one rule, all engines). Pinned mid-stream
orders: combat = spawn draws (§2 order) → per-hostile behavior → strikes →
worker auto-defense (creators order); social = persona-spawn draws at the
pinned hooks, then thought-content draws, then romance gate rolls; comedy =
odds draw → archetype draw → instance draws left to right.

---

## 2. CONFLICT RULINGS — one ruling per cross-doc disagreement

The three sibling docs are peer-coordinated and mostly agree; these are the
places they collide or leave a gap. Each ruling is binding on every directive
below.

| # | Conflict | Ruling |
|---|----------|--------|
| 1 | Slot taxonomy: this consolidation brief names "combat-eval" as one of three new evals, but COMBAT §5.1 pins combat as a domain PHASE (`creators → hostiles → hazards → migration → check`) and explicitly keeps "story-eval and rewards-eval exactly where they are" — an eval-chain slot would misplace combat after the sim tick it must participate in. | "combat-eval" = the `cistern--phase-hostiles` slot in the domain phase order (creators → **hostiles** → hazards → migration → check), NOT a member of the story→social→comedy→dialogue→rewards eval chain. The phase carries combat's event pushes so story-eval (the next reader) sees them the same tick. Social-eval and comedy-eval ARE eval-chain members. The §1.1 diagram is canonical. |
| 2 | Entity-id claims: SOCIAL §1.1 reserves a distinct "pest" species id pending "the sibling design that lands the entities", but COMBAT §1 already lands the four pests as fauna hostiles in the SAME `cistern--enemy` struct with `g<N>` ids ("nothing else may collide with it"). | No separate pest id space exists. Pests are fauna hostiles with `g<N>` ids (one global sequential counter, already collision-free). SOCIAL's census gains species **`pest`** = hostiles with `:faction fauna`, sorting in the §1.1 total order immediately after goblins (workers < goblins < pests < fixtures < tanks < structures); persona/romance machinery accepts them the day V5-01 lands — no deferral. Thought-table species column may name `pest`; the goblin mood-banding defconst extends by kind. |
| 3 | Event vocabulary gap: SOCIAL §1.4 row 8 (guild-mourning) fires on "goblin death", but COMBAT §4.6's closed event-kind list has no goblin-death kind (only `worker-death`, `warband-routed`, …). Related: COMBAT §4.4 logs `guild-depart` without listing it as an event kind. | Combat's closed event-kind vocabulary gains exactly one kind: **`goblin-death`** (pushed when any hostile reaches 0 hp or is removed with cause; leech-removed-with-host counts as host `worker-death` only). The closed list is: `raid` (OPEN + CLOSED) · `ambush` · `infestation` · `worker-death` · `goblin-death` · `warband-routed` · `guild-arrival`. `guild-depart` stays LOG-ONLY — it is not an event kind; nothing reads it. Social row 8 reads `goblin-death`. Rewards-eval ignores foreign kinds, as already pinned. |
| 4 | Copy subsection names: COMBAT §4.7 defines `(combat . …)` with keys `combat-` AND two badge keys `badge-focus` / `badge-rally` ("ARMED: FOCUS" / "ARMED: RALLY") that duplicate the V4-SPEC ruling-6 pattern — the existing live key `badge-armed . "ARMED: %s"` composes the verb name. | Three new copy subsections, prefixes `combat-` / `social-` / `comedy-`, exactly as the sibling docs list them — EXCEPT `badge-focus` and `badge-rally` are DELETED from the combat plan: the existing `badge-armed` row composes `FOCUS` / `RALLY` as its `%s` argument (one key, one badge row — same logic that deleted `badge-type-fmt` in V4). Stage names stay data (`cistern--romance-stage-names`); the comedy copy family `comedy-thought-*` lives in bank `:copy`, not the table. |
| 5 | Stream-table drift: SOCIAL §4.1 says "6+ free"; COMEDY §5.1 says "6 COMEDY · 7+ free"; COMBAT §5.2 only pins "4 is the first free id, never 5+". | The §1.2 table stands: 0 reserved · 1 story-gen · 2 story-runtime · 3 RPG · 4 COMBAT · 5 SOCIAL · 6 COMEDY · **7+ free**. All three docs' per-engine hygiene clauses are consistent with it and inherit it unchanged. |
| 6 | Label collision: COMEDY §1.2 numbers its suppression rows S1–S5, the same letters as the five soars both siblings cite verbatim; and both COMBAT and COMEDY number acceptance criteria C1–C15 / C1–C12. | Soars are always written "the five soars" (S1–S5 reserved for them). Comedy suppression rows are cited as **CY-S1…CY-S5** (§1.2 rows). Acceptance-criteria namespaces: **CB1–CB15** (combat), **SC1–SC12** (social, already lettered), **CY1–CY12** (comedy). Source-doc letters map 1:1; this spec uses only the namespaced forms. |
| 7 | Read-direction claims: COMEDY reads combat's `raid` state directly ("sibling contract, already agreed"), SOCIAL reads combat entity facts, while SOCIAL §3.2 pins "the read direction is combat → social only" for raid targeting. | The dependency graph is: social READS combat facts (ids, factions, positions); comedy READS combat state (`raid`, violent-anchor events); combat READS NEITHER. Combat never reads social state to resolve combat, and social never modifies raid targeting (`star-crossed-raid` is an event the story engine opens and COMBAT resolves). No directive may add a combat→{social,comedy} read edge; CB10/SC10/CY9 assert the hygiene side. |

---

## 3. DIRECTIVE BUILD ORDER (wave-ordered, R10 discipline)

Same discipline as V4-SPEC: every directive lands a red test first, ships the
file-level minimal change, names size (S/M/L) and PROTECT interactions. Every
directive inherits the §0 PROTECT block (five soars, width contract, copy-table
rule, L-076 pin route, deterministic-envelope guards, comedy-violence contrast
rule); only directive-specific PROTECT interactions are listed. Waves are the
owner's orchestration: wave 1 the violent base (combat entities + combat-eval
+ player verbs, no social/comedy deps) → wave 2 the social layer (personas +
thoughts + romance, reads wave-1 facts only) → wave 3 the presentation (comedy
director + whimssey bank + README dossier, reads both).

### WAVE 1 — the violent base (combat entities, combat-eval, player verbs)

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V5-01 | Entity struct + dossiers + stream 4 (COMBAT §1.4, §2, §5.1–5.2) | `cistern--enemy` cl-defstruct (id/faction/kind/x/y/stats/hp/gnaw/drain/grip) in cistern-domain.el; state fields `hostiles` (spawn-appended, never re-sorted) + `combat-pos`; `g<N>` sequential id counter on state; 4d6-drop-lowest ×4 dossier draws from stream 4 (mid-bits slice) in the pinned call order; worker struct gains `hp` AND the stable spawn-index pin, `cistern--worker-glyph` reads the stored index | CB1 (seed-20260830 pinned raid draw → three warband entities `g1..g3`, 4d6 stats from stream 4 in pinned order); CB13 partial (two runs → identical hashes incl. `combat-pos`) | M | stream-4 only, never sim LCG / streams 0–3 / 5+ (extends A10); copy-table rule (no copy yet); glyph L-076 route deferred to V5-07 |
| V5-02 | Combat resolution on the shared pipeline (COMBAT §3.1–3.2, §5.3 C10) | `dmg-minor` / `dmg-warband` domain consts in bank-entry shape folded into the EXISTING `cistern--matrix-hash` via the ONE loader (V4-19 fn); attack = d20 + ATK − DEF, shared margin-band + nat-20/nat-1 promotion, one gethash; hostile strikes once/tick on hostiles move; worker auto-defense in creators order, targeting = focus-else-nearest, ALWAYS guild-filtered; band 0 logs nothing | CB2 (resolve through shared band + one gethash; band 0 = silent miss; warband band 3 = exactly 3); CB10 (no combat symbol calls `cistern--rand`, touches no stream 0–3/5+ position) | M | A9 one-hash shape (no second band vocabulary, no new matrix id per verb); S2 voice (misses silent); sealed-envelope: damage touches only `hp` |
| V5-03 | Injury ladder + worker death + identity pin (COMBAT §3.3–3.4) | worker `hp` max = 8 + GRIT mod at spawn; LIMP (hp ≤ 60%: 1 step / 2 ticks, stride off, SUSPENDED on relief journeys) / SHAKEN (hp ≤ 40%: NERVE −2 inside existing [50,68] clamp) / mining loss (+1 mine rate via existing clamp); +1 hp per shift boundary; hp ≤ 0 death procedure: removal from creators, journey drop, `:busy` clear, gripping leech removed, `worker-death` event push, sealed record, migrant cadence refills | CB3 (ladder couplings + shift heal, P5 relief exemption); CB4 (death cleanup AND α's death leaves β rendering β — spawn-index, not list position) | M | P4 envelope untouchable (no combat effect writes bladder/seek/use-ticks/purge/costs); P5 limp-vs-relief-window pin; S5 non-modal (log + story hook, never a modal; death panel untouched) |
| V5-04 | Spawn table + hostiles phase + raid lifecycle (COMBAT §1.1, §2, §4.1–4.3, §5.1) | ONE new phase `cistern--phase-hostiles` pinned `creators → hostiles → hazards → migration → check`; spawn draws S1–S5 pinned order (raid d20 ≥ DC 8/5 by act, ambush d20 ≥ 13 at flood-dist ≥ 6 isolation, infestation d20 ≥ 14 − severed min 8 every 20 ticks, leech/sponge at old floods); raid state `(:open T0)` / `(:last-end T)`, n = clamp(pop−1,1,3|2,4), 40-tick forced withdrawal, `warband-routed` close variant; movement via `cistern--dist-from`; gnaw 4-tick → existing `hazard` ▒ (no new tile state, L-040 split untouched); steal drains `:load` 5/tick out of the sim; event pushes per ruling 3's closed list | CB6 (act-scaled raid opens at 120 with d20 ≥ 8, clamp raider count, contamination ≥ 18 / pop ≤ 1 suppresses, closes by open+40); CB7 (3 severed → S3 DC 11 floored 8, one rat at a dead pipe, one `infestation` event); CB13 (300-tick determinism incl. hostile positions/hp, `raid`, worker `hp`); CB15 soak (window(w) ≥ 22 for every worker with combat active; hostiles ≤ 8; raid state ∈ three legal shapes) | L | P1 contamination valve; P2 numeric caps (raiders ≤ pop−1, hostiles ≤ 8, sponge split banked); P3 bounded raids; comedy reads `raid` read-only (ruling 7); S3 popups-at-act for raid announcements |
| V5-05 | Guild fixer loop + guard-rail (COMBAT §1.3, §3.5, §4.4) | S6 spawn (severed ≥ 2, none present, per 40 ticks, d20 ≥ 12) at map edge; walk to nearest DEAD pipe → 2-tick restoration → live, `cistern-cost-pipe` − 1 alloy → repeat; depart after 3 restorations or 40 idle ticks; loop READ-ONLY on tanks/pipes/alloy except the two pinned writes; `focus` on guild REFUSES via `combat-refusal-friendly`, consuming NO draw; no attack path may touch faction `guild` | CB8 (restore in 2 ticks, exactly −1 alloy, ≤ 3, depart; alloy 0 → wait 20, leave); CB5 (adjacent guild + hostile → worker strikes the hostile; refusal consumes no stream draw; no verb sequence reduces guild hp) | M | S4 purge economy (−1 fee fixed, no cost/purge-rate change); guild glyphs/faces via V5-07; arrival mid-raid legal — guild is never a combatant |
| V5-06 | Player verbs — FOCUS / RALLY (COMBAT §4.5) | `f` arms FOCUS (click enemy → `focus` = its id, defenders prefer it, cleared on its death, guild refusal per V5-05); `h` arms RALLY (click floor → non-seated workers' `journey` set there, resume seek-work; seated/using exempt); both ride the EXISTING armed-verb pattern; badges via existing `badge-armed` (ruling 4 — no new badge keys); `u`/C-g disarm unchanged | CB9 (`f` sets focus + preference; `h` routes journeys, seated exempt; armed-badge pattern; `u`/C-g disarm) | M | S5 non-modal (badge + click, nothing blocks); no new rolls — the player shapes WHERE violence happens, dice roll through the shared pipeline; emacs alias pairings are a driver-pass note, not this directive |
| V5-07 | Combat surfaces — glyphs, faces, copy sweep (COMBAT §1 table, §4.7, §5.4) | view: glyphs `g G r c e s` (distinct from tile table, particle palette, α–θ), faces `cistern-goblin` / `cistern-pest` … via S2 roles, enemies render through the worker overlay/z-order path, floor-only; domain copy table gains `(combat . …)` exactly per COMBAT §4.7 MINUS `badge-focus`/`badge-rally` (ruling 4); inspector enemy rows reuse the existing row pattern | CB11 (every glyph passes the L-076 gui probe, batch-skipped); CB14 (every string through `cistern--copy`; grep finds no new combat literal in view/game) | S | **L-076 pin route**: all six glyphs ASCII, probe-must-pass; 95-col (templates ≤ 60 raw chars); S1 inspector byte-identical with no hostiles; S2 voice (severity families extended, idle line untouched) |

Wave-1 ordering: V5-01 → V5-02 → V5-03 (struct → resolution → injury/death);
V5-04 after V5-02 (phase needs attack math); V5-05 after V5-02 and V5-04
(spawn table + filter); V5-06 after V5-02 (focus routing needs targeting);
V5-07 after V5-01 (glyphs need entities) and parallel-safe otherwise.

### WAVE 2 — the social layer (personas, thoughts, romance)

Cross-wave dep: ALL of wave 2 reads wave-1 facts only (hostiles plists,
faction, `g<N>` ids, `worker-death`/`goblin-death` events, positions);
V5-08 additionally requires V5-01's struct landing. No wave-2 directive
writes any combat state (ruling 7).

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V5-08 | Persona layer + census (SOCIAL §1.1–1.2, §4.3, §4.4 quirk half) | state hash `personas` + `social-pos`; census id protocol per ruling 2's total order (workers α–θ < goblins `g<N>` < pests `g<N>` < fixtures < tanks < structures); persona plist `(:species :quirks :ledger :urge :urge-tick)`; spawn hooks pinned — workers at `cistern--new-game` after story-generate, goblins/pests at hostile spawn (combat's hook calls the domain persona-spawn), fixtures/tanks at build, structures at first bank-granted sighting; quirk count draw (d6 1–2/3–4/5–6 → 1/2/3) then selector draws over the species-filtered bank; `quirk` bank kind gains optional `:species`, loader-validated fail-first | SC1 (seed-20260830 fixture: α = 2 quirks via draws 2,3; `social-pos` = 1083329933 after the α + starter-toilet pass); SC2 (1000 spawns × 50 seeds: counts ∈ [1,3], selectors resolve, ledger nil at spawn) | M | stream-5 only; bank loader discipline (load-time errors, same as every kind); copy-table rule (bank content, zero literals) |
| V5-09 | Mood — the derived enum (SOCIAL §1.3) | one pure banding function per species over state that already exists (worker bladder bands 100/110+sick; fixture `cistern--toilet-state`; tank 50%/85% of `cistern-tank-cap`; goblin/pest mapped from combat facts via one defconst; structure always NOMINAL); NO mood field on any struct | SC3 (bladder 99 NOMINAL / 100 STRAINED / 110 CRITICAL; tank 84% STRAINED / 85% CRITICAL; manifold NOMINAL through a soak; the test asserts no mood field exists) | S | reads-only — mood never touches a sim number; S1 (the inspector word arrives with V5-12's render) |
| V5-10 | Thought pipeline — trigger table + three channels (SOCIAL §1.4–1.6, §4.4 bank half) | domain const trigger table (all 11 rows, event × species × mood → class); new bank kind `thought` (`:id :class :species :when :copy-key`) with closed class table + loader validation; `cistern--social-thoughts` runs per tick reading pending events NON-DRAINING; channels pinned — PRIVATE (ledger cap 3 FIFO, inspector-only), MUTTERED (≤ 2 log lines/tick via `social-mutter-fmt`/`social-file-fmt`, goblins/workers quote, fixtures/tanks/structures FILE, each mutter pushes `(:social 'mutter …)`), SILENT URGE (flag ttl 1 tick; fixture → render flash; worker → one `cistern--shuffle` idle step only with NO journey; goblin/pest → one constant-velocity `cistern--field-spawn`, no draw; structure → none); budgets: ≤ 1 thought/entity/tick, ≤ 4 sector/tick, row-order over-cap, downgrade-not-draw on mutter overflow | SC4 (breach at (5,5): fixture-flood at (7,6), nerve-flood at (6,5), nothing at (9,9); FIFO cap; no trigger row → no thought); SC5 (mutter = exactly one log line + one event push; private = inspector-only, no push; urge = byte-identical log, view `:urge` flips); SC6 (6 eligible rows → ≤ 4 thoughts row-order; 3rd mutter downgrades to private with ZERO stream draws) | L | S3 popups (channels are log/ledger/render-toggle, exhaustive); non-draining read asserted; worker urge can never reach pathing/seating/bladder targets by construction; Q13 — mutter/file lines severity `info`, reuse existing faces, no new face family |
| V5-11 | Romance — the relationship graph (SOCIAL §2) | state hash `relationships`; pair key = `(id-a . id-b)` sorted by the V5-08 total order (deterministic, no canonicalization draws); plist `(:stage :score :since :cross-faction)`; score accrual: +1/tick proximity (Chebyshev ≤ 2, both on map), +2 shared events (breach resolved, same purge, same relief, co-demolish — all reads of fired events); stages FILED (first point, no roll) → CROSS-REFERENCED (10, DC 8) → CO-SIGNED (40, DC 12) → ANNOTATED IN THE MARGINS (80, DC 16) via `cistern--romance-thresholds`/`-dcs`; gate roll d20 + audit-mod (worker ARCHIVE mod; +1 co-signed) on stream 5, band ≥ 2 advances, ≤ 1 re-arms at score + 5; transitions = deadpan log (`social-stage-fmt`) + `(:social 'romance-stage …)` push + `romance-stage` thoughts for both partners; caps: ≤ 2 attachments ≥ stage 2 (refusal consumes NO draw), monotonic, pairwise only; termination: endpoint ceases → key deleted, stage ≥ 2 closes with `social-stage-close` + one `loss` thought | SC7 (§6 fixture courtship: FILED at score 1, CROSS-REFERENCED at 10, CO-SIGNED at 50 after two re-armed failures, ANNOTATED at 80 with the co-signed +1); SC8 (sim-field hash identical around every transition); SC9 (third attachment refused with zero draws; demolish at stage 2 deletes the key, one close log, one `loss` thought, no dangling keys) | L | **SC8 is the load-bearing guard**: no social rule touches bladder/costs/purge/pathing/contamination/combat stats; no triangle state; gate checks fire on score-crossings only (no per-tick scan of non-proximate pairs); S5 — the player's only romance surface is READING |
| V5-12 | social-eval wiring + cross-faction friction + determinism (SOCIAL §3, §4.2, §4.6–4.7, §4.5 render) | ONE game-layer call pinned story-eval → **social-eval** → comedy-eval → dialogue-eval; emits ONLY `(:layer 'log …)` intents, `(:social …)` pushes, persona/relationship mutations, urge particles — never banner, never popup; cross-faction: warband goblins within Chebyshev 6 of an attached goblin fire `faction-mock` FILED OBJECTIONS (`social-objection`) on stage ≥ 1 transitions, capped by the §1.6 budgets; `star-crossed-raid` push when a raid targets a beloved's cell (story opens it, combat resolves it — ruling 7); guild carries no friction rows; story effects whitelist gains exactly ONE kind, `proximity-nudge` (writes a SOCIAL number, never a sim number); persona inspector clause: mood word, first quirk word, latest private thought, degradation thought → quirk → mood → byte-identical base; copy `(social . …)` per SOCIAL §4.6 | SC10 (no social symbol calls `cistern--rand`, reads `particle-rng`/`rpg-pos`/`combat-pos`/`roll-pos`, advances any position but `social-pos`; urge particle = constant velocity); SC11 (two 300-tick runs → identical `social-pos`/personas/relationships; social-disabled run byte-identical to pre-v5 sim); SC12 (maximal inspector line degrades per pinned order, never > 95; muttered/filed ≤ 95; grep: no new social literals in view/game) | M | **read-only contract asserted here** (SC10) — social reads events without draining, rewards-eval sole drainer; S1/S2/S3/S5 pinned per SOCIAL §7; 95-col width contract with the degradation order as the test |

Wave-2 ordering: V5-08 → V5-09 → V5-10 (census → mood → thoughts);
V5-11 after V5-08 (pair keys need the total order) and V5-09 (gate copy
names moods); V5-12 last (wires the whole layer into the eval chain).

### WAVE 3 — the presentation (comedy director, whimssey bank, README dossier)

Cross-wave deps: comedy reads wave-1 combat state (`raid`, the violent-anchor
events `worker-death` / `burst` / `infestation` / raid CLOSED) and wave-2
social surfaces (the pinned thought-push helper, the mutter push path,
`romance-stage` events, derived mood, persona quirk matching) — V5-13 needs
V5-04's `raid` state; V5-15–V5-17 need V5-10/V5-11/V5-12 landed. The README
dossier (V5-19) describes waves 1–2 content and builds last of all.

| # | Directive | File-level minimal change | Batch-testable acceptance | Size | PROTECT notes |
|---|-----------|---------------------------|---------------------------|------|---------------|
| V5-13 | Comedy tracker — dual clock, suppression, latching (COMEDY §1) | state plist `comedy` (`:pos :last-beat-tick :due-p :recent :active`) — nothing else on `cistern-st`; budgets `cistern--comedy-budget-manual` = 150 / `-auto` = 750 (mode = existing auto-run flag); suppression rows CY-S1…CY-S5 in pinned order (raid open; ≤ 40 ticks since a violent anchor — `worker-death`, `burst`, `infestation`, raid CLOSED, `cistern--comedy-calm` = 40; contamination ≥ 15; act-rollover ± 10 or hook force-miss; beat already active); density dampener (≥ 2 anchors / 60 ticks → `tense`, `:loud` weights ×0.5); latching: budget expiry under suppression sets `:due-p`, delivers on the first fully-calm tick, consumes no draw while latched; spontaneous odds draw 1/90 manual-only, ≤ 1 draw and ≤ 1 beat per tick | CY1 (900-tick auto soak: every calm 750-tick window ≥ 1 comedy line, max calm gap ≤ 750; forced-manual ≤ 150; raid-spanning run delivers within 5 ticks of first calm, never inside the cooldown); CY2 (auto forces at 750 never 150, manual vice versa; `:due-p` nil without suppression overlap); CY3 (raid open → zero intents; anchor at T → zero through T+40; contamination 15 and rollover ±10 suppress; dampener halves `:loud` on the schedule fixture) | M | Clock B backstop is DRIVER-side only — wall time never enters `cistern-st`, nudges cycle a driver defconst through the hint slot, never fire bank beats or consume stream 6; schedule stays a pure function of (seed, banks, state) |
| V5-14 | Whimsey bank kind + footprint whitelist (COMEDY §2.1, §5.2) | sixth bank slot `:kind whimsey` (`:id :when :weight :loud :cooldown :draws :thread :footprint :copy-key`), loader-validated; the §5.2 footprint whitelist (complaint-count, accent-ttl, aesthetic-p, rival-ttl, place-names, alloy-delta ±1, xp-delta +1, rat-despawn, drill-counter, thought-push, mutter-push) — the loader and a batch guard reject any entry whose `:footprint` names anything else; copy via `(comedy . …)` or bank `:copy` through the one chain | CY6 loader half (a bank entry naming an off-whitelist footprint fails with a named load-time error; the example bank loads clean) | M | copy-table rule operational for the new kind; fail-first pattern; no bladder number, no purge rate, no contamination arithmetic, no pathing, no spawn position — ever |
| V5-15 | Selection algorithm + the twelve archetypes (COMEDY §2.2, §5.4) | pinned 5-step selection: eligibility (`:when` predicate, id ∉ `:recent` cap 3, per-archetype `:cooldown`) → weight fold (×0.5 `:loud` under `tense`) → one mid-bits stream-6 archetype draw (cumulative walk) → instance draws left to right per `:draws` → commit + deliver (`:recent` update, `:last-beat-tick`, `:due-p` nil); all twelve entries in the example bank — pipe-complaint, clog-blame (3-tick thread), manifold-accent, workers-comp, aesthetic-refusal (flagship REAL beat, armed only at ≥ 2 usable fixtures), formal-duel, memo-rename, inventory-audit (±1 alloy), queue-etiquette, toilet-rivalry (rival-ttl 60, one-shot +1 waste via the STORY §6.4 family), successor-letter, safety-drill; fallback family (`:when t`, `:loud nil`) guarantees a non-empty pool | CY4 (same seed + banks → byte-identical beat schedule; no archetype twice in any 3 consecutive beats; fallback covers an all-else-ineligible state; cooldowns honored); CY5 (aesthetic refusal fails the seating attempt that tick, worker reroutes next tick, never seatless across a 50-seed sweep; 1-usable state never arms); CY6 footprints (workers-comp +1 alloy, audit lands exactly one ±1, letter +1 on demolish, drill counter tallies at rollover, 3rd complaint flags) | L | **envelope guards**: the aesthetic refusal is bounded by the ≥ 2-usable guard (RPG §5.4 inequality untouched); alloy deltas ±1 against a purge economy in dozens; XP via the existing RPG §4 ledger family; rat despawn via the existing path; S5 non-modal throughout |
| V5-16 | Delivery — intent grammar, arbitration, face, width (COMEDY §5.3, §5.5) | delivery via the EXISTING intent shapes: `(:layer 'log :text … :face 'info|'comedy)`, `(:layer 'banner …)`, popup particles via `cistern--field-spawn` floor-only; pinned arbitration — comedy takes the banner slot ONLY if story-eval and combat emitted none this tick (a deterministic read of their returned intents, comedy-eval runs after both); log share ≤ 3 comedy lines/tick; new face role `comedy` derived from the S2 palette, never an alert role; inspector annotations (`DIALECT ACTIVE`, `:place-names` alias) degrade FIRST: comedy → thought → quirk → mood → byte-identical base | CY10 (every comedy string resolves through the table or bank `:copy` — A15 grep rule; rendered log/banner ≤ 95 cols; maximal inspector line degrades in the pinned order) | M | five soars restated: S1 (annotations degrade first, base byte-identical), S2 (comedy face from standard palette, never alert faces), S3 (particles floor-only, never on act-rollover), S5 (everything log/banner/particle/hint, nothing waits); protected surfaces — death panel, ceremony, condemnation, goal-card banner — comedy never touches |
| V5-17 | Thought/romance comedy hooks (COMEDY §3) | dry channel: one comedic private thought per 60 ticks (`cistern--comedy-dry-gap`) via the SOCIAL-pinned thought-push helper ONLY (comedy never writes `personas` directly), one stream-6 draw over the `comedy-thought-*` bank family, quirk-tagged variants preferred, NEVER for a CRITICAL-mood worker, private-only delivery; romance priority slots: every `romance-stage` event comedy reads arms a beat within 10 ticks (draws: which tick, which variant), superseding the budget WITHOUT moving `:last-beat-tick`; stage 2 → CO-SIGNED banner (arbitration permitting) + one rival mutter through the social push; stage 3 → stage-3 log family + one shared dry thought bypassing the 60-tick gap ONCE; stages 0/1 → low-weight log lines only; cross-faction objection ticks get NOTHING on top; termination is never comedic | CY7 (pinned stage-2 transition → banner within 10 ticks on a banner-free tick, exactly one rival mutter, `:last-beat-tick` unchanged; transitions during a raid → zero comedy intents); CY8 (≤ 1 per 60 ticks, helper-only push, never CRITICAL mood, private-only — SC5's channel assertions hold) | M | suppression still outranks slots (a raid outranks a wedding); S2/S5; the dry channel competes for the SAME social budgets by row order — comedy draws no extra budget |
| V5-18 | Comedy determinism + contrast close-out (COMEDY §5.4, §2.3) | beat-schedule fixture: headless `cistern--comedy-eval` per tick over the soak asserts the EXACT `(tick archetype-id)` schedule for seed 20260830 + example bank (4 whimsey + 2 thought entries pin every selection branch); stream-hygiene batch; contrast content scan over the bank | CY9 (no comedy symbol calls `cistern--rand`, reads `particle-rng`/`rpg-pos`/`combat-pos`/`social-pos`/`roll-pos`, advances any position but `comedy-pos`; two 300-tick runs → identical hashes incl. `comedy-pos` and every whitelisted footprint); CY12 (no comedy intent within 40 ticks of any anchor — mechanical; no comedy copy key's rendered text contains a dead worker's glyph — string scan) | S | **read-only contract asserted here** (CY9); **comedy-violence contrast rule asserted on both layers** — timing via CY-S1/S2, content via the CY12 scan |
| V5-19 | README — the Sector 7 onboarding dossier (COMEDY §4) | README.md rewritten as the in-universe dossier, 130–190 lines, 12 sections in COMEDY §4.2 order (title block + classification line, THE STRUCTURE, TERMS OF EMPLOYMENT ending `THE STRUCTURE DOES NOT CARE.`, YOUR PREDECESSORS, PERSONNEL DOSSIERS, REQUISITIONS — THE FIXTURE CATALOG, TERRAIN AND WILDLIFE incl. guild AND warband goblins + fixture personas, THE WARBAND SITUATION, SECTOR RECORDS + the one whimsy disclosure, EMPLOYMENT PROCEDURES, READING THE SCREEN, closing + links); byte-accuracy blocks migrate verbatim per §4.3 (run fence, the `M-x cistern` line, the two doc links, fixture-catalog numerics, stat-effect bullets); migration ledger §4.4 followed; tone calibrations §4.5 (one bracketed footnote max per section, none near hazard statements, numbers never funny); version string bumped to the v5 string in BOTH README.md and PLAYING.md in the same commit | CY11 (extracted-block string-equality on all byte-accurate blocks; length 130–190; §4.4 spot-fact list present: contamination 20, pop cap 8, purge pay 1 alloy per 3 waste, thresholds 12/30 XP, budget numbers) | L | `# CISTERN` stays byte-1; PLAYING.md remains canonical and is never contradicted; S2 pressure voice (the dread paragraphs get zero footnotes); `THE STRUCTURE DOES NOT CARE.` and the one-sentence summary are byte-identical |

Wave-3 ordering: V5-13 → V5-14 → V5-15 (tracker → bank kind → archetypes);
V5-16 after V5-15 (delivery needs beats to deliver); V5-17 after V5-15 and
V5-12 (slots need social's helper + events); V5-18 last in the engine chain;
V5-19 any time after V5-07 and V5-12 (it describes fauna/warband/personas).

### 3.1 Wave summary

| Wave | Theme | Directives | Count |
|------|-------|------------|-------|
| 1 | the violent base — combat entities + combat-eval + player verbs | V5-01..V5-07 | 7 |
| 2 | the social layer — personas + thoughts + romance | V5-08..V5-12 | 5 |
| 3 | the presentation — comedy director + whimssey bank + README dossier | V5-13..V5-19 | 7 |
| **Total** | | **V5-01..V5-19** | **19** |

---

## 4. ACCEPTANCE CRITERIA + CARRIED GUARDS (consolidated)

Per-directive acceptance lives in the §3 tables, cited by the namespaced
letters of ruling 6 (CB1–CB15 from COMBAT §6, SC1–SC12 from SOCIAL §5,
CY1–CY12 from COMEDY §6 — source letters map 1:1). This section carries the
guards that outlive any one directive; they are asserted by the directives
named, re-probed once per wave close, and hold with each layer off OR on.

1. **Bladder-window envelope** — window(w) = (120 − seek_eff(w))/2 −
   use_ticks_eff_max ≥ 22 for every worker, every soak run, combat active or
   not (RPG §5.4 A12; combat's P5/P6 restate it — CB15 asserts it with
   hostiles live). No combat effect writes bladder, bladder rate, seek
   thresholds beyond the existing clamp, use ticks, purge rate, or costs.
2. **Stream isolation** — no new engine symbol calls `cistern--rand` or
   touches the sim LCG or the particle stream; each engine advances only its
   own position field (`combat-pos`, `social-pos`, `comedy-pos`); mid-bits
   slice `(ash pos -6)` on every draw, one rule, all engines. Asserted per
   engine: CB10, SC10, CY9 (extends V4's A10/D6).
3. **Rewards-eval sole drainer — five non-draining readers.** The pending
   list is read WITHOUT draining by story-eval, dialogue-eval (existing) and
   combat (the hostiles phase's event consumers), social-eval, comedy-eval
   (new); rewards-eval remains the only drainer of
   `cistern-st-rewards-events` (L-027 wiring untouched). The read-only
   contract is asserted PER NEW EVAL — combat's event reads in CB10/CB12,
   social's in SC10, comedy's in CY9 — and a batch guard fails on any drain
   from a non-rewards slot.
4. **L-076 pin route, complete glyph list** — every v5 glyph passes the gui
   probe (`font-at` advance == cell width) on a graphic display,
   batch-skipped like `cistern-test-gui-cell-width`: the six enemy/pest
   glyphs `g G r c e s` (CB11). No other v5 surface adds a glyph — personas,
   moods, thoughts, romance, and comedy are copy and faces only.
5. **Determinism** — two runs of seed 20260830, 300 ticks, all layers
   active: byte-identical state hashes including `combat-pos`, hostiles
   positions/hp, `raid`, worker `hp`, `social-pos`, personas,
   relationships, and the `comedy` plist incl. `comedy-pos` (CB13, SC11,
   CY9). Layer-disabled runs (combat off, social banks absent) are legal
   no-ops byte-identical to the pre-v5 sim.
6. **Comedy-violence contrast** — mechanical layer: zero comedy intents on
   a raid-open tick and within the 40-tick calm after any violent anchor
   (CY-S1/CY-S2, asserted by CY3/CY12). Copy layer: no comedy copy key's
   rendered text names a dead worker's glyph, quotes a death panel, or
   formats a burst as wit (CY12 string scan). The README inherits it in
   prose: no footnote within three lines of a hazard statement, and the
   contamination clock and death panel are never joked about.
7. **Width + copy sweep** — 95-col capture over every new rendered surface
   (combat log/banner, persona inspector clause with the pinned degradation
   order, muttered/filed lines, comedy log/banner); every new player-facing
   string resolves through `(combat . …)`, `(social . …)`, `(comedy . …)`,
   or bank `:copy` — grep-level no-literal checks per wave (CB14, SC12,
   CY10).

### 4.1 First five to build

1. **V5-01** entity struct + dossiers + stream 4 — the full-entity
   foundation: everything in waves 2 and 3 keys off stable `g<N>` ids,
   `hostiles`, and `combat-pos`.
2. **V5-02** combat resolution on the shared pipeline — matrices into the
   ONE hash, band + promotion, guild-filtered targeting; unblocks
   V5-03–V5-06.
3. **V5-03** injury ladder + worker death + identity pin — the
   spawn-index identity fix lands here (a bug fix pinned by combat's
   arrival) and `worker-death` arms the mourning-hook path.
4. **V5-04** spawn table + hostiles phase + raid lifecycle — the phase
   itself, the pressure valve, and every violent event kind the story and
   comedy readers consume.
5. **V5-08** persona layer + census — first wave-2 directive; unblocks
   V5-09–V5-12 and, through social's helper, all of comedy's dry channel.

(V5-01 → V5-02 → V5-03 → V5-04 are strictly sequential per the wave-1
ordering note; V5-08 is parallel-safe against wave-1's surface half
V5-05–V5-07 once V5-01 lands.)
