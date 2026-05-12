## Victory Moment Screen — foreground floor-clear celebration screen
## between dungeon_run_view RUN_ENDED and guild_hall.
##
## Sprint 16 S16-S1 candidate scaffold (pre-emptively authored 2026-05-07
## per the established cadence). Ships the contract layer + minimal .tscn
## layout per Unlock / Victory Moment GDD #25 §C.1 / §C.2 / §C.3 / §C.4
## / §C.5 / §C.7. Visual polish (anchors + theme variations + portrait
## sourcing + DimBackdrop fade-in + ContinuationPrompt pulse + staggered
## reveal animations) deferred to post-`/design-review` of GDD #25.
##
## Foreground-only invariant per GDD §C.7: this screen is entered ONLY
## via dungeon_run_view's RUN_ENDED handler. Offline replay floor-clears
## do NOT trigger this screen — Return-to-App Screen #20 handles offline
## aggregation (otherwise a 4-hour offline session would stack 12+
## celebrations).
##
## Floor Unlock §C.1 R5 LOCK honored: identical fanfare WIN/LOSING. The
## losing_run field is read but does NOT branch any visual or audio
## logic.
##
## Foreground entry replaces the Sprint-9 hard-coded
## request_screen("main_menu", CROSS_FADE) route at
## dungeon_run_view.gd:308 when implementation lands. This scaffold
## DOES NOT change the dungeon_run_view route — that's a separate
## one-line change deferred to post-/design-review polish.
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

# Pacing constants per GDD §G.
const TAP_GRACE_MS: int = 200
const CONTINUATION_DWELL_MS: int = 1500


# Captured render data — populated in on_enter from DungeonRunOrchestrator
# + Economy + HeroRoster + FloorUnlock.
var _floor_index: int = 0
var _biome_id: String = ""
var _kill_count: int = 0
var _gold_delta: int = 0
var _is_new_high_clear: bool = false
var _is_biome_completed: bool = false  # Floor 5 boss-floor completion
# Per-hero level deltas: Array of {display_name, terminal_level} dicts
# (terminal-only render per GDD §C.10 + §I OQ-25-2 resolution).
var _hero_level_deltas: Array = []

# Tap-debounce grace from on_enter (per GDD §C.9).
var _enter_time_msec: int = 0


@onready var _dim_backdrop: ColorRect = $DimBackdrop
## Reserved for Sprint 17 S17-S2 visual polish — staggered reveal
## animation queries the center panel for size/position to drive
## tween targets. Read deferred until that work lands.
@warning_ignore("unused_private_class_variable")
@onready var _center_panel: PanelContainer = $CenterPanel
@onready var _headline_label: Label = $CenterPanel/CenterVBox/HeadlineLabel
@onready var _unlock_notice_label: Label = $CenterPanel/CenterVBox/UnlockNoticeLabel
@onready var _kill_count_value: Label = $CenterPanel/CenterVBox/StatsBlock/KillCountRow/KillCountValue
@onready var _gold_gained_value: Label = $CenterPanel/CenterVBox/StatsBlock/GoldGainedRow/GoldGainedValue
@onready var _level_ups_block: VBoxContainer = $CenterPanel/CenterVBox/StatsBlock/LevelUpsBlock
@onready var _continuation_prompt: Label = $CenterPanel/CenterVBox/ContinuationPromptLabel


# ---------------------------------------------------------------------------
# Screen lifecycle (per GDD §C.2)
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass  # No buttons in MVP — tap-anywhere via DimBackdrop input handler.


