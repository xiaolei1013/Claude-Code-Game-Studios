# Story: Hard Mode Unlock Gating

> **Epic**: difficulty-system
> **Type**: UI
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-difficulty-003 (Hard mode locked until Normal clear; unlock state from LevelStats), TR-difficulty-009 (difficulty cannot be changed mid-room; set per-room before entering)
**ADR Reference**: ADR-0001 -- Implementation Guideline 10 (MenuPrepareStagePanelPC calls SetDifficultyProvider on room entry)
**Control Manifest Rules**: R-006 (consumers read via IDifficultyProvider)

## Description

Implement Hard mode unlock gating in the room selection UI and wire the difficulty provider assignment on room entry. This story has two parts: the unlock/lock UI and the provider assignment flow.

**Part 1 -- Unlock Gating UI:**

1. In `MenuPrepareStagePanelPC` (the room preparation screen), add Normal and Hard difficulty buttons/toggle.

2. **Unlock check:** When rendering the difficulty selector for a room, read `LevelStats` for the room's Normal entry:
   ```csharp
   bool normalCleared = LevelStats.GetState(roomId, LevelDifficulty.Normal) == LevelState.Completed;
   ```
   If `normalCleared == true`, enable the Hard button. Otherwise, Hard is visually dimmed with a lock icon and tooltip: "Clear on Normal to unlock."

3. **Unlock animation:** When Hard becomes available (player just cleared Normal and returns to room select), play a brief gold flash animation on the Hard button. Reuse the rarity glow effect from DESIGN.md.

4. **Persistence:** Unlock state is derived from existing `LevelStats` save data -- no additional save field needed. If Normal is cleared, Hard is unlocked. This survives save/load automatically.

**Part 2 -- Provider Assignment:**

5. When the player confirms room + difficulty selection, `MenuPrepareStagePanelPC` calls:
   ```csharp
   GameManager.Instance.SetDifficultyProvider(selectedProvider);
   ```
   Where `selectedProvider` is the `CampaignDifficultyProvider` instance wired to either `DifficultyConfig_Normal.asset` or `DifficultyConfig_Hard.asset`.

6. **Mid-room prevention:** Difficulty selector is only available on the room select screen (TR-difficulty-009). The pause menu during gameplay shows current difficulty as read-only info text. No toggle, no way to change mid-run.

**Endless Mode note:** Endless Mode has no difficulty gate -- it uses its own scaling. This UI should not appear in the Endless Mode entry flow.

## Acceptance Criteria

- [ ] Room select UI shows Normal and Hard difficulty options
- [ ] GDD AC 2: Hard mode locked by default -- Hard button is dimmed with lock icon for rooms not yet cleared on Normal
- [ ] GDD AC 3: After clearing Room N on Normal, Hard toggle becomes active for Room N. Persists across sessions
- [ ] Unlock state is read from `LevelStats` save data -- no additional save fields added
- [ ] Gold flash animation plays on Hard button when it unlocks (reuses rarity glow from DESIGN.md)
- [ ] Tooltip on locked Hard button reads "Clear on Normal to unlock"
- [ ] On room entry confirmation, `GameManager.SetDifficultyProvider()` is called with the correct provider (Normal or Hard)
- [ ] Difficulty cannot be changed mid-room -- pause menu shows read-only difficulty info
- [ ] Endless Mode entry flow does not show the campaign difficulty selector

## Test Evidence

**Type**: Manual Walkthrough + Screenshot
**Path**: `production/qa/evidence/`

- Screenshot: Room select with Hard locked (dimmed + lock icon)
- Screenshot: Room select with Hard unlocked after Normal clear
- Screenshot: Pause menu showing read-only difficulty info
- Manual walkthrough: Clear Room 1 on Normal, verify Hard unlocks, select Hard, confirm correct provider is active in gameplay

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (IDifficultyProvider and SetDifficultyProvider must exist), 002-normal-hard-config-presets (Normal and Hard config assets must exist)
- **Blocks**: None (this is a leaf node -- no downstream stories depend on it within this epic)

## Engine Notes

`MenuPrepareStagePanelPC` is in `Assets/Trizzle/Scripts/UI/PC/`. `LevelStats` is part of the existing Save/Load system (D11). Read both files to understand the current room selection flow and how `LevelState` is queried. The gold flash animation should reuse existing VFX/tween infrastructure from the project -- check DESIGN.md for the rarity glow specification. Unity UI (UGUI Canvas) is the UI framework per the project's existing patterns.
