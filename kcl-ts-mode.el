;;; kcl-ts-mode.el --- Tree-sitter major mode for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, tools
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; Tree-sitter based major mode for editing KCL (Kusion Configuration
;; Language) files.  Requires the tree-sitter-kcl grammar shared
;; library to be installed.
;;
;; This mode provides accurate, parse-tree-based:
;; - Syntax highlighting (font-lock)
;; - Indentation
;; - Navigation (defun, sibling)
;; - Imenu
;;
;; To install the grammar, build tree-sitter-kcl from source:
;;   git clone https://github.com/kcl-lang/tree-sitter-kcl
;;   cd tree-sitter-kcl
;;   gcc -shared -fPIC -O2 -o libtree-sitter-kcl.so src/parser.c src/scanner.c -I src
;;
;; Then place libtree-sitter-kcl.so on `treesit-extra-load-path' or
;; in the Emacs default tree-sitter load directory.
;;
;; Usage:
;;   (require 'kcl-ts-mode)

;;; Code:

(require 'treesit)
(require 'rx)
(require 'kcl-mode)  ; shared commands and customization

(declare-function treesit-parser-create "treesit.c")

;;; Customization

(defgroup kcl-ts nil
  "Tree-sitter based major mode for KCL."
  :group 'languages
  :prefix "kcl-ts-")

(defcustom kcl-ts-mode-indent-offset 4
  "Number of spaces for each indentation level in `kcl-ts-mode'."
  :type 'integer
  :group 'kcl-ts)

;;; Font-lock

(defvar kcl-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'kcl
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'kcl
   :feature 'string
   '((string) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face)

   :language 'kcl
   :feature 'string
   :override t
   '((schema_stmt
      body: (block :anchor
                   (string (string_content) @font-lock-doc-face)))
     (rule_stmt
      body: (block :anchor
                   (string (string_content) @font-lock-doc-face)))
     (protocol_stmt
      body: (block :anchor
                   (string (string_content) @font-lock-doc-face))))

   :language 'kcl
   :feature 'keyword
   '(["all" "any" "assert" "as" "check" "elif" "else"
      "filter" "for" "if" "import" "lambda" "map"
      "mixin" "protocol" "rule" "schema" "type"]
     @font-lock-keyword-face)

   :language 'kcl
   :feature 'operator
   '(["and" "or" "not" "in" "is"] @font-lock-keyword-face
     ["+" "-" "*" "**" "/" "//" "%" "<<" ">>" "&" "|" "^"
      "<" ">" "~" "<=" ">=" "==" "!=" "=" ":"]
     @font-lock-operator-face)

   :language 'kcl
   :feature 'constant
   '([(true) (false) (none) (undefined)] @font-lock-constant-face)

   :language 'kcl
   :feature 'number
   '([(integer) (float)] @font-lock-number-face)

   :language 'kcl
   :feature 'type
   '((basic_type) @font-lock-type-face
     (schema_type (dotted_name (identifier) @font-lock-type-face))
     (schema_stmt name: (identifier) @font-lock-type-face)
     (protocol_stmt (identifier) @font-lock-type-face)
     (rule_stmt (identifier) @font-lock-type-face)
     (schema_expr (identifier) @font-lock-type-face))

   :language 'kcl
   :feature 'definition
   '((schema_stmt name: (identifier) @font-lock-type-face)
     (protocol_stmt (identifier) @font-lock-type-face)
     (rule_stmt (identifier) @font-lock-type-face))

   :language 'kcl
   :feature 'function
   '((call_expr function: (identifier) @font-lock-function-call-face)
     (call_expr
      function: (selector_expr
                 (select_suffix
                  (identifier) @font-lock-function-call-face))))

   :language 'kcl
   :feature 'property
   '((selector_expr
      (select_suffix (identifier) @font-lock-property-use-face))
     ;; Schema attribute declarations
     (assign_stmt left: (dotted_name (identifier) @font-lock-variable-name-face))
     (optional_attribute_declaration
      attribute: (identifier) @font-lock-variable-name-face))

   :language 'kcl
   :feature 'namespace
   '((import_stmt
      name: (dotted_name (identifier) @font-lock-constant-face))
     (import_stmt "as" (identifier) @font-lock-constant-face))

   :language 'kcl
   :feature 'decorator
   '((decorator (identifier) @font-lock-preprocessor-face))

   :language 'kcl
   :feature 'parameter
   '((lambda_expr
      (typed_parameter (identifier) @font-lock-variable-name-face))
     (lambda_expr (identifier) @font-lock-variable-name-face))

   :language 'kcl
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face)

   :language 'kcl
   :feature 'interpolation
   :override t
   '((interpolation "${" @font-lock-misc-punctuation-face
                    "}" @font-lock-misc-punctuation-face)))
  "Tree-sitter font-lock settings for KCL.")

;;; Indentation

