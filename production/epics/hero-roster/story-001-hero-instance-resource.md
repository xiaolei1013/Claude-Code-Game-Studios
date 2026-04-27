# Story 001: HeroInstance RefCounted class + 5-field schema + to_dict / from_dict

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-001, TR-hero-roster-002, TR-hero-roster-003, TR-hero-roster-004
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity) + ADR-0011 (Resource Schemas Core Databases)
**ADR Decision Summary**: `HeroInstance` is `class_name HeroInstance extends RefCounted` — a lightweight data record, NOT a Godot Resource (no `.tres` file). 5 fields exactly: `instance_id: int`, `class_id: String`, `display_name: String`, `current_level: int`, `xp: int`. `to_dict()` / `from_dict(d)` produce/consume exactly the 5-field dictionary; no other per-hero data persisted. HeroInstance has NO mutation methods — all mutation flows through `HeroRoster` autoload methods (Story 005).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure GDScript inheritance, RefCounted lifecycle, Dictionary serialization. No post-cutoff API risk.

**Control Manifest Rules (Feature Layer, HeroRoster)**:
- **Required**: HeroInstance is `class_name HeroInstance extends RefCounted` — NOT a Resource. — ADR-0012
- **Required**: HeroInstance has exactly 5 fields. — ADR-0012 / TR-002
- **Forbidden**: HeroInstance must not contain mutation methods — ADR-0012 / TR-004

---

## Acceptance Criteria

- [ ] TR-hero-roster-001: HeroInstance is `class_name HeroInstance extends RefCounted`
- [ ] TR-hero-roster-002: HeroInstance fields exactly: `instance_id: int`, `class_id: String`, `display_name: String`, `current_level: int`, `xp: int` (xp reserved V1.0; default 0)
- [ ] TR-hero-roster-003: `to_dict()` produces exactly a 5-field Dictionary; `from_dict(d)` consumes it
- [ ] TR-hero-roster-004: HeroInstance has no mutation methods; all mutation via HeroRoster autoload methods (Story 005)

---

## Implementation Notes

Per ADR-0012 §HeroInstance:

```gdscript
# src/core/hero_roster/hero_instance.gd
class_name HeroInstance extends RefCounted

var instance_id: int = 0
var class_id: String = ""
var display_name: String = ""
var current_level: int = 1
var xp: int = 0  # Reserved V1.0; never displayed in MVP

func to_dict() -> Dictionary:
    return {
        "instance_id": instance_id,
        "class_id": class_id,
        "display_name": display_name,
        "current_level": current_level,
        "xp": xp,
    }

func from_dict(d: Dictionary) -> void:
    instance_id = int(d.get("instance_id", 0))
    class_id = String(d.get("class_id", ""))
    display_name = String(d.get("display_name", ""))
    current_level = int(d.get("current_level", 1))
    xp = int(d.get("xp", 0))
```

