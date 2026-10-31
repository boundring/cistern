# CISTERN v6 — THREE-CHANNEL LOGS (LOGS.md)

Status: SPEC v1, 2026-09-08. DESIGN ONLY — no code in this doc; every
directive lands red-first per R10. Owner requirement (verbatim intent):
SEPARATE LOGS FOR SEPARATE THINGS — (a) a log for specific ambient events
in view or OUT OF VIEW, (b) a log for story beats and dialogue, (c) a
summary log for players to follow general events as well as specific ones.

Carried constraints, binding on every directive below (PROTECT block):
- **Five soars**: S1 inspector standard · S2 pressure voice · S3
  popups-at-act · S4 purge economy · S5 non-modal ceremony.
- **Width contract**: no permanent render row exceeds 95 cols (C1/L-076
  discipline); summary/bank templates ≤ 60 raw chars.
- **Copy-table rule** (Q11): every new player-facing string lands in
  `cistern--copy` under a named key; no literals in view/game/input.
- **L browser PROTECT**: the shipped `cistern-log-mode` keymap (n/p, /,
  g, G, RET, q; native special-mode keys) is ADDITIVE ONLY — old ∩ new
  keymap = identical actions, probe-asserted.
- **Uncapped ring contract** (Q16): the log never clips; the tail is a
  view concern. Channels must not change this.
- **least-active-decisions**: one state mutation rule, one append path,
  no new state fields beyond what §5 pins.
- **Performance budget**: three channels MUST NOT triple log writes —
  §5.3 pins the budget at exactly v5's append count.

---

## 0. RULINGS — read first

R1. **ONE ring, not three.** The log stays `cistern-st-log`, one
    uncapped list. The Q13 entry shape `(LINE SEVERITY TICK)` migrates
    to `(LINE SEVERITY TICK CHANNEL)` with CHANNEL ∈ {ambient story
    summary}. Rationale: three rings = three state fields, a forked
    append path, duplicated collapse/pick logic, and a migration of
    every reader; the browser already reads ONE list and can filter.
    Readers of nth 0/1/2 (log-tail, collapse-log, restart-dedup, boot
    line) are shape-compatible unchanged; only new code reads nth 3.

R2. **SUMMARY is DERIVED, never stored.** The summary channel is a pure
    projection of the ring computed by a summarizer function — zero
    ring appends. Rationale: no extra writes, no state growth, no
    uncapped-contract risk, and batch testability for free (pure
    function → pinned fixture). The AMBIENT and STORY channels are the
    stored ones; SUMMARY is recomputed on demand.

R3. **Routing is at the append path, not at call sites.** Two existing
    helpers keep their names; a channel variant joins them. Call sites
    reclassify by switching helper, driven by a routing table (§1) —
    one migration commit, greppable, no per-site channel arguments.

R4. **No event is logged twice.** A breach is one ambient entry whose
    text makes it summary-ELIGIBLE; the summary channel cites it by
    clustering. The write budget (§5.3) pins total appends == v5.

---

## 1. CHANNEL TAXONOMY + ROUTING TABLE

Channels: `ambient` = mechanical truth, anywhere, located (the firehose
the tail already is today, plus out-of-view events — §4); `story` =
narrative voice (premise, hooks, verdicts, dialogue, romance, comedy,
milestones, tutorial); `summary` = the distilled shift (derived, §2).

Routing rule: exactly ONE stored channel per append, chosen at the
helper; summary-eligibility is a property of the entry (§2), never a
second write.

### 1.1 Routing table (existing call sites → channel)

| Event family (copy keys / sites) | Channel | Summary-eligible |
|---|---|---|
| breach `breach-fmt`, severed line (leak), gnaw `combat-gnaw` | ambient | YES (cluster anchor) |
| raid open / warband-routed / raid closed | ambient | YES |
| worker/goblin death, composure-broken, condemnation | ambient | YES |
| guild arrival/fix/depart, ambush, infest, tank-raid, leech, drive-off, sponge | ambient | counts only |
| relief, migrant in/waits, rubble-cleared, cache-pickup | ambient | counts only |
| RPG: clearance-up, composure-slip, exposure hold/fail, injury crossings | ambient | counts only |
| placements, demolish, purge, decon, ALL refusals/hints-backed lines | ambient | no |
| boot line `SECTOR-7 ONLINE…` | story | no |
| premise, goal-mod, story hook open/verdict/missed lines, act open | story | YES (milestones) |
| milestones, goal-complete lines (`milestone`, card lines) | story | YES |
| dialogue muttered/filed, social objections/stage/close, romance stages | story | counts only |
| comedy beats, whimsey, comedy thoughts (delivered-to-log ones) | story | counts only |
| tutorial step/complete/skipped | story | no |

