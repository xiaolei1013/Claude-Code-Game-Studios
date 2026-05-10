# EngineBootstrap public-API coverage tests (US-018 backfill).
#
# EngineBootstrap is a Foundation autoload (registered BEFORE SaveLoadSystem in
# project.godot) that exposes three pure getters consumed by SaveLoadSystem:
#
#   - get_boot_prefix_b()                → 16-byte boot-prefix fragment B
#   - get_current_build_version_string() → compile-time const String
#   - get_prior_build_version_string()   → compile-time const String
#
# get_boot_prefix_b() returns a duplicate() of a class-level static
# PackedByteArray, so the testable invariants are:
#   1. Length is exactly 16 bytes
#   2. Content matches the ASCII bytes documented in the source comments
#   3. The returned PackedByteArray is a copy — mutating it does NOT affect
#      subsequent calls (so consumers cannot poison the shared static)
#
# The two version-string getters are pure const reads. Their testable invariant
# is that they return the documented compile-time const value (not a runtime-
# overridable value) — per ADR-0004 §Forbidden Patterns these MUST remain
# compile-time constants so they cannot be overridden via user://overrides.cfg.
#
# Test groups:
#   A — get_boot_prefix_b               happy path + duplicate invariant edge
#   B — get_current_build_version_string  happy path + non-empty edge
#   C — get_prior_build_version_string    happy path + non-empty edge
extends GdUnitTestSuite


# Expected byte content — mirror of the source-of-truth constants. If the
# source `_BOOT_PREFIX_B` changes, this must change too.
#
# Declared as `static var` (not `const`) — GDScript does not allow
# PackedByteArray(...) constructor calls in constant expressions. Same rationale
# as the production constant in src/core/engine_bootstrap/engine_bootstrap.gd.
static var _EXPECTED_BOOT_PREFIX_B: PackedByteArray = PackedByteArray([
	0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65, 0x42, 0x6F,  # "EngineBo"
	0x6F, 0x74, 0x73, 0x74, 0x72, 0x61, 0x70, 0x42,  # "otstrapB"
])

const _EXPECTED_CURRENT_VERSION: String = "v0.1.0-alpha.1"
const _EXPECTED_PRIOR_VERSION: String = "v0.1.0-alpha.0"


func _get_engine_bootstrap() -> Node:
	return get_tree().root.get_node_or_null("EngineBootstrap")


# ===========================================================================
# Group A — get_boot_prefix_b
# ===========================================================================

func test_get_boot_prefix_b_returns_documented_16_byte_ascii_fragment() -> void:
	# Arrange
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()

	# Act
	var prefix_b: PackedByteArray = eb.get_boot_prefix_b()

	# Assert
	assert_int(prefix_b.size()).is_equal(16)
	assert_array(prefix_b).is_equal(_EXPECTED_BOOT_PREFIX_B)


func test_get_boot_prefix_b_returns_copy_so_mutation_does_not_poison_subsequent_calls() -> void:
	# Arrange — grab one copy and mutate it.
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()
	var first: PackedByteArray = eb.get_boot_prefix_b()
	first[0] = 0xFF  # Vandalize the returned buffer.

	# Act — request a fresh copy.
	var second: PackedByteArray = eb.get_boot_prefix_b()

	# Assert — fresh copy is unaffected by the mutation of the first.
	assert_int(second.size()).is_equal(16)
	assert_int(second[0]).is_equal(0x45)
	assert_array(second).is_equal(_EXPECTED_BOOT_PREFIX_B)


# ===========================================================================
# Group B — get_current_build_version_string
# ===========================================================================

func test_get_current_build_version_string_returns_documented_compile_time_const() -> void:
	# Arrange
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()

	# Act
	var ver: String = eb.get_current_build_version_string()

	# Assert
	assert_str(ver).is_equal(_EXPECTED_CURRENT_VERSION)


func test_get_current_build_version_string_is_non_empty_and_matches_const_table() -> void:
	# Arrange — the function MUST return the same value as the class-level
	# const it reads, on every call (no runtime override path per ADR-0004
	# §Forbidden Patterns).
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()

	# Act
	var first_call: String = eb.get_current_build_version_string()
	var second_call: String = eb.get_current_build_version_string()

	# Assert — non-empty + idempotent across calls.
	assert_str(first_call).is_not_empty()
	assert_str(second_call).is_equal(first_call)


# ===========================================================================
# Group C — get_prior_build_version_string
# ===========================================================================

func test_get_prior_build_version_string_returns_documented_compile_time_const() -> void:
	# Arrange
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()

	# Act
	var prior: String = eb.get_prior_build_version_string()

	# Assert
	assert_str(prior).is_equal(_EXPECTED_PRIOR_VERSION)


func test_get_prior_build_version_string_is_non_empty_and_matches_const_table() -> void:
	# Arrange — the function MUST return the same value as the class-level
	# const it reads, on every call (no runtime override path per ADR-0004
	# §Forbidden Patterns). The prior-version string is load-bearing for
	# SaveLoadSystem's N-1 retry path: drift here breaks save-compat across
	# release boundaries.
	var eb: Node = _get_engine_bootstrap()
	assert_object(eb).is_not_null()

	# Act
	var first_call: String = eb.get_prior_build_version_string()
	var second_call: String = eb.get_prior_build_version_string()

	# Assert — non-empty + idempotent across calls.
	assert_str(first_call).is_not_empty()
	assert_str(second_call).is_equal(first_call)
