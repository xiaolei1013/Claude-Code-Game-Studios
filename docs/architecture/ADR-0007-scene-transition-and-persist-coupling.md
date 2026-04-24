# ADR-0007: Scene Transition Architecture and Persist Coupling

## Status

Accepted

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Source of truth: `design/gdd/scene-screen-manager.md` (Designed, pending independent review)

## Summary

Codifies the Scene/Screen Manager (autoload identifier `SceneManager`) as the sole orchestrator of screen transitions in *Lantern Guild*. Locks: a persistent root scene architecture (`MainRoot.tscn` with four `CanvasLayer` children — HUD/Screen/Transition/Overlay) deliberately rejecting Godot's `change_scene_to_packed()` in favor of a `ScreenContainer` node-swap pattern (preserves persistent state across transitions, enables frame-perfect transition control); the four-state machine `(UNINITIALIZED | IDLE | TRANSITIONING | PAUSED)`; the `Screen` base class with four lifecycle hooks `(on_enter / on_exit / on_pause / on_resume)`; the `request_screen(screen_id, transition_type)` sole external API; the `scene_boundary_persist` signal contract (emitted before `dungeon_run_view` entry and after `victory_moment` exit); the hard-stop persist-failure policy (resolves architecture.md OQ-3); the queue-with-max-1 back-to-back transition contract; the `reduce_motion` accessibility clamp; and the `get_tree().paused = true` modal-overlay → sim-clock-pause coupling. Also fixes architecture.md drift: rank table label `SceneScreenManager` → `SceneManager`, and the incorrect "uses `SceneTree.change_scene_to_packed()`" engine-API claim.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Core / Scripting (CanvasLayer composition, scene tree composition, Tween, AnimationPlayer, get_tree().paused, PROCESS_MODE flags) |
| **Knowledge Risk** | LOW for CanvasLayer / Tween / get_tree().paused / PROCESS_MODE flags (stable since 4.0). MEDIUM for Godot 4.6 dual-focus UI system (per architecture.md §Engine Knowledge Gap Summary — but this ADR doesn't directly touch focus visuals; F06 owns that). |
| **References Consulted** | `design/gdd/scene-screen-manager.md`; `design/gdd/save-load-system.md` §Dependencies (Scene Manager row); `design/gdd/game-time-and-tick.md` §Interactions / Pause; `docs/engine-reference/godot/breaking-changes.md`; `docs/engine-reference/godot/current-best-practices.md`; `docs/engine-reference/godot/modules/ui.md` |
| **Post-Cutoff APIs Used** | None for the chosen pattern. ResourceLoader.load_threaded_request() listed as a future-V1.0 lever for Dungeon Run View asset preload (deferred — open question per GDD §I) |
| **Verification Required** | H-01 timing window 150ms ± 10ms (GDD AC); H-10 transition overhead < 5ms on min-spec mobile (GDD AC). Both are runtime/perf validation, not engine-knowledge gaps. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Autoload Rank Table, Accepted; amended) — establishes the autoload pattern + rank invariant. ADR-0004 (Save Envelope, Accepted) — `scene_boundary_persist` triggers a full-envelope persist. ADR-0005 (Time System, Accepted) — `get_tree().paused = true` interaction with Time System's `PROCESS_MODE_ALWAYS` + explicit pause guard. ADR-0006 (Data Loading, Accepted) — `SceneManager` stays UNINITIALIZED until `DataRegistry.registry_ready` fires. |
| **Enables** | All 7 MVP UI screens (each extends `Screen` base class); the Settings overlay implementation (modal pause path); the onboarding flow (Guild Hall `on_enter` checks `is_first_launch`). All AC H-01 through H-12 in `design/gdd/scene-screen-manager.md`. |
| **Blocks** | SceneManager implementation epic; all 7 Presentation-layer screen implementations; Settings/Accessibility implementation; Save/Load AC-SL-01 happy-path round-trip (depends on `scene_boundary_persist` signal contract). |
| **Ordering Note** | Final Foundation ADR before F06 (UI Framework). Independent of F06 (UI dual-focus parity is presentation-layer; this ADR is orchestration-layer). After this ADR + F06 land, all 6 Foundation ADRs are Accepted and `/architecture-review` may run in a fresh session to populate `tr-registry.yaml`. |

## Context

### Problem Statement

The Scene/Screen Manager is the orchestration layer between every player action that changes screens (tap "Recruit", swipe to roster, exit a dungeon run) and the persistence + time + data layers below. Architecture.md identified ADR-F05 with these decisions to lock:

1. **Which transitions emit `scene_boundary_persist`** — the GDD names two (entering `dungeon_run_view`, exiting `victory_moment`); other persist triggers belong to the heartbeat path (ADR-0005) or graceful exit (ADR-0004).
2. **Persist-failure UX** (architecture.md OQ-3) — hard-stop the transition + modal vs allow + persistent banner vs allow + toast.
3. **Sync vs async persist** — does the transition wait for `save_completed` before proceeding, or run in parallel?
4. **The screen-swap mechanism itself** — and here the existing architecture.md is wrong: it claims `SceneTree.change_scene_to_packed()` is the engine API used, but the GDD explicitly rejects that pattern in favor of a persistent root scene with a `ScreenContainer` node-swap. This drift must be fixed alongside this ADR.

