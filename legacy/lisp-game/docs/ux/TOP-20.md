| # Cistern UX — TOP 20 Qualities

> STATUS: ROUND-1 SHIPPED 2026-09-07 — all 20 qualities (incl. the
> 5 PROTECT soars) implemented or made executable; see TOP-30 marks
> and ledger L-035..L-059.

Curator: ux-curator. Consolidated from `antagonist-round1.md` (A*, S*), `qualities-legibility.md` (L*),
`qualities-interaction.md` (I*), `qualities-motivation.md` (M*). No code changed in this phase.

Ranked by player-experience leverage. PROTECT = an existing soar the refactor must not regress.

## Curation note — the one collector disagreement

Legibility #3 verified the pressure line "truthful" (`CRITICAL` fires exactly with toilet-down);
the antagonist (A4) showed it "dangerously wrong" after severing the starter pipe. Both verified
correctly: the line is truthful for *backed-up* and lying for *severed*, because
`cistern--toilets-backed-p` (`cistern-domain.el:293-301`) collapses both states into one flag.
Resolution: quality #4 below covers the severed case; the split is a domain-layer prerequisite.

Cut from the top 20 (considered, below the bar): keyboard/mouse tick-tempo parity (I7 — real but
invisible until contamination endgame); standalone worker-identity, log-severity, legend-source,
cursor-hint, and run-summary entries (absorbed into #7, #10, #12 as prerequisites — they reappear
as derived directives Q13/Q14/Q17/Q22 in TOP-30).

---

1. **A dealt goal card exists from tick one.** Every new game has an active goal card the player
   can name; the rewards loop §1/§5 is reachable in shipped play, not only in tests.
   *Sources:* antagonist A1, motivation M1. *Directive:* issue a starter card in
   `cistern--new-game` via the existing `cistern--cmd-set-goal-card` (one call).

2. **Progress is rendered on the fixed frame.** SCORE, GOALS n/m, and REP are visible every tick
   without opening any surface; the header spends its width on player state, not `SEED` RNG trivia.
   *Sources:* antagonist A3, legibility L5, motivation M3. *Directive:* add a status-strip segment
   reading score/rep/goal progress from game state; move SEED to the `?` briefing.

3. **Every refusal names its next action at the cursor.** A refused act produces cursor-adjacent,
   one-tick feedback with state + verb (inspector grade) in the same tick — never only in the log
   tail 15 rows away.
   *Sources:* antagonist A7, interaction I1. *Directive:* a transient hint slot under the inspector,
   fed by refusal copy that names the fix.

4. **The always-visible coach never contradicts the field.** Severed and backed-up are different
   states with different verbs; the pressure line and the inspector agree in every frame.
   *Sources:* antagonist A4, motivation M5, legibility L3 (backed-up scope only). *Directive:*
   split the severed/backed-up conflation in the domain, then re-branch the pressure line.

5. **Failure states on the field are distinguishable at a squint.** Dead pipe has its own glyph —
   never floor's `·` — and the legend lists no glyph twice because it is generated from the same
   table the map draws from.
   *Sources:* antagonist A6, legibility L1. *Directive:* distinct glyph for unconnected pipe;
   regenerate the legend from the view tile table.

6. **No hidden modes.** An armed verb shows in the frame (`ARMED: PIPE — click places`), is
   cancelable, and a later click cannot spend it unknowingly; arm-then-click is taught on the help
   line.
   *Sources:* antagonist A8, interaction I2/I3/I4. *Directive:* header badge + cancel key + split
   arm from at-cursor place semantics.

7. **Death outweighs a purge on screen.** Condemnation renders a summary panel — ticks survived,
   relieves, score, cause, one restart key — with no repeated log spam; losing weighs at least as
   much as MAP COMPLETED.
   *Sources:* antagonist A10, motivation M7. *Directive:* condemned state renders a run-summary
   panel instead of appending four identical log lines.

8. **Every rung of the ladder announces.** Crossing a milestone produces a log line and a banner
   tick in the same frame as the crossing; unlocks are never silent.
   *Sources:* antagonist A2, motivation M2. *Directive:* tag the unlock intent with `:layer`
   (`log` + `banner`) in rewards-eval so the view's existing routing picks it up.

