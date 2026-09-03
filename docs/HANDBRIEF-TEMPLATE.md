# Handoff brief — <run-id successor>

> One brief per delegated run. The replacement session gets: this brief,
> `docs/DESIGN-SPEC.md`, and nothing it would have to re-discover.

## Mission

<one requirement + its failing test id>

## Repo state

- Location: `/home/bricker/Projects/etc/20260830/cistern`
- Base commit: <hash>
- Working tree: <clean/dirty; uncommitted files if any>

## Files to read

- <exact paths + line ranges; briefs carry what the run needs, never make it re-discover>

## Constraints

- Least-active-decisions: pin only this phase's decisions; everything
  ambiguous goes to DEFERRED in the run's notes, never into code.
- <commit policy> — planning phases stage-only; implementation
  phases commit per red/green pair (commit-as-you-go is resumable
  state; PROCESS-RETRO P2).
- Fail-first: the red test commit precedes the green implementation commit.
- Scope: no code beyond this phase's slice; no formatters, linters, or
  project-wide test runs (siblings may be mid-flight).
- Layer rules per DESIGN-SPEC §3.3; headless determinism per §5.2.

## Failure protocol (reference/roguelike-agentic.md)

- A run that stalls, loops, or operates on a faulty basis is dead: call it
  off, harvest the lesson into `docs/FAILURE-LEDGER.md` (§5.3 format),
  emit a replacement brief with the failure named and the fix.

## Standing checklist (PROCESS-RETRO P4/P5 — every run, every commit)

- Grep for duplicate defuns before committing (L-005 apply-patch
  misplacement class).
- Run the full suite batch: `emacs -Q --batch -l tests/run.el -f
  cistern-run-all-tests` — the canonical runner, no ad-hoc loops.
- No `sxhash` on structural signatures — hash printed content
  (`secure-hash` over `prin1-to-string`); L-002 depth-limit trap.
- Conservative elisp only — no version-specific APIs (`equal<` does
  not exist in Emacs 31.1 batch; L-006).

Probe rules:

- Unexpected red-pass → strengthen the probe, never manufacture a bug
  (L-006).
- A pass that could be luck → disable-the-guard probe to quantify what
  the assert actually catches (L-004, ~13%).

## Done-when

- <verbatim acceptance criterion from DESIGN-SPEC §4>
