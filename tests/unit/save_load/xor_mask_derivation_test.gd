# Tests for Story S4-M5: XOR mask — SHA256-derived seed + chunk-indexed mask stream.
# Covers: TR-save-load-020 (seed derivation + mask stream), TR-save-load-004 (XOR portion).
#
# All tests use preload-and-new (not the live autoload scene tree) so that:
#   - Unit tests are isolated from the full autoload boot stack
#   - TickSystem / DataRegistry / SceneManager absence does not trigger errors
#   - Tests remain fast and deterministic (no scene tree required)
#
# Golden values: seed derivation tests use a reference path (independent HashingContext
# call with hardcoded inputs) as the expected value. This ensures the SUT matches the
# SHA256 specification rather than itself.
#
# Determinism rule: No randi() or random seeds — all values are fixed constants.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

# ---------------------------------------------------------------------------
# Constants mirrored from production code for reference-path construction
# ---------------------------------------------------------------------------

## MAGIC bytes ("LGLD") — must match SaveLoadSystem._MAGIC exactly.
## static var: GDScript does not allow PackedByteArray(...) in const expressions.
static var _MAGIC_BYTES: PackedByteArray = PackedByteArray([0x4C, 0x47, 0x4C, 0x44])

## BootNamespace salt — must match BootNamespace._GAME_NAMESPACE_BYTES exactly.
static var _NAMESPACE_BYTES: PackedByteArray = PackedByteArray([
	0x4C, 0x47, 0x47, 0x55, 0x49, 0x4C, 0x44, 0x53,
	0x4E, 0x53, 0x32, 0x36, 0x30, 0x34, 0x32, 0x35,
])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a fresh SaveLoadSystem instance (not added to tree; _ready skipped).
## auto_free registers the Node for gdunit4 to clean up at test end. Without
## it, each test that calls _make_sls leaks a Node — which is what produced
## the 15 pre-existing "orphans" warning across this 17-test suite (the 2
## tests that don't use _make_sls were the non-orphans). Pattern reference:
## tests/unit/floor_unlock_system/floor_unlock_system_test.gd:_make_floor_unlock_with_stubs.
func _make_sls() -> Node:
	var sls: Node = SaveLoadScript.new()
	auto_free(sls)
	return sls


## Computes the reference seed for a given version using the canonical formula.
## This is the independent reference path — NOT calling _derive_mask_seed.
func _reference_seed(version: int) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(_MAGIC_BYTES)
	var version_bytes := PackedByteArray()
	version_bytes.resize(2)
	version_bytes.encode_u16(0, version)
	ctx.update(version_bytes)
	ctx.update(_NAMESPACE_BYTES)
	return ctx.finish()


## Computes the reference chunk block SHA256(mask_seed || u32_le(chunk_index)).
func _reference_chunk(mask_seed: PackedByteArray, chunk_index: int) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(mask_seed)
	var chunk_bytes := PackedByteArray()
	chunk_bytes.resize(4)
	chunk_bytes.encode_u32(0, chunk_index)
	ctx.update(chunk_bytes)
	return ctx.finish()


# ---------------------------------------------------------------------------
# TR-save-load-020: Seed derivation — length and golden value
# ---------------------------------------------------------------------------

## _derive_mask_seed(1) produces exactly 32 bytes.
func test_derive_mask_seed_version1_returns_32_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var mask_seed: PackedByteArray = sls._derive_mask_seed(1)

	# Assert
	assert_int(mask_seed.size()).is_equal(32)


## _derive_mask_seed(1) matches the reference SHA256(MAGIC || u16_le(1) || NAMESPACE).
## This is the golden-file check — proves all three inputs are load-bearing.
func test_derive_mask_seed_version1_matches_golden_reference() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var expected: PackedByteArray = _reference_seed(1)

	# Act
	var actual: PackedByteArray = sls._derive_mask_seed(1)

	# Assert
	assert_array(actual).is_equal(expected)