Notes: (a) condemnation keeps its ambient error entry AND anchors the
final act summary; (b) private-only deliveries (comedy dry thoughts,
SOCIAL private thoughts) never reach the ring today — they gain no
channel and no new write is invented (budget rule R4); (c) the tutorial
is coaching voice, hence story, matching the `?` briefing's register.

### 1.2 Migration surface

`cistern--log` / `cistern--log-sev` push with channel `ambient`;
new `cistern--log-story` pushes with channel `story`. Reclassify
exactly these story families by switching the helper at the ~15 call
sites listed in §1.1 (story-eval intents landing via the cistern-game
`(:layer 'log)` projector, social mutter/file/objection, comedy
delivery, romance/social stage/close, premise/goal-mod, boot, tutorial,
milestone/goal-complete). The rewards-events stream, popup paths and
banner intents are UNTOUCHED (S3, S5 protected).

---

## 2. THE SUMMARY WRITER (derived summarizer)

Option (a) per-tick clustering over the ring, chosen over (b) act-only
and (c) rolling sector status: act boundaries alone are too sparse to
follow a shift, rolling status loses history, and the clustering
window is exactly the player's attention span. Act boundaries and
on-demand reuse the same function.

### 2.1 Shape and fire points

```
cistern--log-summarize (log st) → ordered list of entries
entry = (TICK SEV TEXT)   ; TEXT carries `AT (x,y)` of the cluster anchor
```

- **Pure, deterministic**: reads only the ring, the tick, map
  dimensions and story act boundaries from `st`; consumes no stream,
  draws no rng, mutates nothing. Same seed + same ring ⇒ byte-identical
  output (LG5).
- **Fires**: (1) at every story act boundary (act-open tick recorded in
  story state); (2) every `cistern-summary-every` = 60 ticks
  (`cistern--const`, one block beside the catalogs); (3) on demand —
  every build of the browser's summary view (§3). With no banks loaded
  only the cadence fires: a legal no-op state, like story itself.
- **Windows**: [prev-fire-tick, now). An act boundary cuts a window
  even if short; the cadence resets at act boundaries.

### 2.2 Clustering rule (fixed clause order, one line per quadrant)

Cluster key = map quadrant of each eligible event's anchor
(NW/NE/SW/SE from map midpoints). Per quadrant per window, ONE line
composed from FIXED ordered clauses, present-or-absent (deterministic
concatenation, no prose generation):

1. BREACH clause: n breaches/gnaws — `N BREACHES` / `BREACH OPEN` if
   the window's last breach has no in-window restore at its coords.
2. LOSSES clause: `N LOST` for worker deaths.
3. RAID clause: `WARBAND ROUTED` / `RAID — MAIN CLAIMED`.
4. COUNT clause: `+N ALLOY` from the window's income events.
5. Fallback: `QUIET` when no eligible event lands in the quadrant.

Line: `EAST GALLERY: 2 BREACHES, 1 LOST — WARBAND ROUTED — +12 ALLOY`
(quadrant names via copy keys `sector-nw/ne/sw/se`, in-universe).
Severity = max severity in the cluster (error else info). Anchor = the
first eligible event's coords → existing RET regex jumps to it.

Act boundary adds one prefix line per act:
`ACT II CLOSED — 4 BREACHES, 1 DEATH, SCORE 220` (+ the story verdict
when one exists). These are also derived; the S3 banner keeps its own
act ceremony untouched.

### 2.3 Batch testability

- **Unit fixture**: hand-built ring (no sim) → pinned summary output
  list, byte-exact. Covers: clustering by quadrant, clause order,
  breach-open vs breach-contained, quiet fallback, act prefix line.
- **End-to-end fixture**: seed 20260830, driven 300 ticks → pinned
  `(tick text)` sequence of all summary entries (LG5/LG6).
