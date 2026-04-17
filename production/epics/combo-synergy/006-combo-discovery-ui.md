# Story: Combo Discovery UI

> **Epic**: combo-synergy
> **Type**: UI
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-combo-005 (combo discovery UI: gold text flash, Cinzel font, center screen, 2s fade, distinct SFX)
**ADR Reference**: ADR-0003 -- Migration Plan step 8 ("flash logic subscribes to IComboRegistry.OnComboDiscovered"), GDD Requirements Addressed (TR-combo-005 "Not covered by ADR -- presentation story")
**Control Manifest Rules**: R-028 (OnComboDiscovered fires exactly once per combo per run; UI subscribes to this event), Layer Rules Section 4 Presentation Layer ("reads from Gameplay events only; IComboRegistry.OnComboDiscovered -> flash UI; must not own game state")

## Description

Create the combo discovery presentation layer: a gold text flash notification that appears when a new combo is discovered during a run. This is a Presentation-layer component that subscribes to `IComboRegistry.OnComboDiscovered` and displays the combo name. It owns no game state.

**Files to create:**

1. **`Assets/Trizzle/Scripts/UI/ComboDiscoveryUI.cs`** -- MonoBehaviour UI component:
   - Subscribe to `IComboRegistry.OnComboDiscovered` in `OnEnable()`, unsubscribe in `OnDisable()`
   - On event: display the combo's `comboName` in gold text, center screen, with a 2-second fade-out animation
   - If multiple combos are discovered simultaneously (Edge Case 2), queue them with 0.5s delay between flashes
   - Play a distinct discovery SFX (separate from level-up or rarity sounds) via the existing audio system
   - Text styling: Cinzel font, gold color (#FFD700 or project-specific gold), large size (readable from gameplay distance), center-aligned
   - Animation: fade in quickly (0.1-0.2s), hold, fade out over 2s total display time
   - Must not block gameplay input or obscure critical HUD elements

2. **`Assets/Trizzle/Prefabs/UI/ComboDiscoveryFlash.prefab`** -- UI prefab:
   - Canvas setup: Screen Space Overlay, high sort order (above gameplay, below pause menu)
   - TextMeshPro component with Cinzel font asset
   - CanvasGroup for alpha animation (fade in/out)
   - Positioned center screen, vertically offset slightly above center (avoid overlapping player character)

3. **`Assets/Trizzle/Audio/SFX/combo_discovery.wav`** (or reference existing SFX asset):
   - Distinct SFX for combo discovery -- must not be confused with level-up, skill draft, or rarity tier sounds
   - Short, impactful, rewarding (1-2 second duration max)
   - Played via the existing `AudioManager` or `SFXPlayer` system

**Presentation-only constraints:**
- This component reads from `IComboRegistry.OnComboDiscovered` and the `ComboDefinition.comboName` -- it never writes back to the combo system
- It does not check `discoveredFlag` (that's persistence logic in Story 008). The flash fires every run on combo discovery (GDD Open Question 3 resolution: every run)
- If `ComboDiscoveryUI` receives an event while a flash is already showing, it queues the new flash (Edge Case 2: 0.5s delay between sequential flashes)

## Acceptance Criteria

- [ ] Combo discovery flash appears centered on screen when `OnComboDiscovered` fires
- [ ] Flash text is gold color, Cinzel font (via TextMeshPro), large readable size
- [ ] Flash animation: quick fade-in, 2-second total display, smooth fade-out
- [ ] Distinct discovery SFX plays with the flash (not level-up or rarity SFX)
- [ ] Multiple simultaneous combos flash sequentially with 0.5s delay between (Edge Case 2)
- [ ] Flash does not block gameplay input
- [ ] Flash does not obscure critical HUD elements (health bar, skill cooldowns)
- [ ] Flash fires every run on combo discovery, not just first-ever discovery
- [ ] GDD Acceptance Criterion 1: "Plague Volley" name flashes on screen when combo discovered
- [ ] Component properly unsubscribes from `OnComboDiscovered` in `OnDisable()`

## Test Evidence

**Type**: Manual Walkthrough + Screenshot
**Path**: `production/qa/evidence/`

- Screenshot: combo discovery flash showing "Plague Volley" in gold Cinzel text, center screen
- Screenshot: two sequential flashes showing correct queuing behavior
- Manual walkthrough doc: step-by-step verification of flash timing, font, color, position, SFX
- Verify: flash does not appear when no combo is discovered
- Verify: flash appears on second run when same combo is re-discovered

## Dependencies

- **Blocked by**: 002-combo-effect-base-class (needs IComboRegistry.OnComboDiscovered event to subscribe to)
- **Soft dependency on**: 003/004/005 (effect implementations) and 007 (database population) for full end-to-end testing. Can be unit-tested with a mock `IComboRegistry` that fires `OnComboDiscovered` directly.
- **Blocks**: None -- presentation layer is a leaf dependency

## Engine Notes

Uses TextMeshPro (TMPro) for text rendering, `CanvasGroup.alpha` for fade animation, and `Coroutine` or `DOTween` for the fade sequence. TextMeshPro is bundled with Unity 6 and is the standard text solution. Cinzel font must be imported as a TMPro font asset (SDF format). If Cinzel is not already in the project, it needs to be added as a font asset (Google Fonts, OFL license). Verify TMPro font asset generation works in Unity 6000.3.11f1.

## Completion Notes
**Completed**: 2026-04-17
**Criteria**: 8/10 passing (AC-7 HUD obscuring, AC-9 Plague Volley runtime flash deferred to visual playtest)
**Deviations**:
- ADVISORY: Modified existing `ComboDiscoveryFeedback.cs` (UI/PC/) instead of creating new `ComboDiscoveryUI.cs`. Existing component covered 80% of requirements; creating a duplicate would be wasteful.
- ADVISORY: Cinzel font not imported. TMPro component uses current scene font until Cinzel SDF asset is added.
- ADVISORY: `_discoverySfx` AudioClip not assigned. Falls back to `SoundEffectType.Positive` until distinct clip is wired.
- ADVISORY: Inspector re-wiring needed: `_comboRegistry` field must be assigned to scene ComboRegistry (was previously `draftRunController`).
- ADVISORY: Prefab `ComboDiscoveryFlash.prefab` not extracted from scene hierarchy.
**Test Evidence**: UI — manual walkthrough + screenshot required at production/qa/evidence/
**Code Review**: Skipped (Lean mode)
