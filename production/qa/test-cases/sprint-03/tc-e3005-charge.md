# Manual Test Cases: E3-005 Charge

**Sprint**: 3 | **Date**: 2026-04-14
**Session target**: 20 minutes
**Assigned risk**: HIGHEST — assign most experienced tester
**Sign-off required**: qa-lead + game-designer
**Evidence destination**: `production/session-logs/playtest-sprint-03-charge.md`

**Pre-session note**: Use ad-hoc boss prefab from E3-004 with ChargeAbility swapped/added. CRITICAL: verify `_playerLayerMask` and `_wallLayerMask` are set — defaults are `LayerMask = 0` which matches nothing (silent pass on collision checks → false negatives on AC5/AC6).

---

### TC-E3005-00: Prefab setup + configuration
**Story AC**: AC1, AC2, AC3, AC10
**Steps**:
1. Verify ChargeAbility component attached.
2. Confirm all 8 SerializeFields present.
3. Confirm defaults: Telegraph=0.5, Distance=8, Speed=20, Multiplier=2.
4. Set Player LayerMask + Wall LayerMask + Telegraph VFX + Impact VFX.
5. Console: zero errors, zero warnings.
6. Play mode: no NRE or MissingComponentException.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-01: Telegraph line appears 0.5s then disappears
**Story AC**: AC3
**Steps**: Trigger Charge. Time VFX duration. Verify points toward player position at trigger moment.
**Expected**: VFX for ~0.5s (±1 frame at 60fps), oriented toward player, destroyed on dash start.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-02: Direction LOCKS at telegraph start **[BLOCKING]**
**Story AC**: AC4
**Steps**:
1. Trigger. Note telegraph direction (e.g., north).
2. During 0.5s telegraph, move player sharply east by 4+ units.
3. Observe dash direction.
**Expected**: Boss dashes original north direction, NOT redirected east.
**Pass/Fail**: _[fill in]_
**Notes**: If boss redirects → `_chargeDirection` set after yield instead of before. S2 escalation.

---

### TC-E3005-03: Direction lock re-verification from second position **[BLOCKING]**
**Story AC**: AC4
**Steps**: Repeat TC-02 from 2 different starting positions.
**Expected**: Direction locks in all iterations.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-04: Player contact applies damage via DamageCalculator **[BLOCKING]**
**Story AC**: AC6
**Preconditions**: Attack stat noted. Player HP visible.
**Steps**: Player in direct path ~4 units ahead. Trigger. Observe impact VFX at player, HP reduction.
**Expected**: HP reduced by ~Attack*2.0. Impact VFX at player position. Boss stops on contact.
**Pass/Fail**: _[fill in]_
**Notes**: Zero damage → first check `_playerLayerMask` set, then check StateMachine on boss.

---

### TC-E3005-05: Sideways dodge escapes cleanly **[BLOCKING]**
**Story AC**: AC7
**Steps**: Player in path. During 0.5s telegraph, move perpendicular 2+ units. Observe. Repeat opposite direction.
**Expected**: Boss dashes locked direction, no contact. HP unchanged.
**Pass/Fail**: _[fill in]_
**Notes**: "Magnetic" hit at 2+ units → verify ContactRadius=0.5, OverlapSphere at boss position.

---

### TC-E3005-06: Wall stop — no clipping **[BLOCKING]**
**Story AC**: AC5
**Steps**: Boss faces wall 5 units away. Player behind boss. Trigger. Observe stop point.
**Expected**: Boss stops on player-side surface. Impact VFX at wall hit point. No penetration.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-07: Thin wall (SphereCast tunneling check)
**Story AC**: AC5
**Steps**: 0.15-unit thin wall. Test at 60fps, then 30fps (Application.targetFrameRate=30).
**Expected**: Boss stops at both FPS levels.
**Pass/Fail**: _[fill in]_
**Notes**: Tunneling at 30fps → SphereCast radius may need increase. Data defect, not logic.

---

### TC-E3005-08: Origin-in-wall CheckSphere abort
**Story AC**: AC5
**Steps**: Position boss 0.1-0.3 units inside wall collider. Trigger.
**Expected**: Dash aborted. Impact VFX at boss position. No crash. NavMeshAgent restored.
**Pass/Fail**: _[fill in]_
**Notes**: If boss dashes from inside wall → potential S2 geometry-escape defect.

---

### TC-E3005-09: NavMesh restores after charge **[BLOCKING]**
**Story AC**: post-AC4/5/6 state
**Steps**:
1. Full uninterrupted charge (8 units, no wall/player hit). Confirm boss resumes pathfinding.
2. Wall-stopped charge. Confirm boss paths normally.
3. Charge to map edge (off-navmesh endpoint). Confirm NavMesh restore log, boss not stuck.
**Expected**: All 3 cases — agent re-enabled, pathfinding resumes within 1-2s.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-10: NavMesh restore after mid-dash Reset/BT abort
**Story AC**: AC8
**Steps**: Trigger, mid-dash call Reset(). Verify cleanup path.
**Expected**: AbortChargeSequence handles everything: stop coroutine, destroy telegraph, restore agent, clear flags.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-11: Pool re-use — second Execute after Reset
**Story AC**: AC4, AC6
**Steps**: Complete charge. Reset(). Move player 90° from first direction. Trigger again.
**Expected**: Second charge locks new direction. No stale direction from first.
**Pass/Fail**: _[fill in]_

---

### TC-E3005-12: VFX null-safety — both fields unassigned
**Story AC**: AC9
**Steps**: Clear both VFX fields. Play mode. Trigger with player in path.
**Expected**: No NRE. Damage still applies. Clean console.
**Pass/Fail**: _[fill in]_

---

**BLOCKING for gate-check**: TC-02, 03, 04, 05, 06, 09 must ALL pass. Any FAIL blocks sprint.
