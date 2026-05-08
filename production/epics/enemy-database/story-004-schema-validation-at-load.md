# Story 004: EnemyData schema validation at load time

> **Epic**: enemy-database
> **Status**: Complete (system shipped; see systems-index Implementation Status #7. Test evidence: `tests/{unit,integration}/enemy_database/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §C, §E (edge cases), §H-02, §H-08, §H-10
**Requirements**: TR-enemy-db-006, TR-enemy-db-014, TR-enemy-db-015, TR-enemy-db-018
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (per-resource validation contract), ADR-0006 (DataRegistry per-type validators trigger ERROR state below MIN_CONTENT_COUNT)
**ADR Decision Summary**: EnemyData implements `_validate() -> Array[String]` returning a list of human-readable schema violations. DataRegistry calls this per-resource at boot; non-empty result → resource rejected + push_error + count toward ERROR state threshold. Validation rules: required fields non-empty, `tier in {1, 2, 3}`, `archetype` member of `EnemyArchetypes.MVP_SET`, base stats > 0, exactly one is_boss=true across set.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: per-resource `_validate()` shape per ADR-0011. — ADR-0011 / ADR-0006
- **Required**: tier ∈ {1, 2, 3}; archetype ∈ EnemyArchetypes.MVP_SET. — ADR-0011
- **Required**: base_hp/base_attack/base_speed > 0. — ADR-0011
- **Required**: sprite_path + death_anim_key non-empty. — ADR-0011

---

## Acceptance Criteria

- [ ] EnemyData declares `_validate() -> Array[String]` method (empty array = OK)
- [ ] **TR-enemy-db-006 required fields**: `id`, `display_name`, `archetype`, `biome`, `sprite_path`, `death_anim_key` non-empty; `tier` ∈ {1, 2, 3}; `base_hp` / `base_attack` / `base_speed` > 0
- [ ] **AC H-02 archetype membership**: `archetype` is a member of `EnemyArchetypes.MVP_SET` (BRUISER / CASTER / ARMORED); else violation listed
- [ ] **AC H-10**: unknown archetype string at load → `push_error`, resource rejected/unregistered; below MIN_CONTENT_COUNT triggers ERROR state (DataRegistry)
- [ ] **TR-enemy-db-014 + TR-enemy-db-018**: HP within tier bands per GDD §D calibration; out-of-band advisory warning (not violation by default — decide at story pickup whether to elevate to violation)
- [ ] DataRegistry per-type validator hook (per ADR-0006) calls `_validate()` for each loaded EnemyData; non-empty result → resource rejected + `push_error("EnemyData[id]: [violations joined]")`
- [ ] A test fixture with 1 valid + 1 deliberately-malformed enemy produces: 1 resolvable id + 1 rejected id + ERROR state if MIN_CONTENT_COUNT requires both
- [ ] Set-level invariants (exactly one is_boss=true; tier-archetype distribution from Story 003) — validated by separate story-level smoke check, not per-resource `_validate()` (per-resource validates only its own fields)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §schema validation. Mirror the HeroClass validator pattern from hero-class-database epic Story 008 (S2-N2 / S3-N1 carryover).*

- Pseudocode:
  ```
  # On EnemyData:
  func _validate() -> Array[String]:
      var errors: Array[String] = []
      if id.is_empty():
          errors.append("id is empty")
      if display_name.is_empty():
          errors.append("display_name is empty")
      if not (tier == 1 or tier == 2 or tier == 3):
          errors.append("tier=%d not in {1, 2, 3}" % tier)
      if archetype not in EnemyArchetypes.MVP_SET:
          errors.append("archetype='%s' not in EnemyArchetypes.MVP_SET" % archetype)
      if biome.is_empty():
          errors.append("biome is empty")
      if base_hp <= 0 or base_attack <= 0 or base_speed <= 0:
          errors.append("base stats must all be > 0")
      if sprite_path.is_empty():
          errors.append("sprite_path is empty")
      if death_anim_key.is_empty():
          errors.append("death_anim_key is empty")
      return errors
  ```
- DataRegistry's per-type validator hookup (data-registry epic Story 005) is currently a no-op stub. The validation hookup may need to be extended in DataRegistry to dispatch to per-type `_validate()` methods. If extending DataRegistry is out of scope for Sprint 3, the test for this story can call `EnemyData._validate()` directly without going through DataRegistry; the integration with DataRegistry's `_validate_resource_fields` is a follow-on story (data-registry epic Story 008).
- HP-band validation is per GDD §D calibration: Tier-1 [50, 74]; Tier-2 [162, 242]; Tier-3 elite [540, 820]; boss = 4818 exact. Decision at story pickup: violation (hard) vs push_warning (soft). Recommend `push_warning` to keep authoring loose; designers can tune within the bands.

---

## Out of Scope

- Story 003: 7+ MVP enemy `.tres` content authoring (sibling)
- DataRegistry per-type validator dispatch infrastructure (data-registry epic Story 008)
- Set-level invariants like "exactly one is_boss=true" (covered by Story 003 smoke check)

---

## QA Test Cases

- **AC: valid enemy passes**
  - **Given**: real Hollow Brute `.tres` (Story 003)
  - **When**: `hollow_brute._validate()`
  - **Then**: returns empty array
  - **Edge cases**: each MVP enemy validates clean

- **AC: missing required field rejected**
  - **Given**: a fixture EnemyData with `id == ""`
  - **When**: `_validate()`
  - **Then**: returns array containing "id is empty"
  - **Edge cases**: separately test each required field — empty `display_name`, empty `archetype`, empty `biome`, empty `sprite_path`, empty `death_anim_key`

- **AC: tier out of range**
  - **Given**: fixture with `tier = 0` and `tier = 4`
  - **When**: `_validate()`
  - **Then**: each returns violation listing tier value
  - **Edge cases**: tier = -1 also rejected

- **AC H-02 + H-10: archetype membership**
  - **Given**: fixture with `archetype = "purple_dragon"` (V1.0 archetype outside MVP_SET)
  - **When**: `_validate()`
  - **Then**: violation listed; resource rejected by DataRegistry
  - **Edge cases**: each `MVP_SET` value passes; `BEAST` / `CONSTRUCT` / `INCORPOREAL` (V1.0) → rejected for MVP scope; case-mismatched ("BRUISER") → violation

- **AC: base stats positivity**
  - **Given**: fixture with `base_hp = 0`, `base_attack = -5`, etc.
  - **When**: `_validate()`
  - **Then**: violation per stat
  - **Edge cases**: all stats simultaneously non-positive surfaces single combined error

- **AC: DataRegistry rejects malformed resources at boot**
  - **Given**: fixture directory with 1 valid + 1 malformed `.tres`
  - **When**: DataRegistry boot scan completes
  - **Then**: only the valid resource resolvable; `push_error` logged with violation list; if valid count is below MIN_CONTENT_COUNT (e.g., 1 < 5), DataRegistry transitions to ERROR
  - **Edge cases**: pure-malformed directory → ERROR state at boot

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_database/enemy_data_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (EnemyData schema), data-registry epic Story 005 (per-type validator hookup — currently a no-op stub; story tests call `_validate()` directly OK)
- **Unlocks**: Production-readiness (validation is required for safe content authoring)
