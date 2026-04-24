## Godot 4.6 Autoload + ProjectSettings Probe
##
## Purpose: empirically verify three engine-idiom claims that have been
## asserted and contradicted across Floor Unlock #16 review Passes 6/7/8/9:
##
##   Claim 1 (Pass-8 godot-specialist + Pass-9 godot-gdscript + godot-specialist convergence):
##     Rank-N autoload can connect to rank-(N+1) autoload's signal in its
##     own `_ready()`. All autoload nodes are added to the scene tree before
##     any `_ready()` fires.
##
##   Claim 2 (Pass-8 user decision D1 + Pass-9 cross-model verification):
##     `ProjectSettings.set_initial_value(key, default)` +
##     `ProjectSettings.add_property_info({...})` +
##     `ProjectSettings.get_setting(key, default)` registers a custom key
##     that appears in the editor Project Settings UI after the first
##     game launch registers it.
##
##   Claim 3 (Pass-9 3-specialist cross-model CONCERN closure):
##     `PROPERTY_HINT_NONE` is the correct hint for a TYPE_STRING key
##     where `hint_string` is descriptive documentation (not an in-field
##     placeholder). `PROPERTY_HINT_PLACEHOLDER_TEXT` renders the hint
##     as greyed-out placeholder text inside the input field — wrong for
##     descriptive help.
##
## How to run this probe:
##
##   1. Create a scratch Godot 4.6 project (File → New Project).
##   2. Copy this file to the project root as `autoload_probe.gd`.
##   3. Open `project.godot` and add the two autoload singletons below
##      (Project → Project Settings → Autoload tab). Register in this
##      order — names matter for rank ordering:
##
##        Rank 1: Node   "ProbeSource"  script: probe_source.gd   (see below)
##        Rank 2: Node   "ProbeSink"    script: probe_sink.gd     (see below)
##
##   4. Run the project (F5). Watch stdout for the probe output.
##   5. Close the game, re-open Project Settings → search for
##      "probe_registration/test_key". Verify it appears under a custom
##      "Probe Registration" category. Verify the hint_string appears as
##      tooltip/description, NOT as in-field placeholder overlay.
##   6. Record findings in `docs/engine-reference/godot/modules/autoload.md`.
##
## This script is TEMPLATE prose. The two helper scripts (probe_source.gd
## + probe_sink.gd) are defined below as string constants — copy them into
## separate files in the scratch project.
##
## Authored: 2026-04-21 after Floor Unlock #16 Pass-9 — in response to the
## three-consecutive-wrong-engine-idiom-claim pattern (Pass-6 @export,
## Pass-7 bare get_setting, Pass-8 PROPERTY_HINT_PLACEHOLDER_TEXT).
## The probe exists BECAUSE cross-model specialist convergence alone has
## failed three times; only empirical verification is authoritative.

extends Node

# ---------------------------------------------------------------------------
# probe_source.gd — Rank 1 autoload template
# ---------------------------------------------------------------------------
#
#   extends Node
#
#   signal probe_signal_fired(payload: int)
#
#   func _ready() -> void:
#       print("[PROBE] ProbeSource._ready() fired at tree_time=", Time.get_ticks_msec())
#       # Emit deferred so ProbeSink's _ready() can subscribe first and catch it.
#       call_deferred("_emit_test_signal")
#
#   func _emit_test_signal() -> void:
#       print("[PROBE] ProbeSource emitting probe_signal_fired(42)")
#       probe_signal_fired.emit(42)

# ---------------------------------------------------------------------------
# probe_sink.gd — Rank 2 autoload template
# ---------------------------------------------------------------------------
#
#   extends Node
#
#   func _ready() -> void:
#       print("[PROBE] ProbeSink._ready() fired at tree_time=", Time.get_ticks_msec())
#
#       # CLAIM 1 TEST: can rank-2 connect to rank-1's signal in its own _ready()?
#       # Expected per Pass-9 cross-model verdict: YES — ProbeSource node exists
#       # in the tree before any _ready() fires, so the signal object is addressable.
#       var source_exists := get_node_or_null("/root/ProbeSource")
#       print("[PROBE] ProbeSink sees /root/ProbeSource node: ", source_exists != null)
#
#       if source_exists:
#           # Bare-identifier autoload lookup — verifies autoload name resolution.
#           print("[PROBE] ProbeSink using bare identifier: ProbeSource == source_exists: ",
#                 ProbeSource == source_exists)
#           # Connect synchronously (default flags = 0, NOT CONNECT_DEFERRED).
#           ProbeSource.probe_signal_fired.connect(_on_probe_signal)
#           print("[PROBE] ProbeSink connected to probe_signal_fired")
#
#       # CLAIM 2 TEST: register a custom ProjectSettings key.
#       # After first launch, the key should appear in editor Project Settings UI
#       # under a "Probe Registration" category (category derived from key prefix).
#       var key := "probe_registration/test_key"
#       if not ProjectSettings.has_setting(key):
#           ProjectSettings.set_setting(key, "default_value_xyz")
#       ProjectSettings.set_initial_value(key, "default_value_xyz")
#       ProjectSettings.add_property_info({
#           "name": key,
#           "type": TYPE_STRING,
#           "hint": PROPERTY_HINT_NONE,
#           "hint_string": "Descriptive help text — should appear as TOOLTIP/DESCRIPTION, NOT as in-field placeholder",
#       })
#       print("[PROBE] ProjectSettings registration complete for key=", key)
#       print("[PROBE] ProjectSettings.get_setting(key) = ",
#             ProjectSettings.get_setting(key, "fallback_if_missing"))
#
#   func _on_probe_signal(payload: int) -> void:
#       print("[PROBE] ProbeSink received probe_signal_fired(", payload, ") — CLAIM 1 CONFIRMED")

# ---------------------------------------------------------------------------
# Expected stdout order if all three claims hold:
# ---------------------------------------------------------------------------
#   [PROBE] ProbeSource._ready() fired at tree_time=<T1>
#   [PROBE] ProbeSink._ready() fired at tree_time=<T2>        (T2 >= T1; ranks fire in order)
#   [PROBE] ProbeSink sees /root/ProbeSource node: True       (CLAIM 1: tree has both nodes)
#   [PROBE] ProbeSink using bare identifier: ... == ... True  (autoload name resolution works)
#   [PROBE] ProbeSink connected to probe_signal_fired          (connection succeeds — no crash)
#   [PROBE] ProjectSettings registration complete for key=...
#   [PROBE] ProjectSettings.get_setting(key) = default_value_xyz
#   [PROBE] ProbeSource emitting probe_signal_fired(42)        (deferred emit runs next frame)
#   [PROBE] ProbeSink received probe_signal_fired(42) — CLAIM 1 CONFIRMED
#
# If any of these lines are missing OR appear in the wrong order, a claim is wrong.
# Document findings in docs/engine-reference/godot/modules/autoload.md.

func _ready() -> void:
	push_error("This file is DOCUMENTATION ONLY. Copy probe_source.gd + probe_sink.gd " +
			   "into a scratch Godot project as autoloads (see header comment for setup).")
	get_tree().quit(1)
