# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the assign -> idle -> return -> escalate loop with class-vs-biome matchup feel satisfying?
# Date: 2026-04-25
extends Control

const TICK_SECONDS: float = 1.0  # 1 real sec = 1 in-game minute
const STARTING_GOLD: int = 25
const RECRUIT_BASE_COST: int = 10
const RECRUIT_GROWTH: float = 1.5
const FORMATION_SLOTS: int = 3
const FLOOR_CLEAR_GOAL: int = 100  # progress points to clear a floor

# Class identity. Color is the silhouette stand-in (no pixel art in prototype).
enum HeroClass { KNIGHT, MAGE, ROGUE }
enum EnemyType { BRUTE, CASTER, BEAST }

const CLASS_NAMES := { HeroClass.KNIGHT: "Knight", HeroClass.MAGE: "Mage", HeroClass.ROGUE: "Rogue" }
const CLASS_COLORS := {
	HeroClass.KNIGHT: Color(0.85, 0.75, 0.45),  # warm gold
	HeroClass.MAGE: Color(0.55, 0.40, 0.80),    # dusk purple
	HeroClass.ROGUE: Color(0.80, 0.45, 0.30),   # ember orange
}
const ENEMY_NAMES := { EnemyType.BRUTE: "Brute", EnemyType.CASTER: "Caster", EnemyType.BEAST: "Beast" }

# Matchup table: rock-paper-scissors counters.
# Knight beats Beast, Mage beats Brute, Rogue beats Caster.
const MATCHUP := {
	HeroClass.KNIGHT: { EnemyType.BRUTE: 1.0, EnemyType.CASTER: 0.5, EnemyType.BEAST: 2.0 },
	HeroClass.MAGE:   { EnemyType.BRUTE: 2.0, EnemyType.CASTER: 1.0, EnemyType.BEAST: 0.5 },
	HeroClass.ROGUE:  { EnemyType.BRUTE: 0.5, EnemyType.CASTER: 2.0, EnemyType.BEAST: 1.0 },
}

# Each floor's primary enemy mix. 70/20/10 weighted toward primary.
const FLOORS := [
	{ "name": "Floor 1: Goblin Quarry",   "primary": EnemyType.BRUTE,  "favors": HeroClass.MAGE },
	{ "name": "Floor 2: Sunken Library",  "primary": EnemyType.CASTER, "favors": HeroClass.ROGUE },
	{ "name": "Floor 3: Wolf Hollow",     "primary": EnemyType.BEAST,  "favors": HeroClass.KNIGHT },
	{ "name": "Floor 4: Ember Garrison",  "primary": EnemyType.BRUTE,  "favors": HeroClass.MAGE },
	{ "name": "Floor 5: Star Sanctum",    "primary": EnemyType.CASTER, "favors": HeroClass.ROGUE },
]

# Game state
var gold: int = STARTING_GOLD
var roster: Array[Dictionary] = []  # [{ "class": HeroClass, "level": 1 }]
var formation: Array[int] = []      # roster indices, max FORMATION_SLOTS
var current_floor: int = 0
var floor_progress: float = 0.0
var pending_loot: float = 0.0
var elapsed_minutes: int = 0
var session_started_at: float = 0.0

# Instrumentation counters (printed at end / on demand)
var collect_count: int = 0
var formation_changes: int = 0
var _floor_announced: bool = false
var time_to_first_recruit_min: int = -1
var time_to_first_clear_min: int = -1
var first_collect_min: int = -1

@onready var lbl_gold: Label = %LblGold
@onready var lbl_time: Label = %LblTime
@onready var lbl_floor: Label = %LblFloor
@onready var lbl_floor_favors: Label = %LblFloorFavors
@onready var lbl_pending: Label = %LblPending
@onready var lbl_rate: Label = %LblRate
@onready var bar_floor: ProgressBar = %BarFloor
@onready var roster_box: VBoxContainer = %RosterBox
@onready var formation_box: HBoxContainer = %FormationBox
@onready var recruit_box: HBoxContainer = %RecruitBox
@onready var btn_collect: Button = %BtnCollect
@onready var btn_next_floor: Button = %BtnNextFloor
@onready var btn_close_app: Button = %BtnCloseApp
@onready var lbl_event_log: RichTextLabel = %LblEventLog
@onready var tick_timer: Timer = %TickTimer


func _ready() -> void:
	session_started_at = Time.get_ticks_msec() / 1000.0
	tick_timer.wait_time = TICK_SECONDS
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()
	btn_collect.pressed.connect(_on_collect)
	btn_next_floor.pressed.connect(_on_next_floor)
	btn_close_app.pressed.connect(_on_close_app)
	_log("Welcome. Recruit a hero, slot them into formation, and start the run.")
	_log("Tip: each floor favors a different class — check the [Favors] line.")
	_rebuild_recruit_buttons()
	_rebuild_roster()
	_rebuild_formation()
	_refresh_hud()


