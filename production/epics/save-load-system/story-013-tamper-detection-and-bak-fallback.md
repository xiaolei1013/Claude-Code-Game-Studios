# Story 013: Tamper detection — HMAC verify fail + `.bak` fallback + tamper modal + counter increment

> **Epic**: save-load-system
> **Status**: Complete (Phase 2 — both 2A central recovery + 2B modal coordination — landed 2026-05-09; full save_load suite 159/159 PASS, full project sweep 1758/1758 PASS).
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

**Phase 2A — central recovery flow + `_meta` persistence (LANDED 2026-05-09)**

Closes ACs 2 (`.bak` attempt), 3 (`.bak` success path + cozy toast + promote re-persist), 6 (header-write wiring for FLAGS.bit0), and the prereq `_meta` namespace persistence (TR-save-load-018/019/025). Ships:
- 4 new private fields: `_meta_slot_index: int = 0`, `_meta_save_sequence_number: int = 0`, `_meta_backup_restore_events: Array[int] = []`. Phase 1's `_tamper_suspicious_count` now also persists.
- New signal `bak_recovered_toast(event_count: int)` — emitted exactly once when `.bak` fallback succeeds, post-hydration, with the within-window event count for UI escalation logic.
- 4 new private helpers:
  - `_compose_meta_dict(now_unix: int) -> Dictionary` — prunes events older than `BACKUP_ESCALATION_WINDOW_SECONDS`, snapshots all 4 `_meta` fields for JSON serialization.
  - `_hydrate_meta_dict(meta: Dictionary) -> void` — restores fields from loaded payload with `int()` coercion (TYPE_FLOAT round-trip safety per project memory) and `clampi` defense on `tamper_suspicious_count`.
  - `_compute_persist_flags() -> int` — returns 1 when `_pending_flags_bit0_tamper`, else 0.
  - `_load_envelope_from_path(path: String) -> Dictionary` — side-effect-free MAGIC → VERSION → split → HMAC pipeline; returns `{ok, envelope_bytes, error_code, failure}`. Reused by `.bak` fallback branch.
- `request_full_persist` modifications: increments `_meta_save_sequence_number` BEFORE compose; injects `_meta` sub-dict into `root_dict`; replaces hardcoded `flags = 0` with `_compute_persist_flags()`; pre-copies prior `.dat → .bak` via `DirAccess.copy_absolute()` BEFORE the rename so the next launch can recover; clears `_pending_flags_bit0_tamper = false` after `save_completed` emits.
- `request_full_load` modifications: on `.dat` HMAC fail → emit `tamper_detected_on_load` (preserved Phase 1 behavior) + attempt `.bak` via `_load_envelope_from_path`. On `.bak` ok: capture recovery timestamp from TickSystem cache (ADR-0005 single-call-site invariant honored), reuse `.bak` envelope bytes for the JSON parse, queue `call_deferred("request_full_persist", "bak_recovery_repersist")` so the recovered `.bak` content is promoted back to `.dat`. Post-hydration block prunes stale events, appends the recovery timestamp, and emits `bak_recovered_toast` — ordering matters because `_hydrate_meta_dict` overwrites in-memory events from the `.bak` payload, then we append. On `.bak` also-fail: existing CORRUPT terminal path runs unchanged.
- Test evidence: `tests/integration/save_load/tamper_detection_test.gd` — 10 test functions, 10/10 PASS in 65ms. Full save_load suite: **152/152 PASS**. Full project sweep: **1751/1751 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans**.

Test groups:
- Group A — `_meta` round-trip: tamper_count + save_sequence_number + backup_restore_events all preserved across persist→reset→load cycle; sequence advances by exactly +1 per persist (TR-save-load-018/019/025).
- Group B — FLAGS.bit0 round-trip: `acknowledge_tamper_modal_yes()` → next persist writes header FLAGS=1 → pending flag clears; persist without pending writes FLAGS=0 (TR-save-load-026).
- Group C — `.bak` rotation on persist: first persist creates `.dat` only; second persist creates `.dat.bak` whose bytes equal the prior `.dat` (ADR-0004 §Atomic write Rule 7).
- Group D — `.bak` fallback success path: corrupt `.dat` HMAC byte → load completes from `.bak` + `bak_recovered_toast` emitted with count=1 + tamper_detected_on_load emitted exactly once + event timestamp appended to in-memory `_meta_backup_restore_events` (TR-save-load-016/017).
- Group E — `.bak` also-corrupt + missing-`.bak` paths: both → CORRUPT terminal state + load_failed emitted; missing `.bak` treated identically to HMAC fail (defensive).

