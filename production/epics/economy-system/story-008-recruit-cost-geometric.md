# Story 008: recruit_cost geometric formula (1.8× per copy)

> **Epic**: economy-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #5. Test evidence: `tests/unit/economy/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-07, §D.3
**Requirements**: TR-economy-008 (recruit_cost formula + RECRUIT_RATIO=1.8)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0013 (`recruit_cost(class_id, copies_owned)` signature) + ADR-0011 (HeroClass.tier resolution via DataRegistry)
**ADR Decision Summary**: `recruit_cost(class_id: String, copies_owned: int) -> int = floor(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)`. Caller passes class_id String; Economy resolves tier internally via `DataRegistry.resolve("classes", class_id).tier`. Pure read; no state mutation.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `pow()` returns float; `floori()` truncates; integer arithmetic discipline.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: pure-read query; no state mutation. — ADR-0013
- **Required**: tier resolved via DataRegistry per ADR-0011, NOT via per-class cost overrides (TR-hero-class-db-019). — ADR-0011 / ADR-0013
- **Forbidden**: hardcoded BASE_RECRUIT values in `economy.gd` (lives in `economy_config.tres`). — ADR-0013

---

## Acceptance Criteria

- [ ] **H-07**: GIVEN Tier-1 class with `BASE_RECRUIT[1] = 150`, `RECRUIT_RATIO = 1.8`, copies_owned N (N ∈ {0,1,2,3}), WHEN `recruit_cost(class_id, N+1's-purchase)` queried, THEN cost = `floori(150 × 1.8^N)`: N=0 → 150, N=1 → 270, N=2 → 486, N=3 → 874
- [ ] Ratio invariant: `cost(N+1) / cost(N) ≈ 1.8` within integer rounding (verified for N = 0..3 as independent sub-cases)
- [ ] Tier resolution: invalid `class_id` (no resolve match) → `push_error("Economy.recruit_cost: class_id='X' not in DataRegistry")`; returns `-1` sentinel
- [ ] `copies_owned < 0` → `push_error`; returns `-1`
- [ ] Pure-read: no state mutation, no signals, no side effects
- [ ] Tier coverage: BASE_RECRUIT keys exhaustive for tiers 1, 2 (MVP — Tier-3 enemies exist but no Tier-3 recruitable classes per `hero-class-database.md`)

---

## Implementation Notes

*Derived from ADR-0013 §Decision §recruit_cost:*

- Pseudocode:
  ```
  func recruit_cost(class_id: String, copies_owned: int) -> int:
      if copies_owned < 0:
          push_error("Economy.recruit_cost: copies_owned=%d must be non-negative" % copies_owned)
          return -1
      var hero_class: HeroClass = DataRegistry.resolve("classes", class_id)
      if hero_class == null:
          push_error("Economy.recruit_cost: class_id='%s' not in DataRegistry" % class_id)
          return -1
      var tier: int = hero_class.tier
      if not EconomyConfig.BASE_RECRUIT.has(tier):
          push_error("Economy.recruit_cost: tier=%d has no BASE_RECRUIT entry" % tier)
          return -1
      var base: int = EconomyConfig.BASE_RECRUIT[tier]
      return floori(base * pow(EconomyConfig.RECRUIT_RATIO, copies_owned))
  ```
- `pow(1.8, 0) == 1.0` exactly per IEEE-754; `floori(150 × 1.0) = 150` ✓.
- For very large `copies_owned` (e.g., > 30), `pow` may produce values exceeding `int64`. The cost would saturate. Document but do NOT add explicit overflow handling (Pillar 1: keep code simple; in MVP scope, copies_owned never exceeds ~10).
- Caller (Recruitment Feature epic) typically queries `recruit_cost(class_id, roster.get_copies_owned(class_id))` then passes the result to `try_spend(cost, "recruit:" + class_id)`.

---

## Out of Scope

- Story 004: `try_spend` (the eventual deduction)
- Recruitment system (Feature epic) — chains query → spend → roster.add_hero
- Hero leveling cost — covered by Story 009

---

## QA Test Cases

- **AC H-07: ratio invariant for Tier-1**
  - **Given**: EconomyConfig with `BASE_RECRUIT[1] == 150`, `RECRUIT_RATIO == 1.8`; DataRegistry resolves `"warrior"` to a Tier-1 HeroClass
  - **When**: `recruit_cost("warrior", N)` called for N = 0, 1, 2, 3
  - **Then**: returns `[150, 270, 486, 874]` (each `floori(150 × 1.8^N)`)
  - **Edge cases**: N=4 → `floori(150 × 1.8^4) = floori(1574.64) = 1574`; N=10 → `floori(150 × 357.04...) = ...` (compute and assert exact integer)

- **AC: invalid class_id**
  - **Given**: `class_id = "nonexistent"`
  - **When**: `recruit_cost("nonexistent", 0)`
  - **Then**: `push_error`; returns `-1`
  - **Edge cases**: empty string, `null`-like sentinel

- **AC: negative copies_owned**
  - **Given**: any state
  - **When**: `recruit_cost("warrior", -1)`
  - **Then**: `push_error`; returns `-1`
  - **Edge cases**: very negative `INT64_MIN` should not crash

- **AC: pure-read**
  - **Given**: arbitrary state, including `_gold_balance = 100`
  - **When**: `recruit_cost("warrior", 5)` called 100 times
  - **Then**: `_gold_balance` unchanged; no `gold_changed` emissions; no other signal emissions
  - **Edge cases**: cost query result is consistent (deterministic) across repeated calls

- **AC: tier resolution via DataRegistry (not hardcoded)**
  - **Given**: a fresh test class fixture with non-default tier
  - **When**: `recruit_cost(test_class_id, 0)`
  - **Then**: returned cost reflects `BASE_RECRUIT[fixture.tier]`, NOT a hardcoded value
  - **Edge cases**: tier 2 class → uses `BASE_RECRUIT[2]`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_recruit_cost_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload), Story 002 (EconomyConfig.BASE_RECRUIT + RECRUIT_RATIO), data-registry epic Story 004 (`resolve` API), hero-class-database epic Story 001 (HeroClass.tier field)
- **Unlocks**: Story 009 (level_cost — sibling formula); Recruitment Feature epic
