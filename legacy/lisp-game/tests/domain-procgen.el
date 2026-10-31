;;; domain-procgen.el --- R3(a): procgen variety across seeds -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-procgen-seeds '(20260830 1 2 3 4))

(defun cistern-test--layout-signature (st)
  "Hash of wall/ore/plumbing positions — the layout signature.
Legacy map-hash pattern, cf. cistern.el:1028-1033."
  (let (cells)
    (cl-loop for i below (length (cistern-st-map st))
             for c = (aref (cistern-st-map st) i)
             when (memq c '(wall ore pipe toilet tank))
             do (push (list c (% i (cistern-st-w st))
                            (/ i (cistern-st-w st)))
                      cells))
    ;; ponytail note: sxhash is depth-limited for lists and collides on
    ;; long same-prefix lists; hash the printed structure instead.
    (secure-hash 'md5 (prin1-to-string (nreverse cells)))))

(defun cistern-test-procgen-variety ()
  "R3(a): >=5 seeds yield >=3 distinct layout signatures, and the
starter plumbing (tank-pipe-pipe-toilet chain) is present in every
generated map."
  (let ((states (mapcar #'cistern--new-game cistern-test-procgen-seeds)))
    ;; starter plumbing present in every map
    (dolist (st states)
      (cl-assert (eq (cistern--cell st 5 2) 'tank) nil "starter tank missing")
      (cl-assert (eq (cistern--cell st 4 2) 'pipe) nil "starter pipe (4,2) missing")
      (cl-assert (eq (cistern--cell st 3 2) 'pipe) nil "starter pipe (3,2) missing")
      (cl-assert (eq (cistern--cell st 3 3) 'toilet) nil "starter toilet missing")
      (cl-assert (gethash (cons 5 2) (cistern-st-tanks st)) nil "tank hash entry missing")
      (cl-assert (gethash (cons 3 3) (cistern-st-toilets st)) nil "toilet hash entry missing"))
    ;; >=3 distinct signatures across the 5 seeds
    (let* ((sigs (mapcar #'cistern-test--layout-signature states))
           (distinct (delete-dups (copy-sequence sigs))))
      (cl-assert (>= (length distinct) 3)
                 nil "only %d distinct layout signatures across %d seeds"
                 (length distinct) (length sigs)))))

(provide 'domain-procgen)
;;; domain-procgen.el ends here
