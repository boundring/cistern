# Cistern Rewards Design — Deliverable

Source notes: `rewards-notes.md` (turns 1–3). Consumed by the Clean Architecture rewrite. Decisions with one-line rationales; no essays.

---

## 1. Design brief

**The three player complaints, answered:**

| Complaint | Answer |
|---|---|
| "Why can't I demolish stuff?" | M1: demolish tool free from the start, partial refund, dust particles, faced log line. Gating a demanded tool re-triggers the complaint; unlocks are for *upgrades*, never the basic verb set. |
| "Why is it always the same map?" | M2: seeded-procedural map generation with solvability validation inside the generation loop. Same seed → identical map (also a player-facing feature, Brogue Sunday-Seed style). |
| "What's the point? Make me care." | M4–M9: the reward loop below. Reputation as headline stat, goal cards per map, milestone unlocks, completion ceremony, trophies. Every session ends with something gained (Hades contract). |

**The core loop:** pay (relieve-pay, streaks, tips) → see (popup glyphs, face flashes, faced log) → spend (shop sink) → unlock (milestone ladder) → finish (goal card) → ceremony (commit-first celebration) → next map (reputation tier sets difficulty).

**One currency, two ledgers.** Session coins (earned in-map, spent in-map shop, reset between maps) and persistent records (reputation, unlocked upgrades — unlock-once-available-everywhere, trophies, visited seeds). The persistence is the psychology, not a second currency (Kudosh/Two Point evidence).

**No-fake-wins rule.** Variable-ratio rewards genuine outcomes only — variance lives in the *amount/chance of bonus*, never in simulated disappointment or near-miss theater. Core sim outcomes (relief success, pathing) stay deterministic given inputs; seeded randomness is reward garnish only (ADOM: "beating the game shouldn't rest on the whim of the RNG").

**Worker inner life: positive rewards only (v1).** No mood system, no tantrum spiral — dread needs player investment that doesn't exist yet; the existing bladder/burst mechanic is the stick. Revisit negative spirals post-milestone-ladder.

---

## 2. MUST (answers all three complaints; M6 is first-class)

| # | Mechanic | Acceptance criterion (fail-first phrasing) | Layer | Emacs feasibility |
|---|---|---|---|---|
| M1 | **Demolish tool** — remove pipe/toilet, partial refund | Demolishing a pipe worth 10 with 50% refund on 100 coins leaves 105; tile empty; adjacent contamination puff if pipe was dirty. Refuses on empty tile (error, no state change) | Domain (removal/refund/contamination); use-case; adapter (mouse→command) | Trivial — existing tile model, one new use-case |
| M2 | **Seeded map generation** — seed → map, validated | Same seed twice → identical maps (property test). Different seeds → ≥3 distinct layout signatures over N seeds. Every generated map solvable: worker starts reach a toilet, network completable — validation retries *inside* generation, bounded (Brogue pattern) | Domain (pure generator) | Text-grid generation, no graphics dependency |
| M3 | **Goal cards per map** — 2–3 goals | Satisfying all goals on a tick emits MapCompleted; missing one does not; goals re-checked every tick | Domain (goal evaluator) | Status-bar progress = formatted text |
| M4 | **Reputation** — 0–100, headline stat | Clean relieve +1, burst −5, leak −2, clamped 0–100; next map's card consumes current reputation | Domain | One number in status line |
| M5 | **Relieve-pay + popup** — coins on timely relief | Relief within warning window pays base, near-burst pays 2x; popup entity ttl=3, drifts up 1/tick, removed at ttl 0; occasional tip VR-8 (seeded) | Domain (payout, popup list); adapter (render glyphs) | Glyph + face per popup cell; cheap |
| M6 | **Dancing-pixels celebration** — domain-owned particle field | See §4 for full spec and seven test criteria | Domain (field, seeded); adapter (dumb renderer) | Seeded glyph particles per tick — fully feasible |
| M7 | **Face flash + three-tier log** | Relief→minor faced line; burst→major line + error face on tile; MapCompleted→game-changing banner, cleared after N ticks | Domain (event→severity mapping); adapter (faces, banner row) | Pure faces + text (DF announcement model) |
| M8 | **Milestone ladder** — relieves-served thresholds unlock upgrades | Threshold crossed exactly once → UnlockEmitted; unlocked upgrade purchasable; unlocks persist across maps | Domain | Status line + shop list |
| M9 | **Map-completion ceremony** | MapCompleted ⇒ trophy persisted *before* any ceremony tick (commit-first); ceremony state: particle field + centered multi-line banner; auto-run pauses; 6 ticks, skippable with any key, no forfeit | Domain (ceremony state, trophy record); adapter | NetHack ascension precedent: centered text + M6 particles |

