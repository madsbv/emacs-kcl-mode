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
;;
;; Usage:
;;   (require 'kcl-mode)
;;
;; Files with the `.k' extension are automatically opened in kcl-mode.

;;; Code:

(require 'rx)

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
    ;; Add useful key bindings
    (define-key map (kbd "C-c C-r") #'kcl-run-buffer)
    (define-key map (kbd "C-c C-f") #'kcl-format-buffer)
    map)
  "Keymap for `kcl-mode'.")

;;; Interactive Commands

(defun kcl-run-buffer ()
  "Run the current KCL buffer using `kcl run'."
  (interactive)
  (let ((file (buffer-file-name)))
    (if file
        (compile (format "kcl run %s" (shell-quote-argument file)))
      (user-error "Buffer is not visiting a file"))))

(defun kcl-format-buffer ()
  "Format the current KCL buffer using `kcl fmt'."
  (interactive)
  (let ((file (buffer-file-name)))
    (if file
        (progn
          (save-buffer)
          (let ((output (shell-command-to-string
                         (format "kcl fmt %s" (shell-quote-argument file)))))
            (revert-buffer t t t)
            (message "KCL formatted: %s" (string-trim output))))
      (user-error "Buffer is not visiting a file"))))

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
                  space)))

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
