# CISTERN

SECTOR 7 SANITATION DIVISION — EMPLOYEE ONBOARDING DOSSIER 7-C

---

## §1 THE STRUCTURE

You have been assigned to Sector 7: thirty-four by sixteen cells of
corridor, vein and wall inside a megastructure nobody finished and
nobody will. The pipes predate the sector. The walls do not answer
questions. Somewhere far off, water moves through mains no one has
inspected in living memory — it is not your water; your sector is the
part that flushes.

The Structure does not explain itself, and neither does this document. What follows is procedure.

## §2 TERMS OF EMPLOYMENT

1. You run sanitation for one sector. Workers (α β γ …) mine ore (◆)
   for alloy. Alloy buys pipe, fixtures, tanks.
2. Their bladders fill as they work — 2% a tick. At the seek threshold
   a worker walks to a fixture and sits; entering the tile is sitting down.
3. A fixture works only when pipe (─) connects it to a tank (▣) with
   room left — or to a manifold (╬), which needs no tank. Each use sends
   waste down the line and occupies the fixture a few ticks.
4. A full tank backs up every fixture it feeds; backed-up fixtures turn red and
   refuse customers. Purge with `x` — free, and it pays 1 alloy per 3 units of waste.
5. A worker who cannot reach a working fixture eventually breaches: the
   tile turns to contamination (▒), which spreads and sickens nearby
   workers. Decontaminate with `c`. At 20 contamination the sector is
   condemned. This clause is not renegotiated.
6. Every 40 ticks a migrant arrives. Population is load. The cap is 8.

Service is compensated: a relief pays 10 score — twice that when the
bladder was near bursting — and one relieve in eight draws a tip worth 2–3×.

THE STRUCTURE DOES NOT CARE.

## §3 YOUR PREDECESSORS

- Supervisor Renn flourished. Transferred surface-side. The surface is not confirmed.
- Inspector Vall filed every report on time. Filed under F.
- The third one left the lights on. [the lights are load-bearing, unlike the org chart.]

## §4 PERSONNEL DOSSIERS

Every worker rolls four stats at the gate — FLOW, GRIT, NERVE,
ARCHIVE, scores 3 to 18 — and keeps them for life. Cursor onto a worker;
the inspector shows the segments after their status:

- **NERVE** moves the worker's personal seek threshold. The base is
  60%; the range across workers is 50–68%. High NERVE files the
  relief request before the spike.
- **GRIT** sets how long sickness lasts, 18–42 ticks around the 30
  base.
- **FLOW** sets mining pace, 2–6 ore-ticks per alloy around the 3
  base. Sick workers move at half pace.
- **ARCHIVE** backs the institution's checks — certifications and
  story rolls.

Every relief earns XP — a SUITED fixture pays double; each migrant
cycle pays the whole crew 1. At 12 XP: CLEARANCE II; at 30:
CLEARANCE III. A fixture suits a worker when it plays to their
dominant stat; from CLEARANCE II no worker is ever unsuited again.

## §5 REQUISITIONS — THE FIXTURE CATALOG

Five fixture types, one catalog. `T` cycles the armed type — the
header badge names it — then `t` builds at the cursor.

| Type | Cost | Use | Suit | Placement |
|------|------|-----|------|-----------|
| long-drop | 10 | 2 ticks, 10 load | GRIT · FLOW | anywhere |
| fall-shaft | 8 | 2 ticks, 8 load | FLOW · GRIT | not beside another toilet |
| high-cistern | 14 | 1 tick, 10 load | ARCHIVE · NERVE | against a wall |
| archive-stall | 12 | 3 ticks, 12 load | NERVE · ARCHIVE | against a wall |
| hermetic-booth | 20 | 2 ticks, 10 load | NERVE · GRIT | anywhere |

Requisitions may be declined with a named reason; the inspector reports a fixture's type and state.

## §6 TERRAIN AND WILDLIFE

The sector grows its own obstacles:

- **Rubble ▚** — impassable debris; `d` clears it to floor for 2 alloy.
- **Flood ░** — water, not waste; a breach can flood its neighbors. It steals
  ticks, not health, never counts toward contamination; `c` dries (3 alloy).
- **Manifold ╬** — a free pipe anchor: pipe wired to it is live without
  any tank (unlimited headroom, no purge income), never severed.
- **Cache ?** — walk a worker over it: +3 alloy, once, then floor.
- **Event !** — a story marker on open floor, passable, gone in three ticks.

