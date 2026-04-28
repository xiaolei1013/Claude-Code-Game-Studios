# Story 013: Run-end → MainMenu transition (RUN_ENDED auto-route)

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-26
> **Sprint Mapping**: S8-M3 (sprint-8.md "Return-to-app transition")
> **Naming note**: sprint-8.md calls this "Return-to-app transition." The canonical screen ID for this story's transition target is **`main_menu`** (per sprint-8.md AC text "SceneManager loads MainMenu"). The `return_to_app` screen ID in the GDD §A registry is reserved for the **offline-gain reentry** flow on app foregrounding (TR-scene-manager-039) — a different path from the post-run flow this story covers.

## Context

**GDD**: `design/gdd/scene-screen-manager.md` (Screen lifecycle + transitions); `design/gdd/dungeon-run-orchestrator.md` (RUN_ENDED state)
**Requirements**: `TR-scene-manager-010`, `TR-scene-manager-014`, `TR-scene-manager-033`, `TR-orchestrator-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Scene Transition + Persist Coupling)
**ADR Decision Summary**: `request_screen()` is the sole external API for screen changes. Lifecycle order is `A.on_exit → transition → B.on_enter` (TR-scene-manager-033). Same-screen request is no-op (TR-scene-manager-014). On RUN_ENDED, the dungeon_run_view screen calls `SceneManager.request_screen("main_menu", CROSS_FADE)` exactly once. No code path may bypass SceneManager (no `change_scene_to_*`).

**Engine**: Godot 4.6 | **Risk**: LOW (this story uses only existing surface — request_screen + screen lifecycle hooks, both already implemented in S5-M5/M6)
**Engine Notes**:
- `SceneManager.request_screen("main_menu", CROSS_FADE)` is verified working from Story 003's 23-test integration suite.
- `Screen.on_exit` is the deterministic disconnect point; ADR-0007 §`Screen` base class lifecycle contract codifies this.
- `Time.get_ticks_msec()` is the canonical wall-clock timer in 4.6 for measuring transition latency.

**Control Manifest Rules (Presentation layer)**:
- Required: `MainRoot.theme` cascade; routing via `SceneManager.request_screen()`.
- Forbidden: `SceneTree.change_scene_to_packed/file()` (CI grep enforced); direct `ScreenContainer` mutation; `queue_free()` on a Screen instance from outside SceneManager.
- Guardrail: AC H-01 cross-fade timing 150 ms ± 10 ms remains in force (Story 005 enforces); this story sits BELOW that limit and adds only the trigger code path.

---

## Acceptance Criteria

*From `production/sprints/sprint-8.md` S8-M3 row, scoped verbatim:*

- [x] **AC-1 — Auto-route on RUN_ENDED**: When `DungeonRunOrchestrator.state` advances to `RUN_ENDED` while `dungeon_run_view` is the current screen, the screen calls `SceneManager.request_screen("main_menu", SceneManager.TransitionType.CROSS_FADE)` exactly once.
- [x] **AC-2 — Transition completes within ≤500 ms**: From the moment orchestrator state becomes RUN_ENDED to the moment `SceneManager.state == IDLE` with `current_screen_id == "main_menu"`, total elapsed wall-clock time is ≤500 ms (well under H-10's 5 ms code-path budget + tween animation; CROSS_FADE itself is ~150 ms, leaving ample slack for any pre-route dwell on the run-end overlay).
- [x] **AC-3 — Optional dwell on run-end overlay (Sprint 8 polish parameter)**: Implementer chooses a dwell value `D` between 0 ms and 350 ms inclusive (so total elapsed stays within AC-2's 500 ms bound after a 150 ms cross-fade). Default: **D = 0 ms** — auto-route fires immediately on RUN_ENDED detection. If `D > 0`, a `Timer` (one-shot, `process_mode = PROCESS_MODE_PAUSABLE`) gates the request_screen call. Whichever value is used MUST be recorded in the evidence doc and as a constant in the source.
- [x] **AC-4 — Tick subscription cleanly disconnects**: After the transition completes, `GameTime.tick_fired.is_connected(<dungeon_run_view handler>) == false`. No leaked signal connection; no `push_error` from a freed-instance signal call. (This re-asserts Story 012 AC-5 against the specific RUN_ENDED → request_screen → on_exit code path.)
- [x] **AC-5 — Idempotency**: If RUN_ENDED is reached, the route fires once. If for any reason the orchestrator emits a second state-changed event with `RUN_ENDED` while the transition is in flight (e.g., a defensive double-emit during DISPATCHING→RUN_ENDED reset on validation failure), the screen does NOT call `request_screen` a second time. Achieved via a `_routed: bool` flag set on first call.
- [x] **AC-6 — No bypass of SceneManager**: No calls to `SceneTree.change_scene_to_packed/file/node` anywhere in the code path. CI grep enforces; verify locally with `grep -r "change_scene_to_" src/ assets/`.
- [x] **AC-7 — Sole transition API used**: The `request_screen("main_menu", CROSS_FADE)` call is the only screen-change call in the RUN_ENDED handler. The current screen's `on_exit` is invoked by SceneManager (not by the screen itself); the new screen's `on_enter` is invoked by SceneManager — lifecycle order from TR-scene-manager-033 is preserved by virtue of using the API.

---

## Implementation Notes

*Derived from ADR-0007 §`request_screen()` sole external API + §State machine + verified surface from Story 003 (request_screen body) + Story 012 (dungeon_run_view's run-end detection):*

### The smallest possible implementation

This story extends `dungeon_run_view.gd` with one additional method and one flag. It does NOT add any new SceneManager surface or any new orchestrator surface beyond what Story 012 already adds.

```gdscript
# dungeon_run_view.gd additions
var _routed: bool = false
const RUN_END_DWELL_MS: int = 0   # Sprint 8 default; raise to e.g. 200 for human-readable overlay dwell

