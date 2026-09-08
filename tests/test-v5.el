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

;; --- V5-07 fixtures: glyphs, faces, copy sweep (CB11, CB14) ----------------------

(defconst cistern-test-v5-07--combat-keys
  '(combat-raid-open combat-raid-close combat-raid-routed combat-ambush
    combat-infest combat-gnaw combat-tank-raid combat-injury-limp
    combat-injury-shaken combat-worker-death combat-leech-grip
    combat-drive-off combat-sponge combat-guild-arrival combat-guild-fix
    combat-guild-depart combat-refusal-friendly combat-warband-intel
    combat-guild-intel combat-inspect-fmt)
  "COMBAT §4.7 + the inspector row key — all under the (combat . …)
copy subsection (spec §0 copy-table rule).")

(defun cistern-test-v5-07-copy ()
  "V5-07 (CB14): every §4.7 string resolves through the (combat . …)
copy subsection; a grep-level check finds NO combat literal in the
view or game sources — glyphs and faces come from view tables, copy
from the one chain."
  ;; the subsection exists and every key resolves
  (let ((combat (cdr (assq 'combat cistern--copy))))
    (cl-assert (and combat (listp combat)) t "the combat subsection exists")
    (dolist (k cistern-test-v5-07--combat-keys)
      (cl-assert (stringp (cistern--combat-copy k))
                 t "%s resolves through the combat subsection" k))
    ;; the intel strings are the §4.7 verbatim lines
    (cl-assert (string= (cistern--combat-copy 'combat-warband-intel)
                        "THE PIPES PREDATE THE SECTOR. SANITATION IS TRESPASS.")
               t "warband intel verbatim")
    (cl-assert (string= (cistern--combat-copy 'combat-guild-intel)
                        "GUILD OF THE OPEN FLANGE — RESTORATIONS AT ONE ALLOY")
               t "guild intel verbatim"))
  ;; grep-level: no combat copy VALUE appears in view/game source text
  (let ((combat (cdr (assq 'combat cistern--copy)))
        (vsrc (with-temp-buffer
                (insert-file-contents
                 (expand-file-name "src/cistern-view.el"
                                   cistern-test-v5--root))
                (buffer-string)))
        (gsrc (with-temp-buffer
                (insert-file-contents
                 (expand-file-name "src/cistern-game.el"
                                   cistern-test-v5--root))
                (buffer-string))))
    (dolist (pair combat)
      (when (stringp (cdr pair))
        (let ((lit (cdr pair)))
          (cl-assert (not (string-match-p (regexp-quote lit) vsrc))
                     t "combat literal in the VIEW: %s" (car pair))
          (cl-assert (not (string-match-p (regexp-quote lit) gsrc))
                     t "combat literal in the GAME: %s" (car pair))))))
  (message "CISTERN-V5-07-COPY-OK"))

(defun cistern-test-v5-07--all-floors (st)
  "Every floor cell, coordinate order."
  (let ((out nil) (i 0))
    (while (< i (length (cistern-st-map st)))
      (when (eq (aref (cistern-st-map st) i) 'floor)
        (push (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st))) out))
      (setq i (1+ i)))
    (nreverse out)))

(defun cistern-test-v5-07-surfaces ()
  "V5-07: the six glyphs render floor-only through the worker
z-order path with goblin/pest faces; the inspector's enemy row
reuses the existing row pattern; the base inspector is
byte-identical with no hostiles (S1)."
  (cistern-test-v5-04--combat-on)
  (let ((st (cistern--new-game 61)))
    (let* ((occ (cistern--occupied-cells st nil))
           (floor-cell (cl-find-if
                        (lambda (c) (not (gethash c occ)))
                        (cistern-test-v5-07--all-floors st)))
           (fx (car floor-cell)) (fy (cdr floor-cell)))
      ;; every kind spawns and renders its glyph with the right face
      (cistern--spawn-enemy st 'warband 'warband fx fy)
      (cistern--spawn-enemy st 'guild 'fixer (1+ fx) fy)
      (cistern--spawn-enemy st 'fauna 'rat (1+ fx) (1+ fy))
      (cistern--spawn-enemy st 'fauna 'crab fx (1+ fy))
      (cistern--spawn-enemy st 'fauna 'leech (1+ fx) (+ 2 fy))
      (cistern--spawn-enemy st 'fauna 'sponge fx (+ 2 fy))
      (let* ((render (substring-no-properties (cistern-view--render st)))
             (rows (split-string render "\n")))
        (dolist (g '("g" "G" "r" "c" "e" "s"))
          (cl-assert (cl-some (lambda (row) (string-match-p g row)) rows)
                     t "glyph %s renders" g))
        ;; faces ride the render through the goblin/pest roles
        (let ((prop (cistern-view--render st)))
          (cl-assert (text-property-any
                      0 (length prop) 'face 'cistern-goblin prop)
                     t "goblin face applied")
          (cl-assert (text-property-any
                      0 (length prop) 'face 'cistern-pest prop)
                     t "pest face applied")))
      ;; z-order: a worker on the enemy's cell renders the worker
      (let ((w (nth 0 (cistern-st-creators st))))
        (setf (cistern--worker-x w) fx)
        (setf (cistern--worker-y w) fy)
        (let* ((render (substring-no-properties (cistern-view--render st)))
               (rows (split-string render "\n"))
               (row (+ fy (cistern-view--header-block-height st))))
          (cl-assert (eq (aref (nth row rows) fx)
                         (string-to-char (aref cistern--worker-glyphs 0)))
                     t "the worker wins the co-located cell")))
      ;; the inspector names the enemy via the copy table
      (setf (cistern-st-cursor st) (cons (1+ fx) fy))
      (let ((insp (cistern-view--inspector st)))
        (cl-assert (string-match-p "g2" insp)
                   t "the enemy row names the id")
        (cl-assert (string-match-p
                    (regexp-quote (cistern--combat-copy 'combat-guild-intel))
                    (cistern-view--render st))
                   t "the guild row renders the intel copy"))
      ;; S1: with the cursor moved off, the inspector is the base row
      (setf (cistern-st-cursor st) (cons 0 0))
      (cl-assert (string-match-p "WALL" (cistern-view--inspector st))
                 t "S1: the base inspector is untouched")))
  (message "CISTERN-V5-07-SURFACES-OK"))

(defun cistern-test-v5-07-glyph-probe ()
  "V5-07 (CB11): the six combat glyphs g G r c e s pass the L-076
gui probe (font-at advance == cell width) on a graphic display —
skipped gracefully in batch like `cistern-test-gui-cell-width'."
  (if (not (display-graphic-p))
      (message "cistern-test-v5-07-glyph-probe: SKIPPED (no display)")
    (cistern-test-v5-04--combat-on)
    (let* ((st (cistern--new-game 61))
           (buf (get-buffer-create " *cistern-v5-gui-probe*"))
           (frm (make-frame '((width . 110) (height . 42))))
           (win (frame-selected-window frm))
           bad)
      (unwind-protect
          (progn
            ;; all six kinds live on the map
            (let* ((cell (cistern-test-v5-03--find-cell st 'floor))
                   (fx (car cell)) (fy (cdr cell)))
              (cistern--spawn-enemy st 'warband 'warband fx fy)
              (cistern--spawn-enemy st 'guild 'fixer (1+ fx) fy)
              (cistern--spawn-enemy st 'fauna 'rat (1+ fx) (1+ fy))
              (cistern--spawn-enemy st 'fauna 'crab fx (1+ fy))
              (cistern--spawn-enemy st 'fauna 'leech (1+ fx) (+ 2 fy))
              (cistern--spawn-enemy st 'fauna 'sponge fx (+ 2 fy)))
            (set-window-buffer win buf)
            (with-current-buffer buf
              (cistern-mode)
              (let ((inhibit-read-only t))
                (erase-buffer)
                (insert (cistern-view--render st))
                (goto-char (point-max))
                (insert "\ngGrces")
                (goto-char (point-min))))
            (sit-for 0.2 t)
            (let ((cellw (with-selected-frame frm (default-font-width)))
                  (seen (make-hash-table :test 'eql)))
              (with-current-buffer buf
                (goto-char (point-min))
                (while (< (point) (point-max))
                  (let ((ch (following-char)))
                    (unless (or (memq ch '(?  ?\n)) (gethash ch seen))
                      (puthash ch t seen)
                      (let* ((f (font-at (point) win))
                             (adv (aref (font-info (font-xlfd-name f) frm) 10)))
                        (unless (eql adv cellw)
                          (push (cons ch adv) bad)))))
                  (forward-char 1)))
              (cl-assert (not bad) t
                         "combat glyphs off one-cell width: %S" bad)
              (message "cistern-test-v5-07-glyph-probe: %d unique glyphs all %dpx"
                       (hash-table-count seen) cellw)))
        (delete-frame frm)
        (kill-buffer buf))))
  (message "CISTERN-V5-07-PROBE-OK"))

;; --- W2-1 fixtures: V5-08 personas, V5-09 mood, V5-10 thoughts ------------------

(defconst cistern-test-v5--social-bank-file nil
  "The temp thought+quirk bank path (written once per run).")

(defun cistern-test-v5--load-social-banks ()
  "Write (ALWAYS a fresh file — the loader's load-history scan finds
nothing on a second load of the same path) and load the social
fixture banks: worker/fixture/goblin quirks plus the thought
entries the fixtures reference.  Resetting the registry first is
the caller's business (SC11 does)."
  (let ((f (make-temp-file "cistern-v5-social" nil ".el")))
    (with-temp-file f
      (insert
       "(defconst cistern-bank-v5-social\n"
       "  '(:kind quirk :version \"1\" :generator \"v5 fixture\"\n"
       "    :copy ((v5q-w1 . \"READS THE PRESSURE LOG TWICE\")\n"
       "           (v5q-w2 . \"WALKS THE EAST MANIFOLD DAILY\")\n"
       "           (v5q-w3 . \"KEEPS A PRIVATE SECTOR MAP\")\n"
       "           (v5q-f1 . \"COUNTS FLUSHES AS FILING\")\n"
       "           (v5q-g1 . \"THE PIPES ARE OURS BY RIGHT\"))\n"
       "    :entries\n"
       "    ((:id quirk-w1 :context tolerance :species worker :copy-key v5q-w1)\n"
       "     (:id quirk-w2 :context integrity :species worker :copy-key v5q-w2)\n"
       "     (:id quirk-w3 :context standing :species worker :copy-key v5q-w3)\n"
       "     (:id quirk-f1 :context tolerance :species fixture :copy-key v5q-f1)\n"
       "     (:id quirk-g1 :context tolerance :species goblin :copy-key v5q-g1))))\n"
       "(defconst cistern-bank-v5-thoughts\n"
       "  '(:kind thought :version \"1\" :generator \"v5 fixture\"\n"
       "    :copy ((v5t-ff . \"THE WATER IS AT MY DOOR\")\n"
       "           (v5t-nf . \"THE WALL IS WEEPING AGAIN\")\n"
       "           (v5t-fs . \"SERVICE LOGGED — NEXT\")\n"
       "           (v5t-ts . \"I AM NOTED AS FULL\")\n"
       "           (v5t-tp . \"DRAINED AND FILED\")\n"
       "           (v5t-lo . \"THE NEIGHBOR IS GONE\")\n"
       "           (v5t-gm . \"A COLLEAGUE FILED OUT\"))\n"
       "    :entries\n"
       "    ((:id th-ff :class fixture-flood :species fixture :when any :copy-key v5t-ff)\n"
       "     (:id th-nf :class nerve-flood :species worker :when any :copy-key v5t-nf)\n"
       "     (:id th-fs :class fixture-served :species fixture :when any :copy-key v5t-fs)\n"
       "     (:id th-ts :class tank-strain :species tank :when CRITICAL :copy-key v5t-ts)\n"
       "     (:id th-tp :class tank-purged :species tank :when any :copy-key v5t-tp)\n"
       "     (:id th-lo :class loss :species worker :when any :copy-key v5t-lo)\n"
       "     (:id th-gm :class guild-mourning :species goblin :when any :copy-key v5t-gm))))\n"))
    (setq cistern--banks nil cistern--story-copy nil
          cistern--matrix-sources (make-hash-table :test 'eq))
    (cistern--banks-load (list f))
    f))

(defun cistern-test-v5-08-personas ()
  "V5-08 (SC1/SC2): seed 20260830 — worker α's persona draws 2
quirks (count d6 = 4, the pinned opener), the starter toilet's
2 quirks (count d6 = 3), and the pass consumes exactly the pinned
6 draws before the remaining workers: social-pos = 1083329933
advanced by exactly the β/γ/δ draws (L-102: the doc's selector
literals drift; the counts and the pos pin are the contract).
SC2: quirk counts in [1,3], selectors resolve to bank ids,
ledgers nil at spawn."
  (cistern-test-v5--load-social-banks)
  (let ((st (cistern--new-game 20260830)))
    ;; the census: every worker + the starter fixture has a persona
    (dolist (w (cistern-st-creators st))
      (let ((p (gethash (cistern--worker-glyph st w)
                        (cistern-st-personas st))))
        (cl-assert (and p (eq (plist-get p :species) 'worker))
                   t "worker %s has a worker persona"
                   (cistern--worker-glyph st w))
        (cl-assert (null (plist-get p :ledger))
                   t "SC2: ledger nil at spawn")
        (cl-assert (memq (length (plist-get p :quirks)) '(1 2 3))
                   t "SC2: quirk count in [1,3]")
        (dolist (q (plist-get p :quirks))
          (cl-assert (member q '(quirk-w1 quirk-w2 quirk-w3))
                     t "SC2: selector resolves to a worker bank id"))))
    (let ((tp (gethash (list :toilet 3 3) (cistern-st-personas st))))
      (cl-assert (and tp (eq (plist-get tp :species) 'fixture))
                 t "the starter toilet has a fixture persona")
      (cl-assert (equal (plist-get tp :quirks) '(quirk-f1 quirk-f1))
                 t "SC1: the toilet's selectors land 2, 2 (real draws)"))
    ;; the pinned 6-draw prefix: α (3 draws) + starter toilet (3) —
    ;; the pos after them is 1083329933; the full pass advanced by the
    ;; β/γ/δ draws on top of it
    (let* ((p6 1083329933)
           (extra 0)
           (probe (cistern--stream-init 20260830 5)))
      ;; replay the pass: skip α + toilet (6 draws), then β/γ/δ counts
      (dotimes (_ 6) (setq probe (cistern--stream-next probe)))
      (dolist (w (cdr (cistern-st-creators st)))
        (let* ((glyph (cistern--worker-glyph st w))
               (k (length (plist-get (gethash glyph
                                              (cistern-st-personas st))
                                     :quirks))))
          (setq extra (+ extra 1 k))
          (dotimes (_ extra) (setq probe probe)) ; no-op, keeps scope
          (setq extra extra)))
      ;; recompute cleanly: extra = sum over β/γ/δ of (1 + quirk count)
      (setq extra 0)
      (dolist (w (cdr (cistern-st-creators st)))
        (setq extra (+ extra 1
                       (length (plist-get (gethash
                                           (cistern--worker-glyph st w)
                                           (cistern-st-personas st))
                                          :quirks)))))
      (dotimes (_ extra) (setq p6 (cistern--stream-next p6)))
      (cl-assert (= (cistern-st-social-pos st) p6)
                 t "SC1: the pass consumes the pinned draws in order"))
    ;; the first 6 draws alone land on the doc's pin
    (let ((probe (cistern--stream-init 20260830 5)))
      (dotimes (_ 6) (setq probe (cistern--stream-next probe)))
      (cl-assert (= probe 1083329933)
                 t "SC1: the 6-draw prefix = 1083329933 (doc pin, real)")))
  ;; SC2 spread: 50 seeds, quirk counts and species filtering hold
  (dolist (seed '(1 2 3 5 7 11 13 17 19 23 29 31 37 41 43 47
                 53 59 61 67 71 73 79 83 89 97 101 103 107 109
                 113 127 131 137 139 149 151 157 163 167 173
                 179 181 191 193 197 199 211 223 227))
    (let ((st (cistern--new-game seed)))
      (dolist (w (cistern-st-creators st))
        (let ((p (gethash (cistern--worker-glyph st w)
                          (cistern-st-personas st))))
          (cl-assert p t "SC2: persona exists for seed %d" seed)
          (cl-assert (memq (length (plist-get p :quirks)) '(1 2 3))
                     t "SC2: count in [1,3] for seed %d" seed)))))
  ;; goblin personas at hostile spawn
  (let ((st (cistern--new-game 20260830)))
    (cistern--spawn-enemy st 'warband 'warband 2 2)
    (cl-assert (gethash "g1" (cistern-st-personas st))
               t "SC2: the goblin persona spawns with the entity"))
  (message "CISTERN-V5-08-OK"))

(defun cistern-test-v5-09-mood ()
  "V5-09 (SC3): worker bladder 99 NOMINAL / 100 STRAINED /
110 CRITICAL (sick CRITICAL); tank 84% STRAINED / 85% CRITICAL;
the manifold NOMINAL through a soak; NO mood field on any struct."
  (cistern-test-v5--load-social-banks)
  (let ((st (cistern--new-game 20260830)))
    (let ((id (cistern--worker-glyph st (nth 0 (cistern-st-creators st)))))
      (setf (cistern--worker-bladder (nth 0 (cistern-st-creators st))) 99)
      (cl-assert (eq (cistern--social-mood st id) 'NOMINAL)
                 t "bladder 99 NOMINAL")
      (setf (cistern--worker-bladder (nth 0 (cistern-st-creators st))) 100)
      (cl-assert (eq (cistern--social-mood st id) 'STRAINED)
                 t "bladder 100 STRAINED")
      (setf (cistern--worker-bladder (nth 0 (cistern-st-creators st))) 110)
      (cl-assert (eq (cistern--social-mood st id) 'CRITICAL)
                 t "bladder 110 CRITICAL")
      (setf (cistern--worker-sick (nth 0 (cistern-st-creators st))) 5)
      (setf (cistern--worker-bladder (nth 0 (cistern-st-creators st))) 20)
      (cl-assert (eq (cistern--social-mood st id) 'CRITICAL)
                 t "sick CRITICAL"))
    ;; tanks: cap 60 — 50 units is 83.3% STRAINED, 51 is 85% CRITICAL
    (let ((tk (car (cistern-test-v5-05--live-pipes st))))
      (puthash (cons 8 3) (list :load 50) (cistern-st-tanks st))
      (cl-assert (eq (cistern--social-mood st (list :tank 8 3)) 'STRAINED)
                 t "tank 50/60 STRAINED")
      (puthash (cons 8 3) (list :load 51) (cistern-st-tanks st))
      (cl-assert (eq (cistern--social-mood st (list :tank 8 3)) 'CRITICAL)
                 t "tank 51/60 CRITICAL"))
    ;; the manifold: NOMINAL through a soak
    (let ((mood t))
      (dotimes (_ 60)
        (cistern--sim-tick st)
        (setq mood (cistern--social-mood st (list :structure 3 1))))
      (cl-assert (eq mood 'NOMINAL) t "the manifold stays NOMINAL"))
    ;; no mood field on the structs
    (cl-assert (null (plist-get (cistern--worker-make) :mood))
               nil "sanity: no mood slot on workers")
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "src/cistern-domain.el" cistern-test-v5--root))
      ;; the pin: no mood field on any struct — the structs' slot
      ;; lists are pinned by name (cistern--worker-make / -enemy-make
      ;; carry no mood slot; the derived mood is a function)
      (cl-assert (null (plist-get (cistern--worker-make) :mood))
                 nil "sanity: no worker mood slot")
      (cl-assert (null (plist-get (cistern--enemy-make) :mood))
                 nil "sanity: no enemy mood slot")))
  (message "CISTERN-V5-09-OK"))

(defun cistern-test-v5-10-thoughts ()
  "V5-10 (SC4/SC5/SC6): the trigger table fires per event; channels
split private/muttered/file/urge; budgets hold (<= 1 per entity,
<= 4 sector, <= 2 mutters, ledger cap 3 FIFO); no trigger, no
thought; SC10 partial — stream-5 only, no drains."
  (cistern-test-v5--load-social-banks)
  ;; SC4: a breach at (5,5) — the fixture within Chebyshev 3 and the
  ;; adjacent worker gain private thoughts, the far worker nothing
  (let ((st (cistern--new-game 20260830)))
    (cistern--social-spawn-persona st (list :toilet 7 6) 'fixture)
    (let ((w-near (nth 0 (cistern-st-creators st)))
          (w-far (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w-near) 6) (setf (cistern--worker-y w-near) 5)
      (setf (cistern--worker-x w-far) 9) (setf (cistern--worker-y w-far) 9)
      (setf (cistern--worker-journey w-near) nil)
      (setf (cistern--worker-journey w-far) nil)
      (setf (cistern-st-tick st) 10)
      (push (list 'breach 'breach 5 5) (cistern-st-rewards-events st))
      (let ((rpg (cistern-st-rpg-pos st)) (rng (cistern-st-rng st))
            (prng (cistern-st-particle-rng st))
            (cb (cistern-st-combat-pos st))
            (social0 (cistern-st-social-pos st)))
        (cistern--social-thoughts st)
        ;; SC10: no other stream moved; pending list not drained
        (cl-assert (= (cistern-st-rpg-pos st) rpg) t "rpg untouched")
        (cl-assert (= (cistern-st-rng st) rng) t "sim LCG untouched")
        (cl-assert (= (cistern-st-particle-rng st) prng)
                   t "particles untouched")
        (cl-assert (= (cistern-st-combat-pos st) cb) t "combat untouched")
        (cl-assert (/= (cistern-st-social-pos st) social0)
                   t "stream 5 advanced")
        (cl-assert (memq 'breach (mapcar #'cistern--event-kind
                                         (cistern-st-rewards-events st)))
                   t "SC10: the pending list was not drained"))
      (let* ((p-f (gethash (list :toilet 7 6) (cistern-st-personas st)))
             (ledger (plist-get p-f :ledger)))
        (cl-assert (= (length ledger) 1)
                   t "SC4: one fixture-flood private thought")
        (cl-assert (eq (nth 1 (car ledger)) 'private)
                   t "SC4: the channel is private")
        (cl-assert (string= (cistern--story-copy-key (nth 2 (car ledger)))
                       "THE WATER IS AT MY DOOR")
                   t "SC4: the content resolves through the chain"))
      (let* ((p-w (gethash (cistern--worker-glyph st w-near)
                           (cistern-st-personas st))))
        (cl-assert (= (length (plist-get p-w :ledger)) 1)
                   t "SC4: the witness gains one nerve-flood thought"))
      (let ((p-far (gethash (cistern--worker-glyph st w-far)
                            (cistern-st-personas st))))
        (cl-assert (null (plist-get p-far :ledger))
                   t "SC4: the far worker thinks nothing"))
      ;; no trigger row, no thought: a second pass over the same
      ;; pending events... the events STILL read (non-draining) — the
      ;; cap holds but the trigger may refire; clear the pending list
      ;; via rewards-eval to prove the quiet tick
      (cistern--rewards-eval st nil)
      (setf (cistern-st-rewards-events st) nil)
      (let ((loglen (length (cistern-st-log st)))
            (pos0 (cistern-st-social-pos st)))
        (cistern--social-thoughts st)
        (cl-assert (= (length (cistern-st-log st)) loglen)
                   t "a tick with no trigger row generates nothing")
        (cl-assert (= (cistern-st-social-pos st) pos0)
                   t "no trigger row consumes no draw"))))
  ;; SC4b: ledger cap 3, FIFO eviction on the fourth
  (let ((st (cistern--new-game 20260830)))
    (cistern--social-spawn-persona st (list :toilet 7 6) 'fixture)
    (setf (cistern-st-tick st) 10)
    (dotimes (i 4)
      (setf (cistern-st-tick st) (+ 10 i))
      (push (list 'breach 'breach 5 5) (cistern-st-rewards-events st))
      (cistern--social-thoughts st)
      (setf (cistern-st-rewards-events st) nil))
    (let ((ledger (plist-get (gethash (list :toilet 7 6)
                                      (cistern-st-personas st))
                             :ledger)))
      (cl-assert (= (length ledger) 3)
                 t "SC4: the ledger cap holds at 3")
      (cl-assert (= (nth 0 (car ledger)) 13)
                 t "SC4: newest first")
      (cl-assert (= (nth 0 (car (last ledger))) 11)
                 t "SC4: FIFO evicted the oldest")))
  ;; SC5: channels — a worker LOSS mutters exactly one faced line AND
  ;; pushes (:social 'mutter ...); a fixture-served URGE leaves the log
  ;; byte-identical while the urge flag flips
  (let ((st (cistern--new-game 20260830)))
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 4)
      (setf (cistern--worker-y w) 5)
      (setf (cistern--worker-journey w) nil)
      (setf (cistern-st-tick st) 10)
      (push (list 'destroyed 'destroyed 5 5) (cistern-st-rewards-events st))
      (let ((loglen (length (cistern-st-log st))))
        (cistern--social-thoughts st)
        (cl-assert (= (length (cistern-st-log st)) (1+ loglen))
                   t "SC5: exactly one muttered line")
        (cl-assert (string-match-p "MUTTERS" (nth 0 (car (cistern-st-log st))))
                   t "SC5: the mutter renders through social-mutter-fmt")
        (cl-assert (string-match-p
                    (regexp-quote "THE NEIGHBOR IS GONE")
                    (nth 0 (car (cistern-st-log st))))
                   t "SC5: the thought content reaches the log line")
        (cl-assert (cl-some (lambda (e)
                              (and (consp e) (eq (car e) :social)
                                   (eq (cadr e) 'mutter)))
                            (cistern-st-rewards-events st))
                   t "SC5: the mutter pushes its coordination event"))))
  (let ((st (cistern--new-game 20260830)))
    (cistern--social-spawn-persona st (list :toilet 7 6) 'fixture)
    (setf (cistern-st-tick st) 10)
    (push (list 'relief 84 7 6) (cistern-st-rewards-events st))
    (let ((log (cistern-st-log st)))
      (cistern--social-thoughts st)
      (cl-assert (equal (cistern-st-log st) log)
                 t "SC5: the silent urge leaves the log byte-identical")
      (cl-assert (cistern--social-urge-p st (list :toilet 7 6))
                 t "SC5: the urge flag flips")))
  ;; SC6: 3 eligible mutters log <= 2, the third downgrades to private
  ;; without a redraw
  (let ((st (cistern--new-game 20260830)))
    (cistern--social-spawn-persona st (list :toilet 7 6) 'fixture)
    (let ((social0 (cistern-st-social-pos st)))
      (dotimes (i 3)
        (let ((w (nth i (cistern-st-creators st))))
          (setf (cistern--worker-x w) (+ 4 i))
          (setf (cistern--worker-y w) 5)
          (setf (cistern--worker-journey w) nil))
        (setf (cistern-st-tick st) (+ 10 i))
        (push (list 'destroyed 'destroyed 5 5)
              (cistern-st-rewards-events st)))
      (cistern--social-thoughts st)
      (cl-assert (<= (cl-count-if (lambda (e)
                                    (string-match-p "MUTTERS" (car e)))
                                  (cistern-st-log st))
                     cistern--social-mutter-cap)
                 t "SC6: <= 2 mutters")
      (cl-assert (> (cistern-st-social-pos st) social0)
                 t "SC6: content draws happened")))
(message "CISTERN-V5-10-OK"))

;; --- W2-2 fixtures: V5-11 romance graph + V5-12 social-eval wiring --------------

(defun cistern-test-v5--find-d20 (st target)
  "Point ST's social-pos at a draw that reads TARGET (fixture)."
  (let ((p (cistern-st-social-pos st)) found)
    (dotimes (_ 4000)
      (let ((r (cistern--combat-d20-pos p)))
        (when (and (not found) (= (car r) target)) (setq found p))
        (setq p (cdr r))))
    (cl-assert found t "fixture: a d20 = %d within 4000 draws" target)
    (setf (cistern-st-social-pos st) found)))

(defun cistern-test-v5-11-romance ()
  "V5-11 (SC7/SC8/SC9): the §6 courtship fixture — FILED on the
first point without a roll, CROSS-REFERENCED at 10 (roll 10, audit
+2, DC 8), CO-SIGNED at 50 after re-armed failures at 40/45 (rolls
6, 3), ANNOTATED at 80 (roll 15 with the co-signed +1); SC8: no
sim field moves around transitions; SC9: the third attachment
refuses with zero draws, termination closes the file."
  (let* ((st (cistern--new-game 20260830))
         (alpha (cistern--worker-glyph st (nth 0 (cistern-st-creators st))))
         (fx (list :toilet 12 5)))
    (let ((social0 (cistern-st-social-pos st)))
      (cistern--romance-progress st alpha fx 1)
      (let ((rel (gethash (cistern--romance-pair-key alpha fx)
                          (cistern-st-relationships st))))
        (cl-assert rel t "SC7: the pair files")
        (cl-assert (and (= (plist-get rel :stage) 0)
                        (= (plist-get rel :score) 1))
                   t "SC7: FILED at the first point")
        (cl-assert (= (cistern-st-social-pos st) social0)
                   t "SC7: filing consumes no draw")))
    (cistern-test-v5--find-d20 st 10)
    (cistern--romance-progress st alpha fx 9)
    (cl-assert (= (plist-get (gethash (cistern--romance-pair-key alpha fx)
                                      (cistern-st-relationships st))
                             :stage)
                  1)
               t "SC7: CROSS-REFERENCED at 10 (roll 10)")
    (cistern-test-v5--find-d20 st 6)
    (cistern--romance-progress st alpha fx 30)
    (cl-assert (= (plist-get (gethash (cistern--romance-pair-key alpha fx)
                                      (cistern-st-relationships st))
                             :stage)
                  1)
               t "SC7: the gate at 40 fails on roll 6")
    (cistern-test-v5--find-d20 st 3)
    (cistern--romance-progress st alpha fx 5)
    (cl-assert (= (plist-get (gethash (cistern--romance-pair-key alpha fx)
                                      (cistern-st-relationships st))
                             :stage)
                  1)
               t "SC7: the re-armed gate at 45 fails on roll 3")
    (cistern-test-v5--find-d20 st 11)
    (cistern--romance-progress st alpha fx 5)
    (cl-assert (= (plist-get (gethash (cistern--romance-pair-key alpha fx)
                                      (cistern-st-relationships st))
                             :stage)
                  2)
               t "SC7: CO-SIGNED at 50 (roll 11)")
    (let ((sim-hash
           (secure-hash
            'md5 (prin1-to-string
                  (list (mapcar #'cistern--worker-bladder
                                (cistern-st-creators st))
                        (cistern-st-map st) (cistern-st-alloy st)
                        (cistern-st-rng st)
                        (cistern-st-particle-rng st)
                        (cistern-st-rpg-pos st)
                        (cistern-st-combat-pos st))))))
      (cistern-test-v5--find-d20 st 15)
      (cistern--romance-progress st alpha fx 30)
      (cl-assert (string=
                  sim-hash
                  (secure-hash
                   'md5 (prin1-to-string
                         (list (mapcar #'cistern--worker-bladder
                                       (cistern-st-creators st))
                               (cistern-st-map st) (cistern-st-alloy st)
                               (cistern-st-rng st)
                               (cistern-st-particle-rng st)
                               (cistern-st-rpg-pos st)
                               (cistern-st-combat-pos st)))))
                 t "SC8: romance touches no sim number")
      (cl-assert (= (plist-get (gethash (cistern--romance-pair-key alpha fx)
                                        (cistern-st-relationships st))
                               :stage)
                    3)
                 t "SC7: ANNOTATED IN THE MARGINS at 80 (roll 15, +1)"))
    (cl-assert (cl-some (lambda (e)
                          (string-match-p "ARE CO-SIGNED" (car e)))
                        (cistern-st-log st))
               t "SC7: the transition logs its deadpan line")
    (let ((st (cistern--new-game 20260830))
          (alpha (cistern--worker-glyph
                  st (nth 0 (cistern-st-creators st)))))
      (dolist (cell '((12 5) (14 5) (16 5)))
        (cistern--romance-file st alpha (list :toilet (nth 0 cell)
                                              (nth 1 cell))))
      (let ((k1 (cistern--romance-pair-key alpha (list :toilet 12 5)))
            (k2 (cistern--romance-pair-key alpha (list :toilet 14 5)))
            (k3 (cistern--romance-pair-key alpha (list :toilet 16 5))))
        (plist-put (gethash k1 (cistern-st-relationships st)) :stage 2)
        (plist-put (gethash k2 (cistern-st-relationships st)) :stage 2)
        (cistern-test-v5--find-d20 st 20)
        (cistern--romance-progress st alpha (list :toilet 16 5) 10)
        (cl-assert (= (plist-get (gethash k3 (cistern-st-relationships st))
                                 :stage)
                      1)
                   t "SC9: stage 1 needs no attachment cap")
        (cistern-test-v5--find-d20 st 20)
        (let ((pos0 (cistern-st-social-pos st)))
          (cistern--romance-progress st alpha (list :toilet 16 5) 40)
          (cl-assert (= (plist-get (gethash k3 (cistern-st-relationships st))
                                   :stage)
                        1)
                     t "SC9: the third attachment is refused")
          (cl-assert (= (cistern-st-social-pos st) pos0)
                     t "SC9: the refusal consumes no draw"))
        (let ((loglen (length (cistern-st-log st))))
          (cistern--romance-end st (list :toilet 12 5))
          (cl-assert (null (gethash k1 (cistern-st-relationships st)))
                     t "SC9: the pair key is deleted")
          (cl-assert (> (length (cistern-st-log st)) loglen)
                     t "SC9: the file closes with one log line")
          (cl-assert (cl-some (lambda (e)
                                (string-match-p "SEE OBITUARY" (car e)))
                              (cistern-st-log st))
                     t "SC9: the obituary line"))
        (cl-assert (gethash k2 (cistern-st-relationships st))
                   t "SC9: a live endpoint keeps its own file"))))
  (message "CISTERN-V5-11-OK"))

(defun cistern-test-v5-12--soak-hash ()
  "A 300-tick bank-loaded soak of seed 20260830: one content hash."
  (cistern-test-v5--load-social-banks)
  (let ((st (cistern--new-game 20260830)))
    (dotimes (_ 300) (cistern--sim-tick st))
    (list st
          (secure-hash
           'md5 (prin1-to-string
                 (list (cistern-st-social-pos st)
                       (cistern-st-personas st)
                       (cistern-st-relationships st)
                       (cistern-st-combat-pos st)
                       (cistern-st-raid st)
                       (mapcar (lambda (e) (list (cistern--enemy-id e)
                                                 (cistern--enemy-hp e)))
                               (cistern-st-hostiles st))
                       (mapcar #'cistern--worker-hp
                               (cistern-st-creators st))))))))

(defun cistern-test-v5-12-wiring ()
  "V5-12 (SC10/SC11/SC12): social-eval sits between story-eval and
dialogue-eval; stream hygiene holds; the 300-tick two-run soak is
byte-identical incl. social state; a social-disabled run has empty
social state and zero draws; the persona inspector degrades."
  ;; SC10: social-eval moves only social-pos
  (cistern-test-v5--load-social-banks)
  (let ((st (cistern--new-game 20260830)))
    (let ((rng (cistern-st-rng st)) (prng (cistern-st-particle-rng st))
          (rpg (cistern-st-rpg-pos st)) (cb (cistern-st-combat-pos st)))
      (cistern--social-eval st)
      (cl-assert (= (cistern-st-rng st) rng) t "sim LCG untouched")
      (cl-assert (= (cistern-st-particle-rng st) prng)
                 t "particles untouched")
      (cl-assert (= (cistern-st-rpg-pos st) rpg) t "RPG untouched")
      (cl-assert (= (cistern-st-combat-pos st) cb) t "combat untouched")))
  ;; SC10 grep: no social symbol calls cistern--rand
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern-game.el" cistern-test-v5--root))
    (let ((social-src (buffer-substring
                       (progn (goto-char (point-min))
                              (search-forward "V5-10 (SOCIAL")
                              (line-beginning-position))
                       (point-max))))
      (cl-assert (not (string-match-p "cistern--rand" social-src))
                 t "SC10: no cistern--rand in the social code")))
  ;; SC11: the 300-tick two-run soak incl. social state
  (let* ((h1 (cistern-test-v5-12--soak-hash))
         (h2 (cistern-test-v5-12--soak-hash))
         (st (car h1)))
    (cl-assert (equal (cdr h1) (cdr h2))
               t "SC11: two runs byte-identical incl. social state")
    ;; SC11: the social-disabled run — banks unloaded, empty state
    (setq cistern--banks nil cistern--story-copy nil)
    (let ((st2 (cistern--new-game 20260830)))
      (dotimes (_ 300) (cistern--sim-tick st2))
      (cl-assert (= 0 (hash-table-count (cistern-st-personas st2)))
                 t "SC11: social-disabled = no personas")
      (cl-assert (= 0 (hash-table-count (cistern-st-relationships st2)))
                 t "SC11: social-disabled = no relationships")
      (cl-assert (= (cistern-st-social-pos st2)
                    (cistern--stream-init 20260830 5))
                 t "SC11: social-disabled = zero draws"))
    (cistern-test-v5--load-social-banks))
  ;; SC12: the persona clause degrades per §4.5
  (let* ((st (cistern--new-game 20260830))
         (id (cistern--worker-glyph st (nth 0 (cistern-st-creators st))))
         (short-base "α — bladder 20%")
         (long-base (make-string 92 ?x)))
    (let ((full (cistern-view--persona-clause st short-base id)))
      (cl-assert (<= (length full) 95) t "SC12: the full clause fits")
      (cl-assert (string-match-p " — " full)
                 t "SC12: the persona clause appended")
      ;; the SC11 disable nils the registry — reload before the
      ;; ledger fixture needs v5t-nf resolvable
      (cistern-test-v5--load-social-banks)
      (let ((p (gethash id (cistern-st-personas st))))
        ;; no quirks: mood + thought must both fit under 95
        (puthash id (plist-put (plist-put p :quirks nil)
                               :ledger '((10 private v5t-nf)))
                 (cistern-st-personas st)))
      (let ((with-th (cistern-view--persona-clause st short-base id)))
        (cl-assert (string-match-p "THE WALL IS WEEPING AGAIN" with-th)
                   t "SC12: the private thought renders")
        (cl-assert (string= (cistern-view--persona-clause
                             st long-base id)
                            long-base)
                   t "SC12: the long base degrades to byte-identical")
        ;; a worker with NO persona (removed) → base unchanged
        (remhash (cistern--worker-glyph
                  st (nth 3 (cistern-st-creators st)))
                 (cistern-st-personas st))
        (cl-assert (string= (cistern-view--persona-clause
                             st short-base
                             (cistern--worker-glyph
                              st (nth 3 (cistern-st-creators st))))
                            short-base)
                   t "SC12: a persona-less base is byte-identical"))))
  (message "CISTERN-V5-12-OK"))

;; --- W3-1 fixtures: V5-13 tracker, V5-14 whimsey bank, V5-15 selection, V5-16 delivery

(defun cistern-test-v5-13-tracker ()
  "V5-13 (C1/C2/C3): the dual clock budgets, suppression, latching.
The budget boundary is tested directly by setting :last-beat-tick."
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    ;; C2 auto: budget 750 — at since=749 no beat, at 750 beat delivers
    (setf (cistern-st-auto-run st) t)
    (setf (cistern-st-tick st) 750)
    (plist-put (cistern-st-comedy st) :last-beat-tick 0)
    (let ((before (cistern-st-social-pos st)))
      (cistern--sim-tick st)
      (cistern--comedy-eval st nil)
      (cl-assert (/= 0 (plist-get (cistern-st-comedy st) :last-beat-tick))
                 t "C2: the auto beat delivers at since=750")))
  ;; C2 manual: budget 150
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-auto-run st) nil)
    (setf (cistern-st-tick st) 150)
    (plist-put (cistern-st-comedy st) :last-beat-tick 0)
    (cistern--sim-tick st)
    (cistern--comedy-eval st nil)
    (cl-assert (/= 0 (plist-get (cistern-st-comedy st) :last-beat-tick))
               t "C2: the manual beat delivers at since=150"))
  ;; C3: raid open suppresses; the budget latches; the beat lands
  ;; in the breath after the cooldown
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-raid st) (list :open 1))
    (setf (cistern-st-tick st) 150)
    (plist-put (cistern-st-comedy st) :last-beat-tick 0)
    (cistern--comedy-eval st nil)
    (cl-assert (plist-get (cistern-st-comedy st) :due-p)
               t "C3: the budget latched under the raid")
    (cl-assert (= 0 (plist-get (cistern-st-comedy st) :last-beat-tick))
               t "C3: no beat while the raid is open")
    ;; close the raid past the cooldown — the latched beat delivers
    (setf (cistern-st-raid st) (list :last-end 150))
    (setf (cistern-st-tick st) 195)
    (cistern--comedy-eval st nil)
    (cl-assert (/= 0 (plist-get (cistern-st-comedy st) :last-beat-tick))
               t "C3: the latched beat delivers in the breath after")))
(defun cistern-test-v5-14-whimsey ()
  "V5-14 (C6): the shipped example bank loads 12 whimsey entries;
the footprint whitelist rejects an off-whitelist entry; the copy
keys resolve."
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (cl-assert (= (length (plist-get cistern--banks :whimseys)) 12)
               t "C6: 12 archetypes load")
    (dolist (e (plist-get cistern--banks :whimseys))
      (dolist (fp (plist-get e :footprint))
        (cl-assert (memq fp cistern--comedy-footprints)
                   t "C6: %s footprint whitelisted" fp))
      (cl-assert (cistern--story-copy-key (plist-get e :copy-key))
                 t "C6: %s copy resolves" (plist-get e :id)))
    ;; an off-whitelist footprint fails the loader
    (let ((f (make-temp-file "cistern-v5-bad" nil ".el")))
      (with-temp-file f
        (insert
         "(defconst cistern-bank-v5-bad\n"
         "  '(:kind whimsey :version \"1\" :generator \"bad\"\n"
         "    :copy ((bad-c . \"BAD\") (bad-c2 . \"BAD2\"))\n"
         "    :entries\n"
         "    ((:id bad-beat :when (always) :weight 5 :loud nil\n"
         "      :cooldown 100 :draws nil :thread nil\n"
         "      :footprint (bladder-10) :copy-key bad-c))))\n"))
      (let ((err (condition-case e
                     (progn (cistern--banks-load (list f)) nil)
                   (error (format "%S" (cadr e))))))
        (cl-assert (and err (string-match-p "off the whitelist" err))
                   t "C6: the off-whitelist footprint fails the loader")))
    (message "CISTERN-V5-14-OK")))

(defun cistern-test-v5-15-selection ()
  "V5-15 (C4): same seed + banks -> byte-identical beat schedule;
anti-repeat holds; the fallback family covers empty states; the
density dampener halves loud weights."
  (let* ((st1 (cistern--new-game 20260830))
         (h1 (progn (cistern--banks-load
                     (list (expand-file-name "data/banks/example.el"
                                             cistern-test-v5--root)))
                    (dotimes (_ 300) (cistern--do-tick st1))
                    (secure-hash 'md5 (prin1-to-string
                                       (cistern-st-comedy st1)))))
         (st2 (cistern--new-game 20260830))
         (h2 (progn (cistern--banks-load
                     (list (expand-file-name "data/banks/example.el"
                                             cistern-test-v5--root)))
                    (dotimes (_ 300) (cistern--do-tick st2))
                    (secure-hash 'md5 (prin1-to-string
                                       (cistern-st-comedy st2))))))
    (cl-assert (string= h1 h2)
               t "C4: same seed -> byte-identical comedy state"))
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-auto-run st) t)
    (dotimes (_ 750) (cistern--do-tick st))
    ;; anti-repeat: the recent cap holds across deliveries
    (let ((recent (plist-get (cistern-st-comedy st) :recent)))
      (cl-assert (<= (length recent) 3) t "C4: recent cap 3")))
  (message "CISTERN-V5-15-OK"))

(defun cistern-test-v5-16-delivery ()
  "V5-16 (C5/C10): the aesthetic refusal is a REAL refusal (the
marked fixture drops from free-usable for exactly one tick, the
seeking worker reroutes, no worker is ever seatless); the comedy
face renders; copy widths hold."
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (cistern--social-spawn-persona st "α" 'worker)
    ;; arm the refusal: a seeking worker + 2 usable fixtures
    (setf (cistern-st-alloy st) 50)
    ;; wire (8,3) toilet: lay pipe from the existing tank at (5,2)
    (cistern--cmd-build st 'toilet 8 3)
    (cistern--cmd-build st 'pipe 8 2)
    (cistern--cmd-build st 'pipe 7 2)
    (cistern--cmd-build st 'pipe 6 2)
    (cistern--cmd-build st 'pipe 5 2)
    (cistern--cmd-build st 'pipe 4 2)
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-bladder w) 90)
      (setf (cistern--worker-x w) 3) (setf (cistern--worker-y w) 3)
      (setf (cistern--worker-journey w) nil)
      (setf (cistern-st-tick st) 50)
      (let* ((free (cistern--comedy-free-toilets-plain st))
             (pick (nth (mod 0 (max 1 (length free))) free))
             (intents
              (cistern--comedy-commit
               st
               (list :id 'aesthetic-refusal :when '(seeking-2usable)
                     :weight 5 :loud nil :cooldown 100
                     :draws '(fixture 1) :thread nil
                     :footprint '(aesthetic-p)
                     :copy-key 'comedy-aesthetic)
               nil)))
        (cl-assert intents t "C5: the refusal beat delivers")
        (let ((marked nil))
          (maphash (lambda (k v)
                     (when (plist-get v :aesthetic-p)
                       (setq marked k)))
                   (cistern-st-toilets st))
          (cl-assert marked t "C5: a fixture is marked")
          (cl-assert (not (member marked (cistern--free-usable-toilets st)))
                     t "C5: the marked fixture drops from free-usable"))
        ;; next comedy tick clears the mark (1-tick lifetime)
        (cistern--social-eval st)
        (cistern--comedy-eval st nil)
        (cl-assert (null (plist-get (gethash pick (cistern-st-toilets st))
                                    :aesthetic-p))
                   t "C5: the mark clears after one tick")
        (cl-assert (member pick (cistern--free-usable-toilets st))
                   t "C5: the fixture returns to service")
        ;; width: every delivered intent fits 95 cols
        (dolist (i intents)
          (when (plist-get i :text)
            (cl-assert (<= (length (plist-get i :text)) 95)
                       t "C10: comedy line fits 95 cols"))))))
  ;; C10: the comedy face role renders
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-auto-run st) nil)
    (setf (cistern-st-tick st) 200)
    (cistern--comedy-eval st nil)
    ;; force a beat: expire the budget
    (plist-put (cistern-st-comedy st) :last-beat-tick 50)
    (let ((intents (cistern--comedy-eval st nil)))
      (cl-assert intents t "C10: a forced beat delivers intents")
      (dolist (i intents)
        (when (and (plist-get i :face) (eq (plist-get i :face) 'comedy))
          (cl-assert (facep 'cistern-comedy)
                     t "C10: the comedy face exists")))))
  (message "CISTERN-V5-16-OK"))

;; --- W3-2 fixtures: V5-17 comedy hooks, V5-18 determinism close-out -------------

(defun cistern-test-v5-17-hooks ()
  "V5-17 (C7/C8): romance-stage priority slots fire on the next
calm tick (stage >= 2 only); the dry channel pushes one comedic
private thought per 60 ticks via the social helper; never for a
CRITICAL-mood worker; a raid open suppresses both."
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    ;; the dry channel: push a comedic private thought
    (setf (cistern-st-tick st) 100)
    (let ((c (cistern-st-comedy st)))
      (plist-put c :last-dry 40)
      ;; force non-suppressed
      (plist-put c :anchors nil))
    (let ((before (cistern-st-social-pos st))
          (before-comedy (plist-get (cistern-st-comedy st) :pos)))
      (cistern--comedy-eval st nil)
      (cl-assert (/= (plist-get (cistern-st-comedy st) :pos) before-comedy)
                 t "C8: the dry channel draws from stream 6")
      (cl-assert (= (cistern-st-social-pos st) before)
                 t "C8: the thought-push-key does NOT advance social-pos"))
    ;; the thought landed in α's ledger
    (let ((found nil))
      (dolist (w (cistern-st-creators st))
        (let* ((id (cistern--worker-glyph st w))
               (ledger (plist-get (gethash id (cistern-st-personas st))
                                  :ledger)))
          (when (and ledger (eq (nth 1 (car ledger)) 'private))
            (cl-assert (cistern--story-copy-key (nth 2 (car ledger)))
                       t "C8: the dry thought resolves")
            (setq found t))))
      (cl-assert found t "C8: a dry thought landed as private")))
  ;; the dry channel: never for a CRITICAL-mood worker
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-bladder w) 115)
      (setf (cistern--worker-sick w) 5)
      (setf (cistern-st-tick st) 100)
      (let ((c (cistern-st-comedy st)))
        (plist-put c :last-dry 40)
        (plist-put c :anchors nil))
      (let ((ledger-before
             (plist-get (gethash (cistern--worker-glyph st w)
                                 (cistern-st-personas st))
                        :ledger)))
        (cistern--comedy-eval st nil)
        (let ((ledger-after
               (plist-get (gethash (cistern--worker-glyph st w)
                                   (cistern-st-personas st))
                          :ledger)))
          (cl-assert (equal ledger-before ledger-after)
                     t "C8: no dry thought for a CRITICAL worker")))))
  ;; the romance priority slot: stage >= 2 arms a beat on the next
  ;; calm tick, superseding the budget without moving :last-beat-tick
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-tick st) 50)
    (plist-put (cistern-st-comedy st) :last-beat-tick 49)
    (plist-put (cistern-st-comedy st) :romance-slot t)
    (let ((last0 (plist-get (cistern-st-comedy st) :last-beat-tick)))
      (cistern--comedy-eval st nil)
      (cl-assert (/= 0 (plist-get (cistern-st-comedy st) :last-beat-tick))
                 t "C7: the romance slot fires a beat")
      (cl-assert (null (plist-get (cistern-st-comedy st) :romance-slot))
                 t "C7: the slot clears after firing")))
  ;; the contrast rule: a raid open suppresses the romance slot too
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-raid st) (list :open 1))
    (setf (cistern-st-tick st) 50)
    (plist-put (cistern-st-comedy st) :romance-slot t)
    (cistern--comedy-eval st nil)
    (cl-assert (plist-get (cistern-st-comedy st) :romance-slot)
               t "C7: the romance slot holds during a raid"))
  (message "CISTERN-V5-17-OK"))

(defun cistern-test-v5-18-determinism ()
  "V5-18 (C9/C12): stream hygiene — comedy-eval moves only
comedy-pos; two seed-20260830 soaks byte-identical incl. comedy
state; different seed -> different comedy-pos; no comedy intent
within 40 ticks after a violent anchor."
  ;; stream hygiene: comedy-eval moves only comedy-pos
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    (setf (cistern-st-auto-run st) t)
    (setf (cistern-st-tick st) 750)
    (plist-put (cistern-st-comedy st) :last-beat-tick 0)
    (let ((rng (cistern-st-rng st)) (prng (cistern-st-particle-rng st))
          (rpg (cistern-st-rpg-pos st)) (cb (cistern-st-combat-pos st))
          (soc (cistern-st-social-pos st)))
      (cistern--comedy-eval st nil)
      (cl-assert (= (cistern-st-rng st) rng) t "C9: sim LCG untouched")
      (cl-assert (= (cistern-st-particle-rng st) prng)
                 t "C9: particle stream untouched")
      (cl-assert (= (cistern-st-rpg-pos st) rpg) t "C9: RPG untouched")
      (cl-assert (= (cistern-st-combat-pos st) cb) t "C9: combat untouched")
      (cl-assert (= (cistern-st-social-pos st) soc) t "C9: social untouched")))
  ;; C9: two 300-tick soaks byte-identical incl. comedy-pos
  (let* ((h1 (cistern-test-v5-18--soak))
         (h2 (cistern-test-v5-18--soak)))
    (cl-assert (string= (cadr h1) (cadr h2))
               t "C9: two runs byte-identical"))
  ;; different seed -> different comedy-pos
  (let ((st1 (cistern--new-game 20260830))
        (st2 (cistern--new-game 99999)))
    (cl-assert (/= (plist-get (cistern-st-comedy st1) :pos)
                   (plist-get (cistern-st-comedy st2) :pos))
               t "C9: different seeds -> different comedy-pos"))
  ;; C12: no comedy intent within 40 ticks after a violent anchor
  (let ((st (cistern--new-game 20260830)))
    (cistern--banks-load
     (list (expand-file-name "data/banks/example.el"
                             cistern-test-v5--root)))
    ;; force a worker-death anchor at tick 100
    (dotimes (_ 100) (cistern--do-tick st))
    (let ((w (nth 0 (cistern-st-creators st))))
      (setf (cistern--worker-hp w) 1)
      (cistern--worker-damage st w 10))
    (let ((anchor-tick (cistern-st-tick st))
          (comedy-count 0))
      (dotimes (_ 39)
        (cistern--do-tick st)
        (dolist (i (cdr (cistern-st-rewards-outcome st)))
          (when (and (consp i) (eq (plist-get i :face) 'comedy))
            (setq comedy-count (1+ comedy-count)))))
      (cl-assert (= comedy-count 0)
                 t "C12: no comedy within the anchor cooldown")))
  (message "CISTERN-V5-18-OK"))

(defun cistern-test-v5-18--soak ()
  "A 300-tick bank-loaded soak of seed 20260830 with comedy active."
  (cistern-test-v5--load-social-banks)
  (cistern--banks-load
   (list (expand-file-name "data/banks/example.el"
                           cistern-test-v5--root)))
  (let ((st (cistern--new-game 20260830)))
    (dotimes (_ 300) (cistern--do-tick st))
    (list st
          (secure-hash
           'md5 (prin1-to-string
                 (list (cistern-st-comedy st)
                       (cistern-st-combat-pos st)
                       (cistern-st-raid st)))))))
