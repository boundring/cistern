;;; tools/gen-bank.el --- V4-18: the bank GENERATOR (STORY-ENGINE §5) -*- lexical-binding: t; -*-

;; Batch only:
;;   emacs -Q --batch -l tools/gen-bank.el \
;;     --eval '(cistern-gen-bank-run :kind quirk :seed 8402 :count 4
;;                                   :out "data/banks/gen-quirks.el")'
;;
;; Determinism (§5.2): draws from seed ⊕ 0x6A6E through the domain's
;; cistern--stream-next recurrence with the shared bit-6 slice — no
;; second RNG.  Same args ⇒ byte-identical file; entries emitted
;; SORTED by :id so regeneration diffs are stable.  Composition
;; never emits anything the loader would reject: the script loads
;; its own output through cistern--banks-load BEFORE writing the
;; real file (§5.3); a rejected composition aborts nonzero — one
;; launch, no probe loops (P-series).

(require 'cl-lib)
(require 'cistern-domain
         (and load-file-name
              (expand-file-name "src/cistern-domain.el"
                                (file-name-directory
                                 (directory-file-name
                                  (file-name-directory load-file-name))))))

(defconst cistern-gen-bank-version "gen-bank 1.0")

(defconst cistern-gen-bank-stream-mix #x6A6E
  "Generator stream mix (STORY §8.2): a fixed literal OUTSIDE the
runtime stream-id space — the generator never shares a stream with
the running game.")

;; ---------------------------------------------------------------------------
;; §5.3/§5.5: curated fragment pools — minimal, inside the script,
;; never shipped as runtime data.  Pool growth is content work.

(defconst cistern-gen-bank-keywords
  '((kw-block-93 :word "BLOCK-93" :class place)
    (kw-sump :word "SUMP TERRACE" :class place)
    (kw-sector-7g :word "SECTOR 7-G" :class sector)
    (kw-unit-ax :word "UNIT AX-4" :class designation))
  "Keyword entries: generator-side naming tokens, substituted into
copy strings at generation time, never at runtime (STORY §4.2).")

(defconst cistern-gen-bank-quirk-templates
  (list '(:id quirk-tight :context tolerance
          :template "TOLERANCE FILED AS TIGHT — WITHIN SPEC")
        '(:id quirk-thorough :context integrity
          :template "WORKER READS THE DOSSIER TWICE")
        '(:id quirk-loner :context standing
          :template "PREFERS UNASSIGNED SECTORS — NOTED")
        '(:id quirk-quiet :context tolerance
          :template "NO COMPLAINTS ON RECORD — SUSPICIOUS"))
  "Four quirk templates (STORY §5.5).")

(defconst cistern-gen-bank-flavor-templates
  (list '(:id fl-condensation :when act-2
          :template "CONDENSATION ON UPPER TERRACE — NOTED")
        '(:id fl-valve :when act-1
          :template "DISTANT VALVE NOISE — ACCOUNTED FOR")
        '(:id fl-light :when act-1
          :template "STRIP LIGHTS HOLD THEIR TONE")
        '(:id fl-dust :when act-2
          :template "DUST SETTLES IN ASSIGNED PATTERNS")
        '(:id fl-hum :when act-3
          :template "THE HUM HAS A RHYTHM TODAY")
        '(:id fl-pool :when act-3
          :template "STANDING WATER AT THE LOW END — MAPPED"))
  "Six flavor lines (STORY §5.5).")

