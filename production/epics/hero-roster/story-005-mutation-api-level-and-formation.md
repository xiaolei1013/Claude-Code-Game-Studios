# Story 005: set_hero_level + set_formation_slot mutations

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-012, TR-hero-roster-013, TR-hero-roster-014

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: `instance_id`, `class_id`, `display_name` are immutable after `add_hero()` — downstream systems rely on cross-session identity stability. Mutable fields are `current_level` and `xp`. `set_hero_level(id, new_level)` clamps to `[1, LEVEL_CAP=15]` with push_warning on out-of-range; returns false if id unknown. `set_formation_slot(slot_index, hero_id)` validates id and auto-clears prior slot if same id exists elsewhere (no duplicate placement).

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: instance_id / class_id / display_name immutable after add_hero. — TR-012
- **Required**: set_hero_level clamps to [1, LEVEL_CAP] with push_warning. — TR-013
- **Required**: set_formation_slot auto-clears duplicate placements. — TR-014

---

## Acceptance Criteria

- [ ] TR-hero-roster-012: instance_id / class_id / display_name immutable after add_hero (no setter exposed; cross-session identity stable)
- [ ] TR-hero-roster-013: `set_hero_level(id, new_level) -> bool` clamps to [1, LEVEL_CAP=15] with push_warning on out-of-range; returns false if id unknown
- [ ] TR-hero-roster-013: emits `hero_leveled(id, old_level, new_level)` on success
- [ ] TR-hero-roster-014: `set_formation_slot(slot_index: int, hero_id: int) -> bool` validates id (must be in _heroes or 0); auto-clears prior slot if same id placed elsewhere

---

## Implementation Notes

```gdscript
func set_hero_level(id: int, new_level: int) -> bool:
    if not _heroes.has(id):
        push_warning("[HeroRoster] set_hero_level: unknown id %d" % id)
        return false
    var instance: HeroInstance = _heroes[id]
    var clamped: int = clampi(new_level, 1, LEVEL_CAP)
    if clamped != new_level:
        push_warning("[HeroRoster] set_hero_level: %d clamped to %d (LEVEL_CAP=%d)" % [new_level, clamped, LEVEL_CAP])
    var old_level: int = instance.current_level
    instance.current_level = clamped
    hero_leveled.emit(id, old_level, clamped)
    return true

func set_formation_slot(slot_index: int, hero_id: int) -> bool:
    if slot_index < 0 or slot_index >= _formation_slots.size():
        push_warning("[HeroRoster] set_formation_slot: slot_index %d out of range" % slot_index)
        return false
    if hero_id != 0 and not _heroes.has(hero_id):
        push_warning("[HeroRoster] set_formation_slot: unknown hero_id %d" % hero_id)
        return false
    # Auto-clear prior slot if same id is already placed elsewhere
    if hero_id != 0:
        for i in range(_formation_slots.size()):
            if _formation_slots[i] == hero_id and i != slot_index:
                _formation_slots[i] = 0
    _formation_slots[slot_index] = hero_id
    return true
```

No mutation methods exposed for instance_id / class_id / display_name. Code review enforces.

---

## Out of Scope

- Story 008: first-launch seeding (uses set_hero_level / set_formation_slot indirectly via add_hero defaults)
- Story 010: formation strength calc (consumes formation slots set here)
- Combat damage / xp accumulation (out of MVP scope)

---

## QA Test Cases

- **AC TR-013 clamp**: out-of-range level clamped
  - Given: hero with current_level=5 added
  - When: `set_hero_level(id, 99)` called
  - Then: returns true; instance.current_level == LEVEL_CAP (15); push_warning emitted; hero_leveled fired with (id, 5, 15)
- **AC TR-013 negative**: negative level clamped to 1
  - When: `set_hero_level(id, -3)` called
  - Then: instance.current_level == 1; push_warning emitted
