;;; ob-kcl.el --- Org Babel support for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 The KCL Authors
;; SPDX-License-Identifier: Apache-2.0

;; Author: The KCL Authors
;; Maintainer: The KCL Authors
;; URL: https://github.com/kcl-lang/emacs-kcl-mode
;; Version: 0.1.0
;; Keywords: languages, org, babel
;; Package-Requires: ((emacs "27.1") (org "9.1"))

;;; Commentary:

;; Org Babel execution support for KCL source blocks.
;;
;; Usage:
;;   (require 'ob-kcl)
;;
;; Example:
;;   #+begin_src kcl :format yaml
;;   x = 1
;;   #+end_src

;;; Code:

(require 'ob)
(require 'kcl-mode)

(defvar org-babel-default-header-args:kcl
  '((:format . "yaml"))
  "Default header arguments for KCL source blocks.")

(defun org-babel-execute:kcl (body params)
  "Execute a KCL source block BODY with Org Babel PARAMS."
  (let* ((fmt (or (cdr (assq :format params))
                  kcl-eval-output-format))
         (temp-file (make-temp-file "ob-kcl-" nil ".k"))
         (output-buffer (generate-new-buffer " *ob-kcl-output*")))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert body)
            (unless (string-suffix-p "\n" body)
              (insert "\n")))
          (let ((exit-code
                 (call-process kcl-command nil output-buffer nil
                               "run" "--format" fmt temp-file)))
            (with-current-buffer output-buffer
              (let ((output (string-trim
                             (buffer-substring-no-properties
                              (point-min) (point-max)))))
                (if (zerop exit-code)
                    output
                  (user-error "KCL Babel block failed: %s" output))))))
      (ignore-errors (delete-file temp-file))
      (kill-buffer output-buffer))))

(add-to-list 'org-src-lang-modes '("kcl" . kcl))

(provide 'ob-kcl)

;;; ob-kcl.el ends here
