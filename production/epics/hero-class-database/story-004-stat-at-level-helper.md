# Story 004: stat_at_level helper + L15 sanity + level clamp + invalid-input fallback

> **Epic**: hero-class-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-02, §H-03, §H-04, §D
**Requirements**: TR-hero-class-db-009, TR-hero-class-db-010
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (helper method specification + integer arithmetic discipline)
**ADR Decision Summary**: `stat_at_level(stat_name, class_data, level) -> int` returns `base + per_level × (level - 1)` using integer arithmetic. Clamps level to `[1, LEVEL_CAP=15]`: above-cap silent clamp; below-1 fires `push_error` and returns L1 stats as safe fallback.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Standard integer arithmetic.

**Control Manifest Rules (Core Layer)**:
- **Required**: integer arithmetic only (no float intermediate). — ADR-0011
- **Required**: clamp `level` to `[1, LEVEL_CAP]`. — ADR-0011

---

## Acceptance Criteria

- [ ] `stat_at_level(stat_name: String, class_data: HeroClass, level: int) -> int` declared as a static helper on HeroClassDatabase OR as a free function on HeroClass (decide when picked up — recommend HeroClass instance method)
- [ ] **H-02**: For all 9 (stat × class) sub-cases at L15, returns exactly the §D.4 sanity table value: Warrior L15 (attack=40, hp=358, speed=20), Mage L15 (attack=62, hp=210, speed=24), Rogue L15 (attack=42, hp=167, speed=44)
- [ ] **Formula**: result = `class_data["base_" + stat] + class_data[stat + "_per_level"] * (clamp(level, 1, LEVEL_CAP) - 1)` using integer arithmetic
- [ ] **H-03 silent clamp at cap**: `stat_at_level("attack", warrior, 16)`, `stat_at_level("attack", warrior, 100)` both return same value as L15; no error logged
- [ ] **H-04 invalid level fallback**: `stat_at_level("attack", warrior, 0)`, `stat_at_level("attack", warrior, -5)` → `push_error` with the invalid value; returns L1 stats (= base attack) as safe fallback; no crash
- [ ] Unknown stat name → `push_error("HeroClass.stat_at_level: stat_name='X' unknown")`; returns 0
- [ ] Null `class_data` → `push_error`; returns 0

---

## Implementation Notes

*Derived from ADR-0011 §Decision §stat helpers:*

- Pseudocode (HeroClass instance method):
  ```
  # On HeroClass:
  func stat_at_level(stat_name: String, level: int) -> int:
      const VALID_STATS := ["attack", "hp", "speed"]
      if stat_name not in VALID_STATS:
          push_error("HeroClass.stat_at_level: stat_name='%s' unknown" % stat_name)
          return 0
      var clamped_level := level
      if level < 1:
          push_error("HeroClass.stat_at_level: level=%d invalid; clamping to 1" % level)
          clamped_level = 1
      elif level > LEVEL_CAP:
          clamped_level = LEVEL_CAP  # silent clamp
      var base: int = get("base_" + stat_name)
      var per_level: int = get(stat_name + "_per_level")
      return base + per_level * (clamped_level - 1)
  ```
- LEVEL_CAP = 15 (from EconomyConfig — but consider declaring a parallel `HeroClass.LEVEL_CAP` constant to avoid coupling to Economy. Recommend reading from EconomyConfig if available, else use a hardcoded constant `const LEVEL_CAP := 15` matching the contract).
- Use `get(property_name)` for dynamic property access (Godot 4.6 supports this on Resource).

---

## Out of Scope

- Story 005: hero_tick_output (sibling helper, separate concern)
- Story 006: is_class_counter
- Cross-class stat balance tuning (lives in GDD)

---

## QA Test Cases

- **AC H-02: L15 sanity table (parameterized 9 sub-cases)**
  - **Given**: Warrior, Mage, Rogue HeroClass loaded with §D.4 base + per_level values
  - **When**: `stat_at_level(stat, class, 15)` for stat ∈ {"attack","hp","speed"} and class ∈ {warrior,mage,rogue}
  - **Then**: 9 assertions pass against the L15 sanity table
  - **Edge cases**: also verify L1 (= base value), L8 (mid-range)

- **AC H-03: silent clamp at cap**
  - **Given**: Warrior with attack base=12, per_level=2 (L15=40)
  - **When**: `stat_at_level("attack", warrior, 16)`, `stat_at_level("attack", warrior, 100)`
  - **Then**: both return 40; no `push_error` fired; no `push_warning` fired
  - **Edge cases**: L15 itself is the boundary — must return 40 not 38 (off-by-one check)

- **AC H-04: invalid-level fallback**
  - **Given**: any class
  - **When**: `stat_at_level("attack", warrior, 0)`, `stat_at_level("attack", warrior, -5)`
  - **Then**: `push_error` fires; returns L1 stats (= base attack value); function does not crash
  - **Edge cases**: `INT64_MIN` should not crash

- **AC: unknown stat**
  - **Given**: any class, level 5
  - **When**: `stat_at_level("nonexistent_stat", warrior, 5)`
  - **Then**: `push_error`; returns 0
  - **Edge cases**: empty string handled

- **AC: null class_data**
  - **Given**: any state
  - **When**: `stat_at_level("attack", null, 5)` (if free function) or method called on a null reference
  - **Then**: `push_error`; returns 0; no crash
  - **Edge cases**: instance-method form may not be reachable with null `self` — document the design choice

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/stat_at_level_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroClass schema), Story 003 (real `.tres` data for the L15 sanity table assertions)
- **Unlocks**: HeroLeveling Feature epic, Combat Feature epic
