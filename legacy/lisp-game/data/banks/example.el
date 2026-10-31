;;; data/banks/example.el --- V4-14: the one shipped example bank -*- lexical-binding: t; -*-

;; STORY-ENGINE §10: the loader's first fixture and the only bank
;; content shipped beyond the generator's fragment pools.  Size
;; target §10: 1 scenario (2 hooks, 1 matrix), 3 quirks, 2 flavor
;; lines.  Unlike generated banks (one defconst per file, §4.2),
;; this hand-checkable fixture carries its three kinds in one file
;; so the suite can load the whole registry in one call.

(defconst cistern-bank-example
  '(:kind scenario :version "1" :generator "hand (test fixture)"
    :copy
    ((story-sealed-premise . "PRESSURE LOGGED BEHIND EAST WALL")
     (story-seal-creak . "WATCH ORDERED — SEAM (%d,%d) UNDER OBSERVATION")
     (story-seal-creak-fallback . "SEAM (%d,%d) NOTED — NO WATCH ASSIGNED")
     (story-sealed-verdict . "SEAL VERDICT: %s — WATCH DISBANDED")
     (story-sealed-verdict-fallback . "SEAL STANDALONE — WATCH DISBANDED")
     (story-verdict-pass . "STRUCTURE HOLDS")
     (story-verdict-fail . "STRUCTURE WEEPS")
     (story-drip . "A DRIP IS LOGGED — NOBODY IS DISPATCHED"))
    :entries
    ((:id sealed-pressure
      :premise story-sealed-premise
      :acts 3
      :goal-mod (:target-mod ((relieves-served . 2)))
      :hooks
      ((:id seal-creak :act 1 :window (20 . 90)
        :condition (event leak) :requires nil
        :matrix pressure-verdict :resolve-copy story-seal-creak)
       (:id sealed-verdict :act 3 :window (240 . 99999)
        :condition (tick) :requires seal-creak
        :matrix pressure-verdict :resolve-copy story-sealed-verdict))
      :matrices
      ((:id pressure-verdict :difficulty 11 :stat integrity
        :act-mods (0 2 4)
        :outcomes
        ((:line-key story-verdict-fail :effect none :arg nil)
         (:line-key story-verdict-fail :effect none :arg nil)
         (:line-key story-verdict-pass :effect none :arg nil)
         (:line-key story-sealed-verdict :effect none :arg nil))))
      :tiers (60 30 10)
      :events
      ((:id ev-drip :tier occasional :trigger leak
        :matrix pressure-verdict :copy-key story-drip))))))

(defconst cistern-bank-example-quirks
  '(:kind quirk :version "1" :generator "hand (test fixture)"
    :copy
    ((story-quirk-tight . "TOLERANCE FILED AS TIGHT — WITHIN SPEC")
     (story-quirk-thorough . "WORKER READS THE DOSSIER TWICE")
     (story-quirk-loner . "PREFERS UNASSIGNED SECTORS — NOTED"))
    :entries
    ((:id quirk-worker-tight :context tolerance :copy-key story-quirk-tight)
     (:id quirk-worker-thorough :context integrity
      :copy-key story-quirk-thorough)
     (:id quirk-worker-loner :context standing
      :copy-key story-quirk-loner))))

(defconst cistern-bank-example-flavor
  '(:kind flavor :version "1" :generator "hand (test fixture)"
    :copy
    ((story-condensation . "CONDENSATION ON UPPER TERRACE — NOTED")
     (story-sound . "DISTANT VALVE NOISE — ACCOUNTED FOR"))
    :entries
    ((:id fl-condensation :when act-2 :copy-key story-condensation)
     (:id fl-sound :when act-1 :copy-key story-sound))))

(defconst cistern-bank-example-dialogue
  '(:kind dialogue :version "1" :generator "hand (test fixture)"
    :copy
    ((dlg-review-open . "REVIEW: %s FILES A PRESSURE COMPLAINT")
     (dlg-review-wary . "%s: WATCH THE GAUGES — %s AGREES")
     (dlg-review-endorsed . "%s ENDORSES %s — REQUISITION FILED"))
    :entries
    ((:id dlg-pressure-review :actors 2 :tier common :act 1
      :gate (seal-creak . resolved) :as pass
      :pair (stat nerve stat flow)
      :root t :line dlg-review-open
      :branch (:stat nerve :difficulty 10 :matrix dlg-review-verdict
               :next (dlg-review-wary dlg-review-endorsed
                                     dlg-review-wary
                                     dlg-review-endorsed)))
     (:id dlg-review-wary :line dlg-review-wary :root nil
      :branch (:stat flow :difficulty 12 :matrix dlg-review-verdict
               :next (dlg-review-endorsed dlg-review-endorsed
                                          dlg-review-endorsed
                                          dlg-review-endorsed)))
     (:id dlg-review-endorsed :line dlg-review-endorsed :root nil))
    :matrices
    ((:id dlg-review-verdict :difficulty 10 :stat nerve :act-mods (0 0 0)
      :outcomes ((:line-key dlg-review-wary :effect none :arg nil)
                 (:line-key dlg-review-wary :effect none :arg nil)
                 (:line-key dlg-review-endorsed :effect none :arg nil)
                 (:line-key dlg-review-endorsed :effect none :arg nil))))))


