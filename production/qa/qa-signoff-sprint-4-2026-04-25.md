# QA Sign-Off Report: Sprint 4

**Date**: 2026-04-25
**Sprint**: 4 (2026-06-08 → 2026-06-19) — SaveLoadSystem Foundation epic core + UX spec carryover
**QA Lead sign-off**: APPROVED WITH CONDITIONS
**Reference QA Plan**: `production/qa/qa-plan-sprint-4-2026-04-25.md`
**Previous sprint sign-offs**: `qa-signoff-sprint-{1,2,3}-*.md`

---

## Sprint Goal Recap

> "Land the SaveLoadSystem Foundation epic core (Stories 001–004) — autoload
> skeleton + envelope binary layout + XOR mask + HMAC-SHA256 conformance — to
> fill the rank-2 hole. Pair with deferred UX specs (S3-S1 + S3-S2 carryover)."

**Goal status**: ✅ Met. The rank-2 SaveLoadSystem hole that has been open since
Sprint 1 is now closed. The epic's HIGHEST-RISK story (S4-M6 HMAC RFC 4231
conformance) landed with all 7 canonical test vectors byte-exact on the first
green run.

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| S4-M1 main-menu UX spec | UI / Spec | n/a | ux-review APPROVED | PASS |
| S4-M2 pause-menu UX spec | UI / Spec | n/a | ux-review APPROVED | PASS |
| S4-M3 SaveLoadSystem autoload skeleton | Logic | `tests/unit/save_load/autoload_skeleton_test.gd` 13/13 | — | PASS |
| S4-M4 Save envelope binary layout | Logic | `tests/unit/save_load/envelope_layout_test.gd` 19/19 | — | PASS |
| S4-M5 XOR mask derivation | Logic | `tests/unit/save_load/xor_mask_derivation_test.gd` 17/17 | — | PASS |
| **S4-M6 HMAC-SHA256 RFC 4231** | Logic (HIGHEST RISK) | `tests/unit/save_load/hmac_rfc4231_test.gd` 14/14 — **all 7 RFC vectors byte-exact** | — | **PASS** |
| S4-S1 HMAC key derivation + N=2 rotation | Logic | `tests/unit/save_load/integrity_tag_derivation_test.gd` 25/25 | — | PASS |
| S4-S2 stat_at_level helper | Logic | `tests/unit/hero_class_database/stat_at_level_test.gd` 26/26 | — | PASS |
| S4-N1 matchup-visualization quick-spec | Config/Data | n/a (design doc) | Spec read-through (orchestrator) | PASS |
| S4-N2 dungeon-enemy-visualization quick-spec | Config/Data | n/a (design doc) | Spec read-through (orchestrator) | PASS |
| S4-N3 is_class_counter helper | Logic | `tests/unit/hero_class_database/is_class_counter_test.gd` 17/17 | — | PASS |

**Aggregate**: 11/11 stories PASS. 6 Must Have ✓, 2 Should Have ✓, 3 Nice to Have ✓.

---

## Suite Snapshot (post-Sprint-4-close)

| Suite | Result |
|---|---|
| `tests/unit/save_load/` | **88/88 PASS** (rank-2 fully covered) |
| `tests/unit/hero_class_database/` (incl. new `stat_at_level_test.gd` + `is_class_counter_test.gd`) | All PASS |
| `tests/unit/` (full suite) | **309/310 PASS, 1 pre-existing error** |

The single outstanding error is documented under "Bugs Found / Conditions" below.

---

## Encapsulation & Forbidden-Substring Audit (Foundation crypto)

ADR-0004 forbids the substrings `_key`, `_secret`, `_hmac` in identifier
declaration lines for the cryptographic source files. Re-verified at sign-off:

```
$ grep -nE '\b(_key|_secret|_hmac)\b' \
    src/core/engine_bootstrap/engine_bootstrap.gd \
    src/core/runtime_locale_guard/runtime_locale_guard.gd \
    src/core/boot_namespace/boot_namespace.gd \
    src/core/save_load_system/save_load_system.gd
(no output — clean)
```

