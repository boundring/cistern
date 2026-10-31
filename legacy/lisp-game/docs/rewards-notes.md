# Cistern Rewards Design — Working Notes

Multi-turn design workstream. Complaints to answer: (1) no demolish tool, (2) always the same map, (3) no reason to care.
Owner directive: players need rewards for their interest — repay them appropriately, for their interest alone if need be.

---

## TURN 1 — Survey of the space

### References gathered (concrete)
1. **Dwarf Fortress tantrum (dwarffortresswiki Tantrum page, fetched).** Stress accumulates from unmet needs; tantruming dwarves destroy buildings, start fights; victims of tantrums gain stress → cascade ("tantrum spiral"). Lesson: *negative* emotion systems are memorable and create stories; a failure spiral is a reward structure in reverse — dread is also a reason to care. Damage-control play (quarantine the stressed dwarf) is emergent gameplay.
2. **RimWorld mood (rimworldwiki Mood page, fetched).** Mood = slow-moving bar chasing an instant "Mood Target" computed from a list of thoughts (+/- stacks). Tiered Mental Break Thresholds (35% minor / 20% major / 5% extreme) → predictable escalation. High mood can trigger *inspirations* (positive breaks). Lesson: (a) separate fast "target" from slow "actual" bar — reads clearly in text UI; (b) tiered thresholds give legible stakes; (c) the mirror system — positive breaks — is the reward-side trick Cistern can steal.
3. **Theme Hospital (Wikipedia, fetched).** Per-level goal cards (money, reputation, cures, hospital value), year-end trophy judging, reputation as a *flow controller* (higher reputation → more patients), VIP inspection visits with cash/reputation bonus, emergencies with time limits, epidemics with cover-up-vs-inspector tension, rat-shooting secret bonus level. Lesson: goals as *level exit criteria* + reputation as a global attractor stat + periodic inspection events = a full reward loop on top of a management sim. Also: hidden silly bonus content (rat level) repays curiosity.
4. **Cities: Skylines (Wikipedia, fetched).** Population-tier milestones unlock building categories; map/land parcels unlock as reward for growth; sandbox mode for players who want no pressure. Lesson: milestones gate *capability* (new tools/buildings), not just numbers — unlocking the demolish/upgrade tool itself can be a milestone, tying complaint (1) directly to complaint (3).
5. **Two Point Hospital Kudosh (Steam discussion + GameSpew guide, search results).** Kudosh = a second currency earned by completing research/objectives, spent on cosmetic/functional item unlocks; player sentiment shows the failure mode: economy tuned wrong → currency too abundant then too scarce → system feels like a tax. Lesson: reward currency economy needs generous starting flow and a spend-sink catalog players *want*.
6. **Hades (Wikipedia, fetched).** Roguelike meta-progression: run-level rewards (obols, lost on death) vs meta-currencies kept between runs; hub world where rewards are spent; narrative progression guaranteed every run ("dialogue advanced each run makes attempts meaningful"); Pact of Punishment = optional difficulty-for-reward dial. Lesson: short-loop failures still pay meta-progress + story every run — the "you always gain something" contract is the anti-"what's the point" fix.
7. **Idle/incremental + variable-ratio design (domain knowledge; live search throttled — retry next turn).** Core patterns: exponential number-go-up curves, prestige loops (reset for multiplier), *variable-ratio* reinforcement (unpredictable reward timing → strongest compulsion loop), countdown timers, and visible progress bars. Lesson for Cistern: tick-based economy is already an idle-game frame; a small chance-based reward (e.g. bonus payment for "zero-accident day") is cheap to build and testable (seeded RNG).
8. **Juice/game-feel (domain knowledge; article fetches 404'd — retry next turn: "Juice it or lose it", Daniel Cook lostgarden).** Juice = redundant multi-channel feedback for every event (motion, particles, flash, sound, scale pop). In a text UI the equivalents are: face flash, glyph change, one-shot overlay effects, message log bursts, screen-wide color tint.

### Candidate mechanisms by timescale (with Emacs feasibility)

#### A. Moment-to-moment juice (per action / per tick)
| Mechanism | What | Emacs feasibility |
|---|---|---|
| A1 Face flash on events | Pipe fix → brief `success` face on the tile; burst/bladder-crisis → `error`/`warning` face pulse | Trivial. Pure face-assignment on redisplay; timer-driven overlay removal. Feasible, cheap. |
| A2 Score/coin popup glyphs | "+5" drifting up from a relieved worker's tile for 2–3 ticks (position shifts 1 cell/tick) | Feasible: it's just a glyph moved each tick; ephemeral entities with TTL. High value — this is THE dopamine primitive. |
| A3 "Dancing pixels" celebration | On milestone/reward: a bounded splash of one-cell `*`, `·`, `§` particles with random walk + decay over N ticks near the event site; or full-buffer confetti rain in a dedicated overlay row | Feasible: deterministic seeded particle field, rendered as glyphs/faces, redisplay per tick. Must be capped (particle count, duration) to stay testable. |
| A4 Worker relief animation | After relief: worker glyph cycles 2–3 animation frames (`p` → `~p~` → `p`), a "much better" message | Feasible: glyph swap per tick. Character animation in text = glyph cycling. High charm-per-effort. |
| A5 Message log flavor | Log lines with faces (`"Bob reaches the toilet just in time. Phew!"`), color-coded severity | Trivial; already a text buffer idiom. |
| A6 Buffer-wide tint on disaster | Contamination event → whole-map face shifts to sickly green for a tick | Feasible; one face remap on render. |
| A7 Sound | Emacs can beep/play but constraint says glyphs+faces only — skip | Out of scope per constraint. |

Ponytail verdict: A1+A2+A5 are near-free and carry most of the juice. A3 is the requested "dancing pixels" and is very doable as a seeded glyph particle system. A4 is charm. A6 nice-to-have.

#### B. Short loop (task → reward → spend)
| Mechanism | What | Emacs feasibility |
|---|---|---|
| B1 Relieve-pay | Worker reaching a toilet on time pays coins scaled by urgency (warning window vs near-burst). Variable-ratio-lite: occasional "tip" on a crit roll | Core sim math; pure domain. Testable: seed RNG, assert payout. |
| B2 Clean bonus | Ticks with zero contamination leak pay a "hygiene stipend"; streak multiplier grows, resets on leak | Pure domain counters. Strong tie to the leak mechanic — makes contamination matter economically. |
| B3 Emergency call | Timed event: X workers must reach a toilet within N ticks for bonus (Theme Hospital emergency analog) | Domain event scheduler + payout; testable. |
| B4 Shop / spend sink | Spend coins on upgrades: pipe capacity, flush speed, repair kit, decorative tile (gives worker mood points) | Needs a catalog + purchase use-case; pure domain. This makes reward *cyclical*, not just accumulating. |
| B5 VIP inspection | Every K ticks an inspector walks the map; bonus based on contamination level + queue times (Theme Hospital VIP) | Pathfinding already exists for workers; testable scoring rule. |
| B6 Demolish as paid action with refund | Demolish tool refunds part of build cost → economy loop closes; salvage of pipe material | Also answers complaint (1) — see below. |

Ponytail verdict: B1 is the spine — it makes the *existing* sim (bladders, paths) the reward source. B2 gives leaks teeth without new art. B4 is required for "care" (spending is caring). B5/B6 second wave.

#### C. Long loop (objectives, unlocks, score, meaning)
| Mechanism | What | Emacs feasibility |
|---|---|---|
| C1 Milestone ladder (Cities: Skylines) | Population/uptime thresholds unlock: tools (upgraded pipes, *demolish pro*), new tile types, new map seeds | Pure domain state machine; trivially testable (threshold crossed → unlock event). |
| C2 Level goal cards (Theme Hospital) | Each map has 2–3 goals (serve N workers, keep contamination < X for M ticks, earn Y) → completing a map unlocks the next + a trophy | Domain: goal evaluator per tick. Maps need to exist → complaint (2). |
| C3 Map seeds / variety | Procedural or hand-authored map generation (seeded); "next level" maps with new layout constraints (e.g. narrow halls, long pipe runs) | Seeded generator = pure function seed→map; ideal for fail-first tests (same seed → same map). |
| C4 Reputation stat | Global 0–100 reputation rises on good outcomes, falls on bursts/leaks; controls difficulty of future events + is the headline score | One number + event wiring; testable. |
| C5 Trophies / achievements | Named achievements with dates ("Golden Plunger: 50 clean relieves in a row"), shown on a trophy screen | Persisted list; trivial domain. Repays interest *literally* — matches owner directive. |
| C6 Meta-currency between maps ("Prestige") | Carried-over currency buys starting perks for next map (Hades-style meta) | Domain persistence; medium effort; maybe later. |
| C7 Narrative flavor | Post-relief flavor lines, worker names, one-liner "letters" from happy workers (Hades: every run advances something) | Pure text tables; cheap charm; strong "why I care" lever — you care about *Bob*, not the bladder stat. |
| C8 Sandbox mode | Unlimited funds, no goals — for the player who just wants to build/demolish | Cheap: a flag that disables goal evaluation. Cities: Skylines precedent. |
| C9 Demolish tool itself | Select tile → remove pipe/toilet, partial refund, small contamination puff if pipe was dirty | Domain + input adapter. Answers complaint 1 directly. |

### Direct complaint mapping (draft)
1. **Demolish** → C9, gated by nothing or by early milestone C1 (Cities: Skylines gates tools; but gating a basic tool risks re-complaint — open question Q2). Refund mechanics (B6) give it economic texture.
2. **Same map** → C3 seeded generation + C2 level ladder; sandbox (C8) for builders.
3. **Why care** → B1/B2 economy + A-juice makes each tick legible and felt; C2/C4/C5 give direction and record; C7 gives the emotional hook. The Hades contract: *every session ends with something* — reputation moved, trophy earned, next map closer.

### Emacs feasibility summary
Everything proposed reduces to: (a) domain state (counters, thresholds, seeds, catalogs) — trivially testable; (b) presentation events (set face on cell, set glyph, append log line, remove after TTL ticks). The "dancing pixels" is a seeded particle list `{pos, vel, ttl, glyph, face}` ticked in the domain (pure) and rendered as glyphs — the only trick is keeping particle state *in the domain layer* so it's testable fail-first, with the buffer as a dumb renderer. Timer/redisplay constraint is satisfied since particles advance per tick (manual or 5 tps auto-run).

---

### What changed in my thinking this turn
- Started assuming rewards = a score number. Reference pass shifted it: the three *distinct* timescales need three distinct systems, and the moment-to-moment layer (popup glyphs, faces) is not decoration — it's the layer that makes the player feel paid per action. Theme Hospital showed goals and juice are one loop (advisor + trophies + rat level); Cities: Skylines showed tools-as-unlocks can *be* the reward, which fuses complaint 1 into complaint 3 instead of treating them separately.
- RimWorld's mood-target/mood-bar split made me want urgency *displayed* as a fast target chasing a slow bar, and its "positive break" (inspiration) suggested a mirrored event: an over-served, happy worker occasionally *works faster* — a positive event players anticipate.
- Hades reframed the "why care" fix as a contract ("every run pays something") rather than a feature list.

### Five biggest open design questions
1. **Should demolish be unlocked or free?** Cities: Skylines gates tools behind milestones (reward texture), but gating a tool a player explicitly demanded risks re-triggering the complaint. Free-but-refunded vs milestone-gated — which serves the reward loop better?
2. **What is Cistern's single headline stat** — coins, reputation, "care score", or worker survival time? Theme Hospital used reputation as flow controller; Cistern has no spawn pressure yet, so what does reputation *do* here?
3. **How variable should rewards be?** Fixed payouts are testable and fair; variable-ratio is more compulsive but needs seeded RNG discipline in tests. How much randomness does a tick-based management sim want before it feels noisy?
4. **Do workers need an inner life (RimWorld-style mood with negative spirals)** or only positive rewards? A tantrum/contamination spiral adds dread and story, but the complaint is "I don't care" — is punishment the right medicine for a player not yet invested?
5. **What does "finish a map" mean in a sim with no win state?** Goal cards → unlock next map requires defining session length and what persists between maps (trophies only? meta-currency? worker roster?).

---

## TURN 2 — Pressure-test and decide

### New references gathered + what each changed
1. **Two Point Hospital Kudosh (two-point-hospital.fandom Kudosh page, fetched).** Specifics: Kudosh is *persistent across all hospitals*; earned from career goals, finishing levels, star ratings, award ceremonies, staff challenges, VIP reports, and research; spent to unlock items — **once unlocked, an item is available in all hospitals**. *Changed:* confirmed the two-currency split (session cash vs persistent unlock currency) and that unlock persistence is what makes long-loop effort feel banked. I was considering dropping the meta-currency (C6) to COULD; now leaning to fold "persistent unlock" into the milestone ladder instead of a second currency — one currency, two ledgers (session coins spend in-map; milestone unlocks persist). Simpler, same psychology.
2. **Cities: Skylines milestone ladder specifics (cheatbook list via search).** Concrete tiers: Little Hamlet (0 pop) → Worthy Village (1,000) unlocks Police, Fire, districts, policies, industry specializations, second loan, land area… Each tier gates a *mix* of capability and services. *Changed:* validated milestone-ladder granularity — unlocks arrive every few hundred "residents"; for Cistern the analog unit should be **relieves served** (the game's core verb) rather than coins, and each tier should unlock exactly 1–2 things, mixing *capability* (tool/upgrade) with *content* (new map feature).
3. **Nethack ascension (nethackwiki Ascension page, fetched).** Victory is a scripted celebration: multi-line ceremony ("An invisible choir sings, and you are bathed in radiance..."), score multiplier (2x for loyal ascension), and conduct tracking (atheist, never-converted) as self-imposed challenge modifiers. *Changed:* (a) terminal games already do "dancing pixels" — NetHack's ascension radiance, DF's announcement flashes — so our glyph-particle celebration has direct precedent; (b) score multipliers/conducts = cheap replay value knobs ("finish the map with zero bursts" = a conduct); (c) the endgame should be a *ceremony*, not just a number.
4. **Dwarf Fortress announcements (DF2014:Announcement page, fetched).** Three severity classes: minor (flicker in feed), major (pause + recenter camera), game-changing (pause + recenter + framed box + repeated in feed). Player-configurable via announcements.txt. *Changed:* our message log needs exactly this **three-tier severity** — minor (faced line), major (log + brief screen flash/focus), game-changing (milestone: pause auto-run, centered banner). Severity classes make the same event feel weighted without extra art, and they map 1:1 to faces + a banner overlay.
5. **Theme Hospital level goals (turn-1 Wikipedia fetch re-read, goal-list search failed).** Goal-card structure confirmed: per-level winning conditions across 4 axes (money, reputation, cures, hospital value) + losing conditions; CorsixTH wiki page 404'd but Wikipedia already grounds the structure. *Changed:* Cistern goal cards should use exactly 3 axes max — relieves served, bursts allowed (inverted = conduct), contamination kept under X — one card per map, 2–3 goals each. Don't replicate 4 axes; we have no economy of rooms to track hospital value.
6. **Juice references (retried; still 404/throttled for "Juice it or lose it" writeups).** Falling back on the DF/NetHack terminal precedents above, which are actually *more* relevant than AAA particle talk since they prove juice-in-text works. No further change.

### Decisions (resolving the five open questions)
1. **Demolish: FREE FROM THE START, with reward texture.** Refund partial build cost, dust/debris particle puff on demolish, faced log line. Rationale: a demanded tool behind a gate re-triggers the complaint; refunds + juice give it reward texture without a gate. Unlocks stay for *upgrades*, never for the basic verb set (build/demolish).
2. **Headline stat: REPUTATION (0–100), shown in the status bar next to coins.** Reputation rises on clean relieves, goal progress, VIP visits; falls on bursts and leaks. What it *does*: it is the map-exit score (each map card has a reputation goal) AND it feeds the next map's starting conditions. Coins are the short-loop currency; reputation is the long-loop headline. Rationale: Theme Hospital precedent — one stat that expresses "how good is this place" beats coins (which only measure accumulation) or survival (which punishes building since more workers = more burst risk).
3. **Payouts: SEEDED VARIABLE-RATIO where random, fixed elsewhere.** Every payout function takes the game seed → deterministic payout sequence. Tip chance on relief, milestone confetti, event scheduling: all seeded. Rationale: fail-first testability demands seed→determinism; variable-ratio needs randomness; seeded RNG satisfies both. Pure-RNG (time-seeded) is banned in the domain layer.
4. **Worker inner life: POSITIVE REWARDS ONLY (for now).** No mood system, no tantrum spiral. Rationale: dread needs investment — a player who doesn't care yet experiences negative spirals as noise, not story. DF/RL's spiral works because you already love the fort. The existing bladder/burst mechanic IS the negative pressure; adding mood doubles the stick with no carrot. Revisit negative spirals once players are invested (post-milestone-ladder). RimWorld's *positive* break (inspiration) IS worth stealing: an over-served worker occasionally works faster — one seeded event, one test.
5. **Finish a map: goal card → completion ceremony → next map unlocks; SESSION = one map.** A map ends when its 2–3 goals are all met (player then chooses: continue on same map in sandbox-lean mode, or travel to next map). Persists across maps: reputation floor/trend, completed-map trophies, unlocked upgrades (Kudosh-model: unlocked-once, available-everywhere), seed library visited. Does NOT persist: coins, pipes, workers. Rationale: Hades contract — each session ends with something; Theme Hospital level exit; Two Point persistence model. Worker roster could persist later (COULD).

### Priority table

#### MUST (answers all three complaints + first-class celebration)

| # | Mechanism | Fail-first acceptance criterion | Layer | Emacs feasibility |
|---|---|---|---|---|
| M1 | **Demolish tool** — click pipe/toilet → removed, partial refund | Failing test first: demolishing a pipe worth 10 with 50% refund on a 100-coin balance leaves 105; tile empty; adjacent contamination puff if pipe was dirty. Refuses on empty tile (error, no state change) | Domain (removal, refund, contamination); adapter (mouse→command mapping) | Trivial — existing tile model, one new use-case |
| M2 | **Seeded map generation** — seed → map | Same seed twice → identical maps (property test); different seeds → different pipe-start/room layouts (statistical test over N seeds); generated map is always solvable (path from every worker start to a toilet exists) | Domain (pure generator) | Text grid generation — fully feasible, no graphics dependency |
| M3 | **Goal cards per map** — 2–3 goals (relieves served N, bursts ≤ B, contamination < X for T ticks) | Failing test first: satisfying all goals on ticks emits MapCompleted; missing one does not; goals checked every tick | Domain (goal evaluator) | Status-bar display of goal progress = formatted text |
| M4 | **Reputation stat** — rises/falls on events, displayed | Failing test first: clean relieve +1, burst −5, leak −2, clamped 0–100; next map's card consumes current reputation | Domain | One number in status line |
| M5 | **Relieve-pay + popup glyph** — coins on timely relief, "+N" glyph drifts | Failing test first: relief within warning window pays base, near-burst pays 2x; popup entity spawned with ttl=3, position ticks up 1/tick, removed at ttl 0 | Domain (payout + ephemeral popup list); adapter (render popup glyphs) | Glyph + face per popup cell; cheap |
| M6 | **Dancing-pixels celebration** — domain-owned particle field | Failing test first: milestone reached spawns K seeded particles {pos,vel,ttl,glyph,face}; particles tick (move, decay) deterministically from seed; all dead after max-TTL ticks; buffer renderer draws only live particles | Domain (particle list, seeded); adapter (dumb renderer) | Feasible per turn 1; cap K and TTL for testability |
| M7 | **Face flash + three-tier log** — events emit faced log lines at minor/major/game-changing severity | Failing test first: relief→minor line; burst→major line + error face on tile; MapCompleted→game-changing banner; banner clears after N ticks | Domain (event→severity mapping); adapter (faces, banner overlay) | Pure faces + text; DF announcement model |
| M8 | **Milestone ladder** — relieves-served thresholds unlock upgrades (flush speed, bigger cistern, decor) | Failing test first: threshold crossed exactly once → UnlockEmitted; unlocked upgrade purchasable in shop; persisted across maps | Domain | Text status line + shop list |
| M9 | **Map completion ceremony** — radiance-style endgame | Failing test first: MapCompleted triggers ceremony state: particle field + centered multi-line banner + trophy persisted; auto-run pauses | Domain (ceremony state, trophy record); adapter | NetHack ascension precedent — multi-line centered text + M6 particles |

#### SHOULD

| # | Mechanism | Fail-first acceptance criterion | Layer | Emacs feasibility |
|---|---|---|---|---|
| S1 | Clean-streak stipend (zero-leak ticks pay escalating bonus, resets on leak) | Streak counter increments per clean tick, pays at 10/25/50, resets on leak event | Domain | Status-line indicator |
| S2 | Shop / spend sink (upgrades from M8 purchasable, decor tiles grant small reputation) | Buying deducts coins, applies effect, rejects insufficient funds without state change | Domain | List menu buffer |
| S3 | Worker relief glyph animation (p→~p~→p over 2 ticks) | Frame advances per tick after relief event, ends at frame 0 | Domain (anim state); adapter | Glyph cycling |
| S4 | Timed emergency event (N workers must relieve within M ticks for bonus) | Seeded scheduler emits event; success/failure branches pay/penalize reputation | Domain | Warning banner (major severity) |
| S5 | VIP inspection every K ticks (scores contamination + queue times → reputation + coins) | Seeded arrival; score formula deterministic given map state | Domain | Walks existing paths; faced log lines |
| S6 | Worker names + flavor lines (positive-break inspiration: over-served worker works faster, seeded) | Seeded inspiration event ≤1 per 100 ticks when worker satisfied; speed effect applies/expires | Domain | Log lines; names in glyphs/tooltips |
| S7 | Sandbox mode (no goals, unlimited coins) | Goal evaluator disabled, coins pinned — flag flips behavior | Domain | One toggle |

#### COULD

| # | Mechanism | Note | Layer | Emacs feasibility |
|---|---|---|---|---|
| C1 | Buffer-wide tint on disaster | Face remap on render for 1 tick after major event | Adapter-side mostly | Cheap but lowest value |
| C2 | Persistent worker roster between maps | Hades-ish attachment; needs save format work | Domain + persistence | Feasible, defer |
| C3 | Conducts / self-imposed challenges ("zero bursts" → 2x reputation on ceremony) | NetHack precedent; free replay value | Domain (flag + multiplier) | Trivial, defer until goals exist |
| C4 | Meta-currency separate from coins | Rejected for now — one currency, two ledgers (see decision 1 note) | — | — |

Coverage check: complaints — demolish (M1), map variety (M2+M3), reason to care (M4–M9 loop: pay → see it → spend → unlock → finish map → ceremony → next map).

### What changed in my thinking this turn
- Collapsed two currencies into one: session coins + persistent milestone unlocks (Kudosh/Two Point evidence showed the *persistence* is the psychological point, not the second currency).
- Payout randomness resolved cleanly: "seeded variable-ratio" — the fail-first constraint and the compulsion-loop desire are compatible via seeded determinism; time-seeded RNG is banned in the domain.
- Cut worker mood/negative spirals entirely for v1 — existing bladder pressure is the stick; DF spiral requires player investment we don't have yet.
- Added the ceremony (NetHack ascension) as a first-class MUST — map completion is the emotional payoff and needs its own behavior, not just a log line.
- Stole DF's three-tier announcement severity as the universal presentation grammar for all reward events (minor/major/game-changing) — one system, applied everywhere.

### Remaining open questions
1. **Milestone ladder tuning**: what are the actual relieves-served thresholds and the unlock list order? (Needs the shop catalog fixed before thresholds can be priced.)
2. **Map generator scope**: hand-authored seed library vs fully procedural? Solvability test says procedural-with-validation, but how much layout *variety* (obstacles, one-way halls, split floors) does the tile model support?
3. **Reputation's effect on the NEXT map**: start with higher reputation → harder goals? Higher worker count? Needs a concrete "reputation pays forward" rule or it's just a score.
4. **Popup/particle collision**: when popup glyphs and particles land on map cells with real content, do they overwrite (transient overlay) or coexist (second line per cell)? Affects renderer design.
5. **Ceremony length and interruptibility**: how many ticks does the celebration run in auto-run mode, and can the player skip it — does skipping forfeit the particles' remaining tick state (test implications)?

---

## TURN 3 — Dancing-pixels deep-dive + closing the questions

### New references gathered + what each changed
1. **Brogue (brogue.fandom, home + Level Generation pages, fetched).** The gold-standard text-mode juice game: unicode glyphs, mouse OR keyboard play (validates our input constraint — Brogue is fully mouse-playable with click-to-move!), and crucially its **Level Generation** page documents exactly the architecture I need: seeded generation with *validation steps inside the loop* — lake blobs placed via cellular automata (B5678/S45678) with placement retries and a "blocks passability → try again, give up after 10 tries" rule; connectivity explicitly checked so traps/lakes never strand the player; "burning down bridges will never strand you" as a design invariant. Also: Sunday Seed contests — the entire dungeon is identical for everyone from one seed, which is the community proof that same-seed→same-map is both desirable and achievable. *Changed:* the map generator spec (M2) now explicitly adopts Brogue's generate→validate→retry-with-bound loop, and same-seed-identical maps become a community feature, not just a test convenience.
2. **Near-miss effect in slot machines (Springer, J Gambling Studies 2019 review — search hit).** Reviews the Skinner-originated finding that near-miss events (loss that looks almost-like-a-win) reinforce continued play. *Changed:* adds a caution flag, not a feature: Cistern's variable-ratio tips must avoid near-miss theater (no "almost got a tip!" fakeouts) — we reward genuine outcomes only; the variable element is *amount/chance of bonus*, never simulated disappointment. One-line design rule: **no fake wins.**
3. **Reinforcement schedules (Grokipedia Reinforcement + slot-design search results).** Variable-ratio VR schedules produce the highest, most pause-resistant response rates (classic VR range in the literature runs VR-5 to VR-400; slot hit frequencies are tuned to roughly 1-in-5 to 1-in-3 spins for low volatility). *Changed:* pins our tip schedule — relief bonuses should hit on roughly **VR-8** (12.5% of timely relieves tip, amount 2–3x base) — frequent enough to stay legible in a slow tick sim, sparse enough to spike. Priced in ticks: at 1 tick/action, a player relieving a worker every ~15 ticks sees a tip roughly every 2 minutes of auto-run. DEFERRED: exact VR curve tuning to implementation with a seeded fixture.
4. **ADOM design blog (search hit, ancientdomainsofmystery.com).** Kiesenhofer-era note: "Roguelikes are tough enough — being able to beat the game shouldn't (entirely) rest on the whim of the RNG." *Changed:* reinforces decision 3 — variance lives in *rewards*, not in *outcomes*; success/failure of core sim actions (relief, pathing) must stay deterministic given inputs. Confirms the split: deterministic gameplay + seeded-random garnish.
5. **NetHack/DF (turn 2) reused** for the celebration grammar — no further fetch needed; they remain the closest terminal-juice precedents.

### Decisions (closing the five remaining questions)
1. **Milestone ladder shape (pricing DEFERRED).** Upgrade catalog (start): `big-cistern` (toilets hold more), `fast-flush` (shorter occupancy), `self-clean` (pipe decay +), `air-freshener` (decor: +reputation aura), `golden-pipe` (pure prestige decor). Ladder over relieves-served (cumulative, per-run persists in-run only):
   - 5 relieves → `big-cistern` unlocked
   - 15 relieves → `fast-flush` unlocked
   - 30 relieves → `self-clean` unlocked + first *map completion* typically possible
   - 50 relieves → `air-freshener` unlocked
   - 100 relieves → `golden-pipe` unlocked + "Dancing Pixels" full-buffer celebration
   Rationale: two capability unlocks early (they change play), one mid, two decor late (they reward ongoing play) — mirrors Cities: Skylines capability-then-fluff cadence.
2. **Map generator scope: seeded-procedural WITH solvability validation.** Generate → validate (every worker start reaches a toilet via existing pathing; pipe network can be completed) → retry with bound (Brogue precedent); seed-library alternative DEFERRED. Matches ≥3-distinct-signatures acceptance.
3. **Reputation pay-forward: reputation TIER sets the next map's goal-card difficulty.** Tier 1 (0–39): goals −25%; Tier 2 (40–69): standard; Tier 3 (70–100): goals +25% and bonus trophy line. One sentence rationale: same stat feeds both score and difficulty curve — no second mechanism needed.
4. **Popup/particle vs map cells: transient overlay layer.** Particles/popups never occupy cells; rendered *after* the map, conceptually "on top" (in a buffer: overwrite the cell's glyph during that frame's render, restore from map state next frame — the map's own state is never touched). Rationale: renderer stays dumb; domain map state stays pure.
5. **Ceremony: 6 auto-run ticks, skippable with any key, no forfeit.** Rationale: skippable > interruptible; nothing is lost by skipping because the trophy/record was committed at ceremony START (commit-first, celebrate-after — also makes the test trivial: MapCompleted ⇒ trophy exists in state *before* ceremony ticks).

### DEEP-DIVE: Dancing pixels as a testable domain system

#### Data shape (domain-owned, seeded, pure)
```
Particle = {
  pos:        {x, y}          // integer map coords
  vel:        {dx, dy}        // integer or fixed-point, -1/0/+1 per advance
  ttl:        int             // ticks remaining; removed when 0
  glyph:      enum            // from palette below
  face:       enum            // from palette below
  layer:      enum {sparkle, popup, banner}  // render ordering + collision rule
}
ParticleField = { particles: [Particle], rng: seeded-RNG-stream, cap: 64 }
```
The field lives in domain state alongside the sim. It has its own RNG stream **derived from the game seed** (child-stream, e.g. seed ⊕ stream-id) so sim outcomes and particle outcomes never consume each other's randomness.

#### Spawn triggers and intensities
| Trigger | Source MUST | Particles | TTL | Glyphs | Notes |
|---|---|---|---|---|---|
| Tip / relief pay popup | M5 | 1 popup particle "+N" | 3 ticks | digits `1-9`,`+` | `layer:popup`, drifts up 1/tick (vel 0,-1) |
| Demolish dust | M1 | 3–5 | 2–3 ticks | `·`, `.` | `layer:sparkle`, random short vel, gray face |
| Milestone / big tip | M8 | 8–12 | 3–5 ticks | `*`, `·`, `§` | `layer:sparkle`, burst from event tile |
| Map-completion ceremony | M9 | cap 64 (K=64) | 6 ticks (bounded by ceremony) | `*`, `!`, `·`, `§`, digits | `layer:sparkle` + centered banner (`layer:banner`) |
Caps: **K = 64 particles total** (oldest evicted FIFO when exceeded — evictions are deterministic), per-spawn counts above, max TTL 6.

#### Glyph palette (unicode, single-cell, emacs-safe)
`·` `*` `§` `!` `.` `+` digits `0-9`. Face palette: `success` (green), `warning` (amber), `error` (red), `info` (default), `bonus` (magenta/yellow). All are standard face names remapped in the presentation layer; the domain stores enum names, the adapter maps enum→face — domain never imports emacs types.

#### Update semantics — paused vs auto-run (the key decision)
**An explicit `advance-particles` use-case is called by the presentation layer's redisplay timer (the same 5 tps timer that drives auto-run ticks, and an idle-timeout variant when sim is paused).** Consequences:
- When auto-running: per display frame, the timer calls `advance-sim` (1 tick) then `advance-particles` (1 advance). Particle time == sim time.
- When paused (or during pre-game, or mid-ceremony if we later decouple): the timer calls ONLY `advance-particles`. Celebrations finish animating even though the sim is frozen — the "dancing" must never appear stuck, that's the whole point of juice.
- Determinism: `advance-particles` advances every particle one step deterministically from the seeded stream (pos += vel, ttl -= 1, eviction, removal at ttl=0). Two fields with the same seed and the same advance count are identical.
- Frame-rate independence: because advances are tick-counted, not wall-clock, tests assert on advance counts; the timer only decides *when* to advance, never *what* happens.

#### Interaction with buffer resize / header
Particles store map coords; the renderer clips to the current visible map window each frame (out-of-view particles keep ticking, cost nothing). On resize, no particle state changes — only the clip window. Header/status line is drawn last; `layer:banner` particles render into a reserved row (the DF "game-changing announcement" row), never into the header itself.

#### Failure modes (each with a designed answer)
1. Particle storm (many celebrations back-to-back) → FIFO eviction at K=64; eviction order is part of the spec and tested.
2. Seed exhaustion / RNG stream misuse → single child-stream per field; tests pin the first 100 stream values as a fixture so a stream change fails loudly.
3. Renderer bug shows stale particles over changed map → particles are re-read from domain state on every render; nothing cached in the buffer.
4. Sim restart/new map mid-celebration → `reset-particles` use-case; ceremony commits trophy first so a skip/reset loses nothing.
5. Negative ttl / runaway vel from a bug → invariant checks in the advance use-case (ttl ≥ 0, |vel| ≤ 1); violations raise a domain error (fail-first, not silently corrupt).

#### Fail-first test criteria
1. `given seed S and trigger T, the particle field after N advances equals the expected fixture` — golden-fixture equality on the full particle list (pos, vel, ttl, glyph, face) at N = 0, 1, 3, 6.
2. Same seed twice → identical field; different seeds → different field (statistical over 20 seeds).
3. TTL expiry: every particle removed by ttl=6; field empty after max-TTL + 1 advances.
4. Cap: spawning beyond 64 evicts oldest FIFO, deterministic under seed.
5. Advance-when-paused: calling `advance-particles` without `advance-sim` still animates field (ttl decreases, positions move) and never advances sim counters (coins, reputation unchanged).
6. Renderer purity: render(field, map, viewport) is a pure function of arguments — same inputs, same buffer output; particles never mutate map state.
7. Ceremony commit-first: MapCompleted ⇒ trophy persisted even if zero ceremony ticks advance.

### What changed in my thinking this turn
- Brogue's Level Generation page converted the map generator from "seeded generator + validation" (vague) to **generate→validate→retry-with-bound as the generator's own loop** — validation is inside generation, not a filter afterward. Also its Sunday Seed contests upgraded same-seed-identical from test convenience to a player-facing feature.
- The near-miss literature added a constraint I hadn't considered: variable-ratio must reward genuine outcomes only — no fake disappointments. Small rule, but it bounds what "juice" is allowed to lie about.
- Resolved the paused-vs-running animation tension by splitting particle time from sim time architecturally: one use-case, called by whichever timer is live. I had implicitly assumed particles tick with the sim; that would make celebrations freeze when the sim pauses — exactly wrong for juice.
- Commit-first ceremony (trophy at start, celebration after) fell out of the skip question: state changes belong in state machine order, celebration is pure presentation-side animation — the domain error of "did the player see it?" is unanswerable, so we don't ask it.

### Still open
1. Exact upgrade pricing + goal-card difficulty values (DEFERRED to implementation with seeded fixtures, per decisions).
2. Whether the idle-timer variant for `advance-particles` (paused animation) needs a debounce or runs a bare 5 tps always — presentation-layer decision, affects battery/CPU, not design.
3. Ceremony banner text content (flavor lines) — needs a small copy pass; mechanically specified (6 ticks, commit-first, skippable).
4. VR-8 tip schedule tuning (fixture exists; curve may move after playtest).
5. Map variety beyond layout: does a "theme" modifier (e.g., tight corridors map, wet map with faster contamination spread) ride on the seed or on a separate level parameter? Lean: level parameter (deterministic, testable), seed varies layout within the theme.
