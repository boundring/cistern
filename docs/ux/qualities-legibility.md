# UI/UX Qualities — Lens: Legibility & Information

Collector: legibility pass over Cistern (Emacs-buffer toilet-sanitation sim).
Evidence: live renders dumped by `playtest/legibility.el`
(`emacs -Q --batch -l src/cistern.el -l playtest/legibility.el -f cistern-legibility-run`
→ `playtest/LEG-01..06-*.txt`) plus existing `playtest/SCREEN-*.txt` and
`src/cistern-view.el` / `src/cistern-domain.el` line refs.

Rank = legibility leverage: how much per-frame clarity each quality buys or
costs a player.

---

## 1. Dead pipe is glyph-identical to floor — VIOLATES

Unconnected pipe renders as `·` in `cistern-pipe-dead` (grey50,
`cistern-view.el:160-161`); floor renders `·` in `cistern-floor` (grey40).
Two near-identical greys and the exact same glyph. The legend itself
collides on one line: `GLYPHS:  · floor  …  · pipe` (LEG-01 line 3), while
PLAYING.md advertises pipe as `─` — the doc, the legend, and the map
disagree three ways. A player literally cannot see the network they are
building; "capacity that isn't connected is useless" (PLAYING.md:50-52) is
the core lesson and the screen hides exactly that state.

Refactor: give unconnected pipe a distinct glyph (e.g. dim `×` or dotted
`╌`) so live box-drawing vs dead reads at a squint; regenerate legend from
the same view table.

## 2. Log names workers by index; map names them by glyph — VIOLATES

Breach log: `BREACH — CREATOR #2 OVERFLOWED AT (5,6)` (LEG-04, and
`cistern-domain.el:478-480`). Map and inspector show Greek identity glyphs
α β γ δ (`cistern-view.el:75-83`). The player must translate `#2` →
index-2 → the *third* glyph (zero-based) → β, a two-step off-by-one-prone
mapping, in the worst moment (someone just burst). The comment at
`cistern-domain.el:477-478` admits identity is a view concern — the view
never re-projects log lines.

Refactor: single shared worker-name helper (glyph + ordinal) used by both
the log format and the map, so the log says `β OVERFLOWED AT (5,6)`.

## 3. The pressure line names the next action — MEETS (one dead branch)

`PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS` (LEG-02) names
the state, the object, and the key. Verified truthful: it fires exactly
when `load + cistern-use-load > tank-cap` (`cistern-domain.el:255-257`),
i.e. at 55/60 the toilet tile is already red — pressure, tank face, and
toilet face agree in the same frame. Condemned state names the restart key
(`SECTOR CONDEMNED — PRESS n TO RESTART`, LEG-05).

One caveat: the `PRESSURE RISING` branch (`cistern-view.el:236-237`)
triggers at raw total > 100 units regardless of capacity — unreachable
with a single 60-cap tank, and meaningless as capacity scales. Dead
diagnosis that a maintainer will trust.

Refactor: make the warning threshold proportional (`0.85 × Σ tank-cap`)
or delete the branch until multi-tank runs exist.

## 4. Faced log lines fade to dim after one tick — VIOLATES

`log-tail` applies severity faces only by matching the *current* tick's
rewards intents by `string=` (`cistern-view.el:283-291`). A BREACH line
that stays on screen for 3 ticks renders red for 1 tick, then dim grey for
2 more — while it is still the top threat. Minor relief lines use
`info → cistern-dim`, so "faced" and "unfaced" are visually identical for
them anyway. Also: breach lines originate in the domain log, and only
become faced via the rewards path — the face is a property of the tick,
not of the line.

Refactor: store the severity face on the log entry itself
(`(line . face)` in `cistern-st-log`) so color persists with the text.

## 5. Score, reputation, and the goal card are invisible — VIOLATES

Score exists only as transient `+10` popups with 3-tick TTL
(`cistern-game.el:328-334`); nothing persistent renders it. Reputation is
stored and clamped (`cistern-domain.el:86`, M4 deltas) but appears nowhere
in the view or driver — PLAYING.md:90-91 tells players to watch a number
the screen never shows. Goal cards are set (`cistern-game.el:451-462`) and
shape outcomes, but `grep goal-card src/cistern-view.el src/cistern.el`
returns nothing: the objectives a player is supposed to pursue are never
displayed.

