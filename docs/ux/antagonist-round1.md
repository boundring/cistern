# ANTAGONIST ROUND 1 — hostile UI/UX walkthrough

Reviewer: ux-antagonist. Method: fresh batch captures (`playtest/antagonist.el`, dumps
`playtest/ANTAG-01..14-*.txt`), the smoke dumps `SCREEN-*.txt`, and traces of
`src/cistern-view.el`, `src/cistern.el`, `src/cistern-game.el`, `src/cistern-domain.el`.
No code changed. Overlaps with `docs/ux/qualities-motivation.md` and
`qualities-interaction.md` are re-verified here, not copied — new findings are marked NEW.

---

## 1. Ten ANTI-qualities (what sinks the experience)

### A1. The motivation loop is a Potemkin village — the game never deals a goal card (re-verified)
The moment: 82 ticks in, a player who read PLAYING.md is waiting for the promised "Goal
cards" and "MAP COMPLETED". Neither can ever happen: `cistern--cmd-set-goal-card`
(cistern-game.el:451) is called only from tests and `playtest/smoke.el:179`. The entire
REWARDS-DESIGN §2/§5 spine — card, ceremony, trophy, reputation tiers — is unreachable
in shipped play. Why it sinks: PLAYING.md §"Rewards you'll see" is a list of lies from
the player's seat; "why am I doing this" is never answered because the answer was never
shipped.

### A2. Milestone unlocks announce to nobody (re-verified NEW capture)
The moment: crossing 5 relieves. I drove a relief over the threshold
(ANTAG-12-milestone-crossed): `unlocks=(big-cistern)`, and the log tail reads
`CREATOR RELIEVED AT (3,3)` / `SECTOR-7 ONLINE...` — the unlock intent
`(list 'unlock :id ...)` (cistern-game.el:357) carries no `:layer`, so the view's
log-tail (only `:layer 'log`) and banner (only `:layer 'banner`) both drop it. Why it
sinks: the ladder is REWARDS-DESIGN's cadence backbone; the player gets zero feedback
at every rung, so the ladder might as well not exist.

### A3. Score, reputation, trophies: earned, banked, never rendered
The moment: any relief. `cistern-st-score` accumulates (cistern-game.el:324), the
outcome carries `:score` (cistern-game.el:363-364) — and `cistern-view.el` contains not
one reference to score, reputation, trophies, or the goal card. The header spends its
width on `SEED 1535244752` (10 digits of RNG trivia) while the score the design
promises is invisible (ANTAG-01 header). Why it sinks: a rewards layer with no visible
total isn't a reward, it's a rumor.

### A4. The pressure line gives dangerously wrong advice at the exact losing moment (re-verified, sharpened)
The moment: I demolished the starter pipe (ANTAG-05/06). The toilet is SEVERED —
purging cannot fix it — and the pressure line says
`PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS` (cistern-view.el:236),
because `cistern--toilets-backed-p` (cistern-domain.el:293-301) lumps severed and
backed-up into one flag. The inspector, if the cursor happens to be on the toilet,
correctly says `SEVERED: LAY PIPE TO A TANK (p)` (cistern-view.el:213). Two permanent
screen lines disagree about what to do. Why it sinks: the pressure line is the
always-visible coach; when it lies, the player purges, nothing improves, workers
breach, and the game taught them nothing except distrust.

### A5. NEW: the pressure gradient is dead code — failure is binary
The moment: tank at 55/60 (ANTAG-07). `cistern--toilet-usable-p` needs
`load + 10 <= 60` (cistern-domain.el:254-257), so the toilet is already down at 51 —
and the pressure line jumps straight from `LINES NOMINAL` to `PRESSURE CRITICAL` at the
same tick. The middle tier `PRESSURE RISING — total > 100` (cistern-view.el:237-238)
is *unreachable*: any tank above 50 backs toilets, so `total > 100` implies
`toilets-backed-p`, which shadows it with CRITICAL. One tank caps total at 60 — the
tier can never fire in a one-tank game at all. Why it sinks: anticipation is the
whole game — the player gets no gradient, no "tank at 85%", no chance to act before
the failure tick. The warning IS the failure.

