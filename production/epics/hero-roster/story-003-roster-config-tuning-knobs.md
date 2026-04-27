# Story 003: roster_config.tres tuning knobs

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-006, TR-hero-roster-030

**Governing ADR(s)**: ADR-0012 (Hero Roster — config-driven knobs)
**ADR Decision Summary**: All HeroRoster tuning knobs live in `assets/data/config/roster_config.tres`. Hardcoded Roster values in GDScript are FORBIDDEN. Schema includes MAX_ROSTER_SIZE (default 30), FORMATION_SIZE (default 3), LEVEL_CAP (default 15), with constraint MAX_ROSTER_SIZE >= FORMATION_SIZE.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: All Roster constants externalized to roster_config.tres. — ADR-0012 / TR-030
- **Required**: MAX_ROSTER_SIZE >= FORMATION_SIZE (constraint enforced at config load). — TR-006
- **Forbidden**: Hardcoded MAX_ROSTER_SIZE / FORMATION_SIZE / LEVEL_CAP literals in GDScript outside the config-loader path.

---

## Acceptance Criteria

- [ ] TR-hero-roster-006: MAX_ROSTER_SIZE=30; FORMATION_SIZE=3; constraint MAX_ROSTER_SIZE >= FORMATION_SIZE enforced at config load
- [ ] TR-hero-roster-030: Tuning knobs in `assets/data/config/roster_config.tres`; no hardcoded Roster values in GDScript

---

## Implementation Notes

Create `src/core/hero_roster/roster_config.gd` resource subclass:
```gdscript
class_name RosterConfig extends Resource

@export var max_roster_size: int = 30
@export var formation_size: int = 3
@export var level_cap: int = 15

func validate() -> bool:
    if max_roster_size < formation_size:
        push_error("RosterConfig: max_roster_size (%d) < formation_size (%d)" % [max_roster_size, formation_size])
        return false
    return true
```

Author `assets/data/config/roster_config.tres`:
```
[gd_resource type="Resource" script_class="RosterConfig" format=3]
[ext_resource type="Script" path="res://src/core/hero_roster/roster_config.gd" id="1"]
[resource]
script = ExtResource("1")
max_roster_size = 30
formation_size = 3
level_cap = 15
```

HeroRoster.`_ready()` loads via `DataRegistry.resolve("config", "roster_config")` (or direct preload — match the EconomyConfig precedent in Sprint 2). Calls `validate()` and pushes error + uses safe defaults on validation failure. Replaces the hardcoded constants in `hero_roster.gd` (Story 002) with reads from the loaded config.

Register the `config` category in DataRegistry's ORDERED_CATEGORIES if not already there (it was added in Sprint 2 S2-M2 for EconomyConfig — verify it's still present and `roster_config` falls under the same category).

---

## Out of Scope

- HeroRoster autoload + state fields (Story 002 — defines the constants Story 003 replaces)
- Mutation methods consuming these knobs (Stories 004-005)

---

## QA Test Cases

- **AC TR-006**: config loads with correct values
  - Given: roster_config.tres exists with default values
  - When: HeroRoster boots and resolves config
  - Then: HeroRoster.MAX_ROSTER_SIZE == 30; FORMATION_SIZE == 3; LEVEL_CAP == 15
- **AC TR-006**: constraint validation
  - Given: roster_config.tres modified to have max_roster_size=2, formation_size=3
  - When: config.validate() called
  - Then: returns false; push_error logged
- **AC TR-030**: no hardcoded Roster values in GDScript
  - Given: source files in src/core/hero_roster/
  - When: grep for `30\|MAX_ROSTER\|FORMATION_SIZE = 3\|LEVEL_CAP = 15` outside the config loader path
  - Then: zero hits (config-loader path may reference defaults)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check via `production/qa/smoke-*.md` confirming roster_config.tres loads cleanly at boot. Optional: brief unit test on RosterConfig.validate() at `tests/unit/hero_roster/roster_config_test.gd`.
**Status**: [x] Created — `tests/unit/hero_roster/roster_config_test.gd` (18/18 PASS); existing tests Group E + F cited as smoke-equivalent evidence per qa-tester review.

---

## Dependencies

- **Depends on**: Story 002 (HeroRoster autoload exists to consume config) — **Complete**
- **Unlocks**: Story 004 (add_hero needs MAX_ROSTER_SIZE), Story 005 (set_hero_level needs LEVEL_CAP)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 2/2 passing (TR-006, TR-030 — all 3 story-defined QA cases covered)

**Files**:
- `src/core/hero_roster/roster_config.gd` — `class_name RosterConfig extends GameData`; 3 `@export_range` knobs + `_validate() -> Array[String]` (~95 lines)
- `assets/data/config/roster_config.tres` — id="roster_config", display_name="Roster Config", defaults 30/3/15
- `src/core/hero_roster/hero_roster.gd` — replaced 3 hardcoded `const` declarations with `_FALLBACK_*` constants + `_config: Resource` field + `_load_config()` + `_resize_formation_slots()` + 3 duck-typed accessors
- `tests/unit/hero_roster/roster_config_test.gd` — 18 tests (Groups A schema, B validate-clean, C max>=formation, D sub-1 fields, E .tres load+DataRegistry, F autoload integration, G TR-030 source-grep canary)
- `tests/unit/hero_roster/hero_roster_autoload_skeleton_test.gd` — Story 002 GAP-1 const test → accessor test; underscore-prefix test extended for `_config` field

**Test Evidence**: 46/46 hero-roster tests PASS (12 skeleton + 18 roster_config + 16 hero_instance). Zero regressions across wider unit suite. Story specifies "Config/Data" → smoke evidence: existing automated tests (Groups E + F) verify roster_config.tres loads cleanly, validates clean, and HeroRoster accessors return GDD §G defaults at boot — equivalent to a smoke check per qa-tester review.

**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist) + GAPS-advisory (qa-tester). Three of four light gdscript suggestions applied inline:
- Dropped redundant zero-fill loop in `_resize_formation_slots()` (resize() already zero-fills Array[int]).
- Softened `_config` doc-comment to clarify the workaround is a defensive guard against stale class cache, not a permanent Godot limitation. Mentioned the `preload`-based future cleanup path.
- Annotated the source-grep canary with explanation of why literal `3` is intentionally not grepped (too common as array index/loop bound).
- Deferred: `preload`-based typed-field migration (optional cleanup, not blocking).

**Deviations**:
1. `_config` typed as `Resource` (not `RosterConfig`) — defensive guard against stale `.godot/global_script_class_cache.cfg` on a fresh checkout. Documented in field doc-comment with future `preload`-based cleanup path noted.
2. Story's pseudo-code for `validate()` returns `bool`; actual implementation matches the project-wide ADR-0011 contract `_validate() -> Array[String]` (empty == OK). Tests align with the real contract.

**Tech debt**: TD-009 logged — `_load_config()` has 4 defensive branches with no direct test coverage (null-resolve, schema-mismatch, validate-error fallback, no-_validate). LOW severity; production safety preserved by fallback constants. Resolves alongside FOLLOWUP-002 / S6-M12 when test harness gains DataRegistry-injection support.

**Bugs decoded this story**:
- GDScript `+`-concatenated string with trailing `% [args]` only binds to the LAST fragment → "a number is required" runtime error. Fix: wrap concatenation in parens before `%`.
- Class-cache parse-order issue at autoload boot: a freshly-added `class_name` referenced as a typed-field type can fail at parse time on first run before the editor rebuilds the global class cache. Workaround documented in `_config` doc-comment.
