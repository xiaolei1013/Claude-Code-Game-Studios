# Story 006: is_class_counter helper + counter_archetype validation

> **Epic**: hero-class-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-05, §H-06
**Requirements**: TR-hero-class-db-011
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011
**ADR Decision Summary**: `is_class_counter(class_data, enemy_archetype) -> bool` is a pure string-equality check on `class_data.counter_archetype` against the queried archetype. Case-sensitive. Empty string and unknown archetype both return false (no error).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Simple string equality.

**Control Manifest Rules (Core Layer)**:
- **Required**: pure string equality, case-sensitive. — ADR-0011
- **Forbidden**: matching with case-folding or fuzzy comparison. — ADR-0011

---

## Acceptance Criteria

- [ ] `is_class_counter(class_data: HeroClass, enemy_archetype: String) -> bool` declared
- [ ] **H-06 main path**: `is_class_counter(warrior, EnemyArchetypes.BRUISER)` returns `true` (Warrior counters Bruiser); `is_class_counter(warrior, EnemyArchetypes.CASTER)` returns `false`
- [ ] **H-06 empty string**: `is_class_counter(warrior, "")` returns `false` without error
- [ ] **H-06 unknown tag**: `is_class_counter(warrior, "purple_dragon")` returns `false` without error (no membership check enforced; pure equality only)
- [ ] **Case-sensitive**: `is_class_counter(warrior, "BRUISER")` returns `false` (uppercase mismatch)
- [ ] Null `class_data` → `push_error`; returns `false`
- [ ] Function reads only `class_data.counter_archetype`; no other field access (verified by code review or grep)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §is_class_counter:*

- Pseudocode:
  ```
  func is_class_counter(class_data: HeroClass, enemy_archetype: String) -> bool:
      if class_data == null:
          push_error("is_class_counter: class_data is null")
          return false
      return class_data.counter_archetype == enemy_archetype
  ```
- Three-line implementation. The validation rigor in the AC is intentional: this function is hit per-tick in matchup-resolver code paths, so it must be tight.
- DO NOT add membership checks against `EnemyArchetypes.ALL` here — those belong in load-time schema validation (Story 008). Runtime calls accept any string and return false for non-matches.

---

## Out of Scope

- Story 008: load-time validation that `class.counter_archetype` is in `EnemyArchetypes.ALL`
- ClassEnemyMatchupResolver (Feature epic) — consumes this helper but is its own system

---

## QA Test Cases

- **AC H-06: main path**
  - **Given**: Warrior with `counter_archetype == EnemyArchetypes.BRUISER == "bruiser"`
  - **When**: `is_class_counter(warrior, "bruiser")` and `is_class_counter(warrior, "caster")`
  - **Then**: first returns `true`; second returns `false`
  - **Edge cases**: also test mage→caster, rogue→armored

- **AC H-06: empty string + unknown tag**
  - **Given**: any class
  - **When**: `is_class_counter(class, "")`, `is_class_counter(class, "nonexistent_archetype")`
  - **Then**: both return `false` without error or warning
  - **Edge cases**: very long string; whitespace-only string

- **AC: case sensitivity**
  - **Given**: Warrior with counter_archetype="bruiser"
  - **When**: `is_class_counter(warrior, "BRUISER")`, `is_class_counter(warrior, "Bruiser")`, `is_class_counter(warrior, " bruiser ")`
  - **Then**: all return `false`
  - **Edge cases**: trailing whitespace in input is treated as a real character (no trim)

- **AC: null class_data**
  - **Given**: any state
  - **When**: `is_class_counter(null, "bruiser")`
  - **Then**: `push_error`; returns `false`
  - **Edge cases**: ensures no null-deref crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/is_class_counter_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroClass schema), Story 003 (real class data for assertions)
- **Unlocks**: ClassEnemyMatchupResolver Feature epic
