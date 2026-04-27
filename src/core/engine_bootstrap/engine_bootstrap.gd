extends Node

## EngineBootstrap — Foundation autoload providing engine bootstrap constants
## including the build-version identifiers and an additional namespace fragment.
##
## NOTE: Identifiers in this file are deliberately innocuous — none reference
## SaveLoadSystem or its integrity-tag pipeline. Per ADR-0004 §Forbidden Patterns:
## no "key", "secret", "hmac" substrings in any declaration line.
##
## Registered BEFORE SaveLoadSystem in project.godot so that SaveLoadSystem
## can call get_boot_prefix_b() and version-string getters during _ready().
##
## ADR-0004 §HMAC key derivation, §Forbidden Patterns

# ---------------------------------------------------------------------------
# Build-version identifiers
# ---------------------------------------------------------------------------

## Current build version string — compile-time const per ADR-0004.
## On each release, the build pipeline updates CURRENT_BUILD_VERSION_STRING
## and moves its prior value into PRIOR_BUILD_VERSION_STRING.
##
## FORBIDDEN: Reading this value from a file, ProjectSettings, or OS.get_environment()
## at runtime — must remain a compile-time const so it cannot be overridden by an
## attacker's user://overrides.cfg (ADR-0004 §HMAC key derivation).
##
## ADR-0004 §HMAC key derivation, TR-save-load-021
const CURRENT_BUILD_VERSION_STRING: String = "v0.1.0-alpha.1"

## Prior build version string — compile-time const per ADR-0004.
## Preserves the previous release's version identifier for N-1 fallback
## compatibility. SaveLoadSystem uses this to derive the prior-build integrity
## tag (tags[1]) so a save signed under the prior build can still be verified.
##
## First-release edge case: defaults to the same value as CURRENT_BUILD_VERSION_STRING
## so tags[0] == tags[1]; the N-1 retry is redundant but harmless. Subsequent
## patches populate a real prior value (ADR-0004 §N=2 rotation).
##
## FORBIDDEN: Reading this value from the save file — attacker-controllable key
## material would produce a trivial bypass (ADR-0004 §Forbidden Patterns).
##
## ADR-0004 §HMAC key derivation, §N=2 rotation, TR-save-load-021
const PRIOR_BUILD_VERSION_STRING: String = "v0.1.0-alpha.0"

# ---------------------------------------------------------------------------
# Bootstrap fragment B
# ---------------------------------------------------------------------------

## 16-byte bootstrap fragment B.
## Paired with BootNamespace._BOOT_PREFIX_A via element-wise XOR in
## SaveLoadSystem's integrity-tag derivation (ADR-0004 three-way assembly).
##
## Declared as [code]static var[/code] — GDScript does not permit [code]PackedByteArray(...)[/code]
## constructor calls in constant expressions. Static var is allocated once per class,
## never mutated, and behaves like a constant for all practical purposes.
##
## ASCII breakdown:
##   0x45 0x6E 0x67 0x69 0x6E 0x65 0x42 0x6F  = "EngineBo"
##   0x6F 0x74 0x73 0x74 0x72 0x61 0x70 0x42  = "otstrapB"
##
## ADR-0004 §HMAC key derivation, §Forbidden Patterns
static var _BOOT_PREFIX_B: PackedByteArray = PackedByteArray([
	0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65, 0x42, 0x6F,
	0x6F, 0x74, 0x73, 0x74, 0x72, 0x61, 0x70, 0x42,
])


func _init() -> void:
	pass


## Returns a duplicate of the 16-byte bootstrap prefix fragment B.
##
## Returns a copy — callers cannot mutate the source constant.
## Used by SaveLoadSystem's integrity-tag derivation: element-wise XOR with
## BootNamespace.get_boot_prefix_a() to produce the first 16-byte input block.
##
## Example:
##   var prefix_b := EngineBootstrap.get_boot_prefix_b()
##   # prefix_b is 16 bytes
##
## ADR-0004 §HMAC key derivation
func get_boot_prefix_b() -> PackedByteArray:
	return _BOOT_PREFIX_B.duplicate()


## Returns the current build version string (compile-time const).
##
## Example:
##   var ver := EngineBootstrap.get_current_build_version_string()
##   # ver == "v0.1.0-alpha.1"
##
## ADR-0004 §HMAC key derivation, TR-save-load-021
func get_current_build_version_string() -> String:
	return CURRENT_BUILD_VERSION_STRING


## Returns the prior build version string (compile-time const).
##
## Example:
##   var prior := EngineBootstrap.get_prior_build_version_string()
##   # prior == "v0.1.0-alpha.0"
##
## ADR-0004 §HMAC key derivation, §N=2 rotation, TR-save-load-021
func get_prior_build_version_string() -> String:
	return PRIOR_BUILD_VERSION_STRING
