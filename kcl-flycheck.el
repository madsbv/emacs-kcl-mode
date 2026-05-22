;;; kcl-flycheck.el --- Flycheck integration for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, tools
;; Package-Requires: ((emacs "27.1") (flycheck "32"))

;;; Commentary:

;; Optional Flycheck checker for KCL buffers.  This file does not require
;; Flycheck at load time; it registers the checker after Flycheck loads.
;;
;; Usage:
;;   (require 'kcl-flycheck)
;;   (add-hook 'kcl-mode-hook #'flycheck-mode)
;;   (add-hook 'kcl-ts-mode-hook #'flycheck-mode)

;;; Code:

(require 'kcl-mode)

(declare-function flycheck-define-checker "flycheck")
(defvar flycheck-checkers)

(defgroup kcl-flycheck nil
  "Flycheck integration for KCL."
  :group 'kcl
  :prefix "kcl-flycheck-")

(defun kcl-flycheck-setup ()
  "Register the KCL checker with Flycheck."
  (with-no-warnings
    (eval
     '(flycheck-define-checker kcl
        "KCL syntax and style checker using `kcl lint'."
        :command ((eval kcl-command) "lint" "--no_style" source)
        :error-patterns
        ((warning line-start "warning[W" (one-or-more digit) "]:" (message)
                  line-end
                  (zero-or-more "\n" (zero-or-more not-newline))
                  "\n" (zero-or-more " ") "--> " (file-name) ":" line ":" column)
         (error line-start
                (or "error[E" "EvaluationError")
                (zero-or-more not-newline) ":" (message)
                line-end
                (zero-or-more "\n" (zero-or-more not-newline))
                "\n" (zero-or-more " ") "--> " (file-name) ":" line ":" column))
        :modes (kcl-mode kcl-ts-mode))))
  (add-to-list 'flycheck-checkers 'kcl))

(eval-after-load 'flycheck
  '(kcl-flycheck-setup))

(when (featurep 'flycheck)
  (kcl-flycheck-setup))

(provide 'kcl-flycheck)

;;; kcl-flycheck.el ends here
