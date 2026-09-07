;;; tests/test-ux-r2.el --- Round-2 UX refactor batch tests (TOP-30-R2) -*- lexical-binding: t; -*-

;; Batch tests for docs/ux/TOP-30-R2.md (R2-Q01..R2-Q15, build
;; order), one entry per directive, registered in tests/run.el.
;; Reds before greens per PROCESS; ledger entries L-060+ in
;; docs/FAILURE-LEDGER.md (§5.3 format).

(require 'cl-lib)

;; Repo root pinned at load time (test-ux-r1 pattern).
(defconst cistern-test-ux2--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-ux-r2 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-ux2--root))
(load (expand-file-name "src/cistern.el" cistern-test-ux2--root))

(defun cistern-test-ux2--plain (s)
  (substring-no-properties s))

(defun cistern-test-ux2--render-lines (st)
  (split-string (cistern-test-ux2--plain (cistern-view--render st)) "\n"))

;; --- R2-Q01: width contract for all permanent rows -------------------------

(defun cistern-test-ux2-q01-width-contract ()
  "Every render row fits 95 cols: the help reflows into two
deliberate rows (all keys visible, arm phrase included), the
legend wraps on a GLYPHS-aligned continuation row (α worker never
orphaned)."
  (let* ((st (cistern--new-game 42))
         (lines (cistern-test-ux2--render-lines st))
         (help-a (nth 1 lines))
         (help-b (nth 2 lines))
         (legend-idx (cl-position-if
                      (lambda (l) (string-match-p "GLYPHS:" l)) lines)))
    ;; the help reflowed into two rows, all keys visible
    (cl-assert (string-match-p "\\[SPC\\]tick" help-a)
               t "row A shows [SPC]tick")
    (cl-assert (string-match-p "cursor" help-a) t "row A is the cursor row")
    (cl-assert (string-match-p "arm — click to place" help-b)
               t "row B carries the Q19 arm phrase")
    (cl-assert (string-match-p "\\[r\\]auto-run" help-b) t "row B shows auto-run")
    (cl-assert (string-match-p "\\[q\\]uit" help-b) t "row B shows quit")
    ;; the legend wrapped: α worker on the continuation, complete
    (cl-assert legend-idx t "legend present")
    (cl-assert (string-match-p "╌ dead pipe" (nth legend-idx lines))
               t "dead pipe listed")
    (cl-assert (string-match-p "α worker" (nth (1+ legend-idx) lines))
               t "α worker on the continuation row, not orphaned")
    (cl-assert (string-match-p "Ω toilet" (nth (1+ legend-idx) lines))
               t "toilet listed on the continuation")
    ;; THE contract: every render row fits 95 cols
    (dolist (row lines)
      (cl-assert (<= (length row) 95)
                 t "render row over 95 cols (len %d): %S"
                 (length row) (substring row 0 (min 40 (length row)))))))

(provide 'test-ux-r2)
;;; test-ux-r2.el ends here
