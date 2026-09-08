;;; cistern-domain.el --- Pure sim core: tables, state, procgen, tick -*- lexical-binding: t; -*-

;; Domain layer (DESIGN-SPEC §3): no buffers, windows, faces, timers,
;; keymaps, or globals.  One state object threaded everywhere.

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; 1. Constants.  Ported verbatim from cistern.el:47-65.

(defconst cistern-w 34 "Sector width.")
(defconst cistern-h 16 "Sector height.")
(defconst cistern-version "5.0.0-dev"
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
    (manifold :glyph "╬" :passable nil :buildable nil :firebreak t   :conn nil)
    (event :glyph "!" :passable t   :buildable nil :firebreak nil :conn nil)
    (cache :glyph "?" :passable t   :buildable nil :firebreak nil :conn nil))
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
  (stats nil) (xp 0) (clearance 1) (journey nil)
  ;; V5-01 (COMBAT §5.1): the injury track (max = 8 + GRIT mod,
  ;; rolled at spawn — V5-03) and the stable spawn-index — the
  ;; identity glyph reads the STORED index, never list position,
  ;; so a death renames nobody (COMBAT §3.4.2, fail-first C4).
  (hp nil) (spawn-idx nil))

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
  (toilet-type 'long-drop)
  ;; V4-15 (STORY §3.6): the session story plist; nil = no story
  ;; (banks not loaded — a legal no-op state for tests)
  (story nil)
  ;; V4-22: alist ((X . Y) . TICKS-LEFT) - the ! tiles' countdowns
  (event-tiles nil)
  ;; V5-01 (COMBAT §5.1): the violent base.  HOSTILES is the full
  ;; enemy list — spawn-appended, never re-sorted (§1.4).  COMBAT-POS
  ;; is the stream-4 position (seed ⊕ 4), pos-in/pos-out like rpg-pos;
  ;; HOSTILE-SEQ is the g<N> id counter (§1.4: stable for the
  ;; entity's life; nothing else may collide with it).
  (combat-pos 0)
  (hostiles nil)
  (hostile-seq 0)
  ;; V5-02/§4.5 (COMBAT §5.1): the player's FOCUS designation — an
  ;; enemy id or nil.  Auto-defense targeting prefers it (§3.2);
  ;; cleared when the focused enemy dies (V5-06).
  (focus nil)
  ;; V5-04 (COMBAT §4.1/§5.1): nil | (:open T0) | (:last-end T) —
  ;; comedy reads this shape verbatim in wave 3.
  (raid nil)
  ;; flood age tracking for S4/S5 ((X . Y) . BORN-TICK) — the spawn
  ;; table needs "flood open ≥ 20 ticks"; alist, L-099 deviation
  (flood-born nil)
  ;; V5-08 (SOCIAL §1.2/§4.3): entity-id → persona plist.  SOCIAL-POS
  ;; is the stream-5 position (seed ⊕ 5), pos-in/pos-out like every
  ;; child stream.  Relationships (V5-11) complete the §4.3 list.
  (personas nil)
  (social-pos 0)
  (relationships nil)
  (comedy nil))

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

(defun cistern--rpg-d6-pos (pos)
  (let ((p (cistern--stream-next pos)))
    (cons (1+ (% (ash p -6) 6)) p)))

(defun cistern--rpg-d20-pos (pos)
  (let ((p (cistern--stream-next pos)))
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

(defconst cistern--cache-alloy 3
  "V4-22 (S3.2): the alloy bonus banked by the first worker to walk
over a cache tile.")

;; ---------------------------------------------------------------------------
;; V5-01 (COMBAT §1/§5.2): the combat child stream — id 4 (seed ⊕ 4),
;; the first free id after 0 reserved, 1 story-gen, 2 story-runtime,
;; 3 RPG.  Same recurrence, same mid-bits slice as every other child
;; stream (RPG §3.2 ruling: one rule, all streams); pos-in/pos-out on
;; `cistern-st-combat-pos'.  NEVER the sim LCG, never streams 0–3.

(defun cistern--combat-d6-pos (pos)
  (let ((p (cistern--stream-next pos)))
    (cons (1+ (% (ash p -6) 6)) p)))

(defun cistern--combat-d20-pos (pos)
  (let ((p (cistern--stream-next pos)))
    (cons (1+ (% (ash p -6) 20)) p)))

(defun cistern--combat-d6 (st)
  "Stateful stream-4 d6 draw (pos-in/pos-out on `cistern-st-combat-pos')."
  (let ((r (cistern--combat-d6-pos (cistern-st-combat-pos st))))
    (setf (cistern-st-combat-pos st) (cdr r))
    (car r)))

(defun cistern--combat-d20 (st)
  "Stateful stream-4 d20 draw (pos-in/pos-out on `cistern-st-combat-pos')."
  (let ((r (cistern--combat-d20-pos (cistern-st-combat-pos st))))
    (setf (cistern-st-combat-pos st) (cdr r))
    (car r)))

;; ---------------------------------------------------------------------------
;; V5-08 (SOCIAL §1.1/§1.2/§4.1): the persona layer.  Stream 5 (seed
;; 5), the census total order, and the persona spawn draw.

(defun cistern--social-d6 (st)
  "Stateful stream-5 d6 draw (pos-in/pos-out on `cistern-st-social-pos')."
  (let ((p (cistern--stream-next (cistern-st-social-pos st))))
    (setf (cistern-st-social-pos st) p)
    (1+ (% (ash p -6) 6))))

(defun cistern--social-select (st n)
  "One stream-5 selector draw in [0,N) (mid-bits slice)."
  (let ((p (cistern--stream-next (cistern-st-social-pos st))))
    (setf (cistern-st-social-pos st) p)
    (% (ash p -6) n)))

(defconst cistern--social-order
  '(worker goblin pest fixture tank structure)
  "SOCIAL §1.1 census total order (ruling 2): workers < goblins <
pests < fixtures < tanks < structures.  Also sorts romance pair
keys (V5-11) — one defconst, one order.")

(defconst cistern--social-species-names
  '((worker . worker) (goblin . goblin) (fauna . pest)
    (warband . goblin) (guild . goblin))
  "COMBAT faction/kind → census species for hostile personas.")

(defun cistern--social-quirk-bank (species)
  "The quirk bank entries whose :species matches SPECIES (absent
:species = any).  Nil when the bank is unloaded or carries no
content for the species — a species with no bank content simply
gets no persona (SOCIAL §1.2: structures ship bank-optional)."
  (when cistern--banks
    (cl-remove-if-not
     (lambda (q)
       (let ((sp (plist-get q :species)))
         (or (null sp) (eq sp species) (eq sp 'any))))
     (plist-get cistern--banks :quirks))))

(defun cistern--social-spawn-persona (st id species)
  "Spawn one persona (SOCIAL §1.2): one count draw (d6: 1-2 → 1
quirk, 3-4 → 2, 5-6 → 3), then that many selector draws over the
species-filtered quirk bank — stream 5, pos-in/pos-out.  No bank
content for the species means no persona (SC2: :ledger nil at
spawn)."
  (let ((bank (cistern--social-quirk-bank species)))
    (when bank
      (let* ((d6 (cistern--social-d6 st))
             (count (cond ((<= d6 2) 1) ((<= d6 4) 2) (t 3)))
             (quirks nil))
        (dotimes (_ count)
          (push (plist-get (nth (cistern--social-select st (length bank))
                                bank)
                           :id)
                quirks))
        (puthash id (list :species species
                          :quirks (nreverse quirks)
                          :ledger nil :urge nil :urge-tick nil)
                 (cistern-st-personas st))
        id))))

(defun cistern--social-urge-p (st id)
  "V5-10 view query: does the entity's persona carry an uncleared
silent urge?"
  (and (cistern-st-personas st)
       (plist-get (gethash id (cistern-st-personas st)) :urge)))

;; ---------------------------------------------------------------------------
;; V5-09 (SOCIAL §1.3): the derived mood enum — one pure banding
;; function per species over state that already exists.  NO mood field
;; anywhere: a mood that must be remembered is a thought, and thoughts
;; have a channel.

(defconst cistern--social-goblin-bands
  '((40 . CRITICAL) (60 . STRAINED))
  "SOCIAL §1.3: goblin/pest mood banding mapped from combat hp
facts — one defconst, combat owns facts, social bands.  hp at or
below 40% of max is CRITICAL, at or below 60% STRAINED.")

(defun cistern--social-mood (st id)
  "The derived mood word for the entity ID — existing reads only,
never a stored field.  Unmapped ids are NOMINAL (structures, the
manifold: it does not stress, it IS stress)."
  (cond
   ((and (consp id) (eq (car id) :toilet))
    (let ((state (cistern--toilet-state st (nth 1 id) (nth 2 id))))
      (cond ((eq state 'busy) 'STRAINED)
            ((memq state '(down)) 'CRITICAL)
            (t 'NOMINAL))))
   ((and (consp id) (eq (car id) :tank))
    (let* ((load (or (cistern--tank-load st (nth 1 id) (nth 2 id)) 0))
           (pct (* 100.0 load (/ 1.0 cistern-tank-cap))))
      (cond ((>= pct 85) 'CRITICAL)
            ((>= pct 50) 'STRAINED)
            (t 'NOMINAL))))
   ((and (stringp id) (string-match-p "\\`g[0-9]+\\'" id))
    ;; goblin or pest — band off the combat hp facts
    (let ((e (cl-find id (cistern-st-hostiles st)
                      :key #'cistern--enemy-id :test #'equal)))
      (if (null e)
          'NOMINAL
        (let* ((max (+ (cdr (assq (cistern--enemy-kind e)
                                  cistern--enemy-hp-base))
                       (cistern--rpg-mod (nth 1 (cistern--enemy-stats e)))))
               (pct (/ (* 100.0 (cistern--enemy-hp e)) (max 1 max)))
               (band (cl-assoc pct cistern--social-goblin-bands :test #'<)))
          (if band (cdr band) 'NOMINAL)))))
   ((stringp id) ; a worker glyph
    (let ((w (cl-find-if (lambda (w)
                           (equal (cistern--worker-glyph st w) id))
                         (cistern-st-creators st))))
      (cond ((null w) 'NOMINAL)
            ((or (>= (cistern--worker-bladder w) 110)
                 (> (cistern--worker-sick w) 0))
             'CRITICAL)
            ((>= (cistern--worker-bladder w) 100) 'STRAINED)
            (t 'NOMINAL))))
   (t 'NOMINAL)))

;; ---------------------------------------------------------------------------
;; V5-10 (SOCIAL §1.4): the ONE trigger table — rows are
;; (EVENT SPECIES MOOD-GATE CLASS); the resolver in the game layer
;; expands each fired row into per-entity candidates.  Rows 9-11 read
;; events/state that wave-2's later directives produce (faction-mock,
;; romance-stage, relationships) and fire the day those land.

(defconst cistern--social-trigger-table
  '((1 breach fixture any fixture-flood)
    (2 breach worker any nerve-flood)
    (3 bladder-110 worker CRITICAL nerve-pressure)
    (4 relief fixture any fixture-served)
    (5 tank-85 tank CRITICAL tank-strain)
    (6 purge tank any tank-purged)
    (7 destroyed any any loss)
    (8 goblin-death goblin any guild-mourning)
    (9 faction-mock goblin any faction-mock)
    (10 romance-stage any any romance-stage)
    (11 idle-proximity worker NOMINAL fond-proximity))
  "SOCIAL §1.4: event × species × mood → thought class.  No
polling, no timers, no idle chatter: no trigger row, no thought.")

(defconst cistern--social-classes
  '(fixture-flood nerve-flood nerve-pressure fixture-served tank-strain
    tank-purged loss guild-mourning faction-mock romance-stage
    fond-proximity)
  "The closed thought-class table (SOCIAL §4.4 loader).")

(defconst cistern--social-channel-classes
  '((mutter . (loss guild-mourning faction-mock))
    (file . (fixture-served tank-strain tank-purged))
    (private . (fixture-flood nerve-flood nerve-pressure
               romance-stage fond-proximity)))
  "SOCIAL §1.5: class → delivery channel (L-102: the design leaves
the class→channel split unpinned; this is the deterministic pin —
speakers quote loss/mourning/mock, non-speakers FILE their
service classes, self-regarding classes stay private).  Urge
classes live in `cistern--social-urge-classes'.")

(defconst cistern--social-urge-classes '(fixture-served)
  "SOCIAL §1.5: classes that deliver as a SILENT URGE (no text,
no draw) — the served fixture blinks its busy countdown; L-102.")

(defun cistern--social-channel (class species)
  "The delivery channel for CLASS on SPECIES: non-speakers
(fixtures, tanks, structures) cannot quote — a muttered class on
them delivers as a FILE."
  (let* ((entry (cl-find class cistern--social-channel-classes
                         :key #'cdr :test #'memq))
         (chan (if entry (car entry) 'private)))
    (if (and (eq chan 'mutter)
             (memq species '(fixture tank structure)))
        'file chan)))

;; ---------------------------------------------------------------------------
;; V5-11 (SOCIAL §2): the romance graph — sorted-pair keys, stages
;; FILED -> CROSS-REFERENCED -> CO-SIGNED -> ANNOTATED IN THE MARGINS,
;; gate rolls on stream 5 at crossings only.  NO sim numbers (§2.5).

(defconst cistern--romance-thresholds '(10 40 80)
  "SOCIAL §2.3: score thresholds for stages 1/2/3.")

(defconst cistern--romance-dcs '(8 12 16)
  "SOCIAL §2.3: gate DCs for stages 1/2/3.")

(defconst cistern--romance-stage-names
  '(FILED CROSS-REFERENCED CO-SIGNED "ANNOTATED IN THE MARGINS")
  "SOCIAL §2.2: the institutional register — the stage names ARE
the joke; formatted through social-stage-fmt, data not code.")

(defun cistern--romance-species-rank (id)
  "The census rank of ID (SOCIAL §1.1 total order, ruling 2)."
  (cond ((and (stringp id) (string-match-p "\\'g[0-9]+\\'" id)) 1)
        ((stringp id) 0)
        ((and (consp id) (eq (car id) :toilet)) 3)
        ((and (consp id) (eq (car id) :tank)) 4)
        ((and (consp id) (eq (car id) :structure)) 5)
        (t 6)))

(defun cistern--romance-pair-key (id-a id-b)
  "The two ids ordered by the census total order (deterministic,
no canonicalization draws, SOCIAL §2.1)."
  (if (or (< (cistern--romance-species-rank id-a)
             (cistern--romance-species-rank id-b))
          (and (= (cistern--romance-species-rank id-a)
                  (cistern--romance-species-rank id-b))
               (string< (prin1-to-string id-a)
                        (prin1-to-string id-b))))
      (cons id-a id-b)
    (cons id-b id-a)))

(defun cistern--social-faction-of (st id)
  "The combat faction for a hostile id; sector ids are nil."
  (when (and (stringp id) (string-match-p "g[0-9]+" id))
    (let ((e (cl-find id (cistern-st-hostiles st)
                      :key #'cistern--enemy-id :test #'equal)))
      (and e (cistern--enemy-faction e)))))

(defun cistern--romance-file (st id-a id-b)
  "FILED (stage 0) on the first score point — no roll (SOCIAL
§2.3).  Always returns the pair key; records cross-faction."
  (let ((key (cistern--romance-pair-key id-a id-b)))
    (unless (gethash key (cistern-st-relationships st))
      (let ((fa (cistern--social-faction-of st id-a))
            (fb (cistern--social-faction-of st id-b)))
        (puthash key (list :stage 0 :score 0 :since (cistern-st-tick st)
                           :cross-faction (not (eq fa fb))
                           :re-arm nil)
                 (cistern-st-relationships st))))
    key))

(defun cistern--romance-attachments (st id)
  "How many of ID's pairs stand at stage >= 2 (the §2.5 cap)."
  (let ((n 0))
    (maphash (lambda (k v)
               (when (and (>= (plist-get v :stage) 2)
                          (or (equal (car k) id) (equal (cdr k) id)))
                 (setq n (1+ n))))
             (cistern-st-relationships st))
    n))

(defun cistern--romance-advance (st key)
  "Advance the pair one stage (SOCIAL §2.4): the deadpan log line,
the (:social 'romance-stage ...) push, and romance-stage thoughts
for both partners."
  (let* ((rel (gethash key (cistern-st-relationships st)))
         (stage (1+ (plist-get rel :stage)))
         (name (if (stringp (nth stage cistern--romance-stage-names))
                   (nth stage cistern--romance-stage-names)
                 (symbol-name (nth stage cistern--romance-stage-names))))
         (a (car key)) (b (cdr key)))
    (plist-put rel :stage stage)
    (plist-put rel :re-arm nil)
    (cistern--log-sev st 'info "%s"
                      (format (cistern--social-copy 'social-stage-fmt)
                              (cistern--social-display-id a)
                              (cistern--social-display-id b)
                              name
                              (if (= stage 1) "PROXIMITY ON RECORD"
                                (if (= stage 2) "THE PAIR FILES JOINTLY"
                                  "THE MARGINS ARE ANNOTATED"))))
    (push (list :social 'romance-stage :pair key :stage stage)
          (cistern-st-rewards-events st))
    (cistern--social-thought-push st a 'romance-stage)
    (cistern--social-thought-push st b 'romance-stage)
    (when (and (plist-get rel :cross-faction) (>= stage 1))
      (cistern--social-friction st key))))

(defun cistern--social-display-id (id)
  "The rendered form of an entity id."
  (cond ((and (consp id) (eq (car id) :toilet))
         (format "FIXTURE (%d,%d)" (nth 1 id) (nth 2 id)))
        ((and (consp id) (eq (car id) :tank))
         (format "TANK (%d,%d)" (nth 1 id) (nth 2 id)))
        ((and (consp id) (eq (car id) :structure))
         (format "STRUCTURE (%d,%d)" (nth 1 id) (nth 2 id)))
        (t (prin1-to-string id))))

(defun cistern--social-thought-push (st id class)
  "The ONE domain thought-push helper (SOCIAL §4.7): appends a
private thought for the persona, ledger cap 3 FIFO enforced HERE —
comedy (wave 3) cannot exceed the budget by construction."
  (let* ((p (gethash id (cistern-st-personas st)))
         (bank (cistern--social-thought-bank class
                                             (plist-get p :species)
                                             'any))
         (key (when bank
                (plist-get (nth (cistern--social-select st (length bank))
                                bank)
                           :copy-key))))
    (when key
      (let ((ledger (cons (list (cistern-st-tick st) 'private key)
                          (plist-get p :ledger))))
        (puthash id (plist-put p :ledger
                               (if (> (length ledger) 3)
                                   (butlast ledger) ledger))
                 (cistern-st-personas st))))))

(defun cistern--social-friction (st key)
  "SOCIAL §3.2: on a cross-faction stage >= 1 transition, every
warband goblin within Chebyshev 6 of the goblin endpoint files an
OBJECTION through the faction-mock row — capped by §1.6 budgets.
The Guild of the Open Flange does not judge."
  (let* ((rel (gethash key (cistern-st-relationships st)))
         (a (car key)) (b (cdr key))
         (g-id (if (cistern--social-faction-of st a) a
                 (if (cistern--social-faction-of st b) b nil)))
         (other (if (equal g-id a) b a))
         (g (and g-id (cl-find g-id (cistern-st-hostiles st)
                               :key #'cistern--enemy-id :test #'equal))))
    (when g
      (dolist (e (cistern-st-hostiles st))
        (when (and (eq (cistern--enemy-faction e) 'warband)
                   (gethash (cistern--enemy-id e)
                            (cistern-st-personas st))
                   (<= (max (abs (- (cistern--enemy-x e)
                                    (cistern--enemy-x g)))
                            (abs (- (cistern--enemy-y e)
                                    (cistern--enemy-y g))))
                       6))
          (push (list 'faction-mock 'mock
                      (cistern--enemy-x e) (cistern--enemy-y e)
                      (cistern--social-display-id other))
                (cistern-st-rewards-events st)))))))

(defun cistern--romance-end (st id)
  "SOCIAL §2.6: when an endpoint ceases, delete its pair keys; a
stage >= 2 file closes with one social-stage-close log line and a
loss thought to the survivor.  No ghost state."
  (let ((dead nil))
    (maphash (lambda (k v)
               (when (or (equal (car k) id) (equal (cdr k) id))
                 (push (list k v) dead)))
             (cistern-st-relationships st))
    (dolist (pair dead)
      (let* ((key (car pair)) (rel (cadr pair))
             (survivor (if (equal (car key) id) (cdr key) (car key))))
        (remhash key (cistern-st-relationships st))
        (when (>= (plist-get rel :stage) 2)
          (cistern--log-sev st 'info "%s"
                            (format (cistern--social-copy
                                     'social-stage-close)
                                    (cistern--social-display-id (car key))
                                    (cistern--social-display-id (cdr key))))
          (cistern--social-thought-push st survivor 'loss))))))

(defun cistern--romance-progress (st id-a id-b delta)
  "Add DELTA score to the pair (filing it on the first point) and
resolve gate crossings — one d20 per crossing on stream 5, band >=
2 advances, <= 1 re-arms at score + 5 (SOCIAL §2.3).  Audit-mod: a
worker partner's ARCHIVE mod; non-worker pairs file blind; a
CO-SIGNED pair gains +1 on later gates.  A third stage-2+
attachment is refused WITHOUT a draw (§2.5)."
  (let* ((key (cistern--romance-file st id-a id-b))
         (rel (gethash key (cistern-st-relationships st)))
         (stage (plist-get rel :stage)))
    (when rel
      (let* ((score (+ (plist-get rel :score) delta))
             (worker-id (if (stringp id-a) id-a
                          (if (stringp id-b) id-b nil)))
             (audit (if worker-id
                        (let ((w (cl-find-if
                                  (lambda (w)
                                    (equal (cistern--worker-glyph st w)
                                           worker-id))
                                  (cistern-st-creators st))))
                          (if w (cistern--rpg-stat-mod w 3) 0))
                      0)))
        (plist-put rel :score score)
        (when (< stage 3)
          (let ((threshold (nth stage cistern--romance-thresholds))
                (re-arm (plist-get rel :re-arm)))
            (when (and (>= score threshold)
                       (or (null re-arm) (>= score re-arm)))
              (if (and (>= (+ stage 1) 2)
                       (or (>= (cistern--romance-attachments st id-a) 2)
                           (>= (cistern--romance-attachments st id-b) 2)))
                  (plist-put rel :re-arm (+ score 5))
                (let* ((roll (1+ (cistern--social-select st 20)))
                       (bonus (+ audit (if (>= stage 2) 1 0)))
                       (dc (nth stage cistern--romance-dcs))
                       (band (cistern--margin-band (+ roll bonus (- dc)))))
                  (if (>= band 2)
                      (cistern--romance-advance st key)
                    (plist-put rel :re-arm (+ score 5))))))))))
    key))

(defun cistern--romance-position (st id)
  "The map position of an entity id, or nil (off-map)."
  (cond ((and (stringp id) (string-match-p "g[0-9]+" id))
         (let ((e (cl-find id (cistern-st-hostiles st)
                           :key #'cistern--enemy-id :test #'equal)))
           (and e (cons (cistern--enemy-x e) (cistern--enemy-y e)))))
        ((stringp id)
         (let ((w (cl-find-if (lambda (w)
                                (equal (cistern--worker-glyph st w) id))
                              (cistern-st-creators st))))
           (and w (cons (cistern--worker-x w) (cistern--worker-y w)))))
        ((and (consp id) (memq (car id) '(:toilet :tank :structure)))
         (cons (nth 1 id) (nth 2 id)))
        (t nil)))

(defun cistern--romance-proximity-tick (st)
  "V5-11/§4.2: the per-tick romance accrual — +1 score per pair
with both endpoints on the map within Chebyshev 2, +2 for shared
located events this tick (both within 3), gates resolving on
crossings only.  Iterates the relationships hash — pairs exist
once filed; no scan over non-proximate pairs (§2.5)."
  (let ((pairs nil))
    (maphash (lambda (k v) (push (cons k v) pairs))
             (cistern-st-relationships st))
    (dolist (pair pairs)
      (let* ((key (car pair)) (rel (cdr pair))
             (pa (cistern--romance-position st (car key)))
             (pb (cistern--romance-position st (cdr key))))
        (when (and pa pb)
          (let ((delta 0))
            (when (<= (max (abs (- (car pa) (car pb)))
                           (abs (- (cdr pa) (cdr pb))))
                      2)
              (setq delta (+ delta 1)))
            (dolist (ev (cistern-st-rewards-events st))
              (let ((kind (cistern--event-kind ev)))
                (when (memq kind '(breach relief purge destroyed))
                  (let* ((ex (nth 2 ev)) (ey (nth 3 ev)))
                    (when (and (<= (max (abs (- (car pa) ex))
                                        (abs (- (cdr pa) ey)))
                                   3)
                               (<= (max (abs (- (car pb) ex))
                                        (abs (- (cdr pb) ey)))
                                   3))
                      (setq delta (+ delta 2))))))))
          (when (> delta 0)
            (cistern--romance-progress st (car key) (cdr key)
                                       delta)))))))

(defun cistern--social-quirk-copy-key (id)
  "V5-12: the copy-key of quirk entry ID from the loaded quirk
bank — personas store quirk IDS; the copy chain is keyed by
copy-keys (fail-first on a missing entry)."
  (or (plist-get (cl-find id (plist-get cistern--banks :quirks)
                         :key (lambda (q) (plist-get q :id))
                         :test #'equal)
                 :copy-key)
      (error "UNRESOLVED QUIRK ID %S" id)))

(defun cistern--social-thought-push-key (st id key)
  "V5-17 (COMEDY §3.2): the dry-channel variant of the thought-push
helper — takes a COPY-KEY directly instead of doing a class-based
bank lookup.  The ledger cap 3 FIFO is enforced HERE."
  (let* ((p (gethash id (cistern-st-personas st)))
         (ledger (cons (list (cistern-st-tick st) 'private key)
                       (plist-get p :ledger))))
    (puthash id (plist-put p :ledger
                           (if (> (length ledger) 3)
                               (butlast ledger) ledger))
             (cistern-st-personas st))))

(defun cistern--social-persona-id-at (st x y)
  "V5-12 view query: the persona-eligible entity id at (X,Y) —
worker glyph, hostile g<N> id, fixture or tank key — or nil."
  (or (let ((w (cl-find-if (lambda (w)
                             (and (= x (cistern--worker-x w))
                                  (= y (cistern--worker-y w))))
                           (cistern-st-creators st))))
        (and w (cistern--worker-glyph st w)))
      (let ((e (cistern--enemy-at st x y)))
        (and e (cistern--enemy-id e)))
      (and (gethash (cons x y) (cistern-st-toilets st))
           (list :toilet x y))
      (and (gethash (cons x y) (cistern-st-tanks st))
           (list :tank x y))))

(defun cistern--social-persona-words (st id)
  "V5-12: the persona clause words for ID — (:mood-w W :quirk-word W
:thought W), copy resolution included (the domain may read the
copy chain; the VIEW may not, per the r5/v4-16 layer pins)."
  (let ((p (gethash id (cistern-st-personas st))))
    (when p
      (let ((quirk (car (plist-get p :quirks))))
        (list :mood-w (symbol-name (cistern--social-mood st id))
              :quirk-word (when quirk
                            (cistern--story-copy-key
                             (cistern--social-quirk-copy-key quirk)))
              :thought-word
              (let ((th (car (plist-get p :ledger))))
                (when th
                  ;; §4.5: the word is the thought CLASS — recovered
                  ;; from the thought bank by the ledger's copy-key
                  (let* ((entry (cl-find (nth 2 th)
                                         (plist-get cistern--banks
                                                    :thoughts)
                                         :key (lambda (e)
                                                (plist-get e :copy-key))
                                         :test #'equal))
                         (class (and entry (plist-get entry :class))))
                    (format "%s: \"%s\""
                            (upcase (symbol-name class))
                            (cistern--story-copy-key (nth 2 th)))))))))))

;; ---------------------------------------------------------------------------
;; V5-13/14 (COMEDY §1.1/§5.2): the comedy tracker state, stream 6,
;; and the closed footprint/when tables.

(defconst cistern--comedy-budget-manual 150
  "COMEDY §1.1: 150 manual ticks = 2.5 min at the design 1 tps.")

(defconst cistern--comedy-budget-auto 750
  "COMEDY §1.1: 750 auto ticks = 2.5 min at the pinned 5 tps.")

(defconst cistern--comedy-calm 40
  "COMEDY §1.2: the violence-contrast cooldown after an anchor.")

(defconst cistern--comedy-dry-gap 60
  "COMEDY §3.2: one comedic private thought per 60 ticks.")

(defconst cistern--comedy-footprints
  '(complaint-count accent-ttl aesthetic-p rival-ttl place-names
    alloy-delta xp-delta rat-despawn drill-counter thought-push
    mutter-push)
  "COMEDY §5.2: the closed footprint whitelist — every state delta
comedy may make.  The loader and a batch guard reject any bank
entry whose :footprint names anything else.")

(defconst cistern--comedy-when-names
  '(always pipes-long guild-goblins manifold-attached pest-persona
    seeking-2usable rat-adjacent two-workers same-type-toilets
    demolish-event)
  "COMEDY §2.2: the closed :when predicate name table.")

(defun cistern--comedy-draw (st n)
  "One stream-6 draw in [0,N) (mid-bits slice), pos-in/pos-out on
the comedy plist's :pos."
  (let* ((c (cistern-st-comedy st))
         (p (cistern--stream-next (plist-get c :pos))))
    (plist-put c :pos p)
    (% (ash p -6) n)))

(defun cistern--comedy-free-toilets-plain (st)
  "Free usable toilets WITHOUT the aesthetic filter — the
aesthetic-refusal eligibility read needs the pre-filter count."
  (let ((out nil))
    (maphash (lambda (k v)
               (when (and (cistern--toilet-usable-p st (car k) (cdr k))
                          (not (plist-get v :aesthetic-p)))
                 (push k out)))
             (cistern-st-toilets st))
    (sort out (lambda (a b) (< (car a) (car b))))))

(defun cistern--comedy-when (name st)
  "Evaluate the pinned :when predicate NAME over existing state."
  (let ((workers (cistern-st-creators st)))
    (pcase name
      ('always t)
      ('pipes-long
       (let* ((tk (cistern--nearest-tank st 0 0)) (n 0))
         (when tk
           (let ((seen (cistern--flood st (car tk) (cdr tk)
              (lambda (px py) (memq (cistern--cell st px py) '(pipe tank))))))
             (maphash (lambda (k _v)
                (when (eq (cistern--cell st (car k) (cdr k)) 'pipe)
                  (setq n (1+ n)))) seen)))
         (>= n 6)))
      ('guild-goblins
       (>= (cl-count-if (lambda (e) (eq (cistern--enemy-faction e) 'guild))
            (cistern-st-hostiles st)) 2))
      ('manifold-attached
       (let ((found nil) (i 0))
         (while (and (not found) (< i (length (cistern-st-map st))))
           (when (eq (aref (cistern-st-map st) i) 'manifold) (setq found t))
           (setq i (1+ i))) found))
      ('pest-persona
       (cl-some (lambda (e) (and (eq (cistern--enemy-faction e) 'fauna)
            (gethash (cistern--enemy-id e) (cistern-st-personas st))))
        (cistern-st-hostiles st)))
      ('seeking-2usable
       (and (>= (length (cistern--comedy-free-toilets-plain st)) 2)
        (cl-some (lambda (w) (>= (cistern--worker-bladder w)
           cistern-bladder-seek)) workers)))
      ('rat-adjacent
       (cl-some (lambda (e) (and (eq (cistern--enemy-kind e) 'rat)
        (cl-some (lambda (w) (<= (max (abs (- (cistern--enemy-x e)
          (cistern--worker-x w))) (abs (- (cistern--enemy-y e)
          (cistern--worker-y w)))) 1)) workers)))
        (cistern-st-hostiles st)))
      ('two-workers
       (and (>= (length workers) 2)
        (cl-some (lambda (a) (cl-some (lambda (b) (and (not (eq a b))
          (<= (max (abs (- (cistern--worker-x a) (cistern--worker-x b)))
            (abs (- (cistern--worker-y a) (cistern--worker-y b)))) 2)))
          workers)) workers)))
      ('same-type-toilets
       (>= (length (cistern--comedy-free-toilets-plain st)) 2))
      ('demolish-event
       (cl-some (lambda (e) (eq (cistern--event-kind e) 'destroyed))
        (cistern-st-rewards-events st)))
      (_ nil))))

(defun cistern--combat-roll-stat (st)
  "4d6 drop lowest, summed — one stat score (3-18), from stream 4.
The identical draw procedure as the worker dossier (COMBAT §1:
every entity reads its numbers the same way)."
  (let ((rolls (sort (list (cistern--combat-d6 st) (cistern--combat-d6 st)
                           (cistern--combat-d6 st) (cistern--combat-d6 st))
                     #'<)))
    (+ (nth 1 rolls) (nth 2 rolls) (nth 3 rolls))))

;; ---------------------------------------------------------------------------
;; V5-01 (COMBAT §1.4): the full entity — stable id, stats, position,
;; faction.  One struct, one state list, least-active.  GNAW/ DRAIN/
;; GRIP are kind-specific scratch (gnaw timer, drain/split counter,
;; leech host); IDLE is the fixer loop's ticks-since-productive
;; counter (V5-05; one slot past the §1.4 sketch, ledgered L-096).

(defconst cistern--enemy-hp-base
  '((warband . 6) (fixer . 6) (rat . 4) (crab . 5) (leech . 3) (sponge . 8))
  "COMBAT §1 bestiary: kind HP bases.")

(cl-defstruct (cistern--enemy (:constructor cistern--enemy-make))
  id faction kind x y (stats nil) (hp 0)
  (gnaw 0) (drain 0) (grip nil) (idle 0))

(defun cistern--spawn-enemy (st faction kind x y)
  "Spawn one full combat entity into ST (COMBAT §1.4/§2): stable
`g<N>' id from the state counter, a 4d6-drop-lowest × 4 dossier
from stream 4 in the pinned call order, hp = kind-base + GRIT mod.
Appends to `hostiles' — spawn order, never re-sorted."
  (let* ((stats (list (cistern--combat-roll-stat st)
                      (cistern--combat-roll-stat st)
                      (cistern--combat-roll-stat st)
                      (cistern--combat-roll-stat st)))
         (grit-mod (cistern--rpg-mod (nth 1 stats)))
         (e (cistern--enemy-make
             :id (format "g%d" (1+ (cistern-st-hostile-seq st)))
             :faction faction :kind kind :x x :y y
             :stats stats
             :hp (+ (cdr (assq kind cistern--enemy-hp-base)) grit-mod))))
    (setf (cistern-st-hostile-seq st)
          (1+ (cistern-st-hostile-seq st)))
    (setf (cistern-st-hostiles st)
          (append (cistern-st-hostiles st) (list e)))
    ;; V5-08 (SOCIAL §1.2): goblins and pests are full social entities
    ;; — persona at hostile spawn, keyed on the stable g<N> id
    (cistern--social-spawn-persona
     st (cistern--enemy-id e)
     (cdr (assq faction cistern--social-species-names)))
    e))

;; ---------------------------------------------------------------------------
;; V5-02 (COMBAT §3.1/§3.2): combat resolution on the shared core.
;; One roll, one band, one lookup — the v4 pipeline reused verbatim.

(defun cistern--combat-band (st atk def)
  "One attack roll on stream 4 (COMBAT §3.1): margin = roll + ATK
− DEF through the SHARED `cistern--margin-band', with nat-20/nat-1
promotion pre-lookup.  Pos-in/pos-out on `cistern-st-combat-pos'."
  (let* ((r (cistern--combat-d20-pos (cistern-st-combat-pos st)))
         (roll (car r))
         (band (cistern--margin-band (+ roll atk (- def)))))
    (setf (cistern-st-combat-pos st) (cdr r))
    (cond ((= roll 20) 3) ((= roll 1) 0) (t band))))

(defun cistern--combat-strike (st matrix-id atk def)
  "One attack: d20 + ATK − DEF, shared band + promotion, one
gethash on (MATRIX-ID . BAND).  Returns the effect plist; band 0
is a MISS (:dmg 0) that logs nothing (S2: misses are silent)."
  (cistern--matrix-effect matrix-id (cistern--combat-band st atk def)))

(defun cistern--enemy-atk (e)
  "ATK = FLOW mod (COMBAT §1 derived stats)."
  (cistern--rpg-mod (nth 0 (cistern--enemy-stats e))))

(defun cistern--enemy-def (e)
  "DEF = 10 + GRIT mod (COMBAT §1 derived stats)."
  (+ 10 (cistern--rpg-mod (nth 1 (cistern--enemy-stats e)))))

(defun cistern--adjacent-hostiles (st x y)
  "Hostiles 4-adjacent to (X,Y), in spawn (list) order."
  (cl-remove-if-not
   (lambda (e)
     (let ((dx (abs (- (cistern--enemy-x e) x)))
           (dy (abs (- (cistern--enemy-y e) y))))
       (and (= dx 1) (zerop dy))))
   (cistern-st-hostiles st)))

(defun cistern--combat-target (st w)
  "Worker W's auto-defense target (COMBAT §3.2/§3.5): the player's
`focus' enemy first when it is adjacent, else the nearest adjacent
hostile (spawn order breaks ties) — ALWAYS filtered to exclude
faction `guild' (§3.5 guard-rail).  nil when nothing qualifies."
  (let* ((x (cistern--worker-x w)) (y (cistern--worker-y w))
         (cands (cl-remove-if
                 (lambda (e) (eq (cistern--enemy-faction e) 'guild))
                 (cistern--adjacent-hostiles st x y)))
         (focus (and (cistern-st-focus st)
                     (cl-find (cistern-st-focus st) cands
                              :key #'cistern--enemy-id :test #'equal))))
    (or focus
        (let ((best nil) (bd nil))
          (dolist (e cands)
            (let ((d (+ (abs (- (cistern--enemy-x e) x))
                        (abs (- (cistern--enemy-y e) y)))))
              (when (or (null bd) (< d bd))
                (setq bd d best e))))
          best))))

;; ---------------------------------------------------------------------------
;; V5-04 (COMBAT §2/§4.1-4.3): the spawn table and the raid lifecycle.

(defconst cistern--combat-const
  '((raid-ticks . (120 240)) (raid-dc-act2 . 8) (raid-dc-act3 . 5)
    (raid-span . 40) (ambush-dc . 13) (ambush-dist . 6)
    (infest-every . 20) (infest-base-dc . 14) (infest-min-dc . 8)
    (leech-dc . 12) (sponge-dc . 14) (leech-interval . 4)
    (sponge-split . 20) (hostiles-max . 8)
    ;; V5-05 (COMBAT §1.3/§4.4): the guild loop
    (guild-dc . 12) (guild-every . 40) (guild-fee . 1)
    (guild-restore . 2) (guild-max . 3) (guild-idle-max . 40)
    (guild-broke-wait . 20))
  "COMBAT §2/§5.3: spawn DCs, cadences, spans and caps in ONE block
(the §3.5 DC-block pattern).")

(defun cistern--combat-k (key) (cdr (assq key cistern--combat-const)))

(defvar cistern-combat-enabled nil
  "V5 PROTECT (§1.1/§4.5): combat-disabled runs are legal no-ops,
byte-identical to the pre-v5 sim.  Default OFF so curated v4
scenarios and regression fixtures stay exact; the driver enables
it for live play and the v5 tests enable it explicitly.")

(defun cistern--worker-def (w)
  "Worker DEF = 10 + GRIT mod (the worked example: α G+2 → DEF 12)."
  (+ 10 (cistern--rpg-mod (nth 1 (cistern--worker-stats w)))))

(defun cistern--enemy-retreat-p (e)
  "Grip = `retreat' marks a driven-off/dr withdrawing entity; GRIP
is leech-host storage for leeches, so the marker is kind-safe."
  (eq (cistern--enemy-grip e) 'retreat))

(defun cistern--raid-open (st)
  "Open one raid (COMBAT §4.1): n = clamp(pop−1, 1, 3) raiders in
act II, clamp(pop−1, 2, 4) in act III, each rolled per §2 in the
pinned call order and assigned an objective (d20 mod 3 → 0 gnaw /
1 steal / 2 harass).  One `raid' event OPEN."
  (let* ((tick (cistern-st-tick st))
         (act (cistern--story-tick-act tick))
         (pop (length (cistern-st-creators st)))
         (n (if (= act 3) (clamp 2 (1- pop) 4) (clamp 1 (1- pop) 3))))
    (setf (cistern-st-raid st) (list :open tick))
    (let ((ev-cell (cistern--edge-spawn-cell st)))
    (dotimes (_ n)
      (let ((cell (cistern--edge-spawn-cell st)))
        (when cell
          (let ((e (cistern--spawn-enemy st 'warband 'warband
                                         (car cell) (cdr cell))))
            ;; objective in IDLE (warband scratch: 0 gnaw/1 steal/2 harass)
            (setf (cistern--enemy-idle e) (% (cistern--combat-d20 st) 3))))))
    (cistern--log-sev st 'error "%s"
                      (format (cistern--combat-copy 'combat-raid-open) n))
    (push (list 'raid 'open (car ev-cell) (cdr ev-cell))
          (cistern-st-rewards-events st)))))

(defun cistern--raid-close (st routed)
  "Close the raid (COMBAT §4.1/P3): `raid' = (:last-end T),
survivors retreat to the nearest map edge.  The routed variant
carries `warband-routed' INSTEAD of the raid CLOSED event."
  (setf (cistern-st-raid st)
        (list :last-end (cistern-st-tick st)))
  (dolist (e (cistern-st-hostiles st))
    (when (eq (cistern--enemy-faction e) 'warband)
      (setf (cistern--enemy-grip e) 'retreat)))
  (if routed
      (progn
        (cistern--log-sev st 'success "%s"
                          (cistern--combat-copy 'combat-raid-routed))
        (push (list 'warband-routed 'routed
                    (cistern-st-w st) (cistern-st-h st))
              (cistern-st-rewards-events st)))
    (cistern--log st "%s" (cistern--combat-copy 'combat-raid-close))
    (push (list 'raid 'closed (cistern-st-w st) (cistern-st-h st))
          (cistern-st-rewards-events st))))

(defun cistern--edge-spawn-cell (st)
  "First walkable, unoccupied BORDER cell in map-index order —
the deterministic arrival point (no draw is spent on placement)."
  (let ((found nil) (i 0) (maxi (length (cistern-st-map st))))
    (while (and (not found) (< i maxi))
      (let ((x (% i (cistern-st-w st))) (y (/ i (cistern-st-w st))))
        (when (and (or (= x 0) (= y 0)
                       (= x (1- (cistern-st-w st)))
                       (= y (1- (cistern-st-h st))))
                   (cistern--tile-passable-p (cistern--cell st x y))
                   (not (gethash (cons x y) (cistern--occupied-cells st nil))))
          (setq found (cons x y))))
      (setq i (1+ i)))
    found))

(defun cistern--maybe-raid (st)
  "S1 (COMBAT §4.1): one raid draw at each act window floor, ONLY
when no raid is open and this window has not had one yet.  P1: a
raid may not even draw while contam ≥ limit−2 or pop ≤ 1 — the
draw is suppressed entirely, no stream consumption."
  (let* ((tick (cistern-st-tick st))
         (act (cistern--story-tick-act tick))
         (floor-tick (if (= act 3) 240 120))
         (raid (cistern-st-raid st)))
    (when (and (memq tick (cistern--combat-k 'raid-ticks))
               (or (null raid)
                   (and (plist-get raid :last-end)
                        (< (plist-get raid :last-end) floor-tick)))
               (< (cistern-st-contam st) (- cistern-contam-limit 2))
               (> (length (cistern-st-creators st)) 1))
      (when (>= (cistern--combat-d20 st)
                (if (= act 3) (cistern--combat-k 'raid-dc-act3)
                  (cistern--combat-k 'raid-dc-act2)))
        (cistern--raid-open st)))))

(defun cistern--isolated-worker (st)
  "S2 isolation read (COMBAT §4.2): the first worker (creators
order) adjacent to a pipe and at flood-distance ≥ 6 from every
other worker, through the EXISTING flood primitive."
  (cl-find-if
   (lambda (w)
     (let* ((x (cistern--worker-x w)) (y (cistern--worker-y w)))
       (and (cl-some (lambda (n)
                       (eq (cistern--cell st (car n) (cdr n)) 'pipe))
                     (cistern--neighbors st x y))
            (let ((dist (cistern--dist-from st x y
                                            (cistern--occupied-cells st w)
                                            'always x y)))
              (cl-every
               (lambda (o)
                 (let ((d (gethash (cons (cistern--worker-x o)
                                         (cistern--worker-y o))
                                   dist)))
                   (or (null d) (>= d (cistern--combat-k 'ambush-dist)))))
               (cl-remove w (cistern-st-creators st)))))))
   (cistern-st-creators st)))

(defun cistern--maybe-ambush (st)
  "S2 (COMBAT §4.2): one draw when a worker is isolated at
plumbing; success = 2 rats at the pipe + one `ambush' event."
  (let ((w (cistern--isolated-worker st)))
    (when w
      (when (>= (cistern--combat-d20 st) (cistern--combat-k 'ambush-dc))
        (let* ((x (cistern--worker-x w)) (y (cistern--worker-y w))
               (pipe (cl-find-if (lambda (n)
                                   (eq (cistern--cell st (car n) (cdr n))
                                       'pipe))
                                 (cistern--neighbors st x y))))
          (when pipe
            (cistern--spawn-near st 'fauna 'rat (car pipe) (cdr pipe) 2)
            (cistern--log st "%s"
                          (format (cistern--combat-copy 'combat-ambush)
                                  (car pipe) (cdr pipe)))
            (push (list 'ambush 'ambush (car pipe) (cdr pipe))
                  (cistern-st-rewards-events st))))))))

(defun cistern--severed-count (st)
  "Number of severed toilets (each is a severed line)."
  (let ((n 0))
    (maphash (lambda (k _v)
               (when (and (eq (cistern--toilet-state st (car k) (cdr k)) 'down)
                          (null (cistern--connected-tanks st (car k) (cdr k)))
                          (not (cistern--manifold-live-p st (car k) (cdr k))))
                 (setq n (1+ n))))
             (cistern-st-toilets st))
    n))

(defun cistern--infest-dc (severed)
  "S3 DC (COMBAT §4.3): 14 − severed lines, floored at 8 —
ignoring damage breeds rats."
  (max (cistern--combat-k 'infest-min-dc)
       (- (cistern--combat-k 'infest-base-dc) severed)))

(defun cistern--dead-pipe-cell (st)
  "First (coordinate-order) pipe cell not on a live path."
  (let ((found nil) (i 0) (maxi (length (cistern-st-map st))))
    (while (and (not found) (< i maxi))
      (let ((x (% i (cistern-st-w st))) (y (/ i (cistern-st-w st))))
        (when (and (eq (cistern--cell st x y) 'pipe)
                   (not (cistern--pipe-live-p st x y)))
          (setq found (cons x y))))
      (setq i (1+ i)))
    found))

(defun cistern--spawn-near (st faction kind x y n)
  "Spawn up to N entities of KIND on (X,Y) and its free
4-neighbors, coordinate order — P2's hostiles ≤ 8 cap respected."
  (let ((spots (cons (cons x y)
                     (cl-remove-if
                      (lambda (c)
                        (or (not (cistern--tile-passable-p
                                  (cistern--cell st (car c) (cdr c))))
                            (gethash c (cistern--occupied-cells st nil))))
                      (cistern--neighbors st x y)))))
    (while (and spots (> n 0)
                (< (length (cistern-st-hostiles st))
                   (cistern--combat-k 'hostiles-max)))
      (let ((cell (car spots)))
        (cistern--spawn-enemy st faction kind (car cell) (cdr cell)))
      (setq spots (cdr spots) n (1- n)))))

(defun cistern--maybe-infestation (st)
  "S3 (COMBAT §4.3): every 20 ticks, DC = 14 − severed (min 8);
success = exactly one rat at a dead pipe + one `infestation' event."
  (let ((tick (cistern-st-tick st)))
    (when (and (> tick 0) (= 0 (% tick (cistern--combat-k 'infest-every))))
      (when (>= (cistern--combat-d20 st)
                (cistern--infest-dc (cistern--severed-count st)))
        (let ((pipe (cistern--dead-pipe-cell st)))
          (when pipe
            (cistern--spawn-near st 'fauna 'rat (car pipe) (cdr pipe) 1)
            (cistern--log st "%s"
                          (format (cistern--combat-copy 'combat-infest)
                                  (car pipe) (cdr pipe)))
            (push (list 'infestation 'infest (car pipe) (cdr pipe))
                  (cistern-st-rewards-events st))))))))

(defun cistern--floods-of-age (st age)
  "Flood cells that reach AGE ticks old THIS tick (one S4/S5 draw
per cell at its 20th tick — deterministic, no repeat draws)."
  (let ((tick (cistern-st-tick st)) (out nil))
    (dolist (pair (cistern-st-flood-born st))
      (when (= tick (+ (cdr pair) age))
        (push (car pair) out)))
    out))

(defun cistern--maybe-flood-fauna (st)
  "S4/S5 in pinned order (COMBAT §2): leech d20 ≥ 12, then sponge
d20 ≥ 14, one draw per flood tile reaching 20 ticks of age."
  (dolist (cell (cistern--floods-of-age st 20))
    (when (>= (cistern--combat-d20 st) (cistern--combat-k 'leech-dc))
      (cistern--spawn-near st 'fauna 'leech (car cell) (cdr cell) 1))
    (when (>= (cistern--combat-d20 st) (cistern--combat-k 'sponge-dc))
      (cistern--spawn-near st 'fauna 'sponge (car cell) (cdr cell) 1)
      (cistern--log st "%s" (cistern--combat-copy 'combat-sponge)))))

(defun cistern--maybe-guild (st)
  "S6 (COMBAT §4.4): while >= 2 lines are severed and no fixer is
present, one draw per 40 ticks; success = 1 fixer at the map edge +
one `guild-arrival' event."
  (let ((tick (cistern-st-tick st)))
    (when (and (> tick 0) (= 0 (% tick (cistern--combat-k 'guild-every)))
               (>= (cistern--severed-count st) 2)
               (not (cl-some (lambda (e)
                               (eq (cistern--enemy-kind e) 'fixer))
                             (cistern-st-hostiles st))))
      (when (>= (cistern--combat-d20 st) (cistern--combat-k 'guild-dc))
        (let ((cell (cistern--edge-spawn-cell st)))
          (when cell
            (cistern--spawn-enemy st 'guild 'fixer (car cell) (cdr cell))
            (cistern--log st "%s"
                          (format (cistern--combat-copy 'combat-guild-arrival)
                                  (cistern--combat-k 'guild-fee)))
            (push (list 'guild-arrival 'guild (car cell) (cdr cell))
                  (cistern-st-rewards-events st))))))))

(defun cistern--guild-behavior (st e)
  "GUILD OF THE OPEN FLANGE (COMBAT §1.3): walk to the nearest
dead pipe — the gnaw-made hazard, the pipe's remains (L-100) — 2
certified ticks restore it to `pipe' for a fixed 1-alloy fee
(cheaper than the player's re-lay; S4 untouched otherwise).
GNAW is the restoration timer, DRAIN the restoration count, IDLE
the ticks-since-productive counter.  Leaves after 3 restorations
or 40 idle ticks; with alloy 0 they wait 20 ticks and leave."
  (let ((x (cistern--enemy-x e)) (y (cistern--enemy-y e)))
    (cond
     ((> (cistern--enemy-gnaw e) 0) ; mid-restoration
      (setf (cistern--enemy-gnaw e) (1+ (cistern--enemy-gnaw e)))
      (when (>= (cistern--enemy-gnaw e) (cistern--combat-k 'guild-restore))
        (let* ((hz (cistern--nearest-map-cell
                    st (lambda (s px py)
                         (eq (cistern--cell s px py) 'hazard))
                    x y)))
          (when hz
            (cistern--set-cell st (car hz) (cdr hz) 'pipe)
            (setf (cistern-st-alloy st)
                  (- (cistern-st-alloy st) (cistern--combat-k 'guild-fee)))
            (cistern--log st "%s"
                          (format (cistern--combat-copy 'combat-guild-fix)
                                  (car hz) (cdr hz)))))
        (setf (cistern--enemy-gnaw e) 0
              (cistern--enemy-idle e) 0
              (cistern--enemy-drain e) (1+ (cistern--enemy-drain e)))
        (when (>= (cistern--enemy-drain e) (cistern--combat-k 'guild-max))
          (cistern--guild-depart st e))))
     (t
      (let ((hz (cistern--nearest-map-cell
                 st (lambda (s px py)
                      (eq (cistern--cell s px py) 'hazard))
                 x y)))
        (cond
         ;; no work at all: idle toward 40
         ((null hz)
          (setf (cistern--enemy-idle e) (1+ (cistern--enemy-idle e)))
          (when (>= (cistern--enemy-idle e) (cistern--combat-k 'guild-idle-max))
            (cistern--guild-depart st e)))
         ;; work exists but the fee can't be paid: wait 20
         ((< (cistern-st-alloy st) (cistern--combat-k 'guild-fee))
          (setf (cistern--enemy-idle e) (1+ (cistern--enemy-idle e)))
          (when (>= (cistern--enemy-idle e)
                    (cistern--combat-k 'guild-broke-wait))
            (cistern--guild-depart st e)))
         ;; adjacent: begin the certified restoration
         ((= 1 (+ (abs (- (car hz) x)) (abs (- (cdr hz) y))))
          (setf (cistern--enemy-gnaw e) 1))
         ;; otherwise walk toward it
         (t (cistern--enemy-step-toward st e (car hz) (cdr hz)))))))))

(defun cistern--guild-depart (st e)
  "LOG-ONLY departure (ruling 3: `guild-depart' is not an event
kind; nothing reads it).  The fixer retreats to the map edge."
  (setf (cistern--enemy-grip e) 'retreat)
  (cistern--log st "%s" (cistern--combat-copy 'combat-guild-depart)))

;; ---------------------------------------------------------------------------
;; V5-04 (COMBAT §1.1/§1.2/§3.2): per-hostile behavior and the phase.

(defun cistern--enemy-blocked (st e)
  "Cells a hostile cannot enter: other workers + other hostiles."
  (let ((h (cistern--occupied-cells st nil)))
    (dolist (o (cistern-st-hostiles st))
      (unless (eq o e)
        (puthash (cons (cistern--enemy-x o) (cistern--enemy-y o)) t h)))
    h))

(defun cistern--enemy-step-toward (st e tx ty)
  "One 1-step move per tick through the flood-distance field,
same walkability as workers (COMBAT §1.1)."
  (let* ((x (cistern--enemy-x e)) (y (cistern--enemy-y e))
         (blocked (cistern--enemy-blocked st e))
         (dist (cistern--dist-from st tx ty blocked 'always x y))
         (d0 (gethash (cons x y) dist)))
    (when (and d0 (> d0 0))
      (let (nxt)
        (dolist (n (cistern--neighbors st x y))
          (let ((dd (gethash n dist)))
            (when (and dd (= dd (1- d0)) (not (gethash n blocked)) (not nxt))
              (setq nxt n))))
        (when nxt
          (setf (cistern--enemy-x e) (car nxt)
                (cistern--enemy-y e) (cdr nxt)))))))

(defun cistern--nearest-map-cell (st pred x y)
  "Nearest cell satisfying PRED by manhattan distance, ties broken
in coordinate order (deterministic; the nearest-structure pattern)."
  (let ((best nil) (bd nil) (i 0) (maxi (length (cistern-st-map st))))
    (while (< i maxi)
      (let* ((cx (% i (cistern-st-w st))) (cy (/ i (cistern-st-w st))))
        (when (funcall pred st cx cy)
          (let ((d (+ (abs (- cx x)) (abs (- cy y)))))
            (when (or (null bd) (< d bd))
              (setq bd d best (cons cx cy))))))
      (setq i (1+ i)))
    best))

(defun cistern--adjacent-worker (st e)
  "A non-seated worker 4-adjacent to hostile E (creators order;
no attack while the worker is seated mid-use, COMBAT §3.2)."
  (cl-find-if
   (lambda (w)
     (and (not (cistern--worker-using w))
          (= 1 (+ (abs (- (cistern--worker-x w) (cistern--enemy-x e)))
                  (abs (- (cistern--worker-y w) (cistern--enemy-y e)))))))
   (cistern-st-creators st)))

(defun cistern--hostile-strike (st e)
  "E strikes an adjacent worker ONCE per tick (COMBAT §3.2):
warband rolls dmg-warband, everything else dmg-minor; worker DEF =
10 + GRIT mod; damage lands through the injury ladder."
  (let* ((w (cistern--adjacent-worker st e))
         (matrix (if (eq (cistern--enemy-faction e) 'warband)
                     'dmg-warband 'dmg-minor))
         (effect (cistern--combat-strike st matrix
                                         (cistern--enemy-atk e)
                                         (cistern--worker-def w))))
    (when (and w (> (plist-get effect :dmg) 0))
      (cistern--worker-damage st w (plist-get effect :dmg)))))

(defun cistern--gnaw-complete (st e)
  "A finished gnaw converts the pipe to `hazard' (COMBAT §1.1):
the pipe is GONE, the usual hazard decay applies, downstream
severance follows from the EXISTING connectivity (L-040 untouched),
the player re-lays with `p' at the usual cost."
  (let ((x (cistern--enemy-x e)) (y (cistern--enemy-y e)))
    (cistern--set-cell st x y 'hazard)
    (setf (cistern--enemy-gnaw e) 0)
    (cistern--log st "%s"
                  (format (cistern--combat-copy 'combat-gnaw) x y))))

(defun cistern--warband-behavior (st e)
  "Pinned priority (COMBAT §1.1): strike → gnaw → steal → harass.
IDLE carries the raid-open objective (0/1/2); DRAIN the claim
accumulator; GNAW the 4-tick pipe timer."
  (if (cistern--adjacent-worker st e)
      (cistern--hostile-strike st e)
    (let ((x (cistern--enemy-x e)) (y (cistern--enemy-y e)))
      (pcase (cistern--enemy-idle e)
        (0 ; gnaw — nearest live pipe; a 4-tick timer standing on it
         (let ((pipe (cistern--nearest-map-cell
                      st (lambda (s px py)
                           (and (eq (cistern--cell s px py) 'pipe)
                                (cistern--pipe-live-p s px py)))
                      x y)))
           (when pipe
             (if (equal (cons x y) pipe)
                 (setf (cistern--enemy-gnaw e) (1+ (cistern--enemy-gnaw e)))
               (cistern--enemy-step-toward st e (car pipe) (cdr pipe)))
             (when (>= (cistern--enemy-gnaw e) 4)
               (cistern--gnaw-complete st e)))))
        (1 ; steal — nearest tank with load > 0; 5 units/tick claimed
         (let ((tk (cistern--nearest-tank st x y)))
           (when tk
             (let ((tp (gethash tk (cistern-st-tanks st))))
               (if (equal (cons x y) tk)
                   (let* ((load (plist-get tp :load))
                          (take (min 5 load)))
                     (puthash tk (plist-put tp :load (- load take))
                              (cistern-st-tanks st))
                     (setf (cistern--enemy-drain e)
                           (+ take (cistern--enemy-drain e)))
                     (cistern--log st "%s"
                                   (format (cistern--combat-copy 'combat-tank-raid)
                                           (car tk) (cdr tk)
                                           (cistern--enemy-drain e))))
                 (cistern--enemy-step-toward st e (car tk) (cdr tk)))))))
        (2 ; harass — step toward the nearest non-limping worker (P5)
         (let ((w (cl-find-if
                   (lambda (w)
                     (not (eq (cistern--worker-injury-state w) 'limp)))
                   (cistern-st-creators st))))
           (when w
             (cistern--enemy-step-toward st e (cistern--worker-x w)
                                         (cistern--worker-y w)))))))))

(defun cistern--retreat-step (st e)
  "Retreat (COMBAT §1.1/§1.2): walk to the nearest map edge,
despawn on arrival."
  (let* ((x (cistern--enemy-x e)) (y (cistern--enemy-y e))
         (edges (list (cons 0 y) (cons (1- (cistern-st-w st)) y)
                      (cons x 0) (cons x (1- (cistern-st-h st)))))
         (tgt (car (sort (copy-sequence edges)
                         (lambda (a b)
                           (< (+ (abs (- (car a) x)) (abs (- (cdr a) y)))
                              (+ (abs (- (car b) x)) (abs (- (cdr b) y)))))))))
    (if (or (= x 0) (= y 0)
            (= x (1- (cistern-st-w st))) (= y (1- (cistern-st-h st))))
        (setf (cistern-st-hostiles st) (delq e (cistern-st-hostiles st)))
      (cistern--enemy-step-toward st e (car tgt) (cdr tgt)))))

(defun cistern--rat-behavior (st e)
  "Pipe-rat (COMBAT §1.2): gnaws pipes (3 ticks); prefers
severed-line joints (dead pipes first)."
  (let* ((x (cistern--enemy-x e)) (y (cistern--enemy-y e))
         (on-pipe (eq (cistern--cell st x y) 'pipe)))
    (if on-pipe
        (progn (setf (cistern--enemy-gnaw e) (1+ (cistern--enemy-gnaw e)))
               (when (>= (cistern--enemy-gnaw e) 3)
                 (cistern--gnaw-complete st e)))
      (let ((tgt (or (cistern--nearest-map-cell
                      st (lambda (s px py)
                           (and (eq (cistern--cell s px py) 'pipe)
                                (not (cistern--pipe-live-p s px py))))
                      x y)
                     (cistern--nearest-map-cell
                      st (lambda (s px py)
                           (eq (cistern--cell s px py) 'pipe))
                      x y))))
        (when tgt
          (cistern--enemy-step-toward st e (car tgt) (cdr tgt)))))))

(defun cistern--crab-behavior (st e)
  "Clog-crab (COMBAT §1.2): occupies a usable toilet; pinches
adjacency (strikes adjacent workers, dmg-minor)."
  (cistern--hostile-strike st e))

(defun cistern--leech-behavior (st e)
  "Vent-leech (COMBAT §1.2): band ≥ 2 ATTACHES (one attack roll vs
the worker's DEF); attached, it drains 1 HP per 4 ticks —
mechanical, not rolled.  The host's death removes it (§3.4)."
  (if (cistern--enemy-grip e)
      (progn
        (setf (cistern--enemy-drain e) (1+ (cistern--enemy-drain e)))
        (when (>= (cistern--enemy-drain e) (cistern--combat-k 'leech-interval))
          (setf (cistern--enemy-drain e) 0)
          (cistern--worker-damage st (cistern--enemy-grip e) 1)))
    (let ((w (cistern--adjacent-worker st e)))
      (when w
        (let ((band (cistern--combat-band st (cistern--enemy-atk e)
                                           (cistern--worker-def w))))
          (when (>= band 2)
            (setf (cistern--enemy-grip e) w)
            (cistern--log st "%s"
                          (format (cistern--combat-copy 'combat-leech-grip)
                                  (cistern--worker-glyph st w)))))))))

(defun cistern--sponge-behavior (st e)
  "Sump-sponge (COMBAT §1.2): immobile; absorbs 1 unit/tick from
the nearest tank with load; splits at 20, cap P2 respected."
  (let ((tk (cistern--nearest-tank st (cistern--enemy-x e)
                                   (cistern--enemy-y e))))
    (when tk
      (let ((tp (gethash tk (cistern-st-tanks st))))
        (when (> (plist-get tp :load) 0)
          (puthash tk (plist-put tp :load (1- (plist-get tp :load)))
                   (cistern-st-tanks st))
          (setf (cistern--enemy-drain e) (1+ (cistern--enemy-drain e)))
          (when (and (>= (cistern--enemy-drain e)
                         (cistern--combat-k 'sponge-split))
                     (< (length (cistern-st-hostiles st))
                        (cistern--combat-k 'hostiles-max)))
            (setf (cistern--enemy-drain e) 0)
            (cistern--spawn-near st 'fauna 'sponge
                                 (cistern--enemy-x e) (cistern--enemy-y e) 1)
            (cistern--log st "%s"
                          (cistern--combat-copy 'combat-sponge))))))))

(defun cistern--enemy-damage (st e n killer)
  "N damage to hostile E from worker KILLER (COMBAT §3.2): a crab
that takes ANY hit drive-offs (retreats); hp 0 removes the entity,
grants +1 XP, pushes `goblin-death' (ruling 3) and clears focus."
  (setf (cistern--enemy-hp e) (- (cistern--enemy-hp e) n))
  (when (and (eq (cistern--enemy-kind e) 'crab)
             (> (cistern--enemy-hp e) 0)
             (not (cistern--enemy-retreat-p e)))
    (setf (cistern--enemy-grip e) 'retreat)
    (cistern--log st "%s"
                  (format (cistern--combat-copy 'combat-drive-off)
                          (cistern--enemy-x e) (cistern--enemy-y e))))
  (when (<= (cistern--enemy-hp e) 0)
    (setf (cistern-st-hostiles st) (delq e (cistern-st-hostiles st)))
    (when killer (cistern--rpg-grant-xp st killer 1))
    (when (equal (cistern-st-focus st) (cistern--enemy-id e))
      (setf (cistern-st-focus st) nil))
    (push (list 'goblin-death (cistern--enemy-kind e)
                (cistern--enemy-x e) (cistern--enemy-y e))
          (cistern-st-rewards-events st))))

(defun cistern--auto-defense (st)
  "Worker auto-defense (COMBAT §3.2): one attack per tick, rolled
in creators order after the hostile behaviors; targeting = focus
else nearest adjacent, ALWAYS guild-filtered; seated workers
don't attack; kills/drive-offs grant +1 XP."
  (dolist (w (copy-sequence (cistern-st-creators st)))
    (unless (cistern--worker-using w)
      (let ((tgt (cistern--combat-target st w)))
        (when tgt
          (let ((effect (cistern--combat-strike st 'dmg-minor
                                                (cistern--rpg-stat-mod w 0)
                                                (cistern--enemy-def tgt))))
            (when (> (plist-get effect :dmg) 0)
              (cistern--enemy-damage st tgt (plist-get effect :dmg) w))))))))

(defun cistern--phase-hostiles (st)
  "V5-04: the combat tick slot (COMBAT §5.1/§5.2), pinned between
creators and hazards so gnaw-made hazards participate in the same
tick's decay/spread.  Stream-4 order: S-spawn draws (S1–S5) → per
hostile, list order: behavior draws then strikes → worker
auto-defense (creators order).  Event pushes drain NOTHING —
rewards-eval stays the sole drainer (L-027)."
  (when cistern-combat-enabled
  ;; P3: the raid span caps at 40 ticks, then forced withdrawal
  (let ((raid (cistern-st-raid st)))
    (when (and (plist-get raid :open)
               (>= (- (cistern-st-tick st) (plist-get raid :open))
                   (cistern--combat-k 'raid-span)))
      (cistern--raid-close st nil)))
  ;; the spawn table, pinned order S1..S5 (S6 guild lands V5-05)
  (cistern--maybe-raid st)
  (cistern--maybe-ambush st)
  (cistern--maybe-infestation st)
  (cistern--maybe-flood-fauna st)
  (cistern--maybe-guild st)
  ;; per hostile, in list (spawn) order
  (dolist (e (copy-sequence (cistern-st-hostiles st)))
    (cond ((cistern--enemy-retreat-p e) (cistern--retreat-step st e))
          ((eq (cistern--enemy-faction e) 'warband)
           (cistern--warband-behavior st e))
          ((eq (cistern--enemy-kind e) 'rat) (cistern--rat-behavior st e))
          ((eq (cistern--enemy-kind e) 'crab) (cistern--crab-behavior st e))
          ((eq (cistern--enemy-kind e) 'leech) (cistern--leech-behavior st e))
          ((eq (cistern--enemy-kind e) 'sponge)
           (cistern--sponge-behavior st e))
          ((eq (cistern--enemy-kind e) 'fixer)
           (cistern--guild-behavior st e))))
  (cistern--auto-defense st)
  ;; every raider killed/driven off before the cap → the routed close
  (when (and (cistern-st-raid st)
             (plist-get (cistern-st-raid st) :open)
             (not (cl-some (lambda (e)
                             (eq (cistern--enemy-faction e) 'warband))
                           (cistern-st-hostiles st))))
    (cistern--raid-close st t))))

(defun cistern--story-tier-face (tier)
  "V4-22 rarity surfacing: the tier maps onto the existing severity
faces - common = info (dim), occasional = warning, rare = error
(the most prominent face in the browser)."
  (pcase tier
    ('occasional 'warning)
    ('rare 'error)
    (_ 'info)))

(defun cistern--add-event-tile (st x y)
  "V4-22 (S3.2): spawn a ! event tile on clean, unoccupied floor -
a silent 3-tick countdown (each standing tick logs nothing)."
  (when (and (cistern--in-bounds-p st x y)
             (eq (cistern--cell st x y) 'floor)
             (not (gethash (cons x y) (cistern--occupied-cells st nil))))
    (cistern--set-cell st x y 'event)
    (setf (cistern-st-event-tiles st)
          (append (cistern-st-event-tiles st)
                  (list (cons (cons x y) 3))))
    t))

(defun cistern--phase-events (st)
  "V4-22: decay the event tiles' countdowns per tick; expiry
renders nothing (the cell returns to floor)."
  (let ((remaining nil))
    (dolist (tile (cistern-st-event-tiles st))
      (let* ((cell (car tile))
             (left (1- (cdr tile))))
        (if (> left 0)
            (push (cons cell left) remaining)
          (when (eq (cistern--cell st (car cell) (cdr cell)) 'event)
            (cistern--set-cell st (car cell) (cdr cell) 'floor)))))
    (setf (cistern-st-event-tiles st) (nreverse remaining))
    st))

(defun cistern--cache-pickup (st w)
  "V4-22 (S3.2): the first worker to walk over a cache banks its
alloy bonus; the tile clears to floor and the pickup logs success."
  (let ((x (cistern--worker-x w)) (y (cistern--worker-y w)))
    (when (eq (cistern--cell st x y) 'cache)
      (cistern--set-cell st x y 'floor)
      (setf (cistern-st-alloy st) (+ (cistern-st-alloy st)
                                     cistern--cache-alloy))
      (cistern--log-sev st 'success "%s"
                        (format (cdr (assq 'cache-pickup cistern--copy))
                                (cistern--worker-glyph st w)
                                cistern--cache-alloy)))))

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
                                    (:spike 0 :xp 1)))
                ;; V5-02 (COMBAT §3.1): the two damage matrices, folded
                ;; into the ONE hash at load time — no second band
                ;; vocabulary, no new matrix id per verb (A9).  Band 0
                ;; is a MISS: damage 0, nothing logs.
                (dmg-minor . ((:dmg 0) (:dmg 1) (:dmg 1) (:dmg 2)))
                (dmg-warband . ((:dmg 0) (:dmg 1) (:dmg 2) (:dmg 3)))))
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

(defun cistern--margin-band (margin)
  "STORY §6.2 band mapping, one ruling for every d20 consumer:
margin ≤ −5 → 0, −4..−1 → 1, 0..+4 → 2, ≥ +5 → 3."
  (cond ((<= margin -5) 0) ((<= margin -1) 1)
        ((<= margin 4) 2) (t 3)))

(defun cistern--rpg-band (st dc mod)
  "One d20 check band (RPG §3.3): stat = clamp(mod, −2, +2),
D&D banding, nat-20 promotes to band 3 / nat-1 demotes to band 0."
  (let* ((r (cistern--rpg-d20-pos (cistern-st-rpg-pos st)))
         (roll (car r))
         (margin (+ roll (clamp -2 mod 2) (- dc)))
         (band (cistern--margin-band margin)))
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
  "Identity glyph for worker W from its STORED spawn-index (V5-01,
COMBAT §3.4.2: the index is assigned at creation and never
renumbered — a death renames nobody).  The map, the inspector and
the accident log all name the worker by this glyph (Q14: no
format drift, no off-by-one)."
  (let ((i (or (cistern--worker-spawn-idx w)
               (cl-position w (cistern-st-creators st) :test #'eq)
               0)))
    (aref cistern--worker-glyphs
          (mod i (length cistern--worker-glyphs)))))

;; ---------------------------------------------------------------------------
;; V5-03 (COMBAT §3.3/§3.4): the injury ladder and worker death.
;; Effects land on EXISTING numbers only (P4): no combat effect ever
;; writes bladder, use ticks, purge rate, or costs.

(defun cistern--worker-hp-max (w)
  "Max hp: 8 + GRIT mod, fixed at spawn (derived from the dossier)."
  (+ 8 (cistern--rpg-mod (nth 1 (cistern--worker-stats w)))))

(defun cistern--worker-injury-state (w)
  "The injury state from hp: `limp' at ≤ 60% of max, `shaken' at
≤ 40%, nil when healthy (COMBAT §3.3)."
  (when (cistern--worker-hp w)
    (let* ((max (cistern--worker-hp-max w))
           (hp (cistern--worker-hp w)))
      ;; exact integer floors of 40% / 60% of max (no float rounding)
      (cond ((<= hp (/ (* 2 max) 5)) 'shaken)
            ((<= hp (/ (* 3 max) 5)) 'limp)
            (t nil)))))

(defun cistern--worker-nerve-eff (w)
  "NERVE mod with the SHAKEN −2; `cistern--rpg-seek-eff' applies
the EXISTING [50,68] clamp, so the envelope is untouched."
  (- (cistern--rpg-stat-mod w 2)
     (if (eq (cistern--worker-injury-state w) 'shaken) 2 0)))

(defun cistern--worker-mine-rate (w)
  "Ore-ticks per alloy with the injury couplings: hp < max → +1
through the EXISTING clamp (mining loss, never mobility); sickness
doubles (RPG §1, unchanged)."
  (let ((rate (cistern--rpg-mine-rate (cistern--rpg-stat-mod w 0))))
    (when (and (cistern--worker-hp w)
               (< (cistern--worker-hp w) (cistern--worker-hp-max w)))
      (setq rate (clamp 2 (1+ rate) 6)))
    (if (> (cistern--worker-sick w) 0) (* 2 rate) rate)))

(defun cistern--worker-death (st w)
  "The death procedure (COMBAT §3.4): remove from creators, drop
any journey, clear a mid-use toilet's :busy, remove a gripping
leech with the body, log + emit `worker-death' (pending list;
rewards-eval ignores the kind, the story hook machine reads it).
The spawn-index pins identity — the death renames nobody."
  (let ((glyph (cistern--worker-glyph st w)))
    (when (cistern--worker-using w)
      (let ((tp (cistern--worker-toilet w)))
        (when tp
          (puthash tp (list :busy nil
                            :type (or (plist-get (gethash tp
                                                          (cistern-st-toilets st))
                                                 :type)
                                      'long-drop))
                    (cistern-st-toilets st)))))
    (setf (cistern--worker-using w) nil)
    (setf (cistern--worker-journey w) nil)
    (setf (cistern-st-creators st) (delq w (cistern-st-creators st)))
    ;; a leech whose host dies is removed with the body (no
    ;; goblin-death event for it — ruling 3)
    (setf (cistern-st-hostiles st)
          (cl-remove-if (lambda (e) (eq (cistern--enemy-grip e) w))
                        (cistern-st-hostiles st)))
    (cistern--log-sev st 'error "%s"
                      (format (cistern--combat-copy 'combat-worker-death)
                              glyph))
    (push (list 'worker-death glyph) (cistern-st-rewards-events st))
    ;; V5-11 (SOCIAL §2.6): the dead endpoint's files close
    (cistern--romance-end st w)))

(defun cistern--worker-damage (st w n)
  "Subtract N hp from worker W (COMBAT §3.3), log the injury-state
crossings through the copy table, and run the death procedure at
hp ≤ 0 — in the same phase the damage landed."
  (when (cistern--worker-hp w)
    (let ((prev (cistern--worker-injury-state w)))
      (setf (cistern--worker-hp w) (- (cistern--worker-hp w) n))
      (let ((now (cistern--worker-injury-state w))
            (glyph (cistern--worker-glyph st w)))
        (cond ((and (eq now 'shaken) (not (eq prev 'shaken)))
               (cistern--log st "%s"
                             (format (cistern--combat-copy 'combat-injury-shaken)
                                     glyph)))
              ((and (eq now 'limp) (not (member prev '(limp shaken))))
               (cistern--log st "%s"
                             (format (cistern--combat-copy 'combat-injury-limp)
                                     glyph)))))
      (when (<= (cistern--worker-hp w) 0)
        (cistern--worker-death st w)))))

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
  "V5-04 (COMBAT §1.2): crab-occupied cells are excluded — an
ACCESS-reality read, not a new rule."
  (let ((out nil)
        (crabs (cistern--kind-cells st 'crab)))
    (maphash (lambda (k v)
               (when (and (cistern--toilet-usable-p st (car k) (cdr k))
                          (not (gethash k crabs))
                          ;; V5-15 (COMEDY §2.2 #5): the aesthetic
                          ;; refusal drops the marked fixture
                          (not (plist-get v :aesthetic-p)))
                 (push k out)))
             (cistern-st-toilets st))
    (sort out (lambda (a b) (< (car a) (car b))))))

(defun cistern--kind-cells (st kind)
  "Hash of the cells occupied by hostiles of KIND."
  (let ((h (make-hash-table :test #'equal)))
    (dolist (e (cistern-st-hostiles st))
      (when (eq (cistern--enemy-kind e) kind)
        (puthash (cons (cistern--enemy-x e) (cistern--enemy-y e)) t h)))
    h))

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
  (let* ((stats (cistern--rpg-roll-stats st))
         (w (cistern--worker-make :x x :y y :bladder 20
                                 ;; V5-01: the stable spawn-index is
                                 ;; monotonic — initial procgen workers
                                 ;; take 0..3, migrant N takes 4+N
                                 :spawn-idx (+ 4 (cistern-st-migrants st))
                                 ;; V5-03 (COMBAT §3.3): max hp rolled
                                 ;; at spawn alongside the dossier
                                 :hp (+ 8 (cistern--rpg-mod (nth 1 stats)))
                                 :stats stats)))
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
                    ;; V5-03: the mine rate reads the worker helper —
                    ;; mining loss (+1, clamped) and sickness (×2)
                    (cistern--worker-mine-rate w))
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
                 ;; V5-03 (COMBAT §3.3/P5): LIMP = 1 step per 2 ticks,
                 ;; stride off — SUSPENDED on relief journeys (the gait
                 ;; normalizes until the worker is seated).  Mining and
                 ;; rally journeys limp normally.
                 (limp (eq (cistern--worker-injury-state w) 'limp))
                 (relief (eq (cistern--cell st tx ty) 'toilet))
                 (stride (and fresh
                              (not (and limp (not relief)))
                              (>= (cistern--rpg-band
                                   st
                                   (cdr (assq 'stride-dc
                                              cistern--rpg-const))
                                   (cistern--rpg-stat-mod w 3))
                                  2)))
                 (steps (cond ((and limp (not relief))
                               (if (= 0 (% (cistern-st-tick st) 2)) 1 0))
                              (stride 2)
                              (t 1))))
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
                                     ;; V5-03: SHAKEN reads NERVE −2
                                     (cistern--rpg-seek-eff
                                      (cistern--worker-nerve-eff w))))
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
    ;; V5-04: record the birth tick — the S4/S5 spawn draws read
    ;; "flood open ≥ 20 ticks" off this alist
    (setf (cistern-st-flood-born st)
          (cons (cons (cons x y) (cistern-st-tick st))
                (cistern-st-flood-born st)))
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
      (push (list 'burst line) (cistern-st-rewards-events st))
      ;; V5-10 (SOCIAL §1.4 rows 1-2): the breach as a located event
      ;; the trigger table reads; rewards and story ignore the kind
      (push (list 'breach 'breach (cistern--worker-x w)
                  (cistern--worker-y w))
            (cistern-st-rewards-events st)))))

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
              ;; V5-03: SHAKEN reads NERVE −2
              (cistern--rpg-seek-eff (cistern--worker-nerve-eff w)))
          (cistern--seek-toilet st w))
         ;; V5-06 (COMBAT §4.5): a rally journey walks first (relief
         ;; outranks it — the base game's own priority holds); arrival
         ;; clears the journey and the worker resumes seek-work.  A
         ;; rally journey points at a FLOOR cell, so the kinds never
         ;; collide with the walk targets seek-work (ore) and
         ;; seek-toilet (toilet) set into the same slot.
         ((and (cistern--worker-journey w)
               (eq (cistern--cell st (car (cistern--worker-journey w))
                                (cdr (cistern--worker-journey w)))
                   'floor))
          (let ((j (cistern--worker-journey w)))
            (cistern--step-toward st w (car j) (cdr j))
            (when (and (= (cistern--worker-x w) (car j))
                       (= (cistern--worker-y w) (cdr j)))
              (setf (cistern--worker-journey w) nil))))
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
              (cistern--set-cell st (car h) (cdr h) 'floor)
              ;; V5-04: a dried flood leaves the age alist
              (setf (cistern-st-flood-born st)
                    (cl-remove-if (lambda (p) (equal (car p) h))
                                  (cistern-st-flood-born st))))
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
      (cistern--rpg-grant-xp st w 1)
      ;; V5-03 (COMBAT §3.3): +1 hp per shift boundary — no cost, no
      ;; roll, deterministic recovery
      (when (and (cistern--worker-hp w)
                 (< (cistern--worker-hp w) (cistern--worker-hp-max w)))
        (setf (cistern--worker-hp w) (1+ (cistern--worker-hp w))))))
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
  "One full simulation tick (V5-04 pinned phase order, COMBAT
§5.1): creators → hostiles → hazards → migration → check (the
event-tiles phase keeps its post-hazards slot)."
  (setf (cistern-st-tick st) (1+ (cistern-st-tick st)))
  (cistern--phase-creators st)
  (cistern--phase-hostiles st)
  (cistern--phase-hazards st)
  (cistern--phase-events st)
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
    ;; V5-01 (COMBAT §5.2): the combat child stream (seed ⊕ 4)
    ;; initializes at construction, like the RPG stream
    (setf (cistern-st-combat-pos st)
          (cistern--stream-init (cistern-st-seed st) 4))
    (let ((i 0))
      (dolist (p cistern--procgen-spawns)
      (let* ((stats (cistern--rpg-roll-stats st))
             (w (cistern--worker-make :x (nth 0 p) :y (nth 1 p)
                                      :spawn-idx i
                                      ;; V5-03 (COMBAT §3.3): max hp at spawn
                                      :hp (+ 8 (cistern--rpg-mod (nth 1 stats)))
                                      :stats stats)))
        (setf (cistern-st-creators st) (append (cistern-st-creators st)
                                               (list w)))
        (setq i (1+ i)))))
    (setf (cistern-st-migrants st) 0)
    (setf (cistern-st-built-at st) (make-hash-table :test #'equal))
    ;; Q03 (REWARDS-DESIGN §1): the starter card is dealt from tick
    ;; one — serve 3, ceiling 5 — so the whole goal loop is live
    ;; without test injection.  One call, via the existing setter.
    (cistern--cmd-set-goal-card st cistern--starter-card)
    (cistern--log st "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
    ;; V4-15 (STORY §3.1): the spine generates immediately after the
    ;; starter card; a no-op when no banks are loaded
    (cistern--story-generate st)
    ;; V5-08 (SOCIAL §1.2): the persona pass — worker α and the
    ;; starter toilet first (the pinned SC1 pair: 6 draws, L-102),
    ;; then the remaining initial workers in creators order.  A no-op
    ;; with no quirk banks (social-disabled runs).
    (setf (cistern-st-personas st) (make-hash-table :test #'equal))
    (setf (cistern-st-social-pos st)
          (cistern--stream-init (cistern-st-seed st) 5))
    (let ((workers (cistern-st-creators st)))
      (when workers
        (cistern--social-spawn-persona
         st (cistern--worker-glyph st (nth 0 workers)) 'worker))
      (cistern--social-spawn-persona st (list :toilet 3 3) 'fixture)
      (dolist (w (cdr workers))
        (cistern--social-spawn-persona
         st (cistern--worker-glyph st w) 'worker)))
    (setf (cistern-st-relationships st) (make-hash-table :test #'equal))
    (setf (cistern-st-comedy st)
          (list :pos (cistern--stream-init (cistern-st-seed st) 6)
                :last-beat-tick 0 :due-p nil :recent nil :active nil
                :anchors nil :cooldowns nil :drills 0 :place-names nil
                :last-close nil))
    st))

(defun cistern--story-generate (st)
  "STORY §3: build the session's story plist from the loaded banks.
Stream 1 only (one consumption pass); stream 2's :roll-pos is
initialized but never advanced here.  No banks means nil story (a
legal no-op state for tests)."
  (when (and cistern--banks
             (consp (plist-get cistern--banks :scenarios))
             (consp (plist-get cistern--banks :quirks)))
    (let* ((pos (cistern--stream-init (cistern-st-seed st) 1))
           (scenarios (plist-get cistern--banks :scenarios))
           (quirks (plist-get cistern--banks :quirks))
           (draw (lambda (n)
                   (let ((p (cistern--stream-next pos)))
                     (setq pos p)
                     (% (ash p -6) n))))
           (sc (if (null (cdr scenarios))
                   (car scenarios)
                 (nth (funcall draw (length scenarios)) scenarios)))
           (cast-n (+ 2 (funcall draw 2)))
           (cast nil))
      (dotimes (_ cast-n)
        (let ((idx (funcall draw (length (cistern-st-creators st)))))
          (push (cons idx
                      (plist-get (nth (funcall draw (length quirks)) quirks)
                                 :id))
                cast)))
      (setq cast (nreverse cast))
      (let ((story (list :premise-id (plist-get sc :id)
                         :cast cast
                         :act 1
                         :hooks (mapcar (lambda (h)
                                          (append h (list :state 'dormant)))
                                        (plist-get sc :hooks))
                         :callbacks nil
                         :roll-pos (cistern--stream-init
                                    (cistern-st-seed st) 2)
                         :announced nil
                         :scenario sc)))
        (setf (cistern-st-story st) story)
        (cistern--log-sev st 'info "%s"
                          (cistern--story-copy-key
                           (plist-get sc :premise)))
        (let ((gm (plist-get sc :goal-mod)))
          (when gm
            (let* ((card (copy-tree (cistern-st-goal-card st)))
                   (goals (plist-get card :goals))
                   (delta 0))
              (dolist (pair (plist-get gm :target-mod))
                (dolist (g goals)
                  (when (eq (plist-get g :kind) (car pair))
                    (setf (plist-get g :target)
                          (+ (plist-get g :target) (cdr pair)))
                    (setq delta (+ delta (cdr pair))))))
              (plist-put card :goals goals)
              (cistern--cmd-set-goal-card st card)
              (when (> delta 0)
                (cistern--log-sev st 'info "%s"
                                  (format (cdr (assq 'story-goal-mod
                                                     cistern--copy))
                                          delta))))))
        story))))

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
(defun cistern--social-copy (key)
  "V5-10: one lookup into the (social . ...) copy subsection
(spec §0 copy-table rule)."
  (cdr (assq key (cdr (assq 'social cistern--copy)))))

(defun cistern--combat-copy (key)
  "V5-07: one lookup into the (combat . ...) copy subsection
(spec §0 copy-table rule; wave 2 adds social/comedy the same way)."
  (cdr (assq key (cdr (assq 'combat cistern--copy)))))

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
    (tutorial-line-fmt . "TUTORIAL %d/%d: %s  (C-t skips)")
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
    (story-goal-mod . "WATCH ORDER AMENDED — %d SERVED")
    (cache-pickup . "CACHE BANKED BY %s - +%d ALLOY")
    (inspector-stat-fmt . "F%+d G%+d N%+d A%+d")
    (inspector-clear-fmt . "CL.%s")
    ;; V5-03 (COMBAT §4.7): injury ladder + death (the full combat
    ;; subsection lands with V5-07's copy sweep)
    ;; V5-04 (COMBAT §4.7): raids, ambush, infestation, gnaw, steal,
    ;; leech, drive-off, sponge
    ;; V5-05 (COMBAT §4.7): the guild family + the focus refusal
    ;; V5-07: the (combat . ...) subsection — COMBAT §4.7 verbatim
    (combat . (
    (combat-injury-limp . "WORKER %s INJURED — LIMP LOGGED — GAIT NORMALIZED ON RELIEF RUNS")
      (combat-injury-shaken . "WORKER %s SHAKEN — NERVE DEGRADED — WATCH THE THRESHOLD")
      (combat-worker-death . "WORKER %s LOST — SERVICE RECORD SEALED")
      (combat-raid-open . "RAID — THE INHERITORS CLAIM THE MAIN — %d HOSTILE")
      (combat-raid-close . "RAID CLOSED — THE INHERITORS WITHDRAW — CLAIM NOT RECOGNIZED")
      (combat-raid-routed . "THE MAIN HOLDS — INHERITORS ROUTED — THE SECTOR REMAINS SERVED")
      (combat-ambush . "AMBUSH AT ISOLATED PLUMBING — (%d,%d)")
      (combat-infest . "INFESTATION — GNAWING LOGGED AT (%d,%d)")
      (combat-gnaw . "LINE SEVERED BY GNAW AT (%d,%d) — RE-LAY (p)")
      (combat-tank-raid . "TANK (%d,%d) DRAWN DOWN — %d UNITS CLAIMED")
      (combat-leech-grip . "VENT-LEECH ATTACHED — WORKER %s — CUT IT OFF")
      (combat-drive-off . "CLOG-CRAB DRIVEN OFF — (%d,%d)")
      (combat-sponge . "SPONGE MASS RECLASSIFIED FAUNA — FEEDING LOGGED AS NATURAL")
      (combat-guild-arrival . "GUILD OF THE OPEN FLANGE ON SITE — RESTORATIONS AT %d ALLOY")
      (combat-guild-fix . "GUILD RESTORATION COMPLETE AT (%d,%d)")
      (combat-guild-depart . "GUILD DEPARTS — WORK ORDER CLOSED")
      (combat-refusal-friendly . "GUILD STANDING — NO HOSTILE ACTION AGAINST CHARTERED ENGINEERS")
      (combat-warband-intel . "THE PIPES PREDATE THE SECTOR. SANITATION IS TRESPASS.")
      (combat-guild-intel . "GUILD OF THE OPEN FLANGE — RESTORATIONS AT ONE ALLOY")
      (combat-inspect-fmt . "%s %s — %s · HP %d/%d · DEF %d · ATK %+d")
      ))
    ;; V5-10 (SOCIAL §4.6): the social copy family — stage keys ride
    ;; in V5-11's romance graph
    (social . (
      (social-mutter-fmt . "WORKER %s MUTTERS — %s")
      (social-file-fmt . "%s FILES A %s")
      (social-stage-fmt . "%s AND %s ARE %s — %s")
      (social-stage-close . "THE FILE OF %s AND %s IS CLOSED — SEE OBITUARY")
      (social-objection . "GOBLIN %s OBJECTS TO %s's LIAISON — REVIEW DUE")))
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

(defconst cistern--bank-kinds
  '(scenario quirk keyword flavor dialogue thought whimsey)
  "The bank kinds (STORY §4.2; dialogue = V4-SPEC §2, wave 3;
thought = SOCIAL §4.4, whimsey = COMEDY §2.1, v5 wave 3).")

(defconst cistern--social-species-census
  '(worker goblin pest fixture tank structure)
  "SOCIAL §4.4: the closed species table for thought/quirk
validation — the census total order's species.")

(defconst cistern--story-stats '(tolerance integrity standing)
  "Story stat keys (STORY §6.1) — matrix :stat must be one of these.")

(defconst cistern--story-effects
  '(none log-line popup hazard-spawn tank-load-delta alloy-grant
    beat-open beat-resolve proximity-nudge)
  "STORY §6.4 effects whitelist — closed in v4; v5 adds the ONE
social-side effect proximity-nudge (SOCIAL §4.7: a SOCIAL number,
never a sim number).")

(defconst cistern--story-act-ticks
  '((1 . (0 . 119)) (2 . (120 . 239)) (3 . (240 . 99999)))
  "STORY §3.5 act windows (v4 pin): Act I 0-119, Act II 120-239,
Act III 240+ (unbounded).")

(defun cistern--enemy-at (st x y)
  "V5-07 view query: the hostile standing at (X,Y), or nil."
  (cl-find-if (lambda (e)
                (and (= x (cistern--enemy-x e))
                     (= y (cistern--enemy-y e))))
              (cistern-st-hostiles st)))

(defun cistern--story-tick-act (tick)
  "The act whose window TICK falls in (STORY §3.5) — derived
from the pinned `cistern--story-act-ticks' spans, not a second
copy of the windows.  Lives in the domain (innermost layer): the
combat spawn table reads it too (COMBAT §4.1)."
  (let ((act 1))
    (dolist (a cistern--story-act-ticks act)
      (when (>= tick (car (cdr a))) (setq act (car a))))))

(defconst cistern--story-tier-drift '(0 5 10)
  "STORY §7.4: per-act rare-tier shift added to the premise's
act-I rare weight (stakes escalation, data only).")

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
    (let ((span (cdr (assq act cistern--story-act-ticks))))
      (unless (and (consp win) (integerp (car win)) (integerp (cdr win))
                   (>= (car win) (car span))
                   (<= (cdr win) (cdr span))
                   (<= (car win) (cdr win)))
        (cistern--bank-error file "hook %s :window %S outside act %d span"
                             id win act)))
    (unless (and (consp cond-grammar)
                 (memq (car cond-grammar) '(event tick)))
      (cistern--bank-error file "hook %s :condition %S not in the closed
grammar" id cond-grammar))
    (when req
      ;; §7.3: the loader validates the -fallback variant key too
      (unless (cdr (assq (intern (concat (symbol-name
                                          (plist-get h :resolve-copy))
                                         "-fallback"))
                         cistern--story-copy))
        (cistern--bank-error file "hook %s :resolve-copy has no
-fallback variant" id))
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

(defconst cistern--dialogue-depth-max 3
  "STORY §2.7: node depth ≤ 3 from any root (D3).")

(defun cistern--bank-dialogue-nodes (file entries loaded)
  "STORY §2.7 per-node dialogue checks: :effect forbidden, :line
resolvable, :gate hook present and not later-acted, :pair
selectors known, :next names a LATER-declared node."
  (let ((index nil) (hook-acts nil) (idx 0))
    (dolist (e entries)
      (let ((id (plist-get e :id)))
        (unless id
          (cistern--bank-error file "dialogue node without :id"))
        (when (plist-get e :effect)
          (cistern--bank-error
           file "dialogue entry %s carries an :effect key (forbidden)" id))
        (unless (cdr (assq (plist-get e :line) cistern--story-copy))
          (cistern--bank-error file "dialogue %s :line unresolvable" id))
        (push (cons id idx) index)
        (setq idx (1+ idx))))
    (setq index (nreverse index))
    (dolist (sc (plist-get loaded :scenarios))
      (dolist (h (plist-get sc :hooks))
        (push (cons (plist-get h :id) (plist-get h :act)) hook-acts)))
    (dolist (e entries)
      (let* ((gate (plist-get e :gate))
             (hact (and gate (cdr (assq (car gate) hook-acts)))))
        (when gate
          (unless hact
            (cistern--bank-error
             file "dialogue %s :gate %S names no scenario hook"
             (plist-get e :id) (car gate)))
          (when (> (plist-get e :act) hact)
            (cistern--bank-error
             file "dialogue %s gates on a hook of a later act"
             (plist-get e :id))))
        (let ((sel (plist-get e :pair)))
          (while sel
            (pcase (car sel)
              ('stat
               (unless (memq (intern (upcase (symbol-name (cadr sel))))
                             (list 'FLOW 'GRIT 'NERVE 'ARCHIVE))
                 (cistern--bank-error file "pair stat unknown")))
              ('quirk
               (unless (cl-find (cadr sel)
                                (plist-get cistern--banks :quirks)
                                :key (lambda (x) (plist-get x :id)))
                 (cistern--bank-error file "pair quirk unknown")))
              (_ (cistern--bank-error file "bad pair selector")))
            (setq sel (cddr sel)))))
        (let ((br (plist-get e :branch)))
          (when br
            (dolist (nxt (plist-get br :next))
              (let ((pos (cdr (assq nxt index)))
                    (own (cdr (assq (plist-get e :id) index))))
                (unless (and pos (> pos own))
                  (cistern--bank-error
                   file "node :next %s unknown or not later-declared"
                   nxt)))))))))


(defun cistern--bank-dialogue-depth (file entries)
  "STORY §2.7: depth <= 3 from any dialogue root."
  (let ((roots nil))
    (dolist (e entries)
      (when (plist-get e :root) (push e roots)))
    (dolist (r roots)
      (let ((d 0) (node r))
        (while node
          (setq d (1+ d))
          (when (> d cistern--dialogue-depth-max)
            (cistern--bank-error
             file "dialogue depth exceeds %d from root %s"
             cistern--dialogue-depth-max (plist-get r :id)))
          (setq node
                (cl-find (car (plist-get (plist-get node :branch) :next))
                         entries :key (lambda (x) (plist-get x :id)))))))))

(defun cistern--bank-validate-dialogue (file entries loaded)
  "STORY §2.7 wrapper: per-node checks, then the depth check."
  (cistern--bank-dialogue-nodes file entries loaded)
  (cistern--bank-dialogue-depth file entries))

(defun cistern--bank-registry-key (kind)
  "Registry slot (plural) for a bank KIND (STORY §4.1)."
  (pcase kind
    ('scenario :scenarios) ('quirk :quirks)
    ('keyword :keywords) ('flavor :flavor)
    ('dialogue :dialogues)
    ('thought :thoughts)
    ('whimsey :whimseys)))

(defvar cistern--matrix-sources (make-hash-table :test (quote eq))
  "V4-19: hash MATRIX-ID -> source file, for cross-source id
uniqueness (a second FILE claiming an id is a collision; the SAME
file reloading its own id is an idempotent overwrite).")

(defun cistern--bank-fold-matrices (file matrices)
  "V4-19 (§1.3/§3.5): fold a bank's scenario matrices into the ONE
shared (matrix-id . band) hash.  An id claimed by a DIFFERENT
source file is a load error (cross-source id uniqueness); the same
file reloading its own ids is an idempotent overwrite."
  (dolist (m matrices)
    (let* ((id (plist-get m :id))
          (outs (plist-get m :outcomes))
          (i 0)
          (src (gethash id cistern--matrix-sources)))
      (when (and src (not (string= src file)))
        (cistern--bank-error file "matrix %s id collision with %s"
                             id src))
      (puthash id file cistern--matrix-sources)
      (dolist (o outs)
        (puthash (cons id i) o cistern--matrix-hash)
        (setq i (1+ i))))))

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
       ;; V5-08 (SOCIAL §1.2): optional :species — worker | goblin |
       ;; pest | fixture | tank | structure | any; absent = any
       (when (plist-get e :species)
         (unless (memq (plist-get e :species)
                       (append cistern--social-species-census '(any)))
           (cistern--bank-error file "quirk %s :species %S unknown"
                                id (plist-get e :species))))
       (unless (cdr (assq (plist-get e :copy-key) cistern--story-copy))
         (cistern--bank-error file "quirk %s :copy-key unresolvable" id)))
      ('thought
       ;; V5-10 (SOCIAL §4.4): :class in the closed table, :species in
       ;; the census, :when a mood band or any, :copy-key resolvable
       (unless (memq (plist-get e :class) cistern--social-classes)
         (cistern--bank-error file "thought %s :class %S unknown"
                              id (plist-get e :class)))
       (unless (memq (plist-get e :species) cistern--social-species-census)
         (cistern--bank-error file "thought %s :species %S unknown"
                              id (plist-get e :species)))
       (unless (memq (plist-get e :when) '(any NOMINAL STRAINED CRITICAL))
         (cistern--bank-error file "thought %s :when %S unknown"
                              id (plist-get e :when)))
       (unless (cdr (assq (plist-get e :copy-key) cistern--story-copy))
         (cistern--bank-error file "thought %s :copy-key unresolvable" id)))
      ('whimsey
       ;; V5-14 (COMEDY §2.1/§5.2): :when in the closed predicate
       ;; table, :weight/:cooldown numbers, :draws a list of (KIND N),
       ;; :footprint entries on the §5.2 whitelist — fail-first on
       ;; anything else
       (unless (memq (car (plist-get e :when))
                     cistern--comedy-when-names)
         (cistern--bank-error file "whimsey %s :when %S unknown"
                              id (plist-get e :when)))
       (unless (and (numberp (plist-get e :weight))
                    (> (plist-get e :weight) 0))
         (cistern--bank-error file "whimsey %s :weight invalid" id))
       (unless (numberp (plist-get e :cooldown))
         (cistern--bank-error file "whimsey %s :cooldown invalid" id))
       (dolist (fp (plist-get e :footprint))
         (unless (memq fp cistern--comedy-footprints)
           (cistern--bank-error
            file "whimsey %s :footprint %S off the whitelist" id fp)))
       (unless (cdr (assq (plist-get e :copy-key) cistern--story-copy))
         (cistern--bank-error file "whimsey %s :copy-key unresolvable" id)))
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
                (when (eq kind 'scenario)
                  (dolist (e entries)
                    (cistern--bank-fold-matrices
                     f (plist-get e :matrices))))
                (when (eq kind 'dialogue)
                  (cistern--bank-validate-dialogue f entries loaded))
                (setq loaded
                      (plist-put loaded
                                 (cistern--bank-registry-key kind)
                                 (append (plist-get loaded
                                                     (cistern--bank-registry-key
                                                      kind))
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
