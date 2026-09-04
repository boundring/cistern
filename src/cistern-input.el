;;; cistern-input.el --- Input adapter: events → use-case calls -*- lexical-binding: t; -*-

;; Adapter layer (DESIGN-SPEC §3.3): translation only — keyboard and
;; mouse intents into use-case calls.  Functions take ST as a
;; parameter (Pinned D1) so they are batch-testable; they never touch
;; buffers, never render, and never name domain hash layouts.

(require 'cl-lib)
(require 'cistern-game)

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

(provide 'cistern-input)
;;; cistern-input.el ends here
