;;; tests/test-smoke-fixes.el --- Regressions from the live-driver smoke -*- lexical-binding: t; -*-

;; Smoke L-034 findings, each one a defect the 32 headless entries
;; could not see because they never load the driver file by path or
;; open the help command:
;;   1. `emacs -Q -l src/cistern.el' could not resolve the sibling
;;      features (load never adds the loaded file's directory to
;;      load-path) — the documented run line died before M-x cistern.
;;   2. `cistern-help' (the `?' command) crashed: two princ calls
;;      passed the substitution value as princ's optional
;;      print-character function ("Invalid function: 20"), and the
;;      controls block hardcoded stale prices.

(require 'cl-lib)
(require 'cistern-domain)
(require 'cistern-game)

(defvar cistern-test-smoke--root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name)))))

(defun cistern-test-smoke-run-line ()
  "Loading the driver file by path (what `emacs -Q -l' does) must
resolve every sibling feature (it errored with file-missing before
the smoke fix)."
  (load (expand-file-name "src/cistern.el" cistern-test-smoke--root))
  (dolist (f '(cistern-domain cistern-game cistern-input cistern-view cistern))
    (cl-assert (featurep f) t "feature %S must be provided after loading src/cistern.el by path" f)))

(defun cistern-test-smoke-help-briefing ()
  "`?' must print the briefing without error (it crashed with
\"Invalid function: 20\" before the smoke fix) and its prices
must come from the cost constants, not stale literals."
  (cistern-help)
  (cl-assert (get-buffer "*cistern help*") t "help command must produce the help buffer")
  (with-current-buffer "*cistern help*"
    (let ((text (buffer-string)))
      (dolist (price (list (format "build toilet (%d)" cistern-cost-toilet)
                           (format "lay pipe (%d)" cistern-cost-pipe)
                           (format "build tank (%d)" cistern-cost-tank)
                           (format "decontaminate (%d)" cistern-cost-decon)
                           (format "demolish (%d)" cistern-cost-demolish)))
        (cl-assert (string-match-p (regexp-quote price) text)
                   t "briefing price %s missing" price))
      (cl-assert (string-match-p
                  (format "At %d the sector is condemned" cistern-contam-limit)
                  text)
                  t "contamination limit line must render")
      (cl-assert (string-match-p
                  (format "Every %d ticks a migrant arrives" cistern-migrant-every)
                  text)
                  t "migrant interval line must render"))))

(provide 'test-smoke-fixes)
;;; test-smoke-fixes.el ends here
