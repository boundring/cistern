;;; tests/test-v5.el --- CISTERN v5 wave 1: the violent base -*- lexical-binding: t; -*-

;; Batch tests for docs/v5/V5-SPEC.md WAVE 1 (V5-01..V5-07, build
;; order), one entry per directive acceptance, registered in
;; tests/run.el.  Reds before greens per PROCESS; ledger entries in
;; docs/FAILURE-LEDGER.md (continuing past L-095).

(require 'cl-lib)

;; Repo root pinned at load time (L-008 pattern from test-v4).
(defconst cistern-test-v5--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-v5 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-v5--root))
(load (expand-file-name "src/cistern-domain.el" cistern-test-v5--root))
(load (expand-file-name "src/cistern-game.el" cistern-test-v5--root))

;;; --- V5-01: entity struct + dossiers + stream 4 (CB1, CB13 partial) -------------

(defun cistern-test-v5-01--expected-dossiers ()
  "Independently derive the three raiders' dossiers from the RAW
stream-4 recurrence (20260826, mid-bits slice): 16 d6 per raider,
4d6-drop-lowest x 4, in the pinned call order.  COMBAT §7's
worked-example ledger is reachable for g1 — (11 8 10 15) — and is
pinned as a literal in the test; the g2/g3 rows of that table do
not exist in the real stream (doc fixture drift, ledgered L-096),
so the procedure itself is the binding contract for them."
  (let ((p 20260826) (expected nil))
    (dotimes (_ 3)
      (let ((blocks nil))
        (dotimes (_ 4)
          (let (rolls)
            (dotimes (_ 4)
              (setq p (cistern--stream-next p))
              (push (1+ (% (ash p -6) 6)) rolls))
            (setq rolls (sort rolls #'<))
            (push (+ (nth 1 rolls) (nth 2 rolls) (nth 3 rolls))
                  blocks)))
        (setq expected (append expected (list (reverse blocks))))))
    expected))

(defun cistern-test-v5-01-entities ()
  "V5-01 (CB1): seed-20260830 pinned raid draws spawn three warband
entities `g1..g3' with 4d6-drop-lowest stats computed from stream 4
in the pinned call order, hp = kind-base + GRIT mod, spawn-appended
to `hostiles'.  Worker struct carries `hp' and a stable spawn-index
and the identity glyph reads the STORED index, not list position."
  (let ((st (cistern--new-game 20260830)))
    ;; stream 4 initializes at seed ⊕ 4 (COMBAT §5.2: 20260830 ⊕ 4)
    (cl-assert (= (cistern-st-combat-pos st) 20260826)
               t "combat-pos inits to seed xor 4")
    (cl-assert (null (cistern-st-hostiles st))
               t "a fresh sector has no hostiles")
    ;; three warband spawns, pinned call order
    (cistern--spawn-enemy st 'warband 'warband 2 2)
    (cistern--spawn-enemy st 'warband 'warband 2 3)
    (cistern--spawn-enemy st 'warband 'warband 3 2)
    (cistern-test-v5-01--check-hostiles st))
  ;; CB13 partial: two runs of one seed → identical hostiles + combat-pos
  (let ((hash1 (cistern-test-v5-01--run-hash))
        (hash2 (cistern-test-v5-01--run-hash)))
    (cl-assert (string= hash1 hash2)
               t "two runs → identical hostiles and combat-pos"))
  ;; the identity pin: the glyph reads the stored spawn-index, so a
  ;; list-position change renames NOBODY (fail-first for C4)
  (let ((st (cistern--new-game 7)))
    (let ((b (nth 1 (cistern-st-creators st))))
      (setf (cistern-st-creators st) (list b))
      (cl-assert (equal (cistern--worker-glyph st b) "β")
                 t "β keeps β after α leaves the list")))
  ;; every fresh worker carries a stable spawn-index
  (let ((st (cistern--new-game 9)))
    (cl-assert (equal (mapcar #'cistern--worker-spawn-idx
                              (cistern-st-creators st))
                      '(0 1 2 3))
               t "procgen workers get spawn-indexes 0..3"))
  (message "CISTERN-V5-01-OK"))

(defun cistern-test-v5-01--check-hostiles (st)
  "The CB1 entity assertions over ST's spawned raiders."
  (let ((hs (cistern-st-hostiles st))
        (want (cistern-test-v5-01--expected-dossiers)))
    (cl-assert (= (length hs) 3) t "three entities spawn-appended")
    (cl-assert (equal (cistern--enemy-id (nth 0 hs)) "g1")
               t "ids are the sequential g<N> counter")
    (cl-assert (equal (cistern--enemy-id (nth 1 hs)) "g2") t "g2")
    (cl-assert (equal (cistern--enemy-id (nth 2 hs)) "g3") t "g3")
    ;; g1 pinned to COMBAT §7's worked-example ledger literal
    (cl-assert (equal (nth 0 want) '(11 8 10 15))
               t "g1 matches COMBAT §7's worked-example ledger")
    (dotimes (i 3)
      (cl-assert (equal (cistern--enemy-stats (nth i hs)) (nth i want))
                 t "g%d stats match the 4d6-drop-lowest draw" (1+ i))
      ;; hp = kind-base (6) + GRIT mod, from the SAME dossiers
      (cl-assert (= (cistern--enemy-hp (nth i hs))
                    (+ 6 (cistern--rpg-mod (nth 1 (nth i want)))))
                 t "g%d hp = kind-base + GRIT mod" (1+ i)))
    ;; stream 4 advanced by exactly 48 d6 draws (3 raiders x 16)
    (let ((p 20260826))
      (dotimes (_ 48) (setq p (cistern--stream-next p)))
      (cl-assert (= (cistern-st-combat-pos st) p)
                 t "combat-pos advanced by exactly the 48 dossier d6"))))

(defun cistern-test-v5-01--run-hash ()
  "One fresh 20260830 run with three raiders: a stable hash of the
hostiles and the stream-4 position."
  (secure-hash
   'md5 (prin1-to-string
         (let ((st (cistern--new-game 20260830)))
           (cistern--spawn-enemy st 'warband 'warband 2 2)
           (cistern--spawn-enemy st 'warband 'warband 2 3)
           (cistern--spawn-enemy st 'warband 'warband 3 2)
           (list (cistern-st-hostiles st)
                 (cistern-st-combat-pos st))))))

;;; --- V5-02: combat resolution on the shared pipeline (CB2, CB10) ---------------

(defun cistern-test-v5-02-resolution ()
  "V5-02 (CB2): attacks resolve through the SHARED margin-band +
promotion path and one gethash on (dmg-minor|dmg-warband . band);
band 0 deals 0 and logs nothing; the warband matrix's band 3 deals
exactly 3.  (CB10 partial): combat draws touch ONLY combat-pos —
the sim LCG, particle stream and RPG stream positions are
untouched, and no log line is emitted for a miss."
  ;; the two damage matrices live in the ONE hash (A9 shape)
  (cl-assert (equal (cistern--matrix-effect 'dmg-minor 0) '(:dmg 0))
             t "band 0 is a silent miss")
  (cl-assert (equal (cistern--matrix-effect 'dmg-minor 3) '(:dmg 2))
             t "minor band 3 = 2")
  (cl-assert (equal (cistern--matrix-effect 'dmg-warband 2) '(:dmg 2))
             t "warband band 2 = 2")
  (cl-assert (equal (cistern--matrix-effect 'dmg-warband 3) '(:dmg 3))
             t "warband band 3 = exactly 3")
  ;; nat-20 promotes to band 3, nat-1 demotes to band 0 — found by
  ;; scanning the raw stream, then replayed through the production fn
  (let ((st (cistern--new-game 31)))
    (cl-assert (= (cistern-test-v5-02--band-at st 20) 3)
               t "nat-20 promotes to band 3")
    (cl-assert (= (cistern-test-v5-02--band-at st 1) 0)
               t "nat-1 demotes to band 0"))
  ;; one strike = exactly one stream-4 draw; the effect comes from
  ;; the shared hash; misses log nothing and touch no other stream
  (let ((st (cistern--new-game 37)))
    (let ((rng (cistern-st-rng st)) (prng (cistern-st-particle-rng st))
          (rpg (cistern-st-rpg-pos st))
          (before (cistern-st-combat-pos st)) (loglen (length (cistern-st-log st))))
      (cistern--combat-strike st 'dmg-minor 0 10)
      (cl-assert (= (cistern-st-combat-pos st)
                    (cistern--stream-next before))
                 t "one strike consumes exactly one d20 draw")
      (cl-assert (= (cistern-st-rng st) rng) t "sim LCG untouched")
      (cl-assert (= (cistern-st-particle-rng st) prng)
                 t "particle stream untouched")
      (cl-assert (= (cistern-st-rpg-pos st) rpg) t "RPG stream untouched")
      (cl-assert (= (length (cistern-st-log st)) loglen)
                 t "resolution itself logs nothing")))
  ;; targeting: guild NEVER selected, focus preferred, else nearest
  (let ((st (cistern--new-game 41)))
    (cistern--spawn-enemy st 'guild 'fixer 5 5)
    (cistern--spawn-enemy st 'warband 'warband 3 5)
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 4) (setf (cistern--worker-y w) 5)
      (let ((tgt (cistern--combat-target st w)))
        (cl-assert (and tgt (equal (cistern--enemy-id tgt) "g2"))
                   t "guild filtered: worker strikes the warband"))
      ;; focus preference: focus g2 explicitly, target unchanged
      (setf (cistern-st-focus st) "g2")
      (let ((tgt (cistern--combat-target st w)))
        (cl-assert (equal (cistern--enemy-id tgt) "g2")
                   t "focus target preferred"))
      ;; focus on a NON-adjacent hostile falls back to nearest adjacent
      (setf (cistern-st-focus st) "g99")
      (let ((tgt (cistern--combat-target st w)))
        (cl-assert (equal (cistern--enemy-id tgt) "g2")
                   t "non-adjacent focus falls back to nearest"))))
  (message "CISTERN-V5-02-OK"))

(defun cistern-test-v5-02--band-at (st roll)
  "Point ST's combat-pos at a draw that reads ROLL, then assert
the production band fn through it (returns the band)."
  (let ((p (cistern-st-combat-pos st)) found)
    (dotimes (_ 500)
      (let ((r (cistern--combat-d20-pos p)))
        (when (and (not found) (= (car r) roll)) (setq found p))
        (setq p (cdr r))))
    (cl-assert found t "fixture: a nat-%d within 500 draws" roll)
    (setf (cistern-st-combat-pos st) found)
    (cistern--combat-band st -5 15)))

;;; --- V5-03: injury ladder + worker death (CB3, CB4) ----------------------------

(defun cistern-test-v5-03-injury ()
  "V5-03 (CB3/CB4): the injury ladder, shift heal, and the death
procedure with the spawn-index identity pin.  See the section
helpers below for each coupling."
  (cistern-test-v5-03--states)
  (cistern-test-v5-03--gait)
  (cistern-test-v5-03--heal)
  (cistern-test-v5-03--death)
  (message "CISTERN-V5-03-OK"))

(defun cistern-test-v5-03--states ()
  "hp max = 8 + GRIT mod at spawn; LIMP at <= 60%; SHAKEN at
<= 40% with NERVE -2 inside the existing [50,68] clamp; damage
worsens mine rate via the existing clamp."
  (let* ((st (cistern--new-game 43))
         (w (nth 0 (cistern-st-creators st)))
         (max (+ 8 (cistern--rpg-mod (nth 1 (cistern--worker-stats w))))))
    (cl-assert (= (cistern--worker-hp w) max)
               t "spawn hp max = 8 + GRIT mod")
    (cl-assert (null (cistern--worker-injury-state w))
               t "a fresh worker has no injury state")
    (setf (cistern--worker-hp w) (/ (* 3 max) 5))
    (cl-assert (eq (cistern--worker-injury-state w) 'limp)
               t "hp at the 60% threshold limps")
    (setf (cistern--worker-hp w) 1)
    (cl-assert (eq (cistern--worker-injury-state w) 'shaken)
               t "hp at 40% is shaken")
    (let ((base (cistern--rpg-stat-mod w 2)))
      (cl-assert (= (cistern--worker-nerve-eff w) (- base 2))
                 t "shaken lowers NERVE by 2")
      (cl-assert (<= 50 (cistern--rpg-seek-eff (cistern--worker-nerve-eff w)) 68)
                 t "seek_eff stays inside the existing clamp")))
  (let* ((st (cistern--new-game 43))
         (w (nth 1 (cistern-st-creators st)))
         (healthy (cistern--worker-mine-rate w)))
    (setf (cistern--worker-hp w) (1- (cistern--worker-hp w)))
    (cl-assert (= (cistern--worker-mine-rate w) (clamp 2 (1+ healthy) 6))
               t "damage worsens mine rate through the clamp")))

(defun cistern-test-v5-03--find-cell (st kind)
  "First (coordinate-order) cell of KIND on the map, as (X . Y)."
  (let ((found nil) (i 0))
    (while (and (not found) (< i (length (cistern-st-map st))))
      (when (eq (aref (cistern-st-map st) i) kind)
        (setq found (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st)))))
      (setq i (1+ i)))
    found))

(defun cistern-test-v5-03--gait ()
  "LIMP: 1 step per 2 ticks (even ticks move), stride off.  Relief
journeys exempt (P5): toward a toilet the gait normalizes."
  (let* ((st (cistern--new-game 47))
         (w (nth 0 (cistern-st-creators st)))
         (floor-cell (cistern-test-v5-03--find-cell st 'floor))
         (toilet-cell (cistern-test-v5-03--find-cell st 'toilet)))
    (cl-assert floor-cell t "fixture: the map has a floor cell")
    (cl-assert toilet-cell t "fixture: the map has a toilet cell")
    ;; exactly at the 60% threshold: LIMP (not shaken) for any stats
    (setf (cistern--worker-hp w) (/ (* 3 (cistern--worker-hp-max w)) 5))
    (setf (cistern--worker-journey w) nil)
    (let ((x0 (cistern--worker-x w)) (y0 (cistern--worker-y w)))
      (cistern--step-toward st w (car floor-cell) (cdr floor-cell))
      (cl-assert (= 1 (+ (abs (- (cistern--worker-x w) x0))
                         (abs (- (cistern--worker-y w) y0))))
                 t "limping: exactly one step on the even tick")
      (setf (cistern-st-tick st) 1)
      (cistern--step-toward st w (car floor-cell) (cdr floor-cell))
      (cl-assert (= 1 (+ (abs (- (cistern--worker-x w) x0))
                         (abs (- (cistern--worker-y w) y0))))
                 t "limping: the odd tick does not move"))
    ;; relief suspension: toward a toilet the limping worker moves
    (let ((x0 (cistern--worker-x w)) (y0 (cistern--worker-y w)))
      (setf (cistern-st-tick st) 1)
      (setf (cistern--worker-journey w) nil)
      (cl-assert (eq t (cistern--step-toward st w (car toilet-cell)
                                        (cdr toilet-cell)))
                 t "relief journeys are exempt from the limp gait"))))

(defun cistern-test-v5-03--heal ()
  "Shift boundary (tick % 40 = 0): +1 hp, no cost, no roll."
  (let* ((st (cistern--new-game 53))
         (w (nth 0 (cistern-st-creators st)))
         (max (+ 8 (cistern--rpg-mod (nth 1 (cistern--worker-stats w))))))
    (setf (cistern--worker-hp w) (1- max))
    (setf (cistern-st-tick st) 40)
    (cistern--phase-migration st)
    (cl-assert (= (cistern--worker-hp w) max)
               t "+1 hp at the shift boundary")))

(defun cistern-test-v5-03--death ()
  "CB4: hp 0 removes the worker from creators, frees their
mid-use toilet, removes a gripping leech, emits `worker-death' —
and survivors keep their glyphs (the spawn-index, not list
position)."
  (let* ((st (cistern--new-game 59))
         (a (nth 0 (cistern-st-creators st)))
         (b (nth 1 (cistern-st-creators st))))
    ;; α mid-use: the toilet's :busy must clear
    (setf (cistern--worker-using a) t)
    (setf (cistern--worker-toilet a) '(11 9))
    (puthash '(11 9) (list :busy t :type 'long-drop) (cistern-st-toilets st))
    (let ((leech (cistern--spawn-enemy st 'fauna 'leech 12 9)))
      (setf (cistern--enemy-grip leech) a)
      (setf (cistern--worker-hp a) 1)
      (cistern--worker-damage st a 5)
      (cl-assert (not (memq a (cistern-st-creators st)))
                 t "the dead worker is removed from creators")
      (cl-assert (null (plist-get (gethash '(11 9) (cistern-st-toilets st))
                                  :busy))
                 t "a mid-use toilet's :busy clears")
      (cl-assert (not (memq leech (cistern-st-hostiles st)))
                 t "the gripping leech is removed with the body")
      (cl-assert (memq 'worker-death (mapcar #'cistern--event-kind
                                             (cistern-st-rewards-events st)))
                 t "a worker-death event joins the pending list")
      (cl-assert (equal (cistern--worker-glyph st b) "β")
                 t "β still renders β — identity is the spawn-index"))))

;; --- V5-04 fixtures (re-added per L-099; combat enabled per-test) ----------------
;; The commit-boundary red for these was captured against 255a3b3 and is
;; documented in L-099 (4/115: void-function cistern--maybe-raid /
;; cistern--infest-dc / cistern-st-raid).  The setter is called as the
;; first body form of each ticking fixture — never file-globally (L-099:
;; a load-time setq poisons every combat-disabled v4 scenario test).

(defun cistern-test-v5-04--combat-on ()
  (setq cistern-combat-enabled t))

(defun cistern-test-v5-04--find-nat (st lo)
  "Point ST's combat-pos at a draw that reads >= LO (fixture)."
  (let ((p (cistern-st-combat-pos st)) found)
    (dotimes (_ 2000)
      (let ((r (cistern--combat-d20-pos p)))
        (when (and (not found) (>= (car r) lo)) (setq found p))
        (setq p (cdr r))))
    (cl-assert found t "fixture: a d20 >= %d within 2000 draws" lo)
    (setf (cistern-st-combat-pos st) found)))

(defun cistern-test-v5-04-raid ()
  "V5-04 (CB6): act-scaled raids — tick 120 with d20 >= 8 opens ONE
raid of clamp(pop-1,1,3); P1: contamination >= 18 or pop <= 1
suppresses the draw entirely; P3: the raid closes by open+40; the
routed close carries `warband-routed' instead of the CLOSED line."
  (cistern-test-v5-04--combat-on)
  ;; direct: the raid opens at the act II floor with a forced high draw
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-tick st) 120)
    (cistern-test-v5-04--find-nat st 8)
    (cistern--maybe-raid st)
    (let ((raid (cistern-st-raid st)))
      (cl-assert (and raid (plist-get raid :open))
                 t "a raid opens at the act II window floor")
      (cl-assert (= (plist-get raid :open) 120) t "T0 is the open tick")
      (cl-assert (= (length (cistern-st-hostiles st)) 3)
                 t "act II: clamp(pop-1,1,3) with pop 4 gives 3 raiders")
      (cl-assert (cl-every (lambda (e)
                             (eq (cistern--enemy-faction e) 'warband))
                           (cistern-st-hostiles st))
                 t "the raid spawns warband entities")
      (cl-assert (memq 'raid (mapcar #'cistern--event-kind
                                     (cistern-st-rewards-events st)))
                 t "a `raid' OPEN event joins the pending list")
      (cl-assert (cl-some (lambda (e) (memq (cistern--enemy-idle e) '(0 1 2)))
                          (cistern-st-hostiles st))
                 t "every raider carries an objective")))
  ;; act III scaling: raider count clamp(pop-1,2,4), DC 5
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-tick st) 240)
    (cistern-test-v5-04--find-nat st 5)
    (cistern--maybe-raid st)
    (cl-assert (cistern-st-raid st) t "act III opens at DC 5")
    (cl-assert (= (length (cistern-st-hostiles st)) 3)
               t "act III: clamp(pop-1,2,4) with pop 4 gives 3 raiders"))
  ;; P1: contamination >= limit-2 suppresses the draw entirely
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-tick st) 120)
    (setf (cistern-st-contam st) (1- cistern-contam-limit))
    (cistern-test-v5-04--find-nat st 8)  ; even a nat-20 stays a no-op
    (cistern--maybe-raid st)
    (cl-assert (null (cistern-st-raid st)) t "P1: contam >= 18 suppresses")
    (cl-assert (null (cistern-st-hostiles st)) t "P1: no raiders spawn"))
  ;; P1: pop <= 1 suppresses
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-tick st) 120)
    (setf (cistern-st-creators st) (list (nth 0 (cistern-st-creators st))))
    (cistern-test-v5-04--find-nat st 8)
    (cistern--maybe-raid st)
    (cl-assert (null (cistern-st-raid st)) t "P1: pop <= 1 suppresses"))
  ;; P3: forced withdrawal at open+40
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-raid st) (list :open 120))
    (setf (cistern-st-tick st) 160)
    (cistern--phase-hostiles st)
    (cl-assert (= (plist-get (cistern-st-raid st) :last-end) 160)
               t "P3: the raid closes by open+40")
    (cl-assert (memq 'raid (mapcar #'cistern--event-kind
                                   (cistern-st-rewards-events st)))
               t "the CLOSED line joins the pending list"))
  ;; routed: every raider killed before the cap -> warband-routed
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-raid st) (list :open 130))
    (setf (cistern-st-tick st) 135)
    (let ((e (cistern--spawn-enemy st 'warband 'warband 2 2)))
      (cistern--enemy-damage st e 99 nil)
      (cistern--phase-hostiles st)
      (cl-assert (plist-get (cistern-st-raid st) :last-end)
                 t "the raid closes when the last raider falls")
      (cl-assert (memq 'warband-routed (mapcar #'cistern--event-kind
                                               (cistern-st-rewards-events st)))
                 t "the routed close carries `warband-routed'")))
  (message "CISTERN-V5-04-RAID-OK"))

