# PLAYING CISTERN

A toilet-sanitation management sim in an Emacs buffer.

## Run it

```
emacs -Q -l /path/to/cistern/src/cistern.el
M-x cistern
```

That's it — the game opens in the `*cistern*` buffer.

## The idea

You run the sanitation for Sector 7. Workers (α β γ …) mine ore (◆)
for alloy — your building currency. Their bladders fill as they work;
at 60% they walk to a toilet (Ω) and sit down. But a toilet only
works when it's wired by pipe (─) to a tank (▣) with room left. Every
use sends 10 units of waste down the line into the tank.

A full tank backs up every toilet it feeds — those toilets go red and
out of service. Purge the tank (free, and it PAYS: 1 alloy per 3
units of waste).

A worker who can't reach a working toilet eventually breaches: the
tile turns to contamination (▒), which spreads to neighboring floor
and makes nearby workers sick. Decontaminate with `c`. At 20
contamination the sector is condemned — game over.

Every 40 ticks a migrant arrives. More workers, more load.

## What to try first

1. Watch the starter setup: there is one toilet already wired to one
   tank. Press `SPC` a few times and find the workers on the map —
   the inspector line describes whatever the cursor rests on, so put
   the cursor on a worker (arrows) and watch their bladder %.
2. When the pressure line says the toilet is backed up, put the
   cursor on the tank (▣) and press `x` to purge it — free toilets
   and free alloy.
3. Expand: lay pipe (`p`) from the wired run outward, add another
   toilet (`t`) at the far end, and a tank (`K`) when the load gets
   heavy. The wiring rule: a toilet works if pipe connects it to ANY
   tank with headroom — short runs are cheap runs.
4. When contamination (▒) appears, cursor onto it and press `c`.
5. Press `r` to let the sim run by itself at 5 ticks/second — press
   `r` again to take back control.

The one lesson of the tutorial scenarios, in a sentence: **wire the
toilets to the tanks before the bladders win.** Capacity that isn't
connected is as useless as no capacity at all.

## Keys

| Key | Action |
|-----|--------|
| `SPC` / `RET` | advance one tick |
| arrow keys / mouse-1 | move the cursor |
| `t` | build a toilet (10 alloy) at the cursor |
| `p` | lay pipe (2 alloy) at the cursor |
| `K` | build a tank (15 alloy) at the cursor |
| `d` | demolish the structure at the cursor (3 alloy, half refunded) |
| `c` | decontaminate the tile at the cursor (3 alloy) |
| `x` | purge the tank at the cursor (free, pays alloy back) |
| `r` | auto-run toggle (5 ticks/second) |
| `T` | skip the tutorial |
| `n` | new game (new sector) |
| `?` | in-game briefing |
| `q` | quit |

Tip: build with the keyboard, or press a build key once and then
click anywhere on the map — the click places it there and advances
one tick. The cursor-movement click (no build key pressed) never
ticks the clock.

## Rewards you'll see

- **Score popups** — a worker who relieves with a full bladder pays
  you: `+10` floats up from the toilet (2× near bursting, occasional
  2–3× tips).
- **Goal cards** — a card sets objectives (serve N workers, keep
  contamination under a ceiling, survive N bursts). Complete all
  goals and the sector celebrates.
- **MAP COMPLETED** — the big one: a banner row appears under the map
  and the whole field fills with ceremony sparkles for a few ticks.
  The sector's seed is banked as a trophy.
- **Milestones** — cumulative relieves unlock achievements (watch the
  log); cross 100 lifetime relieves for a full celebration.
- **Reputation** — rises with relieves, sinks with bursts and leaks;
  three tiers shape future goal cards (easier or harder targets).

## Reading the screen

Line 1: sector status — tick, alloy, population, contamination, seed.
Line 2: the keys, with prices. Line 3: the glyph legend. The map.
Then the banner row (celebrations), the inspector (what the cursor
rests on), the pressure line (how the plumbing feels), and the log.
