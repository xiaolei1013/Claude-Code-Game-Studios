# Tests for Story S4-M6: HMAC-SHA256 wrapper — RFC 4231 §4.2–4.8 conformance gate.
# Covers: AC-SL-HMAC-01 (BLOCKING gate), TR-save-load-022, TR-save-load-019, ADR-0004.
#
# HIGHEST RISK story in the project. All 7 RFC 4231 test vectors are byte-exact gates.
# A tamper AC passing against a buggy HMAC produces false confidence — per ADR-0004,
# each vector is asserted bit-exactly here before any AC-SL-TAMPER-* AC runs.
#
# All tests use preload-and-new (not the live autoload scene tree) so that:
#   - Unit tests are isolated from the full autoload boot stack
#   - TickSystem / DataRegistry / SceneManager absence does not trigger errors
#   - Tests remain fast and deterministic (no scene tree required)
#
# Determinism rule: No randi() or random seeds — all values are fixed RFC constants.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a fresh SaveLoadSystem instance (not added to tree; _ready skipped).
func _make_sls() -> Node:
	return SaveLoadScript.new()


## Converts a lowercase hex string to a PackedByteArray.
## Input must have even length (each byte = two hex digits).
static func _hex_to_bytes(hex: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	for i: int in range(0, hex.length(), 2):
		bytes.append(("0x" + hex.substr(i, 2)).hex_to_int())
	return bytes


## Converts a PackedByteArray to a lowercase hex string (for failure diagnostics).
static func _bytes_to_hex(bytes: PackedByteArray) -> String:
	var hex := ""
	for b: int in bytes:
		hex += "%02x" % b
	return hex


# ---------------------------------------------------------------------------
# RFC 4231 §4.2 — Test Case 1: short key (20 bytes), short data (8 bytes)
# ---------------------------------------------------------------------------
# Exercises the short-key zero-pad path (key.size() == 20 < 64).
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.2 — 20-byte key of 0x0b, "Hi There" data.
func test_integrity_wrap_rfc4231_tc1_short_key_short_data() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(20)
	for i: int in 20:
		tag_material.encode_u8(i, 0x0b)
	var data: PackedByteArray = "Hi There".to_utf8_buffer()
	var expected: PackedByteArray = _hex_to_bytes(
		"b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC1 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.3 — Test Case 2: ASCII key "Jefe" (4 bytes), medium data
# ---------------------------------------------------------------------------
# Very short key (4 bytes); confirms zero-pad correctness in the low-entropy-key regime.
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.3 — "Jefe" key, "what do ya want for nothing?" data.
func test_integrity_wrap_rfc4231_tc2_ascii_key_medium_data() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material: PackedByteArray = "Jefe".to_utf8_buffer()
	var data: PackedByteArray = "what do ya want for nothing?".to_utf8_buffer()
	var expected: PackedByteArray = _hex_to_bytes(
		"5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC2 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.4 — Test Case 3: 20-byte key of 0xaa, 50-byte data of 0xdd
# ---------------------------------------------------------------------------
# Data length > 32 bytes (crosses one SHA block in the inner hash).
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.4 — 20 bytes of 0xaa key, 50 bytes of 0xdd data.
func test_integrity_wrap_rfc4231_tc3_repeating_key_repeating_data() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(20)
	for i: int in 20:
		tag_material.encode_u8(i, 0xaa)
	var data := PackedByteArray()
	data.resize(50)
	for i: int in 50:
		data.encode_u8(i, 0xdd)
	var expected: PackedByteArray = _hex_to_bytes(
		"773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC3 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.5 — Test Case 4: 25-byte incrementing key 0x01..0x19, 50-byte 0xcd data
# ---------------------------------------------------------------------------
# Non-repeating key pattern; sensitive to endian/byte-order bugs that survive
# repeating-byte tests (TC1–3).
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.5 — incrementing-byte key (0x01..0x19), 50 bytes of 0xcd.
func test_integrity_wrap_rfc4231_tc4_incrementing_key_repeating_data() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(25)
	for i: int in 25:
		tag_material.encode_u8(i, i + 1)  # 0x01, 0x02, ..., 0x19
	var data := PackedByteArray()
	data.resize(50)
	for i: int in 50:
		data.encode_u8(i, 0xcd)
	var expected: PackedByteArray = _hex_to_bytes(
		"82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC4 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.6 — Test Case 5: truncation vector
# ---------------------------------------------------------------------------
# RFC 4231 §4.6 only specifies the first 16 bytes (128-bit truncation) as the
# reference. Our implementation returns the full 32-byte HMAC-SHA256 tag — we
# assert BOTH the full 32 bytes (from the story's computed expected value) AND
# the 16-byte RFC-specified prefix independently, so both are load-bearing gates.
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.6 — 20 bytes of 0x0c key, "Test With Truncation" data.
## Asserts full 32-byte output AND the RFC-specified 16-byte prefix independently.
func test_integrity_wrap_rfc4231_tc5_truncation_vector() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(20)
	for i: int in 20:
		tag_material.encode_u8(i, 0x0c)
	var data: PackedByteArray = "Test With Truncation".to_utf8_buffer()
	# Full 32-byte expected (story-computed; first 16 bytes match RFC 4231 §4.6 truncation).
	var expected_full: PackedByteArray = _hex_to_bytes(
		"a3b6167473100ee06e0c796c2955552bfa6f7c0a6a8aef8b93f860aab0cd20c5"
	)
	# RFC 4231 §4.6 specifies this 16-byte truncated prefix as the normative output.
	var expected_prefix: PackedByteArray = _hex_to_bytes(
		"a3b6167473100ee06e0c796c2955552b"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert — full 32-byte tag
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected_full).append_failure_message(
		"RFC 4231 TC5 full-32-byte FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected_full), _bytes_to_hex(result)
		]
	).is_true()
	# Assert — RFC-specified 16-byte prefix (belt-and-suspenders)
	var result_prefix: PackedByteArray = result.slice(0, 16)
	assert_bool(result_prefix == expected_prefix).append_failure_message(
		"RFC 4231 TC5 16-byte prefix FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected_prefix), _bytes_to_hex(result_prefix)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.7 — Test Case 6: key longer than block size (131 bytes of 0xaa)
# ---------------------------------------------------------------------------
# CRITICAL vector: 131 > 64 triggers the pre-hash path.
# Forgetting to pre-hash, or hashing the wrong data, fails here while
# passing TC1–5. This is the most common HMAC bug class.
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.7 — 131-byte key (triggers pre-hash), 54-byte ASCII data.
func test_integrity_wrap_rfc4231_tc6_long_key_triggers_prehash() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(131)
	for i: int in 131:
		tag_material.encode_u8(i, 0xaa)
	var data: PackedByteArray = "Test Using Larger Than Block-Size Key - Hash Key First".to_utf8_buffer()
	var expected: PackedByteArray = _hex_to_bytes(
		"60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC6 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# RFC 4231 §4.8 — Test Case 7: long key + long data
# ---------------------------------------------------------------------------
# 131-byte key (pre-hash path) + 152-byte data (multiple SHA inner blocks).
# Exercises long-key path AND data spanning multiple SHA blocks in the inner hash;
# high sensitivity to any state-reset bug in the GDScript wrapper.
# ---------------------------------------------------------------------------

## AC-SL-HMAC-01 / RFC 4231 §4.8 — 131-byte key (triggers pre-hash), 152-byte data.
func test_integrity_wrap_rfc4231_tc7_long_key_long_data() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(131)
	for i: int in 131:
		tag_material.encode_u8(i, 0xaa)
	# Exact RFC 4231 §4.8 data string (152 bytes in UTF-8; all ASCII).
	var data: PackedByteArray = (
		"This is a test using a larger than block-size key and a larger than " +
		"block-size data. The key needs to be hashed before being used by the " +
		"HMAC algorithm."
	).to_utf8_buffer()
	var expected: PackedByteArray = _hex_to_bytes(
		"9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2"
	)

	# Act
	var result: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert — length sanity
	assert_int(data.size()).is_equal(152)
	assert_int(result.size()).is_equal(32)
	assert_bool(result == expected).append_failure_message(
		"RFC 4231 TC7 FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(result)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# Sanity — Determinism
# ---------------------------------------------------------------------------

## _integrity_wrap is deterministic: two calls with identical inputs produce
## byte-identical 32-byte output.
func test_integrity_wrap_is_deterministic_same_input_same_output() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(20)
	for i: int in 20:
		tag_material.encode_u8(i, 0x0b)
	var data: PackedByteArray = "Hi There".to_utf8_buffer()

	# Act
	var result_a: PackedByteArray = sls._integrity_wrap(tag_material, data)
	var result_b: PackedByteArray = sls._integrity_wrap(tag_material, data)

	# Assert — outputs must be byte-identical
	assert_int(result_a.size()).is_equal(32)
	assert_bool(result_a == result_b).append_failure_message(
		"Determinism FAILED: same input produced different outputs\nA: %s\nB: %s" % [
			_bytes_to_hex(result_a), _bytes_to_hex(result_b)
		]
	).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# Sanity — Avalanche / negative control
# ---------------------------------------------------------------------------
# HMAC is not self-inverse. A 1-byte change in data must flip the tag entirely
# (statistical sanity check — not RFC-required, but catches gross implementation
# errors such as returning zeros, returning the input, or never updating state).
# ---------------------------------------------------------------------------

## Flipping one byte in data produces a different (non-equal) 32-byte tag.
## Also verifies the self-inverse negative control per story spec §QA:
## _integrity_wrap(k, data) != _integrity_wrap(k, data + [0x00]).
func test_integrity_wrap_avalanche_one_byte_change_flips_tag() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tag_material := PackedByteArray()
	tag_material.resize(20)
	for i: int in 20:
		tag_material.encode_u8(i, 0x0b)
	var data_a: PackedByteArray = "Hi There".to_utf8_buffer()
	# data_b = data_a + one zero byte
	var data_b := data_a.duplicate()
	data_b.append(0x00)

	# Act
	var tag_a: PackedByteArray = sls._integrity_wrap(tag_material, data_a)
	var tag_b: PackedByteArray = sls._integrity_wrap(tag_material, data_b)

	# Assert — tags must differ (any implementation bug returning zeros or a
	# truncated hash collapses here).
	assert_int(tag_a.size()).is_equal(32)
	assert_int(tag_b.size()).is_equal(32)
	assert_bool(tag_a == tag_b).append_failure_message(
		"Avalanche FAILED: adding one byte to data produced identical tag\nTag: %s" % [
			_bytes_to_hex(tag_a)
		]
	).is_false()

	# Count differing bytes (statistical check — expect ~16 of 32 to differ).
	var diff_count: int = 0
	for i: int in 32:
		if tag_a.decode_u8(i) != tag_b.decode_u8(i):
			diff_count += 1
	# Sanity: at least 1 byte must differ (not strictly avalanche, but catches
	# catastrophic bugs). A properly functioning HMAC will normally see ~16/32.
	assert_int(diff_count).is_greater(0)
	sls.free()
