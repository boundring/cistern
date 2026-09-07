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

;; --- V4-02: the L buffer becomes an event browser (S1.2/S1.3) -----------------

(defun cistern-test-v4-02-log-browser ()
  "V4-02 (A1.1–A1.6, batch): the browser carries tick prefixes
and persistent severity faces, RET jumps land the game cursor on
the line's (x,y) and refuse coordinate-free lines with the
log-jump-none hint, point survives the RET→L round trip, the
keymap matches the S1.3 table exactly (n/p walk, native motion
NOT rebound), and no line exceeds 95 cols at tick 99999."
  ;; A1.1: the oldest entry with its tick prefix after 13+ events
  (let ((st (cistern--new-game 42)))
    (dotimes (i 13) (cistern--log st "TICK NOISE %d" i))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (forward-line 1)
      (cl-assert (looking-at-p "T0 +SECTOR-7 ONLINE")
                 t "the oldest entry renders with its tick prefix")))
  ;; A1.2: the breach line renders the error face on every re-open
  (let ((st (cistern--new-game 42)))
    (cistern--log-sev st 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log) (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "BREACH")
      (cl-assert (eq (get-text-property (point) 'face)
                     'cistern-toilet-down)
                 t "the breach line keeps its error face on re-open")))
  ;; A1.3: RET jumps land the cursor; coordinate-free lines refuse
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-cursor st) (cons 3 6))
    (cistern--log-sev st 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
    (cistern--log st "NO COORDINATES HERE")
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "BREACH")
      (cistern-log-jump-to-source))
    (cl-assert (equal (cistern-st-cursor st) '(5 . 6))
               t "RET lands the game cursor on the line's (x,y)")
    (cl-assert (eq (current-buffer) (get-buffer "*cistern*"))
               t "RET pops back to the game buffer")
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (search-forward "NO COORDINATES")
      (cistern-log-jump-to-source))
    (cl-assert (equal (cistern-st-cursor st) '(5 . 6))
               t "a coordinate-free line changes no cursor")
    (cl-assert (equal (cistern-st-hint st)
                      (cdr (assq 'log-jump-none cistern--copy)))
               t "a coordinate-free line posts the log-jump-none hint"))
  ;; A1.4: point survives the RET → L round trip (no new events)
  (let ((st (cistern--new-game 42)))
    (dotimes (i 5) (cistern--log st "EVENT %d" i))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min)) (forward-line 3)
      (let ((pt (point)))
        (cistern-log)
        (cl-assert (= (point) pt) t "point survives the L round trip"))))
  ;; A1.5: the S1.3 keymap table, exactly — no shadowing
  (cl-assert (boundp 'cistern-log-mode-map) t "the browser keymap exists")
  (let ((m cistern-log-mode-map))
    (cl-assert (eq (lookup-key m "n") 'next-line) t "n walks next")
    (cl-assert (eq (lookup-key m "p") 'previous-line) t "p walks prev")
    (cl-assert (not (eq (lookup-key m "n") 'cistern-new-game))
               t "n does not run the game verb")
    (cl-assert (not (eq (lookup-key m "p") 'cistern-build-pipe))
               t "p does not run the game verb")
    (cl-assert (eq (lookup-key m "/") 'isearch-forward) t "/ isearches")
    (cl-assert (and (commandp (lookup-key m "g"))
                    (not (eq (lookup-key m "g") 'revert-buffer)))
               t "g rebuilds from state")
    (cl-assert (eq (lookup-key m "G") 'end-of-buffer) t "G ends")
    (cl-assert (eq (lookup-key m (kbd "RET"))
                   'cistern-log-jump-to-source) t "RET jumps")
    (dolist (key '("C-n" "C-p" "C-f" "C-b" "C-s" "C-r" "M-<" "M->" "SPC" "DEL"))
      (cl-assert (null (lookup-key m (kbd key)))
                 t "native %s is documented, not rebound" key))
    (cl-assert (eq (lookup-key m "q") 'quit-window) t "q closes")))

(defun cistern-test-v4-02-log-width ()
  "V4-02 (A1.6): browser lines stay within 95 cols at the max
format width (breach line at tick 99999)."
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-log st)
          (list (list "BREACH — WORKER α OVERFLOWED AT (33,15)" 'error 99999)))
    (setq cistern--st st)
    (when (get-buffer "*cistern log*") (kill-buffer "*cistern log*"))
    (cistern-log)
    (with-current-buffer "*cistern log*"
      (goto-char (point-min))
      (while (not (eobp))
        (cl-assert (<= (- (line-end-position) (line-beginning-position)) 95)
                   t "browser line over 95 cols")
        (forward-line 1))))
  (message "CISTERN-V4-02-OK"))

(provide 'test-v4)
;;; test-v4.el ends here
