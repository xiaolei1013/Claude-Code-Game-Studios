# Story 006: get_save_data / load_save_data round-trip + signal suppression

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-010, TR-hero-roster-019, TR-hero-roster-029

**Governing ADR(s)**: ADR-0004 (Save Envelope + HMAC; consumer canonical naming `get_save_data` / `load_save_data`) + ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: HeroRoster is item #2 in `SaveLoadSystem.CONSUMER_PATHS` (after Economy at #1). Element-layer canonical naming: `get_save_data() -> Dictionary` and `load_save_data(d: Dictionary) -> void`. Save dict shape: `{heroes: Array[Dict], formation_slots: Array[int], next_instance_id: int}`. All signals (`hero_recruited`, `hero_leveled`, `hero_removed`) MUST be SUPPRESSED during `load_save_data()` boot validation — bulk hydration must not trigger HUD updates / sound effects mid-load.

**Engine**: Godot 4.6 | **Risk**: LOW (round-trip serialization)

**Control Manifest Rules**:
- **Required**: HeroRoster implements `get_save_data() -> Dictionary` and `load_save_data(d: Dictionary) -> void` (element-layer naming). — ADR-0004
- **Required**: All signals suppressed during load_save_data. — TR-010
- **Required**: Save dict shape = `{heroes: Array[Dict], formation_slots: Array[int], next_instance_id: int}`. — TR-019
- **Required**: Save round-trip preserves all heroes field-for-field; _next_instance_id preserved across remove/add sequences. — TR-029

---

## Acceptance Criteria

- [ ] TR-hero-roster-019: save dict shape exactly `{heroes: Array[Dict], formation_slots: Array[int], next_instance_id: int}`; per-hero via HeroInstance.to_dict
- [ ] TR-hero-roster-010: signals suppressed during load_save_data (subscribers see zero emissions during bulk hydration)
- [ ] TR-hero-roster-029: round-trip preserves all heroes field-for-field; _next_instance_id preserved across remove/add sequences
- [ ] HeroRoster registered in SaveLoadSystem.CONSUMER_PATHS at index 1 (after Economy at index 0)

---

## Implementation Notes

```gdscript
func get_save_data() -> Dictionary:
    var heroes_arr: Array = []
    for id in _heroes:
        heroes_arr.append((_heroes[id] as HeroInstance).to_dict())
    return {
        "heroes": heroes_arr,
        "formation_slots": _formation_slots.duplicate(),
        "next_instance_id": _next_instance_id,
    }

func load_save_data(d: Dictionary) -> void:
    _suppress_signals = true  # local flag checked in emit guards
    _heroes.clear()
    _formation_slots = [0, 0, 0]
    _next_instance_id = 1
    var heroes_arr: Array = d.get("heroes", []) as Array
    for hero_dict in heroes_arr:
        var instance: HeroInstance = HeroInstance.new()
        instance.from_dict(hero_dict)
        _heroes[instance.instance_id] = instance
    var slots: Array = d.get("formation_slots", [0, 0, 0]) as Array
    _formation_slots = slots.duplicate() as Array[int]
    _next_instance_id = int(d.get("next_instance_id", 1))
    # Boot validation runs in Story 007 — _suppress_signals stays true through that pass
    _suppress_signals = false
```

Wrap `hero_recruited.emit(...)` / `hero_leveled.emit(...)` / `hero_removed.emit(...)` calls (from Stories 004/005) in `if not _suppress_signals` guards. The flag is private; only get_save_data / load_save_data and Story 007 boot validation set it true.

Update `src/core/save_load_system/save_load_system.gd` `CONSUMER_PATHS` array — add `"HeroRoster"` after `"Economy"`. This is a small modification to existing autoload code; coordinate with Sprint 4's save_load_system.gd structure.

---

## Out of Scope

- Story 007: boot validation order (signal suppression must persist through boot validation; this story sets the flag, Story 007 uses it)
- Encryption / HMAC layer (lives in SaveLoadSystem; HeroRoster only produces / consumes plain Dictionary)

---

## QA Test Cases

- **AC TR-019 shape**: get_save_data dict has exactly 3 top-level keys
  - Given: HeroRoster with 3 heroes, formation [1, 0, 2], _next_instance_id=4
  - When: `get_save_data()` called
  - Then: dict.size() == 3; keys == {"heroes", "formation_slots", "next_instance_id"}
- **AC TR-019 hero entries**: each hero is the 5-field to_dict
  - Given: above
  - When: dict.heroes[0] inspected
  - Then: 5 keys (instance_id / class_id / display_name / current_level / xp); values match the source HeroInstance
- **AC TR-010 signal suppression**: spies see zero emissions during load_save_data
  - Given: signal spies connected for all 3 mutation signals; pre-saved dict with 5 heroes
  - When: `load_save_data(saved_dict)` called
  - Then: spy_recruited.size() == 0; spy_leveled.size() == 0; spy_removed.size() == 0; _heroes contains 5 entries
