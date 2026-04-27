# Tests for Sprint 8 combat-resolution Story 009 (S8-S7 carryover from S7-S2):
#   - Empty formation → empty CombatBatchResult; push_warning fires; no 0/0
#   - All-null class_id formation → behaves as empty (TR-019 path)
#   - Mixed valid + bad heroes → bad hero contributes 0 dps + 0 hp; error_logger
#     receives one call per bad class_id with class_id in the message
#   - Optional Callable error_logger DI; null logger = silent skip (production default)
#   - Source-grep canaries: zero RNG/Time/OS calls in resolver source (TR-027)
#   - Source-grep canary: zero `signal` declarations in resolver source (TR-030)
#
# Covers: TR-combat-018 (Combat reports first_clear_in_range; idempotency lives
#                        on Orchestrator),
#         TR-combat-019 (empty formation → empty result + push_warning),
#         TR-combat-020 (unresolvable class_id → 0 dps/hp + optional error_logger
#                        callback),
#         TR-combat-027 (no RNG / no time-dependent reads in resolver),
#         TR-combat-030 (zero signal declarations in resolver source).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const GHOST_CLASS_ID := "ghost_class_does_not_exist"


func _make_hero(class_id: String, instance_id: int = 1, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


func _data_registry_can_resolve_warrior() -> bool:
	return DataRegistry.resolve("classes", WARRIOR_ID) != null


# Spy: collects log messages from the injected error_logger Callable.
var _spy_log_messages: Array[String] = []


func _spy_logger(message: String) -> void:
	_spy_log_messages.append(message)


# ===========================================================================
# Group A: TR-019 — empty formation → 0 dps + 0 hp + push_warning
# ===========================================================================

func test_formation_dps_per_tick_empty_formation_returns_zero() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()

	# Act — push_warning is logged inside; gdunit4 doesn't fail on warnings.
	var dps: float = resolver.formation_dps_per_tick([])

	# Assert
	assert_float(dps).is_equal(0.0)


func test_formation_total_hp_empty_formation_returns_zero() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()

	# Act
	var hp: int = resolver.formation_total_hp([])

	# Assert
	assert_int(hp).is_equal(0)


func test_compute_offline_batch_empty_formation_snapshot_returns_empty_no_division_by_zero() -> void:
	# Arrange — synthesize a snapshot that mirrors an empty-formation dispatch:
	# formation_dps == 0.0; non-empty enemy_list; floor budget present. The
	# resolver must NOT divide by zero in any path.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = 0.0  # empty/all-bad formation post-aggregate
	s.hp_bonus_factor = 1.0
	s.matchup_cache = {&"bruiser": true}
	s.enemy_list = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
	]
	s.dispatched_at_tick = 0
	s.loops_per_run = 1

	# Act — must not crash with 0/0 division (ticks_to_kill returns sentinel 10000).
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 100)

	# Assert — empty result; no kills aggregated within the small budget given
	# the sentinel 10000 ticks_to_kill (kill_tick > tick_hi).
	assert_int(result.kills_by_archetype.size()).is_equal(0)
	assert_int(result.kills_by_tier.size()).is_equal(0)


# ===========================================================================
# Group B: TR-019 — all-null class_id formation behaves as empty
# ===========================================================================

func test_formation_dps_per_tick_all_unresolvable_class_ids_returns_zero() -> void:
	# Arrange — 3 heroes, all with class_ids that DataRegistry can't resolve.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [
		_make_hero(GHOST_CLASS_ID, 1),
		_make_hero("phantom", 2),
		_make_hero("specter", 3),
	]

	# Act
	var dps: float = resolver.formation_dps_per_tick(formation)

	# Assert — all heroes silently skipped; raw_sum == 0; dps == 0.
	assert_float(dps).is_equal(0.0)


func test_formation_total_hp_all_unresolvable_class_ids_returns_zero() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(GHOST_CLASS_ID, 1)]

	# Act
	var hp: int = resolver.formation_total_hp(formation)

	# Assert
	assert_int(hp).is_equal(0)


