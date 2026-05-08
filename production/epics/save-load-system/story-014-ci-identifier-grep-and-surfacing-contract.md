# Story 014: CI identifier-substring grep + production-build surfacing contract

> **Epic**: save-load-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #3. Test evidence: `tests/{unit,integration}/save_load/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §G Tuning Knobs (integrity_check_enabled + save_file_path + SETTINGS_MODIFIED_LABEL_ENABLED) + AC-SL-TAMPER-05
**Requirements**: TR-save-load-050, TR-save-load-051, TR-save-load-052, TR-save-load-053, TR-save-load-054
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — identifier hygiene + compile-time const discipline + Rule 14 CI grep), AC-SL-TAMPER-05 (BLOCKING)
**ADR Decision Summary**: No identifier in SaveLoadSystem or any multi-part HMAC fragment autoload may contain the substrings "key", "secret", or "hmac" (CI grep enforced). `integrity_check_enabled` MUST be compile-time GDScript `const` (NOT ProjectSetting — defeated by `user://overrides.cfg`). `save_file_path` must be empty in production exports. Debug-only fixture helpers (`debug_pause_before_rename`, `corrupt_byte_at_offset`, `replace_save_with`, `arm_pause_before_rename`) MUST NOT be exposed in production. Runtime guards use `push_error + get_tree().quit(1)` (NOT `assert()` — stripped from release).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (CI enforcement is a build-pipeline concern; failures are build-time, not runtime — but a missed check ships a vulnerable build)
**Engine Notes**: Compile-time `const` values emit into bytecode; `user://overrides.cfg` can override `ProjectSettings` but NOT `const`. `assert()` is stripped from GDScript release exports — runtime guards must use `push_error + quit(1)` pattern (Pass-5B-emergency 2026-04-21).

**Control Manifest Rules (Foundation Layer, CI surfacing)**:
- **Required**: `integrity_check_enabled` MUST be compile-time GDScript `const` (NOT ProjectSetting) to prevent override.cfg bypass. Runtime guards use `push_error + get_tree().quit(1)` pattern, NOT `assert()` (stripped from release exports). `save_file_path` knob is debug-only; production builds enforce empty at `_ready()` via `quit(1)`. Debug-only fixture helpers (`SaveSystem.debug_pause_before_rename`, `SaveLoadFixture.corrupt_byte_at_offset`, `replace_save_with`, `arm_pause_before_rename`) runtime-gated by `OS.is_debug_build()`. CI build-step (AC-SL-TAMPER-05) fails build if `integrity_check_enabled` not `const true`, `save_file_path` exposed, or `override.cfg` packaged.
- **Forbidden**: Identifier substrings "key", "secret", or "hmac" in SaveLoad/HMAC code paths (abstraction leak to decompiler attackers). Exposing `integrity_check_enabled` as ProjectSetting. Packaging `override.cfg` in production exports.

---

## Acceptance Criteria

*Scoped to this story (per AC-SL-TAMPER-05 BLOCKING):*

- [ ] CI script `tools/ci/save_load_identifier_scan.sh` (or equivalent invoked from `.github/workflows/` or local `scons` hook) performs the following static grep on:
  - `src/core/save_load_system.gd`
  - Each of the 3-4 HMAC fragment autoloads (e.g., `src/core/boot_namespace.gd`, `src/core/engine_bootstrap.gd`, `src/core/runtime_locale_guard.gd`)
  - Any file matching `src/**/hmac_*.gd` or `tests/**/hmac_*.gd` (wrapper + tests)