func on_enter() -> void:
	_enter_time_msec = Time.get_ticks_msec()

	# Defensive _replay_in_flight invariant guard per GDD §C.7 + AC-25-15
	# + §E.12. Foreground-only — if invariant violated, route to guild_hall.
	if OfflineProgressionEngine.is_replay_in_flight():
		push_warning(
			"[VictoryMoment] entered during offline replay — invariant"
			+ " violation; routing to guild_hall"
		)
		SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
		return

	# Capture run_snapshot data from DungeonRunOrchestrator.
	var snapshot: RunSnapshot = DungeonRunOrchestrator.run_snapshot
	if snapshot == null:
		push_warning(
			"[VictoryMoment] entered with null run_snapshot — defensive"
			+ " route to guild_hall"
		)
		SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
		return

	_kill_count = snapshot.kill_count
	# Parse floor_index + biome_id from run_snapshot.floor_id rather than
	# DungeonRunOrchestrator._dispatched_*, which _exit_active_foreground
	# resets at the ACTIVE_FOREGROUND → RUN_ENDED transition (per the
	# documented field contract at orchestrator.gd:249/:253). The snapshot
	# survives the transition; floor_id format is "{biome_id}_floor_{N}".
	var floor_id: String = snapshot.floor_id
	_floor_index = 0
	_biome_id = ""
	var sep: int = floor_id.rfind("_floor_")
	if sep != -1:
		_biome_id = floor_id.substr(0, sep)
		var idx_str: String = floor_id.substr(sep + 7)  # 7 = len("_floor_")
		if idx_str.is_valid_int():
			_floor_index = int(idx_str)

	# Gold delta via run_snapshot.pre_dispatch_gold (S15-S4 ✓).
	_gold_delta = Economy.get_gold_balance() - snapshot.pre_dispatch_gold

	# Classify new-high vs re-clear via FloorUnlock.get_highest_cleared.
	# A new-high clear means the run advanced the high water mark to
	# this floor — `highest_cleared == floor_index` after Floor Unlock
	# processed the floor_cleared_first_time signal. If
	# floor_index < highest_cleared, the player already cleared a higher
	# floor previously → re-clear path (UnlockNotice hidden per GDD §C.3).
	if _biome_id != "":
		var highest: int = FloorUnlock.get_highest_cleared(_biome_id)
		_is_new_high_clear = (highest == _floor_index and _floor_index >= 1)
		_is_biome_completed = (_floor_index >= 5)

	# Per-hero level deltas (terminal-only render per GDD §C.10).
	_hero_level_deltas = _compute_hero_level_deltas(snapshot)

	# Render all panels.
	_render_all()

	# Tap-to-continue: root-level handler catches taps that CenterPanel would
	# otherwise consume; DimBackdrop handler retained for tests that fire
	# input directly at it.
	if not gui_input.is_connected(_on_backdrop_input):
		gui_input.connect(_on_backdrop_input)
	if not _dim_backdrop.gui_input.is_connected(_on_backdrop_input):
		_dim_backdrop.gui_input.connect(_on_backdrop_input)

	# Schedule the ContinuationPrompt reveal after CONTINUATION_DWELL_MS.
	_continuation_prompt.visible = false
	if get_tree() != null:
		get_tree().create_timer(CONTINUATION_DWELL_MS / 1000.0).timeout.connect(
			_on_continuation_dwell_elapsed,
			CONNECT_ONE_SHOT
		)


func on_exit() -> void:
	if gui_input.is_connected(_on_backdrop_input):
		gui_input.disconnect(_on_backdrop_input)
	if _dim_backdrop != null and _dim_backdrop.gui_input.is_connected(_on_backdrop_input):
		_dim_backdrop.gui_input.disconnect(_on_backdrop_input)


func on_pause() -> void:
	pass  # Modal not pausable per GDD §C.2.


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render — headline / unlock notice / stats / level-ups (per GDD §C.3 / §C.4)
# ---------------------------------------------------------------------------

func _render_all() -> void:
	_render_headline()
	_render_unlock_notice()
	_render_stats()
	_render_level_ups()


func _render_headline() -> void:
	var biome_name: String = _resolve_biome_display_name()
	_headline_label.text = tr("victory_headline_format") % [biome_name, _floor_index]


func _render_unlock_notice() -> void:
	if not _is_new_high_clear:
		# Re-clear path: hide unlock notice (cozy quieter confirmation).
		_unlock_notice_label.visible = false
		return
	_unlock_notice_label.visible = true
	if _is_biome_completed:
		# Floor 5 boss clear → biome completion message.
		var biome_name: String = _resolve_biome_display_name()
		_unlock_notice_label.text = tr("victory_biome_completed_format") % biome_name
	else:
		# Standard new-high message: next floor now available.
		_unlock_notice_label.text = tr("victory_unlock_format") % (_floor_index + 1)


