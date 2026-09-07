;;; tests/test-4a-scenarios.el --- R4 tutorial scenarios, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun cistern-test-4a-losing-breach ()
  ;; the runner and the scenario are there; the scenario is DATA at the
  ;; plan-pinned seed (plan 03 §4a pair 1)
  (cl-assert (fboundp 'cistern-tutorial-run-scenario)
             "scenario runner exists")
  (cl-assert (boundp 'cistern-tutorial-scenario-losing)
             "losing scenario data exists")
  (cl-assert (= 42 (plist-get cistern-tutorial-scenario-losing :seed))
             "losing scenario runs at seed 42")
  ;; scripted replay reaches the breach headlessly: contamination > 0,
  ;; the breach itself in the log, and the lesson stated
  (let* ((st (cistern-tutorial-run-scenario cistern-tutorial-scenario-losing))
         (log (cistern-st-log st)))
    (cl-assert (> (cistern-st-contam st) 0)
               "scripted losing scenario reaches a bladder breach")
    (cl-assert (cl-some (lambda (line)
                          (string-match-p "BREACH" (car line)))
                        log)
               "the breach itself is in the log")
    (cl-assert (cl-some (lambda (line)
                          (string-match-p "lesson" (downcase (car line))))
                        log)
               "lesson log entry states the infrastructure lesson"))
  (message "CISTERN-4A-LOSING-OK"))

(defun cistern-test-4a-winning-clean ()
  ;; same seed as the losing scenario — the fair before/after pair is
  ;; the SAME seed's need served, not a different failure avoided
  (cl-assert (boundp 'cistern-tutorial-scenario-winning)
             "winning scenario data exists")
  (cl-assert (= 42 (plist-get cistern-tutorial-scenario-winning :seed))
             "winning scenario runs at the same seed 42")
  (let* ((st (cistern-tutorial-run-scenario cistern-tutorial-scenario-winning))
         (served (cistern--tank-load-total st)))
    ;; the counter is monotonic (only ever incremented: accident and
    ;; severed-finish-use), so a clean FINAL state proves contamination
    ;; stayed 0 through and at end of the script
    (cl-assert (= (cistern-st-contam st) 0)
               "winning scenario keeps contamination 0")
    (cl-assert (null (cistern-st-over st))
               "sector survives the horizon")
    ;; the need was actually SERVED, not avoided: waste flowed through
    ;; the wired network after the purge reset the starter tank — four
    ;; deposits means every original creator was relieved
    (cl-assert (>= served 40)
               "all four creators relieved through the wired network"))
  (message "CISTERN-4A-WINNING-OK"))

(defun cistern-test-4a-det--hash (st)
  "Full-state fingerprint (L-002): hash PRINTED content, never a
structural signature.  prin1-to-string of the whole state object
covers map vector, both hashes' keys+values, worker fields,
counters, rng, log."
  (secure-hash 'sha1 (prin1-to-string st)))

(defun cistern-test-4a-det--reseeded (scenario seed)
  "SCENARIO data with SEED swapped in (same script/lesson/expect)."
  (list :name (plist-get scenario :name)
        :seed seed
        :script (plist-get scenario :script)
        :lesson (plist-get scenario :lesson)
        :expect (plist-get scenario :expect)))

(defun cistern-test-4a-det--with-script (scenario script)
  "SCENARIO data with SCRIPT swapped in (same seed/lesson/expect)."
  (list :name (plist-get scenario :name)
        :seed (plist-get scenario :seed)
        :script script
        :lesson (plist-get scenario :lesson)
        :expect (plist-get scenario :expect)))

(defun cistern-test-4a-deterministic ()
  ;; replay identity: each scenario run twice at its seed yields a
  ;; byte-identical final state (spec §5.2 applied to scenarios)
  (let* ((l1 (cistern-tutorial-run-scenario cistern-tutorial-scenario-losing))
         (l2 (cistern-tutorial-run-scenario cistern-tutorial-scenario-losing))
         (w1 (cistern-tutorial-run-scenario cistern-tutorial-scenario-winning))
         (w2 (cistern-tutorial-run-scenario cistern-tutorial-scenario-winning))
         (lh1 (cistern-test-4a-det--hash l1)) (lh2 (cistern-test-4a-det--hash l2))
         (wh1 (cistern-test-4a-det--hash w1)) (wh2 (cistern-test-4a-det--hash w2)))
    (cl-assert (string= lh1 lh2)
               "losing scenario replays byte-identical at its seed")
    (cl-assert (string= wh1 wh2)
               "winning scenario replays byte-identical at its seed")

    ;; discriminative arms (L-004: quantify what the assert catches —
    ;; a comparator that never fires is decoration)
    (cl-assert (not (string= lh1
                             (cistern-test-4a-det--hash
                              (cistern-tutorial-run-scenario
                               (cistern-test-4a-det--reseeded
                                cistern-tutorial-scenario-losing 43)))))
               "different seed diverges the losing trajectory")
    (cl-assert (not (string= wh1
                             (cistern-test-4a-det--hash
                              (cistern-tutorial-run-scenario
                               (cistern-test-4a-det--reseeded
                                cistern-tutorial-scenario-winning 43)))))
               "different seed diverges the winning trajectory")
    (cl-assert (not (string= lh1 wh1))
               "losing and winning trajectories differ at the same seed")

    ;; order/chunking tripwire, anchored to the losing scenario's own
    ;; verb step: chunked waits (30+25 = 55) are semantically
    ;; equivalent and MUST hash identical; swapping the verb after the
    ;; waits is a different trajectory and MUST hash different — the
    ;; comparator sees step-execution order
    (let* ((lose-verb (car (plist-get cistern-tutorial-scenario-losing
                                      :script)))
           (chunked (cistern-tutorial-run-scenario
                     (cistern-test-4a-det--with-script
                      cistern-tutorial-scenario-losing
                      (list lose-verb '(wait . 30) '(wait . 25)))))
           (swapped (cistern-tutorial-run-scenario
                     (cistern-test-4a-det--with-script
                      cistern-tutorial-scenario-losing
                      (cons '(wait . 55) (list lose-verb))))))
      (cl-assert (string= lh1 (cistern-test-4a-det--hash chunked))
                 "equivalent wait chunking is invisible to the replay")
      (cl-assert (not (string= lh1 (cistern-test-4a-det--hash swapped)))
                 "step order is visible: swapped script diverges")))
  (message "CISTERN-4A-DETERMINISTIC-OK"))

(provide 'test-4a-scenarios)
;;; tests/test-4a-scenarios.el ends here
