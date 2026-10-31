# UI/UX Qualities — Lens: INTERACTION & FLOW

Method: batch-driven the real driver (`emacs -Q -l src/cistern.el -l playtest/ux-keys.el -f cistern-ux-keys-run`, report in `playtest/UX-KEYS-REPORT.txt`), counted interactive keypresses for real tasks (refused build, distant toilet+5-pipe run, full-tank purge, breach decon, misplacement take-back), and traced keymap/commands (`src/cistern.el`), input adapter (`src/cistern-input.el`), use cases (`src/cistern-game.el`), render (`src/cistern-view.el`), auto-run semantics (`tests/test-r6-timer.el`).

## Ranked top 10

1. **Refusal feedback is distant, generic, and visually silent** — VIOLATES.
   Evidence: build-on-wall logs only `CANNOT BUILD THERE` (`cistern-game.el:27`) into the 3-line log tail at the *bottom* of the screen, face `cistern-dim` (grey). The cursor-adjacent inspector never mentions the refusal — `CURSOR (32,14): FLOOR` while the log says no. Keyboard refusals leave no trace at the cursor at all; you must look away from where you acted to learn why.
   Refactor: flash the refusal one line under the inspector (or recolor the cursor cell red for one render) instead of only appending to the log.

2. **Armed-verb state is invisible on the main screen** — VIOLATES (mode confusion).
   Evidence: after pressing `K`, the header/help/legend render (`cistern-view--render`) contains no armed indicator; my probe found "tank" only in the static help line, not a state readout. Mouse-1 means "place tank" but the screen never says so. `cistern-st-armed-verb` is real state (`cistern-game.el:501`) with zero surface.
   Refactor: append `ARMED: TANK (click to place)` to the header line whenever armed.

3. **Arm-then-click is never taught on-screen** — VIOLATES.
   Evidence: help line reads `[arrows/mouse] cursor  [t]oilet 10` and the `?` briefing's CONTROLS section (`cistern.el:197-208`) never mentions that a verb key *also* arms mouse placement. The workflow is only discoverable by accident (`playtest/SCREEN-08-click-armed.txt`). Yet it is the cheapest path: toilet + 5-pipe run = 6 presses + 4 clicks vs ~40 keyboard presses (T1b/T5 travel counts).
   Refactor: one help-line phrase: `t/p/K arm — click to place at any cell`.

4. **Keyboard build keys conflate arm-and-place, generating spurious refusals** — VIOLATES.
   Evidence: `cistern--arm-and-build` (`cistern.el:127`) arms AND immediately attempts a build at the cursor. After a toilet occupies the cursor, pressing `p` logs `CANNOT BUILD THERE` yet still arms pipe (T2 log: TOILET PLACED → CANNOT BUILD THERE → PIPE PLACED). Refusing but arming is incoherent feedback; the log noise pollutes the 3-line tail players read.
   Refactor: refusal on the at-cursor attempt should leave state (armed or not) unambiguous — e.g. still arm but log `ARMED PIPE — CLICK TO PLACE` instead of a build-refusal line.

5. **Auto-run (5 tps) has no on-screen indicator and no pacing control** — PARTIAL.
   Evidence: `cistern-input-auto-run-toggle` (`cistern-input.el:45`) schedules a 0.2s idle chain; the header shows TICK but never "AUTO-RUN ON". 5 tps is fine for watching migrant flow but too fast to time a purge against a filling tank, and there is no speed choice — only on/off. Idle-timer base is good (any keypress naturally pauses it) but that too is unexplained to the player.
   Refactor: header badge `AUTO-RUN` when the handle is live; optionally `R`-with-argument for 1 tps "think speed".

6. **Undo is paid, not free — misplacement costs alloy every time** — PARTIAL.
   Evidence: T5: place pipe + demolish = alloy 100→96 (build 2, demolish 3, refund 1, `cistern-game.el:69-75`). Correct economics at the 50%-refund design level, but there is no *free* regret: a wrong click in the first seconds of play already bleeds resources, and `CANNOT`-afford-demolish leaves a mistake permanent (`INSUFFICIENT ALLOY — 3 REQUIRED`).
   Refactor: free demolish within the same tick it was placed (build↔demolish ping-pong is already safe).

7. **Keyboard/mouse parity is asymmetric in tick semantics** — PARTIAL.
   Evidence: keyboard build = arm + place, no tick (`cistern--arm-and-build`); click-with-verb = place + exactly one tick (`cistern--cmd-click`, R6 contract at `cistern-game.el:486`). The same act of placing a pipe advances the clock or doesn't depending on the input device — an invisible rule that bites when contamination timing matters.
   Refactor: make the keyboard at-cursor path tick too (or the click not), so device choice doesn't change tempo.

8. **Tick feedback is adequate, celebration pacing is the outlier** — MEETS mostly.
   Evidence: every tick visibly changes header TICK, workers move, tanks recolor (tank-ok/high/full faces), pressure line shifts (`PRESSURE RISING`/`NOMINAL`). Particle advance is tied to redisplay (`cistern.el:33`). Good time-moved signal. Only the reserved banner row renders as an empty line by default (`cistern-view.el:307` DEFERRED) — minor dead space.
   Refactor: none urgent; fill or remove the empty banner row in 4b.

9. **"Waiting on me or on them?" is answered — but only if you read the inspector** — PARTIAL.
   Evidence: pressure line (`cistern-view.el:233-239`) names the systemic state (`PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS` — actionable, names the verb), and the inspector per-cell explains toilet states with the exact fix (`SEVERED: LAY PIPE TO A TANK (p)`, `BACKED UP: PURGE THE TANKS (x)`). Strong. But the *cursor must already be on the problem tile* to see it; nothing highlights which of many toilets/tanks is the offender.
   Refactor: pressure line should name the offending tank's coordinates (it already has the flood-fill data).

10. **Cursor visibility is solid, geometry mapping exact** — MEETS.
    Evidence: buffer cursor hidden (`cursor-type nil`) in favor of an inverse-video cell face (`cistern-cursor`, `cistern-view.el:44`), z-order pinned D5 (cursor > worker > particle), click→cell via the same shared geometry constant (`cistern-view--cell-at`, L-014 header-lines pin). Batch test confirms clicks land on the intended cell. Out-of-map clicks silently ignored (`cistern.el:123` `when xy`) — acceptable.

## Error costs summary
- Exploration is cheap on *refusals* (state untouched, no tick — R6 contract) and expensive on *successes* (paid undo, #6). The failure mode that punishes is the log-only feedback loop: players retry builds blind because the WHY never travels to the cursor.
