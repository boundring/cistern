;;; tests/test-r2-keymap.el --- R2: arrow-key-only keymap, headless -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Repo root pinned at load time (L-008: `load-file-name' is only
;; bound during load; `-f' callers after `-l' see nil).
(defconst cistern-test-r2--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-r2-keymap must be loaded from a file"))))))

;; The driver `require's the inner layers; make them resolvable when
;; this file is loaded standalone (the runner loads src/ explicitly
;; first, so the add is a no-op there).
(add-to-list 'load-path (expand-file-name "src" cistern-test-r2--root))
(load (expand-file-name "src/cistern.el" cistern-test-r2--root))

(defun cistern-test-r2-keymap ()
  "R2 acceptance (spec §4): no binding for \"h\",\"j\",\"k\",\"l\"
as movement; the four arrow keys are bound to cursor commands;
grep-level check that no `cistern-cursor-north/south/west/east'
aliasing to hjkl remains in the driver."
  ;; hjkl unbound entirely — not as movement, not as verbs
  (dolist (key '("h" "j" "k" "l"))
    (cl-assert (null (lookup-key cistern-mode-map key))
               t "hjkl must be unbound: %s" key))
  ;; the four arrows are bound to the cursor commands
  (cl-assert (eq (lookup-key cistern-mode-map (kbd "<up>"))
                 'cistern-cursor-north)
             t "arrow up must move north")
  (cl-assert (eq (lookup-key cistern-mode-map (kbd "<down>"))
                 'cistern-cursor-south)
             t "arrow down must move south")
  (cl-assert (eq (lookup-key cistern-mode-map (kbd "<left>"))
                 'cistern-cursor-west)
             t "arrow left must move west")
  (cl-assert (eq (lookup-key cistern-mode-map (kbd "<right>"))
                 'cistern-cursor-east)
             t "arrow right must move east")
  ;; grep-level: no `define-key' in the driver binds a single hjkl
  ;; character to anything (cursor-command aliasing included)
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "src/cistern.el" cistern-test-r2--root))
    (cl-assert (not (re-search-forward "define-key[^\n]*\"[hjkl]\"" nil t))
               t "driver binds an hjkl key")))

(provide 'test-r2-keymap)
;;; tests/test-r2-keymap.el ends here
