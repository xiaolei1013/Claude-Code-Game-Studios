# Dungeon Run View (Spectator) — GDD #24

> **Status: First-pass DRAFT 2026-05-06** by autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. **Reverse-documentation:** the screen has been shipped + iteratively-evolved across Sprints 5–13 (415 lines of source, comprehensive test coverage at `tests/integration/scene_manager/dungeon_run_view_screen_test.gd`); this GDD formalizes the contract that's already in source. Run `/design-review` to surface drift.

---

## A. Overview

**Dungeon Run View** is the spectator screen the player watches while a dispatched run resolves. It is **read-only** — the player observes; they do not interact with the run itself. The screen subscribes to high-frequency tick events (`TickSystem.tick_fired` at 20 Hz) for a live tick + kill count display, plus low-frequency state events (`DungeonRunOrchestrator.state_changed`, `HeroRoster.hero_leveled`) for the run-end overlay + the floating level-up toast.

The screen is the **canonical hot-path performance constraint** — its `_on_tick_fired` handler runs 20 times per second during ACTIVE_FOREGROUND state. Per `.claude/rules/engine-code.md` zero-allocations-in-hot-paths invariant, the handler does the absolute minimum: two `label.text = str(int)` assignments. No allocations, no format strings (`%d` / `String.format`), no `tr()` calls inside the hot path.

The screen lifecycle:
1. SceneManager FADE_TO_BLACK transitions IN from formation_assignment after dispatch
2. `on_enter`: subscribe tick_fired + state_changed + hero_leveled; reset overlay + idempotency guards; render initial snapshot
3. Live updates from tick_fired (20 Hz hot path) + hero_leveled (occasional toast)
4. State change to RUN_ENDED triggers the run-end overlay + 1500ms dwell + CROSS_FADE to main_menu
5. `on_exit`: disconnect signals; node will be queue_freed

---

## B. Player Fantasy

> *"I dispatched my heroes. Now I watch them work — kills tick up, time advances, the run resolves cleanly. When it ends, I see the result and the screen takes me home."*

The cozy register applies: **observation, not control**. Pillar 2 (run feels meaningful) demands the player perceive the run for ≥2 seconds wall-clock per S9-M2 closure. The 1500ms RUN_END_DWELL_MS is the floor; combat resolves in 5–15 seconds typical, so the player sees the kill counter tick up + the floor clear + the run end overlay before the auto-route fires.

Critical: **the screen never takes input**. There is no Cancel button, no Pause button, no swap-formation-mid-run button. The player can swap formation via formation_assignment (per ADR-0001 mid-run reassignment), but they reach formation_assignment via the SceneManager modal pattern (currently NOT wired in MVP — formation swap mid-run is a Sprint 14+ UX surface). For MVP, dispatch is a commitment.

The level-up toast (Sprint 10 S10-M4) is the **felt-progression moment** during a run — a hero crosses an XP threshold mid-combat, the toast slides up center-screen, holds for 2.4 seconds, fades over 600ms, dismisses. Pairs with the audio chime per S12-M6 AC-AS-05. Multiple level-ups in cascade stack vertically per Hero Leveling GDD #15 §C.4.

---

## C. Detailed Rules

### C.1 Lifecycle hooks

`on_enter`:
1. Reset both idempotency guards (`_overlay_shown = false`, `_routed = false`); hide `_run_end_overlay`
2. Subscribe `TickSystem.tick_fired` → `_on_tick_fired` (idempotent via `is_connected` guard)
3. Subscribe `DungeonRunOrchestrator.state_changed` → `_on_state_changed`
4. Subscribe `HeroRoster.hero_leveled` → `_on_hero_leveled` (S10-M4)
5. `_refresh_display()` — snap labels to current snapshot (covers FADE_TO_BLACK race where ticks advanced before this on_enter)
6. `UIFrameworkScript.suppress_keyboard_focus(self)` — single-focus-mode strategy

