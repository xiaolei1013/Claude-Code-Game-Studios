extends Node

## RuntimeLocaleGuard — Foundation autoload providing locale-related runtime
## constants for the build.
##
## NOTE: Identifiers in this file are deliberately innocuous — none reference
## SaveLoadSystem or its integrity-tag pipeline. Per ADR-0004 §Forbidden Patterns:
## no "key", "secret", "hmac" substrings in any declaration line.
##
## Registered BEFORE SaveLoadSystem in project.godot so that SaveLoadSystem
## can call get_locale_tail() during _ready().
##
## ADR-0004 §HMAC key derivation, §Forbidden Patterns

# ---------------------------------------------------------------------------
# Locale tail fragment
# ---------------------------------------------------------------------------

## 16-byte locale tail fragment C.
## Used by SaveLoadSystem's integrity-tag derivation alongside BootNamespace
## and EngineBootstrap fragments — three-way assembly per ADR-0004.
##
## Declared as [code]static var[/code] — GDScript does not permit [code]PackedByteArray(...)[/code]
## constructor calls in constant expressions. Static var is allocated once per class,
## never mutated, and behaves like a constant for all practical purposes.
##
## ASCII breakdown:
##   0x52 0x75 0x6E 0x74 0x69 0x6D 0x65 0x4C  = "RuntimeL"
##   0x6F 0x63 0x61 0x6C 0x65 0x54 0x6C 0x52  = "ocaleTlR"
##
## ADR-0004 §HMAC key derivation, §Forbidden Patterns
static var _LOCALE_TAIL: PackedByteArray = PackedByteArray([
	0x52, 0x75, 0x6E, 0x74, 0x69, 0x6D, 0x65, 0x4C,
	0x6F, 0x63, 0x61, 0x6C, 0x65, 0x54, 0x6C, 0x52,
])


func _init() -> void:
	pass


## Returns a duplicate of the 16-byte locale tail fragment C.
##
## Returns a copy — callers cannot mutate the source constant.
## Used by SaveLoadSystem's integrity-tag derivation as the third input block,
## concatenated after the element-wise XOR of fragments A and B.
##
## Example:
##   var tail := RuntimeLocaleGuard.get_locale_tail()
##   # tail is 16 bytes; concatenated with xor_ab in _derive_integrity_tags
##
## ADR-0004 §HMAC key derivation
func get_locale_tail() -> PackedByteArray:
	return _LOCALE_TAIL.duplicate()
