# CISTERN v5 — STALL ANALYSIS (delegated-subagent fleet)

Status: ANALYSIS v1, 2026-09-08. Prepared by stall-inspector for the owner.
Purpose: post-mortem of every recorded subagent stall/death, clustered into
root-cause classes, with TTSR rule drafts (TTSR = Time-Traveling Stream
Rules; matching rules interrupt a streaming generation and inject a
corrective — see oh-my-pi `docs/ttsr-injection-lifecycle.md`) and routing of
everything TTSR cannot see to always-apply/process rules.

Evidence: docs/FAILURE-LEDGER.md (L-001, L-077, L-090, L-095, L-099, L-102),
docs/PROCESS-RETRO.md, and the session transcripts of
v4-architect / impl-v4w1 / design-social(t1) / design-comedy(t1) / impl-v5w1
(final turns sampled, not whole files).

---

## 1. Incident table (stall/death incidents, chronological)

| # | Run | When (UTC) | Duration at death | Tool-call shape at the stall | Error | Recovery used |
|---|-----|------------|-------------------|------------------------------|-------|---------------|
| 1 | plan-core (L-001) | 2026-08-30 | mid-turn, unknown; all source reads done, plan file not started | turn died in the approach to ONE giant plan write; no partial write landed | upstream idle timeout | steer-resume with retained context (no re-brief); plan delivered next turn |
| 2 | v4-architect, death 1 | 09-07 18:20:08 | ~5 min into run; ~20 s into the write's generation | single `write` carrying the ENTIRE V4-SPEC (~370 lines, all sections at once) | upstream timeout, turn cut after grounding | steer-resume → same giant write retried |
| 3 | v4-architect, death 2 | 09-07 18:29:29 | ~15 min in; ~30 s into the second generation | same single giant write, retried unchanged | second upstream timeout, same write | corrective: write §1 only, then `cat >>` section appends (≤~100 lines each); 369-line spec landed in 5 steps, committed 18:32 |
| 4 | design-social (t1) | 09-08 03:16:31 | ~9 min into run; stalled ≤47 s into the write generation | single `write` of the whole SOCIAL.md (final doc: 590 lines) | upstream idle timeout on the doc write | steer-resume + incremental build: 9.4 KB part-1 `write`, then section appends; done 03:28 |
| 5 | design-comedy (t1) | 09-08 03:29:32 | ~8 min into the doc-write attempt | single giant `write` of COMEDY-DIRECTOR.md | upstream idle timeout on the doc write | steer-resume + incremental (write §1, cat-append rest, eval chunk assembly); doc landed |
| 6 | impl-v4w1 (+ its dead prior run, L-077) | 09-07 | mid-batch | SMALL `edit` to tests/run.el (registering a test entry) — aborted TWICE on the same call, then the session idled out (reminder 3/3) | "Tool execution was aborted: Request was aborted" | prior run: full replacement + git-log reconciliation (L-077); uncommitted test drafts recovered, commit-per-directive made the rule |
| 7 | impl-v5w1 network loss | 09-08 07:11:13 | 3 h 08 m into run; turn ≥12 min old | `bash` with an inline `python3 << 'PYEOF'` heredoc REWRITING the whole `cistern--social-thoughts` defun in cistern-game.el — stream died MID-ARGUMENT-GENERATION; tool never executed | `server_error: Network connection lost` (provider stream ended before the tool ran) | steer-resume; git reconcile (rewrite never landed); identical rewrite re-run at 07:16 → succeeded |
| 8 | impl-v5w1 budget stop | 09-08 05:16:18 | 1 h 13 m in, at the 200-request soft budget | paren-corruption thrash IN FLIGHT on tests/test-v5.el: ~10+ `sed -i` line surgeries + python-heredoc re-inserts + check-parens/READ-ERR oscillation (04:26–05:11), then a post-budget python insert broke the file again (05:22) | harness budget notice (not a provider error) | `git checkout` the test file + L-099 protocol: fixtures rebuilt as ONE clean whole-file write; src side (V5-01..04) had been committed green throughout, so the budget stop cost only the fixtures |

Context rows from the ledger that are NOT stalls but were asked about:

| Ref | What | Why it's in scope |
|-----|------|-------------------|
| L-090 | paren disease from hand-written elisp-in-string fixtures | root cause of #8's thrash; fixed by programmatic bank emission with `%S` |
| L-095 | bank loader shipped, never wired (suite green, product no-op) | a quality-class failure the stall rules cannot see; needs an always-apply checklist item |
| L-102 | keyword/symbol silent fall-through (wrong-answer, not error) | same class as L-095; always-apply only |

---

## 2. The surviving contrast (why per-call size is the variable)

