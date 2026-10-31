# v6 handoff — queue accepted

The Cistern v6 directive queue (docs/v6/V6-SPEC.md, 21 directives) is
accepted and indexed by the Hngh intake system:

- **Queue of record:** hngh repo, `docs/project/cistern-intake/` —
  `QUEUE.md` (index, wave gates, L-112 halt-state verbatim, backlog),
  `README.md` (acceptance charter), `P01.md`..`P21.md` (one packet per
  directive; packets carry pointers, not copies — the contracts here stay
  single-source).

- **Status at handoff** (ledger L-112): V6-01 LANDED (d059270), V6-02
  LANDED (beb3fff), V6-03 NOT STARTED — P03 is the head packet and
  executes L-112's recovery block verbatim.

- Hngh cycles claim one packet at a time, execute per its embedded brief
  under the standing rules (fail-first red/green, commit-per-green, ledger
  harvest, death-and-replacement, green-boundary sync), and record
  outcomes in the packet's Outcome section + QUEUE.md's status column;
  failure records land here in `docs/FAILURE-LEDGER.md` (next entry L-113).
