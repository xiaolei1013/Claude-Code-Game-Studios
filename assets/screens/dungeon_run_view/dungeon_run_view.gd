## DungeonRunView — live tick + kill_count display + RUN_ENDED overlay + auto-route.
##
## Presentation-layer screen (extends Screen) that subscribes to two signals
## while active:
##   1. [signal TickSystem.tick_fired] at 20 Hz → refreshes tick + kill_count
##      labels O(1) from [member DungeonRunOrchestrator.run_snapshot] (no allocs).
##   2. [signal DungeonRunOrchestrator.state_changed] → detects RUN_ENDED,
##      shows the run-end overlay (Story 012 AC-6 preferred path), and
##      auto-routes to victory_moment via [method SceneManager.request_screen]
##      (Story 013 AC-1 / AC-7).
##
## Acceptance Criteria (8 ACs from Story 012, Sprint 8 S8-M2):
##   AC-1: Live tick display — refreshes on every tick_fired; lags ≤1 tick.
##   AC-2: Live kill_count display — same refresh policy as AC-1.
##   AC-3: Run-end overlay — appears when state transitions to RUN_ENDED;
##         non-blocking (does not freeze the tree or require player input).
##   AC-4: ≥30 FPS while per-tick refresh is active (deferred to S8-M4 smoke).
##   AC-5: Lifecycle hygiene — on_exit disconnects ALL subscriptions; no leaked
##         tick connection after leaving this screen.
##   AC-6: RUN_ENDED detection via DungeonRunOrchestrator.state_changed signal.
##   AC-7: No hardcoded Color literals; no per-screen Theme; no interactive
##         Controls with FOCUS_ALL; suppress_keyboard_focus called in on_enter().
##   AC-8: Screen is reached via SceneManager.request_screen("dungeon_run_view");
##         no SceneTree.change_scene_to_* calls anywhere in this file.
##
## Acceptance Criteria (7 ACs from Story 013, Sprint 8 S8-M3):
##   AC-1: Auto-route on RUN_ENDED — calls SceneManager.request_screen("victory_moment",
##         CROSS_FADE) exactly once after RUN_ENDED is detected.
##   AC-2: Transition completes within ≤500 ms total wall-clock time.
##   AC-3: RUN_END_DWELL_MS = 1500 ms (Sprint 9 S9-M2 polish; valid range [0, 2000]).
##         Supersedes Story 013 Sprint 8 AC-3 range [0, 350] — playtest evidence
##         (S8-M5) showed sub-2s run durations registered 1/5 on Pillar 2.
##   AC-4: Tick subscription disconnects cleanly after route fires (on_exit path).
##   AC-5: Idempotent — _routed flag prevents request_screen from being called twice.
##   AC-6: No bypass of SceneManager (no SceneTree.change_scene_to_*).
##   AC-7: request_screen("victory_moment", CROSS_FADE) is the sole screen-change call.
##
## Governing ADRs:
##   ADR-0007: Screen lifecycle contract (on_enter/on_exit/on_pause/on_resume).
##   ADR-0008: UI Framework (tap-target enforcement, keyboard focus suppression,
##             no hardcoded Color literals, parchment theme cascade).
##
## PERFORMANCE NOTE — _on_tick_fired runs at 20 Hz (HOT PATH):
##   - O(1): two label.text = str(int) calls + one null-check.
##   - No allocations. No format strings (%d / String.format). No tr() calls.
##   - Static prefix labels ("Tick:", "Kills:") set once in on_enter(), not here.
##
## PROCESS MODE NOTE (ADR-0007 Risks Note 4):
##   This screen inherits PROCESS_MODE_PAUSABLE from ScreenContainer. When a
##   modal overlay opens (get_tree().paused = true), _on_tick_fired naturally
##   stops firing — correct behavior; overlay closes before ticks resume.
##
## Story 012 — Sprint 8 S8-M2 | Story 013 — Sprint 8 S8-M3
## Sprint 10 S10-M4: subscribes to HeroRoster.hero_leveled and surfaces a level-up
## toast for the felt-progression moment (first time a hero levels up after a run).
## Toast auto-dismisses after LEVEL_UP_TOAST_LIFETIME_SEC.
extends Screen

# ---------------------------------------------------------------------------
# Preload
# ---------------------------------------------------------------------------

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")

