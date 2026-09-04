;;; cistern-domain.el --- Pure sim core: tables, state, procgen, tick -*- lexical-binding: t; -*-

;; Domain layer (DESIGN-SPEC §3): no buffers, windows, faces, timers,
;; keymaps, or globals.  One state object threaded everywhere.

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; 1. Constants.  Ported verbatim from cistern.el:47-65.

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
;; 1b. Reference tile table — the SOLE source for glyph choice and
;; passability (R3b).  Exactly the legacy kinds; shape pinned in plan 01
;; §1.3.  :conn is data-only for now; per-connection-state glyph choices
;; are the Phase 3 view's job (R7).

(defconst cistern--tile-table
  '((floor  :glyph "·" :passable t   :buildable t   :firebreak nil :conn nil)
    (wall   :glyph "▓" :passable nil :buildable nil :firebreak t   :conn nil)
    (door   :glyph "+" :passable t   :buildable nil :firebreak t   :conn nil)
    (ore    :glyph "◆" :passable t   :buildable nil :firebreak t   :conn nil)
    (hazard :glyph "▒" :passable nil :buildable nil :firebreak nil :conn nil)
    (pipe   :glyph "·" :passable t   :buildable nil :firebreak t   :conn nil)
    (toilet :glyph "Ω" :passable nil :buildable nil :firebreak t   :conn nil)
    (tank   :glyph "▣" :passable nil :buildable nil :firebreak t   :conn nil))
  "One entry per cell kind.  No cell-kind pcase/case may exist
outside this table (the connection-dependent pipe glyph is computed
by the view, not here).")

(defun cistern--tile (kind) (cdr (assq kind cistern--tile-table)))

(defun cistern--tile-glyph (kind)
  "Glyph for KIND, resolved through the tile table."
  (plist-get (cistern--tile kind) :glyph))

(defun cistern--tile-passable-p (kind)
  "Passability for KIND, resolved through the tile table."
  (plist-get (cistern--tile kind) :passable))

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
  (armed-verb nil)           ; build verb armed for click-to-place (§3.4)
  (rng 1)                    ; LCG state; determinism lives here
  (purges 0) (built-pipe 0) (built-toilet 0) (built-tank 0) (earned 0) (migrants 0)
  (tutorial 0)               ; index into tutorial steps; t when done
  score objectives unlocks)  ; rewards-owned; shape DEFERRED to REWARDS-DESIGN

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
;; 3. Grid primitives.  Ported verbatim from cistern.el:104-119.

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
;; 4. Procgen — seed-driven map generation (replaces the hardcoded
;; cistern--build-map, cistern.el:200-231).  Same seed ⇒ same map.