(defun cistern-test-v5-04-infestation ()
  "V5-04 (CB7): with 3 severed lines the S3 DC is 11 (14 - 3),
floored at 8; a success spawns exactly one rat at a dead pipe and
emits one `infestation' event."
  (cistern-test-v5-04--combat-on)
  (cl-assert (= (cistern--infest-dc 3) 11) t "14 - 3 severed")
  (cl-assert (= (cistern--infest-dc 7) 8) t "the DC floors at 8")
  (cl-assert (= (cistern--infest-dc 0) 14) t "base DC 14")
  (let ((st (cistern--new-game 77)))
    (let* ((cell (cistern-test-v5-03--find-cell st 'floor))
           (x (car cell)) (y (cdr cell)))
      (cistern--set-cell st x y 'pipe)
      (cl-assert (not (cistern--pipe-live-p st x y))
                 t "fixture: the new pipe is dead (not connected)")
      (setf (cistern-st-tick st) 20)
      (cistern-test-v5-04--find-nat st 11)
      (let ((pos0 (cistern-st-combat-pos st)))
        (cistern--maybe-infestation st)
        (cl-assert (= 1 (cl-count 'rat (cistern-st-hostiles st)
                                   :key #'cistern--enemy-kind))
                   t "exactly one rat spawned")
        (cl-assert (memq 'infestation (mapcar #'cistern--event-kind
                                              (cistern-st-rewards-events st)))
                   t "one `infestation' event joins the pending list")
        (cl-assert (/= (cistern-st-combat-pos st) pos0)
                   t "the S3 draw was consumed")))))

