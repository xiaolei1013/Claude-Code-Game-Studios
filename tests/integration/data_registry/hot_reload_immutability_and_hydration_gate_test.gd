# Tests for Story 007: Hot-reload, immutability enforcement, and SaveLoadSystem
# hydration gate.
# Covers: TR-data-loading-009, TR-data-loading-010, TR-data-loading-013,
#         TR-data-loading-027, TR-data-loading-028,
#         AC-DLS-01, AC-DLS-08, AC-DLS-09.
#
# Fixture strategy (Programmatic Option B — same as resolve_api_and_typed_accessors_test.gd):
#   .tres fixtures are written at runtime via DataRegistryFixtures.write() and
#   torn down in after_test(). Self-contained, deterministic, no committed binaries.
#
# Hot-reload context:
#   hot_reload() is runtime-gated by OS.is_debug_build(). Tests run under the
#   editor / godot --headless which is a debug build, so the gate evaluates true
#   in the test environment. The release-build no-op path is verified by code
#   review of the early `if not OS.is_debug_build(): return` check rather than
#   runtime assertion (we cannot toggle is_debug_build() at runtime).
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")
const DataRegistryFixtures = preload("res://tests/fixtures/data_registry/fixture_helpers.gd")
const TestContentType = preload("res://tests/fixtures/data_registry/test_content_type.gd")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Root of the programmatic fixture tree written/deleted per test.
## Under res:// so ResourceLoader.load() can resolve fixture .tres paths.
const FIXTURE_ROOT: String = "res://tests/fixtures/data_registry/hot_reload_007/"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Boots a fresh DataRegistry pointing at FIXTURE_ROOT.
## Sets min_content_count to {} by default so tests focus on hot-reload semantics.
## Caller is responsible for freeing the returned instance.
func _boot_registry(min_content_count: Dictionary = {}) -> Node:
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = min_content_count
	dr._ready()
	return dr


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func after_test() -> void:
	DataRegistryFixtures.cleanup(FIXTURE_ROOT)


# ---------------------------------------------------------------------------
# Test 1 — AC-DLS-09 / TR-data-loading-010 / TR-data-loading-013:
#   hot_reload() re-enumerates only the target category and emits
#   hot_reload_complete(content_type) once. Other categories' resources stay
#   identity-equal (untouched).
# ---------------------------------------------------------------------------
func test_hot_reload_re_enumerates_target_category_only_and_emits_signal() -> void:
	# Arrange — boot with classes + enemies populated
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
		"enemies": [{"id": "enemy_goblin", "display_name": "Goblin"}],
	})
	var dr: Node = _boot_registry()
	var enemy_before: Resource = dr.resolve("enemies", "enemy_goblin")
	assert_object(enemy_before).is_not_null()
	assert_str(dr.resolve("classes", "hero_warrior").display_name).is_equal("Warrior")

	# Act — overwrite the classes/hero_warrior.tres on disk with a new display_name
	# and call hot_reload("classes"). The "enemies" category is untouched.
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior_v2"}],
	})
	dr.hot_reload("classes")

	# Assert — signal was emitted (synchronously); state is back to READY
	assert_signal(dr).is_emitted("hot_reload_complete", ["classes"])
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)

	# Assert — classes category reflects the new value
	var warrior_after: Resource = dr.resolve("classes", "hero_warrior")
	assert_str(warrior_after.display_name).is_equal("Warrior_v2")

	# Assert — enemies category is untouched (identity-equal cached object)
	var enemy_after: Resource = dr.resolve("enemies", "enemy_goblin")
	assert_bool(enemy_after == enemy_before).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-data-loading-010 release-build no-op (code-review verified):