func _on_tick() -> void:
	elapsed_minutes += 1
	if formation.size() == 0:
		_refresh_hud()
		_rebuild_recruit_buttons()
		_rebuild_roster()
		return
	var rate := _current_rate()
	pending_loot += rate
	floor_progress += rate * 0.5
	if floor_progress >= FLOOR_CLEAR_GOAL and current_floor < FLOORS.size() - 1 and not _floor_announced:
		_log("✦ Cleared %s — next floor unlocked." % FLOORS[current_floor].name)
		if time_to_first_clear_min == -1:
			time_to_first_clear_min = elapsed_minutes
		btn_next_floor.disabled = false
		_floor_announced = true
	_refresh_hud()
	_rebuild_recruit_buttons()
	_rebuild_roster()


func _current_rate() -> float:
	# Loot/min = sum_over_formation(level * matchup_against_primary) * (1 + 0.25 * floor_index)
	if formation.size() == 0:
		return 0.0
	var primary: int = FLOORS[current_floor].primary
	var sum := 0.0
	for idx in formation:
		var hero: Dictionary = roster[idx]
		var mult: float = MATCHUP[hero.cls][primary]
		sum += float(hero.level) * mult
	var floor_bonus := 1.0 + 0.25 * float(current_floor)
	return sum * floor_bonus


func _on_collect() -> void:
	if pending_loot < 1.0:
		return
	var amount: int = int(floor(pending_loot))
	gold += amount
	pending_loot -= float(amount)
	collect_count += 1
	if first_collect_min == -1:
		first_collect_min = elapsed_minutes
	_log("+%d gold collected." % amount)
	_refresh_hud()
	_rebuild_recruit_buttons()
	_rebuild_roster()


func _on_next_floor() -> void:
	if floor_progress < FLOOR_CLEAR_GOAL or current_floor >= FLOORS.size() - 1:
		return
	current_floor += 1
	floor_progress = 0.0
	btn_next_floor.disabled = true
	_floor_announced = false
	_log("→ Descending to %s. Primary: %s. Favors: %s." % [
		FLOORS[current_floor].name,
		ENEMY_NAMES[FLOORS[current_floor].primary],
		CLASS_NAMES[FLOORS[current_floor].favors],
	])
	_refresh_hud()
	_rebuild_formation()
	_rebuild_recruit_buttons()
	_rebuild_roster()


func _on_close_app() -> void:
	# Simulate "close app + come back later." Awards 30 in-game minutes of accumulation
	# then prompts the player to collect. Tests the return-to-app moment.
	var minutes_offline: int = 30
	var rate := _current_rate()
	var offline_loot := rate * minutes_offline
	pending_loot += offline_loot
	floor_progress += offline_loot * 0.5
	elapsed_minutes += minutes_offline
	if floor_progress >= FLOOR_CLEAR_GOAL and current_floor < FLOORS.size() - 1 and not _floor_announced:
		btn_next_floor.disabled = false
		_floor_announced = true
	_log("─── You closed the app and returned 30 minutes later ───")
	_log("Welcome back. While you were away: +%d gold pending." % int(offline_loot))
	_refresh_hud()
	_rebuild_recruit_buttons()
	_rebuild_roster()


# --- Roster / formation / recruit ---

func _recruit(hero_class: int) -> void:
	var cost := _recruit_cost()
	if gold < cost:
		return
	gold -= cost
	roster.append({ "cls": hero_class, "level": 1 })
	if time_to_first_recruit_min == -1:
		time_to_first_recruit_min = elapsed_minutes
	# Auto-fill empty formation slot with newly recruited hero
	if formation.size() < FORMATION_SLOTS:
		formation.append(roster.size() - 1)
	_log("Recruited %s (lvl 1) for %d gold." % [CLASS_NAMES[hero_class], cost])
	_rebuild_recruit_buttons()
	_rebuild_roster()
	_rebuild_formation()
	_refresh_hud()


func _recruit_cost() -> int:
	return int(round(RECRUIT_BASE_COST * pow(RECRUIT_GROWTH, roster.size())))


func _level_up(roster_idx: int) -> void:
	var hero: Dictionary = roster[roster_idx]
	var cost: int = 5 * int(pow(2, hero.level - 1))
	if gold < cost:
		return
	gold -= cost
	hero.level += 1
	_log("Leveled %s to lvl %d for %d gold." % [CLASS_NAMES[hero.cls], hero.level, cost])
	_rebuild_roster()
	_refresh_hud()


func _toggle_formation(roster_idx: int) -> void:
	formation_changes += 1
	if formation.has(roster_idx):
		formation.erase(roster_idx)
	elif formation.size() < FORMATION_SLOTS:
		formation.append(roster_idx)
	else:
		# Replace oldest
		formation.pop_front()
		formation.append(roster_idx)
	_rebuild_roster()
	_rebuild_formation()
	_refresh_hud()


# --- HUD rebuild ---

