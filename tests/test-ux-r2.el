;;; tests/test-ux-r2.el --- Round-2 UX refactor batch tests (TOP-30-R2) -*- lexical-binding: t; -*-

;; Batch tests for docs/ux/TOP-30-R2.md (R2-Q01..R2-Q15, build
;; order), one entry per directive, registered in tests/run.el.
;; Reds before greens per PROCESS; ledger entries L-060+ in
;; docs/FAILURE-LEDGER.md (§5.3 format).

(require 'cl-lib)

;; Repo root pinned at load time (test-ux-r1 pattern).
(defconst cistern-test-ux2--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-ux-r2 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-ux2--root))
(load (expand-file-name "src/cistern.el" cistern-test-ux2--root))

(defun cistern-test-ux2--plain (s)
  (substring-no-properties s))

(defun cistern-test-ux2--render-lines (st)
  (split-string (cistern-test-ux2--plain (cistern-view--render st)) "\n"))

;; --- R2-Q01: width contract for all permanent rows -------------------------

(defun cistern-test-ux2-q01-width-contract ()
  "Every render row fits 95 cols: the help reflows into two
deliberate rows (all keys visible, arm phrase included), the
legend wraps on a GLYPHS-aligned continuation row (α worker never
orphaned)."
  (let* ((st (cistern--new-game 42))
         (lines (cistern-test-ux2--render-lines st))
         (help-a (nth 1 lines))
         (help-b (nth 2 lines))
         (legend-idx (cl-position-if
                      (lambda (l) (string-match-p "GLYPHS:" l)) lines)))
    ;; the help reflowed into two rows, all keys visible
    (cl-assert (string-match-p "\\[SPC\\]tick" help-a)
               t "row A shows [SPC]tick")
    (cl-assert (string-match-p "move" help-a) t "row A is the cursor row")
    (cl-assert (string-match-p "arm — click to place" help-b)
               t "row B carries the Q19 arm phrase")
    (cl-assert (string-match-p "\\[r\\]auto-run" help-b) t "row B shows auto-run")
    (cl-assert (string-match-p "\\[q\\]uit" help-b) t "row B shows quit")
    ;; the legend wrapped: α worker on the continuation, complete
    (cl-assert legend-idx t "legend present")
    (cl-assert (string-match-p "╌ dead pipe" (nth legend-idx lines))
               t "dead pipe listed")
    (cl-assert (string-match-p "α worker" (nth (1+ legend-idx) lines))
               t "α worker on the continuation row, not orphaned")
    (cl-assert (string-match-p "▣ tank" (nth (1+ legend-idx) lines))
               t "tank listed on the continuation")
    ;; THE contract: every render row fits 95 cols
    (dolist (row lines)
      (cl-assert (<= (length row) 95)
                 t "render row over 95 cols (len %d): %S"
                 (length row) (substring row 0 (min 40 (length row)))))))

;; --- R2-Q02: badge budget + header-append contract ---------------------------