(defun cistern-test-v5-04-events ()
  "V5-04 (CB12): combat events reach the pending list exactly when
their condition fires; rewards-eval ignores them; a scenario hook
with :condition (event raid) opens, resolves, and the resolution
is visible to later acts (STORY §7.2 machinery untouched)."
  (cistern-test-v5-04--combat-on)
  (let ((st (cistern--new-game 20260830)))
    (setf (cistern-st-tick st) 120)
    (cistern-test-v5-04--find-nat st 8)
    (let ((roll-pos (and (cistern-st-story st)
                         (plist-get (cistern-st-story st) :roll-pos)))
          (combat-pos (cistern-st-combat-pos st)))
      (cistern--maybe-raid st)
      (cl-assert (/= (cistern-st-combat-pos st) combat-pos)
                 nil "sanity: the raid draw consumed stream 4")
      (when roll-pos
        (cl-assert (= (plist-get (cistern-st-story st) :roll-pos) roll-pos)
                   t "combat leaves :roll-pos untouched"))
      ;; rewards-eval ignores foreign kinds
      (cistern--rewards-eval st nil)
      (let ((card (cistern-st-goal-card st)))
        (cl-assert (= (plist-get card :relieves) 0)
                   t "rewards-eval ignores the raid event"))))
  ;; the story hook machine reads combat events through a real bank
  (let ((bank-file (make-temp-file "cistern-v5-bank" nil ".el")))
    (with-temp-file bank-file
      (insert
       "(defconst cistern-bank-v5-test\n"
       "  '(:kind scenario :version \"1\" :generator \"v5 fixture\"\n"
       "    :copy ((v5-premise . \"THE MAIN IS CLAIMED\")\n"
       "           (v5-verdict . \"RAID HOOK RESOLVED\"))\n"
       "    :entries\n"
       "    ((:id v5-raid-story :premise v5-premise :acts 3 :tiers (60 30 10)\n"
       "      :hooks ((:id v5-raid-hook :act 1 :window (20 . 90)\n"
       "               :condition (event raid) :requires nil\n"
       "               :matrix v5-m :resolve-copy v5-verdict))\n"
       "      :matrices\n"
       "      ((:id v5-m :difficulty 1 :stat tolerance :act-mods (0 0 0)\n"
       "        :outcomes ((:effect none :line-key v5-verdict) (:effect none :line-key v5-verdict) (:effect none :xp 1 :line-key v5-verdict)\n"
       "                   (:effect none :line-key v5-verdict))))))))\n"
       "(defconst cistern-bank-v5-quirks\n"
       "  '(:kind quirk :version \"1\" :generator \"v5 fixture\"\n"
       "    :copy ((v5-quirk . \"READS THE PRESSURE LOG TWICE\"))\n"
       "    :entries\n"
       "    ((:id quirk-v5-tight :context tolerance :copy-key v5-quirk))))\n"))
    (setq cistern--banks nil cistern--story-copy nil
          cistern--matrix-sources (make-hash-table :test 'eq))
    (cistern--banks-load (list bank-file))
    (let ((st (cistern--new-game 20260830)))
      (setf (cistern-st-tick st) 50)
      (push (list 'raid 'open 2 2) (cistern-st-rewards-events st))
      (cistern--story-eval st)
      (let* ((story (cistern-st-story st))
             (hook (cl-find 'v5-raid-hook (plist-get story :hooks)
                            :key (lambda (h) (plist-get h :id)))))
        (cl-assert (eq (plist-get hook :state) 'resolved)
                   t "the (event raid) hook opened and resolved")
        (cl-assert (memq 'v5-raid-hook (plist-get story :callbacks))
                   t "the resolution is visible to later acts")))
  (message "CISTERN-V5-04-EVENTS-OK")))

(defun cistern-test-v5-04--soak-hash ()
  "A 300-tick combat-active soak of seed 20260830: one content hash."
  (cistern-test-v5-04--combat-on)
  (let ((st (cistern--new-game 20260830)))
    (dotimes (_ 300) (cistern--sim-tick st))
    (list st
          (secure-hash
           'md5 (prin1-to-string
                 (list (cistern-st-combat-pos st)
                       (cistern-st-raid st)
                       (cistern-st-focus st)
                       (mapcar (lambda (e) (list (cistern--enemy-id e)
                                                 (cistern--enemy-x e)
                                                 (cistern--enemy-y e)
                                                 (cistern--enemy-hp e)
                                                 (cistern--enemy-gnaw e)))
                               (cistern-st-hostiles st))
                       (mapcar #'cistern--worker-hp (cistern-st-creators st))
                       (length (cistern-st-log st))))))))

(defun cistern-test-v5-04-determinism ()
  "V5-04 (CB13/P6): two 300-tick combat-active runs of seed
20260830 give identical hashes including combat-pos, hostiles,
raid and worker hp; hostiles <= 8; raid state stays a legal shape;
the bladder window guard (A12/P6) still holds for every worker."
  (let* ((h1 (cistern-test-v5-04--soak-hash))
         (h2 (cistern-test-v5-04--soak-hash))
         (st (car h1)))
    (cl-assert (equal (cdr h1) (cdr h2))
               t "two runs give byte-identical combat state hashes")
    (cl-assert (<= (length (cistern-st-hostiles st))
                   (cistern--combat-k 'hostiles-max))
               t "P2: live hostiles <= 8")
    (let ((raid (cistern-st-raid st)))
      (cl-assert (or (null raid) (plist-get raid :open)
                     (plist-get raid :last-end))
                 t "P6: raid state is a legal shape"))
    (dolist (w (cistern-st-creators st))
      (let ((window (- (/ (- 120 (cistern--rpg-seek-eff
                                   (cistern--worker-nerve-eff w))) 2)
                       cistern-use-ticks)))
        (cl-assert (>= window 22) t "P6: bladder window >= 22")))
    (message "CISTERN-V5-04-DET-OK")))

;; --- V5-05 fixtures: guild fixer loop + guard-rail (CB8, CB5) --------------------

(defun cistern-test-v5-05-guild ()
  "V5-05 (CB8): a fixer restores a dead pipe (the gnaw-made
hazard — the pipe's remains, L-100) in 2 ticks, deducts exactly 1
alloy, repeats <= 3 times, then departs; with alloy 0 they wait 20
ticks and leave.  `guild-depart' is LOG-ONLY (ruling 3)."
  (cistern-test-v5-04--combat-on)
  ;; fixture: one live pipe cell converted to hazard (a completed gnaw)
  (let* ((st (cistern--new-game 20260830))
         (pipe (cl-find-if
                (lambda (p) (cistern--pipe-live-p st (car p) (cdr p)))
                (cistern-test-v5-05--live-pipes st)))
         (hx (car pipe)) (hy (cdr pipe))
         (fixer (cistern--spawn-enemy st 'guild 'fixer hx (1+ hy))))
    (cistern--set-cell st hx hy 'hazard)
    (cl-assert (eq (cistern--cell st hx hy) 'hazard)
               t "fixture: the gnawed pipe is dead (hazard)")
    (let ((alloy0 (cistern-st-alloy st)) (hp0 (cistern--enemy-hp fixer)))
      ;; 2 ticks: certified restoration, no roll
      (cistern--phase-hostiles st)
      (cistern--phase-hostiles st)
      (cl-assert (eq (cistern--cell st hx hy) 'pipe)
                 t "the pipe returns to live state after 2 ticks")
      (cl-assert (cistern--pipe-live-p st hx hy)
                 t "the restored pipe is on a live path again")
      (cl-assert (= (cistern-st-alloy st) (1- alloy0))
                 t "exactly 1 alloy deducted")
      (cl-assert (= (cistern--enemy-hp fixer) hp0)
                 t "the guild is never damaged by its own work")
      ;; repeat: 2 more restorations then departure after the 3rd
      (cistern--set-cell st hx hy 'hazard)
      (cistern--phase-hostiles st) (cistern--phase-hostiles st)
      (cl-assert (= (cistern--enemy-drain fixer) 2)
                 t "second restoration counted")
      (cistern--set-cell st hx hy 'hazard)
      (cistern--phase-hostiles st) (cistern--phase-hostiles st)
      (cl-assert (= (cistern--enemy-drain fixer) 3)
                 t "third restoration counted")
      (cl-assert (eq (cistern--enemy-grip fixer) 'retreat)
                 t "the fixer departs after 3 restorations")
      ;; retreat walks it off the map
      (dotimes (_ 40) (cistern--phase-hostiles st))
      (cl-assert (not (memq fixer (cistern-st-hostiles st)))
                 t "the fixer despawns at the map edge")))
  ;; alloy 0: the fixer waits 20 ticks then leaves (no free work)
  (let* ((st (cistern--new-game 20260830))
         (pipe (car (cistern-test-v5-05--live-pipes st)))
         (fixer (cistern--spawn-enemy st 'guild 'fixer
                                      (car pipe) (1+ (cdr pipe)))))
    (cistern--set-cell st (car pipe) (cdr pipe) 'hazard)
    (setf (cistern-st-alloy st) 0)
    (dotimes (_ 20) (cistern--phase-hostiles st))
    (cl-assert (eq (cistern--enemy-grip fixer) 'retreat)
               t "alloy 0: wait 20 ticks, leave")
    (dotimes (_ 60) (cistern--phase-hostiles st))
    (cl-assert (not (cl-some (lambda (e) (eq (cistern--enemy-kind e) 'fixer))
                             (cistern-st-hostiles st)))
               t "the broke fixer retreats off the map"))
  ;; guild-depart is log-only: no `guild-depart' event kind exists
  (let ((st (cistern--new-game 20260830)))
    (cistern--maybe-guild st)
    (setf (cistern-st-tick st) 40)
    (cl-assert (not (memq 'guild-depart (mapcar #'cistern--event-kind
                                                (cistern-st-rewards-events st))))
               t "guild-depart stays log-only (ruling 3)"))
  (message "CISTERN-V5-05-GUILD-OK"))

(defun cistern-test-v5-05--live-pipes (st)
  "All live pipe cells, coordinate order."
  (let ((out nil) (i 0))
    (while (< i (length (cistern-st-map st)))
      (let ((x (% i (cistern-st-w st))) (y (/ i (cistern-st-w st))))
        (when (cistern--pipe-live-p st x y) (push (cons x y) out)))
      (setq i (1+ i)))
    (sort out (lambda (a b)
                (or (< (car a) (car b))
                    (and (= (car a) (car b)) (< (cdr a) (cdr b))))))))

(defun cistern-test-v5-05-guardrail ()
  "V5-05 (CB5): with a guild fixer AND a hostile adjacent, the
worker auto-defense strikes the HOSTILE; `cistern--cmd-focus' on
the fixer refuses via `combat-refusal-friendly' and consumes NO
stream draw; no verb sequence reduces a guild entity's hp."
  (cistern-test-v5-04--combat-on)
  (let ((st (cistern--new-game 41)))
    (cistern--spawn-enemy st 'guild 'fixer 5 5)
    (cistern--spawn-enemy st 'warband 'warband 3 5)
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 4) (setf (cistern--worker-y w) 5)
      (setf (cistern--worker-using w) nil)
      ;; force a hit: point combat-pos at a nat-20 draw
      (cistern-test-v5-04--find-nat st 20)
      (let ((fixer (nth 0 (cistern-st-hostiles st)))
            (warband (nth 1 (cistern-st-hostiles st)))
            (hp-f (cistern--enemy-hp (nth 0 (cistern-st-hostiles st))))
            (hp-w (cistern--enemy-hp (nth 1 (cistern-st-hostiles st)))))
        (cistern--auto-defense st)
        (cl-assert (< (cistern--enemy-hp warband) hp-w)
                   t "the worker strikes the hostile")
        (cl-assert (= (cistern--enemy-hp fixer) hp-f)
                   t "the guild entity keeps its hp"))
      ;; the refusal: focus on the fixer's cell
      (let ((before (cistern-st-combat-pos st))
            (loglen (length (cistern-st-log st))))
        (cistern--cmd-focus st 5 5)
        (cl-assert (null (cistern-st-focus st))
                   t "a guild entity cannot be focused")
        (cl-assert (= (cistern-st-combat-pos st) before)
                   t "a refused verb consumes no stream draw")
        (cl-assert (> (length (cistern-st-log st)) loglen)
                   t "the refusal names the charter")
        (cl-assert (cl-some (lambda (entry)
                              (string-match-p "CHARTERED" (car entry)))
                            (cistern-st-log st))
                   t "combat-refusal-friendly copy in the log"))
      ;; and a legit focus still works
      (cistern--cmd-focus st 3 5)
      (cl-assert (equal (cistern-st-focus st) "g2")
                 t "focus on the hostile lands")))
  (message "CISTERN-V5-05-GUARDRAIL-OK"))

;; --- V5-06 fixtures: FOCUS / RALLY on the armed-verb pattern (CB9) ---------------

(defun cistern-test-v5-06-verbs ()
  "V5-06 (CB9): `f' arms FOCUS (click enemy → focus = its id,
defenders prefer it, guild refusal per V5-05); `h` arms RALLY
(click floor → non-seated workers' journeys there, seated/using
workers exempt, arrival resumes seek-work); both ride the
existing armed-badge pattern; `u'/C-g disarm."
  (cistern-test-v5-04--combat-on)
  (load (expand-file-name "src/cistern-view.el" cistern-test-v5--root))
  ;; FOCUS: arm -> click the enemy -> focus set, armed cleared
  (let ((st (cistern--new-game 41)))
    (cistern--spawn-enemy st 'warband 'warband 3 5)   ; g1
    (cistern--spawn-enemy st 'warband 'warband 5 5)   ; g2
    (cistern--cmd-arm-verb st 'focus)
    (cl-assert (eq (cistern-st-armed-verb st) 'focus)
               t "`f' arms the FOCUS verb")
    (cistern--cmd-click st 3 5)
    (cl-assert (equal (cistern-st-focus st) "g1")
               t "the click focuses the hostile")
    (cl-assert (null (cistern-st-armed-verb st))
               t "a landed focus disarms")
    ;; defenders prefer the focus target among adjacents
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 4) (setf (cistern--worker-y w) 5)
      (let ((tgt (cistern--combat-target st w)))
        (cl-assert (equal (cistern--enemy-id tgt) "g1")
                   t "defenders prefer the focus target")))
    ;; refocusing the other hostile moves the designation
    (cistern--cmd-arm-verb st 'focus)
    (cistern--cmd-click st 5 5)
    (cl-assert (equal (cistern-st-focus st) "g2")
               t "the focus follows the second click")
    ;; guild refusal keeps the verb armed and changes nothing
    (cistern--spawn-enemy st 'guild 'fixer 6 5)       ; g3
    (cistern--cmd-arm-verb st 'focus)
    (cistern--cmd-click st 6 5)
    (cl-assert (equal (cistern-st-focus st) "g2")
               t "a refused focus changes nothing")
    (cl-assert (eq (cistern-st-armed-verb st) 'focus)
               t "a refusal leaves the verb armed")
    ;; the badge: ARMED: FOCUS through the existing badge row
    (let ((badges (cistern-view--header-badges st)))
      (cl-assert (and badges (string-match-p "ARMED: FOCUS" badges))
                 t "the armed badge composes FOCUS (ruling 4)"))
    ;; u / C-g disarm
    (cistern--cmd-disarm st)
    (cl-assert (null (cistern-st-armed-verb st))
               t "u/C-g disarms"))
  ;; RALLY: arm -> click floor -> non-seated journeys, seated exempt
  (let ((st (cistern--new-game 43)))
    (let* ((floor-cell (cistern-test-v5-03--find-cell st 'floor))
           (rx (car floor-cell)) (ry (cdr floor-cell))
           (free (nth 0 (cistern-st-creators st)))
           (seated (nth 1 (cistern-st-creators st))))
      ;; seat the second worker mid-use: exempt from the rally
      (setf (cistern--worker-using seated) t)
      (setf (cistern--worker-toilet seated) '(11 9))
      (cistern--cmd-arm-verb st 'rally)
      (cistern--cmd-click st rx ry)
      (cl-assert (equal (cistern--worker-journey free) (cons rx ry))
                 t "the free worker's journey points at the rally cell")
      (cl-assert (null (cistern--worker-journey seated))
                 t "the seated worker is exempt")
      (cl-assert (null (cistern-st-armed-verb st))
                 t "a landed rally disarms")
      ;; the badge composes RALLY while armed
      (cistern--cmd-arm-verb st 'rally)
      (let ((badges (cistern-view--header-badges st)))
        (cl-assert (and badges (string-match-p "ARMED: RALLY" badges))
                   t "the armed badge composes RALLY"))
      (cistern--cmd-disarm st)
      ;; the walk: the rallied worker steps toward the cell each tick
      ;; and resumes seek-work on arrival
      (let ((x0 (cistern--worker-x free)) (y0 (cistern--worker-y free)))
        (cistern--sim-tick st)
        (cl-assert (or (/= (cistern--worker-x free) x0)
                       (/= (cistern--worker-y free) y0))
                   t "the rallied worker walks")
        (cl-assert (not (cistern--worker-using free))
                   t "rally does not seat the worker"))))
  ;; arrival: the journey clears and the worker resumes seek-work
  (let ((st (cistern--new-game 47)))
    (let* ((floor-cell (cistern-test-v5-03--find-cell st 'floor))
           (rx (car floor-cell)) (ry (cdr floor-cell))
           (w (nth 0 (cistern-st-creators st))))
      ;; adjacent to the rally cell: arrival in one step
      (setf (cistern--worker-x w) (1+ rx))
      (setf (cistern--worker-y w) ry)
      (setf (cistern--worker-journey w) (cons rx ry))
      (setf (cistern-st-tick st) 1)
      (cistern--phase-creators st)
      (cl-assert (null (cistern--worker-journey w))
                 t "arrival clears the rally journey")
      (cl-assert (= (cistern--worker-x w) rx)
                 t "the worker stood on the rally cell")))
  (message "CISTERN-V5-06-VERBS-OK"))