(defconst cistern-gen-bank-scenario-skeleton
  (list :id 'sk-%s
        :premise 'story-%s-premise
        :acts 3
        :goal-mod '(:target-mod ((relieves-served . 2)))
        :hooks
        (list '(:id hook-%s-creak :act 1 :window '(20 . 90)
               :condition '(event leak) :requires nil
               :matrix 'matrix-%s :resolve-copy 'story-%s-creak)
              '(:id hook-%s-verdict :act 3 :window '(240 . 99999)
               :condition '(tick) :requires 'hook-%s-creak
               :matrix 'matrix-%s :resolve-copy 'story-%s-verdict))
        :matrices
        (list (list :id 'matrix-%s :difficulty 11 :stat 'integrity
                    :act-mods '(0 2 4)
                    :outcomes
                    (list '(:line-key story-%s-fail :effect none :arg nil)
                          '(:line-key story-%s-fail :effect none :arg nil)
                          '(:line-key story-%s-pass :effect none :arg nil)
                          '(:line-key story-%s-verdict :effect none
                                      :arg nil))))
        :tiers '(60 30 10)
        :events
        (list (list :id (quote ev-%s-drip) :tier 'occasional :trigger 'leak
                    :matrix 'matrix-%s :copy-key 'story-%s-drip)))
  "The one scenario skeleton (STORY §5.5): a hook graph over the
pinned condition grammar, one matrix, four outcomes.  Every symbol
containing a `%s' slot takes the entry's id prefix at composition.")

(defconst cistern-gen-bank-scenario-copy
  '(("creak" . "WATCH ORDERED — SEAM (%d,%d) UNDER OBSERVATION")
    ("verdict" . "SEAL VERDICT: %s — WATCH DISBANDED")
    ("pass" . "STRUCTURE HOLDS")
    ("fail" . "STRUCTURE WEEPS")
    ("drip" . "A DRIP IS LOGGED — NOBODY IS DISPATCHED"))
  "Scenario copy suffixes; the premise line carries the {KW} token
for keyword substitution (STORY §5.3).")

(defun cistern-gen-bank--subst (form prefix)
  "Replace every symbol containing a `%s' slot with the
PREFIX-instantiated symbol (pure rebuild of quoted data)."
  (cond
   ((symbolp form)
    (if (string-match-p "%s" (symbol-name form))
        (intern (replace-regexp-in-string "%s" prefix
                                          (symbol-name form)))
      form))
   ((consp form)
    (cons (cistern-gen-bank--subst (car form) prefix)
          (cistern-gen-bank--subst (cdr form) prefix)))
   (t form)))

(defun cistern-gen-bank--draw (state n)
  "Draw in [0,N) from the generator's own position cell (car
STATE): advance, then the shared bit-6 slice."
  (let* ((p (cistern--stream-next (car state)))
         (v (% (ash p -6) n)))
    (setcar state p)
    v))

(defun cistern-gen-bank--scenario-entry (state i)
  (let* ((prefix (format "s%d" i))
         (kw (nth (cistern-gen-bank--draw state
                                          (length
                                           cistern-gen-bank-keywords))
                  cistern-gen-bank-keywords))
         (skel (cistern-gen-bank--subst cistern-gen-bank-scenario-skeleton
                                        prefix))
         (copy
          (cons (cons (intern (format "story-%s-premise" prefix))
                      (replace-regexp-in-string
                       "{KW}" (plist-get kw :word)
                       "PRESSURE LOGGED BEHIND {KW} WALL"))
                (mapcar (lambda (pair)
                          (cons (intern (format "story-%s-%s"
                                                prefix (car pair)))
                                (cdr pair)))
                        cistern-gen-bank-scenario-copy))))
    (list :id (plist-get skel :id)
          :premise (plist-get skel :premise)
          :acts 3
          :goal-mod '(:target-mod ((relieves-served . 2)))
          :hooks (plist-get skel :hooks)
          :matrices (plist-get skel :matrices)
          :tiers '(60 30 10)
          :events (plist-get skel :events)
          :bank-copy copy)))

(defun cistern-gen-bank--quirk-entry (state i)
  (let* ((tpl (nth (cistern-gen-bank--draw state
                                           (length
                                            cistern-gen-bank-quirk-templates))
                   cistern-gen-bank-quirk-templates))
         (id (intern (format "%s-%d" (plist-get tpl :id) i)))
         (key (intern (format "story-%s-%d" (plist-get tpl :id) i))))
    (list :id id
          :context (plist-get tpl :context)
          :copy-key key
          :bank-copy (list (cons key (plist-get tpl :template))))))

