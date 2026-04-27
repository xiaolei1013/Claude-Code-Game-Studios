# Story 004: HMAC-SHA256 GDScript wrapper + 7 RFC 4231 test vectors (BLOCKING gate)

> **Epic**: save-load-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §AC-SL-HMAC-01 (BLOCKING — gates all AC-SL-TAMPER-* ACs)
**Requirements**: TR-save-load-022, TR-save-load-019, TR-save-load-004 (HMAC portion)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — HMAC scheme + RFC 4231 conformance gate)
**ADR Decision Summary**: HMAC-SHA256 per RFC 2104, implemented from scratch in GDScript layered on `HashingContext.HASH_SHA256`. The ~30-line wrapper MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly BEFORE any AC-SL-TAMPER-* AC is permitted to run. No constant-time compare (single-player premium game; not a timing-side-channel threat model).

**Engine**: Godot 4.6 | **Risk**: HIGH (from-scratch cryptographic primitive; subtle bugs pass basic tests and fail edge cases)
**Engine Notes**: `HashingContext.HASH_SHA256` is the canonical native SHA-256 primitive (stable since 4.0, LOW knowledge risk). The HMAC wrapper is pure GDScript byte manipulation on `PackedByteArray`. SHA-256 block size = 64 bytes; SHA-256 output = 32 bytes.

