# Story 006: Validation order (MAGIC → VERSION → HMAC) + DoS-safe pre-HMAC buffer sizing

> **Epic**: save-load-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #3. Test evidence: `tests/{unit,integration}/save_load/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-005, TR-save-load-023, TR-save-load-024, TR-save-load-011
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — validation order section + Rule 2 DoS defense)
**ADR Decision Summary**: Validation order is deliberate: (1) validate MAGIC bytes, (2) read VERSION, (3) recompute HMAC using `keys[0]` first, retry once with `keys[1]`. Pre-HMAC buffer allocation MUST use `file_length - 44`, NOT the header-declared PAYLOAD_LENGTH (Rule 2 DoS defense — attacker-controlled PAYLOAD_LENGTH could trigger over-read/allocation). Post-HMAC, assert `PAYLOAD_LENGTH == file_length - 44`. HMAC-first reordering is explicitly rejected (creates save-destruction DoS on N-1 fallback path).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (DoS defense correctness is load-bearing; a misplaced PAYLOAD_LENGTH read could bypass the guard silently)
**Engine Notes**: `FileAccess.open(path, READ)` + `get_length()` returns file length as int64; `get_buffer(length)` reads bytes. On load entry, delete any stale `.tmp` unconditionally (TR-save-load-011).

**Control Manifest Rules (Foundation Layer, validation order)**:
- **Required**: Validation order on load MUST be MAGIC → VERSION → HMAC (deliberate; never reorder to HMAC-first). Pre-HMAC buffer allocation uses `file_length - 44`, NOT PAYLOAD_LENGTH (Rule 2 DoS defense). HMAC first computed under `keys[0]`; on mismatch, retry once under `keys[1]`. Post-HMAC, assert `PAYLOAD_LENGTH == file_length - 44`. On load entry, delete any stale `.tmp` file at the slot path unconditionally.
- **Forbidden**: Reordering to HMAC-first (creates save-destruction DoS). Using header-declared PAYLOAD_LENGTH as input to pre-HMAC buffer allocation (attacker-controlled).

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `_validate_envelope(envelope_bytes: PackedByteArray) -> Dictionary` performs the 4-step pipeline: (1) magic, (2) version, (3) HMAC[keys[0]] with retry on keys[1], (4) payload_length cross-check
- [ ] Step 1 (MAGIC): bytes[0..4) == `_MAGIC` ("LGLD") — mismatch → return `{ok: false, failure: "magic"}` and do NOT proceed
- [ ] Step 2 (VERSION): read u16 LE at offset 4; if `version > CURRENT_SAVE_VERSION`, return `{ok: false, failure: "version_future"}` per `future_version_save_policy`
- [ ] Step 3 (HMAC): compute HMAC over bytes `[0 .. file_length - 33]` — i.e., header (12B) + masked_payload (`file_length - 44` bytes) — using `keys[0]`; compare to `envelope[file_length - 32 .. file_length)`. On mismatch, retry once with `keys[1]`. If `keys[1]` matches: return `{ok: true, keys_index: 1}` and set `_needs_rekey_persist = true`. If both mismatch: return `{ok: false, failure: "hmac"}`
- [ ] Pre-HMAC masked-payload buffer size is computed as `file_length - 44`; the header-declared PAYLOAD_LENGTH is NOT consulted at this point
- [ ] Step 4 (post-HMAC): assert `declared_payload_length == file_length - 44`; mismatch → return `{ok: false, failure: "payload_length_mismatch"}` (CORRUPT state transition)
- [ ] On load entry, any stale `user://save_slot_1.dat.tmp` is deleted unconditionally before reading `.dat`
- [ ] `future_version_save_policy = refuse` is the MVP default; mismatch surfaces a modal (delegated to Story 010)

---

## Implementation Notes

- The reason for `file_length - 44` (not `PAYLOAD_LENGTH`) is the Rule 2 DoS defense: if the attacker sets `PAYLOAD_LENGTH = 0xFFFFFFFF` in the header, using it to allocate an input buffer would trigger a 4 GB allocation attempt. By contrast, `file_length - 44` is bounded by the actual on-disk file size (which the OS already enforces) and the `max_payload_size_bytes` (2 MB MVP hard cap) knob on the `FileAccess.open` path
- HMAC input = `envelope[0 .. file_length - 32)`, which is exactly the header (12B) + the masked payload bytes as they sit on disk — NOT trusting PAYLOAD_LENGTH to slice the payload region
- The footer HMAC occupies `envelope[file_length - 32 .. file_length)`
- Why MAGIC-first: a file with wrong MAGIC bytes (a non-LGLD file accidentally placed in the slot) should be rejected cheaply BEFORE burning the N-1 HMAC retry budget. Burning keys[1] on structurally unrelated files would risk false-positive-N-1 retry on actual attacker-controlled data in the worst case
- Why VERSION before HMAC: if VERSION indicates a future schema this build can't migrate, we refuse immediately with a "your save is from a newer build; update the game" modal. Running HMAC first would waste CPU on a file we're going to reject anyway
- Why NOT HMAC-first: per ADR-0004 rejection rationale — a file with intact MAGIC+VERSION but failing HMAC under both keys (e.g., legitimately old save, cross-game paste sharing MAGIC somehow) burns the HMAC-retry budget; MAGIC→VERSION gates structural validity first so retry is reserved for plausibly-our-format files
- Stale `.tmp` cleanup: per TR-save-load-011, delete `user://save_slot_1.dat.tmp` unconditionally on load entry (before attempting to read `.dat`). This handles interrupted persist aftermath cleanly
- `max_payload_size_bytes` hard cap (2 MB) — if `file_length - 44 > max_payload_size_bytes`, return `{ok: false, failure: "size_cap"}` before allocating
- Return-type sugar: internally this function may return a small typed record (dict or RefCounted LoadEnvelopeResult); external callers consume `code + detail`

