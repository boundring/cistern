;;; tests/test-v5.el --- CISTERN v5 wave 1: the violent base -*- lexical-binding: t; -*-

;; Batch tests for docs/v5/V5-SPEC.md WAVE 1 (V5-01..V5-07, build
;; order), one entry per directive acceptance, registered in
;; tests/run.el.  Reds before greens per PROCESS; ledger entries in
;; docs/FAILURE-LEDGER.md (continuing past L-095).

(require 'cl-lib)

;; Repo root pinned at load time (L-008 pattern from test-v4).
(defconst cistern-test-v5--root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (error "test-v5 must be loaded from a file"))))))

(add-to-list 'load-path (expand-file-name "src" cistern-test-v5--root))
(load (expand-file-name "src/cistern-domain.el" cistern-test-v5--root))
(load (expand-file-name "src/cistern-game.el" cistern-test-v5--root))

;;; --- V5-01: entity struct + dossiers + stream 4 (CB1, CB13 partial) -------------

(defun cistern-test-v5-01--expected-dossiers ()
  "Independently derive the three raiders' dossiers from the RAW
stream-4 recurrence (20260826, mid-bits slice): 16 d6 per raider,
4d6-drop-lowest x 4, in the pinned call order.  COMBAT §7's
worked-example ledger is reachable for g1 — (11 8 10 15) — and is
pinned as a literal in the test; the g2/g3 rows of that table do
not exist in the real stream (doc fixture drift, ledgered L-096),
so the procedure itself is the binding contract for them."
  (let ((p 20260826) (expected nil))
    (dotimes (_ 3)
      (let ((blocks nil))
        (dotimes (_ 4)
          (let (rolls)
            (dotimes (_ 4)
              (setq p (cistern--stream-next p))
              (push (1+ (% (ash p -6) 6)) rolls))
            (setq rolls (sort rolls #'<))
            (push (+ (nth 1 rolls) (nth 2 rolls) (nth 3 rolls))
                  blocks)))
        (setq expected (append expected (list (reverse blocks))))))
    expected))

(defun cistern-test-v5-01-entities ()
  "V5-01 (CB1): seed-20260830 pinned raid draws spawn three warband
entities `g1..g3' with 4d6-drop-lowest stats computed from stream 4
in the pinned call order, hp = kind-base + GRIT mod, spawn-appended
to `hostiles'.  Worker struct carries `hp' and a stable spawn-index
and the identity glyph reads the STORED index, not list position."
  (let ((st (cistern--new-game 20260830)))
    ;; stream 4 initializes at seed ⊕ 4 (COMBAT §5.2: 20260830 ⊕ 4)
    (cl-assert (= (cistern-st-combat-pos st) 20260826)
               t "combat-pos inits to seed xor 4")
    (cl-assert (null (cistern-st-hostiles st))
               t "a fresh sector has no hostiles")
    ;; three warband spawns, pinned call order
    (cistern--spawn-enemy st 'warband 'warband 2 2)
    (cistern--spawn-enemy st 'warband 'warband 2 3)
    (cistern--spawn-enemy st 'warband 'warband 3 2)
    (cistern-test-v5-01--check-hostiles st))
  ;; CB13 partial: two runs of one seed → identical hostiles + combat-pos
  (let ((hash1 (cistern-test-v5-01--run-hash))
        (hash2 (cistern-test-v5-01--run-hash)))
    (cl-assert (string= hash1 hash2)
               t "two runs → identical hostiles and combat-pos"))
  ;; the identity pin: the glyph reads the stored spawn-index, so a
  ;; list-position change renames NOBODY (fail-first for C4)
  (let ((st (cistern--new-game 7)))
    (let ((b (nth 1 (cistern-st-creators st))))
      (setf (cistern-st-creators st) (list b))
      (cl-assert (equal (cistern--worker-glyph st b) "β")
                 t "β keeps β after α leaves the list")))
  ;; every fresh worker carries a stable spawn-index
  (let ((st (cistern--new-game 9)))
    (cl-assert (equal (mapcar #'cistern--worker-spawn-idx
                              (cistern-st-creators st))
                      '(0 1 2 3))
               t "procgen workers get spawn-indexes 0..3"))
  (message "CISTERN-V5-01-OK"))

(defun cistern-test-v5-01--check-hostiles (st)
  "The CB1 entity assertions over ST's spawned raiders."
  (let ((hs (cistern-st-hostiles st))
        (want (cistern-test-v5-01--expected-dossiers)))
    (cl-assert (= (length hs) 3) t "three entities spawn-appended")
    (cl-assert (equal (cistern--enemy-id (nth 0 hs)) "g1")
               t "ids are the sequential g<N> counter")
    (cl-assert (equal (cistern--enemy-id (nth 1 hs)) "g2") t "g2")
    (cl-assert (equal (cistern--enemy-id (nth 2 hs)) "g3") t "g3")
    ;; g1 pinned to COMBAT §7's worked-example ledger literal
    (cl-assert (equal (nth 0 want) '(11 8 10 15))
               t "g1 matches COMBAT §7's worked-example ledger")
    (dotimes (i 3)
      (cl-assert (equal (cistern--enemy-stats (nth i hs)) (nth i want))
                 t "g%d stats match the 4d6-drop-lowest draw" (1+ i))
      ;; hp = kind-base (6) + GRIT mod, from the SAME dossiers
      (cl-assert (= (cistern--enemy-hp (nth i hs))
                    (+ 6 (cistern--rpg-mod (nth 1 (nth i want)))))
                 t "g%d hp = kind-base + GRIT mod" (1+ i)))
    ;; stream 4 advanced by exactly 48 d6 draws (3 raiders x 16)
    (let ((p 20260826))
      (dotimes (_ 48) (setq p (cistern--stream-next p)))
      (cl-assert (= (cistern-st-combat-pos st) p)
                 t "combat-pos advanced by exactly the 48 dossier d6"))))

(defun cistern-test-v5-01--run-hash ()
  "One fresh 20260830 run with three raiders: a stable hash of the
hostiles and the stream-4 position."
  (secure-hash
   'md5 (prin1-to-string
         (let ((st (cistern--new-game 20260830)))
           (cistern--spawn-enemy st 'warband 'warband 2 2)
           (cistern--spawn-enemy st 'warband 'warband 2 3)
           (cistern--spawn-enemy st 'warband 'warband 3 2)
           (list (cistern-st-hostiles st)
                 (cistern-st-combat-pos st))))))
