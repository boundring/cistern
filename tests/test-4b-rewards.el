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

;; ---------------------------------------------------------------------------
;; 4b Pair 2 — M1 demolish-with-refund (REWARDS-DESIGN §2 M1).

(defconst cistern-test-4b-m1-dust-glyphs '("·" ".")
  "M1 dust glyphs, REWARDS-DESIGN §4 trigger table (Demolish dust
row).  Dust face: the doc row says \"gray face\" but the §4 face
enum is closed (success/warning/error/info/bonus) — 'info is the
neutral enum pending the L-024 ruling.")

(defun cistern-test-4b-m1-demolish-refund ()
  ;; M1 acceptance (§2): 50% refund of the build cost, tile empty,
  ;; refuse on empty tile (no state change).  The doc's illustrative
  ;; arithmetic ("pipe worth 10 ... leaves 105") uses doc-era prices;
  ;; the invariant is the 50% refund.  Rounding is not doc-pinned —
  ;; FLOOR, ledgered (L-024).  The Phase-2 demolish fee (3) still
  ;; charges.  Anchors: (6,2)/(6,3)/(6,4) are floor neighbors of the
  ;; reserved starter plumbing (L-011 derivation), verified floor at
  ;; seed 42.
  (dolist (case '((pipe 6 2 2 1) (toilet 6 3 10 5) (tank 6 4 15 7)))
    (let* ((kind (nth 0 case))
           (x (nth 1 case)) (y (nth 2 case))
           (cost (nth 3 case)) (refund (nth 4 case))
           (st (cistern--new-game 42)))
      (cistern--cmd-build st kind x y)
      (cl-assert (eq (cistern--cell st x y) kind) "fixture placed")
      (let ((alloy0 (cistern-st-alloy st)))
        (cistern--cmd-demolish st x y)
        (cl-assert (eq (cistern--cell st x y) 'floor) "tile empty")
        (cl-assert (= (cistern-st-alloy st)
                      (+ (- alloy0 cistern-cost-demolish) refund))
                   "fee 3 charged, 50% of build cost refunded (floor)"))
      ;; dust: M1 trigger row — 3-5 sparkle particles at the demolished
      ;; tile, glyphs from the row, amounts drawn from the CHILD stream
      ;; (never the sim LCG); intents in the L-017 pinned shape
      (let* ((rng0 (cistern-st-rng st))
             (prng0 (cistern-st-particle-rng st))
             (intents (nth 2 (cistern--rewards-eval st nil))))
        (cl-assert (and (>= (length intents) 3) (<= (length intents) 5))
                   "demolish dust: 3-5 particles")
        (dolist (i intents)
          (cl-assert (equal (plist-get i :pos) (cons x y))
                     "dust spawns at the demolished tile")
          (cl-assert (member (plist-get i :glyph) cistern-test-4b-m1-dust-glyphs)
                     "dust glyphs from the M1 row")
          (cl-assert (eq (plist-get i :face) 'info)
                     "dust face is the neutral palette enum")
          (cl-assert (eq (plist-get i :layer) 'sparkle)
                     "dust layer is sparkle"))
        (cl-assert (= (cistern-st-rng st) rng0)
                   "sim LCG untouched by dust draws")
        (cl-assert (not (= (cistern-st-particle-rng st) prng0))
                   "dust draws consume the child stream (position advances)")
        (cl-assert (null (nth 2 (cistern--rewards-eval st nil)))
                   "emitted events drain on read"))))
  ;; refusal on empty tile: free, no event, no dust
  (let* ((st (cistern--new-game 42))
         (alloy0 (cistern-st-alloy st)))
    (cistern--cmd-demolish st 6 5)
    (cl-assert (= (cistern-st-alloy st) alloy0) "refusal is free")
    (cl-assert (null (cistern-st-rewards-events st))
               "refusal emits no event"))
  ;; starter plumbing is player-equivalent: refunds like any pipe
  ;; (L-020 note: losing scenario alloy shifts +1; breach timing is
  ;; bladder-driven and unaffected — the 4a tripwire confirms)
  (let* ((st (cistern--new-game 42))
         (alloy0 (cistern-st-alloy st)))
    (cistern--cmd-demolish st 4 2)
    (cl-assert (= (cistern-st-alloy st)
                  (+ (- alloy0 cistern-cost-demolish) 1))
               "starter pipe refunds like any pipe"))
  ;; determinism: identical replay → identical dust
  (let ((dust (lambda ()
                (let ((st (cistern--new-game 42)))
                  (cistern--cmd-build st 'pipe 6 2)
                  (cistern--cmd-demolish st 6 2)
                  (nth 2 (cistern--rewards-eval st nil))))))
    (cl-assert (equal (funcall dust) (funcall dust))
               "dust draws are deterministic from the child stream"))
  (message "CISTERN-4B-M1-OK"))
