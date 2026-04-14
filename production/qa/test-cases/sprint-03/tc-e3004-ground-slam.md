# Manual Test Cases: E3-004 Ground Slam

**Sprint**: 3 | **Date**: 2026-04-14
**Session target**: 15 minutes
**Sign-off required**: qa-lead + game-designer
**Evidence destination**: `production/session-logs/playtest-sprint-03-ground-slam.md`

---

### TC-E3004-00: Test boss prefab setup (prerequisite)
**Preconditions**: Unity Editor open. Console clear.
**Steps**:
1. Hierarchy → create empty `TestBoss_GroundSlam`.
2. Add `EnemyController` component, `IsBoss = true`.
3. Add `StateMachine`. Set Attack = 20 (record value).
4. Add `GroundSlamAbility`. Verify defaults: `Telegraph = 0.8`, `Radius = 5`, `Multiplier = 1.5`. Assign `_telegraphVFX` and `_impactVFX` (any particle prefab).
5. Add `NavMeshAgent` if absent.
6. Place Player object with Health + StateMachine ≤3 units away.
7. Save scene as `QA_GroundSlam_Test.unity` in `Assets/Trizzle/Scenes/QA/`.
8. Enter Play mode. Confirm zero errors.

**Expected**: Scene runs cleanly. GroundSlamAbility Inspector shows correct defaults.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-01: Telegraph VFX visible for full 0.8s
**Story AC**: AC3
**Steps**: Trigger Execute(). Observe VFX at boss feet. Time ~0.8s (acceptable 0.7-0.9s).
**Expected**: Ground indicator visible for ~0.8s, disappears at damage moment.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-02: Telegraph dodgeable at normal reaction speed
**Story AC**: AC3
**Preconditions**: Second person triggers Execute() without warning, or tester closes eyes until VFX appears.
**Steps**: Player inside 5-unit radius. Trigger without warning. Dodge on VFX cue only. Repeat 5 times.
**Expected**: 3+ of 5 escapes succeed without pre-knowledge.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-03: Damage inside radius matches formula
**Story AC**: AC4, AC6
**Preconditions**: Attack=20, Defense=0, no status modifiers.
**Steps**: Record HP. Trigger. Calculate `expected = 20 * 1.5 = 30`. Compare delta.
**Expected**: Damage delta within ±2 of 30.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-04: Player at exactly 5.0 units takes zero damage
**Story AC**: AC5
**Steps**: Position player at 5.0 units exact. Trigger. Check HP.
**Expected**: HP unchanged (OverlapSphere boundary exclusive).
**Pass/Fail**: _[fill in]_
**Notes**: If FAIL, test 5.1 to check if boundary off-by-one.

---

### TC-E3004-05: DamageCalculator pipeline applies Defense
**Story AC**: AC6
**Steps**:
1. Run A — Defense=10. Trigger. Record damage.
2. Run B — Defense=0. Reset, trigger. Record damage.
3. Compare.
**Expected**: Run A damage < Run B damage.
**Pass/Fail**: _[fill in]_
**Notes**: Identical values indicate DamageCalculator bypass.

---

### TC-E3004-06: VFX lifecycle — telegraph destroyed, impact self-terminates
**Story AC**: AC3, AC8
**Steps**: Trigger 4x in succession. Watch Hierarchy for VFX instances. Verify cleanup.
**Expected**: No VFX accumulation. Impact VFX self-terminates within particle duration.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-07: Null VFX references — no crash
**Story AC**: AC8
**Steps**: Clear both VFX SerializeFields. Enter Play mode. Trigger.
**Expected**: No NullReferenceException. Damage still applies.
**Pass/Fail**: _[fill in]_

---

### TC-E3004-08: No NavMeshAgent stutter during ability
**Story AC**: qa-plan checklist
**Steps**: Trigger while boss pathing. Watch for jitter/teleport during 0.8s. Verify agent resumes after IsDone.
**Expected**: Stable position during ability. Normal pathfinding resumes within 1-2s.
**Pass/Fail**: _[fill in]_
