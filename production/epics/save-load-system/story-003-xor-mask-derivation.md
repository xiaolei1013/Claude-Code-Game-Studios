# Story 003: XOR mask — SHA256-derived seed + chunk-indexed mask stream

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-020, TR-save-load-004 (XOR portion — HMAC computed over masked bytes)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — XOR obfuscation layer)
**ADR Decision Summary**: Payload is XOR-masked before HMAC. Seed = `SHA256(MAGIC || VERSION || STATIC_SECRET_16_BYTES)`. Mask stream repeats via `SHA256(seed || u32_le(chunk_index))` until PAYLOAD_LENGTH bytes exist. Mask is deterministic and reproducible — not confidentiality. `STATIC_SECRET` MUST NOT participate in HMAC key derivation.

**Engine**: Godot 4.6 | **Risk**: LOW (deterministic byte-math; native SHA-256)
**Engine Notes**: `HashingContext` with `HashingContext.HASH_SHA256` is the canonical SHA-256 primitive (stable since 4.0). No post-cutoff API concerns.

**Control Manifest Rules (Foundation Layer, XOR mask)**:
- **Required**: XOR mask seed = `SHA256(MAGIC || VERSION || STATIC_SECRET_16_BYTES)`; mask repeats via `SHA256(seed || u32_le(chunk_index))` until PAYLOAD_LENGTH bytes; XOR-mask **before** HMAC. `STATIC_SECRET` (16 bytes) lives in a non-SaveLoad autoload under a non-suggestive identifier (e.g., `_GAME_NAMESPACE_BYTES`).
- **Forbidden**: Identifier substrings "key", "secret", "hmac" in the SaveLoad or mask-fragment autoload. Referencing `STATIC_SECRET` as "providing secrecy" in comments, names, or logs. Letting `STATIC_SECRET` participate in HMAC key derivation (architectural separation).

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] Static 16-byte constant lives in a non-SaveLoad autoload under a non-suggestive name (e.g., `_GAME_NAMESPACE_BYTES` in `BootNamespace` autoload)
- [ ] `_derive_mask_seed(version: int) -> PackedByteArray` returns 32 bytes = `SHA256(MAGIC || u16_le(version) || STATIC_SECRET_16)`
- [ ] `_generate_mask(seed: PackedByteArray, payload_length: int) -> PackedByteArray` produces exactly `payload_length` bytes by concatenating `SHA256(seed || u32_le(chunk_index))` for `chunk_index = 0, 1, 2, ...`, truncating the final block
- [ ] `_apply_xor_mask(plaintext: PackedByteArray, mask: PackedByteArray) -> PackedByteArray` returns element-wise XOR
- [ ] XOR is self-inverse: `_apply_xor_mask(_apply_xor_mask(p, m), m) == p`
- [ ] For a fixed `STATIC_SECRET`, mask stream is bit-exact deterministic across runs (golden-file test)
- [ ] No identifier in SaveLoadSystem or the mask-fragment autoload contains "key", "secret", or "hmac" (CI grep — Story 014 enforces globally; this story asserts locally via a test)

---

## Implementation Notes

- `STATIC_SECRET` is a **namespace salt**, not a key. Per-product; regenerated per shipped product line (ADR-0004 risk row)
- A single SHA-256 call returns 32 bytes; for a payload up to 20 KB MVP, this means `ceil(20480 / 32) = 640` chunks. For the 2 MB hard cap, ~65 536 chunks. At sub-µs per SHA-256 call on native HashingContext, total mask generation <50 ms worst case — well under the persist budget
- `chunk_index` is written little-endian as u32 (consistent with envelope field encoding)
- XOR is the simplest possible transform; any flip of mask byte `m[i]` propagates to `plaintext[i]`, making byte-level text edits (e.g., changing `"gold":100` to `"gold":999`) visible as random noise in the file
- The mask stream MUST be indexed deterministically: given the same `version` and `STATIC_SECRET`, the same mask bytes appear for every run — this is the whole point (the encoded file must load on any machine with the same binary)
- Comments in the mask-generation code MUST NOT use "secrecy" or "encrypts"; use "obfuscates" or "namespace-scrambles" language. This is threat-model honest.
- Encapsulation test: `grep -RE '_key|_secret|_hmac' src/core/save_load_system.gd src/core/boot_namespace.gd` returns zero hits

