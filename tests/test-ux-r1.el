;;; tests/test-ux-r1.el --- Round-1 UX refactor batch tests (TOP-30) -*- lexical-binding: t; -*-

;; Batch tests for docs/ux/TOP-30.md (Q01..Q30, build order), one
;; entry per directive, registered in tests/run.el.  Reds before
;; greens per PROCESS; ledger entries L-035+ in
;; docs/FAILURE-LEDGER.md (§5.3 format).

(require 'cl-lib)

;; Repo root pinned at load time (test-r5-hook pattern).
(defconst cistern-test-ux--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-ux-r1 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-ux--root))
(load (expand-file-name "src/cistern.el" cistern-test-ux--root))

;; --- fixtures -------------------------------------------------------------

(defun cistern-test-ux--plain (s)
  "S with text properties stripped (assert on plain strings)."
  (substring-no-properties s))

(defun cistern-test-ux--render-lines (st)
  (split-string (cistern-test-ux--plain (cistern-view--render st)) "\n"))

(defun cistern-test-ux--header (st)
  (nth 0 (cistern-test-ux--render-lines st)))

(defun cistern-test-ux--drive-relief (st)
  "Seat creator 0 on the starter toilet (3,3) from a guaranteed
free floor neighbor and drive one full relief through `cistern--do-tick'.
Returns the seat spot (X . Y)."
  (let* ((w (car (cistern-st-creators st)))
        (spot (cl-loop for n in (cistern--neighbors st 3 3)
                       when (and (eq (cistern--cell st (car n) (cdr n)) 'floor)
                                 (not (gethash n (cistern--occupied-cells st w))))
                       return n)))
    (cl-assert spot t "a free floor neighbor of the starter toilet exists")
    (setf (cistern--worker-x w) (car spot))
    (setf (cistern--worker-y w) (cdr spot))
    (setf (cistern--worker-sick w) 0)
    (setf (cistern--worker-bladder w) cistern-bladder-seek)
    (cistern--do-tick st)
    (cl-assert (cistern--worker-using w) t "worker seated on the starter toilet")
    (dotimes (_ cistern-use-ticks)
      (cistern--do-tick st))
    (cl-assert (not (cistern--worker-using w)) t "use completed")
    spot))

;; --- Q01: header strip contract --------------------------------------------

(defun cistern-test-ux-q01-header-strip ()
  "Strip: fixed segment order TICK ALLOY POP CONTAM SCORE GOALS
REP; no SEED; nothing truncated at width 95; a dim badge slot is
reserved (Q19 armed, Q29 auto-run); SEED lives in the ? briefing."
  (let* ((st (cistern--new-game 42))
         (header (cistern-test-ux--header st)))
    (dolist (seg '("TICK " "ALLOY " "POP " "CONTAM " "SCORE " "GOALS " "REP "))
      (cl-assert (string-match-p (regexp-quote seg) header)
                 t "strip segment %s missing" seg))
    (cl-assert (< (string-match-p "SCORE" header)
                  (string-match-p "GOALS" header)
                  (string-match-p "REP" header))
               t "strip order ... SCORE GOALS REP broken")
    (cl-assert (null (string-match-p "SEED" header))
               t "SEED left the strip — it lives in the ? briefing now")
    (cl-assert (<= (length header) 95)
               t "strip truncated at width 95 (len %d)" (length header))
    (cl-assert (equal (cistern-view--header-badges st) "")
               t "badge slot reserved and empty")
    (cistern-help)
    (let ((text (with-current-buffer "*cistern help*" (buffer-string))))
      (cl-assert (string-match-p "seed" text)
                 t "briefing carries the seed"))))

;; --- Q02: score/reputation rendered ----------------------------------------

(defun cistern-test-ux-q02-score-rep ()
  "After one driven relief the next render's SCORE is greater
than before; REP matches state.  No game-layer change."
  (let ((st (cistern--new-game 42)))
    (cl-assert (string-match-p "SCORE 0" (cistern-test-ux--header st))
               t "cold strip shows SCORE 0")
    (cistern-test-ux--drive-relief st)
    (cl-assert (> (or (cistern-st-score st) 0) 0)
               t "the driven relief paid score")
    (let ((header (cistern-test-ux--header st)))
      (cl-assert (string-match-p
                  (regexp-quote (format "SCORE %d" (cistern-st-score st))) header)
                 t "strip SCORE reads state")
      (cl-assert (string-match-p
                  (regexp-quote (format "REP %d" (cistern-st-reputation st))) header)
                 t "strip REP reads state"))))

(provide 'test-ux-r1)
;;; test-ux-r1.el ends here
