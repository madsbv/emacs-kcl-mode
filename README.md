# emacs-kcl-mode

Emacs major mode for editing [KCL](https://kcl-lang.io) (Kusion Configuration Language) files.

## Features

- **`kcl-mode`** -- Regex-based major mode (Emacs 27.1+)
  - Syntax highlighting via font-lock (keywords, types, strings, numbers, decorators, etc.)
  - Comment support (`#` line comments)
  - Python-like indentation (4-space default)
  - Imenu for schema, rule, protocol, mixin, and type definitions
  - Outline support for code folding
  - `which-function-mode` support

- **`kcl-ts-mode`** -- Tree-sitter based major mode (Emacs 29.1+)
  - Accurate, parse-tree-based syntax highlighting with 16 feature categories
  - Structural indentation and navigation
  - Imenu and defun navigation via tree-sitter queries
  - Tree-sitter-based `which-function-mode` support
  - All the same keybindings and commands as `kcl-mode`

- **LSP integration** -- Works with `kcl-language-server`
  - `kcl-lsp.el` for [lsp-mode](https://emacs-lsp.github.io/lsp-mode/) users
  - `kcl-eglot.el` for [eglot](https://github.com/joaotavora/eglot) users (built-in to Emacs 29+)
  - Supports: completion, hover, go-to-definition, find references, rename, formatting, diagnostics

- **Eval with snapshot diff**
  - `kcl-eval-buffer` -- evaluate and display output in a side buffer (yaml/json/toml)
  - `kcl-eval-freeze` -- save the current output as a baseline snapshot
  - `kcl-eval-diff` -- re-evaluate and diff against the frozen snapshot
  - `kcl-switch-output-format` -- cycle yaml/json/toml and re-evaluate
  - `kcl-live-preview-mode` -- re-evaluate automatically after saves

- **CLI commands**
  - `kcl-lint-buffer` -- lint the current file
  - `kcl-test` -- run tests in the current project
  - `kcl-vet` -- validate data files against schemas
  - `kcl-mod-init` / `kcl-mod-add` / `kcl-mod-update` / `kcl-mod-graph` -- module management
  - `kcl-import-add` -- insert an import in the import section
  - `kcl-goto-imports` -- jump to the import section

- **Editor integrations** -- project.el roots for `kcl.mod`, Eldoc fallback docs, basic xref, breadcrumbs, and schema hierarchy display

- **Compilation modes** -- `kcl-compilation-mode` and `kcl-test-compilation-mode` with KCL error regexps, ANSI color support, and clickable error locations

- **Documentation lookup** -- `kcl-open-doc-at-point` opens kcl-lang.io docs for the symbol at point (built-in types, functions, stdlib modules, keywords)

- **Templates** -- built-in tempo templates for schema, rule, mixin, protocol, check, import, lambda, if, for, assert; optional YASnippet snippets in `snippets/`

- **Flymake integration** -- `kcl-flymake-backend` for live diagnostics via `kcl lint`

- **Optional Flycheck integration** -- `kcl-flycheck.el` registers a Flycheck checker without hard-requiring Flycheck at startup

- **Optional Org Babel integration** -- `ob-kcl.el` evaluates `#+begin_src kcl` blocks through `kcl run`

- **Optional embedded KCL support** -- `kcl-polyglot.el` registers mmm-mode regions for KCL YAML literal blocks

- **Transient menu** -- `kcl-transient` popup grouping all commands (falls back to `completing-read` when transient is unavailable)

- **Format on save** -- Optional automatic formatting via `kcl fmt`

- **treesit-auto** -- Automatic tree-sitter grammar installation when [treesit-auto](https://github.com/renzmann/treesit-auto) is available

## Requirements

- Emacs 27.1+ for `kcl-mode` (regex-based)
- Emacs 29.1+ for `kcl-ts-mode` (tree-sitter-based) and `kcl-eglot.el`
- [KCL CLI](https://kcl-lang.io/docs/user_docs/getting-started/install/) for `kcl run` and `kcl fmt` commands
- [kcl-language-server](https://kcl-lang.io/docs/user_docs/getting-started/install/) for LSP features
- Optional: [Flycheck](https://www.flycheck.org/) for `kcl-flycheck.el`
- Optional: Org mode for `ob-kcl.el`
- Optional: [mmm-mode](https://github.com/purcell/mmm-mode) for `kcl-polyglot.el`

### Installing the tree-sitter grammar

If you use `treesit-auto` with `global-treesit-auto-mode`, the grammar will be installed automatically when you first open a `.k` file.

Otherwise, build and install it manually:

```sh
git clone https://github.com/kcl-lang/tree-sitter-kcl
cd tree-sitter-kcl
gcc -shared -fPIC -O2 -o libtree-sitter-kcl.so src/parser.c src/scanner.c -I src
```

Place the resulting `libtree-sitter-kcl.so` (or `.dylib` on macOS) somewhere on your `treesit-extra-load-path`, or in `~/.emacs.d/tree-sitter/`.

### Installing the language server

```sh
# Via the KCL installer script
curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash

# Via Homebrew
brew install kcl-lang/tap/kcl-lsp

# Via Nix
nix-env -iA nixpkgs.kcl-language-server
# or run without installing:
nix run nixpkgs#kcl-language-server
```

## Installation

### From source (straight.el)

```elisp
(straight-use-package
 '(kcl-mode :type git :host github :repo "madsbv/emacs-kcl-mode"))
```

### From source (use-package + straight)

```elisp
(use-package kcl-mode
  :straight (:host github :repo "madsbv/emacs-kcl-mode"))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-kcl-mode")
(require 'kcl-mode)
```

## Configuration

### Basic setup (regex mode)

```elisp
(require 'kcl-mode)
;; .k files will automatically use kcl-mode
```

### Tree-sitter mode

```elisp
(require 'kcl-ts-mode)
;; .k files will automatically use kcl-ts-mode (requires grammar installed)
;; Falls back to kcl-mode if the grammar is not available
```

### LSP with lsp-mode

```elisp
(require 'kcl-lsp)
;; Then manually start with M-x lsp in a .k buffer

;; Or auto-start LSP in KCL buffers:
(add-hook 'kcl-mode-hook #'lsp-deferred)
(add-hook 'kcl-ts-mode-hook #'lsp-deferred)
```

### LSP with eglot

```elisp
(require 'kcl-eglot)
;; Then manually start with M-x eglot in a .k buffer

;; Or auto-start eglot in KCL buffers:
(add-hook 'kcl-mode-hook #'eglot-ensure)
(add-hook 'kcl-ts-mode-hook #'eglot-ensure)
```

### Flymake

Flymake is automatically set up when `kcl-mode` or `kcl-ts-mode` activates. To enable it:

```elisp
(add-hook 'kcl-mode-hook #'flymake-mode)
(add-hook 'kcl-ts-mode-hook #'flymake-mode)
```

### Flycheck

```elisp
(require 'kcl-flycheck)
(add-hook 'kcl-mode-hook #'flycheck-mode)
(add-hook 'kcl-ts-mode-hook #'flycheck-mode)
```

### Org Babel

```elisp
(require 'ob-kcl)

;; Example Org block:
;; #+begin_src kcl :format yaml
;; x = 1
;; #+end_src
```

Use `:format yaml`, `:format json`, or `:format toml` to control `kcl run --format`.

### Embedded KCL in YAML

`kcl-polyglot.el` registers an mmm-mode class for YAML literal blocks keyed by
`kcl`, `kclCode`, or `kcl_code`:

```elisp
(require 'mmm-mode)
(require 'kcl-polyglot)
```

### Breadcrumbs and live preview

```elisp
(add-hook 'kcl-mode-hook #'kcl-breadcrumb-mode)
(add-hook 'kcl-ts-mode-hook #'kcl-breadcrumb-mode)

;; Re-evaluate the buffer after each save.
(add-hook 'kcl-mode-hook #'kcl-live-preview-mode)
```

### Format on save

```elisp
(setq kcl-format-on-save t)
```

### Eval output format

```elisp
;; Default is "yaml"; also supports "json" and "toml"
(setq kcl-eval-output-format "json")
```

Use `M-x kcl-switch-output-format` to cycle formats and immediately re-evaluate.

### Custom KCL binary path

```elisp
(setq kcl-command "/path/to/kcl")
```

### Custom language server path

```elisp
;; For lsp-mode:
(setq kcl-lsp-server-command '("/path/to/kcl-language-server"))

;; For eglot:
(setq kcl-eglot-server-command '("/path/to/kcl-language-server"))
```

### Semantic tokens and inlay hints

`kcl-language-server` advertises semantic tokens and inlay hints. Use the
standard client controls for your LSP package, for example `lsp-semantic-tokens-enable`
with lsp-mode or `eglot-inlay-hints-mode` with Eglot when available.

### YASnippet snippets

If you use [YASnippet](https://github.com/joaotavora/yasnippet), add the bundled snippets directory:

```elisp
(setq yas-snippet-dirs (append yas-snippet-dirs
                               '("/path/to/emacs-kcl-mode/snippets")))
```

Available snippets: `schema`, `rule`, `mixin`, `protocol`, `check`, `import`, `lambda`, `if`, `for`, `assert`.

## Doom Emacs

Add the following to your Doom Emacs configuration:

### `packages.el`

```elisp
;; From GitHub:
(package! kcl-mode
  :recipe (:host github :repo "madsbv/emacs-kcl-mode"))

;; Or from a local git repo (useful during development):
(package! kcl-mode
  :recipe (:local-repo "/path/to/emacs-kcl-mode"
           :build (:not compile)))
```

### `config.el`

```elisp
;; KCL language support
(use-package! kcl-mode
  :mode "\\.k\\'"
  :config
  (setq kcl-format-on-save t)

  ;; Evil localleader keybindings (SPC m)
  (map! :localleader
        :map kcl-mode-map
        ;; Run / Eval
        :desc "Run buffer"       "r" #'kcl-run-buffer
        :desc "Eval buffer"      "e" #'kcl-eval-buffer
        :desc "Freeze snapshot"  "s" #'kcl-eval-freeze
        :desc "Diff snapshot"    "d" #'kcl-eval-diff
        :desc "Output format"    "o" #'kcl-switch-output-format
        :desc "Live preview"     "p" #'kcl-live-preview-mode
        ;; Tooling
        :desc "Format buffer"    "f" #'kcl-format-buffer
        :desc "Lint buffer"      "l" #'kcl-lint-buffer
        :desc "Test project"     "t" #'kcl-test
        :desc "Vet data file"   "v" #'kcl-vet
        ;; Project
        :desc "Go to imports"    "i" #'kcl-goto-imports
        ;; Docs
        :desc "Doc at point"     "h" #'kcl-open-doc-at-point
        ;; Menu
        :desc "Command menu"     "m" #'kcl-transient))

;; Tree-sitter mode (Emacs 29+, Doom with +tree-sitter)
(use-package! kcl-ts-mode
  :when (modulep! :tools tree-sitter)
  :mode "\\.k\\'"
  :config
  (map! :localleader
        :map kcl-ts-mode-map
        :desc "Run buffer"       "r" #'kcl-run-buffer
        :desc "Eval buffer"      "e" #'kcl-eval-buffer
        :desc "Freeze snapshot"  "s" #'kcl-eval-freeze
        :desc "Diff snapshot"    "d" #'kcl-eval-diff
        :desc "Output format"    "o" #'kcl-switch-output-format
        :desc "Live preview"     "p" #'kcl-live-preview-mode
        :desc "Format buffer"    "f" #'kcl-format-buffer
        :desc "Lint buffer"      "l" #'kcl-lint-buffer
        :desc "Test project"     "t" #'kcl-test
        :desc "Vet data file"   "v" #'kcl-vet
        :desc "Go to imports"    "i" #'kcl-goto-imports
        :desc "Doc at point"     "h" #'kcl-open-doc-at-point
        :desc "Command menu"     "m" #'kcl-transient))

;; LSP integration
;; Option A: lsp-mode (if you use the :tools lsp module)
(after! lsp-mode
  (require 'kcl-lsp))

(add-hook! (kcl-mode kcl-ts-mode) #'lsp!)

;; Option B: eglot (if you use :tools lsp +eglot)
;; (after! eglot
;;   (require 'kcl-eglot))
;; (add-hook! (kcl-mode kcl-ts-mode) #'eglot-ensure)
```

With LSP enabled, Doom's built-in `SPC c` bindings work automatically in KCL buffers:

| Key       | Action                     |
|-----------|----------------------------|
| `SPC m r` | Run file (`kcl run`)       |
| `SPC m e` | Eval buffer (side output)  |
| `SPC m s` | Freeze output snapshot     |
| `SPC m d` | Diff against snapshot      |
| `SPC m o` | Cycle output format        |
| `SPC m p` | Toggle live preview        |
| `SPC m f` | Format (`kcl fmt`)         |
| `SPC m l` | Lint buffer                |
| `SPC m t` | Test project               |
| `SPC m v` | Vet data file              |
| `SPC m i` | Go to imports              |
| `SPC m h` | Doc at point               |
| `SPC m m` | Command menu (transient)   |
| `SPC c d` | Go to definition           |
| `SPC c D` | Find references            |
| `SPC c a` | Code action                |
| `SPC c r` | Rename symbol              |
| `SPC c f` | Format (via LSP)           |
| `SPC c k` | Documentation lookup       |
| `SPC c x` | List diagnostics           |

If the language server is installed somewhere non-standard (e.g., via Nix):

```elisp
;; In config.el
(setq kcl-lsp-server-command '("nix" "run" "nixpkgs#kcl-language-server" "--"))
;; or
(setq kcl-lsp-server-command '("/path/to/kcl-language-server"))
```

### Nix + Doom Emacs

If you manage your system with Nix and want the language server available without installing it globally:

```elisp
;; In config.el
(after! lsp-mode
  (require 'kcl-lsp)
  (setq kcl-lsp-server-command '("nix" "run" "nixpkgs#kcl-language-server" "--")))
```

## Key Bindings

### Emacs

| Key       | Command                | Description                      |
|-----------|------------------------|----------------------------------|
| `C-c C-c` | `kcl-transient`        | Open KCL command menu            |
| `C-c C-r` | `kcl-run-buffer`       | Run the current file with `kcl`  |
| `C-c C-e` | `kcl-eval-buffer`      | Eval and show output in side buf |
| `C-c C-s` | `kcl-eval-freeze`      | Freeze output as snapshot        |
| `C-c C-d` | `kcl-eval-diff`        | Diff against frozen snapshot     |
| `C-c C-o` | `kcl-switch-output-format` | Cycle eval output format     |
| `C-c C-p` | `kcl-live-preview-mode`| Toggle live preview              |
| `C-c C-f` | `kcl-format-buffer`    | Format the current file          |
| `C-c C-l` | `kcl-lint-buffer`      | Lint the current file            |
| `C-c C-t` | `kcl-test`             | Run tests in project             |
| `C-c C-v` | `kcl-vet`              | Validate data file against schema|
| `C-c C-i` | `kcl-goto-imports`     | Jump to import section           |
| `C-c C-h` | `kcl-open-doc-at-point`| Open docs for symbol at point    |

### Evil (Doom Emacs)

See the [Doom Emacs](#doom-emacs) section for `SPC m` localleader bindings.
LSP actions (`SPC c d`, `SPC c r`, etc.) work automatically when LSP is enabled.

## Customization

| Variable                    | Default                        | Description                               |
|-----------------------------|--------------------------------|-------------------------------------------|
| `kcl-indent-offset`         | `4`                            | Number of spaces per indentation level    |
| `kcl-command`               | `"kcl"`                        | Path to the `kcl` CLI binary              |
| `kcl-format-on-save`        | `nil`                          | Format buffer before saving               |
| `kcl-eval-output-format`    | `"yaml"`                       | Eval output format (yaml/json/toml)       |
| `kcl-lsp-server-command`    | `nil`                          | lsp-mode server override                  |
| `kcl-lsp-auto-start`        | `nil`                          | Auto-start lsp-mode in KCL buffers        |
| `kcl-eglot-server-command`  | `nil`                          | eglot server override                     |

## Running Tests

```sh
# Reproducible full validation with Nix
nix flake check --print-build-logs

# Or enter the dev shell and run the same local target
nix develop
make all

# Run all local validation with tools from PATH
make all

# Run tests only (requires kcl CLI and tree-sitter grammar)
./test/run-tests.sh

# Override tool and fixture locations when needed
EMACS=/path/to/emacs \
KCL_TREE_SITTER_LOAD_PATH=/path/to/tree-sitter-libs \
KCL_NUMAFLOW_DIR=/path/to/kcl-numaflow/numaflow/v1alpha1 \
  ./test/run-tests.sh

# Run specific test files
emacs --batch -L . -l test/test-fontlock.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l test/test-ts-mode.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l test/test-lsp.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l ert -l test/test-optional.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l kcl-mode -l kcl-ts-mode -l test/test-commands.el -f ert-run-tests-batch-and-exit

# Run live LSP tests (requires kcl-language-server)
KCL_LANGUAGE_SERVER=/path/to/kcl-language-server \
  emacs --batch -L . -l test/test-lsp.el -f ert-run-tests-batch-and-exit
```

## License

Apache-2.0. See [SPDX headers](https://spdx.org/licenses/Apache-2.0.html) in source files.
