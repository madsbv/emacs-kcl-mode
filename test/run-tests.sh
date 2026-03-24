#!/usr/bin/env bash
# Run all ERT tests for kcl-mode, kcl-ts-mode, and LSP integration.
# Usage: ./test/run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FAILURES=0

echo "=== Running kcl-mode ERT tests ==="
echo "Project: $PROJECT_DIR"
echo ""

# --- kcl-mode font-lock tests ---
echo "--- Font-lock tests (kcl-mode, regex) ---"
if emacs --batch \
	-L "$PROJECT_DIR" \
	-l ert \
	-l kcl-mode \
	-l "$SCRIPT_DIR/test-fontlock.el" \
	-f ert-run-tests-batch-and-exit 2>&1; then
	echo "  PASSED"
else
	echo "  FAILED"
	((FAILURES++)) || true
fi

# --- kcl-ts-mode tests ---
echo ""
echo "--- Tree-sitter mode tests (kcl-ts-mode) ---"
if emacs --batch \
	-L "$PROJECT_DIR" \
	--eval "(setq treesit-extra-load-path '(\"$PROJECT_DIR/\"))" \
	-l ert \
	-l "$SCRIPT_DIR/test-ts-mode.el" \
	-f ert-run-tests-batch-and-exit 2>&1; then
	echo "  PASSED"
else
	echo "  FAILED (treesit grammar may not be available)"
	((FAILURES++)) || true
fi

# --- LSP integration tests ---
echo ""
echo "--- LSP integration tests ---"
if emacs --batch \
	-L "$PROJECT_DIR" \
	--eval "(setq treesit-extra-load-path '(\"$PROJECT_DIR/\"))" \
	-l ert \
	-l "$SCRIPT_DIR/test-lsp.el" \
	-f ert-run-tests-batch-and-exit 2>&1; then
	echo "  PASSED"
else
	echo "  FAILED"
	((FAILURES++)) || true
fi

# --- Command/feature tests ---
echo ""
echo "--- Command and feature tests ---"
if emacs --batch \
	-L "$PROJECT_DIR" \
	--eval "(setq treesit-extra-load-path '(\"$PROJECT_DIR/\"))" \
	-l ert \
	-l kcl-mode \
	-l kcl-ts-mode \
	-l "$SCRIPT_DIR/test-commands.el" \
	-f ert-run-tests-batch-and-exit 2>&1; then
	echo "  PASSED"
else
	echo "  FAILED"
	((FAILURES++)) || true
fi

# --- Sample file smoke test ---
echo ""
echo "--- Sample file smoke test ---"
emacs --batch \
	-L "$PROJECT_DIR" \
	-l kcl-mode \
	--eval '
(progn
  (find-file "'"$SCRIPT_DIR/sample.k"'")
  (if (eq major-mode (quote kcl-mode))
      (progn
        (font-lock-ensure)
        (princ (format "  kcl-mode: %s - OK\n" major-mode))
        (let ((count 0))
          (goto-char (point-min))
          (while (not (eobp))
            (when (get-text-property (point) (quote face))
              (setq count (1+ count)))
            (forward-char 1))
          (princ (format "  Fontified characters: %d\n" count))))
    (princ (format "  ERROR: Expected kcl-mode, got %s\n" major-mode))))' 2>/dev/null

# --- Integration tests against kcl-numaflow ---
echo ""
echo "--- Integration tests (kcl-numaflow) ---"
if [ -d "/home/mbv/workspace/github/kcl-lang/kcl-numaflow/numaflow/v1alpha1/" ]; then
	if emacs --batch \
		-L "$PROJECT_DIR" \
		--eval "(setq treesit-extra-load-path '(\"$PROJECT_DIR/\"))" \
		-l ert \
		-l "$SCRIPT_DIR/test-integration.el" \
		-f ert-run-tests-batch-and-exit 2>&1; then
		echo "  PASSED"
	else
		echo "  FAILED"
		((FAILURES++)) || true
	fi
else
	echo "  SKIPPED (kcl-numaflow not available)"
fi

# --- Summary ---
echo ""
echo "=== Test Summary ==="
if [ "$FAILURES" -eq 0 ]; then
	echo "All test suites PASSED"
	exit 0
else
	echo "$FAILURES test suite(s) FAILED"
	exit 1
fi
