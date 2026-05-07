## Matchup Assignment Screen — biome+floor selector that opens from
## formation_assignment's FloorButton.
##
## Sprint 16 S16-M3 candidate scaffold (pre-emptively authored 2026-05-07
## per the established cadence). Ships the contract layer + minimal .tscn
## layout per Matchup Assignment Screen GDD #23 §C.1 / §C.2 / §C.3 / §C.4
## / §C.5 / §C.6. Visual polish (anchors + theme variations + biome icon
## sourcing + EnemyDistributionList per-row layout + matchup-hint locale
## strings) deferred to post-`/design-review` of GDD #23.
##
## Drift notes from cross-GDD sweep iterations (THIRD iteration —
## these surfaced during S16-M3 scaffold authoring):
## - DataRegistry uses `get_all_by_type(content_type)` not `list_category`
##   — GDD §C.2 + §F mention list_category which doesn't exist; using
##   the correct API.
## - FloorUnlock.is_unlocked is SINGLE-ARG `is_unlocked(floor_index)`
##   — GDD §C.3 + §C.4 + §D.1 + §F + AC-23-05/06/15 claim
##   `is_unlocked(biome_id, floor_index)` (2-arg). The single-arg form
##   uses an implicit active biome (single-biome MVP per GDD §C.8).
##   Using single-arg form here; flag for sweep iteration to fix the GDD.
## - FloorUnlock has NO `floor_unlocked` signal — GDD §C.2 + §E.3 +
##   AC-23-15 claim subscription. The signal doesn't exist; the screen
##   re-renders on next on_enter instead. Sweep iteration item.
## - FormationAssignment.set_target / get_target shipped in S15-N1 (✓);
##   the screen pushes selection back via set_target on Select press.
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


# Initial selection (set by caller BEFORE show_modal / request_screen).
# Empty string / 0 means "no prior selection — render with first unlocked
# floor highlighted" per GDD §C.7 fallback.
var _initial_biome_id: String = ""
var _initial_floor_index: int = 0

# Currently-selected target. Set by FloorButton press; pushed to
# FormationAssignment.set_target on SelectButton press.
var _selected_biome_id: String = ""
var _selected_floor_index: int = 0


@onready var _back_button: Button = $HeaderBar/HeaderHBox/BackButton
@onready var _select_button: Button = $FooterBar/SelectButton
@onready var _biome_panel: PanelContainer = $BiomePanel


# Cached resolution state — built in on_enter from DataRegistry.
var _biomes: Array[Resource] = []
var _floors_by_biome: Dictionary = {}  # biome_id (String) → Array[Resource] sorted by floor_index


# ---------------------------------------------------------------------------
# Public API — set_initial_selection (per GDD §C.2 step 2)
# ---------------------------------------------------------------------------

## Sets the initial selection rendered on entry. Caller MUST call this
## BEFORE SceneManager.request_screen("matchup_assignment", ...) so
## on_enter renders with the prior selection highlighted per GDD §C.7.
##
## Empty biome_id / floor_index <= 0 → fallback to first unlocked floor.
func set_initial_selection(biome_id: String, floor_index: int) -> void:
	_initial_biome_id = biome_id
	_initial_floor_index = floor_index


# ---------------------------------------------------------------------------
# Screen lifecycle (per GDD §C.2)
# ---------------------------------------------------------------------------

func _ready() -> void:
	UIFrameworkScript.wire_touch_feedback(_back_button)
	UIFrameworkScript.wire_touch_feedback(_select_button)


func on_enter() -> void:
	# Step 1: resolve all biomes + floors via DataRegistry (correct API
	# is get_all_by_type, NOT list_category — GDD inline-noted drift).
	_biomes = DataRegistry.get_all_by_type("biomes")
	# Sort biomes alphabetically by id (deterministic — GDD §C.2 step 1).
	_biomes.sort_custom(func(a: Resource, b: Resource) -> bool:
		return String(a.id) < String(b.id)
	)
	# Build floor-by-biome map. Per Dungeon resource shape (dungeon.gd
	# line 62: `floors: Array[Floor]`), each Dungeon contains multiple
	# Floor sub-resources. We flatten dungeons → floors per biome here.
	# (GDD §C.2 step 2.b's per-dungeon-equals-single-floor model was
	# wrong — captured as sweep iteration #3 drift; using actual data
	# shape.)
	_floors_by_biome = {}
	var all_dungeons: Array[Resource] = DataRegistry.get_all_by_type("dungeons")
	for biome: Resource in _biomes:
		var biome_id: String = String(biome.id)
		_floors_by_biome[biome_id] = []
		for dungeon: Resource in all_dungeons:
			if String(dungeon.biome_id) == biome_id:
				# Flatten dungeon.floors → biome's floor list.
				var dungeon_floors: Array = dungeon.floors as Array
				for floor_data: Resource in dungeon_floors:
					_floors_by_biome[biome_id].append(floor_data)
		# Sort floors by floor_index ascending.
		(_floors_by_biome[biome_id] as Array).sort_custom(func(a: Resource, b: Resource) -> bool:
			return int(a.floor_index) < int(b.floor_index)
		)

	# Step 2: render biome tabs (single tab in MVP — forest_reach only).
	_render_biome_tabs()

	# Step 3: apply initial selection (or fallback to first unlocked).
	_apply_initial_selection()

	# Step 4: signal subscriptions deferred — GDD §C.2 cites
	# FloorUnlock.floor_unlocked which doesn't exist (sweep iteration #3
	# drift). Mid-screen unlock-state updates require either polling OR
	# the signal landing in Sprint 17+. For MVP single-biome scope,
	# unlock-state is stable during a screen visit.

	# Step 5: button handlers.
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if not _select_button.pressed.is_connected(_on_select_pressed):
		_select_button.pressed.connect(_on_select_pressed)


