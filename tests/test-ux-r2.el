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
    (cl-assert (string-match-p "move" help-a) t "row A is the cursor row")
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
    (cl-assert (string-match-p "▣ tank" (nth (1+ legend-idx) lines))
               t "tank listed on the continuation")
    ;; THE contract: every render row fits 95 cols
    (dolist (row lines)
      (cl-assert (<= (length row) 95)
                 t "render row over 95 cols (len %d): %S"
                 (length row) (substring row 0 (min 40 (length row)))))))

;; --- R2-Q02: badge budget + header-append contract ---------------------------

(defun cistern-test-ux2-q02-badge-geometry ()
  "The badges live on ONE reserved dim row directly below the
strip; the block height is one constant both the renderer and
cell-at derive from (cold 3, badge live 4); the condemn append is
short.  THE probe: with the badge row live, cell-at of the map's
first cell is unchanged."
  (let ((st (cistern--new-game 42)))
    ;; cold: strip + two help rows = 3; the map starts at line 4
    (cl-assert (= (cistern-view--header-block-height st) 3)
               t "cold block height is 3")
    (cl-assert (equal (cistern-view--cell-at st 4 0) '(0 . 0))
               t "cold: map's first cell at line 4")
    ;; armed: the badge row is line 2, the map starts at line 5
    (cistern--cmd-arm-verb st 'pipe)
    (setf (cistern-st-auto-run st) t)
    (cl-assert (= (cistern-view--header-block-height st) 4)
               t "badge live: block height 4")
    (let ((lines (cistern-test-ux2--render-lines st)))
      (cl-assert (string= (nth 0 lines)
                          (cistern-test-ux2--plain
                           (cistern-view--header-line st)))
                 t "the strip is line 0")
      (cl-assert (string-match-p "ARMED: PIPE" (nth 1 lines))
                 t "the badge row sits directly below the strip")
      (cl-assert (string-match-p "AUTO-RUN" (nth 1 lines))
                 t "armed and auto-run coexist on the one badge row")
      (cl-assert (string-match-p "\\[SPC\\]tick" (nth 2 lines))
                 t "help row A follows the badge row")
      (dolist (row lines)
        (cl-assert (<= (length row) 95)
                   t "badge-live row over 95 cols")))
    ;; THE geometry probe: cell-at of the map's first cell, badge live
    (cl-assert (equal (cistern-view--cell-at st 5 0) '(0 . 0))
               t "badge live: map's first cell at line 5 — clicks land")
    ;; the condemn append is short
    (setf (cistern-st-over st) "SECTOR CONDEMNED — CONTAMINATION LIMIT")
    (cl-assert (string-match-p "!! CONDEMNED"
                               (cistern-test-ux2--plain
                                (cistern-view--header-line st)))
               t "condemn append shortened")
    (cl-assert (null (string-match-p "SECTOR CONDEMNED — CONTAM"
                                     (cistern-test-ux2--plain
                                      (cistern-view--header-line st))))
               t "the long cause lives on the death panel, not the strip")))

;; --- R2-Q03: one copy table, one verb -------------------------------------------

(defun cistern-test-ux2--string-count (s file)
  "Occurrences of S in FILE via split-count (how-many chokes on
multibyte literals)."
  (with-temp-buffer
    (insert-file-contents file)
    (1- (length (split-string (buffer-string) s)))))

(defun cistern-test-ux2-q03-copy-sweep ()
  "RESTART everywhere (zero NEW GAME), the TUTORIAL strings live
only in `cistern--copy', and the idle pressure line stays
byte-identical."
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-contam st) cistern-contam-limit)
    (with-temp-buffer
      (dotimes (_ 3) (cistern-tick)))
    (dolist (e (cistern-st-log st))
      (when (string-match-p "PRESS n" (car e))
        (cl-assert (string-match-p "PRESS n TO RESTART" (car e))
                   t "every PRESS n occurrence says RESTART")
        (cl-assert (null (string-match-p "NEW GAME" (car e)))
                   t "no NEW GAME wording left")))
  ;; the idle line is checked on a LIVE game (the condemned state
  ;; reads the panel line, not the idle line)
  (let ((st (cistern--new-game 42)))
    (cl-assert (string= (cistern-view--pressure-line st)
                        "LINES NOMINAL — THE STRUCTURE DOES NOT CARE")
               t "idle pressure line byte-identical")))
  (dolist (key '(restart-log tutorial-complete tutorial-step
                 tutorial-skipped tutorial-line-fmt))
    (let ((s (cdr (assq key cistern--copy))))
      (cl-assert (stringp s) t "copy key %S present" key)
      (dolist (f (directory-files (expand-file-name "src"
                                                    cistern-test-ux2--root)
                                  t "\\.el\\'"))
        (unless (string-match-p "cistern-domain" f)
          (cl-assert (= 0 (cistern-test-ux2--string-count s f))
                     t "copy %S drifted outside the table" s))))))

(provide 'test-ux-r2)
;;; test-ux-r2.el ends here