(defconst cistern--procgen-spawns '((12 6) (14 7) (11 9) (15 6)))

(defun cistern--procgen-reserved-p (x y)
  "Cells procgen must never overwrite: the four worker spawn
cells and the starter plumbing chain."
  (or (member (list x y) cistern--procgen-spawns)
      (member (list x y) '((3 2) (4 2) (5 2) (3 3)))))

(defun cistern--procgen-place (st x y kind)
  "Table-validated placement of KIND at (X,Y): allowed only
in-bounds, not on a reserved cell, and where the current cell's
table entry says :buildable."
  (when (and (cistern--in-bounds-p st x y)
             (not (cistern--procgen-reserved-p x y))
             (plist-get (cistern--tile (cistern--cell st x y)) :buildable))
    (cistern--set-cell st x y kind)
    t))

(defun cistern--gen-map (st seed)
  "Fill ST with a seed-generated sector.  Same SEED ⇒ same map,
plumbing hashes, and LCG residue."
  (setf (cistern-st-map st)
        (make-vector (* (cistern-st-w st) (cistern-st-h st)) 'floor))
  (setf (cistern-st-toilets st) (make-hash-table :test #'equal))
  (setf (cistern-st-tanks st) (make-hash-table :test #'equal))
  (setf (cistern-st-rng st) seed)
  ;; outer walls
  (dotimes (y (cistern-st-h st))
    (dotimes (x (cistern-st-w st))
      (when (or (= x 0) (= x (1- (cistern-st-w st)))
                (= y 0) (= y (1- (cistern-st-h st))))
        (cistern--set-cell st x y 'wall))))
  ;; west migrant gate
  (cistern--set-cell st 0 7 'door)
  ;; seed-driven spine wall, full height, random doors
  (let* ((sx (+ 9 (cistern--rand st (- (- cistern-w 2) 9))))
         (door1 (+ 2 (cistern--rand st (- cistern-h 4))))
         (door2 (+ 2 (cistern--rand st (- cistern-h 4)))))
    (cl-loop for y from 1 to (- cistern-h 2)
             do (cistern--procgen-place st sx y 'wall))
    (unless (cistern--procgen-reserved-p sx door1)
      (cistern--set-cell st sx door1 'door))
    (unless (cistern--procgen-reserved-p sx door2)
      (cistern--set-cell st sx door2 'door)))
  ;; seed-driven cross wall y, spanning x=14..24, random door
  (let* ((cy (+ 3 (cistern--rand st (- cistern-h 6))))
         (cdoor (+ 15 (cistern--rand st 9))))
    (cl-loop for x from 14 to 24 do (cistern--procgen-place st x cy 'wall))
    (unless (cistern--procgen-reserved-p cdoor cy)
      (cistern--set-cell st cdoor cy 'door)))
  ;; seed-driven ore veins
  (let ((n (+ 2 (cistern--rand st 3))))
    (dotimes (_ n)
      (let ((x (+ 2 (cistern--rand st (- cistern-w 4))))
            (y (+ 2 (cistern--rand st (- cistern-h 4)))))
        (cistern--procgen-place st x y 'ore))))
  ;; starter plumbing: tank (5,2) - pipe (4,2) - pipe (3,2) - toilet (3,3)
  (cistern--set-cell st 5 2 'tank)
  (cistern--set-cell st 4 2 'pipe)
  (cistern--set-cell st 3 2 'pipe)
  (cistern--set-cell st 3 3 'toilet)
  (puthash (cons 3 3) (list :busy nil) (cistern-st-toilets st))
  (puthash (cons 5 2) (list :load 30) (cistern-st-tanks st)))

;; ---------------------------------------------------------------------------
;; 4c. Connection logic — ONE flood primitive serves pathing and
;; connectivity (minimal port of cistern.el:124-195 needed by the
;; integrity test; the movement half arrives with the tick phases).

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

(defun cistern--walkable-p (st x y tx ty)
  "Is (X,Y) enterable by a worker walking to target (TX,TY)?
Table-passable cells always.  A toilet only when it is the target:
entering a toilet IS seating yourself.  Toilets are rooms, not floors."
  (let ((kind (cistern--cell st x y)))
    (or (cistern--tile-passable-p kind)
        (and (eq kind 'toilet) (= x tx) (= y ty)))))

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

;; ---------------------------------------------------------------------------
;; 5. Worker lifecycle (cistern.el:236-258).

(defun cistern--worker-glyph (st w)
  (let ((i (or (cl-position w (cistern-st-creators st) :test #'eq) 0)))
    (aref cistern--worker-glyphs (mod i (length cistern--worker-glyphs)))))

(defun cistern--spawn-worker (st x y)
  (let ((w (cistern--worker-make :x x :y y :bladder 20)))
    (setf (cistern-st-creators st)
          (append (cistern-st-creators st) (list w)))
    (setf (cistern-st-migrants st) (1+ (cistern-st-migrants st)))
    w))

;; ---------------------------------------------------------------------------
;; 6. Simulation behavior — seek/step/shuffle and the four phases
;; (cistern.el:262-493; tutorial hook moved to the game layer, Phase 2).

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
                (or (not (cistern--tile-passable-p
                          (cistern--cell st (car n) (cdr n))))
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

(defun cistern--sim-tick (st)
  "One full simulation tick: creators, hazards, migration, check.
Exactly the four domain phases; the tutorial hook is added by the
game layer (Phase 2)."
  (setf (cistern-st-tick st) (1+ (cistern-st-tick st)))
  (cistern--phase-creators st)
  (cistern--phase-hazards st)
  (cistern--phase-migration st)
  (cistern--phase-check st))

(defun cistern--new-game (&optional seed)
  "Build fresh state.  SEED (integer) makes the run reproducible."
  (let ((st (make-cistern-st)))
    (cistern--gen-map st (or seed 20260830))
    (dolist (p cistern--procgen-spawns)
      (let ((w (cistern--worker-make :x (nth 0 p) :y (nth 1 p))))
        (setf (cistern-st-creators st) (append (cistern-st-creators st)
                                               (list w)))))
    (setf (cistern-st-migrants st) 0)
    (cistern--log st "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
    st))

(provide 'cistern-domain)
;;; cistern-domain.el ends here