Milestone ladder thresholds: 5 relieves → `big-cistern`; 15 → `fast-flush`; 30 → `self-clean`; 50 → `air-freshener`; 100 → `golden-pipe` + full-buffer celebration. Capability early, decor late (Cities: Skylines cadence). Pricing DEFERRED.

---

## 3. SHOULD and COULD

### SHOULD

| # | Mechanic | Acceptance criterion (fail-first phrasing) | Layer | Feasibility |
|---|---|---|---|---|
| S1 | Clean-streak stipend (zero-leak ticks escalate, reset on leak) | Streak increments per clean tick; pays at 10/25/50; resets on leak | Domain | Status indicator |
| S2 | Shop / spend sink | Buy deducts coins, applies effect; insufficient funds → error, no state change | Domain | List menu buffer |
| S3 | Relief glyph animation (p→~p~→p) | Frame advances per tick after relief; ends at frame 0 | Domain (anim state); adapter | Glyph cycling |
| S4 | Timed emergency event | Seeded scheduler emits; success/failure branches pay/penalize reputation | Domain | Major-severity warning banner |
| S5 | VIP inspection every K ticks | Seeded arrival; deterministic score from map state → reputation + coins | Domain | Walks existing paths |
| S6 | Worker names + inspiration (positive break, seeded) | Inspiration ≤1/100 ticks when worker satisfied; speed effect applies/expires | Domain | Log lines, names in tooltips |
| S7 | Sandbox mode | Goal evaluator disabled, coins pinned — flag flips behavior | Domain | One toggle |

### COULD

| # | Mechanic | Acceptance criterion | Layer | Feasibility |
|---|---|---|---|---|
| C1 | Buffer-wide disaster tint | Face remap for 1 tick after major event | Adapter | Cheap, lowest value |
| C2 | Persistent worker roster between maps | Roster survives map transition in save | Domain + persistence | Feasible, defer |
| C3 | Conducts ("zero bursts" → 2x reputation) | Conduct flag tracked; multiplier applied at ceremony | Domain | Trivial once goals exist |
| C4 | Separate meta-currency | **Rejected** — one currency, two ledgers (§1) | — | — |

---

## 4. Dancing-pixels spec (M6)

**Data shape (domain-owned, seeded, pure):**

```
Particle = {
  pos:   {x, y}                    // integer map coords
  vel:   {dx, dy}                  // integer, -1/0/+1 per advance
  ttl:   int                       // ticks remaining; removed at 0
  glyph: enum                      // palette below
  face:  enum                      // palette below
  layer: enum {sparkle, popup, banner}  // render ordering
}
ParticleField = { particles: [Particle], rng: child-stream, cap: 64 }
```

The field lives in domain state beside the sim. Its RNG stream is **derived from the game seed** (seed ⊕ stream-id) so sim outcomes and particle outcomes never consume each other's randomness. First 100 stream values pinned as a fixture.

**Caps:** K = 64 particles total; per-spawn counts per table below; max TTL 6. Overflow evicts oldest FIFO — eviction order is part of the spec and tested.

**Trigger table:**

