# ADR-0004: Save Envelope Format and HMAC Scheme

## Status

Accepted

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Source of truth: `design/gdd/save-load-system.md` Anti-Tamper Specification (Pass-5B-remainder + Pass-5D + Pass-5E user decisions D1, D3, D4, D5E-3)

## Summary

This ADR formalizes the binary save envelope, the HMAC-SHA256 integrity scheme, the XOR obfuscation layer, the multi-part HMAC key derivation with N=2 build-version rotation, the load-time validation order (MAGIC→VERSION→HMAC), and the SaveLoadSystem-owned `_meta` sub-schema. All of these were decided in the Save/Load GDD through Passes 5B/5D/5E; the ADR locks them as architectural commitments and resolves architecture.md OQ-2 (HMAC key derivation) by adopting the multi-part-assembly + build-version-rotation pattern over the three simpler alternatives.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (FileAccess I/O, HashingContext SHA-256, atomic rename, byte-array manipulation) |
| **Knowledge Risk** | LOW for SHA-256 / FileAccess / DirAccess (stable since 4.0). NEAR-CUTOFF for `FileAccess.store_*` returning `bool` (changed in 4.4). |
| **References Consulted** | `design/gdd/save-load-system.md` Anti-Tamper Specification; `docs/engine-reference/godot/breaking-changes.md` (FileAccess store_* bool return); `docs/engine-reference/godot/deprecated-apis.md`; Godot 4.6 `HashingContext` + `Crypto` API docs |
| **Post-Cutoff APIs Used** | `FileAccess.store_buffer() -> bool` (4.4) — return value is asserted truthy in code; `DirAccess.rename()` (stable) |
| **Verification Required** | RFC 4231 §4.2-4.8 HMAC-SHA256 test vectors must pass bit-exactly before any tamper AC is exercised (gate AC-SL-HMAC-01 in Save/Load GDD) |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Autoload Rank Table) — Accepted. SaveLoadSystem at rank 2 is the sole owner of envelope I/O; this ADR's contracts assume that ranking. |
| **Enables** | ADR-F03 (Time dual-clock — depends on `last_persist_unix_ts` envelope contract); ADR-F05 (Scene transition + persist coupling — depends on persist atomicity contract); all Save/Load implementation stories (AC-SL-01 through AC-SL-14, AC-SL-TAMPER-01 through 05, AC-SL-HMAC-01) |
| **Blocks** | Save/Load implementation epic; Floor Unlock implementation (state persists through this envelope); Economy implementation (gold + ledger persist through this envelope); all 6 consumers in `CONSUMER_PATHS` |
| **Ordering Note** | Must be Accepted before any Save/Load implementation story can be drafted, because story acceptance criteria reference envelope byte offsets, HMAC construction, and `_meta` schema fields defined here. |

## Context

### Problem Statement

