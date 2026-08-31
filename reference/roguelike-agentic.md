# Roguelike agent lifecycle — the death-and-replacement rule

Hngh grows agentically the way a roguelike grows: **a run is cheap, a
death is data, and the successor runs better than the one that died.**
This is central to how Hngh develops, not a nicety.

## The rule

1. **A session that stalls, loops, errors without recovery, or operates
   on a faulty basis is dead.** Call it off ASAP. Do not keep steering a
   dead session — that is the anti-pattern (barking at a corpse).
2. **End the session, reevaluate, reorient, then launch a replacement**
   whose context and instruction set are *informed by the failure*:
   what it needed, where it stalled, what the correction is. The new
   agent starts with a handoff brief that names the failure and the
   fix, not a blank slate.
3. **Any error is a good reason to call off and respawn.** Failed work,
   exploratory tool-calling spirals, token-expensive searches for
   information the brief should have carried, experimental test calls
   that are less efficient than a fresh informed run — all are death
   triggers.

## The session-boundary is a turn-boundary

Ending a session and starting a new one is no more final than a turn
ending and the next beginning. Treat the seam as a rotation point:
- capture the state (what landed, what's uncommitted, what failed);
- harvest the lesson into the failure ledger;
- emit the handoff brief;
- launch the replacement with the corrected context.

## Procedural over agentic, and the hook

When we can predict what an agent's next turn *would* do, and there's a
token-cheap procedural alternative for it (a known file write, a known
script, a known probe), do not let the agent spend tokens on it:
- an attention signal / predictable-next-turn triggers the hook
- **end the session now**, run the procedural call directly,
- **complete evaluation** of the session's partial work,
- **prepare and launch the replacement** with the brief.

This is the continual loop: *let it live, watch it fail, learn from
that, prepare and launch its replacement for success* — self-optimizing
each part, obsessively managing the context any agent gets (feed it
only what the brief needs; never let it re-discover).

## When NOT to respawn

- A turn that is mid-flight and genuinely progressing → steer, don't
  kill (steering is the live corrective; death is for non-recovery).
- A read-only scout whose exploration is cheap and bounded: let it
  finish if its goals are still clear.
The judgment is: *is this agent learning, or just burning?* If the
next step is a correct small step under budget → let it run. If it's
looping, re-failing, or about to spend tokens on something we know how
to do procedurally → die and replace.

## Provenance

2026-08-26: WebDashboard stalled on `style.css` (its write was
interrupted), never recovered; steering once failed to unstick it;
the deliverable was completed by a handoff replacement while the dead
session lingered until cancelled. The rule: cancel at non-recovery,
respawn with a failure-informed brief, never nurse a corpse.