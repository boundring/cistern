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
    ;; R2-Q02: idle = no badge row at all (nil, not an empty row)
    (cl-assert (null (cistern-view--header-badges st))
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

;; --- Q03: goal card dealt from tick one -------------------------------------

(defun cistern-test-ux-q03-starter-card ()
  "Every new game holds a non-nil starter goal card (serve 3,
ceiling 5) issued through `cistern--cmd-set-goal-card', and a
driven run reaches MAP COMPLETED with no test injection."
  (let ((st (cistern--new-game 42)))
    (let ((card (cistern-st-goal-card st)))
      (cl-assert card t "starter goal card dealt at tick one")
      (cl-assert (= (plist-get card :map-id) 42)
                 t "starter card stamped with the map seed")
      (cl-assert (= (length (plist-get card :goals)) 2)
                 t "starter card: serve 3 + ceiling 5"))
    (dotimes (_ 3) (cistern-test-ux--drive-relief st))
    (cl-assert (cl-find-if (lambda (i)
                             (and (eq (plist-get i :layer) 'banner)
                                  (equal (plist-get i :text) "MAP COMPLETED")))
                           (cdr (cistern-st-rewards-outcome st)))
               t "driven run reaches MAP COMPLETED without injection")))

;; --- Q04: goal progress rendered ---------------------------------------------

(defun cistern-test-ux-q04-goal-progress ()
  "The strip's GOALS n/m reads the active card's objectives; the
first objective met shows in the same tick's render."
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 1))))
    (cl-assert (string-match-p "GOALS 0/1" (cistern-test-ux--header st))
               t "strip reads the card's unmet objective")
    (cistern-test-ux--drive-relief st)
    (cl-assert (string-match-p "GOALS 1/1" (cistern-test-ux--header st))
               t "first objective met shows in the same tick's strip")))

;; --- Q05: milestone unlocks announce ------------------------------------------

(defun cistern-test-ux-q05-milestone-announce ()
  "Crossing 5 relieves announces: the milestone line rides both
the log tail (faced) and the banner row of the same frame — the
ANTAG-12 silence is gone."
  (let ((st (cistern--new-game 42)))
    (cistern--rewards-eval st (make-list 5 'relief))
    (let* ((tail (cistern-view--log-tail st))
           (banner (cdr (cistern-view--celebration-overlay st)))
           (rows (split-string tail "\n"))
           (hit (cl-find-if (lambda (r) (string-match-p "MILESTONE" r)) rows)))
      (cl-assert (string-match-p "MILESTONE — BIG CISTERN ONLINE"
                                 (cistern-test-ux--plain tail))
                 t "milestone line in the log tail")
      (cl-assert hit t "milestone row present in the tail")
      (cl-assert (eq (get-text-property 0 'face hit) 'cistern-toilet)
                 t "milestone rides the success face")
      (cl-assert (string-match-p "MILESTONE — BIG CISTERN ONLINE"
                                 (cistern-test-ux--plain banner))
                 t "milestone on the banner row"))))

;; --- Q06: PROTECT popup channel -----------------------------------------------

(defun cistern-test-ux-q06-popup-protect ()
  "The relief popup stays the act-time channel: `+N` spawns at the
toilet cell at the tick of relief (SCREEN-13), cursor still wins
the cell (z-order cursor > worker > popup > cell)."
  (let ((st (cistern--new-game 42)))
    (cistern--rewards-eval st (list (list 'relief 70 12 6)))
    (let* ((overlay (car (cistern-view--celebration-overlay st)))
           (hit (assoc (cons 12 6) overlay)))
      (cl-assert hit t "popup present at the relief cell, tick of relief")
      (cl-assert (string-match-p "\\`\\+[0-9]+\\'" (car (cdr hit)))
                 t "popup glyph is +N over the pay")
      ;; z-order unchanged: the cursor at the same cell occludes the popup
      (setf (cistern-st-cursor st) (cons 12 6))
      (let* ((row (nth (+ cistern-view--header-lines 6)
                       (cistern-test-ux--render-lines st)))
             (glyph (substring-no-properties row 12 (1+ 12))))
        (cl-assert (not (string-match-p "\\`\\+" glyph))
                   t "cursor occludes the popup at D5 precedence")))))

;; --- Q07: PROTECT purge economy guard ------------------------------------------

(defun cistern-test-ux-q07-purge-economy ()
  "Purge at a known tank load changes alloy by exactly the
advertised 1-per-3; the inspector line's rate stays verbatim."
  (let ((st (cistern--new-game 42)))
    (puthash (cons 5 2) (list :load 45) (cistern-st-tanks st))
    (let ((a0 (cistern-st-alloy st)))
      (cistern--cmd-purge st 5 2)
      (cl-assert (= (cistern-st-alloy st) (+ a0 15))
                 t "45 load pays exactly 15 alloy (1 per 3)"))
    (setf (cistern-st-cursor st) (cons 5 2))
    (cl-assert (string-match-p "pays 1 alloy per 3"
                               (cistern-test-ux--plain
                                (cistern-view--render st)))
               t "inspector purge rate verbatim")))

