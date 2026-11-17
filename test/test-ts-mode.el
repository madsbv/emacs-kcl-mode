;;; test-ts-mode.el --- Tests for kcl-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Mads Bach Villadsen
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:

;; ERT tests for the tree-sitter based KCL major mode.
;; Requires the tree-sitter-kcl grammar to be installed.

;;; Code:

(require 'ert)
(require 'treesit)

;; Set up grammar load path.
(setq treesit-extra-load-path
      (list (or (getenv "KCL_TREE_SITTER_LOAD_PATH")
                (file-name-directory
                 (directory-file-name
                  (file-name-directory
                   (or load-file-name buffer-file-name)))))))

(require 'kcl-ts-mode)

;;; Test helpers

(defmacro kcl-ts-test-with-buffer (content &rest body)
  "Insert CONTENT into a temporary buffer in `kcl-ts-mode' and run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,content)
     (kcl-ts-mode)
     (font-lock-ensure)
     ,@body))

(defun kcl-ts-test-face-at (text &optional occurrence)
  "Return the face at the first character of TEXT in the buffer.
If OCCURRENCE is given, find the Nth occurrence (1-indexed)."
  (let ((count (or occurrence 1)))
    (save-excursion
      (goto-char (point-min))
      (dotimes (_ count)
        (search-forward text))
      (get-text-property (- (point) (length text)) 'face))))

;;; Mode basics

(ert-deftest kcl-ts-mode-activates ()
  "Test that kcl-ts-mode activates correctly."
  (kcl-ts-test-with-buffer "x = 1\n"
    (should (eq major-mode 'kcl-ts-mode))
    (should (treesit-parser-list))))

(ert-deftest kcl-ts-mode-comment-settings ()
  "Test comment configuration."
  (kcl-ts-test-with-buffer ""
    (should (string= comment-start "# "))
    (should (string= comment-end ""))))

;;; Keywords

(ert-deftest kcl-ts-keyword-schema ()
  "Test schema keyword highlighting."
  (kcl-ts-test-with-buffer "schema Foo:\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "schema") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-rule ()
  "Test rule keyword highlighting."
  (kcl-ts-test-with-buffer "rule MyRule:\n    True\n"
    (should (eq (kcl-ts-test-face-at "rule") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-protocol ()
  "Test protocol keyword highlighting."
  (kcl-ts-test-with-buffer "protocol MyProto:\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "protocol") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-import ()
  "Test import keyword highlighting."
  (kcl-ts-test-with-buffer "import math\n"
    (should (eq (kcl-ts-test-face-at "import") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-if ()
  "Test if/elif/else keywords."
  (kcl-ts-test-with-buffer "if True:\n    x = 1\nelif False:\n    x = 2\nelse:\n    x = 3\n"
    (should (eq (kcl-ts-test-face-at "if") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "elif") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "else") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-for ()
  "Test for keyword highlighting."
  (kcl-ts-test-with-buffer "x = [i for i in [1, 2]]\n"
    (should (eq (kcl-ts-test-face-at "for") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-lambda ()
  "Test lambda keyword highlighting."
  (kcl-ts-test-with-buffer "f = lambda x: int -> int {\n    x + 1\n}\n"
    (should (eq (kcl-ts-test-face-at "lambda") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-assert ()
  "Test assert keyword highlighting."
  (kcl-ts-test-with-buffer "assert True\n"
    (should (eq (kcl-ts-test-face-at "assert") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-check ()
  "Test check keyword highlighting."
  (kcl-ts-test-with-buffer "schema Foo:\n    x: int\n    check:\n        x > 0\n"
    (should (eq (kcl-ts-test-face-at "check") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-all-any-map-filter ()
  "Test quantifier keywords."
  (kcl-ts-test-with-buffer "a = all x in [1] { x > 0 }\nb = any x in [1] { x > 0 }\nc = map x in [1] { x + 1 }\nd = filter x in [1] { x > 0 }\n"
    (should (eq (kcl-ts-test-face-at "all") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "any") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "map") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "filter") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-type ()
  "Test type alias keyword."
  (kcl-ts-test-with-buffer "type Units = str | int\n"
    (should (eq (kcl-ts-test-face-at "type") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-as ()
  "Test as keyword."
  (kcl-ts-test-with-buffer "import pkg as p\n"
    (should (eq (kcl-ts-test-face-at "as") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-keyword-mixin ()
  "Test mixin keyword."
  (kcl-ts-test-with-buffer "schema Foo:\n    mixin [Bar]\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "mixin") 'font-lock-keyword-face))))

;;; Operator keywords

(ert-deftest kcl-ts-operator-and-or-not ()
  "Test and/or/not keywords as operators."
  (kcl-ts-test-with-buffer "x = True and False or not True\n"
    (should (eq (kcl-ts-test-face-at "and") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "or") 'font-lock-keyword-face))
    (should (eq (kcl-ts-test-face-at "not") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-operator-in ()
  "Test 'in' keyword highlighting."
  (kcl-ts-test-with-buffer "x = \"a\" in [\"a\", \"b\"]\n"
    (should (eq (kcl-ts-test-face-at "in") 'font-lock-keyword-face))))

(ert-deftest kcl-ts-operator-is ()
  "Test 'is' keyword highlighting."
  (kcl-ts-test-with-buffer "x = None is None\n"
    (should (eq (kcl-ts-test-face-at "is") 'font-lock-keyword-face))))

;;; Constants

(ert-deftest kcl-ts-constant-true ()
  "Test True constant."
  (kcl-ts-test-with-buffer "x = True\n"
    (should (eq (kcl-ts-test-face-at "True") 'font-lock-constant-face))))

(ert-deftest kcl-ts-constant-false ()
  "Test False constant."
  (kcl-ts-test-with-buffer "x = False\n"
    (should (eq (kcl-ts-test-face-at "False") 'font-lock-constant-face))))

(ert-deftest kcl-ts-constant-none ()
  "Test None constant."
  (kcl-ts-test-with-buffer "x = None\n"
    (should (eq (kcl-ts-test-face-at "None") 'font-lock-constant-face))))

(ert-deftest kcl-ts-constant-undefined ()
  "Test Undefined constant."
  (kcl-ts-test-with-buffer "x = Undefined\n"
    (should (eq (kcl-ts-test-face-at "Undefined") 'font-lock-constant-face))))

;;; Numbers

(ert-deftest kcl-ts-number-integer ()
  "Test integer literal highlighting."
  (kcl-ts-test-with-buffer "x = 42\n"
    (should (eq (kcl-ts-test-face-at "42") 'font-lock-number-face))))

(ert-deftest kcl-ts-number-float ()
  "Test float literal highlighting."
  (kcl-ts-test-with-buffer "x = 3.14\n"
    (should (eq (kcl-ts-test-face-at "3.14") 'font-lock-number-face))))

(ert-deftest kcl-ts-number-hex ()
  "Test hex literal highlighting."
  (kcl-ts-test-with-buffer "x = 0xFF\n"
    (should (eq (kcl-ts-test-face-at "0xFF") 'font-lock-number-face))))

;;; Types

(ert-deftest kcl-ts-type-basic ()
  "Test basic type highlighting."
  (kcl-ts-test-with-buffer "schema Foo:\n    x: str\n    y: int\n    z: float\n    w: bool\n"
    (should (eq (kcl-ts-test-face-at "str") 'font-lock-type-face))
    (should (eq (kcl-ts-test-face-at "int") 'font-lock-type-face))
    (should (eq (kcl-ts-test-face-at "float") 'font-lock-type-face))
    (should (eq (kcl-ts-test-face-at "bool") 'font-lock-type-face))))

(ert-deftest kcl-ts-type-schema-name ()
  "Test schema name gets type face."
  (kcl-ts-test-with-buffer "schema MySchema:\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "MySchema") 'font-lock-type-face))))

(ert-deftest kcl-ts-type-rule-name ()
  "Test rule name gets type face."
  (kcl-ts-test-with-buffer "rule MyRule:\n    True\n"
    (should (eq (kcl-ts-test-face-at "MyRule") 'font-lock-type-face))))

(ert-deftest kcl-ts-type-protocol-name ()
  "Test protocol name gets type face."
  (kcl-ts-test-with-buffer "protocol MyProto:\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "MyProto") 'font-lock-type-face))))

(ert-deftest kcl-ts-type-schema-expr ()
  "Test schema instantiation type."
  (kcl-ts-test-with-buffer "x = Person {\n    name = \"Alice\"\n}\n"
    (should (eq (kcl-ts-test-face-at "Person") 'font-lock-type-face))))

;;; Strings

(ert-deftest kcl-ts-string-double ()
  "Test double-quoted string."
  (kcl-ts-test-with-buffer "x = \"hello\"\n"
    (should (eq (kcl-ts-test-face-at "hello") 'font-lock-string-face))))

(ert-deftest kcl-ts-string-single ()
  "Test single-quoted string."
  (kcl-ts-test-with-buffer "x = 'hello'\n"
    (should (eq (kcl-ts-test-face-at "hello") 'font-lock-string-face))))

;;; Comments

(ert-deftest kcl-ts-comment ()
  "Test comment highlighting."
  (kcl-ts-test-with-buffer "# This is a comment\nx = 1\n"
    (should (eq (kcl-ts-test-face-at "This") 'font-lock-comment-face))))

(ert-deftest kcl-ts-inline-comment ()
  "Test inline comment highlighting."
  (kcl-ts-test-with-buffer "x = 1  # inline\n"
    (should (eq (kcl-ts-test-face-at "inline") 'font-lock-comment-face))))

;;; Decorators

(ert-deftest kcl-ts-decorator ()
  "Test decorator highlighting."
  (kcl-ts-test-with-buffer "@deprecated\nschema Foo:\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "deprecated") 'font-lock-preprocessor-face))))

;;; Functions

(ert-deftest kcl-ts-function-call ()
  "Test function call highlighting."
  (kcl-ts-test-with-buffer "x = len([1, 2, 3])\n"
    (should (eq (kcl-ts-test-face-at "len") 'font-lock-function-call-face))))

(ert-deftest kcl-ts-method-call ()
  "Test method call highlighting."
  (kcl-ts-test-with-buffer "x = regex.match(\"a\", \"b\")\n"
    (should (eq (kcl-ts-test-face-at "match") 'font-lock-function-call-face))))

;;; Properties

(ert-deftest kcl-ts-property-access ()
  "Test property access highlighting."
  (kcl-ts-test-with-buffer "x = obj.prop\n"
    (should (eq (kcl-ts-test-face-at "prop") 'font-lock-property-use-face))))

;;; Imports / namespace

(ert-deftest kcl-ts-import-module ()
  "Test import module name highlighting."
  (kcl-ts-test-with-buffer "import math\n"
    (should (eq (kcl-ts-test-face-at "math") 'font-lock-constant-face))))

(ert-deftest kcl-ts-import-alias ()
  "Test import alias highlighting."
  (kcl-ts-test-with-buffer "import pkg as myalias\n"
    (should (eq (kcl-ts-test-face-at "myalias") 'font-lock-constant-face))))

;;; Lambda parameters

(ert-deftest kcl-ts-lambda-parameter ()
  "Test lambda parameter highlighting."
  (kcl-ts-test-with-buffer "f = lambda x: int -> int {\n    x + 1\n}\n"
    (should (eq (kcl-ts-test-face-at "x") 'font-lock-variable-name-face))))

;;; Schema attributes

(ert-deftest kcl-ts-schema-attribute ()
  "Test schema attribute name highlighting."
  (kcl-ts-test-with-buffer "schema Foo:\n    name: str\n"
    (should (eq (kcl-ts-test-face-at "name") 'font-lock-variable-name-face))))

(ert-deftest kcl-ts-optional-attribute ()
  "Test optional attribute highlighting."
  (kcl-ts-test-with-buffer "schema Foo:\n    label?: str\n"
    (should (eq (kcl-ts-test-face-at "label") 'font-lock-variable-name-face))))

;;; Docstrings

(ert-deftest kcl-ts-schema-docstring ()
  "Test schema docstring gets doc face."
  (kcl-ts-test-with-buffer "schema Foo:\n    \"\"\"This is a docstring.\"\"\"\n    x: int\n"
    (should (eq (kcl-ts-test-face-at "docstring") 'font-lock-doc-face))))

;;; Imenu

(ert-deftest kcl-ts-imenu-schema ()
  "Test imenu finds schema definitions."
  (kcl-ts-test-with-buffer "schema Person:\n    name: str\n\nschema Employee:\n    company: str\n"
    (let ((index (treesit-simple-imenu)))
      (should (assoc "Schema" index)))))

;;; Navigation

(ert-deftest kcl-ts-beginning-of-defun ()
  "Test beginning-of-defun navigates to schema start."
  (kcl-ts-test-with-buffer "schema Foo:\n    x: int\n    y: str\n"
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at "schema Foo"))))

(provide 'test-ts-mode)

;;; test-ts-mode.el ends here
