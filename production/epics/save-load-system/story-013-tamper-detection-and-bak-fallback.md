# Story 013: Tamper detection — HMAC verify fail + `.bak` fallback + tamper modal + counter increment

> **Epic**: save-load-system
> **Status**: Ready (Phase 1 of 2 landed 2026-05-08 — peripheral surface; central `.bak` fallback path remains. See Progress notes below.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-26

---

## Progress notes

**Phase 1 — peripheral surface (LANDED 2026-05-08)**

Closes ACs 7 + 8 (and AC 1 was already wired pre-existing in source). Ships:
- 4 constants on `SaveLoadSystem`: `BACKUP_ESCALATION_THRESHOLD = 3`, `BACKUP_ESCALATION_WINDOW_SECONDS = 604_800` (7 days), `SETTINGS_MODIFIED_LABEL_ENABLED = false`, `MAX_TAMPER_SUSPICIOUS_COUNT = 10_000`.
- Session-scoped `_tamper_suspicious_count: int` field with saturation cap.
- `_pending_flags_bit0_tamper: bool` field tracking the next-persist FLAGS.bit0 = 1 intent.
- `_on_flag_suspicious_timestamp_emitted` body filled in (was a `pass` stub) — increments counter via `_increment_tamper_count` saturation-aware helper.
- Public `acknowledge_tamper_modal_yes()` UI entry point — synchronously increments counter AND sets `_pending_flags_bit0_tamper = true` BEFORE returning (per AC: synchronous persist completes before modal dismiss; the on-disk-write side of that contract lands in Phase 2).
- Public read accessors: `get_tamper_suspicious_count()`, `get_pending_flags_bit0_tamper()`.
- Test evidence: `tests/unit/save_load/tamper_counter_and_constants_test.gd` — 11 test functions, 11/11 PASS. Covers all 4 constants, initial state, both entry points (TickSystem-driven and modal-Yes), saturation cap, and aggregation across both entry points.

Already wired pre-existing in source (AC 1 — independent of this Phase 1 PR):
- `tamper_detected_on_load.emit()` fires exactly once when both HMAC keys fail (line 664 of `save_load_system.gd`); no `consumer.load_save_data` is called on the corrupted `.dat`. The CORRUPT state transition + signal emission for AC 1 are operational.

**Phase 2 — central recovery flow (DEFERRED — Story 013 stays Ready)**

ACs 2-6, 9 remain open. Phase 2 work:
- `.bak` fallback file I/O: refactor `request_full_load`'s envelope-read pipeline (lines 584-685) into a helper that runs on either `.dat` or `.bak`. After `.dat` HMAC fail, attempt `.bak`; on `.bak` HMAC pass, hydrate from `.bak`, append timestamp to `_meta.backup_restore_events`, queue full atomic re-persist to promote `.bak` → `.dat`.
- Backup-restore escalation: scrub `_meta.backup_restore_events` entries older than `BACKUP_ESCALATION_WINDOW_SECONDS`, then check post-append count against `BACKUP_ESCALATION_THRESHOLD`. On threshold hit, emit a storage-advisory signal so UI shows the [Check Storage] modal instead of the cozy `.bak`-recovered toast.
- "Both Corrupt" flow: when `.bak` also fails HMAC, transition to CORRUPT, emit a distinct signal so UI shows the AC-SL-07 single-button modal; on player [Begin] tap, emit `corrupt_both_acknowledged` and seed via the first-launch bootstrap path.
- AC-SL-08 distinct path: DataRegistry ERROR on boot is NOT a tamper path — emit a separate signal so the UI shows the "reinstall the app" modal (no filesystem writes).
- Header-write wiring for `_pending_flags_bit0_tamper`: thread the pending flag through `_compose_envelope`'s FLAGS field and clear the in-memory flag on persist success.
- `_meta` namespace persistence: out-of-scope-for-this-story but a PREREQ — currently `_meta` is NOT actually composed into the persist `root_dict` despite Story 009's audit-cascade Status flip claiming `_meta` is shipped. The session-scoped counter from Phase 1 needs an in-memory ↔ on-disk mirror to survive across launches; that wiring is a follow-up too. The existing `_meta` skeleton (CONSUMER_PATHS / `save_sequence_number` references in code comments) needs to actually land in the envelope.

When all of the above lands, Story 013's Status flips to Complete. Until then it's Ready/Phase-1-prep.

---

## Context

**GDD**: `design/gdd/save-load-system.md` §HMAC Verification Behavior + AC-SL-03 + AC-SL-TAMPER-01..05
**Requirements**: TR-save-load-016, TR-save-load-017, TR-save-load-023, TR-save-load-025, TR-save-load-026, TR-save-load-056, TR-save-load-059
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — HMAC verification behavior + tamper response), ADR-0007 (cross-ref for "Try Again / Stay Here" modal pattern mirror)
**ADR Decision Summary**: On HMAC failure (both `keys[0]` + `keys[1]`), try `.bak`; on `.bak` HMAC-pass, hydrate + cozy toast + promote re-persist. On `.bak` also failing, fire "Both Corrupt" modal ("Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]") — seed fresh save via first-launch bootstrap. On HMAC modal-Yes: synchronously write FLAGS.bit0 = 1 + increment `_meta.tamper_suspicious_count` BEFORE modal dismiss. `SETTINGS_MODIFIED_LABEL_ENABLED = false` in MVP (UI surface suppressed; on-disk FLAGS.bit0 still persists).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (tamper response orchestrates multiple subsystems: validation, `.bak` fallback, modal UX, sync FLAGS.bit0 write, counter increment — ordering and signal-emission cardinality matter)
**Engine Notes**: `tamper_detected_on_load` signal emitted exactly ONCE per load session (TR-save-load-056). All modals are non-blocking toasts except the "Both Corrupt" modal which is single-button blocking per AC-SL-07.

