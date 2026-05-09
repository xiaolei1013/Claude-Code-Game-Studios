class_name MainRoot
extends Control

## MainRoot — persistent root of the always-loaded scene tree.
##
## Extends Control (not Node) so that the `theme` property exists and the
## single canonical parchment theme cascades to every Control descendant.
## (Node does not expose `theme`; only Control and Window do in Godot 4.x.
## The story spec says "MainRoot.theme = preload(...)" which requires Control.)
##
## ADR-0007: Persistent root scene architecture
## ADR-0008: Parchment theme preload cascade
##
## IMPORTANT — PROCESS MODE NOTE (ADR-0007 Risks Note 4):
## Screen children are added to ScreenContainer at runtime. ScreenContainer has
## process_mode = PROCESS_MODE_PAUSABLE (value 1), so all Screen children will pause when
## `get_tree().paused = true` is set by SceneManager. Any child node inside a
## Screen that MUST continue running during a modal overlay pause (e.g., idle
## particles, persistent counter tweens, looping background animations) MUST
## explicitly override its own process_mode to PROCESS_MODE_ALWAYS. Do not rely
## on ScreenContainer's mode cascading downward in the "always runs" direction —
## it does not; PAUSABLE freezes everything below it unless overridden.


## No public API — all scene routing flows through SceneManager (Story 002).
## Do not add business logic to this script.
##
## Boot-wiring contract (Story 005b — tick-system):
## On the production main-scene path (parent == /root), `_ready()` calls
## `SaveLoadSystem.request_full_load("boot")` then
## `TickSystem.bootstrap_offline_replay()` in that order. The order is locked:
## the load must complete (or fail to first-launch) BEFORE the replay computes
## Formula D.2, since the replay's anchor reads `_last_persist_unix` and
## `_session_high_water` which are populated by SaveLoadSystem hydration.
##
## Test-fixture isolation: when MainRoot is added under any parent OTHER than
## the SceneTree root (e.g., a test suite's auto_free child), the boot wiring
## is SKIPPED. This is structural (parent-pointer check), not flag-based — no
## exported field for tests to forget to set. Production main-scene MainRoot
## is parented directly under `/root` per `project.godot::run/main_scene`.
func _ready() -> void:
	theme = preload("res://assets/ui/parchment_theme.tres")
	_bootstrap_save_load_and_offline_replay()


## Story 005b — invokes the cold-launch boot sequence on the production
## main-scene path.
##
## Skipped under test fixtures (parent != /root). Defensive against missing
## autoloads (logs `push_warning` and short-circuits). Both calls are
## process-scoped one-shots; subsequent invocations in the same process are
## no-ops, so a double `_ready()` (e.g., scene change re-instantiation in
## an unexpected flow) does not double-boot.
##
## ADR-0005 §"Cold-launch offline-replay path", ADR-0007, TR-time-016 + TR-time-030.
func _bootstrap_save_load_and_offline_replay() -> void:
	# Test-fixture isolation guard: only the production main scene is parented
	# directly under /root. Test fixtures add MainRoot via `add_child(inst)`
	# from a test suite Node, so parent != /root.
	if get_parent() != get_tree().root:
		return
	var save_load: Node = get_node_or_null("/root/SaveLoadSystem")
	if save_load == null:
		push_warning(
			"MainRoot._bootstrap_save_load_and_offline_replay: " +
			"SaveLoadSystem missing at /root/SaveLoadSystem — boot wiring " +
			"skipped. This indicates an autoload boot-order failure."
		)
		return
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	if tick_system == null:
		push_warning(
			"MainRoot._bootstrap_save_load_and_offline_replay: " +
			"TickSystem missing at /root/TickSystem — boot wiring skipped. " +
			"This indicates an autoload boot-order failure."
		)
		return
	# Order is LOCKED: load first (populates TickSystem's _last_persist_unix
	# and _session_high_water via consumer hydration), then bootstrap-replay
	# (reads those fields for Formula D.2). See Story 005b ADR §sequence.
	save_load.request_full_load("boot")
	tick_system.bootstrap_offline_replay()
