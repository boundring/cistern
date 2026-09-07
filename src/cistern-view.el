;;; cistern-view.el --- View adapter: pure projection of state -*- lexical-binding: t; -*-

;; Adapter layer (DESIGN-SPEC §3.3): projection only.  Every function
;; here is a pure function of its state argument — no buffer mutation
;; (the driver owns inserting), no side effects.  Glyphs come from the
;; Phase-1 tile table, connection/load state from domain query
;; functions (D6 — never direct hash access), faces from view-local
;; enum→face tables.  The pipe's connection-DEPENDENT shape is the
;; view's R7 job (the tile table is one-glyph-per-kind, plan 01 §1.3).

(require 'cistern-domain (and load-file-name (expand-file-name "cistern-domain.el" (file-name-directory load-file-name))))
(require 'cistern-game (and load-file-name (expand-file-name "cistern-game.el" (file-name-directory load-file-name))))

(defconst cistern-view--header-lines 3
  "Rendered lines above the map rows: status, help, glyph legend.
Buffer line header-lines+1 is map row 0 — `cistern-view--cell-at'
and the render MUST agree on this count (L-014).")

(defun cistern-view--header-block-height (st)
  "R2-Q02: THE block-height constant — rows above the map that
both the renderer and `cistern-view--cell-at' derive from.  Cold
strip + two help rows = 3; one live badge row (armed and/or
auto-run) makes 4.  Never two independent numbers."
  (+ cistern-view--header-lines
     (if (or (cistern-st-armed-verb st) (cistern-st-auto-run st)) 1 0)))

;; ---------------------------------------------------------------------------
;; Faces (ported from legacy :604-621; pipe gains connection faces).

(defface cistern-wall '((t :foreground "grey35")) "CISTERN walls.")
(defface cistern-floor '((t :foreground "grey40")) "CISTERN floor.")
(defface cistern-door '((t :foreground "grey60")) "CISTERN doors.")
(defface cistern-ore '((t :foreground "yellow3")) "CISTERN ore veins.")
(defface cistern-pipe-live '((t :foreground "cyan" :weight bold))
  "Pipe connected to capacity (R7).")
(defface cistern-pipe-dead '((t :foreground "grey50"))
  "Isolated pipe (R7).")
(defface cistern-toilet '((t :foreground "white" :weight bold)) "Toilet.")
(defface cistern-toilet-busy '((t :foreground "magenta" :weight bold))
  "Toilet in use.")
(defface cistern-toilet-down '((t :foreground "red" :weight bold))
  "Toilet out of service.")
(defface cistern-tank-ok '((t :foreground "green")) "Tank below 50% load.")
(defface cistern-tank-high '((t :foreground "yellow")) "Tank at 50-85% load.")
(defface cistern-tank-full '((t :foreground "red" :weight bold))
  "Tank near capacity.")
(defface cistern-hazard '((t :foreground "red" :weight bold))
  "Contamination.")
(defface cistern-worker '((t :foreground "green" :weight bold)) "Worker.")
(defface cistern-worker-sick '((t :foreground "orange" :weight bold))
  "Sick worker.")
(defface cistern-cursor '((t :inverse-video t :weight bold)) "Cursor cell.")
(defface cistern-header '((t :foreground "white" :weight bold))
  "Header line.")
(defface cistern-dim '((t :foreground "grey55")) "Dim UI text.")
(defface cistern-tutorial '((t :foreground "cyan" :weight bold))
  "Tutorial line.")

;; ---------------------------------------------------------------------------
;; View-local tables: enum→face, kind→legend/inspector text.  Worker
;; identity glyphs moved BACK to the domain (Q14): one helper, shared
;; by the accident log, the map and the inspector — superseding the
;; L-012 view-only placement.

(defconst cistern-view--kind-faces
  '((wall . cistern-wall) (floor . cistern-floor) (door . cistern-door)
    (ore . cistern-ore) (hazard . cistern-hazard)))

(defconst cistern-view--toilet-faces
  '((busy . cistern-toilet-busy) (usable . cistern-toilet)
    (down . cistern-toilet-down)))

(defconst cistern-view--kind-names
  '((floor . "floor") (wall . "wall") (door . "gate") (ore . "ore vein")
    (hazard . "contamination") (pipe . "pipe") (toilet . "toilet")
    (tank . "tank")))

(defconst cistern-view--kind-descriptions
  '((wall . "MEGASTRUCTURE WALL") (floor . "FLOOR") (door . "GATE / DOOR")
    (ore . "ORE VEIN — +1 ALLOY PER 3 TICKS WORKED")
    (hazard . "CONTAMINATION — press c to decon")
    (pipe . "PIPE — the only wire; keep it short")))

;; Q14 removed the private copy: identity lives in the domain —
;; `cistern--worker-glyph' is the one helper.

(defconst cistern-view--palette-faces
  '((success . cistern-toilet) (warning . cistern-tank-high)
    (error . cistern-toilet-down) (info . cistern-dim)
    (bonus . cistern-tank-ok))
  "REWARDS-DESIGN palette enums → Emacs faces (plan 02 §3.2).
Exact colors are Phase 4b; unknown faces pass through so
hand-built test intents can use Emacs faces directly.")

(defun cistern-view--celebration-overlay (st)
  "Dumb celebration projection (§4 renderer purity): project the
FIELD particles at their CURRENT positions — no mutation, no
advance inside the renderer (advance-particles is called by the
presentation layer, L-027/L-029) — plus the banner text from the
stored non-particle intents.  MAP-ALIST entries \(\(X . Y) .
\(GLYPH . FACE)) clipped to map bounds; BANNER-TEXT is the
reserved post-map row text."
  (let ((map nil) (banner ""))
    ;; field particles (L-029: particle-layer intent emission died
    ;; here — the field is the only particle source)
    (dolist (p (cistern-st-particles st))
      (let* ((pos (plist-get p :pos))
             (face (plist-get p :face)))
        (when (and pos (cistern--in-bounds-p st (car pos) (cdr pos)))
          (push (cons (cons (car pos) (cdr pos))
                      (cons (plist-get p :glyph)
                            (or (cdr (assq face cistern-view--palette-faces))
                                face)))
                map))))
    ;; non-particle intents (banner) from the stored per-tick slot
    (dolist (intent (cdr (cistern-st-rewards-outcome st)))
      (when (eq (plist-get intent :layer) 'banner)
        (setq banner (concat banner (plist-get intent :text)))))
    (cons map banner)))

;; ---------------------------------------------------------------------------
;; Cell projection: (GLYPH . FACE), tile table + query functions only.

(defun cistern-view--pipe-shape (st x y)
  "Box-drawing shape for the CONNECTED pipe at (X,Y) by plumbing
membership of the four neighbours (legacy :623-640 verbatim)."
  (let* ((plumbp (lambda (px py)
                   (and (cistern--in-bounds-p st px py)
                        (memq (cistern--cell st px py)
                              '(pipe toilet tank)))))
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
          (t (cistern--tile-glyph 'pipe)))))

(defun cistern-view--cell-glyph (st x y)
  "(GLYPH . FACE) for the cell at (X,Y): glyph from the tile
table, connection/load variant from domain queries, face from the
view-local tables.  The kind dispatch below selects CONNECTION
variants only — base glyphs never leave the table."
  (let* ((kind (cistern--cell st x y))
         (glyph (cistern--tile-glyph kind))
         (face (cdr (assq kind cistern-view--kind-faces))))
    (cond
     ((eq kind 'pipe)
      (if (cistern--connected-tanks st x y)
          (cons (cistern-view--pipe-shape st x y) 'cistern-pipe-live)
        ;; Q12: the unconnected pipe gets the tile table's distinct
        ;; dead glyph — it is no longer the floor dot
        (cons (cistern--tile-dead-glyph kind) 'cistern-pipe-dead)))
     ((eq kind 'toilet)
      (cons glyph (cdr (assq (cistern--toilet-state st x y)
                             cistern-view--toilet-faces))))
     ((eq kind 'tank)
      (let ((load (cistern--tank-load st x y)))
        (cons glyph
              (cond ((not load) 'cistern-tank-ok)
                    ((< load 30) 'cistern-tank-ok)
                    ((< load 51) 'cistern-tank-high)
                    (t 'cistern-tank-full)))))
     (t (cons glyph face)))))

;; ---------------------------------------------------------------------------
;; Render composition: every piece is a pure function of ST.

(defun cistern-view--header-line (st)
  "Q01 strip contract: fixed segment order TICK ALLOY POP
CONTAM SCORE GOALS REP.  SEED and the version moved to the ?
briefing (width budget at 95 cols); one dim badge slot (Q19
armed, Q29 auto-run) is reserved after REP.  Q21: the CONTAM
segment faces by fraction — yellow >= 50%%, red bold >= 75%% —
so the strip returns already-faced."
  (let* ((gc (cistern-view--goal-counts st))
         (pct (/ (* 100.0 (cistern-st-contam st)) cistern-contam-limit))
         (contam-face (cond ((>= pct 75) 'cistern-toilet-down)
                            ((>= pct 50) 'cistern-tank-high)
                            (t 'cistern-header))))
    (concat (propertize
             (format "CISTERN — SECTOR-7  TICK %d  ALLOY %d  POP %d/%d"
                     (cistern-st-tick st)
                     (cistern-st-alloy st)
                     (length (cistern-st-creators st)) cistern-pop-cap)
             'face 'cistern-header)
            (propertize (format "  CONTAM %d/%d"
                                (cistern-st-contam st) cistern-contam-limit)
                        'face contam-face)
            (propertize
             (format "  SCORE %d  GOALS %s  REP %d%s"
                     (or (cistern-st-score st) 0)
                     (if gc (format "%d/%d" (car gc) (cdr gc)) "-/-")
                     (cistern-st-reputation st)
                     (if (cistern-st-over st)
                         (concat "   " (cdr (assq 'condemn-append
                                                  cistern--copy)))
                       ""))
             'face 'cistern-header))))

(defun cistern-view--goal-counts (st)
  "Active-card progress (Q04): (MET . TOTAL) from the card's
objectives (R2-Q04: satisfied-at-least-once — claimed); nil
without a card."
  (let ((card (cistern-st-goal-card st)))
    (when card
      (cons (cl-count-if (lambda (g) (plist-get g :claimed))
                         (plist-get card :goals))
            (length (plist-get card :goals))))))

(defun cistern-view--header-badges (st)
  "R2-Q02: the ONE reserved badge row, directly below the strip —
armed and auto-run coexist here.  Empty string when idle (no row)."
  (let ((parts nil))
    (when (cistern-st-armed-verb st)
      (push (format (cdr (assq 'badge-armed cistern--copy))
                    (upcase (symbol-name (cistern-st-armed-verb st))))
            parts))
    (when (cistern-st-auto-run st)
      (push (cdr (assq 'badge-auto cistern--copy)) parts))
    (when parts
      (mapconcat #'identity (nreverse parts) " · "))))

(defun cistern-view--help-line ()
  "R2-Q01: the help is TWO deliberate dim rows, each within the
95-col contract — row A cursor + act verbs, row B arm/meta."
  (format (concat "[arrows/mouse] move [t]oilet %d [p]ipe %d [K]tank %d"
                  " [d]emolish %d [c]decon %d [x]purge [SPC]tick\n"
                  "%s [r]auto-run [n]ew [?]help [q]uit\n")
          cistern-cost-toilet cistern-cost-pipe cistern-cost-tank
          cistern-cost-demolish cistern-cost-decon
          (cdr (assq 'help-arm cistern--copy))))

(defun cistern-view--legend-line ()
  "Q12: GENERATED from the tile table — a kind with :dead-glyph
lists the dead glyph (its base glyph never renders), so one glyph
can never be listed twice."
  ;; R2-Q01: wrapped on a GLYPHS:-aligned continuation row — α worker
  ;; never orphans onto a wrapped display line at 95 cols.  The legend
  ;; renders below the map (the pre-map block is pinned at the
  ;; header-lines constant; see R2-Q02's block-height derivation).
  (let* ((entries (mapconcat
                   (lambda (entry)
                     (let* ((kind (car entry))
                            (dead (plist-get (cdr entry) :dead-glyph))
                            (glyph (or dead (cistern--tile-glyph kind)))
                            (name (cdr (assq kind cistern-view--kind-names))))
                       (format "%s %s" glyph
                               (if dead (concat "dead " name) name))))
                   cistern--tile-table "  "))
         ;; wrap before the last two entries: row 1 fits 85 cols,
         ;; the continuation is GLYPHS:-aligned and carries the worker
         (split-at (string-match-p "  ▣" entries)))
    (concat "GLYPHS:  "
            (substring entries 0 split-at) "\n"
            (make-string 9 ?\s)
            (substring entries (+ split-at 2))
            "  " (aref cistern--worker-glyphs 0) " worker\n")))

(defun cistern-view--inspector (st)
  "One sentence describing whatever the cursor rests on."
  (let* ((x (car (cistern-st-cursor st)))
         (y (cdr (cistern-st-cursor st)))
         (kind (cistern--cell st x y))
         (w (cl-find-if (lambda (w)
                          (and (= (cistern--worker-x w) x)
                               (= (cistern--worker-y w) y)))
                        (cistern-st-creators st)))
         (base
          (cond
           ((eq kind 'toilet)
            (let ((s (cistern--toilet-state st x y)))
              (cond ((eq s 'busy) "TOILET — IN USE")
                    ((eq s 'usable) "TOILET — WIRED AND SERVICED")
                    ((cistern--connected-tanks st x y)
                     "TOILET — BACKED UP: PURGE THE TANKS (x)")
                    (t "TOILET — SEVERED: LAY PIPE TO A TANK (p)"))))
           ((eq kind 'tank)
            (format "TANK — LOAD %d/%d — PURGE WITH x (pays 1 alloy per %d)"
                    (or (cistern--tank-load st x y) 0)
                    cistern-tank-cap cistern-purge-rate))
           ;; R2-Q07: the DEAD pipe names its state and the fix — the
           ;; connected pipe keeps its round-1 line byte-identical
           ((and (eq kind 'pipe) (null (cistern--connected-tanks st x y)))
            (cdr (assq 'pipe-dead cistern--copy)))
           ((eq kind 'floor)
            ;; Q20 (extension only): the floor cursor gets its
            ;; bearings — nearest toilet and tank, manhattan from the
            ;; shared geometry.  All non-floor lines untouched.
            (let ((bearing (cistern-view--floor-bearing st x y)))
              (if bearing
                  (format (cdr (assq 'bearing-floor cistern--copy)) bearing)
                (cdr (assq kind cistern-view--kind-descriptions)))))
           (t (cdr (assq kind cistern-view--kind-descriptions)))))
         (who
          (when w
            (format "%s — bladder %d%% — %s"
                    (cistern--worker-glyph st w)
                    (cistern--worker-bladder w)
                    (cond ((cistern--worker-using w)
                           (format "in toilet (%d ticks left)"
                                   (cistern--worker-use-t w)))
                          ((> (cistern--worker-sick w) 0)
                           (format "sick (%d ticks)" (cistern--worker-sick w)))
                          (t "working"))))))
    ;; R2-Q09: a demolishable cell built this tick advertises the
    ;; free undo where the cursor rests
    (when (and (memq kind '(pipe toilet tank))
               (cistern--built-this-tick-p st x y))
      (setq base (concat base (cdr (assq 'same-tick-free cistern--copy)))))
    (concat "CURSOR (" (number-to-string x) "," (number-to-string y)
            "): " base (if who (concat "  —  " who) ""))))

(defun cistern-view--pressure-face (st)
  "Q21: colors, not new words — CRITICAL (and SEVERED, the other
act-now state) red bold, RISING yellow, NOMINAL dim.  Mirrors the
pressure-line state cond."
  (cond ((or (cistern-st-over st)
             (cistern--toilets-severed-p st)
             (cistern--toilets-backed-up-p st))
         'cistern-toilet-down)
        ((and (> (cistern--tank-capacity-total st) 0)
              (>= (cistern--tank-load-total st)
                  (* 0.85 (cistern--tank-capacity-total st))))
         'cistern-tank-high)
        (t 'cistern-dim)))

(defun cistern-view--floor-bearing (st x y)
  "Q20: nearest toilet and tank bearings for the floor cursor at
\(X,Y) — per-axis direction words over the manhattan pick; nil
when nothing is placed yet."
  (let ((parts nil))
    (dolist (kind '(toilet tank))
      (let ((pos (cistern--nearest-structure st kind x y)))
        (when pos
          (let* ((dx (- (car pos) x))
                 (dy (- (cdr pos) y))
                 (words nil))
            (when (/= dx 0)
              (push (format "%d %s" (abs dx) (if (> dx 0) "east" "west"))
                    words))
            (when (/= dy 0)
              (push (format "%d %s" (abs dy) (if (> dy 0) "south" "north"))
                    words))
            (push (format "%s %s %s"
                          (cdr (assq kind cistern-view--kind-names))
                          (cistern--tile-glyph kind)
                          ;; R2-Q14: a multi-axis target reads as ONE compound
                          (mapconcat #'identity (nreverse words) " + "))
                  parts)))))
    (when parts
      (mapconcat #'identity (nreverse parts) ", "))))

(defun cistern-view--pressure-line (st)
  "Q08: the middle tier anticipates — RISING fires at 0.85 x the
total tank capacity and names the fill %; the raw-total branch is
deleted (101 units over many tanks is not pressure).  Copy per
Q11 from the domain table."
  (let* ((capsum (cistern--tank-capacity-total st))
         (total (cistern--tank-load-total st)))
    ;; R2-Q03: one verb, from the table — panel, log and line agree
    (cond ((cistern-st-over st) (cdr (assq 'restart-log cistern--copy)))
        ;; Q10: severed lines get rewired, never purged — and the
        ;; line names the tank cell to wire toward (copy per Q11)
        ((cistern--toilets-severed-p st)
         (let ((tk (cistern--severed-remedy st)))
           (if tk
               (format (cdr (assq 'pressure-severed cistern--copy))
                       (car tk) (cdr tk))
             (cdr (assq 'pressure-severed-bare cistern--copy)))))
        ((cistern--toilets-backed-up-p st)
         "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS")
        ((and (> capsum 0) (>= total (* 0.85 capsum)))
         (format (cdr (assq 'pressure-rising cistern--copy))
                 (round (/ (* 100.0 (cistern--tank-load-max st))
                           cistern-tank-cap))))
        (t "LINES NOMINAL — THE STRUCTURE DOES NOT CARE"))))

(defun cistern-view--map-rows (st &optional overlay)
  (let ((out ""))
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (let* ((cur (equal (cons x y) (cistern-st-cursor st)))
               (w (cl-find-if
                   (lambda (w)
                     (and (= (cistern--worker-x w) x)
                          (= (cistern--worker-y w) y)))
                   (cistern-st-creators st)))
               ;; particle loses to cursor AND worker (D5: cursor >
               ;; worker > particle > cell)
               (ov (and (not cur) (not w)
                        (cdr (assoc (cons x y) overlay))))
               (cg (cistern-view--cell-glyph st x y))
               (glyph (cond (w (cistern--worker-glyph st w))
                            (ov (car ov))
                            (t (car cg))))
               (base-face (cond (w (if (> (cistern--worker-sick w) 0)
                                       'cistern-worker-sick 'cistern-worker))
                                (ov (cdr ov))
                                (t (cdr cg))))
               (face (if cur (list 'cistern-cursor base-face) base-face)))
          (setq out (concat out
                            (propertize
                             glyph 'face face)))))
      (setq out (concat out "\n")))
    out))

(defun cistern-view--tutorial-line (st)
  ;; R2-Q11 (c): suppressed while over — the death frame is the
  ;; tutorial's end
  (unless (cistern-st-over st)
    (let ((idx (cistern-st-tutorial st))
          (steps (cistern--tutorial-steps)))
      (when (and (numberp idx) (< idx (length steps)))
        (propertize (concat (format (cdr (assq 'tutorial-line-fmt
                                              cistern--copy))
                                    (1+ idx) (length steps)
                                    (car (nth idx steps)))
                            "\n")
                    'face 'cistern-tutorial)))))

(defun cistern-view--log-tail (st)
  "Three-line tail (Q15): consecutive identical lines collapse
with a silent ×N count; majors (breach/condemnation) keep max
severity weight inside the recent window; older flavor ages out
like any line.  V4-01: each entry is (LINE SEVERITY TICK); the
collapse projects entries to their (LINE . SEVERITY) 2-list
first, so faces persist with the text and the triple stays
(LINE SEVERITY COUNT).  Suppression is silent."
  (let* ((log (cistern-st-log st))
         (boot (car (car (last log))))         ; the boot LINE: oldest entry
         (collapsed (cistern-view--collapse-log
                     (mapcar (lambda (e) (cons (car e) (cadr e)))
                             (reverse log))))  ; chronological
        ;; ponytail: window 12 = the old log cap; a ranking constant,
        ;; revisit only if tails feel stale
        (window (last collapsed (min 12 (length collapsed))))
        ;; R2-Q15: an empty player era still renders the boot line
        (picked (or (cistern-view--pick-tail window boot)
                    (last window (min 3 (length window)))))
        (out ""))
    (dolist (e picked out)
      (setq out (concat out
                        (propertize (if (> (nth 2 e) 1)
                                        (format "%s ×%d" (nth 0 e) (nth 2 e))
                                      (nth 0 e))
                                    'face
                                    (or (cdr (assq (nth 1 e)
                                                   cistern-view--palette-faces))
                                        'cistern-dim))
                        "\n")))))

(defun cistern-view--collapse-log (chron)
  "Collapse consecutive identical lines (Q15): chronological
input of (LINE . SEVERITY) 2-lists (the V4-01 3-list entries are
projected by the caller) → (LINE SEVERITY COUNT) triples.
Silent except the count."
  (let ((out nil))
    (dolist (e chron)
      (let ((top (car out)))
        (if (and top (string= (car top) (car e)))
            (setf (nth 2 top) (1+ (nth 2 top)))
          (push (list (car e) (cdr e) 1) out))))
    (nreverse out)))

(defun cistern-view--pick-tail (window boot)
  "Choose ≤3 lines from the chronological WINDOW of triples:
majors keep max severity weight (breach/condemnation always make
the tail), remaining slots fill by recency; output order stays
chronological."
  (let* ((major-idx (last (cl-loop for e in window
                                   for i from 0
                                   when (eq (nth 1 e) 'error)
                                   collect i)
                          3))
         (n (length window))
         ;; newest first — the descending index stream is already in
         ;; recency order, so the fill takes its HEAD
         (rest-idx (let ((cand (cl-loop for i from (1- n) downto 0
                                       unless (or (memq i major-idx)
                                                  ;; R2-Q15: boot flavor
                                                  ;; ranks below any
                                                  ;; player-era line
                                                  (string= (nth 0 (nth i window))
                                                           boot))
                                        collect i)))
                     (cl-subseq cand 0
                                (min (length cand)
                                     (max 0 (- 3 (length major-idx))))))))
    (mapcar (lambda (i) (nth i window))
            (sort (append major-idx rest-idx) #'<))))

(defun cistern-view--render (st)
  "Pure projection of ST into a propertized string.  No buffer
mutation, no side effects (D4) — the driver owns inserting it.
Layout contract: exactly `cistern-view--header-lines' header
lines precede the map rows."
  (let* (;; the rewards use case is read exactly ONCE per render (§3.6)
         (celebration (cistern-view--celebration-overlay st))
         (overlay (car celebration))
         ;; reserved banner row (§3.5): after the map rows, before the
         ;; inspector; empty for the default outcome.  Banner content
         ;; design (ceremony copy/centering) is Phase 4 — DEFERRED.
         ;; Q23: on condemnation the banner layer carries the death
         ;; panel built from the banked Q22 summary.
         (banner (concat (cdr celebration)
                         (when (and (cistern-st-over st)
                                    (cistern-st-summary st))
                           (format (cdr (assq 'death-panel cistern--copy))
                                   (plist-get (cistern-st-summary st) :cause)
                                   (plist-get (cistern-st-summary st) :ticks)
                                   (plist-get (cistern-st-summary st) :relieves)
                                   (plist-get (cistern-st-summary st) :score))))))
    (concat
     ;; Q21: the header line arrives already-faced (CONTAM segment)
     (propertize (concat (cistern-view--header-line st) "\n")
                 'face 'cistern-header)
     ;; R2-Q02: the badges render on ONE reserved dim row directly
     ;; below the strip; the block height is the one constant
     (when (cistern-view--header-badges st)
       (propertize (concat (cistern-view--header-badges st) "\n")
                   'face 'cistern-dim))
     ;; R2-Q01: the help is two dim rows; the wrapped legend renders
     ;; below the map — the pre-map block stays header-lines tall
     (propertize (cistern-view--help-line) 'face 'cistern-dim)
     (cistern-view--map-rows st overlay)
     (propertize (concat banner "\n") 'face 'cistern-header)
     (propertize (concat (cistern-view--inspector st) "\n")
                 'face 'cistern-dim)
     ;; Q17: the one-tick transient hint slot, under the inspector —
     ;; R2-Q06: the row is RESERVED (dim blank when idle) so the
     ;; pressure line never shifts; lifetime is intent-tied — cursor
     ;; moves and renders preserve the hint, non-cursor commands
     ;; drain it (see the driver commands)
     (propertize (concat (or (cistern-st-hint st) "") "\n")
                 'face 'cistern-dim)
     (propertize (concat (cistern-view--pressure-line st) "\n")
                 'face (cistern-view--pressure-face st))
     (cistern-view--tutorial-line st)
     (cistern-view--log-tail st)
     ;; R2-Q01: the wrapped legend renders at the frame foot — the
     ;; banner→inspector adjacency and the header-lines-tall pre-map
     ;; block both stay pinned
     (propertize (cistern-view--legend-line) 'face 'cistern-dim))))

;; ---------------------------------------------------------------------------
;; Buffer geometry (Pair 2 slice; shares the header-lines constant).

(defun cistern-view--cell-at (st line col)
  "Pure buffer geometry: 1-based buffer LINE and 0-based COL →
(X . Y) grid cell; nil outside the map (clicks on header/log lines
are ignored by the driver).  Used by the driver's mouse handler;
batch-tested."
  (let ((x col)
        (y (- line 1 (cistern-view--header-block-height st))))
    (when (and (>= x 0) (< x (cistern-st-w st))
               (>= y 0) (< y (cistern-st-h st)))
      (cons x y))))

(provide 'cistern-view)
;;; cistern-view.el ends here