Save/Load is the operational guarantor of Pillar 1 (Respect the Player's Time). Architecture.md identified six binding decisions for the persistence boundary that the GDD's Anti-Tamper Specification has already worked through but no ADR has formally locked:

1. **Envelope format** — what bytes go where in `save_slot_1.dat`
2. **HMAC scheme** — what algorithm, what construction
3. **Key derivation** — how the HMAC key is assembled at runtime (architecture.md OQ-2 listed three options; the GDD chose a fourth, more robust option)
4. **Validation order on load** — MAGIC→VERSION→HMAC vs HMAC-first; the GDD has a deliberate ordering with a documented rationale that must not drift
5. **`_meta` sub-schema** — the SaveLoadSystem-owned namespace inside the JSON payload, distinct from consumer namespaces
6. **Atomic write + backup rotation** — temp+rename pattern + iOS/Android fallback

Without an ADR, future stories or revisions could re-litigate any of these and produce contradictory implementations. ADR-0003 already established that SaveLoadSystem is rank 2 and that consumer enumeration is a hardcoded list; this ADR establishes the on-disk contract.

### Current State

- `design/gdd/save-load-system.md` Anti-Tamper Specification (lines 351-492) contains the full byte layout, HMAC construction, key rotation policy, validation order, and `_meta` schema, all settled through Pass-5B-remainder (2026-04-21) + Pass-5D (2026-04-21) + Pass-5E (2026-04-21) with explicit user decisions D1, D3, D4, D5E-3.
- `docs/architecture/architecture.md` §Required ADRs lists ADR-F02 with these decisions to lock and OQ-2 (HMAC key derivation) listing only three options (a/b/c) — the GDD chose option (d) multi-part assembly + build-version rotation, which strictly dominates a/b/c on threat coverage.
- ADR-0003 (Accepted 2026-04-22) makes `SaveLoadSystem.CONSUMER_PATHS` the source of truth for which autoloads contribute to the payload.
- `tests/probes/godot_autoload_probe.gd` exists for autoload behavior; no equivalent probe exists for HMAC-SHA256 conformance — the RFC 4231 test vector suite must be authored as part of AC-SL-HMAC-01.

### Constraints

- Godot 4.6's `HashingContext` exposes raw SHA-256 only — no stdlib HMAC primitive. HMAC-SHA256 must be implemented in GDScript per RFC 2104.
- `FileAccess.store_*` returns `bool` since Godot 4.4 (NEAR-CUTOFF) — implementation must check or assert truthy.
- Atomic rename is not guaranteed on iOS/Android — fallback uses a `.commit` marker pattern (per GDD Atomic Write section).
- The HMAC key cannot be kept secret from a determined attacker — the binary ships with the player's machine. The threat model is **casual-deterrent**, not bulletproof.
- Single-player premium game with no competitive integrity requirements; no server-side validation; no cloud save in MVP.
- Performance: persist budget < 10ms PC / < 50ms mobile; payload < 20KB MVP.

### Requirements

- Envelope MUST be byte-exact reproducible across builds (deterministic output for the same input).
- Tampering with any byte (header, payload, footer) MUST be detectable on load with HMAC failure → modal flow (per GDD HMAC Verification Behavior step 6).
- A save signed under the prior build's HMAC key MUST load successfully on the current build (N-1 key rotation); an N-2 save MUST NOT (intentional invalidation window).
- `_meta` namespace MUST be owned exclusively by SaveLoadSystem — consumers MUST NOT read or write `_meta` fields.
- The XOR obfuscation layer MUST be reproducible (deterministic mask) and MUST NOT be referenced as a confidentiality boundary in any code, comment, or log.
- HMAC-SHA256 implementation MUST pass all 7 RFC 4231 §4.2-4.8 test vectors bit-exactly before any tamper AC is exercised (gate AC-SL-HMAC-01).

## Decision

### Envelope byte layout (the contract)

Every save file at `user://save_slot_1.dat` is exactly:

```
Offset  Size  Field            Notes
─────────────────────────────────────────────────────────────────────────────
0       4     MAGIC            Bytes "LGLD" (0x4C 0x47 0x4C 0x44)
4       2     VERSION          u16 little-endian — CURRENT_SAVE_VERSION at write time
6       2     FLAGS            u16 little-endian. MVP: 0x0000. V1.0+ bit 0 = save_is_flagged_tampered
8       4     PAYLOAD_LENGTH   u32 little-endian — length of XOR-masked JSON payload only
12      N     PAYLOAD          PAYLOAD_LENGTH bytes — UTF-8 JSON, XOR-masked
12+N    32    HMAC             HMAC-SHA256 over bytes [0 .. 12+N-1] using current build key
─────────────────────────────────────────────────────────────────────────────
Total file size = 12 + PAYLOAD_LENGTH + 32 = 44 + PAYLOAD_LENGTH bytes
```

Header fixed = 12 bytes. Footer fixed = 32 bytes. PAYLOAD_LENGTH lives **inside** the HMAC-protected region — it cannot be rewritten to trigger an over-read.

### Payload encoding: UTF-8 JSON

The plaintext payload is a single JSON dictionary with two disjoint key classes:

- **Consumer namespace keys** — one per entry in `CONSUMER_PATHS` (per ADR-0003), e.g., `"economy"`, `"hero_roster"`, `"floor_unlock"`, `"formation_assignment"`, `"recruitment"`, `"dungeon_run_orchestrator"`. Each consumer's `get_save_data()` returns its own sub-dictionary; SaveLoadSystem nests these by snake-cased path basename.
- **`_meta`** — owned exclusively by SaveLoadSystem; consumers MUST NOT read or write any field under `_meta`.

JSON-only encoding (not MessagePack, not Godot's `bytes_to_var`, not BSON):

- **Pro-JSON**: Inspectable in the unmasked debug-mode dump; native `JSON` class in Godot 4.6 is well-tested and stable; trivial forward-compatible field addition (unknown keys are ignored on the read side via consumer ownership); no binary-format migration risk; aligns with the GDD's "implementation detail stays inspectable" principle.
- **Anti-MessagePack**: Saves <20KB MVP / <200KB V1.0; binary efficiency gain is negligible vs JSON's debuggability win.
- **Anti-`bytes_to_var`**: Godot's binary serialization is engine-version-coupled and undocumented at byte level — any 4.x→5.x migration would be brittle. JSON survives engine upgrades unchanged.

No compression in MVP. Revisit only if V1.0 payload exceeds 200KB (per Save/Load §D.1).

### XOR obfuscation layer

The JSON payload is XOR-masked **before** the HMAC is computed, so the HMAC integrity-protects the masked bytes. Mask derivation:

```gdscript
seed = SHA256(MAGIC || VERSION || STATIC_SECRET_16_BYTES)
mask = SHA256(seed || u32_le(chunk_index)) repeated until PAYLOAD_LENGTH bytes exist
masked_payload[i] = plaintext_json[i] XOR mask[i]
```

**This is not encryption.** Purpose: a player with Notepad++ or a casual hex editor sees binary noise instead of `"gold": 100`, eliminating string-search-and-replace as a tampering vector. A determined attacker with `gdsdecomp` extracts `STATIC_SECRET` from the binary in under two minutes.

**Static secret implementer contract** (per GDD security-engineer F2):

- `STATIC_SECRET` is a 16-byte namespace salt, NOT a key.
- It MUST NOT be referenced as providing secrecy in implementation comments, variable names, or log messages.
- Variable identifier MUST NOT contain "key", "secret", or "hmac" hints (e.g., naming it `_GAME_NAMESPACE_BYTES` is acceptable; `_HMAC_SECRET` is forbidden).
- It MUST NOT participate in HMAC key derivation (architectural separation of concerns: XOR mask seeding is a different boundary from integrity keying).

### HMAC scheme

**Algorithm**: HMAC-SHA256 (RFC 2104, layered on `HashingContext.HASH_SHA256`).

**Implementation**: from-scratch in GDScript per RFC 2104 (Godot 4.6 has no stdlib HMAC primitive). Reference structure per GDD §HMAC-SHA256 Construction:

```gdscript
const _BLOCK_SIZE_SHA256 := 64

func _hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
    if key.size() > _BLOCK_SIZE_SHA256:
        key = _sha256(key)
    if key.size() < _BLOCK_SIZE_SHA256:
        key.resize(_BLOCK_SIZE_SHA256)   # zero-pads
    var o_key_pad := PackedByteArray(); o_key_pad.resize(_BLOCK_SIZE_SHA256)
    var i_key_pad := PackedByteArray(); i_key_pad.resize(_BLOCK_SIZE_SHA256)
    for i in _BLOCK_SIZE_SHA256:
        o_key_pad[i] = key[i] ^ 0x5C
        i_key_pad[i] = key[i] ^ 0x36
    return _sha256(o_key_pad + _sha256(i_key_pad + msg))

func _sha256(data: PackedByteArray) -> PackedByteArray:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(data)
    return ctx.finish()
```

**Conformance gate**: AC-SL-HMAC-01 (BLOCKING). The implementation MUST pass all 7 RFC 4231 §4.2-4.8 test vectors bit-exactly before any AC-SL-TAMPER-* AC is permitted to run. A subtly-buggy HMAC that catches one wrong-tag pattern but misses others produces false confidence in tamper detection.

**No constant-time comparison**: a single-player premium game is out of scope for timing side-channel attacks. The HMAC compare may use plain `PackedByteArray == PackedByteArray`.

**Native primitive choice**: SHA-256 itself uses Godot's native `HashingContext` (not a GDScript SHA-256 implementation) — the hot inner loop stays native. Only the ~30-line HMAC wrapper is GDScript. GDExtension binding to libsodium was rejected as disproportionate to the threat (no native-build-pipeline pressure for MVP; compile-time dependency cost outweighs perf gain at our save sizes).

### HMAC key derivation: multi-part assembly + N=2 rotation

This resolves architecture.md OQ-2 by adopting the GDD's option (d), strictly stronger than OQ-2 options (a)/(b)/(c).

**Multi-part assembly at runtime**:

```gdscript
# Conceptual — the parts live in different autoload scripts under non-suggestive names.
# Implementation MUST NOT name any of these "_HMAC_KEY_PART_X" or similar.
var key = sha256(part_a XOR part_b || part_c || build_version_string)
```

- 3-4 byte arrays (each 16-32 bytes) defined in **different autoload scripts**, each named without "HMAC"/"key"/"secret" hints. Combined at runtime via `SHA256(PART_A ⊕ PART_B || PART_C || build_version_string)`.
- The decompiler attacker must locate and combine 3-4 fragments scattered across the codebase rather than copy a single labeled constant. Marginal raise to extraction effort; meaningful against script-kiddie tooling.

**Build-version rotation with N=2 key history**:

- Each shipped patch produces a new HMAC key (because `build_version_string` is part of derivation).
- Loader holds a fixed-length key history array of size N=2: `keys[0] = current build's key`, `keys[1] = prior build's key`.
- On load: compute HMAC under `keys[0]` first; if mismatch, retry once with `keys[1]`.
- If `keys[1]` succeeds: hydrate normally AND queue an immediate re-persist (Rule 7 atomic write) so the save is re-signed under `keys[0]`. Player's next load matches on `keys[0]` and never touches `keys[1]`.
- The "prior version string" is `CURRENT_VERSION_STRING` from the prior release commit, **compiled into the shipped binary** by the build pipeline (compile-time `const`, not read from the save file — never attacker-controllable).

**N=2 is authoritative** (per GDD user decision D1, Pass-5B-remainder):
- N>2 prolongs compatibility for any published cheat tool — strictly harmful.
- N<2 (zero history, pure rotation) destroys every pre-patch save on update — Pillar 1 catastrophe.
- Implementations MUST NOT generalize N to a tuning knob.

**When the key leaks**: ship a patch bumping the version string. Cheat tools built for the old key stop working against new saves. Legitimate saves migrate forward silently on next load via the N-1 fallback.

### Validation order on load (MAGIC → VERSION → HMAC)

This order is **deliberate and load-bearing** (per GDD security-engineer F7/C, Pass-5B-remainder ordering rationale):

1. Validate MAGIC bytes (`"LGLD"`) — mismatch → corruption modal; do not proceed
2. Read VERSION — if newer than `CURRENT_SAVE_VERSION`, apply `future_version_save_policy` (default: refuse + modal)
3. Recompute HMAC over bytes `[0 .. file_length - 33]` using `keys[0]`; on mismatch, retry once with `keys[1]`. Pre-HMAC buffer allocation uses `file_length - 44`, NOT `PAYLOAD_LENGTH` (Rule 2 DoS defense). On `keys[1]` success: queue immediate re-persist under `keys[0]`.
4. Post-HMAC: assert `PAYLOAD_LENGTH == file_length - 44`; mismatch → corruption policy.

**Rejection of HMAC-first**: reordering HMAC to step 1 ("fail-fast efficiency") creates a save-destruction DoS on the N-1 fallback path. A file with intact MAGIC+VERSION but failing HMAC under both keys (e.g., a save legitimately signed by a build older than N-1, a corrupted save with partially-intact header, or a cross-game paste from a same-engine build sharing MAGIC) would burn the HMAC-retry budget and enter corruption policy without the cheap MAGIC-byte gate filtering structurally unrelated files first. The MAGIC→VERSION→HMAC order preserves the N-1 retry exclusively for files plausibly our own save format.

### `_meta` sub-schema (SaveLoadSystem-owned)

The save payload's top-level `"_meta"` key is owned exclusively by SaveLoadSystem. Canonical JSON shape:

```json
"_meta": {
  "slot_index": 1,
  "save_sequence_number": 4217,
  "tamper_suspicious_count": 0,
  "backup_restore_events": []
}
```

Field semantics, widths, persist timing, and overflow behavior are specified in the GDD `_meta` Sub-Schema table; this ADR locks the contract that:

- Consumers MUST NOT read, write, or inspect `_meta` (top-level dict has two disjoint key classes: consumer namespaces and `_meta`).
- Adding a new `_meta` field requires a save-format `VERSION` bump (so migrators can seed defaults).
- `_meta.slot_index` is immutable post-creation; mismatch on load → corruption policy (NOT `.bak` fallback — mismatched slot_index implies the same defect in `.bak`).
- `_meta.save_sequence_number` saturates at 2^53-1 (JSON-lossless int max) with a `push_warning`; MVP uses it diagnostically only (cloud-sync replay detection is V1.0).
- `_meta.tamper_suspicious_count` saturates at 10 000 with a `push_warning`; diagnostic signal for post-launch analytics.
- `_meta.backup_restore_events` is a `PackedInt64Array` of unix timestamps, scrubbed on every persist (entries older than `BACKUP_ESCALATION_WINDOW_SECONDS` dropped pre-write); hard cap 16 entries per persist pre-scrub.

### Atomic write + backup rotation

Per GDD Atomic Write section:

- Write order: `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous `.dat` to `save_slot_1.dat.bak`.
- iOS/Android fallback (rename atomicity not guaranteed): write `.tmp`, write 1-byte `.commit` marker, rename, delete `.commit`. On load, partial state (`.tmp` present but `.commit` missing, or vice versa) falls back to `.bak`.
- HMAC is computed over the **masked** payload bytes, NOT plaintext. Any byte-level edit is caught regardless of whether the attacker knows the XOR mask.

### Architecture diagram

```
                       ┌─── plaintext JSON dict ────────────────────────┐
                       │ {                                              │
   consumers           │   "economy": <Economy.get_save_data()>,        │
   (rank 3,7,10-12,14) │   "hero_roster": <HeroRoster.get_save_data()>, │
                       │   ...                                          │
   SaveLoadSystem ─────│   "_meta": { slot_index, save_seq, ... }       │
   (rank 2)            │ }                                              │
                       └────────────────────┬───────────────────────────┘
                                            │ JSON.stringify()
                                            ▼
                                       UTF-8 bytes
                                            │
                                            ▼  XOR-mask (SHA256-derived stream)
                                       masked bytes
                                            │
        ┌───────────────────────────────────┴───────────────────────────────┐
        │                                                                   │
        ▼                                                                   ▼
   header bytes                                                       HMAC-SHA256
   ┌────┬───┬───┬───┐                                          (over header+masked,
   │MAG │VER│FLG│PLN│                                           keyed by keys[0])
   └────┴───┴───┴───┘                                                       │
        │                                                                   │
        └─────────► concatenate ◄── masked payload ────► concatenate ◄──────┘
                                            │
                                            ▼
                              user://save_slot_1.dat.tmp
                                            │ flush + rename
                                            ▼
                              user://save_slot_1.dat
                                            │ copy
                                            ▼
                              user://save_slot_1.dat.bak
```

### Key interfaces

```gdscript
# In SaveLoadSystem (rank 2)
const _MAGIC: PackedByteArray = PackedByteArray([0x4C, 0x47, 0x4C, 0x44])  # "LGLD"
const _HEADER_SIZE := 12
const _HMAC_SIZE := 32
const CURRENT_SAVE_VERSION: int = 1   # u16 — bump on payload schema change

# Multi-part assembly entry point (parts live in other autoloads under unsuggestive names)
func _derive_keys() -> PackedByteArray:
    # Returns flat array of 64 bytes = keys[0] (32) || keys[1] (32)
    # Implementation reads byte fragments from non-SaveLoad autoloads.
    # See ADR-0004 HMAC key derivation section for the contract.
    pass

# Envelope assembly (all returns are exact byte arrays; no string concatenation)
func _compose_envelope(masked_payload: PackedByteArray) -> PackedByteArray
func _validate_and_extract(envelope: PackedByteArray) -> Variant   # returns plaintext_dict or null
```

## Alternatives Considered

### Alternative 1: AES-GCM via GDExtension binding to libsodium

- **Description**: Use authenticated encryption (AEAD) with libsodium bound via GDExtension, replacing the HMAC + XOR layers with a single AES-GCM operation. Confidentiality + integrity in one primitive.
- **Pros**: Stronger primitive; eliminates the HMAC-from-scratch implementation risk; eliminates the XOR-mask "is this encryption?" confusion in code review; industry-standard AEAD construction.
- **Cons**: Requires GDExtension binding (additional build pipeline, native lib dependency, cross-platform export complexity); the threat model is casual-deterrent — confidentiality is not a goal because the binary ships with the player; the key extractability problem is unchanged (the AEAD key has the same leak surface as the HMAC key); engineering cost is disproportionate for a $15 single-player premium game.
- **Estimated Effort**: ~3 stories of native-binding setup + per-platform export validation; +1 story of cross-platform CI for libsodium builds.
- **Rejection Reason**: Disproportionate to the threat. The GDD explicitly targets the casual-deterrent threshold; stronger primitives don't move the bar against decompiler attackers and cost meaningful build-pipeline complexity. Re-evaluate at V1.0 if cloud save introduces a server-side validation layer where AEAD becomes architecturally relevant.

### Alternative 2: HMAC key derived from per-machine device id

- **Description**: Derive the HMAC key from a stable machine identifier (e.g., `OS.get_unique_id()` or platform-specific equivalents) plus a hardcoded salt. Each player's saves are signed under their own derived key; cross-player save sharing produces an HMAC failure on load.
- **Pros**: Cheat-tool sharing is harder (each player needs to extract their own machine's key); cleaner UX than version-rotation in some failure modes (saves never expire on patch).
- **Cons**: Save migration on machine change is broken — moving a save to a new device fails HMAC verification, surfacing the tamper modal to legitimate users; complicates Steam Cloud or future cloud-save (the device id changes); platform fragmentation (`OS.get_unique_id` semantics vary across platforms — some return process-lifetime ids, some return install ids); legitimate user-machine-replacement looks identical to attacker-machine-clone-then-paste.
- **Estimated Effort**: ~1 story; comparable to multi-part-assembly.
- **Rejection Reason**: Worse legitimate-user UX (machine change = tamper modal) for marginal anti-cheat gain. The GDD's multi-part + version-rotation pattern provides the rotation property without coupling save validity to hardware identity.

### Alternative 3: Hardcoded HMAC key with light obfuscation only (architecture.md OQ-2 option a)

- **Description**: Single hardcoded `_HMAC_KEY` constant in SaveLoadSystem with an obfuscation transform (e.g., XOR with a build-time constant). No multi-part assembly, no rotation.
- **Pros**: Simplest possible implementation; zero coordination cost across autoloads.
- **Cons**: Decompiler attackers locate the labeled constant immediately; no key rotation means a single leak compromises all past and future saves; cheat tools written against MVP keep working against V1.0 unless the entire scheme is replaced; no path to re-sign legitimate saves during a key change.
- **Estimated Effort**: <0.5 story.
- **Rejection Reason**: The version-rotation property (cheat tools break on every patch; legitimate saves migrate silently) is exactly what makes the multi-part scheme worth its modest extra complexity. Hardcoded-constant fails the "what happens when the key leaks?" test that the GDD explicitly designed for.

### Alternative 4: Filename-salted key (architecture.md OQ-2 option c)

- **Description**: Derive the HMAC key from the save filename (`"save_slot_1.dat"`) plus a hardcoded salt. No per-machine state; each slot's key is deterministically different.
- **Pros**: Multi-slot saves get independent keys for free; no per-machine UX concerns.
- **Cons**: Cross-slot copy attacks (rename `slot_2.dat` to `slot_1.dat`) bypass HMAC because the key derivation reads the destination filename; defeats the protection it claims to add. No version rotation. Same hardcoded-salt extraction problem as Alternative 3.
- **Estimated Effort**: <0.5 story.
- **Rejection Reason**: The cross-slot rename attack is real and not trivially mitigated without making the slot index a payload field — at which point the filename derivation stops adding any protection over a constant key. The multi-part + version-rotation approach is strictly better at the same engineering cost.

## Consequences

### Positive

- **Locks a working design**. The GDD's Pass-5B/D/E user decisions are now formal architectural commitments. No ADR-level re-litigation is possible without an explicit superseding ADR.
- **Eliminates implementation-story drift risk**. Acceptance criteria for AC-SL-01 through AC-SL-14 + AC-SL-TAMPER-01 through 05 + AC-SL-HMAC-01 reference envelope byte offsets, HMAC construction, and `_meta` schema fields — all anchored here.
- **Resolves architecture.md OQ-2** with a strictly-stronger answer (multi-part assembly + N=2 rotation) than the three originally-listed alternatives. OQ-2 may be marked CLOSED in architecture.md.
- **Casual-deterrent threat model is honest**. Static secret extractability, HMAC key leak inevitability, and replay residual risk are all called out explicitly with bounded mitigations (offline cap, sequence number, suspicious-count diagnostic) rather than handwaved.
- **HMAC-from-scratch is bounded by RFC 4231 conformance**. The risk of subtly-buggy HMAC is closed by AC-SL-HMAC-01's bit-exact test vector requirement.

### Negative

- **HMAC-from-scratch implementation cost**. ~30 lines of GDScript plus the 7-vector RFC 4231 test suite (~150 lines) is engineering work that doesn't ship value to the player. Mitigated by the GDD's explicit code structure (already drafted).
- **Multi-part key assembly creates implementation-discipline burden**. Implementers must place the byte fragments in non-SaveLoad autoloads under unsuggestive names. A single labeled constant in the wrong file leaks the abstraction. Mitigated by code review checklist + a `/security-audit` pass before MVP ship.
- **N=2 key history rotation has a documented edge case**: a save signed by a build older than N-1 (e.g., player skipped two patches) will fail to load. Mitigation: in-app upgrade reminder before patch N+2 ships ("update from version X required to keep your save"); accepted residual risk for an indie patch cadence.
- **JSON encoding loses ~2x byte efficiency vs MessagePack**. At MVP save sizes (<2KB realistic, 20KB budgeted), this is negligible. Re-evaluate at V1.0 if payload approaches 200KB.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| HMAC-SHA256 from scratch has a subtle bug that passes obvious tests but fails edge cases | Low | Critical (silent tamper-detection failure across all saves) | AC-SL-HMAC-01 mandates bit-exact RFC 4231 §4.2-4.8 conformance BEFORE any tamper AC runs; gated in CI |
| Implementer names a multi-part fragment with a suggestive identifier (`_HMAC_KEY_PART_A`) and the abstraction leaks | Medium | Medium (raises decompiler attacker's effort from "find 3 fragments" to "find 1 labeled fragment") | Code review checklist explicitly forbids any identifier containing "key", "secret", "hmac" in the SaveLoad/HMAC code paths; `/security-audit` static-grep scan before MVP ship |
| N=2 rotation logic regresses under refactor (loader reads `keys[1]` from save file instead of compiled-in const) | Low | Critical (attacker-controllable key material → trivial bypass) | The "compile-time `const` discipline" is a code review gate; same pattern as `integrity_check_enabled`; document in coding-standards.md cross-autoload reference patterns section |
| iOS/Android `.commit` marker fallback corrupts on partial flash-write of the marker itself | Low | Medium (rare; produces a `.bak` fallback path which IS the normal recovery) | Existing `.bak` fallback handles this; adds one Rule 8 backup-restore event to `_meta.backup_restore_events` (rate-limited per the escalation window) |
| `FileAccess.store_*` returning `bool` (4.4 change) — implementation misses an error case | Medium | High (silent partial write that passes HMAC because the partial bytes are still HMAC'd correctly) | Coding standard: every `store_*` call must `assert(file.store_buffer(bytes), ...)` or check the return; CI lint rule once `/architecture-review` matures. Atomic-rename pattern bounds damage to the `.tmp` file even if the assert fails. |
| The 16-byte STATIC_SECRET is reused across multiple shipped products (e.g., a sequel) | Low | Low (XOR mask collision means a cheat tool for one product works against the other) | Build pipeline must regenerate `STATIC_SECRET` per product line; document in release-checklist |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (per persist) | N/A | JSON serialize ~1KB + XOR mask (sub-ms) + HMAC-SHA256 (sub-ms for ~2KB input) + atomic rename (~1-5ms platform-dependent) | < 10ms PC / < 50ms mobile (per Save/Load §D.2) |
| CPU (per load) | N/A | File read + HMAC verify (sub-ms) + JSON parse + consumer hydration | < 50ms PC / < 100ms mobile (per Save/Load §D.3) |
| Memory (steady-state) | N/A | One PackedByteArray of envelope size at write/read time (~2KB MVP, 20KB worst case); zero retained between persists | 512MB PC / 256MB mobile — negligible |
| Disk write per persist | N/A | Single `~2KB-20KB` write + rename + copy-to-bak | N/A (mobile flash wear is acceptable at heartbeat cadence 60s) |
| Save file size | N/A | 44 bytes envelope overhead + JSON payload | <20KB MVP / <200KB V1.0 (per Save/Load §D.1) |

## Migration Plan

**No migration required for MVP** — no shipped saves exist. This ADR codifies the format the first MVP build will write.

**Future schema migrations** (CURRENT_SAVE_VERSION increments):
1. Bump `CURRENT_SAVE_VERSION` const in SaveLoadSystem.
2. Add a migration function `_migrate_from_vN_to_vN_plus_1(payload: Dictionary) -> Dictionary` that transforms the payload dict.
3. On load: if `header.VERSION < CURRENT_SAVE_VERSION`, run the migration chain `[stored_version → ... → current]`, then re-persist atomically to upgrade the file on disk.
4. If migration fails: fall through to corruption policy (try `.bak`, then fresh start with modal).

**Build-version key rotation migration**:
- Each shipped patch advances `CURRENT_BUILD_VERSION_STRING`.
- Build pipeline writes `PRIOR_BUILD_VERSION_STRING` from the previous release commit into the binary as a compile-time `const`.
- N=2 fallback handles in-flight saves silently on next load.
- Saves older than N-1 fail HMAC permanently; player-facing fallback is the standard `.bak` then corruption modal flow (NOT a "save expired" UX — Pillar 1 requires we never blame the player for our patch cadence).

**Rollback plan**: If the multi-part + rotation scheme proves unworkable (e.g., a Godot upgrade breaks `HashingContext` semantics, or the implementation effort blows the MVP budget), supersede this ADR with one adopting Alternative 3 (hardcoded key, no rotation) and accept the weaker threat coverage. Saves authored under the multi-part scheme would need a one-time forced re-signing on load under the new scheme — a Rule 7 atomic re-persist after successful hydration.

## Validation Criteria

- [ ] AC-SL-HMAC-01 passes all 7 RFC 4231 §4.2-4.8 test vectors bit-exactly (BLOCKING for any tamper AC to run).
- [ ] AC-SL-03 (HMAC integrity — tampered save emits `tamper_detected_on_load`) passes after AC-SL-HMAC-01 is green.
- [ ] AC-SL-TAMPER-01 through 05 all pass (direct text edit blocked, hex edit detected, replay bounded by offline cap, clock manipulation detected, production build surfacing constraints CI-enforced).
- [ ] AC-SL-01 (happy path round-trip) passes under both `keys[0]` (steady state) and `keys[1]` fallback path (verifies migration).
- [ ] No identifier in SaveLoadSystem or any of the multi-part HMAC fragment autoloads contains the substrings "key", "secret", or "hmac" (verifiable by grep CI rule).
- [ ] `_meta` is read or written by SaveLoadSystem only (verifiable by grep across consumer source files).
- [ ] Persist time on PC SSD < 10ms median (AC-SL-11 ADVISORY); on minimum-spec mobile < 50ms median.
- [ ] Save file size on a typical MVP roster < 20KB (Save/Load §D.1).
- [ ] `/security-audit` skill produces a clean report on the SaveLoad code path before MVP ship.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/save-load-system.md` Anti-Tamper Specification (Pass-5B-remainder + Pass-5D + Pass-5E) | Save/Load | "Single binary envelope at `user://save_slot_1.dat`; HMAC-SHA256 footer; XOR-masked JSON payload; atomic temp+rename + `.bak` rotation; `_meta` SaveLoad-owned namespace" | Codifies the byte-exact envelope layout, the HMAC scheme, the validation order, and the `_meta` schema as architectural commitments |
| `design/gdd/save-load-system.md` Pass-5B-remainder D1 (key history N=2) | Save/Load | "N=2 key history; keys[1] is prior build's CURRENT_VERSION_STRING compiled into binary; N is NOT a tuning knob" | Locks N=2 in the Decision; lists N>2 and N<2 in Negative consequences with rationale |
| `design/gdd/save-load-system.md` Pass-5B-remainder D4 (HMAC-SHA256 from scratch) | Save/Load | "GDScript HMAC-SHA256 per RFC 2104 layered on HashingContext; no GDExtension/libsodium in MVP" | Codifies the implementation pattern; documents the rejection of the GDExtension alternative; ties to AC-SL-HMAC-01 conformance gate |
| `design/gdd/save-load-system.md` security-engineer F2/F7 (static secret + ordering rationale) | Save/Load | "Static secret is namespace salt only, NOT in HMAC keying; MAGIC→VERSION→HMAC ordering is deliberate" | Codifies both contracts as MUST NOT clauses; documents why HMAC-first reordering is rejected |
| `docs/architecture/architecture.md` Open Question OQ-2 | (cross-cutting) | "Where does the HMAC key come from? (a) hardcoded, (b) per-device, (c) filename-salted" | Resolves by adopting option (d) multi-part assembly + N=2 rotation per the GDD; OQ-2 may be marked CLOSED |
| `docs/architecture/architecture.md` §System Layer Map (SaveLoadSystem at rank 2) | (cross-cutting) | "SaveLoadSystem is the sole persistence boundary; consumers expose get_save_data / load_save_data" | This ADR's `_meta` ownership clause + envelope contract anchors the boundary architecturally |
| ADR-0003 §Save/Load consumer table protocol | Save/Load | "CONSUMER_PATHS is the secondary authoritative list of which autoloads contribute to the payload" | This ADR's payload structure exactly matches: top-level dict has one key per CONSUMER_PATHS entry (snake-cased basename) plus `_meta`; consumers MUST NOT touch `_meta` |

## Related Decisions

- ADR-0001 (Mid-Run Reassignment, Accepted) — `RunSnapshot` deep-copy invariants depend on save-load round-trip integrity (AC-SL-13 / Save/Load Rule 11)
- ADR-0002 (LOSING-clear monotonic credit, Accepted) — `floor_clear_bonus_credited: Dictionary[int, int]` field persists through this envelope; JSON int round-trip is lossless within JSON-safe range
- ADR-0003 (Autoload Rank Table, Accepted) — established `CONSUMER_PATHS` and SaveLoadSystem rank 2 status; this ADR's payload structure depends on that contract
- ADR-F03 (planned) — Time System dual-clock contract; depends on `last_persist_unix_ts` envelope field
- ADR-F05 (planned) — Scene transition + persist coupling; depends on this ADR's atomic-write contract
- `design/gdd/save-load-system.md` — full implementation spec (this ADR's source of truth)
- `design/gdd/save-load-system.md/reviews/save-load-system-review-log.md` — Pass-5B-remainder, Pass-5D, Pass-5E user decisions
- `docs/engine-reference/godot/breaking-changes.md` — `FileAccess.store_*` 4.4 bool return note
- `docs/engine-reference/godot/modules/autoload.md` — autoload ranking foundation
