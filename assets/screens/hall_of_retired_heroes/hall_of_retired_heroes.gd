## Hall of Retired Heroes — read-only screen showing every prestiged hero
## as a card, with the global prestige multiplier as the header badge.
##
## Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B). Per
## `design/gdd/prestige-system.md` §C.4 + §F + AC-PR-13. Card metadata
## format ties to the writer-locked `hall_card_metadata_format` locale key.
##
## Lifecycle:
##   1. Player taps the Hall button on Guild Hall
##   2. SceneManager.request_screen("hall_of_retired_heroes")
##   3. on_enter reads HeroRoster.get_retired_hero_records() + populates
##      cards into the ScrollContainer; subscribes to
##      prestige_completed_signal so a new prestige (which can only happen
##      from the Hero Detail Modal — different screen — but defensive)
##      auto-rebuilds the list
##   4. Player taps Back → SceneManager.request_screen("guild_hall")
##
## Empty-state: if records.size() == 0 (defensive — Guild Hall hides the
## entry button when empty), render the title + ×1.00 multiplier badge +
## a single "No retired heroes yet" placeholder card. Cozy degrade, no
## error.
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _multiplier_label: Label = $RootVBox/MultiplierLabel
@onready var _scroll: ScrollContainer = $RootVBox/ScrollContainer
@onready var _card_list: VBoxContainer = $RootVBox/ScrollContainer/CardList
@onready var _back_button: Button = $RootVBox/BackButton


func _ready() -> void:
	UIFrameworkScript.wire_touch_feedback(_back_button)


func on_enter() -> void:
	# Localized title + back button — `tr()` returns the key verbatim if
	# the en translation didn't load, which still degrades to a readable
	# label.
	_title_label.text = tr("hall_of_retired_heroes_title")
	_back_button.text = tr("hall_back_button_label")

	# Subscribe to prestige_completed_signal so the list rebuilds if a
	# new prestige fires while this screen is in the foreground (defensive
	# — current flow is Hero Detail Modal → autoload → modal dismiss →
	# Guild Hall; the player would not normally be on this screen during
	# a prestige). Idempotent connect.
	if not HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
		HeroRoster.prestige_completed_signal.connect(_on_prestige_completed)

	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)

	_rebuild_card_list()
	_refresh_multiplier_label()


func on_exit() -> void:
	if HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
		HeroRoster.prestige_completed_signal.disconnect(_on_prestige_completed)
	if _back_button != null and _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render — multiplier badge + card list
# ---------------------------------------------------------------------------

## Renders the global prestige multiplier as `×N.NN` (2 decimal places)
## per AC-PR-13. `×1.00` is the no-prestige baseline and DOES render
## (the screen is reachable via direct request_screen even with 0
## records — the empty-state path).
func _refresh_multiplier_label() -> void:
	var mult: float = HeroRoster.get_prestige_multiplier()
	_multiplier_label.text = "×%.2f" % mult


## Tears down the current card children and rebuilds from
## `HeroRoster.get_retired_hero_records()`. Each card is a Label whose
## text is `tr("hall_card_metadata_format")` formatted with
## `(display_name, class_id, level_at_retirement, day)`.
##
## Day rendering: V1.0 simplification uses `prestige_index` as the
## displayed day number. True calendar-day rendering (e.g.,
## "Day 156" since first launch) is a V1.5+ polish item — first_launch_ts
## is not currently persisted, and the GDD §C.5 schema does not specify
## Day semantics beyond the locale key format. Using prestige_index is
## cozy + meaningful + deterministic across save round-trips.
func _rebuild_card_list() -> void:
	# Clear existing card children. queue_free is safe here — these are
	# leaf Labels with no signal connections.
	for child: Node in _card_list.get_children():
		_card_list.remove_child(child)
		child.queue_free()

	var records: Array = HeroRoster.get_retired_hero_records()
	if records.is_empty():
		# Empty-state: a single placeholder card. Cozy degrade.
		var placeholder: Label = Label.new()
		placeholder.text = tr("hall_empty_state_placeholder")
		_card_list.add_child(placeholder)
		return

	for rec_variant: Variant in records:
		var rec: Dictionary = rec_variant
		var card: Label = Label.new()
		card.text = _format_card_text(rec)
		_card_list.add_child(card)


## Formats a single retired-hero record into the writer-locked card
## metadata text via `hall_card_metadata_format`. Defensive: missing
## fields fall back to safe defaults.
##
## The format `%s · %s · Lv %d · Retired Day %d` per `en.csv`.
func _format_card_text(record: Dictionary) -> String:
	var display_name: String = String(record.get("display_name", "Unknown"))
	var class_id: String = String(record.get("class_id", "?")).capitalize()
	var level: int = int(record.get("level_at_retirement", 0))
	var day: int = int(record.get("prestige_index", 0))
	return tr("hall_card_metadata_format") % [display_name, class_id, level, day]


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_prestige_completed(_record: Dictionary, _new_count: int) -> void:
	_rebuild_card_list()
	_refresh_multiplier_label()


func _on_back_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