impl-v5w1 ran **3+ hours and 200+ requests of turns built from up to ~300
small tool calls each** (suite runs, greps, small edits, one-message appends)
and never stalled on them. Every mid-stream death in the fleet happened while
the provider was generating **one long single tool call**: a whole-document
`write` (#2–#5), a whole-defun python-heredoc bash argument (#7), or — for
#1, whose write never started — the read-then-write plan turn whose write was
destined to be giant. The only death with a SMALL call (#6) was a
provider-side request abort, a different class. Conclusion: the
stall-generator is **payload size per generation**, not turn length. This is
exactly the observable TTSR can police.

---

## 3. Root-cause classes

### Class A — Giant single-call generation (upstream idle timeout mid-args)
Incidents #1–#5. The provider stalls while streaming one huge tool call; the
harness idle-timeouts; everything not yet persisted is lost (here: nothing
was persisted, so only time was lost). Root cause: task shape — "write the
whole doc/file in one call". The proven corrective (used by all four
recoveries) is incremental section-by-section landing. **TTSR-EXPRESSIBLE**
(three rules below, R1/R2).

### Class B — Provider request abort / network loss
Incident #6 (small call, aborted twice — pure provider flake) and the
network-loss half of #7. **NOT TTSR-EXPRESSIBLE for the small-call variant**:
nothing in the stream identifies it; TTSR matches streamed content, and a
tiny edit carries no signature. The mitigations are process: steer-resume
first, replacement run second, git-log reconciliation instead of trusting
narration (L-077), commit-per-directive so a death costs one directive.
The large-argument variant of #7 IS pre-emptable by R2 (below), which aborts
the call before the long generation can die mid-flight.

### Class C — Elisp assembly thrash (paren corruption loop)
Incident #8 (and its precursor #7's python rewrites). Signature: repeated
`sed -i` line-number surgery + python-heredoc re-inserts + check-parens
oscillation on the same `.el` file, burning requests until the budget fires
mid-thrash. Root cause: assembling elisp via heredoc+sed instead of one
whole-file write (L-017 class, encoded as the L-099 protocol). The
budget stop itself is harness-side and invisible to TTSR, but the thrash
signature IS stream-visible. **PARTIALLY TTSR-EXPRESSIBLE** (R3 below, with
one stated ceiling).

### Class D — Silent wrong-answer / unwired machinery (non-stall)
L-095, L-102. No stream signature; detected only by probes. Route to
always-apply rules. **NOT TTSR-EXPRESSIBLE.**

---

## 4. TTSR-expressible verdicts and draft rules

All conditions were compiled and exercised against the evidence: each fires
on the observed death shape and does NOT fire on the observed survivor
shapes (253-line heredoc append; 9.4 KB / 11.3 KB part-writes; `sed -n`
reads). Default settings per the lifecycle doc: `contextMode: discard`,
`interruptMode: always`, `repeatMode: once` — overridden below where noted.

### R1 — `giant-single-write` (Class A; kills incidents #1–#5)

- **scope**: `tool:write`, `tool:edit` (edit's reconstructed snapshot sees
  added lines only — the same regex applies).
- **condition** (regex, compiles ✓):
  ```
  \n(?:[^\n]*\n){300,}
  ```
  (≥300 streamed newlines inside the call payload. Calibration: the failed
  generations were ≥369-line single writes; the largest observed survivor
  was a 253-line heredoc append and an 11.3 KB fragment write. 300 lines
  separates death from survival with margin.)
- **interruptMode**: `always` — abort mid-args, before the upstream can idle
  out; nothing has executed yet, so aborting is free.
- **contextMode**: `discard` — the partial giant payload is worthless; drop
  it so the retry doesn't inherit a half-formed call.
- **repeatMode**: `after-gap`, `repeatGap: 10` — a worker legitimately
  landing a big file once shouldn't be nagged every turn; after 10 quiet
  turns it re-arms.
- **globs**: none (payload-based, any file; docs and tests die the same way).
- **body**:
  > DEATH SHAPE (observed ×4, incidents #1–#5): one tool call generating
  ≥300 lines stalls the provider mid-generation and the whole payload is
  lost. ABORT this call. Land the same content incrementally: one
  section/fragment per call (≤~100 lines), each landed and verified before
  the next — the V4-SPEC recovery pattern. Never grow a single call past
  ~300 lines.

### R2 — `python-heredoc-file-rewrite` (Class A/B large-arg variant; pre-empts #7)

- **scope**: `tool:bash`.
- **condition** (regex, compiles ✓):
  ```
  python3?\s+(?:-c\s+)?<<-?\s*['"]?\w+['"]?[\s\S]{200,}
  ```
  (inline `python3 << HEREDOC` with a ≥200-char body — the whole-defun
  rewrite shape that died mid-generation at #7 and repeatedly mis-escaped
  quotes at #8. Deliberately does NOT match `cat >> f << 'EOF'` section
  appends, which are the sanctioned incremental landing method.)
- **interruptMode**: `always`.
- **contextMode**: `discard`.
- **repeatMode**: `after-gap`, `repeatGap: 10`.
- **body**:
  > Inline python heredoc rewriting files in place is the observed
  network-loss + paren-corruption shape (L-099, L-017): the provider died
  mid-generation of exactly this call. Prefer an `edit`/apply_patch, or ONE
  clean whole-file `write` of the fragment, then re-load and check-parens
  once. (The L-099 "python whole-file template" remains legal — as a
  single clean write, not repeated in-place surgery.)

### R3 — `elisp-line-surgery` (Class C thrash signature; early warning for #8)

- **scope**: `tool:bash`. NOTE: `globs` is unusable here — bash has no
  top-level path argument for the global path gate, so the regex must match
  the command text itself.
- **condition** (regex, compiles ✓):
  ```
  \bsed\s+-[a-zA-Z]*i[a-zA-Z]*\b
  ```
  (`sed -i` anywhere in the args; `sed -n` reads are untouched.)
- **interruptMode**: `always` — abort before the surgery call executes and
  re-inject the protocol.
- **contextMode**: `discard`.
- **repeatMode**: `after-gap`, `repeatGap: 2` — the thrash loop is
  sed→check-parens→sed; a 2-turn gap makes the rule re-fire roughly every
  loop iteration once the run has quieted between surgeries, so a one-off
  surgical fix passes but a whack-a-mole loop gets hammered.
- **body**:
  > Line surgery on an elisp file (the L-099 thrash signature: repeated
  `sed -i` + check-parens oscillation burns the request budget). STOP.
  Rebuild the file in ONE whole-file `write` (or one python whole-file
  template), run check-parens once, then re-capture red/green.
- **stated ceiling**: TTSR cannot count "N surgeries on the SAME file"
  across calls — matching is per-call, and `repeatMode` counts turns, not
  per-file occurrences. This rule approximates the detector (fires per
  occurrence, re-armed every 2 turns). True per-file repetition counting
  belongs in the harness/extension layer if the approximation proves noisy.
  `ponytail:` note — approximation accepted; upgrade path is a
  ttsr_triggered-listening extension that aggregates occurrences per path.

---

## 5. Non-expressible items → always-apply rules / harness

| Item | Why TTSR can't see it | Routed rule (always-apply) |
|------|----------------------|---------------------------|
| #6 provider request aborts on small calls | no in-stream signature; the call is tiny and the abort is provider-side | **steer-resume-first**: on any aborted/error turn, the director's first corrective is steer-resume (context retained), replacement run only if resume fails; L-001 protocol, standing |
| #6 idle-out after aborted turn (reminder 3/3) | the death was the session idling AFTER a provider abort — a harness cadence issue, not stream content | **commit-per-directive** (L-077 change): never hold more than one directive uncommitted, so a death costs one directive |
| #8 budget stop itself (200/300-request notice) | request counts are harness-side; no stream regex can see "how many requests" | keep the harness budget; the THrash precursor is R3. Additionally: **budget-stop recovery = reconcile via `git log`, never narration** (L-077: a run's own narration claimed a commit that had/hadn't landed — verify against git) |
| L-095 wired-machinery-never-powered | a missing CALLER is invisible in any single stream | **shipped-surface probe**: every new domain entry point that ships must show one live driver-path invocation in the same directive (or an explicit PROTECT deferral), not just unit tests that call it directly |
| L-102 silent keyword/symbol fall-through | wrong-answer, not an error; nothing in the stream flags it | existing probe discipline (P5 disable-the-guard / SC probes); already standing |
| Class A residual: stall BELOW the R1 threshold (e.g. generation dies on a <300-line write, or stalls in thinking/prose) | TTSR only sees matched content; a small generation that stalls carries no detectable signature until it's too late | **incremental-by-default for docs**: directors brief any doc ≥ ~250 lines as "one section per append, never one giant generation" up front (the corrective already used 4/4 times) — belt and braces alongside R1 |

---

## 6. Answers to the two standing questions

1. **Is the paren-thrash a TTSR-detectable precursor worth a rule?** Yes —
   partially. `sed -i` on an el file mid-flight is exactly what R3 catches,
   and after-gap(2) re-arming approximates "repeated surgery". The honest
   ceiling: TTSR is per-call and counts turns, not same-file repetition; the
   full "≥3 surgeries on one file" counter needs a harness extension
   listening to `ttsr_triggered`. R3 as drafted is the cheap 80% version.
2. **Would R1/R2 have prevented the observed deaths?** #2–#5 (all giant
   writes) — yes, R1 aborts each before the upstream idles out, and the
   injected body text names the exact incremental protocol the recoveries
   used. #7 — yes with R2: the call was aborted before its long
   argument generation could die on the network. #6 and #1-pre-write — no
   (class B small-call abort; pre-write read turn) — those stay with the
   steer-resume/commit-per-directive process rules.

Incident count: 8 stall/death incidents (+3 ledger context rows). Classes:
A giant-single-call generation, B provider abort/network loss, C elisp
assembly thrash, D silent wrong-answer. Top 3 proposed rules: R1
giant-single-write, R2 python-heredoc-file-rewrite, R3 elisp-line-surgery.