---

## Out of Scope

- Story 007: what happens AFTER validation succeeds (consumer loop)
- Story 008: atomic write mechanics
- Story 010: schema migration path when `version < CURRENT_SAVE_VERSION`
- Story 013: tamper-detection UX (modal + `_meta.tamper_suspicious_count` increment) on HMAC failure

---

## QA Test Cases

- **TR-save-load-023 (MAGIC gate)**: Wrong magic bytes rejected cheaply
  - **Given**: A file of length 44 bytes where bytes [0..4) are `[0x00, 0x00, 0x00, 0x00]`
  - **When**: `_validate_envelope(bytes)` runs
  - **Then**: Returns `{ok: false, failure: "magic"}`; HMAC is NEVER computed (test spies on the HMAC wrapper and asserts zero invocations)
  - **Edge cases**: Correct MAGIC but wrong length (<44 bytes total) → returns `{ok: false, failure: "magic_or_length"}` before HMAC

- **TR-save-load-023 (VERSION gate)**: Future version refused
  - **Given**: MAGIC ok, VERSION field = `0xFFFF` (u16 max, far above `CURRENT_SAVE_VERSION = 1`)
  - **When**: `_validate_envelope` runs
  - **Then**: Returns `{ok: false, failure: "version_future"}`; HMAC is NOT computed
  - **Edge cases**: VERSION == `CURRENT_SAVE_VERSION` proceeds to HMAC; VERSION < `CURRENT_SAVE_VERSION` proceeds (Story 010 handles migration)

- **TR-save-load-005 / Rule 2 DoS defense**: PAYLOAD_LENGTH not used for buffer allocation
  - **Given**: A crafted envelope where bytes [8..12) (header PAYLOAD_LENGTH field) == `0xFFFFFFFF` but `file_length == 100` bytes
  - **When**: `_validate_envelope` runs
  - **Then**: HMAC is computed over `bytes[0 .. 100 - 32)` = 68 bytes (file_length - 32); the 4 GB PAYLOAD_LENGTH is never used to allocate a buffer; no OOM; no >200 ms stall
  - **Edge cases**: Post-HMAC step 4 catches the mismatch (`declared 0xFFFFFFFF != actual 56`) → returns `{ok: false, failure: "payload_length_mismatch"}`

- **TR-save-load-023 (HMAC keys[0] happy path)**
  - **Given**: A valid envelope signed under `keys[0]`
  - **When**: `_validate_envelope` runs
  - **Then**: Returns `{ok: true, keys_index: 0}`; `_needs_rekey_persist` stays `false`
  - **Edge cases**: Single-byte corruption anywhere in the envelope → `failure: "hmac"` after both keys fail

- **TR-save-load-021 / 023 (keys[1] fallback)**
  - **Given**: A valid envelope signed under `keys[1]` (prior build)
  - **When**: `_validate_envelope` runs
  - **Then**: keys[0] mismatch; keys[1] match; returns `{ok: true, keys_index: 1}`; `_needs_rekey_persist` set `true`
  - **Edge cases**: Both keys fail → HMAC failure branch; NO third key ever tried (N=2 is hard-coded)

- **TR-save-load-024**: Post-HMAC PAYLOAD_LENGTH cross-check
  - **Given**: HMAC valid envelope where header PAYLOAD_LENGTH = 12 but actual masked-payload bytes = 13 (mismatch, but HMAC was over the actual 13 bytes so HMAC passes)
  - **When**: Step 4 runs
  - **Then**: Returns `{ok: false, failure: "payload_length_mismatch"}`; state transitions to CORRUPT
  - **Edge cases**: This is a defense-in-depth check — in practice an attacker flipping PAYLOAD_LENGTH would also fail HMAC (PAYLOAD_LENGTH is inside the HMAC-protected region), but Step 4 catches compose-side bugs

- **TR-save-load-011**: Stale `.tmp` cleanup on load entry
  - **Given**: `user://save_slot_1.dat` exists (valid) AND `user://save_slot_1.dat.tmp` exists (leftover from a prior interrupted persist)
  - **When**: Load pipeline starts
  - **Then**: `.tmp` is deleted BEFORE `.dat` is opened; final state has `.dat` loaded successfully and no `.tmp` remaining
  - **Edge cases**: `.tmp` absent → no-op; `.tmp` present but `.dat` absent → `.tmp` still deleted, then fall through to first-launch bootstrap (Story 007)

- **Anti-regression**: HMAC-first reordering not permitted
  - **Given**: Code review gate (not automated in GdUnit4)
  - **When**: Reviewer inspects `_validate_envelope`
  - **Then**: Steps are (MAGIC, VERSION, HMAC, payload_length); no "fast path" that computes HMAC before MAGIC check
  - **Edge cases**: Reviewer verifies against ADR-0004 validation order section

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/validation_order_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (envelope layout), Story 003 (XOR mask — validated masked payload bytes), Story 004 (HMAC wrapper), Story 005 (keys[0] / keys[1])
- **Unlocks**: Story 007 (consumer loop, called only after validation success), Story 013 (tamper-detection UX on validation failure)
