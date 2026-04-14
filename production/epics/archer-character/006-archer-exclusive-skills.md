# Story: Archer Exclusive Skills (7)

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: XL

## Context

**GDD Requirement**: TR-archer-007 (7 new archer-exclusive skills: PiercingArrow, Multishot, PoisonArrow, Afterimage, CounterRoll, Quickdraw, EagleEye)
**ADR Reference**: ADR-0005 -- Decision item 6 (seven UpgradableSkill-derived ScriptableObject assets in `Assets/Trizzle/Data/Skill/Archer/`)
**Control Manifest Rules**: R-023 (archer-exclusive skill assets in `Assets/Trizzle/Data/Skill/Archer/`), F-010 (no MagePlayerController casts), F-012 (no per-frame polling for trigger conditions -- use events), F-017 (MonoBehaviour + SO + interface only)

## Description

Create all 7 archer-exclusive skill ScriptableObjects. Each skill's `compatibleUpgradeTypes` field references `ArrowShotSkill` or `DodgeRollSkill` as appropriate, so `CanApplyUpgrade()` handles class filtering with no new logic.

**Files to create in `Assets/Trizzle/Data/Skill/Archer/`:**

### Arrow Upgrades (3)

1. **PiercingArrow** (`PiercingArrow.asset`)
   - Arrows pass through enemies, hitting up to 3 targets in a line
   - Damage reduced 20% per pierce: `damage = baseDamage * (0.8 ^ pierceIndex)`
   - Target 1: 1.0x, Target 2: 0.8x, Target 3: 0.64x
   - `compatibleUpgradeTypes` references `ArrowShotSkill`
   - Tuning knobs: `_maxPierceTargets = 3`, `_pierceFalloff = 0.8f`

2. **Multishot** (`Multishot.asset`)
   - Fires 3 arrows in a fan spread instead of 1
   - Each arrow deals 50% damage: `perArrowDamage = baseDamage * 0.5`
   - Total DPS if all 3 hit = 1.5x (requires clustered enemies)
   - `compatibleUpgradeTypes` references `ArrowShotSkill`
   - Tuning knobs: `_arrowCount = 3`, `_damagePerArrow = 0.5f`

3. **PoisonArrow** (`PoisonArrow.asset`)
   - Arrows apply Poison status on hit (DoT over 4s)
   - Uses existing `PoisonState` via `StateEffect` (upstream: D3 Status Effects)
   - `compatibleUpgradeTypes` references `ArrowShotSkill`
   - Tuning knob: `_poisonDuration = 4f`
   - **Stacking deferred to story 010-poison-state-stack-extension** — `PoisonState`/`StateEffect` do not currently support stack counts. Follow-up story adds `StackCount` field + stack-aware DoT math, then re-enables `_maxStacks = 3` here.

### Dodge Upgrades (2)

4. **Afterimage** (`Afterimage.asset`)
   - Dodge roll leaves a decoy at the start position for 2s
   - Decoy has 1 HP, draws enemy aggro, destroyed by any hit (GDD Edge Case 10, TR-archer-010)
   - Enemies targeting decoy switch to player when decoy dies
   - Decoy does NOT block projectiles
   - `compatibleUpgradeTypes` references `DodgeRollSkill`
   - Tuning knobs: `_decoyDuration = 2f`, `_decoyHealth = 1`
   - Requires: Decoy must be targetable by enemy BehaviourTree (upstream: D5 Enemy AI)

5. **CounterRoll** (`CounterRoll.asset`)
   - If dodge roll i-frames block an attack, next Arrow Shot deals 2x damage
   - 3s window to use the buff; expires if no attack within window
   - No stacking -- a second i-frame block refreshes the 3s window (GDD Edge Case 6)
   - `compatibleUpgradeTypes` references `DodgeRollSkill`
   - Tuning knobs: `_damageMultiplier = 2.0f`, `_buffWindow = 3.0f`

### Passives (2)

6. **Quickdraw** (`Quickdraw.asset`)
   - After dodge roll ends, attack speed +50% for 2s
   - Implementation: `cooldownTime = baseCooldownTime * 0.5` during buff window
   - Effectively doubles fire rate during the window
   - Stacks with CounterRoll intentionally (GDD Edge Case 7: "massive burst window after well-timed dodge")
   - Tuning knobs: `_attackSpeedBuff = 0.5f`, `_buffDuration = 2.0f`

7. **EagleEye** (`EagleEye.asset`)
   - +30% crit chance against enemies beyond 50% of attack range
   - `if (distanceToTarget > attackRange * 0.5): effectiveCritChance += 0.30`
   - Rewards maintaining distance -- core archer kiting fantasy
   - Tuning knobs: `_critBonus = 0.30f`, `_rangeThreshold = 0.5f`

**Interaction edge cases (from GDD):**
- **Piercing + Multishot**: Each of 3 fan arrows can independently pierce up to 3 targets. Max hits per shot = 9. Both track pierce count independently.
- **Quickdraw + CounterRoll**: Both can be active simultaneously. This is intentional design -- reward for skilled dodge-to-attack weaving.
- **Afterimage decoy aggro**: Decoy draws enemy targeting. When destroyed, enemies return to targeting player. Decoy does not block projectiles.