#   The release-build no-op path cannot be exercised at runtime because
#   OS.is_debug_build() is fixed for the running process. This test documents
#   the contract by asserting the DEBUG path IS taken (proves the gate functions
#   in the test environment) and points at the source-line that strips it from
#   release. The release-build path is verified by code review of:
#       func hot_reload(content_type: String) -> void:
#           if not OS.is_debug_build():
#               return
# ---------------------------------------------------------------------------
func test_hot_reload_runtime_gate_passes_through_in_debug_build() -> void:
	# Arrange
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})
	var dr: Node = _boot_registry()

	# Act — confirm we're in a debug build (test environment invariant)
	# and that hot_reload actually performs work when called.
	assert_bool(OS.is_debug_build()).is_true()
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior_reloaded"}],
	})
	dr.hot_reload("classes")

	# Assert — debug build executed the reload (proves the gate evaluates true)
	assert_str(dr.resolve("classes", "hero_warrior").display_name).is_equal("Warrior_reloaded")

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-data-loading-010 precondition (state != READY):
#   hot_reload() called while state != READY logs a warning and is ignored;
#   state is NOT transitioned to HOT_RELOAD.
# ---------------------------------------------------------------------------
func test_hot_reload_in_non_ready_state_is_ignored() -> void:
	# Arrange — construct a registry without calling _ready() so state stays UNLOADED;
	# also explicitly set LOADING to exercise the most-common race condition.
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.state = DataRegistryScript.State.LOADING

	# Act
	dr.hot_reload("classes")

	# Assert — state did NOT transition to HOT_RELOAD or READY
	assert_int(dr.state).is_equal(DataRegistryScript.State.LOADING)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 4 — Empty-catalog ERROR via hot_reload (Story spec QA case):
