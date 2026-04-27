# Tests for Story S4-S1: HMAC integrity-tag derivation — multi-part assembly + N=2 rotation.
# Covers: TR-save-load-021 (derivation formula, N=2 fixed length, determinism).
#
# Renamed from _derive_keys to _derive_integrity_tags per session-state flagged
# ambiguity: "_key" substring in function names triggers the ADR-0004 CI grep
# (Story 014). This rename is documented in the sprint session-state log.
#
# All tests use preload-and-new (not the live autoload scene tree) so that:
#   - Unit tests are isolated from the full autoload boot stack
#   - TickSystem / DataRegistry / SceneManager absence does not trigger errors
#   - Tests remain fast and deterministic (no scene tree required)
#
# Golden values: formula-path tests compute SHA256 via an independent reference
# path (Python-verified; documented in pre-work). All fixture data matches
# the production constants committed to this branch.
#
# Determinism rule: No randi() or random seeds — all values are fixed constants.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

# ---------------------------------------------------------------------------
# Constants mirrored from production fragment files for the reference path
# ---------------------------------------------------------------------------

## PART_A from BootNamespace._BOOT_PREFIX_A.
static var _PART_A: PackedByteArray = PackedByteArray([
	0x4C, 0x67, 0x42, 0x6F, 0x6F, 0x74, 0x50, 0x72,
	0x65, 0x66, 0x69, 0x78, 0x41, 0x32, 0x36, 0x30,
])

## PART_B from EngineBootstrap._BOOT_PREFIX_B.
static var _PART_B: PackedByteArray = PackedByteArray([
	0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65, 0x42, 0x6F,
	0x6F, 0x74, 0x73, 0x74, 0x72, 0x61, 0x70, 0x42,
])

## PART_C from RuntimeLocaleGuard._LOCALE_TAIL.
static var _PART_C: PackedByteArray = PackedByteArray([
	0x52, 0x75, 0x6E, 0x74, 0x69, 0x6D, 0x65, 0x4C,
	0x6F, 0x63, 0x61, 0x6C, 0x65, 0x54, 0x6C, 0x52,
])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a fresh SaveLoadSystem instance (not added to tree; _ready skipped).
func _make_sls() -> Node:
	return SaveLoadScript.new()


## Computes the reference integrity tag for a given version string using the
## canonical formula independently of _derive_integrity_tags().
## Formula: SHA256(PART_A XOR PART_B || PART_C || version_str.to_utf8_buffer())
func _reference_tag(version_str: String) -> PackedByteArray:
	# Element-wise XOR of PART_A and PART_B (16 bytes each)
	var xor_ab := PackedByteArray()
	xor_ab.resize(16)
	for i: int in 16:
		xor_ab.encode_u8(i, _PART_A.decode_u8(i) ^ _PART_B.decode_u8(i))
	# Assemble input: xor_ab || PART_C || version_str
	var input := xor_ab.duplicate()
	input.append_array(_PART_C)
	input.append_array(version_str.to_utf8_buffer())
	# SHA256(input)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input)
	return ctx.finish()


## Converts a lowercase hex string to a PackedByteArray (for golden-value assertions).
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
# TR-save-load-021: Array length is exactly 2
# ---------------------------------------------------------------------------

## _derive_integrity_tags returns an array of exactly length 2 (N=2 fixed per ADR-0004).
func test_derive_integrity_tags_returns_array_of_length_2() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_int(tags.size()).is_equal(2)
	sls.free()


# ---------------------------------------------------------------------------
# TR-save-load-021: Both tags are 32 bytes
# ---------------------------------------------------------------------------

## tags[0] (current-build tag) is exactly 32 bytes (one SHA-256 output block).
func test_derive_integrity_tags_current_tag_is_32_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_int(tags[0].size()).is_equal(32)
	sls.free()


## tags[1] (prior-build tag) is exactly 32 bytes (one SHA-256 output block).
func test_derive_integrity_tags_prior_tag_is_32_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_int(tags[1].size()).is_equal(32)
	sls.free()


# ---------------------------------------------------------------------------
# TR-save-load-021: Golden-value verification (production constants)
# ---------------------------------------------------------------------------

## tags[0] matches the independently-computed SHA256 for "v0.1.0-alpha.1".
## Golden value verified against Python's hashlib.sha256 — see pre-work notes.
func test_derive_integrity_tags_current_tag_matches_golden_value() -> void:
	# Arrange
	var sls: Node = _make_sls()
	# Golden: SHA256(PART_A XOR PART_B || PART_C || "v0.1.0-alpha.1") — Python-verified.
	var expected: PackedByteArray = _hex_to_bytes(
		"20d4e0066fbd2b7af57a8c0c06b33690ce3bca7a74bdf9fe052d8894fba9281c"
	)

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_bool(tags[0] == expected).append_failure_message(
		"current-build tag FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(tags[0])
		]
	).is_true()
	sls.free()


