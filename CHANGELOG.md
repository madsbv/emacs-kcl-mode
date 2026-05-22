# Changelog

All notable changes to `emacs-kcl-mode` are documented in this file. The
project follows semantic versioning.

## 0.1.0 - Unreleased

### Added

- Regex and tree-sitter major modes for KCL files.
- Shared KCL CLI commands for run, eval, format, lint, test, vet, module
  management, import insertion, documentation lookup, snapshots, and live
  preview.
- Flymake diagnostics, optional Flycheck checker, and optional Org Babel
  execution support.
- `lsp-mode` and Eglot registration for `kcl-language-server`.
- Project.el, Eldoc, xref, schema hierarchy, breadcrumb, imenu, outline, and
  `which-function-mode` integrations.
- Nix flake, GitLab CI wrapper, Makefile targets, MELPA recipe draft, and Eask
  metadata for development and packaging workflows.

### Changed

- Formatting uses a temp-file workflow and `replace-buffer-contents` so unsaved
  buffers are not force-saved by `kcl fmt`.
- Test execution is reproducible through `nix flake check` and configurable via
  `EMACS`, `KCL_TREE_SITTER_LOAD_PATH`, and `KCL_NUMAFLOW_DIR`.

### Fixed

- Dotted standard-library documentation lookup such as `math.log`.
- Regex highlighting for decorator arguments and invalid SI-number suffixes.
- Continuation indentation after operators.
- Flymake diagnostic type parsing for mixed warning/error output.
- Diff labels for frozen output formats and remembered defaults for `kcl-vet`.
