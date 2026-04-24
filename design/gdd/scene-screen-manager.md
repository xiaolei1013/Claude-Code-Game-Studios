# Scene / Screen Manager GDD — Lantern Guild

> **GDD #8 in design order** (System #4 in systems index)
> **Status**: Designed (pending independent review)
> **Created**: 2026-04-19
> **Authors**: systems-designer + gameplay-programmer + qa-lead + main session
> **Depends on**: `design/gdd/data-loading.md` (GDD #2)
> **Referenced by**: Save/Load (#3), Time System (#1 pause interaction), Audio System (#28), 7 UI screens (#19–#25), Onboarding (#29), Settings overlay (#30)
> **Implements Pillar**: Indirect — Pillar 1 (fast transitions respect player time), Pillar 4 (Art Bible UI animation budget ≤150ms standard, 800ms ceremony cap)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Scene/Screen Manager is the Foundation-layer orchestrator that moves the player between the seven named UI screens of *Lantern Guild* (Guild Hall, Return-to-App, Recruit, Roster/Hero Detail, Matchup Assignment, Dungeon Run View, Victory/Unlock Moment) plus boot and settings overlay states. It owns a **persistent root scene architecture**: a single always-loaded `MainRoot.tscn` containing HUD, persistent systems, and four `CanvasLayer` nodes (HUD, Screen, Transition, Overlay), with the current screen swapped as a child node rather than via Godot's `change_scene_to_packed()`. This keeps persistent state resident across transitions and gives the manager frame-perfect control over the transition layer.

The system is deliberately thin. Its only external API is `request_screen(screen_id, transition_type)`. Every screen extends a `Screen` base class providing four lifecycle hooks — `on_enter / on_exit / on_pause / on_resume`. Transitions are 150–300ms for standard navigation and up to 800ms for reward ceremonies (Victory/Unlock Moment), all calibrated to the Art Bible's "stately warm snappiness" constraint. Input is blocked during transitions; modal overlays (Settings) pause the sim clock without replacing the current screen.

Eight downstream systems depend on this GDD's contracts. The manager itself is small — the value is in its consistency: one API, one transition policy, one place to change how the game moves between its moments.

---

## B. Player Fantasy

The Scene/Screen Manager has no direct player fantasy — players never touch this system. It serves the indirect fantasy: **"the game responds to me."**

The moment a player taps a button — "Recruit," "Assign Formation," "Collect" — they expect the game to move. That movement must feel *responsive* without feeling *rushed*. Too slow (>200ms) and the UI feels unresponsive. Too fast (<80ms) and the fade reads as a cut — no sense of place-to-place, just jarring state swap. The 150ms cross-fade default lives in that narrow band where the transition registers as a deliberate moment without ever becoming a wait.

The emotional target is *invisibility of navigation*. A player clicking through Guild Hall → Recruit → back to Guild Hall should never think about the transitions themselves. They should think about the roster choice they just made. The only time the manager is supposed to be *felt* is during reward ceremonies (Unlock Moment, Victory) where the 400–800ms flare earns its airtime — those are the beats where the game stops to say "you did something."

Art Bible's "setting down paper" metaphor shapes the ease curves: panels close with the settled weight of a physical object, not the elastic bounce of a toy. The Scene/Screen Manager is what makes that metaphor real at the engine level.

---

## C. Detailed Design

### C.1 Core Rules

1. **`SceneManager` is a Godot Autoload singleton.** It initializes `MainRoot.tscn` and owns the persistent scene tree: `PersistentHUDLayer` (CanvasLayer `layer=10`), `ScreenContainer` (swap target Node), `TransitionLayer` (CanvasLayer `layer=100`, always above screen), `OverlayLayer` (CanvasLayer `layer=110`, modals above transitions).

2. **`current_screen` is exactly one Control-based Node child of `ScreenContainer`.** Swapping calls `current_screen.on_exit()`, queues it free via `queue_free()`, defers new child addition via `call_deferred("_complete_swap", new_scene_instance)`, then calls `new_screen.on_enter()` after the frame boundary. At most one queued-free is in flight; deferred add-child prevents piling freed nodes.

3. **Every screen must extend the `Screen` base class**, declaring four lifecycle hooks: `on_enter()` (becomes current), `on_exit()` (before queue_free), `on_pause()` (modal overlay opens on top), `on_resume()` (overlay closes). Screens that skip a hook must still implement it (empty body is acceptable; silence is not).

4. **Transitions are not player-skippable.** All standard transitions are 150–300ms — shorter than a reaction window — so skip logic adds complexity with no player benefit. OS suspend mid-transition: `on_application_focus_in/out` signals are deferred until the in-progress transition completes.

5. **Modal overlays use `OverlayLayer` and do not replace `current_screen`.** When a modal opens (Settings, Roster/Hero Detail when invoked as overlay): manager instantiates overlay into `OverlayLayer`, calls `current_screen.on_pause()`, sets state to `PAUSED`. Closing calls `on_resume()` and returns to `IDLE`. Underlying screen is never freed.

6. **`TransitionLayer` blocks all input during an active transition.** A full-screen `Control` with `mouse_filter = MOUSE_FILTER_STOP` consumes pointer events for the transition duration, then reverts to `MOUSE_FILTER_IGNORE` on completion. No input reaches `ScreenContainer` during a transition.

7. **`SceneManager` does not own the Boot/Splash screen.** Engine presents the splash before the Autoload chain runs. `SceneManager._ready()` subscribes to `DataRegistry.registry_ready`; until fired, manager stays `UNINITIALIZED` and no-ops. The first internal `request_screen()` call routes to `guild_hall` (or `return_to_app` if offline gains present) when the signal fires.

8. **`request_screen(screen_id: String, transition: TransitionType)` is the sole external API.** No other system calls `queue_free` on a screen or modifies `ScreenContainer` children directly. `TransitionType` enum: `CROSS_FADE`, `SLIDE_UP`, `SLIDE_LEFT`, `SLIDE_DOWN`, `FADE_TO_BLACK`, `PUSH_MODAL`, `CEREMONY`.

### C.2 States and Transitions

Four-state machine:

| State | Meaning |
|---|---|
| `UNINITIALIZED` | Before `DataRegistry.registry_ready`. No screens loaded. |
| `IDLE` | One screen is current. No transition in progress. Ready for input. |
| `TRANSITIONING` | Transition animation playing. Input blocked. |
| `PAUSED` | Modal overlay active on top of `current_screen`. |

| From | Event | To | Boundary Actions |
|---|---|---|---|
| `UNINITIALIZED` | `registry_ready` fires | `TRANSITIONING` | Check save for offline gains; call `request_screen("return_to_app")` or `request_screen("guild_hall")` |
| `TRANSITIONING` | Animation complete | `IDLE` | Call `new_screen.on_enter()`; restore `TransitionLayer` input pass-through |
| `IDLE` | `request_screen()` called | `TRANSITIONING` | Call `current_screen.on_exit()`; queue_free current; play transition; deferred add_child new screen |
| `IDLE` | Modal overlay opened | `PAUSED` | Call `current_screen.on_pause()`; add overlay to `OverlayLayer`; if Settings: `get_tree().paused = true` |
| `PAUSED` | Modal overlay closed | `IDLE` | Remove overlay; if Settings was open: `get_tree().paused = false`; call `current_screen.on_resume()` |
| `TRANSITIONING` | `request_screen()` called | `TRANSITIONING` | **Queue request (max 1 in queue)**; play after current animation completes; additional calls overwrite queue with `push_warning` |
| `IDLE` | App backgrounded | `IDLE` | Call `SaveLoad.persist()`; Time System receives foreground/background event |
| `IDLE` | App foregrounded | `TRANSITIONING` | Load save; if offline gains > 0: `request_screen("return_to_app", SLIDE_DOWN)` |

**Queue-with-max-1 is the declared contract** for `request_screen` during `TRANSITIONING`. Newer calls overwrite the queued request (with `push_warning`), not rejected. This matches "session-based idle, no urgency" — queue feels natural; reject feels punitive.

**Major scene boundary save triggers** (contract with Save/Load GDD #3):
- Before `dungeon_run_view` becomes current: `SceneManager` emits `scene_boundary_persist` signal; Save/Load fires persist routine.
- On `victory_moment` exit (returning to Guild Hall): same signal.
- On app backgrounded: Time System's heartbeat fires; scene manager does not duplicate.

### C.3 Interactions with Other Systems

**Data Loading (#2)** — `SceneManager._ready()` connects to `DataRegistry.registry_ready`. Until this signal fires, the manager is inert. Only initialization dependency.

**Save/Load (#3)** — Emits `scene_boundary_persist` at two points: entering `dungeon_run_view` and exiting `victory_moment`. Save/Load subscribes and fires its persist routine. Save/Load's `save_completed` signal may drive brief HUD confirmation (HUD's concern, not manager's).

**Time System (#1)** — Sim clock runs at 20 Hz and does not pause during transitions unless `PAUSED` active. On `PAUSED` (Settings overlay): `get_tree().paused = true`; Time System's tick loop (node with `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard — see C.6) freezes. On overlay close: `get_tree().paused = false`, tick resumes.

**All 7 UI screens** — Each extends `Screen`. Each connects internal signals on `on_enter()` and disconnects on `on_exit()`. Screens must not assume persistence between visits — re-initialize from game data model on each entry.

### C.6 Systems Integration Notes

*Godot 4.6 feasibility validation by gameplay-programmer. Six integration flags.*

**VALIDATE — Node swap pattern**: `queue_free() + call_deferred("add_child", new_screen)` is sound in 4.6. `call_deferred` preferred over `await get_tree().process_frame` because the await pattern introduces a one-frame stall producing visible black frames at 60fps. Back-to-back transitions guarded by `_transitioning` boolean — if second request arrives while true, it queues (max 1) per Rule 6; never double-queue_free the same node.

**VALIDATE — Pause handling**: `get_tree().paused` with `PROCESS_MODE_PAUSABLE`/`PROCESS_MODE_ALWAYS` is correct in 4.6. **Recommended**: `ScreenContainer` + gameplay nodes → `PROCESS_MODE_PAUSABLE`; `PersistentHUDLayer`, `TransitionLayer`, `OverlayLayer` → `PROCESS_MODE_ALWAYS`. **WARN**: Time System's tick loop must use `PROCESS_MODE_ALWAYS` with explicit `if get_tree().paused: return` guard — otherwise overlay pause drops ticks entirely rather than suspending cleanly.

**VALIDATE — Transition rendering**: CanvasLayer with high `layer` value is idiomatic. Full-screen `ColorRect` tweened via `modulate.a` for cross-fade works in 4.6 with no gotchas.

**RECOMMEND — Tween vs AnimationPlayer**: Use `create_tween()` for all five MVP transitions (cross-fade, slide, fade-to-black, push modal) — single-property interpolations with fixed easing. Reserve `AnimationPlayer` exclusively for the Victory Ceremony (multi-node multi-property sequenced keyframes).

**RECOMMEND — Screen preload**: All 7 MVP screens preloaded as `PackedScene` constants at boot (<10MB total memory). **WARN**: Dungeon Run View with embedded AnimationPlayer/tilemaps may warrant `ResourceLoader.load_threaded_request()` on demand — verify against 4.6 reference docs before shipping (API was in flux through 4.5).

**RECOMMEND — Input blocking**: Full-screen `Control` child of `TransitionLayer` with `mouse_filter = MOUSE_FILTER_STOP` consumes all pointer events. Activate at transition start, deactivate when `on_enter` completes. Silent-drop policy (no queuing taps for replay) — session-based idle screens are state-owning, not action-streaming.

---

## D. Formulas / Timing Budgets

No mathematical formulas. Timing constants and animation curve selections.

### D.1 Transition Timing Targets

| Transition | Screen | Total | Breakdown | Curve |
|---|---|---|---|---|
| Cross-fade (default) | Guild Hall, Roster, others | 150ms | 75ms fade-out + 10ms overlap + 75ms fade-in | linear (alpha only) |
| Slide up | Recruit | 180ms | single-direction slide, no hold | `ease_out_quad` |
| Slide left | Matchup Assignment | 180ms | single-direction slide, no hold | `ease_out_quad` |
| Push modal (slide down) | Return-to-App, Settings | 150–200ms | slide from top of viewport | `ease_out_quad` |
| Fade to black | Dungeon Run View enter | 300ms | 150ms fade-out + 50ms hold + 100ms fade-in | linear |
| Ceremony (full) | Victory / Unlock Moment | 400–800ms | 400ms flare build + 200ms hold + 200ms fade | custom (Art Bible) |

The 10ms cross-fade overlap produces a dissolve rather than a cut-through-black. Implemented as two overlapping `Tween` sequences on `TransitionLayer`'s `ColorRect` modulate alpha.

Art Bible constraints:
- All slide transitions use `ease_out_quad` — "heavy objects settling into place"
- Ceremony flare must render primary reward number within first 100ms of ceremony window, even if decorative animation continues to 800ms
- Touch feedback (1.05× scale pulse, 80ms, return in 1 frame/16ms) owned by individual screen nodes, not `SceneManager` — documented here for completeness

### D.2 Platform Performance Budgets

| Platform | Target | Compliance |
|---|---|---|
| PC (Steam) | 60 fps | 150ms = 9 frames at 60fps — well clear of frame-jank risk |
| Mobile (post-launch) | 60 fps target, 30 fps floor | 150ms = 4.5 frames at 30 fps — still smooth; no platform-specific duration adjustment |

Art Bible animation budget (150ms standard / 800ms ceremony) is platform-parity. If device drops below 30 fps during transition, tween plays to completion at whatever real time — do NOT skip or abbreviate.

---

## E. Edge Cases

- **App backgrounded mid-transition**: `on_application_focus_out` fires. `SceneManager` sets `_pending_background_action = true` and lets the active transition run to completion (≤300ms). When `tween_completed` fires, background action processes: `SaveLoad.persist()` then background state entered. OS has already composited last rendered frame; partial animation is not a problem.

- **New transition requested while one is in progress**: Incoming `request_screen()` stored in single `_queued_request` slot. If queue already occupied, newer call overwrites with `push_warning`. Queue fires when `IDLE` reached. Only one request can queue — prevents transition storms.

- **Same-screen request**: `SceneManager` detects `screen_id == current_screen_id` and returns early; no transition, no queue_free, no animation; `push_warning` logged. Not an error state.

- **Modal overlay opens during transition**: Modal opens queued identically to screen requests — held in `_queued_modal` until `IDLE`, then opened. Modal cannot open during `TRANSITIONING`, preventing `OverlayLayer` from rendering over half-faded `TransitionLayer`.

- **Settings overlay during Dungeon Run View**: Primary pause scenario. `SceneManager` enters `PAUSED`, `get_tree().paused = true`. Dungeon Run Orchestrator's tick loop is `PROCESS_MODE_PAUSABLE` — sim clock freezes. Run state (hero assignments, floor progress, accumulated loot) preserved in memory. Settings close: `paused = false`, tick resumes from last state.

- **Memory leak from back-to-back transitions**: `queue_free()` defers deallocation to end of current frame. `call_deferred("_complete_swap", new_screen)` runs on next frame after free processes. At most one old screen instance in "pending free" state at any time. `TRANSITIONING` state blocks new requests during this window — no pileup possible.

- **First-launch sequence (no save)**: `DataRegistry.registry_ready` fires. Save/Load finds no save, reports `offline_gains = 0`, `is_first_launch = true`. `SceneManager` routes directly to `guild_hall`. Return-to-App never shown. Tutorial entry point owned by Guild Hall's `on_enter()`, not manager.

- **OS low-memory warning during transition**: Complete active transition first, then call `SaveLoad.persist()` as defensive write. Do not attempt to free texture caches or unload resources during transition — defer to after `IDLE`.

- **Player tap during transition**: `TransitionLayer`'s input-blocker `Control` with `MOUSE_FILTER_STOP` consumes all pointer events. Tap silently discarded — no click sound, no feedback. Correct behavior: transitions short enough that queuing would feel like delayed misfire.

- **Save failure on scene boundary persist**: If `SaveLoad.persist()` returns error before Dungeon Run View transition, manager emits `save_failed` signal and **stays on current screen** (transition aborted). Matches Save/Load GDD's anti-tamper posture (don't proceed on corrupted state).

---

## F. Dependencies

### Upstream Dependencies

| Upstream | Hard/Soft | Interface |
|---|---|---|
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | Subscribes to `DataRegistry.registry_ready` signal; stays `UNINITIALIZED` until fired |
| **Art Bible** (`design/art/art-bible.md`) | Hard — design contract | Section 7 UI animation timing budget: 150ms standard, 800ms ceremony max; "stately warm snappiness" curve philosophy |

### Downstream Dependents

| Consumer | Hard/Soft | Interface |
|---|---|---|
| **Save/Load (#3)** | Hard | Subscribes to `scene_boundary_persist` signal; emits `save_completed` and `save_failed` back |
| **Time System (#1)** | Hard | `SceneManager` sets `get_tree().paused` during `PAUSED` state; Time System's tick loop uses `PROCESS_MODE_ALWAYS` + `if get_tree().paused: return` guard |
| **Audio System (#28)** | Soft | Subscribes to screen-change signals for background music/ambience crossfades |
| **7 UI screens (#19–#25)** | Hard | Each extends `Screen` base class; receives lifecycle hooks |
| **Onboarding Flow (#29)** | Soft | Guild Hall's `on_enter()` checks `is_first_launch` flag and triggers onboarding |
| **Settings / Options (#30)** | Hard | Opens via modal overlay API; triggers `get_tree().paused = true` |

### Bidirectional Consistency

- `design/gdd/data-loading.md` ✅ lists Scene Manager as hard dependent (`registry_ready` signal contract)
- `design/gdd/save-load-system.md` ✅ references `pause_persist_enabled = true` on foreground→background boundary — Scene Manager coordinates this via `scene_boundary_persist` signal
- `design/gdd/game-time-and-tick.md` ✅ PAUSED state contract — Scene Manager drives `get_tree().paused` flag
- **New contract**: `scene_boundary_persist` signal name — to be added to Save/Load's subscribed signals list during that GDD's next revision

---

## G. Tuning Knobs

All tuning knobs in `scene_manager_config.tres` (Godot `Resource` loaded at Autoload init).

| Knob | Default | Type | Safe Range | Effect |
|---|---|---|---|---|
| `default_crossfade_ms` | 150 | int | 80–300 | Cross-fade base duration; below 80ms reads as cut |
| `slide_duration_ms` | 180 | int | 100–300 | All slide transitions; shared default, per-screen overridable |
| `fade_to_black_ms` | 300 | int | 200–500 | Dungeon Run enter total; breakdown ratios (50/16/33) fixed |
| `ceremony_min_ms` | 400 | int | 300–600 | Floor of Victory/Unlock ceremony window |
| `ceremony_max_ms` | 800 | int | 400–1200 | Ceiling of ceremony; must be ≥ `ceremony_min_ms` |
| `touch_feedback_scale` | 1.05 | float | 1.0–1.15 | Scale multiplier for 80ms touch pulse; 1.0 disables |
| `touch_feedback_ms` | 80 | int | 40–120 | Touch scale pulse duration; return to 1.0 always ≤1 frame (16ms) |
| `reduce_motion` | false | bool | true/false | **Accessibility**: clamps all transitions to 50ms, replaces ceremony with instant cut; overrides all duration knobs |
| `transition_input_policy` | `BLOCK` | enum | `BLOCK`, `QUEUE_ONE` | `BLOCK` silently drops taps (default). `QUEUE_ONE` stores last tap target and fires after transition. Not recommended. |

**Per-screen duration overrides**: Each `Screen` subclass may export `transition_override_ms: int`. Non-zero value replaces matching default for that screen's enter transition only. Avoids modifying `scene_manager_config.tres` for one-off adjustments.

**`reduce_motion` accessibility**: When `true`, all tween durations → 50ms; ceremony `ColorRect` alpha cut is instantaneous. Exposed in in-game Settings; persisted in save file as player preference.

---

## Visual / Audio Requirements

Pure infrastructure — no direct visual/audio assets owned by this system. Each screen's visual/audio are defined in that screen's own GDD. The manager provides:

- Transition `ColorRect` (full-screen, `modulate.a` tweened) — solid black color, no asset needed
- Lantern-flare particle overlay for Ceremony transition — **deferred to VFX System GDD (#27)**; Scene Manager triggers the particle emitter but does not own the asset

**Audio coordination**: Scene Manager emits `screen_changed(new_screen_id, old_screen_id)` signal; Audio System subscribes for background music/ambience crossfades. Scene Manager does not own audio decisions — pure signal emitter.

---

## UI Requirements

No direct UI of its own. The manager is meta-UI (orchestrates other screens).

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 12 criteria total (10 BLOCKING + 2 ADVISORY).

### H-01 — Cross-Fade Completes Within Timing Window (Integration+Performance, BLOCKING)

**GIVEN** scene manager is in IDLE state and current screen is not `guild_hall`,
**WHEN** `request_screen("guild_hall", TransitionType.CROSS_FADE)` is called,
**THEN** outgoing screen's `on_exit` fires first; cross-fade animation starts within the same frame; incoming screen's `on_enter` fires; manager returns to IDLE; total elapsed wall-clock time from the `request_screen` call to IDLE is **150ms ± 10ms**; logged to `production/qa/evidence/screen-manager-timing-[date].md`.

### H-02 — Lifecycle Hook Order (Logic, BLOCKING)

**GIVEN** screen A is active, screen B is a different registered screen,
**WHEN** `request_screen(B.id, any_transition)` called and transition completes,
**THEN** call order is: `A.on_exit()` → transition starts → transition ends → `B.on_enter()`; `A.on_exit` never skipped even if B and A are same class type; `B.on_enter` never called before `A.on_exit` returns.

### H-03 — Same-Screen Request Is a No-Op (Logic, BLOCKING)

**GIVEN** current screen is `guild_hall`, manager in IDLE,
**WHEN** `request_screen("guild_hall", any_transition)` called,
**THEN** no transition starts; manager stays IDLE; `on_exit` not called on current; `on_enter` not called; returns immediately; silent (`push_warning` only, no error signal).

### H-04 — Input Blocked During Transition (Integration, BLOCKING)

**GIVEN** a cross-fade transition is in progress (TRANSITIONING state),
**WHEN** a simulated touch tap or mouse click reaches the input layer between start and end of transition,
**THEN** event consumed by input-block layer; doesn't propagate to any screen; no button `pressed` signal fires; no gameplay state mutation; input unblocks in same frame manager returns to IDLE.

### H-05 — Back-to-Back Transition: Queue with Max-1 (Logic, BLOCKING)

**GIVEN** a transition from A to B is in progress (TRANSITIONING),
**WHEN** `request_screen("screen_c", any_transition)` is called before first transition completes,
**THEN** manager **queues** the second request in `_queued_request` slot; executes it immediately when first transition reaches IDLE. Additional calls during same TRANSITIONING window **overwrite** the queued request with `push_warning` (max 1 in queue); no crash, no orphaned screen instance, no stuck TRANSITIONING state.

*Contract declared*: QUEUE with max-1, overwrite on collision. Matches session-based idle "no urgency" pattern.

### H-06 — Manager Blocks Until DataRegistry Ready (Integration, BLOCKING)

**GIVEN** game just launched; `DataRegistry.registry_ready` has NOT yet fired,
**WHEN** scene manager `_ready()` is called,
**THEN** manager is UNINITIALIZED; any `request_screen` call before `registry_ready` is queued via `_queued_request`; manager does not transition to IDLE until `registry_ready` received; after fires, manager processes queued request.

### H-07 — SaveLoad.persist() Called at Dungeon Run View Boundary (Integration, BLOCKING)

**GIVEN** current screen is not `dungeon_run_view`,
**WHEN** `request_screen("dungeon_run_view", TransitionType.FADE_TO_BLACK)` is called,
**THEN** `scene_boundary_persist` signal emitted **before** transition animation begins; `SaveLoad.persist()` is called; if `persist()` returns error (`save_failed` signal), transition is aborted and manager stays on current screen.

### H-08 — Modal Overlay Pauses Sim Clock, Not UI Animations (Integration, BLOCKING)

**GIVEN** manager is IDLE with any sim-clock-dependent screen active,
**WHEN** a modal overlay (Settings) pushed via overlay API, manager → PAUSED,
**THEN** Time System sim clock pause fires (tick accumulation stops); UI animations and tweens in `PersistentHUDLayer` and `OverlayLayer` continue running; no frame stutter from pause; on overlay dismiss, sim clock resumes from exact tick paused at with no tick debt or skip.

### H-09 — App Backgrounded Mid-Transition (Logic, BLOCKING)

**GIVEN** a transition is in progress (TRANSITIONING),
**WHEN** OS sends `NOTIFICATION_WM_WINDOW_FOCUS_OUT`,
**THEN** in-progress transition completes fully before background handler runs; `on_enter` and `on_exit` not interrupted; manager reaches IDLE before yielding to background; after resume, manager is IDLE with correct destination screen active.

### H-10 — Transition Overhead Under 5ms on Minimum Mobile (Performance, BLOCKING)

**GIVEN** scene manager on minimum-spec mobile,
**WHEN** `request_screen(any, any_transition)` called,
**THEN** scene manager's own code path (excluding tween time, screen `_ready` time, DataRegistry queries) completes in < **5ms** wall-clock; logged to `production/qa/evidence/screen-manager-perf-[date].md`.

### H-11 — No Memory Leaks Over 10 Consecutive Transitions (Performance, BLOCKING)

**GIVEN** scene manager in clean IDLE,
**WHEN** 10 consecutive `request_screen` calls cycling through ≥3 distinct screens,
**THEN** memory (via `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)`) returns to baseline ±2 nodes; no orphaned `Screen` instances in SceneTree; `queue_free` confirmed called on each outgoing screen in same frame its `on_exit` returns.

### H-12 — Touch Feedback Pulse Within One Frame (Integration, ADVISORY)

**GIVEN** any interactive button in a managed screen,
**WHEN** touch/click press event received,
**THEN** 1.05× scale pulse tween begins within **16ms** of input receipt (1 frame at 60fps); completes after **80ms**; pulse fires in IDLE and PAUSED states (not in TRANSITIONING — H-04 blocks input).

*Gate = ADVISORY*: missing pulse degrades feel but doesn't block functionality.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | Cross-fade within 150ms ± 10ms | Integration+Performance | BLOCKING |
| H-02 | Lifecycle hook order | Logic | BLOCKING |
| H-03 | Same-screen request no-op | Logic | BLOCKING |
| H-04 | Input blocked during TRANSITIONING | Integration | BLOCKING |
| H-05 | Back-to-back queue with max-1 | Logic | BLOCKING |
| H-06 | Blocks until DataRegistry ready | Integration | BLOCKING |
| H-07 | SaveLoad.persist() before Dungeon Run | Integration | BLOCKING |
| H-08 | Modal pauses sim clock, not UI | Integration | BLOCKING |
| H-09 | App backgrounded mid-transition | Logic | BLOCKING |
| H-10 | Transition overhead < 5ms on mobile | Performance | BLOCKING |
| H-11 | No memory leaks over 10 transitions | Performance | BLOCKING |
| H-12 | Touch feedback pulse ≤16ms + 80ms | Integration | ADVISORY |

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| **`scene_boundary_persist` signal name** — Save/Load GDD #3 doesn't yet list this subscription. When Save/Load is next revised, add this signal to its upstream dependencies. | main session (coordinating) | Next Save/Load revision or consistency check |
| **Dungeon Run View preload strategy** — if embedded assets grow heavy, use `ResourceLoader.load_threaded_request()`. Verify 4.6 API stability in breaking-changes.md before relying. | godot-gdscript-specialist | Before Dungeon Run View GDD (#24) |
| **Reduce-motion save persistence** — `reduce_motion` accessibility flag must persist in save file. Save/Load schema must include user preference section. | security-engineer (schema) + ux-designer | During Settings Screen GDD (#30) |
| **H-01 timing bounds at 30fps** — if mobile drops to 30fps, ±10ms window is tight (half a frame). Consider widening to ±20ms on mobile, or making the bound frame-rate-aware. | qa-lead | First mobile performance pass |
| **H-07 save-failure policy** — current spec: hard-stop transition on persist failure. If player is mid-dispatch and save fails, they see a modal and stay on current screen. Lenient alternative: log and continue. Hard-stop matches Save/Load anti-tamper posture. | systems-designer + ux-designer | First MVP playtest |
| **Screen-change audio signal** — Scene Manager emits `screen_changed(new, old)` for Audio System subscription. Exact signal signature confirmed during Audio GDD (#28). | audio-director | During Audio System GDD |