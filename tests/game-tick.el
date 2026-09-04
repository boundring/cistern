;;; tests/game-tick.el --- R6 exactly one tick per action, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-tick--root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Repo root; load-file-name is only bound during load, so pin it here.")

(defun cistern-test-tick--src-mentions (sym string)
  "Does the source of the (uncompiled) function SYM mention STRING?"
  (and (fboundp sym)
       (string-match-p string (prin1-to-string (symbol-function sym)))))

(defun cistern-test-tick--src-mentions-file (string)
  "Does any file under src/ mention STRING?  File-level static check."
  (let ((srcdir (expand-file-name "src" cistern-test-tick--root)))
    (cl-some (lambda (f)
               (with-temp-buffer
                 (insert-file-contents (expand-file-name f srcdir))
                 (goto-char (point-min))
                 (search-forward string nil t)))
             (directory-files srcdir nil "\\.el\\'"))))

(defun cistern-test-exactly-one-tick ()
  (let ((st (cistern--new-game 42)))
    ;; one call advances tick by exactly 1
    (let ((t0 (cistern-st-tick st)))
      (cistern--do-tick st)
      (cl-assert (= (cistern-st-tick st) (1+ t0))
                 "one tick command advances tick by exactly 1"))
    ;; N calls advance tick by exactly N — no run-10 drift in disguise
    (let ((t0 (cistern-st-tick st)))
      (dotimes (_ 5) (cistern--do-tick st))
      (cl-assert (= (cistern-st-tick st) (+ t0 5))
                 "five calls advance tick by exactly 5"))
    ;; over-guard: a condemned sector stops ticking
    (setf (cistern-st-over st) "SECTOR CONDEMNED — CONTAMINATION LIMIT")
    (let ((t0 (cistern-st-tick st)))
      (cistern--do-tick st)
      (cl-assert (= (cistern-st-tick st) t0) "over-guard stops the clock"))
    (setf (cistern-st-over st) nil)

    ;; static: no multi-tick command exists anywhere in src/
    (cl-assert (not (cistern-test-tick--src-mentions-file "cistern-run-10"))
               "run-10 must not be ported to src/")

    ;; static: domain tick carries no tutorial hook (game layer wraps it)
    (cl-assert (not (cistern-test-tick--src-mentions
                     'cistern--sim-tick "cistern--tutorial"))
               "domain sim-tick must not reference tutorial state")
    ;; static: game do-tick does wrap the tutorial mechanism
    (cl-assert (cistern-test-tick--src-mentions
                'cistern--do-tick "cistern--tutorial-advance")
               "game do-tick must wrap the tutorial advance hook"))

  (message "CISTERN-TICK-OK"))

(provide 'game-tick)
;;; tests/game-tick.el ends here
