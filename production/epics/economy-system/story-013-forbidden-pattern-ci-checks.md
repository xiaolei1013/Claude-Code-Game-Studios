# Story 013: 4 forbidden-pattern CI grep checks for Economy

> **Epic**: economy-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §C (positive contracts) + `docs/architecture/control-manifest.md` §Core Layer Rules (Forbidden Patterns)
**Requirements**: ADR-0013 forbidden-pattern enforcement; cross-cutting with ADR-0014's 5 additional offline-replay forbidden patterns
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` and the control manifest.)*

**Governing ADR(s)**: ADR-0013 (4 new CI-enforced forbidden patterns) + ADR-0014 (5 additional)
**ADR Decision Summary**: CI must grep-enforce 4 ADR-0013 forbidden patterns + 5 ADR-0014 forbidden patterns. Violations fail the build.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI infrastructure landed in Sprint 1; this story extends `.github/workflows/tests.yml` with grep-based pattern guards.

**Control Manifest Rules (Core Layer, Economy)**:
- **Forbidden** (ADR-0013): `hardcoded_balance_value_outside_economy_config`, `economy_reads_losing_run_state`, `economy_signal_emission_during_offline_replay`, `try_spend_with_non_positive_amount`
- **Forbidden** (ADR-0014): `offline_replay_progressed_domain_subscriber`, `heroinstance_cache_outside_runsnapshot_allowlist`, `offline_summary_field_set_expansion_without_version_bump`, `per_chunk_domain_signal_emission_during_offline_replay`, `worker_thread_pool_for_offline_replay_in_mvp`

---

## Acceptance Criteria

- [ ] CI workflow includes a grep-based check that fails if any of the 9 forbidden patterns are found in `src/`
- [ ] **Pattern 1 — `hardcoded_balance_value_outside_economy_config`**: grep for known balance constant names (`BASE_DRIP`, `BASE_KILL`, `BASE_RECRUIT`, `BASE_LEVEL`, `FLOOR_CLEAR_BONUS`, `RECRUIT_RATIO`, `LEVEL_RATIO`, `MATCHUP_GOLD_MULTIPLIER`, `MATCHUP_DRIP_BONUS`, `LEVEL_CAP`, `LOSING_RUN_LOOT_FACTOR`) appearing as `var ... = ...` declarations or numeric-literal initializers in any `.gd` file under `src/` outside `src/core/economy/economy_config.gd`. Allowlist: `economy.gd` may reference these symbols via `EconomyConfig.BASE_DRIP[...]` (read-only access is fine).
- [ ] **Pattern 2 — `economy_reads_losing_run_state`**: grep for `losing_run`, `survived`, `hp_bonus_factor` token usage inside `src/core/economy/`; any match fails the check
- [ ] **Pattern 3 — `economy_signal_emission_during_offline_replay`**: grep for `gold_changed.emit` OR `first_clear_awarded.emit` not preceded (within 5 lines) by `if not _is_offline_replay`; surfaces as a manual-review request rather than a hard fail (heuristic) — OR encode as a unit test asserting zero emissions during `compute_offline_batch`
- [ ] **Pattern 4 — `try_spend_with_non_positive_amount`**: grep for `try_spend(0,` literal or `try_spend(-` literal in `src/`; fails on direct call sites with literal non-positive amounts (defensive code in `try_spend` itself is allowlisted)
- [ ] **Patterns 5–9 (ADR-0014)**: each implemented as a separate grep rule; documented in `tools/ci/forbidden_patterns.sh` (or equivalent)
- [ ] All 9 patterns have at least one positive-test fixture (a deliberately-violating snippet in `tests/ci/forbidden_pattern_fixtures/` that the grep MUST flag)
- [ ] CI integration: failure of any pattern grep produces a clear error message in the GitHub Actions log
- [ ] Documentation: each pattern's rationale and example violation listed in `tools/ci/README.md` or `tools/ci/forbidden_patterns.md`

---

## Implementation Notes

*Derived from ADR-0013 §New Forbidden Patterns + ADR-0014 §Forbidden Patterns:*

- Implement as a shell script `tools/ci/forbidden_patterns.sh` invoked by `.github/workflows/tests.yml` after the unit-test step
- Use `grep -RnE 'pattern' src/` with appropriate regex per rule. Exit non-zero on any match. Print path:line:matched-text for diagnostics.
- Allowlist mechanism: allow a literal comment-marker `# ALLOW: forbidden_pattern_name` on the offending line to suppress that single occurrence. Document the marker in the README.
- Pattern 3 (signal-during-replay) is the trickiest because it requires line-context awareness. Two implementation paths:
  - **Path A (recommended)**: encode as a runtime test in Story 010 — verify zero emissions during `compute_offline_batch`. Skip the static check, since the runtime test catches all paths definitively.
  - **Path B**: write a small AST/regex helper that flags emission calls without an `if not _is_offline_replay` guard within 5 preceding lines. Complex; skip for MVP.
- Pattern 4 needs care: the defensive `push_error` inside `try_spend` MUST not be flagged. Use a path-scoped allowlist for `src/core/economy/economy.gd:func try_spend`.
- Run the pattern checks BEFORE the slow integration tests so violations fail fast.

---

## Out of Scope

- Implementing the violations themselves (no new game code in this story)
- Pattern 3 dynamic enforcement (lives in Story 010's test file)
- Patterns from other epics (Foundation patterns already enforced in Sprint 1; Feature/Presentation patterns deferred to their epics)

---

## QA Test Cases

- **AC: each pattern has a positive-test fixture that grep flags**
  - **Given**: 9 fixture files in `tests/ci/forbidden_pattern_fixtures/`, each containing a deliberate violation of one pattern
  - **When**: `tools/ci/forbidden_patterns.sh` runs against the fixture directory
  - **Then**: each fixture produces exactly one match and the script exits non-zero
  - **Edge cases**: a fixture with multiple violations of the same pattern produces multiple match lines; allowlist comment suppresses correctly

- **AC: clean source tree passes**
  - **Given**: current `src/` (post-Sprint 1) without any forbidden patterns
  - **When**: `tools/ci/forbidden_patterns.sh` runs
  - **Then**: zero matches; exit code 0; CI proceeds
  - **Edge cases**: regex must not produce false positives on legitimate uses of the same identifiers

- **AC: GitHub Actions integration**
  - **Given**: a PR introduces a violation
  - **When**: PR CI runs
  - **Then**: workflow fails with a clear log line pointing to the file:line and pattern name
  - **Edge cases**: the failure message includes the rationale ("ADR-0013 §New Forbidden Patterns: ...") so the contributor can fix without lookups

- **AC: allowlist comment works**
  - **Given**: a fixture line with `# ALLOW: hardcoded_balance_value_outside_economy_config`
  - **When**: grep runs
  - **Then**: that line is not counted as a match; otherwise-matching lines without the allowlist marker still match
  - **Edge cases**: misspelled allowlist tokens MUST NOT silently allow; document the canonical token format

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tools/ci/forbidden_patterns.sh` exists and is executable
- `tests/ci/forbidden_pattern_fixtures/` directory with 9 fixtures
- `tools/ci/README.md` (or `forbidden_patterns.md`) with pattern rationale + example violation per pattern
- A passing CI run on the current `main` branch demonstrating zero false positives
- Smoke check pass at `production/qa/smoke-*.md`

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Sprint 1's `.github/workflows/tests.yml` infrastructure
- **Unlocks**: Pre-Production gate (forbidden-pattern enforcement is a control-manifest commitment)
