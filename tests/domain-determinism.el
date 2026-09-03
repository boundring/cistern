;;; domain-determinism.el --- R3+R9: same seed, identical trajectory -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun cistern-test--map-hash (st)
  "Full-content hash of the map vector and plumbing state."
  (secure-hash
   'md5
   (prin1-to-string
    (list (cistern-st-map st)
          (let (ts) (maphash (lambda (k v) (push (list k v) ts))
                             (cistern-st-toilets st)) (sort ts #'equal<))
          (let (ts) (maphash (lambda (k v) (push (list k v) ts))
                             (cistern-st-tanks st)) (sort ts #'equal<))))))

(defun cistern-test--trajectory-hash (st)
  "Hash of the observable state after N ticks."
  (secure-hash
   'md5
   (prin1-to-string
    (list (cistern-st-alloy st) (cistern-st-contam st) (cistern-st-rng st)
          (cistern-st-map st)
          (mapcar (lambda (w)
                    (list (cistern--worker-x w) (cistern--worker-y w)
                          (cistern--worker-bladder w)
                          (cistern--worker-sick w)
                          (cistern--worker-using w)))
                  (cistern-st-creators st))))))

(defun cistern-test-determinism ()
  "Same seed twice ⇒ identical map hash AND identical 50-tick
trajectory (legacy pattern cistern.el:1028-1033, extended to the
full observable state)."
  (let ((s1 (cistern--new-game 7)) (s2 (cistern--new-game 7)))
    (cl-assert (equal (cistern-test--map-hash s1) (cistern-test--map-hash s2))
               nil "same seed produced different maps")
    (dotimes (_ 50) (cistern--sim-tick s1) (cistern--sim-tick s2))
    (cl-assert (= (cistern-st-alloy s1) (cistern-st-alloy s2))
               nil "alloy diverged after 50 ticks")
    (cl-assert (= (cistern-st-contam s1) (cistern-st-contam s2))
               nil "contam diverged after 50 ticks")
    (cl-assert (equal (cistern-st-rng s1) (cistern-st-rng s2))
               nil "rng state diverged after 50 ticks")
    (cl-assert (equal (cistern-test--trajectory-hash s1)
                      (cistern-test--trajectory-hash s2))
               nil "full trajectory diverged after 50 ticks")))

(provide 'domain-determinism)
;;; domain-determinism.el ends here