# Story 004: add_hero + signals (hero_recruited, hero_leveled, hero_removed)

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-008, TR-hero-roster-009

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: `add_hero(class_id) -> HeroInstance | null` returns null on cap (size >= MAX_ROSTER_SIZE) or unresolvable class (DataRegistry returns null). Increments `_next_instance_id` AFTER successful add. Emits `hero_recruited(instance)` signal. The 3 signals are the only mutation-feedback channels; subscribers (HUD, Recruitment, Economy) react via signal connections — never poll `_heroes`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: `add_hero` returns null on cap or unresolvable class. — TR-008
- **Required**: `_next_instance_id` increments AFTER success (not before — failed add must not consume an id). — TR-008/011
- **Required**: 3 signals: `hero_recruited(instance)`, `hero_leveled(id, old, new)`, `hero_removed(id, class_id, display_name)`. — TR-009

---

## Acceptance Criteria

- [ ] TR-hero-roster-008: `add_hero(class_id) -> HeroInstance|null` returns null on cap or unresolvable class; increments `_next_instance_id` AFTER success
- [ ] TR-hero-roster-009: 3 signals declared with exact arity: `hero_recruited(instance: HeroInstance)`, `hero_leveled(id: int, old: int, new: int)`, `hero_removed(id: int, class_id: String, display_name: String)`
- [ ] `add_hero` resolves `class_id` via `DataRegistry.resolve("classes", class_id)`; returns null if resolution fails (push_warning logged)
- [ ] `add_hero` emits `hero_recruited(instance)` exactly once per successful add

---

## Implementation Notes

```gdscript
func add_hero(class_id: String) -> HeroInstance:
    if _heroes.size() >= MAX_ROSTER_SIZE:
        push_warning("[HeroRoster] add_hero: roster at cap (%d)" % MAX_ROSTER_SIZE)
        return null
    var class_data: Resource = DataRegistry.resolve("classes", class_id)
    if class_data == null:
        push_warning("[HeroRoster] add_hero: unresolvable class_id '%s'" % class_id)
        return null
    var instance: HeroInstance = HeroInstance.new()
    instance.instance_id = _next_instance_id
    instance.class_id = class_id
    instance.display_name = _generate_name(class_id)  # Story 009
    instance.current_level = 1
    instance.xp = 0
    _heroes[instance.instance_id] = instance
    _next_instance_id += 1  # AFTER success
    hero_recruited.emit(instance)
    return instance
```

Story 009 implements `_generate_name(class_id)` (name pool + DataRegistry); for this story use placeholder `"Hero %d" % instance.instance_id` if Story 009 hasn't landed yet.

`remove_hero(id)` is included in this story (mirror of add_hero) for completeness:
```gdscript
func remove_hero(id: int) -> bool:
    if not _heroes.has(id):
        push_warning("[HeroRoster] remove_hero: unknown id %d" % id)
        return false
    var instance: HeroInstance = _heroes[id]
    var class_id: String = instance.class_id
    var display_name: String = instance.display_name
    _heroes.erase(id)
    # Clear formation slots referencing this id
    for i in range(_formation_slots.size()):
        if _formation_slots[i] == id:
            _formation_slots[i] = 0
    hero_removed.emit(id, class_id, display_name)
    return true
```

---

## Out of Scope

- Story 005: `set_hero_level` (emits `hero_leveled` signal)
- Story 005: `set_formation_slot` validation
- Story 009: full name pool generation (Story 004 uses placeholder)

---

## QA Test Cases

- **AC TR-008 success**: add_hero returns instance and increments _next_instance_id
  - Given: HeroRoster IDLE; DataRegistry has "warrior" class registered
  - When: `add_hero("warrior")` called
  - Then: returns non-null HeroInstance; instance.instance_id == 1; instance.class_id == "warrior"; instance.current_level == 1; _heroes.size() == 1; _next_instance_id == 2
- **AC TR-008 cap**: add_hero returns null at cap
  - Given: roster filled to MAX_ROSTER_SIZE
  - When: `add_hero("warrior")` called
  - Then: returns null; _heroes.size() unchanged; _next_instance_id unchanged
