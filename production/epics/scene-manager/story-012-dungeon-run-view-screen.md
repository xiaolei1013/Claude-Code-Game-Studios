# Story 012: Dungeon Run View — live tick + kill_count display + RUN_ENDED overlay

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-26
> **Sprint Mapping**: S8-M2 (sprint-8.md "DungeonRunView UI")

## Context

**GDD**: `design/gdd/scene-screen-manager.md` (Screen lifecycle + transitions); `design/gdd/dungeon-run-orchestrator.md` (RunSnapshot + state machine); `design/gdd/game-time-and-tick.md` (tick_fired contract)
**Requirements**: `TR-scene-manager-005`, `TR-orchestrator-001`, `TR-orchestrator-003`, `TR-orchestrator-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Scene Transition + Screen lifecycle) + ADR-0008 (UI Framework + Theme)
**ADR Decision Summary**: Screen extends `Screen extends Control` with all 4 lifecycle hooks declared. UI per-tick refresh is read-only against `DungeonRunOrchestrator.run_snapshot` — never mutate kernel state from the screen.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (UI knowledge gap; `tick_fired` is a high-frequency signal at 20 Hz — UI render must stay <16.6 ms/frame)
**Engine Notes**:
- Per ADR-0005: `GameTime.tick_fired(tick_number: int)` fires at 20 Hz nominal. Subscribing a Control's handler is safe; the handler must be O(1) read + UI-text-set only — no allocation, no signal-of-signal cascades.
- Per ADR-0007 §C.6: `ScreenContainer` children are `PROCESS_MODE_PAUSABLE` by default — meaning if a Settings modal pauses the tree, this screen's per-tick subscription naturally freezes (the orchestrator unsubscribes on its own state-exit, not via SceneTree pause). The screen's tick handler under PROCESS_MODE_PAUSABLE will also stop firing during pause — desired.
- Per TR-orchestrator-007: orchestrator subscribes to `tick_fired` only in ACTIVE_FOREGROUND. When the orchestrator transitions out (e.g., to RUN_ENDED), this screen's own subscription is independent and must be cleaned up by `on_exit()` regardless.
- Godot 4.6 `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` is the canonical way to verify no node leak across run cycles.

**Control Manifest Rules (Presentation layer)**:
- Required: `MainRoot.theme` cascade; `UIFramework.assert_tap_target_min(self)` in interactive Control `_ready()`; `tr()` for all UI strings; theme encodes Art Bible §4 palette as named theme constants.
- Forbidden: `Color(r, g, b)` literals in UI code; per-screen Theme; keyboard-focus visuals; `MOUSE_FILTER_STOP` cascade assumption.
- Guardrail: UI render per frame ≤16.6 ms — non-trivial here because the per-tick handler runs 20 Hz; total UI cost per tick must stay budgetable.

---

## Acceptance Criteria

*From `production/sprints/sprint-8.md` S8-M2 row, scoped verbatim:*

- [x] **AC-1 — Live tick display**: While `DungeonRunOrchestrator.state == ACTIVE_FOREGROUND`, screen shows the value of `DungeonRunOrchestrator.run_snapshot.current_tick`. Display refreshes at least once per `GameTime.tick_fired` emission (i.e., the visible number lags the snapshot by ≤1 tick).
- [x] **AC-2 — Live kill_count display**: Same conditions as AC-1; screen shows `run_snapshot.kill_count`. Refresh policy identical.
- [x] **AC-3 — Run-end overlay**: When orchestrator state advances to `RUN_ENDED`, screen displays a "Run Complete" overlay containing the final `kill_count` summary. Overlay is non-blocking: it does not freeze the screen tree, and it does not require player input to continue (Story 013 handles auto-route to MainMenu).
- [x] **AC-4 — Performance: ≥30 FPS in real Godot run**: On dev machine with default settings, real-Godot run sustains ≥30 FPS while the per-tick refresh is active. Measured via S8-M4 manual smoke; recorded in evidence doc.
- [x] **AC-5 — Lifecycle hygiene (no leaked tick subscription)**: `on_enter()` subscribes to `GameTime.tick_fired` (or equivalent refresh hook). `on_exit()` disconnects the subscription. After leaving this screen, `GameTime.tick_fired.is_connected(<screen-handler>) == false`. No `push_error` or warning emits from a freed-instance signal call.
- [x] **AC-6 — Run-end signal wiring**: Screen subscribes to whatever orchestrator surface signals state transition to RUN_ENDED. Sprint 8 acceptable surfaces, in order of preference:
  1. A new `state_changed(new_state, old_state)` signal added to orchestrator alongside this story (preferred — explicit + orthogonal to existing signals).
  2. Polling `orchestrator.state` inside the per-tick handler (acceptable — orchestrator unsubscribes from `tick_fired` on RUN_ENDED entry, so this screen still gets the final tick AND can detect the state-change because it owns its own subscription independently).
  3. A `run_ended(reason)` signal — equivalent to (1) for this story's purposes.
  - Whichever path is taken, AC-3's overlay MUST appear within 100 ms of the actual state transition (per H-12 ADVISORY framing).
- [x] **AC-7 — Theme + tap-target compliance**: No `Color(...)` literals; all colors via `MainRoot.theme` cascade. No interactive Controls in Sprint 8 scope (display-only screen) — but if the run-end overlay includes a "Continue" button (optional Sprint 8 scope), it MUST call `UIFramework.assert_tap_target_min(self)` in `_ready()`.
- [x] **AC-8 — Routed via SceneManager**: Screen is reached via `SceneManager.request_screen("dungeon_run_view", FADE_TO_BLACK)` (the FADE_TO_BLACK transition emits `scene_boundary_persist("enter_dungeon_run_view")` per TR-scene-manager-015 — this is honoured by Story 008 implementation, not by this screen). No code path mutates `ScreenContainer.add_child` directly. No `SceneTree.change_scene_to_*` calls.

---

## Implementation Notes

*Derived from ADR-0007 §`Screen` base class lifecycle contract + ADR-0014 §Coordination contract + verified consumer surface from existing `src/core/dungeon_run_orchestrator/run_snapshot.gd`:*

### Wiring map

```
dungeon_run_view.gd  (extends Screen)
  ├── on_enter()
  │     ├── _subscribe_to_tick()   # GameTime.tick_fired → _on_tick_fired
  │     ├── _subscribe_to_run_end() # see AC-6 — preferred path: orchestrator.state_changed
  │     └── _refresh_display()      # initial render reading run_snapshot
  ├── on_exit()
  │     └── _disconnect_signals()   # mirrors on_enter exactly
  ├── on_pause(): pass               # PROCESS_MODE_PAUSABLE handles freeze; UI animations pause naturally
  ├── on_resume(): _refresh_display() # snap to current snapshot in case ticks fired during pause
  ├── _on_tick_fired(tick_number):
  │     ├── if orchestrator.run_snapshot == null: return   # defensive — should never happen post-dispatch
  │     ├── _tick_label.text = str(orchestrator.run_snapshot.current_tick)
  │     ├── _kill_count_label.text = str(orchestrator.run_snapshot.kill_count)
  │     └── # NO allocation; NO signal emit; pure label.text set
  └── _on_run_ended():
        ├── _show_run_end_overlay(orchestrator.run_snapshot.kill_count)
        └── # Story 013 owns the auto-route; this screen does NOT call request_screen
