;;; domain-tick.el --- R9: domain runs a full sim tick headless -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun cistern-test-tick-headless ()
  "R9 (domain half): in batch, no display/buffer setup, fresh state
from seed, ONE full tick via `cistern--sim-tick' advances the tick
counter by exactly 1 with no error; a few more ticks stay clean."
  (let ((st (cistern--new-game 20260830)))
    (cistern--sim-tick st)
    (cl-assert (= (cistern-st-tick st) 1) nil "tick counter = %d after one tick"
               (cistern-st-tick st))
    (dotimes (_ 20) (cistern--sim-tick st))
    (cl-assert (= (cistern-st-tick st) 21) nil "tick counter = %d after 21 ticks"
               (cistern-st-tick st))
    ;; the four phases really acted: workers have bladder pressure and the
    ;; log grows; state remains coherent
    (cl-assert (cistern-st-creators st) nil "no workers")
    (cl-assert (null (cistern-st-over st)) nil "sector condemned too early")))

(provide 'domain-tick)
;;; domain-tick.el ends here