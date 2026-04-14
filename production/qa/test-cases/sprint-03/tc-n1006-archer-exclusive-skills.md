# Manual Test Cases: N1-006 Archer Exclusive Skills

**Sprint**: 3 | **Date**: 2026-04-14
**Session duration target**: 30–40 minutes + 5-minute N1-007 extension
**Sign-off required**: qa-lead + game-designer
**Evidence destination**: `production/session-logs/playtest-sprint-03-archer-skills.md`

**STATUS**: BLOCKED — `Assets/Trizzle/Data/Skill/Archer/` does not exist. All 7 `.asset` ScriptableObject instances are missing. TC-N1006-01 fails on first execution. Run `CreateArcherSkillAssets.cs` editor helper to author the 7 assets before executing this test suite.

**Prerequisites before starting**: Unity Editor open at `/Users/xiaolei/work/Trizzle`, automated tests in `ArcherExclusiveSkillsTest.cs` confirmed passing, Archer class selectable from character select screen, 7 `.asset` files authored in `Assets/Trizzle/Data/Skill/Archer/`.

---

### TC-N1006-01: Asset existence verification — all 7 Archer skill assets
**Story AC**: AC1
**Preconditions**:
- Unity Editor open, Project window visible
- Navigate to `Assets/Trizzle/Data/Skill/Archer/` in the Project window

**Steps**:
1. In the Unity Project window, expand `Assets/Trizzle/Data/Skill/Archer/`.
2. Confirm the folder itself exists.
3. Verify each of the following `.asset` files is present: `PiercingArrowSkill.asset`, `MultishotSkill.asset`, `PoisonArrowSkill.asset`, `AfterimageSkill.asset`, `CounterRollSkill.asset`, `QuickdrawSkill.asset`, `EagleEyeSkill.asset`.
4. Single-click each asset to open it in the Inspector. Verify the type shown in the Inspector header matches the expected skill class (e.g., `PiercingArrowSkill`).
5. For each asset, confirm all `[SerializeField]` tuning fields are visible in the Inspector (not missing or hidden).

**Expected Result**: All 7 `.asset` files are present under `Assets/Trizzle/Data/Skill/Archer/`. Each Inspector shows the correct class type and all tuning knob fields are exposed.

**Actual Result**: _[Tester fills in]_
**Pass/Fail**: _[Tester fills in]_
**Notes**: CAUTION — filesystem check as of 2026-04-14 found `Assets/Trizzle/Data/Skill/Archer/` does NOT exist on disk. If the folder is absent, this TC fails immediately. All downstream gameplay TCs will be BLOCKED until assets are present. Log as BUG if absent.

---

### TC-N1006-02: PiercingArrow — arrow passes through and hits 3 enemies in a line
**Story AC**: AC2
**Preconditions**:
- Archer class selected, run started in any combat room
- PiercingArrow collected from draft pool (verify it appears and is selectable)
- At least 3 enemies positioned roughly in a line relative to the player

**Steps**:
1. Position the player so 3 enemies are in a roughly straight line ahead.
2. Fire one arrow directly through all 3 enemies using the standard attack input.
3. Observe the arrow projectile's behavior as it passes each enemy.
4. Observe each enemy's health bar or damage number popup.

**Expected Result**: Arrow does not stop or disappear on the first enemy hit. Continues through and strikes enemies 2 and 3. Damage numbers: enemy 1 = 100% base, enemy 2 = ~80%, enemy 3 = ~64% (within visible rounding). Arrow stops after 3rd target.

**Actual Result**: _[Tester fills in]_
**Pass/Fail**: _[Tester fills in]_
**Notes**: Relative ratio (1.00 : 0.80 : 0.64) is the pass condition. If damage numbers invisible, verify via Health component value.

---

### TC-N1006-03: PiercingArrow — 4th enemy in line is not hit
**Story AC**: AC2 (max pierce cap edge case)
**Preconditions**: 4 enemies in a line.
**Steps**: Fire one PiercingArrow through all 4. Observe whether 4th takes damage.
**Expected**: Enemies 1-3 take damage per falloff. Enemy 4 takes 0. Arrow terminates after 3rd hit.
**Pass/Fail**: _[fill in]_

---

### TC-N1006-04: Multishot — 3 arrows in fan spread at 0.5x damage each
**Story AC**: AC3
**Preconditions**: Multishot collected.
**Steps**: Aim at isolated enemy. Fire one attack. Count projectiles. Observe spread. Note damage per arrow vs base ArrowShot.
**Expected**: Exactly 3 arrows spawn in visible fan pattern. Each arrow ~50% of base damage.
**Pass/Fail**: _[fill in]_
**Notes**: If arrows overlap at spawn, fan-spread config bug.

---

### TC-N1006-05: PoisonArrow — Poison status applied, DoT over 4s
**Story AC**: AC4
**Steps**: Fire PoisonArrow at living enemy. Observe Poison status icon on hit. Watch health tick over 4s. At ~4.5s confirm DoT stopped.
**Expected**: Poison indicator visible immediately. Health decreases repeatedly over ~4s. DoT stops at 4s.
**Pass/Fail**: _[fill in]_
**Notes**: Stacking explicitly deferred to story 010. Do not test double-hit stacking.

---