- [ ] Grep pattern (case-insensitive, identifier context only): `(?i)\b(_?\w*)(key|secret|hmac)(\w*)\b` restricted to identifier positions (var, const, func, signal declarations). Hits in comments and string literals are allowed (the wrapper's param names `key` and `msg` are OK inside the HMAC function body scope per ADR-0004 — but the top-level SaveLoadSystem variables referencing the wrapper output MUST use non-suggestive names like `_integrity_tag` / `_derived_tags`)
- [ ] CI fails the build on any hit in the enforced file set
- [ ] `integrity_check_enabled` is declared as `const integrity_check_enabled: bool = true` in SaveLoadSystem (NOT a ProjectSetting custom key); CI scan greps `ProjectSettings.get_setting("save_load/integrity_check_enabled")` across the codebase — zero hits
- [ ] `save_file_path` is a private `var _save_file_path: String = ""` with a debug-only static setter; CI scan verifies production-build `_ready()` contains the enforcement pattern `if not OS.is_debug_build() and _save_file_path != "": push_error(...); get_tree().quit(1)`
- [ ] Debug-fixture helper surface-test: production build export (or a test harness simulating it) verifies that `SaveSystem.debug_pause_before_rename`, `SaveLoadFixture.corrupt_byte_at_offset`, `replace_save_with`, `arm_pause_before_rename` are NOT callable (their bodies short-circuit on `OS.is_debug_build() == false`)
- [ ] `override.cfg` presence check: CI verifies the exported PCK does NOT contain `user://overrides.cfg` as a packaged resource
- [ ] `SETTINGS_MODIFIED_LABEL_ENABLED` is compile-time `const` (not ProjectSetting); CI greps for any occurrence of `SETTINGS_MODIFIED_LABEL_ENABLED = true` in production exports — fails the build unless a V1.0 consequence-feature explicitly lands it
- [ ] Runtime-guard pattern scan: any use of `assert(` in SaveLoadSystem production code paths fails the build (assert is stripped in release — must use `push_error + quit(1)` per TR-save-load-051)

---

## Implementation Notes

- Scan script shape (POSIX-portable, invoked by CI):
  ```sh
  #!/usr/bin/env bash
  set -euo pipefail
  FILES=(
    "src/core/save_load_system.gd"
    "src/core/boot_namespace.gd"
    "src/core/engine_bootstrap.gd"
    "src/core/runtime_locale_guard.gd"
  )
  FAIL=0
  for f in "${FILES[@]}"; do
      # Identifier-only grep — excludes comments (lines starting with `#`) and string literals (rough heuristic)
      if grep -nE '^[^#"]*\b(var|const|func|signal)[[:space:]]+[_[:alnum:]]*(key|secret|hmac)[_[:alnum:]]*' "$f"; then
          echo "FAIL: suggestive identifier in $f"
          FAIL=1
      fi
  done
  exit $FAIL
  ```
  (Production version should use a proper GDScript AST parser for accuracy; the regex above is the MVP quickcheck)
- Nuance: the HMAC function body (ADR-0004 reference structure) uses parameter names `key` and `msg`. That's acceptable per RFC convention BUT only in the wrapper's private scope. Any export-level or top-level `var` or `const` with "key" in the name fails.
  - Allowed: `func _integrity_wrap(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray` (params scoped to function)
  - Forbidden: `const _HMAC_KEY := ...` or `var _integrity_key: PackedByteArray`
  - Preferred: `func _derive_keys()` returns an array referenced as `_derived_tags` or similar non-suggestive name in the top-level scope. Actually — `_derive_keys()` itself contains "keys" — per ADR-0004 example this is borderline. Rename to `_derive_integrity_tags()` for strictness.
- `user://overrides.cfg` attack surface: Godot 4.5+ applies `user://overrides.cfg` to ProjectSettings before any autoload `_ready()` runs. An attacker writing `save_load/integrity_check_enabled = false` to their overrides file could flip the flag IF it were a ProjectSetting. Compile-time `const` values are baked into the script bytecode and immune.
- `assert()` stripping: confirmed Pass-5B-emergency 2026-04-21. GDScript `assert(expr, msg)` compiles to nothing in release exports. Runtime guards must use:
  ```gdscript
  if not OS.is_debug_build() and not integrity_check_enabled:
      push_error("[SaveLoad] FATAL: integrity_check_enabled is false in production build — halting")
      get_tree().quit(1)
      return
  ```
- CI integration: likely ran via `.github/workflows/ci.yml` job `save-load-surfacing-check` that runs BEFORE any `gdunit4` test suite. Fail the job → fail the PR.

---

## Out of Scope

- Story 015: runtime performance verification (unrelated scan concern)
- The content of the HMAC / envelope / key logic itself (covered by Stories 002-006)

---

## QA Test Cases

- **TR-save-load-054 / AC-SL-TAMPER-05**: Identifier-substring grep (local)
  - **Given**: Current working source tree
  - **When**: Grep pattern runs against enforced file set
  - **Then**: Zero hits on "key", "secret", "hmac" in var/const/func/signal declarations (parameters inside function bodies excepted per scoping rule)
  - **Edge cases**: Inserting `const _HMAC_KEY := [...]` into `save_load_system.gd` MUST fail the CI job; comments like `# Compute the HMAC tag here` are allowed

- **TR-save-load-050**: `integrity_check_enabled` is compile-time const
  - **Given**: SaveLoadSystem source + a malicious `user://overrides.cfg` with `[save_load] integrity_check_enabled=false`
  - **When**: Production build boots
  - **Then**: `integrity_check_enabled` remains `true` (const is baked into bytecode); HMAC verification runs normally
  - **Edge cases**: Grep `ProjectSettings.get_setting("save_load/integrity_check_enabled")` across codebase returns zero hits

- **TR-save-load-052**: `save_file_path` empty enforcement in production
  - **Given**: Production build with `_save_file_path = "user://cheat_slot.dat"` injected via a hypothetical attack
  - **When**: SaveLoadSystem `_ready()` runs
  - **Then**: `push_error` emitted; `get_tree().quit(1)` fires (process exits with code 1)
  - **Edge cases**: Debug builds allow non-empty `_save_file_path` (enables GdUnit4 test isolation per AC-FU-13/14)

- **TR-save-load-053**: Debug-fixture helpers absent in production
  - **Given**: Production build
  - **When**: Test harness calls `SaveLoadFixture.corrupt_byte_at_offset(...)` or `SaveSystem.debug_pause_before_rename`
  - **Then**: Function body short-circuits on `if not OS.is_debug_build(): return`; no effect
  - **Edge cases**: Grep for `debug_pause_before_rename` outside `OS.is_debug_build()` guards MUST fail CI

- **TR-save-load-054 (AC-SL-TAMPER-05 BLOCKING)**: Exported PCK does not contain override.cfg
  - **Given**: Production build pipeline
  - **When**: CI extracts the exported PCK and scans for `overrides.cfg`
  - **Then**: Zero hits; build fails if the file is packaged
  - **Edge cases**: `user://overrides.cfg` is a runtime-user file by convention, not a packaged asset — this check defends against accidental packaging

- **TR-save-load-026 / Pass-5E (MVP compile-time const)**
  - **Given**: Production build source
  - **When**: CI greps `SETTINGS_MODIFIED_LABEL_ENABLED = true`
  - **Then**: Zero hits in production exports (MVP); V1.0 feature flag would require an explicit ADR amendment
  - **Edge cases**: The on-disk FLAGS.bit0 state still persists; only the UI gate is affected

- **TR-save-load-051**: No `assert()` in SaveLoadSystem production paths
  - **Given**: `src/core/save_load_system.gd` + HMAC fragment autoloads
  - **When**: CI greps `^[^#]*\bassert\(`
  - **Then**: Zero hits in release-bound files; test files in `tests/` are allowed (assertion framework)
  - **Edge cases**: Debug-build-only guards using `if OS.is_debug_build(): assert(...)` are technically allowed but discouraged; prefer `push_error`

- **AC-SL-TAMPER-05 (BLOCKING gates Pass-5B-emergency regression)**
  - **Given**: CI pipeline configured
  - **When**: Any commit lands that violates these contracts
  - **Then**: Build fails; PR cannot merge; regression detected before ship
  - **Edge cases**: The BLOCKING designation is non-negotiable — this AC's pass is a prerequisite for Foundation layer being considered complete

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tools/ci/save_load_identifier_scan.sh` (or equivalent) exists and runs in CI
- `tests/integration/save_load/surfacing_contract_test.gd` — must exist and pass (runtime-side contracts: const, quit-guard, debug helper short-circuit)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Stories 001-013 (files to scan must exist with correct identifier discipline from the start)
- **Unlocks**: Ship-readiness; AC-SL-TAMPER-05 BLOCKING pass
