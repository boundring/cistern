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
