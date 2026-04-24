# Story 008: Atomic write order + iOS/Android `.commit` marker fallback + `.bak` rotation

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-001, TR-save-load-012, TR-save-load-013, TR-save-load-014, TR-save-load-015, TR-save-load-016, TR-save-load-017, TR-save-load-018, TR-save-load-029
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — atomic write + backup rotation), ADR-0003 (SaveLoadSystem is sole owner of I/O)
**ADR Decision Summary**: Write order is `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous `.dat` to `save_slot_1.dat.bak`. iOS/Android rename atomicity not guaranteed — fallback pattern: write `.tmp`, write 1-byte `.commit` marker, rename, delete `.commit`. On load, partial state (`.tmp` present but `.commit` missing, or vice versa) falls back to `.bak`. `FileAccess.store_*` returns `bool` since 4.4; every call MUST be asserted/checked. `flush()` returns `void` — failure undetectable.

**Engine**: Godot 4.6 | **Risk**: HIGH (post-cutoff API behavior: `FileAccess.store_buffer -> bool` since 4.4; iOS/Android rename atomicity platform-specific; `DirAccess.rename -> Error` enum returns — NOT bool)
**Engine Notes**: `FileAccess.store_buffer() -> bool`, `FileAccess.flush() -> void`, `DirAccess.rename() -> Error` (ADR-0004 + Pass-5D 2026-04-21 verified against Godot 4.6 reference docs). `store_buffer == false` → abort persist, close handle, delete `.tmp`, log error, retry next heartbeat; do NOT rename.

**Control Manifest Rules (Foundation Layer, atomic write)**:
- **Required**: Atomic write order `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous → `.bak`. iOS/Android fallback uses `.commit` marker. `FileAccess.store_*` calls (4.4+ return bool) MUST be asserted/checked. `store_buffer == false` aborts persist without rename; retry next heartbeat. On `.dat` integrity fail → try `.bak`; on `.bak` success → hydrate + show cozy toast + re-persist to promote. Persist `backup_restore_events` as PackedInt64Array scrubbed on every persist. `save_sequence_number` incremented pre-HMAC on successful persist; failed persist does NOT advance.
- **Forbidden**: Using `assert(file.store_buffer(...))` in release-dependent code paths (assert is stripped from release exports — use explicit `if not ok: push_error; abort` pattern).

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `save_slot_path(slot: int) -> String` helper returns `user://save_slot_%d.dat` (MVP: slot=1 only); `.tmp` / `.bak` / `.commit` variants via suffix
- [ ] `_atomic_persist(envelope: PackedByteArray) -> bool` performs the write pipeline and returns success
- [ ] Write pipeline desktop path (Windows/macOS/Linux): (1) open `.tmp` WRITE; (2) `store_buffer(envelope)` → check bool result; (3) `flush()`; (4) close; (5) copy existing `.dat` to `.bak` (if `.dat` exists); (6) `DirAccess.rename(tmp, dat)` → check `Error == OK`
- [ ] Write pipeline iOS/Android fallback: (1) open `.tmp` WRITE + `store_buffer` + check; (2) write `.commit` 1-byte marker; (3) copy `.dat` → `.bak` (if exists); (4) `DirAccess.rename(tmp, dat)` → check Error; (5) delete `.commit`
- [ ] On `store_buffer == false`: close handle, delete `.tmp`, `push_error`, return false (no rename; retry on next heartbeat per TR-save-load-013)
- [ ] On `DirAccess.rename()` returning non-OK: `push_error` with Error code in message, return false; `.bak` integrity preserved (was copied BEFORE rename)
- [ ] Load-time crash recovery: if `.tmp` present AND (`.commit` absent on iOS/Android, OR `.tmp` present on desktop at all), delete `.tmp` unconditionally on load entry (TR-save-load-011 — Story 006 anchor)
- [ ] `.bak` fallback path: if `.dat` integrity fails, attempt `.bak`; on success, hydrate + queue full atomic re-persist to promote `.bak` → `.dat` (TR-save-load-016)
- [ ] Backup-restore event logged: append `Time.get_unix_time_from_system()` to `_meta.backup_restore_events` on `.bak` success (TR-save-load-018 — anchors this story; `_meta` management detailed in Story 009)
- [ ] `save_sequence_number` increment happens pre-HMAC on a SUCCESSFUL persist; a failed persist leaves it unchanged (TR-save-load-029)
- [ ] Platform detection: `OS.get_name()` in `["iOS", "Android"]` selects the `.commit` marker fallback; else desktop rename path
- [ ] `flush()` return value is `void` in Godot 4.6 — document as accepted mobile caveat per TR-save-load-014 (failure undetectable; covered by `.bak` fallback on next launch)

