# Story 002: HeroRoster autoload skeleton + state fields + encapsulation

> **Epic**: hero-roster
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-005, TR-hero-roster-007, TR-hero-roster-011, TR-hero-roster-028
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0012 (primary) + ADR-0003 (autoload registration; zero-arg `_init` per Amendment #3)
**ADR Decision Summary**: HeroRoster is `extends Node` (NO `class_name` per Sprint 1 autoload lessons). State: `_heroes: Dictionary` keyed by `instance_id: int` → `HeroInstance`; `_formation_slots: Array[int]` (size FORMATION_SIZE, 0 = empty); `_next_instance_id: int` (monotonic, never reused). Underscore-private encapsulation enforced at code review. Add to `[autoload]` after SaveLoadSystem (rank > 2 per ADR-0003 + ADR-0004 CONSUMER_PATHS ordering).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload pattern stable since 4.0. Typed `Dictionary[int, HeroInstance]` works in 4.6.

**Control Manifest Rules (Feature Layer, HeroRoster)**:
- **Required**: `extends Node` autoload; no `class_name` (would conflict with autoload identifier). — ADR-0003
- **Required**: `_heroes`, `_formation_slots`, `_next_instance_id` underscore-private. — ADR-0012 / TR-028
- **Required**: `instance_id` is monotonic positive int; `_next_instance_id` only increments. — TR-011
- **Required**: zero-arg `_init` per ADR-0003 Amendment #3.

---

## Acceptance Criteria

- [ ] TR-hero-roster-005: HeroRoster is `extends Node`; `_heroes: Dictionary` keyed by instance_id (int) → HeroInstance
- [ ] TR-hero-roster-007: `_formation_slots: Array[int]` size = FORMATION_SIZE; elements are instance_id or 0 (empty)
- [ ] TR-hero-roster-011: `_next_instance_id: int` is monotonic positive (starts at 1); never reused after remove
- [ ] TR-hero-roster-028: `_heroes`, `_formation_slots`, `_next_instance_id` underscore-private (no external read/write)

---

## Implementation Notes

```gdscript
# src/core/hero_roster/hero_roster.gd
extends Node

const FORMATION_SIZE: int = 3   # From roster_config.tres in Story 003 (this story uses constant)
const MAX_ROSTER_SIZE: int = 30 # ditto
const LEVEL_CAP: int = 15

var _heroes: Dictionary = {}                            # int -> HeroInstance
var _formation_slots: Array[int] = [0, 0, 0]             # 0 = empty slot
var _next_instance_id: int = 1                          # monotonic, never reused
var _orphaned_heroes: Array = []                         # session-only; Story 007

signal hero_recruited(instance: HeroInstance)
signal hero_leveled(instance_id: int, old_level: int, new_level: int)
signal hero_removed(instance_id: int, class_id: String, display_name: String)

func _init() -> void:
    pass  # Zero required params per ADR-0003 Amendment #3

func _ready() -> void:
    pass  # Story 006 connects SaveLoadSystem signals
```

Register in `project.godot` after SaveLoadSystem. Concrete rank determined at story implementation per ADR-0003 §Editing Protocol (claim a vacant slot).

---

## Out of Scope

- Story 004: `add_hero` body + signal emission
- Story 005: mutation methods (`set_hero_level`, `set_formation_slot`)
- Story 006: `get_save_data` / `load_save_data` bodies
- Constants from roster_config.tres (Story 003 wires the resource)

---

## QA Test Cases

- **AC TR-005**: autoload reachable
  - Given: project booted
  - When: `get_tree().root.get_node_or_null("HeroRoster")` queried
  - Then: returns non-null Node; script attached
- **AC TR-005**: `_heroes` is Dictionary
  - Given: fresh HeroRoster
  - When: `_heroes` field accessed
  - Then: type is Dictionary; size is 0 at boot
- **AC TR-007**: formation slots array
  - Given: fresh HeroRoster
  - When: `_formation_slots` accessed
  - Then: `Array[int]` with size 3; all elements are 0 (empty)
- **AC TR-011**: `_next_instance_id` starts at 1
  - Given: fresh HeroRoster
  - When: `_next_instance_id` accessed
  - Then: equals 1; type is int
- **AC TR-028**: zero-arg `_init`
  - Given: HeroRoster script loaded
  - When: `script.new()` invoked with no args (non-autoload context)
  - Then: instance created without "Method expected N arguments" error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_roster/hero_roster_autoload_skeleton_test.gd`
**Status**: [x] Created — `tests/unit/hero_roster/hero_roster_autoload_skeleton_test.gd` (12/12 PASS)

---

## Dependencies

- **Depends on**: Story 001 (HeroInstance type referenced in `_heroes` Dictionary value type)
- **Unlocks**: Stories 003-010 (all subsequent HeroRoster work)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 4/4 passing (TR-005, TR-007, TR-011, TR-028 all verified)
**Files**:
- `src/core/hero_roster/hero_roster.gd` — autoload skeleton (~135 lines)
- `tests/unit/hero_roster/hero_roster_autoload_skeleton_test.gd` — 12 tests
- `project.godot` — `HeroRoster` registered between `BiomeDungeonDatabase` and `SceneManager` (rank 7)
**Test Evidence**: 12/12 PASS — all 6 groups (A through F) green, including new constants regression canary.
**Code Review**: APPROVED (godot-gdscript-specialist) + GAPS-cleared (qa-tester GAP-1 addressed inline; GAP-2/GAP-3 deferred as advisory).
**Deviations**: signal `hero_recruited` typed as `RefCounted` not `HeroInstance` (defensive against autoload class-registry parse-order; can tighten to `HeroInstance` in Story 004 when first emitted).
**Tech debt**: none logged. F-02 rank-order test position-sensitivity (qa-tester GAP-3) noted as forward-risk to revisit when DungeonRunOrchestrator autoload is added.
