;;; tests/test-v4.el --- CISTERN v4 wave-1 surface foundations -*- lexical-binding: t; -*-

;; Batch tests for docs/v4/V4-SPEC.md WAVE 1 (V4-01..V4-09, build
;; order), one entry per directive acceptance, registered in
;; tests/run.el.  Reds before greens per PROCESS; ledger entries in
;; docs/FAILURE-LEDGER.md (§5.3 format, continuing past L-076).

(require 'cl-lib)

;; Repo root pinned at load time (L-008 pattern).
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

(provide 'test-v4)
;;; test-v4.el ends here
