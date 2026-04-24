# Story 002: Save envelope binary layout + little-endian encode/decode

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-002, TR-save-load-003, TR-save-load-024, TR-save-load-047
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — envelope byte layout)
**ADR Decision Summary**: Every save file at `user://save_slot_1.dat` is exactly 44 + PAYLOAD_LENGTH bytes: 12-byte header (MAGIC "LGLD" 4B + VERSION u16 LE + FLAGS u16 LE + PAYLOAD_LENGTH u32 LE) + PAYLOAD (variable) + 32-byte HMAC footer. PAYLOAD_LENGTH lives inside the HMAC-protected region.

**Engine**: Godot 4.6 | **Risk**: LOW (pure byte-manipulation math)
**Engine Notes**: `PackedByteArray.encode_u8(offset, value) -> void` / `encode_u16(offset, value) -> void` / `encode_u32(offset, value) -> void` are the canonical little-endian writers (Pass-5D 2026-04-21 confirmed); `decode_u16(offset) -> int` / `decode_u32(offset) -> int` mirror on load. No endianness ambiguity.

**Control Manifest Rules (Foundation Layer, save envelope)**:
- **Required**: Envelope layout `MAGIC ("LGLD" 0x4C4C474C44, 4 bytes) + VERSION u16 LE + FLAGS u16 LE + PAYLOAD_LENGTH u32 LE + UTF-8 JSON payload (XOR-masked) + 32-byte HMAC-SHA256`. Total = 44 + PAYLOAD_LENGTH bytes. All header fields little-endian via `encode_u8/u16/u32`; decode via `decode_u16/u32`. On HMAC pass, assert `PAYLOAD_LENGTH == file_length - 44`.
- **Guardrail**: Save file size <20 KB MVP / <200 KB V1.0 [BUDGET].

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `const _MAGIC := PackedByteArray([0x4C, 0x47, 0x4C, 0x44])` ("LGLD")
- [ ] `const _HEADER_SIZE := 12`, `const _HMAC_SIZE := 32`, `const CURRENT_SAVE_VERSION: int = 1`
- [ ] `_compose_header(version: int, flags: int, payload_length: int) -> PackedByteArray` produces exactly 12 bytes in the canonical order
- [ ] `_parse_header(envelope: PackedByteArray) -> Dictionary` returns `{magic_ok: bool, version: int, flags: int, payload_length: int}` by reading offsets [0..4), [4..6), [6..8), [8..12)
- [ ] Round-trip: `_parse_header(_compose_header(v, f, n))` reproduces `{v, f, n}` for all 16-bit / 32-bit values
- [ ] `_compose_envelope(masked_payload, flags) -> PackedByteArray` returns header (12B) + payload + 32B placeholder-zero HMAC region, total `12 + payload.size() + 32` bytes
- [ ] `_split_envelope(envelope) -> Dictionary` returns `{header_bytes, masked_payload, footer_hmac, payload_length_claimed, file_length}`; computes `payload_length_actual = file_length - 44`
- [ ] Post-HMAC assertion helper: `_validate_payload_length_match(parsed) -> bool` returns `PAYLOAD_LENGTH == file_length - 44`

---

## Implementation Notes

- Writer side uses `PackedByteArray.encode_u8(0, 0x4C)` etc., OR pre-seeds a fixed-size buffer via `bytes.resize(12)` then writes via `encode_*`; prefer the latter for clarity
- All widths fixed: VERSION is u16 (allows 65 535 schema versions; sufficient indefinitely); FLAGS is u16 (16 bit flags available; only bit 0 `save_is_flagged_tampered` used in V1.0); PAYLOAD_LENGTH is u32 (4 GB ceiling, far above the 2 MB hard cap at TR-save-load-047)
- MAGIC comparison uses `bytes.slice(0, 4) == _MAGIC` (PackedByteArray equality)
- The HMAC footer occupies the last 32 bytes unconditionally; callers do NOT use PAYLOAD_LENGTH to locate the footer — they use `file_length - 32` (Rule 2 DoS defense; full enforcement in Story 006)
- Zero-pad the HMAC slot in `_compose_envelope`; Story 004/006 overwrites it with the computed tag
- Unit tests use synthetic payloads of `PackedByteArray()` (empty), 1 byte, 511 bytes, 512 bytes, 65 536 bytes, and `max_payload_size_bytes` hard-cap boundary (2 MB) to verify size math

---

## Out of Scope

- Story 003: XOR mask generation
- Story 004: HMAC implementation
- Story 006: validation order + DoS-safe buffer sizing enforcement
- Story 008: atomic write to disk

---

## QA Test Cases

- **TR-save-load-002**: Envelope byte layout
  - **Given**: A synthetic masked payload `p` of length N
  - **When**: `_compose_envelope(p, 0x0000)` runs
  - **Then**: Result size is exactly `12 + N + 32`; bytes [0..4) == `[0x4C, 0x47, 0x4C, 0x44]`; bytes [12..12+N) == `p`; bytes [12+N .. 12+N+32) are all zero (HMAC placeholder)
  - **Edge cases**: N=0 (empty payload, still 44 bytes total); N=1; N at 2 MB hard cap

- **TR-save-load-003**: Little-endian encoding of all header fields
  - **Given**: VERSION=1, FLAGS=0x0001, PAYLOAD_LENGTH=0x12345678
  - **When**: `_compose_header(1, 1, 0x12345678)` runs
  - **Then**: Bytes [4..6) == `[0x01, 0x00]`; bytes [6..8) == `[0x01, 0x00]`; bytes [8..12) == `[0x78, 0x56, 0x34, 0x12]`
  - **Edge cases**: All-max (VERSION=0xFFFF, FLAGS=0xFFFF, PAYLOAD_LENGTH=0xFFFFFFFF) round-trips correctly; all-zero round-trips

- **TR-save-load-003 (decode path)**: Parse header
  - **Given**: A 12-byte header `[0x4C, 0x47, 0x4C, 0x44, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00]`
  - **When**: `_parse_header(...)` runs
  - **Then**: Returns `{magic_ok: true, version: 1, flags: 0, payload_length: 16}`
  - **Edge cases**: Wrong MAGIC bytes → `magic_ok: false` (Story 006 converts this to CORRUPT transition)

- **TR-save-load-024**: PAYLOAD_LENGTH vs file_length cross-check
  - **Given**: A 56-byte envelope where `PAYLOAD_LENGTH` header field claims 12
  - **When**: `_split_envelope` runs
  - **Then**: `payload_length_claimed == 12`; `payload_length_actual = 56 - 44 == 12`; validator returns true
  - **Edge cases**: Claimed 13 with actual 12 → validator returns false (Story 006 transitions CORRUPT); claimed 12 with actual 13 (over-read attempt) → validator returns false

- **Roundtrip fuzz (sanity)**: Compose-then-split determinism
  - **Given**: Random 16-bit values for version, flags; random payload up to 65 KB
  - **When**: `_split_envelope(_compose_envelope(p, flags))` runs with composed header
  - **Then**: Returned fields equal inputs; no field shifts on byte boundary

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/envelope_layout_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload skeleton)
- **Unlocks**: Story 003 (XOR mask), Story 006 (validation order)
