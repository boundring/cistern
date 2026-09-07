# ANTAGONIST ROUND 2 — hostile re-walk of the refactored surface

Reviewer: ux-antagonist-r2. Method: fresh batch captures (`playtest/antagonist2.el`, dumps
`playtest/R2-01..18-*.txt`), live face/width probes (R2-NOTE lines in the run log), targeted
probes for the tutorial gate, log-tail collapse, and step-1 lottery; full re-read of
`src/{cistern-view,cistern-game,cistern-domain,cistern-input,cistern}.el` against
`docs/ux/TOP-30.md`. Suite re-run: **ALL 64 TESTS PASSED**. No code changed.

---

## 1. Verdicts on the 30 directives

**25 FIXED · 5 PARTIAL · 0 MISSED · 0 REGRESSED.** Residues are listed where they exist.

| Q | Verdict | Fresh evidence |
|---|---|---|
| Q01 strip | FIXED | R2-01: `TICK 3 · ALLOY 20 · POP 4/8 · CONTAM 0/20 · SCORE 0 · GOALS 1/2 · REP 0`, len 85 ≤ 95, no SEED; seed in `?` briefing (cistern.el:208). Caveat: the badge slot has no width budget — see N1. |
| Q02 score/rep | FIXED | R2-15/16: SCORE 0→50→70, REP 0→3→5 after driven reliefs. |
| Q03 starter card | FIXED | R2-NOTE 01: card `serve 3 / ceiling 5 / tier 2, map-id 42` at tick 0; MAP COMPLETED reached with zero injection (R2-15). Flaw: the ceiling goal is **pre-satisfied** (contam 0 ≤ 5) — GOALS reads 1/2 from tick one (N3). |
| Q04 goal progress | FIXED | GOALS 1/2 → 2/2 in the same tick the objective lands (R2-01 vs R2-15). |
| Q05 milestone | FIXED | R2-16: `MILESTONE — BIG CISTERN ONLINE` on the banner row AND in the tail, same frame; unlocks committed. |
| Q06 popup channel | FIXED | R2-NOTE 11b: the only off-floor particles are `(popup "+10")` at the toilet cell at the tick of relief; z-order tests green. |
| Q07 purge economy | FIXED | R2-NOTE 13c: 30 units → +10 alloy exactly; inspector rate line verbatim (R2-18:21). |
| Q08 pressure gradient | FIXED | R2-08: `PRESSURE RISING — TANK 92%` at 55/60; CRITICAL only at cap (R2-09). Raw-total branch gone. |
| Q09 domain split | FIXED | R2-NOTE 05: severed-p=t, backed-up-p=nil on the same state. |
| Q10 re-branch | FIXED | R2-06:22 `LINES SEVERED — REWIRE (p) — TANK AT (5,2)` — names the tank cell; no purge advice. |
| Q11 copy table | FIXED | Idle line byte-identical (`THE STRUCTURE DOES NOT CARE`, R2-01:22); table exists and tests police it. Residue: several new strings bypassed the table — `"SECTOR CONDEMNED — PRESS n FOR NEW GAME"` (cistern.el:99, hardcoded), all TUTORIAL strings (cistern-game.el:141,148; cistern-view.el:385). |
| Q12 dead glyph + legend | PARTIAL | ╌ renders on an unconnected pipe (R2-17, cell (10,6)); legend generated from the tile table, no dup. **But the legend now lists only `╌ dead pipe` — the live pipe's actual glyphs (`─ ┌ ┐ └ ┘ ┼`) are explained nowhere; the legend no longer matches the map's real glyph set, and the `?` briefing says `─ pipe` (a shape variant, not the table glyph).** The dead-pipe inspector line is unchanged (`PIPE — the only wire`) — no dead-state coaching at the cursor. |
| Q13 severity persists | FIXED | R2-NOTE 08/08b: BREACH line face `cistern-toilet-down` (red bold) at t1 AND t3. |
| Q14 worker identity | FIXED | R2-NOTE 08: log `BREACH — CREATOR β OVERFLOWED AT (12,6)`, map cell (12,6) renders β. Residue: "CREATOR β" keeps the anonymous noun; "β OVERFLOWED" would be tighter. |
| Q15 ranking + collapse | FIXED | Probe: 25 identical relief lines + 1 breach → tail `[boot] [CREATOR RELIEVED AT (3,3) ×25] [BREACH…]`; majors kept, silent suppression. |
| Q16 full log | FIXED | 12c: 27 events → `L` buffer shows 27 lines oldest-first (`SECTOR-7 ONLINE…` first), read-only, main tail still 3 lines (R2-14). |
| Q17 hint surface | FIXED | R2-03:22 hint row under the inspector; R2-04: gone next command; no permanent layout shift. Caveat N7: ANY command consumes it. |
| Q18 refusal copy | FIXED | R2-03: `NO FLOOR THERE — AIM FOR OPEN FLOOR`; R2-05:22 `NEED 15 ALLOY — PURGE (x) PAYS`; refusal still in the log (26-27). |
| Q19 armed verb | FIXED | R2-NOTE 02: header `… REP 0  ARMED: PIPE — CLICK PLACES, ESC CANCELS` (len 126); ESC + u wired; refused at-cursor build does NOT arm (R2-NOTE 03: armed=nil). **Practical caveats: at the pinned 95 cols the badge is clipped to `ARMED: PIPE` — the CLICK/ESC teaching is invisible; and `<escape>` only fires on GUI frames (`-nw` players get meta-prefix, not cancel) while the fallback `u` is taught nowhere on-screen.** |
| Q20 floor bearing | FIXED | R2-01:21 `FLOOR — toilet Ω 3 north, tank ▣ 2 east, 4 north`; tank/toilet inspector lines byte-identical. Copy nit: multi-axis bearings read like two separate distances ("2 east, 4 north" is one tank). |
| Q21 urgency color | FIXED | CONTAM segments propertized (R2-NOTE row probe); RISING yellow, CRITICAL/SEVERED red bold (R2-NOTE 06/07). |
| Q22 run summary | FIXED | R2-NOTE 09: `(:ticks 1 :relieves 0 :score 0 :cause "SECTOR CONDEMNED — CONTAMINATION LIMIT")` banked at trigger. |
| Q23 death panel | FIXED | R2-12:20 full panel `…TICKS 1 · RELIEVES 0 · SCORE 0 / PRESS n TO RESTART`; 3 post-over ticks → exactly ONE restart log line (R2-NOTE 09b, R2-13:26). Residue: the header `!! SECTOR CONDEMNED…` append survives (129 chars, still truncated at 95 — now redundant since the panel carries it) and the restart log line's wording differs from the panel (N4). |
| Q24 goal narration | FIXED | R2-15: tail shows `GOAL MET — 3 SERVED` / `GOAL MET — CONTAM UNDER 5` before the `MAP COMPLETED` banner row (20). |
| Q25 particle placement | PARTIAL | M9 ceremony: 64 sparkles, all on floor, glyphs `* ! §` only (R2-NOTE 11, R2-15 map: structures visible under ceremony). **M1 demolish dust is out of contract: it still spawns `·` and `.` glyphs (cistern-game.el:274) — colliding with the floor dot and the pipe glyph set — and it doesn't spawn at demolish time at all: rewards-eval runs only on ticks, so the dust appears one tick later, or never if the player doesn't tick (R2-NOTE 16: 0 particles immediately after demolish).** |
| Q26 non-modal guard | FIXED | Input live during the panel (ticks log the restart line, n starts a new game, summary banked — test-ux-q26 green). |
| Q27 tutorial table | PARTIAL | Step-1 prompt renders from tick 0 (R2-01:23); steps 2/3 have real predicates. **Step 1 is a lottery: the predicate is checked AFTER the wander phase (cistern--do-tick → phase-creators → tutorial-advance), so the worker the player chased has already moved. Probe: cursor parked on worker 0's spawn cell for 200 ticks — idx never left 0. The only reliable path is parking the cursor on the toilet tile and waiting for a seeker to sit (advanced somewhere inside 200 ticks, untaught). The one-per-tick gate also means a player who purges first is pinned at step 1/3 forever, and the prompt line persists over the death panel (R2-13:23).** The shipped test needed a 60-tick luck bound on seed 42 — the batch suite proves the mechanism, not the player experience. |
| Q28 briefing | FIXED | `At 60%` / `At 100%` real percents, seed line, arm-then-click line (cistern.el:208-239). |
| Q29 auto-run | FIXED | Badge `AUTO-RUN` renders (R2-NOTE 15, header len 87 — fits 95 with zero margin); slow mode 1.0s vs 0.2s (R2-NOTE 15b). |
| Q30 regret window | FIXED | R2-NOTE 13: place+demolish same tick → alloy 20→20 (round-1 cost: −4); after a tick the old rules return (fee 3, half-refund). Q07 ledger untouched. |

