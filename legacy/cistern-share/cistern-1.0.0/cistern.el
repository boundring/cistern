;;; cistern.el --- CISTERN: sanitation management for the megastructure -*- lexical-binding: t; -*-

;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: games

;;; Commentary:

;; CISTERN — a turn-based sanitation management sim for the
;; megastructure.
;;
;; The creators mine the structure.  The structure does not care what
;; they become.  Your contract: build toilets, lay pipe to the tanks,
;; purge the tanks, decontaminate breaches, and keep scaling — every
;; forty ticks another migrant walks in through the west gate.
;;
;; Run `M-x cistern'.  SPACE advances one tick.  Move the cursor and
;; place infrastructure.  Contamination ends the sector at 20.

;;; Code:

(require 'cl-lib)

(defgroup cistern nil "CISTERN: sanitation management sim." :group 'games)

(defconst cistern-version "1.0.0")

(defconst cistern--w 34)
(defconst cistern--h 16)
(defconst cistern--tank-cap 60)
(defconst cistern--use-load 10)
(defconst cistern--contam-limit 20)
(defconst cistern--creator-cap 8)
(defconst cistern--migrant-every 40)

(defconst cistern--cost-toilet 12)
(defconst cistern--cost-pipe 2)
(defconst cistern--cost-tank 15)
(defconst cistern--cost-decon 4)

(defconst cistern--creator-glyphs ["α" "β" "γ" "δ" "ε" "ζ" "η" "θ"])

;;; Faces

(defface cistern-wall '((t :foreground "grey35")) "CISTERN walls.")
(defface cistern-floor '((t :foreground "grey40")) "CISTERN floor.")
(defface cistern-door '((t :foreground "grey60")) "CISTERN doors.")
(defface cistern-ore '((t :foreground "yellow3")) "CISTERN ore veins.")
(defface cistern-pipe '((t :foreground "cyan")) "CISTERN pipe.")
(defface cistern-toilet '((t :foreground "white" :weight bold)) "Toilet.")
(defface cistern-toilet-busy '((t :foreground "magenta" :weight bold)) "Toilet in use.")
(defface cistern-toilet-down '((t :foreground "red" :weight bold)) "Backed-up or severed toilet.")
(defface cistern-tank-ok '((t :foreground "green")) "Tank below 50% load.")
(defface cistern-tank-high '((t :foreground "yellow")) "Tank at 50-85% load.")
(defface cistern-tank-full '((t :foreground "red" :weight bold)) "Tank at 85%+ load.")
(defface cistern-hazard '((t :foreground "red" :weight bold)) "Biohazard tile.")
(defface cistern-creator '((t :foreground "green" :weight bold)) "Creator.")
(defface cistern-creator-sick '((t :foreground "orange" :weight bold)) "Sick creator.")
(defface cistern-cursor '((t :inverse-video t :weight bold)) "Cursor cell.")
(defface cistern-header '((t :foreground "white" :weight bold)) "Header line.")
(defface cistern-dim '((t :foreground "grey55")) "Dim UI text.")
(defface cistern-alert '((t :foreground "red")) "Alert line.")

;;; State

(defvar cistern--map nil "Vector of cell symbols.")
(defvar cistern--toilets nil "Hash (X . Y) -> plist (:busy, :user).")
(defvar cistern--tanks nil "Hash (X . Y) -> plist (:load).")
(defvar cistern--creators nil)
(defvar cistern--alloy 20)
(defvar cistern--tick 0)
(defvar cistern--contam 0)
(defvar cistern--cursor (cons 3 6))
(defvar cistern--log nil)
(defvar cistern--over nil)

(cl-defstruct (cistern--cr (:constructor cistern--cr-create))
  x y (bladder 0) (sick 0) (mine 0) (use-t 0) (using nil))

(defun cistern--log (fmt &rest args)
  (push (apply #'format fmt args) cistern--log)
  (when (> (length cistern--log) 12)
    (setq cistern--log
          (nbutlast cistern--log (- (length cistern--log) 12)))))

;;; Cells and map

(defun cistern--in-bounds-p (x y)
  (and (>= x 0) (< x cistern--w) (>= y 0) (< y cistern--h)))

(defun cistern--idx (x y) (+ x (* y cistern--w)))

(defun cistern--cell (x y) (aref cistern--map (cistern--idx x y)))

(defun cistern--set-cell (x y c) (aset cistern--map (cistern--idx x y) c))

(defun cistern--neighbors (x y)
  (delq nil
        (list (and (< (1+ x) cistern--w) (cons (1+ x) y))
              (and (> x 0) (cons (1- x) y))
              (and (< (1+ y) cistern--h) (cons x (1+ y)))
              (and (> y 0) (cons x (1- y))))))

(defun cistern--build-map ()
  (setq cistern--map (make-vector (* cistern--w cistern--h) 'floor))
  ;; outer walls
  (dotimes (y cistern--h)
    (dotimes (x cistern--w)
      (when (or (= x 0) (= x (1- cistern--w)) (= y 0) (= y (1- cistern--h)))
        (cistern--set-cell x y 'wall))))
  ;; interior spine wall x=8, doors at y=4 and y=11
  (cl-loop for y from 1 to (- cistern--h 2) do (cistern--set-cell 8 y 'wall))
  (cistern--set-cell 8 4 'door)
  (cistern--set-cell 8 11 'door)
  ;; cross wall y=8 from x=14..24, door at x=20
  (cl-loop for x from 14 to 24 do (cistern--set-cell x 8 'wall))
  (cistern--set-cell 20 8 'door)
  ;; west gate for migrants
  (cistern--set-cell 0 7 'door)
  ;; ore veins
  (cistern--set-cell 13 3 'ore)
  (cistern--set-cell 24 12 'ore)
  (cistern--set-cell 28 3 'ore)
  ;; starting plumbing: tank (5,2) - pipe (4,2) - pipe (3,2) - toilet (3,3)
  (cistern--set-cell 5 2 'tank)
  (cistern--set-cell 4 2 'pipe)
  (cistern--set-cell 3 2 'pipe)
  (cistern--set-cell 3 3 'toilet)
  (setq cistern--toilets (make-hash-table :test #'equal))
  (setq cistern--tanks (make-hash-table :test #'equal))
  (puthash (cons 3 3) (list :busy nil :user nil) cistern--toilets)
  (puthash (cons 5 2) (list :load 0) cistern--tanks))

;;; Pathing

(defun cistern--walkable-p (x y tx ty)
  "Cell (X,Y) passable for a creator heading to target (TX,TY)?"
  (let ((c (cistern--cell x y)))
    (or (memq c '(floor door ore pipe))
        (and (eq c 'toilet) (= x tx) (= y ty)))))

(defun cistern--dist-map (tx ty blocked)
  "BFS distances from (TX,TY).  BLOCKED is a hash of blocked cells."
  (let ((dist (make-hash-table :test #'equal))
        (q (list (cons tx ty))))
    (puthash (cons tx ty) 0 dist)
    (while q
      (let* ((cur (car q))
             (d (gethash cur dist)))
        (setq q (cdr q))
        (dolist (n (cistern--neighbors (car cur) (cdr cur)))
          (let ((k n))
            (when (and (not (gethash k dist))
                       (not (gethash k blocked))
                       (cistern--walkable-p (car k) (cdr k) tx ty))
              (puthash k (1+ d) dist)
              (setq q (append q (list k))))))))
    dist))

(defun cistern--occupied-cells (except)
  (let ((h (make-hash-table :test #'equal)))
    (dolist (c cistern--creators)
      (unless (eq c except)
        (puthash (cons (cistern--cr-x c) (cistern--cr-y c)) t h)))
    h))

(defun cistern--move-one (c tx ty)
  "Step creator C one cell toward (TX,TY).  Non-nil on success."
  (let* ((blocked (cistern--occupied-cells c))
         (dist (cistern--dist-map tx ty blocked))
         (x (cistern--cr-x c))
         (y (cistern--cr-y c))
         (d0 (gethash (cons x y) dist)))
    (when (and d0 (> d0 0))
      (let (best)
        (dolist (n (cistern--neighbors x y))
          (let ((dd (gethash n dist)))
            (when (and dd (= dd (1- d0)) (not best))
              (setq best n))))
        (when best
          (setf (cistern--cr-x c) (car best))
          (setf (cistern--cr-y c) (cdr best))
          t)))))

;;; Plumbing

(defun cistern--connected-tanks (x y)
  "Tanks reachable from toilet at (X,Y) through pipes.  List of cells."
  (let ((seen (make-hash-table :test #'equal))
        (q (list (cons x y)))
        (tanks nil))
    (puthash (cons x y) t seen)
    (while q
      (let* ((cur (car q)))
        (setq q (cdr q))
        (when (eq (cistern--cell (car cur) (cdr cur)) 'tank)
          (push cur tanks))
        (dolist (n (cistern--neighbors (car cur) (cdr cur)))
          (when (and (not (gethash n seen))
                     (memq (cistern--cell (car n) (cdr n)) '(toilet pipe tank)))
            (puthash n t seen)
            (setq q (append q (list n)))))))
    (nreverse tanks)))

(defun cistern--toilet-usable-p (x y)
  (let ((entry (gethash (cons x y) cistern--toilets)))
    (and entry
         (not (plist-get entry :busy))
         (cl-some (lambda (tk)
                    (<= (+ (plist-get (gethash tk cistern--tanks) :load)
                           cistern--use-load)
                        cistern--tank-cap))
                  (cistern--connected-tanks x y)))))

(defun cistern--free-usable-toilets ()
  (let ((out nil))
    (maphash (lambda (k _v)
               (when (cistern--toilet-usable-p (car k) (cdr k))
                 (push k out)))
             cistern--toilets)
    out))

;;; Creators

(defun cistern--make-creator-at (x y)
  (cistern--cr-create :x x :y y :bladder 20))

(defun cistern--spawn-initial ()
  (setq cistern--creators nil)
  (dolist (p '((12 6) (14 7) (11 9) (15 6)))
    (push (cistern--make-creator-at (nth 0 p) (nth 1 p)) cistern--creators))
  (setq cistern--creators (nreverse cistern--creators)))

(defun cistern--creator-index (c)
  (or (cl-position c cistern--creators :test #'eq) 0))

(defun cistern--creator-glyph (c)
  (aref cistern--creator-glyphs (mod (cistern--creator-index c)
                                     (length cistern--creator-glyphs))))

(defun cistern--nearest-target (c candidates)
  "Nearest reachable cell to creator C among CANDIDATES ((X . Y) ...)."
  (let (best bd)
    (dolist (cand candidates)
      (let* ((blocked (cistern--occupied-cells c))
             (dist (cistern--dist-map (car cand) (cdr cand) blocked))
             (d (gethash (cons (cistern--cr-x c) (cistern--cr-y c)) dist)))
        (when (and d (or (null bd) (< d bd)))
          (setq bd d best cand))))
    (cons best bd)))

(defun cistern--ores ()
  (let ((out nil) (i 0))
    (while (< i (length cistern--map))
      (when (eq (aref cistern--map i) 'ore)
        (push (cons (% i cistern--w) (/ i cistern--w)) out))
      (cl-incf i))
    (nreverse out)))

(defun cistern--begin-use (c tx ty)
  (puthash (cons tx ty) (list :busy t :user c) cistern--toilets)
  (setf (cistern--cr-using c) t)
  (setf (cistern--cr-use-t c) 4))

(defun cistern--finish-use (c)
  (setf (cistern--cr-using c) nil)
  (setf (cistern--cr-bladder c) 0)
  (let* ((x (cistern--cr-x c))
         (y (cistern--cr-y c))
         (tanks (cistern--connected-tanks x y)))
    (puthash (cons x y) (list :busy nil :user nil) cistern--toilets)
    (if (null tanks)
        (progn
          (cistern--add-hazard-at x y)
          (setq cistern--contam (1+ cistern--contam))
          (cistern--log "SEVERED LINE AT (%d,%d) — WASTE SPILLED" x y))
      (let ((best (car tanks)))
        (dolist (tk tanks)
          (when (< (plist-get (gethash tk cistern--tanks) :load)
                   (plist-get (gethash best cistern--tanks) :load))
            (setq best tk)))
        (puthash best
                 (list :load (+ cistern--use-load
                                (plist-get (gethash best cistern--tanks) :load)))
                 cistern--tanks)))))

(defun cistern--accident (c)
  (let* ((x (cistern--cr-x c))
         (y (cistern--cr-y c)))
    (setf (cistern--cr-bladder c) 0)
    (unless (cistern--add-hazard-at x y)
      (catch 'placed
        (dolist (n (cistern--neighbors x y))
          (when (cistern--add-hazard-at (car n) (cdr n))
            (throw 'placed t)))))
    (setq cistern--contam (1+ cistern--contam))
    (dolist (n (cistern--neighbors x y))
      (dolist (o cistern--creators)
        (when (and (not (eq o c))
                   (= (cistern--cr-x o) (car n))
                   (= (cistern--cr-y o) (cdr n)))
          (setf (cistern--cr-sick o) 30))))
    (cistern--log "BREACH — CREATOR %s OVERFLOWED AT (%d,%d)"
                  (cistern--creator-glyph c) x y)))

(defun cistern--seek-toilet (c)
  (let* ((x (cistern--cr-x c))
         (y (cistern--cr-y c))
         (adj (cl-find-if
               (lambda (n)
                 (and (eq (cistern--cell (car n) (cdr n)) 'toilet)
                      (cistern--toilet-usable-p (car n) (cdr n))))
               (cistern--neighbors x y))))
    (cond
     (adj (cistern--begin-use c (car adj) (cdr adj)))
     (t
      (let ((tgt (cistern--nearest-target c (cistern--free-usable-toilets))))
        (if (car tgt)
            (cistern--move-one c (car (car tgt)) (cdr (car tgt)))
          (cistern--seek-work c)))))))

(defun cistern--seek-work (c)
  (let* ((x (cistern--cr-x c))
         (y (cistern--cr-y c)))
    (if (eq (cistern--cell x y) 'ore)
        (progn
          (setf (cistern--cr-mine c) (1+ (cistern--cr-mine c)))
          (when (= (cistern--cr-mine c) 3)
            (setf (cistern--cr-mine c) 0)
            (setq cistern--alloy (1+ cistern--alloy))))
      (let ((tgt (cistern--nearest-target c (cistern--ore-list))))
        (if (car tgt)
            (cistern--move-one c (car (car tgt)) (cdr (car tgt)))
          ;; nowhere to go: shuffle
          (when (< (random 100) 40)
            (let ((ns (cl-remove-if
                       (lambda (n)
                         (not (memq (cistern--cell (car n) (cdr n))
                                    '(floor door ore pipe))))
                       (cistern--neighbors x y))))
              (when ns
                (let ((n (nth (random (length ns)) ns)))
                  (setf (cistern--cr-x c) (car n))
                  (setf (cistern--cr-y c) (cdr n)))))))))))

(defun cistern--creator-tick (c)
  (when (> (cistern--cr-sick c) 0)
    (setf (cistern--cr-sick c) (1- (cistern--cr-sick c))))
  (if (cistern--cr-using c)
      (progn
        (setf (cistern--cr-use-t c) (1- (cistern--cr-use-t c)))
        (when (<= (cistern--cr-use-t c) 0)
          (cistern--finish-use c)))
    (setf (cistern--cr-bladder c) (+ 3 (cistern--cr-bladder c)))
    (cond
     ((>= (cistern--cr-bladder c) 100) (cistern--accident c))
     ((>= (cistern--cr-bladder c) 70) (cistern--seek-toilet c))
     (t (cistern--seek-work c)))))

;;; Ore

(defun cistern--ore-list ()
  (let ((out nil) (i 0))
    (while (< i (length cistern--map))
      (when (eq (aref cistern--map i) 'ore)
        (push (cons (% i cistern--w) (/ i cistern--w)) out))
      (cl-incf i))
    (nreverse out)))

;;; Hazards

(defun cistern--add-hazard-at (x y)
  (when (and (cistern--in-bounds-p x y)
             (memq (cistern--cell x y) '(floor ore pipe)))
    (cistern--set-cell x y 'hazard)
    t))

(defun cistern--hazard-tick ()
  (let ((hazards nil) (i 0))
    (while (< i (length cistern--map))
      (when (eq (aref cistern--map i) 'hazard)
        (push (cons (% i cistern--w) (/ i cistern--w)) hazards))
      (cl-incf i))
    (setq hazards (nreverse hazards))
    (dolist (h hazards)
      (when (< (random 100) 6)
        (let* ((cands (cl-remove-if
                       (lambda (n)
                         (not (eq (cistern--cell (car n) (cdr n)) 'floor)))
                       (cistern--neighbors (car h) (cdr h))))
               (n (and cands (nth (random (length cands)) cands))))
          (when n
            (cistern--add-hazard-at (car n) (cdr n))))))))

;;; Migrants

(defun cistern--migrant-tick ()
  (when (and (> cistern--tick 0)
             (= 0 (% cistern--tick cistern--migrant-every))
             (< (length cistern--creators) cistern--creator-cap)
             (memq (cistern--cell 1 7) '(floor)))
    (setq cistern--creators
          (append cistern--creators (list (cistern--make-creator-at 1 7))))
    (cistern--log "MIGRANT ENTERED SECTOR — POPULATION %d"
                  (length cistern--creators))))

;;; Tick

(defun cistern--do-tick ()
  (setq cistern--tick (1+ cistern--tick))
  (dolist (c (copy-sequence cistern--creators))
    (cond
     ((cistern--cr-using c)
      (setf (cistern--cr-use-t c) (1- (cistern--cr-use-t c)))
      (when (<= (cistern--cr-use-t c) 0)
        (cistern--finish-use c)))
     (t
      (when (> (cistern--cr-sick c) 0)
        (unless (= 1 (mod cistern--tick 2))
          (setf (cistern--cr-sick c) (1- (cistern--cr-sick c)))))
      (setf (cistern--cr-bladder c) (+ 3 (cistern--cr-bladder c)))
      (cond
       ((>= (cistern--cr-bladder c) 100) (cistern--accident c))
       ((>= (cistern--cr-bladder c) 70) (cistern--seek-toilet c))
       (t (cistern--seek-work c))))))
  (cistern--hazard-tick)
  (cistern--migrant-tick)
  (when (>= cistern--contam cistern--contam-limit)
    (setq cistern--over "SECTOR CONDEMNED — CONTAMINATION LIMIT")
    (cistern--log cistern--over)))

;;; Player actions

(defun cistern--cmd-build (kind x y)
  (let ((cost (pcase kind
                ('toilet cistern--cost-toilet)
                ('pipe cistern--cost-pipe)
                ('tank cistern--cost-tank))))
    (cond
     ((not (cistern--in-bounds-p x y)) (cistern--log "OUT OF SECTOR"))
     ((not (eq (cistern--cell x y) 'floor)) (cistern--log "CANNOT BUILD THERE"))
     ((gethash (cons x y) (cistern--occupied-cells nil))
      (cistern--log "CREATOR IN THE WAY"))
     ((< cistern--alloy cost)
      (cistern--log "INSUFFICIENT ALLOY — %d REQUIRED" cost))
     (t
      (setq cistern--alloy (- cistern--alloy cost))
      (cistern--set-cell x y kind)
      (pcase kind
        ('toilet (puthash (cons x y) (list :busy nil :user nil) cistern--toilets))
        ('tank (puthash (cons x y) (list :load 0) cistern--tanks)))
      (cistern--log "%s PLACED AT (%d,%d) — %d ALLOY"
                    (upcase (symbol-name kind)) x y cost)))))

(defun cistern--cmd-decon (x y)
  (cond
   ((not (and (cistern--in-bounds-p x y)
              (eq (cistern--cell x y) 'hazard)))
    (cistern--log "NO CONTAMINANT UNDER CURSOR"))
   ((< cistern--alloy cistern--cost-decon)
    (cistern--log "INSUFFICIENT ALLOY — %d REQUIRED" cistern--cost-decon))
   (t
    (setq cistern--alloy (- cistern--alloy cistern--cost-decon))
    (cistern--set-cell x y 'floor)
    (cistern--log "DECONTAMINATED (%d,%d) — %d ALLOY" x y cistern--cost-decon))))

(defun cistern--cmd-purge (x y)
  (let ((tp (gethash (cons x y) cistern--tanks)))
    (cond
     ((not tp) (cistern--log "CURSOR NOT ON A TANK"))
     ((= (plist-get tp :load) 0) (cistern--log "TANK ALREADY CLEAR"))
     (t
      (let* ((load (plist-get tp :load))
             (gain (/ load 3)))
        (puthash (cons x y) (list :load 0) cistern--tanks)
        (setq cistern--alloy (+ cistern--alloy gain))
        (cistern--log "TANK PURGED — RECOVERED %d ALLOY" gain))))))

(defun cistern--cursor-move (dx dy)
  (let ((nx (+ (car cistern--cursor) dx))
        (ny (+ (cdr cistern--cursor) dy)))
    (when (cistern--in-bounds-p nx ny)
      (setq cistern--cursor (cons nx ny)))
    (cistern--render)))

;;; Rendering

(defun cistern--pipe-glyph (x y)
  (let* ((plumbp (lambda (px py)
                   (and (cistern--in-bounds-p px py)
                        (memq (cistern--cell px py) '(pipe toilet tank)))))
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

(defun cistern--glyph-face (x y)
  (let ((c (cistern--cell x y)))
    (pcase c
      ('wall (cons "▓" 'cistern-wall))
      ('floor (cons "·" 'cistern-floor))
      ('door (cons "+" 'cistern-door))
      ('ore (cons "◆" 'cistern-ore))
      ('hazard (cons "▒" 'cistern-hazard))
      ('toilet
       (let ((e (gethash (cons x y) cistern--toilets)))
         (cond ((plist-get e :busy) (cons "Ω" 'cistern-toilet-busy))
               ((cistern--toilet-usable-p x y) (cons "Ω" 'cistern-toilet))
               (t (cons "Ω" 'cistern-toilet-down)))))
      ('tank
       (let ((l (plist-get (gethash (cons x y) cistern--tanks) :load)))
         (cons "▣" (cond ((< l 30) 'cistern-tank-ok)
                         ((< l 51) 'cistern-tank-high)
                         (t 'cistern-tank-full)))))
      ('pipe (cons (cistern--pipe-glyph x y) 'cistern-pipe))
      (_ (cons "?" 'default)))))

(defun cistern--render ()
  (let ((inhibit-read-only t))
    (erase-buffer)
    ;; header
    (insert (propertize
             (format "CISTERN ▓ SECTOR-7 ▓ SHIFT %d  TICK %d   ALLOY %d   POP %d/%d   CONTAM %d/%d%s\n"
                     (1+ (/ cistern--tick 40)) cistern--tick
                     cistern--alloy
                     (length cistern--creators) cistern--creator-cap
                     cistern--contam cistern--contam-limit
                     (if cistern--over (concat "   ▓▓ " cistern--over) ""))
             'face 'cistern-header))
    (insert (propertize
             (format "[hjkl/arrows] cursor  [t]oilet %d  [p]ipe %d  [k]tank %d  [c]decon %d  [x]purge  [SPC]tick  [r]un  [n]new  [?]help  [q]quit\n"
                     cistern--cost-toilet cistern--cost-pipe
                     cistern--cost-tank cistern--cost-decon)
             'face 'cistern-dim))
    ;; grid
    (dotimes (y cistern--h)
      (dotimes (x cistern--w)
        (let* ((pos (cons x y))
               (cur (equal pos cistern--cursor))
               (cr (cl-find-if
                    (lambda (c) (and (= (cistern--cr-x c) x)
                                     (= (cistern--cr-y c) y)))
                    cistern--creators))
               (cell-g (cistern--glyph-face x y))
               (glyph (if cr (cistern--creator-glyph cr) (car cell-g)))
               (face (if cr
                         (if (> (cistern--cr-sick cr) 0)
                             'cistern-creator-sick 'cistern-creator)
                       (cdr cell-g))))
          (insert (propertize glyph 'face
                              (if cur (list 'cistern-cursor face) face)))))
      (insert "\n"))
    ;; status + log
    (insert (propertize (cistern--pressure-line) 'face 'cistern-dim))
    (insert "\n")
    (dolist (l (last (reverse cistern--log) 3))
      (insert (propertize l 'face 'cistern-dim) "\n"))
    (goto-char (point-min))))

(defun cistern--pressure-line ()
  (let* ((total-load 0)
         (_ (maphash (lambda (_k v) (setq total-load (+ total-load (plist-get v :load))))
                     cistern--tanks))
         (backed nil))
    (maphash (lambda (k _v)
               (when (and (not (plist-get (gethash k cistern--toilets) :busy))
                          (not (cistern--toilet-usable-p (car k) (cdr k))))
                 (setq backed t)))
             cistern--toilets)
    (cond (cistern--over "SECTOR CONDEMNED — PRESS n TO RESTART")
          (backed "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS")
          ((> total-load 100) "PRESSURE RISING — LINES NEAR CAPACITY")
          (t "LINES NOMINAL — THE STRUCTURE DOES NOT CARE"))))

;;; Mode and entry

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
  (unless cistern--map
    (cistern--new-game))
  (cistern--render))

(defun cistern--new-game ()
  (random t)
  (cistern--build-map)
  (cistern--spawn-initial)
  (setq cistern--alloy 20
        cistern--tick 0
        cistern--contam 0
        cistern--over nil
        cistern--log nil
        cistern--cursor (cons 3 6))
  (cistern--log "SECTOR-7 ONLINE — KEEP THE WATER MOVING"))

(defun cistern-new-game ()
  (interactive)
  (cistern--new-game)
  (cistern--render))

(defun cistern-tick ()
  (interactive)
  (if cistern--over
      (cistern--log "SECTOR CONDEMNED — PRESS n FOR NEW GAME")
    (cistern--do-tick))
  (cistern--render))

(defun cistern-run-10 ()
  (interactive)
  (dotimes (_ 10)
    (unless cistern--over (cistern--do-tick)))
  (cistern--render))

(defun cistern-cursor-north () (interactive) (cistern--cursor-move 0 -1))
(defun cistern-cursor-south () (interactive) (cistern--cursor-move 0 1))
(defun cistern-cursor-west () (interactive) (cistern--cursor-move -1 0))
(defun cistern-cursor-east () (interactive) (cistern--cursor-move 1 0))

(defun cistern-build-toilet ()
  (interactive)
  (cistern--cmd-build 'toilet (car cistern--cursor) (cdr cistern--cursor))
  (cistern--render))

(defun cistern-build-pipe ()
  (interactive)
  (cistern--cmd-build 'pipe (car cistern--cursor) (cdr cistern--cursor))
  (cistern--render))

(defun cistern-build-tank ()
  (interactive)
  (cistern--cmd-build 'tank (car cistern--cursor) (cdr cistern--cursor))
  (cistern--render))

(defun cistern-decon ()
  (interactive)
  (cistern--cmd-decon (car cistern--cursor) (cdr cistern--cursor))
  (cistern--render))

(defun cistern-purge ()
  (interactive)
  (cistern--cmd-purge (car cistern--cursor) (cdr cistern--cursor))
  (cistern--render))

(defun cistern-help ()
  (interactive)
  (with-output-to-temp-buffer "*cistern help*"
    (princ "CISTERN — sanitation protocol for Sector 7\n\n")
    (princ "The creators mine the structure.  The structure does not\ncare what they become.  You are the infrastructure.\n\n")
    (princ "Creators work the veins.  Their bladders fill.  At 70% they\nseek a toilet wired by pipe to a tank with headroom.  At 100%\nthey breach where they stand: the tile turns to contaminant,\nthe sector count rises, and the nearby fall sick.  At 20 the\nsector is condemned.\n\n")
    (princ "Each use sends 10 units down the line.  A full tank backs up\nevery toilet it feeds.  Purge with x on the tank; recover 1\nalloy per 3 units.  Contaminant spreads tile by tile.\n\n")
    (princ "Every 40 ticks a migrant arrives.  The pipes must grow.\n\n")
    (princ "CONTROLS\n")
    (princ "  SPC / RET   advance one tick\n")
    (princ "  hjkl / arrows   move cursor\n")
    (princ "  t           build toilet (12 alloy)\n")
    (princ "  p           lay pipe (2 alloy)\n")
    (princ "  K           build tank (15 alloy)\n")
    (princ "  c           decontaminate tile (4 alloy)\n")
    (princ "  x           purge tank under cursor (recovers alloy)\n")
    (princ "  r           run 10 ticks\n")
    (princ "  n           new game\n")
    (princ "  q           quit\n")))

(defun cistern-run-selftest ()
  "Batch self-test: map integrity, plumbing, breach, pathing, economy."
  (interactive)
  (cistern--new-game)
  (cl-assert (= cistern--w 34))
  (cl-assert (= cistern--h 16))
  (cl-assert (= (length cistern--map) (* cistern--w cistern--h)))
  ;; border solid
  (cl-loop for x from 0 below cistern--w
           do (cl-assert (memq (cistern--cell x 0) '(wall))))
  (cl-loop for y from 0 below cistern--h
           do (cl-assert (memq (cistern--cell 0 y) '(wall door))))
  ;; gates, start plumbing
  (cl-assert (eq (cistern--cell 0 7) 'door))
  (cl-assert (eq (cistern--cell 3 3) 'toilet))
  (cl-assert (gethash (cons 5 2) cistern--tanks))
  (cl-assert (cistern--toilet-usable-p 3 3))
  ;; full tank backs up the toilet; purge restores service and pays
  (maphash (lambda (k _v) (puthash k (list :load cistern--tank-cap) cistern--tanks))
           cistern--tanks)
  (cl-assert (not (cistern--toilet-usable-p 3 3)))
  (let ((a0 cistern--alloy))
    (cistern--cmd-purge 5 2)
    (cl-assert (= cistern--alloy (+ a0 (/ cistern--tank-cap 3)))))
  (cl-assert (cistern--toilet-usable-p 3 3))
  ;; forced breach on open floor
  (let ((c (car cistern--creators)))
    (setf (cistern--cr-x c) 12)
    (setf (cistern--cr-y c) 6)
    (setf (cistern--cr-bladder c) 99)
    (cistern--do-tick)
    (cl-assert (eq (cistern--cell 12 6) 'hazard))
    (cl-assert (= cistern--contam 1)))
  (cistern--cmd-decon 12 6)
  (cl-assert (eq (cistern--cell 12 6) 'floor))
  ;; build at cost
  (let ((a0 cistern--alloy))
    (cistern--cmd-build 'pipe 10 6)
    (cl-assert (eq (cistern--cell 10 6) 'pipe))
    (cl-assert (= cistern--alloy (- a0 cistern--cost-pipe))))
  ;; pathing toward ore
  (let ((c (nth 1 cistern--creators)))
    (setf (cistern--cr-x c) 20)
    (setf (cistern--cr-y c) 12)
    (setf (cistern--cr-bladder c) 0)
    (cistern--seek-work c)
    (cl-assert (= (cistern--cr-x c) 21)))
  ;; 60 ticks run without error
  (cistern--new-game)
  (dotimes (_ 60) (cistern--do-tick))
  (message "CISTERN-SELFTEST-OK"))

(provide 'cistern)
;;; cistern.el ends here