- **Width probe**: every generated summary line ≤ 95 cols in the
  browser capture (raw clause templates ≤ 60 chars, the bank budget).

---

## 3. THE THREE-VIEW UX

### 3.1 Browser — channel filter, additive keys

The ONE `*cistern log*` buffer gains a channel filter; the shipped
keymap is untouched (PROTECT):

| Key | Action |
|---|---|
| `1` | filter AMBIENT |
| `2` | filter STORY |
| `3` | filter SUMMARY (renders the §2 derived list) |
| `0` | filter ALL (v5 behavior, the default) |

- Header copy names the channel: `log-header` gains per-channel
  variants (`— STORY — press q to close —`); the `log-hint` line gains
  `1/2/3 CHANNELS · 0 ALL` (fits 95: current 64 cols + 18).
- Staleness gate `cistern-log--built-for` becomes a cons
  `(ring-length . channel)` so switching channels always rebuilds and
  point stability survives round trips within one channel.
- `g` rebuilds the current filter (also re-derives SUMMARY); `n/p`,
  `/`, `G`, `q` untouched; RET jump is per-channel for free — every
  channel's lines carry `AT (x,y)` spans (summary anchors included),
  so the existing jump regex needs no change.
- Browser line format: `T%-4d` prefix as today; the channel is carried
  by the filter header, not per-line (all-zero noise avoided).

### 3.2 Main screen — ONE combined tail, budget unchanged

No new permanent rows. The 3-line tail stays; its pick rule extends:
majors (error) keep priority → remaining slots fill ambient-first by
recency → STORY beats fill only slots left over (newest first).
Pure-ambient state therefore renders BYTE-IDENTICAL to v5 (PROTECT).
Each tail line gains a 3-col channel tag prefix — `[A] `, `[S] ` —
under the 95-col contract (tail lines ≤ 64 cols today).

The SUMMARY channel's main-screen surface is the RESERVED BANNER ROW
(rendered empty since §3.5 deferral): by default it now shows the
LATEST summary entry, dim, severity-faced; ceremony banners override
it exactly as today (S3 protected, one row, zero geometry change).

---

## 4. OUT-OF-VIEW AMBIENT + THE "YOU ARE NEEDED ELSEWHERE" SURFACE

### 4.1 What gets logged (write side)

ALL ambient events are logged unconditionally, in or out of view,
always with their `AT (x,y)` — no sampling, no importance gate at
write time. This is already v5's write behavior (every hostile,
hazard, breach and restoration logs located); v6 adds zero write
pressure, only the channel tag. The AMBIENT channel IS the
beyond-the-window record: filter `1`, walk, RET, arrive.

### 4.2 The pressure surface (read side)

Importance tiering is a READ-TIME concern with one surface: the
pressure line (persistent, already reserved, S2-adjacent — extended
via copy-table suffix, never edited):

```
PRESSURE RISING — NEEDED AT (x,y)
```

- **Tier-1 standing problems** (open problems only): severed line,
  active raid, attached leech-grip — read from LIVE state queries
  (the same predicates the pressure line already computes), not from
  ring scans. The FIRST instance in row-major scan order outside the
  visible window names its coords. No instance → suffix omitted.
- **Visible window**: `cistern-view--in-viewport-p` (one view helper;
  today the 34×16 map renders whole ⇒ constant t over bounds ⇒ the
  clause is provably INERT). If a v6 world layer enlarges the map,
  the clause activates with no further change here.
- **Cold-start PROBE**: today's render pressure lines are
  byte-identical to v5 (LG11) — the surface is additive only.

Tier-2 (transient errors like burst) and Tier-3 (the rest) get no
dedicated surface — they live in AMBIENT `L` and the browser filter.

---

## 5. DETERMINISM / INTEGRATION

### 5.1 State and shape

Zero new `cistern-st` fields. Entry shape migrates to the 4-list
`(LINE SEVERITY TICK CHANNEL)` at the two push sites (R1). Reader
list from V4-01 (log-tail, collapse-log, restart-dedup, boot line)
projects nth 0/1 and is unchanged; the tail and browser additionally
read nth 3. Runs are ephemeral — no save migration exists.

### 5.2 Determinism

