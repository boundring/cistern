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

(provide 'cistern-input)
;;; cistern-input.el ends here
