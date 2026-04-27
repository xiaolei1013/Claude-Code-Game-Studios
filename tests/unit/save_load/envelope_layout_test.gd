# Tests for Story S4-M4: Save envelope binary layout + little-endian encode/decode.
# Covers: TR-save-load-002, TR-save-load-003, TR-save-load-024, TR-save-load-047.
#
# All tests use preload-and-new (not the live autoload scene tree) so that:
#   - Unit tests are isolated from the full autoload boot stack
#   - TickSystem / DataRegistry / SceneManager absence does not trigger errors
#   - Tests remain fast and deterministic (no scene tree required)
#
# Determinism rule: No randi() or random seeds — all payload sizes and values are
# fixed constants. "Fuzz" here means multiple predetermined sizes, not truly random.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

# Hard cap constant (TR-save-load-047): max payload = 2 MB - envelope overhead.
const _MAX_PAYLOAD_SIZE: int = 2 * 1024 * 1024 - 44  # 2_097_108 bytes

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a fresh SaveLoadSystem instance (not added to tree; _ready skipped).
func _make_sls() -> Node:
	return SaveLoadScript.new()


## Builds a PackedByteArray filled with a repeating byte value.
func _make_payload(size: int, fill_byte: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(size)
	p.fill(fill_byte)
	return p


# ---------------------------------------------------------------------------
# Test Group 1 — TR-save-load-002: Envelope size and structural byte regions
#
# For synthetic payloads of several sizes N:
#   total size == 12 + N + 32
#   bytes [0..4) == MAGIC "LGLD"
#   bytes [12..12+N) == payload bytes verbatim
#   bytes [12+N..12+N+32) are all zero (HMAC placeholder)
# ---------------------------------------------------------------------------

func test_envelope_size_empty_payload_is_exactly_44_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = PackedByteArray()

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert
	assert_int(envelope.size()).is_equal(44)

	sls.free()


func test_envelope_size_1_byte_payload_is_exactly_45_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(1, 0xAB)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — 12 + 1 + 32 = 45
	assert_int(envelope.size()).is_equal(45)

	sls.free()


func test_envelope_size_511_byte_payload_is_exactly_555_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(511, 0x55)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — 12 + 511 + 32 = 555
	assert_int(envelope.size()).is_equal(555)

	sls.free()


func test_envelope_size_512_byte_payload_is_exactly_556_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(512, 0xFF)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — 12 + 512 + 32 = 556
	assert_int(envelope.size()).is_equal(556)

	sls.free()


func test_envelope_size_65536_byte_payload_is_exactly_65580_bytes() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(65536, 0x42)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — 12 + 65536 + 32 = 65580
	assert_int(envelope.size()).is_equal(65580)

	sls.free()


func test_envelope_magic_bytes_at_offset_0_to_4_are_correct() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(8, 0x00)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — bytes [0..4) == 0x4C 0x47 0x4C 0x44 ("LGLD")
	assert_int(envelope.decode_u8(0)).is_equal(0x4C)
	assert_int(envelope.decode_u8(1)).is_equal(0x47)
	assert_int(envelope.decode_u8(2)).is_equal(0x4C)
	assert_int(envelope.decode_u8(3)).is_equal(0x44)

	sls.free()


func test_envelope_payload_bytes_are_verbatim_at_offset_12() -> void:
	# Arrange — distinctive sentinel bytes at known positions
	var sls: Node = _make_sls()
	var payload: PackedByteArray = PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF])

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — bytes [12..16) == payload verbatim
	assert_int(envelope.decode_u8(12)).is_equal(0xDE)
	assert_int(envelope.decode_u8(13)).is_equal(0xAD)
	assert_int(envelope.decode_u8(14)).is_equal(0xBE)
	assert_int(envelope.decode_u8(15)).is_equal(0xEF)

	sls.free()


func test_envelope_hmac_placeholder_region_is_all_zeros() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(4, 0xFF)
	var hmac_start: int = 12 + 4  # 16

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)

	# Assert — bytes [16..48) are all zero
	for i: int in range(hmac_start, hmac_start + 32):
		assert_int(envelope.decode_u8(i)).is_equal(
			0,
		)

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 2 — TR-save-load-003: Little-endian encoding of header fields
#
# Known input: VERSION=1, FLAGS=0x0001, PAYLOAD_LENGTH=0x12345678
# Expected output bytes verified by direct byte-index inspection.
# ---------------------------------------------------------------------------

func test_header_little_endian_version_1_flags_1_payload_0x12345678() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var hdr: PackedByteArray = sls._compose_header(1, 0x0001, 0x12345678)

	# Assert — exactly 12 bytes
	assert_int(hdr.size()).is_equal(12)

	# VERSION u16 LE at [4..6): 1 → [0x01, 0x00]
	assert_int(hdr.decode_u8(4)).is_equal(0x01)
	assert_int(hdr.decode_u8(5)).is_equal(0x00)

	# FLAGS u16 LE at [6..8): 0x0001 → [0x01, 0x00]
	assert_int(hdr.decode_u8(6)).is_equal(0x01)
	assert_int(hdr.decode_u8(7)).is_equal(0x00)

	# PAYLOAD_LENGTH u32 LE at [8..12): 0x12345678 → [0x78, 0x56, 0x34, 0x12]
	assert_int(hdr.decode_u8(8)).is_equal(0x78)
	assert_int(hdr.decode_u8(9)).is_equal(0x56)
	assert_int(hdr.decode_u8(10)).is_equal(0x34)
	assert_int(hdr.decode_u8(11)).is_equal(0x12)

	sls.free()