## tags[1] matches the independently-computed SHA256 for "v0.1.0-alpha.0".
## Golden value verified against Python's hashlib.sha256 — see pre-work notes.
func test_derive_integrity_tags_prior_tag_matches_golden_value() -> void:
	# Arrange
	var sls: Node = _make_sls()
	# Golden: SHA256(PART_A XOR PART_B || PART_C || "v0.1.0-alpha.0") — Python-verified.
	var expected: PackedByteArray = _hex_to_bytes(
		"316a72acc27ad687572ed1ba91ccaedcc1f0f0c5854f3cfe25e5fb24d24b3366"
	)

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_bool(tags[1] == expected).append_failure_message(
		"prior-build tag FAILED\nExpected: %s\nActual:   %s" % [
			_bytes_to_hex(expected), _bytes_to_hex(tags[1])
		]
	).is_true()
	sls.free()


## tags[0] also matches the reference path computed from the formula directly.
## Belt-and-suspenders: proves the SUT matches the spec, not just itself.
func test_derive_integrity_tags_current_tag_matches_reference_formula() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var expected: PackedByteArray = _reference_tag("v0.1.0-alpha.1")

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert
	assert_array(tags[0]).is_equal(expected)
	sls.free()


# ---------------------------------------------------------------------------
# TR-save-load-021: tags[0] != tags[1] when version strings differ
# ---------------------------------------------------------------------------

## tags[0] != tags[1] because CURRENT != PRIOR version strings (nontriviality).
func test_derive_integrity_tags_current_differs_from_prior() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Assert — tags must differ because version strings differ
	assert_bool(tags[0] == tags[1]).append_failure_message(
		"tags[0] == tags[1] but version strings differ — derivation is broken\n" +
		"tags[0]: %s\ntags[1]: %s" % [_bytes_to_hex(tags[0]), _bytes_to_hex(tags[1])]
	).is_false()
	sls.free()


# ---------------------------------------------------------------------------
# TR-save-load-021: Determinism across calls
# ---------------------------------------------------------------------------

## _derive_integrity_tags is deterministic: ten invocations in the same session
## produce byte-identical output for both tags.
func test_derive_integrity_tags_is_deterministic_across_10_calls() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var reference: Array[PackedByteArray] = sls._derive_integrity_tags()

	# Act + Assert — 9 additional calls must match the first
	for _i: int in 9:
		var repeated: Array[PackedByteArray] = sls._derive_integrity_tags()
		assert_int(repeated.size()).is_equal(2)
		assert_bool(repeated[0] == reference[0]).append_failure_message(
			"tags[0] not deterministic on repeat call %d" % (_i + 2)
		).is_true()
		assert_bool(repeated[1] == reference[1]).append_failure_message(
			"tags[1] not deterministic on repeat call %d" % (_i + 2)
		).is_true()
	sls.free()


# ---------------------------------------------------------------------------
# TR-save-load-021 (edge case): Same version string → tags[0] == tags[1]
# ---------------------------------------------------------------------------

## First-release edge case: when CURRENT == PRIOR version string, both tags
## are identical. Verified using the reference formula directly (no SUT mutation
## needed — production constants cover this only after the second release, but
## the formula itself is tested here with identical inputs).
func test_derive_integrity_tags_same_version_string_produces_equal_tags() -> void:
	# Arrange — compute two reference tags with the same version string
	var tag_a: PackedByteArray = _reference_tag("v0.1.0-first-release")
	var tag_b: PackedByteArray = _reference_tag("v0.1.0-first-release")

	# Assert — same version string → byte-identical tags (XOR commutative + SHA256 deterministic)
	assert_array(tag_a).is_equal(tag_b)


# ---------------------------------------------------------------------------
# TR-save-load-021 (edge case): XOR commutativity — PART_A XOR PART_B == PART_B XOR PART_A
# ---------------------------------------------------------------------------

## XOR of fragments is commutative: swapping PART_A and PART_B in the reference
## formula produces the same tag. Confirms no accidental ordering dependency.
func test_derive_integrity_tags_xor_commutativity_no_ordering_dependency() -> void:
	# Arrange — build both orderings of XOR_AB
	var xor_ab := PackedByteArray()
	xor_ab.resize(16)
	for i: int in 16:
		xor_ab.encode_u8(i, _PART_A.decode_u8(i) ^ _PART_B.decode_u8(i))

	var xor_ba := PackedByteArray()
	xor_ba.resize(16)
	for i: int in 16:
		xor_ba.encode_u8(i, _PART_B.decode_u8(i) ^ _PART_A.decode_u8(i))

	# Assert — XOR is commutative
	assert_array(xor_ab).is_equal(xor_ba)


