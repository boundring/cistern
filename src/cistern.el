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
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (cistern-view--render cistern--st))
    ;; Q17: the hint is a one-tick transient — the render consumed it
    (cistern--cmd-consume-hint cistern--st)
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
    (define-key m "T" #'cistern-skip-tutorial)
    (define-key m "r" #'cistern-auto-run-toggle)
    (define-key m "u" #'cistern-disarm)
    (define-key m (kbd "<escape>") #'cistern-disarm)
    (define-key m "L" #'cistern-log)
    (define-key m "n" #'cistern-new-game)
    (define-key m "?" #'cistern-help)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode cistern-mode special-mode "CISTERN"
  "Major mode for the CISTERN sanitation management sim."
  (setq-local truncate-lines t)
  (setq-local cursor-type nil))

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
  cistern--st)

(defun cistern-new-game ()
  (interactive)
  (setq cistern--st (cistern--new-game
                     (cistern--rand cistern--st 2147483647)))
  (cistern--refresh))

(defun cistern-skip-tutorial ()
  (interactive)
  (cistern--cmd-skip-tutorial cistern--st)
  (cistern--refresh))

(defun cistern-tick ()
  (interactive)
  (if (cistern-st-over cistern--st)
      (cistern--log cistern--st "SECTOR CONDEMNED — PRESS n FOR NEW GAME")
    (cistern--do-tick cistern--st))
  (cistern--refresh))

(defun cistern-cursor-north ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'north)
  (cistern--refresh))
(defun cistern-cursor-south ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'south)
  (cistern--refresh))
(defun cistern-cursor-west ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'west)
  (cistern--refresh))
(defun cistern-cursor-east ()
  (interactive)
  (cistern-input-cursor-move cistern--st 'east)
  (cistern--refresh))

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
      (cistern-input-click cistern--st (car xy) (cdr xy))
      (cistern--refresh))))

(defun cistern--arm-and-build (kind)
  "Arm KIND via the input adapter (use-case `cistern--cmd-arm-verb',
the single arming site per L-010 pin 4) and build it at the cursor
(Pinned D3: the keyboard build keys keep the legacy at-cursor flow
while arming the verb for click-to-place).  Q19: a refused
at-cursor build posts its hint and does NOT arm — refuse cleanly,
no arm-then-fail noise."
  (when (cistern--cmd-build cistern--st kind
                            (car (cistern-st-cursor cistern--st))
                            (cdr (cistern-st-cursor cistern--st)))
    (cistern-input-arm-verb cistern--st kind))
  (cistern--refresh))

(defun cistern-disarm ()
  (interactive)
  (cistern-input-disarm cistern--st)
  (cistern--refresh))

(defun cistern-build-toilet ()
  (interactive) (cistern--arm-and-build 'toilet))
(defun cistern-build-pipe ()
  (interactive) (cistern--arm-and-build 'pipe))
(defun cistern-build-tank ()
  (interactive) (cistern--arm-and-build 'tank))

(defun cistern-demolish ()
  (interactive)
  (cistern--cmd-demolish cistern--st
                         (car (cistern-st-cursor cistern--st))
                         (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-decon ()
  (interactive)
  (cistern--cmd-decon cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-purge ()
  (interactive)
  (cistern--cmd-purge cistern--st
                      (car (cistern-st-cursor cistern--st))
                      (cdr (cistern-st-cursor cistern--st)))
  (cistern--refresh))

(defun cistern-auto-run-toggle ()
  "Toggle the 5 ticks/second auto-run timer ('r').  Scheduling
and the chain callback live in the input adapter; the handle is
`cistern--auto-run-timer' (Pinned D2)."
  (interactive)
  (setq cistern-input--refresh #'cistern--refresh)
  (cistern-input-auto-run-toggle cistern--st))

(defun cistern-log ()
  "Q16: the full uncapped log, oldest first, in a read-only
buffer.  The main screen keeps its 3-line tail."
  (interactive)
  (let ((buf (get-buffer-create "*cistern log*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (dolist (e (reverse (cistern-st-log cistern--st)))
          (insert (car e) "\n"))
        (goto-char (point-min)))
      (setq buffer-read-only t))
    (pop-to-buffer buf)))

(defun cistern-help ()
  (interactive)
  (with-output-to-temp-buffer "*cistern help*"
    (princ (format "CISTERN v%s — sanitation protocol for Sector 7 — map seed %d\n\n"
                   cistern-version
                   (if cistern--st (cistern-st-seed cistern--st) 0)))
    (princ "THE CONCEPT\n")
    (princ "  Route need to capacity.  Convert waste to income.\n")
    (princ "  Contamination is the clock.\n\n")
    (princ "GLYPHS\n")
    (princ "  ▓ wall    · floor    ◆ ore vein    ─ pipe    Ω toilet\n")
    (princ "  ▣ tank    ▒ contamination    + gate    α..θ workers\n\n")
    (princ "THE LOOP\n")
    (princ "  Workers mine ◆ for alloy.  Their bladders fill.  At 60%%\n")
    (princ "  they walk to a Ω and seat themselves — entering the toilet\n")
    (princ "  tile IS sitting down.  A Ω works only when piped to a ▣ with\n")
    (princ "  headroom.  Each use sends 10 units down the line.\n\n")
    (princ "  A full ▣ backs up every Ω it feeds (red Ω).  Purge with x on\n")
    (princ "  the ▣: free, and it PAYS 1 alloy per 3 units of waste.\n\n")
    (princ "  At 100%% a worker breaches: the tile turns ▒, contamination\n")
    (princ "  rises, neighbors fall sick.  ▒ spreads to adjacent floor.\n")
    (princ (format "  Decon with c.  At %d the sector is condemned.\n\n"
                   cistern-contam-limit))
    (princ (format "  Every %d ticks a migrant arrives.  Population means load.\n\n"
                   cistern-migrant-every))
    (princ "CONTROLS\n")
    (princ "  SPC / RET   advance one tick\n")
    (princ "  arrows / mouse   move cursor\n")
    (princ (format "  t   build toilet (%d)     p   lay pipe (%d)\n"
                   cistern-cost-toilet cistern-cost-pipe))
    (princ (format "  K   build tank (%d)       c   decontaminate (%d)\n"
                   cistern-cost-tank cistern-cost-decon))
    (princ (format "  x   purge tank (pays)     d   demolish (%d)\n"
                   cistern-cost-demolish))
    (princ "  r   auto-run (5 ticks/s)\n")
    (princ "  T   skip tutorial         n   new game\n")
    (princ "  ?   this briefing         q   quit\n")))

(provide 'cistern)
;;; cistern.el ends here
