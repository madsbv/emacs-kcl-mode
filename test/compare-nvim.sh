#!/usr/bin/env bash
# Cross-validate kcl-mode font-lock against the neovim kcl.nvim syntax plugin.
#
# This script:
# 1. Uses nvim --headless to extract syntax group for each token in a .k file
# 2. Uses emacs --batch to extract font-lock face for each token
# 3. Maps nvim syntax groups to expected emacs faces and compares
#
# Usage: ./test/compare-nvim.sh [file.k]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# Required: path to a kcl.nvim checkout (the syntax plugin being compared against).
NVIM_PLUGIN_DIR="${KCL_NVIM_PLUGIN_DIR:-}"
if [ -z "$NVIM_PLUGIN_DIR" ] || [ ! -d "$NVIM_PLUGIN_DIR" ]; then
  echo "Set KCL_NVIM_PLUGIN_DIR to a kcl.nvim checkout" >&2
  exit 1
fi
TEST_FILE="${1:-$SCRIPT_DIR/sample.k}"

echo "=== Cross-validation: Emacs kcl-mode vs Neovim kcl.nvim ==="
echo "Test file: $TEST_FILE"
echo ""

# --- Step 1: Extract Neovim syntax groups ---
echo "--- Extracting Neovim syntax groups ---"
NVIM_OUTPUT=$(mktemp /tmp/kcl-nvim-XXXXXX.txt)

nvim --headless --clean \
	--cmd "set runtimepath+=$NVIM_PLUGIN_DIR" \
	-c "edit $TEST_FILE" \
	-c "set filetype=kcl" \
	-c "syntax on" \
	-c "lua vim.defer_fn(function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local output = {}
    for lnum, line in ipairs(lines) do
      for col = 1, #line do
        local syn_id = vim.fn.synID(lnum, col, true)
        local syn_name = vim.fn.synIDattr(syn_id, 'name')
        local trans_id = vim.fn.synIDtrans(syn_id)
        local trans_name = vim.fn.synIDattr(trans_id, 'name')
        if syn_name ~= '' then
          table.insert(output, string.format('%d\t%d\t%s\t%s', lnum, col, syn_name, trans_name))
        end
      end
    end
    local f = io.open('$NVIM_OUTPUT', 'w')
    f:write(table.concat(output, '\n'))
    f:close()
    vim.cmd('qa!')
  end, 100)" 2>/dev/null

echo "Neovim output: $(wc -l <"$NVIM_OUTPUT") syntax entries"

# --- Step 2: Extract Emacs font-lock faces ---
echo "--- Extracting Emacs font-lock faces ---"
EMACS_OUTPUT=$(mktemp /tmp/kcl-emacs-XXXXXX.txt)

emacs --batch \
	-L "$PROJECT_DIR" \
	-l kcl-mode \
	--eval "