| Trigger | Source | Particles | TTL | Glyphs | Notes |
|---|---|---|---|---|---|
| Relief pay popup | M5 | 1 `popup` "+N" | 3 | digits, `+` | vel (0,−1), drifts up |
| Demolish dust | M1 | 3–5 `sparkle` | 2–3 | `·` `.` | gray face, short vel |
| Milestone / big tip | M8 | 8–12 `sparkle` | 3–5 | `*` `·` `§` | burst from event tile |
| Map completion | M9 | up to 64 `sparkle` | 6 | `*` `!` `·` `§` digits | + centered `banner` |

**Palettes:** glyphs `· * § ! . + 0-9` (single-cell, emacs-safe). Faces `success / warning / error / info / bonus` as **domain enums**; adapter maps enum→emacs face — domain never imports emacs types.

**Advance semantics — sim time vs render time (key decision):** an explicit `advance-particles` use-case is called by the presentation layer's redisplay timer.
- Auto-run (5 tps): per frame, timer calls `advance-sim` (1 tick) **then** `advance-particles` (1 advance). Particle time == sim time.
- Paused / idle / pre-game: timer calls **only** `advance-particles` — celebrations finish animating while the sim is frozen. Stuck juice is broken juice.
- Deterministic: pos += vel, ttl −= 1, FIFO eviction, removal at ttl 0 — all from the seeded stream. Same seed + same advance count ⇒ identical field. Tests assert on advance counts; the timer only decides *when*, never *what*.

**Renderer purity contract:** `render(field, map, viewport)` is a pure function of its arguments. Particles are a transient overlay — never occupy cells, rendered after the map, map state untouched. Particles re-read from domain state every render (nothing cached in the buffer). Viewport clipping only — resize changes the clip window, never particle state. `banner` layer renders into a reserved row, never the header/status line.

**Failure modes:**
1. Particle storm → FIFO eviction at K=64, deterministic, tested.
2. RNG stream drift → fixture pins first 100 values; change fails loudly.
3. Stale particles over changed map → re-read every render; nothing cached.
4. Restart/new-map mid-celebration → `reset-particles`; trophy already committed (commit-first).
5. Invalid state (ttl < 0, |vel| > 1) → domain error raised, fail-first, no silent corruption.

**Seven fail-first test criteria (verbatim):**
1. Given seed S and trigger T, the particle field after N advances equals the expected fixture (full particle list: pos, vel, ttl, glyph, face) at N = 0, 1, 3, 6.
2. Same seed twice → identical field; different seeds → different field (statistical over 20 seeds).
3. TTL expiry: every particle removed by ttl=6; field empty after max-TTL + 1 advances.
4. Cap: spawning beyond 64 evicts oldest FIFO, deterministic under seed.
5. Advance-when-paused: calling `advance-particles` without `advance-sim` still animates the field (ttl decreases, positions move) and never advances sim counters (coins, reputation unchanged).
6. Renderer purity: render(field, map, viewport) is a pure function of arguments — same inputs, same buffer output; particles never mutate map state.
7. Ceremony commit-first: MapCompleted ⇒ trophy persisted even if zero ceremony ticks advance.

---

## 5. Integration contract with the rewrite

**`cistern--rewards-eval`** (per-tick domain use-case):
- **Consumes:** full game state (map, workers, coins, reputation, streak, particle field, milestone progress, RNG streams, active goal card) + list of events emitted this tick (relief, burst, leak, milestone-crossed, goal-satisfied).
- **Returns:** a 3-list — updated game state + the outcome record
  (score, objectives, unlocks, celebrate) + presentation intents (log
  lines with severity, face assignments, popup/particle spawns, unlock
  notifications, banner, MapCompleted).

**Goal-card shape:** `{map_id, goals: [{kind: relieves-served | bursts-allowed | contamination-ceiling, target, window_ticks?}], difficulty_tier}`. Max 3 goals. Evaluator runs every tick; all goals satisfied ⇒ MapCompleted.

**Milestone ladder shape:** ordered list of `{threshold: 5|15|30|50|100, unlock: upgrade_id}` over cumulative relieves-served; crossing emits UnlockEmitted exactly once; unlocks persist across maps (ledger 2).

