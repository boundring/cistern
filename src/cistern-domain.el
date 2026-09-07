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

(defconst cistern-cost-clear 2
  "V4-05 (S3.2): alloy cost of `d' on a rubble cell — the same
demolish verb, a lighter fee than plumbing removal.")
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
    (tank   :glyph "▣" :passable nil :buildable nil :firebreak t   :conn nil)
    ;; V4-05 (SURFACE S3.2 — all three glyphs inside the L-076
    ;; pin-covered ranges: U+259A, U+2591, U+256C)
    (rubble   :glyph "▚" :passable nil :buildable nil :firebreak t   :conn nil)
    (flood    :glyph "░" :passable nil :buildable nil :firebreak nil :conn nil)
    (manifold :glyph "╬" :passable nil :buildable nil :firebreak t   :conn nil))
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
  x y (bladder 20) (sick 0) (mine 0) (use-t 0) (using nil) (toilet nil)
  ;; V4-10 (RPG §1): the maintenance dossier — (FLOW GRIT NERVE
  ;; ARCHIVE) scores 3-18, XP ledger, clearance level 1..3
  (stats nil) (xp 0) (clearance 1) (journey nil))

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
  (rpg-pos 0)                ; V4-10: RPG child-stream position (seed ⊕ 3) —
                             ; pos-in/pos-out like particle-rng, NEVER the sim LCG
  (goal-card nil)            ; active goal card (§5): (:map-id :tier :goals :completed)
  (reputation 0)             ; 0-100 clamped; M4 deltas: +1 relief −5 burst −2 leak
  (rewards-outcome nil)      ; stored per-tick (outcome . intents) 2-list; the view reads it
  (particles nil)            ; the particle field (§4): newest-first plist list, K=64 FIFO cap
  (relieves 0)               ; cumulative relieves counter (M8 ladder; approval L-031)
  (trophies nil)             ; completed map seeds, committed at trigger time (M9; §5 ledger 2)
  (summary nil)              ; Q22: run-summary snapshot, banked at condemnation
  (auto-run nil)             ; Q29: badge mirror — the timer HANDLE never
                             ; enters state (D2); this is its on/off echo
  (built-at nil)             ; Q30: hash (X . Y) -> tick-of-build, for the
                             ; same-tick regret window
  ;; V4-11 (RPG §2): the armed fixture type — `T` cycles it in
  ;; catalog order
  (toilet-type 'long-drop))

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

;; ---------------------------------------------------------------------------
;; V4-10 (RPG §1/§3.1): worker stat blocks from child stream 3.
;; Draw procedure pinned for BOTH docs (STORY §6.3): the glibc LCG
;; recurrence, sliced at bit 6 — the low bits cycle (RPG §3.2).

(defconst cistern--rpg-stat-names '(FLOW GRIT NERVE ARCHIVE))

(defun cistern--rpg-advance (pos)
  (% (+ (* pos 1103515245) 12345) 2147483648))

(defun cistern--rpg-d6-pos (pos)
  (let ((p (cistern--rpg-advance pos)))
    (cons (1+ (% (ash p -6) 6)) p)))

(defun cistern--rpg-d20-pos (pos)
  (let ((p (cistern--rpg-advance pos)))
    (cons (1+ (% (ash p -6) 20)) p)))

(defun cistern--rpg-d6 (st)
  "Stateful stream-3 d6 draw (pos-in/pos-out on `cistern-st-rpg-pos')."
  (let ((r (cistern--rpg-d6-pos (cistern-st-rpg-pos st))))
    (setf (cistern-st-rpg-pos st) (cdr r))
    (car r)))

(defun cistern--rpg-d20 (st)
  "Stateful stream-3 d20 draw (pos-in/pos-out on `cistern-st-rpg-pos')."
  (let ((r (cistern--rpg-d20-pos (cistern-st-rpg-pos st))))
    (setf (cistern-st-rpg-pos st) (cdr r))
    (car r)))

(defun cistern--rpg-mod (score)
  "D&D-standard modifier: floor((score − 10) / 2), −4..+4."
  (floor (- score 10) 2))

(defun cistern--rpg-roll-stat (st)
  "4d6 drop lowest, summed — one stat score (3-18)."
  (let ((rolls (sort (list (cistern--rpg-d6 st) (cistern--rpg-d6 st)
                           (cistern--rpg-d6 st) (cistern--rpg-d6 st))
                     #'<)))
    (+ (nth 1 rolls) (nth 2 rolls) (nth 3 rolls))))

(defun cistern--rpg-roll-stats (st)
  "Roll the four stat scores in fixed order FLOW, GRIT, NERVE,
ARCHIVE, consuming stream 3 sequentially."
  (list (cistern--rpg-roll-stat st) (cistern--rpg-roll-stat st)
        (cistern--rpg-roll-stat st) (cistern--rpg-roll-stat st)))

(defun cistern--rpg-seek-eff (nerve-mod)
  "NERVE coupling (§1): seek threshold clamp(60 − 5·mod, 50, 68).
High NERVE files the relief request BEFORE the spike."
  (clamp 50 (- 60 (* 5 nerve-mod)) 68))

(defun cistern--rpg-sick-duration (grit-mod)
  "GRIT coupling (§1): sickness clamp(30 − 4·mod, 18, 42) ticks."
  (clamp 18 (- 30 (* 4 grit-mod)) 42))

(defun cistern--rpg-mine-rate (flow-mod)
  "FLOW coupling (§1): healthy ore-ticks per alloy
clamp(3 − mod, 2, 6); sick workers take twice as many (§1)."
  (clamp 2 (- 3 flow-mod) 6))

(defun clamp (lo v hi)
  "V4-10 helper: clamp V into [LO, HI]."
  (min hi (max lo v)))

;; ---------------------------------------------------------------------------
;; V4-11 (RPG §2): the fixture catalog — sole source for cost, ticks,
;; suits and placement of every toilet type.  Differentiators are
;; numbers, suits, placement, cost; no special-case behavior.

(defconst cistern--toilet-catalog
  '((long-drop      :glyph "t" :cost 10 :ticks 2 :load 10
      :primary GRIT :secondary FLOW :placement any)
    (fall-shaft     :glyph "u" :cost 8  :ticks 2 :load 8
      :primary FLOW :secondary GRIT :placement no-adjacent-toilet
      :place-fail "SHAFT CLEARANCE")
    (high-cistern   :glyph "¶" :cost 14 :ticks 1 :load 10
      :primary ARCHIVE :secondary NERVE :placement wall-adjacent
      :place-fail "NEEDS A WALL")
    (archive-stall  :glyph "¤" :cost 12 :ticks 3 :load 12
      :primary NERVE :secondary ARCHIVE :placement wall-adjacent
      :place-fail "NEEDS A WALL")
    (hermetic-booth :glyph "Ω" :cost 20 :ticks 2 :load 10
      :primary NERVE :secondary GRIT :placement any))
  "One entry per fixture type, keyed by type id (RPG §2).")

(defun cistern--toilet-type-entry (type)
  (cdr (assq type cistern--toilet-catalog)))

(defun cistern--toilet-type-next (type)
  "The catalog entry after TYPE, wrapping."
  (let ((ids (mapcar #'car cistern--toilet-catalog))
        (pos (cl-position type (mapcar #'car cistern--toilet-catalog))))
    (nth (% (1+ pos) (length ids)) ids)))

(defun cistern--toilet-place-verdict (st x y type)
  "t when TYPE may be placed at (X,Y), else the verdict text
(rendered through the copy-table refusal line, R7 style)."
  (let ((rule (plist-get (cistern--toilet-type-entry type) :placement)))
    (cond
     ((eq rule 'any) t)
     ((eq rule 'no-adjacent-toilet)
      (if (cl-some (lambda (n) (eq (cistern--cell st (car n) (cdr n)) 'toilet))
                   (cistern--neighbors st x y))
          (plist-get (cistern--toilet-type-entry type) :place-fail)
        t))
     ((eq rule 'wall-adjacent)
      (if (cl-some (lambda (n) (eq (cistern--cell st (car n) (cdr n)) 'wall))
                   (cistern--neighbors st x y))
          t
        (plist-get (cistern--toilet-type-entry type) :place-fail))))))

;; ---------------------------------------------------------------------------
;; V4-12 (RPG §3/§4): checks, matrices, XP/clearance.  All rolls are
;; pos-in/pos-out on stream 3 — the sim LCG and particle stream are
;; never touched (A10).

(defconst cistern--rpg-const
  '((exposure-dc . 12) (composure-dc . 10) (stride-dc . 16))
  "RPG §3.5: DCs live in one block beside the catalog.")

(defconst cistern--matrix-hash
  (let ((h (make-hash-table :test #'equal)))
    (dolist (m '((exposure-grit . ((:sick 5) (:sick 0) (:sick 0) (:sick 0 :xp 1)))
                 (composure-nerve . ((:spike 10) (:spike 5) (:spike 0)
                                     (:spike 0 :xp 1)))))
      (let ((i 0))
        (dolist (b (cdr m))
          (puthash (cons (car m) i) b h)
          (setq i (1+ i)))))
    h)
  "Shared (MATRIX-ID . BAND 0..3) → effect plist (§1.3 ruling 5;
the story engine folds its matrices into this same hash in
V4-19).")

(defun cistern--matrix-effect (matrix-id band)
  "Resolve (MATRIX-ID . BAND); an unknown matrix-id errors
fail-first (A9)."
  (or (gethash (cons matrix-id band) cistern--matrix-hash)
      (error "UNKNOWN MATRIX %S" matrix-id)))

(defun cistern--rpg-band (st dc mod)
  "One d20 check band (RPG §3.3): stat = clamp(mod, −2, +2),
D&D banding, nat-20 promotes to band 3 / nat-1 demotes to band 0."
  (let* ((r (cistern--rpg-d20-pos (cistern-st-rpg-pos st)))
         (roll (car r))
         (margin (+ roll (clamp -2 mod 2) (- dc)))
         (band (cond ((<= margin -5) 0) ((<= margin -1) 1)
                     ((<= margin 4) 2) (t 3))))
    (setf (cistern-st-rpg-pos st) (cdr r))
    (cond ((= roll 20) 3) ((= roll 1) 0) (t band))))

(defun cistern--rpg-check (st matrix-id dc mod)
  "Full matrix check: (BAND . EFFECT-PLIST) — one d20, then the
shared hash lookup (no runtime hashing)."
  (let ((band (cistern--rpg-band st dc mod)))
    (cons band (cistern--matrix-effect matrix-id band))))

(defun cistern--rpg-stat-mod (w idx)
  (cistern--rpg-mod (nth idx (cistern--worker-stats w))))

(defun cistern--rpg-dominant (w)
  "Index of the highest stat score; ties break in fixed
FLOW, GRIT, NERVE, ARCHIVE order (§2.1)."
  (let ((stats (cistern--worker-stats w)) (best 0))
    (dotimes (i 4)
      (when (> (nth i stats) (nth best stats)) (setq best i)))
    best))

(defun cistern--rpg-suit (w type)
  "SUITED/NEUTRAL/UNSUITED for W on TYPE (§2.1).  CL.II
cross-cert: never unsuited again (worst case neutral)."
  (let* ((entry (cistern--toilet-type-entry type))
         (dom (cistern--rpg-dominant w))
         (pri (cl-position (plist-get entry :primary)
                           cistern--rpg-stat-names))
         (sec (cl-position (plist-get entry :secondary)
                           cistern--rpg-stat-names))
         (suit (cond ((= dom pri) 'suited)
                     ((= dom sec) 'neutral)
                     (t 'unsuited))))
    (if (and (eq suit 'unsuited) (>= (cistern--worker-clearance w) 2))
        'neutral
      suit)))

(defun cistern--rpg-use-ticks (w type)
  "§2.2: clamp(type-ticks − 1·suited + 1·unsuited, 1, 4)."
  (let ((base (plist-get (cistern--toilet-type-entry type) :ticks))
        (suit (cistern--rpg-suit w type)))
    (clamp 1 (+ base (pcase suit ('suited -1) ('unsuited 1) (_ 0))) 4)))

(defun cistern--rpg-grant-xp (st w n)
  "Add N XP and apply clearance unlocks (§4): CL.II at 12,
CL.III at 30 (+2 to the lowest stat, fixed F/G/N/A order).
Clearance-up logs one line; the popup rides the rewards stream
(S3, at the act)."
  (let* ((old (cistern--worker-clearance w))
         (xp (+ (cistern--worker-xp w) n))
         (new (cond ((>= xp 30) 3) ((>= xp 12) 2) (t 1))))
    (setf (cistern--worker-xp w) xp)
    (when (> new old)
      (setf (cistern--worker-clearance w) new)
      (cistern--log-sev st 'success "%s"
                        (format (cdr (assq (if (= new 3)
                                               'clearance-up-3
                                             'clearance-up)
                                           cistern--copy))
                                (cistern--worker-glyph st w)))
      (push (list 'clearance (cistern--worker-glyph st w)
                  (cistern--worker-x w) (cistern--worker-y w))
            (cistern-st-rewards-events st))
      (when (= new 3)
        (let* ((stats (cistern--worker-stats w))
               (idx 0) (low (nth 0 stats)))
          (dotimes (i 4)
            (when (< (nth i stats) low) (setq low (nth i stats) idx i)))
          (setf (nth idx stats) (+ low 2)))))))

(defun cistern--rpg-composure (st w prev)
  "RPG §3.4 #3: the composure check fires when an unseated
worker's bladder CROSSES 100 (prev < 100 ≤ now) — crossing tick
only.  Band 0/1 spike the bladder mid-walk: an early burst is
possible (A7)."
  (let ((now (cistern--worker-bladder w)))
    (when (and (< prev 100) (>= now 100) (not (cistern--worker-using w)))
      (let* ((r (cistern--rpg-check st 'composure-nerve
                                    (cdr (assq 'composure-dc
                                               cistern--rpg-const))
                                    (cistern--rpg-stat-mod w 2)))
             (band (car r))
             (spike (plist-get (cdr r) :spike)))
        (when (> spike 0)
          (setf (cistern--worker-bladder w) (+ now spike))
          (cistern--log-sev st 'error "%s"
                            (format (cdr (assq (if (= band 0)
                                                   'composure-broken
                                                 'composure-slip)
                                               cistern--copy))
                                    (cistern--worker-glyph st w))))))))

(defun cistern--rpg-exposure (st victim)
  "V4-12 (RPG §3.4 #2): the exposure check for VICTIM beside a
breach — REPLACES the automatic sick (A6).  Band 0/1 sicken for
clamp(30 − 4·GRIT-mod, 18, 42) ticks (+5 on band 0); bands 2/3
hold (band 3 pays +1 XP)."
  (let* ((r (cistern--rpg-check st 'exposure-grit
                                (cdr (assq 'exposure-dc cistern--rpg-const))
                                (cistern--rpg-stat-mod victim 1)))
         (band (car r))
         (effect (cdr r))
         (glyph (cistern--worker-glyph st victim)))
    (if (<= band 1)
        (progn
          (setf (cistern--worker-sick victim)
                (+ (plist-get effect :sick)
                   (cistern--rpg-sick-duration
                    (cistern--rpg-stat-mod victim 1))))
          (cistern--log-sev st 'error "%s"
                            (format (cdr (assq 'exposure-fail
                                               cistern--copy))
                                    glyph)))
      (when (plist-get effect :xp)
        (cistern--rpg-grant-xp st victim (plist-get effect :xp)))
      (cistern--log-sev st 'info "%s"
                        (format (cdr (assq 'exposure-hold cistern--copy))
                                glyph)))))

(defun cistern--cmd-cycle-toilet-type (st)
  "V4-11: `T` — advance the armed fixture type in catalog order."
  (setf (cistern-st-toilet-type st)
        (cistern--toilet-type-next (cistern-st-toilet-type st)))
  st)

(defun cistern--stream-next (pos)
  "One raw child-stream step from POS: the domain LCG recurrence.
Returns the new 31-bit position; call sites mod-scope it at use.
Pure — never touches cistern-st-rng."
  (mod (+ (* pos 1103515245) 12345) 2147483648))

(defun cistern--log (st fmt &rest args)
  "Append a plain line.  Q13: entries are (LINE SEVERITY TICK)
so color persists with the text and V4-01 stamps the append-time
tick; nil severity renders dim.  Q16: the log is UNCAPPED — tail
clipping is the view's concern."
  (push (list (apply #'format fmt args) nil (cistern-st-tick st))
        (cistern-st-log st)))

(defun cistern--log-sev (st sev fmt &rest args)
  "Append a line carrying SEVERITY-ENUM (Q13): info = minor,
error = major — the view maps the enum through its palette.
V4-01: the entry is (LINE SEVERITY TICK), stamped at append."
  (push (list (apply #'format fmt args) sev (cistern-st-tick st))
        (cistern-st-log st)))

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
cells, the starter plumbing chain, and the tutorial scenario's
build corridor (win-serve grows the second seat there — V4-05
procgen keeps it floor)."
  (or (member (list x y) cistern--procgen-spawns)
      (member (list x y) '((3 2) (4 2) (5 2) (3 3)))
      ;; V4-05: the win-serve walkthrough builds its seats here —
      ;; procgen keeps them floor
      (member (list x y) '((4 1) (4 3) (2 2)))))

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
  ;; V4-05 (S3.2): map-gen debris fields — 2-4 clusters of 1-3
  ;; impassable rubble cells that shape routing
  (let ((n (+ 2 (cistern--rand st 3))))
    (dotimes (_ n)
      (let* ((x (+ 2 (cistern--rand st (- cistern-w 4))))
             (y (+ 2 (cistern--rand st (- cistern-h 4))))
             (size (+ 1 (cistern--rand st 3))))
        (cistern--procgen-place st x y 'rubble)
        (dotimes (_ (1- size))
          (let ((n (nth (cistern--rand st 4)
                        '((1 . 0) (0 . 1) (-1 . 0) (0 . -1)))))
            (cistern--procgen-place st (+ x (car n)) (+ y (cdr n))
                                    'rubble))))))
  ;; V4-05 (S3.2): 0-2 manifold anchors — free pipe liveness
  (let ((n (cistern--rand st 3)))
    (dotimes (_ n)
      (let ((x (+ 2 (cistern--rand st (- cistern-w 4))))
            (y (+ 2 (cistern--rand st (- cistern-h 4)))))
        (cistern--procgen-place st x y 'manifold))))
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
  (puthash (cons 3 3) (list :busy nil :type 'long-drop)
            (cistern-st-toilets st))
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

(defun cistern--manifold-live-p (st sx sy)
  "V4-05 (S3.2): is the plumbing network containing (SX,SY)
anchored — does it touch a PIPE orthogonally adjacent to a
manifold?  A manifold is live with unlimited headroom: no tank
needed, no purge income."
  (let ((seen (cistern--flood st sx sy
                              (lambda (px py)
                                (memq (cistern--cell st px py)
                                      '(toilet pipe tank)))))
        (live nil))
    (maphash (lambda (k _)
               (when (and (not live)
                          (eq (cistern--cell st (car k) (cdr k)) 'pipe))
                 (dolist (n (cistern--neighbors st (car k) (cdr k)))
                   (when (eq (cistern--cell st (car n) (cdr n)) 'manifold)
                     (setq live t)))))
             seen)
    live))

(defun cistern--pipe-live-p (st x y)
  "V4-05 view query: a pipe is live when it reaches tank capacity
OR is anchored to a manifold."
  (or (cistern--connected-tanks st x y)
      (cistern--manifold-live-p st x y)))

(defun cistern--toilet-usable-p (st x y)
  (let ((entry (gethash (cons x y) (cistern-st-toilets st))))
    (and entry
         (not (plist-get entry :busy))
         (or ;; tanks with headroom on the live path
             (cl-some (lambda (tk)
                        (<= (+ (plist-get (gethash tk (cistern-st-tanks st))
                                          :load)
                               cistern-use-load)
                            cistern-tank-cap))
                      (cistern--connected-tanks st x y))
             ;; V4-05: a manifold anchor is unlimited headroom
             (cistern--manifold-live-p st x y)))))

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

(defun cistern--toilet-type-at (st x y)
  "V4-12 view query: the fixture type placed at (X,Y) — long-drop
for pre-catalog toilets."
  (or (plist-get (gethash (cons x y) (cistern-st-toilets st)) :type)
      'long-drop))

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
                          (null (cistern--connected-tanks st (car k) (cdr k)))
                          ;; V4-05: a manifold anchor is never severed
                          (not (cistern--manifold-live-p st (car k)
                                                         (cdr k))))
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

(defun cistern--built-this-tick-p (st x y)
  "R2-Q09: was the placed piece at (X,Y) built THIS tick (the
free regret window still open)?  The view reads this query — it
never touches the built-at hash (D6)."
  (let ((bt (gethash (cons x y) (cistern-st-built-at st))))
    (and bt (= bt (cistern-st-tick st)))))

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
  (let ((w (cistern--worker-make :x x :y y :bladder 20
                                 :stats (cistern--rpg-roll-stats st))))
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
                    (let ((rate (cistern--rpg-mine-rate
                                 (cistern--rpg-stat-mod w 0))))
                      ;; sickness halves throughput (RPG §1), never mobility
                      (if (> (cistern--worker-sick w) 0) (* 2 rate) rate)))
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
          ;; V4-12 (RPG §3.4 #4): stride — one roll per journey (a
          ;; journey = a contiguous walk toward one target); a pass
          ;; moves 2 steps this tick, never fewer than the base 1
          (let* ((fresh (not (equal (cistern--worker-journey w)
                                    (cons tx ty))))
                 (steps (if (and fresh
                                 (>= (cistern--rpg-band
                                      st
                                      (cdr (assq 'stride-dc
                                                 cistern--rpg-const))
                                      (cistern--rpg-stat-mod w 3))
                                     2))
                            2 1)))
            (when fresh
              (setf (cistern--worker-journey w) (cons tx ty)))
            (dotimes (_ steps)
              (let ((d (gethash (cons (cistern--worker-x w)
                                      (cistern--worker-y w))
                                dist)))
                (when (and d (> d 0))
                  (let (nxt)
                    (dolist (n (cistern--neighbors st
                                                   (cistern--worker-x w)
                                                   (cistern--worker-y w)))
                      (let ((dd (gethash n dist)))
                        (when (and dd (= dd (1- d))
                                   (not (gethash n blocked)))
                          (unless nxt (setq nxt n)))))
                    (when nxt
                      (setf (cistern--worker-x w) (car nxt))
                      (setf (cistern--worker-y w) (cdr nxt))
                      (when (and (eq (cistern--cell st (car nxt)
                                                (cdr nxt))
                                     'toilet)
                                 (= (car nxt) tx) (= (cdr nxt) ty)
                                 (>= (cistern--worker-bladder w)
                                     (cistern--rpg-seek-eff
                                      (cistern--rpg-stat-mod w 2))))
                        ;; stepping onto the target toilet = seating
                        (let ((type (or (plist-get
                                         (gethash nxt
                                                  (cistern-st-toilets st))
                                         :type)
                                        'long-drop)))
                          (puthash nxt (list :busy t :type type)
                                   (cistern-st-toilets st))
                          (setf (cistern--worker-using w) t)
                          (setf (cistern--worker-use-t w)
                                (cistern--rpg-use-ticks w type))
                          (setf (cistern--worker-toilet w) nxt)))))))))
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
      ;; V4-11/V4-12: release preserves the fixture's :type
      (puthash tp (list :busy nil
                        :type (or (plist-get (gethash tp
                                                        (cistern-st-toilets st))
                                             :type)
                                  'long-drop))
               (cistern-st-toilets st)))
    (let ((tanks (cistern--connected-tanks st (cistern--worker-x w)
                                            (cistern--worker-y w))))
      (cond
       ((and (null tanks)
             (cistern--manifold-live-p st (cistern--worker-x w)
                                       (cistern--worker-y w)))
        ;; V4-05: a manifold anchor drains the waste — relief
        ;; without tank income and without a spill
        (cistern--log-sev st 'info "%s"
                          (format (cdr (assq 'relief-log cistern--copy))
                                  x y))
        (push (list 'relief bladder x y)
              (cistern-st-rewards-events st))
        ;; V4-12: manifold relief earns XP too (suited check on the
        ;; seated fixture)
        (cistern--rpg-grant-xp
         st w
         (if (eq (cistern--rpg-suit
                  w (or (plist-get (gethash (cons x y)
                                            (cistern-st-toilets st))
                                  :type)
                       'long-drop))
               'suited)
             2 1)))
       ((null tanks)
        (progn
          (cistern--add-hazard st x y)
          (setf (cistern-st-contam st) (1+ (cistern-st-contam st)))
          (let ((line (format "SEVERED LINE AT (%d,%d) — WASTE SPILLED" x y)))
            (cistern--log-sev st 'error "%s" line)
            (push (list 'leak line) (cistern-st-rewards-events st))))) ; leak (M4)
       (t
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
          ;; V4-12 (RPG §4): +1 per relief, +1 extra on a SUITED fixture
          (cistern--rpg-grant-xp st w
                                 (if (eq (cistern--rpg-suit
                                          w (or (plist-get
                                                 (gethash (cons x y)
                                                          (cistern-st-toilets st))
                                                 :type)
                                                 'long-drop))
                                         'suited)
                                     2 1))
          (cistern--log-sev st 'info "%s"
                            (format (cdr (assq 'relief-log cistern--copy))
                                    x y))))))))

(defun cistern--add-hazard (st x y)
  "Contaminate (X,Y) if it is floor.  Everything else — ore,
pipe, toilet, tank, wall — is a firebreak by rule: the resource
base can never be destroyed by unserved need."
  (when (and (cistern--in-bounds-p st x y)
             (eq (cistern--cell st x y) 'floor))
    (cistern--set-cell st x y 'hazard)
    t))

(defun cistern--add-flood (st x y)
  "V4-05 (S3.2): flood (X,Y) if it is clean, unoccupied floor.
Flood is water, not waste: it never counts toward the contam
limit — it steals ticks, not health."
  (when (and (cistern--in-bounds-p st x y)
             (eq (cistern--cell st x y) 'floor)
             (not (gethash (cons x y) (cistern--occupied-cells st nil))))
    (cistern--set-cell st x y 'flood)
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
    ;; V4-05 (S3.2): a breach may flood the wet floor around it —
    ;; spread-pct roll per clean neighbor
    (dolist (n (cistern--neighbors st x y))
      (when (< (cistern--rand st 100) cistern-spread-pct)
        (cistern--add-flood st (car n) (cdr n))))
    (dolist (n (cistern--neighbors st x y))
      (dolist (o (cistern-st-creators st))
        (when (and (not (eq o w))
                   (= (cistern--worker-x o) (car n))
                   (= (cistern--worker-y o) (cdr n)))
          (cistern--rpg-exposure st o))))
    ;; Q14: the log names the worker's identity glyph — the same one
    ;; the map renders at this cell (one helper, one source).
    ;; R2-Q12: the noun is WORKER everywhere
    (let ((line (format (cdr (assq 'breach-fmt cistern--copy))
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
        (let ((prev (cistern--worker-bladder w)))
          (setf (cistern--worker-bladder w)
                (+ cistern-bladder-rate (cistern--worker-bladder w)))
          ;; V4-12 (RPG §3.4 #3): composure on the 100-crossing; a
          ;; spike can push past burst → the cond below bursts early
          (cistern--rpg-composure st w prev))
        (cond
         ((>= (cistern--worker-bladder w) cistern-bladder-burst)
          (cistern--accident st w))
         ;; V4-12 (RPG §1): NERVE files the relief request early or late
         ((>= (cistern--worker-bladder w)
              (cistern--rpg-seek-eff (cistern--rpg-stat-mod w 2)))
          (cistern--seek-toilet st w))
         (t (cistern--seek-work st w))))))

(defun cistern--phase-hazards (st)
  "Spread and decay.  Spread 3%% onto clean floor (never onto a
worker); decay 2%% back to floor.  Contamination is pressure, not
permanent scarring: stop bleeding and the marks fade."
  (let ((hs nil) (i 0))
    (while (< i (length (cistern-st-map st)))
      (when (memq (aref (cistern-st-map st) i) '(hazard flood))
        (push (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st))) hs))
      (cl-incf i))
    (setq hs (nreverse hs))
    (dolist (h hs)
      (let ((roll (cistern--rand st 100)))
        (if (eq (cistern--cell st (car h) (cdr h)) 'flood)
            ;; V4-05: flood does not spread — it only dries, on the
            ;; same decay-pct roll the hazard uses
            (when (< roll cistern-decay-pct)
              (cistern--set-cell st (car h) (cdr h) 'floor))
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
            (cistern--set-cell st (car h) (cdr h) 'floor))))))))

(defun cistern--phase-migration (st)
  ;; V4-12 (RPG §4): +1 XP per shift survived, at the boundary tick
  (when (and (> (cistern-st-tick st) 0)
             (= 0 (% (cistern-st-tick st) cistern-migrant-every)))
    (dolist (w (cistern-st-creators st))
      (cistern--rpg-grant-xp st w 1)))
  ;; V4-09 (S5.5): the arrival announces itself three ticks out —
  ;; exactly once per cycle, and only when an arrival will actually
  ;; happen (pop cap not reached)
  (when (and (> (cistern-st-tick st) 0)
             (< (length (cistern-st-creators st)) cistern-pop-cap)
             (= 3 (- cistern-migrant-every
                     (% (cistern-st-tick st) cistern-migrant-every))))
    (cistern--log-sev st 'info "%s"
                      (format (cdr (assq 'migrant-in-fmt cistern--copy)) 3)))
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
    ;; R2-Q06: condemnation clears any posted hint
    (setf (cistern-st-hint st) nil)
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
    ;; V4-10 (RPG §1.1): the RPG child stream (seed ⊕ 3) initializes
    ;; before the cast so spawn stat draws consume it sequentially
    (setf (cistern-st-rpg-pos st)
          (cistern--stream-init (cistern-st-seed st) 3))
    (dolist (p cistern--procgen-spawns)
      (let ((w (cistern--worker-make :x (nth 0 p) :y (nth 1 p)
                                     :stats (cistern--rpg-roll-stats st))))
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
    ;; V4-11 (RPG §2): the fixture placement refusal (R7 verdict style)
    (refusal-place . "FIXTURE REJECTED THERE — %s")
    (pipe-dead . "PIPE — DEAD: NOT CONNECTED — REWIRE (p)")
    (badge-armed . "ARMED: %s")
    (badge-auto . "AUTO-RUN")
    (condemn-append . "!! CONDEMNED")
    (restart-log . "SECTOR CONDEMNED — PRESS n TO RESTART")
    (breach-fmt . "BREACH — WORKER %s OVERFLOWED AT (%d,%d)")
    (relief-log . "WORKER RELIEVED AT (%d,%d)")
    (tutorial-complete . "TUTORIAL COMPLETE — THE SECTOR IS YOURS")
    (tutorial-step . "TUTORIAL: OBJECTIVE COMPLETE")
    (tutorial-skipped . "TUTORIAL SKIPPED")
    (tutorial-line-fmt . "TUTORIAL %d/%d: %s  (T skips)")
    (help-arm . "t/p/K arm — click to place")
    (bearing-floor . "FLOOR — %s")
    (same-tick-free . " — SAME-TICK: FREE UNDO")
    (death-panel . "%s / TICKS %d · RELIEVES %d · SCORE %d / PRESS n TO RESTART")
    (goal-met-served . "GOAL MET — %d SERVED")
    (goal-met-bursts . "GOAL MET — %d BURSTS HELD")
    (goal-met-ceiling . "GOAL MET — CONTAM UNDER %d")
    (tutorial-1 . "MOVE THE CURSOR ONTO A WORKER")
    (tutorial-2 . "PURGE A FILLING TANK (x)")
    (tutorial-3 . "THE PURGE PAYS — ALLOY IN THE BANK")
    ;; V4-05 (SURFACE S3.2): rubble clear log
    (rubble-cleared . "RUBBLE CLEARED AT (%d,%d) — %d ALLOY")
    ;; V4-06 (SURFACE S3.2/S1): inspector lines for the new kinds —
    ;; state + fix verb, copy-table only (A3.6)
    (desc-rubble . "RUBBLE — IMPASSABLE: D CLEARS TO FLOOR")
    (desc-flood . "FLOOD — IMPASSABLE WHILE WET: C DRIES IT")
    (desc-manifold . "MANIFOLD — FREE PIPE ANCHOR: WIRES WITHOUT A TANK")
    (desc-cache . "CACHE — WALK IT TO BANK THE ALLOY")
    (desc-event . "EVENT INCOMING — THE COUNTDOWN IS STANDING")
    ;; V4-09 (SURFACE S5.3/S5.5)
    (death-log-hint . "L — FULL HISTORY")
    (migrant-in-fmt . "MIGRANT IN %d TICKS")
    ;; V4-12 (RPG §8): clearance/composure/exposure/inspector copy
    (clearance-up . "CLEARANCE II — %s CROSS-CERTIFIED")
    (clearance-up-3 . "CLEARANCE III — %s FIELD-CERTIFIED")
    (composure-slip . "COMPOSURE SLIP — WORKER %s — PRESSURE MOUNTING")
    (composure-broken . "COMPOSURE LOST — WORKER %s — PRESSURE CRITICAL")
    (exposure-hold . "CONTAMINATION EXPOSURE LOGGED — WORKER %s UNAFFECTED")
    (exposure-fail . "WORKER %s CONTAMINATED — DEGRADATION UNDERWAY")
    (toilet-type-fmt . "FIXTURE — %s — %s")
    (inspector-stat-fmt . "F%+d G%+d N%+d A%+d")
    (inspector-clear-fmt . "CL.%s")
    ;; V4-07 (SURFACE S4.2/S4.3): the power layer's copy
    (capacity-none . "NO WIRED TOILET ON THE GRID — LAY PIPE (p)")
    (teach-arrows . "C-n/C-p/C-f/C-b MOVE TOO")
    (teach-cancel . "C-g CANCELS — OR U/ESC")
    (teach-emacs-cancel . "C-g IS THE EMACS CANCEL")
    (teach-auto-run . "r RUNS THE TICKS — C-u r SLOW")
    (teach-log . "C-s SEARCHES THE LOG / n/p WALK IT")
    ;; V4-02 (SURFACE S1.2/S1.3): the log browser's table copy
    (log-header . "— press q to close —")
    (log-jump-none . "NO CELL ON THIS LINE")
    (log-hint . "LOG BROWSER — n/p WALK · / SEARCH · g REBUILD · RET JUMPS TO SOURCE"))
  "Q11 copy table, keyed by surface (Q05/Q08/Q10 milestones and
pressure lines so far).")

;; ---------------------------------------------------------------------------
;; V4-14 (STORY §4): the banks — registry, copy chain, loader.  Loading
;; is fail-first: a malformed bank errors with the offending field
;; named, never a silent skip (same ruling as the goal-card setter).

(defvar cistern--banks nil
  "Registry plist (:scenarios ... :quirks ... :keywords ... :
flavor ...) — each slot a list of validated entry plists.  Nil
until `cistern--banks-load'.")

(defvar cistern--story-copy nil
  "Folded copy alist built once at load: cistern--copy's story
section first, then bank :copy sections in load order (§4.4).")

(defconst cistern--bank-kinds '(scenario quirk keyword flavor)
  "The four bank kinds (STORY §4.2; dialogue arrives in wave 3).")

(defconst cistern--story-stats '(tolerance integrity standing)
  "Story stat keys (STORY §6.1) — matrix :stat must be one of these.")

(defconst cistern--story-effects
  '(none log-line popup hazard-spawn tank-load-delta alloy-grant
    beat-open beat-resolve)
  "STORY §6.4 effects whitelist — closed in v4.")

(defconst cistern--story-act-span 100
  "Act span in ticks (V4-14 pin): act N covers
((N−1)·span .. N·span); the LAST act is unbounded (the §4.2
example's act-3 window 240..99999 fixes this reading).")

(defun cistern--story-copy-key (key)
  "STORY §4.4 copy chain: cistern--copy's story section first,
then bank :copy sections in load order, else load-time error.
The loader pre-resolves every key, so runtime lookup is one assq."
  (or (cdr (assq key cistern--story-copy))
      (cdr (assq key (cdr (assq 'story cistern--copy))))
      (error "UNRESOLVED STORY COPY KEY %S" key)))

(defun cistern--bank-error (file fmt &rest args)
  (error "BANK %s: %s" file (apply #'format fmt args)))

(defun cistern--bank-validate-hook (file h act-count seen-hooks)
  "Validate one scenario hook (STORY §4.3): act in 1..3, window
inside its act span, :requires names a hook of a STRICTLY EARLIER
act."
  (let ((id (plist-get h :id))
        (act (plist-get h :act))
        (win (plist-get h :window))
        (req (plist-get h :requires))
        (cond-grammar (plist-get h :condition)))
    (unless id (cistern--bank-error file "hook without :id"))
    (unless (and (integerp act) (>= act 1) (<= act act-count))
      (cistern--bank-error file "hook %s :act %S outside 1..%d"
                           id act act-count))
    (unless (and (consp win) (integerp (car win)) (integerp (cdr win))
                 (>= (car win) (* (1- act) cistern--story-act-span))
                 (<= (cdr win) (if (= act act-count) 99999
                                 (* act cistern--story-act-span)))
                 (<= (car win) (cdr win)))
      (cistern--bank-error file "hook %s :window %S outside act %d span"
                           id win act))
    (unless (and (consp cond-grammar)
                 (memq (car cond-grammar) '(event tick)))
      (cistern--bank-error file "hook %s :condition %S not in the closed
grammar" id cond-grammar))
    (when req
      (let ((prev (assq req seen-hooks)))
        (unless (and prev (< (cdr prev) act))
          (cistern--bank-error
           file "hook %s :requires %s is not a hook of a strictly
earlier act" id req))))
    (cons id act)))

(defun cistern--bank-validate-matrix (file m)
  (let ((id (plist-get m :id))
        (outs (plist-get m :outcomes))
        (stat (plist-get m :stat))
        (mods (plist-get m :act-mods)))
    (unless id (cistern--bank-error file "matrix without :id"))
    (unless (= (length outs) 4)
      (cistern--bank-error file "matrix %s has %d outcomes (need 4)"
                           id (length outs)))
    (unless (memq stat cistern--story-stats)
      (cistern--bank-error file "matrix %s :stat %S unknown" id stat))
    (unless (= (length mods) 3)
      (cistern--bank-error file "matrix %s :act-mods not length 3" id))
    (dolist (o outs)
      (unless (memq (plist-get o :effect) cistern--story-effects)
        (cistern--bank-error file "matrix %s effect %S off the whitelist"
                             id (plist-get o :effect)))
      (unless (cdr (assq (plist-get o :line-key) cistern--story-copy))
        (cistern--bank-error file "matrix %s :line-key %S unresolvable"
                             id (plist-get o :line-key))))))

(defun cistern--bank-validate-goal-mod (file gm)
  (let ((mods (plist-get gm :target-mod)))
    (when mods
      (dolist (pair mods)
        (unless (memq (car pair) cistern--goal-kinds)
          (cistern--bank-error file "goal-mod kind %S outside :goal-kinds"
                               (car pair)))))))

(defun cistern--bank-registry-key (kind)
  "Registry slot (plural) for a bank KIND (STORY §4.1)."
  (pcase kind
    ('scenario :scenarios) ('quirk :quirks)
    ('keyword :keywords) ('flavor :flavor)))

(defun cistern--bank-validate-entry (file kind e registry)
  "Validate one entry of KIND; returns its :id.  REGISTRY carries
the ids seen so far (duplicate detection across banks)."
  (let ((id (plist-get e :id)))
    (unless id (cistern--bank-error file "%s entry without :id" kind))
    (when (member id (cdr (assq (cistern--bank-registry-key kind)
                                registry)))
      (cistern--bank-error file "duplicate :id %s in kind %s" id kind))
    (pcase kind
      ('scenario
       (unless (cdr (assq (plist-get e :premise) cistern--story-copy))
         (cistern--bank-error file "scenario %s :premise %S unresolvable"
                              id (plist-get e :premise)))
       (unless (memq (plist-get e :acts) '(1 2 3))
         (cistern--bank-error file "scenario %s :acts %S invalid"
                              id (plist-get e :acts)))
       (cistern--bank-validate-goal-mod file (plist-get e :goal-mod))
       (let ((seen nil))
         (dolist (h (plist-get e :hooks))
           (push (cistern--bank-validate-hook file h (plist-get e :acts)
                                              seen)
                 seen)))
       (dolist (m (plist-get e :matrices))
         (cistern--bank-validate-matrix file m))
       (let ((tiers (plist-get e :tiers)))
         (unless (and (= (apply #'+ tiers) 100) (= (length tiers) 3))
           (cistern--bank-error file "scenario %s :tiers %S do not sum
to 100 over 3 acts" id tiers)))
       (dolist (ev (plist-get e :events))
         (unless (cdr (assq (plist-get ev :copy-key) cistern--story-copy))
           (cistern--bank-error file "event %s :copy-key unresolvable"
                                (plist-get ev :id)))))
      ('quirk
       (unless (memq (plist-get e :context) cistern--story-stats)
         (cistern--bank-error file "quirk %s :context %S unknown"
                              id (plist-get e :context)))
       (unless (cdr (assq (plist-get e :copy-key) cistern--story-copy))
         (cistern--bank-error file "quirk %s :copy-key unresolvable" id)))
      ('keyword
       (unless (memq (plist-get e :class) '(place sector designation))
         (cistern--bank-error file "keyword %s :class %S unknown"
                              id (plist-get e :class))))
      ('flavor
       (unless (cdr (assq (plist-get e :copy-key) cistern--story-copy))
         (cistern--bank-error file "flavor %s :copy-key unresolvable" id))))
    id))

(defun cistern--banks-load (files)
  "STORY §4: load each bank FILE, validate fail-first, fold the
entries into `cistern--banks' and the copy chain.  Each file is
one (or more) defconsts of pure data named cistern-bank-*."
  (let ((loaded nil))
    (dolist (f files)
      (let ((new-syms nil))
        (load f nil t)
        ;; the file's load-history entry lists the defconst'd symbols —
        ;; robust across repeated loads (a boundp diff would find
        ;; nothing on a second load of the same bank)
        (dolist (e (cdr (assoc f load-history)))
          (when (and (symbolp e)
                     (string-match-p "\\`cistern-bank-" (symbol-name e)))
            (push e new-syms)))
        (setq new-syms (sort new-syms #'string<))
        (unless new-syms
          (cistern--bank-error f "no cistern-bank-* defconst found"))
        (dolist (sym new-syms)
          (let ((bank (symbol-value sym)))
            (unless (and (listp bank) (plist-get bank :kind))
              (cistern--bank-error f "%s is not a bank plist" sym))
            (let ((kind (plist-get bank :kind)))
              (unless (memq kind cistern--bank-kinds)
                (cistern--bank-error f "unknown :kind %S" kind))
              (let ((entries (plist-get bank :entries)))
                (unless (and (listp entries) (consp entries))
                  (cistern--bank-error f "empty :entries"))
                ;; fold the bank copy into the chain BEFORE entry
                ;; validation: keys resolve after the bank's own :copy
                ;; is folded in (STORY §4.4)
                (setq cistern--story-copy
                      (append cistern--story-copy
                              (plist-get bank :copy)))
                (let ((seen nil))
                  (dolist (e entries)
                    (let ((id (plist-get e :id)))
                      (when (member id seen)
                        (cistern--bank-error
                         f "duplicate :id %s in kind %s" id kind))
                      (push id seen)
                      (cistern--bank-validate-entry
                       f kind e cistern--banks))))
                (setq loaded
                      (plist-put loaded
                                 (pcase kind
                                   ('scenario :scenarios)
                                   ('quirk :quirks)
                                   ('keyword :keywords)
                                   ('flavor :flavor))
                                 (append (plist-get loaded
                                                     (pcase kind
                                                       ('scenario :scenarios)
                                                       ('quirk :quirks)
                                                       ('keyword :keywords)
                                                       ('flavor :flavor)))
                                         entries)))))))))
    (setq cistern--banks loaded)
    cistern--banks))

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
