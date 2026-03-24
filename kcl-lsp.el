;;; kcl-lsp.el --- lsp-mode integration for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2024 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: emacs-kcl-mode contributors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, kcl, lsp
;; Package-Requires: ((emacs "27.1") (lsp-mode "8.0.0"))

;;; Commentary:

;; Integration between `kcl-mode' / `kcl-ts-mode' and `lsp-mode' for
;; the KCL language server (kcl-language-server).
;;
;; The KCL language server supports:
;; - Diagnostics (errors, warnings)
;; - Completion
;; - Hover documentation
;; - Go to definition
;; - Find references
;; - Document symbols
;; - Code formatting
;; - Rename
;;
;; Prerequisites:
;;   1. Install kcl-language-server:
;;      - Via KCL installer: `curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash'
;;      - Via brew: `brew install kcl-lang/tap/kcl-lsp'
;;      - Via nix: `nix-env -iA nixpkgs.kcl-language-server'
;;
;;   2. Install lsp-mode: https://emacs-lsp.github.io/lsp-mode/
;;
;; Usage:
;;   (require 'kcl-lsp)
;;
;; To auto-start LSP in KCL buffers:
;;   (add-hook 'kcl-mode-hook #'lsp-deferred)
;;   (add-hook 'kcl-ts-mode-hook #'lsp-deferred)

;;; Code:

(require 'kcl-mode)

;; Defer lsp-mode require to avoid hard dependency at load time
(declare-function lsp-register-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")
(declare-function lsp "lsp-mode")
(declare-function lsp-deferred "lsp-mode")

(defgroup kcl-lsp nil
  "LSP integration for KCL via lsp-mode."
  :group 'kcl
  :prefix "kcl-lsp-")

(defcustom kcl-lsp-server-command '("kcl-language-server")
  "Command and arguments to start the KCL language server.
The server must support the Language Server Protocol over stdio."
  :type '(repeat string)
  :group 'kcl-lsp)

(defcustom kcl-lsp-auto-start nil
  "If non-nil, automatically start LSP when opening KCL files.
When nil, use `M-x lsp' or `M-x lsp-deferred' to start manually."
  :type 'boolean
  :group 'kcl-lsp)

(defun kcl-lsp--server-command ()
  "Return the KCL language server command."
  kcl-lsp-server-command)

(defun kcl-lsp-register ()
  "Register the KCL language server with lsp-mode.
This function is safe to call even if lsp-mode is not yet loaded;
it will register the client when lsp-mode becomes available."
  (eval-after-load 'lsp-mode
    '(progn
       (lsp-register-client
        (make-lsp-client
         :new-connection (lsp-stdio-connection #'kcl-lsp--server-command)
         :activation-fn (lsp-activate-on "kcl")
         :server-id 'kcl-language-server
         :major-modes '(kcl-mode kcl-ts-mode)
         :priority -1
         :multi-root nil))

       ;; Register language-id mapping for both modes
       (add-to-list 'lsp-language-id-configuration '(kcl-mode . "kcl"))
       (add-to-list 'lsp-language-id-configuration '(kcl-ts-mode . "kcl")))))

;; Register on load
(kcl-lsp-register)

;; Optional auto-start hook
(defun kcl-lsp--maybe-start ()
  "Start LSP if `kcl-lsp-auto-start' is non-nil."
  (when (and kcl-lsp-auto-start
             (fboundp 'lsp-deferred))
    (lsp-deferred)))

(add-hook 'kcl-mode-hook #'kcl-lsp--maybe-start)
(add-hook 'kcl-ts-mode-hook #'kcl-lsp--maybe-start)

(provide 'kcl-lsp)

;;; kcl-lsp.el ends here
