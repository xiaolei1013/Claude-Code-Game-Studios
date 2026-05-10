## TelemetrySink — opt-in local-sink telemetry autoload (Sprint 21+ S21-N3
## Stage 2 implementation per `production/live-ops/telemetry-events-v1.md`).
##
## Owns the gameplay-signal → JSONL-append translation per the V1 taxonomy.
## Gameplay code never calls TelemetrySink directly; routing happens here via
## signal subscription, mirroring the AudioRouter pattern exactly.
##
## Privacy contract per the taxonomy doc §C:
##   - Opt-in default OFF. Every handler short-circuits on `_opt_in == false`.
##   - Anonymous ephemeral session_id (UUID per launch, NOT persisted).
##   - No PII (no display_name, no save contents, no IP, no fingerprints).
##   - Local-only sink in MVP (`user://telemetry/events-YYYY-MM-DD.jsonl`).
##   - Daily file rotation (rotation happens at write-time when date changes).
##
## class_name omitted: per `project_godot_autoload_class_name_collision`
## memory note (same pattern as AudioRouter, FormationAssignment, etc.).
##
## Governing spec: production/live-ops/telemetry-events-v1.md
## Autoload rank: 19 (after AudioRouter at rank 18; needs all gameplay-signal
##   sources at our `_ready()` time).
extends Node


# ---------------------------------------------------------------------------
# Constants — per taxonomy doc §D envelope
# ---------------------------------------------------------------------------

## Envelope schema_version. Bumped when the envelope shape changes (NOT when
## per-event payload fields change — those are forward-compat additive).
const SCHEMA_VERSION: int = 1

## Default sink directory. Tests override via `_sink_dir_override` per project
## memory `feedback_test_isolation_user_configfile` to avoid contaminating
## the dev's actual `user://telemetry/` directory.
const _DEFAULT_SINK_DIR: String = "user://telemetry/"

## DungeonRunOrchestrator state enum mirrors (per dungeon_run_state.gd).
## Filtering state_changed by these values discriminates dispatch vs end.
const _STATE_DISPATCHING: int = 1
const _STATE_RUN_ENDED: int = 4


# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Opt-in toggle. Default false (taxonomy doc §C.1). Persisted via the
## SaveLoadSystem consumer surface; written hot via `set_opt_in()` from
## the Settings overlay UI.
var _opt_in: bool = false

## Per-launch ephemeral session_id (taxonomy doc §C.2). Generated at `_ready`,
## NOT persisted, NOT cross-referenced. Used only as within-session
## correlation for the designer's manual JSONL inspection workflow.
var _session_id: String = ""

## Path override for tests. Empty string means use the default sink dir.
## Per project memory `feedback_test_isolation_user_configfile`.
var _sink_dir_override: String = ""

## Debug-build-only test-observable event log (mirrors AudioRouter
## _test_play_sfx_log pattern). Tests assert on this array to verify
## handler payload construction without a JSONL filesystem round-trip.
## Production overhead is zero in release builds (OS.is_debug_build() guard
## inside `_emit_event`).
## Schema per entry: { "event_type": String, "payload": Dictionary }
var _test_event_log: Array = []


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