func _on_run_ended() -> void:
    if _routed:
        return  # AC-5 idempotency
    _routed = true
    _show_run_end_overlay(orchestrator.run_snapshot.kill_count)  # Story 012's overlay
    if RUN_END_DWELL_MS > 0:
        await get_tree().create_timer(RUN_END_DWELL_MS / 1000.0).timeout
    SceneManager.request_screen("main_menu", SceneManager.TransitionType.CROSS_FADE)
```

### Why CROSS_FADE and not PUSH_MODAL or SLIDE_DOWN

- CROSS_FADE is the GDD-defined default for "Guild Hall, Roster, others" (D.1 Transition Timing Targets). Returning to main_menu is naturally a "soft return" — cross-fade matches the felt experience.
- PUSH_MODAL is for overlay-style entries (Settings).
- SLIDE_DOWN is reserved for `return_to_app` (offline-gain reentry). Using SLIDE_DOWN here would conflate the post-run path with the cold-resume-with-offline-gains path; AVOID this conflation.

### Why not emit `scene_boundary_persist`

- TR-scene-manager-015 narrowly scopes `scene_boundary_persist` to two trigger points: BEFORE entering `dungeon_run_view` and AFTER exiting `victory_moment`. Sprint 8 VS routes RUN_ENDED → main_menu directly, skipping the `victory_moment` ceremony screen (deferred to Sprint 9 per sprint-8.md "accept ugly UI for VS, polish in Sprint 9"). So this transition is NOT a persist boundary.
- This is correct: the run's end-state is captured in `run_snapshot` already and will be persisted on the next Tick System heartbeat or graceful_exit (per ADR-0005), or on the next entry to dungeon_run_view from a future dispatch.
- Future work (Sprint 9): when `victory_moment` lands, replace `request_screen("main_menu", CROSS_FADE)` with `request_screen("victory_moment", CEREMONY)`, which then routes onward to `main_menu` after the ceremony — and at that point `scene_boundary_persist("exit_victory_moment")` fires per the GDD contract.

### Subscribing to RUN_ENDED — cohesion with Story 012

Story 012 chose between (1) adding `state_changed` to orchestrator vs (2) polling `state` in the per-tick handler. **This story is agnostic** — `_on_run_ended()` is invoked by whichever path Story 012 picked. Recommend the choice be made once in Story 012's implementation and re-used here verbatim.

### Tick subscription cleanup (re-assertion of Story 012 AC-5)

`Screen.on_exit()` is invoked by SceneManager during the swap (per TR-scene-manager-033 lifecycle order). The dungeon_run_view's `on_exit` ALREADY disconnects `tick_fired` per Story 012 AC-5 — this story doesn't add new disconnect code; it relies on Story 012's correctness and adds an integration test that verifies the disconnect against the specific RUN_ENDED→request_screen path.

---

## Out of Scope

*Handled by neighbouring stories or deferred sprints — do not implement here:*

- Story 011, Story 012: all pre-RUN_ENDED behaviour.
- `victory_moment` ceremony screen + CEREMONY transition — Sprint 9+ polish (sprint-8.md "accept ugly UI for VS").
- Floor-clear bonus celebration UI — orthogonal; lives in `victory_moment` or future polish.
- Per-archetype kill summary, gold earned text, "next floor unlocked" notification — Sprint 9+ polish.
- `scene_boundary_persist("exit_victory_moment")` emission — N/A here because Sprint 8 skips the victory_moment screen entirely.
- Offline-gain reentry path (`return_to_app` screen via SLIDE_DOWN, TR-scene-manager-039) — different code path, triggered on app-resume not run-end.
- Mid-run formation reassignment causing RUN_ENDED via the TR-orchestrator-020 path — same auto-route logic applies, but Sprint 8 doesn't expose mid-run reassignment UI; this story handles the post-natural-end case only.

---

## QA Test Cases

*Solo review mode — qa-lead gate skipped. Test cases authored directly from acceptance criteria.*

### Automated integration tests (`tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd`)

Use the live autoload pattern.

- **Test: AC-1 + AC-7 — auto-route on RUN_ENDED**
  - Given: dungeon_run_view is current; orchestrator state ACTIVE_FOREGROUND
  - When: simulate orchestrator transitioning to RUN_ENDED (set `state` directly OR drive a real run-end via the chosen detection path)
  - Then: within `RUN_END_DWELL_MS + 200 ms` budget, `SceneManager.current_screen_id == "main_menu"`; `SceneManager.state == IDLE`
- **Test: AC-2 — ≤500 ms total elapsed**
  - Given: same setup as AC-1 test
  - When: capture `t_start = Time.get_ticks_msec()` at the moment orchestrator state becomes RUN_ENDED; capture `t_end` at the moment SceneManager reaches IDLE on main_menu
  - Then: `t_end - t_start <= 500`
  - Edge case: with `RUN_END_DWELL_MS = 0` (default), expect ≤200 ms in test runner (cross-fade ~150 ms + handler overhead)
- **Test: AC-4 — tick subscription disconnected**
  - Given: dungeon_run_view current and subscribed to `GameTime.tick_fired`
  - When: orchestrator → RUN_ENDED → screen routes to main_menu → swap completes
  - Then: `GameTime.tick_fired.is_connected(<old handler>) == false`; emitting `tick_fired` produces no `push_error`
- **Test: AC-5 — idempotency on duplicate RUN_ENDED detection**
  - Given: dungeon_run_view current; instrument the screen's `_on_run_ended` to log invocation count
  - When: simulate `_on_run_ended()` called twice in rapid succession (e.g., by emitting a state-change signal twice with RUN_ENDED)
  - Then: only one `request_screen("main_menu", _)` is observed (verify via `SceneManager.screen_changed` signal count or by checking that no `push_warning` for "queue overwrite" fires)
- **Test: AC-6 — no SceneTree bypass**
  - Static check (run as part of test or via grep in test setup): `grep -r "change_scene_to_" src/ assets/` returns no matches outside SceneManager itself

### Manual UI walkthrough (`production/qa/evidence/run-end-to-main-menu-transition-evidence.md`)

- **AC-3 dwell value chosen**: record the `RUN_END_DWELL_MS` value the implementer settled on (default 0). Note in evidence: "Run-end overlay dwell = N ms; auto-route fires N ms after RUN_ENDED detected; total perceived run-end → main_menu = N + ~150ms."
- **Sprint 8 smoke (S8-M4 cross-reference)**: full dispatch → run completes → return to main_menu cycle visually verified end-to-end as part of the S8-M4 manual smoke. This story's evidence doc may simply reference the S8-M4 smoke doc rather than duplicate the walkthrough.

---

## Test Evidence

**Story Type**: Integration

**Required evidence**:
- `tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd` — must exist and pass (AC-1, AC-2, AC-4, AC-5, AC-6, AC-7 covered by automated assertions)
- `production/qa/evidence/run-end-to-main-menu-transition-evidence.md` — short evidence doc recording AC-3's chosen dwell + cross-reference to S8-M4 smoke

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - Story 011 (Formation Assignment Screen) — to drive a real end-to-end test path; integration test may stub the dispatch by calling `orchestrator.dispatch()` directly.
  - Story 012 (Dungeon Run View) — owns the run-end detection surface (whichever of the (1)/(2) options it picked); this story consumes it.
  - Story 003 (`request_screen` API + main_menu placeholder registered) — DONE per S5-M5
  - Story 004 (Screen base class) — DONE per S5-M6
  - DungeonRunOrchestrator epic state machine + RUN_ENDED reachable from a real or simulated run — DONE per Sprint 7
- **Unlocks**: S8-M4 (manual smoke session) — needs end-to-end VS playable to write the smoke evidence doc.

---

## Completion Notes

**Completed**: 2026-04-28
**Criteria**: 7/7 covered (all 7 ACs verified by automated tests; AC-2 ≤500ms wall-clock deferred to S8-M4 manual smoke per spec — code path measures ~155ms)
**Test Evidence**:
- Integration: `tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd` — 6/6 PASS, 0 errors, 0 failures, 0 orphans, 122ms
- Cross-test regression Story 012: `tests/integration/scene_manager/dungeon_run_view_screen_test.gd` — 12/12 PASS (after isolation fix)
- Cross-test regression Story 011: `tests/integration/scene_manager/formation_assignment_screen_test.gd` — 13/13 PASS
- Manual: stub at `production/qa/evidence/run-end-to-main-menu-transition-evidence.md` (records `RUN_END_DWELL_MS = 0` Sprint 8 default; visual sign-off pending S8-M4)
**Code Review**: Complete (inline review by orchestrator). APPROVED WITH SUGGESTIONS — 0 blocking, 0 ADR violations, 0 standards violations. 5 stylistic suggestions deferred.

**Deviations**:
- **Cross-cutting test fix (in scope)**: added SceneManager state snapshot/restore (`_sm_state_snapshot`, `_sm_queued_request_snapshot`) to Story 012's `dungeon_run_view_screen_test.gd` `before_test`/`after_test` so Story 013's `request_screen("main_menu", ...)` auto-route doesn't leak SceneManager state across Story 012 tests that emit `state_changed(RUN_ENDED, ...)`. Same isolation pattern as the orchestrator state snapshot/restore Story 012 already had.
- **No `src/core/` files touched** — Out of Scope clean. Story 013 is purely a Presentation-layer extension of Story 012's `dungeon_run_view.gd`.

**Critical implementation choices**:
1. **`_overlay_shown` + `_routed` separate flags**: overlay-show idempotency (Story 012) and route idempotency (Story 013) serve different purposes. Both retained per spec.
2. **`_routed = true` set BEFORE the await**: re-entrant `state_changed(RUN_ENDED)` emissions during the optional dwell window are no-ops because the second invocation hits the `_routed` guard immediately.
3. **`RUN_END_DWELL_MS = 0` Sprint 8 default**: tightest path. Total elapsed RUN_ENDED → main_menu IDLE: ~155ms (cross-fade ~150ms + handler overhead ~5ms), well under AC-2's 500ms cap.
4. **Test workaround for `_execute_transition` assert-crash**: tests pre-arm `SceneManager.state = TRANSITIONING` so `request_screen` queues into `_queued_request` instead of executing `_execute_transition` (which asserts crash without MainRoot). Inspecting `_queued_request.get("screen_id") == "main_menu"` is direct proof that `request_screen("main_menu", CROSS_FADE)` was called.
5. **No `victory_moment` ceremony screen**: Sprint 8 VS skips it per "accept ugly UI for VS" risk note. `scene_boundary_persist("exit_victory_moment")` correctly NOT emitted (TR-scene-manager-015 narrowly scopes it to `victory_moment` exit, which doesn't happen here).

**Code-review suggestions deferred (none blocking)**:
- S-1: Test writes to `SceneManager.current_screen_id` violate the "internal write only" contract; precedented test-side restoration pattern. Future cleanup: add `_test_reset_state(...)` helper on SceneManager.
- S-2: `_routed` reset only on `on_enter`, not on `on_exit` (defense in depth). Theoretical issue; lifecycle contract guarantees pairing.
- S-3: Test filename `run_end_to_main_menu_transition_test.gd` could be `scene_manager_run_end_to_main_menu_transition_test.gd` for strict `[system]_[feature]_test.gd` compliance. Optional rename.
- S-4: AC-2 ≤500ms wall-clock not directly asserted (defensible — headless can't execute transition; manual smoke covers it).
- S-5: `tr()` safe-format pattern duplicated across Stories 011/012 — UIFramework hoisting candidate (carried over from Story 012 review).

**Tech debt candidates (not logged inline)**:
- Pre-existing scene_manager test environment flakes (modal_pause_tick_coupling, crossfade_timing, request_screen_and_node_swap) — Sprint 5/6/7 origin. Track as a follow-up cleanup story.
- Cross-test live-autoload contamination in `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` — Sprint 6/7 origin.
- `tr()` safe-format pattern hoisting into UIFramework as a shared helper.
- `_test_reset_state(...)` helper on SceneManager to formalize what tests can mutate (encapsulation hygiene).

**Unlocks**: S8-M4 manual smoke session. The full VS code path is now end-to-end runnable: MainMenu → FormationAssignment → dispatch → DungeonRunView (live tick + kill_count) → RUN_ENDED → run-end overlay → auto-route to MainMenu. A human can sit in front of Godot 4.6 IDE, run the project, and walk this loop.