### Round-1 anti-qualities A1–A11: all addressed (A1 Potemkin loop, A2 silent milestones, A3 invisible score, A4 lying pressure line, A5 dead gradient, A6 invisible dead pipe, A7 whispered refusals, A8 hidden armed mode, A9 anonymous log, A10 quiet death, A11 `%%` — each verified fixed above).

---

## 2. NEW anti-qualities introduced or exposed by the refactor

**N1. The width budget was audited for row 1 only — rows 2–3 are 168 and 102 chars wide.**
Q01 pinned 95 cols and fixed the header; nobody measured the other permanent rows. At 95
cols with `truncate-lines t`:
- help line (168): visible through `[x]purge ` — **`[SPC]tick`, `[r]auto-run`, `[n]ew`, `[?]help`,
  `[q]uit` and the entire Q19 arm-teaching phrase are invisible on the pinned width**
  (probe: truncated95 ends `…[x]purge  [`). The game's own how-to-tick key is off-window.
- legend (102): `α worker` clipped — workers are unexplained at 95.
- armed badge (126): clipped to `ARMED: PIPE` — CLICK/ESC teaching invisible.
- death header (129): `!! …CONTAMINATION LIMIT` truncated (round-1 A10 residue, now
  redundant with the panel but still shipped).
- AUTO-RUN badge lands at exactly col 95 — zero margin; ARMED+AUTO-RUN together = 136.
Batch tests assert against the full render string, so every one of these passes while the
player sees a clipped screen. The strip got a layout contract; the rest of the frame didn't.

