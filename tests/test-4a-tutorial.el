;;; tests/test-4a-tutorial.el --- R4 predicate-table mechanism retained -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-4a-tut-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Repo root; load-file-name is only bound during load.")

(defconst cistern-test-4a-tut-table
  (list
   (cons "step one: purge"
         (lambda (st) (> (cistern-st-purges st) 0)))
   (cons "step two: lay pipe"
         (lambda (st) (> (cistern-st-built-pipe st) 0))))
  "Two-step test table over real state fields: both predicates are
state-driven so steps resolve instantly when already satisfied.")

(defun cistern-test-4a-tut--log-has (st needle)
  (cl-some (lambda (line) (string-match-p needle line))
           (cistern-st-log st)))

(defun cistern-test-4a-tutorial ()
  ;; gate: a failing predicate holds the index — a later step whose
  ;; predicate holds does NOT jump the gate
  (let ((st (cistern--new-game 42)))
    (cl-assert (equal (cistern--tutorial-steps cistern-test-4a-tut-table)
                      cistern-test-4a-tut-table)
               "tutorial steps accept an injectable table")
    (cistern--do-tick st)
    (cl-assert (= (cistern-st-tutorial st) 0)
               "failing predicate holds the index")
    (cl-assert (not (cistern-test-4a-tut--log-has st "OBJECTIVE"))
               "no OBJECTIVE line while gated"))

  ;; advance exactly once per tick; already-satisfied steps resolve
  ;; instantly on their tick (order-free catch-up); completing the
  ;; FINAL step sets the index to `t' with the completion line
  ;; (legacy cistern.el:589-599 semantics)
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-purge st 5 2)          ; step one holds, step two fails
    (cistern--do-tick st)
    (cl-assert (= (cistern-st-tutorial st) 1)
               "satisfied step advances the index exactly once per tick")
    (cl-assert (cistern-test-4a-tut--log-has st "TUTORIAL: OBJECTIVE COMPLETE")
               "advance logs the objective line")
    (cistern--cmd-build st 'pipe 6 2)    ; step two now holds too
    (cistern--do-tick st)
    (cl-assert (eq (cistern-st-tutorial st) t)
               "final step sets the index to done")
    (cl-assert (cistern-test-4a-tut--log-has st
                 "TUTORIAL COMPLETE — THE SECTOR IS YOURS")
               "final step logs the completion line")
    ;; done is terminal: ticks after `t' change nothing
    (cistern--do-tick st)
    (cl-assert (eq (cistern-st-tutorial st) t) "done stays done"))

  ;; T skip: the use-case form marks done so advance is a no-op and
  ;; no further OBJECTIVE lines can log
  (let ((st (cistern--new-game 42)))
    (cl-assert (fboundp 'cistern--cmd-skip-tutorial)
               "skip tutorial exists as a use-case")
    (cistern--cmd-skip-tutorial st)
    (cl-assert (eq (cistern-st-tutorial st) t)
               "skip sets the index to done")
    (cl-assert (cistern-test-4a-tut--log-has st "TUTORIAL SKIPPED")
               "skip logs the skip line")
    (cistern--cmd-purge st 5 2)
    (cistern--cmd-build st 'pipe 6 2)
    (cistern--do-tick st)
    (cl-assert (eq (cistern-st-tutorial st) t)
               "advance is a no-op after skip")
    (cl-assert (not (cistern-test-4a-tut--log-has st "OBJECTIVE"))
               "no OBJECTIVE lines after skip"))

  ;; shipped state: the table is empty — ticks run with zero tutorial
  ;; side effects (Phase 2 invariant, regression-pinned)
  (let ((st (cistern--new-game 42)))
    (cl-assert (null (cistern--tutorial-steps))
               "shipped tutorial table is empty")
    (let ((tick0 (cistern-st-tick st)) (log0 (cistern-st-log st)))
      (cistern--do-tick st)
      (cl-assert (= (cistern-st-tick st) (1+ tick0))
                 "tick runs with an empty table")
      (cl-assert (equal (cistern-st-log st) log0)
                 "empty table: zero tutorial log side effects")))

  ;; static: the driver must not setf the tutorial index directly —
  ;; state mutation belongs in the use-case (armed-verb precedent);
  ;; the T binding routes through the use-case
  (let ((driver (expand-file-name "src/cistern.el" cistern-test-4a-tut-root)))
    (with-temp-buffer
      (insert-file-contents driver)
      (cl-assert (not (search-forward "(setf (cistern-st-tutorial" nil t))
                 "driver must not setf the tutorial index directly")
      (cl-assert (search-forward "cistern--cmd-skip-tutorial" nil t)
                 "driver skip command routes through the use-case")))
  (message "CISTERN-4A-TUTORIAL-OK"))

(provide 'test-4a-tutorial)
;;; tests/test-4a-tutorial.el ends here
