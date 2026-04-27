#!/usr/bin/env bash
# check_matchup_resolver_shape.sh — CI guard for the matchup-resolver epic's
# structural invariants (Sprint 8 S8-N3 / TR-matchup-resolver-030).
#
# The MatchupResolver + DefaultMatchupResolver source files MUST remain:
#   1. Stateless — zero class-scope `var` declarations
#   2. Signal-free — zero `signal` declarations
#   3. Instance-method only — no `static func` on the public API surface
#
# Background: ADR-0009's stateless-DI contract requires resolvers to be pure
# functions of their inputs. Class-scope vars introduce hidden state that
# breaks determinism (TR-matchup-resolver-021 / Pillar 1 offline-replay
# parity); signals couple the resolver to a specific consumer (the orchestrator
# is supposed to own all matchup-related signals); static funcs prevent
# spy-subclass injection (TR-matchup-resolver-032).
#
# Usage:
#   bash tools/ci/check_matchup_resolver_shape.sh
#
# Exit codes:
#   0 — both files pass all 3 invariants
#   1 — class-scope var detected
#   2 — signal declaration detected
#   3 — static func detected on public API
#
# Notes:
#   - Comment lines (^# or ^##) are excluded so doc-comment text mentioning
#     "var" or "signal" as English words doesn't trigger a false positive.
#   - Inline trailing comments are NOT stripped — code lines with trailing
#     comments are treated as code (which they are).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FILES=(
    "${REPO_ROOT}/src/core/matchup_resolver/matchup_resolver.gd"
    "${REPO_ROOT}/src/core/matchup_resolver/default_matchup_resolver.gd"
)

EXIT_CODE=0

for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "FAIL: source file missing: ${f#"$REPO_ROOT/"}"
        EXIT_CODE=1
        continue
    fi

    # Strip comment-only lines (^# or ^##) before pattern checking. Awk pass
    # leaves us with code-only content piped to grep.
    CODE_LINES=$(awk '!/^[[:space:]]*#/' "$f")

    # Invariant 1: zero class-scope `var` declarations.
    # Pattern: line starts with optional whitespace then `var ` (note trailing
    # space — guards against catching "variable" or "varied" mid-token).
    if echo "$CODE_LINES" | grep -qE '^var'; then
        echo "FAIL: class-scope var found in ${f#"$REPO_ROOT/"}"
        echo "$CODE_LINES" | grep -nE '^var' | head -3
        EXIT_CODE=1
    fi

    # Invariant 2: zero `signal` declarations.
    if echo "$CODE_LINES" | grep -qE '^signal'; then
        echo "FAIL: signal declaration found in ${f#"$REPO_ROOT/"}"
        echo "$CODE_LINES" | grep -nE '^signal' | head -3
        EXIT_CODE=2
    fi

    # Invariant 3: no `static func` on the public API.
    # Static funcs are valid in Godot but break the spy-subclass override
    # pattern this resolver relies on for testability.
    if echo "$CODE_LINES" | grep -qE '^static func'; then
        echo "FAIL: static func declaration found in ${f#"$REPO_ROOT/"}"
        echo "$CODE_LINES" | grep -nE '^static func' | head -3
        EXIT_CODE=3
    fi
done

if [[ "$EXIT_CODE" -eq 0 ]]; then
    echo "OK: matchup_resolver structural shape clean (${#FILES[@]} files checked)"
fi

exit "$EXIT_CODE"