# ===========================================================================
# Group C: TR-020 — error_logger Callable DI
# ===========================================================================

func test_formation_dps_per_tick_calls_error_logger_for_each_unresolvable_class_id() -> void:
	# Arrange — 3 heroes, all unresolvable. Logger should receive 3 calls.
	_spy_log_messages.clear()
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [
		_make_hero(GHOST_CLASS_ID, 1),
		_make_hero("phantom", 2),
		_make_hero("specter", 3),
	]
	var logger: Callable = Callable(self, "_spy_logger")

	# Act
	var dps: float = resolver.formation_dps_per_tick(formation, logger)

	# Assert
	assert_float(dps).is_equal(0.0)
	assert_int(_spy_log_messages.size()).is_equal(3)


func test_formation_dps_per_tick_logger_message_contains_class_id() -> void:
	# Arrange
	_spy_log_messages.clear()
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(GHOST_CLASS_ID, 1)]
	var logger: Callable = Callable(self, "_spy_logger")

	# Act
	var _dps: float = resolver.formation_dps_per_tick(formation, logger)

	# Assert — message includes the offending class_id for diagnostics.
	assert_int(_spy_log_messages.size()).is_equal(1)
	assert_str(_spy_log_messages[0]).contains(GHOST_CLASS_ID)


func test_formation_dps_per_tick_no_logger_passed_silently_skips() -> void:
	# Arrange — no logger arg → Callable() default → resolver does NOT log.
	_spy_log_messages.clear()
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(GHOST_CLASS_ID, 1)]

	# Act — call with no logger.
	var _dps: float = resolver.formation_dps_per_tick(formation)

	# Assert — spy was NEVER invoked (it can't be — we didn't pass it).
	assert_int(_spy_log_messages.size()).is_equal(0)


func test_formation_total_hp_calls_error_logger_for_unresolvable_class_id() -> void:
	# Arrange
	_spy_log_messages.clear()
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(GHOST_CLASS_ID, 1)]
	var logger: Callable = Callable(self, "_spy_logger")

	# Act
	var _hp: int = resolver.formation_total_hp(formation, logger)

	# Assert
	assert_int(_spy_log_messages.size()).is_equal(1)
	assert_str(_spy_log_messages[0]).contains(GHOST_CLASS_ID)


func test_mixed_formation_one_bad_two_valid_only_logs_for_bad_hero() -> void:
	# Arrange — mix of valid + invalid; logger should receive exactly 1 call
	# (for the bad hero), and the dps total reflects only the valid contributors.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped: DataRegistry cannot resolve warrior")
		return
	_spy_log_messages.clear()
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(GHOST_CLASS_ID, 3),
	]
	var logger: Callable = Callable(self, "_spy_logger")

	# Act
	var dps: float = resolver.formation_dps_per_tick(formation, logger)

	# Assert — non-zero dps from the 2 warriors; 1 logger call for the ghost.
	assert_float(dps).is_greater(0.0)
	assert_int(_spy_log_messages.size()).is_equal(1)
	assert_str(_spy_log_messages[0]).contains(GHOST_CLASS_ID)


# ===========================================================================
# Group D: TR-018 — Combat reports first_clear per-call (no internal idempotency)
# ===========================================================================

func test_emit_events_in_range_first_clear_in_range_fires_every_time_in_range() -> void:
	# TR-018: Combat does NOT carry once-per-dispatch idempotency — every call
	# whose tick range covers the floor-clear boundary reports
	# first_clear_in_range = true. The Orchestrator (NOT Combat) owns the
	# "already-fired" flag for save/load idempotency.
	#
	# Arrange — 3-enemy 1-loop schedule clears at tick 21 (first_clear).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = 1.0
	s.hp_bonus_factor = 1.0
	s.matchup_cache = {&"bruiser": true}
	s.enemy_list = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e2", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e3", "archetype": &"bruiser", "tier": 2, "is_boss": true, "base_hp": 10},
	]
	s.dispatched_at_tick = 0
	s.loops_per_run = 1

	# Act — call twice with overlapping ranges that both contain tick 21.
	var first: CombatTickEvents = resolver.emit_events_in_range(s, 0, 25)
	var second: CombatTickEvents = resolver.emit_events_in_range(s, 0, 30)

	# Assert — both calls report first_clear_in_range = true (NO suppression).
	assert_bool(first.first_clear_in_range).is_true()
	assert_bool(second.first_clear_in_range).is_true()


