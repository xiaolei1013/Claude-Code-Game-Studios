#!/usr/bin/env bash
# check_screen_hooks.sh — CI guard: every `extends Screen` file must declare all
# four lifecycle hooks (on_enter, on_exit, on_pause, on_resume).
#
# Usage:
#   bash tools/ci/check_screen_hooks.sh
#
# Exit codes:
#   0 — all screen scripts pass
#   1 — one or more scripts are missing hook declarations
#
# Search strategy:
#   1. Collect every .gd file under assets/screens/ and src/ that contains the
#      literal string "extends Screen".
#   2. Exclude the base class file itself (screen.gd extends Control, not Screen).
#   3. Exclude tests/fixtures/ (fixture files use .fixture suffix anyway, but
#      double-check in case a .gd fixture slips through).
#   4. For each candidate file, verify all four hooks are declared at line-start
#      (^func hook_name\() — avoids false positives from comment lines that contain
#      the string "func on_resume(" mid-line).
#
# Requires: ripgrep (rg) if available; falls back to grep -rE.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BASE_CLASS="${REPO_ROOT}/src/core/scene_manager/screen.gd"
FIXTURES_DIR="${REPO_ROOT}/tests/fixtures"

HOOKS=("on_enter" "on_exit" "on_pause" "on_resume")

# ---------------------------------------------------------------------------
# Find all .gd files containing "extends Screen"
# ---------------------------------------------------------------------------
CANDIDATES=()
if command -v rg &>/dev/null; then
    # ripgrep: search for "extends Screen" in .gd files, output filenames only.
    # Exclude base class and fixtures directory.
    while IFS= read -r line; do
        [[ -n "$line" ]] && CANDIDATES+=("$line")
    done < <(
        rg --files-with-matches --glob "*.gd" \
            --glob "!${FIXTURES_DIR#"$REPO_ROOT/"}"'/**' \
            "extends Screen" \
            "${REPO_ROOT}/assets/screens" \
            "${REPO_ROOT}/src" \
            2>/dev/null || true
    )
else
    # grep fallback
    while IFS= read -r line; do
        [[ -n "$line" ]] && CANDIDATES+=("$line")
    done < <(
        # NOTE: --exclude-dir takes a bare directory NAME (glob), not an absolute
        # path; the FIXTURES_DIR full-path filter below catches anything that
        # slips through. "fixtures" is sufficient for our layout.
        grep -rlE "extends Screen" \
            --include="*.gd" \
            --exclude-dir="fixtures" \
            "${REPO_ROOT}/assets/screens" \
            "${REPO_ROOT}/src" \
            2>/dev/null || true
    )
fi

# Remove the base class from candidates (it `extends Control`, not Screen, but
# be defensive in case someone adds a stray "extends Screen" comment to it).
FILTERED=()
for f in "${CANDIDATES[@]}"; do
    if [[ "$f" == "$BASE_CLASS" ]]; then
        continue
    fi
    # Also skip anything inside tests/fixtures/
    if [[ "$f" == "${FIXTURES_DIR}"/* ]]; then
        continue
    fi
    FILTERED+=("$f")
done

if [[ "${#FILTERED[@]}" -eq 0 ]]; then
    echo "WARN: no 'extends Screen' files found under assets/screens/ or src/"
    echo "      (expected at least 7 placeholder screens)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Check each file for all four hook declarations
# ---------------------------------------------------------------------------
FAIL_COUNT=0

for file in "${FILTERED[@]}"; do
    MISSING=()
    for hook in "${HOOKS[@]}"; do
        # Anchor to line start (^) to avoid matching comment lines that contain
        # the hook name string mid-line.  Allow optional whitespace before "("
        # to handle both `func on_enter()` and `func on_enter ()` styles.
        if ! grep -qE "^func ${hook}[[:space:]]*\(" "$file"; then
            MISSING+=("$hook")
        fi
    done

    if [[ "${#MISSING[@]}" -gt 0 ]]; then
        IFS=", " joined="${MISSING[*]}"
        echo "FAIL: ${file#"$REPO_ROOT/"} missing hook(s): ${joined}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
TOTAL="${#FILTERED[@]}"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo ""
    echo "FAIL: ${FAIL_COUNT} of ${TOTAL} screen script(s) are missing required lifecycle hooks."
    exit 1
else
    echo "OK: ${TOTAL} screen script(s) checked, all hooks present."
    exit 0
fi