## Acceptance Criteria

- [ ] All 7 skill assets exist in `Assets/Trizzle/Data/Skill/Archer/`
- [ ] PiercingArrow: Arrows pierce up to 3 targets with 0.8x damage falloff per pierce
- [ ] Multishot: 3 arrows fire in fan spread, each dealing 0.5x damage
- [ ] PoisonArrow: Applies Poison status on hit, DoT over 4s (stacking deferred to follow-up story 010-poison-state-stack-extension)
- [ ] Afterimage: Decoy spawned at roll origin, 1 HP, 2s duration, draws enemy aggro
- [ ] CounterRoll: 2x damage buff for 3s on i-frame block; no stacking, refreshes window
- [ ] Quickdraw: +50% attack speed for 2s after dodge roll ends
- [ ] EagleEye: +30% crit chance vs targets beyond 50% of attack range
- [ ] All `compatibleUpgradeTypes` correctly reference ArrowShotSkill or DodgeRollSkill as appropriate
- [ ] All tuning knob values are Inspector-editable via `[SerializeField]`
- [ ] GDD Acceptance Criterion 8: "All 7 new skills: Piercing Arrow pierces 3 targets, Multishot fires 3 arrows, Poison Arrow applies Poison state, Afterimage spawns decoy, Counter Roll buffs next shot, Quickdraw speeds up attacks, Eagle Eye adds crit at range."

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/archer/`

- Unit test: PiercingArrow damage falloff: target 1 = 1.0x, target 2 = 0.8x, target 3 = 0.64x
- Unit test: Multishot per-arrow damage = 0.5x base
- Unit test: PoisonArrow applies PoisonState on hit, duration = 4s (stacking test moved to story 010)
- Unit test: CounterRoll buff expires after 3s; second trigger refreshes window (no stack)
- Unit test: Quickdraw `cooldownTime = baseCooldownTime * 0.5` during buff window
- Unit test: EagleEye crit bonus applied only when `distance > attackRange * 0.5`
- Unit test: All 7 skills have correct `compatibleUpgradeTypes` (arrow upgrades -> ArrowShotSkill, dodge upgrades -> DodgeRollSkill)

## Dependencies

- **Blocked by**: 003-arrow-shot-skill (ArrowShotSkill must exist for arrow upgrades), 004-dodge-roll-skill (DodgeRollSkill must exist for dodge upgrades)
- **Blocks**: 007-draft-pool-filtering (draft pool needs archer skills to filter), 009-archer-character-tests

## Engine Notes

Uses `UpgradableSkill` SO subclasses and the existing `Effect` system -- same pattern as existing Mage skill upgrades. Afterimage decoy requires spawning a targetable entity for enemy BehaviourTree -- verify the AI targeting system can handle non-player targetables. PoisonArrow uses `StateMachine.SwitchState()` for status effect application -- verify the PoisonState class exists and supports stacking.

## Completion Notes

**Completed**: 2026-04-14
**Criteria**: 10/10 covered (stacking deferred to story 010-poison-state-stack-extension)
**Deviations**:
- Test path: `Assets/Trizzle/Tests/Character/Archer/ArcherExclusiveSkillsTest.cs` (Unity requires tests under `Assets/`; spec's `tests/unit/archer/` was notional)
- PoisonArrow stacking deferred to `010-poison-state-stack-extension.md`
- `.asset` ScriptableObject instances authored via editor menu helper (below) rather than per-class `[CreateAssetMenu]` — one-shot bulk author avoided 7× manual editor clicks
**Test Evidence**: `Assets/Trizzle/Tests/Character/Archer/ArcherExclusiveSkillsTest.cs` (35+ unit tests + 2 `[UnityTest]` play-mode cases)
**Code Review**: Complete (3 passes — APPROVED WITH SUGGESTIONS; defensive tweaks and play-mode test expansion logged as follow-ups)
**Playtest Evidence**: `production/session-logs/playtest-sprint-03-archer-skills.md` — 9/9 behavioral checklist items PASS, `/team-qa sprint` sign-off APPROVED (session-local; evidence retained in solo-dev session logs)

### Reopen/close history

Briefly reopened 2026-04-14 during `/team-qa` Phase 4 when QA discovered that
`Assets/Trizzle/Data/Skill/Archer/` did not exist on disk — original completion
was premature (classes shipped, instances not authored). Resolved same day:
- `Assets/Trizzle/Editor/CreateArcherSkillAssets.cs` helper added (Unity menu: `Trizzle → QA Tools → Create Archer Skill Assets`) — idempotent, one-shot bulk creator
- 7 `.asset` instances authored, committed, and merged to `main` via Trizzle PR #117
- `/team-qa sprint` resumed and signed off (see `production/qa/qa-signoff-sprint-03-2026-04-14.md`)
