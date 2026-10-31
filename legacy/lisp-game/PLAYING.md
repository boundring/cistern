# PLAYING CISTERN

Sanitation duty, Sector 7, in an Emacs buffer.

## Run it

```
emacs -Q -l /path/to/cistern/src/cistern.el
M-x cistern
```

The game opens in the `*cistern*` buffer.

## The job

You run the sanitation for one sector of the Structure. Workers
(α β γ …) mine ore (◆) for alloy. Alloy buys pipes, fixtures, tanks.
Their bladders fill as they work — 2% a tick. At the seek threshold a
worker walks to a fixture and sits down; entering the tile is sitting
down. A fixture works only when pipe (─) connects it to a tank (▣) with
room left — or to a manifold (╬), which needs no tank. Each use sends
waste down the line and occupies the fixture for a few ticks.

A full tank backs up every fixture it feeds. Backed-up fixtures turn
red and refuse customers. Purge the tank with `x`: free, and it
pays — 1 alloy per 3 units of waste.

A worker who cannot reach a working fixture eventually breaches. The
tile turns to contamination (▒), which spreads, and nearby workers
fall sick. Decontaminate with `c`. At 20 contamination the sector is
condemned. Game over.

Every 40 ticks a migrant arrives. Population is load. The cap is 8.

## The dossiers

Every worker rolls four stats at the gate — FLOW, GRIT, NERVE,
ARCHIVE, scores 3 to 18 — and keeps them for life. The stats are
rolled per worker, and the inspector shows them: put the cursor on a
worker and read the segments after their status. What they do:

- **NERVE** moves the worker's personal seek threshold. The base is
  60%; the range across workers is 50–68%. High NERVE files the
  relief request before the spike.
- **GRIT** sets how long sickness lasts, 18–42 ticks around the 30
  base.
- **FLOW** sets mining pace, 2–6 ore-ticks per alloy around the 3
  base. Sick workers move at half pace.
- **ARCHIVE** backs the institution's checks — certifications and
  story rolls.

Every relief earns XP — a SUITED fixture pays double, and each
migrant cycle pays the whole crew 1. At 12 XP a worker reaches
CLEARANCE II; at 30, CLEARANCE III. Clearance crosses in the log.
A fixture suits a worker when it plays to their dominant stat; from
CLEARANCE II no worker is ever unsuited again.

## The fixtures

Five fixture types, one catalog. Press `T` to cycle the armed type —
the header badge names it — then `t` builds the armed type at the
cursor.

| Type | Cost | Use | Suit | Placement |
|------|------|-----|-----------|----------|
| long-drop | 10 | 2 ticks, 10 load | GRIT · FLOW | anywhere |
| fall-shaft | 8 | 2 ticks, 8 load | FLOW · GRIT | not beside another toilet |
| high-cistern | 14 | 1 tick, 10 load | ARCHIVE · NERVE | against a wall |
| archive-stall | 12 | 3 ticks, 12 load | NERVE · ARCHIVE | against a wall |
| hermetic-booth | 20 | 2 ticks, 10 load | NERVE · GRIT | anywhere |

Placement is refused with a named reason. The inspector reports a
fixture's type and state.

## Terrain

The sector grows its own obstacles:

- **Rubble ▚** — impassable debris. `d` clears it to floor for
  2 alloy.
- **Flood ░** — water, not waste. A breach can flood its neighbors;
  flood never counts toward the contamination limit — it steals
  ticks, not health. `c` dries a wet cell (3 alloy, the decon price).
- **Manifold ╬** — a free pipe anchor. Pipe wired to a manifold is
  live without any tank: unlimited headroom, no purge income. A
  manifold anchor is never severed.
- **Cache ?** — walk a worker over it and the sector banks +3 alloy.
  One pickup, then floor.
- **Event !** — a story marker stamped on open floor. Passable. It
  stands three ticks, then it is gone.

## First shifts

1. Press `SPC` a few times. One fixture is already wired to one tank.
   Put the cursor on a worker (arrow keys) and read the inspector
   line: bladder percent, stat segments, clearance.
2. When the pressure line says the toilets are backed up, cursor to
   the tank (▣) and press `x`. Free toilets. Free alloy.
3. Expand. Lay pipe (`p`) outward, add a fixture (`t`) at the far
   end, add a tank (`K`) when the load grows. The wiring rule: pipe
   connects a fixture to ANY tank with headroom — or to a manifold,
   which is headroom enough. Short runs win.
4. Contamination (▒) appears — cursor onto it, press `c`. Flood (░)
   dries the same way.
5. Press `r` to let the sim run itself at 5 ticks a second. `r`
   again takes control back.

The whole game in one sentence: **wire the fixtures to the tanks
before the bladders win.** Capacity you did not connect is not
capacity.

## Keys

| Key | Action |
|-----|--------|
| `SPC` / `RET` | advance one tick |
| arrow keys / mouse-1 | move the cursor |
| `t` | build the armed fixture type at the cursor |
| `T` | cycle the armed fixture type |
| `p` | lay pipe (2 alloy) |
| `K` | build a tank (15 alloy) |
| `d` | demolish (3 alloy; full refund same tick, half after); clears rubble (2 alloy) |
| `c` | decontaminate or dry flood (3 alloy) |
| `x` | purge the tank (free, pays alloy back) |
| `r` | auto-run toggle (5 ticks/s; prefix arg runs 1 tick/s) |
| `.` | re-arm the last successfully armed verb |
| `u` / `ESC` / `C-g` | disarm the armed verb |
| `C-t` | skip the tutorial |
| `L` | full log, oldest first |
| `n` | new game (new sector) |
| `?` | briefing — seed, version, the rules, the power layer |
| `q` | quit |