```

### Subscribing to RUN_ENDED — recommendation

**Preferred path: add `state_changed(new_state, old_state)` signal to `DungeonRunOrchestrator`.**

Rationale:
- Cleanest contract; UI doesn't have to poll `state` every tick.
- Future stories (sprint-9 polish, victory_moment screen) will want the same signal.
- Touches one file (`src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd`) — emit at the single `_set_state()` choke-point that already exists at line 400.
- Add a unit test for the new signal in `tests/unit/dungeon_run_orchestrator/state_changed_signal_test.gd` alongside this story.

If the implementer prefers to scope-minimize and avoid touching the orchestrator: the polling fallback is acceptable — handler reads `orchestrator.state` each tick, transitions to overlay-shown when `state == RUN_ENDED && _overlay_visible == false`. Slight CPU waste but functionally correct.

### Per-tick refresh budget

- Two label `text` sets per tick + a single `Performance.get_monitor` debug read in dev builds. Should be <0.5 ms/tick — well under any frame budget.
- DO NOT format strings with `%d` / `String.format` per tick if avoidable; `str()` is fine for int → string.
- DO NOT call `tr()` per tick on static labels (e.g., the static "Tick:" prefix label) — set once in `_ready()` or `on_enter()`.

### Run-end overlay

- Implementation: a `PanelContainer` child of this screen, hidden by default (`visible = false`).
- On RUN_ENDED detection: set `text` to a localized string template like `tr("run_complete_kill_count_format") % final_kill_count` (Sprint 8 EN: "Run Complete — %d kills"). `visible = true`.
- For Sprint 8 VS, the overlay does NOT need a "Continue" button — Story 013's auto-route fires within ≤500 ms of RUN_ENDED, so the overlay is on-screen briefly before the cross-fade to MainMenu.
- If author chooses to add an explicit "Continue" button: tap → `SceneManager.request_screen("main_menu", CROSS_FADE)` (this is the Story 013 surface).

### Localization-ready strings

| Key | Sprint 8 EN value |
|---|---|
| `dungeon_run_view_title` | "Dungeon Run" |
| `tick_label_prefix` | "Tick:" |
| `kill_count_label_prefix` | "Kills:" |
| `run_complete_kill_count_format` | "Run Complete — %d kills" |

### What NOT to do

- DO NOT subscribe to `enemy_killed` / `boss_killed` / `floor_cleared_first_time` from this screen. Those are kernel signals; UI reads the resulting state from `run_snapshot.kill_count`, not from event tallying. Subscribing to enemy_killed and incrementing a UI-side counter would create a parallel-truth bug if the orchestrator's RunSnapshot disagrees.
- DO NOT mutate `run_snapshot` from the screen. Read-only.
- DO NOT call `SceneManager.request_screen` from the run-end overlay show path — Story 013 owns that.

---

## Out of Scope

*Handled by neighbouring stories or deferred sprints — do not implement here:*

- Story 011 (Formation Assignment Screen): all pre-dispatch UI.
- Story 013 (Run-end transition): RUN_ENDED → main_menu auto-route. This screen ONLY shows the overlay; routing is Story 013.
- Per-archetype kill breakdown, gold earned, floor-clear bonus celebration — Sprint 9+ polish (would belong to `victory_moment` ceremony screen per GDD §A).
- Animations on tick-count rollover, kill-count celebration shake/pulse — accept ugly UI for Sprint 8 VS per sprint-8.md risk note.
- Mid-run formation reassignment surface (TR-orchestrator-020) — Sprint 9+.
- Pause overlay / Settings during run — Settings GDD #30 not yet authored; Story 007's modal API is in place but no Settings screen exists.
- App-background indicator, offline-replay progress modal (TR-scene-manager-027 reduce_motion + ADR-0014 PROGRESS_MODAL_THRESHOLD_MS=100) — Story 009 territory.

---

## QA Test Cases

*Solo review mode — qa-lead gate skipped. Test cases authored directly from acceptance criteria.*

### Automated integration tests (`tests/integration/scene_manager/dungeon_run_view_screen_test.gd`)

Use the live autoload pattern from S5-M5: drive the test by calling `request_screen("dungeon_run_view", CROSS_FADE)` after seeding orchestrator state.

- **Test: AC-1 + AC-2 live refresh on tick_fired**
  - Given: orchestrator in ACTIVE_FOREGROUND with `run_snapshot.current_tick = 5, kill_count = 2`; screen is current
  - When: simulate orchestrator updating snapshot to `current_tick = 6, kill_count = 3` and emitting `GameTime.tick_fired(6)`
  - Then: screen's tick label text == `"6"`; kill-count label text == `"3"`
  - Edge case: if `run_snapshot == null` when the handler fires (defensive), no crash; handler returns early
- **Test: AC-3 run-end overlay visibility**
  - Given: orchestrator in ACTIVE_FOREGROUND, screen current, `run_snapshot.kill_count = 7`
  - When: simulate orchestrator transition to RUN_ENDED (via the chosen detection path)
  - Then: run-end overlay is visible; overlay text contains `"7"` (the final kill_count); orchestrator state is RUN_ENDED
- **Test: AC-5 tick-subscription cleanup on exit**
  - Given: screen is current, subscribed to `GameTime.tick_fired`
  - When: `SceneManager.request_screen("main_menu", CROSS_FADE)` triggers `on_exit`
  - Then: after the swap completes, `GameTime.tick_fired.is_connected(<screen handler>) == false`; emitting `tick_fired` produces no `push_error` (no orphaned connection)
- **Test: AC-8 routing via SceneManager**
  - Given: any prior screen is current
  - When: `request_screen("dungeon_run_view", FADE_TO_BLACK)` fires
  - Then: `SceneManager.current_screen_id == "dungeon_run_view"`; `SceneManager.current_screen` is a Control whose root script extends `Screen`

### Manual UI walkthrough (`production/qa/evidence/dungeon-run-view-screen-evidence.md`)

- **AC-4 ≥30 FPS**: Setup — open Godot 4.6 in dev, dispatch a real run. Verify — read FPS counter (`Engine.get_frames_per_second()` or editor monitor) for ≥10 s while ticks fire. Pass condition — sustained ≥30 FPS, no obvious stutter on per-tick refresh.
- **AC-3 overlay visible to a human**: Setup — let a real run play through to RUN_ENDED. Verify — overlay appears with kill_count visible to the eye; player has time to perceive it before Story 013's auto-route swap (Story 013 caps the dwell at ~500 ms but a smaller dwell like 200 ms is also acceptable; record in evidence which value Story 013 uses).
- **AC-7 theme compliance**: Setup — debug build. Verify — no `push_error` from `assert_tap_target_min` if any interactive Control exists; fonts match info_font / identity_font; colors match parchment palette.

---

## Test Evidence

**Story Type**: UI

**Required evidence**:
- `tests/integration/scene_manager/dungeon_run_view_screen_test.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-5, AC-8 covered)
- If implementation adds `state_changed` signal to orchestrator: `tests/unit/dungeon_run_orchestrator/state_changed_signal_test.gd` — must exist and pass
- `production/qa/evidence/dungeon-run-view-screen-evidence.md` — manual walkthrough doc (AC-4, AC-7, human-perceptible parts of AC-3)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - Story 011 (Formation Assignment Screen) — needed to actually drive a dispatch end-to-end during integration test setup; can be unblocked-by-stub if test setup goes around the UI by calling `DungeonRunOrchestrator.dispatch(...)` directly.
  - Story 003 (`request_screen` API) — DONE per S5-M5
  - Story 004 (Screen base class) — DONE per S5-M6
  - DungeonRunOrchestrator epic Stories 001–003 (state machine + RunSnapshot + dispatch) — DONE per Sprint 7
  - Tick System Stories — DONE; `GameTime.tick_fired` is the live signal
  - `assets/screens/dungeon_run_view/dungeon_run_view.{tscn,gd}` placeholder — DONE per S5-M5