# ---------------------------------------------------------------------------
# Constants (Story 013)
# ---------------------------------------------------------------------------

## Dwell duration in milliseconds between showing the run-end overlay and
## auto-routing to victory_moment.
##
## Sprint 9 S9-M2 polish: bumped from 0 to 1500 ms to ensure ≥2 s perceived
## run duration (Story 013 AC-3 spec deviation). Playtest S8-M5 showed
## sub-2 s runs scored 1/5 on Pillar 2 ("run feels meaningful"). Valid range
## is now [0, 2000]; the Story 013 Sprint 8 constraint of [0, 350] is
## superseded by playtest evidence. See sprint-9.md S9-M2 closure note.
const RUN_END_DWELL_MS: int = 1500

## Lifetime in seconds for the S10-M4 level-up toast. AC: "auto-dismisses ~3s".
## Pattern: 0–2.4 s held visible at full alpha; 2.4–3.0 s fade-out via Tween.
const LEVEL_UP_TOAST_LIFETIME_SEC: float = 3.0
const LEVEL_UP_TOAST_FADE_START_SEC: float = 2.4

# ---------------------------------------------------------------------------
# @onready node references (matched to .tscn node names)
# ---------------------------------------------------------------------------

## Live tick counter label — value updated per tick in _on_tick_fired.
@onready var _tick_label: Label = $StatsPanel/TickRow/TickLabel

## Live kill count label — value updated per tick in _on_tick_fired.
@onready var _kill_count_label: Label = $StatsPanel/KillCountRow/KillCountLabel

## Hidden when the run-end overlay is shown — both panels are anchored at
## center 50% so without hiding, the live tick/kill labels render through
## the overlay's transparent PanelContainer background.
@onready var _stats_panel: VBoxContainer = $StatsPanel

## Run-end overlay container. Hidden by default; shown when state → RUN_ENDED.
@onready var _run_end_overlay: Control = $RunEndOverlay

## Label inside the overlay that receives the final kill_count summary text.
@onready var _run_end_label: Label = $RunEndOverlay/RunEndLabel

## Sprint 19 S19-M3 — HD-2D pipeline biome background layer (GDD #26 + ADR-0019).
## Set to the active run's biome on on_enter so the diorama register reflects
## where the player is dispatched. Falls back to forest_reach if no run is
## currently dispatched (idle DRV — possible via dev navigation).
##
## Typed as ColorRect (BiomeBackground's base class) because the `class_name
## BiomeBackground` global registration is not guaranteed at script-parse time
## in Godot 4.6 — the registry can be cold-loaded after this file's parse.
## Method calls (set_biome) dispatch dynamically and resolve correctly.
@onready var _biome_background: ColorRect = $BiomeBackground

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Set to true after _show_run_end_overlay fires so _on_state_changed is
## idempotent (overlay shows exactly once per screen lifetime, even if
## state_changed fires more than once with RUN_ENDED — defensive guard).
var _overlay_shown: bool = false

## Set to true after request_screen("victory_moment") fires so _on_state_changed
## is idempotent on the routing side (AC-5 Story 013). Guards against a second
## request_screen call if state_changed emits RUN_ENDED more than once while
## the transition is in flight (which would trigger a push_warning from
## SceneManager's TRANSITIONING queue-overwrite guard).
## Distinct from _overlay_shown — they guard different concerns.
var _routed: bool = false


# ---------------------------------------------------------------------------
# Built-in lifecycle (_ready — tap-target + label localisation)
# ---------------------------------------------------------------------------

## Sets localized static prefix text on the two prefix labels.
## These are set once and never changed — they must NOT be set inside
## _on_tick_fired (HOT PATH) because tr() + string assignment allocates.
##
## No interactive Controls exist on this screen in Sprint 8 VS so
## assert_tap_target_min is not called here; suppress_keyboard_focus is
## called in on_enter() after the tree is fully ready.
func _ready() -> void:
	# Localized static prefix labels — written exactly once per lifetime.
	$StatsPanel/TickRow/TickPrefixLabel.text = tr("tick_label_prefix")
	$StatsPanel/KillCountRow/KillCountPrefixLabel.text = tr("kill_count_label_prefix")
	$HeaderLabel.text = tr("dungeon_run_view_title")

	# Ensure overlay is hidden at scene-ready time (redundant with .tscn default
	# but makes the intent explicit for code readers).
	_run_end_overlay.visible = false
	_overlay_shown = false


