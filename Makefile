.PHONY: all byte-compile lint checkdoc test nix-test flake-check clean

EMACS ?= emacs
EMACS_BATCH = $(EMACS) --batch -L .

EL_FILES = kcl-mode.el kcl-ts-mode.el kcl-lsp.el kcl-eglot.el
ELC_FILES = $(EL_FILES:.el=.elc)

all: byte-compile lint test

## Byte-compile all .el files (warnings are errors)
byte-compile: $(ELC_FILES)

%.elc: %.el
	@echo "  COMPILE $<"
	@$(EMACS_BATCH) -f batch-byte-compile $<

## Run checkdoc on all .el files
checkdoc:
	@echo "--- checkdoc ---"
	@FAIL=0; \
	for f in $(EL_FILES); do \
	  OUTPUT=$$($(EMACS_BATCH) --eval " \
	    (progn \
	      (require 'checkdoc) \
	      (find-file \"$$f\") \
	      (let ((checkdoc-autofix-flag 'never) \
	            (checkdoc-diagnostic-buffer \"*warn*\")) \
	        (checkdoc-current-buffer t) \
	        (with-current-buffer \"*warn*\" \
	          (goto-char (point-min)) \
	          (when (re-search-forward \":[0-9]+:\" nil t) \
	            (goto-char (point-min)) \
	            (princ (buffer-string)) \
	            (kill-emacs 1)))))" 2>&1) || FAIL=1; \
	  if [ -n "$$OUTPUT" ]; then echo "$$OUTPUT"; fi; \
	done; \
	if [ "$$FAIL" -ne 0 ]; then \
	  echo "  FAILED"; exit 1; \
	else \
	  echo "  PASSED"; \
	fi

## Lint: checkdoc (package-lint requires MELPA setup, omitted for now)
lint: checkdoc

## Run the full ERT test suite
test:
	@EMACS="$(EMACS)" bash test/run-tests.sh

## Run the full validation suite inside the Nix dev shell
nix-test:
	@nix develop --command make all

## Run flake checks
flake-check:
	@nix flake check --print-build-logs

## Remove byte-compiled files
clean:
	@rm -f $(ELC_FILES)
	@echo "Cleaned."
