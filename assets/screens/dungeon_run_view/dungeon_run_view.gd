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
const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
# Demo enemy sprites for the "Enemies ahead" lineup (no-op without demo assets).
const EnemySpriteFactoryScript = preload("res://src/ui/enemy_sprite_factory.gd")

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

## Hero levels that earn an emphasized "milestone" toast (vs the routine
## per-level toast). 15 is the level cap, so it doubles as the max-level beat.
const _MILESTONE_LEVELS: Array[int] = [10, 15]

## Emphasized-toast font size (vs the theme-default routine toast).
const _MILESTONE_TOAST_FONT_SIZE: int = 20

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

## Lantern Guild mock wireframe (feat/ui-wireframe-core-loop) — greybox HUD state.
var _wire_built: bool = false
var _float_layer: Control = null


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
	# Pass the dispatched floor_index so the boss floor renders with a darkened
	# palette per BiomeBackground's per-floor modulation. Regular floors render
	# at baseline. get_dispatched_biome_id() returns "" when no run is active
	# (e.g. dev nav into DRV); BiomeBackground falls back to forest_reach per
	# its own contract (GDD #26 §E + AC-26-12).
	if _biome_background != null:
		_biome_background.set_biome(
			DungeonRunOrchestrator.get_dispatched_biome_id(),
			DungeonRunOrchestrator.get_dispatched_floor_index()
		)

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

	# Felt-progression: a gate floor cleared THIS run can unlock a new region.
	# biome_unlocked fires while this screen is live (the player is watching the
	# run), so the toast surfaces here — the guild_hall subscription rarely sees
	# it because the hall isn't the active screen mid-run. Disconnected in on_exit.
	if FloorUnlock.has_signal("biome_unlocked") and not FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.connect(_on_biome_unlocked)

	# Initial render — snap labels to the current snapshot (covers the case
	# where this screen is shown after DISPATCHING has already begun and ticks
	# have already advanced the snapshot before on_enter fires).
	_refresh_display()

	# Single-focus-mode strategy: suppress keyboard/gamepad focus on all Controls.
	UIFrameworkScript.suppress_keyboard_focus(self)

	# Lantern Guild mock wireframe (feat/ui-wireframe-core-loop): build the
	# greybox live-Expedition HUD once.
	_build_wireframe_once()

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

	# Mirror the on_enter biome_unlocked subscription.
	if FloorUnlock.has_signal("biome_unlocked") and FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.disconnect(_on_biome_unlocked)


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

	# Milestone levels (10, cap-15) earn an emphasized toast; routine levels get
	# the standard one. Both auto-dismiss + stack via the shared spawner.
	var is_milestone: bool = new_level in _MILESTONE_LEVELS
	var loc_key: String = "hero_milestone_toast_format" if is_milestone else "hero_level_up_toast_format"
	var text: String = UIFrameworkScript.format_localized(loc_key, [display_name, new_level])
	_spawn_run_toast(text, "LevelUpToast_%d" % instance_id, is_milestone)


## Felt-progression: a new region unlocked mid-run (a gate floor cleared). Shows
## an emphasized toast naming the region. Defensive — skips if the biome can't be
## resolved (data drift). Mirrors guild_hall._on_biome_unlocked, but fires here
## where the player is actually watching when the unlock happens.
func _on_biome_unlocked(biome_id: String) -> void:
	var biome: Variant = DataRegistry.resolve("biomes", biome_id)
	if biome == null or not ("display_name" in biome):
		return
	var display_name: String = String(biome.get("display_name"))
	if display_name.is_empty():
		return
	var text: String = UIFrameworkScript.format_localized(
		"biome_unlocked_toast_format", [display_name]
	)
	_spawn_run_toast(text, "BiomeUnlockToast", true)


## Spawns a self-fading, self-freeing toast Label anchored top-center. Stacks
## below any live toasts. [param emphasized] bumps the font size + tints it the
## WireframeKit accent (gold) for milestone / unlock beats. The owning Tween is
## parented to the toast so it auto-cleans if the screen exits mid-fade.
func _spawn_run_toast(text: String, node_name: String, emphasized: bool) -> void:
	var toast: Label = Label.new()
	toast.name = node_name
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# S10-N1: hoisted safe-format pattern — caller already formatted the text.
	toast.text = text
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(0, 56 + _live_toast_count() * 28)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if emphasized:
		toast.add_theme_font_size_override("font_size", _MILESTONE_TOAST_FONT_SIZE)
		toast.add_theme_color_override("font_color", WireframeKitScript.ACCENT)
	add_child(toast)

	# Held visible for FADE_START_SEC, then fade modulate.a 1.0 → 0.0 over the
	# remaining lifetime, then queue_free. Tween owned by the toast so it
	# auto-cleans if the screen exits early (Tween freed with parent).
	var tween: Tween = toast.create_tween()
	tween.tween_interval(LEVEL_UP_TOAST_FADE_START_SEC)
	tween.tween_property(
		toast, "modulate:a", 0.0,
		LEVEL_UP_TOAST_LIFETIME_SEC - LEVEL_UP_TOAST_FADE_START_SEC
	)
	tween.tween_callback(toast.queue_free)


