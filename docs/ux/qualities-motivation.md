# UX Qualities — Motivation & Atmosphere lens

Collector drive: live batch driver (`/tmp/cx.el`, smoke.el pattern, seed 42), dumps of first 30
ticks / breach / milestone crossing / purge / tick-300, plus code trace of
`cistern-game.el` rewards-eval and `cistern-view.el`. No code changed.

## 1. The reward engine's biggest prizes are unreachable in real play (CRITICAL)

**State:** `cistern--cmd-set-goal-card` is called from tests and `playtest/smoke.el` only — the
shipped game never issues a goal card. Consequences, verified live: MapCompleted never fires, the
ceremony never runs, no trophy is ever banked, and the reputation→tier→next-card-difficulty loop
(§5) has no next card to feed. PLAYING.md advertises "Goal cards", "MAP COMPLETED", "Reputation —
three tiers shape future goal cards" as things "you'll see"; a real player sees none of them.
**Idea:** issue a starter card in `cistern--new-game` (e.g. serve 3, ceiling 5) — one call, the
whole §1 loop goes live.

## 2. Milestone unlocks announce to nobody

**State:** M8 pushes `(list 'unlock :id unlock)` — an intent with **no `:layer`**. The view's
celebration-overlay reads only `:layer 'banner`; log-tail reads only `:layer 'log`. Verified at the
tick-126 crossing (`big-cistern` at 5 relieves): buffer identical to the tick before, log untouched.
PLAYING.md says "watch the log" — there is nothing to watch. `unlocks` is state the player never
sees from the view (zero references to `cistern-st-unlocks` in view/driver).
**Idea:** emit unlocks as a `:layer 'log` line ("MILESTONE — BIG CISTERN ONLINE") plus one banner
tick; two lines in rewards-eval.

## 3. Score, reputation, goal progress: earned but unrendered

**State:** grep confirms `cistern-view.el`/`cistern.el` reference **none** of score, reputation,
goal card, trophies, or milestone progress. Live drive: score hit 250, rep oscillated, `relieves=12`
at tick 291 — the header shows TICK/ALLOY/POP/CONTAM/SEED only. The player can't see progress
toward the (invisible) milestone ladder, can't see rep before a tier would matter, can't see a goal
card they're supposed to satisfy. Reward *existence* without reward *visibility*.
**Idea:** one header/status extension: `SCORE %d  REP %d  GOALS 1/3 (5 served)` — the inspector
already proves the pattern.

## 4. First 30 ticks: nothing rewards, nothing asks

**State:** dumps at ticks 1/3/10/20/30 are byte-identical except tick number and two workers
shuffling. Log stays "SECTOR-7 ONLINE — KEEP THE WATER MOVING" for 30+ ticks. No popup (first
relieve is ~tick 55), no tutorial line (shipped step table is empty per `cistern--tutorial-steps`),
no goal card, no prompt. The hook a new player gets is a static room and a help key.
**Idea:** ship one 3-step tutorial table (SPC → cursor-on-worker → purge) reusing the existing
predicate mechanism that tests already inject; it's the cheapest possible first-payoff.

## 5. Tutorial scenarios are test fixtures, not teaching

**State:** `cistern-tutorial-scenario-losing`/`-winning` are headless (`tutorial-run-scenario`,
`cistern-run-selftest` only). The losing scenario's excellent lesson line ("UNWIRED TOILET IS
FURNITURE — LAY PIPE TO A TANK") exists only as a log string in a run no player performs. Meanwhile
the on-screen pressure line gives actively wrong advice at exactly the losing moment: after
severing the starter pipe, breach-first dump reads "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE
THE TANKS" — purging cannot fix a severed line; the toilet inspector's "SEVERED: LAY PIPE (p)" copy
is right but only when the cursor is already there.
**Idea:** replay the losing script in-buffer behind a "lose demo" help entry, or make the pressure
line condition on severance ("LINES SEVERED — REWIRE") before the purge advice.