;; --- Q08: pressure gradient anticipates ---------------------------------------

(defun cistern-test-ux-q08-pressure-gradient ()
  "The middle tier is proportional (>= 0.85 x sum-of-tank-cap)
and shows the fill %; the raw-total branch is gone; at cap it is
CRITICAL."
  (let ((st (cistern--new-game 42)))
    ;; 0.9 x cap on the one starter tank: RISING with the fill %,
    ;; and the failure tier has NOT fired (pre-failure state)
    (puthash (cons 5 2) (list :load 54) (cistern-st-tanks st))
    (let ((line (cistern-view--pressure-line st)))
      (cl-assert (string-match-p "PRESSURE RISING — TANK 90%" line)
                 t "RISING at 0.9 cap with the fill %%")
      (cl-assert (null (string-match-p "CRITICAL" line))
                 t "0.9 cap is not critical")
      (cl-assert (null (cistern-st-over st)) t "state is pre-failure"))
    ;; the raw-total branch is deleted: 51+50=101 over two tanks
    ;; (each below 85%) must NOT read RISING
    (puthash (cons 5 2) (list :load 51) (cistern-st-tanks st))
    (puthash (cons 8 5) (list :load 50) (cistern-st-tanks st))
    (cl-assert (string-match-p "NOMINAL" (cistern-view--pressure-line st))
               t "raw-total branch deleted (101 no longer rises)")
    ;; at cap: CRITICAL
    (puthash (cons 5 2) (list :load 60) (cistern-st-tanks st))
    (puthash (cons 8 5) (list :load 0) (cistern-st-tanks st))
    (cl-assert (string-match-p "CRITICAL" (cistern-view--pressure-line st))
               t "at cap is critical")))

;; --- Q11: PROTECT voice register / one copy table ------------------------------

(defconst cistern-test-ux--src-dir
  (expand-file-name "src" cistern-test-ux--root))