---

## Implementation Notes

- `DirAccess.rename()` returns `Error` (enum), NOT bool — check `== OK`; on non-OK, do NOT proceed (Pass-5D 2026-04-21 verified)
- `FileAccess.store_buffer() -> bool` (since 4.4) — bool return indicates whether all bytes were written; `false` is a partial-write warning; abort path deletes `.tmp`
- Use `FileAccess.open(path, FileAccess.WRITE)` then check `FileAccess.get_open_error() == OK` (also 4.4+ pattern)
- `DirAccess.copy_absolute(src, dst)` or `DirAccess.copy(src, dst)` for `.dat` → `.bak` step; check return Error
- The order "copy `.dat` → `.bak` BEFORE rename `.tmp` → `.dat`" is critical — if rename fails, `.bak` still holds the previous good state. If the order were reversed (rename first), a failed `.bak` copy could leave no backup with only the new `.dat`
- iOS/Android: the GDD describes the `.commit` marker pattern as a fallback when rename is non-atomic; the marker is a 1-byte file indicating "rename is about to commit" — its presence-or-absence vs `.tmp` presence lets load detect crash state. On load, if both `.tmp` and `.commit` are present, treat as pre-rename crash → delete both, use `.dat` if present, else fall through to `.bak`. If `.tmp` present but `.commit` absent (mid-marker crash), also delete `.tmp`
- `_save_file_path` knob override (TR-save-load-052): debug-only static setter; production builds enforce empty via `_ready()` quit-guard
- `flush()` returns void → failure is undetectable. Accepted caveat because mobile flash-write errors typically manifest at next read/rename step; worst case is `.bak` fallback on next launch (not a data-loss event, just a progress-window loss documented in Rule 8 toast)
- Debug hook `debug_pause_before_rename` (TR-save-load-053 + AC-SL-02) emits a signal between `flush()` completion and `DirAccess.rename()` call when armed by `SaveLoadFixture.arm_pause_before_rename()`; production-guarded by `if OS.is_debug_build()`

---

## Out of Scope

- Story 009: `_meta.backup_restore_events` scrub logic + cap management (this story appends; Story 009 manages the array semantics)
- Story 010: schema migration (full atomic re-persist after migration uses this pipeline)
- Story 013: tamper UX + `.bak` fallback modal copy
- Story 015: performance measurement against the <10ms/<50ms budget

---

## QA Test Cases

- **TR-save-load-012**: Atomic write order (desktop path)
  - **Given**: Existing valid `.dat` at the slot; a fresh composed envelope to persist
  - **When**: `_atomic_persist(envelope)` runs on desktop (`OS.get_name() == "Windows"` or "macOS" or "Linux")
  - **Then**: File operations occur in order: `.tmp` write + flush + close → `.dat` copy to `.bak` → `DirAccess.rename(tmp, dat)`; final filesystem state has `.dat` (new content), `.bak` (old content), NO `.tmp`
  - **Edge cases**: No prior `.dat` exists → skip `.bak` copy step; `.bak` remains absent post-persist (first-launch state)

- **TR-save-load-012 (iOS/Android fallback)**: `.commit` marker pattern
  - **Given**: `OS.get_name() == "iOS"` (or "Android"); fresh envelope
  - **When**: `_atomic_persist(envelope)` runs
  - **Then**: `.tmp` written + flushed + closed → `.commit` 1-byte marker written → `.dat` copy to `.bak` → `DirAccess.rename(tmp, dat)` → `.commit` deleted; final filesystem state has `.dat` (new), `.bak` (old), NO `.tmp`, NO `.commit`
  - **Edge cases**: On non-atomic rename failure, `.commit` remains → next load detects pre-rename state and uses `.bak`

