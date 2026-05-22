;;; kcl-polyglot.el --- Embedded KCL support -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, tools
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; Optional support for highlighting embedded KCL blocks in host files.
;; Currently this registers an mmm-mode class for YAML literal blocks whose
;; keys look KCL-specific, for example:
;;
;;   kcl: |
;;     schema App:
;;         image: str
;;
;; Usage:
;;   (require 'mmm-mode)
;;   (require 'kcl-polyglot)

;;; Code:

(require 'regexp-opt)
(require 'kcl-mode)

(declare-function mmm-add-classes "mmm-mode")
(declare-function mmm-add-mode-ext-class "mmm-mode")

(defgroup kcl-polyglot nil
  "Embedded KCL support."
  :group 'kcl
  :prefix "kcl-polyglot-")

(defcustom kcl-polyglot-yaml-keys '("kcl" "kclCode" "kcl_code")
  "YAML literal-block keys that should be treated as embedded KCL."
  :type '(repeat string)
  :group 'kcl-polyglot)

(defcustom kcl-polyglot-yaml-host-modes '(yaml-mode yaml-ts-mode)
  "YAML modes that should receive the embedded KCL mmm-mode class."
  :type '(repeat symbol)
  :group 'kcl-polyglot)

(defun kcl-polyglot--yaml-front-regexp ()
  "Return a regexp matching YAML literal blocks that contain KCL."
  (concat "^[ \t]*\\("
          (regexp-opt kcl-polyglot-yaml-keys)
          "\\)[ \t]*:[ \t]*[|>][-+]?[ \t]*\\(?:#.*\\)?$"))

(defun kcl-polyglot-register-mmm ()
  "Register embedded KCL regions with mmm-mode.
This function is safe to call repeatedly after mmm-mode is loaded."
  (interactive)
  (unless (featurep 'mmm-mode)
    (user-error "Load mmm-mode before registering embedded KCL regions"))
  (mmm-add-classes
   `((kcl-yaml-literal
      :submode kcl-mode
      :front ,(kcl-polyglot--yaml-front-regexp)
      :back "^[^ \t\n#].*$")))
  (dolist (mode kcl-polyglot-yaml-host-modes)
    (mmm-add-mode-ext-class mode nil 'kcl-yaml-literal)))

(eval-after-load 'mmm-mode
  '(kcl-polyglot-register-mmm))

(when (featurep 'mmm-mode)
  (kcl-polyglot-register-mmm))

(provide 'kcl-polyglot)

;;; kcl-polyglot.el ends here