## Changing the version produces a different seed (version is load-bearing).
func test_derive_mask_seed_different_versions_produce_different_seeds() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var seed_v1: PackedByteArray = sls._derive_mask_seed(1)
	var seed_v2: PackedByteArray = sls._derive_mask_seed(2)

	# Assert — seeds must differ
	assert_bool(seed_v1 == seed_v2).is_false()


## _derive_mask_seed is deterministic: two calls with the same version produce
## byte-identical output.
func test_derive_mask_seed_is_deterministic() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var seed_a: PackedByteArray = sls._derive_mask_seed(1)
	var seed_b: PackedByteArray = sls._derive_mask_seed(1)

	# Assert
	assert_array(seed_a).is_equal(seed_b)


# ---------------------------------------------------------------------------
# TR-save-load-020 (stream): Mask stream length + chunk structure
# ---------------------------------------------------------------------------

## _generate_mask with length 0 returns an empty array.
func test_generate_mask_zero_length_returns_empty() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var mask_seed: PackedByteArray = _reference_seed(1)

	# Act
	var mask: PackedByteArray = sls._generate_mask(mask_seed,0)

	# Assert
	assert_int(mask.size()).is_equal(0)


## _generate_mask with length 32 returns exactly one full chunk (chunk 0).
func test_generate_mask_length_32_returns_one_full_chunk() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var mask_seed: PackedByteArray = _reference_seed(1)
	var expected: PackedByteArray = _reference_chunk(mask_seed,0)

	# Act
	var mask: PackedByteArray = sls._generate_mask(mask_seed,32)

	# Assert
	assert_int(mask.size()).is_equal(32)
	assert_array(mask).is_equal(expected)


## _generate_mask with length 33 returns chunk 0 + first byte of chunk 1.
func test_generate_mask_length_33_spans_two_chunks() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var mask_seed: PackedByteArray = _reference_seed(1)
	var chunk0: PackedByteArray = _reference_chunk(mask_seed,0)
	var chunk1: PackedByteArray = _reference_chunk(mask_seed,1)
	var expected := PackedByteArray()
	expected.append_array(chunk0)
	expected.append_array(chunk1.slice(0, 1))

	# Act
	var mask: PackedByteArray = sls._generate_mask(mask_seed,33)

	# Assert
	assert_int(mask.size()).is_equal(33)
	assert_array(mask).is_equal(expected)


## _generate_mask with length 100 has the correct chunk structure:
##   bytes [0..32)   == chunk 0
##   bytes [32..64)  == chunk 1
##   bytes [64..96)  == chunk 2
##   bytes [96..100) == first 4 bytes of chunk 3
func test_generate_mask_length_100_chunk_structure_correct() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var mask_seed: PackedByteArray = _reference_seed(1)
	var chunk0: PackedByteArray = _reference_chunk(mask_seed,0)
	var chunk1: PackedByteArray = _reference_chunk(mask_seed,1)
	var chunk2: PackedByteArray = _reference_chunk(mask_seed,2)
	var chunk3: PackedByteArray = _reference_chunk(mask_seed,3)

	# Act
	var mask: PackedByteArray = sls._generate_mask(mask_seed,100)

	# Assert — total length
	assert_int(mask.size()).is_equal(100)
	# Assert — chunk 0: bytes [0..32)
	assert_array(mask.slice(0, 32)).is_equal(chunk0)
	# Assert — chunk 1: bytes [32..64)
	assert_array(mask.slice(32, 64)).is_equal(chunk1)
	# Assert — chunk 2: bytes [64..96)
	assert_array(mask.slice(64, 96)).is_equal(chunk2)
	# Assert — chunk 3 (truncated): bytes [96..100) == first 4 bytes of chunk 3
	assert_array(mask.slice(96, 100)).is_equal(chunk3.slice(0, 4))


