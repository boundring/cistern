;;; tests/test-r1-click.el --- R1 mouse click: input adapter + mouse map -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Repo root pinned at load time (L-008: `load-file-name' is only
;; bound during load).
(defconst cistern-test-r1--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-r1-click must be loaded from a file"))))))

;; Fixture note: `cistern-test-game--floor-run' is the single-copy
;; L-007 fixture in src/cistern-game.el (L-012 finding 3).
(add-to-list 'load-path (expand-file-name "src" cistern-test-r1--root))
(load (expand-file-name "src/cistern.el" cistern-test-r1--root))

(defun cistern-test-r1-click ()
  "R1 acceptance (spec §4): the input-adapter click at (x,y) moves
the cursor; with a verb armed it places at the cell and spends
alloy.  Plus the driver mouse-map half and the L-013 arming
migration (arming is a use-case call)."
  ;; --- unarmed adapter click: cursor moves, clock does not tick
  (let* ((st (cistern--new-game 42))
         (tick0 (cistern-st-tick st)))
    (cistern-input-click st 17 8)
    (cl-assert (equal (cistern-st-cursor st) '(17 . 8))
               t "unarmed click moves the cursor")
    (cl-assert (= (cistern-st-tick st) tick0)
               t "unarmed click does not tick"))

  ;; --- armed adapter click: place, charge, exactly one tick, verb cleared
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (x (car spot)) (y (cadr spot)))
    (setf (cistern-st-alloy st) 100)
    (cistern-input-arm-verb st 'pipe)
    (let ((tick0 (cistern-st-tick st))
          (a0 (cistern-st-alloy st)))
      (cistern-input-click st x y)
      (cl-assert (eq (cistern--cell st x y) 'pipe)
                 t "armed click places the pipe")
      (cl-assert (= (cistern-st-alloy st) (- a0 cistern-cost-pipe))
                 t "alloy reduced by the pipe cost")
      (cl-assert (= (cistern-st-tick st) (1+ tick0))
                 t "click-with-verb advances exactly one tick")
      (cl-assert (null (cistern-st-armed-verb st))
                 t "verb cleared by the placing use-case")))

  ;; --- unaffordable armed click: refused, state untouched
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (x (car spot)) (y (cadr spot)))
    (setf (cistern-st-alloy st) 0)
    (cistern-input-arm-verb st 'tank)
    (let ((tick0 (cistern-st-tick st))
          (log0 (cistern-st-log st)))
      (cistern-input-click st x y)
      (cl-assert (eq (cistern--cell st x y) 'floor) t "nothing placed")
      (cl-assert (= (cistern-st-tick st) tick0) t "refusal does not tick")
      (cl-assert (= (cistern-st-alloy st) 0) t "refusal charges nothing")
      (cl-assert (eq (cistern-st-armed-verb st) 'tank)
                 t "armed verb survives a refusal")
      (cl-assert (not (equal (cistern-st-log st) log0))
                 t "refusal is logged")))

  ;; --- arming migration (L-013): arming is a use-case call, the
  ;; adapter delegates, and the driver owns no setter
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-arm-verb st 'toilet)
    (cl-assert (eq (cistern-st-armed-verb st) 'toilet)
               t "cmd-arm-verb arms the verb"))
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern.el" cistern-test-r1--root))
    (let ((case-fold-search nil))
      (cl-assert (re-search-forward "cistern-input-click" nil t)
                 t "driver click must route through the input adapter")
      (cl-assert (not (re-search-forward "cistern--cmd-click" nil t))
                 t "driver must not bypass the adapter to the use case")
      (cl-assert (not (re-search-forward
                       "(setf[^\n]*cistern-st-armed-verb" nil t))
                 t "driver owns no arming setter (no second arming site)")))

  ;; --- mouse map: mouse-1 bound in the mode map to the driver click
  ;; command, and the pure cell geometry maps buffer coords → cells
  (cl-assert (eq (lookup-key cistern-mode-map (kbd "<mouse-1>"))
                 'cistern-click)
             t "mouse-1 must be bound to the driver click command")
  (let ((st (cistern--new-game 42)))
    (cl-assert (equal (cistern-view--cell-at st 4 0) '(0 . 0))
               t "first map line/col is cell (0,0)")
    (cl-assert (equal (cistern-view--cell-at st 4 17) '(17 . 0))
               t "column maps to x")
    (cl-assert (equal (cistern-view--cell-at st 12 5) '(5 . 8))
               t "line maps to y past the header")
    (cl-assert (null (cistern-view--cell-at st 1 0))
               t "header lines are outside the map")
    (cl-assert (null (cistern-view--cell-at st 3 0))
               t "last header line is outside the map")
    (cl-assert (null (cistern-view--cell-at
                      st (+ 4 (cistern-st-h st)) 0))
               t "past the last map row is outside the map")
    (cl-assert (null (cistern-view--cell-at st 4 (cistern-st-w st)))
               t "past the last map column is outside the map")))

(provide 'test-r1-click)
;;; tests/test-r1-click.el ends here