**N2. Tutorial step 1 is unwinnable as instructed** (see Q27 verdict): post-wander predicate
check + wandering workers = lottery; the working trick (park on the toilet) is untaught; the
one-per-tick gate freezes purge-first players at 1/3; the prompt outlives the game onto the
death panel.

**N3. GOALS progress regresses.** The contamination-ceiling goal evaluates `contam ≤ 5`
every tick, so a fresh game starts at GOALS 1/2 (contam 0), and rising contamination walks
it back to 0/2 (R2-01 vs R2-12). A progress readout that un-progresses teaches the player
to ignore it.

**N4. Restart copy drift + copy-table escapes.** The death screen says PRESS n three ways:
panel `PRESS n TO RESTART`, pressure line `SECTOR CONDEMNED — PRESS n TO RESTART`, log line
`PRESS n FOR NEW GAME` (cistern.el:99, hardcoded outside the Q11 table; tutorial strings
likewise, see Q11).

**N5. M1 demolish dust violates the new particle contract it inspired** — delayed one tick
(spawns only inside rewards-eval) and still uses `·`/`.` glyphs (see Q25).

**N6. Hint flicker by interaction order.** The Q17 hint drains on ANY refresh, so the
refusal answer dies to the very next command — including the cursor move a player makes to
aim their retry (R2-04: gone after one cursor-east). One-tick transiency is the spec, but
the practical result is the coaching vanishes before the corrected attempt. The hint slot
also shifts the pressure line down one row for that tick.

**N7. Dead-pipe inspector line is stale** — cursor on a ╌ cell says `PIPE — the only wire;
keep it short`, with no dead-state or fix verb; the pressure line and toilet inspector got
the Q10 treatment, this line didn't.

**N8. Combined header appends are unbounded.** `REP 0` + `!! SECTOR CONDEMNED…` + ARMED
badge + AUTO-RUN badge can coexist (condemned while armed with auto-run on): four appends,
no ordering or clipping contract.