# ---------------------------------------------------------------------------
# Screen lifecycle hooks (ADR-0007 — all four MUST be declared)
# ---------------------------------------------------------------------------

## Called by SceneManager after this screen becomes current_screen.
##
## Connects two signals:
##   1. GameTime.tick_fired → _on_tick_fired (20 Hz hot path).
##   2. DungeonRunOrchestrator.state_changed → _on_state_changed.
##
## Performs an immediate _refresh_display() so labels show the current snapshot
## even before the first tick fires. Calls UIFramework.suppress_keyboard_focus
## to enforce the single-focus-mode strategy (ADR-0008).
func on_enter() -> void:
	# Reset both idempotency guards for this screen visit (Story 012 + Story 013).
	_overlay_shown = false
	_routed = false
	_run_end_overlay.visible = false

	# Sprint 19 S19-M3 — set the biome background to match the active dispatch.
	# DungeonRunOrchestrator.get_dispatched_biome_id() returns "" when no run
	# is active (e.g. dev navigation into DRV); BiomeBackground.set_biome("")
	# falls back to forest_reach per its own contract (GDD #26 §E + AC-26-12).
	if _biome_background != null:
		_biome_background.set_biome(DungeonRunOrchestrator.get_dispatched_biome_id())

	# Subscribe to tick_fired — 20 Hz hot path.
	# Idempotent via is_connected guard (defensive; SceneManager guarantees
	# only one on_enter per lifetime but guard costs nothing).
	if not TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.connect(_on_tick_fired)

	# Subscribe to state_changed — preferred RUN_ENDED detection path (AC-6).
	if not DungeonRunOrchestrator.state_changed.is_connected(_on_state_changed):
		DungeonRunOrchestrator.state_changed.connect(_on_state_changed)

	# Sprint 10 S10-M4: subscribe to HeroRoster.hero_leveled so the orchestrator's
	# stub XP grant on floor-clear surfaces a player-visible toast. Disconnected
	# in on_exit (AC-5 lifecycle hygiene). Idempotent via is_connected guard.
	if not HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.connect(_on_hero_leveled)

	# Initial render — snap labels to the current snapshot (covers the case
	# where this screen is shown after DISPATCHING has already begun and ticks
	# have already advanced the snapshot before on_enter fires).
	_refresh_display()

	# Single-focus-mode strategy: suppress keyboard/gamepad focus on all Controls.
	UIFrameworkScript.suppress_keyboard_focus(self)

	# Story 013 (Sprint 13 S13-S1) replaces the prior on_enter early-detection
	# hotfix with an orchestrator-level buffered-replay pattern. The Sprint 8
	# S8-M4 + Sprint 9 S9-M2 hotfixes were screen-level workarounds for the
	# during-transition race; the orchestrator now buffers state_changed
	# emissions while SceneManager.state == TRANSITIONING and replays them
	# at SceneManager.transition_complete time, so the slow-path
	# _on_state_changed handler (below) handles BOTH the during-transition
	# fast path AND the normal mid-run path identically.
	#
	# Removed:
	#   - on_enter early-detection block (`if state == RUN_ENDED: ...`)
	#   - _deferred_run_end_route() helper
	# Both became redundant once the orchestrator owns the deferral.
	# See production/epics/dungeon-run-orchestrator/story-013-...md for spec.


## Called by SceneManager BEFORE queue_free. Disconnects ALL signals connected
## in on_enter. After this returns, no orphaned connections remain.
##
## AC-5: GameTime.tick_fired.is_connected(<handler>) == false after on_exit.
func on_exit() -> void:
	# Disconnect tick_fired — primary lifecycle signal for AC-5.
	if TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.disconnect(_on_tick_fired)

	# Disconnect state_changed.
	if DungeonRunOrchestrator.state_changed.is_connected(_on_state_changed):
		DungeonRunOrchestrator.state_changed.disconnect(_on_state_changed)

	# Sprint 10 S10-M4: mirror the on_enter hero_leveled subscription.
	if HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.disconnect(_on_hero_leveled)


