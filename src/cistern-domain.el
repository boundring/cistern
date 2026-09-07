;;; cistern-domain.el --- Pure sim core: tables, state, procgen, tick -*- lexical-binding: t; -*-

;; Domain layer (DESIGN-SPEC §3): no buffers, windows, faces, timers,
;; keymaps, or globals.  One state object threaded everywhere.

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; 1. Constants.  Ported verbatim from cistern.el:47-65.

(defconst cistern-w 34 "Sector width.")
(defconst cistern-h 16 "Sector height.")
(defconst cistern-version "3.0.0-dev"
  "CISTERN version.  Lives in the domain constants block so both
the view header and the driver help read it inward.")
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
    (pipe   :glyph "·" :dead-glyph "╌"
            :passable t   :buildable nil :firebreak t   :conn nil)
    (toilet :glyph "Ω" :passable nil :buildable nil :firebreak t   :conn nil)
    (tank   :glyph "▣" :passable nil :buildable nil :firebreak t   :conn nil))
  "One entry per cell kind.  No cell-kind pcase/case may exist
outside this table (the connection-dependent pipe glyph is computed
by the view, not here).")

(defun cistern--tile (kind) (cdr (assq kind cistern--tile-table)))

(defun cistern--tile-glyph (kind)
  "Glyph for KIND, resolved through the tile table."
  (plist-get (cistern--tile kind) :glyph))

(defun cistern--tile-dead-glyph (kind)
  "Glyph for an UNCONNECTED KIND (Q12) — the table's
:dead-glyph when it has one, the base glyph otherwise."
  (or (plist-get (cistern--tile kind) :dead-glyph)
      (cistern--tile-glyph kind)))

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
  (hint nil)                 ; Q17: one-tick transient cursor hint — posted
                             ; by use-cases, read by the view, drained once
  (seed 0)                   ; the game seed; child streams derive from it (REWARDS-DESIGN §4)
  (rng 1)                    ; LCG state; determinism lives here
  (purges 0) (built-pipe 0) (built-toilet 0) (built-tank 0) (earned 0) (migrants 0)
  (tutorial 0)               ; index into tutorial steps; t when done
  score objectives unlocks   ; rewards-owned; shape DEFERRED to REWARDS-DESIGN
  (rewards-events nil)       ; events emitted since the last rewards-eval read (§5)
  (particle-rng 0)           ; the particle field's child-stream position (§4 ParticleField.rng)
  (goal-card nil)            ; active goal card (§5): (:map-id :tier :goals :completed)
  (reputation 0)             ; 0-100 clamped; M4 deltas: +1 relief −5 burst −2 leak
  (rewards-outcome nil)      ; stored per-tick (outcome . intents) 2-list; the view reads it
  (particles nil)            ; the particle field (§4): newest-first plist list, K=64 FIFO cap
  (relieves 0)               ; cumulative relieves counter (M8 ladder; approval L-031)
  (trophies nil)             ; completed map seeds, committed at trigger time (M9; §5 ledger 2)
  (summary nil)              ; Q22: run-summary snapshot, banked at condemnation
  (auto-run nil)             ; Q29: badge mirror — the timer HANDLE never
                             ; enters state (D2); this is its on/off echo
  (built-at nil))            ; Q30: hash (X . Y) -> tick-of-build, for the
                             ; same-tick regret window

(defun cistern--rand (st n)
  "Advance ST's LCG, return a value in [0,N).  Deterministic."
  (let ((x (cistern-st-rng st)))
    (setq x (mod (+ (* x 1103515245) 12345) 2147483648))
    (setf (cistern-st-rng st) x)
    (mod x n)))

;; 2b. Child streams (REWARDS-DESIGN §4): reward garnish draws from
;; seed⊕stream-id child streams, NEVER the sim LCG — sim outcomes and
;; particle outcomes must not consume each other's randomness.  Both
;; functions are pure: an explicit position in, an explicit position
;; out; no state, no emacs-runtime calls.
(defun cistern--stream-init (seed stream-id)
  "Child-stream initial position: SEED ⊕ STREAM-ID (REWARDS-DESIGN
§4).  STREAM-ID 0 is reserved — it would reproduce the sim LCG's
own sequence."
  (logxor seed stream-id))

(defun cistern--stream-next (pos)
  "One raw child-stream step from POS: the domain LCG recurrence.
Returns the new 31-bit position; call sites mod-scope it at use.
Pure — never touches cistern-st-rng."
  (mod (+ (* pos 1103515245) 12345) 2147483648))