---

## 3. Ten highest-leverage remaining qualities (round-2 deltas — none repeat shipped work)

1. **A width contract for every permanent row, not just the header** — reflow help into two
   rows or drop to verbs-only; legend ≤ 95; badge slots reserve width (steal from ALLOY/POP
   when armed). Acceptance at 95 cols: every key on the help line visible, legend complete,
   badge fully readable. (Kills N1, half of Q19's teaching gap.)
2. **Tutorial step 1 must be a player-controllable act**: check the predicate BEFORE the
   wander phase, or re-word the step to something the cursor can actually cause ("SEAT A
   WORKER — cursor to the Ω, wait"). Gate order: let a satisfied later step advance without
   waiting for earlier ones when its own predicate fires. Remove the prompt from the death
   panel frame.
3. **GOALS readout semantics**: render only goals that are currently claimable, or show
   per-goal state (`SERVE 1/3 · CONTAM ≤5 OK`), so progress never visibly regresses.
4. **One copy table, one verb**: route the restart line and all TUTORIAL strings through
   `cistern--copy`; pick RESTART or NEW GAME and use it everywhere the death screen says it.
5. **M1 dust obeys the particle contract**: spawn at demolish time (or drain pending events
   on render), glyphs from the `* ! §` set, floor-only placement like M9.
6. **Dead-pipe inspector line**: `DEAD PIPE — WIRE IT TO THE NETWORK (p)` — the last tile
   whose cursor line neither names its state nor its fix.
7. **Hint lifetime tied to intent, not keystrokes**: keep the hint until the cursor moves or
   a command succeeds, so aiming the retry doesn't erase the answer.
8. **Teach the cancel key that works everywhere**: help/badge say `u` (and ESC for GUI); or
   bind `[escape]` via terminal-escape translation for `-nw`.
9. **Bearing copy for multi-axis targets**: one compound direction (`5 southeast`) or an
   explicit `2 east + 4 north` so it can't read as two structures.
10. **Boot flavor vacates the tail on first player action** — it still spends a tail slot
    whenever the log holds < 3 distinct lines (probe: boot line sat above 26 events' collapse).

---

## 4. SOARS re-verified — nothing regressed

- **S1 inspector standard** — intact and extended (Q20 bearings; tank/toilet lines
  byte-identical, R2-18:21). Still the best teacher on screen; the dead-pipe line (N7) is
  the one tile that falls below it.
- **S2 pressure voice** — idle line byte-identical; new strings (`RISING`, `SEVERED —
  REWIRE`) hold the Blame! register. The log restart line's NEW GAME/RESTART drift (N4) is
  the only off-register seam.
- **S3 popups at the act** — `+10`/`+20` still spawn at the toilet cell at the tick of
  relief (R2-NOTE 11b); ceremony sparkles never displace them (popup survives, sparkles
  skip occupied cells).
- **S4 purge loop** — +1 per 3 exact (R2-NOTE 13c), inspector rate verbatim, Q30 regret
  window leaves the ledger untouched.
- **S5 non-modal ceremony** — death panel and MAP COMPLETED both commit-first, input live,
  any key proceeds without forfeiting the banked summary (test-ux-q26 + live R2-13).

---

## Top 5 for round 2 (compact)

1. **N1 width audit of rows 2–3 + badge budget** — the help line hides how to tick, quit,
   and arm at the pinned width; every later teaching feature inherits this hole.
2. **N2 tutorial step 1** — make it controllable (pre-wander check or re-worded step), ungate
   the step order, drop the prompt from the death frame.
3. **N3 GOALS regression** — progress that moves backwards trains players to ignore the one
   motivation surface Q01–Q04 just built.
4. **N4+N5 contract stragglers** — restart line + tutorial strings into the copy table,
   RESTART/NEW GAME unified; M1 dust into the Q25 particle contract.
5. **N7+N6 cursor-truth finish** — dead-pipe inspector line names state+fix; hint survives
   aim-correction. The cursor layer is 95% of the coaching surface; finish the last tile.
