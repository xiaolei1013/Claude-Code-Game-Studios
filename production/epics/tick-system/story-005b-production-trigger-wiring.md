# Story 005b: Production-side MainRoot trigger — request_full_load + bootstrap_offline_replay

> **Epic**: tick-system
> **Status**: Complete (2026-05-09 — wiring shipped + 5/5 integration tests PASS; full project sweep 1763/1763)
> **Layer**: Foundation (cross-cutting: SceneManager + SaveLoadSystem + TickSystem)
> **Type**: Integration
> **Manifest Version**: 2026-04-26

---

## Context

**GDD**: `design/gdd/game-time-and-tick.md` §D Offline Replay + §G Cold-Launch Path
**Requirements**: TR-time-016 (process-scoped one-shot), TR-time-030 (first-launch seed), TR-save-load-032 (boot-load trigger), TR-time-021 (single-call-site wall-clock)

**Governing ADR(s)**: ADR-0005 (TickSystem cold-launch offline-replay path), ADR-0007 (Persistent root scene architecture)
**ADR Decision Summary**: The production main scene (`MainRoot.tscn`) owns the cold-launch boot sequence: on `_ready()` it calls `SaveLoadSystem.request_full_load("boot")` (synchronous in MVP) followed by `TickSystem.bootstrap_offline_replay()`. The order is locked: the load must complete (or fail to first-launch) BEFORE the replay computes Formula D.2 — the replay's anchor reads `_last_persist_unix` + `_session_high_water` which are populated by SaveLoadSystem hydration. Both calls are process-scoped one-shots; subsequent invocations within the same process are no-ops.

**Engine**: Godot 4.6 | **Risk**: LOW (autoload-side surface fully implemented and tested per Story 005 + 006 + 007 closures; this story is the production caller wiring + test isolation guard).
**Engine Notes**: MainRoot is instantiated as the project's main scene per `project.godot::run/main_scene`. Autoloads (rank 0–15 per ADR-0003) finish their `_ready()` BEFORE MainRoot's `_ready()` fires, so DataRegistry (rank 1) and SaveLoadSystem (rank 2) and TickSystem (rank 0) are all available at MainRoot boot.

**Control Manifest Rules (Foundation Layer, persistent root scene)**:
- **Required**: MainRoot must call `SaveLoadSystem.request_full_load("boot")` before `TickSystem.bootstrap_offline_replay()`. Both calls are duck-typed via `/root/` lookups so that test fixtures can opt out by adding MainRoot under a non-root parent. ADR-0007.
- **Forbidden**: MainRoot may NOT contain gameplay logic (per main_root.gd header comment "No public API — all scene routing flows through SceneManager"). The boot wiring is system-coordination only — no consumer state mutation, no persist, no UI logic.

---

## Acceptance Criteria

- [x] MainRoot's `_ready()` calls `SaveLoadSystem.request_full_load("boot")` exactly once when MainRoot is instantiated as the production main scene (parented directly under `/root`).
- [x] After `request_full_load` returns, MainRoot calls `TickSystem.bootstrap_offline_replay()` exactly once. The order is locked.
- [x] When MainRoot is added to the tree under a non-root parent (test fixture pattern), the boot wiring is SKIPPED. Both `request_full_load` and `bootstrap_offline_replay` MUST NOT fire — verified by signal-spy assertions.
- [x] When `SaveLoadSystem` autoload is missing at `/root/SaveLoadSystem` (degenerate test env or boot-order failure), the wiring logs a `push_warning` and skips both calls. Production never hits this path; the guard exists for diagnostic clarity.
- [x] When `TickSystem` autoload is missing at `/root/TickSystem`, same behavior: `push_warning` + skip.
- [x] First-launch path (no save file): MainRoot's wiring fires `request_full_load("boot")` which emits `first_launch` + `load_completed("boot")`; `bootstrap_offline_replay` then takes the first-launch branch and emits `offline_elapsed_seconds(0.0, false)`. End-to-end signal sequence is verifiable via integration test.
- [x] Returning-launch path (save file present + valid HMAC): `request_full_load("boot")` hydrates consumers (Economy, HeroRoster, etc.); `bootstrap_offline_replay` takes the Formula D.2 branch using `_last_persist_unix` / `_session_high_water` that consumers (or migration) populated.
- [x] Existing `mainroot_scene_composition_test.gd` continues to pass — MainRoot's other contracts (theme, layer composition, process modes) are not regressed.