**Emacs pairings** (the single-key map above is untouched; they bind
additively): `C-n`/`C-p`/`C-f`/`C-b` move the cursor, `C-a`/`C-e` jump
to row start/end, `M-<`/`M->` to map corners, `M-f`/`M-b` scan
structures forward and back, `C-s` walks the cursor to the nearest
free usable fixture, `C-g` cancels. Use an action three times and a
coach hint posts once, in the hint row — once per game, no nagging.

Build two ways. Press a build key, then press `SPC` — the piece
lands at the cursor. Or press the build key and click the map: the
click places the piece and advances one tick. An unarmed click only
moves the cursor; it never ticks the clock. While a verb is armed,
the header carries a badge: `ARMED: PIPE — CLICK PLACES, ESC CANCELS`.

## The story

The sector keeps a record. At the first rendered tick a premise
banner runs across the banner row — what this run is about. The story
moves in three acts: Act I ticks 0–119, Act II 120–239, Act III from
240 on. Scenario hooks open inside their act windows and resolve in
the log: the requirement HELD or BREACHED. A hook still open at an
act rollover force-misses — the clock does not wait. Some premises
amend the goal card: `WATCH ORDER AMENDED — %d SERVED`.

## Rewards

- **Score** — a worker who relieves pays 10. Paid at 2× when the
  bladder was near bursting. Occasional tips: 1 in 8 relieves pays
  2–3×. The popup floats up from the fixture.
- **Goal cards** — a card sets objectives: serve N workers, hold
  bursts under N, keep contamination under a ceiling. Your first
  card arrives at tick one: serve 3, ceiling 5. Meet every goal and
  the sector logs `GOAL MET`, then `MAP COMPLETED` runs across the
  banner row. The map's seed is banked as a trophy.
- **Ceremony** — on completion the plain floor sparkles for a few
  ticks. No modal. Nothing stops. Pipes, walls and plumbing stay
  visible.
- **Milestones** — cumulative relieves unlock announcements in the
  log: BIG CISTERN at 5, FAST FLUSH at 15, SELF-CLEAN at 30,
  AIR FRESHENER at 50, GOLDEN PIPE at 100. Crossing 100 also
  throws a full celebration.
- **Reputation** — +1 per relief, −5 per burst, −2 per leak,
  clamped 0–100. Three tiers: under 40, mid, 70 and up. Future goal
  cards bend with your tier — easier targets or harder ones.
- **XP and clearance** — relieves and survived cycles earn XP;
  CLEARANCE II at 12, CLEARANCE III at 30.

## Reading the screen

- **Line 1** — the strip: `TICK ALLOY POP CONTAM SCORE GOALS REP`.
  CONTAM goes yellow at half the limit, red bold near it. After REP:
  a dim slot for the ARMED and AUTO-RUN badges. The seed lives in
  the `?` briefing.
- **Line 2** — the keys, with prices.
- **Line 3** — the glyph legend, generated from the tile table:
  `· floor  ▓ wall  + gate  ◆ ore vein  ▚ rubble  ░ flood  ╬
  manifold  ? cache  ! event  ╌ dead pipe  ─ pipe  Ω toilet  ▣ tank
  α worker`. A pipe lit bold is connected to capacity or a manifold;
  a grey `╌` is wire to nowhere.
- **The map** — 34 by 16 cells.
- **The banner row** — the premise banner, celebrations, story
  resolutions, and on condemnation the death panel: cause, ticks
  survived, relieves served, final score, `PRESS n TO RESTART`, and
  `L — FULL HISTORY`.
- **The inspector** — one line on whatever the cursor rests on. On a
  worker: bladder, status, then the stat segments — `F%+d G%+d
  N%+d A%+d` and clearance — which drop first if the window is too
  narrow; nothing else moves. On plain floor it gives bearings:
  nearest fixture and nearest tank, cells and direction.
- **The hint row** — refusals and coach hints that name the fix.
  `NO FLOOR THERE — AIM FOR OPEN FLOOR`. One tick, then gone.
- **The pressure line** — how the plumbing feels, faced by state:
  red bold when toilets are backed up or lines severed, yellow at
  `PRESSURE RISING — TANK 85%`, dim at `LINES NOMINAL — THE
  STRUCTURE DOES NOT CARE`.
- **The log tail** — the last three lines that matter. Repeats
  collapse with an ×N count. Bursts and condemnation always make
  the tail.
- **The tutorial line** — three steps over the real map: cursor
  onto a worker, purge a filling tank, watch the alloy land. `C-t`
  skips.

Colors come from your theme: the palette derives itself from the
frame background at startup and re-derives when the theme changes.
Contrast is the machine's problem, not yours.

## The log browser

`L` opens the full uncapped log, oldest first, one line per event,
each prefixed with its tick — `T123`. Walk with `n`/`p` (or the
native `C-n`/`C-p`), search with `/`, rebuild after auto-run has
ticked under you with `g`, `G` jumps to the end. `RET` on a line
with an `AT (x,y)` lands the game cursor on that cell and pops back
to the map. `q` closes.
