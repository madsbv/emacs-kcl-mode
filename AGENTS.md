# AGENTS.md — emacs-kcl-mode

This document captures the current state of the `emacs-kcl-mode` codebase, the problem space it operates in, architectural decisions made, known limitations, and concrete improvement opportunities for future work.

---

## 1. Codebase Overview

### Repository Structure

```
emacs-kcl-mode/
├── kcl-mode.el          # Regex-based major mode + ALL shared commands (1336 lines)
├── kcl-ts-mode.el       # Tree-sitter major mode (346 lines)
├── kcl-lsp.el           # lsp-mode integration (115 lines)
├── kcl-eglot.el         # eglot integration (80 lines)
├── Makefile             # Build targets: byte-compile, lint, test, nix-test, flake-check, clean (62 lines)
├── flake.nix            # Reproducible Nix dev shell and checks (115 lines)
├── flake.lock           # Locked nixpkgs input
├── .gitlab-ci.yml       # Thin GitLab CI wrapper around `nix flake check`
├── README.md            # User documentation (394 lines)
├── AGENTS.md            # This file
├── .gitignore
├── snippets/kcl-mode/   # 10 YASnippet snippet files
│   ├── schema, rule, mixin, protocol, check
│   ├── import, lambda, if, for, assert
├── test/
│   ├── sample.k         # 247-line KCL test file covering all syntax
│   ├── test-fontlock.el  # 65 regex mode ERT tests
│   ├── test-ts-mode.el   # 46 tree-sitter mode ERT tests
│   ├── test-lsp.el       # 19 LSP tests (11 config + 8 live eglot)
│   ├── test-commands.el  # 79 command/feature ERT tests
│   ├── test-doom.el      # 15 Doom Emacs integration tests
│   ├── test-integration.el # 9 integration tests (numaflow)
│   ├── run-tests.sh      # Test runner script (runs all 7 suites)
│   └── compare-nvim.sh   # Neovim cross-validation script
└── libtree-sitter-kcl.so # Compiled grammar (gitignored, build artifact)
```

Total: ~5000 lines across source, tests, and docs. 233 ERT tests, all passing.

### Architectural Decisions

1. **`kcl-mode.el` is the "core" module.** All shared commands, customization variables, the syntax table, compilation mode, eval/snapshot/diff, live preview, project integration, CLI wrappers, import insertion/navigation, documentation lookup, tempo templates, flymake backend, and the transient menu live here. Both `kcl-ts-mode.el` and `kcl-lsp.el` `(require 'kcl-mode)`.

2. **`kcl-ts-mode.el` derives from `prog-mode`, not `kcl-mode`.** This avoids double font-lock (regex + tree-sitter) and unwanted `syntax-propertize-function` interference. It pulls in shared functionality via `(require 'kcl-mode)` and uses the same commands, flymake backend, and tempo tags.

3. **Shared keymap population via `kcl--define-keys`.** Both `kcl-mode-map` and `kcl-ts-mode-map` are populated by calling the shared function `kcl--define-keys`, which defines all 13 `C-c C-*` bindings. This avoids duplication while keeping the two modes' keymaps independent (since `kcl-ts-mode` does not inherit `kcl-mode-map`).

4. **LSP split into two optional files.** `kcl-lsp.el` (lsp-mode) and `kcl-eglot.el` (eglot) are separate require-able modules. Both use `eval-after-load` to defer registration, avoiding hard dependencies on their respective LSP frameworks. Both default their server-command variable to `nil` and fall back to the core `kcl-language-server-command` variable from `kcl-mode.el`.

5. **Tree-sitter grammar is NOT bundled.** The `.so` is gitignored. Users build from source or use `treesit-auto` for automatic installation.

6. **Evil/localleader bindings are in README only**, not in the package. This follows the Emacs package convention that framework-specific bindings belong in user config, not library code.

7. **Format-on-save uses a guard variable.** `kcl--formatting` prevents recursive saves when `before-save-hook` triggers `kcl-format-buffer`. The formatter uses `replace-buffer-contents` (Emacs 26.1+) instead of `revert-buffer` for minimal flicker.

8. **Flymake backend uses temp files.** Buffer contents are written to a temporary `.k` file for linting, so unsaved buffers can be checked without forcing a save.

9. **Byte-compilation and checkdoc are clean.** All four `.el` files compile with zero warnings and pass checkdoc. The `Makefile` enforces this via `make byte-compile` and `make lint`.

