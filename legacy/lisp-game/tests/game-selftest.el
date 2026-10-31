;;; tests/game-selftest.el --- R9 legacy selftest/soak on new layers -*- lexical-binding: t; -*-

;; Pair 5 of plan 01 §2.1: the legacy selftest/soak entry points
;; (spec §5.1 pins the names) ported onto src/ layers and extended to
;; the new rules — demolish legality (R8), armed-verb click-place
;; (R1/R6, no cmd-build bypass per L-010), procgen variety (R3a),
;; rewards default (R5).  (The pair's red run proved them absent.)

(require 'cl-lib)

(defun cistern-test-legacy-verb-blocks ()
  (cl-assert (fboundp 'cistern-run-selftest)
             "extended selftest must exist on the new layers")
  (cl-assert (fboundp 'cistern-run-soak)
             "soak must exist on the new layers")
  ;; runs the full ported block set; any cl-assert failure propagates
  (cistern-run-selftest)
  (cistern-run-soak))

(provide 'game-selftest)
;;; tests/game-selftest.el ends here
