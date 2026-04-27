# Tests for Sprint 6 dungeon-run-orchestrator Story 002:
#   - Autoload registration at /root/DungeonRunOrchestrator.
#   - Zero-arg _init invariant (ADR-0003 Amendment #3).
#   - 3 DI setters: set_combat_resolver, set_matchup_resolver, set_error_logger.
#   - Lazy-default in _ready(): unset slots get DefaultMatchupResolver /
#     DefaultCombatResolver instantiated; error_logger stays null.
#   - State enum + run_snapshot fields exposed and initialized correctly.
#
# Covers: TR-orchestrator-023 (autoload + lazy-default), TR-orchestrator-024
#         (3 DI setters + spy-injection-before-_ready).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")


# ===========================================================================
# Group A: TR-023 — autoload registration
# ===========================================================================

func test_dungeon_run_orchestrator_autoload_resolves() -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_bool(orch is Node).is_true()


func test_dungeon_run_orchestrator_registered_in_project_godot() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: int = cfg.load("res://project.godot")
	assert_int(load_err).is_equal(OK)
	var path: String = cfg.get_value("autoload", "DungeonRunOrchestrator", "")
	assert_str(path).is_equal("*res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")


func test_dungeon_run_orchestrator_appears_after_scene_manager_in_project_godot() -> void:
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var idx_scene: int = content.find("SceneManager=")
	var idx_orch: int = content.find("DungeonRunOrchestrator=")
	assert_int(idx_scene).is_greater(0)
	assert_int(idx_orch).is_greater(idx_scene)


# ===========================================================================
# Group B: zero-arg _init (ADR-0003 Amendment #3)
# ===========================================================================

# A non-autoload instance can be constructed with no args; if _init had any
# required parameters, this would error with "Method expected N arguments".
func test_orchestrator_init_has_zero_required_args() -> void:
	var orch: Node = OrchestratorScript.new()
	assert_object(orch).is_not_null()
	orch.free()


# ===========================================================================
# Group C: TR-023 — state field initialized to NO_RUN
# ===========================================================================

func test_orchestrator_state_initial_value_is_no_run() -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_orchestrator_run_snapshot_initial_value_is_null() -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_object(orch.run_snapshot).is_null()


# ===========================================================================
# Group D: TR-024 — DI setters exist and accept RefCounted
# ===========================================================================

func test_set_combat_resolver_replaces_internal_field() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_combat_resolver(spy)
	assert_object(orch._combat_resolver).is_same(spy)
	orch.free()


func test_set_matchup_resolver_replaces_internal_field() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_matchup_resolver(spy)
	assert_object(orch._matchup_resolver).is_same(spy)
	orch.free()


func test_set_error_logger_replaces_internal_field() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_error_logger(spy)
	assert_object(orch._error_logger).is_same(spy)
	orch.free()


# ===========================================================================
# Group E: TR-024 — spy injection BEFORE _ready() survives the lazy-default
# ===========================================================================

func test_injected_combat_resolver_survives_ready_call() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_combat_resolver(spy)
	# Add to scene tree triggers _ready(). Lazy-default must NOT overwrite spy.
	add_child(orch)
	auto_free(orch)
	assert_object(orch._combat_resolver).is_same(spy)


func test_injected_matchup_resolver_survives_ready_call() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_matchup_resolver(spy)
	add_child(orch)
	auto_free(orch)
	assert_object(orch._matchup_resolver).is_same(spy)


func test_injected_error_logger_survives_ready_call() -> void:
	var orch: Node = OrchestratorScript.new()
	var spy: RefCounted = RefCounted.new()
	orch.set_error_logger(spy)
	add_child(orch)
	auto_free(orch)
	assert_object(orch._error_logger).is_same(spy)


# ===========================================================================
# Group F: TR-023 — lazy default instantiates when no spy was injected
# ===========================================================================

func test_lazy_default_combat_resolver_instantiated_in_ready() -> void:
	# No injection. _ready() should produce a DefaultCombatResolver instance.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	assert_object(orch._combat_resolver).is_not_null()
	# Verify it's specifically a DefaultCombatResolver via the stub marker.
	assert_str(orch._combat_resolver.is_stub()).contains("DefaultCombatResolver")


func test_lazy_default_matchup_resolver_instantiated_in_ready() -> void:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	assert_object(orch._matchup_resolver).is_not_null()
	assert_str(orch._matchup_resolver.is_stub()).contains("DefaultMatchupResolver")


func test_lazy_default_error_logger_remains_null_in_ready() -> void:
	# error_logger has NO lazy-default in MVP — push_error/push_warning are
	# the default. _ready() leaves it null unless a spy was injected.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	assert_object(orch._error_logger).is_null()


# ===========================================================================
# Group G: live autoload — lazy-default instances exist
# ===========================================================================

func test_live_autoload_has_lazy_defaults_resolved() -> void:
	# Autoload's _ready already fired at boot. Verify both resolvers are non-null
	# (default stubs since no test injected before boot).
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_object(orch._combat_resolver).is_not_null()
	assert_object(orch._matchup_resolver).is_not_null()


# ===========================================================================
# Group H: setter idempotency / null-safe re-injection
# ===========================================================================

func test_setters_can_be_called_after_ready_to_replace_lazy_default() -> void:
	# Call sequence: _ready installs default → set_combat_resolver(spy) replaces it.
	# This is intentional per the doc-comment "Calls AFTER _ready() are allowed
	# but replace the lazy-default".
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	# After _ready: lazy default is in place.
	var pre_default: RefCounted = orch._combat_resolver
	assert_object(pre_default).is_not_null()
	# Now replace with a spy.
	var spy: RefCounted = RefCounted.new()
	orch.set_combat_resolver(spy)
	assert_object(orch._combat_resolver).is_same(spy)
	# Crucially, the spy is NOT the prior default.
	assert_object(orch._combat_resolver).is_not_same(pre_default)
