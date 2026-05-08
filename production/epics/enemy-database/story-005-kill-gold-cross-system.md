# Story 005: Kill-gold formula cross-system consistency (Economy ↔ Enemy DB ↔ Matchup)

> **Epic**: enemy-database
> **Status**: Complete (system shipped; see systems-index Implementation Status #7. Test evidence: `tests/{unit,integration}/enemy_database/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §H-05, §H-06; `design/gdd/economy-system.md` §D.2 (kill-bonus formula)
**Requirements**: TR-enemy-db-012, TR-enemy-db-013, TR-economy-007 (cross-validation)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (EnemyData.tier as input to kill-gold formula), ADR-0013 (Economy `BASE_KILL` table + `MATCHUP_GOLD_MULTIPLIER`)
**ADR Decision Summary**: Kill gold is computed as `floor(BASE_KILL[enemy.tier] × matchup_multiplier)`. The Orchestrator's `_attribute_kill_gold` is the canonical call site (calls `Economy.attribute_kill_gold(tier, matchup_advantage)`). Economy receives the post-LOSING-factor amount; this story verifies the BASE_KILL × matchup-multiplier path produces the expected gold values.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure integer arithmetic + cross-system data resolution.

**Control Manifest Rules (Core Layer)**:
- **Required**: kill gold computed via `Economy.attribute_kill_gold(tier, matchup_advantage)` (Sprint 2 economy-system Story 007; deferred — this story can mock/inject if S2-Story-007 hasn't landed yet, then promote when it does).
- **Required**: `BASE_KILL` lookup keyed by enemy tier; values in `economy_config.tres`. — ADR-0013

---

## Acceptance Criteria

- [ ] **AC H-05**: For each MVP enemy, `floor(BASE_KILL[enemy.tier] × 1.0) == BASE_KILL[enemy.tier]` (no-matchup case): Tier-1 → 10, Tier-2 → 35, Tier-3 → 80
- [ ] **AC H-05 with matchup**: `floor(BASE_KILL[enemy.tier] × 1.5) == correct value`: Tier-1 → 15, Tier-2 → 52, Tier-3 → 120
- [ ] **AC H-06 matchup gating**: `is_class_counter(warrior, "bruiser") == true` → matchup advantage applies (multiplier 1.5); `is_class_counter(warrior, "caster") == false` → no advantage (multiplier 1.0)
- [ ] **TR-enemy-db-012**: integration test verifies the full chain: load enemy → resolve tier → look up `BASE_KILL[tier]` → multiply by matchup → emit `enemy_killed` signal → Economy credits the result
- [ ] **TR-enemy-db-013**: this story verifies the formula at the Economy boundary, not the Orchestrator's `_attribute_kill_gold` call site (Orchestrator is in DungeonRunOrchestrator Feature epic; mock or stub here)

---

## Implementation Notes

*Derived from ADR-0013 §kill-bonus path + ADR-0011 + GDD economy-system.md §D.2:*

- This story does NOT add new code to EnemyData or EnemyDatabase — both are already in place from Stories 001/002. Instead, it verifies cross-system consistency via an integration test:
  ```
  # Pseudocode (test, not source):
  func test_kill_gold_formula_consistency() -> void:
      var enemy: EnemyData = EnemyDatabase.get_by_id("hollow_brute")
      var config: EconomyConfig = Economy.get_config()
      var expected_neutral: int = floori(config.BASE_KILL[enemy.tier] * 1.0)
      var expected_matchup: int = floori(config.BASE_KILL[enemy.tier] * config.MATCHUP_GOLD_MULTIPLIER)
      # ... assertions
  ```
- If economy-system Story 007 (`attribute_kill_gold` body — Sprint 3 Should/Nice candidate or Sprint 4) hasn't landed, the test asserts the formula directly using EconomyConfig values without invoking the actual `Economy.attribute_kill_gold` method. Document the deferral.
- The matchup-multiplier verification depends on `is_class_counter` from hero-class-database Story 006 (Sprint 3 N2 / N1 carryover). If that hasn't landed, mock the boolean directly.

---

## Out of Scope

- DungeonRunOrchestrator's `_attribute_kill_gold` (Feature epic, not in Sprint 3)
- LOSING_RUN_LOOT_FACTOR application (Orchestrator's job, not Economy's)
- Story 007 of economy-system (`attribute_kill_gold` body) — out of Sprint 3 scope; this test mocks/stubs as needed

---

## QA Test Cases

- **AC H-05 + TR-enemy-db-013: kill gold per tier (no matchup)**
  - **Given**: each MVP enemy loaded; `BASE_KILL == {1: 10, 2: 35, 3: 80}` from EconomyConfig
  - **When**: compute `floori(BASE_KILL[enemy.tier] * 1.0)` for each enemy
  - **Then**: Tier-1 enemies → 10, Tier-2 enemies → 35, Tier-3 (Ancient Rootking) → 80
  - **Edge cases**: 7+ enemies × correctness assertion; failure-isolation per enemy

- **AC H-05 with matchup: 1.5× multiplier**
  - **Given**: same setup; `MATCHUP_GOLD_MULTIPLIER == 1.5`
  - **When**: compute `floori(BASE_KILL[tier] * 1.5)`
  - **Then**: Tier-1 → 15, Tier-2 → 52 (= floori(35 × 1.5) = floori(52.5) = 52), Tier-3 → 120
  - **Edge cases**: integer truncation at 52.5 → 52 (NOT round); same for any half-values

- **AC H-06: matchup gating via is_class_counter**
  - **Given**: warrior class loaded (counter_archetype="bruiser"); test against bruiser-archetype enemy + caster-archetype enemy
  - **When**: check `is_class_counter(warrior, enemy.archetype)`
  - **Then**: bruiser enemy → true (matchup applies, multiplier 1.5); caster enemy → false (no advantage, multiplier 1.0)
  - **Edge cases**: empty archetype string → false; case-mismatched (e.g., "BRUISER") → false; mock-or-stub if `is_class_counter` not yet landed

- **AC H-05 integration boundary**
  - **Given**: Economy autoload + EconomyConfig + EnemyDatabase all booted
  - **When**: a hypothetical Orchestrator calls `Economy.attribute_kill_gold(enemy.tier, has_matchup)` (or test mock equivalent)
  - **Then**: Economy's gold balance increases by the computed kill-gold value; `gold_changed` signal fires with delta = computed value
  - **Edge cases**: this leg requires Orchestrator stub OR economy-system Story 007 landed; if neither available, defer this AC to Sprint 4 with note in Test Evidence

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/enemy_database/kill_gold_cross_system_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (EnemyData schema), Story 003 (real enemy `.tres` for tier values), Sprint 2 EconomyConfig (`BASE_KILL` + `MATCHUP_GOLD_MULTIPLIER`), hero-class-database `is_class_counter` (S2-N1 / S3-N2 — mock or wait)
- **Unlocks**: Confidence in Economy ↔ Enemy DB integration; informs DungeonRunOrchestrator Feature epic