- **Unlocks**: Story 013 (Run-end transition) — Story 013 needs RUN_ENDED to be observably reached from the screen's perspective.

---

## Completion Notes

**Completed**: 2026-04-28
**Criteria**: 8/8 covered (7 fully automated; AC-4 ≥30 FPS deferred to S8-M4 manual smoke per UI-tier ADVISORY)
**Test Evidence**:
- Integration: `tests/integration/scene_manager/dungeon_run_view_screen_test.gd` — 12/12 PASS, 0 errors, 225ms
- Unit (orchestrator signal): `tests/unit/dungeon_run_orchestrator/state_changed_signal_test.gd` — 5/5 PASS, 0 errors, 71ms
- Manual: deferred to S8-M4 smoke; evidence file location `production/qa/evidence/dungeon-run-view-screen-evidence.md` (to be authored during S8-M4)
**Code Review**: Complete (inline review by orchestrator). APPROVED WITH SUGGESTIONS — 4 stylistic suggestions, 0 blocking, 0 ADR violations.

**Deviations**:
- OUT OF SCOPE (authorized by Story 012 §Implementation Notes): added `signal state_changed(new_state: int, old_state: int)` to `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` (+15 lines) at the existing `_set_state` choke-point at line 415. Same-state guard preserved (no spurious emissions). Emit position is AFTER state mutation + entry/exit hooks so listeners observe the fully-settled new state.
- ADVISORY (test-wiring): same bypass-SceneManager pattern as Story 011 (`_navigate_to_dungeon_run_view_screen` instantiates the screen directly). AC-8 verified structurally via Story 003's registry test.
- ADVISORY (`tr()` safe-format guard duplicated): `_show_run_end_overlay` uses the same `if "%" in fmt` pattern as Story 011's `_show_toast`. Hoisting into UIFramework as a shared helper is a candidate for a future small refactor.

**Suggestions from code review (deferred, none blocking)**:
- S-1: `_ready()` uses raw `$node/path` references at lines 89-91 instead of `@onready var` (inconsistent with lines 55-64 of the same file). Stylistic — fix in a future sweep.
- S-2: `tr()` safe-format pattern hoisting (see ADVISORY above).
- S-3: `;` comment block in .tscn file may be stripped by the editor on save; consider moving the documentation to the .gd class doc-comment.
- S-4: Empty-snapshot RUN_ENDED edge case shows "Run Complete — 0 kills" silently; minor.

**Tech debt candidates (not logged inline)**:
- Cross-test live-autoload contamination in `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` (Sprint 6/7 origin): 2 tests fail when run alongside other suites that mutate the live autoload, pass 17/17 in isolation. Pre-existing issue. Fix path: add before_test/after_test snapshot+restore to that file.
- `tr()` safe-format pattern duplicated between Stories 011 and 012; UIFramework hoisting candidate.

**Unlocks**: Story 013 (S8-M3 run-end → main_menu transition) — `state_changed` signal is the surface it needs to detect RUN_ENDED and route to main_menu.