**Control Manifest Rules (Foundation Layer, HMAC)**:
- **Required**: HMAC-SHA256 (RFC 2104) implemented in GDScript on `HashingContext.HASH_SHA256`; from-scratch wrapper ~30 lines. HMAC-SHA256 implementation MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly before any tamper AC runs (gate AC-SL-HMAC-01 BLOCKING). Integrity hash is HMAC-SHA256 over 12-byte header + masked payload; returns 32-byte tag.
- **Forbidden**: Identifier substrings "key", "secret", "hmac" in the wrapper file (Story 014 enforces globally; this story's identifiers use "tag", "digest", "integrity_wrap").

---

## Acceptance Criteria

*Scoped to this story (per ADR-0004 Validation Criteria + AC-SL-HMAC-01):*

- [ ] `_BLOCK_SIZE_SHA256 := 64` constant declared
- [ ] `_sha256(data: PackedByteArray) -> PackedByteArray` wrapper returns 32 bytes
- [ ] HMAC wrapper function (under non-suggestive name, e.g., `_integrity_wrap`) accepts `key: PackedByteArray, msg: PackedByteArray` and returns a 32-byte tag
- [ ] Key longer than 64 bytes is SHA-256-hashed first (per RFC 2104 §2 step 1)
- [ ] Key shorter than 64 bytes is zero-padded to 64 bytes (per RFC 2104 §2 step 2)
- [ ] `o_key_pad[i] = key[i] ^ 0x5C`; `i_key_pad[i] = key[i] ^ 0x36` per RFC 2104
- [ ] Output = `SHA256(o_key_pad || SHA256(i_key_pad || msg))`
- [ ] **ALL 7 RFC 4231 §4.2–4.8 test vectors pass bit-exactly** (BLOCKING — gate for every AC-SL-TAMPER-* AC)
- [ ] Tag compare uses plain `PackedByteArray == PackedByteArray` (no constant-time requirement — ADR-0004)

---

## Implementation Notes

*Derived from ADR-0004 HMAC scheme section:*

- Reference structure from ADR-0004:
  ```gdscript
  const _BLOCK_SIZE_SHA256 := 64

  func _integrity_wrap(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
      if key.size() > _BLOCK_SIZE_SHA256:
          key = _sha256(key)
      if key.size() < _BLOCK_SIZE_SHA256:
          key.resize(_BLOCK_SIZE_SHA256)   # zero-pads to 64
      var o_pad := PackedByteArray(); o_pad.resize(_BLOCK_SIZE_SHA256)
      var i_pad := PackedByteArray(); i_pad.resize(_BLOCK_SIZE_SHA256)
      for i in _BLOCK_SIZE_SHA256:
          o_pad[i] = key[i] ^ 0x5C
          i_pad[i] = key[i] ^ 0x36
      return _sha256(o_pad + _sha256(i_pad + msg))
  ```
- `PackedByteArray.resize(N)` zero-fills new entries (Godot 4.x contract — verify against engine-reference doc)
- `PackedByteArray.append_array(other)` or `+` operator concatenates
- The inner SHA-256 must be called with the concatenation of `i_pad` (64 bytes) + msg, returning 32 bytes; the outer SHA-256 takes `o_pad` (64 bytes) + those 32 bytes
- No GDExtension / libsodium (Alternative 1 rejected; ADR-0004)
- No constant-time compare (casual-deterrent threat model; ADR-0004)
- All wrapper identifiers MUST avoid "key", "secret", "hmac" substrings — use `key_bytes` param name OR rename to `seed_bytes` + `_integrity_wrap` function name. Parameter names `key`/`msg` are acceptable per RFC convention, BUT top-level variable declarations in SaveLoadSystem calling this wrapper MUST use non-suggestive names (enforced Story 014)

### The 7 RFC 4231 test vectors (§4.2–4.8)

| # | Section | Key (hex) | Data | Expected HMAC-SHA256 output (hex) |
|---|---|---|---|---|
| 1 | §4.2 | 20 bytes of `0x0b` | `"Hi There"` (ASCII, 8 bytes) | `b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7` |
| 2 | §4.3 | `"Jefe"` (ASCII, 4 bytes) | `"what do ya want for nothing?"` (28 bytes) | `5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843` |
| 3 | §4.4 | 20 bytes of `0xaa` | 50 bytes of `0xdd` | `773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe` |
| 4 | §4.5 | `0x0102030405060708090a0b0c0d0e0f10111213141516171819` (25 bytes) | 50 bytes of `0xcd` | `82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b` |
| 5 | §4.6 | 20 bytes of `0x0c` | `"Test With Truncation"` (20 bytes) | Full 32 bytes: `a3b6167473100ee06e0c796c2955552bfa6f7c0a6a8aef8b93f860aab0cd20c5` (test only the first 16 bytes per §4.6 truncation rule, BUT our implementation returns full 32 bytes — assert first 16 bytes match `a3b6167473100ee06e0c796c2955552b`) |
| 6 | §4.7 | 131 bytes of `0xaa` (longer than block size — triggers key-hash path) | `"Test Using Larger Than Block-Size Key - Hash Key First"` (54 bytes) | `60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54` |
| 7 | §4.8 | 131 bytes of `0xaa` (longer than block size — triggers key-hash path) | `"This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm."` (152 bytes) | `9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2` |

---

## Out of Scope

- Story 005: HMAC key derivation (multi-part assembly + build-version rotation)
- Story 006: validation order + N-1 retry using `keys[0]` and `keys[1]`
- Story 013: tamper detection integration (HMAC verify failure → `.bak` fallback)

---

## QA Test Cases

**SPECIAL: This is the BLOCKING gate AC-SL-HMAC-01 — every RFC 4231 vector is enumerated below as an individual Given/When/Then. A tamper AC passing against a buggy HMAC produces false confidence; per ADR-0004, each vector is asserted bit-exactly before any AC-SL-TAMPER-* AC runs.**

- **AC-SL-HMAC-01 / RFC 4231 §4.2 (Test Case 1 — short key, short data)**
  - **Given**: `key = PackedByteArray` of 20 bytes each `0x0b`; `data = "Hi There".to_utf8_buffer()` (8 bytes: `0x48 0x69 0x20 0x54 0x68 0x65 0x72 0x65`)
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals the 32-byte PackedByteArray for hex `b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7`
  - **Edge cases**: Exercises the short-key zero-pad path (key.size() == 20 < 64)

- **AC-SL-HMAC-01 / RFC 4231 §4.3 (Test Case 2 — ASCII key "Jefe", medium data)**
  - **Given**: `key = "Jefe".to_utf8_buffer()` (4 bytes: `0x4a 0x65 0x66 0x65`); `data = "what do ya want for nothing?".to_utf8_buffer()` (28 bytes)
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals hex `5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843`
  - **Edge cases**: Very short key (4 bytes); confirms zero-pad correctness in the low-entropy-key regime

- **AC-SL-HMAC-01 / RFC 4231 §4.4 (Test Case 3 — 20-byte key, 50-byte data)**
  - **Given**: `key` = 20 bytes of `0xaa`; `data` = 50 bytes of `0xdd`
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals hex `773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe`
  - **Edge cases**: Data length > 32 bytes (crosses one SHA block in the inner hash)

- **AC-SL-HMAC-01 / RFC 4231 §4.5 (Test Case 4 — 25-byte incrementing-hex key, 50-byte data)**
  - **Given**: `key` = bytes `0x01 0x02 0x03 ... 0x19` (25 bytes, i.e., 1..25); `data` = 50 bytes of `0xcd`
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals hex `82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b`
  - **Edge cases**: Non-repeating key pattern; sensitive to endian/byte-order bugs that would survive repeating-byte tests

- **AC-SL-HMAC-01 / RFC 4231 §4.6 (Test Case 5 — truncation test case)**
  - **Given**: `key` = 20 bytes of `0x0c`; `data = "Test With Truncation".to_utf8_buffer()` (20 bytes)
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Full 32-byte result equals hex `a3b6167473100ee06e0c796c2955552bfa6f7c0a6a8aef8b93f860aab0cd20c5`; first 16 bytes specifically equal `a3b6167473100ee06e0c796c2955552b` (RFC 4231 §4.6 only specifies the truncated-to-128-bit output — our impl returns full 32 bytes, so we assert full output against the computed expected value or at minimum verify the 128-bit prefix matches the RFC)
  - **Edge cases**: Our HMAC is not truncated; the tag length in envelope is the full 32 bytes (ADR-0004 §envelope byte layout)

- **AC-SL-HMAC-01 / RFC 4231 §4.7 (Test Case 6 — key longer than block size, triggers pre-hash path)**
  - **Given**: `key` = 131 bytes of `0xaa` (exceeds 64-byte block — MUST trigger the `if key.size() > _BLOCK_SIZE_SHA256: key = _sha256(key)` branch); `data = "Test Using Larger Than Block-Size Key - Hash Key First".to_utf8_buffer()` (54 bytes)
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals hex `60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54`
  - **Edge cases**: This is THE critical vector exercising the long-key pre-hash path — a common bug class (forgetting to pre-hash, or hashing the wrong thing) fails here while passing Cases 1-5

- **AC-SL-HMAC-01 / RFC 4231 §4.8 (Test Case 7 — long key + long data)**
  - **Given**: `key` = 131 bytes of `0xaa`; `data = "This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm.".to_utf8_buffer()` (152 bytes)
  - **When**: `_integrity_wrap(key, data)` runs
  - **Then**: Result equals hex `9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2`
  - **Edge cases**: Exercises long-key path + data spanning multiple SHA blocks in the inner hash; high sensitivity to any state-reset bug in the GDScript wrapper

- **AC-SL-HMAC-01 / Gate enforcement**: No tamper AC runs until all 7 pass
  - **Given**: CI pipeline is configured with this test suite as a blocking prerequisite
  - **When**: One of the 7 vectors fails
  - **Then**: The entire `tests/unit/save_load/` run is marked FAIL; no `AC-SL-TAMPER-*` AC result is accepted as evidence in the same run
  - **Edge cases**: Flake-on-retry is forbidden — the tests are pure deterministic byte math

- **Self-inverse sanity**: HMAC is not self-inverse (unlike XOR) — the test suite includes a negative-control: `_integrity_wrap(key, data) != _integrity_wrap(key, data + PackedByteArray([0x00]))` (any 1-byte change flips the tag)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/hmac_sha256_rfc4231_test.gd` — must exist and pass all 7 vectors

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload skeleton — `_sha256` wrapper hooks into HashingContext)
- **Unlocks**: Story 005 (key derivation), Story 006 (validation order), Story 013 (tamper detection) — ALL tamper ACs gated on this story's pass
