# GdUnit4 test runner — wrapper that invokes the canonical CmdTool from
# `addons/gdUnit4/bin/GdUnitCmdTool.gd` with the project's standard test-discovery
# args (run all unit + integration suites; continue past failures; ignore
# headless-mode warnings).
#
# Usage: godot --headless --script tests/gdunit4_runner.gd
# CI uses the direct invocation in .github/workflows/tests.yml — this wrapper
# exists for the documented dev-loop command (coding-standards.md line 63 +
# tests/README.md line 32 + critical-paths.md line 11).
#
# The original script (PR #1 era) referenced a non-existent path
# `res://addons/gdunit4/GdUnitRunner.gd` (lowercase u, no bin/). That bug is
# closed by S5-M2 (TD-005). This file now spawns Godot as a subprocess with
# the canonical CmdTool invocation; exit code is forwarded.
extends SceneTree


func _init() -> void:
	# Verify the addon is present at the canonical path before forking.
	if not FileAccess.file_exists("res://addons/gdUnit4/bin/GdUnitCmdTool.gd"):
		push_error("[gdunit4_runner] GdUnit4 not found at res://addons/gdUnit4/bin/GdUnitCmdTool.gd. " +
			"Install via AssetLib or check addons/gdUnit4/.")
		quit(1)
		return

	# Compose the canonical invocation matching .github/workflows/tests.yml.
	# OS.execute returns the exit code; forward it so CI gates work.
	var godot_path: String = OS.get_executable_path()
	var args: PackedStringArray = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "-d", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
		"--add", "res://tests/unit/",
		"--add", "res://tests/integration/",
		"--continue",
		"--ignoreHeadlessMode",
	]

	var output: Array = []
	var exit_code: int = OS.execute(godot_path, args, output, true)

	# Print captured output so users see test results in the same terminal.
	for line: String in output:
		print(line)

	if exit_code != 0:
		push_warning("[gdunit4_runner] CmdTool exited with code %d. Note: Godot may " % exit_code
			+ "exit non-zero at headless shutdown even when tests pass; verify via the " +
			"\"Statistics:\" / \"Overall Summary:\" lines in the captured output.")

	quit(exit_code)
