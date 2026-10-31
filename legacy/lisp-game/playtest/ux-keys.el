;;; playtest/ux-keys.el --- UX collector: count keypresses for real tasks -*- lexical-binding: t; -*-
;; Run: emacs -Q --batch -l src/cistern.el -l playtest/ux-keys.el -f cistern-ux-keys-run

(require 'cl-lib)

(defvar ux-presses 0)
(defvar ux-notes nil)

(defun ux-note (fmt &rest args)
  (setq ux-notes (append ux-notes (list (apply #'format fmt args))))
  (apply #'message fmt args))

(defun ux-press (sym)
  (setq ux-presses (1+ ux-presses))
  (call-interactively sym))

(defun ux-mouse-click (x y)
  (setq ux-presses (1+ ux-presses))
  (cistern-input-click cistern--st x y)
  (cistern--refresh))

(defun ux-log-tail ()
  (with-current-buffer "*cistern*"
    (goto-char (point-max))
    (forward-line -3)
    (buffer-substring (point) (point-max))))

(defun ux-find-floor-far ()
  (let ((st cistern--st) best)
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (let ((d (+ (abs (- x 1)) (abs (- y 1)))))
          (when (and (eq (cistern--cell st x y) 'floor)
                     (> d 10)
                     (or (null best) (> d (cdr best))))
            (setq best (cons (cons x y) d))))))
    (car best)))

(defun ux-cursor-to (x y)
  "Move cursor via keyboard presses; returns presses used."
  (let ((start ux-presses))
    (while (< (car (cistern-st-cursor cistern--st)) x) (ux-press 'cistern-cursor-east))
    (while (< (cdr (cistern-st-cursor cistern--st)) y) (ux-press 'cistern-cursor-south))
    (while (> (car (cistern-st-cursor cistern--st)) x) (ux-press 'cistern-cursor-west))
    (while (> (cdr (cistern-st-cursor cistern--st)) y) (ux-press 'cistern-cursor-north))
    (- ux-presses start)))

(defun ux-inspector ()
  (with-current-buffer "*cistern*"
    (goto-char (point-min))
    (if (re-search-forward "^CURSOR" nil t)
        (buffer-substring (line-beginning-position) (line-end-position))
      "NO INSPECTOR")))

(defun cistern-ux-keys-run ()
  (interactive)
  (cistern)
  (let ((st cistern--st))
    ;; ---- T1: why was the build refused? ----
    (let (wall)
      (catch 'found
        (dotimes (y (cistern-st-h st))
          (dotimes (x (cistern-st-w st))
            (when (eq (cistern--cell st x y) 'wall)
              (setq wall (cons x y))
              (throw 'found t)))))
      (setq ux-presses 0)
      (ux-cursor-to (car wall) (cdr wall))
      (ux-press 'cistern-build-toilet)
      (ux-note "T1a build-on-wall: %d presses total; visible log tail: %S; armed-verb now: %S"
               ux-presses (ux-log-tail) (cistern-st-armed-verb st))
      (setq ux-presses 0)
      (setf (cistern-st-alloy st) 0)
      (let ((spot (ux-find-floor-far)))
        (ux-cursor-to (car spot) (cdr spot))
        (cistern--set-cell st (car spot) (cdr spot) 'floor)
        (ux-press 'cistern-build-pipe)
        (ux-note "T1b insufficient-alloy: %d presses; inspector=%S" ux-presses (ux-inspector))))
    ;; ---- T2: toilet + 5-cell pipe run from network ----
    (setf (cistern-st-alloy st) 500)
    (setq ux-presses 0)
    (let* ((spot (ux-find-floor-far))
           (sx (car spot)) (sy (cdr spot))
           (travel (ux-cursor-to sx sy)))
      (ux-press 'cistern-build-toilet)   ; arm + place at cursor
      (ux-press 'cistern-build-pipe)     ; arm pipe (also places 1st pipe)
      (dotimes (i 4)
        (ux-mouse-click (- sx 1 i) sy))  ; arm-and-place via click, 4 more pipes
      (ux-note "T2 toilet+5-pipe at (%d,%d): travel %d + 6 build presses = %d; armed=%S"
               sx sy travel ux-presses (cistern-st-armed-verb st))
      (ux-note "    log tail: %S" (ux-log-tail)))
    ;; ---- T3: recover from backed-up tank ----
    (maphash (lambda (k _v) (puthash k (list :load cistern-tank-cap) (cistern-st-tanks st)))
             (cistern-st-tanks st))
    (setq ux-presses 0)
    (let (tk)
      (maphash (lambda (k _v) (unless tk (setq tk k))) (cistern-st-tanks st))
      (let ((n (ux-cursor-to (car tk) (cdr tk))))
        (ux-press 'cistern-purge)
        (ux-note "T3 purge full tank: travel %d + 1 = %d presses; log tail: %S"
                 n ux-presses (ux-log-tail))
        (ux-note "    pressure line via inspector: %S" (ux-inspector))))
    ;; ---- T4: fix a breach ----
    (setq ux-presses 0)
    (let (hx hy)
      (catch 'hz
        (dotimes (y (cistern-st-h st))
          (dotimes (x (cistern-st-w st))
            (when (eq (cistern--cell st x y) 'hazard)
              (setq hx x hy y)
              (throw 'hz t)))))
      (if hx
          (let ((alloy (cistern-st-alloy st)))
            (setf (cistern-st-alloy st) 100)
            (let ((n (ux-cursor-to hx hy)))
              (ux-press 'cistern-decon)
              (ux-note "T4 decon breach: travel %d + 1 = %d presses; log: %S"
                       n ux-presses (ux-log-tail))
              (setf (cistern-st-alloy st) alloy)))
        (ux-note "T4 no hazard on map")))
    ;; ---- T5: undo a misplacement ----
    (setq ux-presses 0)
    (let* ((spot (ux-find-floor-far))
           (alloy (cistern-st-alloy st)))
      (setf (cistern-st-alloy st) 100)
      (ux-cursor-to (car spot) (cdr spot))
      (ux-press 'cistern-build-pipe)
      (ux-press 'cistern-demolish)
      (ux-note "T5 misplace+take-back: %d presses; alloy %d→%d; log: %S"
               ux-presses 100 (cistern-st-alloy st) (ux-log-tail)))
    ;; ---- T6: mode confusion / armed state visibility ----
    (setq ux-presses 0)
    (ux-press 'cistern-build-tank)
    (let ((head (with-current-buffer "*cistern*"
                  (goto-char (point-min))
                  (buffer-substring (point-min) (line-end-position 3)))))
      (ux-note "T6 after arming tank: header 3 lines=%S — any armed indicator? %S"
               head (string-match-p (regexp-quote (upcase (symbol-name 'tank))) head)))
    (let ((out (expand-file-name "playtest/UX-KEYS-REPORT.txt")))
      (with-temp-file out (insert (mapconcat #'identity ux-notes "\n")))
      (message "UX-KEYS-OK → %s" out))))

(provide 'cistern-ux-keys)
