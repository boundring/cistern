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

;; ---------------------------------------------------------------------------
;; 4b Pair 3 — M2 seeded-generation consumption (REWARDS-DESIGN §2 M2).

(defun cistern-test-4b-m2-solvability ()
  ;; M2's solvability property, stated as an invariant on the existing
  ;; generator (REWARDS-DESIGN §2 M2: "worker starts reach a toilet";
  ;; the plan's mapping shares R3's tests — same-seed identity and
  ;; ≥3 layout signatures live in domain-determinism / domain-procgen
  ;; and are NOT re-litigated here).  Bounded sweep: 20 consecutive
  ;; seeds plus the plan-pinned 42 — every generated map has its
  ;; reserved starter plumbing wired+usable and every spawn cell
  ;; passable AND walkable-connected to the starter toilet.
  (dolist (seed (append (number-sequence 1 20) (list 42)))
    (let* ((st (cistern--new-game seed))
           (d (cistern--flood st 3 3
                              (lambda (x y) (cistern--walkable-p st x y 3 3)))))
      ;; reserved starter plumbing: wired to a tank with capacity
      (cl-assert (cistern--toilet-usable-p st 3 3)
                 nil "seed %S: starter toilet not wired+usable" seed)
      ;; spawn cells: passable, and reachable from the starter toilet
      (dolist (p '((12 6) (14 7) (11 9) (15 6)))
        ;; spawn cells are (X Y) lists; flood keys are (X . Y) dot-conses
        (cl-assert (cistern--tile-passable-p
                     (cistern--cell st (nth 0 p) (nth 1 p)))
                   nil "seed %S: spawn %S not passable" seed p)
        (cl-assert (gethash (cons (nth 0 p) (nth 1 p)) d)
                   nil "seed %S: spawn %S not connected to the starter toilet"
                   seed p))))
  (message "CISTERN-4B-M2-OK"))

;; ---------------------------------------------------------------------------
;; 4b Pair 4 — M3 goal cards (REWARDS-DESIGN §2 M3, §5 goal-card shape).
;; Headless via direct rewards-eval calls; per-tick wiring is the M4/M5
;; step (split pinned in L-026).

(defconst cistern-test-4b-m3-goal-kinds
  '(relieves-served bursts-allowed contamination-ceiling)
  "§5 goal kinds.")

(defun cistern-test-4b-m3--completions (intents)
  "MapCompleted banner intents in INTENTS."
  (cl-remove-if-not
   (lambda (i) (and (eq (plist-get i :layer) 'banner)
                    (string-match-p "MAP COMPLETED" (or (plist-get i :text) ""))))
   intents))

(defun cistern-test-4b-m3-goal-cards ()
  ;; -- setter: shape validation, max 3 goals, known kinds, map_id = seed
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 3))))
    (let ((card (cistern-st-goal-card st)))
      (cl-assert (and card) "card set")
      (cl-assert (= (plist-get card :map-id) 42)
                 "map_id doubles as the game seed (L-025 ruling)")
      (cl-assert (= (plist-get card :tier) 2) "difficulty tier in shape"))
    (cl-assert (condition-case nil
                   (progn (cistern--cmd-set-goal-card
                           st '(:tier 2
                                :goals ((:kind relieves-served :target 1)
                                        (:kind relieves-served :target 2)
                                        (:kind bursts-allowed :target 1)
                                        (:kind contamination-ceiling :target 5))))
                          nil)
                 (error t))
               "a 4-goal card is rejected at card-set time")
    (cl-assert (condition-case nil
                   (progn (cistern--cmd-set-goal-card
                           st '(:tier 2 :goals ((:kind shrinky-dinks :target 1))))
                          nil)
                 (error t))
               "unknown goal kind rejected"))
  ;; (1) relieves-served: completes after the target, not before,
  ;; exactly once
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 3))))
    (cl-assert (null (cistern-test-4b-m3--completions
                      (nth 2 (cistern--rewards-eval st (make-list 2 'relief)))))
               "no completion before the target")
    (let ((done (cistern-test-4b-m3--completions
                 (nth 2 (cistern--rewards-eval st (make-list 2 'relief))))))
      (cl-assert (= 1 (length done))
                 "MapCompleted emitted when the goal satisfies")
      (cl-assert (plist-get (car done) :text) "completion is a banner intent"))
    (cl-assert (null (cistern-test-4b-m3--completions
                      (nth 2 (cistern--rewards-eval st (make-list 5 'relief)))))
               "MapCompleted emitted exactly once"))
  ;; (2) bursts-allowed: breaches count against the window; exceeding
  ;; fails the goal and the failure is observable in the goal's state
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind bursts-allowed :target 1))))
    (cistern--rewards-eval st '(burst))
    (cl-assert (plist-get (car (plist-get (cistern-st-goal-card st) :goals))
                          :satisfied)
               "one burst inside the window satisfies")
    (cistern--rewards-eval st '(burst))
    (cl-assert (not (plist-get (car (plist-get (cistern-st-goal-card st) :goals))
                               :satisfied))
               "exceeding the window fails the goal"))
  ;; (3) contamination-ceiling: violated when contam ever exceeds it
  ;; (the counter is monotonic, so ever-exceeded == exceeded at check)
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind contamination-ceiling :target 1))))
    (cistern--rewards-eval st nil)
    (cl-assert (plist-get (car (plist-get (cistern-st-goal-card st) :goals))
                          :satisfied)
               "contam inside the ceiling satisfies")
    (setf (cistern-st-contam st) 2)
    (cistern--rewards-eval st nil)
    (cl-assert (not (plist-get (car (plist-get (cistern-st-goal-card st) :goals))
                               :satisfied))
               "contam past the ceiling fails the goal"))
  ;; (6) re-check every tick: a card satisfied mid-run and violated
  ;; later never completes — completion requires check-time satisfaction
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 2)
                          (:kind contamination-ceiling :target 0))))
    (cistern--rewards-eval st nil)                       ; ceiling ok, relief 0
    (setf (cistern-st-contam st) 1)                      ; ceiling violated later
    (cistern--rewards-eval st (make-list 2 'relief))     ; relief ok NOW, ceiling FAILED
    (let ((intents (nth 2 (cistern--rewards-eval st (make-list 2 'relief)))))
      (cl-assert (null (cistern-test-4b-m3--completions intents))
                 "no completion after a later violation")
      (cl-assert (not (plist-get (cistern-st-goal-card st) :completed))
                 "card stays incomplete")))
  ;; (5) difficulty_tier scales targets per §5 pay-forward (M1 floor
  ;; precedent): Tier1 −25% / Tier3 +25% in the goal's difficulty
  ;; direction; the tier input is a card-construction parameter here —
  ;; M4's reputation feeds it (pinned L-026)
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 1 :goals ((:kind relieves-served :target 4)))) ; easier: 3
    (cistern--rewards-eval st (make-list 3 'relief))
    (cl-assert (plist-get (cistern-st-goal-card st) :completed)
               "tier 1 scales a 4-relieve goal down to 3"))
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 3 :goals ((:kind relieves-served :target 4)))) ; harder: 5
    (cistern--rewards-eval st (make-list 4 'relief))
    (cl-assert (not (plist-get (cistern-st-goal-card st) :completed))
               "tier 3 does not complete at the unscaled target")
    (cistern--rewards-eval st (make-list 1 'relief))
    (cl-assert (plist-get (cistern-st-goal-card st) :completed)
               "tier 3 completes at 5 relieves"))
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 3 :goals ((:kind contamination-ceiling :target 8)))) ; harder: 6
    (setf (cistern-st-contam st) 7)
    (cistern--rewards-eval st nil)
    (cl-assert (not (plist-get (car (plist-get (cistern-st-goal-card st) :goals))
                               :satisfied))
               "tier 3 tightens a ceiling goal (8 → 6)"))
  (message "CISTERN-4B-M3-OK"))
