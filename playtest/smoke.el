;;; playtest/smoke.el --- Scripted live-driver smoke session (batch) -*- lexical-binding: t; -*-

;; Drives the REAL interactive surface — the `cistern' entry, the
;; buffer, the mode, the interactive commands, synthesized mouse
;; events — the path the 32 headless tests do not cover.
;;
;; Run from the repo root:
;;   emacs -Q --batch -l src/cistern.el -l playtest/smoke.el \
;;     -f cistern-smoke-run
;; Dumps land in playtest/SCREEN-NN-<label>.txt.

(require 'cl-lib)

(defvar smoke-n 0)
(defvar smoke-log nil)

(defun smoke-dump (label)
  "Write the game buffer's player-eye view to a numbered dump file."
  (let* ((path (expand-file-name
                (format "SCREEN-%02d-%s.txt" (setq smoke-n (1+ smoke-n)) label)
                (file-name-as-directory (expand-file-name "playtest" default-directory)))))
    (with-temp-file path
      (insert (with-current-buffer "*cistern*"
                (replace-regexp-in-string "\n$" "" (buffer-string)))))
    (setq smoke-log (append smoke-log (list (format "DUMP %s" (file-name-nondirectory path)))))))

(defun smoke-note (fmt &rest args)
  (setq smoke-log
        (append smoke-log (list (apply #'format fmt args))))
  (apply #'message fmt args))

(defun smoke-facts (label)
  (let ((st cistern--st))
    (smoke-note "%s: %s" label
                (format "tick=%d alloy=%d contam=%d cursor=(%d,%d) armed=%S relieves=%S score=%S rep=%d trophies=%S"
                        (cistern-st-tick st) (cistern-st-alloy st) (cistern-st-contam st)
                        (car (cistern-st-cursor st)) (cdr (cistern-st-cursor st))
                        (cistern-st-armed-verb st) (cistern-st-relieves st)
                        (cistern-st-score st) (cistern-st-reputation st)
                        (cistern-st-trophies st)))))

(defun smoke-buffer-line (n)
  "The Nth line of the game buffer, faces stripped (batch text)."
  (with-current-buffer "*cistern*"
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- n))
      (buffer-substring-no-properties (line-beginning-position)
                                      (line-end-position)))))

(defun smoke-inspector-cursor ()
  (let ((insp (cl-position-if
               (lambda (l) (string-prefix-p "CURSOR (" l))
               (mapcar #'smoke-buffer-line (number-sequence 1 25)))))
    (when insp
      (let ((s (smoke-buffer-line (1+ insp))))
        (when (string-match "CURSOR (\\([0-9-]+\\),\\([0-9-]+\\))" s)
          (cons (string-to-number (match-string 1 s))
                (string-to-number (match-string 2 s))))))))

(defun smoke-seek (pred)
  "First (X . Y) grid cell whose tile satisfies PRED."
  (let ((st cistern--st) (hit nil))
    (catch 'done
      (dotimes (y (cistern-st-h st))
        (dotimes (x (cistern-st-w st))
          (when (funcall pred (cistern--cell st x y) x y)
            (setq hit (cons x y))
            (throw 'done hit)))))
    hit))

(defun smoke-cursor-to (x y)
  "Move the cursor to (X,Y) through the real arrow commands."
  (while (< (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-east))
  (while (> (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-west))
  (while (< (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-south))
  (while (> (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-north)))

(defun smoke-click-at (x y)
  "Real driver mouse path: synthesize a mouse-1 event for the
buffer position of grid cell (X,Y) and call `cistern-click'."
  (let* ((stride (1+ (cistern-st-w cistern--st)))
         (hdr (with-current-buffer "*cistern*"
                (save-excursion
                  (goto-char (point-min))
                  (forward-line cistern-view--header-lines)
                  (1- (point)))))
         (bufpos (+ hdr (* y stride) x 1))
         (event (list 'mouse-1 (list 'text-area 0 0 0 nil bufpos))))
    (cistern-click event)))

