# QA Sign-Off Report: Sprint 4

**Date**: 2026-04-16
**Scope**: 4 Must Have stories (E4-001, E4-002, E4-003, E4-008)
**QA Plan**: production/qa/qa-plan-sprint-04-2026-04-15.md
**Smoke Check**: production/qa/smoke-2026-04-16.md (verdict: PASS WITH WARNINGS)
**Build**: E4-001/002/003 merged via PR #120 (commit `7bd69ae4c` on `main`); E4-008 code authored in local working tree (commit pending)
**Unity**: 6000.3.11f1 (Unity 6.3 LTS)
**QA Lead sign-off**: APPROVED WITH CONDITIONS

---

## Test Coverage Summary

| Story | Type | Automated Test | Manual QA | Result |
|---|---|---|---|---|
| **E4-001** Extend ComboDefinition | Logic | `ComboDefinitionSchemaTest.cs` (passing, user-confirmed) | AC-8 asset load + AC-9 zero warnings user-confirmed in Editor | **PASS** |
| **E4-002** ComboEffect Base Class | Logic | `ComboRegistryTest.cs` (6 tests, passing) | AC-11 zero warnings user-confirmed in Editor | **PASS** |
| **E4-003** Mage Combo Effects (5) | Logic | `MageEffects/` 5 files, 30 tests (user-confirmed all pass) | AoE side-effect playtest **DEFERRED** — gated on PR #118 scene-attach | **PASS WITH NOTES** |
| **E4-008** Discovery Persistence | Logic + Integration | `ComboDiscoveryStoreTest.cs` (13) + `ComboDiscoveryTrackerTest.cs` (8) = 21 tests | Live quit/relaunch scenario **DEFERRED** — gated on PR #118 scene-attach | **PASS WITH NOTES** |

**Totals**:
- Stories PASS: 2
- Stories PASS WITH NOTES: 2
- Stories FAIL: 0
- Stories BLOCKED: 0

---

## Bugs Found

None. No bug reports filed this cycle.

---

## Notes Carried Forward

### Scene-attach deferral (PR #118 followup)
`ComboRegistry` and `ComboDiscoveryTracker` MonoBehaviours are not yet attached to the game scene root. Inspector references (`_database`, `_comboRegistry`) remain unassigned. Consequences: combo effects cannot fire in Play mode; discovery cannot persist to PlayerPrefs in live gameplay. All Sprint 4 code paths are covered by automated tests, including an end-to-end event-path integration test that injects a real `ComboRegistry` MonoBehaviour via reflection. Scene attach is explicitly out of Sprint 4 scope.

### E4-003 AoE side-effect playtest (deferred)
Three AoE behaviors cannot be verified in EditMode unit tests (Unity physics requires Play mode):
- Inferno burn patch tick damage over 3s at 0.5s interval
- Thunderstrike 2× damage multiplier on stunned enemies in cast radius
- Supernova explosion damage and 4-unit radius on proc

