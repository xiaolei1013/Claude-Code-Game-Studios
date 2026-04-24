# Story 009: `_meta` namespace — slot_index, save_sequence_number, tamper counters, backup events

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §`_meta` Sub-Schema
**Requirements**: TR-save-load-027, TR-save-load-028, TR-save-load-029, TR-save-load-030, TR-save-load-018, TR-save-load-017, TR-save-load-025, TR-save-load-026, TR-save-load-042
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — `_meta` sub-schema + owner exclusivity)
**ADR Decision Summary**: `_meta` namespace is owned exclusively by SaveLoadSystem; consumers MUST NOT read or write any `_meta` field. Fields: `slot_index` (immutable post-creation), `save_sequence_number` (saturates at 2^53−1), `tamper_suspicious_count` (saturates at 10 000), `backup_restore_events` (`PackedInt64Array`, hard cap 16 per persist pre-scrub; scrubbed every persist to drop entries older than `BACKUP_ESCALATION_WINDOW_SECONDS`). Adding a new `_meta` field requires a save-format VERSION bump.

**Engine**: Godot 4.6 | **Risk**: LOW (pure dictionary + array manipulation; no engine API risk)
**Engine Notes**: `PackedInt64Array` stable since 4.0; JSON encoding as plain `Array[int]` on the wire, rehydrated to `PackedInt64Array` on load (explicit conversion).

**Control Manifest Rules (Foundation Layer, `_meta`)**:
- **Required**: `_meta` namespace owned exclusively by SaveLoadSystem. Fields: `slot_index` (immutable post-creation, mismatch → CORRUPT, `.bak` NOT attempted), `save_sequence_number` (saturates 2^53−1 with push_warning), `tamper_suspicious_count` (saturates 10 000 with push_warning), `backup_restore_events` (PackedInt64Array, hard cap 16 per persist, scrubbed to BACKUP_ESCALATION_WINDOW_SECONDS every persist). Adding a new `_meta` field requires a save VERSION bump.
- **Forbidden**: Consumers reading or writing `_meta` (CI grep across consumer source files). Silent override on slot_index mismatch. Exposing `_meta` fields via any consumer's `get_save_data()` output.

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `_meta` is composed exclusively inside SaveLoadSystem; never surfaced to any consumer's `get_save_data()` input or `load_save_data` output
- [ ] `slot_index: int` is immutable post-creation; on load, mismatch (`loaded_slot != expected_slot`) → CORRUPT state + modal; `.bak` is NOT attempted (TR-save-load-030)
- [ ] `save_sequence_number: int` increments pre-HMAC on successful persist (TR-save-load-029); saturates at `2^53 - 1` (9 007 199 254 740 991 — JSON-lossless max) with a single `push_warning` on saturation
- [ ] `tamper_suspicious_count: int` increments on `flag_suspicious_timestamp` AND on Yes-on-tamper-modal (TR-save-load-025); saturates at 10 000 with `push_warning`; diagnostic only in MVP
- [ ] `backup_restore_events: PackedInt64Array`: scrubbed on every persist to drop entries older than `now - BACKUP_ESCALATION_WINDOW_SECONDS` (604 800 = 7 days); hard cap 16 entries per persist pre-scrub — 17th append silently dropped + `push_warning`; appended on `.bak` fallback success (Story 008 wiring point)
- [ ] Storage-advisory modal trigger: if post-append array length ≥ `BACKUP_ESCALATION_THRESHOLD` (3), a storage-advisory modal fires on that load (TR-save-load-017 — UX in Story 013)
- [ ] `FLAGS.bit0 = save_is_flagged_tampered`: set synchronously on Yes-on-tamper-modal BEFORE modal dismiss; `SETTINGS_MODIFIED_LABEL_ENABLED = false` in MVP compile-time `const` so the UI surface stays suppressed (TR-save-load-026)
- [ ] Time-rewind anti-replay: reject loaded `last_persist_unix_ts > t_current + 300` as cloud poisoning; seed both fields with `t_current` (TR-save-load-042)
- [ ] Debug-only helper `get_meta_field(name: String) -> Variant` guarded by `OS.is_debug_build()` exposes fields to GdUnit4 tests (per GDD line 472)
- [ ] CI grep sanity: no consumer source file (`src/core/economy.gd`, `src/gameplay/hero_roster.gd`, etc.) contains the substring `"_meta"` as a dictionary key read (Story 014 enforces globally; this story adds its local assertion)

---

## Implementation Notes

