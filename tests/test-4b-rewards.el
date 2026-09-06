;;; tests/test-4b-rewards.el --- R5 seeded reward stream + fixture, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

;; REWARDS-DESIGN §4: the child stream is derived from the game seed
;; (seed ⊕ stream-id) and the "first 100 stream values pinned as a
;; fixture".  The doc pins the DERIVATION, not the values — §6 defers
;; fixtures to implementation ("with seeded fixtures"), and §4's
;; failure mode 2 states their purpose: drift detection ("change
;; fails loudly").  Pinned pair: (seed 42, stream-id 1) — 42 is the
;; plan-pinned scenario seed; the particle field's stream-id naming
;; lands with the M6 field pair.  Values were generated once from the
;; derivation formula (x0 = seed ⊕ id; x(k+1) = (x(k)·1103515245 +
;; 12345) mod 2^31 — the domain LCG recurrence, the only RNG in the
;; codebase) BEFORE the implementation existed.  stream-id 0 is
;; RESERVED: it reproduces the sim LCG's own sequence.
(defconst cistern-test-4b-stream-fixture
  (vector
206527624 86771233 1008917062 1367110663 566343988
1478615901 1352815826 929188259 1583035552 1251891289
1915546654 172350719 1431239372 684925205 557296682
1839548955 936835000 374454673 1048338678 1959030007
249550692 71785933 713397890 961077651 1668613584
1333332425 1375377614 1066796015 32288508 1107261829
850097114 1156116491 1137950440 1958947073 626848678
1395950055 211411348 1287148605 2018812978 918377859
1694335744 266008377 648335742 829802207 1631047468
1307233781 943228810 135918075 1038660120 417813617
379556438 1158394583 1606604740 1229702829 1654291938
1290708339 569879600 1242243241 375821870 553919951
526605148 676077157 13231930 1799835627 1652085064
1659190241 1692351750 810090439 669891060 899200285
1252139922 1120653667 539394400 1544586777 1278928606
1428168895 1533170572 144337621 1812632298 1145047515
1286020216 178511697 1064760246 2024499383 258836516
1626742669 2054591810 2030295379 1544356496 867313545
668779406 174634927 1458026428 1913434949 442862234
2056462283 643208104 264912577 1652668006 1873931687))

(defun cistern-test-4b--draws (seed id n)
  "First N raw values of the (SEED, ID) child stream, as a list."
  (let ((pos (cistern--stream-init seed id))
        (out nil))
    (dotimes (_ n)
      (setq pos (cistern--stream-next pos))
      (push pos out))
    (nreverse out)))

(defun cistern-test-4b-stream-fixture ()
  ;; 1. verbatim fixture: the derivation output matches the pinned values
  (cl-assert (equal (cistern-test-4b--draws 42 1 100)
                    (append cistern-test-4b-stream-fixture nil))
             "child stream matches the pinned first-100 fixture")
  ;; 2. different stream-ids give different sequences
  (cl-assert (not (equal (cistern-test-4b--draws 42 1 100)
                         (cistern-test-4b--draws 42 2 100)))
             "different stream-ids diverge")
  ;; 3. the sim LCG is untouched by any number of stream draws —
  ;;    draws are pure (explicit position), they never take state
  (let* ((st (cistern--new-game 42))
         (snapshot (prin1-to-string st))
         (rng0 (cistern-st-rng st))
         (pos (cistern--stream-init (cistern-st-seed st) 1)))
    (dotimes (_ 500)                   ; well past the fixture horizon
      (setq pos (cistern--stream-next pos)))
    (cl-assert (= (cistern-st-rng st) rng0)
               "sim LCG untouched by stream draws")
    (cl-assert (string= snapshot (prin1-to-string st))
               "state untouched by stream draws")
    ;; derivation reads the game seed FROM state (REWARDS-DESIGN §5:
    ;; rewards-eval consumes state only — the seed must live in state)
    (cl-assert (equal (cistern-test-4b--draws (cistern-st-seed st) 1 100)
                      (append cistern-test-4b-stream-fixture nil))
               "state-derived stream matches the fixture"))
  ;; 4. deterministic across fresh construction
  (cl-assert (equal (cistern-test-4b--draws
                     (cistern-st-seed (cistern--new-game 42)) 1 100)
                    (cistern-test-4b--draws
                     (cistern-st-seed (cistern--new-game 42)) 1 100))
             "fresh same-seed construction reproduces the stream")
  (message "CISTERN-4B-STREAM-OK"))

(provide 'test-4b-rewards)
;;; tests/test-4b-rewards.el ends here
