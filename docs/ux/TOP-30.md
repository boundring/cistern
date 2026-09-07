| # Cistern UX — TOP 30 Refactor Directives (BUILD ORDER)

> STATUS: ROUND-1 SHIPPED 2026-09-07 — all 30 directives (Q01..Q30)
> implemented and batch-tested (tests/test-ux-r1.el, 64/64 suite);
> ledger L-035..L-059.

Curator: ux-curator. The TOP-20 grown with 10 derived qualities (marked **derived** — the
top-20 entry they are implied by is named). Ordered as a build order: a row may depend on any
earlier row, never a later one. Sizes: S ≤ ~15 lines, M ≤ ~1 file/50 lines, L = cross-layer.

Key pinned dependencies (per director): rewards-visibility strip (Q01) before milestone
announcements (Q05); pressure-line gradient (Q08) before the severed-vs-backed split (Q09);
domain split (Q09) before the line re-branch (Q10).

| # | Quality (source) | Directive | Acceptance (batch) | Size | PROTECT constraints |
|---|---|---|---|---|---|
| Q01 | **derived** ← #2: header strip layout contract | `cistern-view.el` header: fixed segment order `TICK ALLOY POP CONTAM SCORE GOALS REP`; move `SEED` to the `?` briefing text (`cistern.el:197-208`). Reserve one dim segment slot for badges (armed Q19, auto-run Q29). | Batch render at 95 cols contains `SCORE`, `GOALS`, `REP` and no `SEED`; no segment truncated at width 95. | M | #10: strip copy stays inspector-grade terse. |
| Q02 | #2: score/reputation rendered | View reads `cistern-st-score` and rep (`cistern-domain.el:86`) into the Q01 segments. No game-layer change. | After one driven relief, next render's `SCORE` is greater than before; `REP` matches state. | S | #13: popups stay the act-time channel; strip is the persistent total only. |
| Q03 | #1: goal card dealt from tick one | `cistern-game.el` `cistern--new-game` issues a starter card via the existing `cistern--cmd-set-goal-card` (e.g. serve 3, ceiling 5) — one call; the whole REWARDS-DESIGN §1 loop goes live. | Batch new game has a non-nil goal card; a driven run can reach MAP COMPLETED without test injection. | S | #17: card commit stays non-modal. |
| Q04 | #2: goal progress rendered | Strip `GOALS n/m` reads active-card objectives each render. | Drive first objective met → render shows `GOALS 1/…` same tick. | S | — |
| Q05 | #8: milestone unlocks announce | `cistern-game.el:357` unlock intent gains `:layer` (`log` + `banner`) so the view's existing log-tail/banner routing picks it up; format `MILESTONE — BIG CISTERN ONLINE`. | Batch crossing 5 relieves: log line and banner present in the same frame's capture (ANTAG-12 scenario no longer silent). | S | #17: banner commit-at-trigger, any key skips. |
| Q06 | #13: PROTECT popup channel | Constraint made executable: milestone and purge reward events reuse the popup-at-act mechanism (`cistern-game.el:317-328`); popup z-order (cursor > worker > popup > cell) unchanged. | Relief still pops `+10`/`+20` at the toilet cell at the tick of relief (SCREEN-13 pattern). | S | IS the protect. |
| Q07 | #14: PROTECT purge economy guard | Purge inspector line (`cistern-view.el:213` region) and the 1-alloy-per-3 rate stay verbatim; any economy change (incl. Q30) must keep the inspector rate true. | Purge at a known tank load changes alloy by exactly the advertised amount. | S | IS the protect. |
| Q08 | #11: pressure gradient anticipates | `cistern-view.el:236-238`: middle tier threshold becomes proportional (≥0.85 × Σ tank-cap) and shows headroom % (`PRESSURE RISING — TANK 92%`). Delete the raw-total branch. | Batch: tank at 0.9×cap → `RISING` (not CRITICAL); at cap → CRITICAL; one-tank game reaches RISING before failure tick. | M | #20: RISING copy in the Blame! register. |
| Q09 | **derived** ← #4: domain state split | `cistern-domain.el:293-301`: split `cistern--toilets-backed-p` consumers into severed-p (no path) vs backed-up-p (path, over capacity); expose both to the view. | Batch severed-with-empty-tanks state differs from backed-up state in the exposed flags. | M | — |
| Q10 | #4: pressure line re-branch + offender coords | `cistern-view.el:236-239`: SEVERED branch advises rewiring (`LINES SEVERED — REWIRE (p)`), never purge; backed-up keeps purge advice. **derived** (← #4, from I9): name the offending tank's coordinates — the flood-fill data already exists. | ANTAG-05 scenario: pressure line and inspector agree (`LAY PIPE`); line names the tank cell. | S | #20: severed copy in register. |
| Q11 | #20: PROTECT voice register | Idle pressure line stays byte-identical (`THE STRUCTURE DOES NOT CARE`); all new strings from Q05/Q08/Q10/Q23/Q24/Q28 written in the same register; flavored-copy additions go through one string table in the domain. | String-equality check on the idle line; new user-facing strings exist only in the copy table. | S | IS the protect. |
| Q12 | #5: dead pipe glyph + legend from table | `cistern-domain.el:41-43`: unconnected pipe gets a distinct glyph (dim `×` or `╌`); **derived** (← #5): the legend line is generated from the same view tile table, so one glyph can never be listed twice. | Severed-pipe cell glyph ≠ floor glyph in batch render; legend lists each glyph at most once and matches the map's actual glyphs. | S | — |
| Q13 | **derived** ← #12: severity stored on log entries | `cistern-domain.el:118-121`: log entries become `(line . severity-face)` so color persists with the text; `cistern-view.el:283-291` reads the entry's face instead of re-matching the current tick's intents by `string=`. | A breach line renders red for every tick it stays in the tail (3+ ticks), not just tick one. | M | — |
| Q14 | **derived** ← #12: shared worker-identity helper | One helper (glyph + ordinal, e.g. `β`) in the view layer, used by the breach log format (`cistern-domain.el:478-480`), the map, and the inspector — replacing `CREATOR #N`. | Batch breach: log names the same glyph the map shows at that cell (β for glyph β, no off-by-one). | S | — |
| Q15 | #12: log consequence ranking + spam suppression | Tail rendering: breach/condemnation lines keep max severity weight; consecutive identical relief lines collapse (`×3`); boot flavor ages out like any line (ANTAG-11). | Batch with breach + relief spam: the 3-line tail contains the breach; identical consecutive lines shown once. | M | #20: suppression is silent, no new copy. |
| Q16 | #12: full log retrievable | `L` opens the uncapped log (drop the 12-entry `nbutlast` destruction — keep an uncapped ring in the domain) in a read-only temp buffer; main screen keeps the 3-line tail. | Batch: after 13+ log events, `L` buffer shows line 1; read-only; main render unchanged. | S | — |
| Q17 | **derived** ← #3: transient cursor-hint surface | `cistern-view.el` inspector row gains a one-tick transient hint slot (below the inspector line); any refusal/event can post a hint consumed by the next render. Generic — refusals today, other coaching later. | Refused build: hint visible in that tick's capture, absent in the next; no permanent layout shift. | M | #10: hint copy follows the inspector pattern. |
| Q18 | #3: refusal copy names next action | Refusals (`cistern-game.el:27` build-on-wall, insufficient-alloy) post through Q17 with fix-naming copy: `NO FLOOR THERE — AIM FOR OPEN FLOOR`, `NEED 15 ALLOY — PURGE (x) PAYS`, and the cursor inspector reflects the refusal state for that tick. | ANTAG-03/04 scenarios: hint text names an action; log still records the refusal (history intact). | S | #10, #20. |
| Q19 | #6: armed verb visible + cancelable + taught | Header badge via Q01's badge slot (`ARMED: PIPE — CLICK PLACES, ESC CANCELS`); `ESC` (or `u`) clears `cistern-st-armed-verb`; help line gains one phrase (`t/p/K arm — click to place`); **derived** (← #6, from I3/I4): at-cursor keypress refuses cleanly instead of arm-then-fail noise (`cistern.el:127-136`). | Batch: after `p`, header contains `ARMED: PIPE`; after ESC, click builds nothing and consumes no tick; help line contains the arm phrase. | M | #17: no modal — armed state never blocks input. |
| Q20 | #10: PROTECT inspector standard, extended | Inspector on empty floor appends nearest-structure bearing (`FLOOR — toilet Ω 3 west, tank ▣ 2 north`, manhattan from the shared geometry); existing per-tile lines untouched. | Batch: cursor on plain floor names a structure and a direction; all existing inspector captures byte-identical otherwise. | S | IS the protect — extension only, zero regression on existing lines. |
| Q21 | #16: urgency colored | Propertize: pressure line faced by state (red bold CRITICAL, yellow RISING, dim NOMINAL — `cistern-view.el:316-317` loses the unconditional dim); CONTAM header segment yellow ≥50%, red bold ≥75%. | Batch: CONTAM 16/20 renders red bold; 5/20 does not; CRITICAL line is red bold. | S | #16/#20 interplay: colors, not new words. |
| Q22 | **derived** ← #7: run-summary snapshot | Domain/game: at condemnation capture one struct — ticks survived, relieves, score, trophies, cause (`cistern-game.el:363-364` outcome already carries score). | Condemned state exposes summary fields matching the driven run's counts. | S | — |
| Q23 | #7: death summary panel | On condemned, the view renders the Q22 snapshot as a panel (banner layer): `SECTOR CONDEMNED — CONTAMINATION LIMIT / TICKS 291 · RELIEVES 12 · SCORE 250 / PRESS n TO RESTART`; suppress the four duplicate post-over log lines (motivation M7). | ANTAG-13 scenario: one frame contains ticks/relieves/score/cause; log shows a single restart line, not four. | M | #17: commit-first, any key skips, input live; #20: cause line in register. |
| Q24 | #15: ceremony narrates cause | Before the MAP COMPLETED banner, log each goal as satisfied (`GOAL MET — 3 SERVED`) from the card objectives (needs Q03). | SCREEN-13 rerun: GOAL MET lines precede the banner in the log. | S | #17, #13. |
| Q25 | **derived** ← #15: particle placement contract | Sparkles spawn/draw only over plain floor cells (`cistern-view.el:249-252` z-order keeps cursor > worker > particle, but placement skips pipe/toilet/tank/wall); remove `·` and bare digits from the sparkle set (`cistern-game.el:285-301`). | LEG-06 rerun: pipe run and walls visible under ceremony; no sparkle glyph collides with floor `·` or popups. | S | #13: popup layer unaffected. |
| Q26 | #17: PROTECT non-modal architecture guard | Constraint made executable for all new ceremonies (Q05, Q23, Q24): commit at trigger time, input stays live, any key skips. | Existing test pattern (`test-4b-rewards.el:828-835`) extended: a keypress during the death panel starts the new game without forfeiting the banked summary. | S | IS the protect. |
| Q27 | #9: tutorial table ships | Populate `cistern--tutorial-steps` (mechanism exists, `cistern-game.el:84-108`) with 3 steps: move cursor onto a worker → purge a filling tank → watch alloy pay; steps render as a persistent prompt line, not log lines. | Batch new game: step 1 prompt visible by tick 3; driving the actions advances all 3 steps. | M | #10: step copy is inspector-grade; #20. |
| Q28 | #9: briefing proofread | `cistern.el:185-191`: fix the `princ` `%%` escapes → `%`; while in the briefing, add the arm-then-click line (with Q19) and SEED mention (from Q01). | Batch: `cistern-help` output contains `60%` and `100%`, no `%%` anywhere (SCREEN-14 regression). | S | — |
| Q29 | #18: auto-run surfaced + pacing | `cistern-input.el:45`: header badge via Q01's slot while the idle-timer handle is live; prefix-arg slow speed (1 tps) alongside the 5 tps toggle; help line mentions `r`. | Batch: toggle on → header contains `AUTO-RUN`; slow mode shows ~1 tick/second spacing across captures. | S | #17: pause-on-keypress behavior unchanged. |
| Q30 | #19: free regret window | Demolish in the same tick the piece was placed refunds fully (skip the 50%-refund split when tick-of-build = tick-of-demolish); can't-afford-demolish never leaves an unfixable mistake in tick 1 (cheap-start alloy covers it). | Batch: place pipe + demolish immediately → alloy unchanged; place, tick, demolish → old refund rules. | S | #14: purge ledger untouched (Q07 guard). |

## Dependency chains (director's map)

- Q01 → Q02, Q04, Q05(display), Q19(badge), Q21(CONTAM segment), Q29(badge)
- Q03 → Q04, Q24
- Q08 → Q09 → Q10 (director-pinned: gradient before split before re-branch)
- Q12 self-contained; Q13 → Q15; Q14 → Q15
- Q17 → Q18
- Q22 → Q23; Q26 constrains Q05, Q23, Q24
- Q07 guards Q30; Q11 constrains all new copy (Q05, Q08, Q10, Q23, Q24, Q27, Q28)

## Suggested first five (leverage per line of code)

1. **Q03** — one call makes the entire designed motivation loop reachable.
2. **Q01+Q02** — the strip: progress exists only once it is rendered; also frees header width
   and creates the badge slots three later directives need.
3. **Q05** — two lines of intent-tagging; the milestone ladder stops being silent.
4. **Q09+Q10** — the always-visible coach stops lying at the exact losing moment.
5. **Q17+Q18** — refusals become answerable where the player is looking; every later feature
   inherits the hint surface.