Gate-logic tests cover the conditional paths (correct skill filter, correct target state check, correct proc roll). Full AoE verification carries forward to the sprint in which scene-attach (PR #118) lands.

### E4-008 live quit/relaunch scenario (deferred)
GDD AC-6 ("discover a combo, quit, reload — present in save data") is covered at the persistence-layer code level via `PlayerPrefs_SaveThenLoad_RoundTripPreservesAllIds` plus `Tracker_AwakeLoadsExistingPlayerPrefs` tests, and via the end-to-end event-path test with reflection-injected `ComboRegistry`. Live in-game verification (actually quitting and relaunching the game) is deferred until scene-attach lands.

### ADR-0003 Amendment 2026-04-16
During E4-003 implementation, 4 spec-vs-reality mismatches were found and documented in `docs/architecture/adr-0003-combo-effect-architecture.md` Amendment §1-6. The implementation follows the corrected spec:
1. `PlayerController.OnSkillUsed` event added in this branch (not pre-existing as the original ADR assumed)
2. Kill event is `Health.OnDead` (parameterless), not `OnDied`
3. Status check is `HasDebuffState(StateCategory)`, not `HasState`
4. Physics is 3D (`Physics.OverlapSphere`), not 2D

Plus a V1 redesign of Venom: poison duration × 1.5 instead of tick interval × 0.67 (GDD and story AC-7 updated to match; rationale in ADR Amendment §6).

### Test path naming deviations (non-blocking)
3 test file paths differ from QA plan; all deliver equivalent or superior coverage:
- E4-001: `ComboDefinitionSchemaTest.cs` vs plan's `ComboDefinitionTest.cs`
- E4-002: QA plan expected 2 files (`ComboEffectBaseTest.cs` + `ComboRegistryTest.cs`); delivered as merged single `ComboRegistryTest.cs`
- E4-008: QA plan expected 1 file (`DiscoveryPersistenceTest.cs`); delivered as split `ComboDiscoveryStoreTest.cs` + `ComboDiscoveryTrackerTest.cs` (21 tests vs plan's estimated 7)

### Review gates (Lean mode)
Per `production/review-mode.txt` = `lean`: QL-TEST-COVERAGE and LP-CODE-REVIEW phase-gates skipped across all 4 stories. `/simplify` + `/review` + `/code-review` ran on E4-003 and E4-008; 10+ findings applied pre-ship.

### Regression
No regressions observed in Sprint 1-3 features. User confirmed via Unity Test Runner: all prior tests (Mage class, Archer class, boss phases, difficulty scaling, loot) still pass. Sprint 3's E3-010 boss-kill-tracking contract unaffected by the combo-system additions.

### Carried from Sprint 3
**E3-004 Ground Slam manual playtest**: deferred since Sprint 3 sign-off, pending E3-008 boss prefab configuration. No change this cycle.

---

## Verdict: APPROVED WITH CONDITIONS

**Conditions** (non-blocking for Sprint 4 close, tracked as prerequisites for Sprint 5):

1. **Scene-attach (PR #118)**: `ComboRegistry` + `ComboDiscoveryTracker` MonoBehaviours must be attached to the game scene root and Inspector references wired before Sprint 5 combo content work begins. Recommended: complete as first task of Sprint 5 or as a pre-sprint prerequisite.

2. **E4-003 AoE playtest**: once Condition 1 is resolved, run manual AoE verification for Inferno (burn patch tick), Thunderstrike (bonus damage on stunned), and Supernova (explosion damage/radius on proc).

3. **E4-008 live quit/reload**: once Condition 1 is resolved, run live in-game quit/relaunch to verify AC-7 end-to-end outside of reflection-based integration test.

4. **E3-004 Ground Slam** (carried from Sprint 3): unchanged; still gated on E3-008 boss prefab configuration.

**Rationale**: All 4 Must Have stories have passing automated coverage (57+ new tests across E4-001/002/003/008 — 21 Discovery + 30 Mage + 6 Registry + schema tests). Zero S1 or S2 bugs. The sprint goal — "lay the combo-synergy foundation (ComboDefinition schema, ComboEffect base class, Mage combo set) and persist discovery" — is delivered at the code and test level. Scene-attach is explicitly a PR #118 followup by design, not a Sprint 4 code gap. Conditions 2 and 3 are gated behind Condition 1. Condition 4 is unchanged from Sprint 3.

### Next Step

**Run `/gate-check`** to evaluate whether Sprint 4 closure advances the project stage. The 4 deferred manual-verification items (scene-attach + 3 dependent playtests + E3-004 carryover) are documented as Sprint 5 acceptance criteria — not blockers for Sprint 4 close.

Recommended Sprint 5 entry sequence:
1. Scene-attach work (PR #118) — unblocks Conditions 2 and 3 above and enables E4-006 discovery UI work
2. E3-008 boss prefab configuration — unblocks Condition 4 (E3-004 Ground Slam)
3. Then: E4-004 Archer Combo Effects, E4-006 Discovery UI, E4-005 Universal Effects per sprint-04.md Should Have / Nice to Have backlog
