;;; cistern.el --- CISTERN: sanitation management for the megastructure -*- lexical-binding: t; -*-

;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: games

;;; Commentary:

;; CISTERN v2 — rebuilt from base principles.
;;
;; THE CONCEPT, PLAINLY
;;
;;   Route need to capacity.  Convert waste to income.
;;   Contamination is the clock.
;;
;; Workers (creators) generate alloy by mining, but must periodically
;; use sanitation.  Sanitation is a flow network: toilet -> pipe ->
;; tank.  A toilet works only when pipe-connected to a tank with
;; headroom.  Unserved need becomes contamination; contamination
;; spreads; at the limit the sector is condemned.
;;
;; ARCHITECTURE
;;
;; One state object (`cistern-st') is threaded through every
;; simulation and command function.  There is exactly one module
;; global: `cistern--st', the live game.  The simulation is
;; deterministic and seedable (tiny LCG in the state), so any run can
;; be reproduced exactly.  Rendering is a pure projection of state;
;; the tutorial is a table of predicates on state; the self-test runs
;; the full sim headless.
;;
;; Run `M-x cistern'.  SPACE advances one tick.  `?' is the briefing
;; with the glyph legend.  The inspector line under the grid explains
;; whatever the cursor rests on.  A tutorial walks the first shift.

;;; Code:

(require 'cl-lib)

(defgroup cistern nil "CISTERN: sanitation management sim." :group 'games)

(defconst cistern-version "2.0.0")

;; ---------------------------------------------------------------------------
;; 1. Tuning constants — the only numbers in the game live here.

(defconst cistern-w 34 "Sector width.")
(defconst cistern-h 16 "Sector height.")
(defconst cistern-tank-cap 60 "Tank capacity in waste units.")
(defconst cistern-use-load 10 "Waste units deposited per toilet use.")
(defconst cistern-use-ticks 2 "Ticks one toilet use occupies.")
(defconst cistern-bladder-seek 60 "Bladder %% at which a worker seeks a toilet.")
(defconst cistern-bladder-burst 120 "Bladder %% at which a worker breaches.")
(defconst cistern-bladder-rate 2 "Bladder %% gained per tick.")
(defconst cistern-sick-ticks 30 "Recovery time from sickness, in ticks.")
(defconst cistern-contam-limit 20 "Contamination count that condemns the sector.")
(defconst cistern-spread-pct 3 "Per-tick %% chance a hazard spreads to one floor.")
(defconst cistern-decay-pct 2 "Per-tick %% chance a hazard decays back to floor.")
(defconst cistern-pop-cap 8 "Maximum population.")
(defconst cistern-migrant-every 40 "Ticks between migrant arrivals.")
(defconst cistern-cost-toilet 10)
(defconst cistern-cost-pipe 2)
(defconst cistern-cost-tank 15)
(defconst cistern-cost-decon 3)
(defconst cistern-purge-rate 3 "Waste units per recovered alloy on purge.")

(defconst cistern--worker-glyphs ["α" "β" "γ" "δ" "ε" "ζ" "η" "θ"])

;; ---------------------------------------------------------------------------
;; 2. State — one object, threaded everywhere.

(cl-defstruct (cistern--worker (:constructor cistern--worker-make))
  x y (bladder 20) (sick 0) (mine 0) (use-t 0) (using nil) (toilet nil))

(cl-defstruct cistern-st
  (w cistern-w) (h cistern-h)
  map                        ; vector of cell symbols
  toilets                    ; hash (X . Y) -> plist (:busy)
  tanks                      ; hash (X . Y) -> plist (:load)
  creators                   ; list of cistern--worker
  (alloy 20) (tick 0) (contam 0) over
  (log nil) (cursor (cons 3 6))
  (rng 1)                    ; LCG state; determinism lives here
  (purges 0) (built-pipe 0) (built-toilet 0) (built-tank 0) (earned 0) (migrants 0)
  (tutorial 0))              ; index into cistern--tutorial-steps; t when done

(defun cistern--rand (st n)
  "Advance ST's LCG, return a value in [0,N).  Deterministic."
  (let ((x (cistern-st-rng st)))
    (setq x (mod (+ (* x 1103515245) 12345) 2147483648))
    (setf (cistern-st-rng st) x)
    (mod x n)))

(defun cistern--log (st fmt &rest args)
  (push (apply #'format fmt args) (cistern-st-log st))
  (when (> (length (cistern-st-log st)) 12)
    (setf (cistern-st-log st)
          (nbutlast (cistern-st-log st)
                    (- (length (cistern-st-log st)) 12)))))

;; ---------------------------------------------------------------------------
;; 3. Grid primitives.

(defun cistern--in-bounds-p (st x y)
  (and (>= x 0) (< x (cistern-st-w st)) (>= y 0) (< y (cistern-st-h st))))

(defun cistern--idx (st x y) (+ x (* y (cistern-st-w st))))

(defun cistern--cell (st x y) (aref (cistern-st-map st) (cistern--idx st x y)))

(defun cistern--set-cell (st x y c)
  (aset (cistern-st-map st) (cistern--idx st x y) c))

(defun cistern--neighbors (st x y)
  (delq nil
        (list (and (< (1+ x) (cistern-st-w st)) (cons (1+ x) y))
              (and (> x 0) (cons (1- x) y))
              (and (< (1+ y) (cistern-st-h st)) (cons x (1+ y)))
              (and (> y 0) (cons x (1- y))))))

;; ---------------------------------------------------------------------------
;; 4. Search — ONE flood primitive serves pathing and connectivity.

(defun cistern--flood (st sx sy pass-p)
  "BFS distances from (SX,SY) over cells where (PASS-P X Y).
Returns hash (X . Y) -> distance.  The seed is included regardless."
  (let ((dist (make-hash-table :test #'equal))
        (q (list (cons sx sy))))
    (puthash (cons sx sy) 0 dist)
    (while q
      (let* ((cur (car q))
             (d (gethash cur dist)))
        (setq q (cdr q))
        (dolist (n (cistern--neighbors st (car cur) (cdr cur)))
          (when (and (not (gethash n dist))
                     (funcall pass-p (car n) (cdr n)))
            (puthash n (1+ d) dist)
            (setq q (append q (list n)))))))
    dist))

(defun cistern--walkable-p (st x y tx ty)
  "Is (X,Y) enterable by a worker walking to target (TX,TY)?
Floor-family cells always.  A toilet only when it is the target:
entering a toilet IS seating yourself.  Toilets are rooms, not floors."
  (let ((c (cistern--cell st x y)))
    (or (memq c '(floor door ore pipe))
        (and (eq c 'toilet) (= x tx) (= y ty)))))

(defun cistern--occupied-cells (st except)
  "Hash of cells blocked by other workers."
  (let ((h (make-hash-table :test #'equal)))
    (dolist (c (cistern-st-creators st))
      (unless (eq c except)
        (puthash (cons (cistern--worker-x c) (cistern--worker-y c)) t h)))
    h))

(defun cistern--dist-from (st tx ty blocked &optional always st-x st-y)
  "Distance map from (TX,TY).  ALWAYS is a cell kept passable
(a worker may always stand on / leave their own tile)."
  (cistern--flood st tx ty
                  (lambda (x y)
                    (or (and always (= x st-x) (= y st-y))
                        (and (not (gethash (cons x y) blocked))
                             (cistern--walkable-p st x y tx ty))))))

(defun cistern--connected-tanks (st x y)
  "Tanks reachable from the plumbing network containing (X,Y)."
  (let ((seen (cistern--flood st x y
                              (lambda (px py)
                                (memq (cistern--cell st px py)
                                      '(toilet pipe tank)))))
        (tanks nil))
    (maphash (lambda (k _)
               (when (eq (cistern--cell st (car k) (cdr k)) 'tank)
                 (push k tanks)))
             seen)
    (sort tanks (lambda (a b) (< (car a) (car b))))))

(defun cistern--toilet-usable-p (st x y)
  (let ((entry (gethash (cons x y) (cistern-st-toilets st))))
    (and entry
         (not (plist-get entry :busy))
         (cl-some (lambda (tk)
                    (<= (+ (plist-get (gethash tk (cistern-st-tanks st)) :load)
                           cistern-use-load)
                        cistern-tank-cap))
                  (cistern--connected-tanks st x y)))))

(defun cistern--free-usable-toilets (st)
  (let ((out nil))
    (maphash (lambda (k _v)
               (when (cistern--toilet-usable-p st (car k) (cdr k))
                 (push k out)))
             (cistern-st-toilets st))
    (sort out (lambda (a b) (< (car a) (car b))))))

;; ---------------------------------------------------------------------------
;; 5. Map construction.

(defun cistern--build-map (st)
  (setf (cistern-st-map st) (make-vector (* (cistern-st-w st) (cistern-st-h st))
                                         'floor))
  ;; outer walls
  (dotimes (y (cistern-st-h st))
    (dotimes (x (cistern-st-w st))
      (when (or (= x 0) (= x (1- (cistern-st-w st)))
                (= y 0) (= y (1- (cistern-st-h st))))
        (cistern--set-cell st x y 'wall))))
  ;; interior spine wall x=8, doors at y=4 and y=11
  (cl-loop for y from 1 to (- (cistern-st-h st) 2)
           do (cistern--set-cell st 8 y 'wall))
  (cistern--set-cell st 8 4 'door)
  (cistern--set-cell st 8 11 'door)
  ;; cross wall y=8 from x=14..24, door at x=20
  (cl-loop for x from 14 to 24 do (cistern--set-cell st x 8 'wall))
  (cistern--set-cell st 20 8 'door)
  ;; west migrant gate
  (cistern--set-cell st 0 7 'door)
  ;; ore veins
  (cistern--set-cell st 13 3 'ore)
  (cistern--set-cell st 24 12 'ore)
  (cistern--set-cell st 28 3 'ore)
  ;; starter plumbing: tank (5,2) - pipe (4,2) - pipe (3,2) - toilet (3,3)
  (cistern--set-cell st 5 2 'tank)
  (cistern--set-cell st 4 2 'pipe)
  (cistern--set-cell st 3 2 'pipe)
  (cistern--set-cell st 3 3 'toilet)
  (setf (cistern-st-toilets st) (make-hash-table :test #'equal))
  (setf (cistern-st-tanks st) (make-hash-table :test #'equal))
  (puthash (cons 3 3) (list :busy nil) (cistern-st-toilets st))
  (puthash (cons 5 2) (list :load 30) (cistern-st-tanks st)))

;; ---------------------------------------------------------------------------
;; 6. Worker lifecycle.

(defun cistern--worker-glyph (st w)
  (let ((i (or (cl-position w (cistern-st-creators st) :test #'eq) 0)))
    (aref cistern--worker-glyphs (mod i (length cistern--worker-glyphs)))))

(defun cistern--spawn-worker (st x y)
  (let ((w (cistern--worker-make :x x :y y :bladder 20)))
    (setf (cistern-st-creators st)
          (append (cistern-st-creators st) (list w)))
    (setf (cistern-st-migrants st) (1+ (cistern-st-migrants st)))
    w))

(defun cistern--new-game (&optional seed)
  "Build fresh state.  SEED (integer) makes the run reproducible."
  (let ((st (make-cistern-st)))
    (cistern--build-map st)
    (setf (cistern-st-rng st) (or seed 20260830))
    (dolist (p '((12 6) (14 7) (11 9) (15 6)))
      (let ((w (cistern--worker-make :x (nth 0 p) :y (nth 1 p))))
        (setf (cistern-st-creators st) (append (cistern-st-creators st)
                                               (list w)))))
    (setf (cistern-st-migrants st) 0)
    (cistern--log st "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
    st))

;; ---------------------------------------------------------------------------
;; 7. Simulation phases.  Each takes ST, mutates ST, returns nothing.

(defun cistern--seek-work (st w)
  (let* ((x (cistern--worker-x w)) (y (cistern--worker-y w)))
    (if (eq (cistern--cell st x y) 'ore)
        (progn
          (setf (cistern--worker-mine w) (1+ (cistern--worker-mine w)))
          (when (>= (cistern--worker-mine w)
                    (if (> (cistern--worker-sick w) 0) 6 3))
            (setf (cistern--worker-mine w) 0)
            (setf (cistern-st-alloy st) (1+ (cistern-st-alloy st)))
            (setf (cistern-st-earned st) (1+ (cistern-st-earned st)))))
      (let ((ore nil) (i 0))
        (while (< i (length (cistern-st-map st)))
          (when (eq (aref (cistern-st-map st) i) 'ore)
            (push (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st))) ore))
          (cl-incf i))
        (setq ore (nreverse ore))
        (let ((best nil) (bd nil))
          (dolist (o ore)
            (let* ((blocked (cistern--occupied-cells st w))
                   (d (gethash (cons x y)
                               (cistern--dist-from st (car o) (cdr o)
                                                   blocked 'always x y))))
              (when (and d (or (null bd) (< d bd)))
                (setq bd d best o))))
          (if best
              (cistern--step-toward st w (car best) (cdr best))
            (cistern--shuffle st w)))))))

(defun cistern--step-toward (st w tx ty)
  "One step toward (TX,TY) using the BFS gradient.  Seats the
worker if the step lands them on a toilet target.  Updates the
occupancy grid so two workers can never share a tile."
  (let* ((x (cistern--worker-x w))
         (y (cistern--worker-y w))
         (blocked (cistern--occupied-cells st w))
         (dist (cistern--dist-from st tx ty blocked 'always x y))
         (d0 (gethash (cons x y) dist)))
    (when (and d0 (> d0 0))
      (let (best)
        (dolist (n (cistern--neighbors st x y))
          (let ((dd (gethash n dist)))
            (when (and dd (= dd (1- d0))
                       (not (gethash n blocked))
                       (not best))
              (setq best n))))
        (when best
          (setf (cistern--worker-x w) (car best))
          (setf (cistern--worker-y w) (cdr best))
          (when (and (eq (cistern--cell st (car best) (cdr best)) 'toilet)
                     (= (car best) tx) (= (cdr best) ty)
                     (>= (cistern--worker-bladder w) cistern-bladder-seek))
            ;; stepping onto the target toilet = seating
            (puthash best (list :busy t) (cistern-st-toilets st))
            (setf (cistern--worker-using w) t)
            (setf (cistern--worker-use-t w) cistern-use-ticks)
            (setf (cistern--worker-toilet w) best))
          t)))))

(defun cistern--shuffle (st w)
  (let* ((x (cistern--worker-x w))
         (y (cistern--worker-y w))
         (ns (cl-remove-if
              (lambda (n)
                (or (not (memq (cistern--cell st (car n) (cdr n))
                               '(floor door ore pipe)))
                    (gethash n (cistern--occupied-cells st w))))
              (cistern--neighbors st x y))))
    (when ns
      (let ((n (nth (cistern--rand st (length ns)) ns)))
        (setf (cistern--worker-x w) (car n))
        (setf (cistern--worker-y w) (cdr n))))))

(defun cistern--finish-use (st w)
  "Release the toilet, zero the bladder, deposit waste upstream.
The released cell is the worker's OWN recorded toilet cell — the
bug class where plumbing state pointed elsewhere cannot exist."
  (let* ((tp (cistern--worker-toilet w))
         (x (cistern--worker-x w))
         (y (cistern--worker-y w)))
    (setf (cistern--worker-using w) nil)
    (setf (cistern--worker-bladder w) 0)
    (setf (cistern--worker-toilet w) nil)
    (when tp
      (puthash tp (list :busy nil) (cistern-st-toilets st)))
    (let ((tanks (cistern--connected-tanks st (cistern--worker-x w)
                                            (cistern--worker-y w))))
      (if (null tanks)
          (progn
            (cistern--add-hazard st x y)
            (setf (cistern-st-contam st) (1+ (cistern-st-contam st)))
            (cistern--log st "SEVERED LINE AT (%d,%d) — WASTE SPILLED" x y))
        (let ((best (car tanks)))
          (dolist (tk tanks)
            (when (< (plist-get (gethash tk (cistern-st-tanks st)) :load)
                     (plist-get (gethash best (cistern-st-tanks st)) :load))
              (setq best tk)))
          (puthash best
                   (list :load (+ cistern-use-load
                                  (plist-get (gethash best
                                                        (cistern-st-tanks st))
                                             :load)))
                   (cistern-st-tanks st)))))))

(defun cistern--add-hazard (st x y)
  "Contaminate (X,Y) if it is floor.  Everything else — ore,
pipe, toilet, tank, wall — is a firebreak by rule: the resource
base can never be destroyed by unserved need."
  (when (and (cistern--in-bounds-p st x y)
             (eq (cistern--cell st x y) 'floor))
    (cistern--set-cell st x y 'hazard)
    t))

(defun cistern--accident (st w)
  (let ((x (cistern--worker-x w)) (y (cistern--worker-y w)))
    (setf (cistern--worker-bladder w) 0)
    (or (cistern--add-hazard st x y)
        (catch 'placed
          (dolist (n (cistern--neighbors st x y))
            (when (and (cistern--add-hazard st (car n) (cdr n))
                       (not (gethash n (cistern--occupied-cells st w))))
              (throw 'placed t)))))
    (setf (cistern-st-contam st) (1+ (cistern-st-contam st)))
    (dolist (n (cistern--neighbors st x y))
      (dolist (o (cistern-st-creators st))
        (when (and (not (eq o w))
                   (= (cistern--worker-x o) (car n))
                   (= (cistern--worker-y o) (cdr n)))
          (setf (cistern--worker-sick o) cistern-sick-ticks))))
    (cistern--log st "BREACH — CREATOR %s OVERFLOWED AT (%d,%d)"
                  (cistern--worker-glyph st w) x y)))

(defun cistern--seek-toilet (st w)
  (let* ((x (cistern--worker-x w))
         (y (cistern--worker-y w))
         (here (cons x y))
         (tp (cistern--worker-toilet w)))
    (cond
     ;; already seated on our own toilet
     ((and tp (cistern--worker-using w)) nil)
     ;; standing ON a free usable toilet: seat
     ((and (eq (cistern--cell st x y) 'toilet)
           (cistern--toilet-usable-p st x y))
      (puthash here (list :busy t) (cistern-st-toilets st))
      (setf (cistern--worker-using w) t)
      (setf (cistern--worker-use-t w) cistern-use-ticks)
      (setf (cistern--worker-toilet w) here))
     (t
      (let ((best nil) (bd nil))
        (dolist (cand (cistern--free-usable-toilets st))
          (let* ((blocked (cistern--occupied-cells st w))
                 (d (gethash (cons x y)
                             (cistern--dist-from st (car cand) (cdr cand)
                                                 blocked 'always x y))))
            (when (and d (or (null bd) (< d bd)))
              (setq bd d best cand))))
        (if best
            (cistern--step-toward st w (car best) (cdr best))
          (cistern--seek-work st w)))))))

(defun cistern--phase-creators (st)
  (dolist (w (copy-sequence (cistern-st-creators st)))
      (if (cistern--worker-using w)
          (progn
            (setf (cistern--worker-use-t w)
                  (1- (cistern--worker-use-t w)))
            (when (<= (cistern--worker-use-t w) 0)
              (cistern--finish-use st w)))
        ;; sickness costs productivity, never mobility: a sick worker
        ;; still reaches toilets in time but mines at half rate
        (when (> (cistern--worker-sick w) 0)
          (setf (cistern--worker-sick w) (1- (cistern--worker-sick w))))
        (setf (cistern--worker-bladder w)
              (+ cistern-bladder-rate (cistern--worker-bladder w)))
        (cond
         ((>= (cistern--worker-bladder w) cistern-bladder-burst)
          (cistern--accident st w))
         ((>= (cistern--worker-bladder w) cistern-bladder-seek)
          (cistern--seek-toilet st w))
         (t (cistern--seek-work st w))))))

(defun cistern--phase-hazards (st)
  "Spread and decay.  Spread 3%% onto clean floor (never onto a
worker); decay 2%% back to floor.  Contamination is pressure, not
permanent scarring: stop bleeding and the marks fade."
  (let ((hs nil) (i 0))
    (while (< i (length (cistern-st-map st)))
      (when (eq (aref (cistern-st-map st) i) 'hazard)
        (push (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st))) hs))
      (cl-incf i))
    (setq hs (nreverse hs))
    (dolist (h hs)
      (let ((roll (cistern--rand st 100)))
        (cond
         ((< roll cistern-spread-pct)
          (let* ((cands (cl-remove-if
                         (lambda (n)
                           (or (not (eq (cistern--cell st (car n) (cdr n))
                                        'floor))
                               (gethash n (cistern--occupied-cells st nil))))
                         (cistern--neighbors st (car h) (cdr h)))))
            (when cands
              (let ((n (nth (cistern--rand st (length cands)) cands)))
                (cistern--add-hazard st (car n) (cdr n))))))
         ((< roll (+ cistern-spread-pct cistern-decay-pct))
          (cistern--set-cell st (car h) (cdr h) 'floor)))))))

(defun cistern--phase-migration (st)
  (when (and (> (cistern-st-tick st) 0)
             (= 0 (% (cistern-st-tick st) cistern-migrant-every))
             (< (length (cistern-st-creators st)) cistern-pop-cap))
    (if (and (eq (cistern--cell st 1 7) 'floor)
             (not (gethash (cons 1 7) (cistern--occupied-cells st nil))))
        (progn
          (cistern--spawn-worker st 1 7)
          (cistern--log st "MIGRANT ENTERED SECTOR — POPULATION %d"
                        (length (cistern-st-creators st))))
      (cistern--log st "MIGRANT WAITS AT THE GATE"))))

(defun cistern--phase-check (st)
  (when (and (not (cistern-st-over st))
             (>= (cistern-st-contam st) cistern-contam-limit))
    (setf (cistern-st-over st) "SECTOR CONDEMNED — CONTAMINATION LIMIT")
    (cistern--log st (cistern-st-over st))))

(defun cistern--do-tick (st)
  (setf (cistern-st-tick st) (1+ (cistern-st-tick st)))
  (cistern--phase-creators st)
  (cistern--phase-hazards st)
  (cistern--phase-migration st)
  (cistern--phase-check st)
  (cistern--tutorial-advance st))

;; ---------------------------------------------------------------------------
;; 8. Player verbs — state in, state out.

(defun cistern--cmd-build (st kind x y)
  (let ((cost (pcase kind
                ('toilet cistern-cost-toilet)
                ('pipe cistern-cost-pipe)
                ('tank cistern-cost-tank))))
    (cond
     ((not (cistern--in-bounds-p st x y)) (cistern--log st "OUT OF SECTOR"))
     ((not (eq (cistern--cell st x y) 'floor))
      (cistern--log st "CANNOT BUILD THERE"))
     ((gethash (cons x y) (cistern--occupied-cells st nil))
      (cistern--log st "WORKER IN THE WAY"))
     ((< (cistern-st-alloy st) cost)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED" cost))
     (t
      (setf (cistern-st-alloy st) (- (cistern-st-alloy st) cost))
      (cistern--set-cell st x y kind)
      (pcase kind
        ('toilet
         (puthash (cons x y) (list :busy nil) (cistern-st-toilets st))
         (setf (cistern-st-built-toilet st)
               (1+ (cistern-st-built-toilet st))))
        ('tank
         (puthash (cons x y) (list :load 0) (cistern-st-tanks st))
         (setf (cistern-st-built-tank st) (1+ (cistern-st-built-tank st))))
        ('pipe
         (setf (cistern-st-built-pipe st) (1+ (cistern-st-built-pipe st)))))
      (cistern--log st "%s PLACED AT (%d,%d) — %d ALLOY"
                    (upcase (symbol-name kind)) x y cost)))))

(defun cistern--cmd-decon (st x y)
  (cond
   ((not (and (cistern--in-bounds-p st x y)
              (eq (cistern--cell st x y) 'hazard)))
    (cistern--log st "NO CONTAMINANT UNDER CURSOR"))
   ((< (cistern-st-alloy st) cistern-cost-decon)
    (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED" cistern-cost-decon))
   (t
    (setf (cistern-st-alloy st) (- (cistern-st-alloy st) cistern-cost-decon))
    (cistern--set-cell st x y 'floor)
    (cistern--log st "DECONTAMINATED (%d,%d) — %d ALLOY"
                  x y cistern-cost-decon))))

(defun cistern--cmd-purge (st x y)
  (let ((tp (gethash (cons x y) (cistern-st-tanks st))))
    (cond
     ((not tp) (cistern--log st "CURSOR NOT ON A TANK"))
     ((= (plist-get tp :load) 0) (cistern--log st "TANK ALREADY CLEAR"))
     (t
      (let* ((load (plist-get tp :load))
             (gain (/ load cistern-purge-rate)))
        (puthash (cons x y) (list :load 0) (cistern-st-tanks st))
        (setf (cistern-st-alloy st) (+ (cistern-st-alloy st) gain))
        (setf (cistern-st-purges st) (1+ (cistern-st-purges st)))
        (cistern--log st "TANK PURGED — RECOVERED %d ALLOY" gain))))))

;; ---------------------------------------------------------------------------
;; 9. Tutorial — a table of predicates on state.

(defun cistern--tutorial-steps ()
  "Each step: (PROMPT . PREDICATE).  Predicate takes ST, non-nil
advances.  Simplest form of the idea: teach one verb at a time."
  '(("SPACE advances the clock.  Press it once."
     . (lambda (st) (> (cistern-st-tick st) 0)))
    ("hjkl / arrows move the cursor.  Park it on the tank ▣ (top left)."
     . (lambda (st) (eq (cistern--cell st (car (cistern-st-cursor st))
                        (cdr (cistern-st-cursor st)))
                        'tank)))
    ("Press x: PURGE converts stored waste back to alloy."
     . (lambda (st) (> (cistern-st-purges st) 0)))
    ("◆ ore pays alloy.  Workers walk there themselves — let them earn."
     . (lambda (st) (> (cistern-st-earned st) 0)))
    ("At 60%% bladder a worker walks to Ω and seats.  Let one use it."
     . (lambda (st)
         (cl-some (lambda (w) (cistern--worker-using w))
                  (cistern-st-creators st))))
    ("Lay pipe: p on open floor.  Pipe is the only wire in the network."
     . (lambda (st) (> (cistern-st-built-pipe st) 0)))
    ("Build a second toilet: t on open floor (10 alloy)."
     . (lambda (st) (> (cistern-st-built-toilet st) 0)))
    ("Wire it: run pipe from the new Ω to a tank until Ω turns white."
     . (lambda (st)
         (cl-some (lambda (k)
                    (and (not (equal k (cons 3 3)))
                         (cistern--toilet-usable-p st (car k) (cdr k))))
                  (let ((out nil))
                    (maphash (lambda (k _v) (push k out))
                             (cistern-st-toilets st))
                    out))))
    ("Every 40 ticks a migrant arrives.  Stay ahead of them.  ? = help."
     . (lambda (st) (> (cistern-st-migrants st) 0)))))

(defun cistern--tutorial-advance (st)
  (let ((idx (cistern-st-tutorial st)))
    (when (and (numberp idx)
               (< idx (length (cistern--tutorial-steps)))
               (funcall (cdr (nth idx (cistern--tutorial-steps))) st))
      (setf (cistern-st-tutorial st) (1+ idx))
      (if (>= (1+ idx) (length (cistern--tutorial-steps)))
          (progn
            (setf (cistern-st-tutorial st) t)
            (cistern--log st "TUTORIAL COMPLETE — THE SECTOR IS YOURS"))
        (cistern--log st "TUTORIAL: OBJECTIVE COMPLETE")))))

;; ---------------------------------------------------------------------------
;; 10. View — a pure projection of state.

(defface cistern-wall '((t :foreground "grey35")) "CISTERN walls.")
(defface cistern-floor '((t :foreground "grey40")) "CISTERN floor.")
(defface cistern-door '((t :foreground "grey60")) "CISTERN doors.")
(defface cistern-ore '((t :foreground "yellow3")) "CISTERN ore veins.")
(defface cistern-pipe '((t :foreground "cyan")) "CISTERN pipe.")
(defface cistern-toilet '((t :foreground "white" :weight bold)) "Toilet.")
(defface cistern-toilet-busy '((t :foreground "magenta" :weight bold)) "Toilet in use.")
(defface cistern-toilet-down '((t :foreground "red" :weight bold)) "Toilet out of service.")
(defface cistern-tank-ok '((t :foreground "green")) "Tank below 50% load.")
(defface cistern-tank-high '((t :foreground "yellow")) "Tank at 50-85% load.")
(defface cistern-tank-full '((t :foreground "red" :weight bold)) "Tank near capacity.")
(defface cistern-hazard '((t :foreground "red" :weight bold)) "Contamination.")
(defface cistern-worker '((t :foreground "green" :weight bold)) "Worker.")
(defface cistern-worker-sick '((t :foreground "orange" :weight bold)) "Sick worker.")
(defface cistern-cursor '((t :inverse-video t :weight bold)) "Cursor cell.")
(defface cistern-header '((t :foreground "white" :weight bold)) "Header line.")
(defface cistern-dim '((t :foreground "grey55")) "Dim UI text.")
(defface cistern-tutorial '((t :foreground "cyan" :weight bold)) "Tutorial line.")

(defun cistern--pipe-glyph (st x y)
  (let* ((plumbp (lambda (px py)
                   (and (cistern--in-bounds-p st px py)
                        (memq (cistern--cell st px py) '(pipe toilet tank)))))
         (n (funcall plumbp x (1- y)))
         (s (funcall plumbp x (1+ y)))
         (w (funcall plumbp (1- x) y))
         (e (funcall plumbp (1+ x) y)))
    (cond ((and n s e w) "┼")
          ((and n s) "│")
          ((and e w) "─")
          ((and n e) "└")
          ((and n w) "┘")
          ((and s e) "┌")
          ((and s w) "┐")
          ((or n s) "│")
          ((or e w) "─")
          (t "·"))))

(defun cistern--glyph-face (st x y)
  (let ((c (cistern--cell st x y)))
    (pcase c
      ('wall (cons "▓" 'cistern-wall))
      ('floor (cons "·" 'cistern-floor))
      ('door (cons "+" 'cistern-door))
      ('ore (cons "◆" 'cistern-ore))
      ('hazard (cons "▒" 'cistern-hazard))
      ('toilet
       (let ((e (gethash (cons x y) (cistern-st-toilets st))))
         (cond ((plist-get e :busy) (cons "Ω" 'cistern-toilet-busy))
               ((cistern--toilet-usable-p st x y) (cons "Ω" 'cistern-toilet))
               (t (cons "Ω" 'cistern-toilet-down)))))
      ('tank
       (let ((l (plist-get (gethash (cons x y) (cistern-st-tanks st)) :load)))
         (cons "▣" (cond ((< l 30) 'cistern-tank-ok)
                         ((< l 51) 'cistern-tank-high)
                         (t 'cistern-tank-full)))))
      ('pipe (cons (cistern--pipe-glyph st x y) 'cistern-pipe))
      (_ (cons "?" 'default)))))

(defun cistern--inspector (st)
  "One sentence describing whatever the cursor rests on."
  (let* ((x (car (cistern-st-cursor st)))
         (y (cdr (cistern-st-cursor st)))
         (c (cistern--cell st x y))
         (w (cl-find-if (lambda (w)
                          (and (= (cistern--worker-x w) x)
                               (= (cistern--worker-y w) y)))
                        (cistern-st-creators st)))
         (base
          (pcase c
            ('wall "MEGASTRUCTURE WALL")
            ('floor "FLOOR")
            ('door "GATE / DOOR")
            ('ore "ORE VEIN — +1 ALLOY PER 3 TICKS WORKED")
            ('hazard "CONTAMINATION — press c to decon (4 alloy)")
            ('pipe "PIPE — the only wire; keep it short")
            ('toilet
             (let ((e (gethash (cons x y) (cistern-st-toilets st))))
               (cond
                ((plist-get e :busy) "TOILET — IN USE")
                ((cistern--toilet-usable-p st x y)
                 "TOILET — WIRED AND SERVICED")
                ((cistern--connected-tanks st x y)
                 "TOILET — BACKED UP: PURGE THE TANKS (x)")
                (t "TOILET — SEVERED: LAY PIPE TO A TANK (p)"))))
            ('tank
             (let ((l (plist-get (gethash (cons x y)
                                          (cistern-st-tanks st)) :load)))
               (format "TANK — LOAD %d/%d · PURGE WITH x (pays 1 alloy per %d)"
                       l cistern-tank-cap cistern-purge-rate)))
            (_ "UNKNOWN")))
         (who
          (when w
            (format "%s — bladder %d%% · %s"
                    (cistern--worker-glyph st w)
                    (cistern--worker-bladder w)
                    (cond ((cistern--worker-using w)
                           (format "in toilet (%d ticks left)"
                                   (cistern--worker-use-t w)))
                          ((> (cistern--worker-sick w) 0)
                           (format "sick (%d ticks)" (cistern--worker-sick w)))
                          (t "working"))))))
    (concat "CURSOR (" (number-to-string x) "," (number-to-string y) "): "
            base (if who (concat "  ·  " who) ""))))

(defun cistern--pressure-line (st)
  (let* ((total-load 0)
         (_ (maphash (lambda (_k v)
                       (setq total-load
                             (+ total-load (plist-get v :load))))
                     (cistern-st-tanks st)))
         (backed nil))
    (maphash (lambda (k _v)
               (when (and (not (plist-get (gethash k (cistern-st-toilets st))
                                          :busy))
                          (not (cistern--toilet-usable-p st
                                                         (car k) (cdr k))))
                 (setq backed t)))
             (cistern-st-toilets st))
    (cond ((cistern-st-over st) "SECTOR CONDEMNED — PRESS n TO RESTART")
          (backed "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS")
          ((> total-load 100) "PRESSURE RISING — LINES NEAR CAPACITY")
          (t "LINES NOMINAL — THE STRUCTURE DOES NOT CARE"))))

(defun cistern--render (st)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize
             (format "CISTERN ▓ SECTOR-7 ▓ v%s  TICK %d   ALLOY %d   POP %d/%d   CONTAM %d/%d   SEED %d%s\n"
                     cistern-version (cistern-st-tick st)
                     (cistern-st-alloy st)
                     (length (cistern-st-creators st)) cistern-pop-cap
                     (cistern-st-contam st) cistern-contam-limit
                     (cistern-st-rng st)
                     (if (cistern-st-over st)
                         (concat "   ▓▓ " (cistern-st-over st)) ""))
             'face 'cistern-header))
    (insert (propertize
             (format "[hjkl/arrows] cursor  [t]oilet %d  [p]ipe %d  [k]tank %d  [c]decon %d  [x]purge  [SPC]tick  [r]un  [n]new  [?]help  [q]uit\n"
                     cistern-cost-toilet cistern-cost-pipe
                     cistern-cost-tank cistern-cost-decon)
             'face 'cistern-dim))
    (insert (propertize
             "GLYPHS:  ▓ wall  · floor  ◆ ore  ─ pipe  Ω toilet  ▣ tank  ▒ contamination  + gate  α worker\n"
             'face 'cistern-dim))
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (let* ((pos (cons x y))
               (cur (equal pos (cistern-st-cursor st)))
               (cr (cl-find-if
                    (lambda (c) (and (= (cistern--worker-x c) x)
                                     (= (cistern--worker-y c) y)))
                    (cistern-st-creators st)))
               (cell-g (cistern--glyph-face st x y))
               (glyph (if cr (cistern--worker-glyph st cr) (car cell-g)))
               (face (if cr
                         (if (> (cistern--worker-sick cr) 0)
                             'cistern-worker-sick 'cistern-worker)
                       (cdr cell-g))))
          (insert (propertize glyph 'face
                              (if cur (list 'cistern-cursor face) face)))))
      (insert "\n"))
    (insert (propertize (cistern--inspector st) 'face 'cistern-dim))
    (insert "\n")
    (insert (propertize (cistern--pressure-line st) 'face 'cistern-dim))
    (insert "\n")
    (let ((idx (cistern-st-tutorial st)))
      (when (numberp idx)
        (insert (propertize
                 (format "TUTORIAL %d/%d: %s  (T skips)"
                         (1+ idx) (length (cistern--tutorial-steps))
                         (car (nth idx (cistern--tutorial-steps))))
                 'face 'cistern-tutorial))
        (insert "\n")))
    (dolist (l (last (reverse (cistern-st-log st)) 3))
      (insert (propertize l 'face 'cistern-dim) "\n"))
    (goto-char (point-min))))

;; ---------------------------------------------------------------------------
;; 11. Interactive layer.  One global: the live state.

(defvar cistern--st nil)

(defvar cistern-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "SPC") #'cistern-tick)
    (define-key m (kbd "RET") #'cistern-tick)
    (define-key m (kbd "<up>") #'cistern-cursor-north)
    (define-key m (kbd "<down>") #'cistern-cursor-south)
    (define-key m (kbd "<left>") #'cistern-cursor-west)
    (define-key m (kbd "<right>") #'cistern-cursor-east)
    (define-key m "k" #'cistern-cursor-north)
    (define-key m "j" #'cistern-cursor-south)
    (define-key m "h" #'cistern-cursor-west)
    (define-key m "l" #'cistern-cursor-east)
    (define-key m "t" #'cistern-build-toilet)
    (define-key m "p" #'cistern-build-pipe)
    (define-key m "K" #'cistern-build-tank)
    (define-key m "c" #'cistern-decon)
    (define-key m "x" #'cistern-purge)
    (define-key m "r" #'cistern-run-10)
    (define-key m "T" #'cistern-skip-tutorial)
    (define-key m "n" #'cistern-new-game)
    (define-key m "?" #'cistern-help)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode cistern-mode special-mode "CISTERN"
  "Major mode for the CISTERN sanitation management sim."
  (setq-local truncate-lines t)
  (setq-local cursor-type nil))

;;;###autoload
(defun cistern ()
  "Open the CISTERN sanitation management sim."
  (interactive)
  (switch-to-buffer "*cistern*")
  (unless (eq major-mode 'cistern-mode)
    (cistern-mode))
  (unless cistern--st
    (setq cistern--st (cistern--new-game)))
  (cistern--render cistern--st))

(defun cistern-new-game ()
  (interactive)
  (setq cistern--st (cistern--new-game
                     (cistern--rand cistern--st 2147483647)))
  (cistern--render cistern--st))

(defun cistern-skip-tutorial ()
  (interactive)
  (setf (cistern-st-tutorial cistern--st) t)
  (cistern--log cistern--st "TUTORIAL SKIPPED")
  (cistern--render cistern--st))

(defun cistern-tick ()
  (interactive)
  (if (cistern-st-over cistern--st)
      (cistern--log cistern--st "SECTOR CONDEMNED — PRESS n FOR NEW GAME")
    (cistern--do-tick cistern--st))
  (cistern--render cistern--st))

(defun cistern-run-10 ()
  (interactive)
  (dotimes (_ 10)
    (unless (cistern-st-over cistern--st)
      (cistern--do-tick cistern--st)))
  (cistern--render cistern--st))

(defun cistern-cursor-north ()
  (interactive) (cistern--cursor-move cistern--st 0 -1))
(defun cistern-cursor-south ()
  (interactive) (cistern--cursor-move cistern--st 0 1))
(defun cistern-cursor-west ()
  (interactive) (cistern--cursor-move cistern--st -1 0))
(defun cistern-cursor-east ()
  (interactive) (cistern--cursor-move cistern--st 1 0))

(defun cistern--cursor-move (st dx dy)
  (let ((nx (+ (car (cistern-st-cursor st)) dx))
        (ny (+ (cdr (cistern-st-cursor st)) dy)))
    (when (cistern--in-bounds-p st nx ny)
      (setf (cistern-st-cursor st) (cons nx ny)))
    (cistern--render st)))

(defun cistern-build-toilet ()
  (interactive)
  (cistern--cmd-build cistern--st 'toilet
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--render cistern--st))

(defun cistern-build-pipe ()
  (interactive)
  (cistern--cmd-build cistern--st 'pipe
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--render cistern--st))

(defun cistern-build-tank ()
  (interactive)
  (cistern--cmd-build cistern--st 'tank
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--render cistern--st))

(defun cistern-decon ()
  (interactive)
  (cistern--cmd-decon cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--render cistern--st))

(defun cistern-purge ()
  (interactive)
  (cistern--cmd-purge cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--render cistern--st))

(defun cistern-help ()
  (interactive)
  (with-output-to-temp-buffer "*cistern help*"
    (princ (format "CISTERN v%s — sanitation protocol for Sector 7\n\n" cistern-version))
    (princ "THE CONCEPT\n")
    (princ "  Route need to capacity.  Convert waste to income.\n")
    (princ "  Contamination is the clock.\n\n")
    (princ "GLYPHS\n")
    (princ "  ▓ wall    · floor    ◆ ore vein    ─ pipe    Ω toilet\n")
    (princ "  ▣ tank    ▒ contamination    + gate    α..θ workers\n\n")
    (princ "THE LOOP\n")
    (princ "  Workers mine ◆ for alloy.  Their bladders fill.  At 60%%\n")
    (princ "  they walk to a Ω and seat themselves — entering the toilet\n")
    (princ "  tile IS sitting down.  A Ω works only when piped to a ▣ with\n")
    (princ "  headroom.  Each use sends 10 units down the line.\n\n")
    (princ "  A full ▣ backs up every Ω it feeds (red Ω).  Purge with x on\n")
    (princ "  the ▣: free, and it PAYS 1 alloy per 3 units of waste.\n\n")
    (princ "  At 100%% a worker breaches: the tile turns ▒, contamination\n")
    (princ "  rises, neighbors fall sick.  ▒ spreads to adjacent floor.\n")
    (princ "  Decon with c.  At %d the sector is condemned.\n\n" cistern-contam-limit)
    (princ "  Every %d ticks a migrant arrives.  Population means load.\n\n" cistern-migrant-every)
    (princ "CONTROLS\n")
    (princ "  SPC / RET   advance one tick\n")
    (princ "  hjkl / arrows   move cursor\n")
    (princ "  t   build toilet (12)     p   lay pipe (2)\n")
    (princ "  K   build tank (15)       c   decontaminate (4)\n")
    (princ "  x   purge tank (pays)     r   run 10 ticks\n")
    (princ "  T   skip tutorial         n   new game\n")
    (princ "  ?   this briefing         q   quit\n")))

;; ---------------------------------------------------------------------------
;; 12. Headless verification.  Deterministic: same seed, same game.

(defun cistern-run-selftest ()
  "Headless proof of every rule that can break gameplay."
  (interactive)
  ;; --- map integrity
  (let ((st (cistern--new-game 42)))
    (cl-assert (= (cistern-st-w st) cistern-w))
    (cl-assert (= (length (cistern-st-map st)) (* cistern-w cistern-h)))
    (cl-loop for x from 0 below cistern-w
             do (cl-assert (eq (cistern--cell st x 0) 'wall)))
    (cl-loop for y from 0 below cistern-h
             do (cl-assert (memq (cistern--cell st 0 y) '(wall door))))
    (cl-assert (eq (cistern--cell st 0 7) 'door))
    (cl-assert (eq (cistern--cell st 3 3) 'toilet))
    (cl-assert (cistern--toilet-usable-p st 3 3))

    ;; --- THE TOILET LOOP (the bug that shipped v1): walk in, use,
    ;; release, network intact, no phantom plumbing state.
    (let ((w (car (cistern-st-creators st))))
      (setf (cistern--worker-x w) 4)
      (setf (cistern--worker-y w) 3)
      (setf (cistern--worker-bladder w) cistern-bladder-seek)
      (setf (cistern--worker-sick w) 0)
      (cistern--do-tick st)
      (cl-assert (cistern--worker-using w) "worker should be seated")
      (let ((tp (cistern--worker-toilet w)))
        (cl-assert (equal tp (cons 3 3)) "seated on the start toilet")
        (cl-assert (plist-get (gethash tp (cistern-st-toilets st)) :busy)))
      (dotimes (_ cistern-use-ticks)
        (cistern--do-tick st))
      (cl-assert (not (cistern--worker-using w)) "use should complete")
      (cl-assert (= (cistern--worker-bladder w) 0))
      (cl-assert (= (+ 30 cistern-use-load)
                    (plist-get (gethash (cons 5 2) (cistern-st-tanks st))
                               :load))
                 "waste deposited in the wired tank")
      (cl-assert (not (plist-get (gethash (cons 3 3)
                                          (cistern-st-toilets st)) :busy))
                 "toilet released after use")
      (cl-assert (cistern--toilet-usable-p st 3 3))
      ;; plumbing state may only reference real toilet cells
      (maphash (lambda (k _)
                 (cl-assert (eq (cistern--cell st (car k) (cdr k)) 'toilet)))
               (cistern-st-toilets st)))

    ;; --- backed up / purge economy
    (puthash (cons 5 2) (list :load cistern-tank-cap)
             (cistern-st-tanks st))
    (cl-assert (not (cistern--toilet-usable-p st 3 3)))
    (let ((a0 (cistern-st-alloy st)))
      (cistern--cmd-purge st 5 2)
      (cl-assert (= (cistern-st-alloy st)
                    (+ a0 (/ cistern-tank-cap cistern-purge-rate)))))
    (cl-assert (cistern--toilet-usable-p st 3 3))

    ;; --- breach, decon, firebreaks
    (let ((w (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 12)
      (setf (cistern--worker-y w) 6)
      (setf (cistern--worker-bladder w)
            (- cistern-bladder-burst cistern-bladder-rate))
      (cistern--do-tick st)
      (cl-assert (eq (cistern--cell st 12 6) 'hazard))
      (cl-assert (= (cistern-st-contam st) 1)))
    (cistern--cmd-decon st 12 6)
    (cl-assert (eq (cistern--cell st 12 6) 'floor))

    ;; --- a worker ON a hazard tile can still leave (no statues)
    (let ((w (nth 2 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 10)
      (setf (cistern--worker-y w) 6)
      (cistern--set-cell st 10 6 'hazard)
      (setf (cistern--worker-bladder w) 0)
      ;; two ticks: the worker may be sick and act only on even ticks
      (let ((x0 (cistern--worker-x w)))
        (dotimes (_ 2) (cistern--do-tick st))
        (cl-assert (not (and (= (cistern--worker-x w) x0)
                             (= (cistern--worker-y w) 6)))
                   "worker stuck on hazard")))

    ;; --- two workers never share a tile
    (let ((a (nth 0 (cistern-st-creators st)))
          (b (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x a) 12) (setf (cistern--worker-y a) 5)
      (setf (cistern--worker-x b) 12) (setf (cistern--worker-y b) 7)
      (setf (cistern--worker-bladder a) 0)
      (setf (cistern--worker-bladder b) 0)
      (dotimes (_ 12) (cistern--do-tick st))
      (cl-assert (not (and (= (cistern--worker-x a) (cistern--worker-x b))
                           (= (cistern--worker-y a) (cistern--worker-y b))))
                 "workers stacked"))

    ;; --- determinism: same seed, same trajectory
    (let ((s1 (cistern--new-game 7)) (s2 (cistern--new-game 7)))
      (dotimes (_ 50) (cistern--do-tick s1) (cistern--do-tick s2))
      (cl-assert (= (cistern-st-alloy s1) (cistern-st-alloy s2)))
      (cl-assert (= (cistern-st-contam s1) (cistern-st-contam s2)))
      (cl-assert (equal (cistern-st-rng s1) (cistern-st-rng s2)))))

  (message "CISTERN-SELFTEST-OK"))

(defun cistern--soak-adj-floor (st)
  "Floor cells 4-adjacent to existing plumbing: building there
joins the network instantly."
  (let ((out nil))
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (when (and (eq (cistern--cell st x y) 'floor)
                   (cl-some (lambda (n)
                              (memq (cistern--cell st (car n) (cdr n))
                                    '(pipe toilet tank)))
                            (cistern--neighbors st x y)))
          (push (cons x y) out))))
    (nreverse out)))

(defun cistern--soak-pick-spot (st spots)
  "The connected spot closest to any worker — the bot grows the
network TOWARD the workforce instead of clustering it."
  (when spots
    (let* ((workers (mapcar (lambda (w)
                              (cons (cistern--worker-x w)
                                    (cistern--worker-y w)))
                            (cistern-st-creators st)))
           (hzs nil))
      (dotimes (y (cistern-st-h st))
        (dotimes (x (cistern-st-w st))
          (when (eq (cistern--cell st x y) 'hazard)
            (push (cons x y) hzs))))
      (setq spots (cl-remove-if
                   (lambda (p)
                     (cl-some (lambda (h)
                                (<= (max (abs (- (car p) (car h)))
                                        (abs (- (cdr p) (cdr h))))
                                    2))
                              hzs))
                   spots))
      (let (best bd)
        (dolist (s spots)
          (let ((d (cl-reduce #'min
                              (mapcar (lambda (w)
                                        (+ (abs (- (car s) (car w)))
                                           (abs (- (cdr s) (cdr w)))))
                                      workers))))
            (when (or (null bd) (< d bd))
              (setq bd d best s))))
        best))))

(defun cistern-run-soak ()
  "600 ticks with a deterministic auto-player.  Proves a competent
player survives: purge when tanks fill, build onto the existing
network when population demands it."
  (interactive)
  (let ((st (cistern--new-game 1)) (survived nil))
    (progn
      (dotimes (_ 600)
        (unless (cistern-st-over st)
          (let ((purged nil))
            (maphash (lambda (k v)
                       (when (and (not purged)
                                  (>= (plist-get v :load) 40))
                         (cistern--cmd-purge st (car k) (cdr k))
                         (setq purged t)))
                     (cistern-st-tanks st)))
          (let ((pop (length (cistern-st-creators st)))
                (spots (cistern--soak-adj-floor st))
                (hzs nil))
            (dotimes (y (cistern-st-h st))
              (dotimes (x (cistern-st-w st))
                (when (eq (cistern--cell st x y) 'hazard)
                  (push (cons x y) hzs))))
            (let ((spot (cistern--soak-pick-spot st spots)))
              ;; decon a hazard when the war chest allows
              (when (and hzs (>= (cistern-st-alloy st)
                                 (+ cistern-cost-decon 15)))
                (let ((h (car hzs)))
                  (cistern--cmd-decon st (car h) (cdr h))))
              (cond
               ((and (>= (cistern-st-alloy st) cistern-cost-tank)
                     (< (hash-table-count (cistern-st-tanks st))
                        (+ 1 (/ pop 3))))
                (when spot
                  (cistern--cmd-build st 'tank (car spot) (cdr spot))))
               ((and (>= (cistern-st-alloy st) cistern-cost-toilet)
                     (< (hash-table-count (cistern-st-toilets st))
                        (+ 1 (/ pop 2))))
                (when spot
                  (cistern--cmd-build st 'toilet (car spot) (cdr spot)))))
              ;; network extension: no spot near workers means lay pipe
              ;; toward them; pipes chain across rooms over time
              (when (and (>= (cistern-st-alloy st) cistern-cost-pipe)
                         (< (length spots) 4))
                (let ((spot (car spots)))
                  (when spot
                    (cistern--cmd-build st 'pipe (car spot) (cdr spot)))))))
          (cistern--do-tick st)))
      (setq survived (not (cistern-st-over st))))
    (unless survived
      (error "AUTO-PLAYER DIED at tick %d contam %d"
             (cistern-st-tick st) (cistern-st-contam st)))
    (message "CISTERN-SOAK-OK tick=%d contam=%d pop=%d alloy=%d"
             (cistern-st-tick st) (cistern-st-contam st)
             (length (cistern-st-creators st)) (cistern-st-alloy st))))

(provide 'cistern)
;;; cistern.el ends here
