# Cistern UX — Round-2 Refactor Directives (BUILD ORDER)

> STATUS: ROUND-2 SHIPPED 2026-09-07 — all 15 directives (R2-Q01..Q15)
> implemented and batch-tested (tests/test-ux-r2.el, 79/79 suite);
> ledger L-060..L-075.  Sources: `antagonist-round2.md` (5 PARTIAL
> verdicts, N1–N8, top-10) + `qualities-round2.md` (R2-1..10), deduped.
> Polish-class set, capped at 15. Anything structural routes to the director instead
> (see the routing notes at the end).

Curator: ux-curator-r2. Round-1 exclusions: everything Q01–Q30 shipped is OUT of scope
(verified FIXED by the antagonist; only the PARTIAL residues reappear here). Format and
discipline per TOP-30: a row may depend on any earlier row, never a later one.
Sizes: S ≤ ~15 lines, M ≤ ~1 file/50 lines, L = cross-layer. The five SOARS (S1 inspector
standard, S2 pressure voice, S3 popups at the act, S4 purge ledger, S5 non-modal ceremony)
and the Q11 copy-table rule still bind.

Key pinned dependency: the copy-table sweep (R2-Q03) precedes every directive that adds new
player-facing strings (R2-Q07, Q08, Q09, Q10, Q12) — their strings land in the table in the
same change, not after it.

