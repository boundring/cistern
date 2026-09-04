;;; tests/game-cursor.el --- R1 use-case half: cursor + click, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Fixture: `cistern-test-game--floor-run' (L-007 pattern, single copy
;; in src/cistern-game.el beside the spec §5.1-pinned selftest) —
;; unoccupied floor with no plumbing 4-adjacent, so test networks stay
;; isolated from procgen's starter plumbing.

(defun cistern-test-cursor-and-click ()
  ;; --- cursor-move: direction updates cursor, clamped to bounds
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-cursor st) (cons 10 6))
    (cistern--cmd-cursor st 'right)
    (cl-assert (equal (cistern-st-cursor st) '(11 . 6)) "east step")
    (cistern--cmd-cursor st 'down)
    (cl-assert (equal (cistern-st-cursor st) '(11 . 7)) "south step")
    (cistern--cmd-cursor st 'left)
    (cl-assert (equal (cistern-st-cursor st) '(10 . 7)) "west step")
    (cistern--cmd-cursor st 'up)
    (cl-assert (equal (cistern-st-cursor st) '(10 . 6)) "north step")
    ;; clamping: refused moves leave the cursor put (legacy :865 guard)
    (setf (cistern-st-cursor st) (cons 0 0))
    (cistern--cmd-cursor st 'left)
    (cistern--cmd-cursor st 'up)
    (cl-assert (equal (cistern-st-cursor st) '(0 . 0)) "clamped at origin")
    (setf (cistern-st-cursor st) (cons (1- (cistern-st-w st))
                                       (1- (cistern-st-h st))))
    (cistern--cmd-cursor st 'right)
    (cistern--cmd-cursor st 'down)
    (cl-assert (equal (cistern-st-cursor st)
                      (cons (1- (cistern-st-w st)) (1- (cistern-st-h st))))
               "clamped at far corner")
    ;; move-only click: cursor set, NO tick (pinned minimal reading of
    ;; R6 — only SPACE/RET/click-with-verb advance the clock)
    (let ((tick0 (cistern-st-tick st)))
      (cistern--cmd-click st 17 8)
      (cl-assert (equal (cistern-st-cursor st) '(17 . 8))
                 "unarmed click moves the cursor")
      (cl-assert (= (cistern-st-tick st) tick0)
                 "move-only click does not tick")))

  ;; --- click with armed verb: place + exactly one tick (R6 cross-assert)
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (x (car spot)) (y (cadr spot)))
    (setf (cistern-st-alloy st) 100)
    (setf (cistern-st-armed-verb st) 'pipe)
    (let ((tick0 (cistern-st-tick st)))
      (cistern--cmd-click st x y)
      (cl-assert (eq (cistern--cell st x y) 'pipe) "armed click places pipe")
      (cl-assert (= (cistern-st-alloy st) (- 100 cistern-cost-pipe))
                 "alloy reduced by the pipe cost")
      (cl-assert (= (cistern-st-tick st) (1+ tick0))
                 "click-with-verb advances exactly one tick")
      (cl-assert (null (cistern-st-armed-verb st))
                 "armed verb cleared by the placing use-case"))
    ;; after clearing, the same cell click is a cursor move again
    (cistern--cmd-click st (+ x 1) y)
    (cl-assert (equal (cistern-st-cursor st) (cons (+ x 1) y))
               "disarmed click moves cursor again")
    (cl-assert (eq (cistern--cell st (+ x 1) y) 'floor)
               "disarmed click places nothing"))

  ;; --- unaffordable placement: refused, state untouched
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (x (car spot)) (y (cadr spot)))
    (setf (cistern-st-alloy st) 0)
    (setf (cistern-st-armed-verb st) 'tank)
    (let ((tick0 (cistern-st-tick st))
          (log0 (cistern-st-log st)))
      (cistern--cmd-click st x y)
      (cl-assert (eq (cistern--cell st x y) 'floor) "nothing placed")
      (cl-assert (= (cistern-st-alloy st) 0) "no charge")
      (cl-assert (= (cistern-st-tick st) tick0) "refusal does not tick")
      (cl-assert (not (equal (cistern-st-log st) log0))
                 "refusal logged")
      (cl-assert (eq (cistern-st-armed-verb st) 'tank)
                 "armed verb survives a refusal"))))

(provide 'game-cursor)
;;; tests/game-cursor.el ends here