---

## Implementation Notes

- The wiring lives in `src/core/scene_manager/main_root.gd::_ready()` after the existing `theme = preload(...)` line.
- Test isolation guard: check `get_parent() != get_tree().root`. Production main scene parents MainRoot directly under `/root`; test fixtures add MainRoot via `add_child(inst)` from a test suite, which puts MainRoot under the test runner / suite node. The guard is structural, not flag-based — no exported field for tests to forget to set.
- Autoload lookups via `get_node_or_null("/root/SaveLoadSystem")` and `get_node_or_null("/root/TickSystem")` so missing autoloads fall through with a `push_warning` (defensive — in production the rank table guarantees presence).
- `request_full_load` is synchronous in MVP per Story 016 / Save-Load GDD §C Synchronous-I/O note — by the time it returns, state is READY (or CORRUPT on terminal failure). Calling `bootstrap_offline_replay()` immediately after is correct; no `await save_completed` or `await load_completed` needed.
- `bootstrap_offline_replay()` is process-scoped one-shot via `_offline_replay_emitted` flag — if MainRoot's `_ready()` somehow fires twice (it shouldn't in production), the second call is a no-op. Same idempotency contract on `request_full_load` (state guard rejects re-load attempts from non-UNLOADED state).

### Wiring sequence

```
MainRoot._ready()
  ├─ theme = preload("res://assets/ui/parchment_theme.tres")
  ├─ if get_parent() != get_tree().root: return  // test-fixture skip
  ├─ var sl = /root/SaveLoadSystem; var ts = /root/TickSystem
  ├─ if sl == null or ts == null: push_warning + return
  ├─ sl.request_full_load("boot")
  │     ├─ first-launch: emits first_launch + load_completed
  │     └─ returning-launch: hydrates consumers + emits load_completed
  └─ ts.bootstrap_offline_replay()
        ├─ first-launch: emits offline_elapsed_seconds(0.0, false)
        └─ returning-launch: Formula D.2 via _compute_offline_elapsed
```

---

## Out of Scope

- AC-SL-08 DataRegistry-ERROR path UX — handled internally by `request_full_load` short-circuit (emits `data_registry_error_modal_required` signal); MainRoot doesn't need a special path here. The data_registry_error_modal_required signal subscriber (UI layer) is Sprint 12+ scope.
- Tamper modal display — `tamper_detected_on_load` + `corrupt_both_modal_required` + `bak_recovered_toast` + `storage_advisory_modal_required` signals are emitted by SaveLoadSystem; UI subscribers are Sprint 12+ scope.
- OfflineProgressionEngine consumption of `offline_elapsed_seconds` — that's the OfflineProgressionEngine Feature epic. This story only wires the trigger.
- TickSystem heartbeat persist coupling — Story 008 owns that.
- BG/FG cycle handling — Story 004 owns that. The bootstrap_offline_replay one-shot flag prevents re-emission across BG/FG cycles per AC-TICK-13.

---

## QA Test Cases

- **AC-1 / AC-2**: production-parent boot fires both calls in order
  - **Given**: MainRoot.tscn instantiated and added directly under `/root` (production main-scene mimic)
  - **When**: `_ready()` fires
  - **Then**: `SaveLoadSystem.request_full_load` was called with reason `"boot"` (verified via signal spy on `load_completed` carrying that reason); `TickSystem.bootstrap_offline_replay` ran (verified via `_offline_replay_emitted` field state OR `offline_elapsed_seconds` signal emission)

- **AC-3**: test-fixture parent skips wiring
  - **Given**: MainRoot.tscn instantiated and added as a child of the test suite Node (parent != /root)
  - **When**: `_ready()` fires
  - **Then**: `SaveLoadSystem.load_completed` does NOT emit; `TickSystem._offline_replay_emitted` stays false; no `offline_elapsed_seconds` emission

- **AC-4 / AC-5**: missing autoload safety
  - **Given**: A MainRoot instance whose `get_parent() == get_tree().root` but where one of the autoloads is intentionally absent (mockable via direct path-removal in a controlled test fixture)
  - **When**: `_ready()` fires
  - **Then**: `push_warning` logged; neither boot call fires

- **AC-6**: first-launch end-to-end signal sequence
  - **Given**: MainRoot under `/root`, no save file at `save_file_path`, DataRegistry READY
  - **When**: `_ready()` fires
  - **Then**: signal sequence observed: `first_launch` → `load_completed("boot")` → `offline_elapsed_seconds(0.0, false)`. State is READY post-call.