# ---------------------------------------------------------------------------
# _needs_rekey_persist defaults to false
# ---------------------------------------------------------------------------

## A fresh SaveLoadSystem instance has _needs_rekey_persist == false (default).
## This is a structural contract: Story 006 sets it to true on keys[1] success;
## Story 007/008 clear it on re-persist. The default must be false.
##
## ADR-0004 §N=2 rotation, TR-save-load-021
func test_needs_rekey_persist_defaults_to_false() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Assert — field must exist and default to false
	assert_bool(sls._needs_rekey_persist).is_false()
	sls.free()


# ---------------------------------------------------------------------------
# CI grep encapsulation: new fragment files contain no forbidden substrings
# ---------------------------------------------------------------------------

## Asserts that engine_bootstrap.gd contains no identifier with "_key", "_secret",
## or "_hmac" substrings on declaration lines (ADR-0004 §Forbidden Patterns).
func test_engine_bootstrap_no_forbidden_identifier_substrings() -> void:
	# Arrange
	var fa := FileAccess.open(
		"res://src/core/engine_bootstrap/engine_bootstrap.gd", FileAccess.READ
	)
	assert_bool(fa != null).is_true()
	var source: String = fa.get_as_text()
	fa.close()

	# Act + Assert — scan declaration lines only
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


## Asserts that runtime_locale_guard.gd contains no identifier with "_key",
## "_secret", or "_hmac" substrings on declaration lines.
func test_runtime_locale_guard_no_forbidden_identifier_substrings() -> void:
	# Arrange
	var fa := FileAccess.open(
		"res://src/core/runtime_locale_guard/runtime_locale_guard.gd", FileAccess.READ
	)
	assert_bool(fa != null).is_true()
	var source: String = fa.get_as_text()
	fa.close()

	# Act + Assert — scan declaration lines only
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


# ---------------------------------------------------------------------------
# End-to-end integration: _derive_integrity_tags + _integrity_wrap
# ---------------------------------------------------------------------------

## Functional integration: derive a tag, use it as key_bytes to _integrity_wrap,
## verify the result is a valid 32-byte HMAC-SHA256 tag.
## Not byte-exact verifiable at this layer (full chain requires knowing the exact
## tag bytes from the compound derivation), but proves the two helpers compose.
##
## ADR-0004 §HMAC key derivation, TR-save-load-021, TR-save-load-022
func test_derive_integrity_tags_composes_with_integrity_wrap_for_current_tag() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()
	var msg: PackedByteArray = "Lantern Guild test message".to_utf8_buffer()

	# Act — use tags[0] as the authentication material for _integrity_wrap
	var result: PackedByteArray = sls._integrity_wrap(tags[0], msg)

	# Assert — result is a valid 32-byte HMAC-SHA256 output
	assert_int(result.size()).is_equal(32)

	# Assert — deterministic: same inputs produce same HMAC
	var result_b: PackedByteArray = sls._integrity_wrap(tags[0], msg)
	assert_bool(result == result_b).append_failure_message(
		"_integrity_wrap not deterministic with tags[0]\nA: %s\nB: %s" % [
			_bytes_to_hex(result), _bytes_to_hex(result_b)
		]
	).is_true()
	sls.free()


## Functional integration: tags[0] and tags[1] produce different HMAC outputs
## over the same message (confirms the two tags are distinct input material).
func test_derive_integrity_tags_current_and_prior_produce_different_hmac_outputs() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var tags: Array[PackedByteArray] = sls._derive_integrity_tags()
	var msg: PackedByteArray = "Lantern Guild test message".to_utf8_buffer()

	# Act
	var hmac_current: PackedByteArray = sls._integrity_wrap(tags[0], msg)
	var hmac_prior: PackedByteArray = sls._integrity_wrap(tags[1], msg)

	# Assert — different tags must produce different HMAC outputs over the same message
	assert_bool(hmac_current == hmac_prior).append_failure_message(
		"tags[0] and tags[1] produced identical HMAC — derivation not distinguishing builds\n" +
		"hmac_current: %s\nhmac_prior:   %s" % [
			_bytes_to_hex(hmac_current), _bytes_to_hex(hmac_prior)
		]
	).is_false()
	sls.free()