func _refresh_hud() -> void:
	lbl_gold.text = "Gold: %d" % gold
	lbl_time.text = "Elapsed: %d min" % elapsed_minutes
	var f: Dictionary = FLOORS[current_floor]
	lbl_floor.text = "%s — primary: %s" % [f.name, ENEMY_NAMES[f.primary]]
	lbl_floor_favors.text = "Favors: %s" % CLASS_NAMES[f.favors]
	lbl_pending.text = "Pending loot: %d" % int(floor(pending_loot))
	lbl_rate.text = "Rate: %.2f gold/min" % _current_rate()
	bar_floor.value = clamp(floor_progress / FLOOR_CLEAR_GOAL * 100.0, 0.0, 100.0)
	btn_collect.disabled = pending_loot < 1.0
	if current_floor >= FLOORS.size() - 1:
		btn_next_floor.text = "Final floor"
		btn_next_floor.disabled = true


func _rebuild_recruit_buttons() -> void:
	for c in recruit_box.get_children():
		c.queue_free()
	var cost := _recruit_cost()
	for cls in [HeroClass.KNIGHT, HeroClass.MAGE, HeroClass.ROGUE]:
		var btn := Button.new()
		btn.text = "Recruit %s\n(%d gold)" % [CLASS_NAMES[cls], cost]
		btn.custom_minimum_size = Vector2(160, 56)
		btn.add_theme_color_override("font_color", CLASS_COLORS[cls])
		btn.disabled = gold < cost
		btn.pressed.connect(_recruit.bind(cls))
		recruit_box.add_child(btn)


func _rebuild_roster() -> void:
	for c in roster_box.get_children():
		c.queue_free()
	if roster.is_empty():
		var hint := Label.new()
		hint.text = "(roster empty — recruit below)"
		hint.modulate = Color(0.7, 0.7, 0.7)
		roster_box.add_child(hint)
		return
	for i in range(roster.size()):
		var hero: Dictionary = roster[i]
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = CLASS_COLORS[hero.cls]
		swatch.custom_minimum_size = Vector2(28, 28)
		row.add_child(swatch)
		var lbl := Label.new()
		var in_form := " [active]" if formation.has(i) else ""
		lbl.text = "%s lvl %d%s" % [CLASS_NAMES[hero.cls], hero.level, in_form]
		lbl.custom_minimum_size = Vector2(180, 28)
		row.add_child(lbl)
		var toggle := Button.new()
		toggle.text = "Drop" if formation.has(i) else "Slot"
		toggle.pressed.connect(_toggle_formation.bind(i))
		row.add_child(toggle)
		var lvl_btn := Button.new()
		var lvl_cost: int = 5 * int(pow(2, hero.level - 1))
		lvl_btn.text = "Lvl up (%d)" % lvl_cost
		lvl_btn.disabled = gold < lvl_cost
		lvl_btn.pressed.connect(_level_up.bind(i))
		row.add_child(lvl_btn)
		roster_box.add_child(row)


func _rebuild_formation() -> void:
	for c in formation_box.get_children():
		c.queue_free()
	for slot_idx in range(FORMATION_SLOTS):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(120, 140)
		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(inner)
		if slot_idx < formation.size():
			var hero: Dictionary = roster[formation[slot_idx]]
			var swatch := ColorRect.new()
			swatch.color = CLASS_COLORS[hero.cls]
			swatch.custom_minimum_size = Vector2(80, 80)
			swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			inner.add_child(swatch)
			var lbl := Label.new()
			lbl.text = "%s lvl %d" % [CLASS_NAMES[hero.cls], hero.level]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(lbl)
			# Show matchup vs current floor
			var primary: int = FLOORS[current_floor].primary
			var mult: float = MATCHUP[hero.cls][primary]
			var match_lbl := Label.new()
			match_lbl.text = "vs %s: ×%.1f" % [ENEMY_NAMES[primary], mult]
			match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			match_lbl.modulate = Color(1.0, 0.85, 0.55) if mult >= 1.5 else (Color(0.9, 0.5, 0.5) if mult <= 0.6 else Color(0.85, 0.85, 0.85))
			inner.add_child(match_lbl)
		else:
			var empty := Label.new()
			empty.text = "(empty slot)"
			empty.modulate = Color(0.55, 0.55, 0.55)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(empty)
		formation_box.add_child(panel)


func _log(msg: String) -> void:
	var t := "[%d min] " % elapsed_minutes
	lbl_event_log.add_text(t + msg + "\n")


func _exit_tree() -> void:
	_print_metrics()


func _print_metrics() -> void:
	var session_seconds: float = (Time.get_ticks_msec() / 1000.0) - session_started_at
	print("=== PROTOTYPE METRICS ===")
	print("Session length (real sec): %.1f" % session_seconds)
	print("Elapsed in-game minutes: %d" % elapsed_minutes)
	print("Roster size: %d" % roster.size())
	print("Final gold: %d" % gold)
	print("Floor reached: %d (%s)" % [current_floor + 1, FLOORS[current_floor].name])
	print("Collect taps: %d" % collect_count)
	print("Formation changes: %d" % formation_changes)
	print("Time to first recruit (min): %d" % time_to_first_recruit_min)
	print("Time to first collect (min): %d" % first_collect_min)
	print("Time to first floor clear (min): %d" % time_to_first_clear_min)