## Generates the per-launch session_id and subscribes to the 5 V1 event
## sources. Defensive autoload-resolution per ADR-0003 §Signal Subscription
## rule — subscription across any rank pair is safe at `_ready()` time
## (signal objects exist on Node instantiation, before any `_ready` fires).
func _ready() -> void:
	_session_id = _generate_session_id()

	# SaveLoadSystem (rank 6) — first_launch event source.
	if has_node("/root/SaveLoadSystem"):
		var sl: Node = get_node("/root/SaveLoadSystem")
		if sl.has_signal("first_launch") and not sl.first_launch.is_connected(_on_first_launch):
			sl.first_launch.connect(_on_first_launch)

	# HeroRoster (rank 11) — recruit + prestige event sources.
	if has_node("/root/HeroRoster"):
		var hr: Node = get_node("/root/HeroRoster")
		if hr.has_signal("hero_recruited") and not hr.hero_recruited.is_connected(_on_hero_recruited):
			hr.hero_recruited.connect(_on_hero_recruited)
		if hr.has_signal("prestige_completed_signal") and not hr.prestige_completed_signal.is_connected(_on_prestige_completed):
			hr.prestige_completed_signal.connect(_on_prestige_completed)

	# DungeonRunOrchestrator (rank 16) — run_dispatched + run_completed
	# both derive from state_changed (filter on new_state).
	if has_node("/root/DungeonRunOrchestrator"):
		var orch: Node = get_node("/root/DungeonRunOrchestrator")
		if orch.has_signal("state_changed") and not orch.state_changed.is_connected(_on_run_state_changed):
			orch.state_changed.connect(_on_run_state_changed)


# ---------------------------------------------------------------------------
# Public API — opt-in toggle (called by Settings overlay; deferred to V1.0+)
# ---------------------------------------------------------------------------

## Sets the opt-in state. Settings overlay UI calls this on Privacy toggle
## change. Hot-reload safe — every event handler reads `_opt_in` per-event,
## not cached at autoload boot.
##
## taxonomy-events-v1.md §C.1.
func set_opt_in(enabled: bool) -> void:
	_opt_in = enabled


## Returns current opt-in state. Settings UI reads this to render the toggle
## position; tests use it to verify save round-trip.
func is_opt_in() -> bool:
	return _opt_in


# ---------------------------------------------------------------------------
# Save consumer surface — per taxonomy-events-v1.md §F.2
# ---------------------------------------------------------------------------

## SaveLoadSystem-compatible save-data getter. Persisted under top-level key
## `"telemetry"` by SaveLoadSystem.
func get_save_data() -> Dictionary:
	return {"telemetry_opt_in": _opt_in}


## SaveLoadSystem-compatible save-data setter. Defensive default (false)
## per taxonomy doc §C.1 opt-in-default-OFF rule. Pre-V1 saves missing the
## field load as opt_in=false (correct behavior).
func load_save_data(d: Dictionary) -> void:
	_opt_in = bool(d.get("telemetry_opt_in", false))


# ---------------------------------------------------------------------------
# Signal handlers — per taxonomy-events-v1.md §D
# ---------------------------------------------------------------------------

## §D.1 first_launch — fires once per device on cold-launch first-time.
## Some payload fields use sentinel values pending upstream amendments
## (cold_launch_ms requires a platform-timing hook not yet wired).
func _on_first_launch() -> void:
	if not _opt_in:
		return
	var payload: Dictionary = {
		"seed_class": "warrior",  # MVP: Theron is the auto-seeded class
		"cold_launch_ms": 0,  # TODO V1.1: needs platform timing hook
	}
	_emit_event("first_launch", payload)


## §D.2 recruit_purchased — fires after a successful recruit transaction.
## cost_paid uses 0 sentinel pending a Recruitment GDD amendment exposing
## the cost from the transaction (today the cost is computed by Economy.recruit_cost
## but not surfaced on the hero_recruited signal payload).
func _on_hero_recruited(instance: RefCounted) -> void:
	if not _opt_in:
		return
	if instance == null:
		return
	var hr: Node = get_node_or_null("/root/HeroRoster")
	var econ: Node = get_node_or_null("/root/Economy")
	var roster_size: int = 0
	if hr != null and hr.has_method("get_all_heroes"):
		roster_size = (hr.call("get_all_heroes") as Array).size()
	var gold_balance: int = 0
	if econ != null and econ.has_method("get_gold_balance"):
		gold_balance = int(econ.call("get_gold_balance"))
	var payload: Dictionary = {
		"class_id": str(instance.get("class_id")),
		"cost_paid": 0,  # TODO V1.1: amend Recruitment to expose transaction cost
		"roster_size_after": roster_size,
		"gold_balance_after": gold_balance,
	}
	_emit_event("recruit_purchased", payload)