#   hot_reload into a now-empty directory whose category has min_content_count
#   transitions to ERROR (terminal); hot_reload_complete is NOT emitted.
# ---------------------------------------------------------------------------
func test_hot_reload_into_empty_directory_transitions_to_error() -> void:
	# Arrange — boot with one class meeting min_content_count == 1
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})
	var dr: Node = _boot_registry({"classes": 1})

	# Act — wipe the classes fixture dir, then hot_reload
	DataRegistryFixtures.cleanup(FIXTURE_ROOT)
	# Recreate the empty classes directory so DirAccess.open() succeeds and the
	# walk yields zero .tres files (rather than a missing-dir warning path).
	DataRegistryFixtures.write(FIXTURE_ROOT, {"classes": []})
	dr.hot_reload("classes")

	# Assert — terminal ERROR; hot_reload_complete was NOT emitted
	assert_int(dr.state).is_equal(DataRegistryScript.State.ERROR)
	assert_signal(dr).is_not_emitted("hot_reload_complete")

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 5 — AC-DLS-08 / TR-data-loading-009 / TR-data-loading-028:
#   Read-only contract. verify_integrity() returns no mismatches at boot;
#   after a consumer mutates a resolved resource, verify_integrity() surfaces
#   exactly that mismatch with the field name, expected, and actual values.
# ---------------------------------------------------------------------------
func test_immutability_snapshot_detects_mutation_in_debug_build() -> void:
	# Arrange
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})
	var dr: Node = _boot_registry()

	# Assert — clean baseline
	var baseline: Array[Dictionary] = dr.verify_integrity()
	assert_int(baseline.size()).is_equal(0)

	# Act — illegally mutate a resolved resource (simulates a consumer bug)
	var hero: Resource = dr.resolve("classes", "hero_warrior")
	hero.display_name = "MUTATED"

	# Assert — exactly one mismatch surfaces
	var mismatches: Array[Dictionary] = dr.verify_integrity()
	assert_int(mismatches.size()).is_equal(1)
	var entry: Dictionary = mismatches[0]
	assert_str(entry["content_type"]).is_equal("classes")
	assert_str(entry["id"]).is_equal("hero_warrior")
	assert_str(entry["property"]).is_equal("display_name")
	assert_str(entry["expected"]).is_equal("Warrior")
	assert_str(entry["actual"]).is_equal("MUTATED")

	# Hygiene — restore the original so a stray cached reference does not poison
	# subsequent tests in the same process if isolation cleanup misses anything.
	hero.display_name = "Warrior"

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 6 — AC-DLS-01: SaveLoadSystem hydration gate (DataRegistry-side contract).
#   A consumer that subscribes to registry_ready in its own _ready() observes
#   DataRegistry.state == READY at the moment its handler runs, AND can resolve
#   loaded content immediately. This proves the synchronous-emission contract
#   the SaveLoadSystem hydration body relies on (per ADR-0003 Amendment #1).
# ---------------------------------------------------------------------------
func test_registry_ready_signal_gates_hydration_consumer() -> void:
	# Arrange — fixture + a tiny consumer that captures state when the signal fires
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})
	var captured: Dictionary = {
		"state_at_signal": -1,
		"resolved_id": "",
		"signal_count": 0,
	}
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	dr.registry_ready.connect(func() -> void:
		captured["signal_count"] += 1
		captured["state_at_signal"] = dr.state
		var res: Resource = dr.resolve("classes", "hero_warrior")
		captured["resolved_id"] = "" if res == null else res.id
	)

	# Act — boot
	dr._ready()

	# Assert — handler observed READY state and could resolve content immediately
	assert_int(captured["signal_count"]).is_equal(1)
	assert_int(captured["state_at_signal"]).is_equal(DataRegistryScript.State.READY)
	assert_str(captured["resolved_id"]).is_equal("hero_warrior")

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 7b — AC-DLS-01 (integration) ERROR-path:
#   When the boot scan fails, registry_error fires (NOT registry_ready); a
#   consumer subscribed to both signals refuses hydration on the error edge.
#   Mirrors the SaveLoadSystem hydration contract: hydrate ONLY if
#   DataRegistry.state == READY at signal-edge time.
# ---------------------------------------------------------------------------
func test_registry_error_signal_observable_by_consumer_refusing_hydration() -> void:
	# Arrange — duplicate id within the same category triggers DuplicateId ERROR
	# (see _load_category step 4). The boot scan calls _transition_to_error and
	# returns false, so registry_ready is NOT emitted.
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [
			{"id": "hero_warrior", "display_name": "Warrior_a"},
			# fixture_helpers writes "<id>.tres" — same id with a different
			# display_name on disk would collide. Force two distinct files at the
			# same id by writing the second entry under a different filename via
			# a tiny helper below.
		],
	})
	# Manually drop a second .tres file with the same id under a different
	# filename so the boot-scan walk encounters two resources with id=hero_warrior.
	var second_path: String = FIXTURE_ROOT + "classes/duplicate.tres"
	var dup: TestContentType = TestContentType.new()
	dup.id = "hero_warrior"
	dup.display_name = "Warrior_b"
	ResourceSaver.save(dup, second_path)

	var captured: Dictionary = {
		"hydrated": false,
		"refused_with_reason": "",
	}
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	# Consumer that subscribes to BOTH signals — happy path runs hydration,
	# ERROR path records the refusal reason without hydrating.
	dr.registry_ready.connect(func() -> void:
		captured["hydrated"] = true
	)
	dr.registry_error.connect(func(reason: String, _details: Dictionary) -> void:
		captured["refused_with_reason"] = reason
	)

	# Act — boot
	dr._ready()

	# Assert — ERROR observed, hydration refused
	assert_int(dr.state).is_equal(DataRegistryScript.State.ERROR)
	assert_str(captured["refused_with_reason"]).is_equal(DataRegistryScript.ERROR_DUPLICATE_ID)
	assert_bool(captured["hydrated"]).is_false()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 7 — TR-data-loading-027:
#   Patch-time live updates are NOT supported. Files dropped into assets/data/
#   at runtime are NOT picked up unless hot_reload() is called explicitly.
# ---------------------------------------------------------------------------
func test_no_patch_time_live_updates_without_hot_reload() -> void:
	# Arrange — boot with one class
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})
	var dr: Node = _boot_registry()
	assert_int(dr.get_all_by_type("classes").size()).is_equal(1)

	# Act — drop a new .tres directly into the classes/ fixture dir at runtime
	# (no hot_reload call). Use the helper to write the additional file.
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [
			{"id": "hero_warrior", "display_name": "Warrior"},
			{"id": "hero_mage", "display_name": "Mage"},
		],
	})

	# Assert — the in-memory index is unchanged; new file is invisible
	assert_int(dr.get_all_by_type("classes").size()).is_equal(1)

	# Act — explicit hot_reload picks up the new file
	dr.hot_reload("classes")

	# Assert — now both classes are visible
	assert_int(dr.get_all_by_type("classes").size()).is_equal(2)
	assert_object(dr.resolve("classes", "hero_mage")).is_not_null()

	# Cleanup
	dr.free()