(defun cistern-gen-bank--flavor-entry (state i)
  (let* ((tpl (nth (cistern-gen-bank--draw state
                                           (length
                                            cistern-gen-bank-flavor-templates))
                   cistern-gen-bank-flavor-templates))
         (id (intern (format "%s-%d" (plist-get tpl :id) i)))
         (key (intern (format "story-%s-%d" (plist-get tpl :id) i))))
    (list :id id
          :when (plist-get tpl :when)
          :copy-key key
          :bank-copy (list (cons key (plist-get tpl :template))))))

(defun cistern-gen-bank--build-bank (kind seed count)
  "Compose and assemble the bank plist for KIND/SEED/COUNT."
  (let* ((state (list (logxor seed cistern-gen-bank-stream-mix)))
         (entries nil) (i 0) (copy nil))
    (while (< i count)
      (let ((e (pcase kind
                 ('quirk (cistern-gen-bank--quirk-entry state i))
                 ('flavor (cistern-gen-bank--flavor-entry state i))
                 ('scenario (cistern-gen-bank--scenario-entry state i)))))
        (setq copy (append copy (plist-get e :bank-copy)))
        (push (cistern-gen-bank--strip-copy e) entries))
      (setq i (1+ i)))
    (setq entries (nreverse entries))
    (setq entries (sort entries
                        (lambda (a b)
                          (string< (symbol-name (plist-get a :id))
                                   (symbol-name (plist-get b :id))))))
    (list :kind kind :version "1"
          :generator (format "%s seed %d" cistern-gen-bank-version seed)
          :copy copy :entries entries)))

(defun cistern-gen-bank--strip-copy (e)
  "Drop the transient :bank-copy pair from a composed entry."
  (let ((out nil))
    (while e
      (unless (eq (car e) :bank-copy)
        ;; append the pair at the end — plist pairs must never be
        ;; element-reversed (nreverse would flip key/value)
        (setq out (append out (list (car e) (cadr e)))))
      (setq e (cddr e)))
    out))

(defun cistern-gen-bank-run (&rest args)
  "STORY §5.1 entry point.  Composes, loads its own output through
the REAL loader (self-validation, §5.3), and only then writes the
final file.  Same args ⇒ byte-identical output (§5.2)."
  (let* ((kind (plist-get args :kind))
         (seed (plist-get args :seed))
         (count (plist-get args :count))
         (out (plist-get args :out)))
    (unless (and kind seed count out)
      (error "GENERATOR: :kind :seed :count :out all required"))
    (condition-case err
        (let* ((bank (cistern-gen-bank--build-bank kind seed count))
               (sym (intern (format "cistern-bank-%s-%d" kind seed)))
               (text (concat ";;; -*- lexical-binding: t; -*- generated by "
                             (format "%s seed %d" cistern-gen-bank-version
                                     seed)
                             " — pure data, do not edit\n"
                             (format "(defconst %s\n  '%S)\n" sym bank))))
          ;; self-validation on a temp copy (§5.3): the loader's
          ;; fail-first walk is the post-check
          (let ((tmp (make-temp-file "cistern-genbank")))
            (with-temp-file tmp (insert text))
            (unwind-protect
                (condition-case e
                    (progn
                      (setq cistern--banks nil cistern--story-copy nil)
                      ;; banks-load performs its own (load) — no pre-load,
                      ;; or the new-symbol diff would find nothing
                      (cistern--banks-load (list tmp))
                      (delete-file tmp)
                      (with-temp-file out (insert text))
                      (princ ""))
                  (error
                   (delete-file tmp)
                   (princ (format "GENERATOR FAILED: %S\n" e))
                   (kill-emacs 1))))))
      (error (princ (format "GENERATOR FAILED: %S\n" err))
             (kill-emacs 1)))))

(provide 'cistern-gen-bank)
;;; tools/gen-bank.el ends here
