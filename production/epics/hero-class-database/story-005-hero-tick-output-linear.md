# Story 005: hero_tick_output linear formula

> **Epic**: hero-class-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-08, §D
**Requirements**: TR-hero-class-db-012, TR-hero-class-db-021
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011
**ADR Decision Summary**: `hero_tick_output(class_data, level) -> int = tick_output_contribution_l1 + tick_output_per_level × (level - 1)`. Linear scaling — distinguishable from Economy's geometric cost curves. No compounding.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Standard integer arithmetic.

**Control Manifest Rules (Core Layer)**:
- **Required**: linear scaling only (no compounding); per-level delta is constant. — ADR-0011

---

## Acceptance Criteria

- [ ] `hero_tick_output(class_data: HeroClass, level: int) -> int` declared (free function or HeroClass instance method — match Story 004's choice)
- [ ] **H-08**: `hero_tick_output(class, L)` for L = 1..15 returns `tick_output_contribution_l1 + tick_output_per_level × (L - 1)`
- [ ] Per-level delta verification: `hero_tick_output(class, L+1) - hero_tick_output(class, L) == tick_output_per_level` for ALL L = 1..14 (constant delta = no compounding)
- [ ] Distinguishability: for any class, the (level → tick_output) curve is linear, NOT exponential / geometric (test by checking second-order delta is zero)
- [ ] Level clamp behavior matches Story 004: `level > LEVEL_CAP` silent clamp; `level < 1` push_error + L1 fallback
- [ ] Null class_data → push_error; returns 0

---

## Implementation Notes

*Derived from ADR-0011 §Decision §tick_output:*

- Pseudocode:
  ```
  func hero_tick_output(class_data: HeroClass, level: int) -> int:
      if class_data == null:
          push_error("hero_tick_output: class_data is null")
          return 0
      var clamped_level := clamp(level, 1, LEVEL_CAP)
      if level < 1:
          push_error("hero_tick_output: level=%d invalid; using L1" % level)
      return class_data.tick_output_contribution_l1 + class_data.tick_output_per_level * (clamped_level - 1)
  ```
- LEVEL_CAP same as Story 004 (15).
- Linear not geometric: an Economy-like 1.6× ratio would test fail this story's distinguishability AC — that's the point. This is per-tick combat output, which is a different gameplay knob from cost curves.

---

## Out of Scope

- Story 004: stat_at_level (sibling helper)
- Story 006: is_class_counter
- Combat resolver consumption of `hero_tick_output` (Feature epic)

---

## QA Test Cases

- **AC H-08: linear scaling for each MVP class**
  - **Given**: each MVP class with `tick_output_contribution_l1` and `tick_output_per_level` from §D
  - **When**: `hero_tick_output(class, L)` for L = 1..15
  - **Then**: each value matches the closed-form formula; deltas between consecutive levels are constant
  - **Edge cases**: L=1 returns `tick_output_contribution_l1` exactly (i.e., no `* 0` weirdness); L=15 returns the cap value

- **AC: linear-not-geometric distinguishability**
  - **Given**: any class
  - **When**: compute `Δ_L = hero_tick_output(L+1) - hero_tick_output(L)` for L = 1..14
  - **Then**: all 14 deltas are equal (variance == 0); equals `tick_output_per_level`
  - **Edge cases**: a buggy geometric implementation (`base * ratio^level`) would fail this assertion — that's the regression guard

- **AC: clamp behavior matches Story 004**
  - **Given**: any class
  - **When**: `hero_tick_output(class, 16)`, `hero_tick_output(class, -5)`
  - **Then**: 16 returns same as 15 (silent clamp); -5 returns L1 with push_error
  - **Edge cases**: 0 → push_error + L1; 100 → silent clamp to 15

- **AC: null class_data**
  - **Given**: any state
  - **When**: `hero_tick_output(null, 5)`
  - **Then**: push_error; returns 0; no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/hero_tick_output_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001, Story 003 (`.tres` data with tick_output fields populated)
- **Unlocks**: Combat Feature epic; Economy drip math (already covered by `formation_strength` aggregation but Combat may consume per-hero tick_output)
