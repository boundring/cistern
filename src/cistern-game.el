;;; cistern-game.el --- Use cases: player verbs, state in → state out -*- lexical-binding: t; -*-

;; Game/use-case layer (DESIGN-SPEC §3.3): pure signatures —
;; state + intent → state + log.  No buffers, faces, keymaps, timers,
;; no `cistern--st' global, no rendering.  Layer dependency is strictly
;; inward: this file requires cistern-domain and nothing else.

(require 'cl-lib)
(require 'cistern-domain (and load-file-name (expand-file-name "cistern-domain.el" (file-name-directory load-file-name))))

(defconst cistern-cost-demolish 3
  "Alloy cost of the demolish verb (R8).  Implementation-seed
value, pinned for testability per plan 01 §2.3; final pricing is
DEFERRED to REWARDS-DESIGN (spec §6).  The 50%-of-build-cost
refund is consumed in 4b (M1).")

(defun cistern--cmd-build (st kind x y)
  "Place KIND (toilet/pipe/tank) at (X,Y).  Ported verbatim from
cistern.el:498-525, rendered calls stripped."
  (let* ((type (and (eq kind 'toilet) (cistern-st-toilet-type st)))
         ;; V4-11: the catalog prices the armed fixture type
         (cost (pcase kind
                 ('toilet (plist-get (cistern--toilet-type-entry type) :cost))
                 ('pipe cistern-cost-pipe)
                 ('tank cistern-cost-tank))))
    ;; returns t on placement, nil on refusal (Q19: the driver's
    ;; arm-and-build arms only when the at-cursor build lands)
    (cond
     ((not (cistern--in-bounds-p st x y))
      (cistern--log st "OUT OF SECTOR") nil)
     ((not (eq (cistern--cell st x y) 'floor))
      (cistern--log st "CANNOT BUILD THERE")
      (setf (cistern-st-hint st)                       ; Q18: the hint
            (cdr (assq 'refusal-no-floor cistern--copy))) ; names the fix
      nil)
     ;; V4-11: catalog placement verdict — refuse before charging
     ((and (eq kind 'toilet)
           (not (eq t (cistern--toilet-place-verdict st x y type))))
      (cistern--log st (cdr (assq 'refusal-place cistern--copy))
                    (cistern--toilet-place-verdict st x y type))
      nil)
     ((gethash (cons x y) (cistern--occupied-cells st nil))
      (cistern--log st "WORKER IN THE WAY") nil)
     ((< (cistern-st-alloy st) cost)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED" cost)
      (setf (cistern-st-hint st)                       ; Q18: the hint
            (format (cdr (assq 'refusal-alloy cistern--copy)) cost))
      nil)
     (t
      (setf (cistern-st-alloy st) (- (cistern-st-alloy st) cost))
      (cistern--set-cell st x y kind)
      (puthash (cons x y) (cistern-st-tick st) (cistern-st-built-at st))
      (pcase kind
        ('toilet
         (puthash (cons x y) (list :busy nil :type type)
                  (cistern-st-toilets st))
         (setf (cistern-st-built-toilet st)
               (1+ (cistern-st-built-toilet st)))
         ;; V5-08 (SOCIAL §1.2): fixtures are persona-eligible at build
         (cistern--social-spawn-persona st (list :toilet x y) 'fixture))
        ('tank
         (puthash (cons x y) (list :load 0) (cistern-st-tanks st))
         (setf (cistern-st-built-tank st) (1+ (cistern-st-built-tank st)))
         ;; V5-08 (SOCIAL §1.2): tanks are persona-eligible at build
         (cistern--social-spawn-persona st (list :tank x y) 'tank))
        ('pipe
         (setf (cistern-st-built-pipe st) (1+ (cistern-st-built-pipe st)))))
      (cistern--log st "%s PLACED AT (%d,%d) — %d ALLOY"
                    (upcase (symbol-name kind)) x y cost)
      t))))

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
     ;; V4-05 (S3.2): rubble clears to floor for a lighter fee
     ((eq kind 'rubble)
      (cond
       ((< (cistern-st-alloy st) cistern-cost-clear)
        (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED"
                      cistern-cost-clear))
       (t
        (setf (cistern-st-alloy st) (- (cistern-st-alloy st)
                                       cistern-cost-clear))
        (cistern--set-cell st x y 'floor)
        (cistern--log st (cdr (assq 'rubble-cleared cistern--copy))
                      x y cistern-cost-clear))))
     ((not (memq kind '(pipe toilet tank)))
      (cistern--log st "NOT YOURS TO DEMOLISH"))
     ((and (eq kind 'toilet)
           (plist-get (gethash (cons x y) (cistern-st-toilets st)) :busy))
      (cistern--log st "TOILET IN USE"))
     ((< (cistern-st-alloy st) cistern-cost-demolish)
      (cistern--log st "INSUFFICIENT ALLOY — %d REQUIRED"
                    cistern-cost-demolish))
     (t
      (let* ((build-cost (pcase kind
                           ('toilet cistern-cost-toilet)
                           ('pipe cistern-cost-pipe)
                           ('tank cistern-cost-tank)))
             ;; Q30: the free regret window — demolishing in the same
             ;; tick the piece was placed refunds EVERYTHING (the fee
             ;; and the full build cost: the cycle costs nothing).
             ;; After a tick the M1 50% split returns (L-024 rounding).
             (regret (let ((bt (gethash (cons x y) (cistern-st-built-at st))))
                       (and bt (= bt (cistern-st-tick st)))))
             (refund (if regret
                         (+ cistern-cost-demolish build-cost)
                       (/ build-cost 2))))
        (setf (cistern-st-alloy st)
              (+ (- (cistern-st-alloy st) cistern-cost-demolish) refund))
        (remhash (cons x y) (cistern-st-toilets st))
        (remhash (cons x y) (cistern-st-tanks st))
        (remhash (cons x y) (cistern-st-built-at st))
        (cistern--set-cell st x y 'floor)
        ;; R2-Q05: the dust spawns AT THE DEMOLISH (zero tick delay),
        ;; obeying the Q25 particle contract: glyphs only from the M9
        ;; set, placement over the now-plain floor
        (let ((count (+ 3 (mod (cistern--particle-draw st) 3))))
          (dotimes (_ count)
            (let* ((g (cistern--particle-draw st))
                   (ttlp (+ 2 (mod (cistern--particle-draw st) 2)))
                   (vx (- (mod (cistern--particle-draw st) 3) 1))
                   (vy (- (mod (cistern--particle-draw st) 3) 1))
                   (glyph (nth (mod g 3) '("*" "!" "§"))))
              (cistern--field-spawn st (cons x y) (cons vx vy) ttlp
                                    glyph 'info 'sparkle))))
        (cistern--log st "DEMOLISHED %s AT (%d,%d) — %d ALLOY — %d REFUND"
                      (upcase (symbol-name kind)) x y
                      cistern-cost-demolish refund)
      ;; V5-10 (SOCIAL §1.4 row 7): the destruction as a located event
      (push (list 'destroyed 'destroyed x y)
            (cistern-st-rewards-events st))
      ;; V5-11 (SOCIAL §2.6): a demolished fixture/tank ceases as a
      ;; romance endpoint
      (when (memq kind '(toilet tank))
        (cistern--romance-end
         st (list (if (eq kind 'toilet) :toilet :tank) x y))))))))

(defun cistern--tutorial-steps (&optional table)
  "Tutorial mechanism holder: table of (PROMPT . PREDICATE) steps,
predicate takes ST and a non-nil result advances.  Scenario content
is Phase 4a; the table ships empty so advance is a no-op.  The
optional TABLE arg is the test-injection point (the shipped game
never passes one)."
  (or table
      ;; Q27: the shipped 3-step table — real predicates over state,
      ;; inspector-grade prompts from the Q11 copy table
      (list (cons (cdr (assq 'tutorial-1 cistern--copy))
                  (lambda (st)
                    (cl-find-if (lambda (w)
                                  (and (= (cistern--worker-x w)
                                          (car (cistern-st-cursor st)))
                                       (= (cistern--worker-y w)
                                          (cdr (cistern-st-cursor st)))))
                                (cistern-st-creators st))))
            (cons (cdr (assq 'tutorial-2 cistern--copy))
                  (lambda (st) (> (cistern-st-purges st) 0)))
            (cons (cdr (assq 'tutorial-3 cistern--copy))
                  (lambda (st) (> (cistern-st-alloy st) 20))))))

(defun cistern--tutorial-advance (st &optional table)
  "R2-Q11: the gate is PER-STEP — every step's predicate counts
each tick (a satisfied later step advances even when an earlier
one hasn't; purge-first players reach step 2 without step 1), the
index never regresses, and completing the final step sets the
index to `t' with the completion line."
  (let ((steps (cistern--tutorial-steps table))
        (idx (cistern-st-tutorial st)))
    (when (numberp idx)
      (let ((done (cl-count-if (lambda (step) (funcall (cdr step) st))
                               steps)))
        (when (> done idx)
          (setf (cistern-st-tutorial st) (if (>= done (length steps)) t done))
          (cistern--log st "%s"
                        (cdr (assq (if (>= done (length steps))
                                       'tutorial-complete
                                     'tutorial-step)
                                   cistern--copy))))))))