## Called by SceneManager when a modal overlay opens on top of this screen.
## No per-screen animations to suspend in Sprint 8 VS.
##
## PROCESS MODE NOTE: ScreenContainer is PROCESS_MODE_PAUSABLE, so
## _on_tick_fired naturally stops firing when get_tree().paused == true.
## on_pause() does not need to manually disconnect the tick subscription.
func on_pause() -> void:
	pass


## Called by SceneManager when the modal overlay closes.
## Snaps labels to the current snapshot in case ticks fired during pause
## (they should not under PROCESS_MODE_PAUSABLE, but this is a safety net
## for any environment where process mode differs from production).
func on_resume() -> void:
	_refresh_display()


# ---------------------------------------------------------------------------
# Per-tick handler — HOT PATH at 20 Hz (O(1) — no allocations allowed)
# ---------------------------------------------------------------------------

## Per-tick handler wired to [signal TickSystem.tick_fired].
##
## HOT PATH CONTRACT:
##   - Defensive null-check on run_snapshot; early-return if null.
##   - Two [code]label.text = str(int)[/code] assignments.
##   - Zero allocations. Zero format strings. Zero tr() calls.
##   - No signal re-emits, no call_deferred.
##
## AC-1: _tick_label.text updated to str(run_snapshot.current_tick).
## AC-2: _kill_count_label.text updated to str(run_snapshot.kill_count).
##
## [param tick_number] is the absolute TickSystem tick counter; not used
## directly (the snapshot's current_tick field mirrors it after each advance).
func _on_tick_fired(_tick_number: int) -> void:
	# Defensive: run_snapshot is null when state is NO_RUN or early DISPATCHING.
	var orch_snapshot: RunSnapshot = DungeonRunOrchestrator.run_snapshot
	if orch_snapshot == null:
		return

	# HOT PATH: two str(int) label writes — the only work done at 20 Hz.
	_tick_label.text = str(orch_snapshot.current_tick)
	_kill_count_label.text = str(orch_snapshot.kill_count)


# ---------------------------------------------------------------------------
# State-change handler — run-end overlay detection (AC-3 / AC-6)
# ---------------------------------------------------------------------------

## Handles [signal DungeonRunOrchestrator.state_changed].
##
## When [param new_state] == RUN_ENDED, shows the run-end overlay (Story 012)
## and auto-routes to victory_moment via SceneManager.request_screen (Story 013 AC-1).
##
## Two distinct idempotency guards cooperate here:
##   [member _overlay_shown] — prevents the overlay from being shown twice.
##   [member _routed]        — prevents request_screen from being called twice
##                             (AC-5 Story 013; a second call while TRANSITIONING
##                             would overwrite the queue with push_warning).
##
## If [const RUN_END_DWELL_MS] > 0 an awaited one-shot Timer gates the route
## call, making this handler async. The [member _routed] flag is set BEFORE
## the await so any re-entrant emission during the dwell is a no-op.
## Sprint 9 S9-M2: default RUN_END_DWELL_MS = 1500 — overlay holds for 1.5 s
## before the cross-fade to victory_moment fires.
##
## AC-7 Story 013: request_screen("victory_moment", CROSS_FADE) is the sole
## screen-change call — no SceneTree.change_scene_to_* call anywhere in
## this handler.
func _on_state_changed(new_state: int, _old_state: int) -> void:
	if new_state != DungeonRunStateScript.State.RUN_ENDED:
		return
	if _routed:
		return  # AC-5 idempotency — route already requested; ignore duplicate.
	_routed = true

	# Show run-end overlay (Story 012 surface). _overlay_shown guards double-show.
	var final_kills: int = 0
	if DungeonRunOrchestrator.run_snapshot != null:
		final_kills = DungeonRunOrchestrator.run_snapshot.kill_count
	_show_run_end_overlay(final_kills)

	# Optional dwell before routing (AC-3 Story 013, expanded by Sprint 9 S9-M2).
	# RUN_END_DWELL_MS = 1500 (Sprint 9 S9-M2) — await holds the overlay for ≥1500 ms.
	if RUN_END_DWELL_MS > 0:
		await get_tree().create_timer(RUN_END_DWELL_MS / 1000.0).timeout

	SceneManager.request_screen("victory_moment", SceneManager.TransitionType.CROSS_FADE)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Reads the current [member DungeonRunOrchestrator.run_snapshot] and updates
