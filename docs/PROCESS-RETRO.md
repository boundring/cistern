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
