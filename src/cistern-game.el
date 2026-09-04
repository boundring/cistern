;;; cistern-game.el --- Use cases: player verbs, state in → state out -*- lexical-binding: t; -*-

;; Game/use-case layer (DESIGN-SPEC §3.3): pure signatures —
;; state + intent → state + log.  No buffers, faces, keymaps, timers,
;; no `cistern--st' global, no rendering.  Layer dependency is strictly
;; inward: this file requires cistern-domain and nothing else.

(require 'cl-lib)
(require 'cistern-domain)

(defconst cistern-cost-demolish 3
  "Alloy cost of the demolish verb (R8).  Implementation-seed
value, pinned for testability per plan 01 §2.3; final pricing is
DEFERRED to REWARDS-DESIGN (spec §6).  Phase 2 ships no refund —
the 50% refund contract is consumed in Phase 4b.")

(defun cistern--cmd-build (st kind x y)
  "Place KIND (toilet/pipe/tank) at (X,Y).  Ported verbatim from
cistern.el:498-525, rendered calls stripped."
  (let ((cost (pcase kind
                ('toilet cistern-cost-toilet)
                ('pipe cistern-cost-pipe)
                ('tank cistern-cost-tank))))
    (cond
     ((not (cistern--in-bounds-p st x y)) (cistern--log st "OUT OF SECTOR"))
     ((not (eq (cistern--cell st x y) 'floor))
      (cistern--log st "CANNOT BUILD THERE"))
     ((gethash (cons x y) (cistern--occupied-cells st nil))
      (cistern--log st "WORKER IN THE WAY"))
     ((< (cistern-st-alloy st) cost)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED" cost))
     (t
      (setf (cistern-st-alloy st) (- (cistern-st-alloy st) cost))
      (cistern--set-cell st x y kind)
      (pcase kind
        ('toilet
         (puthash (cons x y) (list :busy nil) (cistern-st-toilets st))
         (setf (cistern-st-built-toilet st)
               (1+ (cistern-st-built-toilet st))))
        ('tank
         (puthash (cons x y) (list :load 0) (cistern-st-tanks st))
         (setf (cistern-st-built-tank st) (1+ (cistern-st-built-tank st))))
        ('pipe
         (setf (cistern-st-built-pipe st) (1+ (cistern-st-built-pipe st)))))
      (cistern--log st "%s PLACED AT (%d,%d) — %d ALLOY"
                    (upcase (symbol-name kind)) x y cost)))))

(defun cistern--cmd-demolish (st x y)
  "Remove the player-placed plumbing at (X,Y) (R8).  Legality:
player-placed kinds only (pipe/toilet/tank) — walls/doors/ore are
terrain (decon stays the separate, hazard-only verb) — and an
in-use toilet (worker seated) is refused.  Removal = cell → floor
+ `remhash' from BOTH plumbing hashes; downstream usability is
re-decided by the domain flood-fill, so cell+hash removal is the
whole job.  No dangling plumbing entries may survive (the v1
phantom-plumbing invariant, load-bearing)."
  (let ((kind (and (cistern--in-bounds-p st x y)
                   (cistern--cell st x y))))
    (cond
     ((not (memq kind '(pipe toilet tank)))
      (cistern--log st "NOT YOURS TO DEMOLISH"))
     ((and (eq kind 'toilet)
           (plist-get (gethash (cons x y) (cistern-st-toilets st)) :busy))
      (cistern--log st "TOILET IN USE"))
     ((< (cistern-st-alloy st) cistern-cost-demolish)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED"
                    cistern-cost-demolish))
     (t
      (setf (cistern-st-alloy st)
            (- (cistern-st-alloy st) cistern-cost-demolish))
      (remhash (cons x y) (cistern-st-toilets st))
      (remhash (cons x y) (cistern-st-tanks st))
      (cistern--set-cell st x y 'floor)
      (cistern--log st "DEMOLISHED %s AT (%d,%d) — %d ALLOY"
                    (upcase (symbol-name kind)) x y cistern-cost-demolish)))))

(defun cistern--tutorial-steps ()
  "Tutorial mechanism holder: table of (PROMPT . PREDICATE) steps,
predicate takes ST and a non-nil result advances.  Scenario content
is Phase 4a; the table ships empty so advance is a no-op."
  '())

(defun cistern--tutorial-advance (st)
  "Advance the tutorial index if the current step's predicate holds
(cistern.el:589-599 pattern, minus the nine legacy steps)."
  (let ((steps (cistern--tutorial-steps))
        (idx (cistern-st-tutorial st)))
    (when (and (numberp idx)
               (< idx (length steps))
               (funcall (cdr (nth idx steps)) st))
      (setf (cistern-st-tutorial st) (1+ idx))
      (cistern--log st "TUTORIAL: OBJECTIVE COMPLETE"))))

(defun cistern--do-tick (st)
  "Exactly one tick per action (R6): over-guard, then one domain
sim tick, then the tutorial advance.  The legacy multi-tick
command is NOT ported — no way to advance more than one tick per
call exists at the use-case layer."
  (unless (cistern-st-over st)
    (cistern--sim-tick st)
    (cistern--tutorial-advance st)))

(defconst cistern--rewards-default-outcome
  '(:score 0 :objectives nil :unlocks nil :celebrate nil)
  "Pinned Phase 2 placeholder outcome (spec §4 R5; REWARDS-DESIGN
§5).  Final values are REWARDS-DESIGN consumption, Phase 4b.")

(defun cistern--rewards-eval (st events)
  "Rewards use-case (R5): (state, tick EVENTS) → (updated state,
outcome, presentation intents) as a 3-list.  Phase 2 placeholder:
ST is returned unchanged with the pinned default outcome and empty
intents.  The REWARDS-DESIGN consumption (goal cards, milestone
ladder, reputation, particle spawns) is Phase 4b — NOT pre-built
here.  4b's seeded garnish must draw from the seed⊕stream-id child
stream, never ST's sim LCG (REWARDS-DESIGN §4); this placeholder
consumes no randomness at all."
  (list st (copy-sequence cistern--rewards-default-outcome) nil))

(provide 'cistern-game)
;;; cistern-game.el ends here
