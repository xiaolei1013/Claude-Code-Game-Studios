# Story 008: HeroClass schema validation at load time

> **Epic**: hero-class-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §C, §E
**Requirements**: TR-hero-class-db-008, TR-hero-class-db-022, TR-hero-class-db-024
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (per-resource validation contract) + ADR-0006 (DataRegistry per-type validators trigger ERROR state below MIN_CONTENT_COUNT)
**ADR Decision Summary**: HeroClass implements `_validate() -> Array[String]` returning a list of human-readable schema violations. DataRegistry calls this per-resource at boot; non-empty result → resource rejected + push_error + count toward ERROR state threshold. Validation rules: required fields non-empty, `tier in [1, 2]`, `counter_archetype` member of `EnemyArchetypes.ALL`, `role` validated as String (push_warning on unrecognized; not fatal), duplicate counter_archetype across classes is permitted.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: per-resource `_validate()` shape per ADR-0011. — ADR-0011 / ADR-0006
- **Required**: tier ∈ {1, 2}; counter_archetype ∈ EnemyArchetypes.ALL. — ADR-0011
- **Required**: role taxonomy validated as String; unrecognized role is `push_warning` not `push_error`. — ADR-0011
- **Permitted**: duplicate counter_archetype across classes (no load-time uniqueness enforcement at the validation layer; AC H-05's MVP-set uniqueness is a content invariant, enforced by Story 003). — ADR-0011

---

## Acceptance Criteria

- [ ] HeroClass declares `_validate() -> Array[String]` method returning a list of violation strings (empty array = OK)
- [ ] **TR-hero-class-db-008 required fields**: `id`, `display_name`, `counter_archetype`, `role` non-empty; `base_attack`, `base_hp`, `base_speed` ≥ 0; `tier` ∈ {1, 2}
- [ ] **TR-hero-class-db-008 archetype membership**: `counter_archetype` is a member of `EnemyArchetypes.ALL` (BRUISER, CASTER, ARMORED, BEAST, CONSTRUCT, INCORPOREAL); else violation listed
- [ ] **TR-hero-class-db-022 role taxonomy**: `role` is non-empty String; unrecognized value (any role string outside an allowlist if defined) triggers `push_warning` at validate time, NOT a violation; the resource still loads
- [ ] **TR-hero-class-db-024 duplicate-archetype permitted**: two classes with the same counter_archetype both validate OK (no load-time uniqueness enforcement)
- [ ] DataRegistry per-type validator (per ADR-0006) calls `_validate()` for each loaded HeroClass; non-empty result → resource rejected (not added to registry) + `push_error("HeroClass[id]: [violations joined]")`
- [ ] Below MIN_CONTENT_COUNT (data-registry epic constant) → DataRegistry transitions to ERROR state (already implemented per Story 005 of data-registry)
- [ ] A test fixture with 1 valid + 1 deliberately-malformed class produces: 1 resolvable id + 1 rejected id + ERROR state if MIN_CONTENT_COUNT requires both

---

## Implementation Notes

*Derived from ADR-0011 §Decision §schema validation + ADR-0006 §per-type validator hookup:*

- Pseudocode:
  ```
  # On HeroClass:
  func _validate() -> Array[String]:
      var errors: Array[String] = []
      if id.is_empty():
          errors.append("id is empty")
      if display_name.is_empty():
          errors.append("display_name is empty")
      if not (tier == 1 or tier == 2):
          errors.append("tier=%d not in {1, 2}" % tier)
      if counter_archetype not in EnemyArchetypes.ALL:
          errors.append("counter_archetype='%s' not in EnemyArchetypes.ALL" % counter_archetype)
      if base_attack < 0 or base_hp < 0 or base_speed < 0:
          errors.append("base stats must be >= 0")
      if role.is_empty():
          errors.append("role is empty")
      else:
          # Soft validation — warn but don't fail
          const KNOWN_ROLES := ["frontline", "ranged_dps", "flanker", "support", "tank", "healer"]
          if role not in KNOWN_ROLES:
              push_warning("HeroClass[%s]: role='%s' not in known taxonomy" % [id, role])
      return errors
  ```
- DataRegistry's per-type validator hookup (data-registry epic Story 005) calls `_validate()` per loaded resource. This story's contribution is the HeroClass-side `_validate()` body.
- The KNOWN_ROLES allowlist is informational, not authoritative. If a designer adds a new role string, that's permitted with a warning — encourages forward extension without breaking boot.

---

## Out of Scope

- Story 010: flavor_text length advisory (separate Config/Data validation)
- DataRegistry per-type validator infrastructure (data-registry epic Story 005, already implemented Sprint 1)
- AC H-05's MVP set uniqueness (content invariant in Story 003, not a runtime validator concern)

---

## QA Test Cases

- **AC: valid class passes**
  - **Given**: real Warrior `.tres` (Story 003)
  - **When**: `warrior._validate()`
  - **Then**: returns empty array
  - **Edge cases**: each MVP class validates clean

- **AC: missing required field rejected**
  - **Given**: a fixture HeroClass with `id == ""`
  - **When**: `_validate()`
  - **Then**: returns array containing "id is empty"
  - **Edge cases**: separately test each required field — empty `display_name`, empty `counter_archetype`, empty `role`

- **AC: tier out of range**
  - **Given**: fixture with `tier = 0` and `tier = 99`
  - **When**: `_validate()`
  - **Then**: each returns violation listing tier value
  - **Edge cases**: tier = -1 also rejected

- **AC: archetype membership**
  - **Given**: fixture with `counter_archetype = "purple_dragon"`
  - **When**: `_validate()`
  - **Then**: violation listed; resource rejected by DataRegistry
  - **Edge cases**: each EnemyArchetypes.ALL value passes; case-mismatched ("BRUISER") fails

- **AC: role soft-validation**
  - **Given**: fixture with `role = "spelunker"` (unknown but non-empty)
  - **When**: `_validate()`
  - **Then**: returns empty errors array (validation passes); `push_warning` fired with the unrecognized role
  - **Edge cases**: empty role string is a hard error (separate AC)

- **AC: duplicate counter_archetype permitted**
  - **Given**: two fixture classes both with `counter_archetype = "bruiser"`
  - **When**: each `_validate()` runs in isolation
  - **Then**: both return empty arrays; both load
  - **Edge cases**: this property is what enables Tier-2 classes to share archetypes with Tier-1 in V1.0+

- **AC: DataRegistry rejects malformed resources**
  - **Given**: fixture directory with 1 valid + 1 malformed `.tres`
  - **When**: DataRegistry boot scan completes
  - **Then**: only the valid resource resolvable; `push_error` logged for the malformed one with the violation list; if the valid count is below MIN_CONTENT_COUNT (e.g., 1 < 3), DataRegistry transitions to ERROR
  - **Edge cases**: pure-malformed directory (zero valid resources) → ERROR state at boot

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/hero_class_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroClass schema), data-registry epic Story 005 (per-type validator hookup)
- **Unlocks**: Production-readiness (validation is required for safe content authoring)
