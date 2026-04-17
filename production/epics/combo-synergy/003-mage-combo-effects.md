# Story: Mage Combo Effects (5)

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L
>
> **Amended 2026-04-16** — code audit during `/dev-story` found 4 mismatches between original spec and shipped APIs. See ADR-0003 Amendment section. Changes below flagged with ⚠ AMENDED.

## Context

**GDD Requirement**: TR-combo-002 (18 concrete ComboEffect implementations -- 5 Mage-exclusive), TR-combo-003 (trigger conditions via event subscription)
**ADR Reference**: ADR-0003 -- Decision section (concrete subclass authoring pattern, InfernoComboEffect, BlizzardComboEffect, VenomComboEffect examples), ScriptableObject Asset Organization (Data/Combos/Effects/Mage/)
**Control Manifest Rules**: R-011 (Activate registers listeners, Deactivate reverses), R-012 (Activate calls Deactivate first), R-019 (ComboEffect as abstract SO), R-023 (combo effect assets in Data/Combos/Effects/Mage/), R-026 (OnSkillUse subscribes to PlayerController.OnSkillUsed, OnKill to Health.OnDied/OnEnemyKilled, Passive applies AttributeModifier), F-012 (no polling), F-013 (no MonoBehaviour), G-002 (< 0.5ms/frame combo budget)

## Description

Implement the 5 Mage-exclusive `ComboEffect` ScriptableObject subclasses. Each is a concrete C# class extending `ComboEffect` with a corresponding `.asset` file. These upgrade the existing 5 Mage fallback combos (currently name-only, no gameplay effect) into functional triggered effects.

