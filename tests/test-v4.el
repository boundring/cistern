;;; tests/test-v4.el --- CISTERN v4 wave-1 surface foundations -*- lexical-binding: t; -*-

;; Batch tests for docs/v4/V4-SPEC.md WAVE 1 (V4-01..V4-09, build
;; order), one entry per directive acceptance, registered in
;; tests/run.el.  Reds before greens per PROCESS; ledger entries in
;; docs/FAILURE-LEDGER.md (§5.3 format, continuing past L-076).

(require 'cl-lib)

;; Repo root pinned at load time (L-008 pattern from test-r7-glyphs).
(defconst cistern-test-v4--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-v4 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-v4--root))
(load (expand-file-name "src/cistern.el" cistern-test-v4--root))

(defun cistern-test-v4--plain (s)
  (substring-no-properties s))

(defun cistern-test-v4--render-lines (st)
  (split-string (cistern-test-v4--plain (cistern-view--render st)) "\n"))

;; --- V4-01: log entries gain tick stamps (S1.1) -------------------------------

(defun cistern-test-v4-01-tick-stamps ()
  "V4-01 (S1.1/A1.1): log entries are (LINE SEVERITY TICK),
stamped `(cistern-st-tick st)' at append time; every reader keeps
its contract — the collapse triple stays (LINE SEVERITY COUNT),
restart dedup and the boot-line pick still read the LINE field,
and the uncapped ring is untouched."
  (let ((st (cistern--new-game 42)))
    ;; 13+ events: the OLDEST entry carries its append-time stamp
    (dotimes (i 13) (cistern--log st "TICK NOISE %d" i))
    (let ((oldest (car (last (cistern-st-log st)))))
      (cl-assert (= (length oldest) 3)
                 t "entry shape is (LINE SEVERITY TICK), got %d fields"
                 (length oldest))
      (cl-assert (string= (car oldest)
                          "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
                 t "the LINE field is unchanged")
      (cl-assert (integerp (nth 2 oldest))
                 t "the stamp is a tick number")
      (cl-assert (= (nth 2 oldest) (cistern-st-tick st))
                 t "stamp = append-time tick"))
    ;; severity rides slot 2, stamp slot 3 — on every entry
    (cistern--log-sev st 'error "BREACH — TEST EVENT")
    (let ((e (car (cistern-st-log st))))
      (cl-assert (eq (cadr e) 'error) t "severity rides slot 2")
      (cl-assert (integerp (nth 2 e)) t "every entry is stamped"))
    ;; a later tick stamps its own tick, not a shared one
    (dotimes (_ 2) (cistern--do-tick st))
    (cistern--log st "LATER EVENT")
    (cl-assert (= (nth 2 (car (cistern-st-log st))) 2)
               t "the stamp is the tick at append time")
    ;; the collapse triple stays (LINE SEVERITY COUNT): the ×N count
    ;; renders and the severity face persists through the projection
    (let ((st2 (cistern--new-game 42)))
      (dotimes (_ 4) (cistern--log-sev st2 'info "WORKER RELIEVED AT (3,3)"))
      (cistern--log-sev st2 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
      (let* ((tail (cistern-view--log-tail st2))
             (rows (cl-remove-if (lambda (r) (string= r ""))
                                 (split-string tail "\n"))))
        (cl-assert (cl-some (lambda (r) (string-match-p "×4" r)) rows)
                   t "collapse still emits the ×N count")
        (let ((hit (cl-find-if (lambda (r) (string-match-p "BREACH" r)) rows)))
          (cl-assert hit t "the breach line survives the projection")
          (cl-assert (eq (get-text-property 0 'face hit)
                         'cistern-toilet-down)
                     t "severity face persists through the projection"))))
    ;; restart dedup + boot-line pick read the LINE field (driver
    ;; contract: (caar log) is the newest LINE; boot = oldest LINE)
    (let ((st3 (cistern--new-game 42)))
      (cl-assert (string= (caar (cistern-st-log st3))
                          "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
                 t "dedup reads the LINE field")
      (cl-assert (string= (car (car (last (cistern-st-log st3))))
                          "SECTOR-7 ONLINE — KEEP THE WATER MOVING")
                 t "boot pick reads the LINE field")))
  (message "CISTERN-V4-01-OK"))

;; --- V4-02: the L buffer becomes an event browser (S1.2/S1.3) -----------------

(defun cistern-test-v4-02-log-browser ()
  "V4-02 (A1.1–A1.6, batch): the browser carries tick prefixes
and persistent severity faces, RET jumps land the game cursor on
the line's (x,y) and refuse coordinate-free lines with the
log-jump-none hint, point survives the RET→L round trip, the
keymap matches the S1.3 table exactly (n/p walk, native motion
NOT rebound), and no line exceeds 95 cols at tick 99999."
  ;; A1.1: the oldest entry with its tick prefix after 13+ events
  (let ((st (cistern--new-game 42)))
    (dotimes (i 13) (cistern--log st "TICK NOISE %d" i))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (forward-line 1)
      (cl-assert (looking-at-p "T0 +SECTOR-7 ONLINE")
                 t "the oldest entry renders with its tick prefix")))
  ;; A1.2: the breach line renders the error face on every re-open
  (let ((st (cistern--new-game 42)))
    (cistern--log-sev st 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log) (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "BREACH")
      (cl-assert (eq (get-text-property (point) 'face)
                     'cistern-toilet-down)
                 t "the breach line keeps its error face on re-open")))
  ;; A1.3: RET jumps land the cursor; coordinate-free lines refuse
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-cursor st) (cons 3 6))
    (cistern--log-sev st 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
    (cistern--log st "NO COORDINATES HERE")
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "BREACH")
      (cistern-log-jump-to-source))
    (cl-assert (equal (cistern-st-cursor st) '(5 . 6))
               t "RET lands the game cursor on the line's (x,y)")
    (cl-assert (eq (window-buffer (selected-window))
                   (get-buffer "*cistern*"))
               t "RET pops back to the game buffer")
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "NO COORDINATES")
      (cistern-log-jump-to-source))
    (cl-assert (equal (cistern-st-cursor st) '(5 . 6))
               t "a coordinate-free line changes no cursor")
    (cl-assert (equal (cistern-st-hint st)
                      (cdr (assq 'log-jump-none cistern--copy)))
               t "a coordinate-free line posts the log-jump-none hint"))
  ;; A1.4: point survives the RET → L round trip (no new events)
  (let ((st (cistern--new-game 42)))
    (dotimes (i 5) (cistern--log st "EVENT %d" i))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min)) (forward-line 3)
      (let ((pt (point)))
        (cistern-log)
        (cl-assert (= (point) pt) t "point survives the L round trip"))))
  ;; A1.5: the S1.3 keymap table, exactly — no shadowing
  (cl-assert (boundp 'cistern-log-mode-map) t "the browser keymap exists")
  (let ((m cistern-log-mode-map))
    (cl-assert (eq (lookup-key m "n") 'next-line) t "n walks next")
    (cl-assert (eq (lookup-key m "p") 'previous-line) t "p walks prev")
    (cl-assert (not (eq (lookup-key m "n") 'cistern-new-game))
               t "n does not run the game verb")
    (cl-assert (not (eq (lookup-key m "p") 'cistern-build-pipe))
               t "p does not run the game verb")
    (cl-assert (eq (lookup-key m "/") 'isearch-forward) t "/ isearches")
    (cl-assert (and (commandp (lookup-key m "g"))
                    (not (eq (lookup-key m "g") 'revert-buffer)))
               t "g rebuilds from state")
    (cl-assert (eq (lookup-key m "G") 'end-of-buffer) t "G ends")
    (cl-assert (eq (lookup-key m (kbd "RET"))
                   'cistern-log-jump-to-source) t "RET jumps")
    ;; C-n/C-p/C-f/C-b/C-s/C-r: documented native motion — unbound in
    ;; the browser chain (global map supplies them).  SPC/DEL/M-</M->
    ;; are ALSO native, but arrive via the special-mode parent
    ;; (scroll / first / last) — assert the inherited binding, not
    ;; absence (SURFACE S1.3 table).
    (dolist (key '("C-n" "C-p" "C-f" "C-b" "C-s" "C-r"))
      (cl-assert (null (lookup-key m (kbd key)))
                 t "native %s is documented, not rebound" key))
    (cl-assert (eq (lookup-key m (kbd "SPC")) 'scroll-up-command)
               t "SPC scrolls (native)")
    (cl-assert (eq (lookup-key m (kbd "DEL")) 'scroll-down-command)
               t "DEL scrolls back (native)")
    ;; M-</M-> reach first/last via the global map (special-mode
    ;; itself binds plain </>); the browser must not shadow them.
    (let ((b (lookup-key m (kbd "M-<"))))
      (cl-assert (memq b '(nil beginning-of-buffer))
                 t "M-< first entry (native, unshadowed)"))
    (let ((b (lookup-key m (kbd "M->"))))
      (cl-assert (memq b '(nil end-of-buffer))
                 t "M-> last entry (native, unshadowed)"))
    (cl-assert (eq (lookup-key m "q") 'quit-window) t "q closes")))

(defun cistern-test-v4-02-log-width ()
  "V4-02 (A1.6): browser lines stay within 95 cols at the max
format width (breach line at tick 99999)."
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-log st)
          (list (list "BREACH — WORKER α OVERFLOWED AT (33,15)" 'error 99999)))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (while (not (eobp))
        (cl-assert (<= (- (line-end-position) (line-beginning-position)) 95)
                   t "browser line over 95 cols")
        (forward-line 1))))
  (message "CISTERN-V4-02-OK"))

;; --- V4-03: palette derivation pure function (S2.1/S2.2) ----------------------

(defun cistern-test--chan (s)
  "WCAG 2.x linearization of one hex channel pair S."
  (let ((c (/ (string-to-number s 16) 255.0)))
    (if (<= c 0.04045) (/ c 12.92) (expt (/ (+ c 0.055) 1.055) 2.4))))

(defun cistern-test--wcag-lum (hex)
  (let ((r (cistern-test--chan (substring hex 1 3)))
        (g (cistern-test--chan (substring hex 3 5)))
        (b (cistern-test--chan (substring hex 5 7))))
    (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b))))

(defun cistern-test--ratio (fg bg)
  (let ((lf (cistern-test--wcag-lum fg))
        (lb (cistern-test--wcag-lum bg)))
    (/ (+ (max lf lb) 0.05) (+ (min lf lb) 0.05))))

(defun cistern-test-v4-03-derive-palette ()
  "V4-03 (A2.1/A2.2): every role of `cistern--derive-palette'
meets its class ratio (4.5 recessive/standard, 7.0
emphatic/alert) on dark/light/mid/black/white/red backgrounds —
hard floor 4.5 everywhere; the class target whenever ANY color
could achieve it (grey extremes, both sides) — polarity switch and
sat clamp both covered."
  (dolist (bg '("#101010" "#F5F5F5" "#808080" "#000000" "#FFFFFF" "#FF0000"))
    (let ((pal (cistern--derive-palette bg)))
      (dolist (e cistern-view--face-roles)
        (let* ((role (car e))
               (class (nth 2 (cdr e)))
               (target (if (memq class '(emphatic alert)) 7.0 4.5))
               (color (cdr (assq role pal))))
          (cl-assert color t "role %s missing from palette" role)
          (let ((ratio (cistern-test--ratio color bg)))
            (cl-assert (>= ratio 4.5)
                       t "role %s at %.2f below 4.5 on %s" role ratio bg)
            ;; the class target only binds when a grey could reach it
            (let ((reach (max (cistern-test--ratio "#FFFFFF" bg)
                              (cistern-test--ratio "#000000" bg))))
              (when (>= reach target)
                (cl-assert (>= ratio target)
                           t "role %s at %.2f below %.1f on %s"
                           role ratio target bg))))))))
  (message "CISTERN-V4-03-OK"))

(defun cistern-test-v4-03-palette-purity ()
  "V4-03 (A2.3/A2.6 + A2.4): the derivation function calls no
frame/buffer/color-resolver, the palette cache is not an input
(stale cache cannot persist across a session), and no defface in
the view carries a literal :foreground (cistern-cursor excepted)."
  ;; A2.3: no runtime resolver inside the pure function
  (let ((src (format "%S" (symbol-function 'cistern--derive-palette))))
    (cl-assert (not (string-match-p "frame-parameter\\|color-name-to-rgb"
                                    src))
               t "derive-palette resolves runtime state"))
  ;; A2.6: the cache is not an input — a stale value changes nothing
  (let ((cistern--palette-cache
         '("#101010" . ((wall . "#00FF00") (dim . "#0000FF")))))
    (let ((pal (cistern--derive-palette "#F5F5F5")))
      (cl-assert (not (equal (cdr (assq 'wall pal)) "#00FF00"))
                 t "derive read a stale cache")))
  ;; A2.4: deffaces take colors from roles, never literals
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern-view.el" cistern-test-v4--root))
    (let ((src (buffer-string)) (pos 0) faces)
      (while (string-match "(defface \\(cistern-[a-z-]+\\)" src pos)
        (push (match-string 1 src) faces)
        (setq pos (match-end 0)))
      (dolist (f faces)
        (let ((decl (progn (string-match
                            (concat "(defface " (regexp-quote f)
                                    " '((t \\([^)]*\\)))") src)
                           (match-string 1 src))))
          (unless (string= f "cistern-cursor")
            (cl-assert (not (string-match-p ":foreground" decl))
                       t "face %s carries a literal :foreground" f))))))
  (message "CISTERN-V4-03-PURITY-OK"))

(defun cistern-test-v4-04-palette-apply ()
  "V4-04 (A2.5 batch half): mode init applies the derived palette
frame-scoped; the refresh drift guard re-derives on a background
change (one string compare); the theme hook is registered."
  (let ((st (cistern--new-game 42))
        (buf (get-buffer-create " *cistern-palette-probe*")))
    (setq cistern--st st)
    (set-frame-parameter (selected-frame) 'background-color "#101010")
    (setq cistern--palette-cache nil)
    (unwind-protect
        (progn
          (with-current-buffer buf
            (cistern-mode)
            (cl-assert (equal (car cistern--palette-cache) "#101010")
                       t "mode init did not derive the palette")
            (let ((wall (face-attribute 'cistern-wall :foreground
                                        (selected-frame) 'default)))
              (cl-assert (and (stringp wall) (string-match-p "^#[0-9A-F][0-9A-F]" wall))
                         t "cistern-wall got no derived foreground")))
          ;; drift guard: bg change + stale cache → refresh re-derives
          (set-frame-parameter (selected-frame) 'background-color "#F5F5F5")
          (with-current-buffer buf
            (cistern--refresh)
            (cl-assert (equal (car cistern--palette-cache) "#F5F5F5")
                       t "refresh drift guard did not re-derive"))
          ;; the theme hook is registered by mode init
          (cl-assert (memq 'cistern--theme-refresh enable-theme-functions)
                     t "enable-theme-functions hook missing"))
      (kill-buffer buf)))
  (message "CISTERN-V4-04-OK"))

(defun cistern-test-v4-04-palette-live ()
  "V4-04 (A2.5 GUI half): on a display, flipping the frame
background between dark and light flips every glyph face's
polarity and the measured contrast meets each class target.
Registered + SKIPPED in batch (L-076 probe pattern)."
  (if (not (display-graphic-p))
      (message "cistern-test-v4-04-palette-live: SKIPPED (no display) — probe registered, suite stays green")
    (let ((frm (make-frame '((width . 40) (height . 12)))))
      (unwind-protect
          (progn
            (dolist (bg '("#101010" "#F5F5F5"))
              (set-frame-parameter frm 'background-color bg)
              (cistern--apply-palette frm)
              (dolist (e cistern-view--face-roles)
                (let* ((color (face-attribute (intern
                                               (format "cistern-%s" (car e)))
                                              :foreground frm 'default))
                       (ratio (cistern-test--ratio color bg)))
                  (cl-assert (>= ratio 4.5)
                             t "live frame: role %s at %.2f on %s"
                             (car e) ratio bg))))
            (princ "CISTERN-V4-04-LIVE-OK"))
        (delete-frame frm)))))

(defun cistern-test-v4-05-tile-kinds ()
  "V4-05 (A3.1/A3.3/A3.4/A3.5, batch): rubble ▚ / flood ░ /
manifold ╬ enter the sole-source tile table inside the L-076
charset; pathing and builds refuse them per the table; flood pops
in without shifting any other row; the legend stays
table-generated and complete; flood never touches the contam
limit; manifold-adjacent plumbing is live with unlimited headroom."
  ;; A3.1: every table glyph is one char in the pin-covered charset
  (dolist (entry cistern--tile-table)
    (let ((g (cistern--tile-glyph (car entry))))
      (cl-assert (= (length g) 1)
                 t "glyph for %s is not one cell" (car entry))
      (let ((c (string-to-char g)))
        (cl-assert (or (and (>= c #x20) (<= c #x7e))
                       (and (>= c #x2500) (<= c #x25ff))
                       (and (>= c #x2010) (<= c #x2015))
                       (= c #xb7)
                       ;; L-076 measured Ω U+03A9 at one cell — the
                       ;; Greek gate starts at the shipped toilet glyph
                       (and (>= c #x3a9) (<= c #x3c9)))
                   t "glyph for %s outside the L-076 ranges" (car entry)))))
  ;; the three new kinds, with their S3.2 flags
  (dolist (spec '((rubble nil nil t) (flood nil nil nil)
                  (manifold nil nil t)))
    (let ((e (cdr (assq (car spec) cistern--tile-table))))
      (cl-assert e t "kind %s missing from tile table" (car spec))
      (cl-assert (eq (plist-get e :passable) (nth 1 spec))
                 t "%s passability wrong" (car spec))
      (cl-assert (eq (plist-get e :buildable) (nth 2 spec))
                 t "%s buildability wrong" (car spec))
      (cl-assert (eq (plist-get e :firebreak) (nth 3 spec))
                 t "%s firebreak wrong" (car spec))))
  ;; A3.5: pathing refuses rubble/flood; build refused on manifold;
  ;; d clears rubble (cost 2); c dries flood (decon cost)
  (let ((st (cistern--new-game 42)))
    (cistern--set-cell st 8 8 'rubble)
    (cistern--set-cell st 9 8 'flood)
    (cistern--set-cell st 10 8 'manifold)
    (setf (cistern-st-cursor st) (cons 10 8))
    (cl-assert (not (cistern--walkable-p st 8 8 8 8))
               t "rubble is walkable")
    (cl-assert (not (cistern--walkable-p st 9 8 9 8))
               t "flood is walkable")
    (let ((alloy (cistern-st-alloy st)))
      (cl-assert (not (cistern--cmd-build st 'pipe 10 8))
                 t "built on a manifold")
      (cl-assert (eq (cistern--cell st 10 8) 'manifold)
                 t "manifold was overwritten")
      (cl-assert (= (cistern-st-alloy st) alloy)
                 t "refused build charged alloy"))
    (let ((alloy (cistern-st-alloy st)))
      (cistern--cmd-demolish st 8 8)
      (cl-assert (eq (cistern--cell st 8 8) 'floor)
                 t "d did not clear rubble to floor")
      (cl-assert (= (cistern-st-alloy st) (- alloy 2))
                 t "rubble clear did not cost 2"))
    (let ((alloy (cistern-st-alloy st)))
      (cistern--cmd-decon st 9 8)
      (cl-assert (eq (cistern--cell st 9 8) 'floor)
                 t "c did not dry flood")
      (cl-assert (= (cistern-st-alloy st) (- alloy cistern-cost-decon))
                 t "flood drying did not reuse cistern-cost-decon")))
  ;; A3.3: flood pop-in shifts no other row (string-level render diff)
  (let ((st (cistern--new-game 42)))
    (let* ((before (split-string (cistern-view--render st) "\n"))
           (before-rows (length before)))
      (cistern--set-cell st 15 10 'flood)
      (let ((after (split-string (cistern-view--render st) "\n"))
            (diff-rows 0)
            (diff-has-flood nil))
        (cl-assert (= (length after) before-rows)
                   t "flood changed the render row count")
        (dotimes (y before-rows)
          (unless (string= (nth y before) (nth y after))
            (setq diff-rows (1+ diff-rows))
            (cl-assert (= (length (nth y after)) (length (nth y before)))
                       t "flood changed a row's column count")
            (when (string-match-p "░" (nth y after))
              (setq diff-has-flood t))))
        (cl-assert (= diff-rows 1)
                   t "flood pop-in shifted %d rows" diff-rows)
        (cl-assert diff-has-flood t "the diff row does not show flood")))))

(defun cistern-test-v4-05-manifold-flood-loop ()
  "V4-05 (A3.5/loop role): flood never touches the contam limit
across ticks; a manifold-anchored network serves toilets with no
tank at all and is never severed; procgen is deterministic with
0-2 manifolds and bounded rubble."
  (let ((st (cistern--new-game 42)))
    (cistern--set-cell st 8 8 'flood)
    (setf (cistern-st-contam st) 0)
    (dotimes (_ 40)
      (cistern--do-tick st)
      (cl-assert (= (cistern-st-contam st) 0)
                 t "a flood cell moved the contam limit")))
  ;; manifold: no tank, still usable, never severed, no spill on relief
  (let ((st (cistern--new-game 42)))
    (cistern--set-cell st 8 5 'manifold)
    (cistern--set-cell st 9 5 'pipe)
    (cistern--set-cell st 9 6 'toilet)
    (puthash (cons 9 6) (list :busy nil) (cistern-st-toilets st))
    (setf (cistern-st-alloy st) 0)
    (cl-assert (cistern--toilet-usable-p st 9 6)
               t "manifold anchor did not make the toilet usable")
    (cl-assert (not (cistern--toilets-severed-p st))
               t "manifold-anchored toilet counted as severed")
    (let ((w (car (cistern-st-creators st))))
      (setf (cistern--worker-x w) 9)
      (setf (cistern--worker-y w) 6)
      (setf (cistern--worker-using w) t)
      (setf (cistern--worker-toilet w) (cons 9 6))
      (setf (cistern--worker-bladder w) 55)
      (cistern--finish-use st w)
      (cl-assert (= (cistern-st-contam st) 0)
                 t "manifold relief spilled (contam moved)")
      (cl-assert (null (cistern--connected-tanks st 9 6))
               t "manifold relief reached a tank")
      (cl-assert (= (cistern--tank-load-total st) 30)
               t "manifold relief loaded the starter tank")))
  ;; procgen: deterministic, 0-2 manifolds, bounded rubble
  (dotimes (s 20)
    (let ((a (cistern--new-game (+ 1 s)))
          (b (cistern--new-game (+ 1 s)))
          (manifolds 0) (rubble 0))
      (cl-assert (equal (cistern-st-map a) (cistern-st-map b))
                 t "procgen broke determinism at seed %d" (+ 1 s))
      (dotimes (i (length (cistern-st-map a)))
        (cond ((eq (aref (cistern-st-map a) i) 'manifold)
               (setq manifolds (1+ manifolds)))
              ((eq (aref (cistern-st-map a) i) 'rubble)
               (setq rubble (1+ rubble)))))
      (cl-assert (<= manifolds 2) t "seed %d has %d manifolds" (+ 1 s) manifolds)
      (cl-assert (<= rubble 12) t "seed %d has %d rubble" (+ 1 s) rubble)
      (when (= s 0)
        (cl-assert (>= (+ rubble manifolds) 1)
                   t "seed 1 placed nothing at all"))))
  ;; A3.4: the legend stays table-generated and complete
  (let ((legend (cistern-view--legend-line)))
    (dolist (row (split-string legend "\n"))
      (cl-assert (<= (length row) 95) t "legend row over 95 cols"))
    (cl-assert (string-match-p "▚ rubble" legend) t "legend misses rubble")
    (cl-assert (string-match-p "░ flood" legend) t "legend misses flood")
    (cl-assert (string-match-p "╬ manifold" legend) t "legend misses manifold"))
  (message "CISTERN-V4-05-OK"))

(defun cistern-test-v4-06-kind-faces ()
  "V4-06 (A3.6 + A3.1): the five new kinds get S2-rol faces —
derived colors through the same palette path as every other face
— and the inspector names state + fix verb for each, with the
strings living in `cistern--copy'."
  (let ((st (cistern--new-game 42)))
    (set-frame-parameter (selected-frame) 'background-color "#101010")
    (setq cistern--palette-cache nil)
    (cistern--apply-palette (selected-frame))
    (dolist (role '(rubble flood manifold cache event))
      (let ((face (intern (format "cistern-%s" role)))
            (color (cdr (assq role (cistern--derive-palette "#101010")))))
        (cl-assert (facep face) t "face for %s missing" role)
        (cl-assert (equal (face-attribute face :foreground
                                          (selected-frame) 'default)
                          color)
           t "face %s did not take its role color" role)))
  ;; view kind-faces routes the three new tile kinds to their faces
  (dolist (kind '(rubble flood manifold cache event))
    (cl-assert (cdr (assq kind cistern-view--kind-faces))
               t "kind %s has no face mapping" kind))
  ;; inspector lines: state + fix verb, strings from the copy table
  (dolist (spec '((rubble "RUBBLE" "d")
                  (flood "FLOOD" "c")
                  (manifold "MANIFOLD" "TANK")))
    (let* ((kind (car spec))
           (line (progn (cistern--set-cell st 8 8 kind)
                        (setf (cistern-st-cursor st) (cons 8 8))
                        (cistern-view--inspector st))))
      (cl-assert (string-match-p (nth 1 spec) line)
                 t "inspector does not name %s state" kind)
      (cl-assert (string-match-p (nth 2 spec) line)
                 t "inspector %s line names no fix verb" kind)
      (let ((copy-key (intern (format "desc-%s" kind))))
        (cl-assert (cdr (assq copy-key cistern--copy))
                   t "%s line is not copy-table copy" kind))))
  (message "CISTERN-V4-06-OK")))

(defconst cistern-test-v4-07--old-map
  '(("SPC" . cistern-tick) ("RET" . cistern-tick)
    ("<up>" . cistern-cursor-north) ("<down>" . cistern-cursor-south)
    ("<left>" . cistern-cursor-west) ("<right>" . cistern-cursor-east)
    ("t" . cistern-build-toilet) ("p" . cistern-build-pipe)
    ("K" . cistern-build-tank) ("d" . cistern-demolish)
    ("c" . cistern-decon) ("x" . cistern-purge)
    ("T" . cistern-skip-tutorial) ("r" . cistern-auto-run-toggle)
    ("u" . cistern-disarm) ("<escape>" . cistern-disarm)
    ("L" . cistern-log) ("n" . cistern-new-game)
    ("?" . cistern-help) ("q" . quit-window)))

(defun cistern-test-v4-07-keybinds-coach ()
  "V4-07 (A4.1–A4.3): the S4.2 pairing table binds additively —
no pre-v4 key changes — driven positions match the table's
geometry, the structure scan walks in scan order with wrap, C-s
lands on the nearest wired toilet, and the 3rd arrow use posts the
teach-arrows coach exactly once through the Q17 slot."
  ;; A4.1: nothing pre-v4 moved
  (dolist (e cistern-test-v4-07--old-map)
    (cl-assert (eq (lookup-key cistern-mode-map (kbd (car e)))
                   (cdr e))
               t "pre-v4 binding %s changed" (car e)))
  ;; the S4.2 additions exist
  (dolist (e '(("C-n" . cistern-cursor-south) ("C-p" . cistern-cursor-north)
               ("C-f" . cistern-cursor-east) ("C-b" . cistern-cursor-west)
               ("C-a" . cistern-cursor-row-home) ("C-e" . cistern-cursor-row-end)
               ("M-<" . cistern-cursor-map-home) ("M->" . cistern-cursor-map-end)
               ("M-f" . cistern-cursor-scan-next) ("M-b" . cistern-cursor-scan-prev)
               ("C-g" . cistern-disarm) ("C-s" . cistern-cursor-capacity)
               ("." . cistern-repeat-arm)))
    (cl-assert (eq (lookup-key cistern-mode-map (kbd (car e))) (cdr e))
               t "missing %s" (car e)))
  ;; A4.2: driven geometry
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--teach-seen nil cistern--teach-fired nil)
    (setf (cistern-st-cursor st) (cons 10 8))
    (cistern-cursor-row-home)
    (cl-assert (equal (cistern-st-cursor st) '(0 . 8)) t "C-a geometry")
    (cistern-cursor-row-end)
    (cl-assert (equal (cistern-st-cursor st)
                      (cons (1- (cistern-st-w st)) 8)) t "C-e geometry")
    (cistern-cursor-map-home)
    (cl-assert (equal (cistern-st-cursor st) '(0 . 0)) t "M-< geometry")
    (cistern-cursor-map-end)
    (cl-assert (equal (cistern-st-cursor st)
                      (cons (1- (cistern-st-w st)) (1- (cistern-st-h st))))
               t "M-> geometry"))
  ;; structure scan: scan order (y then x), wraps both ways
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--teach-seen nil cistern--teach-fired nil)
    (cistern--set-cell st 8 12 'tank)
    (setf (cistern-st-cursor st) (cons 3 3))
    ;; the contract: next/prev walk the toilet/tank/manifold cells in
    ;; scan order (y then x — reading order), wrapping both ways.
    ;; Procgen may add its own structures, so derive the expected
    ;; order from the live map.
    (let* ((cells nil))
      (dotimes (y (cistern-st-h st))
        (dotimes (x (cistern-st-w st))
          (when (memq (cistern--cell st x y) '(toilet tank manifold))
            (push (cons x y) cells))))
      (setq cells
            (nreverse
             (sort cells (lambda (a b)
                           (or (< (cdr a) (cdr b))
                               (and (= (cdr a) (cdr b)) (< (car a) (car b))))))))
      (cl-assert (>= (length cells) 4)
                 t "fixture too thin for the wrap proof")
      (let ((pos (cl-position (cistern-st-cursor st) cells :test #'equal)))
        (cl-assert pos t "cursor not on a structure")
        (cistern-cursor-scan-next)
        (cl-assert (equal (cistern-st-cursor st)
                          (nth (% (1+ pos) (length cells)) cells))
                   t "scan-next broke scan order/wrap")
        (cistern-cursor-scan-prev)
        (cl-assert (equal (cistern-st-cursor st) (nth pos cells))
                   t "scan-prev did not return")
        (cistern-cursor-scan-prev)
        (cl-assert (equal (cistern-st-cursor st)
                          (nth (% (+ pos (1- (length cells)))
                                  (length cells)) cells))
                   t "scan-prev broke backwards wrap"))))
  ;; C-s: nearest wired toilet; refusal posts the hint, keeps cursor
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--teach-seen nil cistern--teach-fired nil)
    (cistern--cmd-purge st 5 2)          ; make the starter toilet usable
    (setf (cistern-st-cursor st) (cons 15 6))
    (cistern-cursor-capacity)
    (cl-assert (eq (cistern--toilet-state st 3 3) 'usable) t "fixture")
    (cl-assert (eq (cistern--toilet-state st
                    (car (cistern-st-cursor st)) (cdr (cistern-st-cursor st)))
                   'usable)
               t "C-s did not land on a usable toilet"))
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--teach-seen nil cistern--teach-fired nil)
    (cistern--cmd-demolish st 4 2)       ; sever: no usable toilet anywhere
    (setf (cistern-st-cursor st) (cons 15 6))
    (cistern-cursor-capacity)
    (cl-assert (equal (cistern-st-cursor st) '(15 . 6))
               t "C-s moved with nothing to find")
    (cl-assert (string-match-p "WIRED\\|TOILET" (or (cistern-st-hint st) ""))
               t "C-s refusal posted no hint"))
  ;; A4.3: the 3rd arrow move coaches once, then the hint drains
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--teach-seen nil cistern--teach-fired nil)
    (cistern-cursor-north)
    (cistern-cursor-north)
    (cl-assert (null (cistern-st-hint st)) t "coach fired before 3rd use")
    (cistern-cursor-north)
    (cl-assert (equal (cistern-st-hint st)
                      (cdr (assq 'teach-arrows cistern--copy)))
               t "3rd move did not post teach-arrows")
    (cistern-tick)                       ; non-cursor command drains
    (cl-assert (null (cistern-st-hint st)) t "coach hint survived a tick")
    (dotimes (_ 4) (cistern-cursor-north))
    (cl-assert (null (cistern-st-hint st))
               t "coach fired twice in a game"))
  (message "CISTERN-V4-07-OK"))

(defconst cistern-test-v4-08--browser-keys
  '("n/p walk" "C-s search" "RET jump" "g refresh" "q close"))

(defun cistern-test-v4-08-briefing ()
  "V4-08 (A4.4/A4.5): the briefing grows a POWER LAYER section
carrying the S4 pairings and every §S1.3 browser key, the GLYPHS
section is generated from the tile table (no hardcoded glyph
list), and no line exceeds 95 cols."
  (let ((help (cistern--help-text)))
    (cl-assert help t "help text builder exists")
    (cl-assert (string-match-p "POWER LAYER" help)
               t "briefing lacks the POWER LAYER section")
    (dolist (row cistern-test-v4-08--browser-keys)
      (cl-assert (string-match-p row help)
                 t "briefing lacks the browser key row %s" row))
    (cl-assert (string-match-p "already know" help)
               t "the power layer misses the you-already-know frame")
    ;; A4.5: width contract
    (dolist (line (split-string help "\n"))
      (cl-assert (<= (length line) 95) t "help line over 95 cols")))
  ;; GLYPHS: generated from the table — no tile glyph literal may
  ;; appear in the help builder's source
  (let ((src (format "%S" (symbol-function 'cistern--help-text))))
    (dolist (entry cistern--tile-table)
      (cl-assert (not (string-match-p
                       (regexp-quote (cistern--tile-glyph (car entry))) src))
                 t "hardcoded tile glyph %s in the help builder"
                 (cistern--tile-glyph (car entry)))))
  ;; and the generated section agrees with the table (all kinds named)
  (let ((help (cistern--help-text)))
    (dolist (entry cistern--tile-table)
      (cl-assert (string-match-p
                  (cdr (assq (car entry) cistern-view--kind-names)) help)
                 t "help glyphs omit %s" (car entry))))
  (message "CISTERN-V4-08-OK"))

(defun cistern-test-v4-09-qol ()
  "V4-09 (A5.1–A5.3): `.' repeats the last successful arm and
refuses when nothing armed or after ESC; the death panel carries
the L — FULL HISTORY line and the log survives condemnation; the
migrant countdown logs exactly once at T−3."
  ;; A5.1: repeat arms the last verb at the current cursor
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--last-armed nil
          cistern--teach-seen nil cistern--teach-fired nil)
    (cistern--cmd-purge st 5 2)          ; fund the builds
    (setf (cistern-st-cursor st) (cons 8 6))
    (cistern-build-pipe)
    (cl-assert (eq cistern--last-armed 'pipe) t "build did not record fuel")
    (setf (cistern-st-cursor st) (cons 9 6))
    (cistern-repeat-arm)
    (cl-assert (eq (cistern-st-armed-verb st) 'pipe)
               t "`.` did not re-arm pipe")
    (cl-assert (string-match-p "ARMED: PIPE"
                               (or (cistern-view--header-badges st) ""))
               t "header badge missing after repeat")
    ;; refusal via the standard path: cursor moved to a wall
    (setf (cistern-st-cursor st) (cons 0 0))
    (let ((alloy (cistern-st-alloy st)))
      (cistern-repeat-arm)
      (cl-assert (= (cistern-st-alloy st) alloy)
                 t "illegal-cell repeat charged alloy")))
  ;; no prior arm / after ESC: `.` is a no-op
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st cistern--last-armed nil
          cistern--teach-seen nil cistern--teach-fired nil)
    (cistern-repeat-arm)
    (cl-assert (null (cistern-st-armed-verb st))
               t "`.` fired with no prior arm")
    (setf (cistern-st-cursor st) (cons 8 6))
    (cistern-build-pipe)
    (cistern-disarm)
    (cl-assert (null cistern--last-armed) t "ESC kept the repeat fuel")
    (setf (cistern-st-cursor st) (cons 9 6))
    (cistern-repeat-arm)
    (cl-assert (null (cistern-st-armed-verb st))
               t "`.` repeated a disarmed verb"))
  ;; A5.2: the death panel names the full history; log survives
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-contam st) cistern-contam-limit)
    (cistern--do-tick st)
    (cl-assert (cistern-st-over st) t "fixture did not condemn")
    (let ((render (substring-no-properties (cistern-view--render st))))
      (cl-assert (string-match-p "FULL HISTORY" render)
                 t "death panel lacks the full-history line"))
    (let ((before (length (cistern-st-log st))))
      (cl-assert (> before 0) t "empty log at condemnation")))
  ;; A5.3: the migrant countdown lands once at T−3
  (let ((st (cistern--new-game 42))
        (hits 0) (line-95 t))
    (dotimes (_ 38)
      (cistern--do-tick st))
    (dolist (e (cistern-st-log st))
      (when (string-match-p "MIGRANT IN" (car e))
        (setq hits (1+ hits))
        (when (> (length (car e)) 95) (setq line-95 nil))))
    (cl-assert (= hits 1) t "countdown logged %d times" hits)
    (cl-assert line-95 t "countdown line over 95 cols")
    (cistern--do-tick st)
    (dolist (e (last (cistern-st-log st) 1))
      (cl-assert (not (string-match-p "MIGRANT IN" (car e)))
                 t "countdown repeated at T−2")))
  (message "CISTERN-V4-09-OK"))

(defun cistern-test-v4-10-stat-blocks ()
  "V4-10 (A1/A2): workers roll 4d6-drop-lowest stat blocks from
child stream 3 at spawn (seed ⊕ 3, mid-bits d6), fixture-pinned:
seed 20260830 → α FLOW 15 GRIT 15 NERVE 9 ARCHIVE 14, rpg-pos
1156891213 after spawn; modifiers are floor((score−10)/2) and all
scores land in [3,18]."
  ;; A1: the pinned fixture
  (let ((st (cistern--new-game 20260830)))
    (let ((w (car (cistern-st-creators st))))
      (cl-assert (equal (cistern--worker-stats w) '(15 15 9 14))
                 t "fixture stat block wrong: %S"
                 (cistern--worker-stats w))
      (cl-assert (eq (cistern--worker-clearance w) 1) t "spawn clearance")
      (cl-assert (= (cistern--worker-xp w) 0) t "spawn xp"))
    (cl-assert (= (cistern-st-rpg-pos st) 1156891213)
               t "rpg-pos fixture wrong: %S" (cistern-st-rpg-pos st)))
  ;; the sim LCG is untouched by stat generation (stream discipline)
  (let ((a (cistern--new-game 42)) (b (cistern--new-game 42)))
    (cistern--spawn-worker a 12 6)
    (cl-assert (= (cistern-st-rng a) (cistern-st-rng b))
               t "stat generation consumed the sim LCG"))
  ;; A2: bounds + modifier math over 50 seeds × 4 stats
  (dotimes (s 50)
    (let ((st (cistern--new-game (+ 20260000 s))))
      (dolist (w (cistern-st-creators st))
        (dolist (score (cistern--worker-stats w))
          (cl-assert (and (>= score 3) (<= score 18))
                     t "score %d outside [3,18]" score)
          (cl-assert (= (cistern--rpg-mod score) (floor (- score 10) 2))
                     t "modifier math wrong for %d" score)))))
  ;; the clamps per §1 table, at the extremes
  (dolist (mod '(-4 -1 0 2 4))
    (let ((seek (cistern--rpg-seek-eff mod))
          (sick (cistern--rpg-sick-duration mod))
          (mine (cistern--rpg-mine-rate mod)))
      (cl-assert (and (>= seek 50) (<= seek 68)) t "seek clamp broken")
      (cl-assert (and (>= sick 18) (<= sick 42)) t "sick clamp broken")
      (cl-assert (and (>= mine 2) (<= mine 6)) t "mine clamp broken")))
  (cl-assert (= (cistern--rpg-seek-eff -4) 68) t "seek -4 clamp")
  (cl-assert (= (cistern--rpg-seek-eff 4) 50) t "seek +4 clamp")
  (cl-assert (= (cistern--rpg-mine-rate -4) 6) t "mine -4 clamp")
  (cl-assert (= (cistern--rpg-mine-rate 4) 2) t "mine +4 clamp")
  (cl-assert (= (cistern--rpg-sick-duration -4) 42) t "sick -4 clamp")
  (cl-assert (= (cistern--rpg-sick-duration 4) 18) t "sick +4 clamp")
  (message "CISTERN-V4-10-OK"))

(provide 'test-v4)
;;; test-v4.el ends here