- `_meta` is assembled in `_collect_consumer_data()` (Story 007) as the 7th key alongside the 6 consumer namespaces. The dict build is:
  ```gdscript
  var envelope_dict := {}
  for path in CONSUMER_PATHS:
      envelope_dict[_path_to_namespace(path)] = consumer.get_save_data()
  envelope_dict["_meta"] = _build_meta_dict()
  ```
- `_build_meta_dict()` returns `{"slot_index": self._slot_index, "save_sequence_number": self._save_sequence_number + 1, "tamper_suspicious_count": self._tamper_suspicious_count, "backup_restore_events": self._scrub_backup_events()}`. The `+1` encodes the pre-HMAC increment; on successful persist, `self._save_sequence_number = envelope_dict["_meta"]["save_sequence_number"]`
- Scrub implementation: `func _scrub_backup_events() -> PackedInt64Array: var cutoff = Time.get_unix_time_from_system() - BACKUP_ESCALATION_WINDOW_SECONDS; return _backup_restore_events.filter(func(ts): return ts >= cutoff)`. Returns a new PackedInt64Array; the scrub also runs pre-persist to bound memory
- Cap enforcement: `if new_array.size() >= 16: push_warning("...") else: new_array.append(now_ts)` — the cap is defense against pathological `.bak` fallback storms
- Saturation pattern:
  ```gdscript
  const _SEQ_MAX: int = (1 << 53) - 1  # 9_007_199_254_740_991
  const _TAMPER_MAX: int = 10000
  if _save_sequence_number >= _SEQ_MAX: push_warning("[SaveLoad] save_sequence_number saturated")
  else: _save_sequence_number += 1
  ```
- `slot_index` mismatch is a HARD CORRUPT (not a `.bak` fallback) because filesystem cross-contamination most likely has the same defect in `.bak`; attempting `.bak` risks silently hydrating the wrong player's state
- `FLAGS.bit0` write path: when the user taps "Yes" on the HMAC tamper modal (Story 013), Story 013 invokes a SaveLoadSystem method that (a) synchronously writes a minimal envelope with `FLAGS.bit0 = 1` + `_meta.tamper_suspicious_count + 1`, BEFORE dismissing the modal. This closes the write-race per Pass-5B-remainder D3
- `SETTINGS_MODIFIED_LABEL_ENABLED` is a compile-time `const` in SaveLoadSystem (NOT ProjectSettings — same `user://overrides.cfg` attack surface as `integrity_check_enabled`); MVP value is `false`; V1.0 flips to `true` alongside first consequence-feature

---

## Out of Scope

- Story 008: the actual persist pipeline that appends to `backup_restore_events` on `.bak` fallback success (this story owns the array semantics; Story 008 owns the append timing)
- Story 013: the tamper modal UX + FLAGS.bit0 + tamper_suspicious_count increment on modal-Yes (this story defines the fields; Story 013 wires the modal)
- Story 014: CI grep across consumer source files (this story does local assertion)

---

## QA Test Cases

- **TR-save-load-027**: `_meta` field schema completeness
  - **Given**: A fresh persist with default `_meta` state
  - **When**: The composed envelope's JSON is parsed
  - **Then**: Top-level `_meta` key is a Dictionary with exactly 4 fields: `slot_index: int`, `save_sequence_number: int`, `tamper_suspicious_count: int`, `backup_restore_events: Array[int]` (JSON form of PackedInt64Array)
  - **Edge cases**: Load: `_meta` missing from a loaded dict (forward-compat for older-build saves) → all fields default-seeded (slot_index = expected, sequence = 0, tamper = 0, events = [])

- **TR-save-load-028**: Consumers cannot touch `_meta`
  - **Given**: Per-consumer save-data dicts extracted during `_collect_consumer_data`
  - **When**: Grep for `_meta` key read or write in each consumer's `get_save_data` / `load_save_data` source
  - **Then**: Zero hits; the `_meta` key is only assembled/read in SaveLoadSystem
  - **Edge cases**: A consumer accidentally including `"_meta"` in its returned dict would surface as a duplicate top-level key on persist — test validates the persist-side dict construction overwrites or rejects consumer-provided `_meta`

- **TR-save-load-029**: `save_sequence_number` increment on success
  - **Given**: Pre-persist `_save_sequence_number == 100`; persist succeeds
  - **When**: Post-persist read
  - **Then**: `_save_sequence_number == 101`
  - **Edge cases**: Persist fails (Story 008 abort) → still 100; multiple successes → 101, 102, ...