**Files to create (5 C# classes + 5 .asset files):**

### 1. InfernoComboEffect (Fireball + BurnAttackSkill, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/InfernoComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/InfernoComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed` in `Activate()` (⚠ AMENDED: event is new, added in this branch — signature `Action<BaseSkill, Vector3>`)
- **Behavior**: When Fireball or BurnAttack is used, spawn a burning ground patch at the player's cast-commit position (the `Vector3` payload of the event)
- **SerializeField tuning knobs**: `_burnDuration` (default 3.0f, range 1.0-6.0), `_burnTickInterval` (default 0.5f), `_burnRadius` (default 2.0f), `_burnPatchPrefab` (GameObject reference)
- **⚠ AMENDED Implementation**: `SpawnManager.SpawnGroundPatch` does NOT exist. Follow the `IcePondSkill.CreateIcePond` pattern (`Assets/Trizzle/Scripts/Character/Skill/Defense/IcePondSkill.cs:84-96`): `Instantiate(_burnPatchPrefab, ctx.TriggerPosition, Quaternion.identity)`, call `burnPatch.GetComponent<BurnPatchArea>().Initialize(_burnDuration, _burnTickInterval, _burnRadius)`, then `Destroy(burnPatch, _burnDuration)`. A new `BurnPatchArea` MonoBehaviour is authored in this branch (mirror of `IcePondArea`). The `.prefab` is authored in the Unity Editor post-merge.
- In `OnTrigger()`, check if `ctx.TriggeringSkill is FireballSkill || ctx.TriggeringSkill is BurnAttackSkill`. If yes, spawn the patch.
- **Deactivate**: Unsubscribe from `OnSkillUsed`. Active ground patches despawn naturally on their timer.

### 2. BlizzardComboEffect (FrostShardSkill + FreezeAttackSkill, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/BlizzardComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/BlizzardComboEffect.asset`

- **Trigger**: OnKill -- subscribe to `Health.OnDead` (⚠ AMENDED: correct name is `OnDead` not `OnDied`, signature is parameterless `Action`). Subscription strategy: on `Activate()`, subscribe to a spawn-hook to catch newly-spawned enemies; subscribe each enemy's `Health.OnDead` with a closure that captures that enemy's `Health` ref. Alternative for MVP: subscribe to all currently-spawned enemies' `Health.OnDead` at `Activate()` + whenever a new enemy spawns. Confirm available enemy-spawn hook during impl (likely `SpawnManager.OnEnemySpawned` if present, else hook directly into `EnemyController.OnEnable`).
- **Behavior**: When a frozen enemy dies, spawn a frost nova at death position (3-unit radius, applies Slow)
- **SerializeField tuning knobs**: `_frostNovaRadius` (default 3.0f, range 1.5-5.0), `_slowDurationMs` (default 2000f)
- **⚠ AMENDED Implementation**: In the kill-handler, check killed enemy's `Health.GetStateMachine().HasDebuffState(StateCategory.Frozen)` (correct API — `HasDebuffState` not `HasState`). If frozen: `Physics.OverlapSphere()` (⚠ 3D, NOT `Physics2D.OverlapCircle`) at death position. For each nearby enemy, call `stateMachine.SwitchState(StateType.Debuff, StateCategory.MoveSpeedDown, new SlowState(sm, _slowDurationMs))` (correct enum is `MoveSpeedDown`, not `Slowed`). If not frozen at death, no nova (Edge Case 8).
- **Deactivate**: Unsubscribe from every enemy's `Health.OnDead` that was subscribed in `Activate()`.

### 3. ThunderstrikeComboEffect (LightningBoltSkill + StunAttackSkill, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/ThunderstrikeComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/ThunderstrikeComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed` (⚠ AMENDED: event is new — see Inferno note)
- **Behavior**: Stunned enemies take 2x damage from Lightning attacks
- **SerializeField tuning knobs**: `_damageMultiplier` (default 2.0f, range 1.5-3.0), `_bonusRadius` (default 2.0f)
- **⚠ AMENDED Implementation**: `OnSkillUsed` event does NOT carry a target. For Thunderstrike, find stunned enemies near the cast position: `Physics.OverlapSphere(ctx.TriggerPosition, _bonusRadius, enemyLayerMask)`, filter by `enemy.GetComponent<Health>().GetStateMachine().HasDebuffState(StateCategory.Stun)` (correct enum is `Stun`). For each stunned enemy, compute `bonusDamage = baseHit * (_damageMultiplier - 1f)` and apply via `enemyHealth.TakeDamage((int)bonusDamage)`. Only fires when `ctx.TriggeringSkill is LightningBoltSkill`. Base hit damage is a `SerializeField` constant on the combo (no access to skill damage from event).
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

### 4. VenomComboEffect (PoisonCloudSkill + PoisonAttackSkill, Passive) — ⚠ REDESIGNED (V1)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/VenomComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/VenomComboEffect.asset`

- **Trigger**: Passive -- modifies `PoisonAttackSkill.totalDurationInMs` in `Activate()`, restores in `Deactivate()`. No event subscription.
- **⚠ AMENDED Behavior**: Poison **duration** extended by 50% (1.5× multiplier). Original design (tick interval 1.0s → 0.67s) is not implementable — the poison DoT damage loop is not shipped; only visual state + duration expiry exist. See ADR-0003 Amendment §6 for full rationale. GDD `combo-synergy-expansion.md` updated to match.
- **SerializeField tuning knobs**: `_durationMultiplier` (default 1.5f, range 1.1-2.0), `_poisonSkill` (PoisonAttackSkill asset reference — wired in Inspector)
- **Implementation**: In `Activate()`, use reflection to read the private `totalDurationInMs` field on the wired `_poisonSkill`, store as `_originalDuration`, write back `_originalDuration * _durationMultiplier`. In `Deactivate()`, write `_originalDuration` back via the same reflection path. Guard against double-activation via `_isActive` (R-012). The `_poisonSkill` reference must be non-null — if null, log a warning and skip (fail-safe: Venom simply does nothing).
- **F-003 exception (runtime SO mutation)**: ADR-0003 amendment §6 documents this as a narrow pragmatic exception; symmetric restore in `Deactivate()` + `OnDisable → Deactivate` base fallback protects against persistence. Future work: migrate Venom onto a proper poison-DoT system once shipped.
- **Deactivate**: Restore `totalDurationInMs`. Clear `_originalDuration` tracking.

### 5. SupernovaComboEffect (SolarFlareSkill + ExplosionAttackSkill, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/SupernovaComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/SupernovaComboEffect.asset`

- **Trigger**: OnKill -- subscribe to `Health.OnDead` (⚠ AMENDED: same subscription strategy as Blizzard — parameterless event, subscribe per-enemy)
- **Behavior**: 25% chance on kill to trigger secondary explosion (50% original damage, 4-unit radius)
- **SerializeField tuning knobs**: `_procChance` (default 0.25f, range 0.10-0.50), `_explosionDamage` (default 50f, range 25-150 — ⚠ AMENDED: `Health.OnDead` carries no damage payload, so use flat damage from the SO instead of `ctx.DamageAmount * _damageRatio`), `_explosionRadius` (default 4.0f, range 2.0-6.0)
- **⚠ AMENDED Implementation**: In the kill-handler, roll against `_procChance` via `UnityEngine.Random.value` (tests inject a seeded `System.Random` via reflection on the combo's private `_rng` field for deterministic proc). If proc, `Physics.OverlapSphere(deathPosition, _explosionRadius)` — 3D not 2D. Apply `(int)_explosionDamage` to each enemy's `Health.TakeDamage`. Skip the killed enemy itself (avoid re-damaging the already-dead target).
- **Deactivate**: Unsubscribe from every subscribed `Health.OnDead`.

**Code audit step (per ADR-0003 Consequences):** ⚠ COMPLETED 2026-04-16 — audit found 4 mismatches, all resolved in ADR-0003 Amendment 2026-04-16. Summary: (1) `OnSkillUsed` event is NEW (added in this branch); (2) kill event is `Health.OnDead` (parameterless, not `OnDied`); (3) status check is `HasDebuffState(StateCategory)`; (4) physics is 3D.

**All concrete subclasses must:**
- Call `Deactivate()` as the first line of `Activate()` (R-012)
- Use named methods for event subscription, not anonymous lambdas (zero GC in OnTrigger)
- Not use LINQ or closures in `OnTrigger()` (ADR-0003 Risks)
- Leave the asset in a clean state after `Deactivate()` for reuse next run

## Acceptance Criteria

- [ ] 5 C# class files exist in `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/`
- [ ] 5 `.asset` files exist in `Assets/Trizzle/Data/Combos/Effects/Mage/`
- [ ] All `[SerializeField]` tuning knobs are set to GDD default values in the .asset files
- [ ] Inferno: Fireball use spawns burning ground patch (3s duration, 0.5s tick interval)
- [ ] Blizzard: Frozen enemy kill spawns frost nova (3-unit radius, applies Slow). Non-frozen kill does NOT spawn nova (Edge Case 8).
- [ ] Thunderstrike: Lightning attack on stunned enemy deals 2x damage
- [ ] Venom: Poison duration extended by 50% (1.5×) while combo is active (⚠ AMENDED V1 — original "tick interval 0.67s" not implementable; see ADR-0003 Amendment §6)
- [ ] Supernova: 25% kill proc triggers secondary explosion (50% damage, 4-unit radius)
- [ ] All effects properly `Deactivate()` on run end -- no state leak between runs
- [ ] GDD Acceptance Criterion 2: Fireball + BurnAttack combo produces burning ground patch that ticks for 3s
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/MageEffects/`

- Unit test per effect: `CreateInstance<T>()`, `Activate()`, trigger condition, verify behavior
- Unit test: Venom -- read attribute before Activate, after Activate (reduced), after Deactivate (restored)
- Unit test: Blizzard -- frozen target kill triggers nova; non-frozen target kill does not
- Unit test: Supernova -- proc chance of 1.0 always triggers; proc chance of 0.0 never triggers
- Unit test: All 5 effects -- `Deactivate()` then `Activate()` works cleanly (no double-subscribe)

## Dependencies

- **Blocked by**: 001-extend-combo-definition (needs ComboCategory, TriggerCondition enums), 002-combo-effect-base-class (needs ComboEffect abstract class, TriggerContext)
- **Blocks**: 007-combo-database-population (needs Mage effect assets to wire into ComboDefinition entries), 009-combo-system-tests

## Engine Notes

⚠ AMENDED: Uses `ScriptableObject` subclassing, `[SerializeField]`, `Physics.OverlapSphere` (project is 3D, not 2D), reflection-based private-field mutation on `PoisonAttackSkill` (Venom). `SpawnManager.SpawnGroundPatch` does not exist — Inferno uses the `IcePondSkill.CreateIcePond` prefab-instantiate pattern. See ADR-0003 Amendment 2026-04-16 for full audit results.

## Completion Notes
**Completed**: 2026-04-16
**Criteria**: 11/11 addressed (8 COVERED, 3 DEFERRED AoE playtest — Inferno patch tick / Thunderstrike damage / Supernova explosion AoE; Unity physics can't run in EditMode unit tests, gate-logic tests cover the conditional paths)
**Deviations (all ADVISORY, none blocking)**:
- Scope additions (amendment-documented, valid): `BurnPatchArea` MonoBehaviour (per ADR §5), `PlayerController.OnSkillUsed` event + fire-site (per ADR §1), ComboDatabase `triggerEffect` wiring (in-scope per Unity Editor deferral)
- AC-7 text stale-fixed in this closure to match V1 redesign ("duration × 1.5" not "tick interval 0.67s")
- Thunderstrike `_baseHit < 1` int-truncation edge: flagged in adversarial review, accepted low-priority (default 10 is safe)
**Test Evidence**: Unit — 30 tests across 5 files in `Assets/Trizzle/Tests/Combo/MageEffects/`. All 30 passed in Unity Test Runner post-merge (user confirmed). AoE side-effect verification deferred to playtest.
**Code Review**: 4 review passes during dev (/simplify, gstack /review, studio /code-review, adversarial) — 7 findings applied pre-ship. LP-CODE-REVIEW gate skipped (Lean mode). Zero compile warnings confirmed in Unity Console post-merge.
**PR**: https://github.com/xiaolei1013/Trizzle/pull/120 — merged `7bd69ae4c` into main.
**Unity Editor authoring**: BurnPatch.prefab created, 5 Mage .asset files authored via `Trizzle → QA Tools → Create Mage Combo Effect Assets` menu, SerializeField refs wired via Unity MCP (Inferno prefab, Venom PoisonAttackSkill, 4× Enemies LayerMask = 8192), ComboDatabase.triggerEffect × 5 wired.
**Known out-of-scope followups (not blocking this story)**:
- ComboDatabase `skillA`/`skillB` still null on all 5 Mage entries — **E4-007** scope (ComboDatabase population). Combos won't actually discover in-game until wired.
- `ComboRegistry` MonoBehaviour scene-attach + `DraftRunController._comboRegistry` Inspector wire — pending since PR #118 merge. Scene-level work, separate followup.
- AoE playtest verification for Inferno patch tick / Thunderstrike bonus damage / Supernova explosion — full integration tests deferred until the two above are resolved and combos can actually fire in-game.
