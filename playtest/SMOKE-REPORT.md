# Prototype smoke test — live driver exercise (2026-09-06)

Scripted interactive session in batch Emacs, driving the REAL
surface — the `cistern` entry point, the `*cistern*` buffer, the
`cistern-mode` keymap commands, and synthesized `mouse-1` events —
the path the 32 headless test entries do not cover.

Session driver: `playtest/smoke.el`. Player-eye dumps: `SCREEN-NN-*.txt`
in this directory.

Run line:

```
emacs -Q --batch -l src/cistern.el -l playtest/smoke.el -f cistern-smoke-run
```

## Exercise verdicts

| # | Exercise | Observed | Verdict |
|---|----------|----------|---------|
| 1 | Cold start, seed 42 | Header, help line, legend, 16-row map, inspector, pressure line, log all render; starter plumbing visible (Ω wired through ┌─ to ▣) | PASS (after fix 1 — the load line itself errored before the fix) |
| 2 | Cursor arrows | State cursor (6,4) and inspector line `CURSOR (6,4)` agree after 2×north/3×east | PASS |
| 3 | SPC ticks ×3 | tick 0→3; workers move, log tail grows | PASS |
| 4 | t / p / K at cursor | toilet: alloy 20→10; pipe: 10→8; tank (fresh game): 20→5; structures render. Note: keyboard builds advance NO tick — pinned by R6 (SPC/RET/click-with-verb only; legacy identical) | PASS |
| 5 | Click unarmed / armed | Unarmed: cursor jumps to clicked cell, tick unchanged. Armed (pipe): alloy −2, tick +1 — exactly one tick | PASS |
| 6 | Demolish own pipe | Cost 3, 50% refund → net −2 alloy; dust intents spawn on the next tick's rewards-eval (M1 consumption is per-tick) | PASS |
| 7 | Purge starter tank | Tank spawns with load 30 (domain fixture); purge recovers +10 alloy (1 per 3 units), load → 0 | PASS |
| 8 | Rewards showcase | Goal card (tier 1, relieves-served 3 → tier-scaled to 2): relieves at tick 51 and 82, MAP COMPLETED banner, 64 ceremony sparkles across the field, `+20` relieve-pay popup drifting up, trophy seed committed | PASS |
| 9 | `?` help + `r` auto-run | Help printed; timer scheduled (`[nil 0 0 200000 … idle]`) and cancelled (nil) by the toggles | PASS (after fix 2 — help CRASHED before the fix) |
| 10 | `n` new game | New seed, regenerated map visibly different from cold start | PASS |

## Defects found and fixed

Commit sequence (fail-first: red test commit precedes each green):

1. **Run line dead on arrival** — `emacs -Q -l src/cistern.el`
   errored `Cannot open load file: cistern-game` because `load`
   never adds the loaded file's directory to `load-path`. Fixed by
   passing the explicit filename to every sibling `require`
   (c1eddcc). A first attempt (top-level `when` bootstrap) was
   rejected by the L-026 source-integrity gate — the gate working
   as designed.
2. **`?` briefing crashed** — `cistern-help` called `princ` with
   the substitution value as the optional print-character function:
   "Invalid function: 20". Any player pressing `?` got an error.
   Same command hardcoded stale prices (toilet "12" vs constant 10,
   decon "4" vs 3). Fixed from the constants (f0124f4). Regression
   tests: `tests/test-smoke-fixes.el` (red commit 54208e3).

Full story: `docs/FAILURE-LEDGER.md` L-034.

## Verified non-defects (pinned readings)

- Keyboard builds tick zero times (R6 spec + legacy).
- Isolated pipe renders `·` (legacy `cistern--pipe-glyph` `t` branch).
- Starter tank load 30 (deliberate fixture, domain:213).
- Tier-1 goal scaling: target 3 completes at 2 relieves
  (`cistern--goal-target`, −25% pay-forward).
- Header prints the live LCG state as "SEED" — verbatim legacy port
  (legacy :732); flagged to the director for the post-playtest
  presentation pass (a player cannot reproduce a run from it).

## Final suite status

`emacs -Q --batch -l tests/run.el -f cistern-run-all-tests`
→ **ALL 34 TESTS PASSED** (32 original + 2 new smoke regressions).

## How a player runs the prototype

```
emacs -Q -l /path/to/cistern/src/cistern.el
M-x cistern
```

Then play in the `*cistern*` buffer — see `PLAYING.md` at the repo root.
