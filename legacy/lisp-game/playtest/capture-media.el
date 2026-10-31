;;; playtest/capture-media.el --- Deterministic media capture (batch) -*- lexical-binding: t; -*-

;; Drives a real seeded game (same conventions as playtest/smoke.el) and
;; dumps per-frame SCREEN-CAP-NN.txt transcripts plus a SCREEN-CAP-NN.map
;; face sidecar (one code char per cell for honest PNG coloring).
;;
;; Run from the repo root:
;;   emacs -Q --batch -l src/cistern.el -l playtest/capture-media.el \
;;     -f cistern-capture-media-run

(require 'cl-lib)

(defvar cap-n 0)

(defun cap-code (face)
  "Single-letter face code for the capture sidecar."
  (pcase face
    ('cistern-wall ?W)
    ('cistern-floor ?.)
    ('cistern-door ?D)
    ('cistern-ore ?O)
    ('cistern-pipe-live ?P)
    ('cistern-pipe-dead ?p)
    ('cistern-toilet ?T)
    ('cistern-toilet-busy ?B)
    ('cistern-toilet-down ?U)
    ('cistern-tank-ok ?t)
    ('cistern-tank-high ?h)
    ('cistern-tank-full ?F)
    ('cistern-hazard ?H)
    ('cistern-worker ?A)
    ('cistern-worker-sick ?S)
    ('cistern-cursor ?C)
    ('cistern-header ?d)
    ('cistern-dim ?i)
    ('cistern-tutorial ?u)
    ('cistern-rubble ?R)
    ('cistern-flood ?L)
    ('cistern-manifold ?M)
    ('cistern-cache ?c)
    ('cistern-event ?E)
    ('cistern-goblin ?G)
    ('cistern-pest ?Y)
    ('cistern-comedy ?w)
    (_ ??)))

(defun cap-dump (label)
  "Write the game buffer's player-eye view + face codes per frame."
  (let* ((base (expand-file-name
                (format "SCREEN-CAP-%02d-%s" (setq cap-n (1+ cap-n)) label)
                (file-name-as-directory (expand-file-name "playtest" default-directory))))
         (txt (with-current-buffer "*cistern*"
                (replace-regexp-in-string "\n$" "" (buffer-string))))
         (rows (split-string txt "\n")))
    (with-temp-file (concat base ".txt") (insert txt))
    (with-temp-file (concat base ".map")
      ;; Read face codes from the (read-only) game buffer directly.
      (insert
       (with-current-buffer "*cistern*"
         (save-excursion
           (goto-char (point-min))
           (let ((out ""))
             (dotimes (_ (length rows))
               (let (codes)
                 (let ((n (length (buffer-substring-no-properties
                                   (line-beginning-position)
                                   (line-end-position)))))
                   (dotimes (_ n)
                     (let* ((f (get-text-property (point) 'face))
                            (name (cond ((symbolp f) f)
                                        ((listp f) (cl-find-if #'symbolp f)))))
                       (push (cap-code name) codes))
                     (forward-char 1)))
                 (setq out (concat out (apply #'string (nreverse codes)) "\n"))
                 (forward-line 1)))
             out)))))
    (message "CAP %s tick=%d alloy=%d contam=%d"
             label (cistern-st-tick cistern--st)
             (cistern-st-alloy cistern--st) (cistern-st-contam cistern--st))))

(defun cap-seek (pred)
  (let ((st cistern--st) (hit nil))
    (catch 'done
      (dotimes (y (cistern-st-h st))
        (dotimes (x (cistern-st-w st))
          (when (funcall pred (cistern--cell st x y) x y)
            (setq hit (cons x y))
            (throw 'done hit)))))
    hit))

(defun cap-cursor-to (x y)
  (while (< (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-east))
  (while (> (car (cistern-st-cursor cistern--st)) x) (call-interactively #'cistern-cursor-west))
  (while (< (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-south))
  (while (> (cdr (cistern-st-cursor cistern--st)) y) (call-interactively #'cistern-cursor-north)))

(defun cistern-capture-media-run ()
  (interactive)
  ;; Deterministic start, seed 42 (smoke.el precedent).
  (cistern)
  (setq cistern--st (cistern--new-game 42))
  (cistern--refresh)
  (cap-dump "00-cold-start")
  ;; Move onto a worker so the inspector shows.
  (let ((wk (cap-seek (lambda (k _x _y) (eq k 'worker)))))
    (when wk (cap-cursor-to (car wk) (cdr wk))))
  (call-interactively #'cistern-tick)
  (cap-dump "01-worker-inspect")
  ;; Build a toilet next to the starter plumbing, then run it.
  (let ((spot (cap-seek (lambda (k x y)
                          (and (eq k 'floor)
                               (< (cistern-st-alloy cistern--st) 100))))))
    (cap-cursor-to (car spot) (cdr spot))
    (call-interactively #'cistern-build-toilet))
  (cap-dump "02-built-toilet")
  (dotimes (_ 14) (call-interactively #'cistern-tick))
  (cap-dump "03-mid-run")
  (dotimes (_ 15) (call-interactively #'cistern-tick))
  (cap-dump "04-pressure")
  (dotimes (_ 15) (call-interactively #'cistern-tick))
  (cap-dump "05-late")
  (dotimes (_ 15) (call-interactively #'cistern-tick))
  (cap-dump "06-end"))