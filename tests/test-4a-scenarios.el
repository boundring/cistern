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
                          (string-match-p "BREACH" line))
                        log)
               "the breach itself is in the log")
    (cl-assert (cl-some (lambda (line)
                          (string-match-p "lesson" (downcase line)))
                        log)
               "lesson log entry states the infrastructure lesson"))
  (message "CISTERN-4A-LOSING-OK"))

(provide 'test-4a-scenarios)
;;; tests/test-4a-scenarios.el ends here