No `_init` parameters required (per ADR-0003 Amendment #3, but HeroInstance is RefCounted not autoload — still cleaner zero-arg).

---

## Out of Scope

- Story 002: HeroRoster autoload skeleton owning the dictionary of HeroInstance objects
- Story 005: mutation methods on HeroRoster (set_hero_level, set_formation_slot)
- xp consumption logic (V1.0)

---

## QA Test Cases

- **AC TR-001**: HeroInstance class resolves
  - Given: `HeroInstance.gd` script loaded
  - When: `HeroInstance.new()` instantiated
  - Then: instance is non-null; `instance is RefCounted` is true; NOT `is Resource`
- **AC TR-002**: 5 fields with correct types and defaults
  - Given: fresh `HeroInstance.new()`
  - When: each field accessed
  - Then: instance_id == 0, class_id == "", display_name == "", current_level == 1, xp == 0; types match
- **AC TR-003 round-trip**: `to_dict / from_dict` symmetric
  - Given: HeroInstance with known field values
  - When: `to_dict()` → mutate fields → `from_dict(prev_dict)`
  - Then: fields equal pre-mutation values; dictionary has exactly 5 keys
- **AC TR-004**: no mutation methods exposed
  - Given: HeroInstance class loaded
  - When: `get_method_list()` inspected
  - Then: no method named `set_*` or `mutate_*` is defined on HeroInstance (excluding `from_dict` which is a deserializer, not mutation)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_roster/hero_instance_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (foundational data class)
- **Unlocks**: Story 002 (HeroRoster autoload references HeroInstance type)

---

## Completion Notes

**Completed**: 2026-04-26
**Sprint**: Sprint 6 (first implementation story; pre-flighted in Sprint 5 S5-M9)
**Criteria**: 4/4 passing (TR-001..004)
**Test Evidence**: `tests/unit/hero_roster/hero_instance_test.gd` — 16 tests across 4 groups (was 14 at first impl; +2 added during /code-review for QA-flagged GAP-001 type coercion + GAP-002 extra-key passthrough). 0 errors, 0 failures, 0 orphans.
**Code Review**: Complete — APPROVED verdict (godot-gdscript-specialist + qa-tester reviews; 1 BLOCKING-class real bug surfaced + fixed inline)
**Gates skipped per solo mode**: QL-TEST-COVERAGE, LP-CODE-REVIEW

**Files created**:
- `src/core/hero_roster/hero_instance.gd` (~80 lines) — `class_name HeroInstance extends RefCounted`. Exactly 5 fields per TR-002 (instance_id / class_id / display_name / current_level / xp). `to_dict()` produces 5-key Dictionary; `from_dict(d)` hydrates with defensive defaults + type coercion via `int()` and `str()`. No mutation methods (TR-004). Doc comments cite ADR-0011 + ADR-0012.
- `tests/unit/hero_roster/hero_instance_test.gd` (~210 lines) — 16 tests across 4 groups.

**Critical bug surfaced + fixed during /code-review**:
- Original `from_dict` used `String(d.get(...))` for class_id/display_name fields. `String()` is **NOT a valid constructor in GDScript 4** for non-string Variants — runtime crashes with "Invalid call. Nonexistent 'String' constructor" when passing wrong-typed values (e.g., int instead of String). The QA-recommended GAP-001 type-coercion test (added inline) surfaced this immediately. Fix: `String(...)` → `str(...)` for both class_id and display_name. Implementation now genuinely defensive per its own doc-comment claim. Pattern note: GDScript 4 has `int()` (works for any Variant) but NO `String()` — always use `str()` for forced-string conversion.

**Test additions during /code-review** (per qa-tester gap findings):
- GAP-001: `test_hero_instance_from_dict_coerces_wrong_typed_values` — verifies defensive coercion for wrong-typed dict values; this test caught the `String()` bug above.
- GAP-002: `test_hero_instance_from_dict_ignores_extra_keys` — verifies extras are dropped on round-trip; prevents accidental future regression of "exactly 5 keys" invariant.

**Tech debt advisories deferred** (non-blocking):
- GAP-003 (cosmetic): `test_hero_instance_field_types` is a redundant duplicate of default-field tests. Could be deleted in a future cleanup pass; not blocking.

**No deviations from Out of Scope.** HeroRoster autoload (Story 002), mutation methods (Story 005), save/load (Story 006) all untouched.

**Sprint context**: No formal Sprint 6 plan exists yet. This story was implemented standalone as a lightest-touch Sprint 6 starter (the 22 pre-flighted Sprint 6 stories are the input pool). Recommend `/sprint-plan` before resuming the Sprint 6 implementation chain.

**Cumulative project test count**: scene_manager+save_load 219 + hero_roster 16 = **235 in active suites**. Full project via wrapper: 471 total cases (468 PASS + 3 pre-existing data_registry test-env failures unrelated to Sprint 5/6 work).
