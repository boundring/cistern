;;; domain-map-integrity.el --- R3: map integrity invariants across seeds -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-integrity-seeds '(20260830 1 2 3 4))

(defun cistern-test-map-integrity-seeds ()
  "Port of the legacy selftest map-integrity block (cistern.el:941-950),
run over all 5 procgen seeds, plus the invariants procgen must now
guarantee per-seed: border walls, a migrant gate door on the border,
ore, an intact+connected starter plumbing chain, and passable spawn
cells (spawned-on-a-wall is the classic procgen/table contact bug)."
  (dolist (seed cistern-test-integrity-seeds)
    (let ((st (cistern--new-game seed)))
      (cl-assert (= (cistern-st-w st) cistern-w) nil "seed %S: width" seed)
      (cl-assert (= (length (cistern-st-map st)) (* cistern-w cistern-h))
                 nil "seed %S: map size" seed)
      ;; border walls all around (gate door allowed)
      (cl-loop for x from 0 below cistern-w
               do (cl-assert (eq (cistern--cell st x 0) 'wall)
                             nil "seed %S: top border breached at x=%d" seed x)
                  (cl-assert (eq (cistern--cell st x (1- cistern-h)) 'wall)
                             nil "seed %S: bottom border breached at x=%d" seed x))
      (cl-loop for y from 0 below cistern-h
               do (cl-assert (memq (cistern--cell st 0 y) '(wall door))
                             nil "seed %S: west border breached at y=%d" seed y)
                  (cl-assert (eq (cistern--cell st (1- cistern-w) y) 'wall)
                             nil "seed %S: east border breached at y=%d" seed y))
      ;; >=1 migrant gate door on the border
      (cl-assert (cl-some (lambda (y) (eq (cistern--cell st 0 y) 'door))
                          (number-sequence 0 (1- cistern-h)))
                 nil "seed %S: no migrant gate door on the border" seed)
      ;; >=1 ore cell
      (cl-assert (cl-position 'ore (cistern-st-map st))
                 nil "seed %S: no ore" seed)
      ;; starter plumbing chain intact AND connected
      (cl-assert (eq (cistern--cell st 5 2) 'tank) nil "seed %S: starter tank" seed)
      (cl-assert (eq (cistern--cell st 4 2) 'pipe) nil "seed %S: starter pipe (4,2)" seed)
      (cl-assert (eq (cistern--cell st 3 2) 'pipe) nil "seed %S: starter pipe (3,2)" seed)
      (cl-assert (eq (cistern--cell st 3 3) 'toilet) nil "seed %S: starter toilet" seed)
      (cl-assert (cistern--connected-tanks st 3 3)
                 nil "seed %S: starter chain not connected" seed)
      (cl-assert (cistern--toilet-usable-p st 3 3)
                 nil "seed %S: starter toilet unusable" seed)
      ;; every worker spawn cell is passable floor-family
      (dolist (p '((12 6) (14 7) (11 9) (15 6)))
        (cl-assert (cistern--tile-passable-p (cistern--cell st (car p) (cdr p)))
                   nil "seed %S: spawn %S sits on %S"
                   seed p (cistern--cell st (car p) (cdr p)))))))

(provide 'domain-map-integrity)
;;; domain-map-integrity.el ends here