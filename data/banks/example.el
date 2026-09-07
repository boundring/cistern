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

(provide 'cistern-bank-example)
;;; data/banks/example.el ends here
