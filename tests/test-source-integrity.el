;;; tests/test-source-integrity.el --- shared infra: reader form-span
;;; guard (L-026) -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst cistern-test-integrity--root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name)))))

(defconst cistern-test-integrity--max-span 10000
  "Max chars for one top-level form.  The legitimate maximum is the
selftest defun (~8.8k); the L-026 load-merge incident produced a
25k form.  10k sits between with margin.")

(defconst cistern-test-integrity--heads
  '(defun defconst defvar defcustom defface defgroup
     define-derived-mode require provide cl-defstruct)
  "Every expected top-level head in src/.")

(defun cistern-test-source-integrity ()
  "Reader-load every src/*.el and walk top-level forms (L-026):
no form may exceed `cistern-test-integrity--max-span' chars — a
larger span means the reader merged forms, i.e. a missing/extra
paren that check-parens cannot see — and every top-level form must
be one of the expected defining heads.  check-parens validates
list balance only; this validates per-form integrity."
  (dolist (f (directory-files (expand-file-name "src"
                                                cistern-test-integrity--root)
                              t "\\.el\\'"))
    (with-temp-buffer
      (insert-file-contents f)
      (emacs-lisp-mode)
      (goto-char (point-min))
      (condition-case e
          (while t
            (let ((start (point)) (form (read (current-buffer))))
              (cl-assert (<= (- (point) start)
                             cistern-test-integrity--max-span)
                         nil "%s: top-level form spans %d chars — reader merged forms (L-026)"
                         (file-name-nondirectory f) (- (point) start))
              (cl-assert (and (consp form)
                              (memq (car form) cistern-test-integrity--heads))
                         nil "%s: unexpected top-level head %S"
                         (file-name-nondirectory f) (car form))))
        (end-of-file nil)
        (error (cl-assert nil nil "%s: reader error %S"
                          (file-name-nondirectory f) e)))))
  (message "CISTERN-SOURCE-INTEGRITY-OK"))

(provide 'test-source-integrity)
;;; tests/test-source-integrity.el ends here