The on_enter early-detection block for already-RUN_ENDED state (Sprint 8 S8-M4 + Sprint 9 S9-M2 hotfix) was REMOVED in Sprint 13 S13-S1 (commit `d096236`). Story 013's orchestrator-level buffered-replay handles the during-transition race; the slow-path `_on_state_changed` handler is now the canonical RUN_ENDED route trigger for both fast-path and slow-path scenarios.

`on_exit`:
1. Disconnect ALL three subscribed signals (idempotent via `is_connected`)
2. After return, SceneManager queue_frees the node

`on_pause` / `on_resume`: empty bodies (no per-screen pause animation; modal overlays are unlikely on this screen in MVP)

### C.2 Hot-path tick handler

`_on_tick_fired(_tick_number: int) -> void`:
- Reads `DungeonRunOrchestrator.run_snapshot` (RefCounted, identity-stable)
- If snapshot is null (defensive — should never happen in ACTIVE_FOREGROUND state), early return
- Two label writes:
  - `_tick_label.text = str(orch_snapshot.current_tick)`
  - `_kill_count_label.text = str(orch_snapshot.kill_count)`

Performance contract per Story 012 (per-tick performance budget):
- O(1): two `label.text = str(int)` calls + one null-check
- Zero allocations
- Zero format strings (`%d` / `String.format`) — `str(int)` is cheaper
- Zero `tr()` calls (locale lookup is allocator-heavy)

Storyhandler executes at 20 Hz (TickSystem default). 20 calls per second × 2 label writes = 40 label writes per second. Well within frame budget.

### C.3 Run-end overlay rendering

`_show_run_end_overlay(final_kill_count: int)`:
- Idempotent via `_overlay_shown` guard (set true on first call; subsequent calls are no-op)
- Uses `UIFrameworkScript.format_localized("run_complete_kill_count_format", [final_kill_count])` (locale-safe per S10-N1)
- Fallback EN: "Run Complete — N kills"
- Sets `_run_end_overlay.visible = true`

The overlay is a Control containing a Label centered. No animation in MVP; visual polish (slide-up, particle, etc.) is Sprint 14+ scope.

### C.4 RUN_ENDED → main_menu route

`_on_state_changed(new_state, _old_state)`:
- Filter: only RUN_ENDED matters; other states early-return
- Idempotency guard: `_routed` set true on first dispatch; subsequent dispatches are no-op
- Show overlay via `_show_run_end_overlay(final_kills)` where `final_kills = run_snapshot.kill_count if run_snapshot != null else 0`
- Await `RUN_END_DWELL_MS / 1000.0` seconds (1.5s default per S9-M2)
- `SceneManager.request_screen("main_menu", CROSS_FADE)` — sole screen-change call per AC-7 Story 013 (no `change_scene_to_*` anywhere)

The `_routed` guard prevents:
- Re-emit of state_changed during the dwell await (idempotency)
- Multi-fire in the buffered-replay scenario (Story 013 / S13-S1 — buffered emit fires once at transition_complete, slow-path handler runs once)

### C.5 Level-up toast (S10-M4)

