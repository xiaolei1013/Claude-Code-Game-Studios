# Manual Test Cases: E3-010 Boss Kill Tracking Fix

**Sprint**: 3 | **Date**: 2026-04-14
**Session target**: 10 minutes
**Sign-off required**: qa-lead
**Evidence destination**: `production/session-logs/playtest-sprint-03-boss-kill-tracking.md`

---

### TC-E3010-00: Locate boss-killed UI (orientation)
**Steps**: Play run. Kill boss. Complete room. Locate where boss-killed state surfaces: (a) in-game run summary, (b) RunHistory inspector, (c) Console `LogRunCompleted` output, (d) `DraftRunController.BossKilled` in inspector.
**Expected**: At least one location shows a boolean value unambiguously.
**Pass/Fail**: _[fill in]_
**Notes**: If no observable location → file secondary bug: "BossKilled tracked but not surfaced to player UI".

---

### TC-E3010-01: Scenario A — Boss killed, run completed
**Story AC**: AC1, AC2, AC3
**Steps**: StartDraftRun. Enter boss room. Kill boss. Allow OnRunComplete. Check indicator.
**Expected**: BossKilled = true.
**Pass/Fail**: _[fill in]_

---

### TC-E3010-02: Scenario B — Player dies before boss (BUG REPRODUCTION)
**Story AC**: AC1, AC4
**Steps**: StartDraftRun. Enter boss room. Boss alive. Die WITHOUT killing boss. Check indicator.
**Expected**: BossKilled = false.
**Pass/Fail**: _[fill in]_
**Notes**: This is the ORIGINAL BUG. A `true` result here reproduces the defect. S2 escalation.

---

### TC-E3010-03: Scenario C — Room with no boss
**Story AC**: AC1, AC5
**Preconditions**: Room with NO BossController instance (verify in Hierarchy).
**Steps**: Clear room (non-boss enemies only). Allow OnRunComplete. Check indicator.
**Expected**: BossKilled = false. No NRE in console.
**Pass/Fail**: _[fill in]_

---

### TC-E3010-04: Regression — flag doesn't leak across runs
**Story AC**: AC5, AC7
**Steps**:
1. Confirm prior run had BossKilled = true.
2. StartDraftRun new run.
3. Immediately check BossKilled = false (reset verified).
4. Boss room, die without killing.
5. Check BossKilled = false for second run.
**Expected**: Both sub-observations = false. No leak from previous run.
**Pass/Fail**: _[fill in]_
**Notes**: FAIL here = UnsubscribeAllBosses not executing. S2 escalation.

---

### TC-E3010-05: Scene-placed boss detection
**Story AC**: AC2, AC3
**Preconditions**: BossController placed directly in scene (not SpawnManager runtime spawn).
**Steps**:
1. Confirm scene-placed boss in Hierarchy.
2. Enter Play mode. Don't call StartDraftRun yet.
3. Verify `_subscribedBosses.Count > 0` (or observable scan log in Console).
4. StartDraftRun. Kill boss. OnRunComplete. Check indicator.
**Expected**: Scene-placed boss detected via ScanForActiveBosses. BossKilled = true after kill.
**Pass/Fail**: _[fill in]_