- **TR-save-load-027 (saturation)**: `save_sequence_number` saturation
  - **Given**: `_save_sequence_number == (1 << 53) - 1` (JSON-lossless max)
  - **When**: A successful persist attempts increment
  - **Then**: Value stays at max; `push_warning` emitted once; persist proceeds with the saturated value
  - **Edge cases**: No crash, no integer overflow; subsequent persists continue to emit `push_warning` (acceptable — saturation means the diagnostic signal is lost; MVP accepts this)

- **TR-save-load-027 (tamper_suspicious_count)**: Saturation at 10 000
  - **Given**: `_tamper_suspicious_count == 10000`
  - **When**: Another increment is attempted
  - **Then**: Value stays at 10 000; `push_warning` emitted
  - **Edge cases**: Fresh roster → 0; one HMAC-fail-modal-Yes → 1; one flag_suspicious_timestamp event → increments once per launch (not per BG/FG cycle)

- **TR-save-load-030**: `slot_index` mismatch → CORRUPT, `.bak` not attempted
  - **Given**: A loaded envelope with `_meta.slot_index == 2` while SaveLoadSystem expects slot 1
  - **When**: Post-HMAC `_meta` inspection runs
  - **Then**: State transitions to CORRUPT; `.bak` is NOT attempted; standard Rule 8 modal is queued (Story 013 UX)
  - **Edge cases**: This is a hard-fail path distinct from HMAC fail; distinct LoadResult code `ERR_SCHEMA_MISMATCH`

- **TR-save-load-018**: `backup_restore_events` scrub
  - **Given**: `_backup_restore_events = [t - 700_000, t - 500_000, t - 100_000]` where `t = Time.get_unix_time_from_system()` and `BACKUP_ESCALATION_WINDOW_SECONDS = 604_800`
  - **When**: A persist composes its envelope
  - **Then**: Scrub drops `t - 700_000` (older than 7 days); result array is `[t - 500_000, t - 100_000]` plus any new append-this-persist events
  - **Edge cases**: Empty array scrubs to empty; all-older array scrubs to empty

- **TR-save-load-018 (cap)**: Hard cap 16 entries
  - **Given**: `_backup_restore_events` already has 16 entries, all within window
  - **When**: 17th `.bak` fallback success appends
  - **Then**: 17th entry dropped; `push_warning` emitted; array stays at 16
  - **Edge cases**: Scrub pre-next-persist may reduce count below 16 naturally

- **TR-save-load-017**: Escalation threshold trigger
  - **Given**: `_backup_restore_events` has 2 entries in window; a third `.bak` fallback fires
  - **When**: Post-append length is 3 (== `BACKUP_ESCALATION_THRESHOLD`)
  - **Then**: Storage-advisory modal is queued for next load (instead of normal backup-restore toast); Story 013 wires the modal copy
  - **Edge cases**: 2 entries → normal toast; 3+ entries → storage advisory modal once per load

- **TR-save-load-025**: FLAGS.bit0 + tamper_suspicious_count write synchrony
  - **Given**: HMAC tamper modal showing; user taps "Yes"
  - **When**: Modal-Yes handler runs
  - **Then**: A synchronous persist writes FLAGS.bit0 = 1 AND `_meta.tamper_suspicious_count + 1` BEFORE modal dismiss
  - **Edge cases**: If the synchronous persist fails, modal does NOT dismiss; retry offered

- **TR-save-load-042**: Cloud-poisoning rejection
  - **Given**: A loaded dict where TimeSystem's `last_persist_unix_ts > t_current + 300`
  - **When**: `_meta` + Time fields are inspected
  - **Then**: Both fields are seeded to `t_current` (reject the poisoned value); `_meta.tamper_suspicious_count` increments; no crash
  - **Edge cases**: 300-second tolerance absorbs normal clock drift; values beyond that indicate cloud-sync replay or clock skew

- **Debug helper**: `get_meta_field` gated
  - **Given**: Production build (`OS.is_debug_build() == false`)
  - **When**: External code calls `SaveLoadSystem.get_meta_field("save_sequence_number")`
  - **Then**: Returns null (or no-op); function is `if not OS.is_debug_build(): return null`-guarded
  - **Edge cases**: Debug build returns actual value; GdUnit4 tests rely on debug build

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/meta_namespace_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 007 (consumer loop that composes the envelope dict including `_meta`), Story 008 (the `.bak` fallback path that triggers append)
- **Unlocks**: Story 013 (tamper UX uses FLAGS.bit0 + tamper_suspicious_count + storage-advisory modal trigger), Story 014 (CI grep enforcement)