**Control Manifest Rules (Foundation Layer, tamper detection)**:
- **Required**: On `.dat` integrity fail → try `.bak`; on `.bak` success → hydrate + cozy toast + re-persist to promote. Backup-restore escalation: if `.bak` fallback fires ≥3 times in 7 days, show storage-advisory modal with [Check Storage] button. On HMAC fail + Yes-on-modal: synchronously persist FLAGS.bit0=1 AND increment `_meta.tamper_suspicious_count` BEFORE modal dismiss. `tamper_detected_on_load` signal emitted exactly once before any `consumer.load_save_data` on HMAC failure. All fallback modals are non-blocking toasts with cozy writer-approved copy; corrupt modal single [Begin] button.
- **Forbidden**: Silent hydration on HMAC fail (must surface modal). Multi-emit of `tamper_detected_on_load`. Surfacing "Modified" label in MVP (`SETTINGS_MODIFIED_LABEL_ENABLED = false`).

---

## Acceptance Criteria

*Scoped to this story (per GDD AC-SL-03, AC-SL-06, AC-SL-07, AC-SL-TAMPER-01..05):*

- [x] On validation returning `{ok: false, failure: "hmac"}` (Story 006 both-keys-fail): emit `tamper_detected_on_load` EXACTLY ONCE; do NOT call any `consumer.load_save_data` on `.dat` — already wired pre-existing at `save_load_system.gd:664`. Phase 1 verified the wiring continues to work; integration test for the once-only cardinality is owned by Phase 2.
- [ ] Attempt `.bak`: re-run validation pipeline on `user://save_slot_1.dat.bak`; on `.bak` HMAC-pass, hydrate from `.bak` via Story 007 loop — **Phase 2**
- [ ] On `.bak` success: append unix timestamp to `_meta.backup_restore_events` (Story 009 mechanic); queue cozy toast (Pass-5E copy: "Your guild is still here. We restored your last backup — a few minutes of progress may be missing."); queue full atomic re-persist (Story 008) to promote `.bak` → `.dat` — **Phase 2**
- [ ] Backup-restore escalation: if post-append `backup_restore_events` length ≥ `BACKUP_ESCALATION_THRESHOLD` (3) within `BACKUP_ESCALATION_WINDOW_SECONDS` (7 days), show storage-advisory modal with [Check Storage] button INSTEAD of the normal cozy toast — **Phase 2** (constants landed Phase 1; usage wiring deferred)
- [ ] On `.bak` also HMAC-fail (Both Corrupt): transition to CORRUPT state; show AC-SL-07 modal (Pass-5E copy: "Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]") — single [Begin] button; on tap, emit `corrupt_both_acknowledged`; seed via first-launch bootstrap path (Story 007 `first_launch` signal) — **Phase 2**
- [~] HMAC Tamper Modal (distinct from Both-Corrupt): on initial HMAC failure before `.bak` attempt, show tamper modal (Pass-5E-approved cozy copy — already writer-signed-off per GDD); on Yes: synchronous persist writes FLAGS.bit0=1 + `_meta.tamper_suspicious_count + 1` BEFORE modal dismisses — **Phase 1 partial**: `acknowledge_tamper_modal_yes()` UI entry point wired; counter increments synchronously; FLAGS.bit0 pending intent captured in `_pending_flags_bit0_tamper`. Header-write wiring (actually flipping the on-disk FLAGS bit) and modal trigger from the `tamper_detected_on_load` signal are Phase 2.
- [~] `_meta.tamper_suspicious_count` increments synchronously on modal-Yes AND on `TimeSystem.flag_suspicious_timestamp_emitted` (Story 009 wiring) — **Phase 1 partial**: in-memory counter increments on both paths via `_increment_tamper_count` (saturation-aware); `_on_flag_suspicious_timestamp_emitted` body filled in. On-disk persistence wiring (the `_meta` namespace serialization) is Phase 2 because Story 009's audit-cascade Status flip didn't actually compose `_meta` into the persist `root_dict`.
- [x] `SETTINGS_MODIFIED_LABEL_ENABLED = false` compile-time `const` in MVP; UI surface suppressed; on-disk FLAGS.bit0 still persists silently for V1.0 consequence-feature — landed Phase 1.
- [ ] AC-SL-08 path (DataRegistry ERROR) coexists: shows distinct modal ("Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]") — NO filesystem writes on this path; NOT a tamper path — **Phase 2**
- [ ] Save-file surfacing contract (TR-save-load-054 cross-ref for Story 014): production build does NOT expose `debug_pause_before_rename` or `save_file_path` knob — **Phase 2** (cross-cutting with Story 014)