func _render_stats() -> void:
	_kill_count_value.text = "%d" % _kill_count
	if _gold_delta > 0:
		# Sprint 17 S17-S5: short-number format for large gold deltas
		# per cozy-display thresholds (e.g., +12.5K instead of +12500).
		# The locale format string "victory_gold_gained_format" expects
		# %d so we pass the raw int — short-number formatting kicks in
		# at the locale-string layer in V1.0+ when locale strings are
		# updated to %s. MVP keeps %d for backward compat with the
		# preliminary locale seed (commit 1ad8416).
		_gold_gained_value.text = tr("victory_gold_gained_format") % _gold_delta
	else:
		# Defensive — runs only credit gold in MVP; a 0-delta run is
		# possible if no gold-crediting kills occurred.
		_gold_gained_value.text = "0 gold"


func _render_level_ups() -> void:
	for child: Node in _level_ups_block.get_children():
		child.queue_free()
	if _hero_level_deltas.is_empty():
		_level_ups_block.visible = false
		return
	_level_ups_block.visible = true
	# One row per hero who leveled up — terminal level only per GDD §C.10
	# + §I OQ-25-2 resolution.
	for entry: Dictionary in _hero_level_deltas:
		var row: Label = Label.new()
		var display_name: String = String(entry.get("display_name", ""))
		var terminal_level: int = int(entry.get("terminal_level", 0))
		row.text = tr("victory_level_up_format") % [display_name, terminal_level]
		_level_ups_block.add_child(row)


# ---------------------------------------------------------------------------
# Continuation interaction (per GDD §C.5 / §C.9)
# ---------------------------------------------------------------------------

func _on_backdrop_input(event: InputEvent) -> void:
	# Tap-grace: ignore taps in first TAP_GRACE_MS post-on_enter.
	if Time.get_ticks_msec() - _enter_time_msec < TAP_GRACE_MS:
		return
	var is_mouse_press: bool = event is InputEventMouseButton and event.pressed
	var is_touch_press: bool = event is InputEventScreenTouch and event.pressed
	if is_mouse_press or is_touch_press:
		_continue_to_guild_hall()


func _on_continuation_dwell_elapsed() -> void:
	_continuation_prompt.visible = true


func _continue_to_guild_hall() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Resolve biome display name via DataRegistry; fallback to capitalized
# biome_id for orphan / missing-resource scenarios.
func _resolve_biome_display_name() -> String:
	if _biome_id == "":
		return ""
	var biome: Resource = DataRegistry.resolve("biomes", _biome_id)
	if biome != null and "display_name_key" in biome:
		var key: String = String(biome.display_name_key)
		if key != "":
			return tr(key)
	return _biome_id.capitalize().replace("_", " ")


# Compute per-hero level deltas from run_snapshot.formation_snapshot.heroes
# (pre-dispatch level captured per ADR-0014 §B4) vs HeroRoster's current
# state. Terminal-only render per GDD §C.10. Returns Array of Dictionary
# {display_name, terminal_level}.
func _compute_hero_level_deltas(snapshot: RunSnapshot) -> Array:
	var deltas: Array = []
	if snapshot == null:
		return deltas
	var fs: Dictionary = snapshot.formation_snapshot
	var pre_heroes: Variant = fs.get("heroes", [])
	if not (pre_heroes is Array):
		return deltas
	for pre_hero: Variant in pre_heroes:
		if not (pre_hero is Dictionary):
			continue
		var instance_id: int = int(pre_hero.get("instance_id", 0))
		var pre_level: int = int(pre_hero.get("current_level", 0))
		if instance_id == 0:
			continue
		# Resolve current level from live HeroRoster.
		if not HeroRoster._heroes.has(instance_id):
			continue  # Hero removed mid-run (V1.0+ retire UI scenario)
		var current_hero: RefCounted = HeroRoster._heroes[instance_id]
		var current_level: int = current_hero.current_level
		if current_level > pre_level:
			deltas.append({
				"display_name": String(current_hero.display_name),
				"terminal_level": current_level,
			})
	return deltas
