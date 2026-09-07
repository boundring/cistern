;;; tests/test-r7-glyphs.el --- R7: connection glyphs + render projection -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Repo root pinned at load time (L-008: `load-file-name' is only
;; bound during load).
(defconst cistern-test-r7--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-r7-glyphs must be loaded from a file"))))))

;; Fixture: `cistern-test-game--floor-run' (L-007 pattern, single copy
;; in src/cistern-game.el — L-012 finding 3).
(add-to-list 'load-path (expand-file-name "src" cistern-test-r7--root))
(load (expand-file-name "src/cistern.el" cistern-test-r7--root))

(defun cistern-test-r7-glyph ()
  "R7 acceptance (spec §4): the connected pipe renders with the
connected glyph/face while an isolated pipe renders with the
isolated one; toilet connection state is visible in glyph/face;
the render is a pure, propertized projection of state."
  ;; --- (a) connected vs isolated pipe: glyph AND face both differ
  (let* ((st (cistern--new-game 42))
         (run (cistern-test-game--floor-run st 3))
         (x0 (car run)) (y0 (cadr run)))
    (setf (cistern-st-alloy st) 100)
    ;; chain: pipe → toilet → tank, adjacent along the floor run
    (cistern--cmd-build st 'pipe x0 y0)
    (cistern--cmd-build st 'toilet (+ x0 1) y0)
    (cistern--cmd-build st 'tank (+ x0 2) y0)
    ;; an isolated pipe far from the chain
    (let* ((iso (cistern-test-game--floor-run st 1))
           (ix (car iso)) (iy (cadr iso)))
      (cistern--cmd-build st 'pipe ix iy)
      (let ((conn (cistern-view--cell-glyph st x0 y0))
            (dead (cistern-view--cell-glyph st ix iy)))
        (cl-assert (member (car conn)
                           '("┼" "│" "─" "└" "┘" "┌" "┐"))
                   t "connected pipe renders a plumbing shape")
        (cl-assert (eq (cdr conn) 'cistern-pipe-live)
                   t "connected pipe face is the live face")
        ;; Q12: the isolated pipe renders the table's distinct DEAD
        ;; glyph — no longer the base/floor dot
        (cl-assert (string= (car dead) (cistern--tile-dead-glyph 'pipe))
                   t "isolated pipe renders the table's dead glyph")
        (cl-assert (eq (cdr dead) 'cistern-pipe-dead)
                   t "isolated pipe face is the dead face")
        (cl-assert (not (string= (car conn) (car dead)))
                   t "connected vs isolated glyphs differ")
        (cl-assert (not (eq (cdr conn) (cdr dead)))
                   t "connected vs isolated faces differ")))

    ;; --- (c) toilet connection state visible in face (usable/busy/down)
    (cl-assert (eq (cdr (cistern-view--cell-glyph st (+ x0 1) y0))
                   'cistern-toilet)
               t "wired-and-serviced toilet face")
    (puthash (cons (+ x0 1) y0) (list :busy t) (cistern-st-toilets st))
    (cl-assert (eq (cdr (cistern-view--cell-glyph st (+ x0 1) y0))
                   'cistern-toilet-busy)
               t "in-use toilet face")
    (let* ((iso (cistern-test-game--floor-run st 1))
           (ix (car iso)) (iy (cadr iso)))
      (cistern--cmd-build st 'toilet ix iy)
      (cl-assert (eq (cdr (cistern-view--cell-glyph st ix iy))
                     'cistern-toilet-down)
                 t "severed toilet face"))

    ;; tank load faces
    (cl-assert (eq (cdr (cistern-view--cell-glyph st (+ x0 2) y0))
                   'cistern-tank-ok)
               t "empty tank face")
    (puthash (cons (+ x0 2) y0) (list :load 40) (cistern-st-tanks st))
    (cl-assert (eq (cdr (cistern-view--cell-glyph st (+ x0 2) y0))
                   'cistern-tank-high)
               t "mid-load tank face")
    (puthash (cons (+ x0 2) y0) (list :load 55) (cistern-st-tanks st))
    (cl-assert (eq (cdr (cistern-view--cell-glyph st (+ x0 2) y0))
                   'cistern-tank-full)
               t "near-capacity tank face"))

  ;; --- L-012 finding #1: worker identity glyphs live in the view;
  ;; the domain log carries the worker index, not a glyph
  (cl-assert (not (boundp 'cistern--worker-glyphs))
             t "domain no longer owns the glyph table")
  (cl-assert (not (fboundp 'cistern--worker-glyph))
             t "domain glyph lookup removed")
  (cl-assert (fboundp 'cistern-view--worker-glyph)
             t "view owns worker identity rendering")
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern-domain.el" cistern-test-r7--root))
    (cl-assert (not (string-match-p "worker-glyph" (buffer-string)))
               t "domain source carries no worker-glyph references"))
  (let* ((st (cistern--new-game 42))
         (w (car (cistern-st-creators st))))
    (cistern--accident st w)
    (let ((line (caar (cistern-st-log st))))
      (cl-assert (string-match-p "CREATOR #0 OVERFLOWED" line)
                 t "domain log carries the worker index")
      (cl-assert (not (string-match-p "α" line))
                 t "domain log carries no glyph")))
  ;; the view renders identity from the stable per-worker position
  (let* ((st (cistern--new-game 42))
         (w (car (cistern-st-creators st)))
         (wx (cistern--worker-x w))
         (wy (cistern--worker-y w))
         (rows (split-string (cistern-view--render st) "\n"))
         (row (nth (+ 3 wy) rows)))
    (cl-assert (string= (substring row wx (+ wx 1)) "α")
               t "worker glyph rendered at its position"))

  ;; --- (b) static: no cell-kind pcase/case in the view; no tile-table
  ;; glyph hardcoded in view source (probe rules: case-fold nil)
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern-view.el" cistern-test-r7--root))
    (let ((src (buffer-string)))
      (cl-assert (not (string-match-p "(pcase\\|(cl-case\\|(case" src))
                 t "view contains no cell-kind pcase/case")
      (dolist (entry cistern--tile-table)
        (cl-assert (not (string-match-p
                         ;; quoted string-literal form: a bare glyph in
                         ;; code (e.g. the `1+' function) must not trip
                         ;; the probe (L-013 probe-precision rule)
                         (regexp-quote (concat "\""
                                               (cistern--tile-glyph
                                                (car entry))
                                               "\""))
                         src))
                   t "tile glyph hardcoded in view: %s" (car entry)))))

  ;; --- (d) render purity: propertized string, no buffers, twice-equal,
  ;; and the geometry constant stays truthful (L-014)
  (let* ((st (cistern--new-game 42))
         (bufs0 (buffer-list))
         (a (cistern-view--render st))
         (b (cistern-view--render st)))
    (cl-assert (stringp a) t "render returns a string")
    (cl-assert (equal a b) t "render is a pure function of state")
    (cl-assert (get-text-property 0 'face a)
               t "render output is propertized")
    (cl-assert (equal bufs0 (buffer-list))
               t "render creates no buffers")
    (let ((rows (split-string a "\n")))
      (cl-assert (string-prefix-p (car (cistern-view--cell-glyph st 0 0))
                                  (nth 3 rows))
                 t "map row 0 begins at line 4 — header-lines truthful")
      ;; cursor overlay (D5: cursor > worker > particle > cell)
      (setf (cistern-st-cursor st) (cons 0 0))
      (let* ((r2 (cistern-view--render st))
             (row (nth 3 (split-string r2 "\n")))
             (face (get-text-property 0 'face row)))
        (cl-assert (and (listp face) (memq 'cistern-cursor face))
                   t "cursor cell carries the cursor face"))))

  ;; --- refresh wiring: the auto-run callback fires the driver's
  ;; registered refresh (L-015 change item b)
  (let ((st (cistern--new-game 42)) (fires 0) (sched 0))
    (cl-letf (((symbol-function 'cistern--refresh)
               (lambda (&rest _) (cl-incf fires)))
              ((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (cl-incf sched) 'fake))
              (cistern-input--refresh #'cistern--refresh))
      (let ((cistern--st st)
            (tick0 (cistern-st-tick st)))
        (cistern-input--auto-run-callback)
        (cl-assert (= (cistern-st-tick st) (1+ tick0))
                   t "callback still advances exactly one tick")
        (cl-assert (= fires 1) t "callback refreshes once per fire")
        (cl-assert (= sched 1) t "callback still reschedules")))))

(provide 'test-r7-glyphs)
;;; tests/test-r7-glyphs.el ends here
