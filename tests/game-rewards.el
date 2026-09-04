;;; tests/game-rewards.el --- R5 rewards-eval placeholder, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-rewards-default-outcome
  '(:score 0 :objectives nil :unlocks nil :celebrate nil)
  "The pinned placeholder outcome (spec §4 R5; REWARDS-DESIGN §5).")

(defun cistern-test-rewards-default ()
  (cl-assert (fboundp 'cistern--rewards-eval) "rewards-eval exists")
  (let* ((st (cistern--new-game 42))
         (rng0 (cistern-st-rng st))
         (tick0 (cistern-st-tick st))
         (alloy0 (cistern-st-alloy st))
         (result (cistern--rewards-eval st nil))
         (st2 (nth 0 result))
         (outcome (nth 1 result))
         (intents (nth 2 result)))
    ;; fresh state + no events ⇒ unchanged state, default outcome, no intents
    (cl-assert (eq st2 st) "state returned (in-place threading)")
    (cl-assert (equal outcome cistern-test-rewards-default-outcome)
               "default outcome plist verbatim")
    (cl-assert (null intents) "empty presentation intents")
    (cl-assert (= (cistern-st-rng st2) rng0) "sim LCG untouched")
    (cl-assert (= (cistern-st-tick st2) tick0) "tick untouched")
    (cl-assert (= (cistern-st-alloy st2) alloy0) "alloy untouched")

    ;; events with no matching goal card: no score drift, no RNG consumption
    (let* ((result (cistern--rewards-eval st '(relief burst leak)))
           (outcome (nth 1 result))
           (intents (nth 2 result)))
      (cl-assert (equal outcome cistern-test-rewards-default-outcome)
                 "no matched goal: no score drift")
      (cl-assert (null intents) "no unmatched-event intents")
      (cl-assert (= (cistern-st-rng st) rng0)
                 "rewards garnish must never consume the sim LCG \
(REWARDS-DESIGN §4: seed⊕stream-id child stream)")
      (cl-assert (= (cistern-st-tick st) tick0)))
    (cl-assert (= (cistern-st-tick st) tick0) "still exactly one layer of no-op"))

  (message "CISTERN-REWARDS-DEFAULT-OK"))

(provide 'game-rewards)
;;; tests/game-rewards.el ends here