10. **Nix is the reproducible validation path.** `flake.nix` builds the KCL tree-sitter grammar, provides `emacs`, `kcl`, and `kcl-language-server` in a dev shell, and runs `make all` in `nix flake check`. `.gitlab-ci.yml` is intentionally thin and delegates to that check.

### KCL Language Facts (Discovered During Development)

- **File extension**: `.k`
- **Comments**: `#` to end of line (no block comments)
- **Strings**: single-quoted, double-quoted, triple-quoted (`"""`, `'''`), raw strings (`r"..."`, `r'...'`)
- **String interpolation**: `${expr}` inside strings
- **Indentation**: 4-space, Python-like (colon triggers indent)
- **Keywords**: `import as schema mixin protocol rule check if elif else for in assert lambda all any map filter type and or not is`
- **Constants**: `True False None Undefined`
- **Built-in types**: `str int float bool any` (plus `list` and `dict` as type constructors)
- **Number literals**: decimal, hex (`0x`), octal (`0o`), binary (`0b`), float, scientific notation, SI suffixes (`Ki Mi Gi Ti Pi n u m k K M G T P`)
- **Decorators**: `@name` or `@name(args)` before schema definitions
- **Schema system**: `schema`, `mixin`, `protocol`, `rule` — each with optional `check:` blocks, inheritance, and mixins
- **Type aliases**: `type Name = Type`
- **Comprehensions**: `[expr for x in iter if cond]`, `{k: v for ...}`
- **Lambda**: `lambda params { body }`
- **Config expressions**: `SomeSchema { field = value }` instantiation syntax

### KCL CLI (`kcl` v0.12.3)

| Subcommand | Behavior | Notes |
|------------|----------|-------|
| `run`      | Evaluate `.k` files, output yaml/json/toml | `--format` flag, NOT `--output` |
| `fmt`      | Format files in-place | No stdin/stdout mode; `kcl-format-buffer` formats a temp file and replaces buffer contents |
| `lint`     | Lint files | `--no_style` suppresses ANSI colors |
| `test`     | Run KCL tests | No `--no_style` flag available |
| `vet`      | Validate data against schema | |
| `doc`      | Generate documentation | |
| `import`   | Import external data/schemas | |
| `mod`      | Module management (`init add update pull push graph metadata pkg`) | |
| `server`   | Start language server (HTTP mode) | Not used; we use `kcl-language-server` over stdio |

### KCL Language Server (`kcl-language-server`)

- Protocol: LSP over stdio
- Capabilities: completion (triggers: `. = : \n`), hover, definition, references, rename, formatting (document + range), document symbols, code actions, signature help, inlay hints, semantic tokens
- Available via: KCL installer, Homebrew, Nix (`nixpkgs#kcl-language-server`)
- Error output: Rust-style diagnostics, ` --> file:line:col` format

### Testing Infrastructure

- All tests run via `emacs --batch` with ERT
- `run-tests.sh` orchestrates 7 test suites (fontlock, ts-mode, LSP, commands, Doom, smoke, integration)
- `make test` runs the full suite; `make all` also runs byte-compile and lint
- `run-tests.sh` honors `EMACS`, `KCL_TREE_SITTER_LOAD_PATH`, and `KCL_NUMAFLOW_DIR`
- `nix flake check --print-build-logs` builds the tree-sitter grammar and runs `make all` in a clean Nix environment
- `compare-nvim.sh` cross-validates tree-sitter highlighting against the neovim plugin (1529 positions matched, 662 additional Emacs-only positions)
- Integration tests use the `kcl-numaflow` repo (5 large auto-generated `.k` files)
- `treesit-extra-load-path` must include the directory containing `libtree-sitter-kcl.so`
- Doom Emacs integration tests (`test-doom.el`) validate that all README-documented symbols, keybindings, modes, and variables exist and work correctly

### Build System

The `Makefile` provides standard development targets:

| Target | Description |
|--------|-------------|
| `make all` | byte-compile + lint + test (default) |
| `make byte-compile` | Compile all `.el` files (warnings are errors) |
| `make lint` | Run checkdoc on all `.el` files |
| `make checkdoc` | Same as lint |
| `make test` | Run the full ERT test suite via `test/run-tests.sh` |
| `make nix-test` | Run `make all` inside the Nix dev shell |
| `make flake-check` | Run `nix flake check --print-build-logs` |
| `make clean` | Remove `.elc` files |

---

## 2. Known Limitations and Technical Debt

