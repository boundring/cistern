;;; cistern.el --- CISTERN: driver layer — mode, keymap, commands -*- lexical-binding: t; -*-

;; Driver layer (DESIGN-SPEC §3.3): exactly one global live-state var,
;; the major-mode keymap, the interactive commands, the entry point,
;; help.  Commands mutate state via the use cases (cursor moves route
;; through the input adapter); rendering is the view adapter's job,
;; inserted by the driver's `cistern--refresh'.

;;; Code:

(require 'cl-lib)
;; The optional filename makes `emacs -Q -l src/cistern.el' work:
;; load never adds the loaded file's directory to load-path (smoke
;; L-034), and a bare top-level `when' bootstrap would trip the
;; source-integrity gate (every src/ top-level form must be a
;; defining head).  Falls back to load-path when load-file-name is nil.
(require 'cistern-game (and load-file-name (expand-file-name "cistern-game.el" (file-name-directory load-file-name))))
(require 'cistern-input (and load-file-name (expand-file-name "cistern-input.el" (file-name-directory load-file-name))))
(require 'cistern-view (and load-file-name (expand-file-name "cistern-view.el" (file-name-directory load-file-name))))

;; The one module global (spec §3.3, legacy cistern.el:785 pattern).
;; The D2 timer-handle exception (`cistern--auto-run-timer') lives in
;; the input adapter (L-015 pin 1: inward dependency).
(defvar cistern--st nil)

(defun cistern--refresh ()
  "Driver-owned buffer mutation (D4): erase and insert the view's
pure render.  Every state-mutating command ends here."
  ;; §4 auto-run path: one particle advance per redisplay — paired
  ;; with the sim tick the command already ran; paused redisplay
  ;; advances the field only (celebrations finish while frozen).
  ;; Call site pinned in L-029.
  (cistern--advance-particles cistern--st)
  ;; V4-04 (S2.3) trigger 3: drift guard — one string compare; a
  ;; custom-set-faces/load-theme bg change re-derives before render.
  (cistern--apply-palette)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (cistern-view--render cistern--st))
    (goto-char (point-min))))

(defvar cistern-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "SPC") #'cistern-tick)
    (define-key m (kbd "RET") #'cistern-tick)
    (define-key m (kbd "<up>") #'cistern-cursor-north)
    (define-key m (kbd "<down>") #'cistern-cursor-south)
    (define-key m (kbd "<left>") #'cistern-cursor-west)
    (define-key m (kbd "<right>") #'cistern-cursor-east)
    (define-key m (kbd "<mouse-1>") #'cistern-click)
    (define-key m "t" #'cistern-build-toilet)
    (define-key m "p" #'cistern-build-pipe)
    (define-key m "K" #'cistern-build-tank)
    (define-key m "d" #'cistern-demolish)
    (define-key m "c" #'cistern-decon)
    (define-key m "x" #'cistern-purge)
    ;; V4-11 (RPG §2): T cycles the armed fixture type — the
    ;; tutorial skip moves to the power layer (C-t)
    (define-key m "T" #'cistern-cycle-toilet-type)
    (define-key m (kbd "C-t") #'cistern-skip-tutorial)
    (define-key m "r" #'cistern-auto-run-toggle)
    (define-key m "u" #'cistern-disarm)
    (define-key m (kbd "<escape>") #'cistern-disarm)
    (define-key m "L" #'cistern-log)
    (define-key m "n" #'cistern-new-game)
    (define-key m "?" #'cistern-help)
    (define-key m "q" #'quit-window)
    ;; V4-07 (SURFACE S4.2): the emacs pairing layer — additive, the
    ;; single-key roguelike map above is untouched
    (define-key m (kbd "C-n") #'cistern-cursor-south)
    (define-key m (kbd "C-p") #'cistern-cursor-north)
    (define-key m (kbd "C-f") #'cistern-cursor-east)
    (define-key m (kbd "C-b") #'cistern-cursor-west)
    (define-key m (kbd "C-a") #'cistern-cursor-row-home)
    (define-key m (kbd "C-e") #'cistern-cursor-row-end)
    (define-key m (kbd "M-<") #'cistern-cursor-map-home)
    (define-key m (kbd "M->") #'cistern-cursor-map-end)
    (define-key m (kbd "M-f") #'cistern-cursor-scan-next)
    (define-key m (kbd "M-b") #'cistern-cursor-scan-prev)
    (define-key m (kbd "C-g") #'cistern-disarm)
    (define-key m (kbd "C-s") #'cistern-cursor-capacity)
    (define-key m "." #'cistern-repeat-arm)
    m))

(define-derived-mode cistern-mode special-mode "CISTERN"
  "Major mode for the CISTERN sanitation management sim."
  (setq-local truncate-lines t)
  (setq-local line-spacing 0)          ; L-076: no vertical drift
  (setq-local cursor-type nil)
  ;; L-076: with this t (the default), U+25A0-25FF glyphs bypass the
  ;; fontset entirely and use the (wide-fallback) default font — the
  ;; pin below would never engage.  Buffer-local: only the map opts out.
  (setq-local use-default-font-for-symbols nil)
  (cistern--pin-glyph-fontset (selected-frame))
  ;; V4-04 (S2.3): trigger 1 — mode init applies the palette; the
  ;; hook registration rides init so it lands exactly when the game
  ;; goes live (add-hook is idempotent).
  (cistern--apply-palette (selected-frame))
  (add-hook 'enable-theme-functions #'cistern--theme-refresh))

;; ---------------------------------------------------------------------------
;; Theme-contrast application (V4-04, SURFACE S2.3).  The game frame
;; is ours (cistern--own-frame, L-076), so face application is
;; frame-scoped and never touches the user's other frames.

(defun cistern--palette-hex (frame)
  "FRAME's background as \"#RRGGBB\", or nil when unresolvable."
  (let ((bg (frame-parameter frame 'background-color)))
    (and (stringp bg)
         ;; hex first: `color-values' is display-dependent (batch
         ;; returns zeros) and themes often set named colors
         (if (string-match "^#\\([0-9a-fA-F]\\{6\\}\\)$" bg)
             (concat "#" (upcase (match-string 1 bg)))
           (and (color-values bg)
                (apply #'format "#%02X%02X%02X"
                       (mapcar (lambda (v) (round (* 255.0 (/ v 65535.0))))
                               (color-values bg))))))))

(defun cistern--apply-palette (&optional frame)
  "Derive the palette from FRAME's background and apply it
frame-scoped (S2.3).  The cache is one string compare per call —
the refresh drift guard rides this same path."
  (setq frame (or frame (selected-frame)))
  (let ((hex (cistern--palette-hex frame)))
    (when hex
      (unless (and cistern--palette-cache
                   (equal (car cistern--palette-cache) hex))
        (let ((pal (cistern--derive-palette hex)))
          (dolist (e cistern-view--face-roles)
            (set-face-attribute
             (intern (format "cistern-%s" (car e))) frame
             :foreground (cdr (assq (car e) pal))))
          (setq cistern--palette-cache (cons hex pal)))))))

(defun cistern--theme-refresh (&optional _theme)
  "S2.3 trigger 2: a theme change while the game is live re-derives
and re-applies on the game frame.  Hooked by `cistern-mode' init."
  (let ((w (get-buffer-window "*cistern*")))
    (when w
      (cistern--apply-palette (window-frame w)))))

;; ---------------------------------------------------------------------------
;; Glyph-width pin (L-076).  Some tile glyphs (ore U+25C6, tank U+25A3)
;; are East-Asian-ambiguous: with the owner's Iosevka default font they
;; fall back to a double-width font and every column after them drifts.
;; Fix: pin the geometric-shapes range (U+25A0-25FF) to a mono font
;; MEASURED at the current cell width — frame-local to the game frame
;; via `set-fontset-font', never the user's global font or default
;; fontset.  (A face-remap :fontset variant was tried first and
;; measured a 2x font — L-076 notes; frame fontset pin is the
;; mechanism that measured true.)  Measured candidates (L-076
;; diagnosis table, owner env cell=7px): Iosevka Fixed-10, Iosevka
;; Term-10, DejaVu Sans Mono-8/9, Hack-8/9, Fira Code-8/9, Adwaita
;; Mono-8/9 — the runtime sweep re-measures, so any environment lands
;; on a fit or the pin is skipped (behavior unchanged, no luck).

(defconst cistern--pin-font-families
  '("Iosevka Fixed" "Iosevka Term" "DejaVu Sans Mono" "Hack"
    "Fira Code" "Adwaita Mono")
  "Ordered mono fallback candidates; first MEASURED fit wins.
All six cover the pin range (U+25A0-25FF) and the dash range
(U+2010-2015) per fontconfig charset intersection (L-076); sizes
are resolved per frame by `font-info', so any environment with one
of these families lands on a measured fit.")

(defvar cistern--pin-font-cache nil
  "Alist (CELL-WIDTH . FONT-NAME) of measured pins, keyed by cell width.")

(defvar cistern--glyph-fontset nil
  "Font name applied by the last `cistern--pin-glyph-fontset' (L-076).")

(defun cistern--pin-font-fit-p (name cellw frame)
  "NAME resolves on FRAME to a mono font measuring CELLW per cell.
font-info's SPACE-WIDTH, AVERAGE-WIDTH and MAX-WIDTH all equal the
cell advance — a monospace hit at the exact cell width.  No frame
is created; `font-info' resolves the name directly (L-076)."
  (condition-case nil
      (let ((info (font-info name frame)))
        (and (vectorp info)
             (eql (aref info 10) cellw)   ; SPACE-WIDTH
             (eql (aref info 11) cellw)   ; AVERAGE-WIDTH
             (eql (aref info 7) cellw)))  ; MAX-WIDTH (mono sanity)
    (error nil)))

(defun cistern--pin-choose-font (cellw &optional frame)
  "First candidate font measuring CELLW per cell on FRAME.
Result cached per CELL-WIDTH; nil when no candidate fits."
  (or (cdr (assq cellw cistern--pin-font-cache))
      (let ((frame (or frame (selected-frame))) found)
        (catch 'fit
          (dolist (fam cistern--pin-font-families)
            (dolist (n '(6 7 8 9 10 11 12 13 14 15 16))
              (let ((name (format "%s-%d" fam n)))
                (when (cistern--pin-font-fit-p name cellw frame)
                  (setq found name)
                  (throw 'fit name))))))
        (when found
          (push (cons cellw found) cistern--pin-font-cache))
        found)))

(defun cistern--pin-glyph-fontset (&optional frame)
  "Pin U+25A0-25FF to a measured uniform font on FRAME's fontset.
Only the geometric-shapes range is redirected; ASCII and every
glyph the user's default font already measures at cell width keep
rendering in that font.  FRAME defaults to the selected frame (the
game frame — `cistern' selects it before the mode runs).  Skips
silently when no candidate measures a fit (terminal, or unusual
fonts) — behavior then is exactly as before."
  (when (display-graphic-p)
    (let* ((frame (or frame (selected-frame)))
           (cellw (with-selected-frame frame (default-font-width)))
           (font (cistern--pin-choose-font cellw)))
      (when font
        ;; a font NAME string is a valid FONT-SPEC for set-fontset-font
        (set-fontset-font nil '(#x25A0 . #x25FF) font frame)
        ;; em/en dashes in copy lines are East-Asian-ambiguous too
        (set-fontset-font nil '(#x2010 . #x2015) font frame)
        (setq cistern--glyph-fontset font)))))

(defun cistern--own-frame ()
  "L-076: the sector owns the frame — select the game window and
drop the others, so `cistern' reliably lands the user on the map."
  (select-window (or (get-buffer-window "*cistern*" t) (selected-window)))
  (ignore-errors (delete-other-windows)))

;;;###autoload
(defun cistern ()
  "Open the CISTERN sanitation management sim."
  (interactive)
  (switch-to-buffer "*cistern*")
  (unless (eq major-mode 'cistern-mode)
    (cistern-mode))
  (unless cistern--st
    (setq cistern--st (cistern--new-game)))
  (cistern--refresh)
  (cistern--own-frame)
  cistern--st)

(defun cistern-new-game ()
  (interactive)
  (setq cistern--teach-seen nil cistern--teach-fired nil cistern--last-armed nil)
  (when cistern--st (cistern--cmd-consume-hint cistern--st)) ; R2-Q06
  (setq cistern--st (cistern--new-game
                     (cistern--rand cistern--st 2147483647)))
  (cistern--refresh)
  (cistern--own-frame))

(defun cistern-skip-tutorial ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (cistern--cmd-skip-tutorial cistern--st)
  (cistern--refresh))

(defun cistern-tick ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (if (cistern-st-over cistern--st)
      ;; Q23: ONE restart line, not one per post-over keypress — the
      ;; duplicate suppression is silent (log history keeps the first)
      ;; R2-Q03: one verb — RESTART, as the panel and pressure line
      (let ((line (cdr (assq 'restart-log cistern--copy))))
        (unless (equal (caar (cistern-st-log cistern--st)) line)
          (cistern--log cistern--st "%s" line)))
    (cistern--do-tick cistern--st))
  (cistern--teach-note 'tick)
  (cistern--refresh))

(defun cistern-cursor-north ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'north)
  (cistern--teach-note 'move)
  (cistern--refresh))
(defun cistern-cursor-south ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'south)
  (cistern--teach-note 'move)
  (cistern--refresh))
(defun cistern-cursor-west ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'west)
  (cistern--teach-note 'move)
  (cistern--refresh))
(defun cistern-cursor-east ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'east)
  (cistern--teach-note 'move)
  (cistern--refresh))

;; V4-07 (SURFACE S4.2): the emacs power layer — pure-geometry jumps
;; and structure motion, all through the adapter chain.

(defun cistern-cursor-row-home ()
  (interactive)
  (cistern-input-cursor-goto cistern--st 0 (cdr (cistern-st-cursor cistern--st)))
  (cistern--teach-note 'move)
  (cistern--refresh))

(defun cistern-cursor-row-end ()
  (interactive)
  (cistern-input-cursor-goto cistern--st (1- (cistern-st-w cistern--st))
                             (cdr (cistern-st-cursor cistern--st)))
  (cistern--teach-note 'move)
  (cistern--refresh))

(defun cistern-cursor-map-home ()
  (interactive)
  (cistern-input-cursor-goto cistern--st 0 0)
  (cistern--teach-note 'move)
  (cistern--refresh))

(defun cistern-cursor-map-end ()
  (interactive)
  (cistern-input-cursor-goto cistern--st (1- (cistern-st-w cistern--st))
                             (1- (cistern-st-h cistern--st)))
  (cistern--teach-note 'move)
  (cistern--refresh))

(defun cistern-cursor-scan-next ()
  (interactive)
  (cistern-input-cursor-scan cistern--st 'next)
  (cistern--refresh))

(defun cistern-cursor-scan-prev ()
  (interactive)
  (cistern-input-cursor-scan cistern--st 'prev)
  (cistern--refresh))

(defun cistern-cursor-capacity ()
  (interactive)
  (cistern-input-cursor-capacity cistern--st)
  (cistern--refresh))

(defun cistern-cycle-toilet-type ()
  "V4-11 (RPG §2): `T` cycles the armed fixture type in catalog
order; the badge names the selection."
  (interactive)
  (cistern--cmd-cycle-toilet-type cistern--st)
  (cistern--refresh))

(defun cistern-repeat-arm ()
  "V4-07 (S4.2): `.` re-arms the last successfully armed verb."
  (interactive)
  (if cistern--last-armed
      (cistern--arm-and-build cistern--last-armed)
    (cistern--refresh)))

(defun cistern-click (event)
  "Mouse-1 on a grid cell: translate buffer coordinates to (x,y)
via the pure view geometry, then call the input adapter (unarmed =
cursor move, no tick; armed = place at the cell + one tick)."
  (interactive "@e")
  (let ((xy (save-excursion
              (goto-char (posn-point (event-start event)))
              (cistern-view--cell-at
               cistern--st (line-number-at-pos (point))
               (current-column)))))
    (when xy
      ;; R2-Q06: an ARMED click is a placement (drains the hint); an
      ;; unarmed click is aiming (preserves it)
      (when (cistern-st-armed-verb cistern--st)
        (cistern--cmd-consume-hint cistern--st))
      (cistern-input-click cistern--st (car xy) (cdr xy))
      (cistern--refresh))))

(defun cistern--arm-and-build (kind)
  "Arm KIND via the input adapter (use-case `cistern--cmd-arm-verb',
the single arming site per L-010 pin 4) and build it at the cursor
(Pinned D3: the keyboard build keys keep the legacy at-cursor flow
while arming the verb for click-to-place).  Q19: a refused
at-cursor build posts its hint and does NOT arm — refuse cleanly,
no arm-then-fail noise."
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (when (cistern--cmd-build cistern--st kind
                            (car (cistern-st-cursor cistern--st))
                            (cdr (cistern-st-cursor cistern--st)))
    (cistern-input-arm-verb cistern--st kind)
    (setq cistern--last-armed kind)          ; V4-07: `.` repeat fuel
    (cistern--teach-note 'arm))
  (cistern--refresh))

(defun cistern-disarm ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (cistern-input-disarm cistern--st)
  (setq cistern--last-armed nil)             ; ESC/u kills the repeat
  (cistern--teach-note 'disarm)
  (cistern--refresh))

(defun cistern-build-toilet ()
  (interactive) (cistern--arm-and-build 'toilet))
(defun cistern-build-pipe ()
  (interactive) (cistern--arm-and-build 'pipe))
(defun cistern-build-tank ()
  (interactive) (cistern--arm-and-build 'tank))

(defun cistern-demolish ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (cistern--cmd-demolish cistern--st
                         (car (cistern-st-cursor cistern--st))
                         (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-decon ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (cistern--cmd-decon cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-purge ()
  (interactive)
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (cistern--cmd-purge cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-auto-run-toggle (&optional slow)
  "Toggle the 5 ticks/second auto-run timer ('r').  Scheduling
and the chain callback live in the input adapter; the handle is
`cistern--auto-run-timer' (Pinned D2).  Q29: a prefix arg runs
slow mode — 1 tick/second."
  (interactive "P")
  (cistern--cmd-consume-hint cistern--st)      ; R2-Q06: non-cursor
  (setq cistern-input--refresh #'cistern--refresh)
  (cistern-input-auto-run-toggle cistern--st slow))

;; ---------------------------------------------------------------------------
;; V4-07 (SURFACE S4.3): the emacs coach — driver-side ephemeral
;; counters, NOT sim state (C5: determinism untouched).  The 3rd use
;; of a coached action posts a one-lifetime hint through the Q17
;; slot; the alist resets on `cistern-new-game'.

(defvar cistern--teach-seen nil
  "Alist (VERB . N) of coached-action use counts (input layer).")

(defvar cistern--teach-fired nil
  "Coached verbs that already fired their one hint per game.")

(defvar cistern--last-armed nil
  "Last successfully armed verb — the `.` repeat fuel (V4-07).")

(defconst cistern--teach-pairs
  '((move . teach-arrows) (arm . teach-cancel) (disarm . teach-emacs-cancel)
    (tick . teach-auto-run) (log . teach-log))
  "Coached action → copy key (SURFACE S4.3 table).")

(defun cistern--teach-note (verb)
  "Count VERB's use; on the 3rd, post its coach hint once."
  (let ((cell (assq verb cistern--teach-seen)))
    (if cell (setcdr cell (1+ (cdr cell)))
      (push (cons verb 1) cistern--teach-seen)))
  (when (and (>= (cdr (assq verb cistern--teach-seen)) 3)
             (not (memq verb cistern--teach-fired)))
    (push verb cistern--teach-fired)
    (setf (cistern-st-hint cistern--st)
          (cdr (assq (cdr (assq verb cistern--teach-pairs))
                     cistern--copy)))))

(defun cistern-log ()
  "Q16 + V4-02 (SURFACE S1.2): the full uncapped log, oldest
first, in the `cistern-log-mode' browser.  Re-opening does not
touch the buffer unless the log has grown (`cistern-log--built-for'
rings the length), so point survives the RET → L round trip.  The
main screen keeps its 3-line tail."
  (interactive)
  (let ((buf (get-buffer-create "*cistern log*")))
    (cistern--teach-note 'log)
    (pop-to-buffer buf)
    (if (and cistern-log--built-for
             (= cistern-log--built-for (length (cistern-st-log cistern--st))))
        nil                                ; no new events: keep point untouched
      (cistern-log-rebuild))))

(defvar cistern-log--built-for nil
  "Ring length the browser was last built from (V4-02 staleness gate).")

(defun cistern-log-rebuild ()
  "V4-02 (S1.2): rebuild the browser from current state — `g',
and the initial build; also covers auto-run having ticked under
the open browser (S5: opening the log pauses nothing)."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (cdr (assq 'log-header cistern--copy)) "\n")
    (dolist (e (reverse (cistern-st-log cistern--st)))
      (insert (cistern-view--log-line e) "\n"))
    (cistern-log-mode)
    ;; after mode init: kill-all-local-variables would wipe an earlier
    ;; buffer-local binding
    (setq-local cistern-log--built-for
                (length (cistern-st-log cistern--st)))
    (goto-char (point-min))))

(defun cistern-log-jump-to-source ()
  "V4-02 (S1.2): RET on a browser line — land the game cursor on
the line's `AT (x,y)' cell and pop back to `*cistern*'; a
coordinate-free line refuses with the `log-jump-none' hint and
changes no cursor."
  (interactive)
  (let ((line (buffer-substring (line-beginning-position)
                                (line-end-position))))
    (if (string-match "AT (\\([0-9]+\\),\\([0-9]+\\))" line)
        (progn
          (cistern-input-cursor-goto cistern--st
                                     (string-to-number (match-string 1 line))
                                     (string-to-number (match-string 2 line)))
          (pop-to-buffer "*cistern*")
          (cistern--refresh))
      (setf (cistern-st-hint cistern--st)
            (cdr (assq 'log-jump-none cistern--copy))))))

(defvar cistern-log-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m "n" #'next-line)         ; walk: events, not the game verb
    (define-key m "p" #'previous-line)
    (define-key m "/" #'isearch-forward)
    (define-key m "g" #'cistern-log-rebuild)
    (define-key m "G" #'end-of-buffer)
    (define-key m (kbd "RET") #'cistern-log-jump-to-source)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode cistern-log-mode special-mode "CISTERN-LOG"
  "V4-02 (SURFACE S1.3): the log browser.  C-n/C-p/C-f/C-b,
C-s/C-r, M-</M-> and SPC/DEL stay native (documented in the
briefing); n/p walk entries, / isearches, g rebuilds, RET jumps
to the line's source cell, q closes.")

(defun cistern-help ()
  (interactive)
  (with-output-to-temp-buffer "*cistern help*"
    (princ (cistern--help-text))))

(defun cistern--help-text ()
  "V4-08 (SURFACE S4.4): the ? briefing — four sections, basics
before power.  GLYPHS is GENERATED from the tile table (Q12's
one-source spirit — the old hand-typed lines had already drifted);
the power layer is framed as pairings the player already knows."
  (with-output-to-string
    (princ (format "CISTERN v%s — sanitation protocol for Sector 7 — map seed %d\n\n"
                   cistern-version
                   (if cistern--st (cistern-st-seed cistern--st) 0)))
    (princ "THE CONCEPT\n")
    (princ "  Route need to capacity.  Convert waste to income.\n")
    (princ "  Contamination is the clock.\n\n")
    (princ "THE LOOP\n")
    (princ "  Workers mine for alloy.  Their bladders fill.  At 60% they\n")
    (princ "  walk to a toilet and seat themselves — entering the toilet\n")
    (princ "  tile IS sitting down.  A toilet works only when piped to a\n")
    (princ "  tank with headroom.  Each use sends 10 units down the line.\n\n")
    (princ "  A full tank backs up every toilet it feeds (red toilet).\n")
    (princ "  Purge with x on the tank: free, and it PAYS 1 alloy per 3\n")
    (princ "  units of waste.\n\n")
    (princ "  At 100% a worker breaches: the tile turns contaminated,\n")
    (princ "  contamination rises, neighbors fall sick.  It spreads to\n")
    (princ (format "  adjacent floor.  At %d the sector is condemned.\n\n"
                   cistern-contam-limit))
    (princ (format "  Every %d ticks a migrant arrives.  Population means load.\n\n"
                   cistern-migrant-every))
    ;; R2-Q10: the strip's GOALS segment, explained
    (princ "  GOALS n/m tracks the active goal card; complete it for\n")
    (princ "  score and trophies.\n\n")
    ;; V4-08 (S4.4 §2): GENERATED — one source, the tile table
    (princ (cistern-view--legend-line))
    (princ "\n")
    (princ "CONTROLS — THE BASICS\n")
    (princ "  SPC / RET   advance one tick\n")
    (princ "  arrows / mouse   move cursor\n")
    (princ (format "  t   build toilet (%d)     p   lay pipe (%d)\n"
                   cistern-cost-toilet cistern-cost-pipe))
    (princ (format "  K   build tank (%d)       c   decontaminate (%d)\n"
                   cistern-cost-tank cistern-cost-decon))
    (princ (format "  x   purge tank (pays)     d   demolish (%d)\n"
                   cistern-cost-demolish))
    (princ (format "  %s\n" (cdr (assq 'help-arm cistern--copy))))
    ;; R2-Q08: the shipped interactions, named where the player reads
    ;; (briefing prose — per the COPY-TABLE rule this is not table copy)
    (princ "  L full log             u cancel armed verb (ESC on GUI)\n")
    (princ "  C-u r slow auto-run (1 tps)\n")
    (princ "  r   auto-run (5 ticks/s)\n")
    (princ "  T   cycle fixture type   C-t skip tutorial\n")
    (princ "  n   new game\n")
    (princ "  ?   this briefing         q   quit\n\n")
    ;; V4-08 (S4.4 §4): the emacs power layer — pairings, not a new
    ;; language (briefing prose, not table copy)
    (princ "CONTROLS — THE POWER LAYER\n")
    (princ "  You already know these.  Every one already worked in emacs;\n")
    (princ "  here they run the sector.\n")
    (princ "  C-n/C-p/C-f/C-b move     C-a/C-e row home/end\n")
    (princ "  M-< / M-> map corners    M-f/M-b next/prev structure\n")
    (princ "  C-g cancel armed verb    C-s jump to nearest wired toilet\n")
    (princ "  . repeat last build      (emacs C-x z repeats, too)\n\n")
    (princ "  THE LOG BROWSER (L)\n")
    (princ "  n/p walk / C-s search / RET jump to source / g refresh / q close\n")
    (princ "  (describe-mode documents the full keymap: C-h m)\n")))

(provide 'cistern)
;;; cistern.el ends here
