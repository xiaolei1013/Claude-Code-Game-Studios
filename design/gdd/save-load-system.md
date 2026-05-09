# Save / Load System (with Anti-Tamper)

> **Status**: Designed (pending independent review) + **Pass 5E applied 2026-04-21** + **Pass-PROBE-EXECUTED 2026-04-21 — autoload probe VERIFIED → story-authoring gate CLOSED** + **Pass-ADR-0014-SYNC applied 2026-04-22 — Orchestrator consumer contract extended to carry RunSnapshot payload (11 primitive fields + 2 Arrays per ADR-0014 §2 schema; `formation_ids: Array[int]` serialized by-id, not by HeroInstance object reference — ADR-0004 round-trip + ADR-0012 identity invariants both preserved); orphan-hero recovery path uses existing Rule 16 per-consumer fallback pattern (null resolve → discard snapshot + Economy refund via Orchestrator `run_snapshot_discarded_orphan` signal)**
> **Author**: systems-designer + security-engineer + qa-lead + godot-specialist + writer + main session
> **Last Updated**: 2026-04-21 (Pass-5E: Fantasy/Copy — 8 items applied: Rule 8 "Your guild is still here" toast + cozy corruption-modal rewrite; new Rule 8 backup-restore-repetition escalation (3-restores-in-7-days storage advisory) + new `BACKUP_ESCALATION_WINDOW_SECONDS = 604_800` / `BACKUP_ESCALATION_THRESHOLD = 3` tuning knobs; Rule 9 clock-rewind toast cozy rewrite; HMAC tamper-modal copy confirmed (no rewrite — already cozy; Pass-5E sign-off); `SAVE_AGE_WELCOME_BACK_THRESHOLD_SECONDS` default 15_552_000 (180 days) → 5_184_000 (**60 days**) per D5E-2; AC-SL-08 "Your save is safe" reassurance finalized in modal copy + Edge Cases entry; "Modified" label in Settings **suppressed until V1.0 consequence-feature** per D5E-3 (FLAGS.bit0 state still persists silently for future cloud/achievement consequences); AC-SL-07 "Both Corrupt" modal cozy copy locked in. 8/8 items applied in single session at recommended defaults. Writer + qa-lead + ux-designer sign-off points logged in review log. Pass-5D: Engine gaps — Save/Load autoload = **rank 2** (new §C.3 rank table; empirical `godot_autoload_probe.gd` Claim 1 CONVERGED→VERIFIED prerequisite for any implementation story); `FileAccess.store_buffer() -> bool` abort-on-false logic per Godot 4.4+ change; `flush()` returns `void` — platform caveat on failure undetectability; `DirAccess.rename() -> Error` (Error enum, NOT bool — verified against Godot 4.6 reference docs); Rule 2 PackedByteArray endianness construction via `encode_u8/u16/u32(offset, value) -> void`; Rule 11 `for d in serialized` gains `if not d is Dictionary: continue` guard for AC-SL-04 no-exception contract; Rule 13 "bit-perfect" claim softened to "expected round-trip stable for finite normals — empirically verified by AC-SL-01 equality assertions"; §F consumer discovery = per-call `get_node_or_null` + `assert(node != null)` (NOT cached instance vars — hot-reload-safe); state-table gains PERSISTING→PERSISTING overlap row = drop + warn; Rule 5 scene-boundary persist clarified as **async** (signal-based — SceneManager awaits `save_completed`/`save_failed` before committing transition); AC-SL-TAMPER-01 `find_subsequence` corrected to scratch linear-scan helper — Godot 4.6 `PackedByteArray.find()` is single-byte-only; iOS `NOTIFICATION_WM_CLOSE_REQUEST` vs `NOTIFICATION_APPLICATION_PAUSED` flagged [UNVERIFIED — mobile-port empirical]; Open Questions — closed `store_buffer`/`@abstract`, added autoload-probe-execution prerequisite; 13 items applied in-session)
> **Implements Pillar**: Pillar 1 — *Respect the Player's Time* (save corruption = maximum pillar violation)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode
> **Anti-Tamper Ambition**: Casual-deterrent (not bulletproof). Single-player premium game; accepts memory-editor and sophisticated-reverse-engineering as out-of-scope threats.

---

## Overview

The Save/Load System is the sole persistence boundary for all mutable player state in *Lantern Guild*: hero roster, gold balance, class and floor unlocks, active dungeon assignments, the Time System's `last_persist_unix_ts`, and any future progression state. It owns a single save slot at `user://save_slot_1.dat` (multi-slot-capable structure for V1.0), writes via atomic temp-rename, maintains a single `.bak` backup, and verifies a binary envelope with an HMAC-SHA256 integrity footer on every load.

