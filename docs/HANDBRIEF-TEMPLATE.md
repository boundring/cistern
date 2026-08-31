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
- Fail-first: the red test commit precedes the green implementation commit.
- Scope: no code beyond this phase's slice; no formatters, linters, or
  project-wide test runs (siblings may be mid-flight).
- Layer rules per DESIGN-SPEC §3.3; headless determinism per §5.2.

## Failure protocol (reference/roguelike-agentic.md)

- A run that stalls, loops, or operates on a faulty basis is dead: call it
  off, harvest the lesson into `docs/FAILURE-LEDGER.md` (§5.3 format),
  emit a replacement brief with the failure named and the fix.

## Done-when

- <verbatim acceptance criterion from DESIGN-SPEC §4>