(progn
  (find-file \"$TEST_FILE\")
  (font-lock-ensure)
  (let ((result (list)))
    (goto-char (point-min))
    (let ((lnum 1) (col 1))
      (while (not (eobp))
        (let ((face (get-text-property (point) (quote face)))
              (ch (char-after)))
          (when (and face ch (not (eq ch 10)))
            (push (format \"%d\t%d\t%s\" lnum col
                         (if (symbolp face) (symbol-name face)
                           (symbol-name (car face))))
                  result)))
        (if (eq (char-after) 10)
            (progn (setq lnum (1+ lnum)) (setq col 1))
          (setq col (1+ col)))
        (forward-char 1)))
    (with-temp-file \"$EMACS_OUTPUT\"
      (insert (mapconcat (quote identity) (nreverse result) \"\n\")))))" 2>/dev/null

echo "Emacs output: $(wc -l <"$EMACS_OUTPUT") face entries"

# --- Step 3: Compare ---
echo ""
echo "--- Comparison ---"

# Mapping from nvim syntax groups (trans name) to expected emacs faces
declare -A NVIM_TO_EMACS
NVIM_TO_EMACS[Comment]=font-lock-comment-face
NVIM_TO_EMACS[String]=font-lock-string-face
NVIM_TO_EMACS[Number]=font-lock-constant-face
NVIM_TO_EMACS[Conditional]=font-lock-keyword-face
NVIM_TO_EMACS[Repeat]=font-lock-keyword-face
NVIM_TO_EMACS[Operator]=font-lock-keyword-face
NVIM_TO_EMACS[Boolean]=font-lock-constant-face
NVIM_TO_EMACS[Include]=font-lock-keyword-face
NVIM_TO_EMACS[Function]=font-lock-builtin-face
NVIM_TO_EMACS[Noise]=_skip_
NVIM_TO_EMACS[Delimiter]=_skip_

# Build lookup tables
declare -A NVIM_MAP
while IFS=$'\t' read -r line col syn_name trans_name; do
	[ -z "$line" ] && continue
	NVIM_MAP["$line:$col"]="$trans_name"
done <"$NVIM_OUTPUT"

declare -A EMACS_MAP
while IFS=$'\t' read -r line col face; do
	[ -z "$line" ] && continue
	EMACS_MAP["$line:$col"]="$face"
done <"$EMACS_OUTPUT"

# Compare
TOTAL=0
AGREE=0
DISAGREE=0
NVIM_ONLY=0
EMACS_ONLY=0
UNMAPPED=0

declare -A ALL_POSITIONS
for key in "${!NVIM_MAP[@]}" "${!EMACS_MAP[@]}"; do
	ALL_POSITIONS["$key"]=1
done

DISAGREE_LINES=""

for key in $(echo "${!ALL_POSITIONS[@]}" | tr ' ' '\n' | sort -t: -k1,1n -k2,2n); do
	nvim_group="${NVIM_MAP[$key]:-}"
	emacs_face="${EMACS_MAP[$key]:-}"

	((TOTAL++)) || true

	if [ -n "$nvim_group" ] && [ -z "$emacs_face" ]; then
		expected="${NVIM_TO_EMACS[$nvim_group]:-UNMAPPED}"
		if [ "$expected" != "_skip_" ] && [ "$expected" != "UNMAPPED" ] && [ -n "$expected" ]; then
			((NVIM_ONLY++)) || true
		fi
	elif [ -z "$nvim_group" ] && [ -n "$emacs_face" ]; then
		((EMACS_ONLY++)) || true
	elif [ -n "$nvim_group" ] && [ -n "$emacs_face" ]; then
		expected="${NVIM_TO_EMACS[$nvim_group]:-UNMAPPED}"
		if [ "$expected" = "UNMAPPED" ]; then
			((UNMAPPED++)) || true
		elif [ "$expected" = "_skip_" ]; then
			# Skip noise/delimiter groups
			true
		elif [ "$expected" = "$emacs_face" ]; then
			((AGREE++)) || true
		elif [[ "$emacs_face" == *comment* ]] && [[ "$expected" == *comment* ]]; then
			((AGREE++)) || true
		else
			((DISAGREE++)) || true
			DISAGREE_LINES="${DISAGREE_LINES}  L${key}: nvim=${nvim_group}(expect=${expected}) emacs=${emacs_face}\n"
		fi
	fi
done

echo "Total positions compared: $TOTAL"
echo "Agree (same category):    $AGREE"
echo "Disagree:                 $DISAGREE"
echo "Nvim-only highlighting:   $NVIM_ONLY"
echo "Emacs-only highlighting:  $EMACS_ONLY"
echo "Unmapped nvim groups:     $UNMAPPED"

if [ "$DISAGREE" -gt 0 ]; then
	echo ""
	echo "Disagreements (first 30):"
	echo -e "$DISAGREE_LINES" | head -30
fi

COMPARABLE=$((AGREE + DISAGREE))
if [ "$COMPARABLE" -gt 0 ]; then
	PCT=$((AGREE * 100 / COMPARABLE))
	echo ""
	echo "Agreement rate: ${PCT}% ($AGREE/$COMPARABLE comparable positions)"
	if [ "$PCT" -ge 90 ]; then
		echo "RESULT: PASS (>= 90% agreement)"
	else
		echo "RESULT: NEEDS REVIEW (< 90% agreement)"
	fi
else
	echo ""
	echo "No comparable positions found."
fi

# Cleanup
rm -f "$NVIM_OUTPUT" "$EMACS_OUTPUT"
