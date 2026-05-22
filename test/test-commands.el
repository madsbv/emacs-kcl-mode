;;; test-commands.el --- Tests for kcl-mode commands and features -*- lexical-binding: t; -*-

;; Tests for: project root, compilation mode, which-function-mode, eval,
;; CLI commands, documentation lookup, tempo templates, flymake, transient

(require 'ert)
(require 'cl-lib)
(require 'kcl-mode)

;;; ──────────────────────────────────────────────
;;; Project Root
;;; ──────────────────────────────────────────────

(ert-deftest kcl-project-root-finds-kcl-mod ()
  "Should find project root when kcl.mod exists."
  (let* ((dir (make-temp-file "kcl-test-" t))
         (sub (expand-file-name "sub" dir))
         (mod-file (expand-file-name "kcl.mod" dir))
         (k-file (expand-file-name "main.k" sub)))
    (unwind-protect
        (progn
          (make-directory sub t)
          (with-temp-file mod-file (insert "[package]\n"))
          (with-temp-file k-file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect k-file)
            (kcl-mode)
            (should (string= (expand-file-name (kcl-project-root))
                              (file-name-as-directory dir)))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-project-root-nil-without-mod ()
  "Should return nil when no kcl.mod is found."
  (let* ((dir (make-temp-file "kcl-test-" t))
         (k-file (expand-file-name "main.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file k-file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect k-file)
            (kcl-mode)
            (should-not (kcl-project-root))
            (kill-buffer)))
      (delete-directory dir t))))

;;; ──────────────────────────────────────────────
;;; Compilation Mode
;;; ──────────────────────────────────────────────

(ert-deftest kcl-compilation-mode-defined ()
  "kcl-compilation-mode should be a derived compilation mode."
  (should (fboundp 'kcl-compilation-mode)))

(ert-deftest kcl-compilation-error-regexp-matches ()
  "Error regexp should match KCL-style error locations."
  (let ((line " --> /path/to/file.k:42:5"))
    (should (string-match (nth 1 kcl-compilation-error-regexp) line))
    (should (string= (match-string 1 line) "/path/to/file.k"))
    (should (string= (match-string 2 line) "42"))
    (should (string= (match-string 3 line) "5"))))

(ert-deftest kcl-compilation-error-regexp-relative ()
  "Error regexp should match relative file paths."
  (let ((line "  --> main.k:1:1"))
    (should (string-match (nth 1 kcl-compilation-error-regexp) line))
    (should (string= (match-string 1 line) "main.k"))))

(ert-deftest kcl-compilation-error-in-alist ()
  "KCL error regexp should be registered in compilation-error-regexp-alist."
  (require 'compile)
  (should (memq 'kcl compilation-error-regexp-alist))
  (should (assq 'kcl compilation-error-regexp-alist-alist)))

;;; ──────────────────────────────────────────────
;;; which-function-mode
;;; ──────────────────────────────────────────────

(ert-deftest kcl-which-function-schema ()
  "which-function should find schema at point."
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Foo:\n    x: int\n")
    (goto-char (point-min))
    (forward-line 1) ; inside schema body
    (should (string= (kcl-mode--which-function) "schema Foo"))))

(ert-deftest kcl-which-function-rule ()
  "which-function should find rule at point."
  (with-temp-buffer
    (kcl-mode)
    (insert "rule Bar:\n    x > 0\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (string= (kcl-mode--which-function) "rule Bar"))))

(ert-deftest kcl-which-function-nil-top-level ()
  "which-function should return nil at top level."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = 1\n")
    (goto-char (point-min))
    (should-not (kcl-mode--which-function))))

;;; ──────────────────────────────────────────────
;;; Eval commands
;;; ──────────────────────────────────────────────

(ert-deftest kcl-eval-output-format-default ()
  "Default output format should be yaml."
  (should (string= kcl-eval-output-format "yaml")))

(ert-deftest kcl-eval-buffer-no-file-error ()
  "kcl-eval-buffer should error when buffer has no file."
  (with-temp-buffer
    (kcl-mode)
    (should-error (kcl-eval-buffer) :type 'user-error)))

(ert-deftest kcl-eval-freeze-no-output-error ()
  "kcl-eval-freeze should error when no output buffer exists."
  (when (get-buffer "*kcl-output*")
    (kill-buffer "*kcl-output*"))
  (with-temp-buffer
    (kcl-mode)
    (should-error (kcl-eval-freeze) :type 'user-error)))

(ert-deftest kcl-eval-diff-no-snapshot-error ()
  "kcl-eval-diff should error when no snapshot is frozen."
  (with-temp-buffer
    (kcl-mode)
    (setq-local kcl--frozen-output nil)
    (should-error (kcl-eval-diff) :type 'user-error)))

(ert-deftest kcl-eval-buffer-runs-file ()
  "kcl-eval-buffer should produce output for a valid KCL file."
  (let* ((dir (make-temp-file "kcl-eval-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (kcl-eval-buffer)
            (let ((out-buf (get-buffer "*kcl-output*")))
              (should out-buf)
              (with-current-buffer out-buf
                (should (> (buffer-size) 0))
                ;; YAML output should contain "x: 1"
                (should (string-match-p "x: 1"
                                        (buffer-substring-no-properties
                                         (point-min) (point-max)))))
              (kill-buffer out-buf))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-eval-freeze-and-diff ()
  "Freeze and diff should work end-to-end."
  (let* ((dir (make-temp-file "kcl-eval-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            ;; Eval and freeze
            (kcl-eval-buffer)
            (kcl-eval-freeze)
            (should kcl--frozen-output)
            ;; Diff with no changes should show no differences
            (kcl-eval-diff)
            (should-not (get-buffer "*kcl-diff*"))
            (when (get-buffer "*kcl-output*")
              (kill-buffer "*kcl-output*"))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-eval-diff-labels-include-format ()
  "Diff labels should include the frozen output format."
  (let* ((dir (make-temp-file "kcl-eval-diff-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (setq kcl-eval-output-format "yaml")
            (kcl-eval-buffer)
            (kcl-eval-freeze)
            (erase-buffer)
            (insert "x = 2\n")
            (save-buffer)
            (kcl-eval-diff)
            (let ((diff (get-buffer "*kcl-diff*")))
              (should diff)
              (with-current-buffer diff
                (let ((text (buffer-substring-no-properties
                             (point-min) (point-max))))
                  (should (string-match-p "--- frozen (yaml)" text))
                  (should (string-match-p "\\+\\+\\+ current (yaml)" text))))
              (kill-buffer diff))
            (when (get-buffer "*kcl-output*")
              (kill-buffer "*kcl-output*"))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-eval-json-format ()
  "kcl-eval-buffer with json format should produce JSON output."
  (let* ((dir (make-temp-file "kcl-eval-" t))
         (file (expand-file-name "test.k" dir))
         (kcl-eval-output-format "json"))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (kcl-eval-buffer)
            (let ((out-buf (get-buffer "*kcl-output*")))
              (should out-buf)
              (with-current-buffer out-buf
                ;; JSON output should contain "x": 1
                (should (string-match-p "\"x\""
                                        (buffer-substring-no-properties
                                         (point-min) (point-max)))))
              (kill-buffer out-buf))
            (kill-buffer)))
      (delete-directory dir t))))

;;; ──────────────────────────────────────────────
;;; CLI Commands
;;; ──────────────────────────────────────────────

(ert-deftest kcl-lint-buffer-no-file-error ()
  "kcl-lint-buffer should error on non-file buffers."
  (with-temp-buffer
    (kcl-mode)
    (should-error (kcl-lint-buffer) :type 'user-error)))

(ert-deftest kcl-goto-imports-at-imports ()
  "kcl-goto-imports should jump to import section."
  (with-temp-buffer
    (kcl-mode)
    (insert "# comment\nimport math\n\nschema Foo:\n    x: int\n")
    (goto-char (point-max))
    (kcl-goto-imports)
    (should (looking-at "import math"))))

(ert-deftest kcl-goto-imports-no-imports ()
  "kcl-goto-imports should go to beginning when no imports."
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Foo:\n    x: int\n")
    (goto-char (point-max))
    (kcl-goto-imports)
    (should (= (point) (point-min)))))

(ert-deftest kcl-goto-imports-skips-comments ()
  "kcl-goto-imports should skip leading comments."
  (with-temp-buffer
    (kcl-mode)
    (insert "# file header\n# second line\nimport os\n")
    (goto-char (point-max))
    (kcl-goto-imports)
    (should (looking-at "import os"))))

(ert-deftest kcl-goto-imports-finds-later-imports ()
  "kcl-goto-imports should find imports after a module docstring."
  (with-temp-buffer
    (kcl-mode)
    (insert "\"\"\"module docs mentioning import fake\"\"\"\n\nimport math\n")
    (goto-char (point-max))
    (kcl-goto-imports)
    (should (looking-at "import math"))))

(ert-deftest kcl-lint-valid-file ()
  "kcl-lint-buffer should succeed on a valid file."
  (let* ((dir (make-temp-file "kcl-lint-" t))
         (file (expand-file-name "valid.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            ;; Should not error
            (kcl-lint-buffer)
            ;; Wait for compilation to finish
            (sit-for 2)
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-test-command-defined ()
  "kcl-test should be an interactive command."
  (should (commandp 'kcl-test)))

(ert-deftest kcl-test-uses-test-compilation-mode ()
  "kcl-test should use `kcl-test-compilation-mode'."
  (let ((captured nil)
        (kcl-command "kcl"))
    (cl-letf (((symbol-function 'compilation-start)
               (lambda (cmd mode)
                 (setq captured (list cmd mode)))))
      (with-temp-buffer
        (kcl-mode)
        (kcl-test)))
    (should (equal (nth 0 captured) "kcl test"))
    (should (eq (nth 1 captured) 'kcl-test-compilation-mode))))

(ert-deftest kcl-vet-command-defined ()
  "kcl-vet should be an interactive command."
  (should (commandp 'kcl-vet)))

(ert-deftest kcl-vet-remembers-last-values ()
  "kcl-vet should remember the last data file and schema."
  (let* ((dir (make-temp-file "kcl-vet-" t))
         (kcl-file (expand-file-name "main.k" dir))
         (data-file (expand-file-name "data.yaml" dir))
         (captured nil))
    (unwind-protect
        (progn
          (with-temp-file kcl-file (insert "schema Data:\n    x: int\n"))
          (with-temp-file data-file (insert "x: 1\n"))
          (cl-letf (((symbol-function 'compilation-start)
                     (lambda (cmd mode)
                       (setq captured (list cmd mode)))))
            (with-current-buffer (find-file-noselect kcl-file)
              (kcl-mode)
              (kcl-vet data-file "Data")
              (should (string= kcl-vet-last-data-file data-file))
              (should (string= kcl-vet-last-schema-name "Data"))
              (kill-buffer))))
      (delete-directory dir t))
    (should (string-match-p "kcl vet" (car captured)))
    (should (eq (cadr captured) 'kcl-compilation-mode))))

(ert-deftest kcl-mod-init-command-defined ()
  "kcl-mod-init should be an interactive command."
  (should (commandp 'kcl-mod-init)))

(ert-deftest kcl-mod-add-command-defined ()
  "kcl-mod-add should be an interactive command."
  (should (commandp 'kcl-mod-add)))

(ert-deftest kcl-mod-update-command-defined ()
  "kcl-mod-update should be an interactive command."
  (should (commandp 'kcl-mod-update)))

(ert-deftest kcl-mod-graph-command-defined ()
  "kcl-mod-graph should be an interactive command."
  (should (commandp 'kcl-mod-graph)))

(ert-deftest kcl-mod-update-builds-command ()
  "kcl-mod-update should run kcl mod update in the project root."
  (let* ((dir (make-temp-file "kcl-mod-update-" t))
         (captured nil))
    (unwind-protect
        (let ((default-directory dir)
              (kcl-command "kcl"))
          (cl-letf (((symbol-function 'compilation-start)
                     (lambda (cmd mode)
                       (setq captured (list cmd mode default-directory)))))
            (kcl-mod-update "pkg")))
      (delete-directory dir t))
    (should (equal (nth 0 captured) "kcl mod update pkg"))
    (should (eq (nth 1 captured) 'kcl-compilation-mode))
    (should (string= (nth 2 captured) dir))))

(ert-deftest kcl-mod-graph-builds-command ()
  "kcl-mod-graph should run kcl mod graph in the project root."
  (let* ((dir (make-temp-file "kcl-mod-graph-" t))
         (captured nil))
    (unwind-protect
        (let ((default-directory dir)
              (kcl-command "kcl"))
          (cl-letf (((symbol-function 'compilation-start)
                     (lambda (cmd mode)
                       (setq captured (list cmd mode default-directory)))))
            (kcl-mod-graph)))
      (delete-directory dir t))
    (should (equal (nth 0 captured) "kcl mod graph"))
    (should (eq (nth 1 captured) 'kcl-compilation-mode))
    (should (string= (nth 2 captured) dir))))

(ert-deftest kcl-import-add-command-defined ()
  "kcl-import-add should be an interactive command."
  (should (commandp 'kcl-import-add)))

(ert-deftest kcl-import-add-inserts-after-header ()
  "kcl-import-add should insert imports after leading comments."
  (with-temp-buffer
    (kcl-mode)
    (insert "# header\n\nschema Foo:\n    x: int\n")
    (kcl-import-add "math")
    (should (string= (buffer-string)
                     "# header\n\nimport math\n\nschema Foo:\n    x: int\n"))))

(ert-deftest kcl-import-add-appends-to-import-block ()
  "kcl-import-add should append to an existing import block."
  (with-temp-buffer
    (kcl-mode)
    (insert "import math\n\nschema Foo:\n    x: int\n")
    (kcl-import-add "json" "j")
    (should (string= (buffer-string)
                     "import math\nimport json as j\n\nschema Foo:\n    x: int\n"))))

(ert-deftest kcl-import-add-skips-duplicates ()
  "kcl-import-add should not duplicate exact imports."
  (with-temp-buffer
    (kcl-mode)
    (insert "import math\n\nschema Foo:\n    x: int\n")
    (kcl-import-add "math")
    (should (string= (buffer-string)
                     "import math\n\nschema Foo:\n    x: int\n"))))

;;; ──────────────────────────────────────────────
;;; Documentation
;;; ──────────────────────────────────────────────

(ert-deftest kcl-doc-url-builtin-type-str ()
  "Should map 'str' to the correct documentation URL."
  (should (string= (kcl-doc--url-for "str")
                    "https://kcl-lang.io/docs/reference/lang/spec/datatypes#string")))

(ert-deftest kcl-doc-url-builtin-type-int ()
  "Should map 'int' to the correct documentation URL."
  (should (string= (kcl-doc--url-for "int")
                    "https://kcl-lang.io/docs/reference/lang/spec/datatypes#int")))

(ert-deftest kcl-doc-url-builtin-function ()
  "Should map built-in functions to the correct URL."
  (should (string= (kcl-doc--url-for "len")
                    "https://kcl-lang.io/docs/reference/model/builtin#len")))

(ert-deftest kcl-doc-url-keyword-schema ()
  "Should map 'schema' to the correct documentation URL."
  (should (string= (kcl-doc--url-for "schema")
                    "https://kcl-lang.io/docs/reference/lang/tour#schema")))

(ert-deftest kcl-doc-url-stdlib-module ()
  "Should map stdlib module names to the correct URL."
  (should (string= (kcl-doc--url-for "math")
                    "https://kcl-lang.io/docs/reference/model/math")))

(ert-deftest kcl-doc-url-module-function ()
  "Should map module.function to the correct URL."
  (should (string= (kcl-doc--url-for "math.log")
                    "https://kcl-lang.io/docs/reference/model/math#log")))

(ert-deftest kcl-doc-symbol-at-point-dotted ()
  "Documentation symbol lookup should include dotted module names."
  (with-temp-buffer
    (kcl-mode)
    (insert "value = math.log(10)\n")
    (search-backward "math")
    (search-forward "log")
    (should (string= (kcl-doc-symbol-at-point) "math.log"))))

(ert-deftest kcl-open-doc-at-point-dotted ()
  "Documentation lookup should open module.function URLs at point."
  (let ((opened-url nil))
    (cl-letf (((symbol-function 'browse-url)
               (lambda (url &rest _args)
                 (setq opened-url url))))
      (with-temp-buffer
        (kcl-mode)
        (insert "value = math.log(10)\n")
        (search-backward "math")
        (search-forward "log")
        (kcl-open-doc-at-point)))
    (should (string= opened-url
                     "https://kcl-lang.io/docs/reference/model/math#log"))))

(ert-deftest kcl-doc-url-unknown-returns-nil ()
  "Unknown symbols should return nil."
  (should-not (kcl-doc--url-for "UnknownThing12345")))

(ert-deftest kcl-eldoc-function-builtin ()
  "kcl-eldoc-function should document known symbols."
  (with-temp-buffer
    (kcl-mode)
    (insert "value = len(items)\n")
    (goto-char (point-min))
    (search-forward "len")
    (should (string-match-p "built-in function" (kcl-eldoc-function)))))

(ert-deftest kcl-xref-finds-schema-definition ()
  "The KCL xref backend should find project schema definitions."
  (let* ((dir (make-temp-file "kcl-xref-" t))
         (file (expand-file-name "main.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "kcl.mod" dir)
            (insert "[package]\n"))
          (with-temp-file file
            (insert "schema Foo:\n    x: int\n\nbar = Foo {x = 1}\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (let ((defs (xref-backend-definitions 'kcl "Foo")))
              (should defs)
              (should (string-match-p "Foo" (xref-item-summary (car defs)))))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-xref-finds-module-file ()
  "The KCL xref backend should resolve module names to files."
  (let* ((dir (make-temp-file "kcl-xref-module-" t))
         (module-dir (expand-file-name "foo" dir))
         (module-file (expand-file-name "bar.k" module-dir))
         (main-file (expand-file-name "main.k" dir)))
    (unwind-protect
        (progn
          (make-directory module-dir t)
          (with-temp-file (expand-file-name "kcl.mod" dir)
            (insert "[package]\n"))
          (with-temp-file module-file (insert "value = 1\n"))
          (with-temp-file main-file (insert "import foo.bar\n"))
          (with-current-buffer (find-file-noselect main-file)
            (kcl-mode)
            (let ((defs (xref-backend-definitions 'kcl "foo.bar")))
              (should defs)
              (should (string-match-p "module foo.bar"
                                      (xref-item-summary (car defs)))))
            (kill-buffer)))
      (delete-directory dir t))))

;;; ──────────────────────────────────────────────
;;; Tempo Templates
;;; ──────────────────────────────────────────────

(ert-deftest kcl-tempo-schema-defined ()
  "Schema tempo template should be defined."
  (should (assoc "schema" kcl-tempo-tags)))

(ert-deftest kcl-tempo-rule-defined ()
  "Rule tempo template should be defined."
  (should (assoc "rule" kcl-tempo-tags)))

(ert-deftest kcl-tempo-mixin-defined ()
  "Mixin tempo template should be defined."
  (should (assoc "mixin" kcl-tempo-tags)))

(ert-deftest kcl-tempo-protocol-defined ()
  "Protocol tempo template should be defined."
  (should (assoc "protocol" kcl-tempo-tags)))

(ert-deftest kcl-tempo-check-defined ()
  "Check tempo template should be defined."
  (should (assoc "check" kcl-tempo-tags)))

(ert-deftest kcl-tempo-import-defined ()
  "Import tempo template should be defined."
  (should (assoc "import" kcl-tempo-tags)))

(ert-deftest kcl-tempo-lambda-defined ()
  "Lambda tempo template should be defined."
  (should (assoc "lambda" kcl-tempo-tags)))

;;; ──────────────────────────────────────────────
;;; Flymake
;;; ──────────────────────────────────────────────

(ert-deftest kcl-flymake-backend-defined ()
  "Flymake backend function should be defined."
  (should (fboundp 'kcl-flymake-backend)))

(ert-deftest kcl-flymake-registered-in-mode ()
  "Flymake backend should be registered when kcl-mode activates."
  (with-temp-buffer
    (kcl-mode)
    (should (memq 'kcl-flymake-backend flymake-diagnostic-functions))))

(ert-deftest kcl-flymake-parse-diagnostic-types ()
  "Flymake parsing should keep warning and error diagnostic types distinct."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = 1\n")
    (let* ((output (concat "warning[W2001]: style issue\n"
                           " --> /tmp/test.k:1:1\n"
                           "error[E1001]: type issue\n"
                           " --> /tmp/test.k:1:3\n"))
           (diags (kcl--flymake-parse-diagnostics (current-buffer) output)))
      (should (= (length diags) 2))
      (should (eq (flymake-diagnostic-type (nth 0 diags)) :warning))
      (should (eq (flymake-diagnostic-type (nth 1 diags)) :error)))))

;;; ──────────────────────────────────────────────
;;; Transient / Menu
;;; ──────────────────────────────────────────────

(ert-deftest kcl-transient-command-defined ()
  "kcl-transient should be an interactive command."
  (should (commandp 'kcl-transient)))

;;; ──────────────────────────────────────────────
;;; Keymap
;;; ──────────────────────────────────────────────

(ert-deftest kcl-keymap-eval ()
  "C-c C-e should be bound to kcl-eval-buffer."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-e")) 'kcl-eval-buffer)))

(ert-deftest kcl-keymap-lint ()
  "C-c C-l should be bound to kcl-lint-buffer."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-l")) 'kcl-lint-buffer)))

(ert-deftest kcl-keymap-test ()
  "C-c C-t should be bound to kcl-test."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-t")) 'kcl-test)))

(ert-deftest kcl-keymap-vet ()
  "C-c C-v should be bound to kcl-vet."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-v")) 'kcl-vet)))

(ert-deftest kcl-keymap-imports ()
  "C-c C-i should be bound to kcl-goto-imports."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-i")) 'kcl-goto-imports)))

(ert-deftest kcl-keymap-doc ()
  "C-c C-h should be bound to kcl-open-doc-at-point."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-h")) 'kcl-open-doc-at-point)))

(ert-deftest kcl-keymap-transient ()
  "C-c C-c should be bound to kcl-transient."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-c")) 'kcl-transient)))

(ert-deftest kcl-keymap-freeze ()
  "C-c C-s should be bound to kcl-eval-freeze."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-s")) 'kcl-eval-freeze)))

(ert-deftest kcl-keymap-diff ()
  "C-c C-d should be bound to kcl-eval-diff."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-d")) 'kcl-eval-diff)))

;;; ──────────────────────────────────────────────
;;; kcl-ts-mode keymap parity
;;; ──────────────────────────────────────────────

(ert-deftest kcl-ts-keymap-eval ()
  "kcl-ts-mode C-c C-e should be bound to kcl-eval-buffer."
  (require 'kcl-ts-mode)
  (should (eq (lookup-key kcl-ts-mode-map (kbd "C-c C-e")) 'kcl-eval-buffer)))

(ert-deftest kcl-ts-keymap-transient ()
  "kcl-ts-mode C-c C-c should be bound to kcl-transient."
  (require 'kcl-ts-mode)
  (should (eq (lookup-key kcl-ts-mode-map (kbd "C-c C-c")) 'kcl-transient)))

(ert-deftest kcl-ts-keymap-lint ()
  "kcl-ts-mode C-c C-l should be bound to kcl-lint-buffer."
  (require 'kcl-ts-mode)
  (should (eq (lookup-key kcl-ts-mode-map (kbd "C-c C-l")) 'kcl-lint-buffer)))

;;; ──────────────────────────────────────────────
;;; which-function-mode in kcl-ts-mode
;;; ──────────────────────────────────────────────

(ert-deftest kcl-ts-which-function-schema ()
  "Tree-sitter which-function should find schema at point."
  (require 'kcl-ts-mode)
  (when (treesit-ready-p 'kcl t)
    (with-temp-buffer
      (kcl-ts-mode)
      (insert "schema Foo:\n    x: int = 1\n")
      (goto-char (point-min))
      (forward-line 1)
      (forward-char 4) ; inside body
      (should (string= (kcl-ts-mode--which-function) "schema Foo")))))

;;; ──────────────────────────────────────────────
;;; kcl-eval-buffer region-aware (B9)
;;; ──────────────────────────────────────────────

(ert-deftest kcl-eval-buffer-whole-file ()
  "kcl-eval-buffer without region evals the whole file."
  (let* ((dir (make-temp-file "kcl-eval-region-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\ny = 2\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (deactivate-mark)
            (kcl-eval-buffer)
            (let ((out (get-buffer "*kcl-output*")))
              (should out)
              (with-current-buffer out
                (let ((txt (buffer-substring-no-properties (point-min) (point-max))))
                  (should (string-match-p "x: 1" txt))
                  ;; 'y' is YAML reserved; output may be "y: 2" or "'y': 2"
                  (should (string-match-p "2" txt))))
              (kill-buffer out))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-eval-buffer-region ()
  "kcl-eval-buffer with active region evals only that region."
  (let* ((dir (make-temp-file "kcl-eval-region-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\ny = 2\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            ;; Select only "x = 1\n"; enable transient-mark-mode for batch
            (let ((transient-mark-mode t))
              (set-mark (point-min))
              (goto-char (point-min))
              (forward-line 1)
              (setq mark-active t)
              (should (use-region-p))
              (kcl-eval-buffer))
            (let ((out (get-buffer "*kcl-output*")))
              (should out)
              (with-current-buffer out
                (let ((txt (buffer-substring-no-properties (point-min) (point-max))))
                  (should (string-match-p "x: 1" txt))))
              (kill-buffer out))
            (kill-buffer)))
      (delete-directory dir t))))

;;; ──────────────────────────────────────────────
;;; kcl-switch-output-format (B11)
;;; ──────────────────────────────────────────────

(ert-deftest kcl-switch-output-format-defined ()
  "kcl-switch-output-format should be a defined command."
  (should (fboundp 'kcl-switch-output-format))
  (should (commandp 'kcl-switch-output-format)))

(ert-deftest kcl-switch-output-format-cycles ()
  "kcl-switch-output-format should cycle yaml -> json -> toml -> yaml."
  (let* ((dir (make-temp-file "kcl-fmt-cycle-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x = 1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            (setq kcl-eval-output-format "yaml")
            ;; yaml -> json
            (kcl-switch-output-format)
            (should (string= kcl-eval-output-format "json"))
            ;; json -> toml
            (kcl-switch-output-format)
            (should (string= kcl-eval-output-format "toml"))
            ;; toml -> yaml
            (kcl-switch-output-format)
            (should (string= kcl-eval-output-format "yaml"))
            (when (get-buffer "*kcl-output*") (kill-buffer "*kcl-output*"))
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-keymap-switch-format ()
  "C-c C-o should be bound to kcl-switch-output-format."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-o"))
              'kcl-switch-output-format)))

;;; ──────────────────────────────────────────────
;;; project.el integration (B14)
;;; ──────────────────────────────────────────────

(ert-deftest kcl-project-try-defined ()
  "kcl-project-try should be a defined function."
  (should (fboundp 'kcl-project-try)))

(ert-deftest kcl-project-try-with-kcl-mod ()
  "kcl-project-try should return transient project when kcl.mod exists."
  (let* ((dir (make-temp-file "kcl-proj-" t))
         (mod-file (expand-file-name "kcl.mod" dir)))
    (unwind-protect
        (progn
          (with-temp-file mod-file (insert "[package]\n"))
          (let ((result (kcl-project-try dir)))
            (should result)
            (should (eq (car result) 'transient))
            (should (string= (expand-file-name (cdr result))
                             (file-name-as-directory dir)))))
      (delete-directory dir t))))

(ert-deftest kcl-project-try-without-kcl-mod ()
  "kcl-project-try should return nil when no kcl.mod exists."
  (let ((dir (make-temp-file "kcl-proj-" t)))
    (unwind-protect
        (should-not (kcl-project-try dir))
      (delete-directory dir t))))

(ert-deftest kcl-project-find-functions-hooked ()
  "kcl-project-try should be in project-find-functions in kcl-mode buffers."
  (with-temp-buffer
    (kcl-mode)
    (should (memq 'kcl-project-try project-find-functions))))

;;; ──────────────────────────────────────────────
;;; kcl-live-preview-mode (B16)
;;; ──────────────────────────────────────────────

(ert-deftest kcl-live-preview-mode-defined ()
  "kcl-live-preview-mode should be a defined minor mode."
  (should (fboundp 'kcl-live-preview-mode)))

(ert-deftest kcl-live-preview-mode-hooks ()
  "kcl-live-preview-mode enable/disable should add/remove after-save-hook."
  (with-temp-buffer
    (kcl-mode)
    ;; Enable: should add kcl-eval-buffer to after-save-hook
    (kcl-live-preview-mode 1)
    (should (memq 'kcl-eval-buffer after-save-hook))
    ;; Disable: should remove it
    (kcl-live-preview-mode -1)
    (should-not (memq 'kcl-eval-buffer after-save-hook))))

(ert-deftest kcl-schema-hierarchy-at-point-returns-chain ()
  "Schema hierarchy should include parent schemas."
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Base:\n    x: int\n\nschema Child(Base):\n    y: int\n")
    (goto-char (point-max))
    (should (equal (kcl-schema-hierarchy-at-point)
                   '("Child" "Base")))))

(ert-deftest kcl-breadcrumb-at-point-check-block ()
  "Breadcrumb should include check blocks."
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Foo:\n    x: int\n    check:\n        x > 0\n")
    (goto-char (point-max))
    (should (string= (kcl-breadcrumb-at-point) "schema Foo > check"))))

(ert-deftest kcl-breadcrumb-mode-sets-header-line ()
  "kcl-breadcrumb-mode should install a header line expression."
  (with-temp-buffer
    (kcl-mode)
    (kcl-breadcrumb-mode 1)
    (should header-line-format)
    (kcl-breadcrumb-mode -1)
    (should-not (local-variable-p 'header-line-format))))

(ert-deftest kcl-keymap-live-preview ()
  "C-c C-p should be bound to kcl-live-preview-mode."
  (should (eq (lookup-key kcl-mode-map (kbd "C-c C-p"))
              'kcl-live-preview-mode)))

;;; ──────────────────────────────────────────────
;;; Format-on-save improvements
;;; ──────────────────────────────────────────────

(ert-deftest kcl-format-buffer-cli-tempfile ()
  "kcl-format-buffer via CLI should not require file to be saved first."
  (let* ((dir (make-temp-file "kcl-fmt-" t))
         (file (expand-file-name "test.k" dir)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "x=1\n"))
          (with-current-buffer (find-file-noselect file)
            (kcl-mode)
            ;; Make buffer dirty without saving
            (goto-char (point-max))
            (insert "y=2\n")
            (should (buffer-modified-p))
            ;; Format should work on unsaved buffer content
            (kcl-format-buffer)
            ;; Buffer should not have been saved (still modified or
            ;; modified state cleared by replace-buffer-contents is ok,
            ;; but the key thing is the file should not have been written)
            (kill-buffer)))
      (delete-directory dir t))))

(ert-deftest kcl-format-via-lsp-defined ()
  "kcl--format-via-lsp helper should be defined."
  (should (fboundp 'kcl--format-via-lsp)))

(ert-deftest kcl-format-via-cli-defined ()
  "kcl--format-via-cli helper should be defined."
  (should (fboundp 'kcl--format-via-cli)))

(provide 'test-commands)
;;; test-commands.el ends here
