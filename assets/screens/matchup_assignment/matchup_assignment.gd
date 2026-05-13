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
## Drift resolution log (Sprint 17 sweep #4 + S17-N2 + S17-N3 closure;
## previously a SWEEP-#3 backlog at scaffold-authoring time):
## - DataRegistry uses `get_all_by_type(content_type)` not `list_category`
##   — GDD updated 2026-05-07 (S17-M5 sweep #4); scaffold already correct.
## - FloorUnlock.is_unlocked_in_biome(biome_id, floor_index) added in
##   Sprint 17 S17-N3 as the V1.0+ multi-biome variant; the 1-arg
##   `is_unlocked(floor_index)` is preserved as the Orchestrator AC-ORC-13
##   contract. GDD §C.3 + §C.4 + §D.1 + §F + AC-23-05 updated to cite
##   the new method name. Scaffold uses `is_unlocked_in_biome` here.
## - FloorUnlock.floor_unlocked(biome_id, floor_index) signal added in
##   Sprint 17 S17-N2; scaffold subscribes per GDD §C.2 + §E.3 + AC-23-15.
##   Re-renders biome tabs on advance (e.g., during offline-replay flush).
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

	# Step 4: subscribe to FloorUnlock.floor_unlocked (R11 — S17-N2 landed
	# the signal). Mid-screen advance (e.g., offline-replay flush) re-renders
	# the affected FloorButton from locked → unlocked per AC-23-15.
	if not FloorUnlock.floor_unlocked.is_connected(_on_floor_unlocked):
		FloorUnlock.floor_unlocked.connect(_on_floor_unlocked)

	# Step 5: button handlers.
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if not _select_button.pressed.is_connected(_on_select_pressed):
		_select_button.pressed.connect(_on_select_pressed)


func on_exit() -> void:
	if FloorUnlock.floor_unlocked.is_connected(_on_floor_unlocked):
		FloorUnlock.floor_unlocked.disconnect(_on_floor_unlocked)
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
		# Biome name label — use the resource's localizable display_name
		# instead of capitalize(id) so "hollow_stair" → "The Hollow Stair".
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = String(biome.display_name) if "display_name" in biome and String(biome.display_name) != "" else biome_id.capitalize()
		biome_tab.add_child(name_label)
		# Sprint 17 — matchup hint: surface the biome's dominant_archetypes
		# so the player can pick a team composition with intent. Format:
		# "Common: armored, caster". Hidden when dominant_archetypes is empty
		# (defensive; no biome currently ships without archetypes).
		var archetypes: Array[String] = []
		if "dominant_archetypes" in biome:
			var raw: Array = biome.get("dominant_archetypes") as Array
			for a: Variant in raw:
				if a is String and String(a) != "":
					archetypes.append(String(a))
		if not archetypes.is_empty():
			var hint_label: Label = Label.new()
			hint_label.name = "MatchupHintLabel"
			hint_label.text = "Common: %s" % ", ".join(archetypes)
			biome_tab.add_child(hint_label)
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
			# Lock-state visual: disabled if not unlocked. Uses the V1.0+
			# multi-biome predicate `is_unlocked_in_biome(biome_id, floor_index)`
			# (S17-N3 — GDD §C.3 step 2).
			floor_button.disabled = not FloorUnlock.is_unlocked_in_biome(biome_id, floor_index)
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
	if FloorUnlock.is_unlocked_in_biome(biome_id, floor_index):
		_select_button.disabled = false
		_select_button.text = tr("matchup_select_format") % [floor_index, biome_id.capitalize()]
	else:
		_select_button.disabled = true
		_select_button.text = "Select (locked)"


# ---------------------------------------------------------------------------
# Interactions — per GDD §C.4 (floor select) / §C.5 (confirm) / §C.6 (back)
# ---------------------------------------------------------------------------

func _on_floor_button_pressed(biome_id: String, floor_index: int) -> void:
	if not FloorUnlock.is_unlocked_in_biome(biome_id, floor_index):
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


# ---------------------------------------------------------------------------
# Signal handler — FloorUnlock.floor_unlocked (R11 — S17-N2)
# ---------------------------------------------------------------------------

## Re-renders biome tabs and re-applies current selection when an unlock
## advance lands while the screen is open (rare; primarily during offline
## replay flush). Per AC-23-15: the affected FloorButton transitions from
## locked → unlocked visual.
##
## Implementation note: the cheap path is a full re-render rather than a
## targeted button-state mutation, because the scaffold rebuilds floor rows
## from scratch in `_render_biome_tabs` (queue_free + re-instantiate). This
## is safe at MVP scale (5 buttons × 1 biome = 5 nodes) and avoids drift
## between the locked/unlocked visual state and the underlying FloorUnlock
## query. The unused params are namespaced via underscore-prefix per the
## "all-floors-of-this-biome are now potentially advanced" simpler model.
func _on_floor_unlocked(_biome_id: String, _floor_index: int) -> void:
	_render_biome_tabs()
	# Re-apply current selection so SelectButton state follows the new
	# unlock predicate (e.g., a previously-locked target is now selectable).
	if _selected_biome_id != "" and _selected_floor_index > 0:
		_select_floor(_selected_biome_id, _selected_floor_index)