(defun cistern--cmd-skip-tutorial (st)
  "T skip (R4): mark the tutorial done so advance is a no-op.
Use-case form — the index is state and mutates here, never in the
driver (armed-verb precedent, L-010 pin 4)."
  (setf (cistern-st-tutorial st) t)
  (cistern--log st "%s" (cdr (assq 'tutorial-skipped cistern--copy))))

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
      ;; V4-05 retune (procgen gained rubble/manifold, shifting the
      ;; old corridor run): seat the need ON the starter cluster —
      ;; each new toilet is a direct floor neighbor of the already-
      ;; wired starter pipes, so no extra pipe alloy is spent
      (verb . ,(lambda (st) (cistern--cmd-build st 'toilet 4 1)))
      (verb . ,(lambda (st) (cistern--cmd-build st 'toilet 4 3)))
      (verb . ,(lambda (st) (cistern--cmd-build st 'toilet 2 2)))
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
                              (string-match-p (downcase val)
                                              (downcase (car line))))
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

;; ---------------------------------------------------------------------------
;; V4-16/V4-17 (STORY §6/§7/§8): story evaluation.  ONE call per tick,
;; before rewards-eval (§1 pinned ordering); reads pending events,
;; drains NOTHING (rewards-eval stays the sole drainer).  Stream 2
;; only (:roll-pos); the sim LCG and particle stream are forbidden
;; (S7 — asserted in tests).

(defun cistern--story-stat (st stat)
  "STORY §6.1: banded story stats (−2..+2) read existing state."
  (pcase stat
    ('tolerance
     (let* ((story (cistern-st-story st))
            (cast (plist-get story :cast))
            (w (nth (car (car cast)) (cistern-st-creators st)))
            (ttb (/ (- 120 (cistern--worker-bladder w)) 2)))
       (cond ((<= ttb 6) -2) ((<= ttb 18) 0) (t 2))))
    ('integrity
     (cond ((cistern--toilets-severed-p st) -2)
           ((cistern--toilets-backed-up-p st) -1)
           ((and (> (cistern--tank-capacity-total st) 0)
                 (>= (cistern--tank-load-max st)
                     (* 0.85 (cistern--tank-capacity-total st)))) 0)
           (t 2)))
    ('standing
     (let ((rep (cistern-st-reputation st)))
       (cond ((>= rep 80) 2) ((>= rep 50) 1) (t 0))))))

(defun cistern--story-condition-p (st h events)
  "Does hook H's :condition hold this tick (STORY §7.1/§7.5)?
Events are the pending tick event kinds."
  (let ((c (plist-get h :condition)))
    (pcase (car c)
      ('event (memq (cadr c) events))
      ('tick t)
      ('stat-band
       (let ((band (cistern--story-stat st (cadr c))))
         (pcase (nth 2 c)
           ('>= (>= band (nth 3 c)))
           ('<= (<= band (nth 3 c)))
           (_ nil)))))))

(defun cistern--story-draw (st n)
  "One stream-2 draw in [0,N) (bit-6 slice), advancing :roll-pos."
  (let* ((story (cistern-st-story st))
         (p (cistern--stream-next (plist-get story :roll-pos))))
    (plist-put story :roll-pos p)
    (% (ash p -6) n)))

(defun cistern--story-render (story h)
  "The hook's resolution line (§7.3): the required hook HELD or
BREACHED rides the callback variant; a MISSED requirement renders
the -fallback standalone variant."
  (let* ((req (plist-get h :requires))
         (key (plist-get h :resolve-copy))
         (req-hook (and req
                        (cl-find req (plist-get story :hooks)
                                 :key (lambda (x) (plist-get x :id)))))
         (req-state (and req-hook (plist-get req-hook :state)))
         (req-as (and req-hook (plist-get req-hook :resolved-as))))
    (cond ((and req-hook (eq req-state 'resolved))
           (format (cistern--story-copy-key key)
                   (if (eq req-as 'pass) "HELD" "BREACHED")))
          ((and req-hook (eq req-state 'missed))
           (cistern--story-copy-key
            (intern (concat (symbol-name key) "-fallback"))))
          (t (cistern--story-copy-key key)))))

(defun cistern--story-pick-floor (st)
  "One stream-2 draw picks the unoccupied floor cell a story
effect lands on (STORY §6.4); :roll-pos advances only when a
floor exists.  Returns the (X . Y) cell or nil."
  (let ((floors nil) (i 0))
    (while (< i (length (cistern-st-map st)))
      (when (eq (aref (cistern-st-map st) i) 'floor)
        (push (cons (% i (cistern-st-w st)) (/ i (cistern-st-w st)))
              floors))
      (cl-incf i))
    (when floors
      (let* ((p (cistern--stream-next
                 (plist-get (cistern-st-story st) :roll-pos)))
             (cell (nth (% (ash p -6) (length floors))
                        (nreverse floors))))
        (plist-put (cistern-st-story st) :roll-pos p)
        cell))))

(defun cistern--story-apply-effect (st outcome cell)
  "STORY §6.4: commit-first application of the sim-visible
effects.  Returns presentation intents (popup), possibly nil."
  (let ((effect (plist-get outcome :effect))
        (arg (plist-get outcome :arg)))
    (pcase effect
      ('hazard-spawn
       (let ((cell2 (cistern--story-pick-floor st)))
         (when cell2
           (cistern--add-hazard st (car cell2) (cdr cell2)))))
      ('tank-load-delta
       (let ((tk nil) (ks nil))
         (maphash (lambda (k _v) (push k ks))
                  (cistern-st-tanks st))
         (setq ks (sort ks (lambda (a b)
                             (or (< (car a) (car b))
                                 (and (= (car a) (car b))
                                      (< (cdr a) (cdr b)))))))
         (setq tk (car ks))
         (when tk
           (let ((cap cistern-tank-cap))
             (puthash tk
                      (list :load (min cap
                                       (max 0 (+ (or arg 0)
                                                 (plist-get
                                                  (gethash tk
                                                           (cistern-st-tanks st))
                                                  :load)))))
                      (cistern-st-tanks st))))))
      ('alloy-grant
       (setf (cistern-st-alloy st) (+ (cistern-st-alloy st) (or arg 0))))
      ('tile-place
       ;; V4-22 (S3.1): the story beat lands an ! event tile — the
       ;; cell is stream-2-picked floor
       (let ((cell2 (cistern--story-pick-floor st)))
         (when cell2
           (cistern--add-event-tile st (car cell2) (cdr cell2)))))
      ('popup
       (cistern--field-spawn st cell (cons 0 -1) 3
                             (or (and (stringp arg) arg) "NOTED")
                             'success 'popup))
      (_ nil))
    nil))

(defun cistern--story-eval (st)
  "STORY §6-§8: one story evaluation per tick.  Reads pending
events, drains nothing; advances the hook state machine
(dormant → armed → open → resolved|missed) with §7.2 force-miss at
act rollover; applies effects commit-first; returns (st . intents)
with at most ONE story banner."
  (let ((story (cistern-st-story st))
        (intents nil))
    (when story
      (let* ((tick (cistern-st-tick st))
             (tick-act (cistern--story-tick-act tick))
             (act (plist-get story :act))
             (hooks (plist-get story :hooks))
             (events (mapcar #'cistern--event-kind
                             (cistern-st-rewards-events st)))
             (ev-cell (let ((ev (cl-find-if #'consp
                                            (cistern-st-rewards-events st))))
                        (and ev (>= (length ev) 4)
                             (cons (nth 2 ev) (nth 3 ev)))))
             (cell (or ev-cell (cistern-st-cursor st))))
        ;; §7.2 act rollover: force-resolve armed/open hooks as
        ;; missed, THEN open the next act (the story can fall behind
        ;; the player; it can never fall apart)
        (when (> tick-act act)
          (dolist (h hooks)
            (when (and (memq (plist-get h :state) '(armed open))
                       (= (plist-get h :act) act))
              (plist-put h :state 'missed)
              (plist-put h :resolved-as 'missed)
              (push h (plist-get story :callbacks))))
          (plist-put story :act tick-act)
          (setq act tick-act))
        (dolist (h hooks)
          (let ((hact (plist-get h :act))
                (win (plist-get h :window))
                (state (plist-get h :state)))
            ;; arm at the hook's act open
            (when (and (= hact act) (eq state 'dormant))
              (plist-put h :state 'armed)
              (setq state 'armed))
            ;; §7.1: armed → missed when the window closes
            (when (and (eq state 'armed) (> tick (cdr win)))
              (plist-put h :state 'missed)
              (plist-put h :resolved-as 'missed)
              (setq state 'missed))
            ;; §7.1: armed + condition + window → open + resolve
            (when (and (eq state 'armed)
                       (>= tick (car win)) (<= tick (cdr win))
                       (cistern--story-condition-p st h events))
              (plist-put h :state 'open)
              ;; §7.5: tier draw, then roll — pinned order, stream 2
              (let* ((tiers (plist-get (plist-get story :scenario) :tiers))
                     (tdraw (cistern--story-draw st 100))
                     (tier (cond ((< tdraw (nth 0 tiers)) 'common)
                                 ((< tdraw (+ (nth 0 tiers) (nth 1 tiers)))
                                  'occasional)
                                 (t 'rare)))
                     (m (cl-find (plist-get h :matrix)
                                 (plist-get (plist-get story :scenario)
                                            :matrices)
                                 :key (lambda (x) (plist-get x :id))))
                     (diff (+ (plist-get m :difficulty)
                              (nth (1- act) (plist-get m :act-mods))))
                     (roll (cistern--story-draw st 20))
                     (stat (cistern--story-stat st (plist-get m :stat)))
                     (margin (+ roll stat (- diff)))
                     (band (cistern--margin-band margin))
                     ;; V4-19: one shared hash serves both sources
                     (outcome (cistern--matrix-effect
                               (plist-get m :id) band))
                     (line-key (plist-get outcome :line-key))
                     (effect (plist-get outcome :effect)))
                (plist-put h :state 'resolved)
                (plist-put h :resolved-as (if (>= band 2) 'pass 'fail))
                (plist-put h :tick tick)
                (plist-put h :tier tier)
                ;; callbacks list: resolved hook ids, visible to later acts
                (plist-put story :callbacks
                           (cons (plist-get h :id)
                                 (plist-get story :callbacks)))
                ;; commit-first: sim-visible effects apply here
                (cistern--story-apply-effect st outcome cell)
                ;; presentation: hook verdict line + outcome line
                (let* ((line (cistern--story-render story h))
                       (face (if (>= band 2) 'success 'error)))
                  (when line
                    (push (list :layer 'log :text line :face face)
                          intents))
                  (let ((oline (cistern--story-copy-key line-key)))
                    (when oline
                      (push (list :layer 'log :text oline :face face)
                            intents))))))))
        ;; §8.3: the premise banner announces once at Act I's first
        ;; rendered tick — :announced makes it once per game, so the
        ;; banner budget holds by construction
        (when (and (null (plist-get story :announced)) (> tick 0))
          (plist-put story :announced t)
          (push (list :layer 'banner
                      :text (concat (cistern--story-copy-key
                                     (plist-get (plist-get story
                                                          :scenario)
                                                :premise))
                                    "\n"))
                intents))
        (plist-put story :intents (nreverse intents))))
    (cons st intents)))

;; ---------------------------------------------------------------------------
;; V4-19/§2 (wave 3): dialogue evaluation.  Runs AFTER story-eval and
;; BEFORE rewards-eval (§1 pinned order); draws stream 2 AFTER
;; story-eval completes its draws; drains nothing; emits only faced
;; log intents (§2.6 — never banner, never popup); ≤1 line per tick.

(defun cistern--dialogue-cast-worker (st story sel-kind sel-arg)
  "Resolve one flat :pair selector (SEL-KIND SEL-ARG) against the
story cast (§2.3): (stat S) → the cast member with the highest S
score (ties break in cast order); (quirk Q) → the cast member
carrying quirk Q."
  (let* ((cast (plist-get story :cast))
         (workers (cistern-st-creators st))
         (pick (pcase sel-kind
                 ('stat
                  (let ((best -99) (bi 0)
                        (si (cl-position
                             (intern (upcase (symbol-name sel-arg)))
                             cistern--rpg-stat-names)))
                    (dotimes (i (length cast))
                      (let* ((ci (car (nth i cast)))
                             (w (nth ci workers))
                             (score (nth si (cistern--worker-stats w))))
                        (when (> score best) (setq best score bi i))))
                    bi))
                 ('quirk
                  (let ((bi 0))
                    (dotimes (i (length cast))
                      (when (eq (cdr (nth i cast)) sel-arg) (setq bi i)))
                    bi))
                 (_ 0))))
    (nth (car (nth pick cast)) workers)))

(defconst cistern--dialogue-cooldown 60
  "STORY §2.5: pinned default tree cooldown in ticks.")

(defun cistern--dialogue-eligible-p (st tree)
  "§2.5: act reached, gate hook in the gated state (resolved
default; :as pass|fail pins the verdict), cooldown honored."
  (let* ((story (cistern-st-story st))
         (act (plist-get story :act))
         (tick (cistern-st-tick st))
         (gate (plist-get tree :gate))
         (hook (cl-find (car gate) (plist-get story :hooks)
                        :key (lambda (x) (plist-get x :id))))
         (want (or (cdr gate) 'resolved)))
    (and (>= act (plist-get tree :act))
         hook
         (or (eq want 'open) (eq (plist-get hook :state) 'resolved))
         (if (eq want 'open)
             t
           (if (plist-get tree :as)
               (eq (plist-get hook :resolved-as) (plist-get tree :as))
             t))
         (let ((last (cdr (assq (plist-get tree :id)
                                (plist-get (plist-get story :dlg) :cooldowns)))))
           (or (null last) (>= (- tick last)
                               cistern--dialogue-cooldown))))))

(defun cistern--dialogue-eval (st)
  "STORY §2.4-§2.6: at most ONE tree opens per tick; an open
conversation delivers ONE line per tick; branch rolls consume
stream 2 at open (tier-free: band 0..3 → :next index).  Drains
nothing; emits only faced log intents (info severity)."
  (let ((story (cistern-st-story st))
        (intents nil))
    (when (and story cistern--banks)
      (let ((dlg (plist-get story :dlg)))
        (cond
         ;; deliver one pending line
         ((and dlg (plist-get dlg :pending))
          (push (list :layer 'log :text (car (plist-get dlg :pending))
                      :face 'info)
                intents)
          (plist-put dlg :pending (cdr (plist-get dlg :pending))))
         ;; open a new tree
         (cistern--banks
          (let* ((act (plist-get story :act))
                 (drift (nth (1- act) cistern--story-tier-drift))
                 ;; §7.5: ONE stream-2 draw selects the tier band
                 ;; (weights 60/30/10+drift); the matching tree fires
                 (tier-draw (cistern--story-draw st (+ 100 drift)))
                 (tier (cond ((< tier-draw 60) 'common)
                             ((< tier-draw 90) 'occasional)
                             (t 'rare)))
                 (chosen nil))
            (dolist (tree (plist-get cistern--banks :dialogues))
              (unless chosen
                (when (and (plist-get tree :root)
                           (eq (plist-get tree :tier) tier)
                           (cistern--dialogue-eligible-p st tree))
                  (setq chosen tree))))
            (when chosen
              (let* ((tick (cistern-st-tick st))
                     (dlg2 (or dlg (list :cooldowns nil)))
                     (root chosen)
                     (participants
                      (let ((sel (plist-get chosen :pair)) (out nil))
                        (while sel
                          (push (cistern--dialogue-cast-worker
                                 st story (car sel) (cadr sel)) out)
                          (setq sel (cddr sel)))
                        (nreverse out)))
                     (glyphs (mapcar (lambda (w)
                                       (cistern--worker-glyph st w))
                                     participants))
                     (branch-stats
                      (let ((sel (plist-get chosen :pair)) (out nil))
                        (while sel
                          (when (eq (car sel) 'stat)
                            (let* ((w (cistern--dialogue-cast-worker
                                       st story 'stat (cadr sel)))
                                   (si (cl-position
                                        (intern
                                         (upcase (symbol-name (cadr sel))))
                                        cistern--rpg-stat-names)))
                              (push (cons (cadr sel)
                                          (cistern--rpg-stat-mod w si))
                                    out)))
                          (setq sel (cddr sel)))
                        out))
                     (rootline
                      (cistern--story-fill (cistern--story-copy-key
                                            (plist-get root :line))
                                           glyphs))
                     ;; walk the branch chain at open: one roll per
                     ;; interior node, band → :next index; every node's
                     ;; line queues for one-per-tick delivery
                     (pending (list rootline))
                     (node root)
                     (rolls 0))
                (while (plist-get node :branch)
                  (let* ((br (plist-get node :branch))
                         (stat (or (cdr (assq (plist-get br :stat)
                                              branch-stats))
                                   0))
                         (roll (cistern--story-draw st 20))
                         (margin (+ roll stat
                                    (- (plist-get br :difficulty))))
                         (band (cistern--margin-band margin))
                         (next (nth band (plist-get br :next)))
                         (nnode (cl-find next
                                         (plist-get cistern--banks
                                                    :dialogues)
                                         :key (lambda (x)
                                                (plist-get x :id)))))
                    (setq rolls (1+ rolls))
                    (setq node nnode)
                    (when node
                      (push (cistern--story-fill
                             (cistern--story-copy-key
                              (plist-get node :line))
                             glyphs)
                            pending))))
                (setq pending (nreverse pending))
                (plist-put story :dlg
                           (list :tree (plist-get chosen :id)
                                 :pending (cdr pending)
                                 :cooldowns
                                 (cons (cons (plist-get chosen :id) tick)
                                       (plist-get dlg2 :cooldowns))))
                ;; the ROOT line delivers this tick
                (push (list :layer 'log :text (car pending) :face 'info)
                      intents))))))))
    (cons st intents)))

(defun cistern--story-fill (line glyphs)
  "Fill the line's %s slots with the cast glyphs in order."
  (if (and glyphs (string-match-p "%s" line))
      (let ((i (string-match "%s" line)))
        (cistern--story-fill
         (concat (substring line 0 i) (car glyphs)
                 (substring line (+ i 2)))
         (cdr glyphs)))
    line))

(defun cistern--do-tick (st)
  "Exactly one tick per action (R6): over-guard, then one domain
sim tick, then the tutorial advance.  The legacy multi-tick
command is NOT ported — no way to advance more than one tick per
call exists at the use-case layer."
  (unless (cistern-st-over st)
    ;; R2-Q11 (a): the step predicates check BEFORE the wander phase
    ;; — a chased worker cannot escape mid-tick
    (cistern--tutorial-advance st)
    (cistern--sim-tick st)
    ;; V4-16 (STORY §8.1, §1 pinned ordering): ONE story-eval call
    ;; BEFORE rewards-eval — reads pending events, drains nothing
    ;; V4-16/§2 (§1 pinned ordering): story-eval completes ALL its
    ;; draws, then social-eval, then comedy-eval, then dialogue-eval
    ;; draws, then rewards-eval (the sole drainer, L-027)
    (let* ((story-out (cistern--story-eval st))
           ;; V5 close-fix (L-107): social-eval WAS defined-but-never-
           ;; called — the gate caught it.  Wired here per §1: reads
           ;; pending events WITHOUT draining, draws on stream 5 only.
           (social-out (cistern--social-eval st))
           ;; V5-13 (COMEDY §1): comedy-eval slots after social-eval,
           ;; before dialogue-eval — the §1 pinned chain; arbitration
           ;; reads story's returned intents (§5.3)
           (comedy-out (cistern--comedy-eval st (cdr story-out))))
      (let ((dlg-out (cistern--dialogue-eval st)))
        ;; per-tick rewards evaluation (L-027 wiring): runs ONCE per
        ;; tick, after the sim phases (the tutorial advance runs
        ;; first, R2-Q11); stores outcome+intents in state for the
        ;; view to read
        (cistern--rewards-eval st nil)
        ;; the story's + dialogue's intents append to the stored
        ;; intent list — one stored slot, one render read, zero new
        ;; view query paths
        (setf (cistern-st-rewards-outcome st)
              (cons (car (cistern-st-rewards-outcome st))
                    (append (cdr (cistern-st-rewards-outcome st))
                            (cdr story-out)
                            ;; L-108 #1: comedy-out was bound then
                            ;; dropped — its intents ride the merge
                            ;; (comedy-eval returns the plain intent
                            ;; list, no (head . intents) 2-list)
                            comedy-out
                            (cdr dlg-out))))
        ;; L-108 #2 (LOG-AT-SOURCE): every :layer 'log intent lands
        ;; in the domain log ring as a Q13 (LINE SEVERITY TICK)
        ;; entry — story verdicts, dialogue lines and comedy beats
        ;; become reviewable history (the L browser renders them);
        ;; banner/popup intents keep their own layers
        (dolist (intent (cdr (cistern-st-rewards-outcome st)))
          (when (eq (plist-get intent :layer) 'log)
            (cistern--log-sev st (plist-get intent :face) "%s"
                              (plist-get intent :text))))))))

(defconst cistern--rewards-default-outcome
  '(:score 0 :objectives nil :unlocks nil :celebrate nil)
  "Outcome skeleton (spec §4 R5; REWARDS-DESIGN §5).  4b
consumption fills :score/:unlocks/:celebrate per tick;
:objectives stays the pinned nil placeholder (no per-goal outcome
surface exists — card state is read from the goal card itself).")

(defun cistern--rewards-eval (st raw-events)
  "Rewards use-case (R5): consumes the events emitted since the
last read — ST's pending list (drained here; rewards-eval stays
the SOLE drainer, L-027) plus RAW-EVENTS — mechanic by mechanic
per REWARDS-DESIGN: M1 dust (child stream, never the sim LCG),
M3 goal-card evaluation + MapCompleted, M9 ceremony fill, M4
reputation, M5 relieve-pay + popups, M7 faced log intents, M8
milestone ladder.
Stores (outcome . intents) in state for the view to read (L-027);
do-tick appends the story-eval and dialogue-eval intents to the
stored list before the view's next read (V4-SPEC §1.1).  Returns
the (ST OUTCOME INTENTS) 3-list for tests; the view never calls
this."
  (let ((intents nil)
        (celebrate nil)
        (ceremony-p nil)
        ;; the tick's events: pending list + caller arguments, merged
        (events (append (cistern-st-rewards-events st) raw-events)))
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
                                (plist-put
                                 (plist-put g :satisfied
                                            (if (eq kind 'relieves-served)
                                                (>= value target)
                                              (<= value target)))
                                 ;; R2-Q04: claimed-only readout — a
                                 ;; goal, once satisfied, stays counted;
                                 ;; the ceiling at contamination zero is
                                 ;; not yet claimed (nothing achieved).
                                 ;; :satisfied and the completion check
                                 ;; below are untouched.
                                 :claimed
                                 (or (plist-get g :claimed)
                                     (and (plist-get g :satisfied)
                                          (not (and (eq kind
                                                       'contamination-ceiling)
                                                    (= (cistern-st-contam st)
                                                       0))))))))
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
            (setq intents (cistern--narrate-goals st card intents))
            (push (list :layer 'banner :text "MAP COMPLETED") intents))
          (setf (cistern-st-goal-card st) card))))
    ;; M9 ceremony fill (§4 M9 row): up to K=64 ttl-6 static sparkles
    ;; across the map, glyphs from the M9 row — spawned at the trigger
    ;; evaluation; the ttl-6 decay IS the ceremony duration (no
    ;; separate timer), and no modal state exists (commit-first: input
    ;; works throughout, skipping forfeits nothing)
    (when ceremony-p
      (let ((room (- cistern--field-cap (length (cistern-st-particles st)))))
        ;; Q25: sparkles spawn ONLY over plain floor — pipes, walls,
        ;; toilets and tanks stay visible under the ceremony — and the
        ;; glyph set drops the floor dot and bare digits
        (while (> room 0)
          (let* ((x (+ 1 (mod (cistern--particle-draw st) (- cistern-w 2))))
                 (y (+ 1 (mod (cistern--particle-draw st) (- cistern-h 2)))))
            (when (eq (cistern--cell st x y) 'floor)
              (let* ((g (mod (cistern--particle-draw st) 3))
                     (glyph (cond ((= g 0) "*") ((= g 1) "!") (t "§"))))
                (cistern--field-spawn st (cons x y) (cons 0 0) 6
                                      glyph 'info 'sparkle)
                (setq room (1- room))))))))
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
    ;; V4-12 (RPG §4, S3): clearance-up fires an at-the-act popup —
    ;; a field particle over the worker, same grammar as relieve-pay
    (dolist (e events)
      (when (and (consp e) (eq (cistern--event-kind e) 'clearance))
        (cistern--field-spawn st (cons (nth 2 e) (nth 3 e)) (cons 0 -1) 3
                              "CLEARANCE UP" 'success 'popup)))
    ;; M7 log grammar: events log at their source sites (domain
    ;; cistern--log-sev); the faced log intents are the stored slot's
    ;; assertion surface (the log-tail faces entries by severity, Q13
    ;; — it does NOT match these intents).  Banners: the M3 intent.
    (dolist (e events)
      (let ((sev (cistern--event-severity e)))
        (when (and (consp e) sev (not (eq sev 'game-changing)))
          (let ((line (pcase (cistern--event-kind e)
                        (`relief (format (cdr (assq 'relief-log
                                                   cistern--copy))
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
          (setq intents (cistern--announce-unlock st unlock intents))
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

(defun cistern--announce-unlock (st unlock intents)
  "Q05: announce UNLOCK at the tick of the act — the line enters
the log (history) and rides the log-tail face plus the banner row
of the SAME frame.  Commit-first: the unlock itself is committed
by the caller before this runs.  Returns the extended INTENTS."
  (let ((line (format "MILESTONE — %s"
                      (cdr (assq unlock
                                 (cdr (assq 'milestone cistern--copy)))))))
    (cistern--log-sev st 'success "%s" line)
    (push (list :layer 'log :text line :face 'success) intents)
    (push (list :layer 'banner :text line) intents)
    (push (list 'unlock :id unlock) intents)))

(defun cistern--narrate-goals (st card intents)
  "Q24: log each satisfied goal of CARD as GOAL MET (success
face) BEFORE the completion banner.  Returns the extended
INTENTS."
  (dolist (g (plist-get card :goals) intents)
    (let* ((kind (plist-get g :kind))
           (key (pcase kind
                  (`relieves-served 'goal-met-served)
                  (`bursts-allowed 'goal-met-bursts)
                  (`contamination-ceiling 'goal-met-ceiling)))
           (line (format (cdr (assq key cistern--copy))
                         (plist-get g :target))))
      (cistern--log-sev st 'success "%s" line)
      (push (list :layer 'log :text line :face 'success) intents))))

(defun cistern--particle-draw (st)
  "Advance ST's particle child stream by one raw step, returning
it.  The stream position lives in state (§4 ParticleField.rng)."
  (setf (cistern-st-particle-rng st)
        (cistern--stream-next (cistern-st-particle-rng st))))

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

(defun cistern--cmd-cursor-goto (st x y)
  "V4-02 (SURFACE S1.2): place the cursor directly at (X,Y) — the
log browser's RET jump-to-source landing.  Out-of-bounds cells are
refused (cursor stays put), mirroring `cistern--cmd-cursor'."
  (when (cistern--in-bounds-p st x y)
    (setf (cistern-st-cursor st) (cons x y))))

(defun cistern--cmd-cursor-scan (st dir)
  "V4-07 (SURFACE S4.2): jump the cursor to the next (or previous)
structure — toilets, tanks, manifolds — in scan order (y then x),
wrapping.  The emacs word-motion reading of the grid."
  (let ((cells nil))
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (when (memq (cistern--cell st x y) '(toilet tank manifold))
          (push (cons x y) cells))))
    (setq cells
          (nreverse
           (sort cells (lambda (a b)
                         (or (< (cdr a) (cdr b))
                             (and (= (cdr a) (cdr b)) (< (car a) (car b))))))))
    (when cells
      (let* ((cur (cistern-st-cursor st))
             (pos (cl-position cur cells :test #'equal))
             (idx (if (null pos)
                      (if (eq dir 'next) 0 (1- (length cells)))
                    (if (eq dir 'next)
                        (% (1+ pos) (length cells))
                      (% (+ pos (1- (length cells))) (length cells))))))
        (setf (cistern-st-cursor st) (nth idx cells))))))

(defun cistern--cmd-cursor-capacity (st)
  "V4-07 (SURFACE S4.2): the game's C-s — cursor to the nearest
free usable toilet (manhattan, Q20 geometry); else the nearest
usable toilet; else refuse with the capacity-none hint and move
nothing."
  (let ((best nil) (best-d nil))
    (maphash (lambda (k _)
               (when (cistern--toilet-usable-p st (car k) (cdr k))
                 (let* ((cur (cistern-st-cursor st))
                        (d (+ (abs (- (car k) (car cur)))
                              (abs (- (cdr k) (cdr cur))))))
                   (when (or (not best) (< d best-d))
                     (setq best k best-d d)))))
             (cistern-st-toilets st))
    (if best
        (setf (cistern-st-cursor st) best)
      (setf (cistern-st-hint st)
            (cdr (assq 'capacity-none cistern--copy))))))

(defun cistern--cmd-click (st x y)
  "R1 use-case half: a click at (X,Y).  No build verb armed: the
cursor moves and the clock does NOT tick (R6 names only
SPACE/RET/click-with-verb as ticking actions).  Build verb armed:
place via `cistern--cmd-build' legality at (X,Y); on success clear
the armed verb and advance exactly one tick; on refusal the state
is untouched.  The keymap half that arms verbs is Phase 3."
  (let ((verb (cistern-st-armed-verb st)))
    (cond
     ;; V5-06 (COMBAT §4.5): the violent base's designations ride the
     ;; same armed-verb pattern — arm -> badge -> click.  No tick: the
     ;; player shapes WHERE, the sim does the walking; a refusal keeps
     ;; the verb armed (R7 verdict style).
     ((eq verb 'focus)
      (when (cistern--cmd-focus st x y)
        (setf (cistern-st-armed-verb st) nil)))
     ((eq verb 'rally)
      (when (cistern--cmd-rally st x y)
        (setf (cistern-st-armed-verb st) nil)))
     ((not (memq verb '(toilet pipe tank)))
        (setf (cistern-st-cursor st) (cons x y))
      )
     (t
      (cistern--cmd-build st verb x y)
      ;; placed ⇔ cmd-build turned the floor cell into the verb kind
      (when (eq (cistern--cell st x y) verb)
        (setf (cistern-st-armed-verb st) nil)
        (cistern--do-tick st))))))

(defun cistern--cmd-rally (st x y)
  "V5-06 (COMBAT §4.5): RALLY to a floor cell — every non-seated
worker's `journey' is set there; seated/using workers are exempt.
The walk happens in the creators phase; arrival clears the journey
and the worker resumes seek-work.  No roll.  Returns t when the
rally lands, nil (with the standard floor refusal hint) otherwise."
  (if (not (eq (cistern--cell st x y) 'floor))
      (progn
        (setf (cistern-st-hint st)
              (cdr (assq 'refusal-no-floor cistern--copy)))
        nil)
    (dolist (w (cistern-st-creators st))
      (unless (cistern--worker-using w)
        (setf (cistern--worker-journey w) (cons x y))))
    t))

(defun cistern--cmd-arm-verb (st verb)
  "Arm the build VERB in state (R1 keymap half; L-010 pin 4 — the
armed verb is set/cleared BY USE-CASES: this sets it, cmd-click
clears it on placement).  No arming setter may exist in the driver
or adapter layers (L-013: no second arming site)."
  (setf (cistern-st-armed-verb st) verb))

(defun cistern--cmd-disarm (st)
  "Clear the armed build verb (Q19).  Armed state never blocks
input (PROTECT: no modal) — disarming is a plain use-case
mutation, mirroring `cistern--cmd-arm-verb'."
  (setf (cistern-st-armed-verb st) nil)
  st)

(defun cistern--cmd-focus (st x y)
  "V5-05 (COMBAT §3.5/§4.5): the FOCUS designation on the hostile
at (X,Y) — the auto-defense targets it first.  A guild entity
REFUSES with `combat-refusal-friendly' (the R7 verdict style):
no state change, NO draw consumed.  Returns t when the focus
lands, nil on refusal or empty cell."
  (let ((e (cl-find-if (lambda (e)
                         (and (= x (cistern--enemy-x e))
                              (= y (cistern--enemy-y e))))
                       (cistern-st-hostiles st))))
    (cond
     ((null e) nil)
     ((eq (cistern--enemy-faction e) 'guild)
      (cistern--log st "%s"
                    (cistern--combat-copy 'combat-refusal-friendly))
      nil)
     (t
      (setf (cistern-st-focus st) (cistern--enemy-id e))
      t))))

;; ---------------------------------------------------------------------------
;; V5-10 (SOCIAL §1.4-1.6): the thought pipeline.  ONE pass per tick
;; (wired at the do-tick chain, L-107); reads pending events
;; WITHOUT draining (rewards-eval stays the sole drainer, L-027);
;; content draws on stream 5 only; budgets: <= 1 thought per entity
;; per tick, <= 4 sector-wide, <= 2 mutters, ledger cap 3.

(defconst cistern--social-mutter-cap 2
  "SOCIAL §1.6: <= 2 muttered log lines per tick, sector cap.")

(defconst cistern--social-thought-cap 4
  "SOCIAL §1.6: <= 4 thought generations per tick, sector-wide.")

(defun cistern--social-ledger-push (st id key)
  "Append (TICK 'private KEY) to the persona's ledger — newest
first, cap 3, FIFO eviction (SOCIAL §1.2/§1.5)."
  (let* ((p (gethash id (cistern-st-personas st)))
         (ledger (cons (list (cistern-st-tick st) 'private key)
                       (plist-get p :ledger))))
    (puthash id (plist-put p :ledger
                           (if (> (length ledger) 3)
                               (butlast ledger) ledger))
             (cistern-st-personas st))))

(defun cistern--social-thought-bank (class species mood)
  "Thought bank entries matching (class, species, mood-or-any);
goblin and pest share the census content slots."
  (cl-remove-if-not
   (lambda (e)
     (and (eq (plist-get e :class) class)
          (memq (plist-get e :species)
                (list species
                      (and (eq species 'goblin) 'pest)
                      (and (eq species 'pest) 'goblin)
                      'worker
                      (and (eq species 'fixture) 'tank)
                      (and (eq species 'tank) 'fixture)))
          (memq (plist-get e :when) (list mood 'any))))
   (plist-get cistern--banks :thoughts)))

(defun cistern--social-thoughts (st)
  "V5-10: one thought generation pass over the trigger table.
Reads pending events WITHOUT draining (rewards-eval stays the
sole drainer, L-027); content draws on stream 5 only; budgets:
<= 1 thought per entity per tick, <= 4 sector-wide, <= 2 mutters,
over-budget mutters downgrade to private without a redraw; urges
set the persona flag with no text and no draw (ttl 1 tick)."
  (when (and (cistern-st-personas st)
             (plist-get cistern--banks :thoughts))
    (let ((made 0) (mutters 0) (seen nil)
          (events (cistern-st-rewards-events st))
          (cheby (lambda (a b)
                   (max (abs (- (car a) (car b)))
                        (abs (- (cdr a) (cdr b)))))))
      (cl-labels
          ((deliver (id species class)
             (when (and (< made cistern--social-thought-cap)
                        (not (member id seen))
                        (gethash id (cistern-st-personas st)))
               (let* ((mood (cistern--social-mood st id))
                      (bank (cistern--social-thought-bank
                             class species mood)))
                 (when bank
                   (push id seen)
                   (setq made (1+ made))
                   (if (memq class cistern--social-urge-classes)
                       (let ((p (gethash id (cistern-st-personas st))))
                         (puthash id (plist-put (plist-put p :urge t)
                                                :urge-tick
                                                (cistern-st-tick st))
                                  (cistern-st-personas st)))
                     (let* ((entry (nth (cistern--social-select
                                         st (length bank))
                                        bank))
                            (key (plist-get entry :copy-key))
                            (chan (cistern--social-channel class species)))
                       (cond
                        ((and (eq chan 'mutter)
                              (< mutters cistern--social-mutter-cap))
                         (cistern--log-sev
                          st 'info "%s"
                          (format (cistern--social-copy
                                   'social-mutter-fmt)
                                  id (concat "\""
                                             (cistern--story-copy-key
                                              key)
                                             "\"")))
                         (push (list :social 'mutter :speaker id :key key)
                               (cistern-st-rewards-events st))
                         (setq mutters (1+ mutters)))
                        ((eq chan 'file)
                         (cistern--log-sev
                          st 'info "%s"
                          (format (cistern--social-copy 'social-file-fmt)
                                  id (upcase (symbol-name class)))))
                        (t
                         (cistern--social-ledger-push st id key))))))))))
        ;; rows 1-2 + 6-7: located events drive their rows in order
        (dolist (ev events)
          (let ((kind (cistern--event-kind ev)))
            (cond
             ((eq kind 'breach)
              (let ((bx (nth 2 ev)) (by (nth 3 ev)))
                (maphash
                 (lambda (id _p)
                   (when (and (consp id) (eq (car id) :toilet)
                              (<= (funcall cheby (cons (nth 1 id) (nth 2 id))
                                       (cons bx by))
                                  3))
                     (deliver id 'fixture 'fixture-flood)))
                 (cistern-st-personas st))
                (dolist (w (cistern-st-creators st))
                  (when (<= (funcall cheby
                                     (cons (cistern--worker-x w)
                                           (cistern--worker-y w))
                                     (cons bx by))
                            3)
                    (deliver (cistern--worker-glyph st w)
                             'worker 'nerve-flood)))))
             ((eq kind 'relief)
              (deliver (list :toilet (nth 2 ev) (nth 3 ev))
                       'fixture 'fixture-served))
             ((eq kind 'purge)
              (deliver (list :tank (nth 2 ev) (nth 3 ev))
                       'tank 'tank-purged))
             ((memq kind '(destroyed goblin-death))
              (let ((ex (nth 2 ev)) (ey (nth 3 ev)))
                (dolist (w (cistern-st-creators st))
                  (when (<= (funcall cheby
                                     (cons (cistern--worker-x w)
                                           (cistern--worker-y w))
                                     (cons ex ey))
                            1)
                    (deliver (cistern--worker-glyph st w)
                             'worker 'loss))))))))
        ;; row 3: bladder >= 110, self, CRITICAL gate
        (dolist (w (cistern-st-creators st))
          (let ((id (cistern--worker-glyph st w)))
            (when (and (> (cistern--worker-bladder w) 110)
                       (eq (cistern--social-mood st id) 'CRITICAL))
              (deliver id 'worker 'nerve-pressure))))
        ;; row 5: tanks at or over 85% of cap
        (maphash (lambda (k _v)
                   (when (>= (cistern--tank-load st (car k) (cdr k))
                             (* 0.85 cistern-tank-cap))
                     (deliver (list :tank (car k) (cdr k))
                              'tank 'tank-strain)))
                 (cistern-st-tanks st))
        ;; row 8: goblin death within 6 of a guild goblin
        (dolist (ev events)
          (when (eq (cistern--event-kind ev) 'goblin-death)
            (let ((dx (nth 2 ev)) (dy (nth 3 ev)))
              (dolist (e (cistern-st-hostiles st))
                (when (and (eq (cistern--enemy-faction e) 'guild)
                           (gethash (cistern--enemy-id e)
                                    (cistern-st-personas st))
                           (<= (funcall cheby
                                        (cons (cistern--enemy-x e)
                                              (cistern--enemy-y e))
                                        (cons dx dy))
                               6))
                  (deliver (cistern--enemy-id e)
                           'goblin 'guild-mourning))))))))))

;; ---------------------------------------------------------------------------
;; V5-12 (SOCIAL §4.2): social-eval — ONE call per tick, pinned
;; story-eval -> social-eval -> dialogue-eval.  Urge application +
;; clearing, romance proximity/gates, the thought pass.

(defun cistern--social-eval (st)
  "V5-12: the social evaluation slot.  Order: last tick's urges
apply and clear (ttl 1 tick), the romance graph accrues proximity
and resolves gates, the thought pass reads the pending events.
Social-disabled runs (banks absent) are byte-identical sims
(SOCIAL §4.3)."
  (when (cistern-st-personas st)
    (let ((urges nil))
      (maphash (lambda (id p)
                 (when (plist-get p :urge)
                   (setq urges (cons (cons id p) urges))))
               (cistern-st-personas st))
      (dolist (pair urges)
        (let ((id (car pair)))
          (cond
           ((and (stringp id) (not (string-match-p "g[0-9]+" id)))
            ;; worker urge: ONE extra idle step, only with NO journey
            ;; (pathing and seating stay unreachable, §1.5)
            (let ((w (cl-find-if
                      (lambda (w) (equal (cistern--worker-glyph st w) id))
                      (cistern-st-creators st))))
              (when (and w (null (cistern--worker-journey w)))
                (cistern--shuffle st w))))
           ((and (stringp id) (string-match-p "g[0-9]+" id))
            ;; goblin urge: one constant-velocity particle, no draw
            (let ((e (cl-find id (cistern-st-hostiles st)
                              :key #'cistern--enemy-id :test #'equal)))
              (when e
                (cistern--field-spawn
                 st (cons (cistern--enemy-x e) (cistern--enemy-y e))
                 (cons 0 -1) 1 "!" 'info 'sparkle))))))
        (let ((p (cdr pair)))
          (puthash id (plist-put p :urge nil) (cistern-st-personas st)))))
    ;; the romance graph: proximity + shared events + gates
    (cistern--romance-proximity-tick st)
    ;; the thought pass (trigger table, channels, budgets)
    (cistern--social-thoughts st)))

;; ---------------------------------------------------------------------------
;; V5-13/15/16 (COMEDY §1-§2/§5.3): the comedy director — dual-clock
;; tracker, suppression, latching, selection, delivery.

(defun cistern--comedy-anchors-scan (st)
  "Record this tick's violent anchors (worker-death, burst,
infestation) and a raid close on the comedy plist — pruned to 60
ticks for the density dampener."
  (let* ((c (cistern-st-comedy st))
         (tick (cistern-st-tick st))
         (anchors (plist-get c :anchors))
         (close (plist-get (cistern-st-raid st) :last-end))
         (last-c (plist-get c :last-close)))
    (dolist (ev (cistern-st-rewards-events st))
      (when (memq (cistern--event-kind ev)
                  '(worker-death burst infestation))
        (push tick anchors)))
    (when (and close (not (eq close last-c)))
      (push tick anchors)
      (plist-put c :last-close close))
    (plist-put c :anchors
               (cl-remove-if (lambda (a) (< tick (+ a 60))) anchors))))

(defun cistern--comedy-suppressed-p (st)
  "The §1.2 suppression rows in pinned order (S1-S4).  S5
(beat active) is handled at the delivery site."
  (let* ((c (cistern-st-comedy st))
         (tick (cistern-st-tick st))
         (raid (cistern-st-raid st)))
    (or
     ;; S1: raid open
     (and raid (plist-get raid :open))
     ;; S2: <= 40 ticks since a violent anchor
     (cl-some (lambda (a) (<= (- tick a) cistern--comedy-calm))
              (plist-get c :anchors))
     ;; S3: contamination >= 15
     (>= (cistern-st-contam st) 15)
     ;; S4: act-rollover ± 10
     (or (<= (abs (- tick 120)) 10) (<= (abs (- tick 240)) 10)))))

(defun cistern--comedy-tense-p (st)
  "§1.2 density dampener: >= 2 violent anchors within 60 ticks."
  (>= (length (plist-get (cistern-st-comedy st) :anchors)) 2))

(defun cistern--comedy-budget (st)
  "The mode-conditional budget (Clock A): auto-run flag = existing
state, no new sim input."
  (if (cistern-st-auto-run st)
      cistern--comedy-budget-auto
    cistern--comedy-budget-manual))

(defun cistern--comedy-eval (st story-intents)
  "V5-13/15/16: the comedy director — ONE call per tick, pinned
story-eval -> social-eval -> comedy-eval -> dialogue-eval.  Reads
pending events without draining; draws stream 6 only; emits the
existing intent shapes.  Returns the intent list."
  (let ((intents nil)
        (c (cistern-st-comedy st)))
    (when c
      ;; clear last tick's aesthetic marks (1-tick lifetime)
      (maphash (lambda (k v)
                 (when (plist-get v :aesthetic-p)
                   (puthash k (plist-put v :aesthetic-p nil)
                            (cistern-st-toilets st))))
               (cistern-st-toilets st))
      (cistern--comedy-anchors-scan st)
      ;; V5-17 (COMEDY §3): romance-stage priority slots — stage >= 2
      ;; transitions arm a beat on the next calm tick; the dry channel
      ;; pushes one comedic private thought per 60 ticks.  The contrast
      ;; rule: a raid open suppresses both.
      (let* ((tk (cistern-st-tick st))
             (evs (cistern-st-rewards-events st)))
        (dolist (ev evs)
          (when (and (consp ev) (eq (car ev) :social)
                     (eq (cadr ev) 'romance-stage)
                     (>= (or (plist-get (cddr ev) :stage) 0) 2))
            (plist-put c :romance-slot t)))
        ;; the dry channel: one comedic private thought per 60 ticks,
        ;; never for a CRITICAL-mood worker, via SOCIAL's pinned helper
        (when (and (>= (- tk (or (plist-get c :last-dry)
                                 (- cistern--comedy-dry-gap 60)))
                         cistern--comedy-dry-gap)
                   (not (cistern--comedy-suppressed-p st)))
          (let* ((workers (cl-remove-if
                           (lambda (w)
                             (eq (cistern--social-mood
                                  st (cistern--worker-glyph st w))
                                 'CRITICAL))
                           (cistern-st-creators st))))
            (when workers
              (let* ((pick (nth (cistern--comedy-draw
                                 st (length workers))
                                workers))
                     (th-keys '(comedy-thought-1 comedy-thought-2
                                comedy-thought-3 comedy-thought-4
                                comedy-thought-5 comedy-thought-6
                                comedy-thought-7 comedy-thought-8))
                     (key (nth (cistern--comedy-draw
                                st (length th-keys))
                               th-keys)))
                (cistern--social-thought-push-key
                 st (cistern--worker-glyph st pick) key)
                (plist-put c :last-dry tk))))))
      (let* ((tick (cistern-st-tick st))
             (since (- tick (plist-get c :last-beat-tick)))
             (budget (cistern--comedy-budget st))
             (suppressed (cistern--comedy-suppressed-p st)))
        (cond
         ;; thread delivery: the active beat's next line, calm ticks only
         ((and (plist-get c :active) (not suppressed))
          (setq intents (cistern--comedy-thread st)))
         (suppressed
          ;; latch: budget expired under suppression
          (when (>= since budget)
            (plist-put c :due-p t)))
         (t
          (when (>= since budget) (plist-put c :due-p t))
          (let ((due (plist-get c :due-p))
                (spont (and (not (cistern-st-auto-run st))
                            (= 0 (cistern--comedy-draw st 90)))))
            (when (or due spont
                      ;; V5-17: the romance priority slot fires on the
                      ;; next calm tick, superseding the budget without
                      ;; moving :last-beat-tick (the slot clears here)
                      (progn
                        (when (plist-get c :romance-slot)
                          (plist-put c :romance-slot nil)
                          t)))
              (setq intents (cistern--comedy-select st story-intents))))))))
    intents))

(defun cistern--comedy-thread (st)
  "Deliver the active multi-tick beat's next line; finish the
thread at 0 remaining."
  (let* ((c (cistern-st-comedy st))
         (act (plist-get c :active))
         (lines (plist-get act :lines))
         (left (plist-get act :remaining))
         (line (nth (- (length lines) left) lines)))
    (plist-put act :remaining (1- left))
    (when (<= (1- left) 0) (plist-put c :active nil))
    (list (list :layer 'log :text line :face 'comedy))))

(defun cistern--comedy-select (st story-intents)
  "§1.4 selection: eligibility -> weight fold -> archetype draw ->
instance draws -> commit + deliver.  Returns the intent list."
  (let* ((c (cistern-st-comedy st))
         (tick (cistern-st-tick st))
         (tense (cistern--comedy-tense-p st))
         (entries (plist-get cistern--banks :whimseys))
         (eligible nil) (total 0))
    (dolist (e entries)
      (let* ((when-p (car (plist-get e :when)))
             (recent (plist-get c :recent))
             (cds (plist-get c :cooldowns))
             (lastcd (cdr (assq (plist-get e :id) cds))))
        (when (and (cistern--comedy-when when-p st)
                   (not (memq (plist-get e :id) recent))
                   (or (null lastcd) (>= tick (+ lastcd
                                                 (plist-get e :cooldown)))))
          (let ((w (plist-get e :weight)))
            (when (and tense (plist-get e :loud)) (setq w (/ w 2)))
            (setq total (+ total w))
            (push (cons w e) eligible)))))
    (setq eligible (nreverse eligible))
    (when (and eligible (> total 0))
      ;; banner arbitration: comedy takes the slot only if story
      ;; emitted none this tick
      (let ((story-banner
             (cl-some (lambda (i) (eq (plist-get i :layer) 'banner))
                      story-intents)))
        (let* ((sel (cistern--comedy-draw st total))
               (walk 0) (entry nil))
          (dolist (pair eligible)
            (unless entry
              (setq walk (+ walk (car pair)))
              (when (< sel walk) (setq entry (cdr pair)))))
          (when entry
            (cistern--comedy-commit st entry story-banner)))))))

(defun cistern--comedy-commit (st entry story-banner)
  "§1.4 step 5: instance draws, footprint, :recent/:last-beat-tick
update, delivery via the intent grammar."
  (let* ((c (cistern-st-comedy st))
         (tick (cistern-st-tick st))
         (id (plist-get entry :id))
         (draws (plist-get entry :draws))
         (inst nil)
         (intents nil))
    ;; instance draws left to right — the :draws spec is a flat list
    ;; (kind1 n1 kind2 n2 ...) parsed as consecutive (kind count) pairs
    (let ((d draws))
      (while d
      (let ((kind (car d)) (n (cadr d)))
        (dotimes (_ n)
          (let ((v (pcase kind
                     ('cast
                      (cistern--worker-glyph
                       st (nth (cistern--comedy-draw
                                st (length (cistern-st-creators st)))
                               (cistern-st-creators st))))
                     ('goblin
                      (cistern--enemy-id
                       (nth (cistern--comedy-draw
                             st (max 1 (length (cistern-st-hostiles st))))
                            (cistern-st-hostiles st))))
                     ('pipe
                      (cistern--comedy-draw st 900))
                     ('fixture
                      (car (cistern--comedy-free-toilets-plain st)))
                     ('rat 'ONE-RAT)
                     ('name 'EAST-RUN)
                     ('outcome (cistern--comedy-draw st 2))
                     ('letter (cistern--comedy-draw st 3))
                     (_ nil))))
            (push v inst))))
      (setq d (cddr d))))
    (setq inst (nreverse inst))
    ;; commit
    (plist-put c :last-beat-tick tick)
    (plist-put c :due-p nil)
    (plist-put c :recent (cons id (butlast (plist-get c :recent)
                                           (if (>= (length (plist-get c :recent)) 3) 1 0))))
    (plist-put c :cooldowns
               (cons (cons id tick)
                     (cl-remove-if (lambda (p) (eq (car p) id))
                                   (plist-get c :cooldowns))))
    ;; footprints + delivery per archetype
    (pcase id
      ('workers-comp
       (setf (cistern-st-alloy st) (1+ (cistern-st-alloy st))))
      ('inventory-audit
       (if (= (or (nth 0 inst) 0) 0)
           (setf (cistern-st-alloy st) (1+ (cistern-st-alloy st)))
         (setf (cistern-st-alloy st) (1- (cistern-st-alloy st)))))
      ('successor-letter
       (setf (cistern-st-alloy st) (1+ (cistern-st-alloy st))))
      ('safety-drill
       (plist-put c :drills (1+ (plist-get c :drills)))
       (unless story-banner
         (push (list :layer 'banner :text
                     (cistern--story-copy-key 'comedy-drill))
               intents)))
      ('aesthetic-refusal
       (let* ((ft (cistern--comedy-free-toilets-plain st)))
         (when (>= (length ft) 2)
           (let ((pick (nth (cistern--comedy-draw st (length ft)) ft)))
             (puthash pick
                      (plist-put (gethash pick (cistern-st-toilets st))
                                 :aesthetic-p t)
                      (cistern-st-toilets st)))))))
    ;; the log line
    (let* ((copy-key (plist-get entry :copy-key))
           (tmpl (cistern--story-copy-key copy-key))
           (args (pcase id
                   ('pipe-complaint (list (or (nth 0 inst) "α")
                                          (or (nth 1 inst) 1)))
                   ('clog-blame (list (or (nth 0 inst) "g1")
                                      (or (nth 1 inst) "C")))
                   ('manifold-accent (list 1))
                   ('workers-comp (list tick (or (nth 0 inst) "g1")))
                   ('aesthetic-refusal
                    (list (if (nth 0 inst) (car (nth 0 inst)) 0)
                          (or (nth 1 inst) "α")))
                   ('formal-duel (list (or (nth 0 inst) "α")))
                   ('memo-rename (list 1 1 (or (nth 0 inst) "EAST-RUN")))
                   ('inventory-audit
                    (list (if (= (or (nth 0 inst) 0) 0)
                              "LOCATED" "MISPLACED")))
                   ('queue-etiquette (list "α" "β"))
                   ('toilet-rivalry (list 3 5))
                   ('successor-letter
                    (nth (or (nth 1 inst) 0)
                         (list "A PREDECESSOR'S LETTER — 'PRIME THE EAST RUN FIRST'"
                               "A PREDECESSOR'S LETTER — 'THE SOUTH MANIFOLD LIES'"
                               "A PREDECESSOR'S LETTER — 'DO NOT NAME THE PIPES'")))
                   (_ nil)))
           (line (condition-case nil (apply #'format tmpl args)
                   (error tmpl))))
      (push (list :layer 'log :text line :face 'comedy) intents))
    ;; thread setup
    (when (plist-get entry :thread)
      (let ((thread-lines
             (pcase id
               ('clog-blame
                (list (format (cistern--story-copy-key 'comedy-clog-blame)
                              (or (nth 0 inst) "g1") "C")
                      (format (cistern--story-copy-key 'comedy-clog-blame)
                              (or (nth 0 inst) "g1") "D")
                      (format (cistern--story-copy-key 'comedy-clog-blame)
                              (or (nth 0 inst) "g1") "E")))
               ('formal-duel
                (list (format (cistern--story-copy-key 'comedy-duel-1)
                              (or (nth 0 inst) "α"))
                      (format (cistern--story-copy-key 'comedy-duel-2)
                              (or (nth 0 inst) "α"))))
               (_ nil))))
        (when thread-lines
          (plist-put c :active
                     (list :id id :lines thread-lines
                           :remaining (length thread-lines))))))
    (nreverse intents)))

(defun cistern--cmd-consume-hint (st)
  "Drain ST's transient cursor hint (Q17): the driver calls this
after each render cycle, so a posted hint is visible for exactly
one render — same drain-once pattern as `cistern-st-rewards-events'
\(no double consumption)."
  (setf (cistern-st-hint st) nil)
  st)

(defun cistern--cmd-decon (st x y)
  "Clean a hazard tile or dry a flood cell (cistern.el:527-538
verbatim semantics: hazard/flood tiles ONLY — R8 keeps demolish
distinct from decon; V4-05: drying flood reuses cistern-cost-decon
and never touches the contam limit)."
  (cond
   ((not (and (cistern--in-bounds-p st x y)
              (memq (cistern--cell st x y) '(hazard flood))))
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
        (cistern--log st "TANK PURGED — RECOVERED %d ALLOY" gain)
        ;; V5-10 (SOCIAL §1.4 row 6): the purge as a located event
        (push (list 'purge 'purge x y) (cistern-st-rewards-events st)))))))

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
            ;; L-012#2 recorded exception (L-011-cmd-build style):
            ;; this maphash iterates cistern-st-tanks unsorted —
            ;; deterministic only under the seed-1 soak's fixed tank
            ;; insertion history.  Sort the keys if a future soak-
            ;; touching change makes the trajectory load-order-fragile.
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