**Reputation tiers + pay-forward:** 0–39 Tier 1, 40–69 Tier 2, 70–100 Tier 3. Pay-forward rule: **the next map's goal-card difficulty is set by the reputation tier at the previous map's completion** (Tier 1: goals −25%; Tier 2: standard; Tier 3: goals +25% + bonus trophy line). One stat feeds score and difficulty — no second mechanism.

**Ceremony commit-first semantics:** MapCompleted ⇒ trophy + next-map unlock committed to state *at trigger time*, zero ticks required; ceremony (6 auto-run ticks, particle field + banner) then runs; any key skips; skipping forfeits nothing because nothing is pending — state changes belong in state-machine order, celebration is presentation-side animation.

**Theme-as-level-parameter (signed off):** a theme modifier (tight corridors, wet map with faster contamination spread) is a **level parameter**, deterministic and testable; the seed varies layout *within* the theme. A theme system beyond the parameter stays deferred.

---

## 6. Explicitly deferred + open

**Deferred to implementation (with seeded fixtures):**
1. Upgrade pricing and goal-card difficulty values.
2. VR-8 tip curve tuning (fixture exists; may move after playtest).
3. Map seed library (alternative/complement to procedural generation).

**Open (presentation-layer / copy, not design):**
4. Paused-animation timer: bare 5 tps always vs debounced idle timer — CPU/battery choice only.
5. Ceremony banner flavor text — copy pass needed; mechanics fully specified.
6. Negative worker spirals (mood/tantrum) — revisit only once players are invested.
7. C3 conducts, C2 persistent roster — opportunistic, post-MUST.

---

## 7. References consulted

| Reference | URL | What it changed |
|---|---|---|
| Dwarf Fortress tantrum (T1) | dwarffortresswiki.org/index.php/DF2014:Tantrum | Dread/story as motivation; spirals need invested players (dropped for v1) |
| RimWorld mood (T1) | rimworldwiki.com/wiki/Mood | Fast target/slow bar legibility; positive-break inspiration (S6) |
| Theme Hospital (T1) | en.wikipedia.org/wiki/Theme_Hospital | Goal cards as level exit criteria; reputation as flow controller; VIP/emergency events; hidden bonus content |
| Cities: Skylines (T1) | en.wikipedia.org/wiki/Cities:_Skylines | Milestones unlock *capability*; tools-as-rewards fused complaint 1 into 3; sandbox mode |
| Two Point Kudosh (T1) | steamcommunity.com / gamespew.com (search) | Economy failure mode: mistuned currency feels like a tax |
| Hades (T1) | en.wikipedia.org/wiki/Hades_(video_game) | Every-run-pays-something contract; run vs meta currencies; difficulty-for-reward |
| Two Point Kudosh wiki (T2) | two-point-hospital.fandom.com/wiki/Kudosh | Persistence is the psychology → one currency, two ledgers |
| Cities milestone ladder (T2) | cheatbook.de/files/cities-skylines.htm (search) | Concrete tier cadence → relieves-served thresholds, capability-then-fluff order |
| NetHack ascension (T2) | nethackwiki.com/wiki/Ascension | Terminal celebration ceremony precedent; commit-first endgame; conducts (C3) |
| DF announcements (T2) | dwarffortresswiki.org/index.php/DF2014:Announcement | Three-tier severity grammar for all reward events (M7) |
| Brogue wiki + Level Generation (T3) | brogue.fandom.com/wiki/Brogue_Wiki, /wiki/Level_Generation | Generate→validate→retry-with-bound generator loop; connectivity invariants; same-seed→identical as feature; mouse-playable text game |
| Near-miss effect review (T3) | link.springer.com/article/10.1007/s10899-019-09891-8 | No-fake-wins rule for variable-ratio |
| Reinforcement schedules (T3) | grokipedia.com/page/Reinforcement (search) | VR-8 tip schedule pinning |
| ADOM design blog (T3) | ancientdomainsofmystery.com (search) | Variance in rewards, not outcomes — deterministic core sim |
| Idle/variable-ratio + juice theory (T1, throttled) | — | Domain-knowledge fallback; superseded by terminal-game precedents above |
