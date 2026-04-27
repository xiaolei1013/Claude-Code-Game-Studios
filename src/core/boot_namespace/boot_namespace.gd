extends Node

## BootNamespace — Foundation autoload providing the per-product namespace salt
## used by SaveLoadSystem's XOR mask derivation.
##
## NOTE: This is a NAMESPACE, not a "key" or "secret". It is committed alongside
## the binary and is regenerated per shipped product line. It provides
## product-scoped determinism for the mask stream — NOT confidentiality.
## Per ADR-0004 §Risk row: XOR is obfuscation, not encryption.
##
## Registered BEFORE TickSystem in project.godot (rank ≤ 0 informally) so that
## SaveLoadSystem (rank 2) can call get_namespace_bytes() during _ready().
##
## Comments in this file and its consumers MUST NOT use "secrecy" or "encrypts"
## language. Use "obfuscates" or "namespace-scrambles" — threat-model honest.
##
## ADR-0004 §Forbidden Patterns

# 16 bytes; deterministic; product-scoped. Hand-authored once per product.
# CI grep for forbidden substrings (in identifier names) MUST find zero matches.
#
# ASCII breakdown:
#   0x4C 0x47 0x47 0x55 0x49 0x4C 0x44 0x53  = "LGGUILDS" — Lantern Guild Studios product line
#   0x4E 0x53 0x32 0x36 0x30 0x34 0x32 0x35  = "NS260425" — namespace 2026-04-25
## Declared as [code]static var[/code] — GDScript does not permit [code]PackedByteArray(...)[/code]
## constructor calls in constant expressions. Static var is allocated once per class,
## never mutated, and behaves like a constant for all practical purposes.
static var _GAME_NAMESPACE_BYTES: PackedByteArray = PackedByteArray([
	0x4C, 0x47, 0x47, 0x55, 0x49, 0x4C, 0x44, 0x53,
	0x4E, 0x53, 0x32, 0x36, 0x30, 0x34, 0x32, 0x35,
])


func _init() -> void:
	pass


## Returns a duplicate of the 16-byte product namespace salt.
##
## Returns a copy — callers cannot mutate the source constant.
## Use this to provide the namespace input to SaveLoadSystem's mask derivation.
##
## Example:
##   var ns := BootNamespace.get_namespace_bytes()
##   # ns is 16 bytes; use as input to _derive_mask_seed
##
## ADR-0004 §Forbidden Patterns, §XOR mask derivation
func get_namespace_bytes() -> PackedByteArray:
	return _GAME_NAMESPACE_BYTES.duplicate()


## Additional 16-byte fragment used by SaveLoadSystem's integrity-tag derivation.
## Non-suggestive identifier per ADR-0004 §Forbidden Patterns.
##
## Declared as [code]static var[/code] — GDScript does not permit [code]PackedByteArray(...)[/code]
## constructor calls in constant expressions. Static var is allocated once per class,
## never mutated, and behaves like a constant for all practical purposes.
##
## ASCII breakdown:
##   0x4C 0x67 0x42 0x6F 0x6F 0x74 0x50 0x72  = "LgBootPr"
##   0x65 0x66 0x69 0x78 0x41 0x32 0x36 0x30  = "efixA260"
##
## ADR-0004 §HMAC key derivation, §Forbidden Patterns
static var _BOOT_PREFIX_A: PackedByteArray = PackedByteArray([
	0x4C, 0x67, 0x42, 0x6F, 0x6F, 0x74, 0x50, 0x72,
	0x65, 0x66, 0x69, 0x78, 0x41, 0x32, 0x36, 0x30,
])


## Returns a duplicate of the 16-byte boot prefix fragment A.
##
## Returns a copy — callers cannot mutate the source constant.
## Used alongside BootNamespace's engine-bootstrap and locale fragments in
## SaveLoadSystem's integrity-tag derivation (three-way assembly per ADR-0004).
##
## Example:
##   var prefix_a := BootNamespace.get_boot_prefix_a()
##   # prefix_a is 16 bytes; element-wise XOR with prefix B in _derive_integrity_tags
##
## ADR-0004 §HMAC key derivation
func get_boot_prefix_a() -> PackedByteArray:
	return _BOOT_PREFIX_A.duplicate()
