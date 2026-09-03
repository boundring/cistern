;;; domain-tile-table.el --- R3(b): tile table is the sole source -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-kinds '(floor wall door ore hazard pipe toilet tank))

(defun cistern-test--strip-table (txt)
  "Remove the cistern--tile-table defconst form from TXT."
  (let ((i (string-match "(defconst cistern--tile-table" txt)))
    (if (not i)
        txt
      (with-temp-buffer
        (insert txt)
        (goto-char (1+ i))              ; at the open paren
        ;; skip the whole balanced form
        (condition-case nil
            (forward-sexp)
          (scan-error nil))
        (delete-region i (point))
        (buffer-string)))))

(defun cistern-test--any-kind-symbol (form)
  "Non-nil if FORM (recursively) contains a cell-kind symbol."
  (cond ((symbolp form)
         (memq form '(floor wall door ore hazard pipe toilet tank)))
        ((consp form)
         (or (cistern-test--any-kind-symbol (car form))
             (cistern-test--any-kind-symbol (cdr form))))
        (t nil)))

(defun cistern-test-table-sourcing ()
  "R3(b): glyph choice and passability both route through
cistern--tile-table, and no cell-kind pcase/case exists outside the
table definition in src/cistern-domain.el."
  ;; (a) every kind has a table entry; accessors resolve through it —
  ;; mutate the table and the accessors must follow.
  (dolist (k cistern-test-kinds)
    (cl-assert (assq k cistern--tile-table) nil "kind %S missing from table" k))
  (let ((entry (assq 'wall cistern--tile-table))
        (saved (cdr (assq 'wall cistern--tile-table))))
    (unwind-protect
        (progn
          (setcdr entry '(:glyph "X" :passable t :buildable nil
                          :firebreak t :conn nil))
          (cl-assert (equal (cistern--tile-glyph 'wall) "X")
                     nil "glyph accessor did not follow the table")
          (cl-assert (cistern--tile-passable-p 'wall)
                     nil "passability accessor did not follow the table"))
      (setcdr entry saved)))
  ;; live cells route through the table too
  (let ((st (cistern--new-game 20260830)))
    (cl-assert (equal (cistern--tile-glyph (cistern--cell st 0 0))
                      (cistern--tile-glyph 'wall)))
    (cl-assert (eq (cistern--tile-passable-p (cistern--cell st 3 3))
                   (cistern--tile-passable-p 'toilet))))
  ;; (b) static check: no cell-kind pcase/cl-case/case outside the table
  (with-temp-buffer
    (insert-file-contents (expand-file-name "src/cistern-domain.el"))
    (let ((txt (cistern-test--strip-table (buffer-string)))
          (found nil))
      (with-temp-buffer
        (insert txt)
        (goto-char (point-min))
        (condition-case nil
            (while (not found)
              (let ((form (read (current-buffer))))
                (when (and (consp form)
                           (memq (car form) '(pcase cl-case case))
                           (cistern-test--any-kind-symbol form))
                  (setq found form))))
          (end-of-file nil)))
      (cl-assert (not found)
                 nil "cell-kind pcase/case outside the tile table: %S"
                 found))))

(provide 'domain-tile-table)
;;; domain-tile-table.el ends here