Refactor: render the active goal card as the banner row's default content
and add `SCORE`/`REP` to the header line.

## 6. Only the last 3 log lines are shown; older lines are unretrievable — VIOLATES

The view tail-caps at 3 (`cistern-view.el:284`), and the state log itself
truncates at 12 with `nbutlast` (`cistern-domain.el:118-121`) — the 13th
oldest line is destroyed, not just hidden. In a failure-driven sim the
audit trail ("why is this worker sick? where did the leak start?") is the
memory of the run, and it evaporates.

Refactor: one `L` key that opens the (uncapped) log in a read-only temp
buffer; keep the 3-line tail on the main screen.

## 7. Red consistently means bad; but the pressure line itself is grey — PARTIAL

Face semantics are disciplined: tank-full, toilet-down, hazard are all
`red + bold` (`cistern-view.el:33-40`), worker-sick orange, live pipe cyan
bold, dead pipe grey. No face is reused across the good/bad boundary —
yellow (tank-high) vs yellow3 (ore) is the only near-adjacency. But the
single most urgent line on the screen — `PRESSURE CRITICAL …` — is
rendered unconditionally in `cistern-dim` grey (`cistern-view.el:316-317`),
the same face as the key-help line. Urgency is written but not shown.
Same for `SECTOR CONDEMNED` in the inspector row.

Refactor: face the pressure line by state — red bold for CRITICAL,
yellow for RISING, dim for NOMINAL.

## 8. Ceremony decoration erases structure — VIOLATES

Particle overlay wins over cell glyphs (cursor > worker > particle > cell,
`cistern-view.el:249-252`), and the M9 fill spawns 64 sparkles anywhere in
bounds (`cistern-game.el:285-301`). In LEG-06 the starter plumbing is
gone: a digit `1` sits where the pipe run was, `!` replaces wall segments
(row `▓▓!▓6▓▓`), and sparkle glyphs (`·`, digits, `!`) collide with floor
`·` and with score popups (`+20` in SCREEN-13 mangles the pipe line into
`+20─▣`). Celebration hides the very network the player just finished.

Refactor: spawn/draw sparkles only over plain floor cells (skip
pipe/toilet/tank/wall), and drop `·` and bare digits from the sparkle set.

## 9. Contamination — the lose condition — has no urgency signal — PARTIAL

Hazard tiles themselves are excellent: red bold `▒`, and the inspector on
one names the cure (`CONTAMINATION — press c to decon`, LEG-04). But the
global counter `CONTAM 5/20` sits in a header where every character shares
one white bold face (`cistern-view.el:179-180`), so 5/20 and 19/20 are
pixel-identical. The first global warning is the game-over text itself.

Refactor: face the CONTAM fraction per-tick — yellow at ≥50%, red bold at
≥75% — via a propertized header segment.

## 10. The inspector locates but doesn't orient; the header carries debug noise — PARTIAL

Inspector is the best information surface in the game — cursor target,
load values, worker bladder %, ticks remaining (`cistern-view.el:196-231`)
— but on plain floor it returns only `CURSOR (3,6): FLOOR` (LEG-01): raw
coordinates, no bearing to anything. With a two-room map and no
minimap/labels, a new player must scan for Ω/▣ by eye every time. Meanwhile
the header spends 13 characters on `SEED 1823504434` — a value with no
in-run decision attached to it (PLAYING.md:95 even lists it last).

Refactor: on empty floor, have the inspector append the nearest structure
bearing (`FLOOR — toilet Ω 3 west, tank ▣ 2 north`), and move SEED to the
`?` briefing; spend the reclaimed header width on SCORE/REP (see #5).

---

## Summary of captures

| File | State |
|---|---|
| `playtest/LEG-01-cold-start.txt` | cold start |
| `playtest/LEG-02-tank-85pct.txt` | tank 55/60 (pressure state) |
| `playtest/LEG-03-toilet-backed-up.txt` | tank 60/60, toilet backed up |
| `playtest/LEG-04-contamination-3.txt` | 4 hazards, contam 5/20 |
| `playtest/LEG-05-condemned.txt` | contam 20/20, sector condemned |
| `playtest/LEG-06-ceremony.txt` | MAP COMPLETED banner + 64 sparkles |