`_on_hero_leveled(instance_id, _old_level, new_level)`:
- Defensive: skip if `HeroRoster._suppress_signals == true` (hydration suppression per Hero Leveling GDD #15 §C.7)
- Look up hero's `display_name` from HeroRoster (defaults to "Hero N" if not found)
- Format toast text via `UIFrameworkScript.format_localized("hero_level_up_toast_format", [display_name, new_level])`
- Spawn a transient Label as a child of self (vertical offset to stack multiple concurrent toasts — see §E.5)
- Tween: hold for `LEVEL_UP_TOAST_FADE_START_SEC` (2.4s default) at full alpha, then tween modulate.a from 1.0 to 0.0 over `LEVEL_UP_TOAST_LIFETIME_SEC - LEVEL_UP_TOAST_FADE_START_SEC` (~600ms)
- queue_free the toast Label on tween complete

Total toast lifetime: 3.0 seconds (LEVEL_UP_TOAST_LIFETIME_SEC).

Multiple toasts in cascade (Hero Leveling §C.4 multi-level cascade) stack vertically — each new toast offsets by toast_height. The 250ms gold-chime throttle (audio-system.md §F.2) is OUR audio cue throttle; toasts are visual and can fire faster than audio.

### C.6 Initial render via _refresh_display

`_refresh_display()` reads `DungeonRunOrchestrator.run_snapshot` and snaps both labels to current values. Called from on_enter (covers FADE_TO_BLACK race) AND from on_resume safety snap (per ADR-0007 Risks Note 1 — tween freeze during modal pause may have left the labels stale).

### C.7 Idempotency guards

Two guards prevent double-fire:
- `_overlay_shown: bool` — set true on first `_show_run_end_overlay` call
- `_routed: bool` — set true on first state_changed-triggered route attempt

Both reset to false in on_enter (so a fresh enter on a re-instantiated screen starts clean). Per the Sprint 13 S13-S1 refactor, the `_routed` guard is reached EITHER via the slow-path state_changed handler OR via the legacy fast-path on_enter early-detection (now removed). With Story 013's buffered-replay, only the slow-path is reachable; the guard remains as a defensive contract.

### C.8 Locale keys

en.csv keys used:
- `run_complete_kill_count_format` — "Run Complete — %d kills"
- `hero_level_up_toast_format` — "%s reached level %d!"

### C.9 Production-mode warning per ADR-0007 Risks Note 1

Tweens created inside this screen inherit `Tween.TWEEN_PAUSE_BOUND` from ScreenContainer (PROCESS_MODE_PAUSABLE). Modal overlays (e.g., Settings overlay per #30) freeze in-flight tweens. The level-up toast tween freezes mid-fade if a modal opens; resumes when modal closes (per Tween.TWEEN_PAUSE_BOUND default).

If the dwell tween (await timer.timeout) is mid-flight when a modal opens, the dwell pauses; this is a CONTRACT (the route shouldn't fire during modal). On modal close, the dwell resumes; route fires when complete. No special handling needed.

---

## D. Formulas

### D.1 RUN_END_DWELL_MS = 1500
Per Sprint 9 S9-M2 closure: bumped from 0 to 1500ms after S8-M5 playtest evidence showed sub-2-second runs scored 1/5 on Pillar 2. The 1500ms dwell + 500ms transition slack = 2000ms minimum perceived run duration.

### D.2 LEVEL_UP_TOAST_LIFETIME_SEC = 3.0
Per S10-M4 closure. 3 seconds = enough to read "Theron reached level 4!" + see the visual + register the audio cue.

### D.3 LEVEL_UP_TOAST_FADE_START_SEC = 2.4
2.4 seconds visible at full alpha + 0.6 seconds fading = 3.0 seconds total. Asymmetric to give the player ~80% read-time before the visual starts dimming.

### D.4 No other formulas
The screen is pure rendering; gameplay math lives upstream (Combat Resolution #11 / Hero Leveling #15 / Economy #5).

---

## E. Edge Cases

### E.1 run_snapshot null in tick handler
Defensive: `if orch_snapshot == null: return`. Should never happen in ACTIVE_FOREGROUND state (Story 004 + Story 005 invariant: snapshot built on dispatch + held until RUN_ENDED), but guard prevents crash on a hypothetical orchestrator bug.

### E.2 hero_leveled fires during hydration
Per Hero Leveling §C.7 + S10-M4 + audio-system.md AC-AS-05: `HeroRoster._suppress_signals == true` during hydration. The toast handler MUST skip emit. Tested (or deferred to Hero Leveling GDD's Story 4 implementation).

### E.3 hero_leveled fires for a hero NOT in the current formation
Per Hero Leveling §C.6 formation-determinism: only formation heroes earn XP. So this case shouldn't happen. Defensive: `if hero_id not in formation: skip toast`. NOT in MVP — current implementation shows the toast regardless. Sprint 14+ amendment if playtest reveals confusion.

### E.4 RUN_END_DWELL_MS = 0 (config drift)
If a future tuning pass sets RUN_END_DWELL_MS to 0, the slow-path route fires immediately after overlay shows. The overlay is shown for ~0ms before the cross_fade starts. Pillar 2 violation; mitigated by AC-1 of Story 013: `EXPECTED_S9M2_DWELL_MS = 1500` const-comparison test in `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd:36`.

### E.5 Multiple level-up toasts in cascade
Hero Leveling §C.4 multi-level cascade emits N hero_leveled signals per N levels crossed. Each signal triggers `_on_hero_leveled`. The toasts stack vertically (each new toast offsets by toast_height). With 5 toasts in <250ms, the visual is busy but readable. Audio cue chime throttle (audio-system §F.2) caps audible chimes at 4/sec.

### E.6 Tick fires while overlay is shown
Hot-path handler runs on every tick_fired regardless of overlay visibility. It updates the LIVE labels (which the overlay obscures). Wasteful but cheap (2 label writes per tick = ~40 ops/sec). Could optimize by tracking overlay state + early-returning, but the optimization saves ~40 ops/sec which is negligible. Noted in OQ-24-1.

### E.7 SceneManager TRANSITIONING during state_changed emit
Per Story 013 / S13-S1: orchestrator buffers state_changed emit during TRANSITIONING + replays at transition_complete. The slow-path `_on_state_changed` handler runs at the replay moment, AFTER on_enter has wired the listener. No special handling needed in this screen.

### E.8 on_exit during the dwell await
If on_exit fires while the dwell timer is awaiting (e.g., another route requested), the timer's await keeps running but the screen is queue_freed. The await resolves on a freed object; calling `SceneManager.request_screen` from a freed Node may push_error. Defensive: the dwell timer should be created from the screen's tree, not as a free-floating timer. Current implementation uses `get_tree().create_timer` which is freed when the tree is freed; on screen queue_free, the timer's signal connection is severed. No crash, but the route doesn't fire from this path. Not a production scenario in MVP.

### E.9 Idempotent on_enter guards reset
Re-enter via SceneManager (e.g., test fixture re-mounts) triggers on_enter again. The reset of `_overlay_shown` + `_routed` makes this clean. Tested per existing test suite.

### E.10 Hot-path performance regression
If `_on_tick_fired` adds an allocation (e.g., a new format string or a tr() call), the 20 Hz cost compounds. Visible as stutter on min-spec hardware. Story 012 CI gate enforces zero-alloc via per-tick performance test at `tests/perf/...`. Do not add work to the hot path without performance evidence.

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| `TickSystem` (#1) | 20 Hz tick source | `tick_fired` signal |
| `DungeonRunOrchestrator` (#13) | Run snapshot owner + state machine | `run_snapshot`, `state_changed` signal |
| `HeroRoster` (#9) | Hero state for toast (display_name lookup) + level-up signal | `_heroes[id].display_name`, `hero_leveled` signal, `_suppress_signals` flag |
| `SceneManager` (#4) | Route IN (FADE_TO_BLACK from formation_assignment) + OUT (CROSS_FADE to main_menu) | `request_screen("main_menu", CROSS_FADE)` |
| `UIFramework` (#18) | Locale-safe format + suppress_keyboard_focus | `format_localized`, `suppress_keyboard_focus` |
| `Screen` base class (#18 §C.2) | Lifecycle hooks | on_enter, on_exit, on_pause, on_resume |
| `assets/locale/en.csv` | Locale keys | `run_complete_kill_count_format`, `hero_level_up_toast_format` |

### Reverse dependencies

- `formation_assignment` screen — predecessor screen that triggers FADE_TO_BLACK into this screen via dispatch
- `main_menu` screen — successor screen via the RUN_ENDED → CROSS_FADE route
- `AudioRouter` (#28) — subscribes to `hero_leveled` independently (parallel to this screen's toast subscription) per audio-system.md §C.5

---

## G. Tuning Knobs

### RUN_END_DWELL_MS (int = 1500)
- Range: 0–2000. Below 0 invalid. 0 disables the dwell (Pillar 2 violation if real). Above 2000 feels sluggish.
- Per S9-M2 closure: 1500 is the playtest-verified minimum.

### LEVEL_UP_TOAST_LIFETIME_SEC (float = 3.0)
- Range: 1.5–5.0. Below 1.5 too brief to read. Above 5.0 lingering / overlapping.

### LEVEL_UP_TOAST_FADE_START_SEC (float = 2.4)
- Range: must be < LEVEL_UP_TOAST_LIFETIME_SEC. Default 80% of lifetime (2.4 / 3.0).

### Toast vertical offset for cascading
- Hardcoded in implementation. NOT a knob. Sprint 14+ may parameterize if the cascade UX needs polish.

---

## H. Acceptance Criteria

**AC-24-01 — Tick label updates on every tick_fired**
Subscribe + emit `tick_fired(tick=N)` while screen is on_entered + run_snapshot.current_tick = N. `_tick_label.text == str(N)` within one frame.

**AC-24-02 — Kill count label updates on every tick_fired**
Same pattern with `run_snapshot.kill_count`.

**AC-24-03 — Hot path performs zero allocations**
Per Story 012 perf test: 20 Hz tick handler does not allocate. CI gate at `tests/perf/...`.

**AC-24-04 — RUN_ENDED triggers overlay + dwell + route**
Subscribe + emit `state_changed(RUN_ENDED, ACTIVE_FOREGROUND)`. Overlay visible. After 1500ms dwell, `SceneManager.request_screen("main_menu", CROSS_FADE)` fires.

**AC-24-05 — Idempotent: re-entered RUN_ENDED state does NOT double-route**
After first RUN_ENDED, emit a second `state_changed(RUN_ENDED, ...)`. The second emit is filtered (RUN_ENDED matches state filter but `_routed` guard early-returns). Only ONE `request_screen` call fires.

**AC-24-06 — hero_leveled fires toast (S10-M4)**
`HeroRoster.hero_leveled.emit(1, 1, 2)` while screen on_entered + suppress_signals=false. A Label with formatted text spawns; visible for ~3 seconds; queue_freed.

**AC-24-07 — hero_leveled SUPPRESSED during hydration**
Same emit with `suppress_signals=true`. NO toast spawned.

**AC-24-08 — on_exit disconnects all 3 signals**
After on_exit: `is_connected` returns false for all of tick_fired / state_changed / hero_leveled.

**AC-24-09 — on_enter idempotency reset**
Re-mount the screen via SceneManager. on_enter resets `_overlay_shown = false`, `_routed = false`, `_run_end_overlay.visible = false`.

**AC-24-10 — Story 013 buffered-replay path works end-to-end**
Set orchestrator state = ACTIVE_FOREGROUND, SM.state = TRANSITIONING. Call `orchestrator._set_state(RUN_ENDED)` (buffered). Mount screen. Trigger `_replay_buffered_state_change`. Slow-path `_on_state_changed` runs; overlay shows; dwell elapses; route fires.

**AC-24-11 — Sole screen-change call (no change_scene_to_*)**
Repo grep: `grep "change_scene_to" assets/screens/dungeon_run_view/dungeon_run_view.gd` returns zero matches. Only `SceneManager.request_screen` is used.

**AC-24-12 — Locale keys present**
`assets/locale/en.csv` contains `run_complete_kill_count_format` + `hero_level_up_toast_format`.

**AC-24-13 — UIFramework.suppress_keyboard_focus called**
After on_enter: every Control under the screen has `focus_mode == FOCUS_NONE`.

**AC-24-14 — Level-up toast cascade renders multiple stacked**
`hero_leveled` emits 3 times in rapid succession. Three Labels spawn with vertical offsets; all visible concurrently for ~3 seconds.

---

## I. Open Questions & ADR Candidates

**OQ-24-1 — Hot-path optimization for overlay-shown state**
When the run-end overlay is shown, the hot-path tick handler is still updating live labels (which the overlay obscures). Could short-circuit if `_overlay_shown == true`. MVP says NO — saves ~40 ops/sec, negligible. Sprint 14+ if profiling shows the savings are needed.

**OQ-24-2 — Mid-run formation reassignment UX**
Per ADR-0001, mid-run formation swap is supported by orchestrator. This screen has NO UX surface for it. Sprint 14+ may add a swipe-up or button to trigger formation_assignment via show_modal. Out of MVP scope.

**OQ-24-3 — Cancel-run support**
Pillar 1 No-Fail-State means there's no abort mechanism (a run can't be cancelled — only watched + auto-routed). If V1.0 demands a cancel button (e.g., "I dispatched the wrong formation"), that's a new fantasy + new ADR + new screen surface.

**OQ-24-4 — Live formation strength display**
Could show the current formation's strength + the floor's expected strength (matchup advantage badge). Currently hidden — the player learns matchup via the run resolution, not pre-emptively. MVP cozy register; V1.0+ may add for tactically-curious players.

**OQ-24-5 — Toast cascade visual polish**
Multiple stacked toasts can occlude. UX pass needed for the cascade vertical layout. Currently functional, not polished.

**OQ-24-6 — Run-end overlay animation**
Current overlay is a sudden show + 1500ms hold + cross_fade. Could add a slide-up or fade-in (~300ms). Pillar 2 cozy register may benefit. UX pass needed.

---

## J. Implementation Sequencing (already done — reverse-documentation)

The screen has been implemented across:
- Sprint 5–8: initial Screen subclass + tick subscription + run-end overlay (Stories 008, 011, 012 of dungeon-run-orchestrator epic)
- Sprint 9 S9-M2: bump RUN_END_DWELL_MS 0 → 1500 + S9-M2 fast-path hotfix at `_deferred_run_end_route` (REMOVED in Sprint 13 S13-S1)
- Sprint 10 S10-M4: hero_leveled subscription + level-up toast
- Sprint 10 S10-N1: format_localized helper hoist
- Sprint 13 S13-S1 (commit `d096236`): Story 013 orchestrator-level buffered-replay; remove screen-level on_enter early-detection block + `_deferred_run_end_route` helper

Outstanding amendments (NOT MVP-gating):
1. **Sprint 14+ UX polish** (~0.25d) — Run-end overlay slide-in animation (OQ-24-6)
2. **Sprint 14+ UX polish** (~0.25d) — Toast cascade vertical-stack polish (OQ-24-5)
3. **Sprint 15+ optimization** (~0.1d) — Hot-path overlay-shown short-circuit (OQ-24-1)
4. **V1.0+ scope** — Mid-run reassignment UX (OQ-24-2), cancel-run (OQ-24-3), live formation strength (OQ-24-4)

Total post-GDD work: ~0.5d MVP polish + V1.0 scope items. None of this gates MVP shipping.

---

## Notes

- Authored 2026-05-06 by autonomous-execution session as REVERSE-DOCUMENTATION of the screen shipped + iteratively-evolved across Sprints 5–13 (415 lines of source, comprehensive test coverage at `tests/integration/scene_manager/dungeon_run_view_screen_test.gd` + `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd`).
- Run `/design-review` to surface drift between this GDD and live source. Expected verdict: CONCERNS rather than NEEDS REVISION.
- Closes the design-coverage gap that's existed since project inception. systems-index.md row 24 ("Not Started" since Sprint 1) flips to DRAFT.
- 6 first-pass GDDs drafted this session (Settings #30, Hero Leveling #15, Onboarding #29, UI Framework #18, Return-to-App #20, Dungeon Run View #24).