(defun cistern-test-ux--string-count-in (s file)
  "How many times the literal S appears in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (how-many (regexp-quote s))))

(defun cistern-test-ux--copy-strings (table)
  "All user-facing strings in the copy TABLE (nested alists)."
  (let ((out nil))
    (dolist (e table)
      (if (stringp (cdr e))
          (push (cdr e) out)
        (setq out (append (cistern-test-ux--copy-strings (cdr e)) out))))
    (nreverse out)))

(defun cistern-test-ux-q11-copy-table ()
  "The idle pressure line stays byte-identical; all new
user-facing strings exist exactly once, inside the domain copy
table `cistern--copy' (the old milestone table is consolidated
away, not left beside it)."
  (let ((st (cistern--new-game 42)))
    (cl-assert (string= (cistern-view--pressure-line st)
                        "LINES NOMINAL — THE STRUCTURE DOES NOT CARE")
               t "idle pressure line byte-identical"))
  (cl-assert (boundp 'cistern--copy) t "one domain copy table exists")
  (cl-assert (null (boundp 'cistern--copy-milestones))
             t "milestone strings consolidated into cistern--copy")
  ;; every flavor string in the table lives in cistern-domain.el and
  ;; in NO other src file — the table is the single source, no
  ;; format-string drift (substring overlaps inside the table's own
  ;; file are fine; the long strings contain the short ones)
  (let ((domain (expand-file-name "cistern-domain.el"
                                  cistern-test-ux--src-dir)))
    (dolist (s (cistern-test-ux--copy-strings cistern--copy))
      (cl-assert (> (cistern-test-ux--string-count-in s domain) 0)
                 t "copy %S present in the domain table" s)
      (dolist (f (directory-files cistern-test-ux--src-dir t "\\.el\\'"))
        (unless (string= f domain)
          (cl-assert (= 0 (cistern-test-ux--string-count-in s f))
                     t "copy %S drifted outside the domain table" s))))))

;; --- Q09: severed vs backed-up domain split -----------------------------------

(defun cistern-test-ux-q09-domain-split ()
  "A severed toilet (no path) and a backed-up toilet (path, tanks
full) expose DIFFERENT flags; the collapsed legacy predicate is
gone."
  (cl-assert (fboundp 'cistern--toilets-severed-p)
             t "severed half of the split exists")
  (cl-assert (fboundp 'cistern--toilets-backed-up-p)
             t "backed-up half of the split exists")
  (cl-assert (null (fboundp 'cistern--toilets-backed-p))
             t "collapsed legacy predicate retired")
  ;; severed with empty tanks: severed, not backed-up
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-demolish st 4 2)            ; sever the starter line
    (puthash (cons 5 2) (list :load 0) (cistern-st-tanks st))
    (cl-assert (cistern--toilets-severed-p st)
               t "no-path toilet reads severed")
    (cl-assert (null (cistern--toilets-backed-up-p st))
               t "severed-with-empty-tanks is not backed-up"))
  ;; path with a full tank: backed-up, not severed
  (let ((st (cistern--new-game 42)))
    (puthash (cons 5 2) (list :load 60) (cistern-st-tanks st))
    (cl-assert (cistern--toilets-backed-up-p st)
               t "full-tank path reads backed-up")
    (cl-assert (null (cistern--toilets-severed-p st))
               t "backed-up is not severed")))

;; --- Q10: pressure re-branch + offender coords --------------------------------

(defun cistern-test-ux-q10-severed-rewire ()
  "ANTAG-05: with the starter line severed the pressure line
advises REWIRE — never purge — and names the tank cell to wire
to; the inspector agrees (LAY PIPE)."
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-demolish st 4 2)            ; sever the starter line
    (setf (cistern-st-cursor st) (cons 3 3))  ; cursor on the severed toilet
    (let* ((line (cistern-view--pressure-line st))
           (inspector (cistern-test-ux--plain (cistern-view--inspector st))))
      (cl-assert (string-match-p "LINES SEVERED — REWIRE (p)" line)
                 t "severed branch advises rewiring")
      (cl-assert (null (string-match-p "PURGE" line))
                 t "severed never advises purge")
      (cl-assert (string-match-p "TANK AT (5,2)" line)
                 t "the line names the offending tank cell")
      (cl-assert (string-match-p "SEVERED" inspector)
                 t "inspector reads severed")
      (cl-assert (string-match-p "LAY PIPE" inspector)
                 t "inspector advises laying pipe — the two agree"))
    ;; backed-up keeps the purge advice, byte-identical
    (let ((st2 (cistern--new-game 42)))
      (puthash (cons 5 2) (list :load 60) (cistern-st-tanks st2))
      (cl-assert (string= (cistern-view--pressure-line st2)
                          "PRESSURE CRITICAL — TOILETS BACKED UP / PURGE THE TANKS")
                 t "backed-up keeps its purge advice verbatim"))))

;; --- Q12: dead pipe glyph + legend from the table ------------------------------

(defun cistern-test-ux-q12-dead-pipe-glyph ()
  "An unconnected pipe renders the tile table's distinct dead
glyph — never the floor dot — and the legend is GENERATED from
the same tile table, so no glyph is listed twice."
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1))
         (x (car spot)) (y (cadr spot)))
    (cistern--cmd-build st 'pipe x y)         ; isolated: unconnected
    (let ((glyph (car (cistern-view--cell-glyph st x y))))
      (cl-assert (string= glyph "╌")
                 t "dead pipe carries the table's dead glyph")
      (cl-assert (not (string= glyph (cistern--tile-glyph 'floor)))
                 t "dead pipe is not the floor dot"))
    (let* ((legend (cistern-test-ux--plain (cistern-view--legend-line)))
           (entries (split-string
                     (replace-regexp-in-string "\\`GLYPHS:\\s-*" "" legend)
                     "\\s-\\{2\\}" t))
           (glyphs (mapcar (lambda (e) (substring e 0 1)) entries)))
      ;; NB: how-many cannot match this multibyte glyph; split-count
      (cl-assert (= 1 (1- (length (split-string legend "╌"))))
                 t "legend lists the dead pipe exactly once")
      (cl-assert (= (length glyphs) (length (cl-delete-duplicates
                                            glyphs :test #'string=)))
                 t "no glyph listed twice in the legend")
      (cl-assert (member "╌" glyphs)
                 t "legend matches the map's actual glyphs"))))

;; --- Q13: severity stored on log entries ---------------------------------------