(defun cistern--log (st fmt &rest args)
  "Append a plain line.  Q13: entries are (LINE . SEVERITY-ENUM),
so color persists with the text; nil severity renders dim.  Q16:
the log is UNCAPPED — tail clipping is the view's concern."
  (push (cons (apply #'format fmt args) nil) (cistern-st-log st)))

(defun cistern--log-sev (st sev fmt &rest args)
  "Append a line carrying SEVERITY-ENUM (Q13): info = minor,
error = major — the view maps the enum through its palette."
  (push (cons (apply #'format fmt args) sev) (cistern-st-log st)))

;; Q14: the ONE worker-identity table + helper, hosted in the
;; domain (innermost layer) so the accident log, the map and the
;; inspector all read the same source — superseding L-012's
;; view-only placement, per the TOP-30 binding directive.
(defconst cistern--worker-glyphs ["α" "β" "γ" "δ" "ε" "ζ" "η" "θ"]
  "Worker identity glyphs indexed by the worker's stable position
in the creators list.")

(defun cistern--worker-glyph (st w)
  "Identity glyph for worker W from its stable creators-list
index.  The map, the inspector and the accident log all name the
worker by this glyph (Q14: no format drift, no off-by-one)."
  (let ((i (or (cl-position w (cistern-st-creators st) :test #'eq) 0)))
    (aref cistern--worker-glyphs
          (mod i (length cistern--worker-glyphs)))))

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
  (setf (cistern-st-seed st) seed)
  (setf (cistern-st-rng st) seed)
  ;; the particle field's child stream: seed ⊕ stream-id 1 (§4);
  ;; stream-id 0 is reserved (it would clone the sim LCG sequence)
  (setf (cistern-st-particle-rng st) (cistern--stream-init seed 1))
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

;; View-facing query functions (D6): the projection reads connection
;; and load state ONLY through these enum/number queries — never via
;; direct hash access (plan 02 §2 view item; L-016).

(defun cistern--toilet-state (st x y)
  "Connection state of the toilet at (X,Y): `busy', `usable', or
`down' (severed, backed up, or full tanks)."
  (let ((entry (gethash (cons x y) (cistern-st-toilets st))))
    (cond ((not entry) 'down)
          ((plist-get entry :busy) 'busy)
          ((cistern--toilet-usable-p st x y) 'usable)
          (t 'down))))

(defun cistern--tank-load (st x y)
  "Stored waste in the tank at (X,Y), or nil when absent."
  (let ((tp (gethash (cons x y) (cistern-st-tanks st))))
    (when tp (plist-get tp :load))))

(defun cistern--tank-load-total (st)
  "Total stored waste across all tanks."
  (let ((total 0))
    (maphash (lambda (_k v) (setq total (+ total (plist-get v :load))))
             (cistern-st-tanks st))
    total))

(defun cistern--tank-capacity-total (st)
  "Total tank capacity across all placed tanks (Q08)."
  (* (hash-table-count (cistern-st-tanks st)) cistern-tank-cap))

(defun cistern--tank-load-max (st)
  "Highest single-tank load (Q08: the pressure source the RISING
% names)."
  (let ((maxload 0))
    (maphash (lambda (_k v)
               (setq maxload (max maxload (plist-get v :load))))
             (cistern-st-tanks st))
    maxload))

(defun cistern--toilets-backed-up-p (st)
  "Q09 split, backed-up half: a placed toilet is out of service
with a live path whose tanks are OVER CAPACITY (full to the cap).
The near-full but not-full band stays with Q08's RISING — the
line anticipates instead of lying."
  (let ((backed nil))
    (maphash (lambda (k _v)
               (when (and (eq (cistern--toilet-state st (car k) (cdr k)) 'down)
                          (cl-some (lambda (tk)
                                     (>= (plist-get (gethash tk
                                                          (cistern-st-tanks st))
                                                    :load)
                                         cistern-tank-cap))
                                   (cistern--connected-tanks st (car k) (cdr k))))
                 (setq backed t)))
             (cistern-st-toilets st))
    backed))

(defun cistern--toilets-severed-p (st)
  "Q09 split, severed half: a placed toilet is out of service
with NO tank reachable through its plumbing (the path is cut).
Both halves replace the collapsed legacy backed-p."
  (let ((severed nil))
    (maphash (lambda (k _v)
               (when (and (eq (cistern--toilet-state st (car k) (cdr k)) 'down)
                          (null (cistern--connected-tanks st (car k) (cdr k))))
                 (setq severed t)))
             (cistern-st-toilets st))
    severed))

(defun cistern--nearest-tank (st x y)
  "Coordinate of the tank nearest to (X,Y) by flood-fill distance
over walkable plumbing space; nil when no tank exists (Q10: the
flood-fill data already exists — this reads it)."
  (let ((dist (cistern--flood st x y
                              (lambda (px py)
                                (memq (cistern--cell st px py)
                                      '(floor pipe tank)))))
        (best nil) (bd nil))
    (maphash (lambda (k _v)
               (let ((d (gethash k dist)))
                 (when (and d (or (null bd) (< d bd)))
                   (setq bd d best k))))
             (cistern-st-tanks st))
    best))

(defun cistern--severed-remedy (st)
  "For the first severed toilet (coordinate order — deterministic),
the nearest tank coordinate to wire toward; nil otherwise (Q10)."
  (let ((severed nil))
    (maphash (lambda (k _v)
               (when (and (eq (cistern--toilet-state st (car k) (cdr k)) 'down)
                          (null (cistern--connected-tanks st (car k) (cdr k))))
                 (push k severed)))
             (cistern-st-toilets st))
    (when severed
      (setq severed (sort severed (lambda (a b) (< (car a) (car b)))))
      (cistern--nearest-tank st (car (car severed)) (cdr (car severed))))))

(defun cistern--nearest-structure (st kind x y)
  "Nearest placed structure of KIND (toilet/tank) to (X,Y) by
manhattan distance; ties broken in coordinate order (deterministic).
Q20: the inspector's bearing reads the shared geometry here."
  (let ((cands nil))
    (maphash (lambda (k _v)
               (push (list (+ (abs (- (car k) x)) (abs (- (cdr k) y)))
                           (car k) (cdr k))
                     cands))
             (if (eq kind 'toilet)
                 (cistern-st-toilets st) (cistern-st-tanks st)))
    (let ((sorted (sort cands
                        (lambda (a b)
                          (or (< (car a) (car b))
                              (and (= (car a) (car b))
                                   (or (< (cadr a) (cadr b))
                                       (and (= (cadr a) (cadr b))
                                            (< (caddr a) (caddr b))))))))))
      (when sorted
        (cons (nth 1 (car sorted)) (nth 2 (car sorted)))))))

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
  (let* ((bladder (cistern--worker-bladder w)) ; urgency at relief (M5 payload)
         (tp (cistern--worker-toilet w))
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
            (let ((line (format "SEVERED LINE AT (%d,%d) — WASTE SPILLED" x y)))
              (cistern--log-sev st 'error "%s" line)
              (push (list 'leak line) (cistern-st-rewards-events st)))) ; leak (M4)
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
                  (cistern-st-tanks st))
          (push (list 'relief bladder x y)
                (cistern-st-rewards-events st))
          (cistern--log-sev st 'info "CREATOR RELIEVED AT (%d,%d)" x y))))))

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
    ;; Q14: the log names the worker's identity glyph — the same one
    ;; the map renders at this cell (one helper, one source)
    (let ((line (format "BREACH — CREATOR %s OVERFLOWED AT (%d,%d)"
                        (cistern--worker-glyph st w) x y)))
      (cistern--log-sev st 'error "%s" line)
      ;; breach (M4): payload carries the logged line for the M7
      ;; faced log intent
      (push (list 'burst line) (cistern-st-rewards-events st)))))

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
    (cistern--log-sev st 'error "%s" (cistern-st-over st))
    ;; Q22: bank the run summary AT TRIGGER TIME — commit-first, the
    ;; death panel (Q23) only ever reads it
    (setf (cistern-st-summary st)
          (list :ticks (cistern-st-tick st)
                :relieves (cistern-st-relieves st)
                :score (or (cistern-st-score st) 0)
                :trophies (cistern-st-trophies st)
                :cause (cistern-st-over st)))))

;; 6b. Particle field (REWARDS-DESIGN §4): domain-owned, seeded,
;; pure.  The field is a newest-first list of particle plists
;; (:pos (X . Y) :vel (DX . DY) :ttl N :glyph S :face ENUM :layer ENUM).
;; K = 64, oldest evicted FIFO at spawn; ttl −= 1 per advance,
;; removed at 0.

(defconst cistern--field-cap 64 "Max live particles (§4).")

(defun cistern--field-spawn (st pos vel ttl glyph face layer)
  "Spawn one particle into ST's field.  Vel is (DX . DY), each
component −1/0/+1; TTL counts down per advance.  FIFO eviction at
the K=64 cap, oldest first."
  (push (list :pos pos :vel vel :ttl ttl
              :glyph glyph :face face :layer layer)
        (cistern-st-particles st))
  (when (> (length (cistern-st-particles st)) cistern--field-cap)
    (setf (cistern-st-particles st)
          (cl-subseq (cistern-st-particles st) 0 cistern--field-cap))))

(defun cistern--advance-particles (st)
  "One particle advance (§4): pos += vel, ttl −= 1, removal at 0.
Pure field mechanics — sim counters are untouched.  Invalid field
state (ttl < 0, |vel| > 1) raises: fail-first, no silent
corruption."
  (let ((alive nil))
    (dolist (p (cistern-st-particles st))
      (let* ((vel (plist-get p :vel))
             (dx (car vel)) (dy (cdr vel))
             (pos (plist-get p :pos))
             (ttl (1- (plist-get p :ttl))))
        (when (or (< ttl 0) (> (abs dx) 1) (> (abs dy) 1))
          (error "INVALID PARTICLE STATE — ttl %S vel %S" ttl vel))
        (when (> ttl 0)
          (push (plist-put (plist-put p :ttl ttl)
                           :pos (cons (+ (car pos) dx)
                                      (+ (cdr pos) dy)))
                alive))))
    (setf (cistern-st-particles st) (nreverse alive))))

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
    (setf (cistern-st-built-at st) (make-hash-table :test #'equal))
    ;; Q03 (REWARDS-DESIGN §1): the starter card is dealt from tick
    ;; one — serve 3, ceiling 5 — so the whole goal loop is live
    ;; without test injection.  One call, via the existing setter.
    (cistern--cmd-set-goal-card st cistern--starter-card)
    (cistern--log st "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
    st))

;; Q03 layer note (ledger L-036): the directive pins the call to
;; cistern-game.el, but `cistern--new-game' lives here in the
;; innermost layer — a game-layer call would either run after
;; construction (not one call) or invert the domain→game require
;; edge.  The pure card setter + kind table therefore relocated here
;; unchanged; every caller keeps the same symbol.

(defconst cistern--goal-kinds
  '(relieves-served bursts-allowed contamination-ceiling)
  "Goal kinds per REWARDS-DESIGN §5.")

(defconst cistern--starter-card
  '(:tier 2 :goals ((:kind relieves-served :target 3)
                    (:kind contamination-ceiling :target 5)))
  "The starter goal card (Q03): serve 3, ceiling 5, tier 2
\(standard) — dealt to every new game from tick one.")

;; Q11 PROTECT copy table: ALL new user-facing strings land here —
;; one table, one place for the docs pass to review.  Blame!
;; register — terse, institutional, deadpan.  The idle pressure line
;; is pre-existing view copy and stays byte-identical in
;; cistern-view.el.
(defconst cistern--copy
  '((milestone . ((big-cistern . "BIG CISTERN ONLINE")
                  (fast-flush . "FAST FLUSH ONLINE")
                  (self-clean . "SELF-CLEAN ONLINE")
                  (air-freshener . "AIR FRESHENER ONLINE")
                  (golden-pipe . "GOLDEN PIPE ONLINE")))
    (pressure-rising . "PRESSURE RISING — TANK %d%%")
    (pressure-severed . "LINES SEVERED — REWIRE (p) — TANK AT (%d,%d)")
    (pressure-severed-bare . "LINES SEVERED — REWIRE (p)")
    (refusal-no-floor . "NO FLOOR THERE — AIM FOR OPEN FLOOR")
    (refusal-alloy . "NEED %d ALLOY — PURGE (x) PAYS")
    (badge-armed . "  ARMED: %s — CLICK PLACES, ESC CANCELS")
    (badge-auto . "  AUTO-RUN")
    (help-arm . "t/p/K arm — click to place")
    (bearing-floor . "FLOOR — %s")
    (death-panel . "%s / TICKS %d · RELIEVES %d · SCORE %d / PRESS n TO RESTART")
    (goal-met-served . "GOAL MET — %d SERVED")
    (goal-met-bursts . "GOAL MET — %d BURSTS HELD")
    (goal-met-ceiling . "GOAL MET — CONTAM UNDER %d")
    (tutorial-1 . "MOVE THE CURSOR ONTO A WORKER")
    (tutorial-2 . "PURGE A FILLING TANK (x)")
    (tutorial-3 . "THE PURGE PAYS — ALLOY IN THE BANK"))
  "Q11 copy table, keyed by surface (Q05/Q08/Q10 milestones and
pressure lines so far).")

(defun cistern--cmd-set-goal-card (st card)
  "Set ST's active goal card (M3).  Validates the §5 shape — max 3
goals, known kinds — and stamps :map-id from the game seed (the
seed doubles as map_id, L-025 ruling).  An invalid card is an
error: fail-first, no silent rejection."
  (let ((goals (plist-get card :goals)))
    (if (> (length goals) 3)
        (error "GOAL CARD REJECTED — MAX 3 GOALS"))
    (dolist (g goals)
      (unless (memq (plist-get g :kind) cistern--goal-kinds)
        (error "GOAL CARD REJECTED — UNKNOWN KIND %S" (plist-get g :kind))))
    ;; deep-copy the goals: the evaluator writes :satisfied back into
    ;; each goal plist, and a shallow copy would share them with the
    ;; caller's (often literal) card — state from two games would
    ;; alias one card object (broke 4a replay identity).
    (setf (cistern-st-goal-card st)
          (plist-put (plist-put (copy-sequence card)
                                :goals (mapcar #'copy-sequence goals))
                     :map-id (cistern-st-seed st)))))

(provide 'cistern-domain)
;;; cistern-domain.el ends here
