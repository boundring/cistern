;;; playtest/antagonist.el --- hostile-moment capture driver (batch) -*- lexical-binding: t; -*-

(require 'playtest-smoke)

(defvar antag-n 0)

(defun antag-dump (label)
  (setq antag-n (1+ antag-n))
  (let ((path (expand-file-name
               (format "ANTAG-%02d-%s.txt" antag-n label)
               (file-name-as-directory (expand-file-name "playtest" default-directory)))))
    (with-temp-file path
      (let ((s (with-current-buffer "*cistern*"
                 (buffer-substring (point-min) (point-max)))))
        (insert s)))
    (message "ANTAG-DUMP %s" path)))

(defun antag-line (n)
  (with-current-buffer "*cistern*"
    (buffer-substring-no-properties
     (line-beginning-position n) (line-end-position n))))

(defun antag-cursor-to (x y)
  (while (< (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-east))
  (while (> (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-west))
  (while (< (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-south))
  (while (> (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-north)))

(defun cistern-antagonist-run ()
  (interactive)
  (cistern)
  (setq cistern--st (cistern--new-game 42))

  ;; A. COLD START: what does a brand-new player see, and what does the
  ;; cursor rest on first? Tick 5 with no input.
  (dotimes (_ 5) (call-interactively #'cistern-tick))
  (antag-dump "cold-tick5")

  ;; B. ARMED-BUT-INVISIBLE: arm pipe, dump. Any armed indicator?
  (cistern-input-arm-verb cistern--st 'pipe)
  (antag-dump "armed-invisible")

  ;; C. REFUSED BUILD: try building a toilet on the starter wall.
  (cistern-input-arm-verb cistern--st nil)
  (antag-cursor-to 0 0)
  (call-interactively #'cistern-build-toilet)
  (antag-dump "refused-wall")
  ;; refused by alloy: drain then try a tank
  (setf (cistern-st-alloy cistern--st) 5)
  (antag-cursor-to 10 10)
  (call-interactively #'cistern-build-tank)
  (antag-dump "refused-alloy")

  ;; D. SEVERED PLUMBING: demolish the starter pipe (3,2) so the
  ;; starter toilet goes SEVERED; also inspect the dead pipe cell.
  (setq cistern--st (cistern--new-game 42))
  (antag-cursor-to 3 2)
  (call-interactively #'cistern-demolish)
  (antag-dump "severed-toilet")
  (antag-cursor-to 4 2)
  (antag-dump "dead-pipe-inspect")

  ;; E. MID-PRESSURE: tank at 55/60 — five units from backing up.
  (setq cistern--st (cistern--new-game 42))
  (puthash (cons 5 2) (list :load 55) (cistern-st-tanks cistern--st))
  (antag-cursor-to 5 2)
  (call-interactively #'cistern-tick)
  (antag-dump "tank-55of60")

  ;; F. BACKED UP: tank full, toilet red.
  (puthash (cons 5 2) (list :load 60) (cistern-st-tanks cistern--st))
  (call-interactively #'cistern-tick)
  (antag-dump "backed-up")

  ;; G. BREACH IN PROGRESS: walk a worker's bladder to burst.
  (setq cistern--st (cistern--new-game 42))
  (let ((w (nth 1 (cistern-st-creators cistern--st))))
    (setf (cistern--worker-x w) 12)
    (setf (cistern--worker-y w) 6)
    (setf (cistern--worker-bladder w) (- cistern-bladder-burst cistern-bladder-rate)))
  (call-interactively #'cistern-tick)
  (antag-cursor-to 12 6)
  (antag-dump "breach-just-happened")
  ;; sick worker nearby, contamination spreading window
  (dotimes (_ 6) (call-interactively #'cistern-tick))
  (antag-dump "post-breach-spread")

  ;; H. LOG FIREHOSE: 30 ticks of normal play, then read the tail.
  (setq cistern--st (cistern--new-game 42))
  (dotimes (_ 30) (call-interactively #'cistern-tick))
  (antag-dump "log-after-30-ticks")

  ;; I. MILESTONE MOMENT: cross the 5-relieve threshold — is ANYTHING
  ;; visible to the player?
  (setq cistern--st (cistern--new-game 42))
  (setf (cistern-st-relieves cistern--st) 4)
  ;; force one relief event through a real tick with a seated worker
  (let ((w (car (cistern-st-creators cistern--st))))
    (setf (cistern--worker-x w) 3)
    (setf (cistern--worker-y w) 3)
    (setf (cistern--worker-bladder w) cistern-bladder-seek))
  ;; seat on starter toilet
  (dotimes (_ 3) (call-interactively #'cistern-tick))
  (antag-dump "milestone-crossed")
  (message "I: unlocks=%S relieves=%d log=%S"
           (cistern-st-unlocks cistern--st)
           (cistern-st-relieves cistern--st)
           (cistern-st-log cistern--st))

  ;; J. CONDEMNED: contam at 19 then one more breach.
  (setq cistern--st (cistern--new-game 42))
  (setf (cistern-st-contam cistern--st) 19)
  (let ((w (nth 1 (cistern-st-creators cistern--st))))
    (setf (cistern--worker-x w) 12)
    (setf (cistern--worker-y w) 6)
    (setf (cistern--worker-bladder w) (- cistern-bladder-burst cistern-bladder-rate)))
  (call-interactively #'cistern-tick)
  (antag-dump "condemned")
  ;; what does the world look like 3 ticks later?
  (dotimes (_ 3) (call-interactively #'cistern-tick))
  (antag-dump "condemned-after-3")

  (message "ANTAGONIST-RUN-OK"))

(provide 'playtest-antagonist)
