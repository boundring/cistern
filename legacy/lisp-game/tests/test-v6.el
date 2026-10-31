;;; tests/test-v6.el --- CISTERN v6 wave 1: layout foundation -*- lexical-binding: t; -*-

;; Batch tests for docs/v6/V6-SPEC.md WAVE 1 (V6-01..V6-03), one
;; entry per directive acceptance, registered in tests/run.el.
;; Reds before greens per PROCESS; ledger entries continue past
;; L-109 (docs/FAILURE-LEDGER.md).

(require 'cl-lib)

;; Repo root pinned at load time (L-008 pattern).
(defconst cistern-test-v6--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-v6 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-v6--root))
(load (expand-file-name "src/cistern.el" cistern-test-v6--root))

;;; --- V6-01: LAY layout object + camera + click geometry -------------------

(defun cistern-test-v6-01--big-fixture ()
  "A 68×32 state: the camera needs a map bigger than any viewport
(the size classes land with V6-03)."
  (let ((st (cistern--new-game 42)))
    (setf (cistern-st-w st) 68 (cistern-st-h st) 32)
    (setf (cistern-st-map st) (make-vector (* 68 32) 'floor))
    (setf (cistern-st-cursor st) '(40 . 20))
    st))

(defun cistern-test-v6-01-layout ()
  "WO1.1: LAY at synthetic (120,40) shows the whole 34×16 sector
with header-lines 3 (badge variant 4); larger-than-map keeps the
camera at (0 . 0); (80,24) over a bigger map clamps the camera
with the cursor inside the viewport; the map never clips below
34×16; LAY is a pure function of its arguments."
  ;; whole sector at (120,40), cold header
  (let ((lay (cistern-view--layout 120 40 34 16 '(5 . 5))))
    (cl-assert (eql (plist-get lay :header-lines) 3) t "header-lines 3")
    (cl-assert (equal (plist-get lay :map-origin) '(4 . 0)) t "origin after header")
    (cl-assert (eql (plist-get lay :map-cols) 34) t "whole sector width")
    (cl-assert (eql (plist-get lay :map-lines) 16) t "whole sector height")
    (cl-assert (equal (plist-get lay :cam) '(0 . 0)) t "map fits: no camera shift")
    (cl-assert (eql (plist-get lay :legend-rows) 2) t "legend rows truthful"))
  ;; badge-row variant (WO1.1 parenthetical)
  (let ((lay (cistern-view--layout 120 40 34 16 '(5 . 5) t)))
    (cl-assert (eql (plist-get lay :header-lines) 4) t "badge variant 4")
    (cl-assert (equal (plist-get lay :map-origin) '(5 . 0)) t "origin tracks badge"))
  ;; larger-than-map: camera never shifts
  (let ((lay (cistern-view--layout 120 40 34 16 '(33 . 15))))
    (cl-assert (equal (plist-get lay :cam) '(0 . 0)) t "no shift when map fits"))
  ;; (80,24) over a 68×32 map: viewport absorbs the window, camera
  ;; clamps, cursor cell inside the viewport
  (let ((lay (cistern-view--layout 80 24 68 32 '(40 . 20))))
    (cl-assert (eql (plist-get lay :map-cols) 68) t "width fits")
    (cl-assert (eql (plist-get lay :map-lines) 21) t "height absorbed (24-3)")
    (cl-assert (equal (plist-get lay :cam) '(0 . 10)) t "camera clamped")
    (cl-assert (and (< 40 (plist-get lay :map-cols))
                    (< (- 20 10) (plist-get lay :map-lines)))
                t "cursor inside viewport"))
  ;; clamp at the map edges
  (let ((lay (cistern-view--layout 80 24 68 32 '(3 . 3))))
    (cl-assert (equal (plist-get lay :cam) '(0 . 0)) t "top-left clamp"))
  (let ((lay (cistern-view--layout 80 24 68 32 '(67 . 31))))
    (cl-assert (equal (plist-get lay :cam) '(0 . 11)) t "bottom-right clamp"))
  ;; a window too small for 34×16 keeps full map rows (W1.1 bounds)
  (let ((lay (cistern-view--layout 30 18 34 16 '(5 . 5))))
    (cl-assert (eql (plist-get lay :map-cols) 34) t "never clipped below 34")
    (cl-assert (eql (plist-get lay :map-lines) 16) t "never clipped below 16"))
  ;; purity: same arguments, same LAY
  (cl-assert (equal (cistern-view--layout 80 24 68 32 '(40 . 20))
                    (cistern-view--layout 80 24 68 32 '(40 . 20)))
              t "pure derivation"))

(defun cistern-test-v6-01-roundtrip ()
  "WO1.2: for every cell of the RENDERED map at three synthetic
sizes, `cistern-view--cell-at' of its rendered position round-trips
to the original cell through the SAME LAY object — and the
driver's two LAY call sites share one derivation (A-WO1.2)."
  (let ((st (cistern-test-v6-01--big-fixture)))
    (dolist (size '((80 24) (50 22) (120 40)))
      (let* ((lay (cistern-view--layout (nth 0 size) (nth 1 size)
                                        (cistern-st-w st) (cistern-st-h st)
                                        (cistern-st-cursor st)))
             (origin (car (plist-get lay :map-origin)))
             (cam (plist-get lay :cam))
             (cols (plist-get lay :map-cols))
             (lines (plist-get lay :map-lines))
             (rows (split-string (cistern-view--render st lay) "\n")))
        ;; the render consumed the SAME LAY: map rows are exactly
        ;; the viewport, starting at :map-origin
        (dotimes (ry lines)
          (let ((row (nth (+ (1- origin) ry) rows)))
            (cl-assert (and row (= (length row) cols))
                       t "render row %d is a %d-col viewport row" ry cols))
          (dotimes (rx cols)
            (cl-assert (equal (cistern-view--cell-at
                               st lay (+ origin ry) rx)
                              (cons (+ (car cam) rx) (+ (cdr cam) ry)))
                        t "round trip (%d,%d) at %S" rx ry size)))))
    ;; A-WO1.2: the driver derives LAY at both call sites from the
    ;; same function (refresh + click)
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "src/cistern.el" cistern-test-v6--root))
      (let ((n 0) (pos 0) (s (buffer-string)))
        (while (string-match "cistern--current-lay" s pos)
          (setq n (1+ n) pos (match-end 0)))
        (cl-assert (>= n 2)
                   t "refresh and click share the LAY derivation")))))

(defun cistern-test-v6-01-gui ()
  "WO1.4 (L-076 pattern): on a real frame, resizing through three
sizes re-renders each time and a synthetic click at a rendered
glyph maps back to the right cell after every resize.  SKIPPED in
pure batch."
  (if (not (display-graphic-p))
      (message "cistern-test-v6-01-gui: SKIPPED (no display) — registered, suite stays green")
    (let* ((st (cistern-test-v6-01--big-fixture))
           (saved cistern--st)
           (buf (get-buffer-create "*cistern*"))
           (frm (make-frame '((width . 100) (height . 40))))
           (win (frame-selected-window frm)))
      (unwind-protect
          (progn
            (setq cistern--st st)
            (set-window-buffer win buf)
            (with-current-buffer buf
              (unless (derived-mode-p 'cistern-mode) (cistern-mode))
              (cistern--refresh))
            (dolist (dims '((60 . 24) (90 . 30) (70 . 26)))
              (set-frame-size frm (car dims) (cdr dims))
              (sit-for 0.3 t)          ; the deferred resize refresh runs
              (with-current-buffer buf
                (let* ((lay (cistern--current-lay st))
                       (expect (substring-no-properties
                                (cistern-view--render st lay))))
                  (cl-assert (equal (substring-no-properties (buffer-string))
                                    expect)
                             t "re-rendered at %S" dims)
                  ;; a synthetic click at a rendered glyph maps back
                  (goto-char (point-min))
                  (forward-line (1- (car (plist-get lay :map-origin))))
                  (forward-char 3)
                  (cl-assert (equal
                              (cistern-view--cell-at
                               st lay (line-number-at-pos (point))
                               (current-column))
                              (cons (+ (car (plist-get lay :cam)) 3)
                                    (cdr (plist-get lay :cam))))
                             t "click remap at %S" dims)))))
        (setq cistern--st saved)
        (delete-frame frm)
        (kill-buffer buf)))))

;;; --- V6-02: header strip reflow — priority elision (WO1.3) ----------------

(defconst cistern-test-v6-02--idle-pressure
  "LINES NOMINAL — THE STRUCTURE DOES NOT CARE"
  "The S2 idle verdict (byte-identical when present).")

(defun cistern-test-v6-02-header ()
  "WO1.3: no permanent row exceeds a narrow synthetic width; the
strip keeps its identity segment and elides deepest-priority
first; the S2 pressure words are byte-identical when present and
the idle line is dropped (never rewritten) in a too-narrow
window; wide widths render byte-identical to the v5 strip; new
elision copy lives in `cistern--copy' (Q11)."
  ;; wide widths: zero elision, byte-identical to the default render
  (let* ((st (cistern--new-game 42))
         (wide (substring-no-properties
                (cistern-view--render
                 st (cistern-view--layout 120 40 34 16 '(0 . 0)))))
         (def (substring-no-properties (cistern-view--render st))))
    (cl-assert (equal wide def) t "120-col render == default render"))
  ;; narrow 60: everything fits; the idle pressure line is PRESENT and
  ;; byte-identical
  (let* ((st (cistern--new-game 42))
         (rows (split-string
                (cistern-view--render
                 st (cistern-view--layout 60 20 34 16 '(0 . 0))) "\n")))
    (dolist (r rows)
      (cl-assert (<= (length r) 60) t "row over 60 cols: %S" r))
    (cl-assert (cl-find cistern-test-v6-02--idle-pressure rows
                        :test (lambda (s row) (string-match-p s row)))
                t "idle pressure byte-identical at 60"))
  ;; narrow 40: rows still fit; idle line DROPPED (never rewritten);
  ;; identity strip survives, deep segments elided; [?] help pointer
  (let* ((st (cistern--new-game 42))
         (rows (split-string
                (cistern-view--render
                 st (cistern-view--layout 40 20 34 16 '(0 . 0))) "\n")))
    (dolist (r rows)
      (cl-assert (<= (length r) 40) t "row over 40 cols: %S" r))
    (cl-assert (string-match-p "TICK" (nth 0 rows)) t "identity survives")
    (cl-assert (not (string-match-p "SCORE" (nth 0 rows)))
                t "deepest strip segment elided first")
    (cl-assert (not (cl-find "LINES NOM" rows
                             :test (lambda (s row) (string-match-p s row))))
                t "idle pressure dropped, not rewritten")
    (cl-assert (cl-find (cdr (assq 'help-pointer cistern--copy)) rows
                        :test (lambda (s row) (string-match-p s row)))
                t "help elides to the [?] pointer"))
  ;; S2 alert: the pressure verdict, when present, is byte-identical
  ;; (a live alert is never rewritten, never dropped)
  (let* ((st (cistern--new-game 42))
         (lay (cistern-view--layout 60 20 34 16 '(0 . 0)))
         (rows (split-string (cistern-view--render st lay) "\n")))
    (setf (cistern-st-contam st) 0)
    (puthash (cons 5 2) (list :load 85) (cistern-st-tanks st))
    (setq rows (split-string (cistern-view--render st lay) "\n"))
    (cl-assert (cl-find (cistern-view--pressure-line st) rows
                        :test (lambda (s row) (string= s row)))
                t "alert verdict present, byte-identical: %S"
                (cistern-view--pressure-line st)))
  ;; Q11: the two new elision strings are copy-table keys, not literals
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern-domain.el" cistern-test-v6--root))
    (cl-assert (string-match-p "(help-pointer" (buffer-string))
               t "help pointer is a copy key")
    (cl-assert (string-match-p "(legend-pointer" (buffer-string))
               t "legend pointer is a copy key")))

(provide 'test-v6)
;;; test-v6.el ends here
