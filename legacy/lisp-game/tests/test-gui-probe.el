;;; tests/test-gui-probe.el --- L-076: every rendered glyph one cell wide -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-gui--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-gui-probe must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-gui--root))
(load (expand-file-name "src/cistern.el" cistern-test-gui--root))

(defun cistern-test-gui-cell-width ()
  "L-076 GUI probe: in the game buffer, with `cistern-mode' active,
every rendered glyph (tile table, pipe shapes, dead pipe, tank,
Greek workers) measures EXACTLY one ASCII cell advance.  Skips
gracefully (message, still registered) in pure batch."
  (if (not (display-graphic-p))
      (message "cistern-test-gui-cell-width: SKIPPED (no display) — probe registered, suite stays green")
    ;; GUI: build the game render on a real frame, then measure the
    ;; actual rendered font advance of every unique glyph.
    (let* ((st (cistern--new-game 42))
           (buf (get-buffer-create " *cistern-gui-probe*"))
           (frm (make-frame '((width . 110) (height . 42))))
           (win (frame-selected-window frm))
           bad)
      (unwind-protect
          (progn
            (set-window-buffer win buf)
            (with-current-buffer buf
              (cistern-mode)          ; applies the L-076 fontset pin
              (let ((inhibit-read-only t))
                (erase-buffer)
                (insert (cistern-view--render st))
                ;; guarantee full suspect coverage: pipe shapes, dead,
                ;; table glyphs, workers — even when seed 42 lacks them
                (goto-char (point-max))
                ;; V4-05 (A3.2): coverage extended with ▚ ░ ╬ before
                ;; the glyphs shipped (SURFACE S3.1 rule 3)
                (insert "\n┌┐└┘┼│─╌◆▣▓▒Ω·αβγδεζηθ▚░╬")
                (goto-char (point-min))))
            (sit-for 0.2 t)
            (let ((cellw (with-selected-frame frm (default-font-width)))
                  (seen (make-hash-table :test 'eql)))
              (with-current-buffer buf
                (goto-char (point-min))
                (while (< (point) (point-max))
                  (let ((ch (following-char)))
                    (unless (or (memq ch '(?  ?\n)) (gethash ch seen))
                      (puthash ch t seen)
                      ;; ground truth: the font the real display
                      ;; machinery resolves for this char in THIS
                      ;; window/buffer (font-info index 10 is
                      ;; SPACE-WIDTH on this Emacs; mono => the advance)
                      (let* ((f (font-at (point) win))
                             (adv (aref (font-info (font-xlfd-name f) frm) 10)))
                        (unless (eql adv cellw)
                          (push (cons ch adv) bad)))))
                  (forward-char 1)))
              (cl-assert (not bad) t
                         "glyphs off one-cell width: %S" bad)
              (message "cistern-test-gui-cell-width: %d unique glyphs all %dpx (pin=%s)"
                       (hash-table-count seen) cellw cistern--glyph-fontset)))
        (delete-frame frm)
        (kill-buffer buf)))))

(provide 'test-gui-probe)
;;; tests/test-gui-probe.el ends here