### Syntax Highlighting (Regex Mode)

1. **String interpolation inside triple-quoted strings** uses `syntax-propertize` which can be fragile with nested `${}` expressions. Edge cases with `${` followed by strings containing `}` inside the interpolation may not highlight correctly.

2. **SI number suffixes** (e.g., `1Ki`, `5Mi`) are highlighted as constants, but the regex could false-positive on identifiers that start with digits (unlikely in valid KCL but theoretically possible).

3. **No semantic highlighting** — regex mode cannot distinguish between a schema instantiation (`Foo {}`) and a dict literal. Tree-sitter mode handles this correctly.

4. **Decorator arguments** are not individually highlighted — only the decorator name gets `font-lock-preprocessor-face`.

### Indentation

5. **Regex indentation is heuristic-based.** It handles the common cases (colon-ending lines, closing brackets, elif/else alignment) but can fail on complex multi-line expressions, continuation lines with operators, or deeply nested comprehensions.

6. **Tree-sitter indentation** covers more cases but lacks rules for some edge cases like multi-line function call arguments that aren't in parentheses, or `assert` statements spanning multiple lines.

### Formatting

7. **`kcl fmt` is in-place only.** The `kcl-format-buffer` command works around this by formatting a temporary `.k` file and replacing buffer contents, so the original file is not force-saved. This is safe for unsaved buffers, but it still depends on a file-backed buffer because formatter/project behavior can be path-sensitive.

### LSP

8. **`kcl-lsp.el` cannot be tested in batch mode** because `lsp-mode` is not available in the Nix-managed Emacs environment. The 11 config tests use stubs. Live LSP testing is only done via eglot.

9. **No workspace configuration forwarding.** The language server may support workspace-level settings (like custom lint rules or import paths), but neither `kcl-lsp.el` nor `kcl-eglot.el` provides a mechanism to send these.

### Flymake

10. **Flymake error type detection** looks backward from the `-->` line for `warning[W...]` patterns, which can occasionally match the wrong diagnostic if errors are interleaved in the output.

### Commands

11. **`kcl-eval-diff` captures `kcl--frozen-output` from the current buffer** but the diff is computed in temp files. If the user changes `kcl-eval-output-format` between freeze and diff, the frozen format is preserved (correct), but the diff labels don't indicate which format was used.

12. **`kcl-vet` interactive spec** prompts for both data file and schema name every time. There's no way to remember the last-used data file or auto-detect it from project structure.

13. **`kcl-import-add` is text-based.** It inserts imports into the first import block and avoids exact duplicates, but it does not sort imports or query the language server for module completion.

### Documentation

14. **`kcl-doc--url-for` has a hardcoded URL set.** If kcl-lang.io restructures its documentation, all URLs break. There's no fallback to the language server's hover documentation.

15. **`kcl-open-doc-at-point` uses `thing-at-point 'symbol`** which doesn't capture `module.function` as a single symbol in all cases due to `.` being punctuation in the syntax table.

### Package Metadata

16. **No MELPA recipe file.** The package is not yet on MELPA, GNU ELPA, or NonGNU ELPA.

17. **No `Cask` or `Eask` file** for non-Nix package development workflows.

18. **No release automation.** CI exists via GitLab/Nix, but there is no release workflow, tag automation, or package publishing pipeline yet.

---

## 3. Improvement Opportunities

### A. Polish and Refactoring

_Items A1–A8 have been completed. See section 7 for details._

### B. New Features

9. ~~**`kcl-eval-region`** — Evaluate just the selected region.~~ **DONE as region-aware `kcl-eval-buffer`.** When the region is active, it writes imports plus the selected text to a temp `.k` file and evaluates that.

10. **Eldoc integration.** Wire up `eldoc-documentation-function` to show type info / hover docs at point via the language server (eglot already does this, but a non-LSP fallback using `kcl-doc--url-for` data would be useful).

11. ~~**`kcl-switch-output-format`** — Interactive command to cycle between yaml/json/toml for the eval output, with immediate re-eval.~~ **DONE.**

12. ~~**`kcl-mod-update` and `kcl-mod-graph`** — Additional module management commands that are available in the CLI but not yet wrapped.~~ **DONE.**

13. ~~**`kcl-import-add`** — Interactively add an import statement at the top of the file.~~ **DONE.** Future work: integrate with language-server completion to suggest available modules.

