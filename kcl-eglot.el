;;; kcl-eglot.el --- eglot integration for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, tools
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; Integration between `kcl-mode' / `kcl-ts-mode' and `eglot' for
;; the KCL language server (kcl-language-server).
;;
;; Eglot is built into Emacs 29+.  This file registers the KCL
;; language server so that `M-x eglot' works in KCL buffers.
;;
;; Prerequisites:
;;   1. Install kcl-language-server:
;;      - Via KCL installer: `curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash'
;;      - Via brew: `brew install kcl-lang/tap/kcl-lsp'
;;      - Via nix: `nix-env -iA nixpkgs.kcl-language-server'
;;
;; Usage:
;;   (require 'kcl-eglot)
;;   ;; Then in a .k buffer: M-x eglot
;;
;; To auto-start eglot in KCL buffers:
;;   (add-hook 'kcl-mode-hook #'eglot-ensure)
;;   (add-hook 'kcl-ts-mode-hook #'eglot-ensure)

;;; Code:

(require 'eglot)

(defgroup kcl-eglot nil
  "Eglot integration for KCL."
  :group 'kcl
  :prefix "kcl-eglot-")

(defcustom kcl-eglot-server-command '("kcl-language-server")
  "Command and arguments to start the KCL language server for eglot."
  :type '(repeat string)
  :group 'kcl-eglot)

(defun kcl-eglot-register ()
  "Register the KCL language server with eglot.
Adds entries for both `kcl-mode' and `kcl-ts-mode' to
`eglot-server-programs'."
  (add-to-list 'eglot-server-programs
               `(kcl-mode . ,kcl-eglot-server-command))
  (add-to-list 'eglot-server-programs
               `(kcl-ts-mode . ,kcl-eglot-server-command)))

;; Register on load
(kcl-eglot-register)

(provide 'kcl-eglot)

;;; kcl-eglot.el ends here