- **AC TR-029 round-trip**: 10 heroes + remove/add sequence preserves _next_instance_id
  - Given: HeroRoster: add 10 heroes (ids 1..10); remove id=5
  - When: get_save_data → load_save_data on a fresh roster
  - Then: _heroes has 9 entries (ids 1,2,3,4,6,7,8,9,10); _next_instance_id == 11 (not reused 5)
- **AC SaveLoadSystem registration**: HeroRoster is consumer #1
  - Given: SaveLoadSystem source loaded
  - When: CONSUMER_PATHS array inspected
  - Then: index 0 == "Economy"; index 1 == "HeroRoster"

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hero_roster/save_load_round_trip_test.gd`
**Status**: [x] Created — `tests/integration/hero_roster/save_load_round_trip_test.gd` (20/20 PASS).

---

## Dependencies

- **Depends on**: Story 001, Story 002, Story 004, Story 005 — all Complete. SaveLoadSystem (Sprint 4) — CONSUMER_PATHS already pre-populated at `/root/HeroRoster` index 1.
- **Unlocks**: Story 007 (boot validation extends `_suppress_signals` coverage; consumes the populated `_heroes`)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 4/4 passing (TR-019 shape, TR-010 suppression, TR-029 round-trip, CONSUMER_PATHS registration). All 5 story-defined QA cases COVERED.

**Files modified**:
- `src/core/hero_roster/hero_roster.gd` — added `_suppress_signals: bool` field with convention comment, 3 emit-call guards (in `add_hero`, `remove_hero`, `set_hero_level`), `get_save_data() -> Dictionary` (~10 lines), `load_save_data(d: Dictionary) -> void` (~35 lines including push_warning on slot-truncation).

**Files created**:
- `tests/integration/hero_roster/save_load_round_trip_test.gd` — 20 tests (was 16 → +4 from review) in 7 groups:
  - A get_save_data shape (5)
  - B immutability — formation_slots is duplicated (1)
  - C round-trip preservation — heroes, fields, slots, monotonic counter (4)
  - D state clearing — pre-load wipe before hydration (1)
  - E signal suppression (2 — strengthened: post-load actually emits + spy verifies)
  - F CONSUMER_PATHS registration (2)
  - G defensive-load behavior (4 tests added: empty dict; **NEW** float-coercion JSON safety; **NEW** oversize-slots truncation; **NEW** undersize-slots padding)
  - **NEW** `test_post_load_add_hero_consumes_restored_next_instance_id` — TR-011 monotonic-id end-to-end canary (defensive-skips when DataRegistry not resolving per FOLLOWUP-002)

**Test Evidence**: 20/20 PASS dedicated suite; 113/113 PASS across full hero-roster directory (93 unit + 20 integration); zero regressions in wider unit suite.

**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist) + GAPS-resolved (qa-tester — 3 production-safety items addressed). All 5 review findings applied inline:
- Added convention comment above `_suppress_signals` field declaring guard requirement for future emit sites.
- Added `push_warning` when saved formation_slots count exceeds current `formation_size()` (visible silent-truncation diagnostic).
- Strengthened `test_signals_resume_firing_after_load_save_data_returns` to actually fire a signal post-load and verify the spy receives it (guards against guard-stickiness regression).
- Added `test_post_load_add_hero_consumes_restored_next_instance_id` (TR-011 monotonic-id end-to-end via add_hero post-load).
- Added 3 defensive-load tests: float coercion (JSON round-trip), oversize-slots truncation, undersize-slots padding.

**Architectural notes**:
- `_suppress_signals` flag pattern is single-threaded GDScript safe (no `try/finally` needed; no `await` between toggle-on and toggle-off; no re-entrant call into guarded mutation API since `load_save_data` writes `_heroes` directly).
- ADR-0012 NOTE #5 explicitly permits the `_suppress_signals` naming substitution (story spec called it `_boot_validating`).
- ADR-0004 §Payload encoding uses UTF-8 JSON; `int()` coercion on formation_slots elements is correct defensive practice (not YAGNI).
- `SaveLoadSystem.CONSUMER_PATHS` already pre-populated at `/root/HeroRoster` index 1 from Sprint 4 — no SaveLoadSystem source changes required for this story.

**Tech debt**: none new. Pre-existing TD-009 (DataRegistry test-env defensive branches) still applies. The SaveLoadSystem-actually-invokes-consumer-methods integration smoke test is deferred to whichever future sprint wires the end-to-end save pipeline (out of scope for Story 006).

**Bugs decoded**: none new — `_resize_formation_slots()` reuse and `int()` defensive coercion both Just Worked.

**Sprint 6 progress**: 6/12 Must Have done (M1-M6, hero-roster Foundation epic complete through Story 006). 6 Must Have remain.
