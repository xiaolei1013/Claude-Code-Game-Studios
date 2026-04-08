# Story: Boss System Tests

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: All E3 Acceptance Criteria (1-11) must be verifiable via automated tests or documented evidence
**ADR Reference**: ADR-0004 -- Validation Criteria (11 criteria that must pass in playtest)
**Control Manifest Rules**: G-004 (phase check O(n) where n <= 3), G-012 (validate _phases list length)

## Description

Write comprehensive unit and integration tests for the Boss Phase System. This is the quality gate story -- it validates that all previous stories (001-010) work correctly individually and together.

**Test suites to create:**

### Unit Tests (`tests/unit/boss/`)

1. **Phase Transition Tests:**
   - `test_phase_triggers_at_threshold_expected_phase_change`: Damage 2-phase boss to exactly 50% HP, verify phase 2 triggers
   - `test_phase_does_not_trigger_above_threshold_expected_no_change`: Damage boss to 51% HP, verify phase 1 still active
   - `test_multi_threshold_skip_expected_all_phases_trigger`: Deal 80% max HP in one hit to 3-phase boss, verify phases 2 AND 3 both trigger
   - `test_multi_threshold_skip_stagger_duration_expected_1s`: Verify total stagger for 2 skipped phases = 1.0s
   - `test_phase_order_ascending_expected_sorted`: Provide unsorted phases, verify Awake sorts them ascending

2. **Stagger State Tests:**
   - `test_stagger_invulnerability_expected_zero_damage`: Hit boss during stagger, verify 0 damage
   - `test_stagger_clears_debuffs_expected_frozen_removed`: Freeze boss, trigger phase, verify Frozen cleared
   - `test_stagger_duration_expected_half_second`: Verify stagger lasts exactly 0.5s
   - `test_stagger_swaps_behaviour_tree_expected_new_tree`: Verify BehaviourTree reference changes during stagger

3. **One-Way Phase Tests:**
   - `test_heal_past_threshold_expected_no_phase_reversal`: Trigger phase 2, heal above 50%, verify phase 2 still active
   - `test_re_damage_past_triggered_threshold_expected_no_retrigger`: Trigger phase 2, heal, re-damage past 50%, verify OnPhaseTransition fires only once

4. **Boss Death Tests:**
   - `test_boss_death_fires_event_expected_on_boss_defeated`: Kill boss, verify OnBossDefeated fires exactly once
   - `test_boss_death_during_stagger_expected_death_priority`: Start stagger, set HP to 0, verify death processes and coroutine stops
   - `test_boss_death_stagger_cleanup_expected_invulnerable_false`: After death during stagger, verify IsInStagger = false

5. **EnemyData.IsBoss Tests:**
   - `test_isboss_blocks_oneshot_expected_kill_blocked`: IsBoss = true, apply OneShotKill, verify boss survives
   - `test_isboss_false_allows_oneshot_expected_kill_allowed`: IsBoss = false, apply OneShotKill, verify enemy dies
   - `test_isboss_default_expected_false`: New EnemyData, verify IsBoss == false

6. **Boss Kill Tracking Tests:**
   - `test_boss_killed_tracking_expected_true_on_kill`: Kill boss via OnBossDefeated, verify DraftRunController receives bossKilled = true
   - `test_boss_not_killed_tracking_expected_false_on_death`: Player dies before boss, verify bossKilled = false

7. **IBossPhaseController Interface Tests:**
   - `test_current_phase_index_expected_increments`: Verify CurrentPhaseIndex starts at 0, increments on each transition
   - `test_total_phases_expected_matches_config`: Verify TotalPhases matches _phases.Count
   - `test_is_in_stagger_expected_true_during_transition`: Verify IsInStagger = true during coroutine, false after

### Integration Tests (`tests/integration/boss/`)

8. **Full Boss Encounter Test:**
   - Spawn a configured boss prefab, damage through all phases, verify all transitions fire in correct order
   - Verify boss death at 0 HP after final phase
   - Verify room completion after boss + all minions are dead

**Test naming convention:** `[system]_[feature]_test.cs` for files, `test_[scenario]_[expected]` for methods (per coding standards).

## Acceptance Criteria

- [ ] All unit tests listed above are implemented and pass
- [ ] Integration test for full boss encounter passes
- [ ] Tests are deterministic (no random seeds, no time-dependent assertions beyond coroutine waits)
- [ ] Tests are isolated (each test sets up and tears down its own state)
- [ ] Test fixtures use factory functions, not inline magic numbers
- [ ] Tests cover all 11 GDD Acceptance Criteria (mapped below)
- [ ] Tests cover all 11 ADR-0004 Validation Criteria
- [ ] Zero test failures on CI

**GDD Acceptance Criteria Coverage Map:**

| GDD AC | Test(s) |
|--------|---------|
| AC1: BossController exists | test_phase_triggers_at_threshold (implicitly creates BossController) |
| AC2: Phase transition at threshold | test_phase_triggers_at_threshold |
| AC3: Multi-threshold skip | test_multi_threshold_skip |
| AC4: Stagger invulnerability | test_stagger_invulnerability |
| AC5: Stagger clears debuffs | test_stagger_clears_debuffs |
| AC6: Minions persist after boss death | Integration test: full encounter |
| AC7: Shield blocks damage not status | Unit tests in Story 006 |
| AC8: Boss exempt from count multiplier | Covered by E2 difficulty tests |
| AC9: Boss kill tracking | test_boss_killed_tracking, test_boss_not_killed_tracking |
| AC10: IsBoss flag works | test_isboss_blocks_oneshot, test_isboss_false_allows_oneshot |
| AC11: 5 bosses playable | Integration test: full encounter (per boss) |

## Test Evidence

**Type**: Unit Test (self-evidencing -- the tests ARE the evidence)
**Path**: `tests/unit/boss/`, `tests/integration/boss/`

## Dependencies

- **Blocked by**: All stories 001-010 (tests validate the complete system)
- **Blocks**: None -- this is the final story in the epic

## Engine Notes

Tests use the project's existing test framework. For Unity, this means NUnit-based tests via Unity Test Framework. Coroutine tests may need `UnityTest` attribute for yield-based assertions. Mock `Health.OnDamaged` events for unit test isolation. Integration tests may need to run in Play Mode.
