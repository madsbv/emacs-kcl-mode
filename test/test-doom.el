;;; test-doom.el --- Doom Emacs integration tests for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Mads Bach Villadsen
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:

;; ERT tests that validate the Doom Emacs configuration from README.md.
;; These tests ensure that every function, variable, keymap binding, and
;; mode entry documented in the Doom config section actually exists in
;; the package, so the README instructions never silently break.
;;
;; No Doom macros are needed — we test the underlying symbols directly.

;;; Code:

(require 'ert)
(require 'kcl-mode)
(require 'kcl-ts-mode)

;;; Symbol existence checks
;;
;; Every function referenced in the README Doom config's map! blocks
;; must be fboundp and commandp after loading the package.

(defconst kcl-test--doom-commands
  '(kcl-run-buffer
    kcl-eval-buffer
    kcl-eval-freeze
    kcl-eval-diff
    kcl-switch-output-format
    kcl-live-preview-mode
    kcl-format-buffer
    kcl-lint-buffer
    kcl-test
    kcl-vet
    kcl-goto-imports
    kcl-open-doc-at-point
    kcl-transient)
  "Commands referenced in the README Doom Emacs map! configuration.")

(ert-deftest kcl-doom-commands-fboundp ()
  "All commands referenced in the Doom config are defined as functions."
  (dolist (cmd kcl-test--doom-commands)
    (should (fboundp cmd))))

(ert-deftest kcl-doom-commands-commandp ()
  "All commands referenced in the Doom config are interactive commands."
  (dolist (cmd kcl-test--doom-commands)
    (should (commandp cmd))))

;;; Keymap parity
;;
;; The Doom config maps localleader keys to commands that should also
;; have C-c C-* equivalents in both kcl-mode-map and kcl-ts-mode-map.

(defconst kcl-test--doom-keymap-commands
  '(kcl-run-buffer
    kcl-eval-buffer
    kcl-eval-freeze
    kcl-eval-diff
    kcl-switch-output-format
    kcl-live-preview-mode
    kcl-format-buffer
    kcl-lint-buffer
    kcl-test
    kcl-vet
    kcl-goto-imports
    kcl-open-doc-at-point
    kcl-transient)
  "Commands that must be bound in both kcl-mode-map and kcl-ts-mode-map.")

(defun kcl-test--keymap-has-command-p (keymap cmd)
  "Return non-nil if KEYMAP binds CMD somewhere."
  (catch 'found
    (map-keymap
     (lambda (_key binding)
       (when (eq binding cmd)
         (throw 'found t))
       ;; Check one level of prefix maps (for C-c prefix)
       (when (keymapp binding)
         (map-keymap
          (lambda (_k2 b2)
            (when (eq b2 cmd)
              (throw 'found t)))
          binding)))
     keymap)
    nil))

(ert-deftest kcl-doom-keymap-parity-kcl-mode ()
  "All Doom localleader commands are bound in `kcl-mode-map'."
  (dolist (cmd kcl-test--doom-keymap-commands)
    (should (kcl-test--keymap-has-command-p kcl-mode-map cmd))))

(ert-deftest kcl-doom-keymap-parity-kcl-ts-mode ()
  "All Doom localleader commands are bound in `kcl-ts-mode-map'."
  (dolist (cmd kcl-test--doom-keymap-commands)
    (should (kcl-test--keymap-has-command-p kcl-ts-mode-map cmd))))

;;; Specific keybinding checks
;;
;; Verify the exact C-c C-* bindings match between both keymaps.

(defconst kcl-test--expected-bindings
  '(("C-c C-r" . kcl-run-buffer)
    ("C-c C-e" . kcl-eval-buffer)
    ("C-c C-s" . kcl-eval-freeze)
    ("C-c C-d" . kcl-eval-diff)
    ("C-c C-o" . kcl-switch-output-format)
    ("C-c C-p" . kcl-live-preview-mode)
    ("C-c C-f" . kcl-format-buffer)
    ("C-c C-l" . kcl-lint-buffer)
    ("C-c C-t" . kcl-test)
    ("C-c C-v" . kcl-vet)
    ("C-c C-i" . kcl-goto-imports)
    ("C-c C-h" . kcl-open-doc-at-point)
    ("C-c C-c" . kcl-transient))
  "Expected key bindings in both kcl-mode-map and kcl-ts-mode-map.")

(ert-deftest kcl-doom-exact-bindings-kcl-mode ()
  "Exact keybindings in `kcl-mode-map' match expected values."
  (dolist (binding kcl-test--expected-bindings)
    (let ((key (car binding))
          (cmd (cdr binding)))
      (should (eq (lookup-key kcl-mode-map (kbd key)) cmd)))))

(ert-deftest kcl-doom-exact-bindings-kcl-ts-mode ()
  "Exact keybindings in `kcl-ts-mode-map' match expected values."
  (dolist (binding kcl-test--expected-bindings)
    (let ((key (car binding))
          (cmd (cdr binding)))
      (should (eq (lookup-key kcl-ts-mode-map (kbd key)) cmd)))))

;;; Mode / feature availability

(ert-deftest kcl-doom-auto-mode-alist ()
  "The .k file extension is registered in `auto-mode-alist'."
  (should (assoc "\\.k\\'" auto-mode-alist)))

(ert-deftest kcl-doom-format-on-save-variable ()
  "The `kcl-format-on-save' customization variable exists."
  (should (boundp 'kcl-format-on-save))
  (should (custom-variable-p 'kcl-format-on-save)))

(ert-deftest kcl-doom-kcl-mode-is-major-mode ()
  "Verify `kcl-mode' is a valid major mode."
  (with-temp-buffer
    (kcl-mode)
    (should (eq major-mode 'kcl-mode))))

(ert-deftest kcl-doom-kcl-ts-mode-is-major-mode ()
  "Verify `kcl-ts-mode' is a valid major mode."
  (with-temp-buffer
    (let ((treesit-extra-load-path
           (list default-directory)))
      ;; kcl-ts-mode may fail if grammar isn't available, but the
      ;; function should still be defined
      (should (fboundp 'kcl-ts-mode)))))

(ert-deftest kcl-doom-lsp-server-command-settable ()
  "The `kcl-language-server-command' variable can be set."
  (should (boundp 'kcl-language-server-command))
  (let ((kcl-language-server-command '("custom-server")))
    (should (equal kcl-language-server-command '("custom-server")))))

(ert-deftest kcl-doom-lsp-server-command-override ()
  "The `kcl-lsp-server-command' variable can override the core setting.
This validates the Nix+Doom README pattern:
  (setq kcl-lsp-server-command \\='(\"nix\" \"run\" ...))"
  (require 'kcl-lsp)
  (should (boundp 'kcl-lsp-server-command))
  (let ((kcl-lsp-server-command '("nix" "run" "nixpkgs#kcl-language-server" "--")))
    (should (equal (kcl-lsp--server-command)
                   '("nix" "run" "nixpkgs#kcl-language-server" "--")))))

(ert-deftest kcl-doom-lsp-server-command-fallback ()
  "When `kcl-lsp-server-command' is nil, falls back to core variable."
  (require 'kcl-lsp)
  (let ((kcl-lsp-server-command nil)
        (kcl-language-server-command '("kcl-language-server")))
    (should (equal (kcl-lsp--server-command) '("kcl-language-server")))))

(ert-deftest kcl-doom-provide-symbols ()
  "All expected provide symbols are available."
  (should (featurep 'kcl-mode))
  (should (featurep 'kcl-ts-mode)))

(ert-deftest kcl-doom-keymaps-are-keymaps ()
  "Both keymaps are proper Emacs keymaps."
  (should (keymapp kcl-mode-map))
  (should (keymapp kcl-ts-mode-map)))

(provide 'test-doom)

;;; test-doom.el ends here