func test_header_decode_known_good_12_byte_sequence() -> void:
	# Arrange — [LGLD | version=1 | flags=0 | payload_length=16]
	var sls: Node = _make_sls()
	var raw: PackedByteArray = PackedByteArray([
		0x4C, 0x47, 0x4C, 0x44,  # MAGIC
		0x01, 0x00,               # VERSION = 1 (LE)
		0x00, 0x00,               # FLAGS = 0 (LE)
		0x10, 0x00, 0x00, 0x00,  # PAYLOAD_LENGTH = 16 (LE)
	])

	# Act
	var parsed: Dictionary = sls._parse_header(raw)

	# Assert
	assert_bool(parsed.magic_ok).is_true()
	assert_int(parsed.version).is_equal(1)
	assert_int(parsed.flags).is_equal(0)
	assert_int(parsed.payload_length).is_equal(16)

	sls.free()


func test_header_roundtrip_all_max_values() -> void:
	# Arrange — maximum u16 / u32 values
	var sls: Node = _make_sls()
	var version: int = 0xFFFF
	var flags: int = 0xFFFF
	var payload_length: int = 0xFFFFFFFF

	# Act
	var hdr: PackedByteArray = sls._compose_header(version, flags, payload_length)
	var parsed: Dictionary = sls._parse_header(hdr)

	# Assert
	assert_bool(parsed.magic_ok).is_true()
	assert_int(parsed.version).is_equal(version)
	assert_int(parsed.flags).is_equal(flags)
	assert_int(parsed.payload_length).is_equal(payload_length)

	sls.free()


func test_header_roundtrip_all_zero_values() -> void:
	# Arrange
	var sls: Node = _make_sls()

	# Act
	var hdr: PackedByteArray = sls._compose_header(0, 0, 0)
	var parsed: Dictionary = sls._parse_header(hdr)

	# Assert
	assert_bool(parsed.magic_ok).is_true()
	assert_int(parsed.version).is_equal(0)
	assert_int(parsed.flags).is_equal(0)
	assert_int(parsed.payload_length).is_equal(0)

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 3 — MAGIC check failure
#
# Corrupting bytes [0..4) must cause _parse_header to return magic_ok: false.
# Story 006 converts this to a CORRUPT state transition.
# ---------------------------------------------------------------------------

func test_parse_header_returns_magic_ok_false_when_magic_is_wrong() -> void:
	# Arrange — valid header then overwrite MAGIC with garbage
	var sls: Node = _make_sls()
	var hdr: PackedByteArray = sls._compose_header(1, 0, 64)
	hdr.encode_u8(0, 0xDE)
	hdr.encode_u8(1, 0xAD)
	hdr.encode_u8(2, 0xBE)
	hdr.encode_u8(3, 0xEF)

	# Act
	var parsed: Dictionary = sls._parse_header(hdr)

	# Assert
	assert_bool(parsed.magic_ok).is_false()

	sls.free()


func test_parse_header_returns_magic_ok_false_when_envelope_too_short() -> void:
	# Arrange — fewer than 12 bytes
	var sls: Node = _make_sls()
	var short_bytes: PackedByteArray = PackedByteArray([0x4C, 0x47, 0x4C])  # only 3 bytes

	# Act
	var parsed: Dictionary = sls._parse_header(short_bytes)

	# Assert
	assert_bool(parsed.magic_ok).is_false()
	assert_int(parsed.version).is_equal(0)
	assert_int(parsed.flags).is_equal(0)
	assert_int(parsed.payload_length).is_equal(0)

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 4 — TR-save-load-024: PAYLOAD_LENGTH vs file_length cross-check
# ---------------------------------------------------------------------------

func test_validate_payload_length_match_returns_true_when_correct() -> void:
	# Arrange — 56-byte envelope, PAYLOAD_LENGTH claims 12 (56 - 44 = 12)
	var sls: Node = _make_sls()
	var parsed: Dictionary = {
		"payload_length_claimed": 12,
		"file_length": 56,
	}

	# Act
	var result: bool = sls._validate_payload_length_match(parsed)

	# Assert
	assert_bool(result).is_true()

	sls.free()


func test_validate_payload_length_match_returns_false_when_claimed_too_large() -> void:
	# Arrange — PAYLOAD_LENGTH claims 13 but actual payload is 12 (file=56)
	var sls: Node = _make_sls()
	var parsed: Dictionary = {
		"payload_length_claimed": 13,
		"file_length": 56,
	}

	# Act
	var result: bool = sls._validate_payload_length_match(parsed)

	# Assert
	assert_bool(result).is_false()

	sls.free()