---

## Out of Scope

- Story 004: HMAC implementation (the mask is applied BEFORE the HMAC computes in Story 006)
- Story 005: HMAC key derivation (disjoint from XOR seed per ADR-0004)
- Story 014: CI grep enforcement across all fragment autoloads

---

## QA Test Cases

- **TR-save-load-020**: Mask seed derivation
  - **Given**: MAGIC = "LGLD", version = 1, and a fixed `STATIC_SECRET_16` value committed to the test fixture
  - **When**: `_derive_mask_seed(1)` runs
  - **Then**: Result is a 32-byte PackedByteArray matching a pre-computed golden hex string (test fixture captures the expected output)
  - **Edge cases**: Changing `version` produces a different seed; changing `STATIC_SECRET` produces a different seed (proves all three inputs are load-bearing)

- **TR-save-load-020 (stream)**: Mask stream length + determinism
  - **Given**: A fixed seed
  - **When**: `_generate_mask(seed, 100)` runs
  - **Then**: Result is exactly 100 bytes; two invocations produce identical output; first 32 bytes equal `SHA256(seed || 0x00000000)` (chunk 0); bytes 32-63 equal `SHA256(seed || 0x01000000)` (chunk 1, LE); bytes 64-95 equal `SHA256(seed || 0x02000000)`; final 4 bytes (96-99) are the first 4 bytes of `SHA256(seed || 0x03000000)` (truncated)
  - **Edge cases**: Length 0 returns empty array; length 32 returns exactly one full chunk; length 33 returns one full chunk + 1 byte of chunk 1

- **TR-save-load-004 (XOR portion)**: XOR self-inverse
  - **Given**: Plaintext `{"gold": 100}` as UTF-8 bytes (12 bytes) and a derived 12-byte mask
  - **When**: Mask is applied, then re-applied
  - **Then**: Final bytes equal original plaintext byte-for-byte
  - **Edge cases**: 1-byte plaintext; 2 MB plaintext (hard cap); all-zero plaintext (still masks to non-zero because mask is pseudo-random); plaintext of length exactly 32 (one mask chunk boundary)

- **TR-save-load-020 (text-edit blocking)**: String-search-and-replace resistance
  - **Given**: A JSON plaintext containing the literal bytes `"gold":100`
  - **When**: `_apply_xor_mask(plaintext, _generate_mask(...))` produces masked bytes
  - **Then**: A linear-scan `find_subsequence(masked_bytes, "gold".to_utf8_buffer())` returns -1; same for `"100"` and `"gold":100` (per AC-SL-TAMPER-01 substrate)
  - **Edge cases**: Even if the substring appears by chance in the output (probabilistically ~1 in 2^32 per 4-byte window for 4-byte needles), the test's specific fixture value must not produce that accidental match — covered by committed-plaintext + committed-seed determinism

- **Identifier hygiene (local)**: Grep scan
  - **Given**: `src/core/save_load_system.gd` + the mask-fragment autoload file
  - **When**: Grep pattern `(?i)(key|secret|hmac)` runs over identifier tokens
  - **Then**: Zero hits (case-insensitive substring in var/const/func/signal names)
  - **Edge cases**: Test must ignore comments/strings; the check is on identifiers only — rely on a simple AST or regex with word-boundary + identifier-context anchoring

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/xor_mask_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (envelope layout — MAGIC + VERSION inputs)
- **Unlocks**: Story 004 (HMAC, computed over the masked bytes), Story 006 (compose/parse pipeline)
