# emacs-kcl-mode

Emacs major mode for editing [KCL](https://kcl-lang.io) (Kusion Configuration Language) files.

## Features

- **`kcl-mode`** -- Regex-based major mode (Emacs 27.1+)
  - Syntax highlighting via font-lock (keywords, types, strings, numbers, decorators, etc.)
  - Comment support (`#` line comments)
  - Python-like indentation (4-space default)
  - Imenu for schema, rule, protocol, mixin, and type definitions
  - Outline support for code folding
  - `C-c C-r` to run the current file with `kcl run`
  - `C-c C-f` to format the current file with `kcl fmt`

- **`kcl-ts-mode`** -- Tree-sitter based major mode (Emacs 29.1+)
  - Accurate, parse-tree-based syntax highlighting with 16 feature categories
  - Structural indentation and navigation
  - Imenu and defun navigation via tree-sitter queries
  - All the same keybindings as `kcl-mode`

- **LSP integration** -- Works with `kcl-language-server`
  - `kcl-lsp.el` for [lsp-mode](https://emacs-lsp.github.io/lsp-mode/) users
  - `kcl-eglot.el` for [eglot](https://github.com/joaotavora/eglot) users (built-in to Emacs 29+)
  - Supports: completion, hover, go-to-definition, find references, rename, formatting, diagnostics

- **Format on save** -- Optional automatic formatting via `kcl fmt`

- **treesit-auto** -- Automatic tree-sitter grammar installation when [treesit-auto](https://github.com/renzmann/treesit-auto) is available

## Requirements

- Emacs 27.1+ for `kcl-mode` (regex-based)
- Emacs 29.1+ for `kcl-ts-mode` (tree-sitter-based) and `kcl-eglot.el`
- [KCL CLI](https://kcl-lang.io/docs/user_docs/getting-started/install/) for `kcl run` and `kcl fmt` commands
- [kcl-language-server](https://kcl-lang.io/docs/user_docs/getting-started/install/) for LSP features

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
 '(kcl-mode :type git :host github :repo "kcl-lang/emacs-kcl-mode"))
```

### From source (use-package + straight)

```elisp
(use-package kcl-mode
  :straight (:host github :repo "kcl-lang/emacs-kcl-mode"))
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

### Format on save

```elisp
(setq kcl-format-on-save t)
```

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

## Doom Emacs

Add the following to your Doom Emacs configuration:

### `packages.el`

```elisp
;; From GitHub:
(package! kcl-mode
  :recipe (:host github :repo "kcl-lang/emacs-kcl-mode"))

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
        :desc "Run buffer"    "r" #'kcl-run-buffer
        :desc "Format buffer" "f" #'kcl-format-buffer))

;; Tree-sitter mode (Emacs 29+, Doom with +tree-sitter)
(use-package! kcl-ts-mode
  :when (modulep! :tools tree-sitter)
  :mode "\\.k\\'"
  :config
  (map! :localleader
        :map kcl-ts-mode-map
        :desc "Run buffer"    "r" #'kcl-run-buffer
        :desc "Format buffer" "f" #'kcl-format-buffer))

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

| Key       | Action                |
|-----------|-----------------------|
| `SPC m r` | Run file (`kcl run`)  |
| `SPC m f` | Format (`kcl fmt`)    |
| `SPC c d` | Go to definition      |
| `SPC c D` | Find references       |
| `SPC c a` | Code action           |
| `SPC c r` | Rename symbol         |
| `SPC c f` | Format (via LSP)      |
| `SPC c k` | Documentation lookup  |
| `SPC c x` | List diagnostics      |

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

| Key       | Command              | Description                      |
|-----------|----------------------|----------------------------------|
| `C-c C-r` | `kcl-run-buffer`     | Run the current file with `kcl`  |
| `C-c C-f` | `kcl-format-buffer`  | Format the current file          |

### Evil (Doom Emacs)

See the [Doom Emacs](#doom-emacs) section for `SPC m` localleader bindings.
LSP actions (`SPC c d`, `SPC c r`, etc.) work automatically when LSP is enabled.

## Customization

| Variable                    | Default                        | Description                               |
|-----------------------------|--------------------------------|-------------------------------------------|
| `kcl-indent-offset`        | `4`                            | Number of spaces per indentation level    |
| `kcl-command`              | `"kcl"`                        | Path to the `kcl` CLI binary              |
| `kcl-format-on-save`       | `nil`                          | Format buffer before saving               |
| `kcl-lsp-server-command`   | `("kcl-language-server")`      | lsp-mode server command                   |
| `kcl-lsp-auto-start`       | `nil`                          | Auto-start lsp-mode in KCL buffers        |
| `kcl-eglot-server-command` | `("kcl-language-server")`      | eglot server command                      |

## Running Tests

```sh
# Run all tests (requires kcl CLI and tree-sitter grammar)
./test/run-tests.sh

# Run specific test files
emacs --batch -L . -l test/test-fontlock.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l test/test-ts-mode.el -f ert-run-tests-batch-and-exit
emacs --batch -L . -l test/test-lsp.el -f ert-run-tests-batch-and-exit

# Run live LSP tests (requires kcl-language-server)
KCL_LANGUAGE_SERVER=/path/to/kcl-language-server \
  emacs --batch -L . -l test/test-lsp.el -f ert-run-tests-batch-and-exit
```

## License

Apache-2.0. See [SPDX headers](https://spdx.org/licenses/Apache-2.0.html) in source files.
