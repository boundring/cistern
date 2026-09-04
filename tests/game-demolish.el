;;; tests/game-demolish.el --- R8 demolish verb, headless -*- lexical-binding: t; -*-

;; Pair 1 of plan 01 §2.1 (R8).  Places plumbing via `cistern--cmd-build',
;; removes it via the new `cistern--cmd-demolish', and asserts the legacy
;; phantom-plumbing invariant (cistern.el:976-979) extended to removal.

(require 'cl-lib)

(defun cistern-test-demolish--plumbing-nearby-p (st x y)
  "Is (X,Y) itself or any 4-neighbor of it a plumbing cell?
The test wants fixture networks closed off from the starter plumbing,
so flood-fill results depend only on cells the test built."
  (let ((bad nil))
    (dolist (n (cons (cons x y) (cistern--neighbors st x y)) bad)
      (when (memq (cistern--cell st (car n) (cdr n)) '(pipe toilet tank))
        (setq bad t)))))

(defun cistern-test-demolish--floor-run (st n)
  "Leftmost (X Y) of N consecutive unoccupied floor cells, with no
plumbing adjacent, or nil."
  (let ((occ (cistern--occupied-cells st nil)))
    (catch 'found
      (cl-loop for y from 1 below (1- (cistern-st-h st)) do
               (cl-loop for x from 1 to (- (cistern-st-w st) 1 n) do
                        (when (and (cl-loop for i from 0 below n
                                            always (and (eq (cistern--cell st
                                                             (+ x i) y)
                                                            'floor)
                                                        (not (gethash (cons (+ x i) y)
                                                                      occ))))
                                   (not (cistern-test-demolish--plumbing-nearby-p
                                         st (+ x (1- n)) y)))
                          (throw 'found (list x y))))))))

(defun cistern-test-demolish ()
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-alloy st) 100)

    ;; --- A: place a tank via cmd-build, demolish it back to floor
    (let* ((spot (cistern-test-demolish--floor-run st 1))
           (x (car spot)) (y (cadr spot)))
      (cl-assert (eq (cistern--cell st x y) 'floor))
      (cistern--cmd-build st 'tank x y)
      (cl-assert (eq (cistern--cell st x y) 'tank))
      (cl-assert (gethash (cons x y) (cistern-st-tanks st)))
      (let ((a0 (cistern-st-alloy st)))
        (cl-assert (= a0 (- 100 cistern-cost-tank)))
        (cistern--cmd-demolish st x y)
        (cl-assert (eq (cistern--cell st x y) 'floor) "cell back to floor")
        (cl-assert (not (gethash (cons x y) (cistern-st-tanks st)))
                   "tank hash entry gone")
        (cl-assert (= (cistern-st-alloy st) (- a0 cistern-cost-demolish))
                   "alloy reduced by exactly the demolish cost")))

    ;; --- B: a toilet fed through a demolished tank becomes unusable
    (let* ((run (cistern-test-demolish--floor-run st 3))
           (x (car run)) (y (cadr run)))
      (cistern--cmd-build st 'toilet x y)
      (cistern--cmd-build st 'pipe (1+ x) y)
      (cistern--cmd-build st 'tank (+ x 2) y)
      (cl-assert (cistern--toilet-usable-p st x y) "wired toilet usable")
      (let ((a0 (cistern-st-alloy st)))
        (cistern--cmd-demolish st (+ x 2) y)
        (cl-assert (eq (cistern--cell st (+ x 2) y) 'floor))
        (cl-assert (not (gethash (cons (+ x 2) y) (cistern-st-tanks st))))
        (cl-assert (= (cistern-st-alloy st) (- a0 cistern-cost-demolish)))
        (cl-assert (not (cistern--toilet-usable-p st x y))
                   "toilet fed through removed tank now unusable")
        (cl-assert (gethash (cons x y) (cistern-st-toilets st))
                   "the toilet itself remains (only the tank was removed)")))

    ;; --- C: refusals — wall, door, ore, in-use toilet (all free of charge)
    (let ((a0 (cistern-st-alloy st)))
      ;; wall
      (cistern--cmd-demolish st 0 0)
      (cl-assert (eq (cistern--cell st 0 0) 'wall) "wall refused")
      ;; door (the west migrant gate — 'gate' is the legacy name)
      (cistern--cmd-demolish st 0 7)
      (cl-assert (eq (cistern--cell st 0 7) 'door) "door refused")
      ;; ore
      (let ((ore-idx (cl-position 'ore (cistern-st-map st))))
        (cl-assert ore-idx "procgen laid ore")
        (cistern--cmd-demolish st (% ore-idx (cistern-st-w st))
                               (/ ore-idx (cistern-st-w st)))
        (cl-assert (eq (cistern--cell st (% ore-idx (cistern-st-w st))
                                        (/ ore-idx (cistern-st-w st)))
                       'ore)
                   "ore refused"))
      ;; in-use toilet (worker seated: :busy t, as the sim sets it)
      (let* ((spot (cistern-test-demolish--floor-run st 1))
             (x (car spot)) (y (cadr spot)))
        (cistern--cmd-build st 'toilet x y)
        (puthash (cons x y) (list :busy t) (cistern-st-toilets st))
        (cistern--cmd-demolish st x y)
        (cl-assert (eq (cistern--cell st x y) 'toilet)
                   "in-use toilet refused")
        (cl-assert (plist-get (gethash (cons x y) (cistern-st-toilets st))
                              :busy)
                   "in-use toilet entry untouched"))
      (cl-assert (= (cistern-st-alloy st) a0) "refusals cost nothing"))

    ;; --- D: no phantom plumbing — the legacy invariant, extended to
    ;; removal: every hash key must map to a cell still of that kind.
    (maphash (lambda (k _)
               (cl-assert (eq (cistern--cell st (car k) (cdr k)) 'toilet)
                          "dangling toilets entry"))
             (cistern-st-toilets st))
    (maphash (lambda (k _)
               (cl-assert (eq (cistern--cell st (car k) (cdr k)) 'tank)
                          "dangling tanks entry"))
             (cistern-st-tanks st))
    (dolist (w (cistern-st-creators st))
      (let ((tp (cistern--worker-toilet w)))
        (when tp
          (cl-assert (eq (cistern--cell st (car tp) (cdr tp)) 'toilet)
                     "worker reference to a demolished toilet")))))

  (message "CISTERN-DEMOLISH-OK"))

(provide 'game-demolish)
;;; tests/game-demolish.el ends here
