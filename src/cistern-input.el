;;; cistern-input.el --- Input adapter: events → use-case calls -*- lexical-binding: t; -*-

;; Adapter layer (DESIGN-SPEC §3.3): translation only — keyboard and
;; mouse intents into use-case calls.  Functions take ST as a
;; parameter (Pinned D1) so they are batch-testable; they never touch
;; buffers, never render, and never name domain hash layouts.

(require 'cl-lib)
(require 'cistern-game (and load-file-name (expand-file-name "cistern-game.el" (file-name-directory load-file-name))))

(defun cistern-input-cursor-move (st dir)
  "Move ST's cursor one cell in DIR (north/south/west/east) by
delegating to the cursor-move use case (up/down/left/right)."
  (cistern--cmd-cursor st
                       (pcase dir
                         ('north 'up)
                         ('south 'down)
                         ('west 'left)
                         ('east 'right))))

(defun cistern-input-click (st x y)
  "A click at grid cell (X,Y): delegate to the click use case —
unarmed the cursor moves (no tick); armed the verb places at the
cell and exactly one tick advances (R6)."
  (cistern--cmd-click st x y))

(defun cistern-input-arm-verb (st verb)
  "Arm the build VERB via the arming use case — the single arming
site (L-010 pin 4, L-013 migration)."
  (cistern--cmd-arm-verb st verb))

(defun cistern-input-disarm (st)
  "Clear the armed verb via the disarm use case (Q19) — same
adapter chain as arming, per the L-010 use-case-owned precedent."
  (cistern--cmd-disarm st))

(defun cistern-input-cursor-goto (st x y)
  "V4-02: a direct cursor placement at (X,Y) — the log browser's
RET jump lands here, through the same adapter chain as every move."
  (cistern--cmd-cursor-goto st x y))

(defvar cistern--auto-run-timer nil
  "Auto-run timer handle.  Timer plumbing, never game state
(Pinned D2 — the spec §3.3 one-global exception; it never enters
`cistern-st').  The defvar lives in the adapter so the timer
machinery never references the driver outward; the driver
consumes it inward.")

(defvar cistern-input--refresh nil
  "Driver-registered refresh closure, called by the auto-run
callback after each tick so the timer's per-fire path repaints
(L-015 change item b).  Driver→adapter registration keeps the
dependency inward; nil until the driver's toggle command runs.")

(defvar cistern-input--auto-run-interval 0.2
  "Seconds between auto-run chain links (Q29 pacing): 0.2 = 5
ticks/second; 1.0 = the prefix-arg slow mode, 1 tick/second.
Plumbing, never game state (D2).")

(defun cistern-input-auto-run-toggle (st &optional slow)
  "Toggle auto-run for ST — the testable adapter unit; the
driver's `cistern-auto-run-toggle' command calls this.  On:
schedule the first chain link at the pacing interval (0.2s, or
1.0s when SLOW — Q29 prefix-arg slow mode, 1 tick/second).  Off:
cancel the live link.  The handle stays out of state (D2); the
on/off FLAG mirrors into ST for the Q01 badge slot."
  (if cistern--auto-run-timer
      (progn (cancel-timer cistern--auto-run-timer)
             (setq cistern--auto-run-timer nil)
             (setf (cistern-st-auto-run st) nil))
    (setq cistern-input--auto-run-interval (if slow 1.0 0.2)
          cistern--auto-run-timer
          (run-with-idle-timer cistern-input--auto-run-interval nil
                               #'cistern-input--auto-run-callback))
    (setf (cistern-st-auto-run st) t)))

(defun cistern-input--auto-run-callback ()
  "One auto-run chain link: exactly one tick via the tick use
case, then reschedule (self-rescheduling one-shot chain — L-015
records the plan's REPEAT-t deviation: an explicit reschedule per
fire is what makes every link observable and cancellable; REPEAT t
plus an explicit reschedule would stack timers).  Reads the
driver's `cistern--st' global — the single D1 exception (fires
outside any command context).  A condemned sector ends the chain:
no tick, no reschedule, handle cleared.  REWARDS-DESIGN §4 later
adds an advance-particles step per fire here — Phase 4b wiring,
deliberately not pre-built."
  (when cistern--st
    (if (cistern-st-over cistern--st)
        (setq cistern--auto-run-timer nil)
      (cistern--do-tick cistern--st)
      (when cistern-input--refresh
        (funcall cistern-input--refresh))
      (setq cistern--auto-run-timer
            (run-with-idle-timer cistern-input--auto-run-interval nil
                                 #'cistern-input--auto-run-callback)))))

(provide 'cistern-input)
;;; cistern-input.el ends here