func test_validate_payload_length_match_returns_false_when_file_too_long() -> void:
	# Arrange — PAYLOAD_LENGTH claims 12 but file is 57 (actual payload = 13)
	var sls: Node = _make_sls()
	var parsed: Dictionary = {
		"payload_length_claimed": 12,
		"file_length": 57,
	}

	# Act
	var result: bool = sls._validate_payload_length_match(parsed)

	# Assert
	assert_bool(result).is_false()

	sls.free()


func test_validate_payload_length_match_returns_false_when_file_below_overhead() -> void:
	# Arrange — file shorter than 44 bytes; can never be a valid envelope
	var sls: Node = _make_sls()
	var parsed: Dictionary = {
		"payload_length_claimed": 0,
		"file_length": 43,
	}

	# Act
	var result: bool = sls._validate_payload_length_match(parsed)

	# Assert
	assert_bool(result).is_false()

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 5 — Roundtrip fuzz (deterministic, fixed sizes)
#
# Compose then split with multiple predetermined payload sizes; verify that
# _split_envelope recovers the original masked_payload bytes exactly.
# No randi() — sizes are fixed constants for full determinism.
# ---------------------------------------------------------------------------

func test_roundtrip_compose_split_empty_payload() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = PackedByteArray()

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0001)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert
	assert_int(parts.masked_payload.size()).is_equal(0)
	assert_bool(parts.masked_payload == payload).is_true()
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


func test_roundtrip_compose_split_1_byte_payload() -> void:
	# Arrange
	var sls: Node = _make_sls()
	var payload: PackedByteArray = PackedByteArray([0x7F])

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert
	assert_int(parts.masked_payload.size()).is_equal(1)
	assert_int(parts.masked_payload[0]).is_equal(0x7F)
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


func test_roundtrip_compose_split_256_byte_payload() -> void:
	# Arrange — fill with 0xAA pattern
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(256, 0xAA)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert
	assert_int(parts.masked_payload.size()).is_equal(256)
	assert_bool(parts.masked_payload == payload).is_true()
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


func test_roundtrip_compose_split_1023_byte_payload() -> void:
	# Arrange — boundary before power-of-two
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(1023, 0x55)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert
	assert_int(parts.masked_payload.size()).is_equal(1023)
	assert_bool(parts.masked_payload == payload).is_true()
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


func test_roundtrip_compose_split_65537_byte_payload() -> void:
	# Arrange — just over 64 KB
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(65537, 0x01)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert
	assert_int(parts.masked_payload.size()).is_equal(65537)
	assert_bool(parts.masked_payload == payload).is_true()
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 6 — TR-save-load-047: Hard-cap boundary (2 MB - 44 bytes)
#
# The maximum valid payload size is _ENVELOPE_OVERHEAD bytes below the 2 MB
# hard cap. An envelope at exactly this size must compose and split correctly.
# ---------------------------------------------------------------------------

func test_hard_cap_boundary_max_payload_composes_and_splits_correctly() -> void:
	# Arrange — payload at the 2 MB hard cap boundary
	var sls: Node = _make_sls()
	var payload: PackedByteArray = _make_payload(_MAX_PAYLOAD_SIZE, 0x00)

	# Act
	var envelope: PackedByteArray = sls._compose_envelope(payload, 0x0000)
	var parts: Dictionary = sls._split_envelope(envelope)

	# Assert — total size == 2 MB exactly
	assert_int(envelope.size()).is_equal(2 * 1024 * 1024)
	assert_int(parts.masked_payload.size()).is_equal(_MAX_PAYLOAD_SIZE)
	assert_bool(_validate_length_match_from_parts(parts)).is_true()

	sls.free()


# ---------------------------------------------------------------------------
# Test Group 7 — _split_envelope on undersized input
#
# Files shorter than 44 bytes (the envelope overhead) cannot be valid.
# _split_envelope must not crash and must return safe empty fields.
# ---------------------------------------------------------------------------

func test_split_envelope_on_too_short_input_returns_empty_payload_and_hmac() -> void:
	# Arrange — only 10 bytes; below _ENVELOPE_OVERHEAD (44)
	var sls: Node = _make_sls()
	var tiny: PackedByteArray = _make_payload(10, 0xCC)

	# Act
	var parts: Dictionary = sls._split_envelope(tiny)

	# Assert — payload and HMAC regions must be empty (no crash)
	assert_int(parts.masked_payload.size()).is_equal(0)
	assert_int(parts.footer_tag.size()).is_equal(0)
	assert_int(parts.file_length).is_equal(10)

	sls.free()


# ---------------------------------------------------------------------------
# Private helper — mirrors _validate_payload_length_match logic for test use
# ---------------------------------------------------------------------------

func _validate_length_match_from_parts(parts: Dictionary) -> bool:
	var claimed: int = parts.get("payload_length_claimed", -1)
	var file_length: int = parts.get("file_length", -1)
	if claimed < 0 or file_length < 44:
		return false
	return claimed == (file_length - 44)