## _generate_mask is deterministic: two calls with the same seed+length produce
## byte-identical output.
func test_generate_mask_is_deterministic() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var mask_seed: PackedByteArray = _reference_seed(1)

	# Act
	var mask_a: PackedByteArray = sls._generate_mask(mask_seed,100)
	var mask_b: PackedByteArray = sls._generate_mask(mask_seed,100)

	# Assert
	assert_array(mask_a).is_equal(mask_b)


# ---------------------------------------------------------------------------
# TR-save-load-004 (XOR portion): Self-inverse and edge cases
# ---------------------------------------------------------------------------

## XOR is self-inverse: masking a plaintext twice returns the original bytes.
## Fixture: {"gold": 100} as UTF-8 (12 bytes).
func test_apply_xor_mask_self_inverse_json_fixture() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var plaintext: PackedByteArray = '{"gold": 100}'.to_utf8_buffer()  # 13 bytes
	var mask_seed: PackedByteArray = _reference_seed(1)
	var mask: PackedByteArray = sls._generate_mask(mask_seed,plaintext.size())

	# Act
	var masked: PackedByteArray = sls._apply_xor_mask(plaintext, mask)
	var restored: PackedByteArray = sls._apply_xor_mask(masked, mask)

	# Assert
	assert_array(restored).is_equal(plaintext)


## XOR self-inverse with 1-byte plaintext.
func test_apply_xor_mask_self_inverse_single_byte() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var plaintext := PackedByteArray([0x42])
	var mask_seed: PackedByteArray = _reference_seed(1)
	var mask: PackedByteArray = sls._generate_mask(mask_seed,1)

	# Act
	var masked: PackedByteArray = sls._apply_xor_mask(plaintext, mask)
	var restored: PackedByteArray = sls._apply_xor_mask(masked, mask)

	# Assert
	assert_array(restored).is_equal(plaintext)


## XOR self-inverse with a 32-byte plaintext (exact mask chunk boundary).
func test_apply_xor_mask_self_inverse_exactly_32_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var plaintext := PackedByteArray()
	plaintext.resize(32)
	for i: int in range(32):
		plaintext.encode_u8(i, i)  # [0x00, 0x01, ..., 0x1F]
	var mask_seed: PackedByteArray = _reference_seed(1)
	var mask: PackedByteArray = sls._generate_mask(mask_seed,32)

	# Act
	var masked: PackedByteArray = sls._apply_xor_mask(plaintext, mask)
	var restored: PackedByteArray = sls._apply_xor_mask(masked, mask)

	# Assert
	assert_array(restored).is_equal(plaintext)


## All-zero plaintext still masks to non-zero output (mask stream is pseudo-random noise).
func test_apply_xor_mask_all_zero_plaintext_produces_nonzero() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var plaintext := PackedByteArray()
	plaintext.resize(32)  # 32 zero bytes
	var mask_seed: PackedByteArray = _reference_seed(1)
	var mask: PackedByteArray = sls._generate_mask(mask_seed,32)

	# Act
	var masked: PackedByteArray = sls._apply_xor_mask(plaintext, mask)

	# Assert — masked bytes equal the mask itself (XOR with zero = identity)
	# and the mask is non-zero (SHA256 output of non-zero input is non-zero)
	assert_array(masked).is_equal(mask)
	var all_zero := PackedByteArray()
	all_zero.resize(32)
	assert_bool(masked == all_zero).is_false()


## XOR self-inverse with ~65 KB plaintext (exercises multi-chunk mask generation).
func test_apply_xor_mask_self_inverse_large_payload() -> void:
	# Arrange — 65 KB payload (2048 × 32-byte chunks)
	var sls: Node = _make_sls()
	const LARGE_SIZE: int = 65536
	var plaintext := PackedByteArray()
	plaintext.resize(LARGE_SIZE)
	for i: int in range(LARGE_SIZE):
		plaintext.encode_u8(i, i & 0xFF)
	var mask_seed: PackedByteArray = _reference_seed(1)
	var mask: PackedByteArray = sls._generate_mask(mask_seed,LARGE_SIZE)

	# Act
	var masked: PackedByteArray = sls._apply_xor_mask(plaintext, mask)
	var restored: PackedByteArray = sls._apply_xor_mask(masked, mask)

	# Assert
	assert_int(mask.size()).is_equal(LARGE_SIZE)
	assert_array(restored).is_equal(plaintext)


