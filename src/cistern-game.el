;;; cistern-game.el --- Use cases: player verbs, state in → state out -*- lexical-binding: t; -*-

;; Game/use-case layer (DESIGN-SPEC §3.3): pure signatures —
;; state + intent → state + log.  No buffers, faces, keymaps, timers,
;; no `cistern--st' global, no rendering.  Layer dependency is strictly
;; inward: this file requires cistern-domain and nothing else.

(require 'cl-lib)
(require 'cistern-domain)

(defconst cistern-cost-demolish 3
  "Alloy cost of the demolish verb (R8).  Implementation-seed
value, pinned for testability per plan 01 §2.3; final pricing is
DEFERRED to REWARDS-DESIGN (spec §6).  The 50%-of-build-cost
refund is consumed in 4b (M1).")

(defun cistern--cmd-build (st kind x y)
  "Place KIND (toilet/pipe/tank) at (X,Y).  Ported verbatim from
cistern.el:498-525, rendered calls stripped."
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

(defun cistern--cmd-demolish (st x y)
  "Remove the player-placed plumbing at (X,Y) (R8).  Legality:
player-placed kinds only (pipe/toilet/tank) — walls/doors/ore are
terrain (decon stays the separate, hazard-only verb) — and an
in-use toilet (worker seated) is refused.  Removal = cell → floor
+ `remhash' from BOTH plumbing hashes; downstream usability is
re-decided by the domain flood-fill, so cell+hash removal is the
whole job.  No dangling plumbing entries may survive (the v1
phantom-plumbing invariant, load-bearing)."
  (let ((kind (and (cistern--in-bounds-p st x y)
                   (cistern--cell st x y))))
    (cond
     ((not (memq kind '(pipe toilet tank)))
      (cistern--log st "NOT YOURS TO DEMOLISH"))
     ((and (eq kind 'toilet)
           (plist-get (gethash (cons x y) (cistern-st-toilets st)) :busy))
      (cistern--log st "TOILET IN USE"))
     ((< (cistern-st-alloy st) cistern-cost-demolish)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED"
                    cistern-cost-demolish))
     (t
      (let ((refund (/ (pcase kind
                         ('toilet cistern-cost-toilet)
                         ('pipe cistern-cost-pipe)
                         ('tank cistern-cost-tank))
                       2))) ; 50% of build cost, floor (M1; rounding pinned L-024)
        (setf (cistern-st-alloy st)
              (+ (- (cistern-st-alloy st) cistern-cost-demolish) refund))
        (remhash (cons x y) (cistern-st-toilets st))
        (remhash (cons x y) (cistern-st-tanks st))
        (cistern--set-cell st x y 'floor)
        (push (list 'demolish x y) (cistern-st-rewards-events st))
        (cistern--log st "DEMOLISHED %s AT (%d,%d) — %d ALLOY — %d REFUND"
                      (upcase (symbol-name kind)) x y
                      cistern-cost-demolish refund))))))

(defun cistern--tutorial-steps (&optional table)
  "Tutorial mechanism holder: table of (PROMPT . PREDICATE) steps,
predicate takes ST and a non-nil result advances.  Scenario content
is Phase 4a; the table ships empty so advance is a no-op.  The
optional TABLE arg is the test-injection point (the shipped game
never passes one)."
  (or table '()))

(defun cistern--tutorial-advance (st &optional table)
  "Advance the tutorial index one gated step per tick (legacy
cistern.el:589-599 semantics): the current step's predicate gates,
already-satisfied steps resolve instantly on their tick, and
completing the final step sets the index to `t' with the
completion line."
  (let ((steps (cistern--tutorial-steps table))
        (idx (cistern-st-tutorial st)))
    (when (and (numberp idx)
               (< idx (length steps))
               (funcall (cdr (nth idx steps)) st))
      (setf (cistern-st-tutorial st) (1+ idx))
      (if (>= (1+ idx) (length steps))
          (progn
            (setf (cistern-st-tutorial st) t)
            (cistern--log st "TUTORIAL COMPLETE — THE SECTOR IS YOURS"))
        (cistern--log st "TUTORIAL: OBJECTIVE COMPLETE")))))

(defun cistern--cmd-skip-tutorial (st)
  "T skip (R4): mark the tutorial done so advance is a no-op.
Use-case form — the index is state and mutates here, never in the
driver (armed-verb precedent, L-010 pin 4)."
  (setf (cistern-st-tutorial st) t)
  (cistern--log st "TUTORIAL SKIPPED"))

(defconst cistern-tutorial-scenario-losing
  (list
   :name "lose-breach"
   :seed 42
   :script                       ; (wait . N) → N ticks; (verb . FN) → (funcall FN st)
    `((verb . ,(lambda (st) (cistern--cmd-demolish st 4 2))) ; sever the starter line: the only wired toilet goes dead
      (wait . 55))               ; bladder 20 + 2/tick bursts at tick 50 (bladder-seek 60 → bladder-burst 120); 55 is margin
   :lesson "LESSON: UNWIRED TOILET IS FURNITURE — LAY PIPE TO A TANK"
   :expect '((contamination . (> 0))
             (log-contains . "lesson")))
  "Phase 4a losing walkthrough (plan 03 §4a pair 1): with the wired
line severed, no reachable toilet serves the sector and the bladder
breach fires deterministically from the pinned constants.")

(defconst cistern-tutorial-scenario-winning
  (list
   :name "win-serve"
   :seed 42                       ; same seed as the losing scenario
   :script
    `((verb . ,(lambda (st) (cistern--cmd-purge st 5 2)))    ; starter tank: clears the 30-load backup and funds the build
      (verb . ,(lambda (st) (cistern--cmd-build st 'pipe 6 2)))  ; grow the starter network outward (each cell is a
      (verb . ,(lambda (st) (cistern--cmd-build st 'toilet 7 2))) ;  floor neighbor of the reserved starter plumbing)
      (verb . ,(lambda (st) (cistern--cmd-build st 'pipe 6 3)))
      (verb . ,(lambda (st) (cistern--cmd-build st 'pipe 6 4)))
      (verb . ,(lambda (st) (cistern--cmd-build st 'pipe 6 5)))
      (verb . ,(lambda (st) (cistern--cmd-build st 'toilet 7 5))) ; seat on the seekers' return funnel
      (wait . 55))               ; same horizon budget as the losing scenario
   :expect '((contamination . (= 0))
             (over . nil)))
  "Phase 4a winning walkthrough (plan 03 §4a pair 2): the SAME
seed's need — the pure-wait run breaches at tick 50 because one
wired toilet + a filling tank cannot serve the seekers — is served
by purging before backup and growing a second seat onto the return
funnel.  No :lesson: R4's acceptance here is contamination 0 on the
same need, not a log line (the losing scenario's lesson carries the
teaching moment).")

(defun cistern--scenario-expect-p (st key val)
  "Evaluate one scenario :expect entry (KEY . VAL) against final ST."
  (pcase key
    (`contamination (funcall (car val) (cistern-st-contam st) (cadr val)))
    (`log-contains (cl-some (lambda (line)
                              (string-match-p (downcase val) (downcase line)))
                            (cistern-st-log st)))
    (`over (eq (not (cistern-st-over st)) (not val)))
    (_ (error "UNKNOWN SCENARIO EXPECT KEY %S" key))))

(defun cistern-tutorial-run-scenario (scenario)
  "Headless SCENARIO run (plan 03 §4a): seed fresh state, replay
the script ((wait . N) → that many `cistern--do-tick' calls;
(verb . FN) → one (funcall FN ST) use-case call), state the
scenario's :lesson once a breach lands, then assert every :expect
predicate.  Returns the final state; signals on an unmet expect."
  (let ((st (cistern--new-game (plist-get scenario :seed)))
        (lesson (plist-get scenario :lesson))
        (lesson-said nil))
    (dolist (step (plist-get scenario :script) st)
      (pcase (car step)
        (`wait (dotimes (_ (cdr step))
                 (cistern--do-tick st)
                 (when (and lesson (not lesson-said)
                            (> (cistern-st-contam st) 0))
                   (setq lesson-said t)
                   (cistern--log st "%s" lesson))))
        (`verb (funcall (cdr step) st))
        (_ (error "UNKNOWN SCENARIO STEP %S" step))))
    (dolist (exp (plist-get scenario :expect))
      (unless (cistern--scenario-expect-p st (car exp) (cdr exp))
        (error "SCENARIO %s: EXPECT (%S . %S) FAILED"
               (plist-get scenario :name) (car exp) (cdr exp))))
    st))

(defun cistern--do-tick (st)
  "Exactly one tick per action (R6): over-guard, then one domain
sim tick, then the tutorial advance.  The legacy multi-tick
command is NOT ported — no way to advance more than one tick per
call exists at the use-case layer."
  (unless (cistern-st-over st)
    (cistern--sim-tick st)
    ;; per-tick rewards evaluation (L-027 wiring): runs ONCE per
    ;; tick, after the sim phases and before the tutorial advance;
    ;; stores outcome+intents in state for the view to read
    (cistern--rewards-eval st nil)
    (cistern--tutorial-advance st)))

(defconst cistern--rewards-default-outcome
  '(:score 0 :objectives nil :unlocks nil :celebrate nil)
  "Outcome skeleton (spec §4 R5; REWARDS-DESIGN §5).  4b
consumption fills :score/:unlocks/:celebrate per tick;
:objectives stays the pinned nil placeholder (no per-goal outcome
surface exists — card state is read from the goal card itself).")

(defun cistern--rewards-eval (st raw-events)
  "Rewards use-case (R5): (state, tick EVENTS) → (updated state,
outcome, presentation intents) as a 3-list.  Consumes the events
emitted since the last read — ST's pending list (drained here)
plus RAW-EVENTS — mechanic by mechanic per REWARDS-DESIGN: M1
dust (3–5 sparkles into the field, drawn from the child stream,
never the sim LCG), M3 goal-card evaluation + MapCompleted, M9
ceremony fill, M4 reputation, M5 relieve-pay + popups, M7 faced
log intents, M8 milestone ladder.  Stores (outcome . intents) in
state for the view to read (L-027); the view never calls this."
  (let ((intents nil)
        (celebrate nil)
        (ceremony-p nil)
        ;; the tick's events: pending list + caller arguments, merged
        (events (append (cistern-st-rewards-events st) raw-events)))
    (dolist (ev events)
      ;; §5's event vocabulary is bare symbols (relief, burst, …);
      ;; payload-carrying events (demolish) are lists.  Symbols pass.
      (when (and (listp ev) (eq (car ev) 'demolish))
        ;; §4 trigger table, Demolish dust row: 3–5 `sparkle`, ttl
        ;; 2–3, glyphs `·` `.`, short vel — spawned INTO the field.
        ;; Draw order pinned (L-029 fixture): count, then per
        ;; particle: glyph, ttl, vel-x, vel-y.
        (let* ((x (nth 1 ev)) (y (nth 2 ev))
               (count (+ 3 (mod (cistern--particle-draw st) 3))))
          (dotimes (_ count)
            (let* ((g (cistern--particle-draw st))
                   (ttlp (+ 2 (mod (cistern--particle-draw st) 2)))
                   (vx (- (mod (cistern--particle-draw st) 3) 1))
                   (vy (- (mod (cistern--particle-draw st) 3) 1))
                   (glyph (if (= 0 (mod g 2)) "·" ".")))
              (cistern--field-spawn st (cons x y) (cons vx vy) ttlp
                                    glyph 'info 'sparkle))))))
    ;; M3 goal-card evaluator: re-checked on every call (rewards-eval
    ;; runs exactly once per tick, L-027 wiring).  Progress accrues
    ;; from relief and burst events; each goal's :satisfied is written back into
    ;; the card in state (observable goal state); all satisfied ⇒
    ;; MapCompleted as a banner intent, exactly once (commit-first,
    ;; M9 consumes the flag).
    (let ((card (cistern-st-goal-card st)))
      (when card
        (let* ((relieves (+ (cistern--count-events events 'relief)
                            (or (plist-get card :relieves) 0)))
               (bursts (+ (cistern--count-events events 'burst)
                          (or (plist-get card :bursts) 0)))
               (tier (plist-get card :tier)))
          (setq card (plist-put card :relieves relieves))
          (setq card (plist-put card :bursts bursts))
          (setq card
                (plist-put card :goals
                           (mapcar
                            (lambda (g)
                              (let* ((kind (plist-get g :kind))
                                     (target (cistern--goal-target
                                              kind (plist-get g :target) tier))
                                     (value (pcase kind
                                              (`relieves-served relieves)
                                              (`bursts-allowed bursts)
                                              (`contamination-ceiling
                                               (cistern-st-contam st)))))
                                (plist-put g :satisfied
                                           (if (eq kind 'relieves-served)
                                               (>= value target)
                                             (<= value target)))))
                            (plist-get card :goals))))
          (when (and (not (plist-get card :completed))
                     (cl-every (lambda (g) (plist-get g :satisfied))
                               (plist-get card :goals)))
            (setq card (plist-put card :completed t))
            ;; M9 commit-first: the trophy (the completed map's seed —
            ;; §5 "visited seeds") commits AT TRIGGER TIME, zero
            ;; ticks; the ceremony that follows is pure presentation
            (push (plist-get card :map-id) (cistern-st-trophies st))
            (setq ceremony-p t)
            (push (list :layer 'banner :text "MAP COMPLETED") intents))
          (setf (cistern-st-goal-card st) card))))
    ;; M9 ceremony fill (§4 M9 row): up to K=64 ttl-6 static sparkles
    ;; across the map, glyphs from the M9 row — spawned at the trigger
    ;; evaluation; the ttl-6 decay IS the ceremony duration (no
    ;; separate timer), and no modal state exists (commit-first: input
    ;; works throughout, skipping forfeits nothing)
    (when ceremony-p
      (let ((room (- cistern--field-cap (length (cistern-st-particles st)))))
        (dotimes (_ room)
          (let* ((x (+ 1 (mod (cistern--particle-draw st) (- cistern-w 2))))
                 (y (+ 1 (mod (cistern--particle-draw st) (- cistern-h 2))))
                 (g (mod (cistern--particle-draw st) 6))
                 (glyph (cond ((= g 0) "*") ((= g 1) "!") ((= g 2) "·")
                              ((= g 3) "§")
                              (t (number-to-string (mod (cistern--particle-draw st) 10))))))
            (cistern--field-spawn st (cons x y) (cons 0 0) 6
                                  glyph 'info 'sparkle)))))
    ;; M4 reputation: deltas per §2 M4 verbatim (+1 relief, −5 burst,
    ;; −2 leak), clamped 0–100.
    (let* ((reliefs (cistern--count-events events 'relief))
           (bursts (cistern--count-events events 'burst))
           (leaks (cistern--count-events events 'leak))
           (delta (+ reliefs (* -5 bursts) (* -2 leaks))))
      (unless (= delta 0)
        (setf (cistern-st-reputation st)
              (min 100 (max 0 (+ delta (cistern-st-reputation st)))))))
    ;; M5 relieve-pay: base within the warning window, 2x near-burst,
    ;; VR-8 tips (1-in-8 draws, 2-3x base) from the child stream.
    ;; Popups are field particles: ttl 3, vel (0 . -1) drift up (M6).
    (dolist (e events)
      (when (and (consp e) (eq (cistern--event-kind e) 'relief))
        (let* ((bladder (nth 1 e))
               (x (nth 2 e)) (y (nth 3 e)))
          (when (>= bladder cistern-bladder-seek)
            (let* ((near (>= bladder cistern-score-near-burst-bladder))
                   (tip (= 0 (mod (cistern--particle-draw st) 8)))
                   (mult (cond (tip (+ 2 (mod (cistern--particle-draw st) 2)))
                               (near 2)
                               (t 1)))
                   (pay (* mult cistern-score-relief-base)))
              (setf (cistern-st-score st)
                    (+ pay (or (cistern-st-score st) 0)))
              (cistern--field-spawn st (cons x y) (cons 0 -1) 3
                                    (format "+%d" pay)
                                    (if tip 'bonus 'success) 'popup))))))
    ;; M7 three-tier log grammar: faced log intents ride the stored
    ;; slot; the view's log-tail applies the faces to the matching
    ;; log lines.  Game-changing events present via the banner row
    ;; (the M3 MapCompleted intent); banner copy DEFERRED per §6.
    (dolist (e events)
      (let ((sev (cistern--event-severity e)))
        (when (and (consp e) sev (not (eq sev 'game-changing)))
          (let ((line (pcase (cistern--event-kind e)
                        (`relief (format "CREATOR RELIEVED AT (%d,%d)"
                                         (nth 2 e) (nth 3 e)))
                        (`burst (nth 1 e))
                        (`leak (nth 1 e)))))
            (when line
              (push (list :layer 'log :text line
                          :face (cistern--severity-face sev))
                    intents))))))
    ;; M8 milestone ladder: cumulative relieves cross the ordered
    ;; thresholds; each unlock emitted exactly once (membership
    ;; guard) and persisted in the unlocks list (§5).  The ladder
    ;; adds no reputation — milestones count relieves, not reputation.
    (let ((n (cistern--count-events events 'relief)))
      (when (> n 0)
        (setf (cistern-st-relieves st) (+ n (cistern-st-relieves st)))))
    (dolist (step cistern--milestone-ladder)
      (let ((threshold (car step)) (unlock (cdr step)))
        (when (and (>= (cistern-st-relieves st) threshold)
                   (not (memq unlock (cistern-st-unlocks st))))
          (push unlock (cistern-st-unlocks st))
          (push (list 'unlock :id unlock) intents)
          (when (eq unlock 'golden-pipe)
            (setq celebrate t)))))
    (setf (cistern-st-rewards-events st) nil)
    ;; store the outcome+intents in state (§5/L-027): the view reads
    ;; the stored 2-list and never calls rewards-eval itself
    (let* ((outcome (plist-put (copy-sequence cistern--rewards-default-outcome)
                               :score (or (cistern-st-score st) 0)))
           (outcome (if (cistern-st-unlocks st)
                        (plist-put outcome :unlocks (cistern-st-unlocks st))
                      outcome))
           (outcome (if celebrate
                        (plist-put outcome :celebrate t)
                      outcome))
          (final (nreverse intents)))
      (setf (cistern-st-rewards-outcome st) (cons outcome final))
      (list st outcome final))))

(defun cistern--particle-draw (st)
  "Advance ST's particle child stream by one raw step, returning
it.  The stream position lives in state (§4 ParticleField.rng)."
  (setf (cistern-st-particle-rng st)
        (cistern--stream-next (cistern-st-particle-rng st))))

(defconst cistern--goal-kinds
  '(relieves-served bursts-allowed contamination-ceiling)
  "Goal kinds per REWARDS-DESIGN §5.")

(defun cistern--reputation-tier (rep)
  "Reputation tier (§5): 0–39 Tier 1, 40–69 Tier 2, 70–100
Tier 3.  No production consumer yet — the pay-forward that sets
the next map's :tier from reputation is deferred with cross-map
mechanics (REWARDS-DESIGN §6 item 10); the §5 boundaries are
test-pinned here."
  (cond ((< rep 40) 1) ((< rep 70) 2) (t 3)))

(defconst cistern-score-relief-base 10
  "Base score for a relief within the warning window (M5).  The
doc pins no number — implementation-pinned with fixture, DEFERRED
per §6 (L-028).")

(defconst cistern-score-near-burst-bladder 100
  "Bladder %% at or above which a relief pays 2x base (M5
near-burst).  Implementation-pinned: 20 points (10 ticks at the
bladder rate) before burst.")

(defun cistern--event-kind (e)
  "Event kind of E: the head of a payload list, or the symbol
itself (§5's vocabulary is payloadless symbols; payload-carrying
events — demolish, relief — are lists)."
  (if (consp e) (car e) e))

(defun cistern--count-events (events kind)
  "How many of EVENTS are of KIND (payload lists count too,
via `cistern--event-kind')."
  (length (cl-remove-if-not
           (lambda (e) (eq (cistern--event-kind e) kind)) events)))

(defun cistern--event-severity (event)
  "M7 three-tier announcement grammar (§2 M7, DF model): the
severity of EVENT.  Deterministic given the event."
  (pcase (cistern--event-kind event)
    (`relief 'minor)
    ((or `burst `leak) 'major)
    (`map-complete 'game-changing)
    (_ nil)))

(defun cistern--severity-face (severity)
  "Palette face enum for SEVERITY: minor → info, major → error.
Game-changing presentation is the banner row, not a face."
  (pcase severity
    (`minor 'info)
    (`major 'error)
    (_ nil)))

(defconst cistern--milestone-ladder
  '((5 . big-cistern) (15 . fast-flush) (30 . self-clean)
    (50 . air-freshener) (100 . golden-pipe))
  "Ordered milestone ladder (§2/§5): (CUMULATIVE-RELIEVES .
UNLOCK-ID).  Crossing 100 also celebrates (full buffer).")

(defun cistern--goal-target (kind target tier)
  "Tier-adjusted TARGET (§5 pay-forward: Tier1 −25%, Tier3 +25%
in the goal's own difficulty direction; floor rounding, M1
precedent).  Tier 2 = standard."
  (pcase tier
    (`1 (if (eq kind 'relieves-served)          ; easier: fewer to serve
            (floor (* 3 target) 4)
          (floor (* 5 target) 4)))              ; easier: looser caps
    (`3 (if (eq kind 'relieves-served)          ; harder: more to serve
            (floor (* 5 target) 4)
          (floor (* 3 target) 4)))              ; harder: tighter caps
    (_ target)))

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
    (setf (cistern-st-goal-card st)
          (plist-put (copy-sequence card) :map-id (cistern-st-seed st)))))

(defun cistern--cmd-cursor (st dir)
  "Move the cursor one cell in DIR (up/down/left/right), refusing
out-of-bounds steps (cistern.el:862-867 minus the render call)."
  (let* ((cur (cistern-st-cursor st))
         (x (car cur)) (y (cdr cur)))
    (pcase dir
      ('up    (when (cistern--in-bounds-p st x (1- y))
                (setf (cistern-st-cursor st) (cons x (1- y)))))
      ('down  (when (cistern--in-bounds-p st x (1+ y))
                (setf (cistern-st-cursor st) (cons x (1+ y)))))
      ('left  (when (cistern--in-bounds-p st (1- x) y)
                (setf (cistern-st-cursor st) (cons (1- x) y))))
      ('right (when (cistern--in-bounds-p st (1+ x) y)
                (setf (cistern-st-cursor st) (cons (1+ x) y)))))))

(defun cistern--cmd-click (st x y)
  "R1 use-case half: a click at (X,Y).  No build verb armed: the
cursor moves and the clock does NOT tick (R6 names only
SPACE/RET/click-with-verb as ticking actions).  Build verb armed:
place via `cistern--cmd-build' legality at (X,Y); on success clear
the armed verb and advance exactly one tick; on refusal the state
is untouched.  The keymap half that arms verbs is Phase 3."
  (let ((verb (cistern-st-armed-verb st)))
    (if (not (memq verb '(toilet pipe tank)))
        (setf (cistern-st-cursor st) (cons x y))
      (cistern--cmd-build st verb x y)
      ;; placed ⇔ cmd-build turned the floor cell into the verb kind
      (when (eq (cistern--cell st x y) verb)
        (setf (cistern-st-armed-verb st) nil)
        (cistern--do-tick st)))))

(defun cistern--cmd-arm-verb (st verb)
  "Arm the build VERB in state (R1 keymap half; L-010 pin 4 — the
armed verb is set/cleared BY USE-CASES: this sets it, cmd-click
clears it on placement).  No arming setter may exist in the driver
or adapter layers (L-013: no second arming site)."
  (setf (cistern-st-armed-verb st) verb))

(defun cistern--cmd-decon (st x y)
  "Clean a hazard tile (cistern.el:527-538 verbatim semantics:
hazard tiles ONLY — R8 keeps demolish distinct from decon)."
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
  "Convert stored tank waste back to alloy (cistern.el:540-551)."
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

(defun cistern-run-selftest ()
  "Headless proof of every rule that can break gameplay, on the
src/ layers (cistern.el:937-1035 ported; extended per spec §5.1
with demolish legality, armed-verb click-place, procgen variety,
and rewards defaults)."
  (interactive)
  ;; --- map integrity (legacy block, new procgen landmarks)
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
    ;; release, network intact, no phantom plumbing state.  Worker
    ;; seats from a guaranteed-floor neighbor of the starter toilet.
    (let* ((w (car (cistern-st-creators st)))
           (spot (cl-loop for n in (cistern--neighbors st 3 3)
                          when (and (eq (cistern--cell st (car n) (cdr n))
                                        'floor)
                                    (not (gethash n
                                                  (cistern--occupied-cells
                                                   st nil))))
                          return (progn
                                   (setf (cistern--worker-x w) (car n))
                                   (setf (cistern--worker-y w) (cdr n))
                                   n))))
      (cl-assert spot "a floor neighbor of the starter toilet exists")
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

    ;; --- breach, decon, firebreaks (worker 2 stays on its spawn cell)
    (let ((w (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 14)
      (setf (cistern--worker-y w) 7)
      (setf (cistern--worker-bladder w)
            (- cistern-bladder-burst cistern-bladder-rate))
      (cistern--do-tick st)
      (cl-assert (eq (cistern--cell st 14 7) 'hazard))
      (cl-assert (= (cistern-st-contam st) 1)))
    (cistern--cmd-decon st 14 7)
    (cl-assert (eq (cistern--cell st 14 7) 'floor))

    ;; --- a worker ON a hazard tile can still leave (no statues)
    (let ((w (nth 2 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 11)
      (setf (cistern--worker-y w) 9)
      (cistern--set-cell st 11 9 'hazard)
      (setf (cistern--worker-bladder w) 0)
      ;; two ticks: the worker may be sick and act only on even ticks
      (let ((x0 (cistern--worker-x w)))
        (dotimes (_ 2) (cistern--do-tick st))
        (cl-assert (not (and (= (cistern--worker-x w) x0)
                             (= (cistern--worker-y w) 9)))
                   "worker stuck on hazard")))

    ;; --- two workers never share a tile
    (let ((a (nth 2 (cistern-st-creators st)))
          (b (nth 3 (cistern-st-creators st))))
      (setf (cistern--worker-bladder a) 0)
      (setf (cistern--worker-bladder b) 0)
      (dotimes (_ 12) (cistern--do-tick st))
      (cl-assert (not (and (= (cistern--worker-x a) (cistern--worker-x b))
                           (= (cistern--worker-y a) (cistern--worker-y b))))
                 "workers stacked")))

  ;; --- determinism: same seed, same trajectory
  (let ((s1 (cistern--new-game 7)) (s2 (cistern--new-game 7)))
    (dotimes (_ 50) (cistern--do-tick s1) (cistern--do-tick s2))
    (cl-assert (= (cistern-st-alloy s1) (cistern-st-alloy s2)))
    (cl-assert (= (cistern-st-contam s1) (cistern-st-contam s2)))
    (cl-assert (equal (cistern-st-rng s1) (cistern-st-rng s2))))

  ;; --- demolish legality (R8): armed-verb place, demolish, cleanup
  (let* ((st (cistern--new-game 42))
         (run (cistern-test-game--floor-run st 2))
         (x (car run)) (y (cadr run)))
    (setf (cistern-st-alloy st) 100)
    ;; place a pipe through the ARMED-VERB click path only (L-010):
    ;; no cmd-build bypass — the place⇒one-tick coupling must hold.
    (setf (cistern-st-armed-verb st) 'pipe)
    (let ((tick0 (cistern-st-tick st)))
      (cistern--cmd-click st x y)
      (cl-assert (eq (cistern--cell st x y) 'pipe) "click placed pipe")
      (cl-assert (= (cistern-st-tick st) (1+ tick0))
                 "place advanced exactly one tick"))
    (let ((a0 (cistern-st-alloy st)))
      (cistern--cmd-demolish st x y)
      (cl-assert (eq (cistern--cell st x y) 'floor))
      (cl-assert (= (cistern-st-alloy st)
                    (- (+ a0 (/ cistern-cost-pipe 2))
                       cistern-cost-demolish))))
    ;; refusals: wall, ore, in-use toilet — free of charge
    (let ((ore-idx (cl-position 'ore (cistern-st-map st))))
      (cistern--cmd-demolish st 0 0)
      (cl-assert (eq (cistern--cell st 0 0) 'wall))
      (cl-assert ore-idx)
      (cistern--cmd-demolish st (% ore-idx (cistern-st-w st))
                             (/ ore-idx (cistern-st-w st)))
      (cl-assert (eq (cistern--cell st (% ore-idx (cistern-st-w st))
                                      (/ ore-idx (cistern-st-w st)))
                     'ore))
      (let ((trun (cistern-test-game--floor-run st 1))
            (tw (car (cistern-st-creators st))))
        (setf (cistern-st-armed-verb st) 'toilet)
        (cistern--cmd-click st (car trun) (cadr trun))
        (let ((a0 (cistern-st-alloy st)))
          (puthash (cons (car trun) (cadr trun)) (list :busy t)
                   (cistern-st-toilets st))
          (cistern--cmd-demolish st (car trun) (cadr trun))
          (cl-assert (eq (cistern--cell st (car trun) (cadr trun)) 'toilet)
                     "in-use toilet refused")
          (cl-assert (= (cistern-st-alloy st) a0)
                     "refusals are free"))))
    ;; the hash-cleanup invariant, load-bearing (v1 phantom plumbing)
    (maphash (lambda (k _)
               (cl-assert (eq (cistern--cell st (car k) (cdr k)) 'toilet)))
             (cistern-st-toilets st))
    (maphash (lambda (k _)
               (cl-assert (eq (cistern--cell st (car k) (cdr k)) 'tank)))
             (cistern-st-tanks st)))

  ;; --- procgen variety (R3a): ≥3 distinct signatures over 5 seeds
  ;; (L-002: signatures hash printed content, never bare sxhash)
  (let ((sigs nil))
    (dolist (seed '(1 2 3 4 5))
      (let* ((st (cistern--new-game seed))
             (feats nil))
        (dotimes (y (cistern-st-h st))
          (dotimes (x (cistern-st-w st))
            (let ((k (cistern--cell st x y)))
              (when (memq k '(wall ore pipe toilet tank))
                (push (list k x y) feats)))))
        (push (secure-hash 'md5 (prin1-to-string feats)) sigs)))
    (cl-assert (>= (length (delete-dups (copy-sequence sigs))) 3)
               "procgen variety over seeds"))

  ;; --- rewards default (R5 placeholder)
  (let* ((st (cistern--new-game 9))
         (result (cistern--rewards-eval st nil)))
    (cl-assert (equal (nth 1 result)
                      '(:score 0 :objectives nil :unlocks nil :celebrate nil)))
    (cl-assert (null (nth 2 result)) "empty presentation intents"))

  (message "CISTERN-SELFTEST-OK"))

(defun cistern-test-game--floor-run (st n)
  "L-007 fixture pattern: N consecutive unoccupied floor cells with
no plumbing 4-adjacent, so test networks stay isolated from the
starter plumbing."
  (let ((occ (cistern--occupied-cells st nil)))
    (catch 'found
      (cl-loop for y from 1 below (1- (cistern-st-h st)) do
               (cl-loop for x from 1 to (- (cistern-st-w st) 1 n) do
                        (when (cl-loop for i from 0 below n
                                       always (and (eq (cistern--cell st
                                                        (+ x i) y)
                                                       'floor)
                                                   (not (gethash (cons (+ x i) y)
                                                                 occ))
                                                   (not (cl-some
                                                         (lambda (nn)
                                                           (memq (cistern--cell st
                                                                  (car nn)
                                                                  (cdr nn))
                                                                 '(pipe toilet tank)))
                                                         (cons (cons (+ x i) y)
                                                               (cistern--neighbors
                                                                st (+ x i) y))))))
                          (throw 'found (list x y))))))))

(defun cistern--soak-adj-floor (st)
  "Floor cells 4-adjacent to existing plumbing: building there
joins the network instantly (cistern.el:1037-1049)."
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
network TOWARD the workforce instead of clustering it
(cistern.el:1051-1081)."
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
network when population demands it (cistern.el:1083-1137; the
'one breach from condemnation' tuning is kept intact)."
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

(provide 'cistern-game)
;;; cistern-game.el ends here
