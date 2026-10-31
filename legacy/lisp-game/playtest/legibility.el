;;; playtest/legibility.el --- Legibility-lens render captures (batch) -*- lexical-binding: t; -*-

;; UX collector capture for docs/ux/qualities-legibility.md.  Drives
;; the pure view projection (cistern-view--render) over six states:
;; cold start, tank >=85%, toilet backed up, contamination spreading
;; (3+ hazards), condemned sector, ceremony in progress.  Dumps land
;; in playtest/LEG-NN-<label>.txt.
;;
;; Run from the repo root:
;;   emacs -Q --batch -l src/cistern.el -l playtest/legibility.el \
;;     -f cistern-legibility-run

(require 'cl-lib)

(defvar leg-n 0)

(defun leg-dump (label st)
  "Render ST through the real view projection and dump it."
  (let* ((path (expand-file-name
                (format "LEG-%02d-%s.txt" (setq leg-n (1+ leg-n)) label)
                (file-name-as-directory (expand-file-name "playtest" default-directory)))))
    (with-temp-file path
      (insert (replace-regexp-in-string "\n$" "" (cistern-view--render st))))))

(defun cistern-legibility-run ()
  (let ((st (cistern--new-game 1535244752)))
    ;; 1. cold start
    (leg-dump "cold-start" st)
    ;; 2. tank >=85% (pressure state): starter tank (5,2) at 55/60
    (puthash (cons 5 2) (list :load 55) (cistern-st-tanks st))
    (setf (cistern-st-cursor st) (cons 5 2))
    (cistern--log st "CREATOR RELIEVED AT (3,3)")
    (leg-dump "tank-85pct" st)
    ;; 3. toilet backed up: tank full
    (puthash (cons 5 2) (list :load 60) (cistern-st-tanks st))
    (leg-dump "toilet-backed-up" st)
    ;; 4. contamination spreading: 3+ hazard tiles near the workers
    (dolist (p '((5 5) (4 6) (5 6) (6 5)))
      (cistern--set-cell st (car p) (cadr p) 'hazard))
    (setf (cistern-st-contam st) 5)
    (setf (cistern-st-cursor st) (cons 5 6))
    (cistern--log st "BREACH — CREATOR #2 OVERFLOWED AT (5,6)")
    (cistern--log st "BREACH — CREATOR #3 OVERFLOWED AT (6,5)")
    (leg-dump "contamination-3" st)
    ;; 5. condemned sector
    (setf (cistern-st-cursor st) (cons 3 3))
    (setf (cistern-st-contam st) 20)
    (cistern--phase-check st)
    (leg-dump "condemned" st)
    ;; 6. ceremony in progress: M9 sparkle fill + banner intent
    (dotimes (_ 64)
      (let* ((x (+ 1 (mod (cistern--particle-draw st) (- cistern-w 2))))
             (y (+ 1 (mod (cistern--particle-draw st) (- cistern-h 2))))
             (g (mod (cistern--particle-draw st) 6))
             (glyph (cond ((= g 0) "*") ((= g 1) "!") ((= g 2) "·")
                          ((= g 3) "§")
                          (t (number-to-string (mod (cistern--particle-draw st) 10))))))
        (cistern--field-spawn st (cons x y) (cons 0 0) 6 glyph 'info 'sparkle)))
    (setf (cistern-st-rewards-outcome st)
          (cons '(:score 120 :celebrate t)
                (list (list :layer 'banner :text "MAP COMPLETED"))))
    (leg-dump "ceremony" st))
  (message "legibility: %d renders dumped" leg-n))

(provide 'cistern-legibility)
;;; cistern-legibility.el ends here
