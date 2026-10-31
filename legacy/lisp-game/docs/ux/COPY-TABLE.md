# Copy Table — player-facing strings

Inventory of `cistern--copy` (src/cistern-domain.el, Q11 protect
table). Every new player-facing string lands in that table; this
file is the review surface for the docs register. One line per
string, with where it renders.

| Key | String | Renders |
|-----|--------|---------|
| `milestone/big-cistern` | BIG CISTERN ONLINE | log + banner row, at the act tick (M8 ladder, 5 relieves) |
| `milestone/fast-flush` | FAST FLUSH ONLINE | log + banner row, at 15 relieves |
| `milestone/self-clean` | SELF-CLEAN ONLINE | log + banner row, at 30 relieves |
| `milestone/air-freshener` | AIR FRESHENER ONLINE | log + banner row, at 50 relieves |
| `milestone/golden-pipe` | GOLDEN PIPE ONLINE | log + banner row, at 100 relieves; crossing 100 also fires the full ceremony |
| `pressure-rising` | PRESSURE RISING — TANK %d%% | pressure line, yellow, when total load reaches 85% of total tank capacity; % is the fullest tank's fill |
| `pressure-severed` | LINES SEVERED — REWIRE (p) — TANK AT (%d,%d) | pressure line, red bold, when a toilet has no pipe path; names the nearest tank cell |
| `pressure-severed-bare` | LINES SEVERED — REWIRE (p) | pressure line, red bold, severed variant with no tank placed |
| `refusal-no-floor` | NO FLOOR THERE — AIM FOR OPEN FLOOR | one-tick hint row under the inspector, on a build refused off floor (Q18) |
| `refusal-alloy` | NEED %d ALLOY — PURGE (x) PAYS | one-tick hint row, on a build short of alloy; %d is the piece's price |
| `badge-armed` | "  ARMED: %s — CLICK PLACES, ESC CANCELS" | dim badge slot after REP in the header strip, while a build verb is armed; %s is the upcased verb |
| `badge-auto` | "  AUTO-RUN" | dim badge slot, while auto-run is on (Q29) |
| `help-arm` | t/p/K arm — click to place | end of the help line (screen line 2) and the `?` briefing |
| `bearing-floor` | FLOOR — %s | inspector line on plain floor; %s is the nearest-toilet/nearest-tank bearing (Q20) |
| `death-panel` | %s / TICKS %d · RELIEVES %d · SCORE %d / PRESS n TO RESTART | banner row on condemnation, built from the banked run summary (Q23) |
| `goal-met-served` | GOAL MET — %d SERVED | log narration before MAP COMPLETED (Q24) |
| `goal-met-bursts` | GOAL MET — %d BURSTS HELD | log narration before MAP COMPLETED |
| `goal-met-ceiling` | GOAL MET — CONTAM UNDER %d | log narration before MAP COMPLETED |
| `tutorial-1` | MOVE THE CURSOR ONTO A WORKER | tutorial line, cyan, step 1 of 3 (Q27) |
| `tutorial-2` | PURGE A FILLING TANK (x) | tutorial line, step 2 of 3 |
| `tutorial-3` | THE PURGE PAYS — ALLOY IN THE BANK | tutorial line, step 3 of 3 |

## Not in the table

Pre-existing view copy (src/cistern-view.el) stays byte-identical
and lives where it renders: `LINES NOMINAL — THE STRUCTURE DOES NOT
CARE` (pressure line, the register calibration point),
`PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS`,
`SECTOR CONDEMNED — PRESS n TO RESTART`, `MAP COMPLETED` (banner
intent, rewards use case), the inspector sentences per tile kind,
the worker status line, and the briefing (`?`) prose.
