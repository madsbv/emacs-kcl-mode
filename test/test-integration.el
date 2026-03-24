;;; test-integration.el --- Integration tests against real KCL files -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests kcl-mode and kcl-ts-mode against the kcl-numaflow project
;; files to ensure they handle large real-world KCL code without errors.

;;; Code:

(require 'ert)
(require 'imenu)

(defvar kcl-test-numaflow-dir
  "/home/mbv/workspace/github/kcl-lang/kcl-numaflow/numaflow/v1alpha1/"
  "Directory containing numaflow KCL files.")

(defvar kcl-test-numaflow-files nil
  "Cached list of numaflow .k files.")

(defun kcl-test-numaflow-files ()
  "Return list of .k files in numaflow directory."
  (or kcl-test-numaflow-files
      (setq kcl-test-numaflow-files
            (when (file-directory-p kcl-test-numaflow-dir)
              (directory-files kcl-test-numaflow-dir t "\\.k\\'")))))

;;; kcl-mode integration tests

(require 'kcl-mode)

(ert-deftest kcl-integration-mode-loads-numaflow ()
  "Test kcl-mode can open and fontify all numaflow files."
  (let ((files (kcl-test-numaflow-files)))
    (should files)
    (dolist (f files)
      (let ((buf (find-file-noselect f)))
        (unwind-protect
            (with-current-buffer buf
              (kcl-mode)
              (should (eq major-mode 'kcl-mode))
              (font-lock-ensure)
              ;; Should have some fontified content
              (goto-char (point-min))
              (should (text-property-any (point-min) (point-max) 'face nil)))
          (kill-buffer buf))))))

(ert-deftest kcl-integration-mode-no-errors ()
  "Test kcl-mode fontifies without errors on large files."
  (let ((files (kcl-test-numaflow-files)))
    (should files)
    (dolist (f files)
      (let ((buf (find-file-noselect f)))
        (unwind-protect
            (with-current-buffer buf
              (kcl-mode)
              ;; This should not signal any errors
              (font-lock-ensure)
              (should (> (buffer-size) 0)))
          (kill-buffer buf))))))

(ert-deftest kcl-integration-mode-imenu ()
  "Test imenu works on numaflow files."
  (let* ((files (kcl-test-numaflow-files))
         ;; Use smallest file
         (f (car files)))
    (when f
      (let ((buf (find-file-noselect f)))
        (unwind-protect
            (with-current-buffer buf
              (kcl-mode)
              ;; imenu should find schemas
              (let ((index (imenu--make-index-alist t)))
                (should (> (length index) 1))))
          (kill-buffer buf))))))

(ert-deftest kcl-integration-mode-comment ()
  "Test commenting works in numaflow files."
  (let* ((files (kcl-test-numaflow-files))
         (f (car files)))
    (when f
      (let ((buf (find-file-noselect f)))
        (unwind-protect
            (with-current-buffer buf
              (kcl-mode)
              (should (string= comment-start "# ")))
          (kill-buffer buf))))))

;;; kcl-ts-mode integration tests

(setq treesit-extra-load-path
      (list (file-name-directory
             (directory-file-name
              (file-name-directory
               (or load-file-name buffer-file-name))))))

(when (treesit-language-available-p 'kcl)
  (require 'kcl-ts-mode)

  (ert-deftest kcl-integration-ts-loads-numaflow ()
    "Test kcl-ts-mode can open and fontify all numaflow files."
    (let ((files (kcl-test-numaflow-files)))
      (should files)
      (dolist (f files)
        (let ((buf (find-file-noselect f)))
          (unwind-protect
              (with-current-buffer buf
                (kcl-ts-mode)
                (should (eq major-mode 'kcl-ts-mode))
                (font-lock-ensure)
                (should (> (buffer-size) 0)))
            (kill-buffer buf))))))

  (ert-deftest kcl-integration-ts-no-parse-errors ()
    "Test tree-sitter parses numaflow files without catastrophic errors."
    (let ((files (kcl-test-numaflow-files)))
      (should files)
      (dolist (f files)
        (let ((buf (find-file-noselect f)))
          (unwind-protect
              (with-current-buffer buf
                (kcl-ts-mode)
                ;; Parser should exist
                (should (treesit-parser-list))
                ;; Root node should exist and cover the buffer
                (let ((root (treesit-buffer-root-node 'kcl)))
                  (should root)
                  (should (string= (treesit-node-type root) "module"))))
            (kill-buffer buf))))))

  (ert-deftest kcl-integration-ts-imenu ()
    "Test treesit imenu works on numaflow files."
    (let* ((files (kcl-test-numaflow-files))
           (f (car files)))
      (when f
        (let ((buf (find-file-noselect f)))
          (unwind-protect
              (with-current-buffer buf
                (kcl-ts-mode)
                (let ((index (treesit-simple-imenu)))
                  ;; Should find some definitions
                  (should (> (length index) 0))))
            (kill-buffer buf)))))))

;;; Performance benchmarks

(ert-deftest kcl-integration-mode-performance ()
  "Test that kcl-mode fontifies the largest file in reasonable time."
  (let* ((files (kcl-test-numaflow-files))
         ;; Find largest file
         (largest (car (sort (copy-sequence files)
                             (lambda (a b)
                               (> (file-attribute-size (file-attributes a))
                                  (file-attribute-size (file-attributes b))))))))
    (when largest
      (let ((buf (find-file-noselect largest)))
        (unwind-protect
            (with-current-buffer buf
              (let ((start (float-time)))
                (kcl-mode)
                (font-lock-ensure)
                (let ((elapsed (- (float-time) start)))
                  (message "kcl-mode on %s (%d lines): %.2fs"
                           (file-name-nondirectory largest)
                           (count-lines (point-min) (point-max))
                           elapsed)
                  ;; Should complete in under 10 seconds
                  (should (< elapsed 10.0)))))
          (kill-buffer buf))))))

(when (and (treesit-available-p) (treesit-language-available-p 'kcl))
  (ert-deftest kcl-integration-ts-performance ()
    "Test that kcl-ts-mode fontifies the largest file in reasonable time."
    (let* ((files (kcl-test-numaflow-files))
           (largest (car (sort (copy-sequence files)
                               (lambda (a b)
                                 (> (file-attribute-size (file-attributes a))
                                    (file-attribute-size (file-attributes b))))))))
      (when largest
        (let ((buf (find-file-noselect largest)))
          (unwind-protect
              (with-current-buffer buf
                (let ((start (float-time)))
                  (kcl-ts-mode)
                  (font-lock-ensure)
                  (let ((elapsed (- (float-time) start)))
                    (message "kcl-ts-mode on %s (%d lines): %.2fs"
                             (file-name-nondirectory largest)
                             (count-lines (point-min) (point-max))
                             elapsed)
                    ;; Should complete in under 10 seconds
                    (should (< elapsed 10.0)))))
            (kill-buffer buf)))))))

(provide 'test-integration)

;;; test-integration.el ends here