(defun cistern-test-ux-q13-severity-persists ()
  "A breach line renders red for every tick it stays in the tail
\(3+), not just tick one — severity rides the ENTRY, not the
current tick's intents."
  (let ((st (cistern--new-game 42)))
    (let ((w (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 14)
      (setf (cistern--worker-y w) 7)
      (setf (cistern--worker-bladder w)
            (- cistern-bladder-burst cistern-bladder-rate)))
    (cistern--do-tick st)                    ; the breach
    (cistern--do-tick st)                    ; the next eval replaces the intents
    (cistern--do-tick st)                    ; and the one after that
    (let* ((tail (cistern-view--log-tail st))
           (rows (split-string tail "\n"))
           (hit (cl-find-if (lambda (r) (string-match-p "BREACH" r)) rows)))
      (cl-assert hit t "breach still in the tail after 3 ticks")
      (cl-assert (eq (get-text-property 0 'face hit) 'cistern-toilet-down)
                 t "breach renders red for every tail tick"))))

;; --- Q16: full log retrievable ---------------------------------------------------

(defun cistern-test-ux-q16-full-log ()
  "The domain log is uncapped; `L' shows the oldest line in a
read-only buffer; the main screen keeps the 3-line tail."
  (let ((st (cistern--new-game 42)))
    (dotimes (i 13) (cistern--log st "TICK NOISE %d" i))
    (cl-assert (cl-find-if (lambda (e) (string-match-p "SECTOR-7 ONLINE" (car e)))
                           (cistern-st-log st))
               t "uncapped: the boot line survives in state")
    (setq cistern--st st)
    (cistern-log)
    (let ((buf (get-buffer "*cistern log*")))
      (cl-assert buf t "L opens the log buffer")
      (with-current-buffer buf
        (goto-char (point-min))
        (cl-assert (string-match-p "SECTOR-7 ONLINE"
                                   (buffer-substring
                                    (point) (line-end-position)))
                   t "the log buffer shows line 1, oldest first")
        (cl-assert buffer-read-only t "the log buffer is read-only")))
    (cl-assert (null (cl-find-if (lambda (r) (string-match-p "SECTOR-7 ONLINE" r))
                                 (split-string (cistern-view--log-tail st) "\n")))
               t "the main screen keeps the 3-line tail")))

;; --- Q14: shared worker-identity helper ----------------------------------------

(defun cistern-test-ux-q14-worker-identity ()
  "One identity helper, at the SOURCE the accident log can reach
\(the domain — innermost layer): the breach log names the same
glyph the map shows at that cell, no off-by-one, no CREATOR #N;
the view's private copy is retired."
  (cl-assert (fboundp 'cistern--worker-glyph)
             t "shared helper exists in the domain")
  (cl-assert (null (boundp 'cistern-view--worker-glyphs))
             t "the view's private glyph table is retired")
  (cl-assert (null (fboundp 'cistern-view--worker-glyph))
             t "the view's private helper is retired")
  (let ((st (cistern--new-game 42)))
    (let ((w (nth 1 (cistern-st-creators st))))
      (setf (cistern--worker-x w) 14)
      (setf (cistern--worker-y w) 7)
      (setf (cistern--worker-bladder w)
            (- cistern-bladder-burst cistern-bladder-rate)))
    (cistern--do-tick st)
    (let* ((w (nth 1 (cistern-st-creators st)))
           (glyph (cistern--worker-glyph st w))
           (breach (cl-find-if (lambda (e) (string-match-p "BREACH" (car e)))
                               (cistern-st-log st))))
      (cl-assert (string-match-p
                  (format "CREATOR %s OVERFLOWED" glyph) (car breach))
                 t "the log names the worker's glyph, not #N")
      ;; the map at the breach cell shows the same glyph (the worker
      ;; occludes the tile at D5 precedence)
      (let* ((row (nth (+ cistern-view--header-lines 7)
                       (cistern-test-ux--render-lines st)))
             (cell (substring row 14 (1+ 14))))
        (cl-assert (string= cell glyph)
                   t "map and log agree on the identity glyph")))))

;; --- Q15: log consequence ranking + spam suppression ----------------------------

(defun cistern-test-ux-q15-log-ranking ()
  "With breach + relief spam the 3-line tail keeps the breach;
identical consecutive relief lines collapse to one with an ×N
count; boot flavor ages out like any line.  Suppression is
silent — no new copy beyond the count."
  ;; (a) breach survives relief spam; identical lines shown once
  (let ((st (cistern--new-game 42)))
    (dotimes (_ 12) (cistern--log-sev st 'info "CREATOR RELIEVED AT (3,3)"))
    (cistern--log-sev st 'error "BREACH — CREATOR β OVERFLOWED AT (5,6)")
    (let* ((tail (cistern-view--log-tail st))
           (rows (cl-remove-if (lambda (r) (string= r ""))
                               (split-string tail "\n")))
           (breach-row (cl-find-if (lambda (r) (string-match-p "BREACH" r))
                                   rows)))
      (cl-assert breach-row t "the breach keeps a tail slot")
      (cl-assert (= 1 (cl-count-if (lambda (r) (string-match-p "RELIEVED" r))
                                   rows))
                 t "identical consecutive relief lines collapse")
      (cl-assert (cl-find-if (lambda (r) (string-match-p "×12" r)) rows)
                 t "the collapse carries the ×12 count")
      (cl-assert (eq (get-text-property 0 'face breach-row)
                     'cistern-toilet-down)
                 t "the breach keeps its red face")))
  ;; (b) boot flavor ages out: 13 distinct later lines push it out
  (let ((st (cistern--new-game 42)))
    (dotimes (i 13) (cistern--log st "TICK NOISE %d" i))
    (cl-assert (null (cl-find-if (lambda (r) (string-match-p "ONLINE" r))
                                 (split-string (cistern-view--log-tail st)
                                               "\n")))
               t "boot flavor ages out like any line")))

;; --- Q17: transient cursor-hint surface -----------------------------------------

(defun cistern-test-ux-q17-cursor-hint ()
  "A posted hint renders one row UNDER the inspector and is
consumed — gone by the next render, no permanent layout shift.
Transport: a state slot posted by use-cases, read by the view,
drained once (rewards-events pattern)."
  (let ((st (cistern--new-game 42)))
    (cl-assert (null (cistern-st-hint st)) t "no hint by default")
    (setf (cistern-st-hint st) "HINT TEXT")
    (let* ((lines (cistern-test-ux--render-lines st))
           (insp-idx (cl-position-if (lambda (l) (string-match-p "^CURSOR" l))
                                     lines)))
      (cl-assert insp-idx t "inspector row found")
      (cl-assert (string-match-p "HINT TEXT" (nth (1+ insp-idx) lines))
                 t "hint renders in the transient slot under the inspector"))
    (cistern--cmd-consume-hint st)
    (let ((lines (cistern-test-ux--render-lines st)))
      (cl-assert (null (cl-position-if (lambda (l) (string-match-p "HINT TEXT" l))
                                       lines))
                 t "consumed: absent from the next render"))))

;; --- Q18: refusal copy names the next action -------------------------------------

(defun cistern-test-ux-q18-refusal-hints ()
  "Refusals post through the hint surface with fix-naming copy
\(copy-table text); the log still records the refusal — history
intact — and the cursor inspector reflects the state for that
tick."
  (let ((st (cistern--new-game 42)))
    ;; build on wall
    (cistern--cmd-build st 'tank 0 0)         ; wall cell
    (cl-assert (equal (cistern-st-hint st)
                      "NO FLOOR THERE — AIM FOR OPEN FLOOR")
               t "wall refusal posts the fix-naming hint")
    (cl-assert (cl-find-if (lambda (e) (string-match-p "CANNOT BUILD THERE"
                                                      (car e)))
                           (cistern-st-log st))
               t "log still records the refusal")
    (cistern--cmd-consume-hint st)
    ;; insufficient alloy
    (let ((spot (cistern-test-game--floor-run st 1)))
      (setf (cistern-st-alloy st) 0)
      (cistern--cmd-build st 'tank (car spot) (cadr spot))
      (cl-assert (equal (cistern-st-hint st)
                        "NEED 15 ALLOY — PURGE (x) PAYS")
                 t "alloy refusal names the cost and the paying move")
      (cl-assert (cl-find-if (lambda (e) (string-match-p "INSUFFICIENT ALLOY"
                                                        (car e)))
                             (cistern-st-log st))
                 t "log still records the refusal"))))

;; --- Q19: armed verb visible, cancelable, taught ---------------------------------

(defun cistern-test-ux-q19-armed-badge ()
  "After `p' the header badge names the verb and the cancel key;
ESC/u clear the verb through a use-case; the help line teaches
arm-then-click; an at-cursor keypress refuses CLEANLY instead of
arm-then-fail noise."
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-arm-verb st 'pipe)
    ;; R2-Q02: the badge is its own dim row below the strip
    (cl-assert (string-match-p "ARMED: PIPE"
                               (nth 1 (cistern-test-ux--render-lines st)))
               t "armed verb visible in the badge row")
    (cistern--cmd-disarm st)
    (cl-assert (null (cistern-st-armed-verb st))
               t "disarm clears the verb via the use-case")
    (cl-assert (eq (lookup-key cistern-mode-map "u") #'cistern-disarm)
               t "u bound to disarm")
    (cl-assert (eq (lookup-key cistern-mode-map (kbd "<escape>"))
                   #'cistern-disarm)
               t "escape bound to disarm (unbound before Q19)")
    (cl-assert (string-match-p "t/p/K arm — click to place"
                               (cistern-view--help-line))
               t "help line gains the arm phrase"))
  ;; at-cursor keypress refuses cleanly: no arm-then-fail noise
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-cursor st) (cons 0 0))   ; wall
    (with-temp-buffer
      (cistern--arm-and-build 'tank)
      (cl-assert (string-match-p "NO FLOOR THERE" (buffer-string))
                 t "the refusal's hint rode that render")
      (cl-assert (null (cistern-st-armed-verb st))
                 t "a refused at-cursor build does not arm"))))

;; --- Q20: inspector bearing on plain floor ---------------------------------------

(defun cistern-test-ux-q20-floor-bearing ()
  "A plain-floor cursor names the nearest toilet and tank with
grid distances and directions; every existing per-tile inspector
line stays byte-identical (extension only)."
  ;; extension: plain floor gains the bearing
  (let* ((st (cistern--new-game 42))
         (spot (cistern-test-game--floor-run st 1)))
    (setf (cistern-st-cursor st) (cons (car spot) (cadr spot)))
    (let ((insp (cistern-test-ux--plain (cistern-view--inspector st))))
      (cl-assert (string-match-p
                  "FLOOR — toilet Ω [0-9]+ \\(west\\|east\\|north\\|south\\).*tank ▣ [0-9]+"
                  insp)
                 t "floor cursor names the nearest structures")
      (cl-assert (not (string-match-p "FLOOR\\s-*$" insp))
                 t "the bare FLOOR line gained its bearing")))
  ;; zero regression: non-floor lines byte-identical
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-cursor st) (cons 0 0))   ; wall
    (cl-assert (string= (cistern-test-ux--plain (cistern-view--inspector st))
                        "CURSOR (0,0): MEGASTRUCTURE WALL")
               t "wall inspector byte-identical")))

;; --- Q21: urgency colored ---------------------------------------------------------

(defun cistern-test-ux-q21-urgency-color ()
  "Colors, not words: the CONTAM segment faces by fraction
\(yellow >= 50%%, red bold >= 75%%), and the pressure line faces
by state (CRITICAL red bold, RISING yellow, NOMINAL dim)."
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-contam st) 16)         ; 80%: red bold
    (let* ((header (cistern-view--header-line st))
           (pos (string-match-p "CONTAM 16/20" header)))
      (cl-assert pos t "contam segment present")
      (cl-assert (eq (get-text-property pos 'face header)
                     'cistern-toilet-down)
                 t "contam >= 75%% renders red bold"))
    (setf (cistern-st-contam st) 5)          ; 25%: not red bold
    (let* ((header (cistern-view--header-line st))
           (pos (string-match-p "CONTAM 5/20" header)))
      (cl-assert (not (eq (get-text-property pos 'face header)
                          'cistern-toilet-down))
                 t "contam 25%% is not red bold")))
  ;; pressure line faces by state
  (let ((st (cistern--new-game 42)))
    (puthash (cons 5 2) (list :load 60) (cistern-st-tanks st))
    (cl-assert (eq (cistern-test-ux--pressure-row-face st)
                   'cistern-toilet-down)
               t "CRITICAL renders red bold"))
  (let ((st (cistern--new-game 42)))
    (puthash (cons 5 2) (list :load 54) (cistern-st-tanks st))
    (cl-assert (eq (cistern-test-ux--pressure-row-face st)
                   'cistern-tank-high)
               t "RISING renders yellow"))
  (let ((st (cistern--new-game 42)))
    (cl-assert (eq (cistern-test-ux--pressure-row-face st) 'cistern-dim)
               t "NOMINAL renders dim")))

(defun cistern-test-ux--pressure-row-face (st)
  (let* ((render (cistern-view--render st))
         (pos (string-match-p "PRESSURE\\|LINES NOMINAL\\|SECTOR CONDEMNED"
                              render)))
    (cl-assert pos t "pressure row found")
    (get-text-property pos 'face render)))

;; --- Q22: run-summary snapshot ----------------------------------------------------

(defun cistern-test-ux-q22-run-summary ()
  "At condemnation the state exposes one summary — ticks
survived, relieves, score, trophies, cause — matching the run."
  (let ((st (cistern--new-game 42)))
    (dotimes (_ 400) (cistern--do-tick st))
    (cl-assert (cistern-st-over st) t "the driven run reaches condemnation")
    (cl-assert (cistern-st-summary st) t "summary banked at trigger")
    (let ((s (cistern-st-summary st)))
      (cl-assert s t "condemnation captures the summary")
      (cl-assert (= (plist-get s :ticks) (cistern-st-tick st))
                 t "ticks survived recorded")
      (cl-assert (= (plist-get s :relieves) (cistern-st-relieves st))
                 t "relieves recorded")
      (cl-assert (= (plist-get s :score) (or (cistern-st-score st) 0))
                 t "score recorded")
      (cl-assert (equal (plist-get s :trophies) (cistern-st-trophies st))
                 t "trophies recorded")
      (cl-assert (equal (plist-get s :cause)
                        "SECTOR CONDEMNED — CONTAMINATION LIMIT")
                 t "cause recorded"))))

;; --- Q25: particle placement contract ----------------------------------------------

(defun cistern-test-ux-q25-particle-placement ()
  "Ceremony sparkles spawn ONLY over plain floor, and the glyph
set no longer collides with the floor dot or digits; pipes, walls,
toilets and tanks stay visible under the ceremony (LEG-06)."
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 1))))
    (cistern-test-ux--drive-relief st)      ; completes the card: ceremony
    (let ((sparkles (cl-remove-if-not
                     (lambda (p) (eq (plist-get p :layer) 'sparkle))
                     (cistern-st-particles st))))
      (cl-assert sparkles t "ceremony spawned sparkles")
      (dolist (p sparkles)
        (let* ((pos (plist-get p :pos))
               (glyph (plist-get p :glyph)))
          (cl-assert (eq (cistern--cell st (car pos) (cdr pos)) 'floor)
                     t "sparkle over plain floor at %S" pos)
          (cl-assert (null (member glyph '("·" "0" "1" "2" "3" "4"
                                           "5" "6" "7" "8" "9")))
                     t "no sparkle glyph collides with floor or digits"))))))

;; --- Q26: PROTECT non-modal architecture guard ---------------------------------------

(defun cistern-test-ux-q26-non-modal-guard ()
  "PROTECT executable: during the death panel input stays live,
and a keypress (n) starts the new game without forfeiting the
banked summary — committed at trigger time, nothing pending."
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-contam st) cistern-contam-limit)
    (cistern--phase-check st)
    (cl-assert (cistern-st-summary st) t "summary banked at trigger")
    ;; input live during the death panel
    (cistern--cmd-cursor st 'right)
    (cl-assert (equal (cistern-st-cursor st) (cons 4 6))
               t "input live during the death panel")
    ;; the keypress: n starts the new game
    (setq cistern--st st)
    (with-temp-buffer
      (cistern-new-game))
    (cl-assert (= (cistern-st-tick cistern--st) 0)
               t "the keypress started the new game")
    (cl-assert (cistern-st-goal-card cistern--st)
               t "the new game is fully dealt")
    ;; nothing forfeited: the banked summary survives in the old state
    (cl-assert (plist-get (cistern-st-summary st) :ticks)
               t "the banked summary is intact")))

;; --- Q27: tutorial table ships ----------------------------------------------------

(defun cistern-test-ux-q27-tutorial-table ()
  "The default tutorial table ships 3 steps over real predicates:
cursor onto a worker, purge a filling tank, watch alloy pay.  The
prompt renders as a persistent line, not log lines."
  (let ((st (cistern--new-game 42)))
    ;; step 1 prompt visible from the start (persistently)
    (cl-assert (string-match-p "TUTORIAL 1/3"
                               (cistern-test-ux--plain (cistern-view--render st)))
               t "step 1 prompt visible on a new game")
    (cistern--do-tick st) (cistern--do-tick st) (cistern--do-tick st)
    (cl-assert (string-match-p "TUTORIAL 1/3"
                               (cistern-test-ux--plain (cistern-view--render st)))
               t "step 1 still the prompt by tick 3")
    ;; drive step 1: park the cursor on a worker's spawn cell — the
    ;; wanderer passes under it within the bound (deterministic seed)
    (let ((w0 (car (cistern-st-creators st))))
      (setf (cistern-st-cursor st)
            (cons (cistern--worker-x w0) (cistern--worker-y w0)))
      (dotimes (_ 60)
        (unless (string-match-p "TUTORIAL 2/3"
                                (cistern-test-ux--plain
                                 (cistern-view--render st)))
          (cistern--do-tick st))))
    (cl-assert (string-match-p "TUTORIAL 2/3"
                               (cistern-test-ux--plain (cistern-view--render st)))
               t "cursor-on-worker advances to step 2")
    ;; drive step 2: purge the filling starter tank
    (cistern--cmd-purge st 5 2)
    (cistern--do-tick st)
    (cl-assert (string-match-p "TUTORIAL 3/3"
                               (cistern-test-ux--plain (cistern-view--render st)))
               t "the purge advances to step 3")
    ;; drive step 3: the alloy paid
    (cl-assert (> (cistern-st-alloy st) 20) t "the purge paid alloy")
    (cistern--do-tick st)
    (cl-assert (null (string-match-p "TUTORIAL 3/3"
                                     (cistern-test-ux--plain
                                      (cistern-view--render st))))
               t "watching the pay completes the tutorial")))

;; --- Q28: briefing proofread --------------------------------------------------------

(defun cistern-test-ux-q28-briefing-proofread ()
  "The ? briefing prints real percentages (no %% artifacts),
carries the arm-then-click line and the seed mention (Q01)."
  (cistern-help)
  (let ((text (with-current-buffer "*cistern help*" (buffer-string))))
    (cl-assert (string-match-p "60%" text) t "60% renders")
    (cl-assert (string-match-p "100%" text) t "100% renders")
    (cl-assert (null (string-match-p "%%" text))
               t "no %% artifacts anywhere in the briefing")
    (cl-assert (string-match-p "click to place" text)
               t "the briefing carries the arm-then-click line")
    (cl-assert (string-match-p "seed" text) t "the briefing mentions the seed")))

;; --- Q29: auto-run surfaced + pacing ------------------------------------------------

(defun cistern-test-ux-q29-auto-run ()
  "While the auto-run chain is live the Q01 badge slot shows
AUTO-RUN; prefix-arg slow mode schedules 1 tick/second (1.0s
links) beside the 5tps default.  The handle stays out of state."
  ;; slow mode schedules 1.0s links; the flag mirrors into state
  (setq cistern--auto-run-timer nil)
  (let (sched)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (secs repeat fn &rest _)
                 (push (list secs repeat fn) sched)
                 (list 'fake-timer (length sched))))
              ((symbol-function 'cancel-timer) #'ignore))
      (let ((st (cistern--new-game 42)))
        (cistern-input-auto-run-toggle st 'slow)
        (cl-assert (equal (car sched) (list 1.0 nil
                                            'cistern-input--auto-run-callback))
                   t "slow mode: 1 tick/second links")
        (cl-assert (cistern-st-auto-run st) t "auto-run flag on")
        (cistern-input-auto-run-toggle st)
        (cl-assert (null (cistern-st-auto-run st))
                   t "toggle-off clears the flag")
        ;; fast default unchanged: 0.2s links
        (cistern-input-auto-run-toggle st)
        (cl-assert (equal (car sched) (list 0.2 nil
                                            'cistern-input--auto-run-callback))
                   t "default stays 5 ticks/second")
        ;; the badge rides Q01's reserved slot
        ;; R2-Q02: the badge is its own dim row below the strip
        (cl-assert (string-match-p "AUTO-RUN"
                                   (nth 1 (cistern-test-ux--render-lines st)))
                   t "badge row shows AUTO-RUN while the chain is live")
        (cistern-input-auto-run-toggle st)))))

;; --- Q30: free regret window ----------------------------------------------------------

(defun cistern-test-ux-q30-regret-window ()
  "Demolishing in the same tick the piece was placed refunds
fully — the place+demolish cycle costs nothing; after a tick the
old refund rules return.  The Q07 purge ledger is untouched."
  ;; same tick: alloy unchanged across the cycle
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1))
          (a0 (cistern-st-alloy st)))
      (cistern--cmd-build st 'pipe (car spot) (cadr spot))
      (cistern--cmd-demolish st (car spot) (cadr spot))
      (cl-assert (= (cistern-st-alloy st) a0)
                 t "place + immediate demolish: alloy unchanged")))
  ;; after a tick: the old refund rules (50% of build cost)
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1))
          (a0 (cistern-st-alloy st)))
      (cistern--cmd-build st 'pipe (car spot) (cadr spot))
      (cistern--do-tick st)
      (cistern--cmd-demolish st (car spot) (cadr spot))
      (cl-assert (= (cistern-st-alloy st)
                    (- (+ a0 (/ cistern-cost-pipe 2))
                       cistern-cost-pipe cistern-cost-demolish))
                 t "after a tick the old refund rules return")))
  ;; tick 1: the cheap start always affords the undo
  (let ((st (cistern--new-game 42)))
    (let ((spot (cistern-test-game--floor-run st 1)))
      (cistern--cmd-build st 'tank (car spot) (cadr spot))
      (cl-assert (>= (cistern-st-alloy st) cistern-cost-demolish)
                 t "tick-1 alloy always affords the demolish undo"))))

;; --- Q23: death summary panel -------------------------------------------------------

(defun cistern-test-ux-q23-death-panel ()
  "On condemned the render carries the summary as a banner-layer
panel — cause, ticks, relieves, score, restart — and the log
shows a SINGLE restart line, not one per post-over keypress."
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-relieves st) 12)
    (setf (cistern-st-score st) 250)
    (setf (cistern-st-contam st) cistern-contam-limit)
    (with-temp-buffer
      (cistern--refresh))
    (cistern--phase-check st)
    (let ((render (cistern-test-ux--plain (cistern-view--render st))))
      (cl-assert (string-match-p
                  (concat "SECTOR CONDEMNED — CONTAMINATION LIMIT"
                          " / TICKS [0-9]+ · RELIEVES 12 · SCORE 250"
                          " / PRESS n TO RESTART")
                  render)
                 t "one frame carries the death panel")))
  ;; post-over keypresses: one restart line, not four
  (let ((st (cistern--new-game 42)))
    (setq cistern--st st)
    (setf (cistern-st-contam st) cistern-contam-limit)
    (with-temp-buffer
      (dotimes (_ 4) (cistern-tick))
      (let ((restarts (cl-count-if
                       (lambda (e) (string-match-p "PRESS n TO RESTART"
                                                   (car e)))
                       (cistern-st-log st))))
        (cl-assert (= restarts 1)
                   t "log shows a single restart line (got %d)" restarts)))))

;; --- Q24: ceremony narrates the goals -------------------------------------------------

(defun cistern-test-ux-q24-goal-narration ()
  "Before the MAP COMPLETED banner, each satisfied goal logs
GOAL MET — the narration precedes the banner in the log."
  (let ((st (cistern--new-game 42)))
    (cistern--cmd-set-goal-card
     st '(:tier 2 :goals ((:kind relieves-served :target 1)
                          (:kind contamination-ceiling :target 5))))
    (cistern-test-ux--drive-relief st)
    (let* ((intents (cdr (cistern-st-rewards-outcome st)))
           (met-idx (cl-position-if
                     (lambda (i) (and (eq (plist-get i :layer) 'log)
                                      (string-match-p "GOAL MET"
                                                      (plist-get i :text))))
                     intents))
           (banner-idx (cl-position-if
                        (lambda (i) (and (eq (plist-get i :layer) 'banner)
                                         (equal (plist-get i :text)
                                                "MAP COMPLETED")))
                        intents)))
      (cl-assert met-idx t "a GOAL MET line narrated")
      (cl-assert banner-idx t "the completion banner present")
      (cl-assert (< met-idx banner-idx)
                 t "GOAL MET precedes the banner")
      (cl-assert (cl-find-if (lambda (e) (string-match-p "GOAL MET — 1 SERVED"
                                                        (car e)))
                             (cistern-st-log st))
                 t "the served goal narrates its count"))))

(provide 'test-ux-r1)
;;; test-ux-r1.el ends here