| # | Quality (source) | Directive | Acceptance (batch) | Size | PROTECT constraints |
|---|---|---|---|---|---|
| R2-Q01 | **N1** (antagonist top-10 #1; R2-3): width contract for ALL permanent rows | `cistern-view.el` `cistern-view--help-line` (`:220-226`): reflow the 168-col help into two deliberate dim rows — row A cursor + act verbs (`[arrows/mouse] … [x]purge`), row B arm/meta (`[t]/[p]/[K] arm — click to place`, `[r]auto-run`, `[n]ew`, `[?]help`, `[q]uit`). `cistern-view--legend-line` (`:228-242`): wrap on a `GLYPHS:`-aligned continuation row so `α worker` is never orphaned. Contract: no permanent row exceeds 95 cols. | At 95 cols: every help key visible including `[SPC]tick` and the Q19 arm phrase; legend complete including `α worker`; probe every permanent render row ≤ 95 (the round-1 tests asserted full strings — the new assertions assert against the 95-col truncated render). | M | #10: reflow is layout only — help copy stays inspector-grade terse. |
| R2-Q02 | **N1 + N8** (R2-1, R2-2 width half): badge budget + header-append contract | The ARMED badge (`badge-armed` in `cistern--copy`, rendered `cistern-view.el:190-197`) moves to its own reserved dim row directly below the strip — the header stays a fixed-geometry block and `cistern-view--cell-at` math is updated once, consciously, to 4 rows. Append contract: at most one badge row (ARMED and AUTO-RUN coexist on it: `ARMED: PIPE · AUTO-RUN`); the condemn append shortens to `!! CONDEMNED`. The block height is a constant both the renderer and `cell-at` derive from — never two independent numbers. | Cold header block = 3 rows; armed or auto-run = 4; the combined armed+auto-run+condemned render fits 95 with full badge text visible; **map-geometry probe: with the badge row live, `cell-at` of the map's first cell is unchanged** — the round-1 wrap bug is the regression test. | M | #17: armed state never blocks input; Q01 segment order untouched. |
| R2-Q03 | **N4 + Q11 stragglers**: one copy table, one verb | Route the hardcoded restart log line (`cistern.el:99`) and all TUTORIAL strings (`cistern-game.el:141,148`, `cistern-view.el:385`) through `cistern--copy`. Pick RESTART; rewrite the log line to `SECTOR CONDEMNED — PRESS n TO RESTART` so panel, pressure line, and log agree. New keys: `restart-log`, `tutorial-1..3` relocated into the table. | Death-frame capture: every `PRESS n` occurrence says RESTART (zero `NEW GAME`); the three tutorial strings exist only in `cistern--copy` (test greps source for the literals outside the table — none); idle pressure line stays byte-identical. | S | IS the Q11 protect. |
| R2-Q04 | **N3** (top-10 #3): GOALS progress never regresses | Claimed-only semantics for the ceiling objective: `contam ≤ 5` counts once claimed (evaluated when contamination first rises past… no — simplest: a goal, once counted, stays counted for the readout; the check is monotone). `GOALS n/m` renders the count of satisfied-at-least-once objectives. | Fresh game renders `GOALS 0/2` (not 1/2); a driven run where contamination crosses the ceiling then keeps rising never shows the count drop between any two captures; completion (2/2 → MAP COMPLETED) unchanged. | S | Q03/Q04 motivation loop untouched — the card, scoring, and narration are not re-touched. |
| R2-Q05 | **N5** (Q25 PARTIAL residue): M1 demolish dust obeys the particle contract | `cistern-game.el:274`: demolish dust spawns at demolish time (or its pending events drain on the next render, so zero-tick-delay is observable), glyphs drawn only from the M9 set `* ! §`, placement floor-only like M9. | Immediately after a demolish capture contains dust particles (no intervening tick needed); no particle is `·` or `.`; all dust on plain floor. | S | #13: popup layer unaffected; Q25 M9 behavior untouched. |
| R2-Q06 | **N6** (top-10 #7): hint lifetime tied to intent, not keystrokes | The Q17 hint slot drains on a command that is not a cursor move; cursor moves (the aim-correction) and renders preserve it. Any successful command, a new refusal, or `over` clears it. Reserve the hint row permanently (dim blank when idle) so the pressure line never shifts down for a hint tick. | Refusal → one cursor-east → hint still visible in that capture; next non-cursor command (or the corrected successful attempt) clears it; pressure-line row index identical with and without a live hint. | S | Amends Q17's one-tick spec — the transient-until-actionable intent is kept; #10 copy rules unchanged. |
| R2-Q07 | **N7** (R2-7; top-10 #6): dead pipe inspects as dead | `cistern-view.el` inspector (`:244-274`): add the severed-pipe branch before the default — copy-table key `pipe-dead`: `PIPE — DEAD: NOT CONNECTED — REWIRE (p)`. | Cursor on a ╌ cell renders the dead line (state + fix verb); all other inspector lines byte-identical (the S1 zero-regression probe). | S | S1 inspector standard; string lands in the table per R2-Q03. |
| R2-Q08 | **R2-4** (top-10 #8): shipped interactions named on a player-facing surface | Briefing CONTROLS (`cistern.el` `?` text) gains three lines: `L full log`, `u cancel armed verb (ESC on GUI)`, `C-u r slow auto-run (1 tps)`. Teach `u` as the everywhere-cancel; ESC stays the GUI nicety. | `cistern-help` output contains `L`, `u`, and `C-u r` mentions (R2-07 probes mentions-L/ESC/slow all flip non-nil). | S | Copy lands in the briefing prose per the COPY-TABLE "not in the table" rule; no keybindings changed. |
| R2-Q09 | **R2-5**: the free same-tick regret is discoverable at the moment it matters | Demolish inspector on a cell built this tick appends table key `same-tick-free`: `— SAME-TICK: FREE UNDO`. | Place a pipe, cursor onto it before ticking: inspector line contains `SAME-TICK: FREE UNDO`; after one tick it does not; Q30 mechanics untouched. | S | S4 purge ledger; Q07 rate line untouched. |
| R2-Q10 | **R2-6**: the strip's GOALS segment is explained somewhere | One briefing paragraph (THE LOOP section, `cistern.el:217-229`): `GOALS n/m tracks the active goal card; complete it for score and trophies.` | `cistern-help` output mentions GOALS and the goal card (R2-07 mentions-goals flips non-nil). | S | #17: card commit stays non-modal (copy only). |
| R2-Q11 | **N2** (Q27 PARTIAL; top-10 #2): tutorial step 1 is a player-controllable act | Three fixes in one pass: (a) step predicates are checked BEFORE the wander phase in `cistern--do-tick` so a chased worker cannot escape mid-tick; (b) the one-per-tick gate becomes per-step — a satisfied later step advances even when an earlier one hasn't (purge-first players reach 2/3); (c) the tutorial line is suppressed while `over`. Step copy may be reworded to the honest act (`SEAT A WORKER — CURSOR TO Ω, WAIT`) only if (a) still leaves a lottery — state which fix carried in the PR. | With cursor parked on a worker's tick-start cell the step advances that tick (deterministic on a pinned seed); a purge-first driven run reaches step 2 without step 1; death-frame capture contains no TUTORIAL line; suite's tutorial tests updated to drop the 60-tick luck bound. | M | #10, #20; Q27's persistent-prompt-line mechanism untouched. |
| R2-Q12 | **R2-9** (Q14 residue): worker naming agrees across surfaces | Breach format (`cistern-domain.el:478-480` region): `BREACH — WORKER δ OVERFLOWED AT …` (drop the CREATOR noun; the δ glyph already carries identity). Same sweep for the round-1 `CREATOR RELIEVED` collapse wording — one noun everywhere. | Breach capture contains no `CREATOR`; log, map, legend, inspector all say worker/δ; Q14's glyph-match probe still green. | S | A9 (named actors) preserved — the noun changes, the naming does not disappear. |
| R2-Q13 | **R2-10**: the `L` log buffer exits like everything else | `cistern.el:191-203`: open the log buffer read-only with `(use-local-map special-mode-map)` (or a `q` → `quit-window` binding) and prepend `— press q to close —`. | `L` buffer shows the log, `q` closes it returning to the game, hint line is the buffer's first line; main render unchanged. | S | Q16: still read-only, oldest-first, uncapped. |
| R2-Q14 | **top-10 #9** (Q20 copy nit): multi-axis bearings read as one target | The Q20 bearing helper: multi-axis targets render as one compound (`tank ▣ 2 east + 4 north`); single-axis lines unchanged. | Floor bearing at a diagonal offset contains exactly one `+`-joined compound; single-axis captures byte-identical. | S | S1/Q20: extension of copy only, no geometry change. |
| R2-Q15 | **top-10 #10**: boot flavor vacates the tail on first player action | Log-tail ranking (`Q15` collapse logic): the `[boot]` line ranks below any player-era line; with ≥3 newer distinct events it never occupies a tail slot. | After first player command with 3+ newer events, the 3-line tail contains no boot line; with an empty log the boot line still renders. | S | Q15: suppression stays silent, no new copy. |

## Dependency chains

- R2-Q03 → R2-Q07, R2-Q09, R2-Q10, R2-Q12 (new copy lands in the table)
- R2-Q01 is independent; R2-Q02 touches the same header block — land Q01 first, Q02 second,
  then re-run both width probes together.
- R2-Q06 amends Q17's spec; R2-Q11's (c) reuses R2-Q06's reserved-row pattern if the tutorial
  line shares the hint slot region.
- R2-Q04 is self-contained; R2-Q05 guards itself against Q25's M9 tests.

## Suggested first five (leverage per line of code)

1. **R2-Q01** — the game hides how to tick, quit, and arm at the pinned width; every teaching
   feature inherits this hole.
2. **R2-Q02** — the badge shifts the whole map under the cursor; geometry integrity is the
   acceptance core.
3. **R2-Q03** — one sweep legalizes the copy of five later directives.
4. **R2-Q04** — a motivation readout that moves backwards trains players to ignore it.
5. **R2-Q06 + R2-Q07** — finish the cursor layer: the hint that survives aiming, and the last
   tile that doesn't name its state or fix.

## Deliberately routed OUT (to the director, not this set)

- **`-nw` terminal-escape translation** (binding real `<escape>` in terminal frames):
  an input-layer change with regression risk across every ESC-adjacent binding; round 2
  takes the copy route (`u` taught everywhere, ESC labeled GUI-only) inside R2-Q08. If
  `-nw` players remain second-class after that, the director owns the binding change.
- **Header geometry rearchitecture beyond the badge row**: R2-Q02 fixes the one known
  geometry break with a single constant; a general renderer/layout abstraction is
  structural and stays with the director.
- **Step-copy redesign as a tutorial system** (reordering steps, new steps, per-step
  surfaces): R2-Q11 repairs the shipped 3 steps only; any tutorial redesign is structural.
- **GOALS per-goal rendering** (`SERVE 1/3 · CONTAM ≤5 OK` variant from top-10 #3): kept as
  an alternative acceptance shape, not a second directive — monotone claimed-only counting
  (R2-Q04) kills the regression with less strip width; the per-goal render needs a wider
  contract than 95 cols comfortably gives.
- Nothing else from the two source docs: all N1–N8, all 5 PARTIAL residues, and all ten
  collector qualities are claimed above; the count lands exactly at the 15 cap.
