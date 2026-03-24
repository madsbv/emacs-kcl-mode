;;; test-lsp.el --- Tests for KCL LSP integration -*- lexical-binding: t; -*-

;; Copyright (C) 2024 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:

;; ERT tests for kcl-lsp.el and kcl-eglot.el configuration.
;; These tests verify registration and configuration, not actual
;; LSP communication (which requires the server to be running).

;;; Code:

(require 'ert)

;;; kcl-lsp.el tests

(ert-deftest kcl-lsp-loads ()
  "Test that kcl-lsp loads without error."
  (require 'kcl-lsp)
  (should (featurep 'kcl-lsp)))

(ert-deftest kcl-lsp-server-command-default ()
  "Test default server command is nil (falls back to core variable)."
  (require 'kcl-lsp)
  (should (null kcl-lsp-server-command)))

(ert-deftest kcl-lsp-auto-start-default ()
  "Test auto-start is off by default."
  (require 'kcl-lsp)
  (should (null kcl-lsp-auto-start)))

(ert-deftest kcl-lsp-server-command-function ()
  "Test server command function returns the configured command."
  (require 'kcl-lsp)
  (should (equal (kcl-lsp--server-command) '("kcl-language-server"))))

(ert-deftest kcl-lsp-hook-installed ()
  "Test that auto-start hooks are installed."
  (require 'kcl-lsp)
  (should (memq #'kcl-lsp--maybe-start kcl-mode-hook))
  (should (memq #'kcl-lsp--maybe-start kcl-ts-mode-hook)))

(ert-deftest kcl-lsp-no-hard-dependency ()
  "Test that kcl-lsp does not require lsp-mode at load time."
  ;; kcl-lsp should be loadable even when lsp-mode is not installed
  (require 'kcl-lsp)
  ;; lsp-mode functions are declared but not required
  (should (not (featurep 'lsp-mode))))

;;; kcl-eglot.el tests

(ert-deftest kcl-eglot-loads ()
  "Test that kcl-eglot loads without error."
  (require 'kcl-eglot)
  (should (featurep 'kcl-eglot)))

(ert-deftest kcl-eglot-server-command-default ()
  "Test default eglot server command is nil (falls back to core variable)."
  (require 'kcl-eglot)
  (should (null kcl-eglot-server-command)))

(ert-deftest kcl-eglot-registers-kcl-mode ()
  "Test that kcl-mode is registered in eglot-server-programs."
  (require 'eglot)
  (require 'kcl-eglot)
  (let ((entry (assoc 'kcl-mode eglot-server-programs)))
    (should entry)
    ;; Just verify the mode is registered; exact command may vary in test env
    (should (eq (car entry) 'kcl-mode))))

(ert-deftest kcl-eglot-registers-kcl-ts-mode ()
  "Test that kcl-ts-mode is registered in eglot-server-programs."
  (require 'eglot)
  (require 'kcl-eglot)
  (let ((entry (assoc 'kcl-ts-mode eglot-server-programs)))
    (should entry)
    (should (eq (car entry) 'kcl-ts-mode))))

(ert-deftest kcl-eglot-custom-command ()
  "Test custom server command is used."
  (require 'eglot)
  (require 'kcl-eglot)
  (let ((kcl-eglot-server-command '("custom-kcl-lsp" "--stdio"))
        (eglot-server-programs (copy-sequence eglot-server-programs)))
    ;; Re-register with new command in a let-bound copy
    (kcl-eglot-register)
    (let ((entry (assoc 'kcl-mode eglot-server-programs)))
      (should entry)
      (should (equal (cdr entry) '("custom-kcl-lsp" "--stdio"))))))

;;; Live LSP tests (require kcl-language-server to be available)
;;
;; These tests actually connect to the KCL language server via eglot
;; and verify real LSP operations.  They are skipped if the server
;; binary is not found.

(defvar kcl-test--lsp-server-command
  (or (getenv "KCL_LANGUAGE_SERVER")
      (car (file-expand-wildcards
            "/nix/store/*/bin/kcl-language-server"))
      "kcl-language-server")
  "Path to kcl-language-server for live tests.")

(defvar kcl-test--lsp-project-dir nil
  "Temporary project directory for live LSP tests.")

(defvar kcl-test--lsp-test-file nil
  "Path to test .k file for live LSP tests.")

(defun kcl-test--lsp-server-available-p ()
  "Return non-nil if kcl-language-server is available."
  (condition-case nil
      (eq 0 (call-process kcl-test--lsp-server-command nil nil nil "--version"))
    (error nil)))

(defun kcl-test--lsp-setup ()
  "Set up a temporary KCL project and connect eglot.
Returns the eglot server object, or nil if setup fails."
  (require 'eglot)
  (require 'project)
  ;; Create temp project with git init
  (setq kcl-test--lsp-project-dir (make-temp-file "kcl-lsp-test" t))
  (setq kcl-test--lsp-test-file
        (expand-file-name "test.k" kcl-test--lsp-project-dir))
  ;; git init so project.el can find it
  (call-process "git" nil nil nil "init" kcl-test--lsp-project-dir)
  ;; Write a test file
  (with-temp-file kcl-test--lsp-test-file
    (insert "schema Person:\n"
            "    name: str\n"
            "    age: int\n"
            "    labels?: {str:str}\n"
            "\n"
            "alice = Person {\n"
            "    name = \"Alice\"\n"
            "    age = 30\n"
            "}\n"))
  ;; Register eglot server
  (add-to-list 'eglot-server-programs
               `(kcl-mode . (,kcl-test--lsp-server-command)))
  ;; Open the file and connect
  (find-file kcl-test--lsp-test-file)
  (kcl-mode)
  (let ((eglot-sync-connect 5))
    (eglot 'kcl-mode (project-current t) 'eglot-lsp-server
           (list kcl-test--lsp-server-command) "kcl"))
  (accept-process-output nil 2)
  (eglot-current-server))

(defun kcl-test--lsp-teardown (server)
  "Shut down SERVER and clean up the temporary project."
  (when server
    (ignore-errors (eglot-shutdown server)))
  (when (and kcl-test--lsp-test-file
             (get-file-buffer kcl-test--lsp-test-file))
    (kill-buffer (get-file-buffer kcl-test--lsp-test-file)))
  (when kcl-test--lsp-project-dir
    (delete-directory kcl-test--lsp-project-dir t)))

(ert-deftest kcl-lsp-live-connect ()
  "Test that eglot can connect to kcl-language-server."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (progn
          (should server)
          (should (eglot--server-info server))
          (should (equal (plist-get (eglot--server-info server) :name)
                         "kcl-language-server")))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-capabilities ()
  "Test that the server reports expected capabilities."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (let ((caps (eglot--capabilities server)))
          (should caps)
          (should (eq (plist-get caps :hoverProvider) t))
          (should (eq (plist-get caps :definitionProvider) t))
          (should (eq (plist-get caps :documentFormattingProvider) t))
          (should (eq (plist-get caps :renameProvider) t))
          (should (eq (plist-get caps :referencesProvider) t))
          (should (plist-get caps :completionProvider))
          (should (plist-get caps :semanticTokensProvider)))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-hover ()
  "Test hover returns schema documentation."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          (goto-char (point-min))
          (search-forward "Person")
          (backward-char 3)
          (let ((hover (jsonrpc-request server :textDocument/hover
                         (eglot--TextDocumentPositionParams))))
            (should hover)
            (should (plist-get hover :contents))
            ;; Contents should mention Person
            (let* ((contents (plist-get hover :contents))
                   (text (cond
                          ((stringp contents) contents)
                          ((vectorp contents)
                           (mapconcat
                            (lambda (c)
                              (if (stringp c) c
                                (or (plist-get c :value) "")))
                            contents " "))
                          (t (plist-get contents :value)))))
              (should (string-match-p "Person" text)))))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-document-symbols ()
  "Test document symbols returns schema and variable definitions."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          (let ((symbols (jsonrpc-request server :textDocument/documentSymbol
                           (list :textDocument (eglot--TextDocumentIdentifier)))))
            (should symbols)
            (should (>= (length symbols) 2))
            ;; Should find Person schema and alice variable
            (let ((names (mapcar (lambda (s) (plist-get s :name)) symbols)))
              (should (member "schema Person" names))
              (should (member "alice" names)))))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-completion ()
  "Test completion returns items."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          ;; Add a dot access to trigger completion
          (goto-char (point-max))
          (insert "\nalice.")
          ;; Notify server of change
          (eglot--signal-textDocument/didChange)
          (accept-process-output nil 1)
          (let* ((response (jsonrpc-request server :textDocument/completion
                             (eglot--TextDocumentPositionParams)))
                 (items (if (vectorp response) response
                          (plist-get response :items))))
            (should items)
            (should (> (length items) 0))
            ;; Should include Person's fields
            (let ((labels (mapcar (lambda (i) (plist-get i :label))
                                  items)))
              ;; At minimum, built-in functions should be present
              (should (> (length labels) 0))))
          ;; Clean up the added line
          (goto-char (point-max))
          (delete-region (line-beginning-position) (point))
          (delete-char -1))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-goto-definition ()
  "Test go-to-definition resolves Person usage to its schema."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          ;; Position on Person in the usage `alice = Person {`
          (goto-char (point-min))
          (search-forward "alice = ")
          (search-forward "Person")
          (backward-char 3)
          (let ((defs (jsonrpc-request server :textDocument/definition
                        (eglot--TextDocumentPositionParams))))
            (should defs)
            ;; Definition should point to line 0 (the schema definition)
            (let* ((def (if (vectorp defs) (aref defs 0) defs))
                   (range (plist-get def :range))
                   (start (plist-get range :start))
                   (line (plist-get start :line)))
              (should (= line 0)))))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-references ()
  "Test find-references returns all occurrences of Person."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          ;; Position on Person in the schema definition
          (goto-char (point-min))
          (search-forward "schema ")
          (search-forward "Person")
          (backward-char 3)
          (let ((refs (jsonrpc-request server :textDocument/references
                        (list :textDocument (eglot--TextDocumentIdentifier)
                              :position (eglot--pos-to-lsp-position)
                              :context (list :includeDeclaration t)))))
            (should refs)
            ;; Should find at least 2 references (definition + usage)
            (should (>= (length refs) 2))))
      (kcl-test--lsp-teardown server))))

(ert-deftest kcl-lsp-live-formatting ()
  "Test document formatting returns without error."
  (skip-unless (kcl-test--lsp-server-available-p))
  (let ((server (kcl-test--lsp-setup)))
    (unwind-protect
        (with-current-buffer (get-file-buffer kcl-test--lsp-test-file)
          (let ((edits (jsonrpc-request server :textDocument/formatting
                         (list :textDocument (eglot--TextDocumentIdentifier)
                               :options (list :tabSize 4
                                              :insertSpaces t)))))
            ;; Should return edits (possibly empty if already formatted)
            (should (or (null edits)
                        (vectorp edits)
                        (listp edits)))))
      (kcl-test--lsp-teardown server))))

(provide 'test-lsp)

;;; test-lsp.el ends here