# ---------------------------------------------------------------------------
# _apply_xor_mask defensive: size mismatch returns empty array
# ---------------------------------------------------------------------------

## Passing mismatched sizes returns an empty array (programmer-error guard).
## NOTE: push_error is called internally; GdUnit4 does not intercept push_error
## as a test failure — the test verifies the return value contract only.
func test_apply_xor_mask_size_mismatch_returns_empty() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var plaintext := PackedByteArray([0x01, 0x02, 0x03])
	var mask := PackedByteArray([0xAA, 0xBB])  # wrong size

	# Act
	var result: PackedByteArray = sls._apply_xor_mask(plaintext, mask)

	# Assert
	assert_int(result.size()).is_equal(0)


# ---------------------------------------------------------------------------
# CI grep encapsulation: no forbidden identifier substrings in source files
# ---------------------------------------------------------------------------

## Asserts that save_load_system.gd contains no identifier with "_key", "_secret",
## or "_hmac" substrings (case-sensitive on identifiers per ADR-0004 §Forbidden Patterns).
## Reads source text directly — checks identifier-level tokens in var/const/func/signal lines.
func test_save_load_system_no_forbidden_identifier_substrings() -> void:
	# Arrange
	var fa := FileAccess.open("res://src/core/save_load_system/save_load_system.gd", FileAccess.READ)
	assert_bool(fa != null).is_true()
	var source: String = fa.get_as_text()
	fa.close()

	# Act + Assert — check identifier-bearing lines for forbidden substrings
	# Split into lines; only examine lines that contain declaration keywords.
	# This avoids false positives from comments/strings explaining threat model.
	var lines: PackedStringArray = source.split("\n")
	var violation_lines: Array[String] = []
	for line: String in lines:
		var stripped: String = line.strip_edges()
		# Only check declaration lines (var/const/func/signal/class)
		var is_declaration: bool = (
			stripped.begins_with("var ") or
			stripped.begins_with("const ") or
			stripped.begins_with("func ") or
			stripped.begins_with("signal ") or
			stripped.begins_with("static var ") or
			stripped.begins_with("class ")
		)
		if not is_declaration:
			continue
		# Check for forbidden identifier substrings
		if "_key" in stripped or "_secret" in stripped or "_hmac" in stripped:
			violation_lines.append(line)

	assert_array(violation_lines).is_empty()


## Asserts that boot_namespace.gd contains no identifier with "_key", "_secret",
## or "_hmac" substrings (case-sensitive per ADR-0004 §Forbidden Patterns).
func test_boot_namespace_no_forbidden_identifier_substrings() -> void:
	# Arrange
	var fa := FileAccess.open("res://src/core/boot_namespace/boot_namespace.gd", FileAccess.READ)
	assert_bool(fa != null).is_true()
	var source: String = fa.get_as_text()
	fa.close()

	# Act + Assert
	var lines: PackedStringArray = source.split("\n")
	var violation_lines: Array[String] = []
	for line: String in lines:
		var stripped: String = line.strip_edges()
		var is_declaration: bool = (
			stripped.begins_with("var ") or
			stripped.begins_with("const ") or
			stripped.begins_with("func ") or
			stripped.begins_with("signal ") or
			stripped.begins_with("static var ") or
			stripped.begins_with("class ")
		)
		if not is_declaration:
			continue
		if "_key" in stripped or "_secret" in stripped or "_hmac" in stripped:
			violation_lines.append(line)

	assert_array(violation_lines).is_empty()
