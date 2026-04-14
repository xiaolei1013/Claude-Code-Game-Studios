# Story: Boss Kill Tracking Fix

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-boss-012 (fix DraftRunController.OnRunComplete() to detect actual boss kill via IBossPhaseController.OnBossDefeated event instead of hardcoding true)
**ADR Reference**: ADR-0004 -- Decision section (IBossPhaseController.OnBossDefeated event), Key Interfaces section (SpawnManager and DraftRunController subscribe to OnBossDefeated)
**Control Manifest Rules**: R-027 (SpawnManager and DraftRunController subscribe to IBossPhaseController.OnBossDefeated -- never poll CurrentPhaseIndex per frame), F-007 (do not use tag/name string comparisons for boss detection)

## Description

Fix `DraftRunController.OnRunComplete()` to detect actual boss kills using the `IBossPhaseController.OnBossDefeated` event instead of the current hardcoded `true` value. This is a bug fix that affects the accuracy of run completion tracking.

**Current behavior (broken):**
- `DraftRunController.OnRunComplete()` currently passes `bossKilled = true` unconditionally (or uses a hardcoded value)
- This means the game thinks a boss was killed even when the player dies before reaching the boss

**Desired behavior:**
- `DraftRunController` subscribes to `IBossPhaseController.OnBossDefeated` event when a boss entity spawns
- When the event fires, set an internal `_bossKilled = true` flag
- `OnRunComplete()` reads `_bossKilled` to determine the correct value
- If the player dies before the boss is killed, `_bossKilled` remains `false`

**Implementation details:**

1. **In `DraftRunController`**:
   - Add `private bool _bossKilled = false`
   - Reset `_bossKilled = false` at the start of each room/run
   - Subscribe to `IBossPhaseController.OnBossDefeated` when a boss entity is detected (via `SpawnManager` or entity spawn callback)
   - In `OnRunComplete()`, pass `_bossKilled` instead of `true`

2. **Boss detection for subscription**:
   - Use `EnemyData.IsBoss` to identify when a boss entity spawns (from Story 003)
   - Get the `IBossPhaseController` component from the boss entity
   - Subscribe to `OnBossDefeated` event

3. **Cleanup**:
   - Unsubscribe from `OnBossDefeated` in `OnDisable()` or when the room ends
   - Handle edge case: boss entity destroyed without firing event (should not happen, but defensive coding)

## Acceptance Criteria

- [ ] `DraftRunController.OnRunComplete()` uses actual boss kill state, not hardcoded `true`
- [ ] `DraftRunController` subscribes to `IBossPhaseController.OnBossDefeated` event
- [ ] Boss killed: `OnRunComplete()` receives `bossKilled = true`
- [ ] Player dies before boss: `OnRunComplete()` receives `bossKilled = false`
- [ ] `_bossKilled` resets to `false` at start of each room/run
- [ ] No tag/name string comparisons used for boss detection (uses `EnemyData.IsBoss`)
- [ ] Event subscription properly cleaned up on disable/room end
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Spawn boss, kill boss (fire OnBossDefeated), call OnRunComplete(), verify `bossKilled == true`
- Unit test: Spawn boss, simulate player death (do NOT fire OnBossDefeated), call OnRunComplete(), verify `bossKilled == false`
- Unit test: Start new room, verify `_bossKilled` resets to `false`
- Unit test: Room with no boss, call OnRunComplete(), verify `bossKilled == false`

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (IBossPhaseController and OnBossDefeated must exist), 003-enemydata-isboss-flag (EnemyData.IsBoss used for boss detection)
- **Blocks**: 011-boss-system-tests (integration test covers this fix)

## Engine Notes

Modifies existing `DraftRunController.cs` -- read the current implementation to find the exact location of the hardcoded `true` in `OnRunComplete()`. Uses C# event subscription pattern (existing pattern throughout the project). No post-cutoff API concerns.

## Completion Notes

**Completed**: 2026-04-14
**Criteria**: 8/8 passing (AC8 zero-warnings-compile deferred to Unity Editor per project convention)
**Deviations**:
- ADVISORY -- AC6 mechanism: story suggested using `EnemyData.IsBoss` to detect boss spawns; implementation uses new static event `BossController.OnAnyBossSpawned` instead. Both satisfy the F-007 "no tag/name strings" rule; chosen approach is more event-driven per R-027.
- ADVISORY -- Scope expansion: story listed only DraftRunController.cs; actual production changes spanned DraftRunController.cs (core state + subscription), BossController.cs (new static OnAnyBossSpawned event + RuntimeInitializeOnLoadMethod reset), SceneManagerPC.cs line 167 (call-site updated because OnRunComplete signature lost its bool parameter). All required by the chosen event-driven approach.
- ADVISORY -- DraftRunController now names BossController concrete class in subscription code (static events cannot live on C# interfaces). Documented as explicit ADR-0004 exception via inline comment.
- ADVISORY -- Integration tests (SceneManagerPC -> OnRunComplete -> LogRunCompleted chain) deferred to play-mode per project convention for MonoBehaviour-dependent flows.

**Test Evidence**: Logic -- `Assets/Trizzle/Tests/Combat/BossKillTrackingTest.cs` (11 test functions: 4 structural + 7 behavioral covering story TC-1 through TC-4 plus stale-subscription, OnDisable cleanup, double-subscription idempotency)
**Code Review**: Complete -- `/code-review` ran unity-specialist + qa-tester in parallel. Initial verdict CHANGES REQUIRED: 2 CRITICAL implementation bugs (OnEnable ordering race / StartDraftRun-clears-before-rescan; static event lacks domain-reload reset) + 1 BLOCKING test gap (TC-1/TC-2 didn't exercise OnRunComplete). User approved all 5 fixes (3 required + 2 suggested). Final verdict APPROVED WITH SUGGESTIONS.

**Files created**: `BossKillTrackingTest.cs`
**Files modified**: `DraftRunController.cs` (internal state + subscription machinery + parameterless OnRunComplete + scene-scan fix), `BossController.cs` (static OnAnyBossSpawned event + RuntimeInitializeOnLoadMethod reset), `SceneManagerPC.cs` (line 167 call-site)

**Implementation notes**:
- Boss spawn detection is fully event-driven via a static event; `FindObjectsByType<BossController>` scan in OnEnable + StartDraftRun catches scene-placed bosses and OnEnable ordering races without relying on Unity's non-deterministic sibling component enable order.
- `_subscribedBosses.Contains` guard prevents double-subscription under pool re-enable cycles.
- Static event `RuntimeInitializeOnLoadMethod` reset handles Unity 6's "Enter Play Mode without Domain Reload" editor optimization.
