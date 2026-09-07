;;; tests/run.el --- Canonical Cistern test runner -*- lexical-binding: t; -*-

;; Canonical suite entry point (PROCESS-RETRO P3): workers and
;; verifiers run this, never ad-hoc entry-point discovery.
;;
;; Usage: emacs -Q --batch -l tests/run.el -f cistern-run-all-tests

(require 'cl-lib)

(let ((root (file-name-directory
             (directory-file-name
              (file-name-directory (or load-file-name buffer-file-name))))))
  (load (expand-file-name "src/cistern-domain.el" root) nil t)
  (load (expand-file-name "src/cistern-game.el" root) nil t)
  (dolist (f (directory-files (expand-file-name "tests" root)
                              t "\\(domain\\|game\\|test\\)-.*\\.el\\'"))
    (load f nil t)))

(defvar cistern-test-entries
  '(cistern-test-procgen-variety
    cistern-test-table-sourcing
    cistern-test-map-integrity-seeds
    cistern-test-tick-headless
    cistern-test-determinism
    cistern-test-determinism-order
    cistern-test-demolish
    cistern-test-exactly-one-tick
    cistern-test-rewards-default
    cistern-test-cursor-and-click
    cistern-test-legacy-verb-blocks
    cistern-test-r2-keymap
    cistern-test-r1-click
    cistern-test-r6-timer
    cistern-test-r7-glyph
    cistern-test-r5-hook
    cistern-test-4a-losing-breach
    cistern-test-4a-winning-clean
    cistern-test-4a-tutorial
    cistern-test-4a-deterministic
    cistern-test-4b-stream-fixture
    cistern-test-4b-m1-demolish-refund
    cistern-test-4b-m2-solvability
    cistern-test-4b-m3-goal-cards
    cistern-test-4b-m4-reputation
    cistern-test-source-integrity
    cistern-test-4b-m5-relieve-pay
    cistern-test-4b-m6-particle-field
    cistern-test-4b-m7-severity
    cistern-test-4b-m8-milestones
    cistern-test-rewards-consumption
    cistern-test-4b-m9-ceremony
  ;; smoke L-034 regressions (live-driver defects)
    cistern-test-smoke-run-line
    cistern-test-smoke-help-briefing
  ;; UX Round-1 refactor (docs/ux/TOP-30.md, build order)
    cistern-test-ux-q01-header-strip
    cistern-test-ux-q02-score-rep
    cistern-test-ux-q03-starter-card
    cistern-test-ux-q04-goal-progress
    cistern-test-ux-q05-milestone-announce
    cistern-test-ux-q06-popup-protect
    cistern-test-ux-q07-purge-economy
    cistern-test-ux-q08-pressure-gradient
    cistern-test-ux-q11-copy-table
    cistern-test-ux-q09-domain-split
    cistern-test-ux-q10-severed-rewire
    cistern-test-ux-q12-dead-pipe-glyph
    cistern-test-ux-q13-severity-persists
    cistern-test-ux-q16-full-log
    cistern-test-ux-q14-worker-identity))

(defun cistern-run-all-tests ()
  "Run every cistern-test-* entry; exit non-zero on any failure."
  (interactive)
  (let (failed)
    (dolist (test cistern-test-entries)
      (condition-case err
          (progn (funcall test)
                 (message "PASS %s" test))
        (error (push (cons test err) failed)
               (message "FAIL %s: %S" test err))))
    (if failed
        (progn (message "%d/%d FAILED" (length failed)
                        (length cistern-test-entries))
               (kill-emacs 1))
      (message "ALL %d TESTS PASSED" (length cistern-test-entries)))))

(provide 'run)
;;; tests/run.el ends here