14. ~~**Project.el integration.** Define a `project-find-functions` entry that recognizes `kcl.mod` as a project root marker, giving KCL projects first-class support in Emacs's built-in project management.~~ **DONE.**

15. **Xref integration (non-LSP).** For users without the language server, provide basic `xref-backend-functions` that can resolve imports to files by searching the `kcl.mod` vendor directory.

16. ~~**`kcl-debug` / REPL.** KCL doesn't have a true REPL, but a pseudo-REPL that evaluates buffer contents on each save and shows output (like a live preview) would be valuable.~~ **DONE as `kcl-live-preview-mode`.**

17. **Schema inheritance hierarchy visualization.** A command that shows the inheritance chain of a schema, using tree-sitter to parse the `(ParentSchema)` part of `schema Child(Parent):`.

18. **`kcl-test` with test result parsing.** Currently `kcl-test` just launches compilation. A proper integration could parse test results and display them in a test-result buffer or integrate with Emacs's test frameworks.

19. **Headerline breadcrumb.** Show the current schema/rule path in the header line (e.g., `schema Deployment > check`), leveraging tree-sitter parent traversal.

20. **Flycheck integration.** In addition to flymake, provide a flycheck checker definition for users who prefer flycheck over flymake.

### C. Release and Distribution

21. **Create a MELPA recipe.** Requires: a `melpa/recipes/kcl-mode` file, ensuring `Package-Requires` headers are correct, and that byte-compilation succeeds cleanly. _(Byte-compilation is now clean; this is ready to pursue.)_

22. ~~**Add Gitlab CI pipeline using Nix.** Run the ERT test suite on push/PR. The CI would need: Emacs 27+ (for regex mode tests), Emacs 29+ (for treesit/eglot tests), the `kcl` CLI, and the tree-sitter grammar. Use `nix` for reproducible builds and actually running the tests, make the Gitlab CI job as thin as possible wrapper around Nix.~~ **DONE.** `nix flake check` builds the grammar and runs `make all`; `.gitlab-ci.yml` delegates to it.

23. **Version management.** Add a `Version:` changelog and follow semver. The current `0.1.0` is a good starting point.

24. ~~**Add a `Makefile` or `Eask` file.**~~ **DONE.** `Makefile` added with `byte-compile`, `lint` (checkdoc), `test`, `clean` targets.

25. **Write a `DEVELOPING.md`.** Document how to build the tree-sitter grammar, run tests, package, and other relevant tasks.

26. ~~**Add an `Eask` or `Cask` file** for reproducible CI dependency management.~~ **DONE via Nix flake instead of Eask/Cask.**

### D. Advanced / Exploratory

27. **Semantic token support.** The language server provides `semanticTokensProvider`. Tree-sitter mode could use semantic tokens from the server to enhance highlighting beyond what the grammar provides (e.g., distinguishing local variables from schema attributes). Emacs LSP-mode supports semantic tokens.

28. **Inlay hints.** The language server supports `inlayHintProvider`. Emacs 29+ eglot and lsp-mode both support inlay hints. Document how to enable them, and potentially add a custom face for KCL-specific inlay hint styling.

29. **Code lens.** If the language server adds code lens support in the future, wire it up.

30. **DAP (Debug Adapter Protocol).** If KCL ever adds debugging support, provide a `dap-mode` integration.

31. **Org-babel integration.** Allow KCL code blocks in Org mode files with `#+begin_src kcl` that can be evaluated and produce yaml/json output inline.

32. **Polyglot/multi-mode support.** For files that embed KCL in YAML (like some Kusion configurations), provide a way to activate KCL highlighting in embedded contexts.

### E. Doom Emacs Integration Testing

33. ~~**Add tests that validate the Doom Emacs configuration from the README.**~~ **DONE.** 15 ERT tests in `test/test-doom.el` validate:
    - Symbol existence: all 11 commands referenced in `map!` blocks are `fboundp` and `commandp`
    - Keymap parity: every command has a `C-c C-*` binding in both `kcl-mode-map` and `kcl-ts-mode-map`
    - Exact binding verification: all 11 keybindings match expected command targets
    - Mode/feature availability: `auto-mode-alist`, major-mode activation, `provide` symbols, keymap validity
    - Variable availability: `kcl-format-on-save` is a custom variable, `kcl-language-server-command` is settable
    - LSP server-command fallback: `kcl-lsp-server-command` overrides and falls back to the core variable correctly

---

## 4. Environment Notes

