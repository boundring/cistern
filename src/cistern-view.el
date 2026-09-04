;;; cistern-view.el --- View adapter: buffer geometry (Pair 2 slice) -*- lexical-binding: t; -*-

;; Adapter layer (DESIGN-SPEC §3.3): projection only.  Pair 2 ships
;; just the pure buffer→cell geometry the driver's mouse handler
;; routes through; the glyph/face projection and render composition
;; are Pair 4 (plan 02 §2).

(require 'cistern-domain)

(defconst cistern-view--header-lines 3
  "Rendered lines above the map rows (legacy :731-748: status,
help, glyph legend).  Buffer line header-lines+1 is map row 0.")

(defun cistern-view--cell-at (st line col)
  "Pure buffer geometry: 1-based buffer LINE and 0-based COL →
(X . Y) grid cell; nil outside the map (clicks on header/log lines
are ignored by the driver).  Used by the driver's mouse handler;
batch-tested."
  (let ((x col)
        (y (- line 1 cistern-view--header-lines)))
    (when (and (>= x 0) (< x (cistern-st-w st))
               (>= y 0) (< y (cistern-st-h st)))
      (cons x y))))

(provide 'cistern-view)
;;; cistern-view.el ends here