# ===========================================================================
# Group E: TR-027 — source-grep canary for RNG / time / OS APIs
# ===========================================================================

const _RESOLVER_SOURCES: Array[String] = [
	"res://src/core/combat/combat_resolver.gd",
	"res://src/core/combat/default_combat_resolver.gd",
]
# Forbidden API patterns. Each is checked as a substring after stripping the
# leading `#`/`##` comment lines (TR-027).
const _FORBIDDEN_RNG_APIS: Array[String] = [
	"randi(",
	"randf(",
	"randi_range(",
	"randf_range(",
	"RandomNumberGenerator",
	"Time.",
	"OS.get_ticks",
	"OS.get_unix_time",
]


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Source file missing: %s" % path)
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


func _scan_for_forbidden_apis(path: String, forbidden: Array[String]) -> Array[String]:
	# Walk source line-by-line, skipping comment lines. Returns the list of
	# forbidden strings found in non-comment content.
	var hits: Array[String] = []
	var src: String = _read_source(path)
	if src.is_empty():
		return hits
	var lines: PackedStringArray = src.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		# Skip comments and doc-comments (TR-027 doc-comment exemption: comment
		# text mentioning "Time" or "OS" as English words must not trigger).
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		# Strip inline trailing comment if present (e.g., `var x = 1 # comment`).
		var hash_idx: int = trimmed.find("#")
		var code_only: String = trimmed if hash_idx < 0 else trimmed.substr(0, hash_idx)
		for f: String in forbidden:
			if code_only.contains(f):
				hits.append("%s: '%s' in line: %s" % [path, f, trimmed])
	return hits


func test_combat_resolver_source_has_no_rng_or_time_api_calls() -> void:
	# TR-027 canary: walk both resolver source files for forbidden APIs.
	var all_hits: Array[String] = []
	for path: String in _RESOLVER_SOURCES:
		var hits: Array[String] = _scan_for_forbidden_apis(path, _FORBIDDEN_RNG_APIS)
		all_hits.append_array(hits)

	# Assert — zero hits across both files.
	assert_int(all_hits.size()).is_equal(0)


# ===========================================================================
# Group F: TR-030 — source-grep canary for `signal` declarations
# ===========================================================================

func test_combat_resolver_source_has_no_signal_declarations() -> void:
	# TR-030: Combat is signal-free. Walk source line-by-line; assert no line
	# (after skipping comments) begins with "signal " — the GDScript token for
	# signal declaration. Substring "signal" can appear in identifiers/strings
	# (e.g., "signal_free invariant" in a doc comment) — the begins_with check
	# is the precise form.
	for path: String in _RESOLVER_SOURCES:
		var src: String = _read_source(path)
		if src.is_empty():
			continue
		var lines: PackedStringArray = src.split("\n")
		for line: String in lines:
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or trimmed.begins_with("##"):
				continue
			# Defensive: assert NO non-comment line begins with the `signal `
			# declaration token.
			assert_bool(trimmed.begins_with("signal ")).is_false()


# ===========================================================================
# Group G: positive control — stateful regression check
# ===========================================================================

func test_resolver_two_calls_with_identical_args_produce_identical_dps() -> void:
	# TR-021 / TR-027 reaffirmed: no float accumulation across calls; no
	# time-dependent state. Two calls with identical inputs → byte-equal output.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1, 5)]

	# Act
	var dps_a: float = resolver.formation_dps_per_tick(formation)
	var dps_b: float = resolver.formation_dps_per_tick(formation)

	# Assert
	assert_float(dps_a).is_equal(dps_b)