- **Emacs version**: 30.2 (with `treesit` module)
- **KCL CLI version**: 0.12.3
- **Language server**: 0.11.2 (from Nix, at `/nix/store/64fh9mah7f0fa4i0q5pgcrp89jpymnb4-kcl-language-server-0.11.2-unstable-2025-10-26/bin/kcl-language-server`)
- **Tree-sitter grammar**: built from source at `https://github.com/kcl-lang/tree-sitter-kcl`; local `.so` at repo root is gitignored, while Nix builds a pinned grammar derivation
- **Reference repos**: `kcl.nvim/` (neovim plugin), `kcl-numaflow/` (integration test files), `tree-sitter-kcl/` (grammar source)
- **Testing**: `emacs --batch` with ERT. `lsp-mode` NOT available in batch; `eglot` IS available (built-in).
- **Nix**: `flake.nix` provides `nix develop`, `nix flake check`, `kcl`, `kcl-language-server`, and a pinned tree-sitter grammar build

## 5. Cross-validation Results

The `compare-nvim.sh` script extracted tree-sitter highlighting from both the neovim plugin and Emacs's `kcl-ts-mode` on the same `sample.k` file:

- **1529 positions** matched exactly between neovim and Emacs
- **0 mismatches** — no position was highlighted differently
- **662 additional positions** highlighted by Emacs that neovim did not highlight (Emacs is more thorough)
- **kcl-ts-mode is ~2.5x faster** than regex `kcl-mode` on the numaflow files

## 6. Key Bug Fixes During Development

1. **`defvar-local` scope in `with-temp-file`**: `kcl--frozen-output` was nil inside `with-temp-file` because `defvar-local` variables are buffer-local. Fixed by capturing the value in a `let` binding before entering `with-temp-file`.

2. **`define-derived-mode` auto-creates keymaps**: If `kcl-ts-mode-map` was defined AFTER `define-derived-mode`, the mode would create an empty keymap and ignore the one defined by `defvar`. Fixed by moving the keymap `defvar` BEFORE the mode definition.

3. **Tree-sitter `alias:` field**: `import_stmt` inlines `_aliased_import` in the grammar, so the `alias:` field name doesn't work in queries. Fixed by matching `(import_stmt "as" (identifier) @cap)` instead.

4. **`treesit-node-type` returns strings**: Some code compared node types with symbols. Fixed all comparisons to use `string=` or `member` with string lists.

5. **`kcl run --output` doesn't exist**: The flag is `--format`. Discovered by testing and fixed.

6. **Hermetic tests need a writable HOME.** In the Nix sandbox, Emacs `project.el` and `kcl` both need writable state directories. The flake check sets `HOME` under `$TMPDIR`, and live LSP tests bind `project-list-file` inside their temp project.

7. **Tree-sitter output modes should be guarded.** `yaml-ts-mode` and `toml-ts-mode` can exist even when their grammars are missing. `kcl--display-output-buffer` now checks `treesit-ready-p` before enabling them, avoiding noisy grammar warnings during eval tests.

## 7. Completed Improvements

### Phase 1: Code Quality (A1–A8)

All eight items from section 3A have been completed and committed:

1. **A1 — Eliminate keymap duplication.** Created `kcl--define-keys` helper function in `kcl-mode.el` that populates a keymap with the standard bindings (currently 13). Both `kcl-mode-map` and `kcl-ts-mode-map` call this function, eliminating duplicated `define-key` calls.

2. **A2 — Improve format-on-save.** Added `kcl--formatting` guard variable (defvar-local) to prevent recursive saves when `before-save-hook` triggers formatting. Replaced `revert-buffer` with `replace-buffer-contents` (Emacs 26.1+) for less visual flicker during formatting.

3. **A3 — Make flymake work on unsaved buffers.** Rewrote the flymake backend to write buffer contents to a temporary `.k` file, run `kcl lint` on that temp file, and clean up in the process sentinel. Removed the forced `save-buffer` call and source-file matching (since all diagnostics come from the temp file).

4. **A4 — Guard `kcl-eglot.el`.** Replaced `(require 'eglot)` with `(eval-after-load 'eglot ...)` plus `declare-function` and `defvar` declarations. Added `(require 'kcl-mode)` for the core variable fallback. `kcl-eglot.el` is now loadable on Emacs <29 without errors.

5. **A5 — Consolidate language-server-command.** `kcl-lsp-server-command` and `kcl-eglot-server-command` now default to `nil`. Both LSP files define a `--server-command` helper function that returns `(or local-var kcl-language-server-command)`, falling back to the core variable from `kcl-mode.el`.

