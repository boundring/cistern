;;; tests/test-r6-timer.el --- R6 timer half: auto-run scheduling records -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Repo root pinned at load time (L-008: `load-file-name' is only
;; bound during load).
(defconst cistern-test-r6--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-r6-timer must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-r6--root))
(load (expand-file-name "src/cistern.el" cistern-test-r6--root))

(defun cistern-test-r6-timer ()
  "R6 timer half (spec §4): toggle on schedules a 0.2s idle timer,
toggle off cancels it — via scheduling RECORDS (`cl-letf' stubs;
no real timers, no wall clock, spec §5.2).  The callback advances
exactly one tick and reschedules itself; a condemned sector ends
the chain; 'r' is bound to the toggle."
  ;; --- (1) toggle on schedules one 0.2s timer; toggle off cancels it
  (setq cistern--auto-run-timer nil)
  (let (sched cancels)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (secs repeat fn &rest _)
                 (push (list secs repeat fn) sched)
                 (list 'fake-timer (length sched))))
              ((symbol-function 'cancel-timer)
               (lambda (timer) (push timer cancels))))
      (cistern-input-auto-run-toggle (cistern--new-game 42))
      (cl-assert (= (length sched) 1)
                 t "toggle-on schedules exactly one timer")
      (cl-assert (equal (car sched)
                        (list 0.2 nil 'cistern-input--auto-run-callback))
                 t "scheduled: 0.2s self-rescheduling callback link")
      (cl-assert (null cancels) t "toggle-on cancels nothing")
      (cistern-input-auto-run-toggle (cistern--new-game 42))
      (cl-assert (= (length sched) 1) t "toggle-off schedules nothing")
      (cl-assert (= (length cancels) 1)
                 t "toggle-off cancels exactly once")
      (cl-assert (equal (car cancels) (list 'fake-timer 1))
                 t "cancel receives the stored handle")
      (cl-assert (null cistern--auto-run-timer)
                 t "toggle-off clears the handle")))

  ;; --- (2) direct callback fire: exactly one tick + one reschedule
  (setq cistern--auto-run-timer nil)
  (let ((st (cistern--new-game 42)) sched)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (push 'resched sched) 'fake-next)))
      (let ((cistern--st st)
            (tick0 (cistern-st-tick st)))
        (cistern-input--auto-run-callback)
        (cl-assert (= (cistern-st-tick st) (1+ tick0))
                   t "callback advances exactly one tick")
        (cl-assert (equal sched '(resched))
                   t "callback reschedules itself, exactly once")
        (cl-assert (eq cistern--auto-run-timer 'fake-next)
                   t "handle updated to the new chain link"))))

  ;; --- N fires advance exactly N ticks (plan: fire the callback
  ;; N times directly → tick advanced by exactly N; no multi-tick path)
  (setq cistern--auto-run-timer nil)
  (let ((st (cistern--new-game 42)) (sched 0))
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (cl-incf sched) 'fake)))
      (let ((cistern--st st)
            (tick0 (cistern-st-tick st)))
        (dotimes (_ 5) (cistern-input--auto-run-callback))
        (cl-assert (= (cistern-st-tick st) (+ tick0 5))
                   t "N fires advance exactly N ticks")
        (cl-assert (= sched 5)
                   t "each fire reschedules exactly once"))))

  ;; --- (3) double toggle-on does not double-schedule
  (setq cistern--auto-run-timer nil)
  (let (sched cancels)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (push 's sched) (list 'fake (length sched))))
              ((symbol-function 'cancel-timer)
               (lambda (timer) (push timer cancels))))
      (cistern-input-auto-run-toggle (cistern--new-game 42))
      (cistern-input-auto-run-toggle (cistern--new-game 42))
      (cistern-input-auto-run-toggle (cistern--new-game 42))
      (cl-assert (= (length sched) 2)
                 t "three toggles schedule exactly twice (no stacking)")
      (cl-assert (= (length cancels) 1)
                 t "the middle toggle cancels the live link")))

  ;; --- (4) condemned sector: no tick, no reschedule, chain stops
  (setq cistern--auto-run-timer 'stale)
  (let ((st (cistern--new-game 42)) sched)
    (setf (cistern-st-over st) "SECTOR CONDEMNED")
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (push 'resched sched) 'fake)))
      (let ((cistern--st st)
            (tick0 (cistern-st-tick st)))
        (cistern-input--auto-run-callback)
        (cl-assert (= (cistern-st-tick st) tick0)
                   t "condemned sector: no tick")
        (cl-assert (null sched)
                   t "condemned sector: no reschedule")
        (cl-assert (null cistern--auto-run-timer)
                   t "condemned sector: chain stops, handle cleared"))))

  ;; --- (5) 'r' bound to the toggle command; hjkl tripwire still holds
  (cl-assert (eq (lookup-key cistern-mode-map "r")
                 'cistern-auto-run-toggle)
             t "r must be bound to the auto-run toggle")
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern.el" cistern-test-r6--root))
    (let ((case-fold-search nil))
      (cl-assert (not (re-search-forward "define-key[^\n]*\"[hjkl]\"" nil t))
                 t "hjkl tripwire still holds")))
  ;; inherited regression pin (plan 02 §1 Pair 3: no multi-tick command)
  (cl-assert (not (fboundp 'cistern-run-10))
             t "the multi-tick command stays dead"))

(provide 'test-r6-timer)
;;; tests/test-r6-timer.el ends here
