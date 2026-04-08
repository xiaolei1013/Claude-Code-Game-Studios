# Story: Healing Drop Rate Scaling

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-difficulty-005 (healing drop rate multiplied by healDropMultiplier; non-healing drops unaffected)
**ADR Reference**: ADR-0001 -- Key Interfaces (HealDropMultiplier property), Migration Plan step 9 (migrate D8 drop behaviors)
**Control Manifest Rules**: R-006 (read via IDifficultyProvider), F-001 (no direct enum/struct access in drop behaviors)

## Description

Wire drop behavior to apply `HealDropMultiplier` from `IDifficultyProvider`. This affects both enemy death drops and destructible crate drops. Non-healing drops (gold, gems, skills) must remain unaffected.

**Implementation:**

1. Locate the drop behavior code that handles healing drop rolls (enemy death drops and crate break drops). The drop system is in the Loot & Drops (D8) area.

2. When rolling for a healing drop, apply the multiplier to the base drop chance:
   ```csharp
   var provider = GameManager.Instance.ActiveDifficultyProvider;
   float actualDropChance = baseDropChance * provider.HealDropMultiplier;
   bool dropsHeal = Random.value <= actualDropChance;
   ```

3. **Only healing drops are affected.** Gold drops, gem drops, skill drops, and any other non-healing drops must use their base drop chance without the difficulty multiplier.

4. GDD formula examples:
   - Normal: 10% base heal chance -> 10% actual (multiplier = 1.0)
   - Hard: 10% base heal chance -> 5% actual (multiplier = 0.5)
   - Edge case: 1% base heal chance on Hard -> 0.5% actual. `Random.value <= 0.005` still works correctly. No floor needed.

5. Both enemy death drops and destructible crate drops must apply this multiplier. Identify all code paths where healing drops are rolled.

## Acceptance Criteria

- [ ] Drop behavior reads `HealDropMultiplier` from `GameManager.Instance.ActiveDifficultyProvider`
- [ ] Healing drop probability = `baseDropChance * HealDropMultiplier`
- [ ] GDD AC 5: Over 100 enemy kills on Hard, healing drops appear roughly half as often as Normal (tolerance +/-15%)
- [ ] Non-healing drops (gold, gems, skills, materials) are completely unaffected by `HealDropMultiplier`
- [ ] Both enemy death drops and crate break drops apply the multiplier
- [ ] Normal difficulty (multiplier=1.0) produces identical drop rates to current behavior
- [ ] No direct difficulty enum checks remain in drop behavior code

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/difficulty/`

- Unit test: With `HealDropMultiplier = 1.0` and base chance 0.10, effective chance = 0.10
- Unit test: With `HealDropMultiplier = 0.5` and base chance 0.10, effective chance = 0.05
- Unit test: With `HealDropMultiplier = 0.5` and base chance 0.01, effective chance = 0.005 (no floor)
- Unit test: Non-healing drop chance is unmodified regardless of `HealDropMultiplier` value

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (IDifficultyProvider must exist), 002-normal-hard-config-presets (config values needed)
- **Blocks**: 009-difficulty-system-tests (integration test covers full pipeline)

## Engine Notes

Drop behavior code is likely in `Assets/Trizzle/Scripts/Combat/` or a loot/drops subdirectory. Read the existing drop system to identify the healing drop roll location. The `Random.value` comparison pattern is standard Unity. Ensure the multiplier is applied before the random roll, not after.