This system is the operational guarantor of Pillar 1 (Respect the Player's Time). Every idle session ends in a persist; every launch begins with a load. If this system fails silently, hours of player progress evaporate without acknowledgment — the single most severe pillar violation possible in the game. The design therefore treats "never silently lose data, never silently accept corruption" as load-bearing invariants.

The anti-tamper layer is casual-deterrent, not bulletproof. A player with a hex editor who wants to cheat can, after enough effort, modify a save and avoid detection. The design goal is to make that effort expensive enough that the typical "change gold in notepad" attack fails while keeping the engineering cost proportional to a single-player premium game with no competitive integrity requirements.

---

---

## Player Fantasy

This system has no direct player fantasy — players never see it. The indirect fantasy it serves: **"my guild is still here."**

Every time the player re-opens Lantern Guild after hours or days away, the first beat of the session is the Return-to-App screen enumerating what accumulated while they were gone. That moment only works — only *lands* — if the player's trust in their own progress is absolute. A single corrupted save, a single silently-deleted hero, a single "progress lost" modal breaks the cozy promise permanently. This system's job is to make the guild feel permanent; the emotional payload lives at the screens that read its output.

The anti-tamper response is shaped by the same tone. A player who modifies their save does not get a "CHEATER DETECTED" banner or a bricked game — they get a gentle "this save file has been modified" modal that lets them continue. The tone is non-accusatory; the consequence is legible. Even the response to cheating is cozy.

---

---

## Detailed Rules

### Core Rules

**1. Save file location.**
The canonical save path for a single slot is `user://save_slot_1.dat`. At MVP, one slot exists. The path is constructed via a slot-index helper (`save_slot_path(slot: int) -> String`) so multi-slot support in V1.0 requires only changing the count constant, not refactoring call sites. Backup files use the suffix `.bak` (`user://save_slot_1.dat.bak`).

**2. Save file format.**
Binary envelope with three regions: a fixed-width **header**, a variable-length **XOR-masked JSON payload**, and a fixed-width **integrity footer**. **Pass-5A edit 2026-04-21** — closes systems-designer F6 + security-engineer F4 cross-model BLOCKING: Rule 2 previously specified a 32-byte header (magic+version+slot+29-byte padding) which contradicted the Anti-Tamper Specification's 12-byte header (magic+version+FLAGS+PAYLOAD_LENGTH). Incompatible binary formats; implementations following Rule 2 vs Anti-Tamper produce files the other rejects. Anti-Tamper spec is authoritative (security-motivated; FLAGS needed for AC-SL-03 `save_is_flagged_tampered` bit; PAYLOAD_LENGTH-inside-HMAC-protected-region is the correct defense against over-read attacks). Rule 2 rewritten below to match.

- **Header** (fixed, **12 bytes**): magic bytes `4C474C44` ("LGLD", 4 bytes), format version (uint16 little-endian), FLAGS (uint16 little-endian; reserved = `0x0000` in MVP; bit 0 = `save_is_flagged_tampered`), PAYLOAD_LENGTH (uint32 little-endian). **Slot index is NOT in the header** — it is implicit in the file path (`save_slot_1.dat`) and carried inside the JSON payload under `"_meta": {"slot_index": int}` for verification; this Pass-5A change decouples header size from slot count and avoids a fixed 32-byte padded region. V1.0 multi-slot adds no header change; only the file path and `_meta` slot_index change.
- **Payload** (variable, `PAYLOAD_LENGTH` bytes): UTF-8 JSON produced by serializing each consumer's `get_save_data()` output into a top-level dictionary, then XOR-masked per the Anti-Tamper Specification mask-key derivation. JSON is chosen over Godot binary Resource serialization because it is human-readable during debugging, diffable in playtests, and does not require `ResourceSaver`/`ResourceLoader` round-trips that could re-entangle with the Data Loading System's resource cache. **The HMAC footer is computed over the masked payload bytes, NOT the plaintext** (Pass-5A edit — closes security-engineer F3: Rule 2 + Rule 9 prior said "raw header + payload"; Anti-Tamper §353 correctly says "masked payload"; resolved in favor of the Anti-Tamper spec, since HMAC-over-masked is required for byte-level edit detection regardless of whether the attacker knows the XOR mask).
- **Footer** (fixed, 32 bytes): HMAC-SHA256 over the raw header bytes + the masked-payload bytes. The specific key derivation and keying material are owned by the security-engineer (see Anti-Tamper Specification). This GDD references the result as "integrity hash" and consumes it as an opaque 32-byte blob.

**Total fixed envelope overhead: 12 + 32 = 44 bytes** (down from Pass 4B's stated 64 bytes). The payload dominates size at any realistic scale. Binary envelope prevents casual inspection and trivial hex-editing; JSON payload keeps the authoring and debugging workflow sane at indie scale.

**Header construction — little-endian via `PackedByteArray.encode_*` (Pass-5D 2026-04-21 — godot-specialist F1).** The header uint16/uint32 fields MUST be written via `PackedByteArray`'s built-in little-endian encoders, NOT via manual shift-and-mask byte packing. Manual packing is a frequent endianness bug source (implementer writes `header[4] = version >> 8; header[5] = version & 0xFF` — big-endian — and the loader, expecting little-endian per the spec, rejects every save as malformed MAGIC-OK/VERSION-garbage). Verified against Godot 4.6 reference docs: `encode_u8/u16/u32(byte_offset: int, value: int) -> void` are little-endian by contract and are the canonical primitives. Reference construction (implementer fills payload bytes + HMAC separately):

```gdscript
# Header: 12 bytes. All integer fields little-endian per Rule 2.
var header := PackedByteArray()
header.resize(12)
# MAGIC "LGLD" at offset 0 (4 bytes, fixed order — not endianness-sensitive)
header.encode_u8(0, 0x4C)  # 'L'
header.encode_u8(1, 0x47)  # 'G'
header.encode_u8(2, 0x4C)  # 'L'
header.encode_u8(3, 0x44)  # 'D'
header.encode_u16(4, CURRENT_SAVE_VERSION)  # uint16 LE
header.encode_u16(6, flags)                 # uint16 LE (bit 0 = save_is_flagged_tampered)
header.encode_u32(8, masked_payload.size()) # uint32 LE — PAYLOAD_LENGTH

# Reader (inverse):
var version: int = file_bytes.decode_u16(4)
var flags_read: int = file_bytes.decode_u16(6)
var payload_length: int = file_bytes.decode_u32(8)
```

`decode_u16/u32` are the inverse little-endian readers and MUST be used on load. Do not `bitshift` manually even "once to avoid the helper call" — the helper is native, the manual path is GDScript interpreted, and correctness matters more than a sub-microsecond save on a once-per-session load path.

**PAYLOAD_LENGTH pre-HMAC trust boundary (Pass-5B-remainder 2026-04-21 — security-engineer F3).** PAYLOAD_LENGTH lives inside the HMAC-protected region, but the load path necessarily reads it BEFORE HMAC verification completes. Implementers MUST NOT use PAYLOAD_LENGTH for pre-HMAC buffer allocation — an attacker who sets PAYLOAD_LENGTH = `0xFFFFFFFF` (~4 GB) would trigger an oversize allocation attempt before HMAC fails, producing a local denial-of-service (OOM crash on mobile, long freeze on desktop). The pre-HMAC read budget is instead `file_length − 44` (on-disk file size minus the 12-byte header minus the 32-byte footer), derived from the filesystem `size` result, which is not part of the save envelope and thus not attacker-controllable through the save bytes themselves. PAYLOAD_LENGTH is a **post-HMAC cross-check only**: after HMAC passes, assert `PAYLOAD_LENGTH == file_length − 44`; mismatch → corruption modal per Rule 8. Rule 9's integrity-module contract is unchanged; this clarifies the caller's obligation on the load path.

**3. Serialization contract.**
All mutable player state is owned by this system at the persistence boundary. Each consumer exposes exactly two methods:

```
get_save_data() -> Dictionary
load_save_data(data: Dictionary) -> void
```

Pass-5A edit 2026-04-21 — closes 4-specialist cross-model BLOCKING (systems-designer F1 + qa-lead F1 + godot-gdscript Item 4 + godot-specialist Bonus): harmonized the consumer contract to `get_save_data() / load_save_data()` (canonical pair matching Orchestrator GDD #13 + Floor Unlock GDD #16). Prior pair `save_to_dict() / load_from_dict()` was deprecated; §F preamble partially documented this in Pass 4B but did not propagate to Rule 3, Rule 13, AC-SL-01, the state-transition table, §C Interactions rows, or §F Economy/Roster/Formation/Recruitment rows. All are now harmonized.

This system calls `get_save_data()` on each consumer during persist and writes the results under a namespaced key (e.g., `"economy"`, `"roster"`, `"unlocks"`). On load, it reads each namespace and calls `load_save_data()`. Consumers are responsible for the schema of their own sub-dictionary; this system does not interpret the contents. Version migration (see Rule 4) occurs before `load_save_data()` is called.

**4. Version field and migration.**
The header's format version (uint16) is `1` for MVP. On load, if the version field differs from the compiled `CURRENT_SAVE_VERSION` constant, the system enters `MIGRATION` state and runs the appropriate migration script before hydrating consumers. In MVP, only version 1 exists; the `MIGRATION` state is a stub that immediately falls through to `READY`. V1.0 will add `migrate_v1_to_v2()` etc. If the version is higher than `CURRENT_SAVE_VERSION` (save from a newer build), see the forward-compatibility edge case.

**5. Persist triggers.**
Persists fire on five events (Pass-5-lean 2026-04-21 — count corrected from "four"; scene-boundary trigger was added but the intro count was not updated):

| Trigger | Source | Notes |
|---------|--------|-------|
| Heartbeat (every 60 s) | Time System's `heartbeat_interval_seconds` knob | Overwrites current slot. Interval is owned by Time System — do not duplicate the constant here. |
| App pause | Time System FOREGROUND → BACKGROUNDED transition signal | Fires synchronously before sim clock freezes. |
| Graceful shutdown | `NOTIFICATION_WM_CLOSE_REQUEST` (desktop) OR `NOTIFICATION_APPLICATION_PAUSED` (mobile) | Same synchronous persist. **iOS notification mapping [UNVERIFIED — Pass-5D 2026-04-21]**: on iOS, `NOTIFICATION_WM_CLOSE_REQUEST` is widely reported to NOT fire — the OS kills the app after `applicationDidEnterBackground` (Godot: `NOTIFICATION_APPLICATION_PAUSED`) rather than delivering a graceful-close notification. The MVP implementation MUST persist on the `PAUSED` notification unconditionally, and treat any `CLOSE_REQUEST` that does fire as a redundant second trigger (handled by PERSISTING → PERSISTING drop+warn per the state-table row below). This claim is currently inferred from Apple's `UIApplicationDelegate` lifecycle docs + Godot 4.6 platform notes; it is **NOT empirically verified** on a real iOS device. Before mobile port, `engine-programmer` MUST run an empirical probe on iOS (attach console, background the app via home swipe, force-quit from app switcher) and log which notifications fire in each path. Result goes into `docs/engine-reference/godot/modules/autoload.md` or a new `platform-notifications.md` reference doc. Android verification is also needed but is less risky — Android's `NOTIFICATION_APPLICATION_PAUSED` is known-reliable per Godot's platform notes. |
| Post-migration | MIGRATION → READY transition | Immediately re-persists the migrated save so recovery does not re-run migration. |
| Scene boundary persist | `SceneManager.scene_boundary_persist` signal (entering Dungeon Run View; exiting Victory Moment) | **Async-signal pattern (Pass-5D 2026-04-21 — user decision D5D-3)**: SceneManager calls `SaveLoadSystem.request_scene_boundary_persist()` then `await`s the `save_completed` OR `save_failed` response signal before committing the transition. A synchronous persist blocks the main thread for the full atomic write cycle (up to 50 ms mobile target, 150 ms warning threshold per §D.2) — long enough to produce a visible animation hitch on the transition-starting frame. Async-signal yields the frame to the render loop, runs the persist, and re-enters SceneManager in the subsequent frame to commit or abort. If `save_failed` is received, SceneManager cancels the transition and surfaces the "save failed" banner per Rule 8-adjacent disk-full path. See Scene/Screen Manager GDD Section C.2. |

There is no "Save" button in MVP. Players never initiate a manual save.

**6. Load triggers.**
Load fires exactly once per session: at app launch, if a save file exists at the slot path. It never fires mid-session. Re-loading mid-session would require re-initializing all consumers and is out of scope.

**On load entry, delete any stale `.tmp` file at the slot path before proceeding.** A `save_slot_1.dat.tmp` present at launch represents an aborted prior persist (crash or power loss between write and rename) and is never a valid load source. Deletion is unconditional — the atomic write pattern guarantees either `.dat` or `.bak` holds a complete save. This rule was previously documented only in Edge Cases (Pass-5-lean 2026-04-21 — promoted to a Rule per R-N3).

**7. Atomic write pattern.**
All persists use write-temp-then-rename. Engine return types (**Pass-5D 2026-04-21** — verified against Godot 4.6 reference docs: `FileAccess.store_buffer(buffer: PackedByteArray) -> bool` (changed from `void` in Godot 4.4, COMPAT-preserving); `FileAccess.flush() -> void`; `DirAccess.rename(from: String, to: String) -> Error` — **`Error` enum, NOT `bool`**; `OK` is the success value):

1. Serialize payload and compose full binary envelope in memory.
2. Open `user://save_slot_1.dat.tmp` via `FileAccess.open(path, FileAccess.WRITE)`. **Assert the returned handle is non-null**; if `null`, call `FileAccess.get_open_error()` and enter the disk-full / I/O-error path (abort persist, log, show "save failed" banner, retry next heartbeat). Do NOT proceed to `store_buffer`.
3. Write via `store_buffer(bytes) -> bool`. **On `false`, abort the persist immediately**: close the handle (this also flushes), delete the partial `.tmp` (best-effort; if the delete itself errors, log and continue — a stale `.tmp` is handled by Rule 6 on next launch), log `[SaveLoad] ERROR: store_buffer returned false — aborting persist; path=[...]`, surface the "save failed" banner, retry next heartbeat. Do NOT rename.
4. Call `flush() -> void`. **Failure is undetectable** — Godot 4.6's `FileAccess.flush()` returns no status (verified: signature is `void flush()` in class_fileaccess reference). On mobile, a silent flush failure (OS-level write-back buffer flushed to a disk that errored) is a known gap — the subsequent rename will succeed from the OS perspective because the buffered bytes *looked* written, but the on-disk file may be truncated or absent after a reboot. Mitigation: the `.bak` rotation in step 6 + the HMAC verification on next load catch the majority of these; an HMAC-fail load enters Rule 8. **No loss-of-data prevention is possible at this layer** — it is an accepted platform caveat and is documented in Edge Cases. Do not add a post-flush file-size verification read: on mobile the OS cache returns the buffered size even after the physical write failed, so the check is false-assurance.
5. Close the handle (still via `FileAccess.close()` or scope exit). `store_buffer` successful + `close()` fired is the pre-rename commit point.
6. Rename `.tmp` to `.dat` via `DirAccess.rename(tmp, target) -> Error`. **On non-`OK` return**, abort: the `.tmp` remains on disk but is never valid for load (Rule 6 cleanup on next launch deletes it); the prior `.dat` is untouched so load-safety is preserved; log `[SaveLoad] ERROR: DirAccess.rename failed with Error=[error_name]; tmp stays, .dat preserved`; surface "save failed" banner; retry next heartbeat. **On `OK`**, proceed.
7. Copy the newly-renamed `.dat` to `.dat.bak` as the backup rotation (via `DirAccess.copy(src, dst) -> Error`; same `OK`-or-abort pattern, but `.bak` copy failure does NOT abort the persist — the `.dat` is already committed and a heartbeat-later `.bak` refresh is acceptable; log and continue).

**Platform note:** iOS and Android do not support atomic rename in all configurations. On those platforms, step 6 must fall back to a copy-then-delete pattern (`DirAccess.copy(tmp, target)` + `DirAccess.remove(tmp)`); the `.commit` marker pattern described in the Anti-Tamper Specification §Atomic Write + Backup Rotation Details handles the cross-step atomicity. The implementation must detect the platform and branch accordingly. This is flagged in Open Questions; `flush()` failure-undetectability is documented in the Edge Cases section as a separate mobile caveat.

The invariant this achieves: at any moment, `save_slot_1.dat` is either the previous complete save or the new complete save — never a partial write.

**8. Failure policy — corrupt current save.**
On load, if integrity verification fails on `.dat`:

1. Log warning: `[SaveLoad] WARN: save_slot_1.dat failed integrity check — attempting .bak`.
2. Attempt to load `.dat.bak`. If `.bak` passes integrity, hydrate from `.bak` and show a non-blocking toast — **Pass-5E 2026-04-21 — writer sign-off on cozy rewrite**: *"Your guild is still here. We restored your last backup — a few minutes of progress may be missing."* The second sentence is deliberate: it names the small loss honestly (a heartbeat-interval's worth of progress between `.bak` rotation and `.dat` failure), without alarm. Previous draft "We restored your last backup save." did not acknowledge the loss window and did not reinforce the Player-Fantasy anchor ("my guild is still here") — the new copy does both in twelve words. Then immediately re-persist to `.dat` so the backup is promoted (per AC-SL-06 full atomic re-persist semantics).
3. If `.bak` also fails (or does not exist), start a fresh session and show a modal — **Pass-5E 2026-04-21 — writer sign-off on cozy rewrite**: *"Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]"* The single [Begin] button is deliberate: a two-button "Continue / Cancel" would offer no actionable Cancel (the save is already lost, there is nothing to cancel back to). Previous draft "Starting a new adventure." was terse to the point of coldness; the rewrite names the loss, validates the player's feeling ("your guild will grow again"), and returns agency via the button label. Do not silently discard — the player must acknowledge. Log the event to the session audit trail.

A silent new-game on corruption is a Pillar 1 catastrophe. The modal acknowledges the loss; it does not prevent play.

**Backup-restore repetition escalation (Pass-5E 2026-04-21 — new sub-rule).** If the `.bak` fallback path (step 2 above) fires **`BACKUP_ESCALATION_THRESHOLD` times within a rolling `BACKUP_ESCALATION_WINDOW_SECONDS` window** (default: 3 restores in 7 days), the non-blocking backup-restore toast is **replaced** (for that specific load event only) by a non-blocking storage advisory modal: *"Your save has been restored from backup a few times recently. This can happen if your device's storage is nearly full or has hardware issues. Please check free space. [Check Storage] [Dismiss]"*. The `[Check Storage]` button opens the platform's native storage settings via `OS.shell_open("appstorage://")` (platform-mapped; mobile falls back to a clipboard of the platform-specific deep-link). Dismiss is always available. Escalation state is recorded in `_meta.backup_restore_events` as a `PackedInt64Array` of unix timestamps (scrubbed to the last `BACKUP_ESCALATION_WINDOW_SECONDS` entries on every persist — no unbounded growth). Rationale: a single backup-restore is routine (crash mid-persist, first-launch-after-OS-update); three in a week signals a storage-layer issue the player can actually act on. The escalation is advisory, not blocking — the save is still loaded; only the surface is upgraded from toast to modal. Knobs are tunable post-launch if the signal is noisy. See `BACKUP_ESCALATION_WINDOW_SECONDS` and `BACKUP_ESCALATION_THRESHOLD` in Section G.

**9. Anti-tamper collaboration.**
The integrity hash is computed by the security-engineer's module during persist and verified during load. This GDD treats it as a black box: on persist, pass the 12-byte header + the masked-payload bytes to the integrity module and receive a 32-byte HMAC-SHA256 tag to write to the footer. On load, pass header + masked-payload + tag to the integrity module and receive a boolean result. **Pass-5A edit 2026-04-21 — closes security-engineer F3: HMAC input is the MASKED payload, not the plaintext**; Rule 9 previously said "full header + payload" which was ambiguous between the two layers. Anti-Tamper §353 is authoritative; this rule now aligns. If verification returns `false`, enter the failure policy defined in Rule 8.

On `flag_suspicious_timestamp` received from the Time System (clock-rewind detected): log the event to the session audit trail. In MVP, the escalation policy is warn-only — show a non-blocking toast and continue normally — **Pass-5E 2026-04-21 — writer sign-off on cozy rewrite**: *"Welcome back. Offline progress is paused for this session while your device clock settles."* The previous draft "Time inconsistency detected — offline progress may be limited" was accurate but sounded like a security warning; a legitimate player whose device just synced from a wrong-timezone reboot should not be accused. The rewrite: (a) opens with the Player-Fantasy anchor "Welcome back"; (b) names what changed without using the word "tamper" or "suspicious"; (c) implies the outcome is recoverable (the next launch after the clock settles returns to normal). The save is not locked. (An offline session with zero credit is already the Time System's response; locking the save would double-penalize players with legitimate NTP clock corrections. Revisit for V1.0 if tamper signal volume is high post-launch.) See `suspicious_timestamp_escalation` tuning knob in Section G.

**`tamper_suspicious_count` field schema — resolved (Pass-5B-remainder 2026-04-21, closes R-N5).** AC-SL-09 and AC-SL-TAMPER-04 rely on this counter being observable across launches. Full schema (width, overflow behavior, persist-immediate timing) is now specified in the **`_meta` Sub-Schema** subsection of the Anti-Tamper Specification (below), alongside `_meta.save_sequence_number` and `_meta.slot_index`. Persist timing summary: the counter increments immediately on `flag_suspicious_timestamp` AND immediately on Yes-on-tamper-modal (closes FLAGS.bit0 write-race per Pass-5B-remainder user decision D3). See HMAC Verification Behavior step 6 for the write-path contract.

---

### States and Transitions

| State | Description |
|-------|-------------|
| `UNLOADED` | No save in memory. App has just launched or no save file exists. |
| `LOADING` | File is being read, integrity verified, header parsed, references hydrated via `DataRegistry.resolve()`. Gameplay is blocked. |
| `READY` | Save hydrated. Consumers have received `load_save_data()`. Heartbeat scheduler is active. Normal runtime state. |
| `PERSISTING` | An atomic write is in progress. Brief (target under 50 ms on mobile). Gameplay continues; state returns to `READY` on completion or on error. |
| `CORRUPT` | Integrity failed on both `.dat` and `.bak`, or Data Loading System is in `ERROR` state on launch. Gameplay is blocked. Modal shown. On player acknowledgment, transitions to `READY` with a fresh save. |
| `MIGRATION` | Version mismatch detected. Migration script running. MVP: immediate pass-through. V1.0: versioned migrators. |

| From | Event | To | Boundary Action |
|------|-------|----|-----------------|
| — | App launch, no save file | READY | Seed fresh state; write initial save; start heartbeat scheduler |
| — | App launch, save file found | LOADING | Begin integrity check |
| LOADING | Integrity pass, no version mismatch | READY | Call `load_save_data()` on all consumers; start heartbeat |
| LOADING | Integrity pass, version mismatch | MIGRATION | Queue appropriate migration script |
| LOADING | Integrity fail on `.dat`, `.bak` passes | READY | Hydrate from `.bak`; show toast; re-persist to promote `.bak` |
| LOADING | Both files corrupt; or Data Loading ERROR | CORRUPT | Block gameplay; show modal |
| READY | Heartbeat / pause / shutdown trigger | PERSISTING | Begin atomic write |
| PERSISTING | Write complete | READY | Update `.bak` |
| PERSISTING | Write error (disk full, I/O error) | READY | Log error; retry deferred to next heartbeat; do not crash |
| PERSISTING | Another persist trigger fires (overlap) | PERSISTING (unchanged) | **Pass-5D 2026-04-21 — user decision D5D-2: drop + warn.** The new trigger is dropped (the in-flight persist continues to completion); log `[SaveLoad] WARN: persist trigger [name] fired while persist already in progress — dropping duplicate`. Rationale: queuing the overlap would amplify mobile I/O pressure (every overlapped heartbeat would serialize the full six-consumer state again against an in-flight write); coalescing to "the in-flight write wins, the next heartbeat catches any later state changes" is the safe default. The 60 s heartbeat cadence + the <50 ms mobile persist budget means overlap is a rare degenerate case (only under pathological I/O stall); the data-loss window is bounded by the next heartbeat and the in-flight persist's snapshot-consistency invariant. Overlaps on **scene-boundary triggers specifically** (the async-signal pattern per Rule 5 row 5) are handled slightly differently: SceneManager's `await save_completed` already serializes boundary persists sequentially, so boundary→boundary overlap cannot occur at this layer. Heartbeat→boundary or boundary→heartbeat overlap: the second trigger is dropped per the rule above, SceneManager receives `save_completed` from the in-flight write (which is a complete and valid save for the moment the heartbeat fired — accepted). |
| MIGRATION | Migration complete | READY | Call `load_save_data()` on all consumers; immediately re-persist |
| CORRUPT | Player acknowledges modal | READY | Fresh save initialized |

---

### Interactions with Other Systems

**Time System.** On load: reads both `data["time"]["last_persist_unix_ts"]` AND `data["time"]["t_session_high_water"]` from the save payload and calls `TimeSystem.set_last_persist_ts(value: int)` and `TimeSystem.set_session_high_water(value: int)`. These are the only permitted writes into the Time System. During persist: reads both `TimeSystem.get_last_persist_ts()` and `TimeSystem.get_session_high_water()` and writes both to the payload — **both fields MUST be covered by the HMAC signature**, since `t_session_high_water` is the anchor that prevents the in-session rewind attack (Time System AC-TICK-05b). On future-timestamp guard: reject any loaded `last_persist_unix_ts > t_current + 300` as implausible (cloud-save poisoning defense per Time System E8) and seed both fields with `t_current`. On `flag_suspicious_timestamp` signal from Time System: log to audit trail; apply escalation policy (MVP default: warn-only, see Section G).

**Data Loading System.** Hydration depends on `DataRegistry` being in `READY` state. On load entry: check `DataRegistry.state`. If `ERROR`, immediately transition to `CORRUPT` state — loading with a poisoned content index would hydrate all references to null, silently corrupting the roster, dungeon assignments, and class unlocks. On `null` returned from `DataRegistry.resolve()` for a specific id: apply the per-consumer fallback table below.

| Consumer | Resolve returns null | Fallback policy |
|----------|---------------------|-----------------|
| Hero Roster — hero class | `DataRegistry.resolve("classes", id) == null` | Remove hero from roster; log `[SaveLoad] WARN: hero class '{id}' no longer exists — hero removed from roster`. Show in-session notification if roster was non-empty. |
| Floor/Biome Unlock — biome | `DataRegistry.resolve("biomes", id) == null` | Mark floor as locked (safe default). Log warning. |
| Dungeon assignments | `DataRegistry.resolve("dungeons", id) == null` | Clear assignment; heroes return to idle. Log warning. |
| Items (V1.0) | `null` | Remove from inventory; log. |

**Economy System.** Calls `Economy.get_save_data()` during persist (gold balance, production rates). Calls `Economy.load_save_data(data)` during hydration. No content resolution needed — Economy state is purely numeric.

**Hero Roster.** Same dict contract. Roster entries store hero class by stable `id: String`; `DataRegistry.resolve("classes", id)` is called per hero during `load_save_data()` to attach the live `HeroClass` resource. Fallback as noted above.

**Floor/Biome Unlock.** Same dict contract. Pass-5A edit 2026-04-21 — closes qa-lead F11: payload shape is a `Dictionary[String, int]` mapping `biome_id` to `highest_cleared` (e.g., `{"highest_cleared": {"forest_reach": 2}}` under the `"floor_unlock"` namespace key). Prior `Array[String]` description was a pre-Pass-4B placeholder that §F rows were updated away from without §C being harmonized. No content resolution is required (keys are biome_id strings; values are primitives). Stale `biome_id` entries from removed biomes are preserved for forward-compat with a warning (per Floor Unlock GDD #16 §E); they filter out of UI surfaces via `is_biome_available()`.

**Offline Progression Engine.** Does not read from this system directly. It receives `offline_elapsed_seconds` from the Time System (which this system restored `last_persist_unix_ts` into). The dependency chain is: Save/Load restores timestamp → Time System computes elapsed → Offline Engine receives elapsed. This system must complete `set_last_persist_ts()` before the Time System performs its offline calculation.

**Dungeon Run Orchestrator.** See Rule 10 (RunSnapshot integration) and Rule 11 (Array-element serialization) below.

---

### §C.3 Autoload Rank (Pass-5D 2026-04-21 — user decision D5D-1)

SaveLoadSystem is a Godot autoload (AutoLoad singleton Node). The rank column below defines the exact order autoloads appear in `project.godot`'s `[autoload]` section, which in Godot 4.6 controls `_ready()` ordering (ranks are called in ascending order). Save/Load is **rank 2** — between DataRegistry (rank 1) and all consumer autoloads (rank 3+). The assignment is load-bearing and MUST NOT be reordered casually.

| Rank | Autoload | Rationale (why this slot; why not earlier/later) |
|---|---|---|
| 1 | **DataRegistry** (Data Loading System) | MUST `_ready()` first. Save/Load (rank 2) reads `DataRegistry.state` on launch and refuses to load if `state != READY` per AC-SL-08. If DataRegistry were rank 2 or later, Save/Load's load path would see `UNINITIALIZED` / `LOADING` instead of the modeled `ERROR` and could either (a) enter a nil-resolve hydration storm silently corrupting the roster, or (b) misclassify an in-progress content load as a content error. DataRegistry must be fully ready before Save/Load observes its state. |
| 2 | **SaveLoadSystem** (this GDD) | `_ready()` after DataRegistry, before any consumer. The `_ready()` path: (a) connects to `TimeSystem.flag_suspicious_timestamp_emitted` and `SceneManager.scene_boundary_persist` signals (valid: per Claim 1 in `docs/engine-reference/godot/modules/autoload.md`, signal objects on rank-3+ autoloads exist before those autoloads' `_ready()` fires, so rank-2→rank-3 signal-connect is safe); (b) checks `DataRegistry.state`; (c) reads the save file, verifies HMAC, XOR-unmasks, JSON-parses; (d) iterates the hardcoded consumer list and calls `load_save_data()` on each. Consumers at rank 3+ have **not yet had their `_ready()` fire** when Save/Load calls `load_save_data()` on them — this is the intended contract: consumers populate their internal state from the save dict in `load_save_data`, NOT in `_ready`. Any consumer that initializes production state in `_ready()` before `load_save_data` overwrites the loaded state with defaults — a regression against this rank table. |
| 3 | **Economy**, **HeroRoster**, **FloorUnlock**, **FormationAssignment**, **Recruitment**, **DungeonRunOrchestrator** | Consumer autoloads. Their `_ready()` fires after SaveLoadSystem's but MUST NOT initialize production state — Save/Load has already called `load_save_data(sub_dict)` before these `_ready`s fire. Acceptable `_ready` work: defensive self-validation (assert invariants), connect non-Save/Load signals, allocate internal data structures that do not depend on persisted state. Any persisted-state initialization MUST live exclusively in `load_save_data`. |
| 4 | **TimeSystem** | Can be earlier (rank 2 before Save/Load if Time System does not depend on DataRegistry) or later — the exact Time System rank is owned by `design/gdd/game-time-and-tick.md` and is not dictated by this GDD. The only Save/Load-imposed constraint: Time System's `flag_suspicious_timestamp_emitted` signal object must exist at SaveLoadSystem `_ready()` time, which holds for all rank assignments per autoload Claim 1 (all autoload Nodes are added to the tree root before any `_ready` fires). |
| 5 | **SceneManager** | Rank after Save/Load so its `scene_boundary_persist` signal is connectable at Save/Load `_ready`. Same Claim-1 safety as Time System. SceneManager itself does not participate in the initial load path — it renders the first scene AFTER Save/Load has populated consumer state. |

**Empirical probe prerequisite (story-authoring gate — CLOSED 2026-04-21).** Claim 1 in `docs/engine-reference/godot/modules/autoload.md` ("a rank-N autoload can connect to a rank-(N+1) autoload's signal in its own `_ready()`") was promoted `[CONVERGED] → [VERIFIED]` via empirical probe execution on 2026-04-21 (Godot 4.6.1.stable.mono.official, Apple M2 Max, Metal backend). The rank-2 assignment above is now empirically grounded. Full probe trace is in `autoload.md` Claim 1 Empirical-results block; Change log has the Pass-PROBE-EXECUTED 2026-04-21 entry with context. **Save/Load implementation stories are un-gated and ready-to-execute.** (Historical: the probe was a carry-forward since Pass-5 — load-bearing for Pass-5 Item 8 AC-SL-08 `DataRegistry.state == READY` invariant + Claim 1. Had the probe FAILED, the rank table would have collapsed and a deferred-signal-connect redesign would have been required. It passed on first empirical run with all four sub-assertions holding — see autoload.md for the stdout trace.)

**Rank change protocol.** Changing the SaveLoadSystem rank requires: (a) a new ADR in `docs/architecture/`; (b) Pass-5D ADR dependency annotation in this §C.3; (c) regression re-run of AC-SL-08 + AC-SL-01 against the new ordering; (d) re-execution of `godot_autoload_probe.gd` if any signal-connection assumption changes. Do not reorder "because it seems cleaner" — every reorder risks the nil-hydration catastrophe described in rank 1's rationale.

---

### Rule 10 — RunSnapshot Integration (Pass 4B-SaveLoad, 2026-04-20)

The Dungeon Run Orchestrator (#13) is a registered save consumer. Its `RunSnapshot` (a `RefCounted` value type — Orchestrator C.2) represents active run state that must survive app suspend + resume. Save/Load integrates the Orchestrator via the standard dict contract (`get_save_data` / `load_save_data`), with the following specifics:

**Schema key**: The Orchestrator's namespace key in the top-level save dict is `"active_run"`. On save, Save/Load calls `orchestrator.get_save_data() -> Dictionary`, which returns:
- `{}` (empty dict) if `state == NO_RUN` — no snapshot to persist.
- `{"active_run": snapshot.to_dict()}` if a run is active.

On load, Save/Load calls `orchestrator.load_save_data(data: Dictionary)`. The Orchestrator checks `data.has("active_run")`; if present, calls `RunSnapshot.from_dict(data["active_run"])` to reconstruct. If absent, initializes to `NO_RUN`.

**Persist triggers (when is `to_dict` called)**: Save/Load calls `get_save_data()` on every persist trigger (heartbeat, app-pause, graceful shutdown, scene-boundary, post-migration — per Rule 5). The Orchestrator serializes `snapshot.to_dict()` on every call; there is no special "only on state transition" exception. This keeps the consumer contract uniform and prevents drift between heartbeat-triggered and transition-triggered saves.

**NO_RUN handling**: When `state == NO_RUN`, `get_save_data()` returns `{}`. Save/Load writes an empty dict under `"active_run"` (or omits the key — both are acceptable; `has("active_run")` check on load handles either). On load, if the key is missing or maps to `{}`, the Orchestrator initializes to `NO_RUN`. There is no error path for a missing key — absence is valid and expected for fresh saves.

**Error contract on `from_dict` failure**: If `RunSnapshot.from_dict(data)` fails — due to malformed data, missing required fields, or a failed `DataRegistry.resolve("floors", floor_id)` call — the method logs `push_error("RunSnapshot.from_dict: deserialization failed — resetting to NO_RUN; reason: [details]")` and returns `null`. The Orchestrator consumer treats a `null` return as `NO_RUN` initialization. The session continues; the player loses the in-progress run state (equivalent to the app having been killed before the run began). This is a Pillar 1 compliant outcome — progress loss is acknowledged, the session is not blocked.

**Registration**: The Orchestrator registers itself as a save consumer by implementing:
```gdscript
func get_save_data() -> Dictionary: ...
func load_save_data(data: Dictionary) -> void: ...
```
Save/Load calls these under the `"orchestrator"` namespace key in the top-level save dict (i.e., `save_dict["orchestrator"] = orchestrator.get_save_data()`; `orchestrator.load_save_data(save_dict.get("orchestrator", {}))`).

---

### Rule 11 — Array-Element Serialization for RefCounted Types (Pass 4B-SaveLoad, 2026-04-20)

GDScript's `Dictionary.duplicate(true)` deep-copies primitive values and nested Dictionaries but **does NOT serialize RefCounted objects**. Typed arrays of RefCounted types (`Array[KillEvent]`, `Array[HeroInstance]`) serialized without per-element conversion will contain opaque object references that cannot be written to disk and do not survive a process restart.

**Mandatory serialization pattern**: Every RefCounted type that is a field on a serializable value type (such as `RunSnapshot`) MUST provide:
- `func to_dict() -> Dictionary` — converts the object to a plain primitive/dictionary representation.
- `static func from_dict(d: Dictionary) -> T` — class method that reconstructs the object from a dictionary; returns `null` on malformed input.

**Array round-trip pattern**: Serialize an `Array[T extends RefCounted]` by iterating and calling `to_dict()` on each element:

```gdscript
# Serialize: Array[T] → Array[Dictionary]
var serialized: Array[Dictionary] = []
for item in arr:
    serialized.append(item.to_dict())

# Deserialize: Array[Dictionary] → Array[T]
var result: Array[T] = []
for d in serialized:
    # Pass-5D 2026-04-21 — type-guard added. JSON round-trip of an Array field
    # may contain non-Dictionary entries if a save was authored by a malformed
    # prior version, was hand-edited, or was migrated across a schema change
    # that changed the element type. `T.from_dict(d)` expects a Dictionary and
    # would either crash or return a degenerate object on a non-Dict input;
    # the guard preserves AC-SL-04's "no GDScript exception propagates"
    # contract by skipping the element and logging.
    if not d is Dictionary:
        push_warning("[SaveLoad] Array[T] element is not Dictionary (got %s) — skipping" % typeof(d))
        continue
    var obj: T = T.from_dict(d)
    if obj != null:
        result.append(obj)
    else:
        push_error("from_dict returned null for entry — skipping element")
```

**Applied types in RunSnapshot**:
- `formation_snapshot: Array[HeroInstance]` → serialized as `Array[Dictionary]` via `HeroInstance.to_dict()` per-element. Deserialized via `HeroInstance.from_dict(d: Dictionary) -> HeroInstance` (static class method). Pass-5A edit 2026-04-21 — closes godot-gdscript Item 5 + systems-designer F1: harmonized to the `to_dict() / from_dict()` array-element pair matching `KillEvent`'s convention. **Array-element serialization primitive (this rule) is DISTINCT from consumer-level registration contract (Rule 10: `get_save_data() / load_save_data()`)** — the former converts a single RefCounted value into a Dictionary; the latter delegates per-consumer namespace persistence to the SaveLoadSystem. An implementer must not conflate these layers: Hero Roster's autoload `get_save_data()` returns a Dictionary whose `"heroes"` key maps to an `Array[Dictionary]` produced via per-element `HeroInstance.to_dict()` calls.
- `kill_schedule: Array[KillEvent]` → serialized as `Array[Dictionary]` via `KillEvent.to_dict()` per-element. Deserialized via `KillEvent.from_dict(d: Dictionary) -> KillEvent`. **KillEvent defines `equals()` but does not currently define `to_dict()` / `from_dict()`.** See gap flag: Pass 3F micro-addendum required (flagged, not edited here).

**Inline vs helper util**: Because only `RunSnapshot` fields require this pattern in MVP (2–3 typed Array fields), the pattern is implemented **inline** inside `RunSnapshot.to_dict()` and `RunSnapshot.from_dict()`. No shared `SaveLoadUtil` helper is introduced. If a second cross-system RefCounted array serialization need arises in V1.0, extract to a utility at that point. The inline pattern is simpler, avoids an additional abstraction for a single consumer, and keeps the contract local to the type that owns it.

**Non-RefCounted dictionary fields (field-rename note — Pass 5B)**: Economy System's per-lifetime floor-clear idempotency gate was renamed in Pass 5B per ADR-0002: `floors_cleared_bonus_awarded: Array[bool]` → `floor_clear_bonus_credited: Dictionary[int, int]`. The replacement field is a plain `Dictionary[int, int]` (JSON-native int keys and int values), **not** an `Array[T extends RefCounted]`, so Rule 11's per-element `to_dict()` / `from_dict()` pattern does NOT apply — a `Dictionary.duplicate()` shallow-copy-of-primitives round-trip is sufficient. Rule 13's `SAVE_LOAD_FLOAT_EPSILON` does NOT apply either (int equality on both keys and values). The rename is a schema change; no migration path is required at launch because MVP has not yet shipped. See Economy C.2.3a + AC H-11 for the round-trip verification on the renamed field.

**Resource references (serialize-by-id)**: Godot `Resource` subclasses (such as `Floor` from Biome/Dungeon DB) must NOT be serialized inline via `inst_to_dict()` or `ResourceSaver` within the Save/Load JSON payload. Instead, serialize only the stable identifier (`id` field) and re-resolve the resource from `DataRegistry` on load. See Rule 12.

---

### Rule 12 — Serialize-by-Id Convention for Resource References (Pass 4B-SaveLoad, 2026-04-20)

When a serializable value type holds a reference to a Godot `Resource` (such as `Floor`, `HeroClass`, `EnemyData`), Save/Load mandates the following serialization approach:

**Serialize the `id` field only.** Example for `RunSnapshot.floor: Floor`:
```gdscript
# In RunSnapshot.to_dict():
result["floor_id"] = floor.id    # String — Floor's stable identifier

# In RunSnapshot.from_dict(d):
var floor_id: String = d.get("floor_id", "")
var floor: Floor = DataRegistry.resolve("floors", floor_id)
if floor == null:
    push_error("RunSnapshot.from_dict: floor_id '%s' could not be resolved — resetting to NO_RUN" % floor_id)
    return null
```

**Rationale**: Inline resource serialization (via `inst_to_dict()` or embedded `.tres` data) is fragile — schema drift between patches causes silent deserialization failures, and the embedded data bloats the save file unnecessarily. Serialize-by-id is idempotent, survives resource file path changes, and plays well with Godot 4.6's ResourceUIDs. The `DataRegistry` resolve is already the authoritative content lookup path used throughout the project.

**Resolve-failure contract**: If `DataRegistry.resolve()` returns `null` for an id stored in a save file (e.g., a floor was removed from content between a save and a load — authoring bug or content removal), the deserializing method:
1. Logs `push_error` with the specific id and the type being resolved.
2. Returns `null` (or a sentinel indicating deserialization failure).
3. The calling consumer (the Orchestrator) treats `null` as a `NO_RUN` reset. The session continues without the lost run state.

**`Floor.id` type**: `Floor.id` is typed as `String` in the Biome/Dungeon DB GDD (C.1). This is confirmed as the canonical type. The key stored in `RunSnapshot.to_dict()` must be `"floor_id"` (not `"floor"`) to distinguish the serialized-id form from a potential future inline form. JSON serialization of `String` is lossless — no type coercion issues at the save boundary.

**Per-consumer fallback table extension**: The existing fallback table in Section C Interactions is extended with a new row for the Orchestrator consumer:

| Consumer | Resolve returns null | Fallback policy |
|----------|---------------------|-----------------|
| Dungeon Run Orchestrator — `floor` in RunSnapshot | `DataRegistry.resolve("floors", floor_id) == null` | Log `push_error`; `from_dict` returns `null`; Orchestrator resets to `NO_RUN`; session continues. |

---

### Rule 13 — Float-Tolerance Semantics at the Save/Load Boundary (Pass 4B-SaveLoad, 2026-04-20)

The Save/Load system's JSON payload serializes and deserializes float values. The following semantics apply at the save/load boundary:

**Round-trip fidelity (Pass-5D 2026-04-21 — godot-gdscript F2; claim softened)**: Godot's JSON serialization of finite normal floats is **expected to round-trip stably** for IEEE 754 double-precision values in the normal range — but this GDD does NOT assert "bit-perfect" as a load-bearing contract. Prior versions of this rule claimed bit-perfect fidelity without citing an authoritative source; `json.stringify` → `json.parse` behavior for floats is a function of Godot's `String.num()` precision setting and the underlying `strtod` path, both of which have shifted across 4.x patches. The operational contract this GDD commits to is **empirically verified by AC-SL-01**: the round-trip equality assertions on `hp_bonus_factor`, `formation_dps_per_tick`, and all other `float` fields in `RunSnapshot` are the single source of ground truth; if any AC-SL-01 field fails equality, the contract is violated and the underlying issue is investigated at that point (fix options include: bump `String.num` precision, switch to `var_to_str`/`str_to_var` for floats specifically, or explicit stringify-with-full-precision helper). Until then, implementers treat round-trip as stable, and treat any AC-SL-01 failure on a float field as a Pass-5D-contract regression ticket.

**Special float values**: NaN, +Inf, -Inf, and subnormal (denormal) floats are not valid in save data — they represent authoring bugs or formula errors. Save/Load handles them as follows:
- On **persist**: if any float field in a consumer's `get_save_data()` output is `NaN`, `INF`, or `-INF`, log `push_error("[SaveLoad] ERROR: float field contains non-finite value — save data may be corrupt; field: [name], value: [value]")` and proceed with the write (do not abort — aborting the persist would lose other consumers' valid data). The non-finite value is written as JSON `null`.
- On **load**: if a float field deserializes as `null` (indicating a prior non-finite write), log `push_warning` and substitute the field's default value (zero for DPS; 1.0 for `hp_bonus_factor` — the safe-default that produces a non-LOSING run on the next dispatch). The session continues; the player's active run state is reset to `NO_RUN` if RunSnapshot deserialization fails.

**Float comparison at boolean gates**: Floats that participate in boolean gates (such as `hp_bonus_factor < 0.5` computing `losing_run`) MUST NOT be re-derived from the loaded float value at load time. The boolean result is serialized explicitly alongside the float — see `losing_run` in Rule 14 below. The loaded `losing_run` bool is authoritative; the float is for display and diagnostics only.

**Float comparison in `equals()` methods**: Use `is_equal_approx(a, b)` with the Godot default epsilon (`CMP_EPSILON = 1e-5`) only for DPS-range floats (`formation_dps_per_tick ∈ [0.0, 2.31]`) and `hp_bonus_factor ∈ [0.0, 1.0]` in field-equality tests (e.g., `RunSnapshot.equals()`). Do NOT use `is_equal_approx` for boolean-gate comparisons — use the saved boolean directly.

**Epsilon constant**: `SAVE_LOAD_FLOAT_EPSILON = 0.00001` (matching Godot's `CMP_EPSILON`). This constant is defined as a class constant on `SaveLoadSystem` and referenced by any Save/Load consumer that needs to perform float comparison at the load boundary. It is NOT redefined per-consumer. See entities.yaml for the registry entry.

---

### Rule 14 — Boolean-Gate Field Serialization (Pass 4B-SaveLoad, 2026-04-20)

Fields whose boolean value is derived from a float comparison at compute time (such as `losing_run`, derived from `hp_bonus_factor < 0.5`) MUST be serialized explicitly as boolean fields in the save data, not re-derived from the serialized float on load.

**Rationale**: Even though Godot's JSON serialization of finite normal floats is bit-perfect, the save/load boundary is a logical discontinuity. Explicit serialization of the derived boolean removes any dependency on float precision at the boundary, eliminates the risk of boundary-flip for values at or near the threshold (e.g., `hp_bonus_factor == 0.5` exactly), and makes the save format self-documenting — the reader can verify the boolean without re-running the derivation formula.

**Applied to `RunSnapshot`**: `to_dict()` includes both `"hp_bonus_factor": float` and `"losing_run": bool` as separate fields. `from_dict()` reads `losing_run` directly from the dict — it does NOT recompute `hp_bonus_factor < 0.5`. The boolean is authoritative through the save boundary.

---

### Anti-Tamper Specification

This subsection details the casual-deterrent anti-tamper layer. It is referenced by Rule 9 as a "black box" for high-level flow; here is the specification the security-engineer owns.

#### File Layout (extends Rule 2)

```
[MAGIC: 4 bytes "LGLD"  (0x4C 0x47 0x4C 0x44)]
[VERSION: u16, little-endian]
[FLAGS: u16, reserved = 0x0000 in MVP; bit 0 = save_is_flagged_tampered (V1.0+)]
[PAYLOAD_LENGTH: u32, little-endian]
[PAYLOAD: PAYLOAD_LENGTH bytes — UTF-8 JSON, XOR-masked]
[HMAC: 32 bytes, HMAC-SHA256 over all preceding bytes]
```

Fixed header = 12 bytes (magic + version + flags + payload length). Fixed footer = 32 bytes (HMAC). Payload dominates size at any realistic scale. `PAYLOAD_LENGTH` lives inside the HMAC-protected region so it cannot be rewritten to trigger over-read.

#### XOR Mask (Obfuscation Layer)

The JSON payload is XOR-masked before the HMAC is computed. The mask key stream is derived as:

```
seed = SHA256(MAGIC || VERSION || 16_BYTE_STATIC_SECRET)
mask = SHA256(seed || chunk_index_u32) repeated until PAYLOAD_LENGTH bytes exist
masked_payload[i] = plaintext_json[i] XOR mask[i]
```

**This is not encryption.** A determined attacker extracts the static secret from the binary and reconstructs the mask. The purpose is that a player with Notepad++ or a casual hex editor sees binary noise instead of `"gold": 100` — they cannot trivially make a targeted edit by searching for a text string. This correctly targets the casual-deterrent threshold.

**Static-secret extractability — implementer contract (Pass-5B-remainder 2026-04-21 — security-engineer F2).** The 16-byte `STATIC_SECRET` is a **namespace salt, not a key**. Implementers MUST NOT treat it as providing secrecy. Any attacker with `gdsdecomp` or an equivalent GDScript decompiler can extract the byte sequence from an exported PCK in under two minutes — a constant named `_STATIC_SECRET`, or even an anonymous 16-byte literal in the XOR-derivation call path, is trivially locatable in decompiled bytecode. Its role is purely to ensure the XOR mask differs across different games built on the same engine conventions (so a cheat tool written for one game's mask cannot be trivially reused against another game's saves); it is NOT a confidentiality boundary and MUST NOT be referenced as one in implementation comments, variable naming, or log messages. HMAC key material (see HMAC Key Problem below) rotates per build version and combines multiple autoload-scattered byte arrays; the static secret does NOT participate in HMAC keying, and any implementation that mixes the static secret into the HMAC key derivation is a regression against this contract.

#### HMAC Key Problem (honest acknowledgment)

The HMAC key cannot be kept secret from a determined attacker — the binary is shipped to the player's machine. We accept this and design for it:

- **Multi-part key assembly at runtime** — the key is derived from 3-4 byte arrays defined in different autoload scripts, none named with "HMAC"/"key" hints. Combined at runtime via `SHA256(PART_A ⊕ PART_B || PART_C || build_version_string)`.
- **Build-version rotation with N-1 key history (Pass-5B-remainder 2026-04-21 — security-engineer F1/C; user decision D1 this pass: N=2).** The build version string is part of key derivation. Each game patch produces a new HMAC key. The loader maintains a **fixed-length key history array of size N=2**, indexed `keys[0] = current, keys[1] = prior`. On load: recompute HMAC with `keys[0]` first; if verification fails, retry once with `keys[1]`. If `keys[1]` succeeds, hydrate normally AND immediately re-persist (Rule 7 atomic write) so the save is re-signed under `keys[0]` on the next write — the player's next load will match on `keys[0]` and no longer touch `keys[1]`. The "prior version string" is **literally** `CURRENT_VERSION_STRING` from the prior release commit, written into `keys[1]` by the build pipeline at export time — it is NOT read from the loaded save (attacker-controllable), it is compiled into the shipped binary via the same compile-time `const` discipline as `integrity_check_enabled` (§G). **N=2 is authoritative.** N>2 prolongs the compatibility window for any published cheat tool (strictly harmful). N<2 (zero history — pure rotation on every patch) destroys every pre-patch save on update, a Pillar 1 catastrophe. Implementers MUST NOT generalize to a variable-length key history or expose N as a tuning knob.
- **When the key leaks** — release a patch that bumps the version string. Cheat tools built for the old key stop working against new saves until updated. The N-1 fallback migrates legitimately-signed saves forward on next load without a visible prompt. For a $15 cozy idle game, the effort-to-reward ratio for cheat-tool authors is marginal.

#### HMAC Verification Behavior (extends Rule 8, Rule 9)

**Ordering rationale (Pass-5B-remainder 2026-04-21 — security-engineer F7/C).** The step order below is deliberate and MUST be preserved: MAGIC → VERSION → HMAC. Reordering HMAC to step 1 ("HMAC-first fail-fast") creates a save-destruction DoS on the N-1 key fallback path: any file that passes MAGIC + VERSION but fails HMAC under BOTH `keys[0]` AND `keys[1]` (e.g., a save legitimately signed by a build older than N-1, a corrupted save with partially-intact header, or a cross-game paste from a same-engine build that happens to share MAGIC) would enter the corruption policy (Rule 8) without the cheap MAGIC-byte gate first filtering structurally unrelated files. Under the specified MAGIC→VERSION→HMAC ordering, any file failing MAGIC is rejected cheaply and never burns the HMAC-retry budget, preserving the N-1 key retry logic (Build-Version Rotation above) exclusively for files that are plausibly our own save format. Implementers MUST NOT reorder for perceived fail-fast efficiency.

On load:

1. Validate MAGIC bytes — mismatch → corruption modal; do not proceed
2. Read VERSION — if newer than `CURRENT_SAVE_VERSION`, apply `future_version_save_policy` (default: refuse + modal)
3. Recompute HMAC over bytes `[0 .. file_length − 33]` using `keys[0]` (current build key); if mismatch, retry once with `keys[1]` (N-1 prior build key per Build-Version Rotation); compare to the last 32 bytes. Pre-HMAC buffer allocation uses `file_length − 44`, NOT PAYLOAD_LENGTH (Rule 2 DoS defense). If `keys[1]` succeeds where `keys[0]` failed, proceed to load AND immediately queue a re-persist under `keys[0]` per the N-1 migration contract.
4. **HMAC passes + `flag_suspicious_timestamp == false`** → normal load (READY). Post-HMAC, assert `PAYLOAD_LENGTH == file_length − 44`; mismatch → corruption policy.
5. **HMAC passes + `flag_suspicious_timestamp == true`** → log; queue "clock change detected" toast for next launch; load normally (Time System already zeroed offline gains — no double penalty)
6. **HMAC fails (either flag)** → show non-blocking modal: *"This save file has been modified. Your progress is still here, but Lantern Guild has noticed the change. Continue anyway? [Yes / No]"* — **Pass-5E 2026-04-21 — writer sign-off: copy CONFIRMED, no rewrite.** The previous draft already meets all Player-Fantasy criteria: non-accusatory ("noticed" not "detected"), reassures continuity ("Your progress is still here"), names the actor by project name (reinforces the cozy world), returns agency via [Yes/No] (the tampered state is the player's choice to accept). The only Pass-5E adjustment is downstream (the "Modified" label suppression below) — the modal itself stays.
    - **Yes** → load; set `save_is_flagged_tampered = true` in the save's FLAGS field; **immediately perform a synchronous atomic persist (Rule 7) BEFORE the modal is dismissed**, so the FLAGS.bit0 write survives an immediate force-quit (Pass-5B-remainder 2026-04-21 — user decision D3 this pass closes the write-race). In the same persist, increment `_meta.tamper_suspicious_count` (see `_meta` Sub-Schema below). Only after the persist completes successfully is the modal dismissed and the session allowed to proceed. If the immediate persist fails (disk full, I/O error), retain the in-memory flag, log `[SaveLoad] ERROR: flag-bit persist failed — retry queued on next heartbeat`, dismiss the modal, and let the heartbeat scheduler retry. **"Modified" label — SUPPRESSED in MVP (Pass-5E 2026-04-21, user decision D5E-3).** The `FLAGS.bit0 = save_is_flagged_tampered` state persists silently on disk but is NOT surfaced to any UI in MVP (no Settings label, no HUD indicator, no Return-to-App screen annotation). Rationale: the state's purpose is to gate V1.0 cloud-save rejection and/or V1.0 achievement-unlock denial — consequence-features that do not ship in MVP. Surfacing the label without a consequence-feature produces a soft warning a legitimate player (e.g., one who edited to recover from a bug) sees forever with no path to clear it. Re-enable in V1.0 alongside the first consequence-feature that consumes the flag. Implementation contract: the on-disk bit is authoritative and set exactly as specified above; only the UI surface is suppressed via `SETTINGS_MODIFIED_LABEL_ENABLED = false` compile-time `const` in the Settings screen (same compile-time-const pattern as `integrity_check_enabled` to avoid `override.cfg` re-exposure — see Section G).
    - **No** → attempt `.bak` fallback; if both fail, apply corruption policy (Rule 8)

The MVP deliberately avoids hard consequences for HMAC failure (no save lock, no achievement block — Steam achievements are not shipped in MVP anyway). The internal flag preserves signal for future consequences (cloud save rejection in V1.0, achievement lock if added post-launch). Pillar 1 dominates: playability over audit purity.

#### HMAC-SHA256 Construction (Pass-5B-remainder 2026-04-21 — godot-gdscript Item 7; user decision D4 this pass)

Godot 4.6's `HashingContext` exposes **raw SHA-256 only** — there is no stdlib HMAC primitive. HMAC-SHA256 MUST be implemented from scratch in GDScript per RFC 2104, layered on `HashingContext.HASH_SHA256`. The scratch implementation is chosen over a GDExtension-wrapped native binding (e.g., libsodium) for three reasons: (a) the code stays inspectable in-tree with no native-build-pipeline pressure; (b) HMAC-SHA256 is a ~30-line wrapper around SHA-256, small enough that scratch cost is negligible; (c) the hot hashing path remains native because the SHA-256 primitive itself is native via `HashingContext`.

Reference structure (implementer fills):

```gdscript
# tests/unit/save_load/test_hmac_sha256_rfc4231.gd gates this (see AC-SL-HMAC-01).
func hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
    const BLOCK_SIZE := 64  # SHA-256 block size in bytes
    if key.size() > BLOCK_SIZE:
        key = sha256(key)                # hash oversized keys first
    if key.size() < BLOCK_SIZE:
        key.resize(BLOCK_SIZE)           # zero-pad to block size (resize zero-fills)
    var o_key_pad := PackedByteArray()
    var i_key_pad := PackedByteArray()
    o_key_pad.resize(BLOCK_SIZE)
    i_key_pad.resize(BLOCK_SIZE)
    for i in BLOCK_SIZE:
        o_key_pad[i] = key[i] ^ 0x5C
        i_key_pad[i] = key[i] ^ 0x36
    return sha256(o_key_pad + sha256(i_key_pad + msg))

func sha256(data: PackedByteArray) -> PackedByteArray:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(data)
    return ctx.finish()
```

**Conformance gate (AC-SL-HMAC-01):** The implementation MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly before ANY `AC-SL-TAMPER-*` AC is exercised. A tamper AC passing while HMAC is subtly buggy produces false confidence — the tamper detection may catch one deterministic wrong-tag pattern but miss others. See AC section for the gate detail. No timing-side-channel (constant-time compare) requirement: a single-player premium game is out of scope for timing attacks.

An attacker who copies an **old, legitimately-signed save** over their current save cannot be detected by HMAC alone (the copied save is cryptographically valid). Mitigation:

- **Offline cap bounds the damage** — even a replayed save produces at most `offline_cap_seconds = 28 800` seconds (8h) of gains on next session
- **`save_sequence_number` field** in the payload increments on every persist; future cloud save uses it to detect replay across devices ("two-device back-and-forth" attack); for local-only MVP it is a diagnostic signal
- **`tamper_suspicious_count` field** increments whenever `flag_suspicious_timestamp` fires; post-launch analytics can identify replay patterns

**This is a documented, accepted residual risk at the local-save layer.** Full defense requires server-validated saves or cloud-authority save state — both out of MVP scope and disproportionate to the threat for a single-player premium game.

#### `_meta` Sub-Schema (Pass-5B-remainder 2026-04-21 — security-engineer F5/C; consolidates R-R6)

The save payload's top-level `_meta` key carries the security and verification fields owned by the **SaveLoadSystem itself** — fields NOT delegated to any consumer's `get_save_data()` output. This consolidates three forward-references that previously lived in Rule 2 (`slot_index`), Rule 9 (`tamper_suspicious_count`), and §346-353 above (`save_sequence_number`). Canonical JSON shape:

```json
"_meta": {
  "slot_index": 1,
  "save_sequence_number": 4217,
  "tamper_suspicious_count": 0,
  "backup_restore_events": []
}
```

| Field | Type | Width | Range | Persist timing | Overflow behavior |
|---|---|---|---|---|---|
| `slot_index` | int | 32-bit | 1..`save_slot_count` | Written once at slot creation (first persist on that slot); never mutated by any subsequent persist. Changing the value requires deleting the save and re-creating. | N/A — immutable post-creation |
| `save_sequence_number` | int | 64-bit (GDScript `int` is 64-bit signed; JSON round-trips losslessly for values ≤ 2^53) | 0..unbounded | Incremented atomically in the persist path BEFORE the envelope is composed (pre-HMAC); monotonic per successful persist only. A failed persist (disk full, etc.) does NOT advance the counter. | Saturates at 2^53 − 1; subsequent persists log `push_warning("[SaveLoad] WARN: save_sequence_number saturated — cloud replay detection degraded")` and reuse the saturated value. Single-player MVP will not reach saturation even under continuous 1-Hz persists for 285 million years. |
| `tamper_suspicious_count` | int | 32-bit (capped; see below) | 0..10 000 | Incremented **immediately** on `flag_suspicious_timestamp` receipt AND **immediately** on Yes-on-tamper-modal (per HMAC Verification Behavior step 6); both increments write through the same synchronous persist path that owns the FLAGS.bit0 write-race closure. | Saturates at 10 000; subsequent increments no-op + `push_warning`. The counter is a diagnostic signal for post-launch analytics, not a gate — saturation is not a security concern. |
| `backup_restore_events` (Pass-5E 2026-04-21) | `PackedInt64Array` of unix timestamps (JSON-encoded as a plain `Array[int]` on the wire; re-hydrated to `PackedInt64Array` on load) | n × 64-bit | 0..`BACKUP_ESCALATION_THRESHOLD + 1` active entries after scrub | Appended on every `.bak` fallback success (Rule 8 step 2). **Scrubbed on every persist** — entries older than `now - BACKUP_ESCALATION_WINDOW_SECONDS` are dropped BEFORE the new persist writes its envelope; this bounds memory to at most ceil(`BACKUP_ESCALATION_WINDOW_SECONDS / heartbeat_interval_seconds`) conservative entries (≈10 080 under a 1-Hz-worst-case and 7-day window, but realistically ≤ `BACKUP_ESCALATION_THRESHOLD + 1` because scrub also clamps post-escalation). | Hard cap at 16 entries per persist pre-scrub; a 17th append is silently dropped + `push_warning` (an attacker cannot exploit this cap — the scrub runs first on every subsequent persist). |

**Consumer boundary.** `_meta` is owned by SaveLoadSystem. Consumers MUST NOT read, write, or inspect `_meta`. The top-level payload dictionary has two disjoint key classes: (a) consumer-namespace keys (`"economy"`, `"roster"`, `"floor_unlock"`, etc., each owned by one consumer) and (b) `"_meta"` (owned by SaveLoadSystem). Any consumer that writes into `_meta` is a regression against this contract.

**Verification on load.**
- `slot_index` mismatch (file at `save_slot_1.dat` carries `_meta.slot_index != 1`) → log `push_error`, transition to CORRUPT, show the standard Rule 8 corruption modal. Mismatch indicates filesystem-level cross-contamination (restore from backup writing to wrong slot) or disk corruption above the integrity layer; `.bak` fallback is NOT attempted because a mismatched slot_index in `.dat` most likely has the same defect in `.bak`. Silent override is forbidden — it would break cloud-sync assumptions in V1.0.
- `save_sequence_number` monotonicity is enforced cross-session only in V1.0 cloud sync; local MVP reads the value for forward-compat population and does NOT reject saves on monotonicity violation (the local attacker can always rewrite a previous save, which is the accepted replay residual risk per §345-353 above).
- `tamper_suspicious_count` is persisted across launches. Debug-only test helper `SaveLoadSystem.get_meta_field(name: String) -> Variant` (guarded by `if OS.is_debug_build():`) exposes the value to GdUnit4 tests. AC-SL-09 and AC-SL-TAMPER-04 assert `get_meta_field("tamper_suspicious_count")` increments as expected.
- `backup_restore_events` (**Pass-5E 2026-04-21**) is persisted across launches and drives the Rule 8 backup-restore repetition escalation. On every persist (BEFORE the envelope composes), the scrub step removes entries where `event_ts < now - BACKUP_ESCALATION_WINDOW_SECONDS`. On every `.bak` fallback success (Rule 8 step 2), `now` is appended to the array; if the post-append array length ≥ `BACKUP_ESCALATION_THRESHOLD`, the storage-advisory modal fires for that load instead of the normal backup-restore toast. Absent field (older save format) hydrates to an empty array — forward-compatible. Debug helper: `SaveLoadSystem.get_meta_field("backup_restore_events") -> PackedInt64Array`.

**Forward-compat.** Adding a new `_meta` field requires a save-format version bump (Rule 4) so migrators can seed the field with its default. Removing or renaming a `_meta` field is a breaking change handled the same way. `_meta` is intentionally a small, stable namespace; resist the temptation to put consumer-adjacent state here.

#### Atomic Write + Backup Rotation Details (extends Rule 7)

- Write order: `save_slot_1.dat.tmp` → flush → rename to `save_slot_1.dat` → copy previous `.dat` contents to `save_slot_1.dat.bak`
- iOS/Android rename atomicity not guaranteed; fallback uses a `.commit` marker pattern — write `.tmp`, write 1-byte `.commit` marker, rename, delete `.commit`. On load, a partial state (`.tmp` exists but `.commit` missing, or vice versa) falls back to `.bak`
- **HMAC is computed over the masked payload bytes**, not plaintext. Any byte-level edit of the file is caught regardless of whether the attacker knows the XOR mask

#### Cross-Device / Cloud Save Preparation (V1.0)

The payload includes two forward-compatibility fields that cost nothing at MVP and prevent save-format migration pain later:

- `last_persist_unix_ts` (already required by Time System) — cloud sync conflict resolution uses higher timestamp as authoritative
- `save_sequence_number` (int, increments per persist) — detects "two-device back-and-forth" replay when cloud sync is added

Cloud save itself is deferred to V1.0+. A dedicated cloud-save GDD will own conflict resolution UX and multi-device orchestration.

---

## Formulas

There are no derived mathematical formulas in this system. The relevant numeric constraints are budgets and invariants.

### D.1 Save File Size Budget

| Tier | Target Max Size | Rationale |
|------|----------------|-----------|
| MVP (3 classes, 5 dungeons, ~8 enemies) | **< 20 KB** per slot | Roster, gold balance, unlocks, timestamp, active assignments — trivially small as JSON |
| V1.0 (15 classes, 20 dungeons, expanded roster) | **< 200 KB** per slot | Still well within any platform's write budget; mobile I/O is not stressed |
| Defensive hard cap | **2 MB** per slot | If serialized payload exceeds this, log `[SaveLoad] ERROR: payload size {N} bytes exceeds cap — aborting persist` and do not write. Prevents runaway serialization bugs from destroying the save file. |

The binary envelope overhead (**header 12 bytes + footer 32 bytes = 44 bytes total** per Pass-5A Rule 2 rewrite; amended Pass-5B-emergency 2026-04-21 — this sentence previously said "header 32 bytes" which was stale from the pre-Pass-5A 32-byte-header-with-padding scheme) is negligible. The JSON payload dominates size. At MVP scale, a realistic payload is under 2 KB before compression. The 20 KB budget is conservative headroom.

**No compression in MVP.** At under 20 KB, compression saves negligible bytes and adds implementation complexity. Revisit at V1.0 if payload grows toward 200 KB.

### D.2 Persist Time Budget

| Platform | Target | Warning Threshold |
|----------|--------|-------------------|
| PC (Steam, SSD) | **< 10 ms** end-to-end | 50 ms — log `[SaveLoad] WARN: persist took {N}ms` |
| Mobile (minimum spec) | **< 50 ms** end-to-end | 150 ms — log warning |

"End-to-end" includes: JSON serialization of all consumer dicts + binary envelope assembly + `store_buffer()` write + `flush()` + `DirAccess.rename()` (or copy-then-delete fallback). If mobile benchmarks exceed the 50 ms target, move serialization to a background thread and double-buffer the payload — measure first before adding the complexity.

### D.3 Load Time Budget

| Platform | Target | Warning Threshold |
|----------|--------|-------------------|
| PC | **< 50 ms** | 200 ms |
| Mobile (minimum spec) | **< 100 ms** | 300 ms |

Load occurs once per session at launch. The player expects a brief loading moment; 100 ms is imperceptible if paired with a fade or splash frame. Load budget includes: file read + integrity verification + JSON parse + all `load_save_data()` calls + `DataRegistry.resolve()` per roster member. At MVP roster sizes (12 or fewer heroes), `resolve()` calls are negligible.

### D.4 Save File Age Warning Threshold

No hard expiry on saves. If `t_current - last_persist_unix_ts > SAVE_AGE_WELCOME_BACK_THRESHOLD_SECONDS`, show a one-time toast on load: "Welcome back! It's been a while — your guild has been waiting." This is a quality-of-life signal only — not a blocking warning. The save is loaded normally. Rationale: a player returning after months of absence should feel welcomed, not interrogated.

**Threshold recalibration — 180 days → 60 days (Pass-5E 2026-04-21, user decision D5E-2).** The prior default of 15 552 000 seconds (~180 days) was inherited from an earlier live-ops pattern where the toast was intended to drive recovery-session analytics. Playtest signal from comparable idle games shows 180 days is too long — by that point most players have already re-installed or uninstalled; the toast never fires for the lapsed-but-returning 2-to-3-month cohort who are the actual target. 60 days is the midpoint of the "lapsed but retrievable" band (post-first-weekend retention cliff, pre-uninstall threshold). The 90-day alternative was considered; 60 was selected because idle-game sessions drift in weekly cadence and a ~2-month gap is already conspicuous to the player (and therefore worth a cozy acknowledgment) without being so tight that the toast fires on a 3-weeks-no-play-during-a-busy-month player who would find it patronizing.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `SAVE_AGE_WELCOME_BACK_THRESHOLD_SECONDS` | int | 0 – unbounded | Seconds since last persist above which the "welcome back" toast fires. Default: **5 184 000** (~60 days; **Pass-5E 2026-04-21 recalibration from 15 552 000 / ~180 days** per D5E-2 rationale above). Set to 0 to disable. Does not affect save validity or loading behavior. |

---

## Edge Cases

**If power is lost mid-persist:** The atomic write pattern (write-temp → rename) guarantees that `save_slot_1.dat` is never partially written. If power fails during the `.tmp` write, `.dat` is untouched and `.dat.bak` holds the prior complete save. On next launch, a stale `save_slot_1.dat.tmp` may exist; it is ignored (not a valid save path) and deleted on startup. The player loses at most the in-progress heartbeat interval — up to 60 seconds of foreground progress.

**If disk is full during persist:** `FileAccess.open()` or `store_buffer()` returns an error (verify exact return type against Godot 4.4 `FileAccess` changes — see Open Questions). The persist is aborted. The in-memory state remains valid. The existing `.dat` is untouched (the atomic write never reached rename). Log `[SaveLoad] ERROR: persist aborted — disk full`. Show a persistent non-blocking banner: "Save failed — storage full. Free space to prevent data loss." Retry on the next heartbeat. Do not crash.

**If the save file is corrupted at rest (bit flip, partial write from a prior crash):** Integrity hash verification fails. Apply the failure policy from Rule 8: attempt `.bak`, then fresh start with modal. This is the primary reason the HMAC footer exists — it detects arbitrary corruption reliably, not just deliberate tampering.

**If the save file is from a newer game version (`header.version > CURRENT_SAVE_VERSION`):** The format version in the header exceeds the compiled constant. Default policy: **refuse-to-load with modal** — "This save was created with a newer version of Lantern Guild. Please update the app." Transition to `CORRUPT` state. Do not attempt to read a format whose schema is unknown; silent partial hydration would produce worse outcomes than an honest failure. (Overridable via `future_version_save_policy` knob — see Section G.)

**If the save file is from an older version (`header.version < CURRENT_SAVE_VERSION`):** Enter `MIGRATION` state and run the versioned migration script for `stored_version → CURRENT_SAVE_VERSION`. If migration succeeds, hydrate and immediately re-persist to upgrade the file on disk. If migration fails, fall through to the corruption policy (try `.bak`, then fresh start with modal).

**If a save references a content id that no longer exists (class deleted in a patch, dungeon removed):** `DataRegistry.resolve()` returns `null`. Apply the per-consumer fallback table from Section C. This is not corruption — the save is structurally valid. The missing reference is logged, the affected slot is conservatively dropped (hero removed, floor re-locked), and the session continues. The player may notice the loss; that outcome is acceptable and far preferable to a crash or silent data corruption.

**If the Data Loading System is in `ERROR` state on launch:** Do not attempt to load the save. `DataRegistry.resolve()` would return `null` for every reference, producing an all-null player state that silently erases the roster and progress. Transition immediately to `CORRUPT` state with the AC-SL-08 modal (**Pass-5E copy**): *"Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]"* Do not delete the save file — it is likely recoverable after a reinstall resolves the content issue; the "your save is safe and untouched" promise is literal (no filesystem writes occur on this path; the on-disk save file is bit-identical to the last persist).

**If the integrity hash mismatches on load:** The save has been modified since it was written — either bit corruption, a prior partial write, or deliberate editing. Apply the failure policy from Rule 8: try `.bak`, then fresh start with modal. The integrity check is always on in production. It is the single-point gate protecting player progress.

**If both `.dat` and `.bak` exist with different content:** Always attempt `.dat` first (it is the result of the most recent successful atomic rename). If `.dat` fails integrity, fall back to `.bak`. Do not attempt to merge the two files.

**If the player has no save (first launch):** `FileAccess.open()` on `user://save_slot_1.dat` returns null or error. This system seeds a fresh in-memory state, initializes all consumers to their defaults, and writes an initial save. It emits `first_launch = true` so the Onboarding / First-Session Flow can activate. Time System receives `last_persist_unix_ts = now` as its seed value per Time System GDD Rule. This system does not own the first-launch UX.

**If iOS/Android backup or device restore copies a save to a new device:** The `last_persist_unix_ts` in the restored save will be behind the new device's current clock. This is a legitimate restore, not an attack — `elapsed_raw` will be large and positive, not negative. The offline cap clamp absorbs the excess (Time System). `flag_suspicious_timestamp` is NOT expected to trigger. No special handling is needed at the Save/Load layer for this scenario; it resolves correctly through the existing time-delta path.

**If the save file is locked by an OS backup process during a heartbeat persist:** `FileAccess.open()` on `.tmp` fails or blocks. Treat identically to a disk-full scenario: abort persist, log the error, show the "save failed" banner, retry on next heartbeat. The existing `.dat` is safe because the write never began.

**If a heartbeat fires while a consumer state change is in flight (concurrency):** All `get_save_data()` calls happen at the start of persist, capturing a consistent snapshot of consumer state at the moment the heartbeat fired. If a UI action completes and changes state after the snapshot is taken (during the file write), the next heartbeat will capture the updated state. The invariant is "save is consistent at the snapshot moment," not "save reflects every change in real time." No consumer-state locking during the write phase is required.

**Cloud save (V1.0+):** Deferred. For conflict resolution, prefer the save with the higher `last_persist_unix_ts` as the authoritative state (per Time System GDD cloud-save note). Full merge strategy, conflict UI, and multi-device orchestration are owned by a future cloud-save GDD. MVP ships with local save only. The slot-path abstraction (`save_slot_path(slot)`) leaves room for a cloud-backed path without refactoring call sites.

---

## Dependencies

### Upstream Dependencies (systems this one depends on)

| Upstream | Hard/Soft | Interface | Notes |
|---|---|---|---|
| **Game Time & Tick System** (`design/gdd/game-time-and-tick.md`) | Hard | Reads `TimeSystem.get_last_persist_ts() -> int64` AND `TimeSystem.get_session_high_water() -> int64`; writes both back via `set_last_persist_ts(ts)` + `set_session_high_water(ts)` on load; receives `flag_suspicious_timestamp` signal. Both timestamp fields MUST be covered by HMAC signature (Time System AC-TICK-05b depends on `t_session_high_water` round-trip integrity). | `heartbeat_interval_seconds=60` owned by Time System, not duplicated here |
| **Scene/Screen Manager** (`design/gdd/scene-screen-manager.md`) | Hard | Subscribes to `scene_boundary_persist` signal (fired before Dungeon Run View enter and Victory Moment exit); emits `save_completed` and `save_failed` back to Scene Manager so it can abort the pending transition on persist failure | Scene Manager owns transition orchestration; Save/Load owns persist timing |
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | Calls `DataRegistry.resolve(content_type, id) -> Resource \| null` during hydration; checks `DataRegistry.state == READY` before load | If `DataRegistry.state == ERROR`, Save/Load refuses to load and transitions to `CORRUPT` state |

### Downstream Dependents (systems that depend on this)

Each consumer exposes `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary) -> void`. This system orchestrates the calls; consumers own their sub-dictionary schema. **Pass-5A edit 2026-04-21** — 4-specialist cross-model BLOCKING (systems-designer F1 + qa-lead F1 + godot-gdscript Item 4 + godot-specialist Bonus) confirmed that Floor-Unlock-Pass-3-Edit's partial harmonization left Rule 3 + state-table + AC-SL-01 + §F Economy/Roster/Formation/Recruitment rows on the stale `save_to_dict / load_from_dict` pair while Rule 10 + Floor Unlock + Orchestrator rows used the canonical pair. Pass-5A completes the harmonization globally. There is no `register_consumer` call — consumers are discovered via Rule 10 direct-call contract at serialization boundaries. **Consumer discovery mechanism (Pass-5A edit; refined Pass-5D 2026-04-21 — godot-gdscript F3 + godot-specialist F2)**: SaveLoadSystem holds a hardcoded ordered list of **consumer autoload node paths** (in rank order: `/root/Economy`, `/root/HeroRoster`, `/root/FloorUnlock`, `/root/FormationAssignment`, `/root/Recruitment`, `/root/DungeonRunOrchestrator`) resolved via `get_node_or_null(path)` at **each serialization boundary** (one resolve per persist AND one resolve per load — NOT cached on an instance var at `_ready` time). Each resolve MUST be followed by an explicit nil-check + fatal assert if missing in a non-debug build:

```gdscript
# Pattern used at each serialization boundary — DO NOT cache in an instance var.
const CONSUMER_PATHS: PackedStringArray = [
    "/root/Economy",
    "/root/HeroRoster",
    "/root/FloorUnlock",
    "/root/FormationAssignment",
    "/root/Recruitment",
    "/root/DungeonRunOrchestrator",
]

func _call_all_get_save_data() -> Dictionary:
    var out := {}
    for path in CONSUMER_PATHS:
        var node := get_node_or_null(path)
        if node == null:
            # In a non-debug production build this is a fatal rank-table violation
            # or a missing-autoload regression; halt rather than persist a partial save.
            push_error("[SaveLoad] FATAL: consumer autoload missing at %s" % path)
            if not OS.is_debug_build():
                get_tree().quit(1)
            continue  # debug-only: skip this consumer and continue so the test harness can report
        assert(node != null, "[SaveLoad] consumer autoload %s missing" % path)
        assert(node.has_method("get_save_data"), "[SaveLoad] consumer %s lacks get_save_data" % path)
        # Namespace key is the trailing path segment lowercased — "/root/Economy" → "economy".
        out[path.get_file().to_snake_case()] = node.get_save_data()
    return out
```

**Why per-call resolution (not cached)** — Godot 4.x hot-reload on an autoload script swaps the underlying node instance: the autoload Node is re-added to the tree root under the same path, but any previously-cached reference on SaveLoadSystem still points at the freed instance. A cached `var _economy: Economy = Economy` captured at `_ready` becomes a dangling reference after a hot-reload cycle (common in dev; also reachable via `EditorPlugin.reload_scripts()` in tooling). Per-call `get_node_or_null(path)` always returns the current instance. Production builds do not hot-reload, but the cost of per-call resolution is one dictionary lookup in Godot's SceneTree path cache — sub-microsecond, sub-negligible relative to the dominant HMAC + JSON phase of a persist. The caching-wins-performance argument does not apply at this boundary.

**The `assert(node != null)` on the resolve result is additionally the contract that prevents AC-SL-01's six-consumer fixture from silently passing with one consumer missing** — a nil consumer would produce a top-level dict missing a namespace key, which `load_save_data` on the other five consumers wouldn't notice; the missing consumer's state would vanish on the next load. The assert catches the regression at persist-time, long before load.

Adding a new consumer requires editing the `CONSUMER_PATHS` constant in SaveLoadSystem + adding its §F row here + assigning it the next available rank in §C.3 + updating AC-SL-01's fixture to include it. No SceneTree group query or runtime registration mechanism is used — the tight coupling is intentional: Save/Load's consumer set is small, enumerable, and stable across sprints.

| Consumer | Hard/Soft | Interface | What they persist |
|---|---|---|---|
| **Economy System** | Hard | `get_save_data()` / `load_save_data(data)` dict contract | Gold balance, resource sink/faucet state, spend history |
| **Hero Roster** | Hard | `get_save_data()` / `load_save_data(data)` + `DataRegistry.resolve("classes", id)` per hero | Roster entries: `{id, class_id, level, xp, equipped_items[]}` |
| **Floor/Biome Unlock System** | Hard | `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)`; namespace key `"floor_unlock"` in top-level dict; payload shape `{"highest_cleared": {biome_id: int}}` (pure int — Rules 13/14 N/A); missing key on load → fresh-save default `{"forest_reach": 0}`; out-of-range value clamped to `BIOME_FLOOR_COUNT[biome_id]` with `push_warning` (GDD #16 §E). Authored 2026-04-20 Floor-Unlock-Propagation-Edit-2; superseded prior "Array[String]" placeholder. | Per-biome highest_cleared monotonic int; see `design/gdd/floor-unlock-system.md` §C.3 |
| **Formation Assignment System** | Hard | `get_save_data()` / `load_save_data(data)` + per-dungeon resolver calls | Current assignments: `{dungeon_id: [hero_id, hero_id, hero_id]}` |
| **Recruitment System** | Hard | `get_save_data()` / `load_save_data(data)` | Recruit pool state, recruit history |
| **Dungeon Run Orchestrator** | Hard | `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)`; namespace key `"orchestrator"` in top-level dict; returns `{"active_run": snapshot.to_dict()}` if run active, `{}` if `NO_RUN`; `RunSnapshot.to_dict()/from_dict()` round-trip per Rules 10–14 | Active run snapshot: formation, floor (by id), kill schedule, loop counter, hp_bonus_factor, losing_run (explicit bool), last_emitted_tick, floor_clear_emitted, matchup_cache |
| **Onboarding / First-Session Flow** | Soft | Reads `first_launch` signal emitted by Save/Load | Determines whether to show first-run flow |

### Bidirectional Consistency

This GDD claims dependence on Game Time & Tick (#1) and Data Loading (#2). Both those GDDs must list "Save/Load System" in their *Downstream Dependents* — verified at authoring time:

- `design/gdd/game-time-and-tick.md` Dependencies section: ✅ lists Save/Load as a hard dependent with `last_persist_unix_ts` + `t_session_high_water` + `flag_suspicious_timestamp` interface (both timestamp fields covered by HMAC signature)
- `design/gdd/data-loading.md` Dependencies section: ✅ lists Save/Load as a hard dependent with `resolve(content_type, id)` interface
- `design/gdd/scene-screen-manager.md` Dependencies section: ✅ lists Save/Load as a hard dependent via `scene_boundary_persist` signal subscription with `save_completed`/`save_failed` return path

**Pass-5-lean 2026-04-21 — R-N1 correction:** prior version of this paragraph claimed *"Economy, Hero Roster, Formation Assignment, Recruitment, and Onboarding GDDs are not yet written."* This was stale. Current status:

- **Economy System GDD** — ✅ authored; cites `design/gdd/save-load-system.md` at line 8; §F consumer row at line 191. **Drift RESOLVED Pass 5F-propagation 2026-04-21** — 7 hits canonicalized to `get_save_data / load_save_data` consumer contract. See `design/gdd/reviews/save-load-system-review-log.md` Pass-5F-propagation entry.
- **Hero Roster GDD** — ✅ authored; cites Save/Load at line 8; §F references at lines 19, 31, 45, 75. **Drift RESOLVED Pass 5F-propagation 2026-04-21** — 22 consumer-layer hits canonicalized to `get_save_data / load_save_data`; 2 element-layer hits at Rule 4 canonicalized to `HeroInstance.to_dict / from_dict` per Rule 11. Classification-per-hit applied.
- **Formation Assignment GDD** — ✗ not yet written; will cite "depends on Save/Load System" when authored against the canonical contract.
- **Recruitment GDD** — ✗ not yet written; same.
- **Onboarding / First-Session Flow GDD** — ✗ not yet written; same (soft dependency via `first_launch` signal).

**Floor/Biome Unlock GDD #16** was authored 2026-04-20 and cites this dependency in its §F (Hard upstream) using the canonical method pair; consumer row in this GDD updated in lockstep via Floor-Unlock-Propagation-Edit-2.

### V1.0 progression-layer downstream consumers (added 2026-05-09)

The following V1.0-tier systems extend the Save/Load contract:

- **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) — adds `RunSnapshot.synergy_id: String` to the Orchestrator save namespace. Forward-compat: missing field on load defaults to `""` (no migration required). Per `class-synergy-system.md` §F + AC-CS-12 / AC-CS-18.
- **Prestige System** (#31, V1.0 first-pass 2026-05-09) — **bumps `CURRENT_SAVE_VERSION` from 1 to 2** when V1.0 ships. Adds 3 fields to the HeroRoster save namespace: `prestige_count: int`, `prestige_multiplier: float`, `retired_hero_records: Array[Dictionary]`. Migration body `_migrate_v1_to_v2` authored in `prestige-system.md` §C.5 — defaults to zero/1.0/empty for V1→V2; idempotent on re-migration. AC-PR-12 + AC-PR-14 verify round-trip + migration. **This is the project's first save-format version bump** since the Story 010 schema-migration-placeholder shipped; the migration chain becomes live with V1.0.

---

---

## Tuning Knobs

| Knob | Type | Default | Safe Range | Effect |
|------|------|---------|------------|--------|
| `heartbeat_interval_seconds` | int | 60 | 15–300 | How often a heartbeat persist fires. **Do not duplicate this constant — it is defined and owned by the Time System.** Referenced here to clarify that reducing it requires a Time System change, not a Save/Load change. Lower values shrink data-loss window on crash; higher values reduce mobile I/O frequency. |
| `heartbeat_persist_enabled` | bool | true | Boolean | Enables/disables the heartbeat persist path. Disable for profiling sessions where disk I/O would skew measurements. Always `true` in production. |
| `pause_persist_enabled` | bool | true | Boolean | Fires a persist on FOREGROUND → BACKGROUNDED transition. Disable in dev if pause events are noisy during hot-reload cycles. Always `true` in production. |
| `shutdown_persist_enabled` | bool | true | Boolean | Fires a persist on graceful shutdown signal. Disable only when explicitly testing crash-recovery paths. Always `true` in production. |
| `integrity_check_enabled` | bool | true | Boolean | Whether the HMAC footer is verified on load. Set `false` in dev builds to load hand-edited saves for debugging. **Must be `true` in all production and QA builds.** Enforcement (Pass-5A, amended Pass-5B-emergency 2026-04-21): (a) **Surfacing mechanism**: this knob MUST be a GDScript compile-time `const` defined in the SaveLoadSystem autoload — NOT a ProjectSetting custom key. ProjectSetting surfacing is defeated by Godot 4.5+'s `user://overrides.cfg` mechanism, which applies overrides before any autoload `_ready()` runs; a player (or any tampering process) writing `override.cfg` would silently flip this to `false` and the runtime guard would halt on a legitimate player's machine (denial-of-service) or — if the halt is patched out of the bytecode — defeat the integrity check. Compile-time `const` values are emitted into bytecode and cannot be overridden at runtime. (b) **CI build-step assertion** inspects the exported PCK's source or compiled bytecode and fails the pipeline if the constant is not `true` in production exports. (c) **Runtime guard at `_ready()`** MUST use `if not OS.is_debug_build() and not integrity_check_enabled: push_error("[SaveLoad] FATAL: integrity_check_enabled is false in production build — halting"); get_tree().quit(1)` rather than `assert(...)`. **Pass-5B-emergency: `assert()` is stripped from GDScript release exports**; the Pass-5A wording mandated an `assert()` which is non-functional in shipped builds. See AC-SL-TAMPER-05 (applied Pass-5B-remainder 2026-04-21) for the CI-enforced automated verification covering this knob's surfacing contract. |
| `save_file_path` | String | `""` (empty = use canonical `save_slot_path()`) | Any valid `user://` path; **dev/QA builds only** | **Pass-5A edit 2026-04-21 — closes Floor Unlock #16 I.14 + systems-designer F2 + qa-lead F10 + godot-specialist Item 9 (user design decision: `save_file_path` knob chosen over `debug_reset_to_fresh()` API due to narrower blast radius — no state-destruction footgun in public API). Amended Pass-5B-emergency 2026-04-21.** When non-empty, overrides `save_slot_path(slot)` construction and uses this exact path for slot 0 reads/writes. GdUnit4 integration tests (Mode-2 per Floor Unlock §J.3) set this via a **debug-only static setter** on SaveLoadSystem (guarded by `if OS.is_debug_build():`) in `before_each()` and clear it in `after_each()`; the underlying field is a private GDScript `var _save_file_path: String = ""` — NOT a ProjectSetting custom key, for the same `user://overrides.cfg` attack surface described in `integrity_check_enabled`. **Production builds MUST enforce this is empty at runtime** via: `if not OS.is_debug_build() and _save_file_path != "": push_error("[SaveLoad] FATAL: save_file_path is non-empty in production build — halting"); get_tree().quit(1)` at SaveLoadSystem `_ready()`. **Pass-5B-emergency: `assert()` is stripped from GDScript release exports**; the Pass-5A wording mandated an `assert()` which is non-functional in shipped builds — replaced with explicit `push_error + quit(1)` pattern. Unblocks Floor Unlock AC-FU-13 + AC-FU-14 from `WRITEABLE-WITH-CI-CONSTRAINT` to full `WRITEABLE` (the pre-launch shell-step filesystem cleanup is no longer required; per-test path redirection handles isolation). See AC-SL-TAMPER-05 (applied Pass-5B-remainder 2026-04-21) for the CI-enforced automated verification that this field defaults to `""` and is not exposed as a ProjectSetting in production builds. |
| `corruption_fallback_policy` | enum | `TRY_BAK_THEN_NEW` | `TRY_BAK_THEN_NEW`, `TRY_BAK_THEN_REFUSE` | `TRY_BAK_THEN_NEW`: if both files corrupt, start fresh with a warning modal (recommended — preserves playability; aligns with Pillar 1). `TRY_BAK_THEN_REFUSE`: block with modal and require reinstall (use only if audit requirements prohibit ambiguous state). MVP default: `TRY_BAK_THEN_NEW`. |
| `save_slot_count` | int | 1 | 1–5 | Number of save slots. 1 for MVP (single player profile). Increase to 3–5 for V1.0 if user profiles are added. Increasing this requires corresponding UI work (slot selection screen). |
| `max_payload_size_bytes` | int | 2 097 152 | 512 KB–10 MB | If the serialized JSON payload exceeds this value, the persist is aborted and an error is logged. Guards against runaway serialization bugs filling the disk. Not expected to trigger in normal play at any realistic content scale. |
| `future_version_save_policy` | enum | `REFUSE_AND_ALERT` | `REFUSE_AND_ALERT`, `WARN_AND_LOAD` | `REFUSE_AND_ALERT`: block load with modal if save version > compiled version (safest — prevents silent schema mismatches). `WARN_AND_LOAD`: attempt best-effort load with a toast (useful during rapid iteration when multiple build versions share save files). Production default: `REFUSE_AND_ALERT`. |
| `save_age_welcome_back_threshold_seconds` | int | **5 184 000** (~60 days — Pass-5E 2026-04-21 recalibration from 15 552 000 / ~180 days per D5E-2; see §D.4 for rationale) | 0–unbounded | If `t_current - last_persist_unix_ts` exceeds this value, show a "welcome back" toast on load. Set to 0 to disable. Does not affect save validity or loading behavior. |
| `suspicious_timestamp_escalation` | enum | `WARN_ONLY` | `WARN_ONLY`, `LOCK_SAVE` | On `flag_suspicious_timestamp` from Time System: `WARN_ONLY` shows a toast and continues normally (MVP default — avoids false positives from NTP clock corrections and device restores). `LOCK_SAVE` transitions to `CORRUPT` and requires fresh start (reserve for V1.0 if post-launch telemetry shows meaningful tamper signal volume). |
| `BACKUP_ESCALATION_WINDOW_SECONDS` | int | **604 800** (7 days) | 86 400 (1 day) – 2 592 000 (30 days) | **Pass-5E 2026-04-21 — new knob.** Rolling window over which `.bak` fallback events are counted (Rule 8 backup-restore repetition escalation). Events outside this window are scrubbed from `_meta.backup_restore_events` on every persist. 7-day default chosen because a single weekend of storage thrash should not escalate; three failures across a full week reliably indicates storage-layer degradation rather than noise. |
| `BACKUP_ESCALATION_THRESHOLD` | int | **3** | 2 – 10 | **Pass-5E 2026-04-21 — new knob.** Number of `.bak` fallback events within `BACKUP_ESCALATION_WINDOW_SECONDS` above which the Rule 8 backup-restore toast is upgraded to the storage-advisory modal. 3 is the lowest count where the signal reliably separates hardware issues from single-event crashes; 2 would false-positive on a crash-then-recovery-crash pair; 4+ risks missing a genuine failing-storage case. |
| `SETTINGS_MODIFIED_LABEL_ENABLED` | compile-time `const` bool | **`false` in MVP** (Pass-5E 2026-04-21, D5E-3); becomes `true` in V1.0 alongside the first FLAGS.bit0 consequence-feature | Boolean compile-time constant | Surfaces the "Modified" label in the Settings screen for saves whose `FLAGS.bit0 == 1`. Suppressed in MVP because no consequence-feature consumes the bit yet; surfacing a soft warning without an actionable path is anti-Player-Fantasy. **Must be a compile-time `const` — NOT a ProjectSetting — for the same `user://overrides.cfg` attack surface as `integrity_check_enabled`.** The on-disk FLAGS.bit0 state is authoritative and unaffected by this knob; only the UI surface is gated. AC-SL-TAMPER-05 CI scan extended Pass-5E to grep for `SETTINGS_MODIFIED_LABEL_ENABLED = true` in production exports and fail the build until a V1.0 consequence-feature is landed. |

---

## Acceptance Criteria

All criteria use Given-When-Then format. 12 functional criteria + 4 tamper-specific criteria. All are BLOCKING except performance criteria (ADVISORY).

### AC-SL-01: Happy Path Round-Trip (Integration, BLOCKING)

**GIVEN** a live session with **all six canonical consumers** populated to a non-trivial stub state via the consumer fixture set (registered in §F — Economy, Hero Roster, Floor/Biome Unlock, Formation Assignment, Recruitment, Dungeon Run Orchestrator-until-Pass-3F lands) — specifically:
- **Economy**: `gold = 1234`, `lifetime_earned = 5678`
- **Hero Roster**: 3 heroes with distinct `hero_id`, `class_id`, `level`, `current_xp`
- **Floor Unlock**: `unlocked_floors = {"forest_reach_f1": 3, "forest_reach_f2": 1}` (Dictionary[String, int] per §C Interactions Pass-5A)
- **Formation Assignment**: one assignment `"forest_reach_f1" → [hero_id_a, hero_id_b]`
- **Recruitment**: `recruit_offers = [{class_id: "warrior", cost: 100}]`
- **Orchestrator** (until Combat Pass 3F): `active_run = null` (NO_RUN state stub; per-element `KillEvent` round-trip covered by AC-SL-13 fixture-ready)
- **Time System cross-fields**: `last_persist_unix_ts`, `t_session_high_water` both non-trivial and `t_session_high_water > last_persist_unix_ts`

and the heartbeat timer fires after 60 seconds,
**WHEN** Save/Load serializes via each consumer's `get_save_data()`, writes the binary envelope to `user://save_slot_1.dat`, then the game is restarted and `load_save_data()` is called on every consumer,
**THEN** every persisted field matches its pre-save value exactly on all six consumers (field-by-field equality asserted per consumer namespace) — including both `last_persist_unix_ts` AND `t_session_high_water` round-tripping into the Time System via `set_last_persist_ts()` + `set_session_high_water()`; HMAC passes without warning; save file size < 50 KB.

*Verification*: integration test — populate state via the consumer fixture set listed above (not inline magic numbers — fixtures live at `tests/fixtures/save_load/six_consumer_baseline.gd`), trigger heartbeat, restart, assert state equivalence on all six consumers + both Time fields. Specifically verify that `t_session_high_water > last_persist_unix_ts` survives the round-trip (this is the in-session-rewind defense per Time System AC-TICK-05b). When Combat Pass 3F lands, the Orchestrator stub is replaced with a non-null `active_run` carrying a 3-element `Array[KillEvent]` — AC-SL-13 takes over the per-element assertion; AC-SL-01 remains a whole-namespace round-trip.

### AC-SL-02: Atomic Write — No Half-Written Save Survives Interruption (Integration, BLOCKING)

**GIVEN** a persist cycle reaches the post-`store_buffer`/pre-rename window — enforced deterministically by the debug-only hook `SaveSystem.debug_pause_before_rename()` (Pass-5C 2026-04-21 — user decision D5C-3). The hook is guarded by `if OS.is_debug_build()` and emits the signal `debug_paused_before_rename` between the completion of `FileAccess.store_buffer()` (including `flush()`) and the `DirAccess.rename(tmp_path, target_path)` call. In release builds the hook compiles out; in debug builds the signal emits only when the corresponding test fixture has registered a listener via `SaveLoadFixture.arm_pause_before_rename()`. The hook is debug-only by contract — production exports MUST NOT expose it (enforced by AC-SL-TAMPER-05 CI surfacing-contract scan extended Pass-5C: grep for `debug_pause_before_rename` outside `OS.is_debug_build()` guards fails the build).

**WHEN** the subprocess test harness (`tests/integration/save_load/test_atomic_write_crash.gd`) launches a child Godot process, waits for `debug_paused_before_rename` via IPC, then issues `OS.kill(child_pid, OS.SIGKILL)` (hard kill — not a graceful shutdown — to simulate power-loss without triggering `NOTIFICATION_WM_CLOSE_REQUEST`),
**THEN** on a fresh launch against the same `user://` directory, the save loader MUST satisfy all four of: (1) `user://save_slot_1.dat` exists and is either the pre-persist `.dat` or a complete post-rename `.dat` (asserted by HMAC pass OR file-absence, not by byte content); (2) `user://save_slot_1.dat.tmp` is either absent OR present-and-ignored per Rule 6 `.tmp` cleanup invariant; (3) loaded state is internally consistent (all six consumers load or first-launch bootstrap fires per AC-SL-05); (4) no consumer observes a partial field write (asserted by AC-SL-01 field-equality semantics over whichever `.dat` survives).

*Verification*: subprocess integration test. Harness responsibilities: spawn child; register IPC listener; wait for `debug_paused_before_rename`; `OS.kill` child; spawn re-launch child; collect load result. Fixture helper: `SaveLoadFixture.arm_pause_before_rename()` returns an `AwaitableSignal` the harness awaits. Evidence: `production/qa/evidence/sl-02-[date].md` with subprocess log + pre/post filesystem listing + HMAC-pass-or-file-absence assertion trace.

### AC-SL-03: HMAC Integrity — Tampered Save Emits `tamper_detected_on_load` Signal (Logic, BLOCKING)

**GIVEN** a valid save file exists at `user://save_slot_1.dat` (seeded by AC-SL-01 baseline fixture),
**WHEN** the fixture helper `SaveLoadFixture.corrupt_byte_at_offset(path: String, offset: int, new_byte: int = -1) -> void` (Pass-5C 2026-04-21) alters a single byte at an offset within the payload region (argument ranges: `offset ∈ [12, file_size − 33]`; `new_byte` defaults to `~original_byte & 0xFF` to guarantee change) and Save/Load is invoked via `SaveSystem.load_save()`,
**THEN** the load path MUST emit the signal `SaveSystem.tamper_detected_on_load(load_result: LoadResult)` exactly once before any consumer's `load_save_data()` is called; `load_result.code == LoadResult.ERR_TAMPER_SUSPECTED`; `load_result.footer_hmac_match == false`; the SaveLoadSystem enters `TAMPER_WARN` state pending user decision (Yes/No) per HMAC Verification Behavior step 6; on Yes-branch, the synchronous atomic persist (per Pass-5B-remainder D3) sets `FLAGS.bit0 = save_is_flagged_tampered = true` and increments `_meta.tamper_suspicious_count` before the modal dismisses; the "Modified" label surface is **SUPPRESSED until V1.0 consequence-feature** (Pass-5E 2026-04-21, user decision D5E-3 — see HMAC Verification Behavior step 6 Yes-branch for the full rationale and `SETTINGS_MODIFIED_LABEL_ENABLED` compile-time-const surfacing contract in Section G).

*Verification*: GdUnit4 unit test `tests/unit/save_load/test_ac_sl_03_hmac_tamper_signal.gd`. Asserts are over the emitted signal's `LoadResult`, NOT over any modal instance (the UI modal is rendered by a separate screen and is Pass 5E copy scope — framing the AC against a signal keeps the Logic test deterministic and UI-framework-independent). Fixture: `SaveLoadFixture.corrupt_byte_at_offset()`. AC passes when signal emits once with expected `LoadResult` fields; fails if silent load OR no signal OR signal-with-wrong-code.

### AC-SL-04: Missing Content Reference — Null Resolve Returns Fallback Without Crash (Logic, BLOCKING)

**GIVEN** a save file references a content id (e.g., class id `"warrior_v1"`) that no longer exists in DataRegistry,
**WHEN** `DataRegistry.resolve("classes", "warrior_v1")` returns `null` during hydration,
**THEN** Save/Load applies the consumer-specific fallback per Section C interaction table (hero removed from roster, floor re-locked, assignment cleared); session continues loading remaining data; no GDScript exception propagates; affected field is internally flagged.

### AC-SL-05: First Launch Bootstrap (Logic, BLOCKING)

**GIVEN** no file exists at `user://save_slot_1.dat` and no `.bak` file exists, and the Time System's mock clock is armed via `TimeSystem.debug_set_unix_time(T_MOCK)` (Pass-5C 2026-04-21 — see cross-GDD request to `game-time-and-tick.md` introduced by AC-SL-TAMPER-04; `TimeSystem.debug_set_unix_time(t: int) -> void` is debug-only, guarded by `if OS.is_debug_build()`, and makes `TimeSystem.get_unix_time_now()` return `T_MOCK` for the remainder of the test scope until `debug_clear_unix_time()` resets it to `Time.get_unix_time_from_system()`),
**WHEN** the game launches for the first time,
**THEN** a new save is seeded with default subsystem states; `last_persist_unix_ts == T_MOCK` (equality assertion, not the previous `±2s` tolerance — the time mock eliminates the wall-clock-drift rationale; a non-mocked wall-clock variant is out of scope for this AC since the mock is available); `first_launch` signal emitted exactly once; initial save is written to disk before main menu is presented.

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_05_first_launch.gd`. Depends on `TickSystem.debug_set_unix_time(t)` being live in the Time System implementation — **AC UN-GATED Pass-TS-DEBUG-API 2026-04-21**: cross-GDD request landed in `game-time-and-tick.md` §Debug-Only Test Surface. The mock API signature matches this AC's expectations exactly (`debug_set_unix_time(t: int) -> void` + `debug_clear_unix_time() -> void`). AC is now writeable + execution-ready without the prior ±2s tolerance fallback.

### AC-SL-06: Backup Fallback with Full Atomic Re-Persist Promotion (Integration, BLOCKING)

**GIVEN** `user://save_slot_1.dat` has a corrupted HMAC (seeded via `SaveLoadFixture.corrupt_byte_at_offset` per AC-SL-03) and `user://save_slot_1.dat.bak` contains a valid prior save,
**WHEN** the game launches and primary load fails integrity check,
**THEN** Save/Load automatically attempts `.bak`; backup passes HMAC; all subsystem state is restored from backup by calling each consumer's `load_save_data()` on the `.bak` payload; a non-blocking info modal informs the player that backup was used; **the backup is then promoted by executing the full atomic persist path (Rule 7) — NOT a byte-copy of the `.bak` file**.

**Full-promotion semantics (Pass-5C 2026-04-21 — user decision D5C-3-adjacent):** promotion MUST execute the complete persist cycle: (1) each consumer's `get_save_data()` is re-invoked against the loaded-from-`.bak` in-memory state, producing a fresh top-level payload; (2) `last_persist_unix_ts` is updated to `TimeSystem.get_unix_time_now()` (NOT copied from the `.bak`'s stale timestamp); (3) `save_sequence_number` in `_meta` is incremented per the `_meta` sub-schema; (4) a fresh HMAC is computed with `keys[0]` (the current build's key per N-1 history per Pass-5B-remainder D1); (5) the envelope is written via the standard `.tmp → rename` path; (6) the old `.bak` is then rotated per §Atomic Write + Backup Rotation Details. A byte-copy would preserve the `.bak`'s stale `last_persist_unix_ts` and, crucially, its old HMAC key (if the build rotated between the backup's creation and now), meaning a subsequent load would hit the N-1 fallback unnecessarily and mark the save as migrated — an internal signal that does not reflect a true key rotation event.

*Verification*: integration test `tests/integration/save_load/test_ac_sl_06_bak_promotion.gd`. Post-promotion assertions: (a) `.dat` loads under `keys[0]` (current), not `keys[1]`; (b) `.dat`'s `last_persist_unix_ts == TimeSystem.debug_set_unix_time` anchor, NOT the `.bak`'s original ts; (c) `.dat`'s `save_sequence_number == bak_sequence_number + 1`; (d) in-memory state after re-load matches in-memory state after `.bak` load (field-by-field). A byte-copy implementation would fail (a) after a key rotation and fails (b)/(c) unconditionally.

### AC-SL-07: Both Corrupt — New Save with Modal (Logic, BLOCKING)

**GIVEN** both `user://save_slot_1.dat` and `user://save_slot_1.dat.bak` fail HMAC verification,
**WHEN** the game launches,
**THEN** Save/Load transitions to `CORRUPT` state; blocking modal is shown with the canonical Rule 8 step-3 copy — **Pass-5E 2026-04-21 — writer sign-off**: *"Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]"*; on `[Begin]` button press (single button by design per Rule 8 rationale — there is nothing to Cancel back to), new empty save is seeded via the first-launch-bootstrap path (AC-SL-05 semantics reused); session starts from default state; `AC-SL-07` emits `SaveSystem.corrupt_both_acknowledged` signal on button press (asserted by test as the state-transition trigger); no silent data loss.

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_07_both_corrupt.gd`. Asserts over the emitted signal + post-state (fresh save on disk with zeroed `_meta.save_sequence_number`, `last_persist_unix_ts == TimeSystem.debug_set_unix_time` anchor), NOT over modal-rendering internals (the modal is a UI surface; the AC tests the state contract). Evidence for the modal copy itself is a manual walkthrough screenshot in `production/qa/evidence/sl-07-[date].md` per Coding Standards "Visual/Feel" evidence type.

### AC-SL-08: DataRegistry ERROR State — Load Refused (Integration, BLOCKING)

**GIVEN** DataRegistry reports `state == ERROR` at session start (invariant: any state other than `READY` triggers this path; `ERROR` is the modeled failure; `LOADING`/`UNINITIALIZED` imply an autoload-rank bug per Pass 5D),
**WHEN** Save/Load is invoked,
**THEN** Save/Load refuses to deserialize; does not call `load_save_data()` on any consumer; transitions to `CORRUPT` state with content-error modal — **Pass-5E 2026-04-21 — writer sign-off**: *"Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]"*. The copy is deliberately split into two clauses: (a) names the failure domain ("Lantern Guild's world" — i.e., the content/data layer, not the player's progress), (b) provides the Player-Fantasy-anchored reassurance ("your save is safe and untouched"). The word **"untouched"** is load-bearing: it commits that the save file on disk is byte-for-byte what the player last wrote, and the reinstall will not affect it. This is a cross-system promise — the Data Loading System may have failed, but Save/Load has not. Save file is preserved (not deleted); **returns `SaveSystem.LoadResult` with `code == LoadResult.ERR_REGISTRY_UNAVAILABLE`** (Pass-5C 2026-04-21 — enum defined).

**`SaveSystem.LoadResult` enum contract (Pass-5C):**

```gdscript
class_name LoadResult
extends Resource

enum Code {
    OK,                          # Load succeeded, all consumers hydrated
    ERR_FILE_ABSENT,             # No .dat and no .bak — AC-SL-05 first-launch bootstrap path
    ERR_TAMPER_SUSPECTED,        # HMAC failed on both keys[0] and keys[1] (plus .bak attempt) — AC-SL-03 path
    ERR_REGISTRY_UNAVAILABLE,    # DataRegistry.state != READY — THIS AC's return path
    ERR_CORRUPT_BOTH,            # .dat failed HMAC, .bak also failed HMAC — AC-SL-07 path
    ERR_SCHEMA_MISMATCH,         # _meta.slot_index mismatch or forward-compat-unsupported version — AC-SL-04-adjacent
    ERR_IO,                      # FileAccess.open failed with non-absent error (permission, disk full read) — Rule 6 fallthrough
}

var code: Code
var footer_hmac_match: bool  # populated for tamper/corrupt paths
var registry_state: int      # populated for ERR_REGISTRY_UNAVAILABLE — carries DataRegistry's state enum value
var migrated_from_prior_key: bool  # true when N-1 key path was used per Pass-5B-remainder D1
```

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_08_registry_error.gd`. Arranges `DataRegistry` via dependency injection of a stub reporting `state == ERROR`; asserts returned `LoadResult.code == Code.ERR_REGISTRY_UNAVAILABLE` and `registry_state == DataRegistry.State.ERROR`. Also asserts `load_save_data()` was NOT invoked on any of the six consumers (spy mocks on each consumer's method).

### AC-SL-09: Time Rewind Escalation (Logic, BLOCKING)

**GIVEN** Time System emits the signal `flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)` (Pass-5C 2026-04-21 — `flag_suspicious_timestamp` is a **signal**, NOT a settable boolean field; previous framing treated it as an assignable flag which was incorrect — Time System detects the rewind internally and emits the signal; Save/Load connects to it in `_ready()`) triggered by a detected clock rewind > `REWIND_TOLERANCE_SECONDS = 300`, and a persist is subsequently triggered,
**WHEN** Save/Load processes the escalation under the default `suspicious_timestamp_escalation = WARN_ONLY` policy (listener method `_on_time_system_flag_suspicious_timestamp_emitted(previous_ts, current_ts)` is connected in `_ready()` and sets an in-memory `_escalation_pending` flag; the next persist drains this flag into the `_meta.tamper_suspicious_count` increment and the audit-log write),
**THEN** audit log records the event with both timestamps; `_meta.tamper_suspicious_count` increments by exactly 1 (asserted via debug helper `SaveLoadSystem.get_meta_field("tamper_suspicious_count")` per `_meta` Sub-Schema); warning toast queued for next launch; save is not locked; Time System's zeroed offline credit is the primary penalty.

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_09_time_rewind.gd`. Fixture manually invokes `TimeSystem.debug_emit_suspicious_timestamp(prev: int, curr: int)` (Pass-5C 2026-04-21 — debug-only emitter requested cross-GDD in `game-time-and-tick.md`; sibling of `debug_set_unix_time`; fires the signal without requiring an actual clock rewind). Triggers a heartbeat persist. Asserts: (a) signal reached Save/Load listener exactly once; (b) `get_meta_field("tamper_suspicious_count")` post-persist == pre-persist + 1; (c) audit log contains the event with both ts values; (d) save state is not locked (next persist succeeds normally).

### AC-SL-10: Save Replay — Backward Timestamp Detectable (Logic, BLOCKING)

**GIVEN** session A saved at timestamp T1 with `_meta.save_sequence_number = 50`, session B saved at T2 (T2 > T1) with `_meta.save_sequence_number = 120`. Both files are generated by the baseline fixture then captured as `save_a.dat` and `save_b.dat` under `user://fixtures/` before the test begins.
**WHEN** the fixture helper `SaveLoadFixture.replace_save_with(src: String, tgt: String) -> void` (Pass-5C 2026-04-21) atomically copies `save_a.dat` over `user://save_slot_1.dat` (implementation: `DirAccess.copy(src, tgt)` with error check — not `FileAccess.store_buffer` of read bytes; uses the filesystem's native copy to avoid breaking any on-disk alignment semantics) and the game loads,
**THEN** HMAC passes (save A is legitimately signed with `keys[0]`, the current build's key); `last_persist_unix_ts` is T1 < T2; offline elapsed is computed from T1; offline cap clamps gain to ≤ `offline_cap_seconds`; in-session progress between T1 and T2 is lost (documented accepted residual risk); `_meta.save_sequence_number = 50` is visible to future cloud sync for rejection (assertable via `get_meta_field("save_sequence_number")`).

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_10_replay.gd`. Baseline-fixture setup produces two distinct signed saves with known sequence numbers; `replace_save_with` is the mechanical helper. Asserts: (a) load succeeds without tamper signal; (b) `TimeSystem.get_last_persist_ts() == T1`; (c) `get_meta_field("save_sequence_number") == 50`; (d) offline credit computed ≤ `offline_cap_seconds`.

*QA note*: This is the documented residual risk. Net attacker gain is bounded by one `offline_cap_seconds` cycle; no competitive harm in a single-player premium game.

### AC-SL-11: Persist Performance (Performance, ADVISORY)

**GIVEN** a fully-populated save near the MVP 50 KB ceiling on minimum-spec hardware,
**WHEN** heartbeat persist executes the full atomic write cycle (serialize → write `.tmp` → rename → copy to `.bak`),
**THEN** total elapsed < **20 ms on PC minimum spec**, < **50 ms on mobile minimum spec**, measured from serialization start to OS-level rename completion; no main-thread stutter visible in profiler.

*Verification*: performance integration test; log p50/p95/p99 to `production/qa/evidence/sl-persist-[date].md` with device spec.

### AC-SL-12: Load Performance (Performance, ADVISORY)

**GIVEN** a valid save near the 50 KB ceiling on minimum-spec hardware,
**WHEN** full load sequence executes (HMAC verify → XOR unmask → JSON parse → all `DataRegistry.resolve()` → all `load_save_data()`),
**THEN** total elapsed < **50 ms on PC**, < **100 ms on mobile**, measured from file open to last consumer's `load_save_data()` return.

### Tamper-Specific Criteria

### AC-SL-TAMPER-01: Direct Text Edit Blocked by XOR Mask (Logic, BLOCKING)

**GIVEN** a valid save file seeded with Economy `gold = 100` via the baseline fixture,
**WHEN** the test loads the raw bytes of `user://save_slot_1.dat` into a `PackedByteArray` and performs a byte-sequence search (Pass-5C 2026-04-21 — reframed from the previous "QA opens in Notepad" manual-only phrasing, which was incompatible with a BLOCKING/Logic classification),
**THEN** all of the following MUST hold:
1. The UTF-8 encoding of `"gold"` (`0x67 0x6F 0x6C 0x64`) does NOT appear as a contiguous subsequence in the payload-region bytes `[12 .. file_size − 33]`;
2. The UTF-8 encoding of the ASCII digit sequence `"100"` (`0x31 0x30 0x30`) does NOT appear as a contiguous subsequence in the payload region;
3. The UTF-8 encoding of `"last_persist_unix_ts"` does NOT appear in the payload region;
4. Any single byte flip in the payload region (applied via `SaveLoadFixture.corrupt_byte_at_offset` from AC-SL-03) triggers AC-SL-03's `tamper_detected_on_load` signal on the next load (forwarded assertion — this AC is a byte-level precondition for the signal-level AC).

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_tamper_01_xor_masks_plaintext.gd`. **Byte-sequence search uses a scratch linear-scan helper in `SaveLoadFixture`** — `PackedByteArray.find_subsequence(needle)` does **NOT** exist in Godot 4.6 (verified Pass-5D 2026-04-21 against `class_packedbytearray.html` reference docs; only `find(value: int, from: int = 0) -> int` exists for single-byte values, and `bsearch` for sorted-array use). The scratch helper is:

```gdscript
# In tests/fixtures/save_load/save_load_fixture.gd
static func find_subsequence(haystack: PackedByteArray, needle: PackedByteArray, start: int = 0) -> int:
    if needle.is_empty():
        return start
    var h_len := haystack.size()
    var n_len := needle.size()
    if n_len > h_len - start:
        return -1
    for i in range(start, h_len - n_len + 1):
        var match := true
        for j in n_len:
            if haystack[i + j] != needle[j]:
                match = false
                break
        if match:
            return i
    return -1
```

Linear-scan complexity is `O(h*n)` worst-case; at MVP payload sizes (<20 KB) with needles of ≤20 bytes the worst case is ~400k byte comparisons — sub-millisecond even interpreted, and runs once per test. A Boyer-Moore or KMP optimization is not justified.

Assertions (1)–(3) are `assert_that(SaveLoadFixture.find_subsequence(payload_bytes, needle)).is_equal_to(-1)`. Assertion (4) is a forward-call to AC-SL-03's path. AC remains BLOCKING/Logic because every step is deterministically assertable.

### AC-SL-TAMPER-02: Hex Edit to HMAC Region Detected (Logic, BLOCKING)

**GIVEN** a valid save file with a known HMAC in the final 32 bytes (envelope footer per Rule 2),
**WHEN** the test iterates every byte offset in the range `[file_size − 32, file_size − 1]` (Pass-5C 2026-04-21 — corrected from the previous `(file_size − 16)` single-offset spec, which probed only the middle of the 32-byte footer and missed the boundary bytes; a hex-editor attacker would flip any of the 32 footer bytes, so QA assertions must cover the full range) and applies `SaveLoadFixture.corrupt_byte_at_offset(path, offset)` for each offset in turn, restoring the file between iterations,
**THEN** for every one of the 32 iterations, load emits `tamper_detected_on_load` with `LoadResult.code == ERR_TAMPER_SUSPECTED` and `footer_hmac_match == false`; save is not silently accepted; `.bak` is offered per AC-SL-06 promotion path when a valid backup exists, per AC-SL-07 `CORRUPT` path when no valid backup exists.

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_tamper_02_hmac_region.gd`. Test iterates 32 offsets. Fails if any offset fails to trigger the signal. Evidence stored under `production/qa/evidence/sl-tamper-02-[date].md` with the full 32-offset assertion trace.

### AC-SL-TAMPER-03: Save Replay Bounded by Offline Cap (Logic, BLOCKING — documents residual risk)

**GIVEN** save A at 9am (T1, sequence 50) with offline gains already claimed; save B at 5pm (T2, sequence 120) with 6 hours of foreground progress,
**WHEN** attacker overwrites save B with save A and launches,
**THEN** save A loads (HMAC valid); 6 hours of foreground progress is lost; offline elapsed = T_now − T1; gain clamped to `offline_cap_seconds = 28800` (8h max); `save_sequence_number = 50` persists for future cloud rejection detection.

*QA note*: This criterion documents that the attack is **not** cryptographically defeated but is **economically bounded**. Accepted residual risk per design.

### AC-SL-TAMPER-04: Clock Manipulation (Forward Jump + Rewind) Detected (Logic, BLOCKING)

**GIVEN** player at `t_last_persist = T` with valid save, and the Time System mock-clock API is live (**LANDED Pass-TS-DEBUG-API 2026-04-21** — cross-GDD request D5C-1 fulfilled; see `game-time-and-tick.md` §Debug-Only Test Surface for the authoritative contract):

```gdscript
# In TickSystem autoload (Game Time & Tick System GDD §Debug-Only Test Surface):
# All three methods guarded by `if OS.is_debug_build():` at method entry.
func debug_set_unix_time(t: int) -> void          # Makes the Formula D.2 wall-clock read return t
func debug_clear_unix_time() -> void              # Clears mock; restores normal wall-clock path
func debug_emit_suspicious_timestamp(prev: int, curr: int) -> void  # Fires flag_suspicious_timestamp_emitted signal without requiring clock rewind
```

**WHEN** the test harness performs a three-phase sequence using `debug_set_unix_time`: (phase 1) `debug_set_unix_time(T)`, launch, persist heartbeat to establish baseline; (phase 2) `debug_set_unix_time(T + 604_800)` (forward 1 week), launch, play 5 minutes of sim time, close app (triggers persist at future timestamp); (phase 3) `debug_set_unix_time(T + 300)` (rewound to 5 minutes after original baseline — wall-clock "reset to real time"), launch,
**THEN** on the phase-3 launch, `get_unix_time_now() < get_last_persist_ts()` by ~1 week (`604_500` seconds); Time System fires formula D.4: `elapsed_offline_seconds = 0`; Time System emits `flag_suspicious_timestamp_emitted(prev=T+604800, curr=T+300)`; Save/Load applies AC-SL-09 escalation (audit log, `_meta.tamper_suspicious_count++`, warning toast next launch); attacker's gain bounded to one `offline_cap_seconds = 28_800` from the forward-clock session.

*Verification*: GdUnit4 integration test `tests/integration/save_load/test_ac_sl_tamper_04_clock_manipulation.gd`. Three-phase harness sequence as above. Assertions: (phase 2) offline credit on phase-2-load == `offline_cap_seconds` (clamp applied); (phase 3) `flag_suspicious_timestamp_emitted` fires exactly once; `get_meta_field("tamper_suspicious_count")` == 1 after phase-3 heartbeat; warning toast queued via the toast-queue inspector. **AC UN-GATED Pass-TS-DEBUG-API 2026-04-21** — Time System shipped `debug_set_unix_time` + `debug_emit_suspicious_timestamp` + formal `flag_suspicious_timestamp_emitted(prev, curr)` signal declaration. AC is now writeable + execution-ready.

### AC-SL-TAMPER-05: Production Build Surfacing Constraints CI-Enforced (Integration, BLOCKING)

**GIVEN** a Lantern Guild production export (CI-built, non-debug) of the shipping binary,
**WHEN** the CI build-step pipeline inspects the exported PCK's compiled GDScript for the SaveLoadSystem autoload AND a smoke-test launch runs against the exported binary,
**THEN** all four of the following MUST hold or the pipeline fails the build:
1. `SaveLoadSystem.integrity_check_enabled` resolves to the compile-time `const` value `true` — NOT a `var`, NOT `@export`-marked, NOT read from a ProjectSetting key, NOT overridable by `user://overrides.cfg` (per §G `integrity_check_enabled` surfacing contract).
2. The private field backing the `save_file_path` knob (`_save_file_path` or equivalently-named `var`) defaults to literal `""` at module scope AND no source-level assignment reads from a ProjectSetting, CLI flag, environment variable, or filesystem path outside an `OS.is_debug_build()`-guarded block (per §G `save_file_path` surfacing contract).
3. The smoke-test launch reaches the main menu without hitting `get_tree().quit(1)` from the SaveLoadSystem `_ready()` runtime guards (both `integrity_check_enabled` and `save_file_path` guards).
4. **No `override.cfg` is packaged in the exported PCK** — CI scans for `user://overrides.cfg` or `res://override.cfg` entries and fails if any exist. The override mechanism MUST NOT ship in production (attack surface per Pass-5B-emergency).

*Gate*: **BLOCKING** (Pass-5B-remainder 2026-04-21 — user decision D2 this pass). Advisory gating would permit silent regressions from Pass-5B-emergency to ship — the `_ready()` runtime guards prevent *launch* on a bad build, not *regression authoring*; this AC is the CI-layer prevention that catches a re-exposure of either knob as a ProjectSetting at PR-merge time, before any export is cut.

*Verification*: CI build-step script + headless smoke-test runner. Evidence: `production/qa/evidence/sl-tamper-05-[build-hash].md` containing PCK inspection output (decompiled with `gdsdecomp` or equivalent) + smoke-test launch log + `override.cfg`-absence grep output. Implementer-level inspection is permitted during authoring, but the CI run is authoritative. Failure modes to test: (a) flip `const integrity_check_enabled := true` → `var integrity_check_enabled := true` → CI must fail on step 1; (b) add `_save_file_path = ProjectSettings.get_setting("save/path")` outside a debug guard → CI must fail on step 2; (c) add `user://overrides.cfg` to export include list → CI must fail on step 4.

### AC-SL-HMAC-01: HMAC-SHA256 RFC 4231 Test Vector Conformance (Logic, BLOCKING — gates all tamper ACs)

**GIVEN** the scratch HMAC-SHA256 implementation specified in the Anti-Tamper Specification (HMAC-SHA256 Construction subsection),
**WHEN** the implementation is invoked with each of the 7 HMAC-SHA256 test vectors specified in RFC 4231 §4.2 through §4.8 (key/message pairs with published expected tags),
**THEN** the computed tag MUST match the RFC 4231 expected tag **bit-exactly for all 7 vectors**. Truncation-only variants MAY be skipped as the project uses the full 32-byte output unconditionally.

*Gate*: **BLOCKING — gates ALL `AC-SL-TAMPER-*` ACs (TAMPER-01 through TAMPER-05).** A tamper AC passing against a buggy HMAC implementation produces false confidence: tamper detection may catch one deterministic wrong-tag pattern while missing others (e.g., an off-by-one on the block-size padding path may pass small-key vectors but fail large-key vectors). The RFC 4231 vector suite is the industry-standard conformance gate for HMAC-SHA256. This AC MUST pass before any tamper AC is marked WRITEABLE; a tamper AC that runs against a non-conformant HMAC is not valid evidence.

*Verification*: GdUnit4 unit test at `tests/unit/save_load/test_hmac_sha256_rfc4231.gd`. Table-driven — iterate all 7 RFC 4231 vectors; assert `hmac_sha256(key, msg) == expected_tag` per vector. No timing assertions (constant-time compare is out of scope for a single-player premium game). Test vectors are sourced from IETF RFC 4231 §4.2–4.8 and pinned as test constants (not fetched at runtime). If Godot's `HashingContext.HASH_SHA256` itself is buggy (vanishingly unlikely but theoretically possible), this AC would also fail — which is the correct outcome.

### AC-SL-13: Array[KillEvent] Round-Trip Field Equality (Logic, BLOCKING — `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]`)

**GIVEN** an `Array[KillEvent]` with 3 entries:
- `{enemy_id: "hollow_brute", archetype: "bruiser", tier: 1, is_boss: false, kill_tick: 40}`
- `{enemy_id: "glowmoth", archetype: "caster", tier: 1, is_boss: false, kill_tick: 80}`
- `{enemy_id: "ancient_rootking", archetype: "bruiser", tier: 3, is_boss: true, kill_tick: 170}`

**WHEN** each element is serialized via `KillEvent.to_dict()` → JSON-written → JSON-read → `KillEvent.from_dict(d)`,

**THEN** for each pair `(original, reconstructed)`: `original.equals(reconstructed) == true`; all 5 fields (`enemy_id`, `archetype`, `tier`, `is_boss`, `kill_tick`) match exactly; `reconstructed` is a new object (`reconstructed != original` by identity), confirming round-trip produces a distinct but field-equal value.

*Prerequisite*: This AC requires `KillEvent.to_dict()` and `KillEvent.from_dict()` to be defined on `KillEvent`. These methods are not yet present in Combat GDD #11 (which treats `KillEvent` as a transient object). **This AC is blocked until Combat GDD Pass 3F lands** (micro-addendum adding `to_dict()` / `from_dict()` to `KillEvent` and `HeroInstance.from_dict_static()`). See Pass 4B-SaveLoad review log for the flag record.

**`[FIXTURE-READY / EXECUTION-GATED-PASS-3F]` state (Pass-5C 2026-04-21 — user decision D5C-2 "defer"):** QA MAY author the fixture now against the assumed-stable Rule 11 contract (`KillEvent.to_dict()` returns a Dictionary with the 5 listed fields; `KillEvent.from_dict(d)` reconstructs field-equal). The fixture lives at `tests/unit/save_load/test_ac_sl_13_killevent_roundtrip.gd` with the assertion body written but an `@warning_ignore("assert_always_false")` guard of the form `assert(KillEvent.has_method("to_dict"), "Combat Pass 3F has not landed — AC-SL-13 is fixture-ready but execution-gated")` at the top of each test method. When Combat Pass 3F merges and `to_dict`/`from_dict` exist on `KillEvent`, the guard is removed in the same PR that lands 3F; no scope re-review of AC-SL-13 is needed at that point. Rationale: waiting on Combat 3F (3+ days stalled) to unblock Save/Load #3 story work is scope creep; the fixture-ready + execution-gated pattern lets QA and the story ship WRITEABLE while Combat 3F lands independently. When 3F arrives, the single guard removal un-gates all three test methods atomically.

### AC-SL-14: Resource Resolve-Failure — NO_RUN Reset Without Crash (Logic, BLOCKING)

**GIVEN** a save payload in the `"orchestrator"` namespace containing `{"active_run": {"floor_id": "forest_reach_f99", ...}}` where `"forest_reach_f99"` does not exist in `DataRegistry`,

**WHEN** the fixture invokes `orchestrator.load_save_data(data["orchestrator"])` (Pass-5C 2026-04-21 — **namespace unwrapping fix**: the fixture passes the `data["orchestrator"]` sub-dict, NOT the full top-level `data` dict; the previous framing implied the full envelope was passed to each consumer, which would require each consumer to namespace-unwrap itself, violating the Rule 3 serialization contract — Save/Load owns namespacing on write AND on read, then passes the unwrapped sub-dict to each consumer's `load_save_data`) and `RunSnapshot.from_dict` calls `DataRegistry.resolve("floors", "forest_reach_f99")`,

**THEN** `DataRegistry.resolve` returns `null`; `push_error` fires with a message containing `"floor_id"` and `"forest_reach_f99"`; `from_dict` returns `null`; the Orchestrator transitions to `NO_RUN` state; the session continues loading all other consumers normally; no GDScript exception propagates; the player is not shown an error modal (the run is simply absent).

*Verification*: GdUnit4 test `tests/unit/save_load/test_ac_sl_14_resource_resolve_failure.gd`. Fixture constructs a top-level dict with the `"orchestrator"` key pointing to the bad-floor-id sub-dict; asserts the fixture then calls `orchestrator.load_save_data(data["orchestrator"])` (sub-dict, per the unwrapping contract) — this mirrors the production Save/Load code path which performs the same unwrap step between HMAC verification and consumer hydration (see §F consumer discovery). Assertion: post-load, `orchestrator.get_state() == Orchestrator.State.NO_RUN`; all other five consumers are called with their respective sub-dicts and hydrate normally.

### Classification Summary (updated Pass-5C 2026-04-21 — AC-SL-13 marked FIXTURE-READY; all ACs gain fixture-helper references)

| ID | Description | Type | Gate |
|---|---|---|---|
| AC-SL-01 | Round-trip on heartbeat + launch | Integration | BLOCKING |
| AC-SL-02 | Atomic write survives mid-persist kill | Integration | BLOCKING |
| AC-SL-03 | HMAC tamper → warn modal + flag | Logic | BLOCKING |
| AC-SL-04 | Missing content ref → fallback, no crash | Logic | BLOCKING |
| AC-SL-05 | First launch → seed save + signal | Logic | BLOCKING |
| AC-SL-06 | Primary corrupt → `.bak` fallback | Integration | BLOCKING |
| AC-SL-07 | Both corrupt → new save + modal | Logic | BLOCKING |
| AC-SL-08 | DataRegistry ERROR → load refused | Integration | BLOCKING |
| AC-SL-09 | Clock rewind → flag + audit | Logic | BLOCKING |
| AC-SL-10 | Replay attack bounded by cap | Logic | BLOCKING |
| AC-SL-11 | Heartbeat persist within budget | Performance | ADVISORY |
| AC-SL-12 | Session-start load within budget | Performance | ADVISORY |
| AC-SL-13 | Array[KillEvent] round-trip field equality | Logic | BLOCKING — `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]` |
| AC-SL-14 | Resource resolve-failure → NO_RUN, no crash | Logic | BLOCKING |
| AC-SL-TAMPER-01 | XOR mask blocks text edit | Logic | BLOCKING |
| AC-SL-TAMPER-02 | Hex edit to HMAC detected | Logic | BLOCKING |
| AC-SL-TAMPER-03 | Replay bounded (residual risk documented) | Logic | BLOCKING |
| AC-SL-TAMPER-04 | Clock forward+rewind detected | Logic | BLOCKING |
| AC-SL-TAMPER-05 | Production build surfacing constraints CI-enforced | Integration | BLOCKING (gates Pass-5B-emergency regression) |
| AC-SL-HMAC-01 | HMAC-SHA256 RFC 4231 conformance | Logic | BLOCKING (gates all `AC-SL-TAMPER-*`) |

**QA notes**:
- AC-SL-01 requires an authoritative consumer list fixture — see Dependencies section for the list (Economy, Hero Roster, Floor/Biome Unlock, Formation Assignment, Recruitment, **Dungeon Run Orchestrator**). **Pass-5C 2026-04-21**: AC-SL-01 GIVEN now enumerates the six consumers with stub-state specifics; fixtures live at `tests/fixtures/save_load/six_consumer_baseline.gd`.
- AC-SL-10/AC-SL-TAMPER-03 depend on Time System retaining cross-session timestamp anchoring — already guaranteed by Time System GDD Rule 4 (sim clock is non-decreasing; wall clock is monotonic after clamp).
- AC-SL-11/12 require documented minimum-spec hardware profile. `production/qa/minimum-spec.md` scaffold authored Pass-5C 2026-04-21; population with actual hardware targets deferred to first pre-playtest QA cycle.
- AC-SL-13 is **`[FIXTURE-READY / EXECUTION-GATED-PASS-3F]`** (Pass-5C 2026-04-21 — user decision D5C-2): QA authors the fixture now with the execution guard `assert(KillEvent.has_method("to_dict"), ...)` at test-method entry; guard is removed in the same PR that lands Combat GDD Pass 3F. AC ships WRITEABLE; story authoring no longer blocks on Combat 3F.
- AC-SL-14 is the primary test for the resource resolve-failure contract (Rule 12 + Rule 10 error path). **Pass-5C 2026-04-21**: namespace-unwrapping fix — fixture passes `data["orchestrator"]` sub-dict to `orchestrator.load_save_data`, matching the production code path; mirrors Save/Load's own on-load unwrap step.
- **AC-SL-HMAC-01 gates all `AC-SL-TAMPER-*` ACs** (Pass-5B-remainder 2026-04-21). QA MUST confirm HMAC-01 passes before marking any TAMPER-AC as ready for execution; a tamper AC passing against a non-conformant HMAC is not valid evidence.
- **AC-SL-TAMPER-05 is a CI-layer AC** (Pass-5B-remainder 2026-04-21), not a gameplay test. Its evidence is the CI build-step output + smoke-test launch log, not a GdUnit4 assertion. Regression risk: if CI pipeline is rebuilt and this AC's build-step script is not carried forward, the Pass-5B-emergency `const`/private-`var` surfacing contract can silently regress. **Pass-5C 2026-04-21**: TAMPER-05 CI scan extended to also grep for `debug_pause_before_rename` outside `OS.is_debug_build()` guards (per AC-SL-02 hook) — failure-mode (d) in the CI script.
- **Fixture-helper surface (Pass-5C 2026-04-21)** — three named fixture APIs MUST exist in `tests/fixtures/save_load/save_load_fixture.gd` before any AC is marked ready for execution: (a) `SaveLoadFixture.corrupt_byte_at_offset(path: String, offset: int, new_byte: int = -1) -> void` (AC-SL-03, AC-SL-06, AC-SL-TAMPER-01, AC-SL-TAMPER-02); (b) `SaveLoadFixture.replace_save_with(src: String, tgt: String) -> void` (AC-SL-10); (c) `SaveLoadFixture.arm_pause_before_rename() -> AwaitableSignal` wrapping `SaveSystem.debug_pause_before_rename()` (AC-SL-02). The three helpers are the named contract for the fixture layer and MUST be reviewed by qa-lead before the first Save/Load story is marked WRITEABLE.
- **Cross-GDD Time System mock API request — LANDED Pass-TS-DEBUG-API 2026-04-21** (original Pass-5C D5C-1): AC-SL-05, AC-SL-09, AC-SL-TAMPER-04 depended on `TickSystem.debug_set_unix_time(t: int) -> void` + `TickSystem.debug_clear_unix_time() -> void` + `TickSystem.debug_emit_suspicious_timestamp(prev: int, curr: int) -> void` shipping in the Time System GDD (all three debug-only, guarded by `if OS.is_debug_build()`). Cross-GDD request issued to `game-time-and-tick.md` via Pass-5C review log entry; **fulfilled Pass-TS-DEBUG-API 2026-04-21** — see `game-time-and-tick.md` §Debug-Only Test Surface for the authoritative contract. All three dependent ACs are now un-gated + execution-ready. The `flag_suspicious_timestamp_emitted(prev, curr)` signal was formalized in the same pass to reconcile AC-SL-09's Pass-5C signal-framing correction with the Time System's prior bool-field framing.
- **`SaveSystem.LoadResult` enum (Pass-5C 2026-04-21)** — 7-code enum defined in AC-SL-08. All load paths MUST return a `LoadResult` instance; implementation-level contract is ground truth for GdUnit4 assertability across AC-SL-03, 06, 07, 08, TAMPER-02, and any future tamper AC. Implementer must NOT add codes without a Rule 4 version bump (enum is part of the public test surface).

---

## Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| ~~Godot 4.4 `FileAccess` return type changes — verify exact API signatures for `DirAccess.rename()`, `FileAccess.open()` error paths~~ | ~~godot-gdscript-specialist~~ | **RESOLVED Pass-5D 2026-04-21.** `FileAccess.store_buffer() -> bool`, `FileAccess.flush() -> void`, `DirAccess.rename() -> Error` — verified against Godot 4.6 reference docs. See Rule 7 for the full pattern; `flush() -> void` caveat in Edge Cases. |
| ~~**Empirical autoload probe execution — Save/Load implementation-story prerequisite.** `tests/probes/godot_autoload_probe.gd` must run in a scratch Godot 4.6 project; `autoload.md` Claim 1 must promote `[CONVERGED] → [VERIFIED]` before any Save/Load story is marked ready-to-execute. Blocks §C.3 rank-2 assignment + signal-connection assumption.~~ **RESOLVED 2026-04-21** — probe executed on Godot 4.6.1.stable.mono.official (Apple M2 Max, Metal). Claim 1 promoted `[CONVERGED] → [VERIFIED]`. All four sub-assertions passed: both autoloads' `_ready()` fired at the same `tree_time=648` ms; rank-2 successfully connected to rank-1's signal in its own `_ready()`; bare-identifier autoload resolution works; deferred signal emission reached the listener. See `docs/engine-reference/godot/modules/autoload.md` Claim 1 Empirical-results block for full stdout trace + Change log Pass-PROBE-EXECUTED entry. **Save/Load implementation stories are now un-gated and ready for `/create-epics` + `/create-stories` authoring.** | godot-specialist + main session | ✅ Resolved 2026-04-21 |
| iOS/Android atomic rename fallback — implement and test the `.commit` marker pattern on both platforms; document any filesystem-specific edge cases. | engine-programmer | Before mobile port work |
| **iOS shutdown-notification probe — `NOTIFICATION_WM_CLOSE_REQUEST` vs `NOTIFICATION_APPLICATION_PAUSED` empirical behavior on real iOS device.** Rule 5 currently documents the inferred behavior as [UNVERIFIED]. Result goes into a new or extended platform-notifications reference doc. Added Pass-5D 2026-04-21. | engine-programmer | Before mobile port work |
| HMAC performance on mobile — SHA-256 in GDScript may not meet the 50ms persist budget for large payloads. Benchmark at V1.0 scale; consider GDExtension wrapper of native crypto if needed. | performance-analyst | Before V1.0 payload size grows beyond ~100 KB |
| Achievement-lock-on-tamper policy — MVP has no Steam achievements, so deferred. If achievements ship V1.0, should flagged-tampered saves block achievement unlocks? | live-ops-designer | During V1.0 achievement system design |
| Cloud save implementation — V1.0+. The `save_sequence_number` field is already in the payload as prep. Conflict resolution UX, multi-device orchestration, cloud-authority model all owned by a dedicated cloud-save GDD. | systems-designer + ux-designer | Post-MVP |
| `tamper_suspicious_count` telemetry — do we ship an opt-in analytics channel to aggregate this across players? The count is stored locally; aggregation would inform post-launch anti-tamper tuning. | analytics-engineer | Post-launch |
| Multi-slot save UI (V1.0) — `save_slot_count` knob supports 1-5, but slot selection UI is not designed. Touches onboarding flow. | ux-designer | During V1.0 scope planning |
