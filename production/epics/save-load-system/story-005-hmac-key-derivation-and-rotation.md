# Story 005: HMAC key derivation — multi-part assembly + N=2 build-version rotation

> **Epic**: save-load-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-021, TR-save-load-022 (partial — rotation pairs with RFC 4231 wrapper)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — HMAC key derivation section + N=2 rotation + compile-time `const` discipline)
**ADR Decision Summary**: Multi-part assembly of 3-4 byte fragments scattered across non-SaveLoad autoloads under non-suggestive names, combined via `SHA256(PART_A XOR PART_B || PART_C || build_version_string)`. Fixed-length `keys` array, N=2: `keys[0]` = current build, `keys[1]` = prior build's key compiled into binary at build time. On `keys[1]` success during load, queue immediate re-persist under `keys[0]` so the save is re-signed forward.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (compile-time `const` discipline for build-version constants is a code-review gate, not engine-enforced; assert stripped from release means runtime-guard pattern must use push_error+quit)
**Engine Notes**: Compile-time `const` values emit into bytecode and cannot be overridden at runtime by `user://overrides.cfg` (distinguishing them from `ProjectSettings`). `HashingContext.HASH_SHA256` stable since 4.0.

**Control Manifest Rules (Foundation Layer, HMAC key derivation)**:
- **Required**: HMAC key derivation = multi-part assembly + N=2 build-version rotation: `SHA256(PART_A XOR PART_B || PART_C || build_version_string)`; parts in different autoload scripts under non-suggestive names. `keys` array is fixed length N=2: `keys[0]` = current build's key, `keys[1]` = prior build's key compiled into binary; on `keys[1]` success, queue immediate re-persist under `keys[0]`. STATIC_SECRET (XOR mask seeding) MUST NOT participate in HMAC key derivation.
- **Forbidden**: Identifier substrings "key", "secret", "hmac" in SaveLoadSystem or fragment autoloads (CI grep Story 014). Deriving HMAC key from `OS.get_unique_id()` (Alternative 2 rejected; legitimate-user UX bug on machine change). Generalizing N to a tuning knob (N=2 is authoritative). Reading the prior-version string from the save file (attacker-controllable) instead of from compile-time `const`.

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] 3-4 byte fragments (each 16-32 bytes) declared as compile-time `const` in non-SaveLoad autoloads (e.g., `BootNamespace`, `EngineBootstrap`, `RuntimeLocaleGuard`), each under a non-suggestive identifier (no "key"/"secret"/"hmac" substring)
- [ ] Build-pipeline authored constants: `CURRENT_BUILD_VERSION_STRING: String` (current release) and `PRIOR_BUILD_VERSION_STRING: String` (prior release), both compile-time `const`
- [ ] `_derive_keys() -> Array[PackedByteArray]` returns a fixed-length-2 array: `[current, prior]`, each 32 bytes
- [ ] Formula: `key_n = SHA256(PART_A XOR PART_B || PART_C || version_string_n)` where `version_string_0 = CURRENT_BUILD_VERSION_STRING` and `version_string_1 = PRIOR_BUILD_VERSION_STRING`
- [ ] `keys[0] != keys[1]` when the two version strings differ (determinism + nontriviality)
- [ ] On load: HMAC verified with `keys[0]` first; on mismatch, retry once with `keys[1]`
- [ ] On `keys[1]` success path: set a `_needs_rekey_persist: bool = true` flag; Story 006 / 007 triggers an immediate re-persist under `keys[0]` after hydration completes
- [ ] `_needs_rekey_persist` is cleared on the next successful persist
- [ ] PRIOR_BUILD_VERSION_STRING is read from compile-time `const` — a test asserts it is NOT read from any file/resource at runtime
- [ ] Array length is hardcoded 2; adding a third entry requires a superseding ADR (per ADR-0004 Decision §N=2 is authoritative)

---

## Implementation Notes

- Fragment placement — recommended distribution (fragment identifiers are non-suggestive, e.g., `_BOOT_PREFIX_A`, `_BOOT_PREFIX_B`, `_LOCALE_TAIL`):
  - `BootNamespace` autoload (rank in fragment region): holds `PART_A` (16 bytes) and `STATIC_SECRET` (16 bytes, XOR mask only — architecturally disjoint)
  - A separate autoload under an innocuous name (e.g., `EngineBootstrap`): holds `PART_B` (16 bytes)
  - A third autoload (e.g., `RuntimeLocaleGuard`): holds `PART_C` (16 bytes)
  - None of these files reference the HMAC path in comments or logs — they look like unrelated bootstrap concerns