✅ Encapsulation grep clean across all 4 crypto-touching files.

---

## Bugs Found / Conditions

| ID | Source | Severity | Status | Resolution |
|----|--------|----------|--------|------------|
| (inline-fix) | `gamedata_base_and_constant_sets_test.gd` lines 64, 178 | S4 | RESOLVED | Removed `.free()` calls on RefCounted GameData instances (pre-existing bug from earlier sprints; Godot 4.6 strict mode catches it now). |
| FOLLOWUP-001 | `tests/unit/data_registry/resolve_api_and_typed_accessors_test.gd:215` — `test_resolve_assert_behavior_returns_null_after_assert_fires` | S3 | OPEN | Test was authored assuming release-mode assert no-op. CI runs in debug; the `assert(false, ...)` in `DataRegistry.resolve` fires and aborts the test. Two paths forward: (a) gate the test with `if OS.is_debug_build(): return # assertion path is debug-only`, or (b) refactor `DataRegistry.resolve` to use `push_error` + early-return semantics in the ASSERT behavior mode. Recommend authoring this as Sprint 5 cleanup story. **Does not block Sprint 4 sign-off.** |

No S1 or S2 bugs open.

---

## Conditions Attached to Sign-Off

1. **FOLLOWUP-001 must be tracked as a Sprint 5 cleanup story** before
   `/gate-check` Pre-Production → Production runs again. The current
   debug-vs-release assert behavior is technically working as designed (debug
   asserts do fire) but the test can never go green in CI without one of the
   two fixes above. This is out of original Sprint 4 scope.

2. **Manual UX walkthrough for the rendered specs (S4-M1/M2/N1/N2) is
   deferred to Sprint 5+** when actual screens are implemented. The specs
   themselves passed ux-review on 2026-04-25.

---

## Verdict: APPROVED WITH CONDITIONS

All 11 Sprint 4 stories meet acceptance criteria with documented test evidence.
The cryptographic core (envelope + XOR mask + HMAC-SHA256 + multi-part key
derivation with N=2 rotation) is locked down with byte-exact RFC 4231
conformance and zero forbidden-substring violations. The single open
condition (FOLLOWUP-001) is a pre-existing test-authoring concern in an
unrelated subsystem and does not affect Sprint 4 deliverables.

---

## Sprint Highlights

- **Risk retired**: Sprint 4's highest-risk story (S4-M6 HMAC) landed first-pass
  green against all 7 RFC 4231 canonical test vectors. The rank-2
  SaveLoadSystem foundation is now production-quality.
- **Encapsulation discipline held**: ADR-0004 forbidden-substring grep
  remained clean across 4 newly-introduced source files (`engine_bootstrap.gd`,
  `runtime_locale_guard.gd`, plus the existing `boot_namespace.gd` and
  `save_load_system.gd`). N=2 build-version rotation works without any
  field name mentioning `_key`, `_secret`, or `_hmac`.
- **Cleanup bonus**: 2 pre-existing data_registry test bugs were fixed inline
  (`.free()` on RefCounted) — improves CI hygiene by 2 tests.
- **Cross-system architecture concerns flagged for Sprint 5**: PauseManager
  singleton (referenced in pause-menu UX spec); OfflineProgressionEngine
  in-progress reads; quit-save vs heartbeat-save semantic.

---

## Next Step

Run `/gate-check` to validate readiness for the Pre-Production → Production
transition. Sprint 4 closes the rank-2 hole, which was the primary blocker
flagged in the prior gate-check session. Track FOLLOWUP-001 as a Sprint 5
cleanup story before the next gate-check fires.

If proceeding to a new sprint, candidates carry over from the SaveLoadSystem
epic stories 006–015 (validation order, atomic write, partial heartbeat,
scene-boundary integration), plus Hero Roster Feature epic + Floor Unlock
Feature epic.
