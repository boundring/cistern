;;; playtest/r2.el --- Round-2 UX collection captures (batch) -*- lexical-binding: t; -*-

;; Fresh evidence pass over the post-TOP-30 surface.  Run:
;;   emacs -Q --batch -l src/cistern.el -l playtest/r2.el -f cistern-r2-run
;; Dumps land in playtest/R2-NN-<label>.txt; measurements go to stdout.

(require 'cl-lib)

(defvar r2-n 0)

(defun r2-dump (label)
  (let* ((path (expand-file-name
                (format "R2-%02d-%s.txt" (setq r2-n (1+ r2-n)) label)
                (file-name-as-directory
                 (expand-file-name "playtest" default-directory)))))
    (with-current-buffer "*cistern*"
      (write-region (point-min) (point-max) path nil 'silent))))

(defun r2-line (n)
  "Nth screen line, faces stripped."
  (with-current-buffer "*cistern*"
    (buffer-substring (line-beginning-position n) (line-end-position n))))

(defun r2-width (s) (length (substring-no-properties s)))

(defun r2-face-at (line col)
  "Face at 0-based COL on 1-based LINE."
  (with-current-buffer "*cistern*"
    (get-text-property (+ (line-beginning-position line) col) 'face)))

(defun r2-seek (pred)
  (let ((hit nil))
    (dotimes (y (cistern-st-h cistern--st))
      (dotimes (x (cistern-st-w cistern--st))
        (when (and (not hit) (funcall pred (cistern--cell cistern--st x y) x y))
          (setq hit (cons x y)))))
    hit))

(defun r2-cursor-to (x y)
  (while (< (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-east))
  (while (> (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-west))
  (while (< (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-south))
  (while (> (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-north)))

(defun cistern-r2-run ()
  (interactive)
  ;; ---- 01 cold start: strip widths at 95 cols, tutorial/pressure adjacency
  (cistern)
  (setq cistern--st (cistern--new-game 42))
  (cistern--refresh)
  (message "01 header-w=%d help-w=%d legend-w=%d"
           (r2-width (r2-line 1)) (r2-width (r2-line 2)) (r2-width (r2-line 3)))
  (message "01 GOALS-seg=%S" (r2-line 1))
  (r2-dump "cold-start")
  ;; tutorial + pressure lines: find their lines & faces
  (let ((lines nil) (n 1))
    (with-current-buffer "*cistern*"
      (goto-char (point-min))
      (while (not (eobp))
        (let ((s (buffer-substring (line-beginning-position) (line-end-position))))
          (when (or (string-prefix-p "TUTORIAL" s)
                    (string-suffix-p "THE STRUCTURE DOES NOT CARE" s)
                    (string-prefix-p "PRESSURE" s)
                    (string-prefix-p "LINES SEVERED" s))
            (push (list n (r2-width s)
                        (get-text-property (line-beginning-position) 'face) s)
                  lines)))
        (setq n (1+ n))
        (forward-line 1)))
    (message "01 attention-lines: %S" (nreverse lines)))

  ;; ---- 02 armed badge width (both badges on)
  (cistern-input-arm-verb cistern--st 'pipe)
  (cistern-input-auto-run-toggle cistern--st nil)
  (cistern-input-auto-run-toggle cistern--st nil) ; off again; just measure armed
  (cistern--refresh)
  (message "02 armed header-w=%d line=%S" (r2-width (r2-line 1)) (r2-line 1))
  (r2-dump "armed-badge")
  (cistern-input-disarm cistern--st)

  ;; ---- 03 dead pipe glyph: isolated pipe + legend + briefing mismatch
  (let ((spot (r2-seek (lambda (k x y)
                         (and (eq k 'floor) (> y 4) (< x 10))))))
    (r2-cursor-to (car spot) (cdr spot))
    (call-interactively #'cistern-build-pipe))
  (cistern--refresh)
  (message "03 legend=%S" (r2-line 3))
  (r2-dump "dead-pipe")
  ;; find the dead glyph row on the map and its face vs live pipe face
  (let ((found nil) (n 1))
    (with-current-buffer "*cistern*"
      (goto-char (point-min))
      (while (not (eobp))
        (let ((s (buffer-substring (line-beginning-position) (line-end-position))))
          (when (string-match "╌" s)
            (push (list n (match-beginning 0) (match-end 0)
                        (r2-face-at n (match-beginning 0))) found)))
        (setq n (1+ n))
        (forward-line 1)))
    (message "03 dead-glyph at %S" found))
  ;; cursor on the dead pipe: inspector copy
  (let ((p (r2-seek (lambda (k _x _y) (eq k 'pipe)))))
    (r2-cursor-to (car p) (cdr p))
    (message "03 inspector-on-dead-pipe: %S" (r2-line 4)))

  ;; ---- 04 refusal hints: wall click armed, wall at-cursor build
  (cistern-input-arm-verb cistern--st 'pipe)
  (let ((wall (r2-seek (lambda (k _x _y) (eq k 'wall)))))
    (r2-cursor-to (car wall) (cdr wall))
    (call-interactively #'cistern-build-pipe)   ; refused at-cursor: armed?
    (message "04 wall-build armed-after-refusal=%S" (cistern-st-armed-verb cistern--st))
    (cistern-input-disarm cistern--st)
    (cistern-input-arm-verb cistern--st 'toilet)
    (let ((alloy (cistern-st-alloy cistern--st)))
      ;; tank too expensive? force alloy refusal: set alloy low via rebuild is
      ;; invasive; instead click the wall with armed verb — floor refusal
      (r2-cursor-to (car wall) (cdr wall))
      (call-interactively #'cistern-cursor-east)
      (call-interactively #'cistern-cursor-east)
      ;; now cursor near wall; find a wall cell and click it via geometry
      (cistern-input-click cistern--st (car wall) (cdr wall))
      (cistern--refresh)
      (message "04 hint-line-after-armed-wall-click tick=%d alloy %d->%d: %S"
               (cistern-st-tick cistern--st) alloy (cistern-st-alloy cistern--st)
               (cdr (cistern-st-hint cistern--st))))
    (r2-dump "refusal-hint"))

  ;; ---- 05 log severity persists across ticks (breach)
  (call-interactively #'cistern-new-game)
  ;; force a breach fast: no toilets on starter map? tick until contam > 0
  (let ((breach-tick nil) (entry nil))
    (dotimes (_ 80)
      (call-interactively #'cistern-tick)
      (dolist (e (cistern-st-log cistern--st))
        (when (and (not breach-tick)
                   (string-match-p "BREACH" (car e))
                   (eq (cdr e) 'error))
          (setq breach-tick (cistern-st-tick cistern--st) entry e))))
    (message "05 breach entry %S at tick %S" entry breach-tick)
    ;; render 3 ticks later, find the line and its face in the tail
    (dotimes (_ 3) (call-interactively #'cistern-tick))
    (let ((hit nil) (n 1))
      (with-current-buffer "*cistern*"
        (goto-char (point-min))
        (while (and (not hit) (not (eobp)))
          (let ((s (buffer-substring (line-beginning-position) (line-end-position))))
            (when (string-match-p "BREACH" s)
              (setq hit (list n s (get-text-property (line-beginning-position) 'face)))))
          (forward-line 1)))
      (message "05 tail 3 ticks later: %S" hit)))

  ;; ---- 06 death panel vs pressure line duplication
  (call-interactively #'cistern-new-game)
  ;; capture-injection: raise contamination to the limit to reach condemnation
  (setf (cistern-st-contam cistern--st) cistern-contam-limit)
  (call-interactively #'cistern-tick)
  (cistern--refresh)
  (let ((tail nil) (n 1))
    (with-current-buffer "*cistern*"
      (goto-char (point-min))
      (while (not (eobp))
        (let ((s (buffer-substring (line-beginning-position) (line-end-position))))
          (when (> (r2-width s) 0)
            (push (list n s) tail)))
        (setq n (1+ n))
        (forward-line 1)))
    (message "06 condemned screen (non-empty lines):")
    (dolist (e (nreverse tail)) (message "06  L%d %S" (car e) (cdr e))))
  (r2-dump "condemned-panel")

  ;; ---- 07 full help briefing
  (cistern-help)
  (let ((help (with-current-buffer "*cistern help*" (buffer-string))))
    (with-temp-file (expand-file-name "R2-07-help.txt"
                                      (file-name-as-directory
                                       (expand-file-name "playtest" default-directory)))
      (insert help))
    (message "07 help has dead-pipe glyph=%S mentions-L=%S mentions-ESC=%S mentions-slow=%S mentions-goals=%S mentions-regret=%S"
             (string-match-p "╌" help)
             (string-match-p "\\bL\\b" help)
             (string-match-p "ESC\\|escape" help)
             (string-match-p "slow\\|prefix\\|C-u" help)
             (string-match-p "GOAL\\|goal" help)
             (string-match-p "regret\\|refund\\|free demolish" help)))

  ;; ---- 08 L full-log buffer
  (call-interactively #'cistern-log)
  (with-current-buffer "*cistern log*"
    (message "08 log-buffer lines=%d read-only=%S"
             (count-lines (point-min) (point-max)) buffer-read-only))

  (message "R2-RUN-OK"))

(provide 'cistern-r2)
