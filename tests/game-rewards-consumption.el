;;; tests/game-rewards-consumption.el --- R5 REWARDS-DESIGN consumption -*- lexical-binding: t; -*-

;; INTENTIONALLY RED until Phase 4b (spec §4 R5, plan 01 §2.1 Pair 3):
;; REWARDS-DESIGN.md drives non-default outcomes; the Phase 2
;; placeholder returns the default plist, so these asserts fail by
;; design.  NOT registered in tests/run.el cistern-test-entries —
;; the canonical runner must stay green for Pairs 4-5.  When 4b lands
;; the consumption, register this entry.

(require 'cl-lib)

(defun cistern-test-rewards-consumption ()
  ;; M8 milestone ladder: crossing 5 cumulative relieves-served unlocks
  ;; big-cistern, emits UnlockEmitted exactly once, persists in state.
  (let* ((st (cistern--new-game 42))
         (events (make-list 5 'relief))
         (result (cistern--rewards-eval st events))
         (outcome (nth 1 result))
         (intents (nth 2 result)))
    (cl-assert (member 'big-cistern (plist-get outcome :unlocks))
               "5 relieves cross the first milestone threshold")
    (cl-assert (assq 'unlock intents)
               "UnlockEmitted emitted as a presentation intent")
    (let* ((replay (cistern--rewards-eval st events))
           (outcome2 (nth 1 replay)))
      (cl-assert (equal (plist-get outcome2 :unlocks)
                        (plist-get outcome :unlocks))
                 "milestone crossed exactly once"))

    ;; M5 relieve-pay: relief events pay, score drifts off zero.
    (let* ((st2 (cistern--new-game 43))
           ;; payload vocabulary (L-028): the relief event carries
           ;; urgency + tile; bladder 70 is inside the warning window
           (paid (cistern--rewards-eval st2 (list (list 'relief 70 3 3)))))
      (cl-assert (> (plist-get (nth 1 paid) :score) 0)
                 "relief within the warning window pays"))

    ;; milestone ladder top: 100 relieves → golden-pipe + full-buffer
    ;; celebration (REWARDS-DESIGN §2 threshold line).
    (let* ((st3 (cistern--new-game 44))
           (top (cistern--rewards-eval st3 (make-list 100 'relief)))
           (outcome3 (nth 1 top)))
      (cl-assert (member 'golden-pipe (plist-get outcome3 :unlocks))
                 "100 relieves unlock golden-pipe")
      (cl-assert (plist-get outcome3 :celebrate)
                 "ladder-top crossing celebrates (full buffer)"))))

(provide 'game-rewards-consumption)
;;; tests/game-rewards-consumption.el ends here
