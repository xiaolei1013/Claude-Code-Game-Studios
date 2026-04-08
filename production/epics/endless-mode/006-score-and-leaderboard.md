# Story: Score & Leaderboard

> **Epic**: endless-mode
> **Type**: UI
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-endless-009 (score = waves cleared; per-class leaderboard via LevelStats with synthetic IDs), TR-endless-014 (death screen shows: waves cleared, total kills, combos discovered, class used)
**ADR Reference**: ADR-0007 -- Score Persistence Contract (LevelStats with "Endless_Mage" / "Endless_Archer" IDs), Decision section (EndlessSessionController.UpdateScoreHUD and ShowDeathScreen methods)
**Control Manifest Rules**: R-024 (Endless score level IDs are "Endless_Mage" and "Endless_Archer" -- reserved, must not be used for campaign rooms)

## Description

Implement the HUD wave counter displayed during an Endless run and the death screen that shows run statistics. Wire score persistence to `LevelStats` with per-class high scores.

**Work items:**

1. **HUD Wave Counter** -- Display the current wave number during an Endless run:
   - Position: top-right area of the HUD, below currency display (per GDD)
   - Format: "Wave [N]" with the current wave number
   - Updated by `EndlessSessionController.UpdateScoreHUD(_score)` after each wave completes
   - Only visible during Endless Mode runs (hidden during campaign)

2. **Death Screen** -- Triggered by `EndlessSessionController.OnPlayerDied()`:
   - **Waves Cleared**: `_score` (integer)
   - **Total Kills**: Accumulated from combat system kill counter during the run
   - **Combos Discovered**: Count of combos discovered this run (from ComboRegistry, E4)
   - **Class Used**: `_classType` (Mage or Archer)
   - **New High Score** indicator: Show if `_score > existingHighScore` for the class
   - Layout follows existing death/result screen patterns in the project

3. **Score Persistence via LevelStats**:
   - Add `LevelStats.SaveEndlessScore(PlayerClassType classType, int wavesCleared)` method (if not already present)
   - Level IDs: `"Endless_Mage"` for Mage runs, `"Endless_Archer"` for Archer runs (R-024)
   - Writes score only if `wavesCleared > existingHighScore` (same pattern as campaign room best-time)
   - Add `LevelStats.GetEndlessHighScore(PlayerClassType classType)` for reading back

4. **Per-Class Leaderboard Display** (on death screen or main menu):
   - Show Mage high score and Archer high score independently
   - High scores persist across sessions via existing save system

**Key constraints:**
- No new persistence class or save schema (ADR-0007: "No new save field, no new persistence class, no new save schema")
- Kill counter and combo discovery count are sourced from existing systems -- this story only reads and displays them
- UI must follow the existing PC/Mobile split pattern if applicable (G-014)

## Acceptance Criteria

- [ ] HUD wave counter visible during Endless runs, positioned top-right below currency
- [ ] Wave counter updates after each wave completes
- [ ] Wave counter not visible during campaign mode
- [ ] Death screen shows: waves cleared, total kills, combos discovered, class used
- [ ] "New High Score" indicator appears when score exceeds existing class record
- [ ] `LevelStats.SaveEndlessScore()` method exists and writes with level IDs "Endless_Mage" / "Endless_Archer"
- [ ] Score saves only if higher than existing high score for that class
- [ ] `LevelStats.GetEndlessHighScore()` reads correct per-class score
- [ ] Mage and Archer high scores are independent: setting Mage record does not affect Archer record
- [ ] High scores persist across game sessions (survive save/load cycle)
- [ ] Death screen accessible after player death terminates the Endless run

## Test Evidence

**Type**: Manual Walkthrough + Screenshot
**Path**: `production/qa/evidence/`

- Screenshot: HUD during an Endless run showing wave counter in top-right
- Screenshot: Death screen showing all 4 stat fields + high score indicator
- Manual test: Set Mage high score at 25 waves. Switch to Archer. Verify Archer leaderboard is independent (GDD AC 9)
- Manual test: Die at wave 17 as Mage. Reload. Verify "Endless_Mage" high score reads 17. Die at wave 8 as Mage. Verify high score still reads 17 (not overwritten by lower score)

## Dependencies

- **Blocked by**: 003-endless-session-controller (provides UpdateScoreHUD and ShowDeathScreen hooks)
- **Blocks**: None (leaf story)

## Engine Notes

UI implementation follows existing project UI patterns. `LevelStats` is part of the D11 Save/Load system. The synthetic level ID convention ("Endless_Mage", "Endless_Archer") uses string keys in the existing save data structure -- no schema migration needed. Verify `LevelStats` write/read cycle survives scene transitions in Unity 6000.3.11f1 (per ADR-0007 Engine Compatibility verification requirement).
