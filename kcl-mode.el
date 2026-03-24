;;; kcl-mode.el --- Major mode for editing KCL files -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, tools
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; Major mode for editing KCL (Kusion Configuration Language) files.
;; KCL is an open-source, constraint-based record and functional
;; language for cloud-native configuration.  See https://kcl-lang.io
;;
;; Features:
;; - Syntax highlighting via font-lock
;; - Comment support (# line comments)
;; - Basic indentation (4-space Python-like)
;; - Integration with lsp-mode and eglot for the KCL language server
;; - `kcl-eval-buffer' with snapshot freeze/diff support
;; - Compilation mode with KCL error regexp and ANSI color
;; - CLI commands: lint, test, vet, mod init/add, goto-imports
;; - Documentation lookup via `kcl-open-doc-at-point'
;; - Tempo templates for schema, rule, mixin, protocol, etc.
;; - Flymake backend using `kcl lint'
;; - Transient menu for all commands
;; - `which-function-mode' support
;;
;; Usage:
;;   (require 'kcl-mode)
;;
;; Files with the `.k' extension are automatically opened in kcl-mode.

;;; Code:

(require 'rx)
(require 'ansi-color)
(require 'compile)

;;; Customization

(defgroup kcl nil
  "Major mode for editing KCL files."
  :group 'languages
  :prefix "kcl-")

(defcustom kcl-indent-offset 4
  "Number of spaces for each indentation level in KCL."
  :type 'integer
  :group 'kcl)

(defcustom kcl-language-server-command '("kcl-language-server")
  "Command to start the KCL language server."
  :type '(repeat string)
  :group 'kcl)

(defcustom kcl-command "kcl"
  "Path to the kcl CLI executable."
  :type 'string
  :group 'kcl)

(defcustom kcl-format-on-save nil
  "If non-nil, format KCL buffers with `kcl fmt' before saving."
  :type 'boolean
  :group 'kcl)

(defcustom kcl-eval-output-format "yaml"
  "Output format for `kcl-eval-buffer'.
Supported values: \"yaml\", \"json\", \"toml\"."
  :type '(choice (const "yaml")
                 (const "json")
                 (const "toml"))
  :group 'kcl)

;;; Syntax Table

(defvar kcl-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Comments: # to end of line
    (modify-syntax-entry ?# "<" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Strings: double and single quotes
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\' "\"" table)
    ;; Parentheses
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    ;; Operators: punctuation
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?/ "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?^ "." table)
    (modify-syntax-entry ?~ "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?! "." table)
    (modify-syntax-entry ?@ "." table)
    ;; Underscore is a word constituent
    (modify-syntax-entry ?_ "w" table)
    ;; Dollar sign is a symbol constituent (for $-prefixed identifiers)
    (modify-syntax-entry ?$ "_" table)
    ;; Dot is punctuation
    (modify-syntax-entry ?. "." table)
    table)
  "Syntax table for `kcl-mode'.")

;;; Font Lock

(defvar kcl-mode--keywords
  '("import" "as"
    "schema" "mixin" "protocol" "rule" "check"
    "if" "elif" "else"
    "for" "in"
    "assert"
    "lambda"
    "all" "any" "map" "filter"
    "type"
    "and" "or" "not" "is")
  "KCL language keywords.")

(defvar kcl-mode--constants
  '("True" "False" "None" "Undefined")
  "KCL language constants.")

(defvar kcl-mode--builtin-types
  '("str" "int" "float" "bool" "any")
  "KCL built-in type names.")

(defvar kcl-mode--builtin-functions
  '("print" "len" "typeof" "range" "abs" "all" "any"
    "bin" "hex" "oct" "ord" "sorted"
    "int" "float" "str" "bool" "list" "dict"
    "max" "min" "sum" "pow" "round"
    "multiplyof" "isunique" "zip" "enumerate")
  "KCL built-in function names.")

(defconst kcl-mode--font-lock-keywords
  (let ((keywords-re (regexp-opt kcl-mode--keywords 'symbols))
        (constants-re (regexp-opt kcl-mode--constants 'symbols))
        (builtins-re (regexp-opt kcl-mode--builtin-types 'symbols))
        (functions-re (regexp-opt kcl-mode--builtin-functions 'symbols)))
    (list
     ;; Decorators: @name or @name(args)
     (list (rx line-start (* space) "@" (group (+ (any word ?_))) (* (any space)) (? "("))
           1 'font-lock-preprocessor-face)

     ;; Schema/mixin/protocol/rule definition names
     (list (rx symbol-start
               (group (or "schema" "mixin" "protocol" "rule"))
               (+ space)
               (group (+ (any word ?_))))
           '(1 font-lock-keyword-face)
           '(2 font-lock-type-face))

     ;; Type alias: type Name = ...
     (list (rx symbol-start "type" (+ space) (group (+ (any word ?_))))
           '(1 font-lock-type-face))

     ;; Import statement: import foo.bar as baz
     (list (rx symbol-start "import" (+ space) (group (+ (any word ?_ ?.))))
           '(1 font-lock-constant-face))

     ;; Keywords
     (cons keywords-re 'font-lock-keyword-face)

     ;; Built-in types used in type annotations (after colon)
     (list (concat ":[[:space:]]*" "\\(" builtins-re "\\)")
           1 'font-lock-type-face)

     ;; Built-in type names in standalone positions
     (cons builtins-re 'font-lock-type-face)

     ;; Constants
     (cons constants-re 'font-lock-constant-face)

     ;; Built-in functions (when followed by open paren)
     (list (concat "\\_<\\(" functions-re "\\)[[:space:]]*(")
           1 'font-lock-builtin-face)

     ;; Numbers: decimal, hex, octal, binary, float
     ;; Float with exponent
     (cons (rx symbol-start
               (? (any "+-"))
               (or (seq (+ digit) "." (* digit) (? (seq (any "eE") (? (any "+-")) (+ digit))))
                   (seq "." (+ digit) (? (seq (any "eE") (? (any "+-")) (+ digit))))
                   (seq (+ digit) (any "eE") (? (any "+-")) (+ digit)))
               symbol-end)
           'font-lock-constant-face)
     ;; Hex
     (cons (rx symbol-start (? "-") "0" (any "xX") (+ hex-digit) symbol-end)
           'font-lock-constant-face)
     ;; Octal
     (cons (rx symbol-start (? "-") "0" (any "oO") (+ (any "0-7")) symbol-end)
           'font-lock-constant-face)
     ;; Binary
     (cons (rx symbol-start (? "-") "0" (any "bB") (+ (any "01")) symbol-end)
           'font-lock-constant-face)
     ;; Decimal with optional SI suffix
     (cons (rx symbol-start (? "-") (or "0" (seq (any "1-9") (* digit)))
               (? (or "Ki" "Mi" "Gi" "Ti" "Pi"
                      "n" "u" "m" "k" "K" "M" "G" "T" "P"))
               symbol-end)
           'font-lock-constant-face)

     ;; Optional field marker: name?:
     (list (rx (group (+ (any word ?_))) "?" (* space) ":")
           1 'font-lock-variable-name-face)

     ;; Schema attribute: name: type (at beginning of line, indented)
     (list (rx line-start (+ space) (group (+ (any word ?_))) (* space) ":")
           1 'font-lock-variable-name-face)))
  "Font-lock keywords for `kcl-mode'.")

;;; String interpolation highlighting

(defun kcl-mode--match-string-interpolation (limit)
  "Search for ${...} string interpolation up to LIMIT."
  (let ((result nil))
    (while (and (not result)
                (re-search-forward "\\${" limit t))
      (let ((start (match-beginning 0))
            (ppss (syntax-ppss)))
        ;; Only match inside strings
        (when (nth 3 ppss)
          (let ((brace-start start)
                (depth 1)
                (end nil))
            (while (and (> depth 0) (< (point) limit))
              (cond
               ((looking-at "\\${")
                (setq depth (1+ depth))
                (forward-char 2))
               ((eq (char-after) ?\})
                (setq depth (1- depth))
                (when (= depth 0)
                  (setq end (1+ (point))))
                (forward-char 1))
               (t (forward-char 1))))
            (when end
              (set-match-data (list brace-start end))
              (setq result t))))))
    result))

;;; Triple-quoted string support via syntax-propertize

(defconst kcl-mode--triple-quote-re
  (rx (group (? "r")
             (or "\"\"\"" "'''"))
      (*? anything)
      (backref 1))
  "Regexp matching triple-quoted strings.")

(defconst kcl-mode--syntax-propertize-function
  (syntax-propertize-rules
   ;; Triple-quoted strings: """ ... """ and ''' ... '''
   ((rx (group (? "r") (or "\"\"\"" "'''")))
    (0 (ignore (kcl-mode--syntax-propertize-triple-quote))))
   ;; String interpolation: ${ ... }
   ((rx "${")
    (0 (ignore (kcl-mode--syntax-propertize-interpolation)))))
  "Syntax propertize rules for KCL mode.")

(defun kcl-mode--syntax-propertize-triple-quote ()
  "Handle triple-quoted strings for syntax-propertize."
  (let* ((start (match-beginning 0))
         (ppss (save-excursion (syntax-ppss start))))
    (unless (nth 4 ppss)  ; not in a comment
      (if (nth 3 ppss)
          ;; We're inside a string; this might be the closing triple-quote
          (let* ((string-char (nth 3 ppss))
                 (quote-char (if (eq string-char t)
                                 (char-after start)
                               string-char))
                 (triple (make-string 3 quote-char))
                 (has-r (eq (char-before (1+ start)) ?r))
                 (match-start (if has-r (1+ start) start)))
            (when (and (>= (- (point-max) match-start) 3)
                       (string= (buffer-substring-no-properties match-start (+ match-start 3))
                                triple))
              (put-text-property (+ match-start 2) (+ match-start 3)
                                 'syntax-table (string-to-syntax "|"))))
        ;; We're not in a string; this is the opening triple-quote
        (let ((match-start (match-beginning 0)))
          (when (or (eq (char-after match-start) ?r)
                    (eq (char-after match-start) ?\")
                    (eq (char-after match-start) ?\'))
            (let* ((has-r (eq (char-after match-start) ?r))
                   (quote-start (if has-r (1+ match-start) match-start)))
              (put-text-property quote-start (1+ quote-start)
                                 'syntax-table (string-to-syntax "|")))))))))

(defun kcl-mode--syntax-propertize-interpolation ()
  "Handle string interpolation ${...} for syntax-propertize."
  ;; Mark ${ and matching } to suppress string syntax inside interpolation
  (let ((start (match-beginning 0))
        (ppss (save-excursion (syntax-ppss (match-beginning 0)))))
    (when (nth 3 ppss)  ; inside a string
      (put-text-property start (1+ start)
                         'syntax-table (string-to-syntax ".")))))

;;; Indentation

(defun kcl-mode-indent-line ()
  "Indent the current line according to KCL rules."
  (interactive)
  (let ((indent (kcl-mode--calculate-indent)))
    (when indent
      (if (<= (current-column) (current-indentation))
          (indent-line-to indent)
        (save-excursion
          (indent-line-to indent))))))

(defun kcl-mode--calculate-indent ()
  "Calculate the indentation for the current line."
  (save-excursion
    (beginning-of-line)
    (if (bobp)
        0
      (let ((cur-indent nil)
            (not-indented t))
        ;; Check if the current line starts with a dedent keyword
        (cond
         ;; Closing bracket/brace/paren
         ((looking-at "^[ \t]*[]})]")
          (save-excursion
            (forward-line -1)
            (setq cur-indent (max 0 (- (current-indentation) kcl-indent-offset)))))
         ;; elif/else
         ((looking-at "^[ \t]*\\(elif\\|else\\)\\b")
          (save-excursion
            (forward-line -1)
            (while (and not-indented (not (bobp)))
              (cond
               ((looking-at "^[ \t]*\\(if\\|elif\\)\\b")
                (setq cur-indent (current-indentation))
                (setq not-indented nil))
               (t (forward-line -1))))
            (unless cur-indent
              (setq cur-indent 0))))
         ;; check block inside schema
         ((looking-at "^[ \t]*check[ \t]*:")
          (save-excursion
            (forward-line -1)
            (while (and not-indented (not (bobp)))
              (cond
               ((looking-at "^[ \t]*\\(schema\\|mixin\\|protocol\\|rule\\)\\b")
                (setq cur-indent (+ (current-indentation) kcl-indent-offset))
                (setq not-indented nil))
               (t (forward-line -1))))
            (unless cur-indent
              (setq cur-indent kcl-indent-offset))))
         ;; Default: look at previous line
         (t
          (save-excursion
            (forward-line -1)
            ;; Skip blank lines
            (while (and (looking-at "^[ \t]*$") (not (bobp)))
              (forward-line -1))
            (cond
             ;; Previous line ends with colon -> indent
             ((looking-at ".*:[ \t]*\\(#.*\\)?$")
              (setq cur-indent (+ (current-indentation) kcl-indent-offset)))
             ;; Previous line ends with opening bracket -> indent
             ((looking-at ".*[{\\[(][ \t]*\\(#.*\\)?$")
              (setq cur-indent (+ (current-indentation) kcl-indent-offset)))
             ;; Previous line ends with backslash (continuation) -> indent
             ((looking-at ".*\\\\[ \t]*$")
              (setq cur-indent (+ (current-indentation) kcl-indent-offset)))
             ;; Default: same indentation as previous line
             (t
              (setq cur-indent (current-indentation)))))))
        (or cur-indent 0)))))

;;; Mode Map

(defvar kcl-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Run / Eval
    (define-key map (kbd "C-c C-r") #'kcl-run-buffer)
    (define-key map (kbd "C-c C-e") #'kcl-eval-buffer)
    (define-key map (kbd "C-c C-s") #'kcl-eval-freeze)
    (define-key map (kbd "C-c C-d") #'kcl-eval-diff)
    ;; Tooling
    (define-key map (kbd "C-c C-f") #'kcl-format-buffer)
    (define-key map (kbd "C-c C-l") #'kcl-lint-buffer)
    (define-key map (kbd "C-c C-t") #'kcl-test)
    (define-key map (kbd "C-c C-v") #'kcl-vet)
    ;; Project
    (define-key map (kbd "C-c C-i") #'kcl-goto-imports)
    ;; Documentation
    (define-key map (kbd "C-c C-h") #'kcl-open-doc-at-point)
    ;; Transient
    (define-key map (kbd "C-c C-c") #'kcl-transient)
    map)
  "Keymap for `kcl-mode'.")

;;; Interactive Commands

(defun kcl-run-buffer ()
  "Run the current KCL buffer using `kcl run'."
  (interactive)
  (let ((file (buffer-file-name)))
    (if file
        (compile (format "%s run %s"
                         (shell-quote-argument kcl-command)
                         (shell-quote-argument file)))
      (user-error "Buffer is not visiting a file"))))

(defun kcl-format-buffer ()
  "Format the current KCL buffer using `kcl fmt'.
Saves the buffer, runs `kcl fmt' on the file, and reverts to
pick up the formatted version.  Preserves point position."
  (interactive)
  (let ((file (buffer-file-name))
        (pos (point)))
    (if file
        (progn
          (save-buffer)
          (let* ((cmd (format "%s fmt %s"
                              (shell-quote-argument kcl-command)
                              (shell-quote-argument file)))
                 (exit-code (call-process-shell-command cmd nil "*kcl-fmt*" nil)))
            (if (zerop exit-code)
                (progn
                  (revert-buffer t t t)
                  (goto-char (min pos (point-max)))
                  (message "Formatted %s" (file-name-nondirectory file)))
              (message "kcl fmt failed (exit %d); see *kcl-fmt* buffer"
                       exit-code))))
      (user-error "Buffer is not visiting a file"))))

(defun kcl--format-on-save ()
  "Run `kcl-format-buffer' if `kcl-format-on-save' is enabled.
Intended for use on `before-save-hook'."
  (when kcl-format-on-save
    (kcl-format-buffer)))

;;; Project Root

(defun kcl-project-root ()
  "Return the KCL project root directory.
Looks for `kcl.mod' in parent directories.  Returns nil if not found."
  (when-let ((file (or (buffer-file-name)
                       default-directory)))
    (locate-dominating-file file "kcl.mod")))

;;; Compilation Mode

(defvar kcl-compilation-error-regexp
  '(kcl " *--> \\(.*?\\):\\([0-9]+\\):\\([0-9]+\\)" 1 2 3)
  "Compilation error regexp alist entry for KCL diagnostics.
Matches lines like: --> /path/to/file.k:10:5")

(defvar kcl-compilation-warning-regexp
  '(kcl-warning "^warning\\[W[0-9]+\\]" nil nil nil 1)
  "Compilation warning regexp alist entry for KCL warnings.
Matches lines like: warning[W2001]: ...")

(defvar kcl-compilation-error-type-regexp
  '(kcl-error-type "^\\(?:error\\[E[0-9]+\\]\\|EvaluationError\\)" nil nil nil 2)
  "Compilation error type regexp for KCL errors.
Matches lines like: error[E1001]: ... or EvaluationError")

(define-compilation-mode kcl-compilation-mode "KCL-Compile"
  "Major mode for KCL compilation buffers.
Supports ANSI colors and KCL-style error navigation."
  (setq-local compilation-error-regexp-alist '(kcl))
  (setq-local compilation-error-regexp-alist-alist
              (list kcl-compilation-error-regexp))
  ;; Enable ANSI color rendering
  (add-hook 'compilation-filter-hook #'kcl--colorize-compilation nil t))

(defun kcl--colorize-compilation ()
  "Apply ANSI color codes in the compilation buffer."
  (let ((inhibit-read-only t))
    (ansi-color-apply-on-region compilation-filter-start (point))))

(with-eval-after-load 'compile
  (add-to-list 'compilation-error-regexp-alist-alist
               kcl-compilation-error-regexp)
  (add-to-list 'compilation-error-regexp-alist 'kcl))

;;; which-function-mode support

(defun kcl-mode--which-function ()
  "Return the name of the current KCL definition at point.
For use with `which-function-mode'."
  (save-excursion
    (end-of-line)
    (when (re-search-backward
           (rx line-start (* space)
               (group (or "schema" "mixin" "protocol" "rule"))
               (+ space)
               (group (+ (any word ?_))))
           nil t)
      (let ((kind (match-string 1))
            (name (match-string 2)))
        (format "%s %s" kind name)))))

;;; Eval with Snapshot Diff

(defvar-local kcl--frozen-output nil
  "Frozen snapshot of last `kcl-eval-freeze' output.")

(defvar-local kcl--frozen-format nil
  "Output format used when the snapshot was frozen.")

(defun kcl-eval-buffer ()
  "Evaluate the current KCL buffer and display output in *kcl-output*.
Uses `kcl-eval-output-format' to determine the output format."
  (interactive)
  (let ((file (buffer-file-name)))
    (unless file
      (user-error "Buffer is not visiting a file"))
    (save-buffer)
    (let* ((fmt kcl-eval-output-format)
           (cmd (format "%s run --format %s %s"
                        (shell-quote-argument kcl-command)
                        (shell-quote-argument fmt)
                        (shell-quote-argument file)))
           (output-buf (get-buffer-create "*kcl-output*"))
           (exit-code nil))
      (with-current-buffer output-buf
        (let ((inhibit-read-only t))
          (erase-buffer)))
      (setq exit-code
            (call-process-shell-command cmd nil output-buf nil))
      (with-current-buffer output-buf
        (goto-char (point-min))
        ;; Try to set an appropriate mode for the output
        (cond
         ((string= fmt "json")
          (when (fboundp 'js-mode) (js-mode)))
         ((string= fmt "yaml")
          (if (fboundp 'yaml-mode)
              (yaml-mode)
            (when (fboundp 'yaml-ts-mode) (yaml-ts-mode))))
         ((string= fmt "toml")
          (when (fboundp 'toml-ts-mode) (toml-ts-mode))))
        (setq buffer-read-only t))
      (display-buffer output-buf
                      '((display-buffer-reuse-window
                         display-buffer-in-side-window)
                        (side . right)
                        (window-width . 0.4)))
      (if (zerop exit-code)
          (message "KCL eval completed (%s)" fmt)
        (message "KCL eval failed (exit %d)" exit-code)))))

(defun kcl-eval-freeze ()
  "Save the current eval output as a frozen snapshot for later diffing."
  (interactive)
  (let ((output-buf (get-buffer "*kcl-output*")))
    (unless output-buf
      (user-error "No *kcl-output* buffer; run `kcl-eval-buffer' first"))
    (let ((content (with-current-buffer output-buf
                     (buffer-string))))
      (setq kcl--frozen-output content)
      (setq kcl--frozen-format kcl-eval-output-format)
      (message "Snapshot frozen (%d bytes, %s format)"
               (length kcl--frozen-output)
               kcl--frozen-format))))

(defun kcl-eval-diff ()
  "Re-evaluate the buffer and diff against the frozen snapshot.
Shows the diff in a `diff-mode' buffer."
  (interactive)
  (unless kcl--frozen-output
    (user-error "No frozen snapshot; run `kcl-eval-freeze' first"))
  (let ((file (buffer-file-name))
        (frozen kcl--frozen-output)
        (frozen-fmt kcl--frozen-format))
    (unless file
      (user-error "Buffer is not visiting a file"))
    (save-buffer)
    (let* ((fmt (or frozen-fmt kcl-eval-output-format))
           (cmd (format "%s run --format %s %s"
                        (shell-quote-argument kcl-command)
                        (shell-quote-argument fmt)
                        (shell-quote-argument file)))
           (new-output (shell-command-to-string cmd))
           (old-file (make-temp-file "kcl-frozen-" nil
                                     (concat "." fmt)))
           (new-file (make-temp-file "kcl-current-" nil
                                     (concat "." fmt)))
           (diff-buf (get-buffer-create "*kcl-diff*")))
      (with-temp-file old-file (insert frozen))
      (with-temp-file new-file (insert new-output))
      (with-current-buffer diff-buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (call-process "diff" nil diff-buf nil "-u"
                        "--label" "frozen" "--label" "current"
                        old-file new-file)
          (goto-char (point-min))
          (diff-mode)
          (setq buffer-read-only t)))
      (delete-file old-file)
      (delete-file new-file)
      (if (zerop (buffer-size diff-buf))
          (progn
            (kill-buffer diff-buf)
            (message "No differences from frozen snapshot"))
        (display-buffer diff-buf)
        (message "Differences found; see *kcl-diff* buffer")))))

;;; CLI Commands

(defun kcl-lint-buffer ()
  "Lint the current KCL buffer using `kcl lint'."
  (interactive)
  (let ((file (buffer-file-name)))
    (unless file
      (user-error "Buffer is not visiting a file"))
    (save-buffer)
    (let ((default-directory (or (kcl-project-root)
                                 (file-name-directory file))))
      (compilation-start
       (format "%s lint %s"
               (shell-quote-argument kcl-command)
               (shell-quote-argument file))
       'kcl-compilation-mode))))

(defun kcl-test ()
  "Run `kcl test' on the current project or directory."
  (interactive)
  (let* ((root (kcl-project-root))
         (dir (or root (and (buffer-file-name)
                            (file-name-directory (buffer-file-name)))
                  default-directory)))
    (let ((default-directory dir))
      (compilation-start
       (format "%s test" (shell-quote-argument kcl-command))
       'kcl-compilation-mode))))

(defun kcl-vet (data-file &optional schema-name)
  "Validate DATA-FILE against a KCL schema.
When called interactively, prompts for the data file.
Optional SCHEMA-NAME specifies which schema to validate against."
  (interactive
   (list (read-file-name "Data file to validate: " nil nil t)
         (let ((s (read-string "Schema name (empty for default): ")))
           (if (string-empty-p s) nil s))))
  (let ((kcl-file (buffer-file-name)))
    (unless kcl-file
      (user-error "Buffer is not visiting a KCL file"))
    (save-buffer)
    (let ((cmd (format "%s vet %s %s %s"
                       (shell-quote-argument kcl-command)
                       (shell-quote-argument kcl-file)
                       (shell-quote-argument (expand-file-name data-file))
                       (if schema-name
                           (format "--schema %s"
                                   (shell-quote-argument schema-name))
                         ""))))
      (compilation-start cmd 'kcl-compilation-mode))))

(defun kcl-mod-init ()
  "Initialize a new KCL module in the current directory."
  (interactive)
  (let ((default-directory (or (and (buffer-file-name)
                                    (file-name-directory (buffer-file-name)))
                               default-directory)))
    (compilation-start
     (format "%s mod init" (shell-quote-argument kcl-command))
     'kcl-compilation-mode)))

(defun kcl-mod-add (package)
  "Add PACKAGE dependency to the KCL module."
  (interactive "sPackage to add (e.g., k8s): ")
  (let ((default-directory (or (kcl-project-root)
                               default-directory)))
    (compilation-start
     (format "%s mod add %s"
             (shell-quote-argument kcl-command)
             (shell-quote-argument package))
     'kcl-compilation-mode)))

(defun kcl-goto-imports ()
  "Jump to the import section of the current buffer.
If no imports exist, jump to the beginning of the buffer."
  (interactive)
  (push-mark)
  (goto-char (point-min))
  ;; Skip any leading comments or blank lines
  (while (and (not (eobp))
              (looking-at "^\\([ \t]*#\\|[ \t]*$\\)"))
    (forward-line 1))
  (if (looking-at "^import\\b")
      (message "At import section")
    (goto-char (point-min))
    (message "No imports found; at beginning of file")))

;;; Documentation

(defvar kcl-doc--builtin-type-urls
  '(("str" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#string")
    ("int" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#int")
    ("float" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#float")
    ("bool" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#bool")
    ("list" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#list")
    ("dict" . "https://kcl-lang.io/docs/reference/lang/spec/datatypes#dict"))
  "URL mappings for KCL built-in types.")

(defvar kcl-doc--builtin-function-url
  "https://kcl-lang.io/docs/reference/model/builtin#%s"
  "URL template for KCL built-in functions.")

(defvar kcl-doc--stdlib-modules
  '("math" "net" "crypto" "base64" "json" "yaml" "regex"
    "datetime" "units" "file" "manifests" "runtime" "template")
  "KCL standard library module names.")

(defvar kcl-doc--keyword-urls
  '(("schema" . "https://kcl-lang.io/docs/reference/lang/tour#schema")
    ("rule" . "https://kcl-lang.io/docs/reference/lang/tour#rule")
    ("protocol" . "https://kcl-lang.io/docs/reference/lang/tour#protocol")
    ("mixin" . "https://kcl-lang.io/docs/reference/lang/tour#mixin")
    ("lambda" . "https://kcl-lang.io/docs/reference/lang/tour#lambda")
    ("check" . "https://kcl-lang.io/docs/reference/lang/tour#check")
    ("assert" . "https://kcl-lang.io/docs/reference/lang/tour#assert")
    ("import" . "https://kcl-lang.io/docs/reference/lang/tour#import")
    ("type" . "https://kcl-lang.io/docs/reference/lang/tour#type-alias")
    ("if" . "https://kcl-lang.io/docs/reference/lang/tour#if-elif-else")
    ("for" . "https://kcl-lang.io/docs/reference/lang/tour#comprehension")
    ("in" . "https://kcl-lang.io/docs/reference/lang/tour#membership-operators"))
  "URL mappings for KCL keywords.")

(defun kcl-open-doc-at-point ()
  "Open KCL documentation for the symbol at point in a browser."
  (interactive)
  (let ((symbol (thing-at-point 'symbol t)))
    (unless symbol
      (user-error "No symbol at point"))
    (let ((url (kcl-doc--url-for symbol)))
      (if url
          (progn
            (browse-url url)
            (message "Opening docs for `%s'" symbol))
        (let ((search-url (format "https://kcl-lang.io/search?q=%s" symbol)))
          (browse-url search-url)
          (message "No specific docs for `%s'; searching..." symbol))))))

(defun kcl-doc--url-for (symbol)
  "Return a documentation URL for SYMBOL, or nil if unknown."
  (cond
   ;; Built-in type
   ((assoc symbol kcl-doc--builtin-type-urls)
    (cdr (assoc symbol kcl-doc--builtin-type-urls)))
   ;; Keyword
   ((assoc symbol kcl-doc--keyword-urls)
    (cdr (assoc symbol kcl-doc--keyword-urls)))
   ;; Built-in function
   ((member symbol kcl-mode--builtin-functions)
    (format kcl-doc--builtin-function-url symbol))
   ;; Standard library module (e.g., "math" from import math)
   ((member symbol kcl-doc--stdlib-modules)
    (format "https://kcl-lang.io/docs/reference/model/%s" symbol))
   ;; Module.function (e.g., "math.log")
   ((string-match "\\`\\([a-z_]+\\)\\.\\([a-z_]+\\)\\'" symbol)
    (let ((mod (match-string 1 symbol))
          (func (match-string 2 symbol)))
      (when (member mod kcl-doc--stdlib-modules)
        (format "https://kcl-lang.io/docs/reference/model/%s#%s" mod func))))
   (t nil)))

;;; Tempo Templates

(require 'tempo)

(defvar kcl-tempo-tags nil
  "Tempo tags for KCL mode.")

(tempo-define-template "kcl-schema"
  '("schema " (p "Schema name: " name) ":" n>
    (p "Docstring: " doc) n>
    r> n>
    "check:" n>
    p)
  "schema"
  "Insert a KCL schema definition."
  'kcl-tempo-tags)

(tempo-define-template "kcl-rule"
  '("rule " (p "Rule name: " name) ":" n>
    (p "Docstring: " doc) n>
    r> p)
  "rule"
  "Insert a KCL rule definition."
  'kcl-tempo-tags)

(tempo-define-template "kcl-mixin"
  '("mixin " (p "Mixin name: " name) ":" n>
    (p "Docstring: " doc) n>
    r> p)
  "mixin"
  "Insert a KCL mixin definition."
  'kcl-tempo-tags)

(tempo-define-template "kcl-protocol"
  '("protocol " (p "Protocol name: " name) ":" n>
    r> p)
  "protocol"
  "Insert a KCL protocol definition."
  'kcl-tempo-tags)

(tempo-define-template "kcl-check"
  '("check:" n>
    (p "Constraint expression: " expr) > ", \"" (p "Error message: " msg) "\"" p)
  "check"
  "Insert a KCL check block."
  'kcl-tempo-tags)

(tempo-define-template "kcl-import"
  '("import " (p "Module path: " module) p)
  "import"
  "Insert a KCL import statement."
  'kcl-tempo-tags)

(tempo-define-template "kcl-lambda"
  '("lambda " (p "Parameters: " params) " {" n>
    r> p n>
    "}")
  "lambda"
  "Insert a KCL lambda expression."
  'kcl-tempo-tags)

(tempo-define-template "kcl-if"
  '("if " (p "Condition: " cond) ":" n>
    r> p)
  "kclif"
  "Insert a KCL if block."
  'kcl-tempo-tags)

(tempo-define-template "kcl-for"
  '("for " (p "Variable: " var) " in " (p "Iterable: " iter) " {" n>
    r> p n>
    "}")
  "for"
  "Insert a KCL for comprehension."
  'kcl-tempo-tags)

(tempo-define-template "kcl-assert"
  '("assert " (p "Condition: " cond) ", \"" (p "Message: " msg) "\"" p)
  "assert"
  "Insert a KCL assertion."
  'kcl-tempo-tags)

;;; Flymake Integration

(defvar-local kcl--flymake-proc nil
  "Current flymake process for KCL.")

(defun kcl-flymake-backend (report-fn &rest _args)
  "Flymake backend for KCL using `kcl lint'.
REPORT-FN is the Flymake callback."
  (when (process-live-p kcl--flymake-proc)
    (kill-process kcl--flymake-proc))
  (let* ((source (current-buffer))
         (file (buffer-file-name)))
    (unless file
      (funcall report-fn nil)
      (cl-return-from kcl-flymake-backend))
    (save-buffer)
    (setq kcl--flymake-proc
          (make-process
           :name "kcl-flymake"
           :noquery t
           :connection-type 'pipe
           :buffer (generate-new-buffer " *kcl-flymake*")
           :command (list kcl-command "lint" "--no_style" file)
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (unwind-protect
                   (when (eq proc (buffer-local-value 'kcl--flymake-proc source))
                     (with-current-buffer (process-buffer proc)
                       (goto-char (point-min))
                       (let ((diags nil)
                             (source-file (buffer-file-name source)))
                         (while (re-search-forward
                                 " *--> \\(.*?\\):\\([0-9]+\\):\\([0-9]+\\)"
                                 nil t)
                           (let* ((diag-file (match-string 1))
                                  (line (string-to-number (match-string 2)))
                                  (col (string-to-number (match-string 3)))
                                  ;; Look backward for error/warning type
                                  (type (save-excursion
                                          (if (re-search-backward
                                               "^warning\\[W[0-9]+\\]" nil t)
                                              :warning
                                            :error)))
                                  ;; Get the message from the line after -->
                                  (msg (save-excursion
                                         (forward-line 0)
                                         (buffer-substring-no-properties
                                          (point) (line-end-position)))))
                             ;; Only report diagnostics for the source file
                             (when (and source-file
                                        (string= (expand-file-name diag-file)
                                                 (expand-file-name source-file)))
                               (with-current-buffer source
                                 (save-excursion
                                   (goto-char (point-min))
                                   (forward-line (1- line))
                                   (let* ((bol (point))
                                          (eol (line-end-position))
                                          (beg (min (+ bol (1- col)) eol))
                                          (end (min (+ beg 1) eol)))
                                     (push (flymake-make-diagnostic
                                            source beg end type
                                            (string-trim msg))
                                           diags)))))))
                         (funcall report-fn (nreverse diags)))))
                 (kill-buffer (process-buffer proc)))))))))

;;; Transient Menu

(defun kcl-transient ()
  "Show the KCL command menu.
If `transient' is available, shows a transient popup.
Otherwise, shows a simple `completing-read' menu."
  (interactive)
  (if (fboundp 'transient-define-prefix)
      (call-interactively #'kcl-transient-menu)
    ;; Fallback for when transient is not available
    (let* ((commands '(("r - Run buffer" . kcl-run-buffer)
                       ("e - Eval buffer" . kcl-eval-buffer)
                       ("f - Format buffer" . kcl-format-buffer)
                       ("l - Lint buffer" . kcl-lint-buffer)
                       ("t - Test project" . kcl-test)
                       ("v - Vet data file" . kcl-vet)
                       ("s - Freeze snapshot" . kcl-eval-freeze)
                       ("d - Diff snapshot" . kcl-eval-diff)
                       ("i - Go to imports" . kcl-goto-imports)
                       ("D - Doc at point" . kcl-open-doc-at-point)
                       ("I - Mod init" . kcl-mod-init)
                       ("a - Mod add" . kcl-mod-add)))
           (choice (completing-read "KCL command: " commands nil t)))
      (call-interactively (cdr (assoc choice commands))))))

(with-eval-after-load 'transient
  (transient-define-prefix kcl-transient-menu ()
    "KCL commands."
    ["Evaluate"
     ("r" "Run buffer" kcl-run-buffer)
     ("e" "Eval buffer" kcl-eval-buffer)
     ("s" "Freeze snapshot" kcl-eval-freeze)
     ("d" "Diff snapshot" kcl-eval-diff)]
    ["Tooling"
     ("f" "Format buffer" kcl-format-buffer)
     ("l" "Lint buffer" kcl-lint-buffer)
     ("t" "Test project" kcl-test)
     ("v" "Vet data file" kcl-vet)]
    ["Project"
     ("I" "Mod init" kcl-mod-init)
     ("a" "Mod add" kcl-mod-add)
     ("i" "Go to imports" kcl-goto-imports)]
    ["Documentation"
     ("D" "Doc at point" kcl-open-doc-at-point)]))

;;; Mode Definition

;;;###autoload
(define-derived-mode kcl-mode prog-mode "KCL"
  "Major mode for editing KCL (Kusion Configuration Language) files.

KCL is an open-source, constraint-based record and functional
language for cloud-native configuration.

\\{kcl-mode-map}"
  :group 'kcl
  :syntax-table kcl-mode-syntax-table

  ;; Comments
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+\\s-*")
  (setq-local comment-end "")

  ;; Font lock
  (setq-local font-lock-defaults
              '(kcl-mode--font-lock-keywords
                nil nil nil nil
                (font-lock-syntactic-face-function
                 . kcl-mode--syntactic-face-function)))

  ;; Syntax propertize for triple-quoted strings and interpolation
  (setq-local syntax-propertize-function
              kcl-mode--syntax-propertize-function)

  ;; Indentation
  (setq-local indent-line-function #'kcl-mode-indent-line)
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width kcl-indent-offset)

  ;; Electric
  (setq-local electric-indent-chars
              (append '(?: ?\} ?\] ?\)) electric-indent-chars))

  ;; Navigation
  (setq-local beginning-of-defun-function #'kcl-mode-beginning-of-defun)
  (setq-local end-of-defun-function #'kcl-mode-end-of-defun)

  ;; Imenu
  (setq-local imenu-generic-expression
              `(("Schema" ,(rx line-start (* space) "schema" (+ space)
                               (group (+ (any word ?_))))
                 1)
                ("Rule" ,(rx line-start (* space) "rule" (+ space)
                             (group (+ (any word ?_))))
                 1)
                ("Protocol" ,(rx line-start (* space) "protocol" (+ space)
                                 (group (+ (any word ?_))))
                 1)
                ("Mixin" ,(rx line-start (* space) "mixin" (+ space)
                              (group (+ (any word ?_))))
                 1)
                ("Type" ,(rx line-start (* space) "type" (+ space)
                             (group (+ (any word ?_))))
                 1)))

  ;; Outline
  (setq-local outline-regexp
              (rx line-start (* space)
                  (or "schema" "mixin" "protocol" "rule" "type")
                  space))

  ;; which-function-mode
  (setq-local which-func-functions '(kcl-mode--which-function))

  ;; Flymake
  (add-hook 'flymake-diagnostic-functions #'kcl-flymake-backend nil t)

  ;; Tempo
  (tempo-use-tag-list 'kcl-tempo-tags)

  ;; Format on save
  (add-hook 'before-save-hook #'kcl--format-on-save nil t))

(defun kcl-mode--syntactic-face-function (ppss)
  "Return face for syntax at PPSS.
Handles comments and strings."
  (if (nth 4 ppss)
      font-lock-comment-face
    (if (nth 3 ppss)
        font-lock-string-face
      nil)))

(defun kcl-mode-beginning-of-defun (&optional arg)
  "Move to the beginning of the current schema/rule/protocol definition.
With ARG, move to the ARGth preceding definition."
  (interactive "^p")
  (setq arg (or arg 1))
  (re-search-backward
   (rx line-start (* space)
       (or "schema" "mixin" "protocol" "rule")
       (+ space) (+ (any word ?_)))
   nil t arg))

(defun kcl-mode-end-of-defun (&optional arg)
  "Move to the end of the current schema/rule/protocol definition.
With ARG, move to the ARGth following definition end."
  (interactive "^p")
  (setq arg (or arg 1))
  (dotimes (_ arg)
    ;; Move past the current defun header
    (unless (looking-at (rx line-start (* space)
                            (or "schema" "mixin" "protocol" "rule")))
      (kcl-mode-beginning-of-defun 1))
    (forward-line 1)
    (let ((base-indent (current-indentation)))
      ;; Move forward while lines are more indented or blank
      (while (and (not (eobp))
                  (or (looking-at "^[ \t]*$")
                      (> (current-indentation) base-indent)
                      (and (= (current-indentation) base-indent)
                           (looking-at "^[ \t]*\\(check\\|mixin\\)\\b"))))
        (forward-line 1))
      ;; Skip any trailing blank lines
      (while (and (not (eobp))
                  (looking-at "^[ \t]*$"))
        (forward-line 1)))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.k\\'" . kcl-mode))

(provide 'kcl-mode)

;;; kcl-mode.el ends here