func on_exit() -> void:
	if _back_button != null and _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)
	if _select_button != null and _select_button.pressed.is_connected(_on_select_pressed):
		_select_button.pressed.disconnect(_on_select_pressed)


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render — biome tabs + floor buttons (per GDD §C.3 / §C.4)
# ---------------------------------------------------------------------------

func _render_biome_tabs() -> void:
	# Scaffold: minimal render — clear existing children, instantiate
	# one BiomeTab HBoxContainer per biome with FloorButtons inside. Full
	# layout polish (BiomeIcon TextureRect + BiomeNameLabel + matchup hint)
	# deferred to post-/design-review.
	var pool_vbox: VBoxContainer = _biome_panel.get_node_or_null("BiomeVBox") as VBoxContainer
	if pool_vbox == null:
		return
	# Clear existing biome tabs (idempotent re-entry).
	for child: Node in pool_vbox.get_children():
		child.queue_free()
	# Per-biome tabs.
	for biome: Resource in _biomes:
		var biome_id: String = String(biome.id)
		var biome_tab: VBoxContainer = VBoxContainer.new()
		biome_tab.name = "BiomeTab_%s" % biome_id
		pool_vbox.add_child(biome_tab)
		# Biome name label (placeholder; full BiomeIcon + matchup hint
		# deferred per visual-polish carve-out).
		var name_label: Label = Label.new()
		name_label.text = biome_id.capitalize()
		biome_tab.add_child(name_label)
		# Floor row.
		var floor_row: HBoxContainer = HBoxContainer.new()
		floor_row.name = "FloorRow"
		biome_tab.add_child(floor_row)
		# 5 FloorButtons (or however many floors exist).
		var floors: Array = _floors_by_biome.get(biome_id, [])
		for floor_data: Resource in floors:
			var floor_index: int = int(floor_data.floor_index)
			var floor_button: Button = Button.new()
			floor_button.name = "FloorButton_%d" % floor_index
			floor_button.text = "F%d" % floor_index
			floor_button.custom_minimum_size = Vector2(60, 60)
			floor_button.focus_mode = Control.FOCUS_NONE
			floor_button.mouse_filter = Control.MOUSE_FILTER_STOP
			# Lock-state visual: disabled if not unlocked. Per drift note in
			# header doc, FloorUnlock.is_unlocked is single-arg (implicit
			# active biome — single-biome MVP per GDD §C.8). The biome_id
			# arg is captured for the future 2-arg API when V1.0+ multi-
			# biome lands.
			floor_button.disabled = not FloorUnlock.is_unlocked(floor_index)
			# Bind handler with biome_id + floor_index.
			floor_button.pressed.connect(
				_on_floor_button_pressed.bind(biome_id, floor_index)
			)
			UIFrameworkScript.wire_touch_feedback(floor_button)
			floor_row.add_child(floor_button)


func _apply_initial_selection() -> void:
	# Determine the initial selection target.
	var target_biome: String = _initial_biome_id
	var target_floor: int = _initial_floor_index
	# Fallback: if no initial selection OR target floor locked, find the
	# first unlocked floor in the first biome.
	if target_biome == "" or target_floor <= 0:
		if _biomes.size() > 0:
			target_biome = String(_biomes[0].id)
			target_floor = 1  # Floor 1 is always unlocked per FloorUnlock §C
	if target_biome != "" and target_floor > 0:
		_select_floor(target_biome, target_floor)
	else:
		# No biomes available — defensive empty-state per GDD §E.7.
		_select_button.disabled = true
		_select_button.text = "No biomes available"


# Update internal selection state + refresh SelectButton.
func _select_floor(biome_id: String, floor_index: int) -> void:
	_selected_biome_id = biome_id
	_selected_floor_index = floor_index
	# Single-arg is_unlocked per drift note in header doc.
	if FloorUnlock.is_unlocked(floor_index):
		_select_button.disabled = false
		_select_button.text = tr("matchup_select_format") % [floor_index, biome_id.capitalize()]
	else:
		_select_button.disabled = true
		_select_button.text = "Select (locked)"


# ---------------------------------------------------------------------------
# Interactions — per GDD §C.4 (floor select) / §C.5 (confirm) / §C.6 (back)
# ---------------------------------------------------------------------------

func _on_floor_button_pressed(biome_id: String, floor_index: int) -> void:
	# Single-arg is_unlocked per drift note in header doc.
	if not FloorUnlock.is_unlocked(floor_index):
		# Toast: tr("matchup_floor_locked_format") with prior unlocked
		# floor index (per §C.4 step 1). Scaffold uses push_warning.
		push_warning(
			"[MatchupAssignmentScreen] toast: %s"
			% (tr("matchup_floor_locked_format") % (floor_index - 1))
		)
		return
	_select_floor(biome_id, floor_index)


func _on_select_pressed() -> void:
	if _selected_biome_id == "" or _selected_floor_index <= 0:
		push_warning("[MatchupAssignmentScreen] select press with no valid selection — defensive")
		return
	# Push selection back via FormationAssignment.set_target (S15-N1).
	FormationAssignment.set_target(_selected_biome_id, _selected_floor_index)
	# Navigate back to formation_assignment.
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)


func _on_back_pressed() -> void:
	# Back without confirming selection — formation_assignment retains
	# its prior target (set_target NOT called).
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)


# Signal handlers deferred — FloorUnlock.floor_unlocked signal doesn't
# exist in the current codebase (drift note in header doc). When the
# signal lands in Sprint 17+ multi-biome work, _on_floor_unlocked
# handler can be added that re-renders biome tabs + re-applies
# current selection.
