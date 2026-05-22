# Developing emacs-kcl-mode

## Prerequisites

- Emacs 27.1+ for `kcl-mode`.
- Emacs 29.1+ for `kcl-ts-mode`, Eglot, and tree-sitter tests.
- KCL CLI for run, format, lint, test, vet, and Org Babel execution.
- `kcl-language-server` for live LSP tests.
- A compiled `tree-sitter-kcl` grammar for tree-sitter tests.

The easiest reproducible environment is:

```sh
nix develop
```

## Tree-sitter grammar

The grammar is not vendored. Build it manually when not using Nix:

```sh
git clone https://github.com/kcl-lang/tree-sitter-kcl
cd tree-sitter-kcl
gcc -shared -fPIC -O2 -o libtree-sitter-kcl.so src/parser.c src/scanner.c -I src
```

Then point tests at the directory containing the shared library:

```sh
KCL_TREE_SITTER_LOAD_PATH=/path/to/tree-sitter-kcl ./test/run-tests.sh
```

## Validation

Run the full local suite with tools from `PATH`:

```sh
make all
```

Run the hermetic Nix check:

```sh
nix flake check --print-build-logs
```

Useful focused targets:

```sh
make byte-compile
make lint
make test
make clean
```

## Tests

`test/run-tests.sh` runs the font-lock, tree-sitter, LSP, command, Doom,
optional integration, smoke, and numaflow integration suites. It honors:

- `EMACS` for the Emacs binary.
- `KCL_TREE_SITTER_LOAD_PATH` for the compiled grammar directory.
- `KCL_NUMAFLOW_DIR` for the integration fixture directory.
- `KCL_LANGUAGE_SERVER` for live Eglot tests.

Run a single suite directly, for example:

```sh
emacs --batch -L . -l ert -l test/test-optional.el -f ert-run-tests-batch-and-exit
```

## Packaging

The package entry point is `kcl-mode.el`. Optional files are intentionally
loadable without their optional dependencies until the corresponding package is
loaded:

- `kcl-lsp.el` registers after `lsp-mode` loads.
- `kcl-eglot.el` registers after Eglot loads.
- `kcl-flycheck.el` registers after Flycheck loads.
- `kcl-polyglot.el` registers embedded YAML regions after mmm-mode loads.
- `ob-kcl.el` requires Org Babel because it provides an Org language executor.

Packaging metadata lives in:

- `melpa/recipes/kcl-mode` for a MELPA recipe draft.
- `Eask` for non-Nix package-development workflows.
- `CHANGELOG.md` for semantic-versioned release notes.

Before tagging a release, update all `Version:` headers, refresh the changelog,
run `make all`, and run `nix flake check --print-build-logs`.