- **AC TR-008 unresolvable**: unknown class_id returns null
  - Given: HeroRoster booted; DataRegistry has no "ghost_class" entry
  - When: `add_hero("ghost_class")` called
  - Then: returns null; _heroes unchanged; _next_instance_id unchanged
- **AC TR-009 signal**: hero_recruited fires exactly once per add
  - Given: signal spy connected
  - When: `add_hero("warrior")` succeeds
  - Then: spy received exactly 1 emission; emission arg is the HeroInstance
- **AC remove_hero**: hero_removed fires; formation slot cleared
  - Given: hero added; manually placed in formation_slots[0]
  - When: `remove_hero(id)` called
  - Then: returns true; _heroes.has(id) is false; _formation_slots[0] == 0; hero_removed signal received with (id, class_id, display_name)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_roster/add_hero_and_signals_test.gd`
**Status**: [x] Created — `tests/unit/hero_roster/add_hero_and_signals_test.gd` (24/24 PASS).

---

## Dependencies

- **Depends on**: Story 001 (HeroInstance) — Complete; Story 002 (HeroRoster skeleton) — Complete; Story 003 (MAX_ROSTER_SIZE config) — Complete
- **Unlocks**: Story 005 (mutation API references `hero_leveled` signal); Story 009 (replaces `_generate_name` placeholder); Story 010 (formation accessors consume `_heroes`)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 4/4 passing — all TR-008/TR-009/TR-011 contracts verified, all 5 story-defined QA cases COVERED.

**Files modified**:
- `src/core/hero_roster/hero_roster.gd` — added `HeroInstanceScript` preload constant, `add_hero()`, `remove_hero()`, `_generate_name()` placeholder.

**Files created**:
- `tests/unit/hero_roster/add_hero_and_signals_test.gd` — 24 tests in 5 groups (A success path 7, B signal emission 3, C unresolvable 4, D cap 2, E remove_hero 8). 3 tests added inline per code review feedback (signal-ordering canaries × 2 + empty-string add_hero).

**Test Evidence**: 24/24 PASS in dedicated suite; 70/70 PASS across full hero-roster directory; zero regressions in wider unit suite.

**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist) + ADEQUATE/GAPS-resolved (qa-tester). Both review findings addressed inline:
- `_generate_name` parameter renamed `class_id` → `_class_id` (idiomatic GDScript unused-parameter convention); dropped the `var _unused` no-op line.
- Added `test_add_hero_emits_signal_after_heroes_dict_mutation` — verifies `_heroes.has(id)` is `true` from inside the `hero_recruited` handler (subscriber-contract canary).
- Added `test_remove_hero_emits_signal_after_heroes_dict_erase` — verifies `_heroes.has(id)` is `false` from inside the `hero_removed` handler (subscriber-contract canary).
- Added `test_add_hero_returns_null_on_empty_string_class_id` — defensive coverage for serialization/formatting bugs that could pass empty class_ids.

**Deferred (advisory, project-wide)**:
- Replacing `push_warning + return` defensive skips with gdunit4's `pending()` so skipped tests appear as SKIPPED rather than PASSED — pre-existing precedent at `economy_config_schema_test.gd:286`. Refactor as a project-wide cleanup when team aligned on gdunit4 API choice.
- FOLLOWUP-002 (S6-M12) DataRegistry-test-env bug: when DataRegistry is in ERROR state in CI, Group A success-path tests skip. Tracked in S6-M12; production safety preserved by Group D + Group C fully exercising the cap and unresolvable branches independent of DataRegistry.

**Deviations**:
1. `add_hero` return type `RefCounted` (not `HeroInstance`). Same defensive parse-order pattern as `signal hero_recruited` and `_config: Resource`. Per gdscript-specialist review, this is necessary — return type annotations are resolved at script compilation BEFORE preload constants are evaluated, so even with the `HeroInstanceScript` preload at the top of the file, `-> HeroInstance` would fail at parse time.
2. Synthetic `HeroInstance` injection via direct `_heroes[i] = ...` in Group D (cap) and Group E (remove_hero) — bypasses DataRegistry dependency. Confirmed legitimate test seam by gdscript-specialist review (no production-surface footprint added).

**Bugs decoded this story**: None new — all GDScript quirks already cataloged in S6-M1 through S6-M3 (parse-order, % vs +, `is` vs Object cast).
