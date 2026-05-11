# BootNamespace public-API coverage tests (US-017 backfill).
#
# BootNamespace is a Foundation autoload (rank ≤ 0 informally) that exposes two
# pure getters consumed by SaveLoadSystem:
#
#   - get_namespace_bytes()   → 16-byte product namespace salt (XOR mask seed input)
#   - get_boot_prefix_a()     → 16-byte boot-prefix fragment A (integrity-tag input)
#
# Both functions return a duplicate() of a class-level static PackedByteArray, so
# the testable invariants are:
#   1. Length is exactly 16 bytes
#   2. Content matches the ASCII bytes documented in the source comments
#   3. The returned PackedByteArray is a copy — mutating it does NOT affect
#      subsequent calls (so consumers cannot poison the shared static)
#
# The byte values themselves are duplicated in the SaveLoadSystem test suite
# (xor_mask_derivation_test.gd and integrity_tag_derivation_test.gd) as
# reference-path constants. If those reference paths drift from this file, one
# of the two definitions has been mutated and the integrity-tag / mask seed
# guarantees no longer hold. This file is the canonical assertion site.
#
# Test groups:
#   A — get_namespace_bytes happy path + duplicate invariant edge
#   B — get_boot_prefix_a   happy path + duplicate invariant edge
extends GdUnitTestSuite


# Expected byte content — mirror of the source-of-truth constants. If the
# source constants change, these must change too (and SaveLoadSystem reference
# constants likewise).

# Declared as `static var` (not `const`) — GDScript does not allow
# PackedByteArray(...) constructor calls in constant expressions. Same rationale
# as the production constants in src/core/boot_namespace/boot_namespace.gd.
static var _EXPECTED_NAMESPACE_BYTES: PackedByteArray = PackedByteArray([
	0x4C, 0x47, 0x47, 0x55, 0x49, 0x4C, 0x44, 0x53,  # "LGGUILDS"
	0x4E, 0x53, 0x32, 0x36, 0x30, 0x34, 0x32, 0x35,  # "NS260425"
])

static var _EXPECTED_BOOT_PREFIX_A: PackedByteArray = PackedByteArray([
	0x4C, 0x67, 0x42, 0x6F, 0x6F, 0x74, 0x50, 0x72,  # "LgBootPr"
	0x65, 0x66, 0x69, 0x78, 0x41, 0x32, 0x36, 0x30,  # "efixA260"
])


func _get_boot_namespace() -> Node:
	return get_tree().root.get_node_or_null("BootNamespace")


# ===========================================================================
# Group A — get_namespace_bytes
# ===========================================================================

func test_get_namespace_bytes_returns_documented_16_byte_ascii_salt() -> void:
	# Arrange
	var bn: Node = _get_boot_namespace()
	assert_object(bn).is_not_null()

	# Act
	var ns: PackedByteArray = bn.get_namespace_bytes()

	# Assert
	assert_int(ns.size()).is_equal(16)
	assert_array(ns).is_equal(_EXPECTED_NAMESPACE_BYTES)


func test_get_namespace_bytes_returns_copy_so_mutation_does_not_poison_subsequent_calls() -> void:
	# Arrange — grab one copy and mutate it.
	var bn: Node = _get_boot_namespace()
	assert_object(bn).is_not_null()
	var first: PackedByteArray = bn.get_namespace_bytes()
	first[0] = 0xFF  # Vandalize the returned buffer.

	# Act — request a fresh copy.
	var second: PackedByteArray = bn.get_namespace_bytes()

	# Assert — fresh copy is unaffected by the mutation of the first.
	assert_int(second.size()).is_equal(16)
	assert_int(second[0]).is_equal(0x4C)
	assert_array(second).is_equal(_EXPECTED_NAMESPACE_BYTES)


# ===========================================================================
# Group B — get_boot_prefix_a
# ===========================================================================

func test_get_boot_prefix_a_returns_documented_16_byte_ascii_fragment() -> void:
	# Arrange
	var bn: Node = _get_boot_namespace()
	assert_object(bn).is_not_null()

	# Act
	var prefix_a: PackedByteArray = bn.get_boot_prefix_a()

	# Assert
	assert_int(prefix_a.size()).is_equal(16)
	assert_array(prefix_a).is_equal(_EXPECTED_BOOT_PREFIX_A)


func test_get_boot_prefix_a_returns_copy_so_mutation_does_not_poison_subsequent_calls() -> void:
	# Arrange — grab one copy and mutate it.
	var bn: Node = _get_boot_namespace()
	assert_object(bn).is_not_null()
	var first: PackedByteArray = bn.get_boot_prefix_a()
	first[0] = 0xFF  # Vandalize the returned buffer.

	# Act — request a fresh copy.
	var second: PackedByteArray = bn.get_boot_prefix_a()

	# Assert — fresh copy is unaffected by the mutation of the first.
	assert_int(second.size()).is_equal(16)
	assert_int(second[0]).is_equal(0x4C)
	assert_array(second).is_equal(_EXPECTED_BOOT_PREFIX_A)