---

## Implementation Notes

- Tamper response flow:
  ```
  load .dat → validation fail (hmac) →
     emit tamper_detected_on_load (once) →
     show HMAC-tamper modal →
        on user Yes → sync persist FLAGS.bit0=1 + tamper_count++ → modal dismiss →
        attempt .bak →
           .bak valid → hydrate + cozy toast + promote re-persist → READY
           .bak invalid → CORRUPT modal → on [Begin] → first-launch bootstrap + fresh save → READY
  ```
- AC-SL-TAMPER-01 (XOR mask blocks text edit) is already substantiated by Story 003's mask determinism test; this story's test re-verifies at the integration level
- AC-SL-TAMPER-02 (hex edit to HMAC region detected) exercises this story's path — flip any byte in the 32-byte HMAC footer → HMAC fail on `keys[0]` + `keys[1]` → tamper detected
- AC-SL-TAMPER-04 (clock manipulation detected) is a separate branch: `TimeSystem.flag_suspicious_timestamp_emitted` fires → `_meta.tamper_suspicious_count++` → next-launch warning toast
- AC-SL-TAMPER-05 (CI build-step) is a separate surface; owned by Story 014
- AC-SL-HMAC-01 is a PRE-CONDITION to this story; Story 004 must be green before any AC-SL-TAMPER-* test runs (noted in test file header)
- Modal ownership: SaveLoadSystem emits signals (`tamper_detected_on_load`, `corrupt_both_acknowledged`) + returns `LoadResult` codes; a UI layer (likely `PresentationRoot` or SceneManager's overlay system per ADR-0007) shows the modals. This story stubs the UI callouts with a modal-id enum and writer-signed-off copy strings
- Writer-signed-off copy strings (LOCKED per Pass-5E 2026-04-21):
  - Cozy `.bak` toast: "Your guild is still here. We restored your last backup — a few minutes of progress may be missing."
  - HMAC tamper modal: [Pass-5E confirmed "already cozy, no rewrite needed" — writer sign-off logged]. Actual copy lives in GDD Rule 8; reviewer cross-ref before implementing
  - Both Corrupt modal: "Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]"
  - AC-SL-08 DataRegistry ERROR modal: "Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]"
  - Storage-advisory modal [Check Storage button]: copy pending writer sign-off (Pass-5E noted new knobs; modal copy TBD or may already be in GDD §edge-cases)

---

## Out of Scope

- Story 007: `first_launch` signal emission (this story triggers it via bootstrap path)
- Story 008: atomic write for the promote-re-persist (consumed here)
- Story 009: `_meta.tamper_suspicious_count` + `_meta.backup_restore_events` mechanics (consumed here)
- Story 014: CI grep + production-build surfacing contract
- Future: V1.0 `SETTINGS_MODIFIED_LABEL_ENABLED = true` consequence-feature

---

## QA Test Cases

- **AC-SL-03 / TR-save-load-023 / TR-save-load-056**: HMAC tamper emits signal once
  - **Given**: Valid save in `.dat` with one byte flipped in the payload region (via `SaveLoadFixture.corrupt_byte_at_offset`)
  - **When**: Load runs
  - **Then**: Validation returns `{ok: false, failure: "hmac"}`; `tamper_detected_on_load` emits EXACTLY ONCE; no consumer's `load_save_data` called on the corrupted `.dat`
  - **Edge cases**: Flip in header (MAGIC or VERSION) → different failure code (`magic` or `version`); flip in HMAC footer region — same path

- **AC-SL-TAMPER-02**: Hex edit to HMAC region detected (32 byte-flip iterations)
  - **Given**: A valid save; iterate each of the 32 HMAC bytes and flip one at a time
  - **When**: Load runs for each iteration
  - **Then**: Each iteration: `tamper_detected_on_load` emits; `LoadResult.code == ERR_TAMPER_SUSPECTED`; `footer_hmac_match == false`
  - **Edge cases**: `.bak` offered per AC-SL-06 when valid backup exists; CORRUPT modal per AC-SL-07 when no valid backup

- **AC-SL-06 / TR-save-load-016**: `.bak` fallback + promote
  - **Given**: `.dat` HMAC-corrupted (per AC-SL-03 fixture); `.bak` valid
  - **When**: Load pipeline runs
  - **Then**: `.bak` loads successfully; cozy toast queued; full atomic re-persist promotes `.bak` content to `.dat`; next launch reads `.dat` (now good) with no fallback
  - **Edge cases**: `backup_restore_events` array appends this event's unix timestamp

- **TR-save-load-017**: Escalation threshold triggers storage-advisory modal
  - **Given**: `_backup_restore_events` already has 2 entries within 7-day window; `.bak` fallback fires a 3rd time
  - **When**: Post-append length is 3
  - **Then**: Storage-advisory modal fires (with [Check Storage] button) INSTEAD of the normal cozy toast
  - **Edge cases**: Older-than-7-day entries are scrubbed first (Story 009); threshold is about within-window count

- **AC-SL-07**: Both Corrupt modal + first-launch seed
  - **Given**: `.dat` HMAC-fail AND `.bak` HMAC-fail
  - **When**: Load pipeline exhausts recovery paths
  - **Then**: State = CORRUPT; modal with Pass-5E copy "Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]"; on [Begin] tap → `corrupt_both_acknowledged` emits → first-launch bootstrap runs → fresh save seeds → `save_completed` after first persist
  - **Edge cases**: No silent data loss; single-button modal (per Rule 8 — nothing to Cancel back to)

- **TR-save-load-025**: FLAGS.bit0 + tamper counter synchronous on modal-Yes
  - **Given**: HMAC tamper modal showing; user taps "Yes"
  - **When**: Modal-Yes handler fires
  - **Then**: Synchronous persist completes BEFORE modal dismiss; post-persist `.dat` has FLAGS.bit0 = 1 and `_meta.tamper_suspicious_count` incremented; modal dismisses only after persist success
  - **Edge cases**: Sync persist failure → modal stays visible; offer retry

- **TR-save-load-026**: `SETTINGS_MODIFIED_LABEL_ENABLED = false` in MVP
  - **Given**: A save with FLAGS.bit0 = 1 (previously-tampered save loaded clean on `keys[0]`)
  - **When**: Settings screen renders
  - **Then**: No "Modified" label visible (UI surface suppressed); on-disk state still has FLAGS.bit0 = 1 (persists silently)
  - **Edge cases**: Grep for `SETTINGS_MODIFIED_LABEL_ENABLED = true` in production export fails the build (Story 014 owns CI check)

- **AC-SL-08**: DataRegistry ERROR coexistence
  - **Given**: `DataRegistry.state == ERROR` at SaveLoadSystem `_ready()` time
  - **When**: Load pipeline runs
  - **Then**: Transitions to CORRUPT; shows AC-SL-08 "reinstall the app — your save is safe and untouched" modal; NO filesystem writes (save file preserved bit-identical); NOT classified as tamper (no `tamper_detected_on_load` emitted)
  - **Edge cases**: The distinction matters for diagnostics — a content-load failure differs from a tamper event

- **AC-SL-TAMPER-04**: Clock manipulation counter escalation
  - **Given**: A time-rewind scenario where `TimeSystem.flag_suspicious_timestamp_emitted` fires on load
  - **When**: Handler runs
  - **Then**: `_meta.tamper_suspicious_count` increments; next-launch warning toast queued; `elapsed_offline_seconds = 0` enforced by TimeSystem
  - **Edge cases**: Attacker gain bounded to one `offline_cap_seconds` window

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/tamper_detection_test.gd` — must exist and pass (AC-SL-HMAC-01 must be green first)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 004 (HMAC RFC 4231 PRECONDITION), Story 006 (validation pipeline), Story 007 (consumer loop + first_launch signal), Story 008 (atomic write for `.bak` promote + sync FLAGS.bit0 write), Story 009 (`_meta` counter + array semantics)
- **Unlocks**: Story 014 (CI surfacing contract), Story 015 (AC-SL-HMAC-01 already passing as gate)