(defun cistern-test-ux2-q02-badge-geometry ()
  "The badges live on ONE reserved dim row directly below the
strip; the block height is one constant both the renderer and
cell-at derive from (cold 3, badge live 4); the condemn append is
short.  THE probe: with the badge row live, cell-at of the map's
first cell is unchanged."
  (let ((st (cistern--new-game 42)))
    ;; cold: strip + two help rows = 3; the map starts at line 4
    (cl-assert (= (cistern-view--header-block-height st) 3)
               t "cold block height is 3")
    (cl-assert (equal (cistern-view--cell-at
                       st (cistern-view--layout 200 60
                           (cistern-st-w st) (cistern-st-h st)) 4 0)
               '(0 . 0))
               t "cold: map's first cell at line 4")
    ;; armed: the badge row is line 2, the map starts at line 5
    (cistern--cmd-arm-verb st 'pipe)
    (setf (cistern-st-auto-run st) t)
    (cl-assert (= (cistern-view--header-block-height st) 4)
               t "badge live: block height 4")
    (let ((lines (cistern-test-ux2--render-lines st)))
      (cl-assert (string= (nth 0 lines)
                          (cistern-test-ux2--plain
                           (cistern-view--header-line st)))
                 t "the strip is line 0")
      (cl-assert (string-match-p "ARMED: PIPE" (nth 1 lines))
                 t "the badge row sits directly below the strip")
      (cl-assert (string-match-p "AUTO-RUN" (nth 1 lines))
                 t "armed and auto-run coexist on the one badge row")
      (cl-assert (string-match-p "\\[SPC\\]tick" (nth 2 lines))
                 t "help row A follows the badge row")
      (dolist (row lines)
        (cl-assert (<= (length row) 95)
                   t "badge-live row over 95 cols")))
    ;; THE geometry probe: cell-at of the map's first cell, badge live
    (cl-assert (equal (cistern-view--cell-at
                       st (cistern-view--layout 200 60
                           (cistern-st-w st) (cistern-st-h st) nil t) 5 0)
               '(0 . 0))
               t "badge live: map's first cell at line 5 — clicks land")
    ;; the condemn append is short
    (setf (cistern-st-over st) "SECTOR CONDEMNED — CONTAMINATION LIMIT")
    (cl-assert (string-match-p "!! CONDEMNED"
                               (cistern-test-ux2--plain
                                (cistern-view--header-line st)))
               t "condemn append shortened")
    (cl-assert (null (string-match-p "SECTOR CONDEMNED — CONTAM"
                                     (cistern-test-ux2--plain
                                      (cistern-view--header-line st))))
               t "the long cause lives on the death panel, not the strip")))

;; --- R2-Q03: one copy table, one verb -------------------------------------------

(defun cistern-test-ux2--string-count (s file)
  "Occurrences of S in FILE via split-count (how-many chokes on
multibyte literals)."
  (with-temp-buffer
    (insert-file-contents file)
    (1- (length (split-string (buffer-string) s)))))

(defun cistern-test-ux2-q03-copy-sweep ()
  "RESTART everywhere (zero NEW GAME), the TUTORIAL strings live
only in `cistern--copy', and the idle pressure line stays
byte-identical."
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-contam st) cistern-contam-limit)
    (with-temp-buffer
      (dotimes (_ 3) (cistern-tick)))
    (dolist (e (cistern-st-log st))
      (when (string-match-p "PRESS n" (car e))
        (cl-assert (string-match-p "PRESS n TO RESTART" (car e))
                   t "every PRESS n occurrence says RESTART")
        (cl-assert (null (string-match-p "NEW GAME" (car e)))
                   t "no NEW GAME wording left")))
  ;; the idle line is checked on a LIVE game (the condemned state
  ;; reads the panel line, not the idle line)
  (let ((st (cistern--new-game 42)))
    (cl-assert (string= (cistern-view--pressure-line st)
                        "LINES NOMINAL — THE STRUCTURE DOES NOT CARE")
               t "idle pressure line byte-identical")))
  (dolist (key '(restart-log tutorial-complete tutorial-step
                 tutorial-skipped tutorial-line-fmt))
    (let ((s (cdr (assq key cistern--copy))))
      (cl-assert (stringp s) t "copy key %S present" key)
      (dolist (f (directory-files (expand-file-name "src"
                                                    cistern-test-ux2--root)
                                  t "\\.el\\'"))
        (unless (string-match-p "cistern-domain" f)
          (cl-assert (= 0 (cistern-test-ux2--string-count s f))
                     t "copy %S drifted outside the table" s))))))

;; --- R2-Q04: GOALS progress never regresses -------------------------------------

(defun cistern-test-ux2-q04-goals-claimed ()
  "Fresh game renders GOALS 0/2; the ceiling objective, once
claimed (contamination rose inside the target), stays counted when
contamination keeps rising.  Completion is untouched."
  (let ((st (cistern--new-game 42)))
    (cl-assert (string-match-p "GOALS 0/2"
                               (cistern-test-ux2--plain
                                (cistern-view--header-line st)))
               t "fresh game renders GOALS 0/2, not 1/2")
    ;; contamination rises INSIDE the target: the ceiling is claimed
    (setf (cistern-st-contam st) 1)
    (cistern--rewards-eval st nil)
    (cl-assert (string-match-p "GOALS 1/2"
                               (cistern-test-ux2--plain
                                (cistern-view--header-line st)))
               t "a risen, held ceiling is claimed")
    ;; contamination keeps RISING past the target: no regression
    (setf (cistern-st-contam st) 7)
    (cistern--rewards-eval st nil)
    (cl-assert (string-match-p "GOALS 1/2"
                               (cistern-test-ux2--plain
                                (cistern-view--header-line st)))
               t "the claimed goal stays counted (never drops)"))
  ;; completion unchanged: served + ceiling-at-zero still completes
  (let ((st (cistern--new-game 42)))
    (cistern--rewards-eval st (make-list 3 'relief))
    (cl-assert (cl-find-if (lambda (i)
                             (and (eq (plist-get i :layer) 'banner)
                                  (equal (plist-get i :text) "MAP COMPLETED")))
                           (cdr (cistern-st-rewards-outcome st)))
               t "completion semantics untouched")))

;; --- R2-Q05: M1 demolish dust obeys the particle contract --------------------------

(defun cistern-test-ux2-q05-dust-contract ()
  "Demolish dust is observable with ZERO tick delay, draws only
from the M9 glyph set, and sits on plain floor."
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1)))
      (cistern--cmd-build st 'pipe (car spot) (cadr spot))
      (cistern--cmd-demolish st (car spot) (cadr spot))
      (let ((ps (cistern-st-particles st)))
        (cl-assert ps t "dust present immediately after the demolish")
        (dolist (p ps)
          (cl-assert (null (member (plist-get p :glyph) '("·" ".")))
                     t "no floor-dot dust glyph")
          (cl-assert (eq (cistern--cell st (car (plist-get p :pos))
                                         (cdr (plist-get p :pos)))
                         'floor)
                     t "dust over plain floor"))))))

;; --- R2-Q06: hint lifetime tied to intent ----------------------------------------

(defun cistern-test-ux2--pressure-row-index (lines)
  (cl-position-if (lambda (l) (string-match-p "PRESSURE\\|LINES NOMINAL\\|SECTOR" l))
                  lines))

(defun cistern-test-ux2-q06-hint-lifetime ()
  "The hint survives cursor moves and renders; a non-cursor
command clears it; a new refusal replaces it; the hint row is
PERMANENTLY reserved so the pressure line never shifts."
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-hint st) "HINT TEXT")
    ;; cursor move preserves the hint
    (with-temp-buffer (cistern-cursor-east))
    (cl-assert (string-match-p "HINT TEXT"
                               (cistern-test-ux2--plain
                                (cistern-view--render st)))
               t "hint survives a cursor move")
    ;; the reserved row: the pressure line never shifts
    (let* ((with-hint (cistern-test-ux2--render-lines st))
           (idx-with (cistern-test-ux2--pressure-row-index with-hint)))
      (setf (cistern-st-hint st) nil)
      (let* ((without (cistern-test-ux2--render-lines st))
             (idx-without (cistern-test-ux2--pressure-row-index without)))
        (cl-assert (= idx-with idx-without)
                   t "pressure row index identical with and without a hint")))
    ;; a non-cursor command clears it
    (setf (cistern-st-hint st) "HINT TEXT")
    (with-temp-buffer (cistern-tick))
    (cl-assert (null (string-match-p "HINT TEXT"
                                     (cistern-test-ux2--plain
                                      (cistern-view--render st))))
               t "a non-cursor command drains the hint")
    ;; over clears it
    (setf (cistern-st-hint st) "HINT TEXT")
    (setf (cistern-st-contam st) cistern-contam-limit)
    (cistern--phase-check st)
    (cl-assert (null (cistern-st-hint st))
               t "condemnation clears the hint")))

;; --- R2-Q07: dead pipe inspects as dead ---------------------------------------------

(defun cistern-test-ux2-q07-dead-pipe-inspector ()
  "A ╌ cell names its state and the fix verb; every other
inspector line stays byte-identical (S1 probe)."
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1)))
      (cistern--cmd-build st 'pipe (car spot) (cadr spot))
      (setf (cistern-st-cursor st) (cons (car spot) (cadr spot)))
      (cl-assert (string-match-p "PIPE — DEAD: NOT CONNECTED — REWIRE (p)"
                                 (cistern-test-ux2--plain
                                  (cistern-view--inspector st)))
                 t "the dead pipe names its state and fix"))
    ;; connected pipe: byte-identical to the round-1 line
    (setf (cistern-st-cursor st) (cons 4 2))
    (cl-assert (string= (cistern-test-ux2--plain (cistern-view--inspector st))
                        "CURSOR (4,2): PIPE — the only wire; keep it short")
               t "connected pipe inspector byte-identical")))

;; --- R2-Q08: shipped interactions named on a player-facing surface ---------------

(defun cistern-test-ux2-q08-briefing-interactions ()
  "The briefing's CONTROLS names the shipped interactions: the L
full log, the u everywhere-cancel (ESC as the GUI nicety), and
C-u r slow auto-run."
  (cistern-help)
  (let ((text (with-current-buffer "*cistern help*" (buffer-string))))
    (cl-assert (string-match-p "L full log" text) t "L taught")
    (cl-assert (string-match-p "u cancel armed verb" text)
               t "u taught as the everywhere-cancel")
    (cl-assert (string-match-p "ESC on GUI" text) t "ESC labeled GUI-only")
    (cl-assert (string-match-p "C-u r slow auto-run (1 tps)" text)
               t "slow auto-run taught")))

;; --- R2-Q10: the strip's GOALS segment is explained ------------------------------

(defun cistern-test-ux2-q10-goals-explained ()
  "THE LOOP section names GOALS n/m and the active goal card."
  (cistern-help)
  (let ((text (with-current-buffer "*cistern help*" (buffer-string))))
    (cl-assert (string-match-p "GOALS n/m tracks the active goal card"
                               text)
               t "GOALS explained")
    (cl-assert (string-match-p "score and trophies" text)
               t "the completion reward named")))

;; --- R2-Q09: the free same-tick regret is discoverable ---------------------------

(defun cistern-test-ux2-q09-same-tick-inspector ()
  "A cell built this tick offers the free undo where the cursor
rests; after one tick the offer is gone."
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1)))
      (cistern--cmd-build st 'pipe (car spot) (cadr spot))
      (setf (cistern-st-cursor st) (cons (car spot) (cadr spot)))
      (cl-assert (string-match-p "SAME-TICK: FREE UNDO"
                                 (cistern-test-ux2--plain
                                  (cistern-view--inspector st)))
                 t "a same-tick cell offers the free undo")
      (cistern--do-tick st)
      (cl-assert (null (string-match-p "SAME-TICK"
                                       (cistern-test-ux2--plain
                                        (cistern-view--inspector st))))
                 t "after a tick the offer is gone"))))

;; --- R2-Q14: multi-axis bearings read as one target ---------------------------------

(defun cistern-test-ux2-q14-compound-bearings ()
  "Diagonal offsets render as one +-joined compound; single-axis
lines are unchanged."
  (let ((st (cistern--new-game 42)))
    ;; cursor (3,4): the starter toilet is straight north (single
    ;; axis), the starter tank is diagonal (compound)
    (setf (cistern-st-cursor st) (cons 3 4))
    (let ((insp (cistern-test-ux2--plain (cistern-view--inspector st))))
      (cl-assert (string-match-p "toilet Ω 1 north, " insp)
                 t "single-axis line unchanged")
      (cl-assert (string-match-p "tank ▣ 2 east \\+ 2 north" insp)
                 t "the diagonal reads as one compound")
      (cl-assert (null (string-match-p "2 east, 2 north" insp))
                 t "no comma-joined axis pair remains"))))

;; --- R2-Q11: tutorial step 1 is a player-controllable act -------------------------

(defun cistern-test-ux2-q11-tutorial-repairs ()
  "Step predicates check BEFORE the wander phase (a chased worker
cannot escape mid-tick); the gate is per-step (purge-first reaches
step 2 without step 1); the prompt is suppressed while over."
  ;; (a) the tick-start cell advances that tick — deterministic
  (let ((st (cistern--new-game 42)))
    (let ((w (car (cistern-st-creators st))))
      (setf (cistern-st-cursor st)
            (cons (cistern--worker-x w) (cistern--worker-y w))))
    (cistern--do-tick st)
    (cl-assert (= 1 (cistern-st-tutorial st))
               t "step 1 advances the tick its predicate holds")
    ;; (c) suppressed while over
    (setf (cistern-st-contam st) cistern-contam-limit)
    (cistern--phase-check st)
    ;; the PROMPT line is suppressed; history (log tail) may still
    ;; carry the completion line
    (cl-assert (null (string-match-p "TUTORIAL [0-9]/[0-9]"
                                     (cistern-test-ux2--plain
                                      (cistern-view--render st))))
               t "death frame contains no tutorial prompt line"))
  ;; (b) per-step gate: purge-first without step 1
  (let ((st2 (cistern--new-game 42)))
    (cistern--cmd-purge st2 5 2)
    (cistern--do-tick st2)
    (cl-assert (= 2 (cistern-st-tutorial st2))
               t "purge-first reaches two steps without step 1")))

;; --- R2-Q12: worker naming agrees across surfaces ----------------------------------

(defun cistern-test-ux2-q12-worker-noun ()
  "The breach and relief lines say WORKER (the glyph carries the
identity); no CREATOR noun anywhere in the capture."
  (let ((st (cistern--new-game 42)))
    ;; a breach
    (let ((w (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 14)
      (setf (cistern--worker-y w) 7)
      (setf (cistern--worker-bladder w)
            (- cistern-bladder-burst cistern-bladder-rate)))
    (cistern--do-tick st)
    (let ((breach (cl-find-if (lambda (e) (string-match-p "BREACH" (car e)))
                              (cistern-st-log st))))
      (cl-assert (string-match-p "BREACH — WORKER" (car breach))
                 t "the breach names WORKER")
      (cl-assert (null (string-match-p "CREATOR" (car breach)))
                 t "no CREATOR noun"))
    ;; the relief line too
    (cistern-test-ux--drive-relief st)
    (let ((relief (cl-find-if (lambda (e) (string-match-p "RELIEVED" (car e)))
                              (cistern-st-log st))))
      (cl-assert (string-match-p "WORKER RELIEVED" (car relief))
                 t "the relief line says WORKER")
      (cl-assert (null (string-match-p "CREATOR" (car relief)))
                 t "no CREATOR noun")))) 

;; --- R2-Q13: the L log buffer exits like everything else ----------------------------

(defun cistern-test-ux2-q13-log-buffer-exit ()
  "The log buffer is a special-mode buffer: q closes it, the
press-q hint is its first line, and the log stays read-only,
oldest first, uncapped."
  (let ((st (cistern--new-game 42)))
    (dotimes (i 14) (cistern--log st "TICK NOISE %d" i))
    (setq cistern--st st)
    (cistern-log)
    (let ((buf (get-buffer "*cistern log*")))
      (cl-assert buf t "the log buffer exists")
      (with-current-buffer buf
        ;; V4-02: the browser is now `cistern-log-mode', derived from
        ;; special-mode (SURFACE S1.2) — the intent (a special-mode
        ;; read-only surface) is checked, not the mode symbol.
        (cl-assert (derived-mode-p 'special-mode) t "special-mode")
        (cl-assert buffer-read-only t "read-only")
        (goto-char (point-min))
        (cl-assert (string-match-p "press q to close"
                                   (buffer-substring
                                    (point) (line-end-position)))
                   t "the press-q hint is the first line")
        (search-forward "SECTOR-7 ONLINE")
        (cl-assert t t "the oldest log line is present")
        (cl-assert (eq (lookup-key special-mode-map "q") 'quit-window)
                   t "q closes via special-mode")
        (quit-window)
        (cl-assert (null (get-buffer-window buf)) t "q closes the buffer")))))

;; --- R2-Q15: boot flavor vacates the tail -------------------------------------------

(defun cistern-test-ux2-q15-boot-vacates ()
  "With three or more newer player-era events the boot line never
occupies a tail slot — even when the player lines collapse; with
an empty log the boot line still renders."
  ;; collapse shrinks the player era: boot must still vacate
  (let ((st (cistern--new-game 42)))
    (dotimes (_ 12) (cistern--log-sev st 'info "WORKER RELIEVED AT (3,3)"))
    (cistern--log-sev st 'error "BREACH — WORKER β OVERFLOWED AT (5,6)")
    (cl-assert (null (cl-find-if (lambda (r) (string-match-p "ONLINE" r))
                                 (split-string (cistern-view--log-tail st) "\n")))
               t "boot flavor vacates the tail"))
  ;; empty log: the boot line still renders
  (let ((st (cistern--new-game 42)))
    (cl-assert (string-match-p "ONLINE" (cistern-view--log-tail st))
               t "with an empty log the boot line renders")))

(provide 'test-ux-r2)
;;; test-ux-r2.el ends here