9. **The first 30 ticks ask something and speak.** A shipped tutorial table walks the first
   purge through the existing predicate mechanism; the briefing contains no escaped-`%%` typos.
   *Sources:* motivation M4/M5, antagonist A11. *Directive:* ship a 3-step tutorial table;
   fix the `princ` `%%` escapes in `cistern-help`.

10. **PROTECT — the inspector one-liner is the teaching standard.** Cursor on any tile yields
    state + next verb + economy in one line; no surface regresses below it, and the inspector
    orients on empty floor (nearest structure bearing).
    *Sources:* antagonist S1, legibility L10. *Directive:* hold every new surface (refusal hints,
    pressure line, death panel) to the inspector copy pattern; append a floor bearing.

11. **The coach anticipates, not just announces.** A tank above ~85% of capacity raises a rising
    warning with headroom % before the failure tick; the warning and the failure are never the
    same tick, and the middle tier is reachable.
    *Sources:* antagonist A5, legibility L3 caveat. *Directive:* proportional threshold
    (0.85 × Σ tank-cap) + headroom % in the pressure line.

12. **The log knows who and what matters.** Workers are named by their map glyph (β, not
    "CREATOR #1"), severity faces persist with the line instead of fading after one tick, breaches
    outrank relief boilerplate, identical spam is suppressed, and the full log is retrievable.
    *Sources:* antagonist A9, legibility L2/L4/L6. *Directive:* shared worker-name helper; store
    the face on the log entry; aggregate repeats; `L` opens the uncapped log.

13. **PROTECT — rewards land at the cell and tick of the act.** `+10`/`+20` popups keep rising
    from the acting tile at the tick of relief; nothing delays or relocates them.
    *Sources:* antagonist S3. *Directive:* keep the popup mechanism as the reward channel; new
    reward events reuse it rather than replacing it.

14. **PROTECT — purge teaches its own economy.** Purge stays free, pays alloy, and the inspector
    keeps advertising the rate; the visible alloy jump is the game's one self-teaching loop.
    *Sources:* antagonist S4. *Directive:* guard the purge inspector line and the alloy ledger
    whenever economy rules change (regret window included).

15. **Ceremony narrates cause and leaves the field readable.** Each goal logs as satisfied before
    the banner; particles never occlude workers, structure, or pipe — no sparkle digit where a
    pipe run was.
    *Sources:* motivation M6, legibility L8, antagonist #10. *Directive:* log `GOAL MET — …` per
    goal before the banner; constrain sparkle spawn/draw to plain floor cells.

16. **Urgency is colored, not just spelled.** The pressure line and the CONTAM fraction are faced
    by state (yellow rising, red bold critical); 5/20 and 19/20 are not pixel-identical.
    *Sources:* legibility L7/L9. *Directive:* propertized header segments + state-faced pressure
    line.

17. **PROTECT — celebration is commit-first and non-modal.** Any key during a ceremony skips it
    without forfeiting anything; input never blocks, trophies commit at trigger time.
    *Sources:* antagonist S5 (verified `test-4b-rewards.el:828-835`). *Directive:* new ceremonies
    (death panel, milestone banners) follow the commit-at-trigger architecture.

18. **Running has a visible tempo.** Auto-run shows a header badge while live, and a slower
    pacing exists for timing a purge against a filling tank.
    *Sources:* interaction I5, motivation M10. *Directive:* `AUTO-RUN` badge + prefix-arg slow
    speed (1 tps) on the existing idle-timer handle.

19. **Regret is free once.** Demolishing in the same tick a piece was placed refunds fully; an
    early misplacement does not bleed alloy.
    *Sources:* interaction I6. *Directive:* full refund when demolish follows build in the same
    tick (the build↔demolish path is already re-entrant).

20. **PROTECT — the pressure line's voice is the atmosphere.** `LINES NOMINAL — THE STRUCTURE
    DOES NOT CARE` stays byte-identical; all new status/warning copy passes the same Blame!
    register — the megastructure as indifferent infrastructure.
    *Sources:* antagonist S2, motivation M8. *Directive:* keep the idle line verbatim; author
    every new state string in the same register.

---

Lens coverage: legibility 2,4,5,10,11,12,16 (+15) · interaction 3,6,17,18,19 ·
motivation 1,7,8,9,13,14,15,20 (+2,10). All antagonist anti-qualities A1–A11 map to
entries 1,8,2,4,11,5,3,6,12,7,9 respectively; all five SOARS are PROTECT (10,13,14,17,20).
