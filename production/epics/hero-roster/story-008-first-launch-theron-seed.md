# Story 008: First-launch Theron seed

> **Epic**: hero-roster
> **Status**: Complete (system shipped; see systems-index Implementation Status #9. Test evidence: `tests/{unit,integration}/hero_roster/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-020, TR-hero-roster-021

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: On first-launch (no save exists), `seed_first_launch_state()` creates a single Warrior hero with `instance_id=1`, `display_name="Theron"`, `current_level=1`, places in formation slot 0, and emits `hero_recruited` (the ONLY mutation signal allowed during first-launch seed — the player's first hero deserves a HUD reaction). The seed name "Theron" is a HARDCODED constant — NOT drawn from the random name pool — for QA reproducibility across reinstalls. SaveLoadSystem invokes this method when no save file exists.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: First-launch seed creates exactly 1 Warrior at id=1 in slot 0. — TR-020
- **Required**: Seed display_name is hardcoded "Theron" — NOT from random pool. — TR-021
- **Required**: hero_recruited signal fires for the seed (NOT suppressed).

---

## Acceptance Criteria

- [ ] TR-hero-roster-020: `seed_first_launch_state()` creates Warrior at instance_id=1, display_name="Theron", current_level=1, in formation slot 0
- [ ] TR-hero-roster-020: emits `hero_recruited(instance)` exactly once
- [ ] TR-hero-roster-021: "Theron" is a hardcoded constant; reinstalls always see the same name (deterministic for QA)

---

## Implementation Notes

```gdscript
const SEED_HERO_CLASS_ID: String = "warrior"
const SEED_HERO_NAME: String = "Theron"  # HARDCODED — NOT from name pool (TR-021)
const SEED_HERO_INSTANCE_ID: int = 1
const SEED_FORMATION_SLOT: int = 0

func seed_first_launch_state() -> void:
    if _heroes.size() > 0:
        push_warning("[HeroRoster] seed_first_launch_state called on non-empty roster; refusing")
        return
    var class_data: Resource = DataRegistry.resolve("classes", SEED_HERO_CLASS_ID)
    if class_data == null:
        push_error("[HeroRoster] seed_first_launch_state: warrior class not registered in DataRegistry")
        return
    var instance: HeroInstance = HeroInstance.new()
    instance.instance_id = SEED_HERO_INSTANCE_ID
    instance.class_id = SEED_HERO_CLASS_ID
    instance.display_name = SEED_HERO_NAME
    instance.current_level = 1
    instance.xp = 0
    _heroes[instance.instance_id] = instance
    _next_instance_id = SEED_HERO_INSTANCE_ID + 1
    _formation_slots[SEED_FORMATION_SLOT] = SEED_HERO_INSTANCE_ID
    # IMPORTANT: signals are NOT suppressed for first-launch seed (TR-020 requires emission)
    hero_recruited.emit(instance)
```

SaveLoadSystem invokes `HeroRoster.seed_first_launch_state()` when its first-launch detection (Sprint 4) signals no existing save. The seed name bypasses the random name pool (Story 009) — `_generate_name` is NOT called.

Note: this seed pattern bypasses `add_hero()` because `add_hero` would assign a random name from the pool. Direct field assignment is the canonical seed path per ADR-0012 §First-launch.

---

## Out of Scope

- Story 009: name pool generation (for non-seed heroes); seed name "Theron" intentionally bypasses
- Story 007: load_save_data validation (first-launch never goes through load_save_data)
- SaveLoadSystem first-launch detection (Sprint 4 territory; this story trusts the call site)

---

## QA Test Cases

- **AC TR-020 single hero**: seed creates exactly 1 hero
  - Given: empty HeroRoster; DataRegistry has "warrior" class
  - When: `seed_first_launch_state()` called
  - Then: _heroes.size() == 1; _heroes[1].class_id == "warrior"; _heroes[1].current_level == 1
- **AC TR-020 instance_id**: seeded hero has instance_id=1
  - Then: _heroes.has(1); _next_instance_id == 2
- **AC TR-020 formation slot**: hero placed in slot 0
  - Then: _formation_slots == [1, 0, 0]
- **AC TR-020 signal**: hero_recruited fires exactly once
  - Given: signal spy connected
  - When: seed
  - Then: spy received exactly 1 emission
- **AC TR-021 deterministic name**: name is "Theron" exactly
  - Then: _heroes[1].display_name == "Theron" (string equality, NOT regex match)
- **AC TR-021 reinstall reproducibility**: 2 fresh seeds produce identical state
  - Given: 2 fresh HeroRoster instances
  - When: each seeds
  - Then: instance_a._heroes[1].display_name == instance_b._heroes[1].display_name (both "Theron")
- **AC seed safety**: refuses on non-empty roster
  - Given: HeroRoster with hero added
  - When: seed_first_launch_state called
  - Then: push_warning logged; _heroes unchanged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_roster/first_launch_seed_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroInstance), Story 002 (HeroRoster skeleton), Story 004 (hero_recruited signal). DataRegistry from Sprint 1 + warrior class .tres from Sprint 2.
- **Unlocks**: end-to-end first-launch flow when SaveLoadSystem is wired to invoke this seed.