(defvar kcl-ts-mode--indent-rules
  `((kcl
     ;; Top-level: no indent
     ((parent-is "module") column-0 0)

     ;; Inside schema/rule/protocol/mixin body
     ((parent-is "block") parent-bol kcl-ts-mode-indent-offset)

     ;; Inside check statement
     ((parent-is "check_stmt") parent-bol kcl-ts-mode-indent-offset)

     ;; Inside if/elif/else bodies
     ((parent-is "if_stmt") parent-bol kcl-ts-mode-indent-offset)
     ((parent-is "elif_clause") parent-bol kcl-ts-mode-indent-offset)
     ((parent-is "else_clause") parent-bol kcl-ts-mode-indent-offset)

     ;; Closing brackets align with opening
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)

     ;; List/dict/config entries
     ((parent-is "list_expr") parent-bol kcl-ts-mode-indent-offset)
     ((parent-is "config_expr") parent-bol kcl-ts-mode-indent-offset)
     ((parent-is "config_entries") parent-bol 0)

     ;; Schema instantiation arguments
     ((parent-is "argument_list") parent-bol kcl-ts-mode-indent-offset)

     ;; Comprehension body
     ((parent-is "list_comprehension") parent-bol kcl-ts-mode-indent-offset)
     ((parent-is "dict_comprehension") parent-bol kcl-ts-mode-indent-offset)

     ;; Lambda body
     ((parent-is "lambda_expr") parent-bol kcl-ts-mode-indent-offset)

     ;; Decorator followed by definition
     ((parent-is "decorators") parent-bol 0)

     ;; Fallback: no change
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for KCL.")

;;; Navigation / Imenu

(defvar kcl-ts-mode--defun-type-regexp
  (rx (or "schema_stmt" "rule_stmt" "protocol_stmt" "mixin_stmt"))
  "Regexp matching tree-sitter node types for KCL definitions.")

(defun kcl-ts-mode--defun-name (node)
  "Return the name of the KCL definition at NODE."
  (let ((name-node (treesit-node-child-by-field-name node "name")))
    (when name-node
      (treesit-node-text name-node t))))

;;; Mode definition

;;;###autoload
(define-derived-mode kcl-ts-mode prog-mode "KCL"
  "Tree-sitter based major mode for editing KCL files.

KCL is an open-source, constraint-based record and functional
language for cloud-native configuration.

\\{kcl-ts-mode-map}"
  :group 'kcl-ts
  :syntax-table (let ((table (make-syntax-table)))
                  (modify-syntax-entry ?# "<" table)
                  (modify-syntax-entry ?\n ">" table)
                  (modify-syntax-entry ?_ "w" table)
                  (modify-syntax-entry ?$ "_" table)
                  table)

  (unless (treesit-ready-p 'kcl)
    (error "Tree-sitter grammar for KCL is not available"))

  (treesit-parser-create 'kcl)

  ;; Comments
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+\\s-*")
  (setq-local comment-end "")

  ;; Font-lock
  (setq-local treesit-font-lock-settings kcl-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword constant number type definition)
                (function property namespace decorator parameter operator)
                (bracket interpolation)))

  ;; Indentation
  (setq-local treesit-simple-indent-rules kcl-ts-mode--indent-rules)
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width kcl-ts-mode-indent-offset)

  ;; Navigation
  (setq-local treesit-defun-type-regexp kcl-ts-mode--defun-type-regexp)
  (setq-local treesit-defun-name-function #'kcl-ts-mode--defun-name)

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              `(("Schema" "\\`schema_stmt\\'" nil nil)
                ("Rule" "\\`rule_stmt\\'" nil nil)
                ("Protocol" "\\`protocol_stmt\\'" nil nil)
                ("Mixin" "\\`mixin_stmt\\'" nil nil)))

  ;; Electric
  (setq-local electric-indent-chars
              (append '(?: ?\} ?\] ?\)) electric-indent-chars))

  ;; Format on save
  (add-hook 'before-save-hook #'kcl--format-on-save nil t)

  (treesit-major-mode-setup))

(defvar kcl-ts-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-r") #'kcl-run-buffer)
    (define-key map (kbd "C-c C-f") #'kcl-format-buffer)
    map)
  "Keymap for `kcl-ts-mode'.")

;;; Auto-mode integration
;; When tree-sitter grammar is available, prefer kcl-ts-mode over kcl-mode
;;;###autoload
(when (treesit-available-p)
  (add-to-list 'major-mode-remap-alist '(kcl-mode . kcl-ts-mode)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.k\\'" . kcl-ts-mode))

;;; treesit-auto integration
;; When treesit-auto is available, register a recipe for automatic grammar
;; installation.  This is deferred via eval-after-load to avoid a hard
;; dependency on treesit-auto.
(declare-function make-treesit-auto-recipe "treesit-auto")
(defvar treesit-auto-recipe-list)
(defvar treesit-auto-langs)

(eval-after-load 'treesit-auto
  '(let ((kcl-recipe (make-treesit-auto-recipe
                      :lang 'kcl
                      :ts-mode 'kcl-ts-mode
                      :remap 'kcl-mode
                      :url "https://github.com/kcl-lang/tree-sitter-kcl"
                      :ext "\\.k\\'")))
     (unless (seq-find (lambda (r) (eq (treesit-auto-recipe-lang r) 'kcl))
                       treesit-auto-recipe-list)
       (add-to-list 'treesit-auto-recipe-list kcl-recipe))
     (unless (memq 'kcl treesit-auto-langs)
       (add-to-list 'treesit-auto-langs 'kcl))))

(provide 'kcl-ts-mode)

;;; kcl-ts-mode.el ends here