- Routing is deterministic by construction (helper identity at the
  call site, table §1.1 greppable).
- The summarizer consumes no stream (§2.1): rng positions, all child
  stream positions and the sim trajectory are unchanged with the log
  layer off OR on — the §5.6-style guard runs tick-for-tick (LG7).
- Browser/tail/banner reads are pure projections; the render stays
  D4 (no mutation, no side effects).

### 5.3 Write budget

Total ring appends per tick == v5's count, asserted on a 300-tick
seed-20260830 soak (LG3): ambient = the events that already logged;
story = a RECLASSIFICATION of existing narrative appends, not new
ones (§1.1 note b); summary = 0 appends (derived). The summarizer's
O(ring) read per summary view/tail render matches the tail's
existing O(ring) projection cost class — accepted.

---

## 6. DIRECTIVES (fail-first, wave-ordered)

Inherits the §0 PROTECT block; only directive-specific interactions
listed. Acceptance namespaces LG1–LG13 (LOGS); every criterion FAILS
before its directive's change and passes after.

| # | Directive | File-level minimal change | Acceptance (fail-first) | Size | PROTECT |
|---|---|---|---|---|---|
| L6-01 | Ring channels + routing | 4-list shape at both push sites; `cistern--log-story`; reclassify §1.1 story call sites; story section keys via copy table | LG1: every append carries a known channel enum. LG2: a driven run lands premise/dialogue/comedy/milestone lines ONLY in story; breach/gnaw/relief ONLY in ambient. LG3: 300-tick soak append count == v5 baseline. LG4: ring still uncapped (13+ mixed events, oldest intact) | M | S3/S5 intent paths untouched |
| L6-02 | Summarizer | `cistern--log-summarize` pure fn + `cistern-summary-every` const + `(summary . …)` copy section | LG5: unit fixture (hand-built ring) + 300-tick fixture byte-exact. LG6: quadrant clustering, clause order, open-vs-contained breach, quiet fallback, act prefix — all fixture-asserted. LG7: no stream/rng consumption tick-for-tick | M | width (§2.3 probe) |
| L6-03 | Browser channels | keys 1/2/3/0, per-channel `log-header`/`log-hint` copy, staleness gate cons | LG8: old ∩ new keymap identical actions; n/p//g/G/RET/q probe green. LG9: filters isolate channels; 3 re-derives; 0 = v5 view. LG10: RET jumps per channel incl. summary anchors; point survives same-channel round trip | M | S5 non-modal (browser never gates) |
| L6-04 | Tail tags + banner summary + ELSEWHERE | tail pick rule + `[A]/[S]` tags; banner-row default = latest summary entry; `cistern-view--in-viewport-p` + pressure suffix `pressure-elsewhere` | LG11 (cold): pure-ambient render byte-identical to v5 tail AND pressure lines. LG12: banner ceremony overrides the summary default; summary shows when quiet. LG13: ELSEWHERE inert on 34×16 (no suffix anywhere), activates under a forced smaller viewport test harness | M | S2 voice (suffix only, copy-table), S3 banner, C1 width on all rows |

Wave order: L6-01 → L6-03 (browser needs the shape) and L6-01 →
L6-04 (tail needs the shape); L6-02 parallel-safe after L6-01, must
land before L6-03's `3` filter can show content. Final sweep re-probes
the five soars, the L-076 pin route for the `[A]/[S]` tags (ASCII —
in-range, no probe risk), and the copy-table grep over every new key.

### 6.1 New copy-table keys (named at design time, C2)

`pressure-elsewhere` · `log-header-ambient` / `-story` / `-summary` /
`-all` · `log-hint` (extended, not new) · `(summary …)` section:
`sector-nw/ne/sw/se`, `summary-quiet`, clause templates
(`summary-breach-n`, `summary-breach-open`, `summary-losses`,
`summary-raid`, `summary-income`, `summary-act-prefix`).

### 6.2 First five to build

1. L6-01 shape + ambient default (the backbone; everything reads it).
2. L6-01 story reclassification (the routing table, one greppable commit).
3. L6-02 summarizer + unit fixture (no view yet, fully testable).
4. L6-03 browser filter (the player gets all three channels).
5. L6-04 tail tags + banner default + ELSEWHERE (the main-screen read).