Mid-flow snags resolved:
1. Project memory `project_typed_collection_test_fixtures` bit again — `Array[int]` field rejected `[]` literal assignment in test fixture; fixed via explicit typed local.
2. `_hydrate_meta_dict` ordering: initial implementation appended the recovery event in the `.bak` branch BEFORE consumer hydration, but `_hydrate_meta_dict` (which runs post-consumer-hydration) then clobbered the in-memory events from the `.bak` payload's `_meta`. Restructured: recovery branch only captures the timestamp; the prune+append+toast-emit moved to a post-hydration block so the on-disk `_meta` is the baseline + the just-occurred event is layered on top.
3. ADR-0005 single-call-site invariant: initial implementation used `Time.get_unix_time_from_system()` as a test-env fallback when TickSystem cache was cold. The `process_delta_forbidden_wall_clock_single_call_site_test.gd` static-analysis test caught this immediately. Fix: removed the fallback; tests now warm the TickSystem cache via `_read_wall_clock_unix_time()` in `before_test()` (the canonical pattern for fixtures that need a non-zero `now_ms()`).

**Phase 2B — modal coordination polish (LANDED 2026-05-09)**

Closes ACs 4 (escalation switch), 5 (Both-Corrupt modal + `[Begin]` bootstrap), and 9 (AC-SL-08 distinct path). Ships:
- 3 new signals: `storage_advisory_modal_required(event_count: int)`, `corrupt_both_modal_required()`, `data_registry_error_modal_required()`. The pre-existing `corrupt_both_acknowledged` signal is now wired in source.
- New public method `acknowledge_corrupt_both_begin()` — UI-layer entry point invoked when the player taps `[Begin]` on the Both-Corrupt modal. Resets `_meta` private fields to first-launch defaults; transitions CORRUPT → UNLOADED via direct field write (the documented exception to `_transition_to`'s CORRUPT-terminal table); emits `corrupt_both_acknowledged`; runs the cold-start bootstrap path (UNLOADED → LOADING → READY + `first_launch` + `load_completed` with reason `"corrupt_both_begin_bootstrap"`).
- `request_full_load` modifications:
  - **AC-SL-08 short-circuit at top of body**: when `DataRegistry.state == DataRegistry.State.ERROR`, emits `data_registry_error_modal_required` + transitions to CORRUPT + emits `load_failed`. NO file I/O, NO tamper signal, NO `.bak` attempt. Save file remains byte-identical.
  - **Both-Corrupt branch**: now emits `corrupt_both_modal_required` BEFORE the CORRUPT transition so UI subscribers can stage the modal.
  - **Post-hydration escalation switch**: when `.bak` recovery succeeds, the within-window event count is compared to `BACKUP_ESCALATION_THRESHOLD` (3). If `count >= 3`, emits `storage_advisory_modal_required(count)`. Else emits `bak_recovered_toast(count)`. The two signals are mutually exclusive — exactly one fires per recovery.
- 7 new test functions appended to `tests/integration/save_load/tamper_detection_test.gd` (Groups F, G, H), all 7/7 PASS:
  - **Group F (escalation switch)**: `test_bak_recovery_at_threshold_emits_storage_advisory_instead_of_toast` (count=3, escalation fires); `test_bak_recovery_below_threshold_emits_toast_only` (count=2, cozy toast only).
  - **Group G (Both-Corrupt)**: `test_corrupt_both_emits_corrupt_both_modal_required_signal`; `test_acknowledge_corrupt_both_begin_runs_first_launch_bootstrap`; `test_acknowledge_corrupt_both_begin_resets_meta_to_first_launch_defaults`; `test_acknowledge_corrupt_both_begin_ignored_when_state_not_corrupt` (defensive guard test).
  - **Group H (AC-SL-08)**: `test_data_registry_error_at_load_emits_modal_required_and_aborts` — verifies signal emission + load_failed + CORRUPT transition + NO tamper signal + save file byte-identical pre/post + no `.bak` written.

Mid-flow snag (1, resolved):
- Initial Group F test logic was wrong: seeded `_meta_backup_restore_events` AFTER the two persists, then did a third persist. That third persist's `.bak` rotation captured the second-persist `.dat` which had EMPTY events (the seeded events only landed in the third persist's `.dat`). After `.bak` recovery, hydration showed empty events, so count=1 not 3. Fix: seed the events BEFORE the persists so both `.dat` and `.bak` carry them; then corrupt `.dat` and verify recovery hydrates [t1, t2] then appends → 3.

Story 013 is COMPLETE — all 9 original ACs closed.

---

(Original Phase 2B deferral notes preserved below for audit history.)

The following work was identified as Phase 2B during Phase 2A close-out and was implemented in the same 2026-05-09 session:
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