## Counts currently-live toasts (level-up + biome-unlock) so newly-spawned
## toasts stack instead of overlapping. A toast is "live" until queue_freed.
func _live_toast_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child is Label and child.name.contains("Toast"):
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


# ===========================================================================
# Lantern Guild mock wireframe — greybox live Expedition HUD
# (feat/ui-wireframe-core-loop)
#
# Recreates the mock's Expedition layout (party HUD top-left, run stats +
# Return-to-Hall top-right, expedition progress bottom-right, channel-light
# lantern bottom-center, event feed mid-left) at greybox fidelity, built
# additively over the existing display-only nodes. The real tick/kill labels
# are kept and repositioned into the run-stats HUD.
#
# NO Color() literals in this file — all colors route through WireframeKit
# constants (dungeon_run_view_screen_test greps this file for Color literals).
# ===========================================================================

const _WIRE_Z: int = 1


func _place(node: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	if node == null:
		return
	node.anchor_left = al
	node.anchor_top = at
	node.anchor_right = ar
	node.anchor_bottom = ab
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob


func _build_wireframe_once() -> void:
	if _wire_built:
		return
	_wire_built = true
	_reposition_existing_nodes_drv()
	_build_party_hud()
	_build_enemy_lineup_drv()
	_build_run_stats_hud()
	_build_progress_panel()
	_build_activity_feed_drv()
	_build_lantern_drv()
	var layer: Control = WireframeKitScript.float_layer()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer = layer


func _reposition_existing_nodes_drv() -> void:
	var header: Label = get_node_or_null("HeaderLabel") as Label
	if header != null:
		_place(header, 0, 0, 1, 0, 0.0, 14.0, 0.0, 54.0)
		header.z_index = 2
	# Real live tick/kill labels → top-right, over the run-stats backing panel.
	if _stats_panel != null:
		_place(_stats_panel, 1, 0, 1, 0, -232.0, 48.0, -28.0, 112.0)
		_stats_panel.z_index = 2
	# Keep the run-end overlay above the wireframe HUD when it shows.
	if _run_end_overlay != null:
		_run_end_overlay.z_index = 5


## Top-left: party HUD — real formation heroes with placeholder HP.
func _build_party_hud() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Party")
	panel.name = "WirePartyHud"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 0, 0, 14.0, 14.0, 324.0, 232.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	var party: Array = []
	if HeroRoster != null:
		party = HeroRoster.get_formation_heroes()
	if party.is_empty():
		body.add_child(WireframeKitScript.caption(
			"No party on this expedition.", WireframeKitScript.MUTED))
		return
	for h: Variant in party:
		if h == null:
			continue
		var nm: String = "Hero"
		if "display_name" in h:
			nm = String(h.display_name)
		var lvl: int = 0
		if "current_level" in h:
			lvl = int(h.current_level)
		var cls: String = ""
		if "class_id" in h:
			cls = String(h.class_id)
		body.add_child(WireframeKitScript.list_tile(
			nm, "%s · Lv %d" % [cls, lvl], "HP"))


## Center, upper-middle: the enemies on the current floor — the diorama focal
## point the party is dispatched against. A horizontal row of sprite + name +
## ×count cells, resolved from the dispatched biome/floor's enemy_list. Enemy
## sprites come from the demo pack (EnemySpriteFactory); absent → greybox box.
func _build_enemy_lineup_drv() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Enemies ahead")
	panel.name = "WireEnemyLineup"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0.5, 0, 0.5, 0, -280.0, 188.0, 280.0, 384.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)

	var enemies: Array = _resolve_floor_enemies()
	if enemies.is_empty():
		body.add_child(WireframeKitScript.caption(
			"The way ahead is quiet.", WireframeKitScript.MUTED))
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	for entry: Dictionary in enemies:
		row.add_child(_make_enemy_cell(entry))


## One enemy cell: sprite thumbnail (or greybox), name, and ×count when >1.
func _make_enemy_cell(entry: Dictionary) -> Control:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(84, 0)
	cell.add_theme_constant_override("separation", 2)

	var tex: Texture2D = EnemySpriteFactoryScript.get_sprite(String(entry.get("enemy_id", "")))
	if tex != null:
		var slot: TextureRect = TextureRect.new()
		slot.custom_minimum_size = Vector2(60, 60)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = tex
		cell.add_child(slot)
	else:
		cell.add_child(WireframeKitScript.placeholder_box("", Vector2(60, 60)))

	var name_lbl: Label = WireframeKitScript.caption(
		String(entry.get("display_name", "")), WireframeKitScript.TEXT, 11)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(84, 0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_child(name_lbl)

	var cnt: int = int(entry.get("count", 1))
	if cnt > 1:
		var cnt_lbl: Label = WireframeKitScript.caption(
			"×%d" % cnt, WireframeKitScript.MUTED, 11)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cnt_lbl)
	return cell