The wildlife is catalogued as follows. Rats gather where pipe has gone dead —
prevention is cheaper than removal.
- **Clog-crabs** — occupy fixtures. Any hit drives one off.
- **Vent-leeches** — attach to workers and must be cut off by hand.
- **Sponge masses** — fauna. Their feeding is logged as natural.
- **Warband goblins** — the inheritors. See §7.
- **Guild goblins** — the Guild of the Open Flange: chartered engineers
  who restore dead pipe for a fixed fee, never valid targets. [they wrote the charter]
- **Fixtures, tanks, structures** — personnel files too: quirks, moods,
  private thoughts. Worker-toilet romances occur, filed as maintenance line-items.

## §7 THE WARBAND SITUATION

Raids happen: the inheritors arrive in the act II and act III windows and hold
the main for roughly forty ticks — gnawing pipe, drawing down tanks, harassment.
Two responses are authorized: `f` arms FOCUS — click a hostile; the crew's
auto-defense targets it first. `H` arms RALLY — click a floor cell; the working
crew walks there. Guild personnel are never valid targets. Ignored plumbing
breeds its own fauna regardless.

## §8 SECTOR RECORDS

The sector keeps a record. A premise banner runs at the first
rendered tick — what this run is about. The story moves in three
acts: Act I ticks 0–119, Act II 120–239, Act III from 240 on. Hooks
open inside their act windows and resolve in the log: the requirement
HELD or BREACHED. A hook still open at a rollover force-misses — the
clock does not wait.

Cumulative relieves unlock milestones: BIG CISTERN at 5, FAST FLUSH
at 15, SELF-CLEAN at 30, AIR FRESHENER at 50, GOLDEN PIPE at 100.
Reputation: +1 per relief, −5 per burst, −2 per leak, clamped 0–100.

THE SECTOR OCCASIONALLY FILES WHIMSEY REPORTS. READ THEM OR DO NOT.

## §9 EMPLOYMENT PROCEDURES

Then `M-x cistern`, or see [PLAYING.md](PLAYING.md) for the full guide.

```sh
git clone https://github.com/boundring/cistern
emacs -Q -l src/cistern.el
```

The story engine loads `cistern-banks-example.el` from beside the
driver (or the load path); without that file the Sector Record stays
silent. The file is your problem. THE STRUCTURE DOES NOT REPLACE IT.

Day one: `SPC` ticks the clock — one fixture is already wired to one tank; cursor
onto a worker and read the inspector. When the pressure line reports a backup,
cursor to the tank, press `x` — free toilets, free alloy. Then expand: pipe (`p`)
outward, a fixture (`t`) far, a tank (`K`) when load grows. Short runs win.

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
| `f` | arm FOCUS — click a hostile; the crew targets it first |
| `H` | arm RALLY — click a floor cell; the crew walks there |
| `L` | full log, oldest first |
| `n` | new game (new sector) |
| `?` | briefing — seed, version, the rules, the power layer |
| `q` | quit |

Build two ways: arm a build key and press `SPC`, or arm and click the map — the
click places and advances one tick; an unarmed click only moves the cursor. Use
an action three times and a coach hint posts once in the hint row — once per game.

**Emacs pairings** (additive; the single-key map is untouched): `C-n`/`C-p`/`C-f`/`C-b` move, `C-a`/`C-e` row start/end, `M-<`/`M->` map corners, `M-f`/`M-b` scan structures, `C-s` walks to the nearest free usable fixture, `C-g` cancels.

`L` opens the full uncapped log, oldest first: `n`/`p` walk, `/` searches,
`g` rebuilds, `RET` on an `AT (x,y)` line lands the cursor there, `q` closes.

## §10 READING THE SCREEN

Line 1 is the strip: `TICK ALLOY POP CONTAM SCORE GOALS REP`. The map
is 34 by 16 cells. The banner row carries the premise, celebrations,
and on condemnation the death panel — cause, ticks survived, relieves
served, final score, `PRESS n TO RESTART`. The inspector reads the
cursor's cell; the stat segments drop first when the line runs long.
The hint row names the fix, one tick. The legend generates itself from the tile
table; the palette derives itself from your theme — contrast is the machine's
problem, not yours.

The whole job in one sentence: **wire the fixtures to the tanks before the
bladders win.** Capacity you did not connect is not capacity.

- [docs/DESIGN-SPEC.md](docs/DESIGN-SPEC.md) — architecture and design spec
- [PLAYING.md](PLAYING.md) — full player guide

v5.0.0-dev · Requires Emacs 27.1+