The GDD also surfaces architecture decisions that affect Save/Load + Time System + Audio that no ADR has formalized:
- The `Screen` base class lifecycle hook contract (`on_enter / on_exit / on_pause / on_resume`)
- The four-state machine `(UNINITIALIZED | IDLE | TRANSITIONING | PAUSED)` and `request_screen()` as sole entry point
- The `get_tree().paused = true` ↔ Time System sim-clock pause coupling (Time GDD already mandates `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard, but the cross-system contract isn't ADR-codified)
- The queue-with-max-1 + overwrite-with-push_warning back-to-back transition policy
- The `reduce_motion` accessibility flag (50ms clamp + ceremony cut) and its save-persistence requirement

### Current State

- `design/gdd/scene-screen-manager.md` is fully designed (346 lines, 12 acceptance criteria, 6 open questions). Pending independent review.
- `docs/architecture/architecture.md` §Module Ownership / SceneScreenManager incorrectly states the engine API used is `SceneTree.change_scene_to_packed()`. This must be corrected to "persistent root scene + node-swap; no `change_scene_to_packed()` use" per the GDD's architectural rationale.
- Architecture.md uses the label `SceneScreenManager`; GDD uses `SceneManager` as the autoload identifier. Cross-doc naming drift; same pattern as TickSystem fix.
- ADR-0006 establishes that consumers connect to `DataRegistry.registry_ready` in their `_ready()`. SceneManager follows this pattern (per GDD §C.1 R7).
- ADR-0005 establishes `get_tree().paused` as the cross-system pause boundary; SceneManager drives this flag on PAUSED state entry.
- ADR-0004 establishes the full-envelope persist contract that `scene_boundary_persist` triggers.
- Save/Load GDD §Dependencies references Scene Manager via the `scene_boundary_persist` signal — bidirectional consistency confirmed in GDD §F.

### Constraints

- Godot's `SceneTree.change_scene_to_packed()` unloads the previous scene and loads a new one — this DESTROYS persistent state (autoloads survive, but anything in the previous scene is freed). Persistent state for HUD, persistent overlays, and the manager's own internal state must survive transitions.
- Frame-perfect transition control (input blocking, transition layer compositing) requires the transition layer to live OUTSIDE the screen being swapped. With `change_scene_to_packed()` the entire scene tree is replaced — no place to compose a stable transition layer.
- Art Bible's "stately warm snappiness" constraint: 150ms standard transitions, 800ms ceremony max. Transitions reading as cuts (<80ms) or as waits (>200ms) violate the felt experience.
- Modal overlays (Settings) must NOT replace the current screen — the underlying screen state must persist. Pause must be cross-system (sim clock freezes; UI animations continue).
- Save persistence at scene boundaries is a Pillar 1 contract: entering Dungeon Run View locks in a known-good save state for the offline replay path; leaving Victory Moment persists the unlock state. Failure to persist at these moments is a P0 bug.
- `reduce_motion` accessibility flag must clamp all transitions and persist across sessions (resolves Save/Load schema integration question per GDD §I).
- Performance: H-10 BLOCKING — transition overhead < 5ms on min-spec mobile. H-11 BLOCKING — no memory leaks over 10 consecutive transitions.

### Requirements

- SceneManager MUST be the sole owner of `current_screen` (no other system mutates `ScreenContainer` children directly).
- SceneManager MUST stay UNINITIALIZED until `DataRegistry.registry_ready` fires.
- `request_screen(screen_id, transition_type)` MUST be the sole external API for screen changes.
- Every screen MUST extend the `Screen` base class with all four lifecycle hooks declared (empty body acceptable; missing-hook is FORBIDDEN).
- `scene_boundary_persist` MUST fire before entering `dungeon_run_view` and after exiting `victory_moment` (no other transitions trigger this signal).
- SaveLoad's `save_completed` / `save_failed` response MUST gate the transition: on `save_failed`, transition is ABORTED and manager stays on current screen with a player-facing toast/modal (resolves OQ-3).
- Back-to-back `request_screen` calls during TRANSITIONING MUST queue (max 1); additional calls overwrite the queue with `push_warning`.
- Modal overlay open MUST set `get_tree().paused = true`; close MUST set `get_tree().paused = false`. Time System's tick loop MUST honor this via `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard (per ADR-0005).
- `reduce_motion` flag MUST clamp transitions to 50ms and replace ceremony with instant cut. MUST persist in save file as a SaveLoadSystem `_meta`-adjacent or settings-namespace field (decided here).
- Transition layer MUST block all input via `Control` with `mouse_filter = MOUSE_FILTER_STOP` for the transition duration.
- App-backgrounded mid-transition: in-progress transition MUST complete before background handler runs (per GDD H-09).

## Decision

### Autoload identifier and registration

The Scene/Screen Manager is implemented as the autoload singleton **`SceneManager`**. It is **NOT in the rank table** of ADR-0003 — it is registered as a Godot autoload but its rank position is implementation-detail (must be ≥ rank 6, after DataRegistry rank 1, since it subscribes to `DataRegistry.registry_ready`). Recommended placement: rank 6 or 7 in `project.godot` (between Foundation/Core autoloads and Feature autoloads), but the architectural contract is "autoloaded after DataRegistry; no other Foundation/Core autoload depends on it." Consumers reference via bare-identifier resolution: `SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)`.

Cross-GDD naming drift correction: architecture.md uses `SceneScreenManager` as the system label; GDD uses `SceneManager` as the autoload identifier. Both are corrected to `SceneManager` in Step 4.7.

### Persistent root scene architecture (the contract)

`MainRoot.tscn` is the always-loaded root scene containing four `CanvasLayer` children:

```
MainRoot (Node)
├── PersistentHUDLayer  (CanvasLayer, layer=10)   — persistent HUD elements; PROCESS_MODE_ALWAYS
├── ScreenContainer     (Node)                     — current screen swapped here; PROCESS_MODE_PAUSABLE
├── TransitionLayer     (CanvasLayer, layer=100)   — transition compositing; always above screens; PROCESS_MODE_ALWAYS
└── OverlayLayer        (CanvasLayer, layer=110)   — modal overlays above transitions; PROCESS_MODE_ALWAYS
```

`current_screen` is exactly one Control-based Node child of `ScreenContainer`. Swapping calls:

```gdscript
func _swap_screen(new_scene: PackedScene) -> void:
    var old := current_screen
    if old:
        old.on_exit()
        old.queue_free()  # deallocates at end of frame
    var new := new_scene.instantiate()
    call_deferred("_complete_swap", new)  # next frame; deferred avoids piling freed nodes

func _complete_swap(new_screen: Control) -> void:
    ScreenContainer.add_child(new_screen)
    current_screen = new_screen
    new_screen.on_enter()
    state = State.IDLE
```

**`SceneTree.change_scene_to_packed()` is FORBIDDEN.** Architecture.md's previous claim that this API is used is incorrect and is corrected in Step 4.7. Rationale per GDD §A:
- Persistent state (HUD, autoloads-adjacent observers, manager's own internal state) survives transitions because the root scene never unloads.
- The TransitionLayer lives outside `ScreenContainer` — it can composite over the swap moment without being itself destroyed.
- `OverlayLayer` modals (Settings) layer above transitions — impossible if the entire scene tree is being replaced.
- Consistent with the Art Bible's "always-loaded warm room" framing; the player never experiences a "loading screen" during navigation.

### Four-state machine

```
                        DataRegistry.registry_ready
                                  │
   UNINITIALIZED ──────────────────┴──────────────────► (auto-route to guild_hall or return_to_app)
                                                                │
                                                                ▼
                                                              IDLE
                                                                │
                              request_screen()                  │
                                                                ▼
        ┌─────────────────► TRANSITIONING ◄────────────────────┐
        │                          │                            │
        │                          │ animation_complete         │
        │                          │                            │
        │                          ▼                            │
        │                        IDLE ────────────────────────► │ (request_screen during TRANSITIONING
        │                          │                              queues; max 1; overwrite with push_warning)
        │                          │
        │                          │ modal_overlay_opened
        │                          ▼
        │                       PAUSED ─── overlay_closed ──► IDLE
        │                          │
        │                          │ (no transitions out except overlay close)
        │                          ▼
        └─────────── (no other state transitions)
```

State table from GDD §C.2 (verbatim):

| From | Event | To | Boundary Actions |
|---|---|---|---|
| `UNINITIALIZED` | `registry_ready` fires | `TRANSITIONING` | Check save for offline gains; route to `return_to_app` or `guild_hall` |
| `TRANSITIONING` | Animation complete | `IDLE` | Call `new_screen.on_enter()`; restore TransitionLayer input pass-through |
| `IDLE` | `request_screen()` called | `TRANSITIONING` | Call `current_screen.on_exit()`; queue_free current; play transition; deferred add_child new screen |
| `IDLE` | Modal overlay opened | `PAUSED` | Call `current_screen.on_pause()`; add overlay to OverlayLayer; if Settings: `get_tree().paused = true` |
| `PAUSED` | Modal overlay closed | `IDLE` | Remove overlay; if Settings was open: `get_tree().paused = false`; call `current_screen.on_resume()` |
| `TRANSITIONING` | `request_screen()` called | `TRANSITIONING` | Queue request (max 1); play after current animation completes; additional calls overwrite with `push_warning` |
| `IDLE` | App backgrounded | `IDLE` | Time System heartbeat handles persist; SceneManager does NOT duplicate |
| `IDLE` | App foregrounded | `TRANSITIONING` (conditional) | Load save; if offline_gains > 0: `request_screen("return_to_app", SLIDE_DOWN)` |

### `Screen` base class lifecycle contract

```gdscript
# assets/screens/_base/screen.gd
class_name Screen extends Control

# Required hooks — empty body acceptable, but the method MUST be declared.
# Missing-hook on a Screen subclass is a contract violation (CI grep enforces).

func on_enter() -> void:
    # Called by SceneManager after this screen becomes current_screen.
    # Connect signals here; initialize from game data model (do NOT assume state from prior visit).
    pass

func on_exit() -> void:
    # Called by SceneManager BEFORE queue_free. Disconnect signals; flush any deferred work.
    pass

func on_pause() -> void:
    # Called by SceneManager when a modal overlay opens on top of this screen.
    # The screen is NOT freed; visual continuity is preserved.
    # Pause animations or hide tooltips that don't make sense above an overlay.
    pass

func on_resume() -> void:
    # Called by SceneManager when the modal overlay closes and this screen becomes interactive again.
    # Restore animations / tooltips paused in on_pause.
    pass
```

Every screen extends `Screen`. The four hooks MUST be declared (empty body OK; silent omission is FORBIDDEN). Code review enforces; CI grep verifies.

### `request_screen()` — sole external API

```gdscript
enum TransitionType { CROSS_FADE, SLIDE_UP, SLIDE_LEFT, SLIDE_DOWN, FADE_TO_BLACK, PUSH_MODAL, CEREMONY }

func request_screen(screen_id: String, transition: TransitionType = TransitionType.CROSS_FADE) -> void
```

**No other system may**:
- Call `queue_free()` on a Screen instance
- Mutate `ScreenContainer` children directly
- Replace the root scene via `change_scene_to_packed()` or any equivalent
- Push children to `OverlayLayer` directly (use the modal API — see below)

The modal overlay API is a separate but related entry point:

```gdscript
func push_overlay(overlay_id: String, pause_on_open: bool = true) -> void
func pop_overlay(overlay_id: String) -> void
```

`push_overlay` instantiates the overlay into `OverlayLayer`, calls `current_screen.on_pause()`, sets state to PAUSED. If `pause_on_open == true` (default for Settings), also sets `get_tree().paused = true`. `pop_overlay` reverses both.

### `scene_boundary_persist` signal contract

```gdscript
signal scene_boundary_persist(reason: String)
signal screen_changed(new_screen_id: String, old_screen_id: String)
signal transition_complete(screen_id: String, transition_type: TransitionType)
```

**Persist trigger points** (per GDD §C.2 + §C.3 cross-reference with Save/Load §Dependencies):
- BEFORE `request_screen("dungeon_run_view", FADE_TO_BLACK)` begins its transition animation: emit `scene_boundary_persist("enter_dungeon_run_view")`
- AFTER `request_screen` from `victory_moment` to anything (typically guild_hall): emit `scene_boundary_persist("exit_victory_moment")`

**No other transitions trigger `scene_boundary_persist`.** Other persist paths:
- `heartbeat` (every 60s, per ADR-0005) — TickSystem invokes `SaveLoadSystem.request_heartbeat_persist()` directly; SceneManager not involved
- `graceful_exit` (NOTIFICATION_WM_CLOSE_REQUEST) — TickSystem fires the notification handler; SaveLoadSystem persists full envelope
- `app_backgrounded` (NOTIFICATION_APPLICATION_PAUSED / WM_WINDOW_FOCUS_OUT) — TickSystem heartbeat fires on BG entry; SceneManager does NOT duplicate

### Persist-failure UX: hard-stop the transition (resolves architecture.md OQ-3)

Per GDD H-07 (BLOCKING) + GDD §I open question:

```gdscript
func _on_persist_completed(success: bool, reason: String) -> void:
    if not success:
        # SaveLoad emitted save_failed; transition was already pending after scene_boundary_persist.
        _abort_pending_transition()
        _show_persist_failure_modal(reason)  # non-blocking modal overlay; player can dismiss + retry
        return
    # success: continue with the queued transition
    _continue_pending_transition()
```

**The chosen policy is hard-stop**: on `save_failed`, the transition is ABORTED and SceneManager stays on the current screen with a player-facing modal:

> *"Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]"*
> — Pass-5E-style copy; non-accusatory; reassures continuity; offers agency.

Modal options:
- **Try Again** — re-emits `scene_boundary_persist` after a short delay; on second failure, stay on current screen and surface a persistent corner banner ("Save failed — check storage; will retry") until next successful persist.
- **Stay Here** — dismisses modal; player remains on current screen; no further automatic retry until next user-initiated transition.

This is option (a) from architecture.md OQ-3 ("refuse the transition + show a modal"). Rationale:
- Matches Save/Load anti-tamper posture (don't proceed on corrupted state per ADR-0004 §HMAC verification step 6 modal pattern).
- Pillar 1 (Respect the Player's Time): silently allowing the transition + showing a banner risks the player thinking the run dispatched when it didn't, then losing perceived progress.
- The cozy framing in the modal copy preserves the Pillar 3 (cozy, no-fail) feel — failure is reframed as "storage is settling" not "you broke something".

### Queue-with-max-1 back-to-back transition policy

```gdscript
var _queued_request: Dictionary = {}   # {} == no queued; otherwise {screen_id, transition}

func request_screen(screen_id: String, transition: TransitionType) -> void:
    if state == State.UNINITIALIZED:
        _queued_request = {"screen_id": screen_id, "transition": transition}
        return
    if state == State.TRANSITIONING:
        if _queued_request:
            push_warning("[SceneManager] Overwriting queued request '%s' with '%s'" %
                [_queued_request.screen_id, screen_id])
        _queued_request = {"screen_id": screen_id, "transition": transition}
        return
    if screen_id == current_screen_id:
        push_warning("[SceneManager] Same-screen request '%s' — no-op" % screen_id)
        return
    _execute_transition(screen_id, transition)
```

**Max queue depth is 1**, and overwriting fires `push_warning`, NOT an error. Matches "session-based idle, no urgency" — queue feels natural; reject would feel punitive. Verified by AC H-05 BLOCKING.

### `reduce_motion` accessibility — saved as user preference

```gdscript
@export var reduce_motion: bool = false   # persisted; clamps all transitions to 50ms; replaces ceremony with instant cut
```

`reduce_motion` is exposed in the Settings overlay and persisted in the save file under a `settings` namespace key — adjacent to consumer namespaces but owned by the Settings/Accessibility system (when its GDD lands; for MVP, SceneManager reads it from a `user://settings.cfg` file via Godot's `ConfigFile` until Settings GDD formalizes the Save/Load integration).

When `reduce_motion == true`:
- All standard transitions (CROSS_FADE / SLIDE_* / FADE_TO_BLACK / PUSH_MODAL) clamp to 50ms.
- CEREMONY transition replaces 400-800ms flare with an instant cut + reward number reveal.
- Touch feedback pulse (1.05× scale, 80ms) stays — it's a per-button feedback, not a transition.

The `reduce_motion` save-persistence question is GDD §I OQ; this ADR resolves it by mandating Save/Load integration via the Settings/Accessibility GDD (when authored). For MVP-first-implementation, a fallback path uses `user://settings.cfg` — explicitly documented as a **temporary** path to be replaced when Settings GDD #30 lands.

### `get_tree().paused` ↔ Time System sim-clock pause coupling

When SceneManager enters PAUSED (modal overlay with `pause_on_open == true`):
1. `current_screen.on_pause()` fires
2. Overlay added to `OverlayLayer`
3. `get_tree().paused = true`
4. Per ADR-0005, TickSystem's tick loop runs under `PROCESS_MODE_ALWAYS` with explicit `if get_tree().paused: return` guard — sim clock freezes
5. Per GDD H-08 BLOCKING: UI animations and tweens in `PersistentHUDLayer` and `OverlayLayer` continue running (those layers are also `PROCESS_MODE_ALWAYS`, but they don't gate on `get_tree().paused`)

When SceneManager exits PAUSED:
1. Overlay removed
2. `get_tree().paused = false`
3. TickSystem resumes tick from exact tick paused at (no debt or skip — accumulator residual preserved per ADR-0005's `discarding_accumulator_residual_on_pause` FORBIDDEN pattern)
4. `current_screen.on_resume()` fires

### Transition input-blocking

Full-screen `Control` child of `TransitionLayer` with `mouse_filter = MOUSE_FILTER_STOP`. Active for the duration of TRANSITIONING state; deactivates (`MOUSE_FILTER_IGNORE`) on return to IDLE. Silent-drop policy — taps during transition are CONSUMED and DISCARDED, not queued. Verified by AC H-04 BLOCKING.

### App-backgrounded mid-transition

Per GDD H-09 BLOCKING: in-progress transition completes fully before background handler runs. SceneManager sets `_pending_background_action = true` and lets the active Tween complete. When `tween_finished` fires, the deferred background work runs (TickSystem heartbeat persist; no SceneManager-side persist duplication). On resume, SceneManager is IDLE with the correct destination screen active.

### Tween vs AnimationPlayer choice

Per GDD §C.6 RECOMMEND:
- **Tween** (`create_tween()`) for all 5 standard MVP transitions (CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL) — single-property interpolations with fixed easing.
- **AnimationPlayer** exclusively for the Victory Ceremony transition — multi-node multi-property sequenced keyframes need the timeline editor.

Why not both via Tween: ceremony's multi-property sync (lantern flare particle + reward number tween + audio cue + screen tint) is uncomfortably verbose in code-built Tween chains; AnimationPlayer's editor view is the right tool. Why not all via AnimationPlayer: would require authoring `.tres` AnimationPlayer assets for every transition, including trivial 150ms cross-fade — overkill.

### Architecture diagram

```
                          ┌──────────────────────────────────────┐
                          │ MainRoot.tscn (always loaded)        │
                          │   ┌──────────────────────────────┐   │
                          │   │ PersistentHUDLayer           │   │ layer=10
                          │   │   (HUD bars, persistent UI)  │   │ PROCESS_MODE_ALWAYS
                          │   └──────────────────────────────┘   │
                          │   ┌──────────────────────────────┐   │
                          │   │ ScreenContainer              │   │ Node
                          │   │   ↑ current_screen swapped   │   │ PROCESS_MODE_PAUSABLE
                          │   │     here via add_child       │   │
                          │   └──────────────────────────────┘   │
                          │   ┌──────────────────────────────┐   │
                          │   │ TransitionLayer              │   │ layer=100
                          │   │   ColorRect modulate.a       │   │ PROCESS_MODE_ALWAYS
                          │   │   + input-block Control      │   │
                          │   └──────────────────────────────┘   │
                          │   ┌──────────────────────────────┐   │
                          │   │ OverlayLayer                 │   │ layer=110
                          │   │   (modals — Settings, etc.)  │   │ PROCESS_MODE_ALWAYS
                          │   └──────────────────────────────┘   │
                          └────────────┬─────────────────────────┘
                                       │
                                       │ owned by
                                       ▼
                          ┌──────────────────────────────────────┐
                          │ SceneManager (autoload)              │
                          │ ─────────────────────────────────── │
                          │ State: UNINITIALIZED → IDLE          │
                          │   ↔ TRANSITIONING ↔ PAUSED           │
                          │ API: request_screen, push_overlay    │
                          │      pop_overlay                     │
                          │ Signals: scene_boundary_persist,     │
                          │          screen_changed,             │
                          │          transition_complete         │
                          └────┬───────────────────────┬─────────┘
                               │                       │
   scene_boundary_persist      │                       │ get_tree().paused = true
   (only at dungeon_run_view   │                       │ on PAUSED entry
    enter + victory_moment      │                       │
    exit; no other triggers)   │                       │
                               ▼                       ▼
                    ┌──────────────────────┐  ┌─────────────────────────┐
                    │ SaveLoadSystem (rk2) │  │ TickSystem (rank 0)     │
                    │ — full-envelope      │  │ — sim clock freezes     │
                    │   persist (ADR-0004) │  │   (PROCESS_MODE_ALWAYS  │
                    │ — emits save_completed│ │   + paused guard per   │
                    │   / save_failed      │  │   ADR-0005)            │
                    └──────────┬───────────┘  └─────────────────────────┘
                               │
                               │ save_failed
                               │
                               ▼
              ┌──────────────────────────────────────────────┐
              │ Scene Manager hard-stop policy (resolves OQ-3): │
              │ — abort pending transition                   │
              │ — show persist-failure modal                 │
              │ — stay on current screen                     │
              │ — Try Again / Stay Here options              │
              └──────────────────────────────────────────────┘
```

### Key interfaces

```gdscript
# SceneManager (autoload `SceneManager`, NOT in ranked autoload table)

enum State { UNINITIALIZED, IDLE, TRANSITIONING, PAUSED }
enum TransitionType {
    CROSS_FADE,    # default — 150ms, two overlapping alpha tweens
    SLIDE_UP,      # 180ms ease_out_quad — Recruit screen
    SLIDE_LEFT,    # 180ms ease_out_quad — Matchup Assignment
    SLIDE_DOWN,    # 150-200ms ease_out_quad — Return-to-App, Settings push
    FADE_TO_BLACK, # 300ms — Dungeon Run View enter (triggers scene_boundary_persist)
    PUSH_MODAL,    # 150ms — overlay push helper
    CEREMONY,      # 400-800ms — Victory / Unlock Moment via AnimationPlayer
}

var state: State = State.UNINITIALIZED   # public read; internal write only
var current_screen: Control                # public read; internal write only
var current_screen_id: String              # public read; internal write only

# Public API — sole entry point
func request_screen(screen_id: String, transition: TransitionType = TransitionType.CROSS_FADE) -> void

# Modal overlay API
func push_overlay(overlay_id: String, pause_on_open: bool = true) -> void
func pop_overlay(overlay_id: String) -> void

# Signals
signal scene_boundary_persist(reason: String)               # Save/Load subscribes; full-envelope persist trigger
signal screen_changed(new_screen_id: String, old_screen_id: String)   # Audio System subscribes for music crossfade
signal transition_complete(screen_id: String, transition_type: TransitionType)
signal save_failed_modal_dismissed(retry_requested: bool)   # internal — feeds back into pending transition resolution

# Tuning knobs (read from scene_manager_config.tres at boot — see GDD §G)
@export var default_crossfade_ms: int = 150
@export var slide_duration_ms: int = 180
@export var fade_to_black_ms: int = 300
@export var ceremony_min_ms: int = 400
@export var ceremony_max_ms: int = 800
@export var reduce_motion: bool = false
@export var transition_input_policy: int = INPUT_POLICY_BLOCK   # BLOCK (default) | QUEUE_ONE
```

```gdscript
# Screen base class (assets/screens/_base/screen.gd)
class_name Screen extends Control

func on_enter() -> void: pass
func on_exit() -> void: pass
func on_pause() -> void: pass
func on_resume() -> void: pass
```

## Alternatives Considered

### Alternative 1: `SceneTree.change_scene_to_packed()` per Godot's standard pattern

- **Description**: Use Godot's built-in scene-replacement API. Each screen is a top-level `.tscn` file; transitions call `get_tree().change_scene_to_packed(packed_scene)`. Persistent state lives in autoloads only.
- **Pros**: Idiomatic Godot; least code; well-documented; familiar to any Godot developer.
- **Cons**: Destroys the entire previous scene tree, including any persistent UI elements not in autoloads. The transition layer cannot live outside the scene being swapped — there's no place to compose a stable cross-fade between scenes. Modal overlays would need to be pushed to the SceneTree root (above the swapped scene) by autoload, working against the framework's grain. Loading hitch is observable; the player sees a blink.
- **Estimated Effort**: Lower (less custom infrastructure).
- **Rejection Reason**: The persistent-root pattern is the right tool for this game's transition feel (Art Bible "warm room never empties"). `change_scene_to_packed()` is correct for AAA-style level-based games where each scene is a distinct world; it's wrong for an idle game with a small fixed set of screens that need to feel like rooms in a single building. This was the architecture.md drift error this ADR fixes.

### Alternative 2: Single-scene UI tree with screen visibility toggling

- **Description**: All 7 MVP screens are children of `ScreenContainer` from boot; transitions hide/show via `visible = true/false` and a tween on alpha. No instantiation/free per transition.
- **Pros**: Zero allocation per transition (memory is bounded at boot); H-11 (no memory leaks) is trivially satisfied; transitions are instantaneous from an allocation perspective.
- **Cons**: Boot-time memory ~7× higher (all 7 screens loaded simultaneously). Screen state persists across hides — a `Recruit` screen the player exited stays "as left" rather than re-initializing from the data model. Bug surface fragments: hidden screens may still process input or signals if `mouse_filter`/`PROCESS_MODE` aren't carefully managed. Re-initialization on `on_enter` becomes a per-screen discipline issue rather than a structural guarantee.
- **Estimated Effort**: Comparable.
- **Rejection Reason**: The GDD's "screens must not assume persistence between visits — re-initialize from game data model on each entry" rule is stronger when screens are freed-and-reinstantiated. Boot memory cost (~10MB total per GDD §C.6) is acceptable but trades memory for a discipline weakness — bugs from stale-state hidden screens are insidious. The chosen swap pattern is more defensible.

### Alternative 3: Dedicated transition state machine per screen

- **Description**: Each screen owns its own enter/exit transition; SceneManager just orchestrates the swap. Each screen's `on_enter` plays its own intro animation; `on_exit` plays its outro.
- **Pros**: Per-screen designers have full control; no shared TransitionLayer needed; each screen can do bespoke animations.
- **Cons**: Cross-fade between screen A and screen B requires both screens to be alive simultaneously — back to the visibility-toggle problem. Inconsistent feel across the game (each screen designer makes their own choices). Settings/transition consistency from a single tunable point becomes impossible.
- **Estimated Effort**: Higher (per-screen authoring overhead).
- **Rejection Reason**: Inconsistency. Art Bible mandates "stately warm snappiness" across all transitions; per-screen authoring fragments that consistency. The shared TransitionLayer + tunable timing constants enforce the constraint structurally.

## Consequences

### Positive

- **Locks the persistent-root pattern**. Architecture.md's incorrect `change_scene_to_packed()` claim is corrected; the right engine approach for a small-fixed-set-of-screens cozy game is now ADR-codified.
- **Resolves architecture.md OQ-3** (persist-failure UX) with the hard-stop policy + cozy modal copy. OQ-3 may be marked CLOSED.
- **Cross-system pause coupling formalized**. `get_tree().paused` ↔ TickSystem `PROCESS_MODE_ALWAYS + paused guard` is the bridge between Settings overlay open and sim clock freeze; AC H-08 + AC-TICK-04 both verify.
- **`scene_boundary_persist` contract precisely scoped**. Only two trigger points (dungeon_run_view enter + victory_moment exit); no other transition triggers full-envelope persist. Heartbeat (ADR-0005) and graceful exit (ADR-0004) are the other persist paths; no overlap, no missing trigger.
- **Save-failure UX is player-respectful**. Hard-stop + cozy modal preserves Pillar 1 (no silent data loss) AND Pillar 3 (cozy, no-blame framing). The "Try Again / Stay Here" agency mirrors ADR-0004's HMAC-failure modal pattern.
- **`reduce_motion` accessibility integrated** even before Settings GDD lands — temporary `user://settings.cfg` fallback is documented as a known interim path.
- **Cross-GDD naming drift fixed**. `SceneScreenManager` → `SceneManager`; matches GDD canonical autoload identifier; same pattern as TickSystem fix.

### Negative

- **Custom infrastructure cost**. Implementing the persistent-root + ScreenContainer + TransitionLayer machinery is more code than `change_scene_to_packed()`. Mitigated by the GDD §C.6 godot-specialist VALIDATE notes — every pattern is verified-idiomatic for Godot 4.6.
- **Boot-time scene weight**. MainRoot.tscn must include all four CanvasLayers + PersistentHUDLayer contents at boot. Estimated ~5MB additional persistent memory vs change_scene_to_packed pattern; acceptable per the 256MB mobile ceiling.
- **`reduce_motion` interim persistence path**. Until Settings GDD #30 lands, `user://settings.cfg` is the storage. Adds a second persistence layer (ConfigFile vs SaveLoadSystem). Documented as temporary; tracked in §Open Questions.
- **`SceneManager` autoload rank is unspecified beyond ≥6**. ADR-0003 rank table currently doesn't include SceneManager. Future stories will need a concrete rank assigned; recommended placement is rank 6 or 7 (after Foundation + Core, before Feature autoloads). Tracked as a follow-up.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A future developer reaches for `change_scene_to_packed()` ("standard Godot pattern") and bypasses SceneManager | Medium | High (breaks persistent state; modal overlays break; transition consistency lost) | Registry forbidden_pattern: `direct_scene_tree_change_scene` (registered below); CI grep enforces; coding-standards.md adds explicit "All screen changes MUST go through SceneManager.request_screen" rule |
| A Screen subclass omits one of the four lifecycle hooks (e.g., forgets `on_resume`) | Medium | Low-Medium (silent omission; modal overlay close doesn't restore animation; visual bug, not crash) | Code review checklist; CI grep for `extends Screen` files verifies all four hooks declared |
| `reduce_motion` interim ConfigFile path persists past Settings GDD #30 implementation | Medium | Low (no data loss; just architectural debt) | Tracked in OQ-7; Settings/Accessibility GDD #30 explicitly inherits this contract |
| Modal overlay opened during TRANSITIONING goes to `_queued_modal` slot but transition fails (save_failed) — queued modal never opens | Low | Low (player loses access to a settings invocation; UI feels stuck) | Queued modals execute in IDLE regardless of save_failed outcome — they're not coupled to the transition's success; explicit code path |
| App backgrounded mid-CEREMONY transition (the longest, 400-800ms): full ceremony plays before background handler, delaying persist | Low | Low-Medium (player closes app expecting it to background; ceremony plays for ≤800ms instead) | Per H-09 BLOCKING contract — accepted trade-off; ceremony is a deliberate "stop and feel" moment; abrupt cut would feel worse than a 0.8s tail |
| Tween cleanup misses on a fast back-to-back transition where the queue overwrites mid-animation | Low | Medium (orphaned tween fires on freed node; push_warning or harmless null-call) | H-11 BLOCKING (no memory leaks over 10 transitions) covers this; per-frame test in QA evidence; explicit `tween.kill()` on transition abort path |
| Settings overlay close + immediate modal-open race condition leaves `get_tree().paused = true` when no overlay is active | Low | High (entire game frozen — player perceives crash) | Counter-based pause: `_modal_pause_count` increments on push, decrements on pop; `get_tree().paused` is `_modal_pause_count > 0`; bullet-proof against race |
| Tweens default to `TWEEN_PAUSE_BOUND` (creating-node's process mode determines pause behavior); a screen-local tween created inside a screen child of `ScreenContainer` will FREEZE during modal pause — usually correct, but a screen-local idle animation a developer wants to keep running must explicitly `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` or be created from a PROCESS_MODE_ALWAYS node | Medium | Low (per-screen polish issue; not crash) | Document in Screen base class doc comment + coding-standards.md screen-authoring section. (godot-specialist Step 4.5 Note 1) |
| Active-transition Tween reference is required for H-11 compliance — implementation MUST maintain `_active_transition_tween: Tween` and call `kill()` on any valid prior reference before each new `create_tween()` | Medium | High (memory leak / orphan-tween modulating freed nodes; H-11 BLOCKING fails) | Implementation requirement, not advisory. Pattern: `if _active_transition_tween and _active_transition_tween.is_valid(): _active_transition_tween.kill()` at the start of `_execute_transition()`. (godot-specialist Step 4.5 Note 2) |
| 4.6 dual-focus system: keyboard/gamepad focus is NOT blocked by `MOUSE_FILTER_STOP` on TransitionLayer's input-blocking Control. Not an MVP issue (project is mouse/touch-primary; no gamepad support per technical-preferences.md), but if F06 ever adds keyboard navigation via `grab_focus()`, a complementary focus-disabling step during TRANSITIONING is needed | Low | Low (V1.0 risk only; mitigated by adding focus-disable in F06's UI Framework if/when keyboard nav is introduced) | Tag as known dependency in ADR-F06 when authored. (godot-specialist Step 4.5 Note 3) |
| Children of a Screen subclass inherit `PROCESS_MODE_PAUSABLE` from `ScreenContainer`; child nodes that need to keep running during a modal overlay (e.g., a looping idle particle, persistent counter animation) MUST explicitly set `PROCESS_MODE_ALWAYS` on the child | Medium | Low (per-screen visual polish gotcha) | Document in Screen base class doc comment + coding-standards.md screen-authoring section. (godot-specialist Step 4.5 Note 4) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU per transition | N/A | SceneManager code path: ~1-2ms on PC, target <5ms on min-spec mobile (AC H-10 BLOCKING). Tween animation: 150-300ms wall clock (60fps = 9-18 frames; budget per-frame is 16.6ms minus normal frame work). | < 5ms SceneManager overhead per transition (H-10) |
| CPU per frame during transition | N/A | Tween interpolation + composite of TransitionLayer ColorRect — negligible (single full-screen alpha modulate is GPU-trivial) | 16.6ms per frame |
| Memory (baseline, MainRoot persistent) | N/A | MainRoot.tscn + PersistentHUDLayer + 4 CanvasLayer overhead: ~5MB persistent | 256MB mobile ceiling |
| Memory (per active screen) | N/A | One screen instance in ScreenContainer; queue_free deallocates at end of frame; at most one "pending free" screen at any time | Per-screen typically 1-5MB; H-11 BLOCKING verifies no leak over 10 transitions |
| Memory (max during transition) | N/A | Outgoing screen pending free + incoming screen newly added = up to 2× peak per-screen for ~16ms (one frame); deallocates immediately after | Peak +5-10MB transient; well within budget |
| Save persist time at scene_boundary_persist | Inherits ADR-0004 budget | < 10ms PC / < 50ms mobile (per ADR-0004 §performance budgets) | ADR-0004 budget unchanged |

## Migration Plan

**No migration required for MVP** — no SceneManager implementation exists yet; this ADR codifies the contracts the first MVP build will implement.

**Architecture.md sync update (Step 4.7 deliverable)**:
1. Replace all occurrences of `SceneScreenManager` with `SceneManager` in `docs/architecture/architecture.md`.
2. Update §Module Ownership / SceneManager (formerly SceneScreenManager) `Engine APIs` line: replace `SceneTree.change_scene_to_packed(). LOW risk.` with `Persistent root scene composition (CanvasLayer + ScreenContainer node-swap pattern); explicitly does NOT use SceneTree.change_scene_to_packed(). LOW risk for CanvasLayer / Tween / get_tree().paused / PROCESS_MODE flags.`

**Future post-MVP changes**:
- Adding a new screen: create `assets/screens/<screen_name>.tscn`, ensure it extends `Screen` with all four lifecycle hooks, add a registration entry to SceneManager's screen registry. Rank assignment N/A (screens are not autoloads).
- Adding a new transition type: append to the `TransitionType` enum, implement the corresponding tween/animation in SceneManager's transition dispatcher, add timing budget to GDD §D.1.
- Replacing `user://settings.cfg` with Save/Load `_meta`-adjacent or settings-namespace persistence: when Settings/Accessibility GDD #30 lands, the `reduce_motion` field migrates from ConfigFile to the save envelope. Migration: read both at boot during transition window; write only to save envelope after; delete ConfigFile entry on first successful save with the field present.

**Rollback plan**: If the persistent-root pattern proves untenable in production (e.g., per-screen memory grows beyond mobile budget), supersede with Alternative 1 (`change_scene_to_packed()`). Persistent state would need to migrate to autoloads (HUD becomes an autoload; modal management moves to a separate UIRoot autoload). Significant refactor; not anticipated.

## Validation Criteria

All 12 GDD acceptance criteria (H-01 through H-12) are this ADR's validation criteria. Specifically:

- [ ] H-01 (BLOCKING): cross-fade completes within 150ms ± 10ms; logged to `production/qa/evidence/screen-manager-timing-[date].md`.
- [ ] H-02 (BLOCKING): lifecycle hook order is `A.on_exit → transition → B.on_enter`; never inverted, never skipped.
- [ ] H-03 (BLOCKING): same-screen request is no-op; silent except `push_warning`.
- [ ] H-04 (BLOCKING): input blocked during TRANSITIONING via `MOUSE_FILTER_STOP`.
- [ ] H-05 (BLOCKING): back-to-back transitions queue with max-1; overwrite fires `push_warning`; no orphan, no crash.
- [ ] H-06 (BLOCKING): SceneManager stays UNINITIALIZED until `DataRegistry.registry_ready` fires; queued requests execute in order on transition to IDLE.
- [ ] H-07 (BLOCKING): `scene_boundary_persist` emitted before `dungeon_run_view` transition; on `save_failed`, transition aborted + modal shown.
- [ ] H-08 (BLOCKING): modal overlay pauses sim clock (per ADR-0005 contract); UI animations in PersistentHUDLayer + OverlayLayer continue running; sim clock resumes from exact tick on overlay close (no tick debt).
- [ ] H-09 (BLOCKING): app backgrounded mid-transition completes the transition before yielding to background handler.
- [ ] H-10 (BLOCKING): SceneManager code path (excluding tween / DataRegistry / `_ready`) under 5ms on min-spec mobile.
- [ ] H-11 (BLOCKING): no memory leak over 10 consecutive transitions; node count returns to baseline ±2.
- [ ] H-12 (ADVISORY): touch feedback pulse begins within 16ms of input receipt; 80ms duration.
- [ ] Architecture.md updated: `SceneScreenManager` → `SceneManager`; `change_scene_to_packed()` claim corrected.
- [ ] CI grep enforces: no `change_scene_to_packed(` calls outside SceneManager itself.
- [ ] CI grep enforces: every `extends Screen` file declares all four lifecycle hooks (even if empty body).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/scene-screen-manager.md` §A Overview | Scene Manager | "Persistent root scene architecture (`MainRoot.tscn` with HUD/Screen/Transition/Overlay CanvasLayers); current screen swapped as child node rather than via `change_scene_to_packed()`" | Codifies the persistent-root pattern; explicitly forbids `change_scene_to_packed()`; corrects architecture.md drift. |
| `design/gdd/scene-screen-manager.md` §C.1 Core Rules 1-8 | Scene Manager | "SceneManager autoload; current_screen sole child of ScreenContainer; queue_free + call_deferred swap; Screen base class with four lifecycle hooks; transitions not skippable; modal overlays use OverlayLayer; TransitionLayer blocks input; SceneManager doesn't own Boot/Splash; request_screen is sole external API" | All 8 rules locked verbatim in Decision section; FORBIDDEN patterns registered for the negative-case enforcement. |
| `design/gdd/scene-screen-manager.md` §C.2 States and Transitions | Scene Manager | "Four-state machine UNINITIALIZED → IDLE ↔ TRANSITIONING ↔ PAUSED; queue-with-max-1 contract; scene_boundary_persist trigger points" | State machine + queue policy + signal trigger points all locked; AC H-05 + H-07 verify. |
| `design/gdd/scene-screen-manager.md` §C.3 Interactions / Time System | Time | "SceneManager sets get_tree().paused during PAUSED state; Time System's tick loop uses PROCESS_MODE_ALWAYS + if get_tree().paused: return guard" | Codifies the cross-system pause coupling; ties to ADR-0005 (Time System) where the receiving-side contract is locked. |
| `design/gdd/scene-screen-manager.md` §H AC H-07 + §I OQ #5 | Scene Manager | "Save-failure policy: hard-stop transition + modal" | Resolves architecture.md OQ-3 with the hard-stop choice + cozy modal copy; matches Save/Load anti-tamper posture. |
| `design/gdd/scene-screen-manager.md` §G Tuning Knobs | Scene Manager | "All transition timing knobs in scene_manager_config.tres; reduce_motion accessibility flag clamps to 50ms + ceremony cut" | All 9 tuning knobs preserved as `@export` runtime-tunable; `reduce_motion` save-persistence path documented (interim ConfigFile, target Save/Load integration via Settings GDD #30). |
| `design/gdd/save-load-system.md` §Dependencies (Scene Manager row) | Save/Load | "Subscribes to scene_boundary_persist; emits save_completed and save_failed back" | Codifies the bidirectional contract; ADR-0004 full-envelope persist is the trigger response. |
| `design/gdd/game-time-and-tick.md` §Interactions / Pause | Time | "On PAUSED (Settings overlay): get_tree().paused = true; Time System's tick loop freezes via PROCESS_MODE_ALWAYS + paused guard" | Codifies SceneManager as the writer-side of the cross-system contract (ADR-0005 codifies the reader-side). |
| `docs/architecture/architecture.md` §Module Ownership / SceneScreenManager | (cross-cutting) | "Engine APIs: SceneTree.change_scene_to_packed(). LOW risk." | **CORRECTED** by this ADR: persistent root + node-swap pattern; explicitly NOT change_scene_to_packed. Architecture.md updated in Step 4.7. |
| `docs/architecture/architecture.md` §Open Question OQ-3 | (cross-cutting) | "When save_failed fires, do we (a) refuse + toast, (b) refuse + modal, (c) allow + persistent banner?" | **RESOLVED** by adopting (b): refuse + modal with cozy "Try Again / Stay Here" copy; OQ-3 marked CLOSED. |

## Related Decisions

- ADR-0003 (Autoload Rank Table, Accepted; amended) — establishes the autoload pattern + rank invariant; SceneManager is autoloaded but rank position is implementation-detail (≥ rank 6).
- ADR-0004 (Save Envelope, Accepted) — `scene_boundary_persist` is the trigger for the full-envelope persist contract.
- ADR-0005 (Time System, Accepted) — `get_tree().paused = true` ↔ TickSystem pause coupling; ceremony transition timing must respect TickSystem's `PROCESS_MODE_ALWAYS` + paused-guard pattern.
- ADR-0006 (Data Loading, Accepted) — SceneManager stays UNINITIALIZED until `DataRegistry.registry_ready` fires.
- ADR-F06 (UI Framework: dual-focus parity, planned) — independent peer; Scene Manager is orchestration-layer, F06 is presentation-layer.
- `design/gdd/scene-screen-manager.md` — full implementation spec (this ADR's source of truth).
- `design/gdd/save-load-system.md` §Dependencies — Save/Load side of the `scene_boundary_persist` contract.
- `design/gdd/game-time-and-tick.md` §Interactions — Time System side of the `get_tree().paused` contract.
- `docs/architecture/architecture.md` §Module Ownership / SceneManager — **corrected** alongside this ADR.

## Open Questions Created by This ADR

- **OQ-7 (`reduce_motion` persistence path)**: Until Settings/Accessibility GDD #30 lands, `reduce_motion` persists via `user://settings.cfg` (ConfigFile). When GDD #30 lands, migrate to Save/Load envelope under a `settings` namespace key. Resolution target: when Settings GDD is authored.
- **OQ-8 (SceneManager rank assignment)**: ADR-0003 rank table doesn't include SceneManager; recommended placement is rank 6 or 7. Resolution: when SceneManager implementation story is drafted, assign concrete rank in ADR-0003 §Rank table + amend if needed.
