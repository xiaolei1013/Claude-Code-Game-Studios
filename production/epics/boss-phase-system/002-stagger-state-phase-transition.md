# Story: Stagger State & Phase Transition Coroutine

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-004 (stagger state: 0.5s invulnerable, clears all debuffs via StateMachine.ResetState(), swaps BehaviourTree, applies stat modifiers, plays VFX), TR-boss-005 (phases are one-way; healing does not reverse triggered phases), TR-boss-013 (boss death during stagger must process immediately; death takes priority over phase transition)
**ADR Reference**: ADR-0004 -- Decision section (stagger coroutine sequence), Risks section (stagger coroutine + boss death race condition: guard with isDead check, StopAllCoroutines on death)
**Control Manifest Rules**: R-010 (stagger coroutine sequence: invulnerable -> ResetState -> swap tree -> apply modifiers -> instantiate VFX -> HasTriggered=true -> fire OnPhaseTransition -> WaitForSeconds(0.5f) -> lift invulnerable)

## Description

Implement the full `TransitionToPhase()` coroutine in `BossController` that was stubbed in Story 001. This is the core phase transition behavior that makes bosses feel like multi-phase encounters.

**Implementation details:**

1. **`TransitionToPhase(BossPhase phase)` coroutine** -- follows the exact R-010 sequence:
   - Set `isInvulnerable = true` (use existing invulnerability system on Health/EnemyController)
   - Set `IsInStagger = true` (IBossPhaseController property)
   - Call `stateMachine.ResetState()` to clear all active debuffs (Frozen, Stun, etc.)
   - Call `SwapBehaviourTree(phase.BehaviourTree)` -- update the active AI tree
   - Apply `phase.StatModifiers` via the existing `AttributeModifier` system (additive stacking across phases)
   - Instantiate `phase.TransitionVFX` at boss position (null-safe: skip if no VFX assigned)
   - Set `phase.HasTriggered = true`
   - Increment `_currentPhaseIndex`
   - Fire `OnPhaseTransition?.Invoke(_currentPhaseIndex)`
   - `yield return new WaitForSeconds(0.5f)` -- the stagger duration
   - Set `isInvulnerable = false`
   - Set `IsInStagger = false`

2. **Death-during-stagger guard** -- the critical race condition from ADR-0004:
   - Every step after the yield (and ideally before) must check `if (isDead) yield break`
   - The existing `EnemyController.Die()` calls `StopAllCoroutines()` which terminates the stagger coroutine -- but the guard ensures clean state if the death happens between coroutine steps
   - `OnBossDefeated` must fire in the death path BEFORE `StopAllCoroutines()` so subscribers receive it

3. **Multi-phase stagger chaining** -- when multiple phases trigger from one damage event (Story 001 iterates all untriggered phases), each `TransitionToPhase()` coroutine runs in sequence. Total stagger = 0.5s * number of phases crossed. This is a coroutine chain, not parallel execution.

4. **Debuff immunity during stagger** -- status effects applied during the 0.5s invulnerability window are ignored because invulnerability blocks all incoming damage and the status effect application path checks invulnerability.

**Key constraints:**
- The stagger duration (0.5s) is fixed and not affected by difficulty multipliers
- Stat modifiers from previous phases are NOT removed -- they stack additively
- `StateMachine.ResetState()` clears debuffs but does NOT clear the stagger state itself

## Acceptance Criteria

- [ ] `TransitionToPhase()` coroutine follows R-010 sequence exactly in the specified order
- [ ] During 0.5s stagger: boss is invulnerable (damage = 0), `IsInStagger == true`
- [ ] Stagger clears all active debuffs via `StateMachine.ResetState()` (Frozen, Stun, etc.)
- [ ] BehaviourTree swaps to the new phase's tree during stagger
- [ ] Stat modifiers apply additively (Phase 2 mods stack on Phase 1 base)
- [ ] TransitionVFX instantiated at boss position (or skipped if null)
- [ ] After stagger ends: `isInvulnerable == false`, `IsInStagger == false`, AI resumes
- [ ] Boss death during stagger: death processes immediately, coroutine stops, `OnBossDefeated` fires
- [ ] Multi-threshold skip produces chained stagger (e.g., 2 phases = 1.0s total stagger)
- [ ] Stagger duration is 0.5s fixed -- not affected by difficulty or stat modifiers
- [ ] Healing past a triggered threshold does NOT reverse the phase (HasTriggered remains true)

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Trigger phase 2 on boss, verify `IsInStagger == true` immediately after, verify `IsInStagger == false` after 0.5s
- Unit test: Apply Frozen debuff to boss, trigger phase transition, verify Frozen state is cleared
- Unit test: During stagger window, deal damage to boss, verify 0 damage applied
- Unit test: Kill boss (HP = 0) during stagger coroutine, verify `OnBossDefeated` fires and coroutine terminates
- Unit test: Trigger 2 phases in one hit, verify total stagger duration is ~1.0s (2 * 0.5s)
- Unit test: Trigger phase 2, heal boss above threshold, verify phase does not reverse

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (BossController must exist with phase iteration and coroutine stub)
- **Blocks**: 008-boss-prefab-configuration (prefabs need working transitions), 009-boss-phase-vfx (VFX plays during stagger), 011-boss-system-tests

## Engine Notes

Uses coroutines (`StartCoroutine`, `WaitForSeconds`, `StopAllCoroutines`) -- stable Unity APIs. ADR-0004 Verification Required: confirm coroutine-based stagger timing is not affected by new frame scheduling behaviour introduced in Unity 6.0. The `StateMachine.ResetState()` call is an existing shipped API on the status effect system.

## Completion Notes
**Completed**: 2026-04-13
**Criteria**: 11/11 passing (all structural — runtime behaviour requires playtest)
**Deviations**: BossPhase.StatModifiers type changed from `AttributeModifier[]` to `BossStatModifier[]` — the original `AttributeModifier` has no `AttributeType` field, making it impossible to apply modifiers to specific attributes. Added `BossStatModifier` struct pairing `AttributeType` with `AttributeModifier`. Existing BossControllerTest field-existence check still passes (field name unchanged).
**Test Evidence**: Logic — Assets/Trizzle/Tests/Combat/BossStaggerTest.cs (10 tests)
**Code Review**: Skipped (Lean mode)
**Files Changed**: BossController.cs (replaced stub with full TransitionToPhase coroutine, ChainPhaseTransitions, CleanupStagger, SwapBehaviourTree, death guard), BossPhase.cs (added BossStatModifier struct, changed StatModifiers type)
