# Story: PoisonState Stack Extension

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P2
> **Status**: Draft
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-007 (deferred portion — PoisonArrow stacking)
**ADR Reference**: ADR-0005 — Decision item 6 (PoisonArrow skill)
**Control Manifest Rules**: F-017 (MonoBehaviour + SO + interface only)

This story is a scope deferral spun out of N1-006 (Archer Exclusive Skills). During implementation of that story, the PoisonArrow skill's "stacks up to 3 times" acceptance criterion could not be satisfied because the existing `PoisonState` and `StateEffect` classes do not support stacking:

- `PoisonState` uses a constant `Coefficient = 1.5f` multiplier per tick — no stack counter field, no stack-aware damage math.
- `StateEffect(StateType, StateCategory, duration, EffectTrigger)` does not accept or forward a stack count parameter.

Rather than silently shipping a non-stacking PoisonArrow while the AC still claimed it stacked, N1-006 amended its AC to defer stacking to this follow-up. This story implements the underlying status-effect stacking mechanism so PoisonArrow (and any future stackable DoT) can rely on it.

## Description

Extend the `PoisonState` + `StateEffect` + `StateMachine` pipeline to support stackable status effects, then re-enable stacking on `PoisonArrowSkill`.

**Files to modify:**

1. **`PoisonState.cs`** — Add `int StackCount` field. Damage-per-tick formula becomes `baseCoefficient * StackCount`. On re-entry while already active, increment stack count up to `_maxStacks`. Expose `GetStackCount()` for tests.

2. **`StateEffect.cs`** — Add optional constructor parameter `int maxStacks = 1`. On `Apply`, if the target is already in the same state, call a new `StateMachine.RefreshOrStack(StateCategory, maxStacks)` method instead of the current `SwitchState()` path.

3. **`StateMachine.cs`** — Add `RefreshOrStack(StateCategory, int maxStacks)`: if current state matches category and supports stacking, increment its stack counter (capped); otherwise behave like `SwitchState()`.

4. **`PoisonArrowSkill.cs`** — Restore the `_maxStacks` field (default 3) and pass it through to the new `StateEffect` constructor. Update doc comment to remove the "stacking not implemented" disclaimer.

5. **`PoisonAttackSkill.cs`** — Existing mage precedent skill. Either update to use new API (opt-in stacking, default single-stack preserves current behavior) or leave alone. Coordinate with whichever is lower-risk.

## Acceptance Criteria

- [ ] `PoisonState` has `StackCount` field, starts at 1, incrementable up to `_maxStacks`
- [ ] DoT damage per tick scales linearly with stack count: `damage = baseCoefficient * StackCount`
- [ ] Re-applying PoisonArrow to an already-poisoned target increments stack count (not refreshes duration only, not replaces)
- [ ] Stack count is capped at `_maxStacks` (default 3 for PoisonArrow)
- [ ] When a stacked PoisonState expires, stack count returns to 0 (next apply starts at stack 1)
- [ ] `PoisonArrowSkill._maxStacks = 3` is Inspector-editable via `[SerializeField]`
- [ ] Existing `PoisonAttackSkill` (mage) behavior is NOT regressed — if unchanged, remains single-stack; if updated, single-stack default preserves current feel
- [ ] F-017 compliant (no new patterns introduced)

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/StateMachine/PoisonStateStackTest.cs`

- Unit test: Fresh PoisonState has `StackCount == 1`
- Unit test: Re-entry increments `StackCount` to 2, then 3, caps at 3
- Unit test: Fourth entry does NOT increment beyond cap
- Unit test: DoT tick damage at StackCount=2 is 2x damage at StackCount=1
- Unit test: `PoisonArrowSkill.GetMaxStacks() == 3` (restored default)
- Unit test: Expiring state resets `StackCount` to 0
- Unit test: `PoisonAttackSkill` (mage) default behavior preserved — no regression

## Dependencies

- **Blocked by**: 006-archer-exclusive-skills (PoisonArrowSkill must exist without stacking first)
- **Blocks**: Full N1 acceptance (TR-archer-007 stacking requirement closed)

## Engine Notes

`PoisonState` is referenced by multiple skills (`PoisonAttackSkill`, `PoisonArrowSkill`, possibly NPC effects). Audit all callers before modifying. The change is additive — default `maxStacks = 1` on the new constructor must preserve existing single-stack behavior wherever the legacy constructor was used. Prefer constructor overload over breaking-change parameter insertion.

## Notes

Amended AC on N1-006 (line 89) references this story by file name. Keep the filename `010-poison-state-stack-extension.md` stable — renaming breaks the traceability link.
