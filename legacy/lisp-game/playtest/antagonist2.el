;;; playtest/antagonist2.el --- ROUND-2 hostile capture driver (batch) -*- lexical-binding: t; -*-

;; Re-walks the REFACTORED surface (TOP-30 Q01..Q30 shipped) at the same
;; cruelty cases as round 1 plus the new surfaces.  Dumps land in
;; playtest/R2-NN-<label>.txt; live probes (faces, widths, log buffer)
;; print as R2-NOTE lines.
;;
;; Run from the repo root:
;;   emacs -Q --batch -l src/cistern.el -l playtest/antagonist2.el \
;;     -f cistern-antagonist2-run

(require 'cl-lib)
(require 'cistern)

(defvar r2-n 0)

(defun r2-note (fmt &rest args)
  (apply #'message "R2-NOTE %s" (cons (apply #'format fmt args) nil)))

(defun r2-dump (label)
  (setq r2-n (1+ r2-n))
  (let ((path (expand-file-name
               (format "R2-%02d-%s.txt" r2-n label)
               (file-name-as-directory (expand-file-name "playtest" default-directory)))))
    (with-temp-file path
      ;; render FRESH from state — direct use-case drives skip the
      ;; buffer, and a stale buffer dumped as evidence is worse than
      ;; useless (round-2 lesson: R2-15/16 first run were stale frames)
      (insert (substring-no-properties (cistern-view--render cistern--st))))
    (message "R2-DUMP %s" path)))

(defun r2-render ()
  (cistern-view--render cistern--st))

(defun r2-plain-line (render n)
  (nth (1- n) (split-string (substring-no-properties render) "\n")))

(defun r2-cursor-to (x y)
  (while (< (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-east))
  (while (> (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-west))
  (while (< (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-south))
  (while (> (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-north)))

(defun r2-line-face (render needle)
  "Face property of the rendered line containing NEEDLE (or nil)."
  (let ((pos (string-match-p (regexp-quote needle) render)))
    (when pos
      (let ((bol (+ pos (- (length (substring render 0 pos))
                           (length (substring (substring-no-properties render) 0 pos))))))
        ;; scan back to the line start for the property
        (while (and (> bol 0) (not (eq (aref render bol) ?\n)))
          (setq bol (1- bol)))
        (get-text-property (min (1+ bol) (1- (length render))) 'face render)))))

(defun r2-width-probe ()
  "Lengths and 95-col truncations of every permanent row."
  (let* ((render (r2-render))
         (lines (split-string render "\n")))
    (dolist (l (append (butlast lines 0) nil))
      nil)
    (dolist (idx '(0 1 2))
      (let ((l (nth idx lines)))
        (r2-note "row%d len=%d truncated95=%S"
                 (1+ idx) (length l) (substring l 0 (min 95 (length l))))))))

(defun r2-drive-relief (st)
  "Copy of the batch suite's driven relief (tests/test-ux-r1.el)."
  (let* ((w (car (cistern-st-creators st)))
         (spot (cl-loop for n in (cistern--neighbors st 3 3)
                        when (and (eq (cistern--cell st (car n) (cdr n)) 'floor)
                                  (not (gethash n (cistern--occupied-cells st w))))
                        return n)))
    (cl-assert spot t "free floor neighbor exists")
    (setf (cistern--worker-x w) (car spot))
    (setf (cistern--worker-y w) (cdr spot))
    (setf (cistern--worker-sick w) 0)
    (setf (cistern--worker-bladder w) cistern-bladder-seek)
    (cistern--do-tick st)
    (dotimes (_ cistern-use-ticks)
      (cistern--do-tick st))
    spot))

(defun cistern-antagonist2-run ()
  (interactive)
  (cistern)
  (setq cistern--st (cistern--new-game 42))

  ;; 01 COLD START: strip contract, starter card, tutorial prompt, GOALS.
  (dotimes (_ 3) (call-interactively #'cistern-tick))
  (r2-note "01 card=%S" (cistern-st-goal-card cistern--st))
  (r2-width-probe)
  (r2-dump "cold-tick3")

  ;; 02 ARMED: badge visible? how wide?
  (cistern-input-arm-verb cistern--st 'pipe)
  (let ((hdr (r2-plain-line (r2-render) 1)))
    (r2-note "02 armed-header len=%d full=%S" (length hdr) hdr))
  (r2-dump "armed-badge")

  ;; 03 REFUSED WALL: hint appears...
  (cistern-input-disarm cistern--st)
  (r2-cursor-to 0 0)
  (call-interactively #'cistern-build-toilet)
  (let ((render (r2-render)))
    (r2-note "03 hint-present=%S armed=%S"
             (string-match-p "NO FLOOR THERE" render)
             (cistern-st-armed-verb cistern--st)))
  (r2-dump "refused-wall-hint")
  ;; ...and vanishes on the next command (cursor move)
  (call-interactively #'cistern-cursor-east)
  (let ((render (r2-render)))
    (r2-note "03b hint-gone=%S" (not (string-match-p "NO FLOOR THERE" render))))
  (r2-dump "refused-wall-hint-gone")

  ;; 04 REFUSED ALLOY
  (setf (cistern-st-alloy cistern--st) 5)
  (r2-cursor-to 10 10)
  (call-interactively #'cistern-build-tank)
  (r2-dump "refused-alloy")

  ;; 05 SEVERED: rewire advice + tank coords + dead glyph + legend.
  (setq cistern--st (cistern--new-game 42))
  (r2-cursor-to 3 2)
  (call-interactively #'cistern-demolish)
  (r2-note "05 severed-p=%S backed-p=%S remedy=%S"
           (cistern--toilets-severed-p cistern--st)
           (cistern--toilets-backed-up-p cistern--st)
           (cistern--severed-remedy cistern--st))
  (r2-dump "severed-rewire")
  (r2-cursor-to 4 2)
  (r2-dump "dead-pipe-inspect")

  ;; 06 RISING: tank at 55/60 = 92%.
  (setq cistern--st (cistern--new-game 42))
  (puthash (cons 5 2) (list :load 55) (cistern-st-tanks cistern--st))
  (call-interactively #'cistern-tick)
  (let ((render (r2-render)))
    (r2-note "06 rising-line=%S face=%S"
             (r2-plain-line render 1)
             (r2-line-face render "PRESSURE RISING")))
  (r2-dump "tank-rising-92")

  ;; 07 BACKED UP: 60/60.
  (puthash (cons 5 2) (list :load 60) (cistern-st-tanks cistern--st))
  (call-interactively #'cistern-tick)
  (let ((render (r2-render)))
    (r2-note "07 critical-face=%S" (r2-line-face render "PRESSURE CRITICAL")))
  (r2-dump "backed-up")

  ;; 08 BREACH IDENTITY + severity persistence over 3 ticks.
  (setq cistern--st (cistern--new-game 42))
  (let ((w (nth 1 (cistern-st-creators cistern--st))))
    (setf (cistern--worker-x w) 12)
    (setf (cistern--worker-y w) 6)
    (setf (cistern--worker-bladder w) (- cistern-bladder-burst cistern-bladder-rate)))
  (call-interactively #'cistern-tick)
  (r2-cursor-to 12 6)
  (let ((render (r2-render)))
    (r2-note "08 breach-face-t1=%S glyph-at-12-6=%S"
             (r2-line-face render "BREACH")
             (with-current-buffer "*cistern*"
               (save-excursion
                 (goto-char (point-min))
                 (forward-line (+ 3 6))
                 (goto-char (+ (point) 12))
                 (buffer-substring-no-properties (point) (1+ (point)))))))
  (r2-dump "breach-identity")
  (dotimes (_ 2) (call-interactively #'cistern-tick))
  (let ((render (r2-render)))
    (r2-note "08b breach-face-t3=%S (persists?)" (r2-line-face render "BREACH")))
  (r2-dump "breach-severity-t3")

  ;; 09 DEATH: panel + ONE restart line; input live during panel.
  (setq cistern--st (cistern--new-game 42))
  (setf (cistern-st-contam cistern--st) 19)
  (let ((w (nth 1 (cistern-st-creators cistern--st))))
    (setf (cistern--worker-x w) 12)
    (setf (cistern--worker-y w) 6)
    (setf (cistern--worker-bladder w) (- cistern-bladder-burst cistern-bladder-rate)))
  (call-interactively #'cistern-tick)
  (r2-note "09 summary=%S" (cistern-st-summary cistern--st))
  (r2-dump "death-panel")
  (dotimes (_ 3) (call-interactively #'cistern-tick))
  (let* ((log (reverse (cistern-st-log cistern--st)))
         (restarts (cl-count-if (lambda (e) (string-match-p "PRESS n" (car e))) log)))
    (r2-note "09b post-over-ticks=3 restart-lines=%d total-log=%d" restarts (length log)))
  (r2-dump "death-after-3")

  ;; 10 FULL LOG: 30 ticks, then L.
  (setq cistern--st (cistern--new-game 42))
  (dotimes (_ 30) (call-interactively #'cistern-tick))
  (call-interactively #'cistern-log)
  (with-current-buffer "*cistern log*"
    (r2-note "10 log-lines=%d first=%S read-only=%S major=%S"
             (count-lines (point-min) (point-max))
             (buffer-substring-no-properties
              (line-beginning-position 1) (line-end-position 1))
             buffer-read-only major-mode))
  (kill-buffer "*cistern log*")
  (r2-dump "full-log-main")

  ;; 11 CEREMONY: driven MAP COMPLETED, sparkles over floor only.
  (setq cistern--st (cistern--new-game 42))
  (dotimes (_ 3)
    (r2-drive-relief cistern--st)
    ;; keep the starter tank under the toilet-usability ceiling
    (cistern--cmd-purge cistern--st 5 2))
  (let* ((render (r2-render))
         (log (reverse (cistern-st-log cistern--st)))
         (goal-pos (cl-loop for e in log for i from 0
                            when (string-match-p "GOAL MET" (car e))
                            collect i))
         (done-pos (cl-position-if (lambda (e) (string-match-p "MAP COMPLETED" (car e))) log))
         (bad-sparkles 0)
         (sparkle-glyphs nil))
    (dolist (p (cistern-st-particles cistern--st))
      (let* ((pos (plist-get p :pos))
             (cell (cistern--cell cistern--st (car pos) (cdr pos))))
        (push (plist-get p :glyph) sparkle-glyphs)
        (unless (eq cell 'floor) (setq bad-sparkles (1+ bad-sparkles)))))
    (r2-note "11 sparkles=%d off-floor=%d glyphs=%S goals-before-banner=%S"
             (length (cistern-st-particles cistern--st)) bad-sparkles
             (delete-dups sparkle-glyphs)
             (and goal-pos done-pos (cl-every (lambda (g) (< g done-pos)) goal-pos))))
  ;; classify off-floor particles by LAYER (sparkle vs popup)
  (let ((off (cl-loop for p in (cistern-st-particles cistern--st)
                      for pos = (plist-get p :pos)
                      unless (eq (cistern--cell cistern--st (car pos) (cdr pos)) 'floor)
                      collect (list (plist-get p :layer) (plist-get p :glyph)))))
    (r2-note "11b off-floor-particles=%S" off))
  (r2-dump "map-completed")

  ;; 12 MILESTONE: two more reliefs cross 5.
  (dotimes (_ 2)
    (r2-drive-relief cistern--st)
    (cistern--cmd-purge cistern--st 5 2))
  (let ((render (r2-render)))
    (r2-note "12 relieves=%d milestone-in-tail=%S milestone-face=%S unlocks=%S"
             (cistern-st-relieves cistern--st)
             (string-match-p "MILESTONE — BIG CISTERN ONLINE" render)
             (r2-line-face render "MILESTONE")
             (cistern-st-unlocks cistern--st)))
  (r2-dump "milestone-crossed")

  ;; 12b DEAD PIPE GLYPH: a lone unconnected pipe must render ╌.
  (setq cistern--st (cistern--new-game 42))
  (cistern--cmd-build cistern--st 'pipe 10 6)
  (r2-cursor-to 10 6)
  (r2-dump "dead-pipe-glyph")

  ;; 12c FULL LOG WITH CONTENT: 25 injected events, then L.
  (dotimes (_ 25) (cistern--log-sev cistern--st 'info "CREATOR RELIEVED AT (3,3)"))
  (call-interactively #'cistern-log)
  (with-current-buffer "*cistern log*"
    (r2-note "12c log-lines=%d first=%S read-only=%S"
             (count-lines (point-min) (point-max))
             (buffer-substring-no-properties
              (line-beginning-position 1) (line-end-position 1))
             buffer-read-only))
  (kill-buffer "*cistern log*")

  ;; 13 REGRET WINDOW + purge economy (Q30, Q07).
  (setq cistern--st (cistern--new-game 42))
  (let ((a0 (cistern-st-alloy cistern--st)))
    (cistern--cmd-build cistern--st 'pipe 10 6)
    (r2-cursor-to 10 6)
    (call-interactively #'cistern-demolish)
    (r2-note "13 same-tick alloy %d -> %d (expect unchanged)" a0 (cistern-st-alloy cistern--st)))
  (let ((a0 (cistern-st-alloy cistern--st)))
    (cistern--cmd-build cistern--st 'pipe 10 6)
    (call-interactively #'cistern-tick)
    (call-interactively #'cistern-demolish)
    (r2-note "13b ticked alloy %d -> %d (expect -1: fee 3, refund 1)" a0 (cistern-st-alloy cistern--st)))
  ;; Q07 purge economy at a known load: 30 units -> +10 alloy.
  (puthash (cons 5 2) (list :load 30) (cistern-st-tanks cistern--st))
  (let ((a0 (cistern-st-alloy cistern--st)))
    (r2-cursor-to 5 2)
    (call-interactively #'cistern-purge)
    (r2-note "13c purge 30 units alloy %d -> %d (expect +10)" a0 (cistern-st-alloy cistern--st)))

  ;; 14 TUTORIAL: drive all three steps.
  (setq cistern--st (cistern--new-game 42))
  (let* ((w (car (cistern-st-creators cistern--st))))
    (r2-cursor-to (cistern--worker-x w) (cistern--worker-y w)))
  (call-interactively #'cistern-tick)
  (r2-note "14 step1-advanced idx=%S" (cistern-st-tutorial cistern--st))
  (puthash (cons 5 2) (list :load 30) (cistern-st-tanks cistern--st))
  (r2-cursor-to 5 2)
  (call-interactively #'cistern-purge)
  (r2-note "14b step2-advanced idx=%S" (cistern-st-tutorial cistern--st))
  (r2-dump "tutorial-mid")
  (call-interactively #'cistern-skip-tutorial)
  (r2-note "14c skip idx=%S" (cistern-st-tutorial cistern--st))

  ;; 15 AUTO-RUN BADGE + slow interval.
  (cistern-input-auto-run-toggle cistern--st)
  (r2-note "15 badge=%S interval=%S" 
           (string-match-p "AUTO-RUN" (r2-render))
           cistern-input--auto-run-interval)
  (cistern-input-auto-run-toggle cistern--st)   ; off
  (cistern-input-auto-run-toggle cistern--st :slow)
  (r2-note "15b slow-interval=%S" cistern-input--auto-run-interval)
  (cistern-input-auto-run-toggle cistern--st)   ; off

  ;; 16 DEMOLISH DUST placement (Q25 scope check): spawn cell + glyphs.
  (setq cistern--st (cistern--new-game 42))
  (cistern--cmd-build cistern--st 'pipe 10 6)
  (r2-cursor-to 10 6)
  (call-interactively #'cistern-demolish)
  (let ((info (mapcar (lambda (p)
                        (list (plist-get p :glyph)
                              (cistern--cell cistern--st (car (plist-get p :pos))
                                            (cdr (plist-get p :pos)))))
                      (cistern-st-particles cistern--st))))
    (r2-note "16 dust-particles=%S" info))

  (message "ANTAGONIST2-RUN-OK"))

(provide 'playtest-antagonist2)
