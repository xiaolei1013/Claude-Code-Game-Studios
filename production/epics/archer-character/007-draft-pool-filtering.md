# Story: Draft Pool Filtering

> **Epic**: archer-character
> **Type**: Integration
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-008 (Refactor DashSkill to cast to PlayerController or ICharacterClass instead of MagePlayerController)
**ADR Reference**: ADR-0005 -- Decision item 9 (DraftRunController filters by CanApplyUpgrade against player collected skills; no class-specific if-branches)
**Control Manifest Rules**: R-014 (DraftRunController.ShowDraft() must filter candidates through CanApplyUpgrade(player.CollectedSkills) before building draft pool; no class-specific if-branches), F-010 (no MagePlayerController casts in DraftRunController)

## Description

Update `DraftRunController` to filter draft skill options by class compatibility, ensuring Mage-only skills never appear for Archer players and vice versa. The filtering mechanism is data-driven through the existing `CanApplyUpgrade()` system -- no new class-specific branching code.

**Files to modify:**

1. **`DraftRunController.cs`** -- Update `ShowDraft()` (or equivalent draft generation method) to filter candidate skills through `CanApplyUpgrade()` before building the draft pool:

   ```csharp
   // Pseudocode per ADR-0005 -- verify exact API signature before implementing
   var eligibleSkills = allSkills
       .Where(s => s.CanApplyUpgrade(player.CollectedSkills))
       .ToList();
   ```

   This is NOT a new code path -- `CanApplyUpgrade()` already checks `compatibleUpgradeTypes`. The change ensures the check is applied during draft generation (before showing options to the player), not just at upgrade application time.

**Verification requirements:**

2. **Mage draft pool**: When playing as Mage, verify:
   - Fireball upgrades (BurnAttack_For_FireballSkill, ExplosionFireball, etc.) APPEAR
   - Arrow upgrades (PiercingArrow, Multishot, PoisonArrow) DO NOT appear
   - Shared passives (Frenzy, Stoneguard, SwiftWind, etc.) APPEAR

3. **Archer draft pool**: When playing as Archer, verify:
   - Arrow upgrades (PiercingArrow, Multishot, PoisonArrow) APPEAR
   - Fireball upgrades DO NOT appear
   - Dodge upgrades (Afterimage, CounterRoll) APPEAR
   - Dash upgrades (ExplosionDashSkill_For_DashSkill, etc.) DO NOT appear
   - Shared passives APPEAR

4. **Cross-verification**: `CanApplyUpgrade()` must work correctly for BOTH classes. Run the check for both Mage and Archer against the full skill pool.

**Key constraints from ADR-0005:**
- Zero class-specific `if` branches in `DraftRunController` -- all filtering is through the `CanApplyUpgrade()` data-driven mechanism
- Draft filtering happens once per draft event (inter-room), not in the combat hot path
- The existing `UpgradableSkill.CanApplyUpgrade()` checks `compatibleUpgradeTypes` -- verify the API signature supports the player's collected skills as input before implementing

## Acceptance Criteria

- [ ] `DraftRunController.ShowDraft()` filters candidates through `CanApplyUpgrade()` before building draft pool
- [ ] No class-specific `if` branches (e.g., `if class == Archer`) exist in `DraftRunController`
- [ ] As Mage: Fireball upgrades appear, Arrow/Dodge upgrades do not appear, shared passives appear
- [ ] As Archer: Arrow/Dodge upgrades appear, Fireball/Dash upgrades do not appear, shared passives appear
- [ ] `CanApplyUpgrade()` returns correct results for both classes against all skill types
- [ ] Draft pool never offers skills incompatible with the current character
- [ ] GDD Acceptance Criterion 6: "Equip 3+ shared skills (Frenzy, BurnAttack, GoldRush) on Archer. All activate and apply effects correctly."
- [ ] GDD Acceptance Criterion 7: "FireballSkill upgrades (e.g., BurnAttack_For_FireballSkill) do NOT appear in Archer's draft pool."
- [ ] ADR-0005 Validation Criterion 3: "As Archer, run DraftRunController test. Fireball upgrades must not appear. Arrow upgrades must appear. Shared passives must appear for both classes."

## Test Evidence

**Type**: Integration Test
**Path**: `tests/integration/archer/`

- Integration test: Generate draft pool as Mage with full skill database -> verify no archer-exclusive skills in pool
- Integration test: Generate draft pool as Archer with full skill database -> verify no mage-exclusive skills in pool
- Integration test: Both classes receive shared passives (Frenzy, BurnAttack, GoldRush) in their draft pools
- Unit test: `CanApplyUpgrade()` returns `false` for PiercingArrow when player has no ArrowShotSkill (Mage case)
- Unit test: `CanApplyUpgrade()` returns `true` for PiercingArrow when player has ArrowShotSkill (Archer case)

## Dependencies

- **Blocked by**: 001-archer-controller-icharacterclass (ArcherPlayerController must exist for class context), 006-archer-exclusive-skills (archer skills must exist to be filtered into the pool)
- **Blocks**: 009-archer-character-tests (integration test requires draft pool to work)

## Engine Notes

`DraftRunController` is an existing system. The change is a filter addition to the draft generation path. Verify `CanApplyUpgrade()` API signature in the codebase -- ADR-0005 notes this as LOW risk but requires verification. If the API is insufficient for the class-filter use case, a targeted extension to `UpgradableSkill` is scoped at that point (ADR-0005 Risk table).