## 6. Ceremony: legible shape, invisible cause

**State** (smoke SCREEN-13 + §4): 64 ttl-6 sparkles + "MAP COMPLETED" banner, decay is the
duration, input stays live — the M9 spec works and the banner is crisp. But a player who never saw
a goal card (finding 1) experiences it as unexplained confetti: no "serve 3 relieves — done"
predecessor, no trophy narration beyond a seed number they can't find on screen (`trophies` is
unrendered). Also sparkles are drawn from only 5 glyph choices across a 33×16 field, so the fill
reads slightly like noise; that's fine once the cause is legible.
**Idea:** before the banner, log each goal as satisfied ("GOAL MET — 3 SERVED") so the ceremony
narrates what was just achieved.

## 7. Stakes legibility: the clock is hidden in a ratio

**State:** header shows `CONTAM 3/20`, help says "at 20 the sector is condemned" — good baseline.
But nothing shows *trend* (contam spreads each tick; the losing demo reaches 4 in 10 ticks) and
reputation loss from bursts is invisible (clamped at 0 in my run — the player is never told bursts
cost them anything). Losing arrives as a log spam loop: four consecutive "SECTOR CONDEMNED — PRESS
n FOR NEW GAME" lines (one per post-over command path), no ceremony-of-failure, no score summary
at the end.
**Idea:** a game-over panel (score, relieves, trophies, ticks) replacing the repeated log line —
the one place a summary earns its space.

## 8. Atmosphere copy: right register, 1/10 the density

**State:** the Nihei voice lands when present — "SECTOR-7 ONLINE — KEEP THE WATER MOVING",
"THE STRUCTURE DOES NOT CARE" (pressure line's idle state is the best line in the game),
"MIGRANT WAITS AT THE GATE". But the full flavored-copy inventory is ~4 strings; everything else
is telemetry ("PIPE PLACED AT (1,1) — 2 ALLOY"). The world is silent exactly when the player is
watching (30 idle ticks, zero lines).
**Idea:** one idle/ambient log line per ~25 ticks drawn from a small table ("SUMP LEVEL RISING.
NO ONE COMMENTS ON IT.") — copy is content, and the domain already owns the log.

## 9. Long-session texture: decay with no texture

**State:** tick-300 dump (291 ticks, 12 relieves, condemned): the screen is the same layout as
tick 1 with more sparkles-as-noise and red glyphs. No escalation, no phase change, no migrant-era
renaming, nothing that says "you are deeper into the structure." The only long-run signal is
contam climbing. Condemnation ends with no recap (finding 7), so a 300-tick run collapses to
"press n".
**Idea:** even one narrative threshold — at pop 6/8 rename the header ("SECTOR-7 — WING B") —
cheap, seeded, and gives the megastructure a sense of extent.

## 10. "One more tick" pull: payoff cadence is ~55 ticks apart

**State:** first reward is the tick-55 `+10` popup; the next is a purge refund; then ~tick 126's
invisible milestone. Between payoffs, SPC produces a one-line header change. The strongest pull
mechanic present is actually the purge ("free, and it PAYS" — inspector repeats it, and alloy
22→35 is a real, visible jump) plus bladder-watching via the inspector. That's a decent core; it
needs the ladder and popups firing more often than once per minute of play.
**Idea:** after finding 1, goal progress in the header gives every tick a direction; until then,
`r` (auto-run) is the only way to reach payoffs without tedium — surface it earlier ("press r —
the sector runs itself" on the tutorial line).

---

### Ranked top 3

1. **#1 Goal cards/ceremony unreachable in shipped play** — the entire designed motivation loop is
   test-only until a card is issued at game start.
2. **#3+#2 Invisibility cluster** — score/rep/goals/unlocks/trophies all exist in state, none in
   the render; ~10 lines in the view fixes all five.
3. **#4 First-30-ticks void** — the shipped predicate table is empty and the screen is inert for
   30+ ticks; the cheapest hook in the repo is shipping one tutorial table and one ambient log line.
