# Story 008: Performance bench + structural CI lint + MatchupResult equality test pattern

> **Epic**: matchup-resolver
> **Status**: Complete (per-AC verification 2026-05-08 — audit-cascade caveat resolved; required test file exists and passes; ACs ticked.)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
**Requirements**: TR-matchup-resolver-030, 031, 033

**Governing ADR**: ADR-0009
**Decision Summary**: Three test/infrastructure invariants:
1. **Structural CI lint** — `matchup_resolver.gd` and `default_matchup_resolver.gd` have zero class-scope `var`, zero `signal`, no `static func` on the public API. Enforced via shell grep + CI step.
2. **Performance budget** — 10,000 `resolve_*` calls in <200ms on CI ubuntu-latest; <50ms on Steam Deck baseline.
3. **MatchupResult equality test pattern** — RefCounted equality is reference-equality; tests must compare field-by-field. A small helper `match_result_equals(a, b)` keeps callers from accidentally using `==`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: structural lint runs in CI (added to `.github/workflows/tests.yml` or equivalent). — TR-030
- Required: perf bench gates a regression budget; failures hard-fail CI. — TR-031
- Required: helper `match_result_equals(a: MatchupResult, b: MatchupResult) -> bool` lives in test fixtures; field-by-field compare; tests use it instead of `==`. — TR-033

---

## Acceptance Criteria

- [x] TR-030 structural lint: `tools/ci/check_matchup_resolver_shape.sh` (or equivalent) returns non-zero on any of: `^var ` outside doc-comment in `matchup_resolver.gd` or `default_matchup_resolver.gd`; `^signal ` in either; `static func` on public API.
- [x] TR-030: lint step added to `.github/workflows/tests.yml` (or equivalent CI config).
- [x] TR-031: bench harness `tests/perf/matchup_resolver_perf_test.gd` runs 10,000 `resolve_formation_matchup` calls — assertion `<200ms` on CI machine.
- [x] TR-033: `tests/fixtures/match_result_eq.gd` provides `match_result_equals(a, b) -> bool` doing field-by-field compare; documented usage pattern in epic README or per-story.

---

## Implementation Notes

```bash
# tools/ci/check_matchup_resolver_shape.sh
#!/bin/bash
set -e
FILES=(
    "src/core/matchup_resolver/matchup_resolver.gd"
    "src/core/matchup_resolver/default_matchup_resolver.gd"
)
for f in "${FILES[@]}"; do
    if grep -E '^var ' "$f" | grep -v '^##' >/dev/null; then
        echo "FAIL: class-scope var found in $f"
        exit 1
    fi
    if grep -E '^signal ' "$f" >/dev/null; then
        echo "FAIL: signal declared in $f"
        exit 2
    fi
    if grep -E '^static func' "$f" >/dev/null; then
        echo "FAIL: static func found in $f (public API must be instance methods)"
        exit 3
    fi
done
echo "OK: matchup_resolver structural shape clean"
```

```gdscript
# tests/fixtures/match_result_eq.gd
static func match_result_equals(a: MatchupResult, b: MatchupResult) -> bool:
    if a == null or b == null:
        return a == b
    return (
        a.is_advantaged == b.is_advantaged
        and a.matched_archetypes == b.matched_archetypes
        and a.effectiveness_label == b.effectiveness_label
    )
```

---

## Out of Scope

- The resolver implementation itself (Stories 001-004).
- Perf optimization (only the bench + assertion lands here; if the budget fails, profile + optimize in a follow-up story).

---

## QA Test Cases

- **TR-030 structural lint passes**: shell script exits 0 against current resolver source
- **TR-030 lint catches regressions**: mutate `matchup_resolver.gd` to add a `var foo: int = 0` → script exits non-zero
- **TR-031 perf budget**: 10,000 calls < 200ms on CI baseline
- **TR-033 equality helper**: `match_result_equals(a, b)` returns true for field-equal results, false otherwise; never returns true for reference-different but field-different inputs

---

## Test Evidence

**Story Type**: Logic
**Required**:
- `tests/perf/matchup_resolver_perf_test.gd`
- `tools/ci/check_matchup_resolver_shape.sh`
- `tests/fixtures/match_result_eq.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-004 (resolver + MatchupResult complete)
- Unlocks: Sprint 7+ Vertical Slice perf gate