(defconst cistern-bank-example-whimsey
  '(:kind whimsey :version "1" :generator "hand (test fixture)"
    :copy
    ((comedy-pipe-complaint . "WORKER %s FILES FORM 7-R AGAINST PIPE SEGMENT %d")
     (comedy-pipe-flagged . "PIPE FLAGGED FOR REVIEW — FORM 7-R ON FILE")
     (comedy-clog-blame . "GOBLIN %s CITES ADDENDUM %s — REVIEW PENDING")
     (comedy-manifold-accent . "MANIFOLD %d ADOPTS A LOCAL DIALECT — REPORTS UNCHANGED")
     (comedy-workers-comp . "CLAIM %d APPROVED — ONE (1) ALLOY DISBURSED TO %s")
     (comedy-aesthetic . "FIXTURE %d DECLINES WORKER %s — AESTHETICS. NO APPEAL.")
     (comedy-duel-1 . "WORKER %s AND ONE (1) RAT EXCHANGE APOLOGIES")
     (comedy-duel-2 . "THE CORRIDOR IS %s'S — THE RAT CONCEDES")
     (comedy-memo . "REGION (%d,%d)-(%d,%d) HEREBY %s — SIGNAGE PENDING")
     (comedy-audit-l . "INVENTORY AUDIT — ONE (1) ALLOY LOCATED")
     (comedy-audit-m . "INVENTORY AUDIT — ONE (1) ALLOY MISPLACED")
     (comedy-queue . "WORKER %s DEFERS TO WORKER %s — THE DOOR REMAINS OPEN")
     (comedy-rivalry . "FIXTURES %d AND %d ENTER COMPETITIVE REVIEW")
     (comedy-rival-jab . "FIXTURE %d CONGRATULATES %d — THROUGH ITS TEETH")
     (comedy-letter-1 . "A PREDECESSOR'S LETTER — 'PRIME THE EAST RUN FIRST'")
     (comedy-letter-2 . "A PREDECESSOR'S LETTER — 'THE SOUTH MANIFOLD LIES'")
     (comedy-letter-3 . "A PREDECESSOR'S LETTER — 'DO NOT NAME THE PIPES'")
     (comedy-drill . "UNSCHEDULED SAFETY DRILL — PLEASE CONTINUE")
     (comedy-drills-tally . "%d UNSCHEDULED DRILLS THIS ACT")
     (comedy-thought-1 . "AUDITED FOUR TIMES, NEVER THANKED.")
     (comedy-thought-2 . "THE PIPES REMEMBER. I DO NOT.")
     (comedy-thought-3 . "THE STRUCTURE FILES EVERYTHING. EVEN THIS.")
     (comedy-thought-4 . "ANOTHER SHIFT. THE TANKS ARE PATIENT.")
     (comedy-thought-5 . "I FILED A COMPLAINT AGAINST THE FLOOR.")
     (comedy-thought-6 . "SECTOR 7: WHERE CAREERS GO TO DRAIN.")
     (comedy-thought-7 . "THE MANIFOLD AND I HAVE AN UNDERSTANDING.")
     (comedy-thought-8 . "NOBODY READS FORM 7-R. I SUBMITTED ANYWAY."))
    :entries
    ((:id pipe-complaint :when (pipes-long) :weight 10 :loud nil
      :cooldown 200 :draws (cast 1 pipe 1) :thread nil
      :footprint (complaint-count) :copy-key comedy-pipe-complaint)
     (:id clog-blame :when (guild-goblins) :weight 8 :loud nil
      :cooldown 200 :draws (goblin 1) :thread t
      :footprint (mutter-push) :copy-key comedy-clog-blame)
     (:id manifold-accent :when (manifold-attached) :weight 6 :loud nil
      :cooldown 300 :draws nil :thread nil
      :footprint (accent-ttl) :copy-key comedy-manifold-accent)
     (:id workers-comp :when (pest-persona) :weight 7 :loud nil
      :cooldown 250 :draws (goblin 1) :thread nil
      :footprint (alloy-delta) :copy-key comedy-workers-comp)
     (:id aesthetic-refusal :when (seeking-2usable) :weight 5 :loud nil
      :cooldown 250 :draws (fixture 1) :thread nil
      :footprint (aesthetic-p) :copy-key comedy-aesthetic)
     (:id formal-duel :when (rat-adjacent) :weight 6 :loud nil
      :cooldown 250 :draws (cast 1) :thread t
      :footprint (xp-delta rat-despawn) :copy-key comedy-duel-1)
     (:id memo-rename :when (always) :weight 5 :loud nil
      :cooldown 300 :draws (name 1) :thread nil
      :footprint (place-names) :copy-key comedy-memo)
     (:id inventory-audit :when (always) :weight 6 :loud nil
      :cooldown 250 :draws (outcome 1) :thread nil
      :footprint (alloy-delta) :copy-key comedy-audit-l)
     (:id queue-etiquette :when (two-workers) :weight 6 :loud nil
      :cooldown 200 :draws (cast 2) :thread nil
      :footprint (mutter-push) :copy-key comedy-queue)
     (:id toilet-rivalry :when (same-type-toilets) :weight 5 :loud nil
      :cooldown 300 :draws nil :thread nil
      :footprint (rival-ttl) :copy-key comedy-rivalry)
     (:id successor-letter :when (demolish-event) :weight 8 :loud nil
      :cooldown 250 :draws (cast 1 letter 1) :thread nil
      :footprint (alloy-delta) :copy-key comedy-letter-1)
     (:id safety-drill :when (always) :weight 4 :loud nil
      :cooldown 300 :draws nil :thread nil
      :footprint (drill-counter) :copy-key comedy-drill))))

(provide 'cistern-bank-example)
;;; data/banks/example.el ends here
