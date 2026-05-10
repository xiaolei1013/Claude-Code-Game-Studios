# RuntimeLocaleGuard public-API coverage tests (US-019 backfill).
#
# RuntimeLocaleGuard is a Foundation autoload (registered BEFORE SaveLoadSystem
# in project.godot) that exposes one pure getter consumed by SaveLoadSystem's
# integrity-tag derivation:
#
#   - get_locale_tail() → 16-byte locale-tail fragment C
#
# The function returns a duplicate() of a class-level static PackedByteArray, so
# the testable invariants are:
#   1. Length is exactly 16 bytes
#   2. Content matches the ASCII bytes documented in the source comments
#      ("RuntimeL" + "ocaleTlR")
#   3. The returned PackedByteArray is a copy — mutating it does NOT affect
#      subsequent calls (so consumers cannot poison the shared static)
#
# The byte values themselves are duplicated in the SaveLoadSystem test suite
# (integrity_tag_derivation_test.gd) as a reference-path constant. If those
# reference paths drift from this file, one of the two definitions has been
# mutated and the integrity-tag guarantees no longer hold. This file is the
# canonical assertion site for the public-API surface.
#
# Test groups:
#   A — get_locale_tail happy path + duplicate invariant edge
extends GdUnitTestSuite


# Expected byte content — mirror of the source-of-truth constants. If the
# source constants change, these must change too (and SaveLoadSystem reference
# constants likewise).

# Declared as `static var` (not `const`) — GDScript does not allow
# PackedByteArray(...) constructor calls in constant expressions. Same rationale
# as the production constants in src/core/runtime_locale_guard/runtime_locale_guard.gd.
static var _EXPECTED_LOCALE_TAIL: PackedByteArray = PackedByteArray([
	0x52, 0x75, 0x6E, 0x74, 0x69, 0x6D, 0x65, 0x4C,  # "RuntimeL"
	0x6F, 0x63, 0x61, 0x6C, 0x65, 0x54, 0x6C, 0x52,  # "ocaleTlR"
])


func _get_runtime_locale_guard() -> Node:
	return get_tree().root.get_node_or_null("RuntimeLocaleGuard")


# ===========================================================================
# Group A — get_locale_tail
# ===========================================================================

func test_get_locale_tail_returns_documented_16_byte_ascii_fragment() -> void:
	# Arrange
	var rlg: Node = _get_runtime_locale_guard()
	assert_object(rlg).is_not_null()

	# Act
	var tail: PackedByteArray = rlg.get_locale_tail()

	# Assert
	assert_int(tail.size()).is_equal(16)
	assert_array(tail).is_equal(_EXPECTED_LOCALE_TAIL)


func test_get_locale_tail_returns_copy_so_mutation_does_not_poison_subsequent_calls() -> void:
	# Arrange — grab one copy and mutate it.
	var rlg: Node = _get_runtime_locale_guard()
	assert_object(rlg).is_not_null()
	var first: PackedByteArray = rlg.get_locale_tail()
	first[0] = 0xFF  # Vandalize the returned buffer.

	# Act — request a fresh copy.
	var second: PackedByteArray = rlg.get_locale_tail()

	# Assert — fresh copy is unaffected by the mutation of the first.
	assert_int(second.size()).is_equal(16)
	assert_int(second[0]).is_equal(0x52)
	assert_array(second).is_equal(_EXPECTED_LOCALE_TAIL)