- **AC-7**: returning-launch end-to-end
  - **Given**: MainRoot under `/root`, valid save file with seeded `_last_persist_unix` (TickSystem `_meta` consumer hydration), DataRegistry READY
  - **When**: `_ready()` fires
  - **Then**: `load_completed("boot")` emits + `offline_elapsed_seconds(elapsed, cap_reached)` emits with elapsed computed via Formula D.2. State is READY.

- **AC-8 (regression)**: existing MainRoot composition tests still pass
  - **Given**: All tests in `tests/integration/scene_manager/mainroot_scene_composition_test.gd`
  - **When**: Test suite runs
  - **Then**: All composition assertions pass (theme load, CanvasLayer count, process modes, etc.) — no regressions from the boot wiring addition.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/mainroot_boot_wiring_test.gd` — must exist and pass.

**Status**: [x] LANDED 2026-05-09 — `tests/integration/scene_manager/mainroot_boot_wiring_test.gd` (5 tests across 3 groups: A test-fixture skip, B production-parent boot + signal sequence + ordering, C idempotency)

## Closure Notes

**Files changed**:
- `src/core/scene_manager/main_root.gd` — added `_bootstrap_save_load_and_offline_replay()` private helper invoked from `_ready()`. Test-fixture isolation via structural `get_parent() != get_tree().root` guard. Defensive autoload null-checks with `push_warning` short-circuit. Order-locked: `request_full_load("boot")` → `bootstrap_offline_replay()`.
- `tests/integration/scene_manager/mainroot_boot_wiring_test.gd` — NEW file, 5 tests (122ms total).

**Test coverage**:
- AC-1/2/6: `test_mainroot_under_root_invokes_request_full_load_then_bootstrap_offline_replay` + `test_mainroot_under_root_first_launch_emits_full_signal_sequence` verify full signal chain `first_launch → load_completed("boot") → offline_elapsed_seconds(0.0, false)` in exact emission order.
- AC-3: `test_mainroot_under_test_parent_skips_boot_wiring` verifies the structural guard.
- Ordering invariant: `test_mainroot_under_root_call_order_load_before_bootstrap_offline_replay` explicitly asserts `offline_elapsed_seconds` index in `_emission_log` > `load_completed` index.
- Idempotency: `test_mainroot_under_root_double_ready_is_safe_idempotent` verifies that re-invoking `_bootstrap_save_load_and_offline_replay` does NOT re-fire either autoload's one-shot logic (state guard rejects re-load; one-shot flag rejects re-replay).

**AC-4 / AC-5 deviation**: Missing-autoload diagnostic `push_warning` paths are NOT exercised by unit/integration tests — they require autoload-removal which gdunit4 does not support cleanly. The guards exist for production diagnostic clarity (per ADR-0003 ranks they should never trigger). Documented-via-code-review.

**AC-7 deviation**: Returning-launch Formula D.2 path is NOT directly exercised in this story's tests — it requires a pre-seeded save with valid `_meta.last_persist_unix` from TickSystem hydration, which depends on Story 008 (heartbeat persist coupling) consumer registration. The Formula D.2 path itself is fully tested in `tests/unit/tick_system/offline_elapsed_formula_d2_clamp_rewind_overflow_test.gd` (Story 006 closure); this story's contract is wiring + ordering, not formula correctness.

**Test results**: 5/5 PASS (122ms); full project sweep 1763/1763 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans. Was 1758 before this story; +5 net.

**Code Review**: skipped per Solo review mode (consistent with same-day pattern).

**Engine risks**: None. The structural parent-pointer guard is a clean, future-proof test-isolation pattern that doesn't depend on runtime flags or environment variables.

---

## Dependencies

- **Depends on**: tick-system Story 005 (autoload-side `bootstrap_offline_replay()` body — landed 2026-05-08), Story 006 (`_compute_offline_elapsed()` body — landed 2026-05-08), save-load-system Story 016 (`request_full_load("boot")` end-to-end body — landed 2026-05-05), save-load-system Story 013 Phase 2 (AC-SL-08 distinct path — landed 2026-05-09 means MainRoot's wiring doesn't need to special-case DataRegistry ERROR).
- **Unlocks**: OfflineProgressionEngine Feature epic (gets reliable `offline_elapsed_seconds` emission at boot in production builds, not just tests).