## both labels to the current values. Used for the initial render in on_enter()
## and for the safety snap in on_resume().
##
## Defensive null-check: if run_snapshot is null, resets labels to "0".
func _refresh_display() -> void:
	var orch_snapshot: RunSnapshot = DungeonRunOrchestrator.run_snapshot
	if orch_snapshot == null:
		_tick_label.text = "0"
		_kill_count_label.text = "0"
		return
	_tick_label.text = str(orch_snapshot.current_tick)
	_kill_count_label.text = str(orch_snapshot.kill_count)


# ---------------------------------------------------------------------------
# Sprint 10 S10-M4 — level-up toast (felt-progression moment)
# ---------------------------------------------------------------------------

## Handles [signal HeroRoster.hero_leveled] while the dungeon_run_view is
## active. Resolves the hero's display_name from HeroRoster, formats a
## localized toast string, and shows a transient Label that fades out and
## queue_frees itself after [const LEVEL_UP_TOAST_LIFETIME_SEC].
##
## Multiple level-ups in close succession (e.g., a 3-hero formation all
## leveling on the same floor clear) each get their own toast, vertically
## stacked just below the header.
##
## Localization key: [code]"hero_level_up_toast_format"[/code]; falls back to
## "%s reached level %d!" plain-format when the locale doesn't define the key.
##
## ADR-0008 §Touch parity: this toast is purely informational — no input
## required to dismiss. mouse_filter is IGNORE so it never blocks tap-through.
func _on_hero_leveled(instance_id: int, _old_level: int, new_level: int) -> void:
	# Resolve display_name from the live roster. Defensive: if the hero is no
	# longer in the roster (mid-run remove), skip the toast.
	var display_name: String = ""
	for hero: Variant in HeroRoster.get_all_heroes():
		if hero == null:
			continue
		if "instance_id" in hero and int(hero.get("instance_id")) == instance_id:
			if "display_name" in hero:
				display_name = String(hero.get("display_name"))
			break
	if display_name.is_empty():
		display_name = str(instance_id)

	var toast: Label = Label.new()
	toast.name = "LevelUpToast_%d" % instance_id
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# S10-N1: hoisted safe-format pattern via UIFramework.format_localized.
	toast.text = UIFrameworkScript.format_localized(
		"hero_level_up_toast_format", [display_name, new_level]
	)
	# Anchor to top-center, just below HeaderLabel; stack subsequent toasts
	# below by counting existing live toasts.
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(0, 56 + _live_level_up_toast_count() * 28)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)

	# Held visible for FADE_START_SEC, then fade modulate.a from 1.0 → 0.0
	# over the remaining lifetime, then queue_free. Tween is owned by the toast
	# so it auto-cleans if the screen exits early (Tween freed with parent).
	var tween: Tween = toast.create_tween()
	tween.tween_interval(LEVEL_UP_TOAST_FADE_START_SEC)
	tween.tween_property(
		toast, "modulate:a", 0.0,
		LEVEL_UP_TOAST_LIFETIME_SEC - LEVEL_UP_TOAST_FADE_START_SEC
	)
	tween.tween_callback(toast.queue_free)


## Counts currently-live level-up toasts so newly-spawned toasts stack instead
## of overlapping. A toast is "live" while it has not yet been queue_freed.
func _live_level_up_toast_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child is Label and child.name.begins_with("LevelUpToast_"):
			n += 1
	return n


## Shows the run-end overlay with a localized summary containing the final
## kill_count. Sets [member _overlay_shown] so subsequent calls are no-ops.
##
## [param final_kill_count] is read from the snapshot at the moment of
## RUN_ENDED detection — not re-read later (snapshot may be cleared).
##
## Localization key: [code]"run_complete_kill_count_format"[/code].
## Sprint 8 EN value: "Run Complete — %d kills".
##
## AC-3: overlay visible and non-blocking (does not freeze the tree;
## requires no player input to continue — Story 013 owns the auto-route).
func _show_run_end_overlay(final_kill_count: int) -> void:
	_overlay_shown = true
	# S10-N1: hoisted safe-format pattern via UIFramework.format_localized.
	_run_end_label.text = UIFrameworkScript.format_localized(
		"run_complete_kill_count_format", [final_kill_count]
	)
	if _stats_panel != null:
		_stats_panel.visible = false
	_run_end_overlay.visible = true