- [x] On validation returning `{ok: false, failure: "hmac"}` (Story 006 both-keys-fail): emit `tamper_detected_on_load` EXACTLY ONCE; do NOT call any `consumer.load_save_data` on `.dat` — already wired pre-existing; Phase 2A test `test_dat_hmac_fail_with_valid_bak_recovers_via_fallback_path` and `test_both_dat_and_bak_corrupt_transitions_to_corrupt_terminal_state` verify the once-only emission cardinality.
- [x] Attempt `.bak`: re-run validation pipeline on `user://save_slot_1.dat.bak`; on `.bak` HMAC-pass, hydrate from `.bak` via Story 007 loop — **Phase 2A** via `_load_envelope_from_path` helper + envelope-bytes reuse for JSON parse pipeline.
- [x] On `.bak` success: append unix timestamp to `_meta.backup_restore_events` (post-hydration ordering); emit `bak_recovered_toast(event_count)` signal; queue full atomic re-persist via `call_deferred("request_full_persist", "bak_recovery_repersist")` to promote `.bak` → `.dat` — **Phase 2A**. Cozy toast string copy ownership remains UI-layer (signal payload provides count; UI maps to Pass-5E text).
- [x] Backup-restore escalation: if post-append `backup_restore_events` length ≥ `BACKUP_ESCALATION_THRESHOLD` (3) within `BACKUP_ESCALATION_WINDOW_SECONDS` (7 days), show storage-advisory modal with [Check Storage] button INSTEAD of the normal cozy toast — **Phase 2B complete**: `storage_advisory_modal_required(count)` and `bak_recovered_toast(count)` are mutually-exclusive signals; the source-side switch fires the right one based on within-window event count. Verified by `test_bak_recovery_at_threshold_emits_storage_advisory_instead_of_toast` + `test_bak_recovery_below_threshold_emits_toast_only`.
- [x] On `.bak` also HMAC-fail (Both Corrupt): transition to CORRUPT state; show AC-SL-07 modal (Pass-5E copy: "Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]") — single [Begin] button; on tap, emit `corrupt_both_acknowledged`; seed via first-launch bootstrap path (Story 007 `first_launch` signal) — **Phase 2B complete**: `corrupt_both_modal_required` signal fires before CORRUPT transition; `acknowledge_corrupt_both_begin()` UI entry point resets `_meta` defaults, transitions CORRUPT → UNLOADED → LOADING → READY, emits `corrupt_both_acknowledged` + `first_launch` + `load_completed`. Modal copy ownership remains UI-layer.
- [x] HMAC Tamper Modal (distinct from Both-Corrupt): on initial HMAC failure before `.bak` attempt, show tamper modal (Pass-5E-approved cozy copy — already writer-signed-off per GDD); on Yes: synchronous persist writes FLAGS.bit0=1 + `_meta.tamper_suspicious_count + 1` BEFORE modal dismisses — **Phase 2A complete**: header-write wiring landed via `_compute_persist_flags()`; on-disk envelope FLAGS bit verified by `test_acknowledge_tamper_modal_yes_persists_flags_bit0_set_in_envelope_header`. Pending flag clears after `save_completed` emits. Modal trigger from `tamper_detected_on_load` signal is UI-layer scope.
- [x] `_meta.tamper_suspicious_count` increments synchronously on modal-Yes AND on `TimeSystem.flag_suspicious_timestamp_emitted` (Story 009 wiring) — **Phase 2A complete**: in-memory counter (Phase 1) now persists in `_meta` via `_compose_meta_dict` and restores via `_hydrate_meta_dict`. Round-trip verified by `test_meta_round_trip_preserves_tamper_count_and_advances_sequence_number`.
- [x] `SETTINGS_MODIFIED_LABEL_ENABLED = false` compile-time `const` in MVP; UI surface suppressed; on-disk FLAGS.bit0 still persists silently for V1.0 consequence-feature — landed Phase 1.
- [x] AC-SL-08 path (DataRegistry ERROR) coexists: shows distinct modal ("Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]") — NO filesystem writes on this path; NOT a tamper path — **Phase 2B complete**: `data_registry_error_modal_required` signal fires when `request_full_load` detects `DataRegistry.state == ERROR`; short-circuits before any file I/O. Verified by `test_data_registry_error_at_load_emits_modal_required_and_aborts` — confirms signal emission + no tamper signal + save file byte-identical + no `.bak` written.
- [ ] Save-file surfacing contract (TR-save-load-054 cross-ref for Story 014): production build does NOT expose `debug_pause_before_rename` or `save_file_path` knob — **Story 014 scope** (cross-cutting; not closed by Story 013).

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