6. **A6 — Byte-compilation warnings audit.** Fixed all warnings across all four `.el` files: added `declare-function` for `transient-define-prefix`, `kcl-transient-menu`, `treesit-auto-recipe-lang`, `lsp-activate-on`, `make-lsp-client`; added `defvar` for `kcl-transient-menu`, `lsp-language-id-configuration`; restored accidentally deleted `kcl-run-buffer` function; fixed an extra closing parenthesis in the flymake backend.

7. **A7 — Checkdoc compliance.** Fixed two warnings: quoted `syntax-propertize` in docstrings for `kcl-mode--syntax-propertize-triple-quote` and `kcl-mode--syntax-propertize-interpolation`.

8. **A8 — Fix flymake backend.** Replaced `cl-return-from` with standard `if/else` control flow, eliminating the need for `cl-lib` at runtime.

### Phase 2: Doom Emacs Integration Tests (E33)

Added `test/test-doom.el` with 15 ERT tests that validate the Doom Emacs configuration documented in the README. Tests cover symbol existence (`fboundp`/`commandp`), keymap parity between both modes, exact keybinding verification, mode/feature availability, customization variables, and LSP server-command fallback behavior. Added the test suite to `test/run-tests.sh`. Total test count was 209 at that point; it is now 233.

### Phase 3: Makefile (C24)

Added `Makefile` with standard development targets: `byte-compile` (compiles all `.el` files, warnings as errors), `lint`/`checkdoc` (runs checkdoc, fails on warnings), `test` (runs full ERT suite via `run-tests.sh`), `clean` (removes `.elc` files), and `all` (default: byte-compile + lint + test).

### Phase 4: Eval, Project, and Live Preview Features (B9, B11, B14, B16)

Added region-aware `kcl-eval-buffer`, `kcl-switch-output-format`, `kcl-project-try` for `kcl.mod` project roots, and `kcl-live-preview-mode`. Tests cover region evaluation, output-format cycling, project detection, and live-preview hook behavior.

### Phase 5: Nix Validation and GitLab CI (C22, C26)

Added `flake.nix` and `flake.lock` with a pinned `tree-sitter-kcl` grammar build, a dev shell containing Emacs/KCL/LSP tooling, and a flake check that runs `make all` with `KCL_TREE_SITTER_LOAD_PATH` and `KCL_LANGUAGE_SERVER` set. Added `.gitlab-ci.yml` as a thin wrapper around `nix flake check --print-build-logs`. `run-tests.sh` now honors `EMACS`, `KCL_TREE_SITTER_LOAD_PATH`, and `KCL_NUMAFLOW_DIR`.

### Phase 6: Module and Import Commands (B12, B13)

Added `kcl-mod-update`, `kcl-mod-graph`, and `kcl-import-add`. Improved `kcl-goto-imports` to find real import statements while avoiding comments/strings. The transient menu exposes the new commands, and `test/test-commands.el` now covers command construction, import insertion, duplicate avoidance, and safer import navigation. Total test count: 233.

### Lessons Learned

- **Paren counting in deeply nested elisp is error-prone.** Always verify changes with `emacs --batch` load test after editing. Use `check-parens` or `forward-sexp` to find mismatches.
- **`cl-return-from` requires `cl-defun`**, not just `defun`. Restructuring to `if/else` is often cleaner than adding the `cl-lib` dependency.
- **`kcl fmt` is in-place only** (no stdin/stdout mode), so formatting uses a temp-file-then-replace workflow. `replace-buffer-contents` (Emacs 26.1+) is superior to `revert-buffer` for this.
- **`before-save-hook` + format-on-save needs a recursion guard.** A simple `defvar-local` guard variable (`kcl--formatting`) is the correct fix.
- **`eval-after-load` is the right pattern** for optional dependencies like `eglot`, `transient`, and `treesit-auto`. Combined with `declare-function`/`defvar`, it gives clean byte-compilation.
- **Test expectations must be updated** when changing variable defaults. The server-command consolidation (A5) changed defaults from `'("kcl-language-server")` to `nil`, breaking 5 existing tests that expected the old value.
- **checkdoc's diagnostic buffer includes a header line** even when there are no warnings. Checking for actual diagnostic content (e.g., lines matching `:[0-9]+:`) is more reliable than checking `(point-min) = (point-max)`.