## §D.3 + §D.4 — both events derive from DungeonRunOrchestrator.state_changed.
## Filter on new_state to discriminate dispatch (1) from end (4).
func _on_run_state_changed(new_state: int, _old_state: int) -> void:
	if not _opt_in:
		return
	if new_state == _STATE_DISPATCHING:
		_emit_run_dispatched()
	elif new_state == _STATE_RUN_ENDED:
		_emit_run_completed()


## §D.5 prestige_completed — fires on HeroRoster.prestige_completed_signal.
## was_last_hero is always false in MVP because the last-hero protection
## prevents the prestige in the first place (AC-PR-20). Logging the bool
## documents the contract for future V1.5+ if the protection rule changes.
func _on_prestige_completed(record: Dictionary, new_count: int) -> void:
	if not _opt_in:
		return
	var hr: Node = get_node_or_null("/root/HeroRoster")
	var multiplier: float = 1.0
	if hr != null and hr.has_method("get_prestige_multiplier"):
		multiplier = float(hr.call("get_prestige_multiplier"))
	var payload: Dictionary = {
		"prestiged_class_id": str(record.get("class_id", "")),
		"level_at_retirement": int(record.get("level_at_retirement", 0)),
		"new_prestige_count": new_count,
		"new_multiplier": multiplier,
		"was_last_hero": false,
	}
	_emit_event("prestige_completed", payload)


# ---------------------------------------------------------------------------
# Private — run-event payload builders
# ---------------------------------------------------------------------------

## Reads orchestrator's run_snapshot at DISPATCHING time and builds the
## §D.3 payload. floor_id format is "<biome>_floor_<N>" per
## DungeonRunOrchestrator.snapshot_formation_for_run; we parse rather than
## re-resolve to avoid coupling.
func _emit_run_dispatched() -> void:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null or not "run_snapshot" in orch:
		return
	var snap: Variant = orch.run_snapshot
	if snap == null:
		return

	var class_multiset: Array[String] = []
	var fs: Variant = snap.formation_snapshot
	if fs is Dictionary and (fs as Dictionary).has("heroes"):
		var heroes: Variant = (fs as Dictionary).get("heroes")
		if heroes is Array:
			for hero_v: Variant in (heroes as Array):
				if hero_v is Dictionary:
					class_multiset.append(str((hero_v as Dictionary).get("class_id", "")))
	class_multiset.sort()

	var hr: Node = get_node_or_null("/root/HeroRoster")
	var prestige_count: int = 0
	if hr != null and hr.has_method("get_prestige_count"):
		prestige_count = int(hr.call("get_prestige_count"))

	var floor_id: String = str(snap.floor_id)
	var payload: Dictionary = {
		"biome_id": _extract_biome_id(floor_id),
		"floor_index": _extract_floor_index(floor_id),
		"formation_class_multiset": class_multiset,
		"synergy_id": str(snap.synergy_id),
		"prestige_count": prestige_count,
	}
	_emit_event("run_dispatched", payload)


## §D.4 run_completed payload from RunSnapshot at RUN_ENDED time. Some
## fields use sentinels pending RunSnapshot amendments (xp_earned not yet
## tracked on the snapshot; was_offline_replay not yet a snapshot field;
## duration_seconds derives from current_tick under the assumption that
## tick == 1 second — TODO V1.1: confirm tick rate or read from TickSystem).
func _emit_run_completed() -> void:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null or not "run_snapshot" in orch:
		return
	var snap: Variant = orch.run_snapshot
	if snap == null:
		return

	# outcome: cleared if floor_clear_emitted; aborted if losing_run + early end;
	# otherwise wiped. Coarse heuristic for V1.
	var outcome: String = "wiped"
	if bool(snap.floor_clear_emitted):
		outcome = "cleared"
	elif bool(snap.losing_run):
		outcome = "wiped"

	var econ: Node = get_node_or_null("/root/Economy")
	var current_gold: int = 0
	if econ != null and econ.has_method("get_gold_balance"):
		current_gold = int(econ.call("get_gold_balance"))
	var gold_earned: int = current_gold - int(snap.pre_dispatch_gold)

	var floor_id: String = str(snap.floor_id)
	var payload: Dictionary = {
		"biome_id": _extract_biome_id(floor_id),
		"floor_index": _extract_floor_index(floor_id),
		"outcome": outcome,
		"losing_run": bool(snap.losing_run),
		"gold_earned": gold_earned,
		"xp_earned": 0,  # TODO V1.1: snap doesn't track xp_earned aggregate yet
		"kills": int(snap.kill_count),
		"duration_seconds": int(snap.current_tick),  # 1 tick == 1 second per tick-system
		"was_offline_replay": false,  # TODO V1.1: snap doesn't track this yet
		"synergy_id": str(snap.synergy_id),
	}
	_emit_event("run_completed", payload)


