;;; test-fontlock.el --- ERT tests for kcl-mode font-lock -*- lexical-binding: t; -*-

;; Tests for kcl-mode syntax highlighting.

;;; Code:

(require 'ert)
(require 'kcl-mode)

;;; Test helpers

(defun kcl-test--face-at (text pos)
  "Return the face at POS in TEXT after fontifying with `kcl-mode'."
  (with-temp-buffer
    (kcl-mode)
    (insert text)
    (font-lock-ensure)
    (get-text-property pos 'face)))

(defun kcl-test--faces-in (text)
  "Return an alist of (TOKEN . FACE) for all fontified spans in TEXT."
  (with-temp-buffer
    (kcl-mode)
    (insert text)
    (font-lock-ensure)
    (let ((result nil)
          (pos (point-min)))
      (while (< pos (point-max))
        (let* ((face (get-text-property pos 'face))
               (next (or (next-single-property-change pos 'face) (point-max)))
               (token (buffer-substring-no-properties pos next)))
          (when face
            (push (cons (string-trim token) face) result))
          (setq pos next)))
      (nreverse result))))

(defun kcl-test--has-face (text substring expected-face)
  "Check that SUBSTRING in TEXT has EXPECTED-FACE after fontification."
  (with-temp-buffer
    (kcl-mode)
    (insert text)
    (font-lock-ensure)
    (goto-char (point-min))
    (when (search-forward substring nil t)
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (or (eq face expected-face)
            (and (listp face) (memq expected-face face)))))))

;;; Keywords

(ert-deftest kcl-fontlock-import ()
  "Test that `import' is fontified as keyword."
  (should (kcl-test--has-face "import regex" "import" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-import-path ()
  "Test that import path is fontified as constant."
  (should (kcl-test--has-face "import k8s.api.core.v1" "k8s.api.core.v1" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-as ()
  "Test that `as' is fontified as keyword."
  (should (kcl-test--has-face "import foo as bar" "as" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-schema ()
  "Test that `schema' is fontified as keyword."
  (should (kcl-test--has-face "schema Foo:" "schema" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-schema-name ()
  "Test that schema name is fontified as type."
  (should (kcl-test--has-face "schema Person:" "Person" 'font-lock-type-face)))

(ert-deftest kcl-fontlock-mixin ()
  "Test that `mixin' keyword is fontified."
  (should (kcl-test--has-face "mixin MetaMixin:" "mixin" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-mixin-name ()
  "Test that mixin name is fontified as type."
  (should (kcl-test--has-face "mixin MetaMixin:" "MetaMixin" 'font-lock-type-face)))

(ert-deftest kcl-fontlock-protocol ()
  "Test that `protocol' keyword is fontified."
  (should (kcl-test--has-face "protocol Serializable:" "protocol" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-rule ()
  "Test that `rule' keyword is fontified."
  (should (kcl-test--has-face "rule MyRule:" "rule" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-check ()
  "Test that `check' keyword is fontified."
  (should (kcl-test--has-face "    check:" "check" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-if ()
  "Test that `if' is fontified as keyword."
  (should (kcl-test--has-face "if True:" "if" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-elif ()
  "Test that `elif' is fontified as keyword."
  (should (kcl-test--has-face "elif False:" "elif" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-else ()
  "Test that `else' is fontified as keyword."
  (should (kcl-test--has-face "else:" "else" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-for ()
  "Test that `for' is fontified as keyword."
  (should (kcl-test--has-face "for x in items" "for" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-in ()
  "Test that `in' is fontified as keyword."
  (should (kcl-test--has-face "for x in items" "in" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-lambda ()
  "Test that `lambda' is fontified as keyword."
  (should (kcl-test--has-face "f = lambda x: int -> int { x }" "lambda" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-assert ()
  "Test that `assert' is fontified as keyword."
  (should (kcl-test--has-face "assert x > 0" "assert" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-all ()
  "Test that `all' is fontified as keyword."
  (should (kcl-test--has-face "all x in items { x > 0 }" "all" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-any ()
  "Test that `any' is fontified as keyword."
  (should (kcl-test--has-face "any x in items { x > 0 }" "any" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-and ()
  "Test that `and' is fontified as keyword."
  (should (kcl-test--has-face "True and False" "and" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-or ()
  "Test that `or' is fontified as keyword."
  (should (kcl-test--has-face "True or False" "or" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-not ()
  "Test that `not' is fontified as keyword."
  (should (kcl-test--has-face "not True" "not" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-is ()
  "Test that `is' is fontified as keyword."
  (should (kcl-test--has-face "x is None" "is" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-type-keyword ()
  "Test that `type' keyword is fontified."
  (should (kcl-test--has-face "type Alias = str | int" "type" 'font-lock-keyword-face)))

(ert-deftest kcl-fontlock-type-alias-name ()
  "Test that type alias name is fontified as type."
  (should (kcl-test--has-face "type Alias = str | int" "Alias" 'font-lock-type-face)))

;;; Constants

(ert-deftest kcl-fontlock-true ()
  "Test that `True' is fontified as constant."
  (should (kcl-test--has-face "x = True" "True" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-false ()
  "Test that `False' is fontified as constant."
  (should (kcl-test--has-face "x = False" "False" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-none ()
  "Test that `None' is fontified as constant."
  (should (kcl-test--has-face "x = None" "None" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-undefined ()
  "Test that `Undefined' is fontified as constant."
  (should (kcl-test--has-face "x = Undefined" "Undefined" 'font-lock-constant-face)))

;;; Types

(ert-deftest kcl-fontlock-type-str ()
  "Test that `str' is fontified as type."
  (should (kcl-test--has-face "    name: str" "str" 'font-lock-type-face)))

(ert-deftest kcl-fontlock-type-int ()
  "Test that `int' is fontified as type."
  (should (kcl-test--has-face "    age: int" "int" 'font-lock-type-face)))

(ert-deftest kcl-fontlock-type-float ()
  "Test that `float' is fontified as type."
  (should (kcl-test--has-face "    salary: float" "float" 'font-lock-type-face)))

(ert-deftest kcl-fontlock-type-bool ()
  "Test that `bool' is fontified as type."
  (should (kcl-test--has-face "    active: bool" "bool" 'font-lock-type-face)))

;;; Strings

(ert-deftest kcl-fontlock-double-string ()
  "Test that double-quoted strings are fontified."
  (should (kcl-test--has-face "x = \"hello\"" "\"hello\"" 'font-lock-string-face)))

(ert-deftest kcl-fontlock-single-string ()
  "Test that single-quoted strings are fontified."
  (should (kcl-test--has-face "x = 'hello'" "'hello'" 'font-lock-string-face)))

(ert-deftest kcl-fontlock-triple-double-string ()
  "Test that triple-double-quoted strings are fontified."
  (should (kcl-test--has-face "x = \"\"\"hello world\"\"\"" "\"\"\"hello world\"\"\"" 'font-lock-string-face)))

(ert-deftest kcl-fontlock-triple-single-string ()
  "Test that triple-single-quoted strings are fontified."
  (should (kcl-test--has-face "x = '''hello world'''" "'''hello world'''" 'font-lock-string-face)))

;;; Numbers

(ert-deftest kcl-fontlock-decimal ()
  "Test that decimal numbers are fontified."
  (should (kcl-test--has-face "x = 42" "42" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-hex ()
  "Test that hex numbers are fontified."
  (should (kcl-test--has-face "x = 0xFF" "0xFF" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-octal ()
  "Test that octal numbers are fontified."
  (should (kcl-test--has-face "x = 0o77" "0o77" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-binary ()
  "Test that binary numbers are fontified."
  (should (kcl-test--has-face "x = 0b1010" "0b1010" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-float ()
  "Test that float numbers are fontified."
  (should (kcl-test--has-face "x = 3.14" "3.14" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-float-exp ()
  "Test that float numbers with exponent are fontified."
  (should (kcl-test--has-face "x = 1.5e10" "1.5e10" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-si-ki ()
  "Test that SI-suffixed number (Ki) is fontified."
  (should (kcl-test--has-face "x = 512Ki" "512Ki" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-si-mi ()
  "Test that SI-suffixed number (Mi) is fontified."
  (should (kcl-test--has-face "x = 256Mi" "256Mi" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-si-gi ()
  "Test that SI-suffixed number (Gi) is fontified."
  (should (kcl-test--has-face "x = 2Gi" "2Gi" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-si-m ()
  "Test that SI-suffixed number (m) is fontified."
  (should (kcl-test--has-face "x = 500m" "500m" 'font-lock-constant-face)))

(ert-deftest kcl-fontlock-si-no-identifier-prefix ()
  "Test that digits in invalid identifier-like tokens are not fontified."
  (should-not (kcl-test--has-face "x = 123abc" "123" 'font-lock-constant-face)))

;;; Comments

(ert-deftest kcl-fontlock-comment ()
  "Test that comments are fontified."
  (should (kcl-test--has-face "# this is a comment" "this" 'font-lock-comment-face)))

(ert-deftest kcl-fontlock-inline-comment ()
  "Test that inline comments are fontified."
  (should (kcl-test--has-face "x = 1  # inline" "inline" 'font-lock-comment-face)))

;;; Decorators

(ert-deftest kcl-fontlock-decorator ()
  "Test that decorators are fontified."
  (should (kcl-test--has-face "@deprecated\nschema Foo:" "deprecated" 'font-lock-preprocessor-face)))

(ert-deftest kcl-fontlock-decorator-argument ()
  "Test that decorator keyword arguments are fontified."
  (should (kcl-test--has-face "@deprecated(reason=\"old\")\nschema Foo:" "reason" 'font-lock-variable-name-face)))

;;; Schema attributes

(ert-deftest kcl-fontlock-attribute ()
  "Test that schema attributes are fontified as variable names."
  (should (kcl-test--has-face "    name: str" "name" 'font-lock-variable-name-face)))

(ert-deftest kcl-fontlock-optional-attribute ()
  "Test that optional attributes are fontified as variable names."
  (should (kcl-test--has-face "    labels?: {str: str}" "labels" 'font-lock-variable-name-face)))

;;; Built-in functions

(ert-deftest kcl-fontlock-builtin-len ()
  "Test that `len' is fontified as builtin when called."
  (should (kcl-test--has-face "len(name)" "len" 'font-lock-builtin-face)))

(ert-deftest kcl-fontlock-builtin-print ()
  "Test that `print' is fontified as builtin when called."
  (should (kcl-test--has-face "print(x)" "print" 'font-lock-builtin-face)))

(ert-deftest kcl-fontlock-builtin-typeof ()
  "Test that `typeof' is fontified as builtin when called."
  (should (kcl-test--has-face "typeof(x)" "typeof" 'font-lock-builtin-face)))

;;; Mode basics

(ert-deftest kcl-mode-auto-mode ()
  "Test that .k files activate kcl-mode."
  (should (assoc "\\.k\\'" auto-mode-alist)))

(ert-deftest kcl-mode-comment-start ()
  "Test that comment-start is set correctly."
  (with-temp-buffer
    (kcl-mode)
    (should (string= comment-start "# "))))

(ert-deftest kcl-mode-indent-tabs ()
  "Test that indent-tabs-mode is nil."
  (with-temp-buffer
    (kcl-mode)
    (should (not indent-tabs-mode))))

(ert-deftest kcl-mode-tab-width ()
  "Test that tab-width is 4."
  (with-temp-buffer
    (kcl-mode)
    (should (= tab-width 4))))

;;; Indentation

(ert-deftest kcl-indent-schema-body ()
  "Test indentation after schema definition."
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Foo:\n")
    (insert "name")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 4))))

(ert-deftest kcl-indent-if-body ()
  "Test indentation after if statement."
  (with-temp-buffer
    (kcl-mode)
    (insert "if True:\n")
    (insert "x")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 4))))

(ert-deftest kcl-indent-closing-brace ()
  "Test indentation of closing brace."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = {\n")
    (insert "    a: 1\n")
    (insert "}")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 0))))

(ert-deftest kcl-indent-elif ()
  "Test that elif aligns with if."
  (with-temp-buffer
    (kcl-mode)
    (insert "if True:\n")
    (insert "    x = 1\n")
    (insert "elif False:")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 0))))

(ert-deftest kcl-indent-top-level ()
  "Test that top-level code has zero indentation."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = 1")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 0))))

(ert-deftest kcl-indent-after-binary-operator ()
  "Test continuation indentation after a binary operator."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = a +\n")
    (insert "b")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 4))))

(ert-deftest kcl-indent-leading-binary-operator ()
  "Test continuation indentation before a leading binary operator."
  (with-temp-buffer
    (kcl-mode)
    (insert "x = a\n")
    (insert "+ b")
    (kcl-mode-indent-line)
    (should (= (current-indentation) 4))))

;;; Imenu

(ert-deftest kcl-imenu-schema ()
  "Test that imenu finds schema definitions."
  (require 'imenu)
  (with-temp-buffer
    (kcl-mode)
    (insert "schema Person:\n    name: str\n\nschema Employee(Person):\n    company: str\n")
    (let ((index (imenu--make-index-alist t)))
      (should (assoc "Schema" index))
      (let ((schemas (cdr (assoc "Schema" index))))
        (should (>= (length schemas) 2))))))

(provide 'test-fontlock)

;;; test-fontlock.el ends here