### A6. Dead plumbing is invisible — the glyph table betrays the legend
The moment: ANTAG-05, the severed pipe cell renders `·` — byte-identical to floor.
The tile table gives pipe the same glyph as floor (cistern-domain.el:41-43), and the
legend literally prints `· floor ... · pipe` twice on one line (ANTAG-01 line 3). Only
the face (grey50 vs grey40) distinguishes dead pipe from nothing. Why it sinks: "wire
the toilets before the bladders win" is the one lesson (PLAYING.md:50) — and the
failure state of wiring is visually indistinguishable from empty floor. Debugging a
network means hovering every cell to read the inspector.

### A7. Refusals are whispered into a firehose's driest corner
The moment: build on a wall (ANTAG-03). `CANNOT BUILD THERE` lands as the dim third
line of a 3-line log 15 rows below the cursor; the cursor's own inspector says
`FLOOR` and nothing else. Alloy refusal is the same shape: `INSUFFICIENT ALLOY — 15
REQUIRED` (ANTAG-04), sitting above the stale `CANNOT BUILD THERE` from the previous
mistake. Why it sinks: the player acts where their eyes are (the cursor) and the
answer appears where their eyes aren't (the log tail). Three distinct causes, one
indistinguishable dim whisper for each; retries are blind.

### A8. NEW: the armed verb is invisible *and* sticky
The moment: press `p` then, ten seconds later, click to inspect a tile — a pipe
materializes under the cursor and the clock ticks. `cistern--arm-and-build`
(cistern.el:127-136) arms on every build key; `cistern--cmd-click`
(cistern-game.el:480-494) spends the arm on any later click. I dumped the armed state
(ANTAG-02): byte-identical to unarmed — no header badge, no cursor change, nothing.
Why it sinks: a hidden mode in an otherwise modeless UI. The accidental build isn't
just surprise, it's an unrequested alloy charge *and* an unrequested tick.

### A9. NEW: the log doesn't know who anyone is, or what matters
The moment: a breach (ANTAG-09). The map shows worker β bursting; the log says
`BREACH — CREATOR #1 OVERFLOWED AT (12,6)` — a zero-indexed "CREATOR #1" for the glyph
β, an identity system the player has never seen anywhere (cistern-game.el:337-338).
Meanwhile the same 3-line tail carries repeated identical `CREATOR RELIEVED AT (3,3)`
spam (SCREEN-11: the same line twice in a 3-line window) at the same dim weight as
boot flavor (`SECTOR-7 ONLINE — KEEP THE WATER MOVING` lingers for 30+ ticks, ANTAG-11).
Why it sinks: the log is the only chronicler of the game's most violent events, and it
spends its budget on anonymous relief boilerplate; a breach scrolls out in two ticks.

### A10. Losing is quieter than winning — and smaller than a log line
The moment: contamination hits 20 (ANTAG-13). The map is unchanged. The verdict is
appended to the far right of an already-95-char header (`!! SECTOR CONDEMNED —
CONTAMINATION LIMIT` — truncated off-window under `truncate-lines t`), plus `PRESS n
TO RESTART` and one log line. No score, no relieves, no ticks survived, no cause
narrative, no ceremony — while MAP COMPLETED fills the field with 64 sparkles
(SCREEN-13). Why it sinks: the emotional ledger is inverted; a 300-tick death collapses
to less screen presence than a purged tank, and the player who loses learns nothing
about how close they came or what to build differently.

### A11 (bonus, NEW). The in-game briefing prints literal `%%`
`cistern-help` uses `princ` on plain strings containing escaped `%%`
(cistern.el:185-186, 191) → the player reads `At 60%% their bladders fill` and
`At 100%% a worker breaches` (SCREEN-14:12,20). The single most-read onboarding text
ships a typo that says "this wasn't proofread."

