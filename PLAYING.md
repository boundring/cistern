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
(α β γ …) mine ore (◆) for alloy. Alloy buys pipes, toilets, tanks.
Their bladders fill as they work — 2% a tick. At 60% a worker walks
to a toilet (Ω) and sits down; entering the tile is sitting down.
A toilet works only when pipe (─) connects it to a tank (▣) with
room left. Each use sends 10 units down the line and takes 2 ticks.

A full tank backs up every toilet it feeds. Backed-up toilets turn
red and refuse customers. Purge the tank with `x`: free, and it
pays — 1 alloy per 3 units of waste.

A worker who cannot reach a working toilet eventually breaches. The
tile turns to contamination (▒), which spreads to adjacent floor,
and nearby workers fall sick. Decontaminate with `c`. At 20
contamination the sector is condemned. Game over.

Every 40 ticks a migrant arrives. Population is load. The cap is 8.

## First shifts

1. Press `SPC` a few times. One toilet is already wired to one tank.
   Put the cursor on a worker (arrow keys) and read the inspector
   line: bladder percent, mood.
2. When the pressure line says the toilets are backed up, cursor to
   the tank (▣) and press `x`. Free toilets. Free alloy.
3. Expand. Lay pipe (`p`) outward, add a toilet (`t`) at the far
   end, add a tank (`K`) when the load grows. The wiring rule: pipe
   connects a toilet to ANY tank with headroom. Short runs win.
4. Contamination (▒) appears — cursor onto it, press `c`.
5. Press `r` to let the sim run itself at 5 ticks a second. `r`
   again takes control back.

The whole game in one sentence: **wire the toilets to the tanks
before the bladders win.** Capacity you did not connect is not
capacity.

## Keys

| Key | Action |
|-----|--------|
| `SPC` / `RET` | advance one tick |
| arrow keys / mouse-1 | move the cursor |
| `t` | build a toilet (10 alloy) |
| `p` | lay pipe (2 alloy) |
| `K` | build a tank (15 alloy) |
| `d` | demolish (3 alloy; full refund same tick, half after) |
| `c` | decontaminate the tile (3 alloy) |
| `x` | purge the tank (free, pays alloy back) |
| `r` | auto-run toggle (5 ticks/s; prefix arg runs 1 tick/s) |
| `u` / `ESC` | disarm the armed build verb |
| `T` | skip the tutorial |
| `L` | full log, oldest first |
| `n` | new game (new sector) |
| `?` | briefing — seed, version, the rules |
| `q` | quit |

Build two ways. Press a build key, then press `SPC` — the piece
lands at the cursor. Or press the build key and click the map: the
click places the piece and advances one tick. An unarmed click only
moves the cursor; it never ticks the clock. While a verb is armed,
the header carries a badge: `ARMED: PIPE — CLICK PLACES, ESC
CANCELS`.

## Rewards

- **Score** — a worker who relieves pays 10. Paid at 2× when the
  bladder was near bursting. Occasional tips: 1 in 8 relieves pays
  2–3×. The popup floats up from the toilet.
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

## Reading the screen

- **Line 1** — the strip: `TICK ALLOY POP CONTAM SCORE GOALS REP`.
  CONTAM goes yellow at half the limit, red bold near it. After REP:
  a dim slot for the ARMED and AUTO-RUN badges. The seed lives in
  the `?` briefing.
- **Line 2** — the keys, with prices.
- **Line 3** — the glyph legend: `· floor  ▓ wall  + gate  ◆ ore
  vein  ╌ dead pipe  ─ pipe  Ω toilet  ▣ tank  ▒ contamination
  α worker`. A pipe lit cyan is connected to capacity; a grey `╌`
  is wire to nowhere.
- **The map** — 34 by 16 cells.
- **The banner row** — celebrations, and on condemnation the death
  panel: cause, ticks survived, relieves served, final score,
  `PRESS n TO RESTART`.
- **The inspector** — one line on whatever the cursor rests on. On
  plain floor it gives bearings: nearest toilet and nearest tank,
  cells and direction.
- **The hint row** — refusals that name the fix. `NO FLOOR THERE —
  AIM FOR OPEN FLOOR`. `NEED 10 ALLOY — PURGE (x) PAYS`. One tick,
  then gone.
- **The pressure line** — how the plumbing feels, faced by state:
  red bold when toilets are backed up or lines severed (`LINES
  SEVERED — REWIRE (p) — TANK AT (x,y)`), yellow at `PRESSURE
  RISING — TANK 85%`, dim at `LINES NOMINAL — THE STRUCTURE DOES
  NOT CARE`.
- **The log tail** — the last three lines that matter. Repeats
  collapse with an ×N count. Bursts and condemnation always make
  the tail. `L` opens the whole log.
- **The tutorial line** — three steps over the real map: cursor
  onto a worker, purge a filling tank, watch the alloy land. `T`
  skips.
