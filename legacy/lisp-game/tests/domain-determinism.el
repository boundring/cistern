;;; domain-determinism.el --- R3+R9: same seed, identical trajectory -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun cistern-test--map-hash (st)
  "Full-content hash of the map vector and plumbing state."
  (cl-labels ((key-less (a b)
                (let ((ka (car a)) (kb (car b)))
                  (or (< (car ka) (car kb))
                      (and (= (car ka) (car kb))
                           (< (cdr ka) (cdr kb)))))))
  (secure-hash
   'md5
   (prin1-to-string
    (list (cistern-st-map st)
          (let (ts) (maphash (lambda (k v) (push (list k v) ts))
                             (cistern-st-toilets st)) (sort ts #'key-less))
          (let (ts) (maphash (lambda (k v) (push (list k v) ts))
                             (cistern-st-tanks st)) (sort ts #'key-less)))))))

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

(defun cistern-test--add-plumbing (st order)
  "Extend ST's network with a tank-pipe-toilet chain on three
consecutive floor cells, inserting the hash entries in ORDER
\(ascending or descending index) — same logical state, different
hash-table layout."
  (let ((cells nil) (i 0))
    (while (and (< i (- (length (cistern-st-map st)) (+ 2 cistern-w)))
                (< (length cells) 1))
      (when (and (eq (aref (cistern-st-map st) i) 'floor)
                 (eq (aref (cistern-st-map st) (+ i 1)) 'floor)
                 (eq (aref (cistern-st-map st) (+ i 2)) 'floor)
                 (<= (% i cistern-w) (- cistern-w 3)))
        (push i cells))
      (cl-incf i))
    (let* ((base (car cells))
           (tank-i (+ base 0)) (pipe-i (+ base 1)) (toilet-i (+ base 2))
           (tx (% toilet-i cistern-w)) (ty (/ toilet-i cistern-w))
           (px (% pipe-i cistern-w)) (py (/ pipe-i cistern-w))
           (kx (% tank-i cistern-w)) (ky (/ tank-i cistern-w))
           (entries (list (cons (cons kx ky) (list :load 30))
                          (cons (cons px py) (list :busy nil))
                          (cons (cons tx ty) (list :busy nil)))))
      (setq entries (if (eq order 'desc) (nreverse entries) entries))
      (cistern--set-cell st kx ky 'tank)
      (cistern--set-cell st px py 'pipe)
      (cistern--set-cell st tx ty 'toilet)
      (dolist (e entries)
        (if (plist-get (cdr e) :load)
            (puthash (car e) (cdr e) (cistern-st-tanks st))
          (puthash (car e) (cdr e) (cistern-st-toilets st)))))))

(defun cistern-test-determinism-order ()
  "Order-robustness (plan 01 §1.5 suspect): two states that are
logically identical but whose plumbing hashes were built in
opposite insertion orders must produce identical trajectories —
hash iteration order must never leak into sim choices."
  (let ((s1 (cistern--new-game 7)) (s2 (cistern--new-game 7)))
    (cistern-test--add-plumbing s1 'asc)
    (cistern-test--add-plumbing s2 'desc)
    (cl-assert (equal (cistern-test--map-hash s1) (cistern-test--map-hash s2))
               nil "stress states not logically identical")
    (dotimes (_ 50) (cistern--sim-tick s1) (cistern--sim-tick s2))
    (cl-assert (equal (cistern-test--trajectory-hash s1)
                      (cistern-test--trajectory-hash s2))
               nil "hash iteration order leaked into the trajectory")))

(provide 'domain-determinism)
;;; domain-determinism.el ends here