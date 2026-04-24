# Epic: Scene Manager

> **Layer**: Foundation
> **GDD**: `design/gdd/scene-screen-manager.md`
> **Architecture Module**: `SceneManager` (autoload rank ≥6, OQ-8 unassigned)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories scene-manager`

## Overview

Implements the persistent-root scene orchestration layer per ADR-0007. A
single `MainRoot.tscn` with four CanvasLayer children serves as the
application root: `PersistentHUDLayer` (layer=10, `PROCESS_MODE_ALWAYS`),
`ScreenContainer` (Node, `PROCESS_MODE_PAUSABLE`), `TransitionLayer`
(layer=100, `PROCESS_MODE_ALWAYS`), `OverlayLayer` (layer=110,
`PROCESS_MODE_ALWAYS`). All screen changes flow through
`request_screen(screen_id, transition_type)`; all modal coordination
through `push_overlay(overlay_id, pause_on_open) / pop_overlay(overlay_id)`
with counter-based `_modal_pause_count` to prevent stuck-pause races.
Four-state machine: `UNINITIALIZED | IDLE | TRANSITIONING | PAUSED`.
Every screen extends `Screen extends Control` and MUST declare all four
lifecycle hooks (`on_enter`, `on_exit`, `on_pause`, `on_resume`). Fires
`scene_boundary_persist(reason)` before entering `dungeon_run_view` and
after exiting `victory_moment` — no other transitions trigger it. Aborts
transitions on `save_failed` with cozy "Try Again / Stay Here" modal
(resolves OQ-3 hard-stop). Five standard transitions via `Tween`
(CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL); CEREMONY transition
exclusively via `AnimationPlayer`. Maintains `_active_transition_tween`
reference and `kill()`s any valid prior before `create_tween()` to
prevent leaks. `reduce_motion` accessibility flag clamps standard
transitions to 50ms and replaces CEREMONY with instant cut + reward
reveal (persisted to interim `user://settings.cfg`; migrates to
Save/Load envelope when Settings GDD #30 lands). Time-gated cozy modal
for offline replay (`PROGRESS_MODAL_THRESHOLD_MS=100` per ADR-0014 §5).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Autoload Rank Table Canonical | SceneManager rank ≥6 (after DataRegistry); UNINITIALIZED until `DataRegistry.registry_ready` fires; rank assignment itself is OQ-8 (implementation-time) | LOW |
| ADR-0007: Scene Transition + Persist Coupling | Persistent-root scene layout; `request_screen` sole external API; four-state machine; `scene_boundary_persist` narrow trigger; Tween for 5 standard + AnimationPlayer for CEREMONY; `_active_transition_tween` leak guard; `reduce_motion` flag; counter-based modal pause | **HIGH** — `CanvasLayer` process-mode interactions; `Tween` with `TWEEN_PAUSE_BOUND` default; 4.5 Recursive Control disable; `MOUSE_FILTER_IGNORE` cascades but STOP does NOT; `get_tree().paused` semantics |
| ADR-0008: UI Framework + Dual-Focus Parity + Parchment Theme | `MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")` cascades to all Control descendants; `UIFramework.suppress_keyboard_focus(root)` walks tree setting `focus_mode = FOCUS_NONE` (MVP single-focus-mode strategy); `UIFramework.assert_tap_target_min(self)` in every interactive Control's `_ready()` (debug-only) | MEDIUM — 4.6 dual-focus sidestepped; 4.5 FoldableContainer, AccessKit (deferred to Settings GDD #30); `MOUSE_FILTER_STOP` cascade behavior |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | Time-gated cozy modal at ≥100ms estimated replay; `SceneManager.show_modal(_progress_modal)` auto-dismisses on `offline_rewards_collected`; main-thread `await get_tree().process_frame` yield between chunks | LOW — coordination contract |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-scene-manager-001..039`) | **39** |
| Covered by Accepted ADR | ~37 |
| Partial | ~2 |
| Gap | 0 (OQ-7 Settings GDD #30 persistence — `user://settings.cfg` interim holds for MVP) |

Full per-TR detail: `docs/architecture/requirements-traceability.md` §Foundation Layer and `docs/architecture/tr-registry.yaml` (filter by `TR-scene-manager-*`).

## Engine Compatibility Notes

Verify during story implementation (Godot 4.6):
- Tween `TWEEN_PAUSE_BOUND` default behavior — transitions bound to SceneTree pause (verify before wiring modal-pause coupling)
- 4.5 `CanvasItem.visible` recursive disable — behavior shift from 4.4 (affects lifecycle hook ordering)
- `MOUSE_FILTER_IGNORE` cascades to children; `MOUSE_FILTER_STOP` does NOT (ADR-0008 LOAD-BEARING note) — OverlayLayer input-block pattern uses full-screen STOP-mode Control
- Screen children inherit `PROCESS_MODE_PAUSABLE` by default — explicit override required for `PROCESS_MODE_ALWAYS` sibling children under PausableContainer
- `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` FORBIDDEN — persistent root + ScreenContainer node-swap pattern per ADR-0007 substantive correction
- AccessKit screen-reader integration (4.5+) covers static menus only — defer dynamic-modal coverage to V1.0 (flagged in accessibility-requirements.md open questions)

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scene-screen-manager.md` are verified (AC-H-01..12 + persist-coupling ACs)
- All Logic stories have passing test files in `tests/unit/scene_manager/` (state-machine transitions, modal counter invariants, `_active_transition_tween` leak guard, `reduce_motion` clamp)
- All Integration stories have passing test files in `tests/integration/scene_manager/` (`save_failed` abort path, `scene_boundary_persist` narrow trigger, 10-transition memory-leak soak, BG-during-transition completion)
- UI stories (screen lifecycle hooks, modal cozy copy, reduce_motion toggle) have evidence docs with sign-off in `tests/evidence/`
- Standard cross-fade = 150ms ± 10ms (AC H-01 BLOCKING)
- Transition overhead <5ms on min-spec mobile, excluding tween + DataRegistry + `_ready()` (AC H-10 BLOCKING)
- Zero memory leaks over 10 consecutive transitions (AC H-11 BLOCKING)
- Touch feedback begins within 16ms of input receipt; 80ms pulse duration (AC H-12 ADVISORY)
- No `SceneTree.change_scene_to_*` calls from any code (CI grep per ADR-0007)
- No direct `ScreenContainer` mutation from outside SceneManager (CI grep per ADR-0007)
- No direct `get_tree().paused = ...` writes from outside SceneManager modal API (CI grep per ADR-0007)
- Every `Screen` subclass declares all 4 lifecycle hooks (CI check per ADR-0007)
- `MainRoot.theme` preload wiring present; `UIFramework.assert_tap_target_min` called in every interactive Control's `_ready()` (ADR-0008)

## Next Step

Run `/create-stories scene-manager` to break this epic into implementable stories.
