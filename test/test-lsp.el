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
  "Test default server command."
  (require 'kcl-lsp)
  (should (equal kcl-lsp-server-command '("kcl-language-server"))))

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
  "Test default eglot server command."
  (require 'kcl-eglot)
  (should (equal kcl-eglot-server-command '("kcl-language-server"))))

(ert-deftest kcl-eglot-registers-kcl-mode ()
  "Test that kcl-mode is registered in eglot-server-programs."
  (require 'kcl-eglot)
  (let ((entry (assoc 'kcl-mode eglot-server-programs)))
    (should entry)
    ;; Just verify the mode is registered; exact command may vary in test env
    (should (eq (car entry) 'kcl-mode))))

(ert-deftest kcl-eglot-registers-kcl-ts-mode ()
  "Test that kcl-ts-mode is registered in eglot-server-programs."
  (require 'kcl-eglot)
  (let ((entry (assoc 'kcl-ts-mode eglot-server-programs)))
    (should entry)
    (should (eq (car entry) 'kcl-ts-mode))))

(ert-deftest kcl-eglot-custom-command ()
  "Test custom server command is used."
  (require 'kcl-eglot)
  (let ((kcl-eglot-server-command '("custom-kcl-lsp" "--stdio"))
        (eglot-server-programs (copy-sequence eglot-server-programs)))
    ;; Re-register with new command in a let-bound copy
    (kcl-eglot-register)
    (let ((entry (assoc 'kcl-mode eglot-server-programs)))
      (should entry)
      (should (equal (cdr entry) '("custom-kcl-lsp" "--stdio"))))))

(provide 'test-lsp)

;;; test-lsp.el ends here
