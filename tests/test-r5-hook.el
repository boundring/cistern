;;; tests/test-r5-hook.el --- R5 render half: celebration overlay hook -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Repo root pinned at load time (L-008: `load-file-name' is only
;; bound during load).
(defconst cistern-test-r5--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-r5-hook must be loaded from a file"))))))

;; Fixture: `cistern-test-game--floor-run' (L-007 pattern, single copy
;; in src/cistern-game.el — L-012 finding 3).
(add-to-list 'load-path (expand-file-name "src" cistern-test-r5--root))
(load (expand-file-name "src/cistern.el" cistern-test-r5--root))

(defconst cistern-test-r5--default-outcome
  '(:score 0 :objectives nil :unlocks nil :celebrate nil)
  "Pinned Phase-2 default outcome (spec §4 R5).")

(defun cistern-test-r5-hook ()
  "R5 render half (spec §4): the view renders celebrations as a
transient, cell-never-occupying overlay; with the default outcome
the hook renders nothing (byte-identical)."
  ;; cursor parked at x=0 (the floor-run fixture never returns x=0),
  ;; so it can never collide with the particle cell below
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (px (car spot)) (py (cadr spot)))
    (setf (cistern-st-cursor st) (cons 0 0))
    (cl-assert (eq (cistern--cell st px py) 'floor) t "fixture is floor")
    (let ((intent (list :pos (cons px py) :glyph "*"
                        :face 'cistern-tank-full :layer 'sparkle))
          r0 r1 r2)
      ;; --- (b) a synthetic non-default intent paints a transient
      ;; glyph at the particle cell — ON TOP, nothing else moves.
      ;; Transport migrated (L-027): intents are STORED in state by
      ;; the per-tick evaluation; the view reads, never calls
      ;; rewards-eval.
      (setq r0 (progn
                 (setf (cistern-st-particles st)
                       (list (plist-put (copy-sequence intent) :ttl 3)))
                 (cistern-view--render st)))
      (setq r1 (cl-letf (((symbol-function 'cistern-view--celebration-overlay)
                          (lambda (_s) '(nil . ""))))
                 (cistern-view--render st)))
      (setf (cistern-st-rewards-outcome st) nil)
      (setf (cistern-st-particles st) nil)
      (setq r2 (cistern-view--render st))
      ;; transient: hook off, and the next live (default) frame,
      ;; restore the original projection byte-for-byte
      (cl-assert (equal r1 r2)
                 t "overlay is transient: default frame restores the map")
      (let ((rows0 (split-string r0 "\n"))
            (rows1 (split-string r1 "\n")))
        (let ((row0 (nth (+ 3 py) rows0))
              (row1 (nth (+ 3 py) rows1)))
          (cl-assert (string= (substring row0 0 px) (substring row1 0 px))
                     t "map row identical left of the particle")
          (cl-assert (string= (substring row0 (1+ px))
                              (substring row1 (1+ px)))
                     t "map row identical right of the particle")
          (cl-assert (string= (substring row0 px (+ px 1)) "*")
                     t "particle glyph painted on the map row")
          (cl-assert (not (string= (substring row0 px (+ px 1))
                                   (substring row1 px (+ px 1))))
                     t "overlay glyph differs from the cell glyph"))
        (dotimes (y (cistern-st-h st))
          (unless (= y py)
            (cl-assert (string= (nth (+ 3 y) rows0) (nth (+ 3 y) rows1))
                       t "non-particle map row byte-identical"))))
      ;; the overlay never occupies cells / never mutates sim state
      (cl-assert (eq (cistern--cell st px py) 'floor)
                 t "sim cell untouched by the overlay")
      (cl-assert (null (cistern-st-armed-verb st)) t "state untouched")
      ;; out-of-bounds particles are clipped from output
      (let ((r3 (progn
                  (setf (cistern-st-rewards-outcome st)
                        (cons cistern-test-r5--default-outcome
                              (list (list :pos (cons 999 999)
                                          :glyph "*"
                                          :face 'cistern-tank-full
                                          :layer 'sparkle))))
                  (cistern-view--render st))))
        (cl-assert (equal r3 r1) t "out-of-bounds particle clipped"))

      ;; --- (c) D5 precedence: cursor > worker > particle > cell — a
      ;; particle under the cursor does not paint
      (setf (cistern-st-cursor st) (cons px py))
      (let* ((rc (progn
                   (setf (cistern-st-particles st)
                         (list (plist-put (copy-sequence intent) :ttl 3)))
                   (cistern-view--render st)))
             (row (nth (+ 3 py) (split-string rc "\n")))
             (face (get-text-property px 'face row)))
        (cl-assert (and (listp face) (memq 'cistern-cursor face))
                   t "cursor wins over the particle")
        (cl-assert (not (string= (substring row px (+ px 1)) "*"))
                   t "particle glyph not painted under the cursor"))

      ;; --- (a) default outcome: the hook is a no-op by construction —
      ;; byte-identical to the short-circuited render
      (setf (cistern-st-rewards-outcome st) nil)
      (setf (cistern-st-particles st) nil)
      (let ((a (cistern-view--render st))
            (b (cl-letf (((symbol-function 'cistern-view--celebration-overlay)
                          (lambda (_s) '(nil . ""))))
                 (cistern-view--render st))))
        (cl-assert (equal a b)
                   t "default outcome: hook renders nothing (byte-identical)"))

      ;; --- (d) banner: reserved post-map row, before the inspector,
      ;; never the header/status lines
      (setf (cistern-st-rewards-outcome st)
            (cons '(:score 0 :objectives nil :unlocks nil :celebrate :map-complete)
                  (list (list :layer 'banner :text "SECTOR CLEARED"))))
      (let* ((h (cistern-st-h st))
             (rb (cistern-view--render st))
             (rows (split-string rb "\n"))
             (_ (setf (cistern-st-rewards-outcome st) nil))
             (rd (cistern-view--render st))
             (rowsd (split-string rd "\n")))
        (cl-assert (string-match-p "SECTOR CLEARED" (nth (+ 3 h) rows))
                   t "banner renders in the reserved post-map row")
        (cl-assert (string-prefix-p "CURSOR (" (nth (+ 4 h) rows))
                   t "banner row sits between map and inspector")
        (cl-assert (string= "" (nth (+ 3 h) rowsd))
                   t "default banner row is empty (reserved)")
        (dotimes (i 3)
          (cl-assert (string= (nth i rows) (nth i rowsd))
                     t "header/status lines never carry the banner"))))

    ;; --- (e) projection-only backstop extension (L-016 change item):
    ;; no direct hash-layout access in the view — the domain query
    ;; functions are the sanctioned path
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "src/cistern-view.el" cistern-test-r5--root))
      (let ((case-fold-search nil))
        (cl-assert (not (re-search-forward
                         "gethash\\|maphash\\|cistern-st-toilets\\|cistern-st-tanks"
                         nil t))
                   t "view must not touch hash layouts directly")))

    ;; geometry regression: header-lines unchanged (R1 pins cell-at)
    (let ((st (cistern--new-game 42)))
      (cl-assert (equal (cistern-view--cell-at
                         st (cistern-view--layout 200 60
                             (cistern-st-w st) (cistern-st-h st)) 4 0)
                 '(0 . 0))
                 t "cell-at geometry unchanged by the banner row")))
)

(provide (quote test-r5-hook))
;;; tests/test-r5-hook.el ends here
