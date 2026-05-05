# Sprint 11 S11-M2b + S11-M3: tests for the two thin wrappers around
# request_full_persist.
#
# - request_heartbeat_persist(time_fields): heartbeat = full persist with
#   reason="heartbeat" per Save/Load GDD §C.7. time_fields parameter is
#   accepted for API stability with TickSystem._fire_heartbeat (S11-M2a)
#   but is unused — request_full_persist itself updates last_persist_ts.
#
# - _on_scene_boundary_persist(reason): scene_boundary = full persist with
#   reason="scene_boundary:<original-reason>" so subscribers can
#   distinguish boundary persists from heartbeat persists at the
#   save_completed listener.
#
# Both wrappers go through request_full_persist's existing state-guards.
# In UNLOADED state (default in tests), persist rejects with save_failed.
# The save_failed payload's reason field is the wrapper-prefixed string
# — that's the contract these tests lock.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier per S10-S4 — reset live SaveLoadSystem state.
# ---------------------------------------------------------------------------

func _reset_save_load_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	sl._state = SaveLoadScript.State.UNLOADED
	sl.save_file_path = "user://save_slot_1.dat"


func before_test() -> void:
	_reset_save_load_state()


func after_test() -> void:
	_reset_save_load_state()


var _save_failed_calls: Array[Dictionary] = []
var _save_completed_calls: Array[String] = []


func _on_save_failed(reason: String, error_code: int) -> void:
	_save_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_save_completed(reason: String) -> void:
	_save_completed_calls.append(reason)


func _connect_spy(sl: Node) -> void:
	_save_failed_calls.clear()
	_save_completed_calls.clear()
	if not sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.connect(_on_save_failed)
	if not sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.connect(_on_save_completed)


func _disconnect_spy(sl: Node) -> void:
	if sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.disconnect(_on_save_failed)
	if sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.disconnect(_on_save_completed)


# ===========================================================================
# Group A — request_heartbeat_persist (S11-M2b)
# ===========================================================================

func test_request_heartbeat_persist_method_exists() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_method("request_heartbeat_persist")).is_true()


func test_request_heartbeat_persist_forwards_to_full_persist_with_reason_heartbeat() -> void:
	# Heartbeat from UNLOADED state: full-persist guard rejects, save_failed
	# emits with reason="heartbeat" — that's the forwarding contract.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spy(sl)

	sl.request_heartbeat_persist({"last_ts_ms": 1234567890000})

	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_str(_save_failed_calls[0].reason).is_equal("heartbeat")
	assert_int(_save_failed_calls[0].error_code).is_equal(ERR_UNAVAILABLE)
	_disconnect_spy(sl)


func test_request_heartbeat_persist_accepts_empty_time_fields() -> void:
	# time_fields parameter is unused in S11-M2b (request_full_persist already
	# routes time fields via TickSystem.set_last_persist_ts). Empty dict OK.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spy(sl)

	sl.request_heartbeat_persist({})

	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_str(_save_failed_calls[0].reason).is_equal("heartbeat")
	_disconnect_spy(sl)


func test_request_heartbeat_persist_coalesces_when_persisting() -> void:
	# Same coalesce contract as request_full_persist — heartbeat fired during
	# in-flight persist drops with push_warning + no save_failed emit.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl._state = SaveLoadScript.State.PERSISTING
	_connect_spy(sl)

	sl.request_heartbeat_persist({"last_ts_ms": 1})

	assert_int(_save_failed_calls.size()).is_equal(0)
	assert_int(_save_completed_calls.size()).is_equal(0)
	assert_int(sl._state).is_equal(SaveLoadScript.State.PERSISTING)
	_disconnect_spy(sl)


# ===========================================================================
# Group B — _on_scene_boundary_persist (S11-M3)
# ===========================================================================

func test_on_scene_boundary_persist_method_exists() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_method("_on_scene_boundary_persist")).is_true()


func test_on_scene_boundary_persist_forwards_with_scene_boundary_prefix() -> void:
	# scene_boundary handler prefixes the reason so save_completed listeners
	# can distinguish scene-boundary persists from heartbeat persists.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spy(sl)

	sl._on_scene_boundary_persist("pre_dungeon_entry")

	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_str(_save_failed_calls[0].reason).is_equal("scene_boundary:pre_dungeon_entry")
	assert_int(_save_failed_calls[0].error_code).is_equal(ERR_UNAVAILABLE)
	_disconnect_spy(sl)


func test_on_scene_boundary_persist_post_victory_exit_carries_payload() -> void:
	# Lock the second emission reason from S11-M1 (post_victory_exit) carries
	# the same prefix + suffix pattern.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spy(sl)

	sl._on_scene_boundary_persist("post_victory_exit")

	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_str(_save_failed_calls[0].reason).is_equal("scene_boundary:post_victory_exit")
	_disconnect_spy(sl)


func test_on_scene_boundary_persist_routes_via_request_full_persist_state_machine() -> void:
	# Scene-boundary handler is NOT a state-machine bypass — it goes through
	# request_full_persist's READY guard. PERSISTING-state coalesces silently.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl._state = SaveLoadScript.State.PERSISTING
	_connect_spy(sl)

	sl._on_scene_boundary_persist("pre_dungeon_entry")

	# Coalesce path: state unchanged, no signal emit.
	assert_int(sl._state).is_equal(SaveLoadScript.State.PERSISTING)
	assert_int(_save_failed_calls.size()).is_equal(0)
	assert_int(_save_completed_calls.size()).is_equal(0)
	_disconnect_spy(sl)


# ===========================================================================
# Group C — wiring contract (the listener stays connected at boot)
# ===========================================================================

func test_save_load_system_subscribed_to_scene_manager_scene_boundary_persist() -> void:
	# Per save_load_system.gd._ready, the live autoload subscribes to
	# SceneManager.scene_boundary_persist. Verify the connection is live so
	# Sprint 11 S11-M1 emit -> Sprint 11 S11-M3 handler -> request_full_persist
	# end-to-end signaling holds.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(sl).is_not_null()
	assert_object(sm).is_not_null()
	assert_bool(sm.scene_boundary_persist.is_connected(sl._on_scene_boundary_persist)).is_true()