(defun cistern-smoke-run ()
  (interactive)
  (mkdir (expand-file-name "playtest") t)
  ;; ---- 1. Cold start on seed 42 ------------------------------------
  (cistern)
  (setq cistern--st (cistern--new-game 42))
  (cistern--refresh)
  (smoke-facts "01-cold")
  (smoke-dump "cold-start")
  ;; ---- 2. Cursor movement ------------------------------------------
  (call-interactively #'cistern-cursor-north)
  (call-interactively #'cistern-cursor-north)
  (call-interactively #'cistern-cursor-east)
  (call-interactively #'cistern-cursor-east)
  (call-interactively #'cistern-cursor-east)
  (smoke-facts "02-cursor (state)")
  (smoke-note "02: inspector tracks cursor: %S (state cursor %S)"
              (smoke-inspector-cursor) (cistern-st-cursor cistern--st))
  (smoke-dump "cursor-moved")
  ;; ---- 3. Ticks -----------------------------------------------------
  (call-interactively #'cistern-tick)
  (call-interactively #'cistern-tick)
  (call-interactively #'cistern-tick)
  (smoke-facts "03-ticks")
  (smoke-dump "after-3-ticks")
  ;; ---- 4. Arm+build: toilet and pipe --------------------------------
  (let* ((spot (smoke-seek (lambda (k _x _y) (eq k 'floor))))
         (alloy0 (cistern-st-alloy cistern--st)))
    (smoke-cursor-to (car spot) (cdr spot))
    (call-interactively #'cistern-build-toilet)
    (smoke-note "04a: toilet at %S alloy %d->%d tick %d"
                spot alloy0 (cistern-st-alloy cistern--st) (cistern-st-tick cistern--st))
    (smoke-dump "built-toilet")
    (let* ((spot2 (smoke-seek (lambda (k _x _y) (eq k 'floor))))
           (alloy1 (cistern-st-alloy cistern--st)))
      (smoke-cursor-to (car spot2) (cdr spot2))
      (call-interactively #'cistern-build-pipe)
      (smoke-note "04b: pipe at %S alloy %d->%d tick %d"
                  spot2 alloy1 (cistern-st-alloy cistern--st) (cistern-st-tick cistern--st))
      (smoke-dump "built-pipe")))
  ;; tank needs 15; fresh game for headroom
  (call-interactively #'cistern-new-game)
  (let* ((spot (smoke-seek (lambda (k _x _y) (eq k 'floor))))
         (alloy0 (cistern-st-alloy cistern--st)))
    (smoke-cursor-to (car spot) (cdr spot))
    (call-interactively #'cistern-build-tank)
    (smoke-note "04c: tank at %S alloy %d->%d tick %d"
                spot alloy0 (cistern-st-alloy cistern--st) (cistern-st-tick cistern--st))
    (smoke-dump "built-tank"))
  ;; ---- 5. Click: unarmed, then armed --------------------------------
  (call-interactively #'cistern-new-game)
  (let* ((target (smoke-seek (lambda (k x y)
                               (and (eq k 'floor)
                                    (not (equal (cons x y)
                                                (cistern-st-cursor cistern--st))))))))
    (smoke-click-at (car target) (cdr target))
    (smoke-note "05a: unarmed click at %S -> cursor %S tick %d (expect moved, +0)"
                target (cistern-st-cursor cistern--st) (cistern-st-tick cistern--st))
    (smoke-dump "click-unarmed")
    (cistern-input-arm-verb cistern--st 'pipe)
    (let ((alloy0 (cistern-st-alloy cistern--st))
          (spot (smoke-seek (lambda (k _x _y) (eq k 'floor)))))
      (smoke-click-at (car spot) (cdr spot))
      (smoke-note "05b: armed click at %S -> alloy %d->%d tick %d (expect -2, +1)"
                  spot alloy0 (cistern-st-alloy cistern--st) (cistern-st-tick cistern--st))
      (smoke-dump "click-armed")))
  ;; ---- 6. Demolish own structure ------------------------------------
  (let ((pipe (smoke-seek (lambda (k _x _y) (eq k 'pipe)))))
    (smoke-cursor-to (car pipe) (cdr pipe))
    (let ((alloy0 (cistern-st-alloy cistern--st))
          (tick0 (cistern-st-tick cistern--st)))
      (call-interactively #'cistern-demolish)
      (smoke-note "06: demolish pipe at %S alloy %d->%d tick %d->%d particles=%d"
                  pipe alloy0 (cistern-st-alloy cistern--st) tick0
                  (cistern-st-tick cistern--st)
                  (length (cistern-st-particles cistern--st)))
      (smoke-dump "demolished")))
  ;; ---- 7. Purge the starter tank ------------------------------------
  (let ((tank (smoke-seek (lambda (k _x _y) (eq k 'tank)))))
    (smoke-cursor-to (car tank) (cdr tank))
    (let ((alloy0 (cistern-st-alloy cistern--st)))
      (call-interactively #'cistern-purge)
      (smoke-note "07: purge tank at %S alloy %d->%d load now %S"
                  tank alloy0 (cistern-st-alloy cistern--st)
                  (cistern--tank-load cistern--st (car tank) (cdr tank)))
      (smoke-dump "purged-tank")))
  ;; ---- 8. Rewards showcase: goal card -> MapCompleted ---------------
  (cistern--cmd-set-goal-card cistern--st
                              '(:tier 1 :goals ((:kind relieves-served :target 3))))
  (smoke-note "08: goal card set; ticking until 3 relieves (starter map)")
  (let ((done nil) (relief-ticks nil) (purges 0))
    (dotimes (_ 140)
      (unless done
        (call-interactively #'cistern-tick)
        ;; the intended loop: when the starter tank backs the toilet
        ;; up, purge it (pressure line tells the player to)
        (when (and (eq (cistern--toilet-state cistern--st 3 3) 'down)
                   (< purges 4))
          (setq purges (1+ purges))
          (smoke-cursor-to 5 2)
          (call-interactively #'cistern-purge)
          (smoke-note "08: purged backed-up tank (alloy now %d)"
                      (cistern-st-alloy cistern--st)))
        (when (> (cistern-st-relieves cistern--st)
                 (length relief-ticks))
          (push (cistern-st-tick cistern--st) relief-ticks)
          (smoke-note "08: relieve at tick %d (total %d)"
                      (cistern-st-tick cistern--st)
                      (cistern-st-relieves cistern--st))
          (smoke-dump (format "relief-%d" (length relief-ticks))))
        (when (and (cistern-st-goal-card cistern--st)
                   (plist-get (cistern-st-goal-card cistern--st) :completed))
          (setq done t)
          (smoke-note "08: MAP COMPLETED at tick %d trophies=%S particles=%d"
                      (cistern-st-tick cistern--st)
                      (cistern-st-trophies cistern--st)
                      (length (cistern-st-particles cistern--st)))
          (smoke-dump "map-completed"))))
    (unless done (smoke-note "08: WARNING — goal card never completed in 90 ticks")))
  ;; ---- 9. Help + auto-run toggle records -----------------------------
  (cistern-help)
  (let ((help (with-current-buffer "*cistern help*" (buffer-string))))
    (with-temp-file (expand-file-name
                     (format "SCREEN-%02d-help-briefing.txt" (setq smoke-n (1+ smoke-n)))
                     (file-name-as-directory (expand-file-name "playtest" default-directory)))
      (insert help)))
  (cistern-auto-run-toggle)
  (smoke-note "09: auto-run on -> timer %S" cistern--auto-run-timer)
  (cistern-auto-run-toggle)
  (smoke-note "09: auto-run off -> timer %S" cistern--auto-run-timer)
  (smoke-dump "auto-run-toggled")
  ;; ---- 10. New game, variety -----------------------------------------
  (call-interactively #'cistern-new-game)
  (smoke-facts "10-new-game")
  (smoke-dump "new-game-variety")
  ;; ---- write the session log -----------------------------------------
  (with-temp-file (expand-file-name "smoke-log.txt"
                                    (file-name-as-directory
                                     (expand-file-name "playtest" default-directory)))
    (insert (mapconcat #'identity smoke-log "\n") "\n"))
  (message "SMOKE-RUN-OK"))

(provide 'playtest-smoke)
