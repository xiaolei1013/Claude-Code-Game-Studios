# Story: Endless Draft Integration

> **Epic**: endless-mode
> **Type**: Integration
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-endless-005 (skill draft every 5 waves via DraftRunController.ShowDraft(); class filtering applies)
**ADR Reference**: ADR-0007 -- Decision section (EndlessSessionController calls DraftRunController.ShowDraft() at wave milestones); Wave Loop diagram step 8
**Control Manifest Rules**: R-014 (DraftRunController filters candidates through CanApplyUpgrade before building draft pool -- no class-specific `if` branches), F-014 (do not make DraftRunController aware of Endless wave numbers)

## Description

Wire the Endless Mode draft system so that skill drafts appear at wave milestones and work correctly with the full skill pool and class filtering. `DraftRunController` is called as-is -- it must remain Endless-agnostic (F-014).

**Work items:**

1. **Draft Trigger Wiring** -- In `EndlessSessionController.WaveLoop()`, after the breathing window, when `_waveNumber % 5 == 0`:
   - Call `DraftRunController.Instance.ShowDraft()`
   - Wait for `DraftRunController.Instance.IsDraftComplete` before continuing to next wave
   - The 60s timeout safeguard (from Story 003) applies here

2. **Class Filtering Verification** -- `DraftRunController` already filters by class via `CanApplyUpgrade(player.CollectedSkills)` (R-014):
   - Mage runs should see Mage + Universal skills only
   - Archer runs should see Archer + Universal skills only
   - No modifications to `DraftRunController` are needed -- verify the existing filtering works in Endless context

3. **Draft Pool Behavior in Endless**:
   - Draft pool does NOT deplete between waves (GDD: "the same skill can be offered again")
   - Passive duplicates stack via existing `UpgradableSkill` rules
   - Maximum 1 copy of the same active skill (existing rule)
   - If the draft pool is exhausted in extremely long runs, offer gold/gem bonuses instead (GDD Edge Case 4)

4. **Boss Wave + Draft Interaction** (GDD Edge Case 1):
   - Wave 10, 20, etc. are both boss waves and draft waves
   - Boss wave completes first, THEN draft screen appears
   - Boss death counts as the wave clear trigger for the draft
   - This is handled by the `WaveLoop()` ordering: SpawnNextWave -> WaitForComplete -> breathing -> draft check

5. **Combo Detection After Draft** -- `ComboRegistry.CheckCombos()` should run after each draft pick (E4 system). Verify this fires correctly in Endless Mode via existing `DraftRunController` -> `ComboRegistry` event chain.

**Key constraints:**
- `DraftRunController` must remain completely Endless-unaware -- it does not know wave numbers, does not know it is in Endless mode (F-014)
- `EndlessSessionController` owns the "when to draft" decision; `DraftRunController` owns the "how to draft" logic
- No limit on total accumulated skills -- player keeps all drafted skills for the entire run

## Acceptance Criteria

- [ ] Draft screen appears after clearing wave 5, 10, 15, 20, etc.
- [ ] Draft screen shows 3 skill options per existing draft behavior
- [ ] Mage runs show only Mage-compatible + Universal skills in draft
- [ ] Archer runs show only Archer-compatible + Universal skills in draft
- [ ] No modifications to `DraftRunController` code (Endless-agnostic verified)
- [ ] Draft on wave 10: boss wave completes first, then draft appears
- [ ] Skills accumulate across drafts -- player retains all previously drafted skills
- [ ] `ComboRegistry.CheckCombos()` fires after each draft pick in Endless
- [ ] Draft pool is not depleted -- same skill can appear again in a later draft
- [ ] 60s timeout on draft completion wait (from Story 003 safeguard)
- [ ] Game loop resumes correctly after draft dismissal

## Test Evidence

**Type**: Integration Test
**Path**: `tests/integration/endless/`

- Integration test: Start Endless Mage run, reach wave 6 -- verify draft appeared after wave 5, verify Mage pool filtering
- Integration test: Start Endless Archer run, reach wave 6 -- verify Archer pool filtering
- Integration test: Complete wave 10 (boss wave + draft wave) -- verify boss spawns, boss dies, then draft appears
- Integration test: Complete two draft cycles (wave 5 and 10) -- verify skills from both drafts are active
- Manual verification: Confirm `DraftRunController.cs` was not modified (no Endless-specific code added)

## Dependencies

- **Blocked by**: 003-endless-session-controller (WaveLoop with draft trigger logic), E4 Combo/Synergy system (for combo detection after draft)
- **Blocks**: 008-endless-mode-tests

## Engine Notes

`DraftRunController` is an existing D7 Meta Layer system. This story calls it via its existing public API (`ShowDraft()`, `IsDraftComplete`). No post-cutoff APIs. The `CanApplyUpgrade()` filtering mechanism is established by ADR-0005 (ICharacterClass). If DraftRunController uses events rather than polling for `IsDraftComplete`, update `EndlessSessionController` to subscribe to the event (per ADR-0007 Negative Consequences note).
