# Process retrospective — Phase 1 (domain rewrite)

Run: `impl-phase1`, 2026-09-03. Evidence: `docs/FAILURE-LEDGER.md`
L-001..L-006; commit range `66f3940..3725f31`.

## 1. What ran

- One good-model session, one mega-turn: 46m40s, 78 tool calls.
- 5 red/green pairs, 10 commits (`66f3940..3725f31`).
- 2 in-cycle retries: sxhash premise bug (L-002), car/cdr test bug (L-004).
- 0 clarification turns.
- One duplicate-definition drift caught by grep before running (L-005);
  one red-passed-unexpectedly resolved by probe strengthening (L-006).
- One plan-order deviation: connection functions needed in Pair 3,
  scheduled Pair 4 — minimal port, ledger-noted.
- One conventions conflict: plan 01 header says "no commits; coherence
  pass commits" (written for planning workers); implementation
  correctly committed per pair under explicit director instruction.
- Independent verifier re-ran the suite: 6/6 exit 0, ordering PASS,
  purity PASS (2m9s).

## 2. What worked — keep

| Keep | Evidence |
|---|---|
| Self-contained brief with read-order + verbatim acceptance criteria + explicit report format | 0 clarification turns across 78 tool calls |
| Red/green commit discipline held under pressure; independent fast verifier confirmed ordering + suite (2m9s) — cheap, catches false greens; make it a standing gate (→ P6) | commit range, verifier re-run |
| Probe-the-premise: minimal batch repro before concluding (sxhash depth-limit) | L-002 |
| Disable-the-guard probe to quantify whether a pass is real or seed luck (~13% caught) | L-004 cl-letf probe |
| Honest deviation protocol: red passing on arrival → strengthen the probe, never manufacture a bug | L-006 |

## 3. What hurt — fix

| Hurt | Evidence | Fix |
|---|---|---|
| 46m40s single turn = long exposure to the L-001 upstream-timeout class; a mid-turn death would cost up to 5 pairs of in-flight work (commits bounded it to per-pair loss) | L-001; run timing | P1 |
| Plan commit-policy conflict: plan 01 header forbade commits (planning convention) vs implementation needing commit-as-you-go as resumable state; resolved by director override, but the conflict shouldn't exist | run record | P2 |
| Mechanical drift on one growing file: apply-patch misplaced a block → duplicate `cistern--walkable-p` + stale section; suite-runner ad-hoc loop picked defconst names as entry points → false FAIL lines | L-005 | P3, P4 |
| Emacs 31.1 API trap: `equal<` does not exist in batch; tests must stay on conservative elisp | L-006 | P4 |

## 4. Process changes applied (Phase 2 onward)

- **P1** Per-pair turn cadence for multi-cycle phases: director sends
  one pair per turn; each result is a verification point; a death
  costs one pair.
- **P2** Plans state a per-phase commit policy (planning: stage-only;
  implementation: commit per pair).
- **P3** Canonical suite runner `tests/run.el` providing
  `cistern-run-all-tests`; workers and verifiers use it; no ad-hoc
  entry-point discovery loops.
- **P4** Standing pre-commit checklist in HANDBRIEF-TEMPLATE: duplicate
  defun grep, full-suite batch run, no sxhash on structural
  signatures, conservative elisp only.
- **P5** Probe rules in HANDBRIEF-TEMPLATE: strengthen-don't-manufacture
  on unexpected red-pass; disable-the-guard probe when a pass could be
  luck.
- **P6** Independent verifier gate after every phase.

## Steering lessons — UX cycle (2026-09-07)

Written after the two-round adversarial UX cycle (45 directives, 79/79 suite, L-035..L-075). Lessons for SOONER guidance and steering of delegated subagents, each tied to observed evidence:

1. **Layout and pixel rulings require a measurement probe before the ruling.** Evidence: the director's batch-3 ruling accepted the armed-badge 95-col overflow on reasoning; round-2 measurement (antagonist N1) showed the badge renders 126 cols, wraps, and shifts the map under `cistern-view--cell-at` — the ruling was overturned and re-fixed as R2-Q02. Rule: any ruling about width/geometry/visual layout is preceded by a render probe with the numbers in it; the director rules on the numbers, not the reasoning.
2. **Merge curator dependency chains into one red/green group at brief time.** Evidence: Q08's acceptance forced Q09's domain split into the same green (ledgered L-039) — handled well, but the merge was discovered mid-batch; the curator's dependency map predicted it. Rule: when the plan prints 'X before Y', the batch brief states them as one group with one green boundary.
3. **Batch cadence: ≤4 directives.** Evidence: round-1 batches of 7–9 directives ran 55–65 minutes, leaving director rulings (Q03 setter placement, Q01 version drop) unratified for the whole batch; round-2's smaller batches surfaced decisions in minutes. Rule: a batch is at most 4 directives or 30 minutes of expected work, whichever comes first.
4. **Throwaway probe scripts are the highest defect-rate artifact — brief the discipline up front.** Evidence: four collector/probe authoring bugs (cons-vs-list hash key ×2, header-stride misread, mapcar nesting) all in /tmp scripts, never in shipped code; the fix pattern (file-based probes over inline --eval, check-parens + reader form probe, explicit key construction for dot-cons vs list) emerged via the ledger but was learned per-session. Rule: collector and antagonist briefs carry the probe discipline from turn one.
5. **Route-don't-invent held at scale — keep it.** Evidence: 10+ contract questions returned as routings with options (Q03 placement, refund arithmetic, map_id, GOALS semantics, badge width, cross-map persistence); every one resolved by a one-line director ruling and audited clean at both closing reviews. Zero silent inventions found.
6. **Mid-turn steering with owner feedback is the fastest corrective available.** Evidence: the owner's 'alignment only in pipes/toilets/ore glyphs' observation, steered into a running diagnosis turn, narrowed the search to two glyphs (◆ ▣ double-width fallback in the owner's Iosevka) within minutes — versus the full-glyph sweep the worker was running. Rule: owner observations go into the running turn as steering, not into a post-mortem.