- **AC TR-013 unknown id**: returns false on missing
  - When: `set_hero_level(99999, 5)` called
  - Then: returns false; no signal emitted; push_warning logged
- **AC TR-014 valid placement**: slot updated
  - Given: hero id=1 added; formation_slots = [0,0,0]
  - When: `set_formation_slot(0, 1)`
  - Then: returns true; _formation_slots == [1, 0, 0]
- **AC TR-014 auto-clear duplicate**: same id placed elsewhere clears prior slot
  - Given: hero id=1 in slot 0; formation = [1, 0, 0]
  - When: `set_formation_slot(2, 1)`
  - Then: returns true; _formation_slots == [0, 0, 1] (prior slot 0 cleared)
- **AC TR-014 invalid index**: out-of-range slot rejected
  - When: `set_formation_slot(99, 1)`
  - Then: returns false; _formation_slots unchanged
- **AC TR-014 zero id**: clearing a slot with hero_id=0 succeeds
  - Given: formation = [1, 0, 0]
  - When: `set_formation_slot(0, 0)`
  - Then: returns true; _formation_slots == [0, 0, 0]
- **AC TR-012 immutability**: no setter for instance_id / class_id / display_name
  - Given: HeroInstance from add_hero
  - When: source code grepped for `set_instance_id\|set_class_id\|set_display_name` on HeroRoster
  - Then: zero hits (no public setter exists)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_roster/mutation_api_test.gd`
**Status**: [x] Created — `tests/unit/hero_roster/mutation_api_test.gd` (23/23 PASS).

---

## Dependencies

- **Depends on**: Story 002 (HeroRoster skeleton) — Complete; Story 003 (LEVEL_CAP from config) — Complete; Story 004 (add_hero + hero_leveled signal) — Complete
- **Unlocks**: Story 008 (first-launch seed); Story 010 (formation accessors)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 4/4 passing (TR-012, TR-013 clamp + signal, TR-014). All 8 story-defined QA cases COVERED.

**Files**:
- `src/core/hero_roster/hero_roster.gd` — added `set_hero_level()` and `set_formation_slot()` (~50 lines + doc-comments).
- `tests/unit/hero_roster/mutation_api_test.gd` — 23 tests in 7 groups (A clamp 5, B unknown id 2, C signal 5 — was 3, +2 from review, D happy+zero 2, E auto-clear 2, F invalid 5, G immutability 2).

**Test Evidence**: 23/23 PASS dedicated suite; 93/93 PASS across full hero-roster directory; zero regressions in wider unit suite.

**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist: 1 real test isolation issue + 1 advisory comment) + GAPS-resolved (qa-tester: 1 BLOCKING gap + 1 advisory ordering canary). All 4 findings addressed inline:
- Reset `_spy_leveled_count = 0` in `test_set_hero_level_does_not_emit_signal_on_unknown_id` (test isolation per `.claude/rules/test-standards.md`).
- Added `test_set_hero_level_emits_signal_even_when_level_unchanged` — guards documented contract that no-op level set still fires the signal (BLOCKING gap closed).
- Added `test_set_hero_level_emits_signal_after_state_mutation` — signal-ordering canary (subscriber observing `instance.current_level` from inside handler sees the NEW value).
- Inline comment in `set_formation_slot` auto-clear loop explaining loop heals synthetic duplicates.

**Deviations**: minimal — `instance: RefCounted` typing (Sprint 6 parse-order pattern); `level_cap()` accessor instead of removed `LEVEL_CAP` const.

**Architecture notes**:
- Encapsulation contract for `instance.current_level` direct write: enforced by code review per ADR-0012 (HeroInstance fields are public `var` — GDScript has no `private` keyword).
- `set_formation_slot` deliberately emits NO signal — Story 010 will add `formation_slot_changed` if polling proves insufficient.

**Tech debt**: none new. Pre-existing TD-009 (DataRegistry test-env defensive branches) still applies.