### TC-N1006-06: Afterimage — decoy spawns, draws aggro, 2s despawn
**Story AC**: AC5
**Preconditions**: D5 Enemy AI upstream dependency status — VERIFY before running. If non-player targetables not supported, mark this TC BLOCKED.
**Steps**: Roll near approaching melee enemy. Observe decoy at roll origin. Watch enemy redirect to decoy. Wait 2s. Confirm decoy despawns and enemy re-targets player.
**Expected**: Decoy visible at roll start position. Enemy turns toward decoy. Decoy disappears ~2s. Enemy re-targets player.
**Pass/Fail**: _[fill in]_
**Notes**: If decoy spawns but enemy doesn't redirect, check D5 upstream before failing.

---

### TC-N1006-07: Afterimage — 1 HP, no projectile block
**Story AC**: AC5 (edge case)
**Steps**: Roll, let melee enemy strike decoy once. Observe destruction. Position decoy between player and ranged enemy. Observe whether projectile passes or blocks.
**Expected**: Decoy destroyed by first melee hit. Ranged projectile passes through decoy.
**Pass/Fail**: _[fill in]_

---

### TC-N1006-08: CounterRoll — 2x damage on i-frame block ONLY
**Story AC**: AC6 (highest-risk behavioral item per qa-lead)
**Steps**:
1. **Uncontested dodge**: Roll with no incoming attack. Fire arrow. Record damage.
2. **I-frame block**: Bait enemy attack, dodge through attack. Fire arrow immediately.
3. Compare damage.
4. Verify 2x buff indicator appears after i-frame block.
5. Wait 4s without shooting. Fire. Confirm damage returns to normal.
**Expected**: Step 1 normal damage, no indicator. Step 2 ~2x damage with indicator. Buff expires after 3s.
**Pass/Fail**: _[fill in]_
**Notes**: CRITICAL — if buff fires on every dodge regardless of i-frame block, this is a high-severity bug.

---

### TC-N1006-09: CounterRoll — window refreshes, doesn't stack
**Story AC**: AC6
**Steps**: Activate CounterRoll buff. Wait 2s. Activate again before expiry. Observe timer resets to 3s (not 6s). Next arrow = 2x not 4x.
**Expected**: Buff resets to full 3s. Damage is 2x not stacked.
**Pass/Fail**: _[fill in]_

---

### TC-N1006-10: Quickdraw — +50% attack speed for 2s post-roll
**Story AC**: AC7
**Steps**:
1. Baseline: time 5 consecutive shots.
2. Roll, then fire as many as possible in ~2s window.
3. Observe faster cadence.
4. Wait 3s. Fire 5 more. Confirm baseline restored.
**Expected**: Post-roll cadence visibly faster. Returns to baseline after 2s.
**Pass/Fail**: _[fill in]_

---

### TC-N1006-11: EagleEye — +30% crit at range only
**Story AC**: AC8
**Steps**:
1. Long-range: 20 arrows at max distance. Count crits.
2. Short-range: 20 arrows at melee range. Count crits.
3. Compare rates.
**Expected**: Long-range crit frequency ~30% higher than short-range (statistical approximation over 20 shots).
**Pass/Fail**: _[fill in]_
**Notes**: Benchmark — 15%+ difference over 20 shots is sufficient PASS given sample variance.

---

### TC-N1006-12: Archer kiting feel — distance-based playstyle sustainable
**Story AC**: GDD fantasy criterion
**Steps**: Fresh run, no skills collected. Kite melee enemies. Count consecutive arrow hits before melee contact. Repeat 3 times.
**Expected**: 5+ consecutive hits at range before melee closes in 2 of 3 attempts.
**Pass/Fail**: _[fill in]_
**Notes**: Benchmark — PASS: 5+ consecutive hits in 2/3 attempts. FAIL: melee closes within 2 hits consistently.

---

### TC-N1006-13: Quickdraw + CounterRoll stacked burst — rewarding not degenerate
**Story AC**: GDD Edge Case 7
**Steps**: Both skills active. I-frame block to trigger CounterRoll. Fire as many as possible in overlapping 2s window. Observe damage output. Confirm enemies remain after window ends.
**Expected**: 2x damage at +50% fire rate during window. At least 1 enemy survives burst — room not trivialized.
**Pass/Fail**: _[fill in]_
**Notes**: Benchmark — PASS: burst clears 1-2 enemies satisfyingly, player must re-engage. FAIL (degenerate): entire room dies during window across 3+ encounters.

---

### TC-N1006-14: compatibleUpgradeTypes correctness (Archer side)
**Story AC**: AC9
**Steps**: Open draft pool as Archer. Verify Arrow upgrades show. Switch to Mage run. Verify 7 archer skills DO NOT appear in Mage draft across 5 rooms.
**Expected**: All 7 archer skills in Archer pool. None in Mage pool.
**Pass/Fail**: _[fill in]_
**Notes**: Doubles as N1-007 re-verification.

---

### TC-N1006-15: N1-007 re-verification (Mage side)
**Story AC**: N1-007 Sprint 2 advisory
**Steps**: Archer run, 5+ upgrade rooms. Scan for any Mage-exclusive skills (Fireball, Blizzard, etc.).
**Expected**: No Mage-only skills appear in Archer draft.
**Pass/Fail**: _[fill in]_

---

**Blocker dependency tree**: TC-01 blocks TC-02 through TC-15. TC-06/07 also blocked by D5 upstream if non-player targetables not yet supported.