- `PART_A XOR PART_B` is a 16-byte PackedByteArray elementwise XOR; the result is concatenated with `PART_C` (16 bytes) + `version_string.to_utf8_buffer()` then SHA-256-hashed
- Build pipeline contract: on release, the build script reads `git describe` or equivalent into `CURRENT_BUILD_VERSION_STRING`; records the prior release's value into `PRIOR_BUILD_VERSION_STRING`. Both are committed to the release branch as compile-time `const` sources (NOT generated at runtime)
- First release edge case: `PRIOR_BUILD_VERSION_STRING` defaults to the same value as `CURRENT_BUILD_VERSION_STRING` (so `keys[0] == keys[1]`; N-1 retry is redundant but harmless). Subsequent patches populate a real prior value.
- Re-persist queue pattern: set `_needs_rekey_persist = true` after `keys[1]` success + successful hydration; the next `PERSISTING` entry checks this flag and, if set, runs an atomic re-persist (Story 008) under `keys[0]`, then clears
- Saves older than N-1 (player skipped two patches) fail HMAC permanently; fall through to `.bak` + corrupt modal per Story 013 (accepted residual risk — ADR-0004 Negative consequence)
- Rollback plan: if the multi-part scheme proves unworkable, supersede ADR-0004 with Alternative 3 (hardcoded constant, no rotation) + accept weaker threat coverage (ADR-0004 Rollback section)

---

## Out of Scope

- Story 004: the HMAC wrapper itself (this story consumes it)
- Story 006: validation order + the pre-HMAC buffer sizing DoS defense
- Story 008: atomic write mechanics (the re-persist goes through that path)
- Story 014: CI grep scan across all fragment files

---

## QA Test Cases

- **TR-save-load-021**: Key derivation formula
  - **Given**: Fixed test-fixture values for `PART_A`, `PART_B`, `PART_C`, and two distinct version strings `"v1.0.0"` and `"v0.9.0"`
  - **When**: `_derive_keys()` runs
  - **Then**: Result array has length 2; `keys[0] == SHA256(PART_A XOR PART_B || PART_C || "v1.0.0")` (pre-computed golden hex); `keys[1] == SHA256(PART_A XOR PART_B || PART_C || "v0.9.0")`; `keys[0] != keys[1]`
  - **Edge cases**: Same version string in both → `keys[0] == keys[1]` (first-release behavior); swapping PART_A and PART_B produces identical result (XOR is commutative — confirms no accidental ordering dependency)

- **TR-save-load-021 (key[1] retry semantics)**: N-1 fallback success flag
  - **Given**: A save file correctly signed under `keys[1]` (prior build); current build loads it
  - **When**: Load runs HMAC verify under `keys[0]` (fails) then under `keys[1]` (succeeds)
  - **Then**: Hydration proceeds normally; `_needs_rekey_persist` is set to `true`; after hydration, an atomic re-persist is queued that writes under `keys[0]`; after re-persist, `_needs_rekey_persist` is `false`
  - **Edge cases**: If re-persist fails (disk-full), the flag stays `true` and the retry fires on the next heartbeat; the original save remains `keys[1]`-signed (fallback still works on next launch)

- **TR-save-load-021 (boundary)**: N=2 fixed-length guarantee
  - **Given**: `_derive_keys()` returns a length-2 array
  - **When**: A static-assertion test enumerates the array
  - **Then**: `keys.size() == 2`; attempting to append a third entry in the derivation function fails either a compile-time `const` assertion or a runtime `assert` (if test mode)
  - **Edge cases**: Proves N=2 is not a soft-tunable — documents the "don't generalize" contract

- **ADR-0004 Rule — PRIOR_BUILD_VERSION_STRING is compile-time, not file-sourced**
  - **Given**: A malicious `user://overrides.cfg` attempt to override `PRIOR_BUILD_VERSION_STRING`
  - **When**: SaveLoadSystem boots and calls `_derive_keys()`
  - **Then**: The value used is the compile-time `const` (unchanged); the override is ineffective
  - **Edge cases**: This test is the teeth of "attacker-controllable key material would produce trivial bypass" — must prove `const` is baked into bytecode

- **ADR-0004 architectural separation**: STATIC_SECRET NOT in HMAC keying
  - **Given**: Read the `_derive_keys()` implementation
  - **When**: Grep for the `STATIC_SECRET` (XOR mask seed) identifier inside `_derive_keys` body
  - **Then**: Zero occurrences — XOR mask seed and HMAC key are disjoint code paths
  - **Edge cases**: Code review gate; static analysis verification

- **Determinism**: Same fragment bytes + same version string → same key bytes
  - **Given**: Two invocations of `_derive_keys()` in the same session
  - **When**: Compare results
  - **Then**: Byte-exact identical results; `keys[0]` is 32 bytes; `keys[1]` is 32 bytes
  - **Edge cases**: Runs across session boundary produce the same key material (no time-dependent input)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/key_derivation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 004 (HMAC-SHA256 wrapper, for the internal `_sha256` primitive)
- **Unlocks**: Story 006 (validation order uses `keys[0]` + `keys[1]`), Story 008 (re-persist on keys[1] success)