## Resolves the dispatched floor's enemy roster as
## [{enemy_id, count, display_name}]. Empty when no run is dispatched or the
## biome/floor cannot be resolved. Defensive duck-typing throughout — the screen
## must never crash on missing content.
func _resolve_floor_enemies() -> Array:
	var out: Array = []
	if BiomeDungeonDatabase == null:
		return out
	var biome_id: String = DungeonRunOrchestrator.get_dispatched_biome_id()
	var floor_index: int = DungeonRunOrchestrator.get_dispatched_floor_index()
	if biome_id == "":
		return out

	var biome: Variant = BiomeDungeonDatabase.get_biome_by_id(biome_id)
	if biome == null or not ("dungeons" in biome) or (biome.dungeons as Array).is_empty():
		return out
	var dungeon: Variant = biome.dungeons[0]
	if dungeon == null or not ("floors" in dungeon) or (dungeon.floors as Array).is_empty():
		return out

	var target: Variant = null
	for f: Variant in dungeon.floors:
		if f != null and ("floor_index" in f) and int(f.floor_index) == floor_index:
			target = f
			break
	if target == null:
		target = dungeon.floors[0]  # defensive: fall back to the first floor
	if not ("enemy_list" in target):
		return out

	for entry: Variant in target.enemy_list:
		var data: Dictionary = entry as Dictionary
		var eid: String = String(data.get("enemy_id", ""))
		if eid == "":
			continue
		out.append({
			"enemy_id": eid,
			"count": int(data.get("count", 1)),
			"display_name": _enemy_display_name(eid),
		})
	return out


## Localized-ish display name for an enemy id, via DataRegistry; falls back to
## a capitalized id when the enemy resource or its display_name is unavailable.
func _enemy_display_name(enemy_id: String) -> String:
	if DataRegistry != null and DataRegistry.has_method("resolve"):
		var ed: Variant = DataRegistry.resolve("enemies", enemy_id)
		if ed != null and ("display_name" in ed) and String(ed.display_name) != "":
			return String(ed.display_name)
	return enemy_id.capitalize()


## Top-right: run stats backing panel + Return-to-Hall. The real StatsPanel
## (Tick/Kills) is repositioned to overlay this panel's body.
func _build_run_stats_hud() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Run")
	panel.name = "WireRunStats"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 1, 0, 1, 0, -250.0, 14.0, -14.0, 120.0)

	var btn: Button = Button.new()
	btn.name = "WireReturnButton"
	btn.text = "Return to Hall"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 44)
	btn.z_index = 2
	add_child(btn)
	_place(btn, 1, 0, 1, 0, -164.0, 132.0, -14.0, 176.0)
	btn.pressed.connect(_on_wire_return_pressed)


## Bottom-right: expedition progress (placeholder bar — no clean run % yet).
func _build_progress_panel() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Expedition progress")
	panel.name = "WireProgress"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 1, 1, 1, 1, -300.0, -118.0, -14.0, -14.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 42.0
	body.add_child(bar)
	body.add_child(WireframeKitScript.caption(
		"tick-driven · wireframe placeholder", WireframeKitScript.MUTED, 10))


## Mid-left: live combat event feed (static flavour lines for the wireframe).
func _build_activity_feed_drv() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Event log")
	panel.name = "WireActivityFeed"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 0, 1, 14.0, 244.0, 324.0, -120.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	for line: String in [
		"A blade finds a skeleton in the dark.",
		"A relic clatters out of the floor.",
		"The lantern flares. The party sees clearly.",
		"The party descends to depth 3.",
	]:
		var l: Label = WireframeKitScript.caption("· " + line, WireframeKitScript.MUTED, 12)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(l)


## Bottom-center: the channel-light lantern (idle-clicker target).
func _build_lantern_drv() -> void:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "WireLantern"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	wrap.z_index = 2
	add_child(wrap)
	_place(wrap, 0.5, 1, 0.5, 1, -150.0, -210.0, 150.0, -16.0)

	var cap_top: Label = WireframeKitScript.eyebrow(
		"Channel light · click the lantern", WireframeKitScript.ACCENT)
	cap_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(cap_top)

	var center_row: HBoxContainer = HBoxContainer.new()
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(center_row)
	center_row.add_child(WireframeKitScript.lantern_button(_on_lantern_pressed_drv))

	var note: Label = WireframeKitScript.caption(
		"Wireframe — click feedback only; channel-light economy TBD",
		WireframeKitScript.MUTED, 10)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(note)


func _on_lantern_pressed_drv() -> void:
	if _float_layer == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var animate: bool = not (SceneManager != null and SceneManager.reduce_motion)
	WireframeKitScript.spawn_float(
		_float_layer, "+ light",
		Vector2(vp.x * 0.5 - 28.0 + randf_range(-26.0, 26.0), vp.y - 210.0),
		animate)


func _on_wire_return_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
