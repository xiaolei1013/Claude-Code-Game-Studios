# Story: Discovery Persistence

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-combo-006 (discoveredFlag persisted per-combo in save data; tracks lifetime discovery across campaign and Endless)
**ADR Reference**: ADR-0003 -- Migration Plan step 9 ("serialize discoveredFlag per ComboDefinition index. Hook IComboRegistry.OnComboDiscovered to set the flag and mark save data dirty"), Decision section ("discoveredFlag on ComboDefinition; save data serialization")
**Control Manifest Rules**: F-003 (no runtime writes to SO assets -- discoveredFlag persistence lives in save data, not on the SO)

## Description

Extend the save/load system to persist combo discovery state. When a player discovers a combo for the first time ever, the `discoveredFlag` is recorded in save data so it persists across sessions and runs. This flag is separate from the per-run combo activation state (which resets each run per TR-combo-007).

**Important distinction:**
- `ComboDefinition.discoveredFlag` on the SO is an Inspector-visible default, NOT the runtime persistence mechanism (writing to SOs at runtime violates F-003)
- The actual persistence lives in the save data system (likely `PlayerSaveData` or equivalent)
- At load time, discovery state is read from save data and applied to the runtime combo system

**Files to modify:**

1. **Extend save data structure** (e.g., `PlayerSaveData.cs` or equivalent):
   - Add `List<string> discoveredComboNames` (or `HashSet<string>`) to the save data
   - Alternatively, `List<int> discoveredComboIndices` if combos are indexed by position in `ComboDatabase`
   - String-based (by combo name) is more robust against reordering combos in the database

2. **Hook into `IComboRegistry.OnComboDiscovered`** (in save data manager or `ComboRegistry` itself):
   - When `OnComboDiscovered` fires, check if this combo is already in the save data's discovered list
   - If not, add it and mark save data dirty (triggers auto-save or queues for next save point)
   - This is a fire-and-forget subscription -- it does not block the combo activation flow

3. **Load-time initialization:**
   - On game load, read `discoveredComboNames` from save data
   - Make this available to any system that needs it (e.g., future achievements system)
   - The combo discovery UI flash fires every run regardless of `discoveredFlag` (GDD Open Question 3)

**What discoveredFlag is used for (v1.0):**
- Lifetime tracking: "how many combos has this player ever discovered?"
- Future: Achievement system (N3) will read this for "Discover 10 combos" type achievements
- Future: Codex/stats screen could display discovered vs total combos

**What discoveredFlag is NOT used for (v1.0):**
- Gameplay: does not affect combo activation, draft weighting, or effect behavior
- UI suppression: the discovery flash plays every run, not just first time

## Acceptance Criteria

- [ ] Save data structure includes a collection for discovered combo identifiers
- [ ] When `OnComboDiscovered` fires for a first-ever discovery, save data is updated
- [ ] Duplicate discoveries do not create duplicate entries in save data
- [ ] Save data persists across application quit and relaunch
- [ ] Loading save data correctly restores the discovered combo set
- [ ] No runtime writes to `ComboDatabase.asset` or `ComboDefinition` ScriptableObject fields (F-003)
- [ ] GDD Acceptance Criterion 6: Discover a combo, quit, reload -- `discoveredFlag` is true in save data
- [ ] Null-safe: if save data has no discovered combos (new save), system initializes empty with no errors

## Test Evidence

**Type**: Unit Test + Integration Test
**Path**: `Assets/Trizzle/Tests/Combo/`

- Unit test: Fire `OnComboDiscovered` with a new combo. Verify save data contains the combo name.
- Unit test: Fire `OnComboDiscovered` with an already-discovered combo. Verify no duplicate in save data.
- Unit test: Serialize save data with 3 discovered combos. Deserialize. Verify all 3 present.
- Integration test: Discover combo in-game, save, reload, verify persistence (requires save/load integration)

## Dependencies

- **Blocked by**: 002-combo-effect-base-class (needs IComboRegistry.OnComboDiscovered event)
- **Soft dependency on**: Existing save/load system (D11). Must understand the current save data structure and serialization format before extending it.
- **Blocks**: None -- this is a persistence enhancement, not a gameplay blocker

## Engine Notes

Uses Unity's existing save system (likely `JsonUtility`, `PlayerPrefs`, or a custom serialization system). Extending a `[Serializable]` save data class with a new `List<string>` field is safe -- `JsonUtility` handles missing fields gracefully on deserialization (defaults to empty list). If the project uses a binary serializer, verify that adding a field does not break existing save compatibility. Check the existing save/load code in `Assets/Trizzle/Scripts/Manager/` before modifying.

## Completion Notes
**Completed**: 2026-04-16
**Criteria**: 8/8 passing (all ACs covered by automated tests)
**Deviations**:
- ADVISORY: Cloud sync not wired — local PlayerPrefs only. Story scoped local-first for v1.0; cloud sync via `CloudServiceManager.UserDataToCloud` is a known followup.
- ADVISORY: `ComboDiscoveryTracker` not yet scene-attached. Tests verify the mechanism via reflection; live in-game verification deferred to PR #118 scene-wire work (same pending scope as `ComboRegistry` scene-attach).
**Test Evidence**: 2 files, 21 tests in `Assets/Trizzle/Tests/Combo/`:
- `ComboDiscoveryStoreTest.cs` (13 unit tests — pure C#, zero Unity dep)
- `ComboDiscoveryTrackerTest.cs` (8 integration tests — PlayerPrefs roundtrip + end-to-end event path + corrupt-JSON recovery)
**Code Review**: Completed via `/simplify` + `/code-review` (Lean mode). 3 post-review fixes applied: OnDestroy unsubscribe hygiene, end-to-end AC-2 event-path test, corrupt-JSON recovery test. LP-CODE-REVIEW + QL-TEST-COVERAGE gates skipped per Lean mode.
**Files delivered** (4 production + 2 tests):
- `Assets/Trizzle/Scripts/Manager/ComboDiscoveryData.cs` — serializable DTO
- `Assets/Trizzle/Scripts/Manager/ComboDiscoveryStore.cs` — pure C# store with `OnFirstDiscovery` dedup event + zero-alloc `DiscoveredIds` view
- `Assets/Trizzle/Scripts/Manager/ComboDiscoveryPersistence.cs` — static PlayerPrefs + Newtonsoft JsonConvert I/O (matches `UserManager` pattern)
- `Assets/Trizzle/Scripts/Manager/ComboDiscoveryTracker.cs` — MonoBehaviour glue: subscribes `ComboRegistry.OnComboDiscovered` → Store → Persistence
- `Assets/Trizzle/Tests/Combo/ComboDiscoveryStoreTest.cs`
- `Assets/Trizzle/Tests/Combo/ComboDiscoveryTrackerTest.cs`
**Known out-of-scope followups**:
- `ComboDiscoveryTracker` scene-attach + `_comboRegistry` Inspector wire — pending PR #118 (same scope as ComboRegistry scene-wire; not blocking E4-008 closure)
- Cloud sync integration via `UserDataToCloud` batch — v1.0 scope allows local PlayerPrefs; cloud sync is a separate enhancement
