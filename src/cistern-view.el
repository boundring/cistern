;;; cistern-view.el --- View adapter: pure projection of state -*- lexical-binding: t; -*-

;; Adapter layer (DESIGN-SPEC §3.3): projection only.  Every function
;; here is a pure function of its state argument — no buffer mutation
;; (the driver owns inserting), no side effects.  Glyphs come from the
;; Phase-1 tile table, connection/load state from domain query
;; functions (D6 — never direct hash access), faces from view-local
;; enum→face tables.  The pipe's connection-DEPENDENT shape is the
;; view's R7 job (the tile table is one-glyph-per-kind, plan 01 §1.3).

(require 'cistern-domain)
(require 'cistern-game)

(defconst cistern-view--header-lines 3
  "Rendered lines above the map rows: status, help, glyph legend.
Buffer line header-lines+1 is map row 0 — `cistern-view--cell-at'
and the render MUST agree on this count (L-014).")

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
;; View-local tables: enum→face, kind→legend/inspector text, worker
;; identity glyphs (L-012 finding 1 resolution: presentation concern,
;; moved here from the domain).

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

(defconst cistern-view--worker-glyphs ["α" "β" "γ" "δ" "ε" "ζ" "η" "θ"]
  "Worker identity glyphs indexed by the worker's stable position
in the creators list.")

(defun cistern-view--worker-glyph (st w)
  "Identity glyph for worker W from its stable creators-list index."
  (let ((i (or (cl-position w (cistern-st-creators st) :test #'eq) 0)))
    (aref cistern-view--worker-glyphs
          (mod i (length cistern-view--worker-glyphs)))))

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
        (cons glyph 'cistern-pipe-dead)))
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
  (format "CISTERN — SECTOR-7 — v%s  TICK %d   ALLOY %d   POP %d/%d   CONTAM %d/%d   SEED %d%s\n"
          cistern-version (cistern-st-tick st)
          (cistern-st-alloy st)
          (length (cistern-st-creators st)) cistern-pop-cap
          (cistern-st-contam st) cistern-contam-limit
          (cistern-st-rng st)
          (if (cistern-st-over st) (concat "   !! " (cistern-st-over st))
            "")))

(defun cistern-view--help-line ()
  (format "[arrows/mouse] cursor  [t]oilet %d  [p]ipe %d  [K]tank %d  [d]emolish %d  [c]decon %d  [x]purge  [SPC]tick  [r]auto-run  [n]ew  [?]help  [q]uit\n"
          cistern-cost-toilet cistern-cost-pipe cistern-cost-tank
          cistern-cost-demolish cistern-cost-decon))

(defun cistern-view--legend-line ()
  (concat "GLYPHS:  "
          (mapconcat (lambda (entry)
                       (format "%s %s" (cistern--tile-glyph (car entry))
                               (cdr (assq (car entry)
                                          cistern-view--kind-names))))
                     cistern--tile-table "  ")
          "  " (aref cistern-view--worker-glyphs 0) " worker\n"))

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
           (t (cdr (assq kind cistern-view--kind-descriptions)))))
         (who
          (when w
            (format "%s — bladder %d%% — %s"
                    (cistern-view--worker-glyph st w)
                    (cistern--worker-bladder w)
                    (cond ((cistern--worker-using w)
                           (format "in toilet (%d ticks left)"
                                   (cistern--worker-use-t w)))
                          ((> (cistern--worker-sick w) 0)
                           (format "sick (%d ticks)" (cistern--worker-sick w)))
                          (t "working"))))))
    (concat "CURSOR (" (number-to-string x) "," (number-to-string y)
            "): " base (if who (concat "  —  " who) ""))))

(defun cistern-view--pressure-line (st)
  (cond ((cistern-st-over st) "SECTOR CONDEMNED — PRESS n TO RESTART")
        ((cistern--toilets-backed-p st)
         "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS")
        ((> (cistern--tank-load-total st) 100)
         "PRESSURE RISING — LINES NEAR CAPACITY")
        (t "LINES NOMINAL — THE STRUCTURE DOES NOT CARE")))

(defun cistern-view--map-rows (st)
  (let ((out ""))
    (dotimes (y (cistern-st-h st))
      (dotimes (x (cistern-st-w st))
        (let* ((w (cl-find-if
                   (lambda (w)
                     (and (= (cistern--worker-x w) x)
                          (= (cistern--worker-y w) y)))
                   (cistern-st-creators st)))
               (cg (cistern-view--cell-glyph st x y))
               (glyph (if w (cistern-view--worker-glyph st w) (car cg)))
               (face (if w
                         (if (> (cistern--worker-sick w) 0)
                             'cistern-worker-sick 'cistern-worker)
                       (cdr cg))))
          ;; D5 overlay precedence: cursor > worker > (particle, 4b) > cell
          (setq out (concat out
                            (propertize
                             glyph 'face
                             (if (equal (cons x y) (cistern-st-cursor st))
                                 (list 'cistern-cursor face)
                               face))))))
      (setq out (concat out "\n")))
    out))

(defun cistern-view--tutorial-line (st)
  (let ((idx (cistern-st-tutorial st))
        (steps (cistern--tutorial-steps)))
    (when (and (numberp idx) (< idx (length steps)))
      (propertize (format "TUTORIAL %d/%d: %s  (T skips)\n"
                          (1+ idx) (length steps)
                          (car (nth idx steps)))
                  'face 'cistern-tutorial))))

(defun cistern-view--log-tail (st)
  (let ((out ""))
    (dolist (l (last (reverse (cistern-st-log st)) 3) out)
      (setq out (concat out (propertize l 'face 'cistern-dim) "\n")))))

(defun cistern-view--render (st)
  "Pure projection of ST into a propertized string.  No buffer
mutation, no side effects (D4) — the driver owns inserting it.
Layout contract: exactly `cistern-view--header-lines' header
lines precede the map rows."
  (concat
   (propertize (cistern-view--header-line st) 'face 'cistern-header)
   (propertize (cistern-view--help-line) 'face 'cistern-dim)
   (propertize (cistern-view--legend-line) 'face 'cistern-dim)
   (cistern-view--map-rows st)
   (propertize (concat (cistern-view--inspector st) "\n")
               'face 'cistern-dim)
   (propertize (concat (cistern-view--pressure-line st) "\n")
               'face 'cistern-dim)
   (cistern-view--tutorial-line st)
   (cistern-view--log-tail st)))

;; ---------------------------------------------------------------------------
;; Buffer geometry (Pair 2 slice; shares the header-lines constant).

(defun cistern-view--cell-at (st line col)
  "Pure buffer geometry: 1-based buffer LINE and 0-based COL →
(X . Y) grid cell; nil outside the map (clicks on header/log lines
are ignored by the driver).  Used by the driver's mouse handler;
batch-tested."
  (let ((x col)
        (y (- line 1 cistern-view--header-lines)))
    (when (and (>= x 0) (< x (cistern-st-w st))
               (>= y 0) (< y (cistern-st-h st)))
      (cons x y))))

(provide 'cistern-view)
;;; cistern-view.el ends here