---

## 2. Five things that already SOAR (protect these)

### S1. The inspector is the best teacher in the game
Cursor on a backed-up toilet: `BACKED UP: PURGE THE TANKS (x)`. Severed:
`SEVERED: LAY PIPE TO A TANK (p)`. Tank: `LOAD 55/60 — PURGE WITH x (pays 1 alloy per
3)` (cistern-view.el:207-217). State *and* next verb *and* economy lesson in one line.
Every other surface should be held to this standard.

### S2. The pressure line's voice is the atmosphere
`LINES NOMINAL — THE STRUCTURE DOES NOT CARE` (cistern-view.el:239) is the Blame!
register perfectly — the megastructure as indifferent infrastructure. When the prose
sounds like this, the sim feels like a place. (It must also stop lying — A4 — but the
voice is right.)

### S3. Score popups land at the moment of the act
`+10`/`+20` rises from the toilet tile at the tick of relief, 2× near-burst, seeded
tips (cistern-game.el:317-328; SCREEN-13's `+20`). Cause and reward occupy the same
cell, the same tick. This is the loop working exactly as designed.

### S4. Purge is a self-teaching economy loop
Free verb, pays alloy, the inspector advertises the rate, and the alloy counter visibly
jumps. The one mechanic where the game teaches its own incentive with zero docs.

### S5. Commit-first, non-modal ceremony
MapCompleted commits the trophy at trigger time and input stays live — any key
"skips", nothing forfeited (REWARDS-DESIGN §5; verified in tests at
test-4b-rewards.el:828-835). The architecture of celebration is right even though the
player rarely reaches it (A1).

---

## 3. Ten highest-leverage UI/UX QUALITIES (ranked by player-experience leverage)

1. **Every failure names its next action, at the place of failure** — inspector-grade
   copy ("SEVERED → p", "NO ALLOY → mine ◆") surfaced at/near the cursor, not only in
   a scrolling log. (Fixes A7, defuses A4's damage.)
2. **A visible rewards strip: SCORE / GOALS n/m / REP** on the fixed frame — progress
   exists only if it is rendered. (Fixes A1/A2/A3's visibility half; the goal-card
   deal itself is one call in `cistern--new-game`.)
3. **The pressure line anticipates, not just announces** — tank headroom % and a
   gradient *before* the backing-up tick; never let the warning and the failure be the
   same tick. (Fixes A5, A4's conflation.)
4. **The always-visible coach never contradicts the inspector** — severed and
   backed-up are different states with different verbs; one flag for both is a UI lie.
5. **Failures are distinguishable at a glance on the field** — dead pipe gets its own
   glyph (not floor's `·`); the legend never lists one glyph twice. (Fixes A6.)
6. **No hidden modes** — the armed verb shows in the frame (`ARMED: PIPE — click
   places`) and is cancelable. (Fixes A8.)
7. **The log ranks events by consequence** — breaches/condemnation at top visual
   weight, relief noise aggregated or suppressed, workers named by their map glyph.
   (Fixes A9.)
8. **Death gets a summary panel** — ticks survived, relieves served, score, cause, one
   key to restart; losing should weigh at least as much as a purge. (Fixes A10.)
9. **The first 30 ticks ask something of the player** — ship a real tutorial table
   through the existing predicate mechanism (a 3-step: tick → inspect worker → purge),
   so the first payoff arrives before boredom does. (Fixes A1's onboarding edge; the
   mechanism already exists at cistern-game.el:84-108.)
10. **Ceremony narrates cause and leaves the field readable** — log each goal as
    satisfied before the banner; particle glyphs that don't occlude workers/structure;
    a banner that says what's next. (Protects S5, extends S3.)

---

### One-line verdict
The bones (inspector, purge loop, popup timing, ceremony architecture) are genuinely
good; what sinks the game is that the reward loop is unshipped and the two permanent
status lines can disagree with each other and with the field — fix the pressure line's
lie, render score/goals, and deal the damn card.
