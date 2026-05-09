# Story 010: Schema VERSION migration path — placeholder MVP tests.
#
# Covers ACs from production/epics/save-load-system/story-010-schema-version-migration.md:
#   - `_run_migration_chain(payload, from, to)` returns payload unchanged when
#     from == to (no-op contract).
#   - Returns null for any (from != to) since no migrations have been authored
#     in MVP — the chain is a stub structural placeholder until V2 ships.
#   - State machine transitions LOADING → MIGRATION → (READY | CORRUPT) per
#     the canonical Story 010 boundary actions; regressions on stale paths
#     (READY → MIGRATION, MIGRATION → LOADING) are explicitly covered.
#
# Pattern: preload-and-new isolation (matches tests/unit/save_load/autoload_skeleton_test.gd).
# Direct `_state` field reads + `_transition_to` calls; no live autoload tree.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")


# ===========================================================================
# Group A — _run_migration_chain stub behavior
# ===========================================================================

func test_run_migration_chain_returns_payload_unchanged_for_same_version() -> void:
	# Defensive contract: callers passing equal from/to versions get the
	# payload back as-is. From the load pipeline this branch is dead code
	# (the call site only fires when version < CURRENT_SAVE_VERSION) but
	# direct callers (tests, V1.0 batch tooling) rely on the no-op path.
	var sls: Node = SaveLoadScript.new()
	var payload: Dictionary = {"hero_roster": {"heroes": []}, "_meta": {"sequence": 1}}
	var result: Variant = sls._run_migration_chain(payload, 1, 1)
	assert_object(result).is_not_null()
	assert_bool(result is Dictionary).is_true()
	# Same dict reference returned (no defensive copy).
	assert_int((result as Dictionary).size()).is_equal(payload.size())
	assert_bool((result as Dictionary).has("hero_roster")).is_true()
	sls.free()


func test_run_migration_chain_returns_null_for_unknown_from_version() -> void:
	# MVP: no migrations authored. Any (from != to) returns null until a
	# real V(N) → V(N+1) step lands in this method.
	var sls: Node = SaveLoadScript.new()
	var payload: Dictionary = {"data": "anything"}
	var result: Variant = sls._run_migration_chain(payload, 0, 1)
	assert_object(result).is_null()
	sls.free()


func test_run_migration_chain_returns_null_for_downgrade_step() -> void:
	# Downgrade (from > to) is also unauthored. The load pipeline rejects
	# version > CURRENT before this method is reached, but the chain itself
	# is symmetric — null on any unauthored step regardless of direction.
	var sls: Node = SaveLoadScript.new()
	var payload: Dictionary = {"data": "anything"}
	var result: Variant = sls._run_migration_chain(payload, 2, 1)
	assert_object(result).is_null()
	sls.free()


func test_run_migration_chain_handles_empty_payload() -> void:
	# Defensive: same-version no-op returns the empty Dict reference.
	var sls: Node = SaveLoadScript.new()
	var payload: Dictionary = {}
	var result: Variant = sls._run_migration_chain(payload, 1, 1)
	assert_object(result).is_not_null()
	assert_bool(result is Dictionary).is_true()
	assert_int((result as Dictionary).size()).is_equal(0)
	sls.free()


# ===========================================================================
# Group B — State-machine transitions for MIGRATION (Story 010 canonical paths)
# ===========================================================================

func test_state_machine_allows_loading_to_migration() -> void:
	# Story 010 entry: LOADING → MIGRATION on version mismatch detected
	# mid-pipeline.
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.MIGRATION)
	sls.free()


func test_state_machine_allows_migration_to_ready() -> void:
	# Chain success: MIGRATION → READY (consumers hydrated from migrated payload).
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	sls._transition_to(SaveLoadScript.State.READY)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.READY)
	sls.free()


func test_state_machine_allows_migration_to_corrupt() -> void:
	# Chain failure: MIGRATION → CORRUPT (no migration authored or chain returned null).
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	sls._transition_to(SaveLoadScript.State.CORRUPT)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	sls.free()


func test_state_machine_rejects_migration_to_loading_regression() -> void:
	# Regression guard: the pre-Story-010 allowed-table had MIGRATION → LOADING
	# (re-enter model). Story 010 retired this in favor of MIGRATION → READY |
	# CORRUPT direct transitions. A MIGRATION → LOADING attempt should now
	# push_warning and leave _state unchanged.
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	# Illegal: should be ignored.
	sls._transition_to(SaveLoadScript.State.LOADING)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.MIGRATION)
	sls.free()


func test_state_machine_rejects_ready_to_migration_regression() -> void:
	# Regression guard: the pre-Story-010 allowed-table had READY → MIGRATION.
	# Story 010 narrowed this to LOADING → MIGRATION only (mismatch is
	# detected mid-pipeline, never from a steady READY state). A
	# READY → MIGRATION attempt should now push_warning + leave _state
	# unchanged.
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.READY)
	# Illegal: should be ignored.
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.READY)
	sls.free()


func test_state_machine_full_path_loading_to_migration_to_ready() -> void:
	# End-to-end happy path traversal (chain success scenario).
	var sls: Node = SaveLoadScript.new()
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.UNLOADED)
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	sls._transition_to(SaveLoadScript.State.READY)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.READY)
	sls.free()


func test_state_machine_full_path_loading_to_migration_to_corrupt() -> void:
	# End-to-end failure path traversal (chain returned null scenario).
	var sls: Node = SaveLoadScript.new()
	sls._transition_to(SaveLoadScript.State.LOADING)
	sls._transition_to(SaveLoadScript.State.MIGRATION)
	sls._transition_to(SaveLoadScript.State.CORRUPT)
	# CORRUPT is terminal — verify subsequent transitions are no-ops.
	sls._transition_to(SaveLoadScript.State.READY)
	assert_int(sls.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	sls.free()


# ===========================================================================
# Group C — CURRENT_SAVE_VERSION constant invariants
# ===========================================================================

func test_current_save_version_is_int_two() -> void:
	# Sprint 21+ Prestige V1.0 Story 2 (2026-05-09): bumped V1 → V2.
	# V2 adds prestige_count + prestige_multiplier + retired_hero_records
	# to the HeroRoster save namespace per `prestige-system.md` §C.5.
	# V1→V2 migration body in _migrate_v1_to_v2 defaults the new fields.
	assert_int(SaveLoadScript.CURRENT_SAVE_VERSION).is_equal(2)
