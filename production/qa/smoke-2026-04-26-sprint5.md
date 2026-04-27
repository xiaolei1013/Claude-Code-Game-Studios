# Smoke Check: Sprint 5

**Date**: 2026-04-26
**Sprint**: 5 (2026-06-22 → 2026-07-03 nominal; closed 2026-04-26 per single-session cadence)
**Verdict**: **PASS WITH NOTES**

## Suite Results

| Suite | Result | Notes |
|---|---|---|
| `tests/unit/scene_manager/` | **71/71 PASS** | 13 skeleton + 16 base class + 25 tween + 18 modal counter; 0 orphans |
| `tests/integration/scene_manager/` | **60/60 PASS** | 18 mainroot + 24 request_screen + 13 crossfade + 5 modal pause; 0 orphans |
| `tests/unit/save_load/` | **88/88 PASS** | Sprint 4 regression clean; 15 orphans (pre-existing, save_load suite) |
| `tests/unit/data_registry/` | 33 cases, 3 pre-existing failures | Economy._ready EconomyConfig boot-error in headless runner; pre-S5 |
| Full project (via `tests/gdunit4_runner.gd` wrapper) | **468/471 PASS** | 3 known data_registry test-env failures unchanged |
| CI grep `tools/ci/check_screen_hooks.sh` | **PASS** (7 screens) | All Screen subclasses declare 4 lifecycle hooks |
| CI grep negative-path | PASS (verified locally during S5-M6) | Lint catches missing hooks via fixture |

## Critical Path Coverage (per `tests/smoke/critical-paths.md`)

| Step | Status |
|---|---|
| 1. Project loads in editor without errors | ✅ |
| 2. Autoload chain initializes (rank 0..8) | ✅ — 8 autoloads + SceneManager rank 8 |
| 3. `godot --headless --script tests/gdunit4_runner.gd` exits via JUnit XML gate | ✅ — TD-005 fixed; wrapper functional |
| 4. SceneManager boots with MainRoot.tscn as main scene | ✅ — `project.godot` `run/main_scene` validated by D-01 test |
| 5. 7 placeholder screens load + extend Screen base class | ✅ — CI grep + Group D unit tests |
| 6. Modal overlay system pause coupling (get_tree().paused) | ✅ — 5/5 integration tests |

## Notes (carry into sign-off)

1. **3 pre-existing data_registry test-env failures**: `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd` has 3 tests that assume DataRegistry reaches READY in the headless runner. The runner has Economy._ready failing to resolve EconomyConfig (visible boot error), keeping DataRegistry in ERROR state; tests fail by this root cause. NOT introduced by Sprint 5; documented in Sprint 4 sign-off conditions; deferred test-env infrastructure work.

2. **Sprint 4 SaveLoadSystem orphan count**: 15 orphans persist in the save_load suite (pre-existing). Investigation deferred.

3. **Manifest version cascade**: control-manifest.md bumped 2026-04-24 → 2026-04-26 during S5-M4 (ADR-0003 Amendment #4 / OQ-8 closure). Sprint 5 stories embed 2026-04-26.

4. **Project test count growth**: scene_manager + save_load grew from 88 (Sprint 4 close) to **219 across the touched suites** (+131 tests added Sprint 5).

## Conclusion

Sprint 5 implementation is functionally clean. Pre-existing test-env failures unchanged from Sprint 4 baseline. Ready for `/team-qa sprint` formal sign-off + `/gate-check` Pre-Production → Production gate evaluation.
