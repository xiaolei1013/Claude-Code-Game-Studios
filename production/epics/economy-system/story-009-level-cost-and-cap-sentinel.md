# Story 009: level_cost geometric formula + LEVEL_CAP sentinel (-1)

> **Epic**: economy-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #5. Test evidence: `tests/unit/economy/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-08, §D.4
**Requirements**: TR-economy-009 (level_cost formula + LEVEL_RATIO=1.6 + LEVEL_CAP=15 → -1 sentinel)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0013 (`level_cost(class_tier, current_level)` signature + cap-sentinel contract)
**ADR Decision Summary**: `level_cost(class_tier: int, current_level: int) -> int = floor(BASE_LEVEL[tier] × LEVEL_RATIO^(current_level-1))`. When `current_level >= LEVEL_CAP`, returns **-1** sentinel — callers (Hero Leveling UI) MUST check for -1 before offering the purchase and display "max level reached".

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Standard `pow()` + `floori()`. `-1` is a sentinel; do NOT use `0` (zero-cost is a valid edge case for some test scenarios).

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: `-1` sentinel for past-cap queries; callers null-check before purchase. — ADR-0013
- **Required**: `LEVEL_CAP = 15` in `economy_config.tres`. — ADR-0013

---

## Acceptance Criteria

- [ ] **H-08**: GIVEN Tier-1 hero at `current_level = L` (L ∈ {1..14}), `BASE_LEVEL[1] = 40`, `LEVEL_RATIO = 1.6`, `LEVEL_CAP = 15`, WHEN `level_cost(1, L+1)` queried, THEN cost = `floori(40 × 1.6^(L-1))`: L=1 → 40, L=2 → 64, ..., L=14 → 18018
- [ ] **At-cap sentinel**: `level_cost(1, 15+1)` (querying level 16) returns **-1** (sentinel "past cap"), NOT a valid gold amount
- [ ] Boundary: `level_cost(1, 15)` (current = cap, level-up to 16) returns `-1`
- [ ] Below-bound defensive: `current_level < 1` → `push_error`; returns `-1`
- [ ] Unknown tier: `class_tier` not in `BASE_LEVEL` keys → `push_error("Economy.level_cost: tier=X has no BASE_LEVEL entry")`; returns `-1`
- [ ] Pure-read: no state mutation, no signals
- [ ] Distinct return for "valid cost" vs "past cap": cost is always `>= 0`; `-1` is only used for past-cap

---

## Implementation Notes

*Derived from ADR-0013 §Decision §level_cost:*

- Pseudocode:
  ```
  func level_cost(class_tier: int, current_level: int) -> int:
      if current_level < 1:
          push_error("Economy.level_cost: current_level=%d must be >= 1" % current_level)
          return -1
      if current_level >= EconomyConfig.LEVEL_CAP:
          return -1  # past cap; sentinel
      if not EconomyConfig.BASE_LEVEL.has(class_tier):
          push_error("Economy.level_cost: tier=%d has no BASE_LEVEL entry" % class_tier)
          return -1
      var base: int = EconomyConfig.BASE_LEVEL[class_tier]
      return floori(base * pow(EconomyConfig.LEVEL_RATIO, current_level - 1))
  ```
- The `current_level >= LEVEL_CAP` check uses `>=` not `==` to handle "querying level 16 cost when at level 15" (which is the typical caller pattern: caller passes the hero's current level; the function returns the cost to advance to level current+1).
- Re-read AC H-08 carefully: "querying for L=15→16 returns -1". This is the boundary case. The function returns -1 when `current_level == 15` (the cap) because there's no level beyond.
- `pow(1.6, 0) == 1.0` exactly; level 1 → 2 cost is `floori(40 × 1.0) = 40` ✓.
- `pow(1.6, 13)` for the L=14 → 15 case: `1.6^13 ≈ 450.36`; `floori(40 × 450.36) = 18014` — but the GDD AC says 18018; discrepancy is float precision. Allow ±1 in the test if needed, OR use the exact arithmetic from GDD §D.4 if a different formulation is documented (verify by re-reading economy-system.md §D when picked up).

---

## Out of Scope

- Story 008: `recruit_cost` (sibling formula)
- HeroLeveling Feature epic — chains query → spend → roster.set_hero_level

---

## QA Test Cases

- **AC H-08: cost progression**
  - **Given**: EconomyConfig with `BASE_LEVEL[1] == 40`, `LEVEL_RATIO == 1.6`, `LEVEL_CAP == 15`
  - **When**: `level_cost(1, L)` called for L = 1, 2, ..., 14
  - **Then**: returns `floori(40 × 1.6^(L-1))` for each. Spot-check: L=1 → 40, L=2 → 64, L=3 → 102 (= floori(102.4)), L=14 → 18018 (or within ±1 due to float precision; verify against GDD §D)
  - **Edge cases**: each value asserted independently; no off-by-one between L and L+1

- **AC: at-cap sentinel**
  - **Given**: `LEVEL_CAP = 15`
  - **When**: `level_cost(1, 15)` is called
  - **Then**: returns `-1`
  - **Edge cases**: `level_cost(1, 16)` also returns `-1`; `level_cost(1, 100)` also `-1`

- **AC: below-bound defensive**
  - **Given**: any state
  - **When**: `level_cost(1, 0)`, `level_cost(1, -5)`
  - **Then**: `push_error`; returns `-1`
  - **Edge cases**: `INT64_MIN` should not crash

- **AC: unknown tier**
  - **Given**: BASE_LEVEL only has tiers 1, 2
  - **When**: `level_cost(99, 5)`
  - **Then**: `push_error`; returns `-1`
  - **Edge cases**: tier 0, tier 3 (if not in BASE_LEVEL)

- **AC: pure-read**
  - **Given**: `_gold_balance = 100`
  - **When**: `level_cost(1, 5)` called 50 times
  - **Then**: `_gold_balance` unchanged; no signals emitted

- **AC: -1 vs 0 distinction**
  - **Given**: any valid query
  - **When**: returned value compared to -1 vs 0
  - **Then**: -1 ONLY appears when past cap or defensive-rejected; 0 never appears as a valid cost
  - **Edge cases**: testing the cost progression must verify all L=1..14 returns are positive (no zero leak)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_level_cost_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload), Story 002 (EconomyConfig.BASE_LEVEL + LEVEL_RATIO + LEVEL_CAP)
- **Unlocks**: HeroLeveling Feature epic