- **TR-save-load-013**: `store_buffer == false` abort path
  - **Given**: `FileAccess.store_buffer` is mocked to return `false` mid-write
  - **When**: `_atomic_persist` runs
  - **Then**: `push_error` emitted; `.tmp` is deleted; `.dat` and `.bak` are unchanged; function returns `false`; no rename attempted
  - **Edge cases**: `.dat` state is bit-identical to pre-call; next heartbeat retries

- **TR-save-load-015 (AC-SL-02 substrate)**: Mid-persist crash leaves no half-written `.dat`
  - **Given**: `debug_pause_before_rename` is armed; the process is killed after `flush()` but before `DirAccess.rename`
  - **When**: Fresh launch loads from the same `user://` directory
  - **Then**: Load entry deletes the stale `.tmp` (Story 006); `.dat` still holds pre-persist state OR is absent (first launch); loaded state is internally consistent; no consumer observes a partial field write (AC-SL-02)
  - **Edge cases**: Post-rename pre-`.bak`-copy crash (desktop order puts copy BEFORE rename so this is impossible; on iOS/Android, `.commit` marker reveals the state)

- **TR-save-load-016**: `.bak` fallback + promotion re-persist
  - **Given**: `.dat` fails HMAC validation (Story 006 returns `{ok: false, failure: "hmac"}`); `.bak` is present and valid
  - **When**: Load pipeline falls back to `.bak`
  - **Then**: `.bak` loads successfully; hydration proceeds; cozy toast message queued (Story 013 UX); a full atomic re-persist fires that writes `.bak` content to `.dat` (overwriting corrupted `.dat`)
  - **Edge cases**: Post-promotion, next save reads `.dat` (now good) and continues normally

- **TR-save-load-018**: `backup_restore_events` append on fallback
  - **Given**: `.bak` fallback succeeds
  - **When**: The promotion re-persist composes its envelope
  - **Then**: `_meta.backup_restore_events` array contains a new entry with the current unix timestamp; entries older than `BACKUP_ESCALATION_WINDOW_SECONDS` (7 days) are scrubbed (Story 009 enforces scrub)
  - **Edge cases**: If post-append array length ≥ `BACKUP_ESCALATION_THRESHOLD` (3), storage-advisory modal fires on next load (TR-save-load-017 — UX in Story 013)

- **TR-save-load-029**: `save_sequence_number` advances on success only
  - **Given**: Pre-persist `_meta.save_sequence_number == 100`; `store_buffer == false` mid-write
  - **When**: `_atomic_persist` aborts
  - **Then**: `_meta.save_sequence_number == 100` (unchanged; the would-be-101 was pre-HMAC in the composed envelope but never landed)
  - **Edge cases**: Successful persist → counter is `101` on next read; rollover saturation handled by Story 009

- **Platform detection**: Path selection on each OS
  - **Given**: Test harness forces `OS.get_name()` to each of "iOS", "Android", "macOS", "Windows", "Linux"
  - **When**: `_atomic_persist` selects its branch
  - **Then**: iOS/Android take the `.commit` marker path; macOS/Windows/Linux take the rename-only path
  - **Edge cases**: Unknown OS (Steam Deck reports "Linux") — defaults to desktop path

- **AC-SL-02 (atomic-write invariant)**: No half-written save survives interruption
  - **Given**: Atomic persist interrupted at any point between `flush()` and `DirAccess.rename()`
  - **When**: Fresh launch
  - **Then**: Four conditions hold: (1) `.dat` exists + passes HMAC, OR file-absence; (2) `.tmp` absent; (3) loaded state is internally consistent; (4) no consumer observes a partial field write
  - **Edge cases**: The full AC-SL-02 test is covered by Story 015's integration-level fuzz; this story's unit test verifies the write-ordering primitives

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/atomic_write_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (envelope layout, `_compose_envelope` output buffer), Story 006 (validation consumes the output — but this story writes, doesn't validate)
- **Unlocks**: Story 009 (`_meta.backup_restore_events` array semantics), Story 010 (migration re-persist uses this path), Story 013 (tamper + `.bak` modal paths call into this), Story 015 (performance measurement)
