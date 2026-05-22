;;; test-optional.el --- Optional integration tests for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:

;; Tests for optional integrations that should load without forcing their
;; optional packages at startup.

;;; Code:

(require 'ert)

(ert-deftest kcl-flycheck-loads-without-flycheck ()
  "kcl-flycheck should load even when Flycheck has not been loaded."
  (require 'kcl-flycheck)
  (should (featurep 'kcl-flycheck))
  (should (fboundp 'kcl-flycheck-setup)))

(ert-deftest ob-kcl-loads ()
  "ob-kcl should load and register the KCL Org source language."
  (require 'ob-kcl)
  (should (featurep 'ob-kcl))
  (should (assoc "kcl" org-src-lang-modes)))

(ert-deftest ob-kcl-executes-block ()
  "ob-kcl should execute a simple KCL source block."
  (require 'ob-kcl)
  (let ((result (org-babel-execute:kcl "x = 1" '((:format . "yaml")))))
    (should (string-match-p "x: 1" result))))

(ert-deftest kcl-polyglot-loads-without-mmm-mode ()
  "kcl-polyglot should load even when mmm-mode has not been loaded."
  (require 'kcl-polyglot)
  (should (featurep 'kcl-polyglot))
  (should (fboundp 'kcl-polyglot-register-mmm))
  (should (string-match-p
           (kcl-polyglot--yaml-front-regexp)
           "kcl: |")))

(provide 'test-optional)

;;; test-optional.el ends here