# ---------------------------------------------------------------------------
# Private — sink writer + envelope helpers
# ---------------------------------------------------------------------------

## Wraps the payload in the §D envelope and appends one JSON line to today's
## sink file. Daily rotation by date in the filename — no in-process scheduler.
##
## Idempotent on opt-in flip OFF→ON: the sink directory is lazy-created on
## first write. No buffer state to flush.
func _emit_event(event_type: String, payload: Dictionary) -> void:
	var envelope: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"session_id": _session_id,
		"event_type": event_type,
		"payload": payload,
	}
	# Debug-build test observability — zero overhead in release builds.
	if OS.is_debug_build():
		_test_event_log.append({"event_type": event_type, "payload": payload})
	_append_jsonl(envelope)


## Appends one JSON-encoded line to the day's sink file. Creates the sink
## directory + file if missing. Best-effort: filesystem failures are
## silently dropped (no push_error) to avoid telemetry-induced crash loops.
func _append_jsonl(envelope: Dictionary) -> void:
	var dir: String = _sink_dir_override if _sink_dir_override != "" else _DEFAULT_SINK_DIR
	var filename: String = "events-%s.jsonl" % _today_date_string()
	var path: String = dir + filename

	# Lazy-create the sink directory (DirAccess.make_dir_recursive_absolute
	# accepts user:// paths in Godot 4.x).
	if not DirAccess.dir_exists_absolute(dir):
		var err: int = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return  # silent failure per docstring contract

	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		# File doesn't exist yet — create it.
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return  # silent failure
	else:
		# Seek to end for append.
		file.seek_end()
	file.store_line(JSON.stringify(envelope))
	file.close()


## Generates a fresh UUID-shaped session_id per launch. Uses Godot's RandomNumberGenerator
## with a process-time seed (ephemeral; not persisted anywhere). Returns
## a 16-char hex string (sufficient anonymity at MVP scale; not a real UUID).
func _generate_session_id() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	# 16 hex chars = 64 bits of entropy. Adequate for within-session correlation.
	var parts: Array[String] = []
	for i: int in range(4):
		parts.append("%04x" % rng.randi_range(0, 65535))
	return "-".join(parts)


## "YYYY-MM-DD" string from system time. Used for daily sink file rotation.
func _today_date_string() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Parses biome from "<biome>_floor_<N>" floor_id format. Returns "" if the
## format doesn't match (defensive — orchestrator could change the format).
func _extract_biome_id(floor_id: String) -> String:
	var sep_idx: int = floor_id.find("_floor_")
	if sep_idx < 0:
		return ""
	return floor_id.substr(0, sep_idx)


## Parses floor index from "<biome>_floor_<N>". Returns 0 sentinel on parse failure.
func _extract_floor_index(floor_id: String) -> int:
	var sep_idx: int = floor_id.find("_floor_")
	if sep_idx < 0:
		return 0
	var tail: String = floor_id.substr(sep_idx + 7)  # len("_floor_") == 7
	if not tail.is_valid_int():
		return 0
	return tail.to_int()
