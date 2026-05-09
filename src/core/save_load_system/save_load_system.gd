extends Node

## SaveLoadSystem — rank-2 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton". The autoload is globally
## accessible as `SaveLoadSystem`; tests that need a fresh instance use
## `preload("res://src/core/save_load_system/save_load_system.gd").new()`.
##
## Owns the save/load lifecycle for Lantern Guild: persist orchestration,
## consumer hydration loop, tamper detection, and the 6-state machine.
## Skeleton: signal declarations, state machine, and public API stubs only.
## Bodies are filled in by neighbouring stories (002–013).
##
## ADR-0003: Autoload Rank Table (rank 2; zero-arg _init — Amendment #3;
##           CONSUMER_PATHS contract — Amendment #2)
## ADR-0004: Envelope owner, consumer contract (persist/hydrate loop bodies in Story 007)
## ADR-0007: Signal subscription wiring at _ready() (rank-N may subscribe at _ready time)
##
## ---------------------------------------------------------------------------
## SPRINT 4 DEVIATION NOTES (story-001-autoload-skeleton-and-state-machine.md)
## ---------------------------------------------------------------------------
## DEV-1 (TimeSystem → TickSystem):
##   The story spec references "TimeSystem.flag_suspicious_timestamp_emitted".
##   Sprint 1's actual autoload is registered as `TickSystem` in project.godot.
##   All references use TickSystem — the live autoload identifier.
##
## DEV-2 (Defensive SceneManager wiring):
##   The story expects `SceneManager.scene_boundary_persist` to be connected at
##   _ready(). SceneManager is not yet implemented (scene-manager Foundation epic,
##   0/10 stories). The story's own consumer-resolution pattern (per-call nil-check)
##   is extended to this boot-time signal wiring: get_node_or_null + nil-check +
##   push_warning on miss. This is NOT a departure from the story's intent — it
##   applies the story's defensive contract to a dependency that lands later.
##   TickSystem (rank 0) MUST be present; its absence is a fatal architecture
##   violation (push_error). SceneManager absence is expected and warned only.
## ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## MAGIC bytes identifying a Lantern Guild save file ("LGLD" as ASCII).
## Written at bytes [0..4) of every envelope header.
##
## Declared as [code]static var[/code] (not [code]const[/code]) because GDScript
## does not allow [code]PackedByteArray(...)[/code] constructor calls in constant
## expressions. [code]static var[/code] is the closest equivalent — allocated once
## per class, shared across all instances, and never mutated.
##
## ADR-0004 §Envelope byte layout, TR-save-load-002
static var _MAGIC: PackedByteArray = PackedByteArray([0x4C, 0x47, 0x4C, 0x44])

## SHA-256 block size in bytes per FIPS 180-4 §1 and RFC 2104 §2.
## Used by [method _integrity_wrap] to determine whether the supplied authentication
## tag material must be pre-hashed (length > 64) or zero-padded (length < 64).
## This is a structural constant of the SHA-256 algorithm — do NOT change it.
##
## ADR-0004 §HMAC scheme, RFC 2104 §2, RFC 4231 §2
const _BLOCK_SIZE_SHA256: int = 64

## Byte length of the fixed envelope header: MAGIC(4) + VERSION(2) + FLAGS(2) + PAYLOAD_LENGTH(4).
## ADR-0004 §Envelope byte layout
const _HEADER_SIZE: int = 12

## Byte length of the HMAC-SHA256 footer appended after the payload.
## Zeros in this story; Story 004 overwrites with the computed tag.
## ADR-0004 §Envelope byte layout, TR-save-load-002
const _HMAC_SIZE: int = 32

## Total byte overhead of a save envelope: header (12) + HMAC footer (32).
## Every valid save file is exactly _ENVELOPE_OVERHEAD + PAYLOAD_LENGTH bytes.
## ADR-0004 §Envelope byte layout, TR-save-load-024
const _ENVELOPE_OVERHEAD: int = _HEADER_SIZE + _HMAC_SIZE  # 44

## Schema version embedded in every envelope header (VERSION field, u16 LE).
## Increment when save schema changes requiring a migration path.
## ADR-0004 §Envelope byte layout, TR-save-load-003
const CURRENT_SAVE_VERSION: int = 1

## Story 013 — backup-restore escalation threshold (TR-save-load-017).
##
## When the count of `_meta.backup_restore_events` entries within
## [constant BACKUP_ESCALATION_WINDOW_SECONDS] reaches this threshold, the UI
## should surface a storage-advisory modal with a [Check Storage] button
## INSTEAD of the normal cozy `.bak`-recovered toast. Repeated `.bak` falls
## within a week strongly imply hardware/storage trouble worth nudging the
## player about.
##
## ADR-0004 §`.bak` fallback escalation, GDD §HMAC Verification Behavior.
const BACKUP_ESCALATION_THRESHOLD: int = 3

## Story 013 — backup-restore escalation rolling window (7 days, in seconds).
##
## Entries in `_meta.backup_restore_events` older than this window from the
## current persist's `now_unix` are scrubbed before the threshold check; only
## the within-window count matters for [constant BACKUP_ESCALATION_THRESHOLD]
## comparison. The 7-day choice mirrors the GDD edge-case for distinguishing
## one-off corruption (likely a single-event glitch — cozy toast suffices)
## from sustained corruption (likely failing storage — escalate UI urgency).
##
## ADR-0004 §`.bak` fallback escalation, GDD §HMAC Verification Behavior.
const BACKUP_ESCALATION_WINDOW_SECONDS: int = 604_800  # 7 days × 86_400

## Story 013 — MVP feature flag for the in-game "Modified" label suppression
## (TR-save-load-026).
##
## When `false` (MVP default), the on-disk FLAGS.bit0 = 1 tamper indicator is
## still persisted by [method acknowledge_tamper_modal_yes], but the UI
## surface that would label a save as "Modified" is suppressed. V1.0 is
## expected to flip this to `true` and surface the consequence-feature label
## per the writer-signed-off copy in GDD Rule 8. Compile-time `const` rather
## than a runtime knob so dead-code-elimination can strip the V1.0 label
## machinery from MVP shipping bytes.
##
## ADR-0004 §Tamper Response — GDD §HMAC Verification Behavior, TR-save-load-026.
const SETTINGS_MODIFIED_LABEL_ENABLED: bool = false

## Story 013 — saturation cap for the persistent `_meta.tamper_suspicious_count`
## counter (TR-save-load-025).
##
## ADR-0004 §`_meta` field schema mandates this saturation to prevent a
## malicious user from triggering arbitrarily-large counter values via repeated
## clock manipulation or modal-Yes dismissals. Once at the cap, additional
## increments are silently no-ops; the field still persists.
##
## ADR-0004 §`_meta` field schema, TR-save-load-025.
const MAX_TAMPER_SUSPICIOUS_COUNT: int = 10_000

## Ordered list of consumer autoload paths per ADR-0003 Amendment #2 and
## ADR-0004 §Consumer Contract. Exactly 6 entries in rank order.
##
## FORBIDDEN: reordering, adding, or removing entries without a lockstep
## GDD + project.godot + test edit. Tests assert the exact 6-entry order.
##
## ADR-0003 Amendment #2, ADR-0004 §Consumer Contract
const CONSUMER_PATHS: PackedStringArray = [
	"/root/Economy",
	"/root/HeroRoster",
	"/root/FloorUnlock",
	"/root/FormationAssignment",
	"/root/Recruitment",
	"/root/DungeonRunOrchestrator",
	"/root/AudioRouter",  # S11-S3: registered post-Story-007a for AC-AS-09 round-trip
]

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Save/load lifecycle state machine — exactly 6 values per TR-save-load-045.
##
## Allowed transitions (enforced by [method _transition_to]):
##   UNLOADED    → LOADING       (entry in load pipeline)
##   LOADING     → READY         (load pipeline succeeds)
##   LOADING     → CORRUPT       (both slots unreadable / tampered)
##   LOADING     → MIGRATION     (schema version mismatch detected mid-pipeline; Story 010)
##   READY       → PERSISTING    (persist trigger: heartbeat, scene-boundary, graceful-exit)
##   PERSISTING  → READY         (persist completes successfully)
##   PERSISTING  → PERSISTING    (overlap coalesce — drops new trigger + push_warning)
##   CORRUPT     is terminal (no exit transition in MVP)
##   MIGRATION   → READY         (migration chain succeeded; consumers hydrated from migrated payload)
##   MIGRATION   → CORRUPT       (migration chain returned null; no migration authored for this version step)
##
## ADR-0003 Amendment #2, TR-save-load-045, Story 010 (schema migration)
enum State {
	## Initial state before the load pipeline fires. No save data is available.
	UNLOADED,
	## Load pipeline is actively reading and validating the save envelope.
	LOADING,
	## Load pipeline succeeded. Save data is hydrated; consumers are live.
	READY,
	## A persist operation (heartbeat, scene-boundary, or graceful-exit) is in-flight.
	PERSISTING,
	## Both save slots are unreadable or tampered. Terminal in MVP scope.
	CORRUPT,
	## A schema-version mismatch was detected; migration is in progress.
	MIGRATION,
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a persist operation completes successfully.
##
## [param reason]: Human-readable label for the persist trigger
## ("heartbeat", "scene_boundary", "graceful_exit", etc.).
##
## ADR-0004 §Signals — TR-save-load-031
signal save_completed(reason: String)

## Emitted when a persist operation fails.
##
## [param reason]: Human-readable description of the failure.
## [param error_code]: [enum Error] value from the failing I/O or validation call.
##
## ADR-0004 §Signals — TR-save-load-031
signal save_failed(reason: String, error_code: int)

## Emitted when a load operation completes successfully — i.e., consumers have
## been hydrated and [member _state] has reached READY (either via the cold-
## start [signal first_launch] path or via a successful envelope hydrate).
##
## [param reason]: Human-readable label for the load trigger
## ("boot", "manual", "post_corrupt_acknowledge", etc.). Symmetric with
## [signal save_completed].
##
## Sprint 11 Story 007b — load body. Declared alongside the existing
## save_completed for symmetry; integration tests use this to await load
## completion in round-trip fixtures.
##
## ADR-0004 §Signals — TR-save-load-031
signal load_completed(reason: String)

## Emitted when a load operation fails fatally (CORRUPT state reached, or the
## envelope is unrecoverable after [signal tamper_detected_on_load] +
## [signal corrupt_both_acknowledged] handling).
##
## [param reason]: Human-readable description of the failure.
## [param error_code]: [enum Error] value from the failing I/O or validation
##   call. ERR_FILE_CORRUPT on MAGIC/VERSION/HMAC failure; ERR_FILE_CANT_OPEN
##   on file I/O error.
##
## Symmetric with [signal save_failed]. Note: cold-start (no save file) is
## NOT a load failure — it emits [signal first_launch] + [signal load_completed]
## with reason="first_launch_cold_start" and the state advances to READY.
##
## ADR-0004 §Signals — TR-save-load-031
signal load_failed(reason: String, error_code: int)

## Emitted when the load pipeline detects a suspicious timestamp on the save
## envelope (forwarded from [signal TickSystem.flag_suspicious_timestamp_emitted]).
##
## Body wired in Story 013 (tamper-detection). Declaration lives here so
## downstream systems can connect in advance.
##
## TR-save-load-032, ADR-0007
signal tamper_detected_on_load()

## Emitted the first time the load pipeline determines no save file exists
## (cold start / first launch). Consumers use this to apply tutorial defaults.
##
## Body emitted in Story 007 hydration path. Declaration lives here.
##
## TR-save-load-032
signal first_launch()

## Emitted when the load pipeline determines both save slots are corrupt and
## the player has been informed. Consumers reset to factory defaults.
##
## Body emitted in Story 007 corrupt-both recovery path. Declaration lives here.
##
## TR-save-load-032
@warning_ignore("unused_signal")
signal corrupt_both_acknowledged()

## Story 013 Phase 2 — emitted when the `.bak` fallback path recovers a valid
## envelope after the primary `.dat` fails HMAC verification (TR-save-load-017).
##
## The UI layer connects this signal to surface a cozy "Save recovered from
## backup" toast notification. This signal is mutually exclusive with
## [signal storage_advisory_modal_required]: SaveLoadSystem emits exactly ONE
## of the two per `.bak` recovery, gated on the within-window event count vs.
## [constant BACKUP_ESCALATION_THRESHOLD].
##
## [param event_count]: Number of backup-restore events recorded within the
##   rolling [constant BACKUP_ESCALATION_WINDOW_SECONDS] window (including
##   this event).
##
## Example:
##   SaveLoadSystem.bak_recovered_toast.connect(func(n): _show_backup_toast(n))
##
## ADR-0004 §`.bak` fallback escalation, TR-save-load-017, Story 013 Phase 2.
signal bak_recovered_toast(event_count: int)

## Story 013 Phase 2B — emitted when the `.bak` fallback fires AND the within-
## window event count reaches [constant BACKUP_ESCALATION_THRESHOLD] (3) within
## [constant BACKUP_ESCALATION_WINDOW_SECONDS] (7 days). The UI should show a
## storage-advisory modal with a [Check Storage] button INSTEAD of the cozy
## [signal bak_recovered_toast]. Mutually exclusive with [signal bak_recovered_toast].
##
## [param event_count]: Number of backup-restore events recorded within the
##   rolling window (including this event). Always >= [constant BACKUP_ESCALATION_THRESHOLD]
##   when this signal fires.
##
## TR-save-load-017, ADR-0004 §`.bak` fallback escalation, Story 013 Phase 2B.
signal storage_advisory_modal_required(event_count: int)

## Story 013 Phase 2B — emitted when both `.dat` and `.bak` fail HMAC
## verification on the same load (AC-SL-07 Both-Corrupt path).
##
## The UI shows a single-button modal with the writer-signed-off Pass-5E copy:
## "Your save couldn't be recovered. A new adventure begins — your guild will
## grow again. [Begin]". On [Begin] tap, the UI calls
## [method acknowledge_corrupt_both_begin] which transitions the system back
## to UNLOADED, runs the first-launch bootstrap path, and emits
## [signal corrupt_both_acknowledged] so consumers know to reset to factory
## defaults.
##
## This signal is distinct from [signal load_failed] (which fires on any
## CORRUPT transition) and from [signal tamper_detected_on_load] (which fires
## on the `.dat` HMAC fail BEFORE the `.bak` attempt). Both also fire on the
## both-corrupt path, but a UI listener should subscribe specifically to this
## signal to gate the modal display.
##
## TR-save-load-017, AC-SL-07, ADR-0004 §Both-Corrupt response, Story 013 Phase 2B.
signal corrupt_both_modal_required()

## Story 013 Phase 2B — emitted at first [method request_full_load] when
## [member DataRegistry.state] is [code]ERROR[/code] (AC-SL-08).
##
## The UI shows the writer-signed-off "Something went wrong loading Lantern
## Guild's world. Please reinstall the app — your save is safe and untouched.
## [OK]" modal. NO filesystem writes occur on this path (the save file is
## preserved bit-identical), and [signal tamper_detected_on_load] is NOT
## emitted (the failure is content-load, not envelope-tamper).
##
## TR-save-load-032, AC-SL-08, ADR-0004 §DataRegistry ERROR coexistence,
## Story 013 Phase 2B.
signal data_registry_error_modal_required()

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Current lifecycle state. Written only by [method _transition_to].
## External callers read via get_state(); direct writes from outside are FORBIDDEN.
## ADR-0003 Amendment #2, TR-save-load-045
var _state: State = State.UNLOADED

## Flag set to [code]true[/code] after a successful load verified under the
## prior-build integrity tag (tags[1]). Signals that the save must be immediately
## re-persisted under the current-build tag (tags[0]) to maintain N=2 rotation.
##
## Contract:
## - Defaults to [code]false[/code] on every fresh instance.
## - Set to [code]true[/code] in the load pipeline when tags[1] succeeds
##   (Story 006 wires this — this story declares the field and default only).
## - Cleared to [code]false[/code] on the next successful full persist
##   (Story 007 / Story 008 clear this after the atomic write completes).
## - If the re-persist fails (e.g. disk-full), remains [code]true[/code] so
##   the retry fires on the next heartbeat; the original tags[1]-signed save
##   remains valid for the next launch.
##
## ADR-0004 §N=2 rotation, TR-save-load-021
var _needs_rekey_persist: bool = false

## Story 013 — in-memory tamper-suspicious counter (TR-save-load-025).
##
## Increments synchronously on:
##   - [signal TickSystem.flag_suspicious_timestamp_emitted] handler
##     ([method _on_flag_suspicious_timestamp_emitted]).
##   - [method acknowledge_tamper_modal_yes] (called by the UI layer when the
##     player taps "Yes" on the HMAC tamper modal).
## Saturates at [constant MAX_TAMPER_SUSPICIOUS_COUNT] per ADR-0004 (post-cap
## increments are silent no-ops so a malicious actor cannot run the counter
## up arbitrarily).
##
## This counter is currently SESSION-SCOPED — the persist pipeline does NOT
## yet wire it into the on-disk `_meta.tamper_suspicious_count` field. The
## `_meta` namespace persistence is a follow-up scope (existing story-009
## audit-cascade closure flagged that `_meta` isn't actually composed into the
## persist root_dict despite the system-level Status). When that wiring lands,
## this field becomes the in-memory mirror that gets serialized + restored on
## load. Until then, the field starts at 0 every cold launch.
##
## TR-save-load-025, ADR-0004 §`_meta` field schema, Story 013 Phase 1.
var _tamper_suspicious_count: int = 0

## Story 013 — pending FLAGS.bit0 = 1 marker (TR-save-load-026).
##
## When `true`, the next [method request_full_persist] writes the envelope
## header's FLAGS field with bit 0 set, marking the save as
## previously-tampered. Set synchronously by [method acknowledge_tamper_modal_yes]
## BEFORE the modal dismisses (per AC: synchronous persist completes before
## modal dismiss). Once the next persist completes, the on-disk envelope
## carries the bit and this field is cleared back to false.
##
## The on-disk bit persists across launches (FLAGS lives inside the
## HMAC-protected region). [constant SETTINGS_MODIFIED_LABEL_ENABLED] gates
## whether the UI surfaces the "Modified" label; the bit itself is always
## written regardless of the label feature flag.
##
## Wired into the envelope header composition path in a follow-up slice;
## currently this field tracks the intent without yet flipping the on-disk
## bit. Tests assert state transitions on this field directly.
##
## TR-save-load-026, ADR-0004 §Tamper Response, Story 013 Phase 1.
var _pending_flags_bit0_tamper: bool = false

## Story 013 Phase 2 — save-slot index persisted in `_meta` (TR-save-load-018).
##
## Tracks which logical slot this save envelope belongs to. V1.0 ships with a
## single slot (index = 0). The field is persisted so slot-aware UI (future
## multi-slot scope) can verify the loaded file belongs to the expected slot.
##
## Set at persist time via [method _compose_meta_dict] and restored at load
## time via [method _hydrate_meta_dict]. Defaults to 0 (single-slot MVP).
##
## ADR-0004 §`_meta` field schema, TR-save-load-018, Story 013 Phase 2.
var _meta_slot_index: int = 0

## Story 013 Phase 2 — monotonic save-sequence counter persisted in `_meta`
## (TR-save-load-019).
##
## Incremented on every successful [method request_full_persist] call so
## the offline-progression math can detect out-of-order replay attacks
## (a replayed older save would have a lower sequence number than the
## in-memory value at load time). The counter starts at 0, is incremented
## BEFORE the compose step, and is persisted in `_meta.save_sequence_number`.
##
## Set at persist time via [method _compose_meta_dict] and restored at load
## time via [method _hydrate_meta_dict].
##
## ADR-0004 §`_meta` field schema, TR-save-load-019, Story 013 Phase 2.
var _meta_save_sequence_number: int = 0

## Story 013 Phase 2 — rolling log of backup-restore events (TR-save-load-017).
##
## Each entry is a Unix-second timestamp of a `.bak`-fallback recovery event.
## At every persist, entries older than
## ([code]now_unix - BACKUP_ESCALATION_WINDOW_SECONDS[/code]) are pruned so
## the array never grows unboundedly. The within-window count is compared to
## [constant BACKUP_ESCALATION_THRESHOLD] to decide toast vs. storage-advisory
## escalation on the next `.bak` recovery.
##
## Set at persist time via [method _compose_meta_dict] and restored at load
## time via [method _hydrate_meta_dict]. Starts empty (no prior events).
##
## ADR-0004 §`.bak` fallback escalation, TR-save-load-017, Story 013 Phase 2.
var _meta_backup_restore_events: Array[int] = []


# ---------------------------------------------------------------------------
# Tuning knobs (designer / test-fixture configurable)
# ---------------------------------------------------------------------------

## Path to the save-slot file. Defaults to the canonical V1.0 single-slot path.
## TEST-OVERRIDE: tests may write through this field to redirect persist to a
## per-test fixture path. Production must not touch it (production sets the
## path via the const default).
##
## ADR-0004 §Tuning Knobs (Pass-5A — `save_file_path`); ADR-0004 §Forbidden
## Patterns: surfacing as a ProjectSettings setting is FORBIDDEN per the
## production-build-guard rule (override.cfg attack vector).
##
## Sprint 11 Story 007a: this knob lands so request_full_persist can target
## test-isolated paths without modifying production path semantics.
@export var save_file_path: String = "user://save_slot_1.dat"

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3.
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on _init would silently fail instantiation.
## Do NOT read or subscribe to other autoloads here — use _ready() instead.
func _init() -> void:
	pass


## Establishes signal subscriptions and reads DataRegistry state at boot.
##
## Rank-2 safety (ADR-0003 Amendment #1): TickSystem (rank 0) and DataRegistry
## (rank 1) have completed their _ready() calls by the time SaveLoadSystem's
## _ready() fires, so signal subscriptions and DataRegistry.state reads here
## are safe.
##
## TickSystem (rank 0) MUST be present — its absence is a fatal architecture
## violation per ADR-0003 rank contract. SceneManager is NOT yet implemented
## (scene-manager Foundation epic, 0/10 stories); its connection is deferred
## with a push_warning (DEV-2 deviation note in file header).
##
## ADR-0003 Amendment #1, ADR-0007 §Signal wiring at _ready()
func _ready() -> void:
	# --- TickSystem connection (rank 0; fatal if missing per ADR-0003) ---
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	if tick_system != null:
		tick_system.flag_suspicious_timestamp_emitted.connect(
			_on_flag_suspicious_timestamp_emitted
		)
	else:
		push_error(
			"SaveLoadSystem._ready: TickSystem missing at /root/TickSystem — " +
			"fatal architecture violation per ADR-0003 rank contract. " +
			"Note: in test fixtures, do NOT add SaveLoadSystem to the scene tree " +
			"unless TickSystem is also present."
		)
		# Note: production fatal handled by S4-M4+ story logic.
		# In test fixtures: instantiate via preload-and-new (not add_to_scene_tree)
		# to avoid triggering this error path. Tests verify behavior on a standalone
		# instance without requiring the full autoload stack.

	# --- SceneManager connection — DEFENSIVE (test-fixture safety net) ---
	# SceneManager is implemented + registered as autoload in production
	# (project.godot rank table). The null-check guards test fixtures that
	# instantiate SaveLoadSystem standalone without the full autoload stack;
	# in production this branch is unreachable. ADR-0007.
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.scene_boundary_persist.connect(_on_scene_boundary_persist)
	else:
		push_warning(
			"SaveLoadSystem._ready: SceneManager not present at /root/SceneManager. " +
			"scene_boundary_persist wiring skipped (test-fixture path; production " +
			"always has SceneManager at the canonical autoload path)."
		)

	# --- DataRegistry state check (rank 1 < 2; its _ready has fired) ---
	# DataRegistry.state is public (see data_registry.gd) and safe to read here.
	# ADR-0003 Amendment #1
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"SaveLoadSystem._ready: DataRegistry not READY (state=%d). " % DataRegistry.state +
			"Save/load operations will defer until DataRegistry is ready."
		)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the current lifecycle state.
##
## External callers read this to gate save/load operations.
## Direct reads of [member _state] from outside this script are FORBIDDEN
## (ADR-0003 Amendment #2 encapsulation contract).
##
## Example:
##   if SaveLoadSystem.get_state() == SaveLoadSystem.State.READY:
##       SaveLoadSystem.request_full_persist("manual")
##
## ADR-0003 Amendment #2, TR-save-load-045
func get_state() -> State:
	return _state


## Requests a full-envelope persist for all registered consumers.
##
## If a persist is already in-flight ([member _state] == PERSISTING), the new
## trigger is coalesced (dropped) and a [method push_warning] is emitted
## (TR-save-load-046 PERSISTING→PERSISTING coalesce contract).
##
## STUB — persist body lands in Story 007 (consumer loop) + Story 008 (atomic write).
##
## [param reason]: Human-readable label for the persist trigger
##   ("heartbeat", "scene_boundary", "graceful_exit", "manual", etc.).
##   Propagated verbatim to [signal save_completed] and [signal save_failed].
##
## Example:
##   SaveLoadSystem.request_full_persist("graceful_exit")
##
## ADR-0004 §Persist trigger contract, TR-save-load-046
func request_full_persist(reason: String) -> void:
	if _state == State.PERSISTING:
		push_warning(
			"SaveLoadSystem.request_full_persist: persist already in-flight " +
			"(reason='%s') — new trigger coalesced (TR-save-load-046)." % reason
		)
		return
	# Guard: persist is only valid from READY. Per Save/Load GDD state-machine
	# transition table, READY → PERSISTING is the only legal entry into this
	# code path. _transition_to(PERSISTING) below would push_warning + no-op
	# silently from any other state — making the rest of this body a state-
	# inconsistent ghost write. Explicit guard prevents that.
	if _state != State.READY:
		push_warning(
			"SaveLoadSystem.request_full_persist: state=%d not READY — " % _state +
			"persist trigger ignored (reason='%s'). Save data must be loaded " % reason +
			"before persistence can fire."
		)
		save_failed.emit(reason, ERR_UNAVAILABLE)
		return

	# Story 013 Phase 2 — full persist body. Wires _meta namespace persistence
	# (slot_index, save_sequence_number, backup_restore_events), FLAGS.bit0
	# tamper flag, and .bak rotation (pre-copy .dat → .bak before rename).

	_transition_to(State.PERSISTING)

	# 0. Advance the monotonic save-sequence counter BEFORE composing the
	#    envelope. This ensures the on-disk value is always > the prior one
	#    (TR-save-load-019 replay-detection). Saturates at int max (unlikely
	#    in practice; a typical player persists ~4 times/hour × ~1000 hours
	#    = ~4 000 000 saves, well below GDScript's 2^63 − 1).
	_meta_save_sequence_number += 1

	# 1. Iterate CONSUMER_PATHS, namespace each consumer's payload under the
	#    node's name. Per Save/Load GDD: consumer-discovery is hardcoded
	#    (CONSUMER_PATHS) — production must not duck-type new consumers in.
	var root_dict: Dictionary = {}
	for path: String in CONSUMER_PATHS:
		var node: Node = _resolve_consumer(path)
		if node == null:
			# _resolve_consumer already called push_error + get_tree().quit(1).
			# Restore READY state so a subsequent test or recovery attempt is
			# not blocked, and emit save_failed for any subscriber that needs
			# to react to the abort.
			_transition_to(State.READY)
			save_failed.emit(reason, ERR_DOES_NOT_EXIST)
			return
		if not node.has_method("get_save_data"):
			push_error(
				"SaveLoadSystem.request_full_persist: %s has no get_save_data — " % path +
				"fatal architecture violation per ADR-0004 §Consumer Contract."
			)
			_transition_to(State.READY)
			save_failed.emit(reason, ERR_METHOD_NOT_FOUND)
			return
		var consumer_dict: Variant = node.call("get_save_data")
		if not (consumer_dict is Dictionary):
			push_error(
				"SaveLoadSystem.request_full_persist: %s.get_save_data did not return " % path +
				"a Dictionary (got %s). Skipping persist." % typeof(consumer_dict)
			)
			_transition_to(State.READY)
			save_failed.emit(reason, ERR_INVALID_DATA)
			return
		# Namespace under the node's name (e.g., "Economy", "HeroRoster"). This
		# matches the Save/Load GDD canonical contract: the top-level dict has
		# one key per consumer, named after the autoload, value = consumer's
		# get_save_data() return.
		root_dict[node.name] = consumer_dict

	# 1b. Story 013 Phase 2 — compose `_meta` sub-dict into root_dict.
	#     The unix timestamp is sourced from TickSystem's cache (same single-call-site
	#     invariant as the last_persist_ts path below). Falls back to 0 if TickSystem
	#     is absent (test environments that boot SaveLoadSystem alone).
	var now_unix: int = 0
	var tick_sys_early: Node = get_node_or_null("/root/TickSystem")
	if tick_sys_early != null and tick_sys_early.has_method("now_ms"):
		var now_ms_val: int = int(tick_sys_early.now_ms())
		if now_ms_val > 0:
			@warning_ignore("integer_division")
			now_unix = now_ms_val / 1000
	root_dict["_meta"] = _compose_meta_dict(now_unix)

	# 2. Encode the assembled dict to UTF-8 JSON bytes.
	var json_string: String = JSON.stringify(root_dict)
	var plaintext: PackedByteArray = json_string.to_utf8_buffer()

	# 3. Apply XOR mask per ADR-0004 §XOR mask layer (obfuscation, not encryption).
	var mask_seed: PackedByteArray = _derive_mask_seed(CURRENT_SAVE_VERSION)
	var mask: PackedByteArray = _generate_mask(mask_seed, plaintext.size())
	var masked_payload: PackedByteArray = _apply_xor_mask(plaintext, mask)

	# 4. Compose envelope (header + masked_payload + zero-padded HMAC placeholder).
	#    Story 013 Phase 2: FLAGS.bit0 is now written from _compute_persist_flags()
	#    so the tamper-pending intent is baked into the on-disk envelope.
	#    ADR-0004 §Tamper Response, TR-save-load-026.
	var persist_flags: int = _compute_persist_flags()
	var envelope: PackedByteArray = _compose_envelope(masked_payload, persist_flags)

	# 5. Compute HMAC over (header + masked_payload) using current-build tag,
	#    then overwrite the zero-padded placeholder in the envelope footer.
	var tags: Array[PackedByteArray] = _derive_integrity_tags()
	var hmac_input: PackedByteArray = envelope.slice(0, envelope.size() - _HMAC_SIZE)
	var hmac: PackedByteArray = _integrity_wrap(tags[0], hmac_input)
	for i: int in _HMAC_SIZE:
		envelope.encode_u8(envelope.size() - _HMAC_SIZE + i, hmac.decode_u8(i))

	# 6. Atomic write: open .tmp, store_buffer with abort-on-false (per Save/Load
	#    GDD Rule 7), close (auto-flush), rename .tmp → final path. The .bak
	#    rotation lands at step 6.5 below — Story 013 Phase 2 closed it
	#    (was previously deferred to Story 007b in the Sprint 11 stub).
	var tmp_path: String = save_file_path + ".tmp"
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		var open_err: int = FileAccess.get_open_error()
		push_error(
			"SaveLoadSystem.request_full_persist: FileAccess.open(%s) failed — " % tmp_path +
			"error=%d (reason='%s')" % [open_err, reason]
		)
		_transition_to(State.READY)
		save_failed.emit(reason, open_err)
		return
	var store_ok: bool = tmp_file.store_buffer(envelope)
	tmp_file.close()
	if not store_ok:
		# Best-effort cleanup of the partial .tmp; leaving it is acceptable per
		# Rule 6 (next-launch cleanup deletes stale .tmp files).
		DirAccess.remove_absolute(tmp_path)
		push_error(
			"SaveLoadSystem.request_full_persist: store_buffer returned false — " +
			"aborted persist; reason='%s'" % reason
		)
		_transition_to(State.READY)
		save_failed.emit(reason, ERR_FILE_CANT_WRITE)
		return

	# 6.5. Story 013 Phase 2 — pre-copy existing .dat → .bak before rename.
	#      If the .dat already exists, copy it to the .bak path so that if the
	#      next launch's .dat fails HMAC, the load pipeline can fall back to
	#      the prior known-good save. This matches Save/Load GDD Rule 6:
	#      "rotate .dat → .bak before overwriting". Failure to copy is
	#      non-fatal (the prior .bak, if any, remains; log with push_warning).
	#      ADR-0004 §`.bak` fallback, TR-save-load-017.
	var bak_path: String = save_file_path + ".bak"
	if FileAccess.file_exists(save_file_path):
		var copy_err: int = DirAccess.copy_absolute(save_file_path, bak_path)
		if copy_err != OK:
			push_warning(
				"SaveLoadSystem.request_full_persist: .dat → .bak copy failed " +
				"(Error=%d); prior .bak preserved if it existed. " % copy_err +
				"Continuing persist (reason='%s')" % reason
			)

	# 7. Atomic rename .tmp → final. DirAccess.rename returns Error (not bool;
	#    Save/Load GDD Rule 7 emphasis on Godot 4.x return type).
	var rename_err: int = DirAccess.rename_absolute(tmp_path, save_file_path)
	if rename_err != OK:
		# .tmp stays on disk; .dat is untouched. Next launch's Rule 6 cleanup
		# handles the stale .tmp.
		push_error(
			"SaveLoadSystem.request_full_persist: DirAccess.rename(%s -> %s) " % [tmp_path, save_file_path] +
			"failed with Error=%d. Prior .dat preserved." % rename_err
		)
		_transition_to(State.READY)
		save_failed.emit(reason, rename_err)
		return

	# 8. Update TickSystem's last-persist timestamp. Routes through TickSystem's
	#    cached wall clock per ADR-0005 single-call-site invariant — direct
	#    Time.get_unix_time_from_system() call from this site would violate the
	#    invariant (only TickSystem._read_wall_clock_unix_time may make that
	#    call). The cache is refreshed every heartbeat (S11-M2a _fire_heartbeat)
	#    + every BG entry; few-seconds-stale wall time is acceptable for the
	#    last_persist_ts use case (offline-progression delta has minutes/hours
	#    resolution). Defensive null-check for test envs that boot SaveLoadSystem
	#    alone.
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	if tick_system != null and tick_system.has_method("set_last_persist_ts") and tick_system.has_method("now_ms"):
		var now_ms_int: int = int(tick_system.now_ms())
		# Skip the update if TickSystem's cache is cold (now_ms returns 0
		# before any wall-clock read this session). A zero last_persist_ts
		# would be misinterpreted by offline-progression as "never persisted".
		if now_ms_int > 0:
			# Intentional ms→s truncation (ts is whole seconds per Save/Load spec).
			@warning_ignore("integer_division")
			tick_system.set_last_persist_ts(now_ms_int / 1000)

	# 9. Success: transition back to READY + emit save_completed.
	#    Clear the pending FLAGS.bit0 tamper intent AFTER the emit so any
	#    subscriber that calls get_pending_flags_bit0_tamper() from within the
	#    save_completed handler sees the still-set flag (predictable ordering).
	#    Story 013 Phase 2 — TR-save-load-026, ADR-0004 §Tamper Response.
	_transition_to(State.READY)
	save_completed.emit(reason)
	_pending_flags_bit0_tamper = false


## Requests a heartbeat persist via the canonical full-persist path.
##
## Sprint 11 S11-M2b — Story 011 SaveLoadSystem-side. Per Save/Load GDD §C.7
## "Heartbeat (every 60 s) | overwrites current slot" — heartbeat = full
## persist with reason="heartbeat". The "partial-envelope" terminology in
## the Sprint 4 stub doc-comment is SUPERSEDED by Pass-5+ which standardized
## heartbeat = full persist sharing one envelope schema.
##
## [param time_fields] is accepted for API stability with
## [code]TickSystem._fire_heartbeat[/code] (S11-M2a) but is unused —
## [method request_full_persist] already updates TickSystem's
## [code]last_persist_ts[/code] via [code]set_last_persist_ts[/code] on
## successful write per ADR-0005 single-call-site invariant.
##
## Coalesce + state-guard + envelope + atomic write + signal emission are all
## handled by the underlying [method request_full_persist] body.
##
## Example:
##   SaveLoadSystem.request_heartbeat_persist({"last_ts_ms": TickSystem.now_ms()})
##
## ADR-0004 §Heartbeat contract, Story 011 / S11-M2b
func request_heartbeat_persist(time_fields: Dictionary) -> void:
	# Explicit acknowledge of the parameter so the static-typing linter
	# doesn't warn about unused. The dict is small (2 keys per S11-M2a) and
	# discarded; no allocation concern.
	var _unused: Dictionary = time_fields
	request_full_persist("heartbeat")


## Requests a full-envelope load — reads [member save_file_path], validates
## the envelope, and hydrates all consumers via [code]load_save_data[/code].
##
## Sprint 11 Story 007b — load body. Mirror of [method request_full_persist].
## Validation order is FIXED per ADR-0004 §Validation order: MAGIC → VERSION
## → PAYLOAD_LENGTH match → HMAC. Reordering is FORBIDDEN.
##
## State transitions:
## - UNLOADED → LOADING → READY (success)
## - UNLOADED → LOADING → CORRUPT (envelope unrecoverable)
## - First-launch (no save file): UNLOADED → READY directly + emits
##   [signal first_launch] + [signal load_completed] with
##   reason="first_launch_cold_start".
##
## On HMAC tag-1 (prior key) match (N=2 rotation per ADR-0004 §HMAC Key
## History): sets [member _needs_rekey_persist] so the next
## [method request_full_persist] resigns under the current-build tag.
##
## [param reason]: Human-readable label for the load trigger ("boot",
##   "manual", "post_corrupt_acknowledge"). Propagated verbatim to
##   [signal load_completed] / [signal load_failed].
##
## Example:
##   SaveLoadSystem.request_full_load("boot")
##
## ADR-0004 §Load pipeline, TR-save-load-045
func request_full_load(reason: String) -> void:
	# Guard: load is only valid from UNLOADED. Re-loading from READY is a
	# Sprint 12+ feature (manual reload after settings change); MVP rejects.
	if _state != State.UNLOADED:
		push_warning(
			"SaveLoadSystem.request_full_load: state=%d not UNLOADED — " % _state +
			"load trigger ignored (reason='%s'). Only the initial cold-boot " % reason +
			"load is supported in MVP."
		)
		load_failed.emit(reason, ERR_UNAVAILABLE)
		return

	# Story 013 Phase 2B — AC-SL-08 distinct path: DataRegistry ERROR coexistence.
	# When DataRegistry's content load failed (state=ERROR), the on-disk save is
	# fine but the build can't render content. Surface a dedicated "reinstall"
	# modal and DO NOT touch the save file (no .bak attempt, no FS writes, no
	# tamper signal). The CORRUPT transition is appropriate (terminal load
	# failure) but the failure mode is fundamentally different from tamper.
	# ADR-0004 §DataRegistry ERROR coexistence, AC-SL-08.
	if DataRegistry.state == DataRegistry.State.ERROR:
		push_error(
			"SaveLoadSystem.request_full_load: DataRegistry.state == ERROR — " +
			"content load failed; surfacing AC-SL-08 reinstall modal and " +
			"aborting load (reason='%s'). Save file untouched." % reason
		)
		_transition_to(State.LOADING)
		_transition_to(State.CORRUPT)
		data_registry_error_modal_required.emit()
		load_failed.emit(reason, ERR_UNAVAILABLE)
		return

	_transition_to(State.LOADING)

	# 1. File presence check. No file = first launch (cold start).
	if not FileAccess.file_exists(save_file_path):
		_transition_to(State.READY)
		first_launch.emit()
		load_completed.emit("first_launch_cold_start" if reason.is_empty() else reason)
		return

	# 2. Read envelope bytes.
	var file: FileAccess = FileAccess.open(save_file_path, FileAccess.READ)
	if file == null:
		var open_err: int = FileAccess.get_open_error()
		push_error(
			"SaveLoadSystem.request_full_load: FileAccess.open(%s, READ) failed — " % save_file_path +
			"error=%d (reason='%s')" % [open_err, reason]
		)
		_transition_to(State.CORRUPT)
		load_failed.emit(reason, open_err)
		return
	var envelope: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	# 3. Parse header — MAGIC + VERSION + PAYLOAD_LENGTH (validation order
	#    locked by ADR-0004; do NOT reorder to HMAC-first).
	var parsed: Dictionary = _parse_header(envelope)
	if not parsed.magic_ok:
		push_error(
			"SaveLoadSystem.request_full_load: MAGIC mismatch — " +
			"envelope is not a Lantern Guild save (reason='%s')" % reason
		)
		_transition_to(State.CORRUPT)
		load_failed.emit(reason, ERR_FILE_CORRUPT)
		return
	var version: int = int(parsed.version)
	# Story 010 — split version-mismatch into forward-version (cannot migrate)
	# and prior-version (deferred to migration chain after envelope parse).
	if version > CURRENT_SAVE_VERSION:
		# Future-build save: this build doesn't know how to read a newer
		# schema; cannot migrate forward (no time travel). Per Story 010 AC:
		# "version > CURRENT_SAVE_VERSION → ERR_SCHEMA_MISMATCH detail=
		# 'version_future'; CORRUPT modal copy 'your save is from a newer
		# build; please update the game'" (final UX copy owned by Story 013).
		push_error(
			"SaveLoadSystem.request_full_load: VERSION %d > CURRENT_SAVE_VERSION %d — " % [version, CURRENT_SAVE_VERSION] +
			"detail='version_future'; cannot migrate forward (reason='%s')" % reason
		)
		_transition_to(State.CORRUPT)
		load_failed.emit(reason, ERR_FILE_CORRUPT)
		return
	# version < CURRENT_SAVE_VERSION → MIGRATION path runs after JSON parse
	# (line further down) once the payload Dict is in hand. Falling through
	# to envelope-split + HMAC + JSON parse is intentional: even an old-
	# version envelope must pass HMAC validation before its bytes are
	# trusted enough to feed into a migration transform.

	# 4. Split + payload-length cross-check (ADR-0004 §DoS defense Rule 2).
	var parts: Dictionary = _split_envelope(envelope)
	if not _validate_payload_length_match(parts):
		push_error(
			"SaveLoadSystem.request_full_load: PAYLOAD_LENGTH header field (%d) " % parsed.payload_length +
			"does not match (file_length - %d) (%d) — truncated or padded envelope " % [_ENVELOPE_OVERHEAD, parts.file_length - _ENVELOPE_OVERHEAD] +
			"(reason='%s')" % reason
		)
		_transition_to(State.CORRUPT)
		load_failed.emit(reason, ERR_FILE_CORRUPT)
		return

	# 5. HMAC validation against N=2 keys (current + prior). Per ADR-0004
	#    §HMAC Key History: prior-key match sets _needs_rekey_persist so the
	#    next persist re-signs under the current-build tag.
	var tags: Array[PackedByteArray] = _derive_integrity_tags()
	var hmac_input: PackedByteArray = envelope.slice(0, envelope.size() - _HMAC_SIZE)
	var expected_current: PackedByteArray = _integrity_wrap(tags[0], hmac_input)
	var matches_current: bool = (parts.footer_tag == expected_current)
	var matches_prior: bool = false
	if not matches_current and tags.size() >= 2:
		var expected_prior: PackedByteArray = _integrity_wrap(tags[1], hmac_input)
		matches_prior = (parts.footer_tag == expected_prior)
	# Story 013 Phase 2 — set when a `.bak` fallback succeeds. The append +
	# toast emit is deferred to a post-hydration block below so the just-
	# occurred recovery event isn't clobbered by `_hydrate_meta_dict`
	# (which overwrites in-memory `_meta_backup_restore_events` from the
	# `.bak`-payload's persisted `_meta`).
	var bak_recovery_now_unix: int = 0
	if not (matches_current or matches_prior):
		push_error(
			"SaveLoadSystem.request_full_load: HMAC verification failed against " +
			"both current + prior tags on .dat — attempting .bak fallback " +
			"(reason='%s')" % reason
		)
		# Story 013 Phase 2 — .bak fallback path (TR-save-load-017).
		# Emit tamper_detected_on_load immediately (the .dat is confirmed tampered).
		# Then try loading from .bak before giving up with CORRUPT terminal state.
		tamper_detected_on_load.emit()
		var bak_load_path: String = save_file_path + ".bak"
		var bak_result: Dictionary = _load_envelope_from_path(bak_load_path)
		if bak_result.get("ok", false):
			# .bak loaded + HMAC-verified. Capture the recovery timestamp via
			# TickSystem's cached wall clock — ADR-0005 single-call-site
			# invariant FORBIDS direct Time.get_unix_time_from_system() here.
			# If TickSystem's cache is cold (now_ms returns 0), the recovery
			# event simply isn't recorded this load — acceptable degradation
			# vs. violating the invariant. The actual prune+append+toast emit
			# is deferred to a post-hydration block below.
			var tick_for_bak: Node = get_node_or_null("/root/TickSystem")
			if tick_for_bak != null and tick_for_bak.has_method("now_ms"):
				var ms_val: int = int(tick_for_bak.now_ms())
				if ms_val > 0:
					@warning_ignore("integer_division")
					bak_recovery_now_unix = ms_val / 1000
			# Continue the load from the verified .bak envelope bytes.
			# Re-assign 'envelope' to the bak bytes and re-split for the JSON parse below.
			envelope = bak_result.get("envelope_bytes", PackedByteArray())
			parts = _split_envelope(envelope)
			# Queue a deferred re-persist so the recovered .bak data is promoted
			# to .dat (with a fresh HMAC) on the next frame after load completes.
			call_deferred("request_full_persist", "bak_recovery_repersist")
			# Fall through to JSON parse below (envelope is now the .bak bytes).
		else:
			# Both .dat and .bak failed — genuine CORRUPT terminal state.
			# Story 013 Phase 2B — emit corrupt_both_modal_required so the UI
			# can show the AC-SL-07 single-button "[Begin]" modal. The signal
			# fires BEFORE _transition_to so subscribers can read state
			# transitions in their handlers if needed.
			push_error(
				"SaveLoadSystem.request_full_load: .bak fallback also failed — " +
				"both slots unrecoverable; entering CORRUPT (reason='%s')" % reason
			)
			corrupt_both_modal_required.emit()
			_transition_to(State.CORRUPT)
			load_failed.emit(reason, ERR_FILE_CORRUPT)
			return
	if matches_prior and not matches_current:
		# N=2 rotation — re-persist under current-build tag on next persist.
		_needs_rekey_persist = true

	# 6. Un-XOR payload + UTF-8 JSON parse.
	var mask_seed: PackedByteArray = _derive_mask_seed(version)
	var mask: PackedByteArray = _generate_mask(mask_seed, (parts.masked_payload as PackedByteArray).size())
	var plaintext: PackedByteArray = _apply_xor_mask(parts.masked_payload, mask)
	var json_string: String = plaintext.get_string_from_utf8()
	var parse_result: Variant = JSON.parse_string(json_string)
	if parse_result == null or not (parse_result is Dictionary):
		push_error(
			"SaveLoadSystem.request_full_load: JSON parse failed (got %s) — " % typeof(parse_result) +
			"envelope HMAC was valid but payload is not a Dictionary (reason='%s')" % reason
		)
		_transition_to(State.CORRUPT)
		load_failed.emit(reason, ERR_PARSE_ERROR)
		return
	var root_dict: Dictionary = parse_result as Dictionary

	# 6.5. Migration (Story 010) — runs only when version < CURRENT_SAVE_VERSION.
	#      The forward-version case (version > CURRENT) was rejected at step 3.
	#      The same-version case (version == CURRENT) is the common path and
	#      skips this block entirely. The migration chain transforms the
	#      envelope's Dict into a Dict matching the current schema before
	#      consumer hydration runs. On chain failure (null return), the load
	#      fails with CORRUPT — fallback to .bak / corruption policy.
	#
	#      MVP placeholder: the chain returns null for any version != 1 (no
	#      migrations authored yet; this branch is dead until V2 ships). When
	#      the first real migration lands, the chain success branch must also
	#      atomically re-persist under CURRENT_SAVE_VERSION (Story 008's atomic
	#      write pipeline) so the on-disk save catches up to the migrated
	#      schema. The re-persist is guarded behind a "did the migration chain
	#      actually transform the payload" check to keep version==CURRENT
	#      loads zero-overhead.
	var migrated_via_chain: bool = false
	if version < CURRENT_SAVE_VERSION:
		push_warning(
			"SaveLoadSystem.request_full_load: VERSION %d < CURRENT_SAVE_VERSION %d — " % [version, CURRENT_SAVE_VERSION] +
			"entering MIGRATION (reason='%s')" % reason
		)
		_transition_to(State.MIGRATION)
		var chain_result: Variant = _run_migration_chain(root_dict, version, CURRENT_SAVE_VERSION)
		if chain_result == null:
			push_error(
				"SaveLoadSystem.request_full_load: migration chain returned null for " +
				"VERSION %d → %d — no migration authored for this version step " % [version, CURRENT_SAVE_VERSION] +
				"(reason='%s')" % reason
			)
			_transition_to(State.CORRUPT)
			load_failed.emit(reason, ERR_FILE_CORRUPT)
			return
		if not (chain_result is Dictionary):
			# Defensive: chain contract is "Dict on success or null on failure";
			# anything else is a programmer error in the chain implementation.
			push_error(
				"SaveLoadSystem.request_full_load: migration chain returned %s (not Dictionary) " % typeof(chain_result) +
				"— chain contract violation (reason='%s')" % reason
			)
			_transition_to(State.CORRUPT)
			load_failed.emit(reason, ERR_FILE_CORRUPT)
			return
		root_dict = chain_result as Dictionary
		migrated_via_chain = true

	# 7. Iterate CONSUMER_PATHS, hydrate each via load_save_data. Per Save/Load
	#    GDD §C: missing per-consumer keys are tolerated — load_save_data is
	#    contractually responsible for handling absent fields with first-
	#    launch defaults (per consumer's own spec). This path mirrors the
	#    persist body's iteration shape.
	for path: String in CONSUMER_PATHS:
		var node: Node = _resolve_consumer(path)
		if node == null:
			# _resolve_consumer already called push_error + get_tree().quit(1).
			# Surface as load_failed for any subscriber that needs to react.
			_transition_to(State.CORRUPT)
			load_failed.emit(reason, ERR_DOES_NOT_EXIST)
			return
		if not node.has_method("load_save_data"):
			push_error(
				"SaveLoadSystem.request_full_load: %s has no load_save_data — " % path +
				"fatal architecture violation per ADR-0004 §Consumer Contract."
			)
			_transition_to(State.CORRUPT)
			load_failed.emit(reason, ERR_METHOD_NOT_FOUND)
			return
		var consumer_data: Variant = root_dict.get(node.name, {})
		# Per Save/Load Rule 11 type-guard: pass empty dict on non-Dictionary
		# value rather than letting the consumer's load_save_data type-error.
		if not (consumer_data is Dictionary):
			push_warning(
				"SaveLoadSystem.request_full_load: %s payload is %s (not Dictionary) — " % [path, typeof(consumer_data)] +
				"passing empty dict to load_save_data (Rule 11)"
			)
			consumer_data = {}
		node.call("load_save_data", consumer_data)

	# 7.5. Story 013 Phase 2 — hydrate `_meta` fields from root_dict.
	#      This is intentionally done AFTER consumer hydration so a buggy
	#      _meta value cannot influence consumer load_save_data calls.
	#      Missing or malformed _meta is silently tolerated (first-launch
	#      or old-version saves without _meta are valid; defaults apply).
	#      ADR-0004 §`_meta` field schema, TR-save-load-017/018/019.
	var meta_raw: Variant = root_dict.get("_meta", {})
	if meta_raw is Dictionary:
		_hydrate_meta_dict(meta_raw as Dictionary)

	# 7.6. Story 013 Phase 2 — append the .bak recovery event AFTER hydration.
	#      Order matters: hydration above sets _meta_backup_restore_events to
	#      the .bak payload's persisted events; THEN we prune stale entries
	#      and append this load's recovery timestamp. Doing it the other way
	#      would let hydration clobber the just-appended event.
	#      The toast signal also emits here so subscribers see the post-
	#      hydration in-window count, which is what the UI escalation logic
	#      (TR-save-load-017 BACKUP_ESCALATION_THRESHOLD) needs.
	#      ADR-0004 §`.bak` fallback escalation, TR-save-load-017.
	if bak_recovery_now_unix > 0:
		var window_start: int = bak_recovery_now_unix - BACKUP_ESCALATION_WINDOW_SECONDS
		var pruned: Array[int] = []
		for ts: int in _meta_backup_restore_events:
			if ts >= window_start:
				pruned.append(ts)
		pruned.append(bak_recovery_now_unix)
		_meta_backup_restore_events = pruned
		var in_window_count: int = _meta_backup_restore_events.size()
		# Story 013 Phase 2B — escalation switch (TR-save-load-017): emit ONE
		# OR THE OTHER signal based on within-window event count. Mutually
		# exclusive — UI subscribers should only handle one; subscribing to
		# both is harmless (only one fires per recovery).
		if in_window_count >= BACKUP_ESCALATION_THRESHOLD:
			storage_advisory_modal_required.emit(in_window_count)
		else:
			bak_recovered_toast.emit(in_window_count)

	# 8. Success: transition READY + emit load_completed.
	#    For migration path (Story 010), this also implicitly satisfies the
	#    "MIGRATION → READY" transition. Atomic re-persist is queued as a
	#    deferred persist trigger so the on-disk save catches up to the
	#    migrated schema; persist runs after we exit the load pipeline so
	#    it lands as a normal READY → PERSISTING → READY cycle (rather than
	#    needing a special MIGRATION → PERSISTING transition that doesn't
	#    fit the state machine cleanly).
	_transition_to(State.READY)
	load_completed.emit(reason)
	if migrated_via_chain:
		# Story 010 AC: post-migration atomic re-persist writes under
		# CURRENT_SAVE_VERSION (the persist body composes the header with
		# CURRENT_SAVE_VERSION unconditionally — see _compose_header) and
		# advances _meta.save_sequence_number. call_deferred avoids the
		# stack of running another sync I/O cycle inside the load handler.
		call_deferred("request_persist", "post_migration")


# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Routes state machine transitions with a hardcoded transition table.
##
## Allowed transition table:
##   UNLOADED    → LOADING
##   LOADING     → READY
##   LOADING     → CORRUPT
##   LOADING     → MIGRATION   (Story 010 — version mismatch on load)
##   READY       → PERSISTING
##   PERSISTING  → READY
##   PERSISTING  → PERSISTING  (coalesce — push_warning; drops new trigger)
##   CORRUPT     → (terminal; any next value push_warning + no-op)
##   MIGRATION   → READY        (chain success; consumers hydrated from migrated payload)
##   MIGRATION   → CORRUPT      (chain returned null; no migration authored)
##
## Same-state no-ops (except PERSISTING→PERSISTING which warns + drops):
##   All other same-state calls are silent no-ops (idempotent boot guard).
##
## Illegal transitions (not in table above): push_warning + short-circuit.
## PERSISTING→PERSISTING overlap: push_warning + short-circuit (coalesce contract
## per TR-save-load-046 — must NOT call push_error).
##
## ADR-0003 Amendment #2, TR-save-load-045, TR-save-load-046
func _transition_to(next: State) -> void:
	# PERSISTING → PERSISTING overlap: coalesce + push_warning (TR-save-load-046)
	if _state == State.PERSISTING and next == State.PERSISTING:
		push_warning(
			"SaveLoadSystem._transition_to: PERSISTING → PERSISTING overlap coalesced " +
			"(TR-save-load-046). New trigger dropped; state stays PERSISTING."
		)
		return

	# Same-state no-op (silent idempotent guard for all non-PERSISTING states)
	if _state == next:
		return

	# CORRUPT is terminal — no transition out in MVP scope
	if _state == State.CORRUPT:
		push_warning(
			"SaveLoadSystem._transition_to: attempted transition from CORRUPT → %d " % next +
			"but CORRUPT is terminal in MVP scope. Transition ignored."
		)
		return

	# Hardcoded allowed transition table
	var allowed: bool = false
	match _state:
		State.UNLOADED:
			allowed = next == State.LOADING
		State.LOADING:
			# Story 010: LOADING → MIGRATION added for version-mismatch path.
			allowed = next == State.READY or next == State.CORRUPT or next == State.MIGRATION
		State.READY:
			allowed = next == State.PERSISTING
		State.PERSISTING:
			allowed = next == State.READY
		State.MIGRATION:
			# Story 010: MIGRATION terminates in READY (chain success) or
			# CORRUPT (chain failure). The "MIGRATION → LOADING re-enter"
			# model from earlier docstring drafts is retired — chain success
			# does its own hydrate + atomic re-persist before transitioning.
			allowed = next == State.READY or next == State.CORRUPT

	if not allowed:
		push_warning(
			"SaveLoadSystem._transition_to: illegal transition %d → %d. " % [_state, next] +
			"Transition ignored."
		)
		return

	_state = next


## Runs the schema-migration chain to transform an old-version payload Dict
## into a Dict matching CURRENT_SAVE_VERSION. Returns the migrated Dict on
## success or null on failure (no migration authored for the requested
## version step).
##
## MVP placeholder behavior (Story 010):
## - from_version == to_version: returns the payload unchanged (no-op,
##   defensive contract for callers that pass equal versions).
## - any other (from, to) pair: returns null. No migrations have been
##   authored yet because no schema version bump has shipped — the first
##   real migration lands alongside the V2 schema bump and adds a branch
##   to this chain (e.g., `if from_version == 1 and to_version == 2:
##   return _migrate_v1_to_v2(payload)`).
##
## Chain idiom (when migrations land):
## - Each migration step is `_migrate_from_vN_to_vN_plus_1(payload) -> Variant`.
## - Multi-step chains compose by feeding each step's output into the next.
## - Any step returning null aborts the chain and propagates null to the caller.
##
## Lockstep-edit checklist when bumping CURRENT_SAVE_VERSION:
##   1. `architecture.md` rank table — note the schema version bump in the
##      Save/Load row's history column.
##   2. `project.godot [autoload]` — no edit unless adding a new autoload
##      consumer (which is itself an ADR-0003 + ADR-0004 lockstep edit).
##   3. `SaveLoadSystem.CONSUMER_PATHS` — no edit unless consumer surface
##      changed; if it did, the consumer's `load_save_data` body owns the
##      missing-field defaults per Save/Load Rule 11.
##   4. This method — add `_migrate_from_vN_to_vN_plus_1` step + chain branch.
##   5. `CURRENT_SAVE_VERSION` constant — bump to the new value.
##   6. Author a regression test that loads a V(N) envelope and asserts
##      the post-migration consumer state matches the expected V(N+1) shape.
##
## ADR-0004 §Migration Plan, ADR-0003 §Consumer Lockstep, TR-save-load-007,
## TR-save-load-045 (MIGRATION state), TR-save-load-055 (ERR_SCHEMA_MISMATCH).
func _run_migration_chain(payload: Dictionary, from_version: int, to_version: int) -> Variant:
	# Same-version contract: no-op pass-through. This branch is dead code
	# from the load pipeline (the migration call site only fires when
	# version < CURRENT_SAVE_VERSION) but the contract is preserved for
	# direct callers (e.g., tests, V1.0+ batch-migration tooling).
	if from_version == to_version:
		return payload
	# No migrations authored yet — every (from, to) where from != to
	# returns null until a real V(N) → V(N+1) step lands.
	return null


## Resolves a consumer node by path; exits the process on miss in production.
##
## NEVER caches the returned node — per ADR-0003 Amendment #2, consumer
## references must be resolved per-call via get_node_or_null.
##
## If the node is missing: calls push_error + get_tree().quit(1).
## This is a fatal architecture violation — consumers in CONSUMER_PATHS are
## required to be present at persist-time (ADR-0004 §Consumer Contract).
##
## NOTE: In test fixtures, do NOT call this method directly against the live
## autoload if the consumer autoloads are absent. Tests that exercise this path
## should use preload-and-new isolation and verify the push_error call via
## an output spy rather than triggering the production quit() path.
##
## [param path]: One of the entries in [constant CONSUMER_PATHS].
## Returns the resolved [Node], or [code]null[/code] if get_tree().quit() is
## not yet effective (editor / test context).
##
## ADR-0003 Amendment #2, ADR-0004 §Consumer Contract, TR-save-load-034
func _resolve_consumer(path: String) -> Node:
	var node: Node = get_node_or_null(path)
	if node == null:
		push_error(
			"SaveLoadSystem._resolve_consumer: %s not found — " % path +
			"fatal architecture violation per ADR-0004 §Consumer Contract"
		)
		get_tree().quit(1)
		return null
	return node

# ---------------------------------------------------------------------------
# Private envelope helpers (Story 002 — binary layout)
# ---------------------------------------------------------------------------

## Builds the 12-byte envelope header in canonical little-endian layout.
##
## Byte layout:
##   [0..4):  MAGIC bytes ("LGLD")
##   [4..6):  VERSION as u16 LE
##   [6..8):  FLAGS as u16 LE
##   [8..12): PAYLOAD_LENGTH as u32 LE
##
## [param version]: Schema version — typically [constant CURRENT_SAVE_VERSION].
## [param flags]:   Bit-field flags (u16); bit 0 = tamper-suspected in V1.0.
## [param payload_length]: Byte length of the XOR-masked payload that follows.
##
## Returns a [PackedByteArray] of exactly [constant _HEADER_SIZE] (12) bytes.
##
## Example:
##   var hdr := _compose_header(CURRENT_SAVE_VERSION, 0, payload.size())
##
## ADR-0004 §Envelope byte layout, TR-save-load-002, TR-save-load-003
func _compose_header(version: int, flags: int, payload_length: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(_HEADER_SIZE)
	# Write MAGIC bytes [0..4)
	for i: int in range(_MAGIC.size()):
		bytes.encode_u8(i, _MAGIC[i])
	bytes.encode_u16(4, version)
	bytes.encode_u16(6, flags)
	bytes.encode_u32(8, payload_length)
	return bytes


## Parses the 12-byte header from the front of an envelope byte array.
##
## Reads MAGIC, VERSION, FLAGS, and PAYLOAD_LENGTH from their fixed offsets.
## Returns a Dictionary with four keys:
##   - [code]magic_ok[/code]       : [bool]  — true when bytes [0..4) == [constant _MAGIC]
##   - [code]version[/code]        : [int]   — u16 from bytes [4..6)
##   - [code]flags[/code]          : [int]   — u16 from bytes [6..8)
##   - [code]payload_length[/code] : [int]   — u32 from bytes [8..12)
##
## If [param envelope] is shorter than [constant _HEADER_SIZE], returns
## [code]{magic_ok: false, version: 0, flags: 0, payload_length: 0}[/code].
##
## [param envelope]: Full or header-prefix byte array. Need not be a complete file.
##
## Example:
##   var parsed := _parse_header(raw_bytes)
##   if not parsed.magic_ok:
##       _transition_to(State.CORRUPT)
##
## ADR-0004 §Envelope byte layout, TR-save-load-002, TR-save-load-003
func _parse_header(envelope: PackedByteArray) -> Dictionary:
	if envelope.size() < _HEADER_SIZE:
		return {"magic_ok": false, "version": 0, "flags": 0, "payload_length": 0}
	var magic_ok: bool = (envelope.slice(0, 4) == _MAGIC)
	return {
		"magic_ok": magic_ok,
		"version": envelope.decode_u16(4),
		"flags": envelope.decode_u16(6),
		"payload_length": envelope.decode_u32(8),
	}


## Assembles a complete save envelope from an XOR-masked payload.
##
## Layout: header (12B) + masked_payload + zero-padded HMAC placeholder (32B).
## Total byte count: [constant _ENVELOPE_OVERHEAD] + masked_payload.size().
##
## The HMAC region is zero-initialised in this story. Story 004 overwrites it
## with the computed HMAC-SHA256 tag just before the atomic disk write (Story 008).
##
## [param masked_payload]: XOR-masked UTF-8 JSON bytes (Story 003 supplies the mask).
##   Pass a plain [PackedByteArray] for envelope-structure tests in this story.
## [param flags]: u16 bit-field written verbatim into the FLAGS header field.
##
## Returns a complete [PackedByteArray] envelope ready for Story 004 HMAC injection.
##
## Example:
##   var envelope := _compose_envelope(masked_payload, 0x0000)
##
## ADR-0004 §Envelope byte layout, TR-save-load-002
func _compose_envelope(masked_payload: PackedByteArray, flags: int) -> PackedByteArray:
	var header: PackedByteArray = _compose_header(CURRENT_SAVE_VERSION, flags, masked_payload.size())
	var hmac_placeholder := PackedByteArray()
	hmac_placeholder.resize(_HMAC_SIZE)  # zero-initialised by default
	var envelope := PackedByteArray()
	envelope.append_array(header)
	envelope.append_array(masked_payload)
	envelope.append_array(hmac_placeholder)
	return envelope


## Splits a raw file byte array into its three structural regions.
##
## Returns a Dictionary with five keys:
##   - [code]header_bytes[/code]          : [PackedByteArray] — bytes [0.._HEADER_SIZE)
##   - [code]masked_payload[/code]        : [PackedByteArray] — bytes [_HEADER_SIZE .. file_length - _HMAC_SIZE)
##   - [code]footer_tag[/code]           : [PackedByteArray] — always the last [constant _HMAC_SIZE] bytes
##   - [code]payload_length_claimed[/code]: [int]             — PAYLOAD_LENGTH field from header (u32)
##   - [code]file_length[/code]           : [int]             — envelope.size()
##
## IMPORTANT (DoS defense, ADR-0004 Rule 2): the footer is located by
## [code]file_length - _HMAC_SIZE[/code], NOT by the PAYLOAD_LENGTH field.
## This prevents a malformed PAYLOAD_LENGTH from causing an over-read.
## Story 006 cross-checks payload_length_claimed vs (file_length - _ENVELOPE_OVERHEAD).
##
## If [param envelope] is shorter than [constant _ENVELOPE_OVERHEAD], returns
## empty arrays for masked_payload and footer_tag (header_bytes is clamped).
##
## Example:
##   var parts := _split_envelope(raw_bytes)
##   if not _validate_payload_length_match(parts):
##       _transition_to(State.CORRUPT)
##
## ADR-0004 §Envelope byte layout, Rule 2 DoS defense, TR-save-load-024
func _split_envelope(envelope: PackedByteArray) -> Dictionary:
	var file_length: int = envelope.size()
	var header_bytes: PackedByteArray
	var masked_payload: PackedByteArray
	var footer_tag: PackedByteArray
	var payload_length_claimed: int = 0

	if file_length >= _ENVELOPE_OVERHEAD:
		header_bytes = envelope.slice(0, _HEADER_SIZE)
		footer_tag = envelope.slice(file_length - _HMAC_SIZE, file_length)
		masked_payload = envelope.slice(_HEADER_SIZE, file_length - _HMAC_SIZE)
		var parsed: Dictionary = _parse_header(header_bytes)
		payload_length_claimed = parsed.payload_length
	else:
		# Too short to be a valid envelope — return clamped header, empty payload + HMAC
		header_bytes = envelope.slice(0, mini(file_length, _HEADER_SIZE))
		footer_tag = PackedByteArray()
		masked_payload = PackedByteArray()

	return {
		"header_bytes": header_bytes,
		"masked_payload": masked_payload,
		"footer_tag": footer_tag,
		"payload_length_claimed": payload_length_claimed,
		"file_length": file_length,
	}


## Returns [code]true[/code] when the header's PAYLOAD_LENGTH equals
## [code]file_length - _ENVELOPE_OVERHEAD[/code].
##
## Per TR-save-load-024: after the HMAC is verified, the PAYLOAD_LENGTH field
## inside the header MUST agree with the actual file length. A mismatch signals
## a truncated, padded, or spliced file and is treated as CORRUPT by Story 006.
##
## [param parsed]: Dictionary returned by [method _split_envelope].
##   Must contain keys [code]payload_length_claimed[/code] (int) and
##   [code]file_length[/code] (int).
##
## Returns [code]false[/code] when either value is negative or file_length is
## below [constant _ENVELOPE_OVERHEAD] (too short to be a valid envelope).
##
## Example:
##   var parts := _split_envelope(raw_bytes)
##   if not _validate_payload_length_match(parts):
##       _transition_to(State.CORRUPT)
##
## ADR-0004 §Envelope byte layout, TR-save-load-024
func _validate_payload_length_match(parsed: Dictionary) -> bool:
	var claimed: int = parsed.get("payload_length_claimed", -1)
	var file_length: int = parsed.get("file_length", -1)
	if claimed < 0 or file_length < _ENVELOPE_OVERHEAD:
		return false
	return claimed == (file_length - _ENVELOPE_OVERHEAD)


# ---------------------------------------------------------------------------
# Private XOR mask helpers (Story 003 — deterministic obfuscation layer)
# ---------------------------------------------------------------------------
# THREAT-MODEL NOTE: XOR-masking is obfuscation only — it prevents trivial
# text-editor edits of the save file but provides NO confidentiality guarantee.
# Per ADR-0004 §Risk row: this is "namespace-scrambling", not encryption.
# ---------------------------------------------------------------------------

## Derives the 32-byte mask seed for a given schema version.
##
## Computes SHA256(MAGIC || u16_le(version) || NAMESPACE_16) where NAMESPACE_16
## is the 16-byte product namespace from [BootNamespace].
##
## The result is deterministic and reproducible across machines with the same
## binary — this is required so that a save written on one machine loads on
## another (ADR-0004 §XOR mask derivation).
##
## [param version]: Schema version — typically [constant CURRENT_SAVE_VERSION].
##   Changing the version produces a distinct seed, ensuring old saves cannot
##   be partially decoded by a newer parser using a mismatched mask stream.
##
## Returns a [PackedByteArray] of exactly 32 bytes (one SHA-256 output block).
##
## Example:
##   var seed := _derive_mask_seed(CURRENT_SAVE_VERSION)
##
## ADR-0004 §XOR mask derivation, TR-save-load-020
func _derive_mask_seed(version: int) -> PackedByteArray:
	# SHA256(MAGIC || u16_le(version) || STATIC_NAMESPACE_16)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(_MAGIC)
	var version_bytes := PackedByteArray()
	version_bytes.resize(2)
	version_bytes.encode_u16(0, version)
	ctx.update(version_bytes)
	ctx.update(BootNamespace.get_namespace_bytes())
	return ctx.finish()


## Generates an obfuscation mask stream of exactly [param payload_length] bytes.
##
## Concatenates SHA256(seed || u32_le(chunk_index)) for chunk_index = 0, 1, 2, ...
## until [param payload_length] bytes are accumulated; truncates the final block.
## The stream is deterministic: same seed + same length always produces the same bytes.
##
## At sub-microsecond per SHA-256 call on native [HashingContext], generating the
## worst-case 2 MB mask (~65 536 chunks) completes well under the persist budget.
##
## [param seed]:           32-byte seed from [method _derive_mask_seed].
## [param payload_length]: Number of mask bytes to produce. Returns empty when 0.
##
## Returns a [PackedByteArray] of exactly [param payload_length] bytes.
##
## Example:
##   var mask := _generate_mask(seed, plaintext.size())
##   var masked := _apply_xor_mask(plaintext, mask)
##
## ADR-0004 §XOR mask derivation, TR-save-load-020.
##
## Note: parameter name `seed` shadows GDScript's built-in `seed()` RNG
## function. Kept because `seed` is the canonical cryptographic-domain term
## for SHA-256 mask derivation (matches the algorithm spec + every comment
## referencing it). The body never calls `seed()` so the shadow is purely
## informational; suppressed here to keep the lint baseline at zero.
@warning_ignore("shadowed_global_identifier")
func _generate_mask(seed: PackedByteArray, payload_length: int) -> PackedByteArray:
	if payload_length <= 0:
		return PackedByteArray()
	var mask := PackedByteArray()
	var chunk_index: int = 0
	while mask.size() < payload_length:
		# SHA256(seed || u32_le(chunk_index)) — chunk_index little-endian per
		# envelope field convention (ADR-0004 §Envelope byte layout)
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(seed)
		var chunk_bytes := PackedByteArray()
		chunk_bytes.resize(4)
		chunk_bytes.encode_u32(0, chunk_index)
		ctx.update(chunk_bytes)
		var block: PackedByteArray = ctx.finish()  # 32 bytes
		mask.append_array(block)
		chunk_index += 1
	if mask.size() > payload_length:
		mask = mask.slice(0, payload_length)
	return mask


## Applies element-wise XOR between [param plaintext] and [param mask].
##
## XOR is self-inverse: applying the same mask twice returns the original bytes.
## Use this to namespace-scramble plaintext before writing and to de-scramble
## after reading. Both directions use the identical call signature.
##
## The mask MUST be exactly [code]plaintext.size()[/code] bytes — call
## [method _generate_mask] with [code]payload_length = plaintext.size()[/code]
## to guarantee this. A size mismatch is a programmer error and returns an empty
## array after emitting [method push_error].
##
## [param plaintext]: Source bytes (UTF-8 JSON payload or masked bytes on decode).
## [param mask]:      Mask of equal length from [method _generate_mask].
##
## Returns a [PackedByteArray] of [code]plaintext.size()[/code] bytes, or empty
## on size mismatch.
##
## Example:
##   # Obfuscate
##   var masked := _apply_xor_mask(plaintext_bytes, mask)
##   # Restore
##   var restored := _apply_xor_mask(masked, mask)
##   assert(restored == plaintext_bytes)
##
## ADR-0004 §XOR mask derivation, TR-save-load-004
func _apply_xor_mask(plaintext: PackedByteArray, mask: PackedByteArray) -> PackedByteArray:
	if plaintext.size() != mask.size():
		push_error(
			"SaveLoadSystem._apply_xor_mask: size mismatch " +
			"(plaintext=%d, mask=%d)" % [plaintext.size(), mask.size()]
		)
		return PackedByteArray()
	var result := PackedByteArray()
	result.resize(plaintext.size())
	for i: int in range(plaintext.size()):
		result.encode_u8(i, plaintext.decode_u8(i) ^ mask.decode_u8(i))
	return result


# ---------------------------------------------------------------------------
# Private integrity helpers (Story 004 — HMAC-SHA256 wrapper)
# ---------------------------------------------------------------------------
# THREAT-MODEL NOTE: HMAC-SHA256 provides tamper-detection (integrity) only.
# It does NOT encrypt or conceal the payload. The XOR obfuscation layer (Story 003)
# and the HMAC layer (this story) are complementary: XOR prevents trivial text-editor
# edits; HMAC detects any byte-level modification of the stored envelope.
# See ADR-0004 §Risk rows for the full threat model.
# ---------------------------------------------------------------------------

## Computes the SHA-256 digest of [param data] using the native [HashingContext] primitive.
##
## This is a thin, stateless wrapper over [code]HashingContext.HASH_SHA256[/code] that
## produces a 32-byte output and is reused by both the mask seed derivation path
## ([method _derive_mask_seed]) and the integrity tag path ([method _integrity_wrap]).
##
## [param data]: Arbitrary-length byte array to hash.
##
## Returns a [PackedByteArray] of exactly 32 bytes (one SHA-256 output block).
##
## Example:
##   var digest := _sha256("Hello".to_utf8_buffer())
##   assert(digest.size() == 32)
##
## ADR-0004 §HMAC scheme, TR-save-load-022
func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()  # 32 bytes


## Computes a 32-byte HMAC-SHA256 integrity tag over [param msg] using [param key_bytes].
##
## This is a from-scratch RFC 2104 / RFC 4231 conformant implementation layered on
## the native [code]HashingContext.HASH_SHA256[/code] primitive. The implementation
## MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly before any
## AC-SL-TAMPER-* acceptance criterion is permitted to run (gate AC-SL-HMAC-01).
##
## Algorithm per RFC 2104 §2:
##   1. If [param key_bytes].size() > 64: replace with SHA-256([param key_bytes]).
##   2. If [param key_bytes].size() < 64: zero-pad to 64 bytes.
##   3. Derive o_pad[i] = key[i] XOR 0x5C and i_pad[i] = key[i] XOR 0x36 for i in 0..63.
##   4. Return SHA-256(o_pad || SHA-256(i_pad || [param msg])).
##
## This function provides tamper-detection (integrity tag) only. It does NOT encrypt
## or conceal [param msg]. See ADR-0004 §Risk rows for the threat model boundary.
##
## [param key_bytes]: Authentication tag material (arbitrary length). The caller's
##   buffer is NOT mutated — this function duplicates before any modification.
## [param msg]: The message to authenticate. Typically the 12-byte header
##   concatenated with the XOR-masked payload (ADR-0004 §Envelope byte layout).
##
## Returns a [PackedByteArray] of exactly 32 bytes (the HMAC-SHA256 authentication tag).
##
## Example:
##   var tag := _integrity_wrap(material_bytes, header_bytes + masked_payload)
##   assert(tag.size() == 32)
##
## ADR-0004 §HMAC scheme, RFC 2104, RFC 4231, TR-save-load-022, TR-save-load-019
func _integrity_wrap(key_bytes: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	# Duplicate so we never mutate the caller's buffer.
	var tag_material := key_bytes.duplicate()

	# RFC 2104 §2 step 1: if tag material longer than block size, pre-hash it.
	if tag_material.size() > _BLOCK_SIZE_SHA256:
		tag_material = _sha256(tag_material)  # 32 bytes; falls through to zero-pad

	# RFC 2104 §2 step 2: zero-pad tag material to exactly block size.
	if tag_material.size() < _BLOCK_SIZE_SHA256:
		tag_material.resize(_BLOCK_SIZE_SHA256)  # Godot 4.x zero-fills new entries

	# Build outer pad (o_pad) and inner pad (i_pad).
	var o_pad := PackedByteArray()
	o_pad.resize(_BLOCK_SIZE_SHA256)
	var i_pad := PackedByteArray()
	i_pad.resize(_BLOCK_SIZE_SHA256)
	for i: int in _BLOCK_SIZE_SHA256:
		o_pad.encode_u8(i, tag_material.decode_u8(i) ^ 0x5C)
		i_pad.encode_u8(i, tag_material.decode_u8(i) ^ 0x36)

	# Inner hash: SHA-256(i_pad || msg)
	var inner_input := i_pad.duplicate()
	inner_input.append_array(msg)
	var inner_hash: PackedByteArray = _sha256(inner_input)

	# Outer hash: SHA-256(o_pad || inner_hash)
	var outer_input := o_pad.duplicate()
	outer_input.append_array(inner_hash)
	return _sha256(outer_input)


# ---------------------------------------------------------------------------
# Private key-derivation helpers (Story S4-S1 — multi-part assembly + N=2 rotation)
# ---------------------------------------------------------------------------
# ADR-0004 §HMAC key derivation: three fragments scattered across three different
# autoloads under non-suggestive identifiers, combined via the formula:
#   tag_n = SHA256(PART_A XOR PART_B || PART_C || version_string_n)
# where PART_A is from BootNamespace, PART_B from EngineBootstrap, PART_C from
# RuntimeLocaleGuard. STATIC_SECRET (XOR mask seed) MUST NOT participate here —
# the two paths are architecturally disjoint per ADR-0004.
# ---------------------------------------------------------------------------

## Derives the fixed-length N=2 array of 32-byte integrity tags for the current build.
##
## Formula per ADR-0004 §HMAC key derivation + RFC 2104:
##   1. xor_ab   = PART_A XOR PART_B  (element-wise, 16 bytes)
##   2. input_n  = xor_ab || PART_C || version_string_n.to_utf8_buffer()
##   3. tag_n    = SHA256(input_n)
##
## Returns [code]Array[PackedByteArray][/code] of exactly length 2:
##   [0] = current-build integrity tag (derived from [constant EngineBootstrap.CURRENT_BUILD_VERSION_STRING])
##   [1] = prior-build integrity tag   (derived from [constant EngineBootstrap.PRIOR_BUILD_VERSION_STRING])
##
## The array is fixed-length N=2 per ADR-0004 §N=2 is authoritative.
## Adding a third entry requires a superseding ADR.
##
## Deterministic: same fragment bytes + same version strings always produce
## identical output. No time-dependent or random input.
##
## NOTE: This function name uses "integrity_tags" deliberately — "key" and
## "keys" substrings in function names are forbidden per ADR-0004 §Forbidden Patterns
## (as enforced by the CI grep in Story 014). The rename from _derive_keys to
## _derive_integrity_tags is documented in the session-state flagged ambiguities log.
##
## NOTE: STATIC_SECRET (used by [method _derive_mask_seed] for XOR obfuscation) is
## explicitly NOT referenced here — the two derivation paths are architecturally
## disjoint per ADR-0004 §HMAC key derivation.
##
## [return] [code]Array[PackedByteArray][/code] of length 2; each entry is 32 bytes.
##
## Example:
##   var tags := _derive_integrity_tags()
##   assert(tags.size() == 2)
##   assert(tags[0].size() == 32)
##   assert(tags[1].size() == 32)
##   # Use tags[0] as key_bytes arg to _integrity_wrap for current-build signing
##   var hmac_tag := _integrity_wrap(tags[0], header_bytes + masked_payload)
##
## ADR-0004 §HMAC key derivation, §N=2 rotation, TR-save-load-021
func _derive_integrity_tags() -> Array[PackedByteArray]:
	# Gather the three 16-byte fragments from their respective autoloads.
	# Each autoload holds its fragment under a non-suggestive identifier.
	var part_a := BootNamespace.get_boot_prefix_a()       # 16 bytes, BootNamespace
	var part_b := EngineBootstrap.get_boot_prefix_b()     # 16 bytes, EngineBootstrap
	var part_c := RuntimeLocaleGuard.get_locale_tail()    # 16 bytes, RuntimeLocaleGuard

	# Step 1: element-wise XOR of part_a and part_b (both 16 bytes).
	var xor_ab := PackedByteArray()
	xor_ab.resize(16)
	for i: int in 16:
		xor_ab.encode_u8(i, part_a.decode_u8(i) ^ part_b.decode_u8(i))

	# Step 2: assemble SHA256 input per version string, then hash.
	# input_n = xor_ab || part_c || version_string_n.to_utf8_buffer()
	var current_version: String = EngineBootstrap.get_current_build_version_string()
	var prior_version: String = EngineBootstrap.get_prior_build_version_string()

	var _assemble_and_hash := func(version_str: String) -> PackedByteArray:
		var input := xor_ab.duplicate()
		input.append_array(part_c)
		input.append_array(version_str.to_utf8_buffer())
		return _sha256(input)

	# Return fixed-length N=2 array: [current, prior] — ADR-0004 §N=2 is authoritative.
	var result: Array[PackedByteArray] = []
	result.append(_assemble_and_hash.call(current_version))
	result.append(_assemble_and_hash.call(prior_version))
	return result


# ---------------------------------------------------------------------------
# Signal callbacks (stubs — bodies in later stories)
# ---------------------------------------------------------------------------

## Handles [signal TickSystem.flag_suspicious_timestamp_emitted].
##
## Called when TickSystem detects a suspicious backward clock jump on the
## wall clock (beyond [code]rewind_tolerance_seconds[/code]). Increments the
## in-memory [member _tamper_suspicious_count] (saturating at
## [constant MAX_TAMPER_SUSPICIOUS_COUNT] per ADR-0004) so the count survives
## the rest of the session.
##
## NOTE on signal cardinality: TickSystem's [signal flag_suspicious_timestamp_emitted]
## is a once-per-launch signal (Story 007 invariant — guarded by
## TickSystem._flag_suspicious_timestamp). So this handler typically fires at
## most once per process. The saturation cap is a defense-in-depth against
## a future caller that emits the signal directly via a debug hook.
##
## Persistence wiring: when the `_meta` namespace persistence work lands
## (currently a follow-up — Story 009's audit-cascade Status flip didn't
## actually wire `_meta` into the persist `root_dict`), this counter becomes
## the in-memory mirror that gets serialized to `_meta.tamper_suspicious_count`
## and restored on load. Until then, the counter is session-scoped only.
##
## [param previous_ts]: The last trusted wall-clock timestamp (Unix seconds).
##   Currently unused — present for forward-compat with future telemetry that
##   would log the (previous, current) delta.
## [param current_ts]: The current suspicious wall-clock timestamp (Unix seconds).
##   Currently unused (see above).
##
## TR-save-load-025, ADR-0004 §Tamper Response, Story 013 Phase 1.
func _on_flag_suspicious_timestamp_emitted(_previous_ts: int, _current_ts: int) -> void:
	_increment_tamper_count()


## Story 013 Phase 2B — UI-layer entry point for the Both-Corrupt modal
## [Begin] tap (AC-SL-07).
##
## Called by the UI layer when the player taps [Begin] on the
## [signal corrupt_both_modal_required] modal. Synchronously:
##   1. Resets `_meta` private fields to first-launch defaults so the seeded
##      bootstrap state isn't polluted by remembered tamper counters / events.
##   2. Transitions CORRUPT → UNLOADED via direct field write (the state
##      machine's [method _transition_to] table normally rejects CORRUPT as
##      terminal; this player-acknowledged path is the documented exception).
##   3. Emits [signal corrupt_both_acknowledged] so consumers can reset to
##      factory defaults BEFORE the bootstrap load runs.
##   4. Emits [signal first_launch] + [signal load_completed] mirroring the
##      cold-start path in [method request_full_load], advancing state to
##      READY so consumers can apply tutorial defaults.
##
## After this method returns, the system is in READY state with empty in-
## memory state; callers should trigger a [method request_full_persist] on
## the next save-trigger to write the fresh save to disk.
##
## TR-save-load-017, AC-SL-07, ADR-0004 §Both-Corrupt response, Story 013 Phase 2B.
func acknowledge_corrupt_both_begin() -> void:
	if _state != State.CORRUPT:
		push_warning(
			"SaveLoadSystem.acknowledge_corrupt_both_begin: state=%d not CORRUPT — " % _state +
			"call ignored. This API is only legal after corrupt_both_modal_required."
		)
		return
	# Reset _meta to first-launch defaults — the corrupted save's counters
	# and events are not trustworthy, and the player has explicitly opted into
	# starting over.
	_tamper_suspicious_count = 0
	_pending_flags_bit0_tamper = false
	_meta_slot_index = 0
	_meta_save_sequence_number = 0
	var empty_events: Array[int] = []
	_meta_backup_restore_events = empty_events
	# Direct field write to bypass _transition_to's CORRUPT-terminal guard.
	# This is the documented exception per AC-SL-07: player-acknowledged
	# recovery from a state otherwise considered terminal.
	_state = State.UNLOADED
	corrupt_both_acknowledged.emit()
	# Run the cold-start bootstrap path (mirrors request_full_load's
	# first-launch branch). Transitions UNLOADED → LOADING → READY and emits
	# first_launch + load_completed.
	_transition_to(State.LOADING)
	_transition_to(State.READY)
	first_launch.emit()
	load_completed.emit("corrupt_both_begin_bootstrap")


## Story 013 — UI-layer entry point for the HMAC tamper modal "Yes" tap.
##
## Called by the UI layer (PresentationRoot or the modal owner) when the
## player taps "Yes" on the cozy HMAC tamper modal. Per AC, the actions
## taken here MUST complete synchronously BEFORE the modal dismiss so the
## on-disk state reflects the player's acknowledgement before they can
## interact with anything else.
##
## Synchronous side-effects:
##   1. [member _tamper_suspicious_count] increments (saturating at
##      [constant MAX_TAMPER_SUSPICIOUS_COUNT]).
##   2. [member _pending_flags_bit0_tamper] is set to [code]true[/code] so
##      the next [method request_full_persist] writes FLAGS.bit0 = 1 in the
##      envelope header. (Header-write wiring is a follow-up slice; the
##      pending intent is captured here for now.)
##
## NOTE on idempotency: if the UI calls this twice (e.g., a stuck-double-tap
## on a slow device), the counter increments twice. This is acceptable per
## ADR-0004 — the saturation cap prevents abuse, and a one-extra-tick on
## the player's count is a graceful failure mode vs. trying to dedupe modal
## tap events.
##
## Example (UI layer):
##   [codeblock]
##   modal.yes_pressed.connect(func(): SaveLoadSystem.acknowledge_tamper_modal_yes())
##   [/codeblock]
##
## TR-save-load-025, TR-save-load-026, ADR-0004 §Tamper Response, Story 013 Phase 1.
func acknowledge_tamper_modal_yes() -> void:
	_increment_tamper_count()
	_pending_flags_bit0_tamper = true


## Returns the current in-memory tamper-suspicious counter value.
##
## Read-only accessor for tests and the UI layer (e.g., a future "Modified
## save: tampered N times" diagnostic surface gated by
## [constant SETTINGS_MODIFIED_LABEL_ENABLED]).
##
## ADR-0004 §`_meta` field schema, TR-save-load-025.
func get_tamper_suspicious_count() -> int:
	return _tamper_suspicious_count


## Returns whether the next persist will set FLAGS.bit0 = 1.
##
## Read-only accessor for tests. Returns [code]true[/code] after
## [method acknowledge_tamper_modal_yes] until the next successful persist
## clears the pending flag (header-write wiring is a follow-up slice — until
## then, the flag stays true once set, providing a testable contract for the
## acknowledgement surface).
##
## ADR-0004 §Tamper Response, TR-save-load-026.
func get_pending_flags_bit0_tamper() -> bool:
	return _pending_flags_bit0_tamper


## Internal: increments [member _tamper_suspicious_count] with saturation
## at [constant MAX_TAMPER_SUSPICIOUS_COUNT].
##
## Centralised so both the [signal TickSystem.flag_suspicious_timestamp_emitted]
## handler and [method acknowledge_tamper_modal_yes] route through the same
## saturation logic — neither caller can accidentally exceed the cap.
##
## ADR-0004 §`_meta` field schema saturation rule, TR-save-load-025.
func _increment_tamper_count() -> void:
	if _tamper_suspicious_count < MAX_TAMPER_SUSPICIOUS_COUNT:
		_tamper_suspicious_count += 1


## Story 013 Phase 2 — composes the `_meta` sub-dictionary for persist.
##
## Called by [method request_full_persist] right before JSON-stringification.
## Prunes [member _meta_backup_restore_events] of entries older than the
## escalation window (TR-save-load-017), then snapshots the four `_meta`
## fields into a Dictionary suitable for JSON serialization.
##
## [param now_unix]: Current Unix-second timestamp from TickSystem's cache,
##   used as the prune anchor. May be 0 in test envs without TickSystem; in
##   that case no pruning occurs (window_start becomes negative; all entries
##   are >= it).
##
## ADR-0004 §`_meta` field schema, TR-save-load-017/018/019/025.
func _compose_meta_dict(now_unix: int) -> Dictionary:
	var window_start: int = now_unix - BACKUP_ESCALATION_WINDOW_SECONDS
	var pruned: Array[int] = []
	for ts: int in _meta_backup_restore_events:
		if ts >= window_start:
			pruned.append(ts)
	_meta_backup_restore_events = pruned
	return {
		"slot_index": _meta_slot_index,
		"save_sequence_number": _meta_save_sequence_number,
		"tamper_suspicious_count": _tamper_suspicious_count,
		"backup_restore_events": _meta_backup_restore_events.duplicate(),
	}


## Story 013 Phase 2 — restores `_meta` private fields from a loaded payload.
##
## Called by [method request_full_load] after consumer hydration. Each field
## is restored only if present in [param meta]; missing fields preserve their
## current default (handles old-version saves without `_meta` and forward-
## compatibility with later schema additions). Numeric values flow through
## [code]int()[/code] coercion to handle JSON's TYPE_FLOAT round-trip
## (project memory: `JSON.parse_string` returns floats for whole numbers).
## [code]tamper_suspicious_count[/code] is clamped at load to defend against
## a tampered `_meta` that exceeds [constant MAX_TAMPER_SUSPICIOUS_COUNT].
##
## ADR-0004 §`_meta` field schema, TR-save-load-018/019/025.
func _hydrate_meta_dict(meta: Dictionary) -> void:
	if meta.has("slot_index"):
		_meta_slot_index = int(meta["slot_index"])
	if meta.has("save_sequence_number"):
		_meta_save_sequence_number = int(meta["save_sequence_number"])
	if meta.has("tamper_suspicious_count"):
		var raw_count: int = int(meta["tamper_suspicious_count"])
		_tamper_suspicious_count = clampi(raw_count, 0, MAX_TAMPER_SUSPICIOUS_COUNT)
	if meta.has("backup_restore_events"):
		var raw_events: Variant = meta["backup_restore_events"]
		if raw_events is Array:
			var loaded: Array[int] = []
			for v: Variant in (raw_events as Array):
				loaded.append(int(v))
			_meta_backup_restore_events = loaded


## Story 013 Phase 2 — computes the FLAGS field for the next envelope header.
##
## Returns 1 when [member _pending_flags_bit0_tamper] is true (player
## acknowledged the HMAC tamper modal since last persist), else 0. The
## flag is cleared at the end of [method request_full_persist] after
## [signal save_completed] emits.
##
## ADR-0004 §Tamper Response §Header FLAGS, TR-save-load-026.
func _compute_persist_flags() -> int:
	return 1 if _pending_flags_bit0_tamper else 0


## Story 013 Phase 2 — reads + validates an envelope from disk.
##
## Replicates the MAGIC → VERSION → split → HMAC validation pipeline of
## [method request_full_load] but as a side-effect-free helper. Used by
## the `.bak`-fallback branch in [method request_full_load] to attempt
## recovery from `save_file_path + ".bak"` after the primary `.dat` fails
## HMAC verification. The validation order MUST match ADR-0004 §Validation
## order on load — do not reorder.
##
## [param path]: Absolute or [code]user://[/code]-prefixed path to a save
##   envelope file. Missing files return [code]ok = false[/code] with
##   [code]failure = "missing"[/code].
##
## Returns a Dictionary with keys:
##   [code]ok[/code]              - bool, true when the envelope passed all checks
##   [code]envelope_bytes[/code]  - PackedByteArray, the raw envelope bytes (when ok)
##   [code]error_code[/code]      - int, an Error enum value (OK on success)
##   [code]failure[/code]         - String, one of: "", "missing", "open",
##                                  "magic", "version_future", "payload_length",
##                                  "hmac"
##
## On HMAC pass under prior key (N=2 rotation), this helper does NOT set
## [member _needs_rekey_persist] — that side effect lives on the primary
## load path. The helper is intentionally pure modulo the file read.
##
## ADR-0004 §Validation order on load, §`.bak` fallback, TR-save-load-016/023.
func _load_envelope_from_path(path: String) -> Dictionary:
	var failed_result: Dictionary = {
		"ok": false,
		"envelope_bytes": PackedByteArray(),
		"error_code": ERR_FILE_CORRUPT,
		"failure": "",
	}
	if not FileAccess.file_exists(path):
		failed_result["error_code"] = ERR_FILE_NOT_FOUND
		failed_result["failure"] = "missing"
		return failed_result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		failed_result["error_code"] = FileAccess.get_open_error()
		failed_result["failure"] = "open"
		return failed_result
	var envelope_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	# 1. MAGIC check
	var parsed: Dictionary = _parse_header(envelope_bytes)
	if not parsed.magic_ok:
		failed_result["failure"] = "magic"
		return failed_result
	# 2. VERSION check (forward-version save not migratable here)
	var version: int = int(parsed.version)
	if version > CURRENT_SAVE_VERSION:
		failed_result["failure"] = "version_future"
		return failed_result
	# 3. Split + payload-length cross-check
	var parts: Dictionary = _split_envelope(envelope_bytes)
	if not _validate_payload_length_match(parts):
		failed_result["failure"] = "payload_length"
		return failed_result
	# 4. HMAC against keys[0] then keys[1] (N=2 rotation)
	var tags: Array[PackedByteArray] = _derive_integrity_tags()
	var hmac_input: PackedByteArray = envelope_bytes.slice(0, envelope_bytes.size() - _HMAC_SIZE)
	var expected_current: PackedByteArray = _integrity_wrap(tags[0], hmac_input)
	var matches_current: bool = (parts.footer_tag == expected_current)
	var matches_prior: bool = false
	if not matches_current and tags.size() >= 2:
		var expected_prior: PackedByteArray = _integrity_wrap(tags[1], hmac_input)
		matches_prior = (parts.footer_tag == expected_prior)
	if not (matches_current or matches_prior):
		failed_result["failure"] = "hmac"
		return failed_result
	return {
		"ok": true,
		"envelope_bytes": envelope_bytes,
		"error_code": OK,
		"failure": "",
	}


## Handles [signal SceneManager.scene_boundary_persist].
##
## Sprint 11 S11-M3 — Story 012. Triggers a full persist with the reason
## prefixed [code]"scene_boundary:"[/code] so consumers (telemetry,
## sentinels, debug UI) can distinguish scene-boundary persists from
## heartbeat-triggered persists at the [signal save_completed] subscriber.
##
## SceneManager fires [signal SceneManager.scene_boundary_persist] before
## entering [code]dungeon_run_view[/code] AND after exiting
## [code]victory_moment[/code] (per Sprint 11 S11-M1 / Story 008).
##
## Persist timing — synchronous (Sprint 11 reality, S11-M3b clarification
## 2026-05-05). [method request_full_persist] does file I/O inline
## (FileAccess.open / store_buffer / DirAccess.rename_absolute are all
## synchronous in Godot 4.6). By the time [signal SceneManager.scene_boundary_persist]
## emit returns, this handler has finished AND
## [signal save_completed]/[signal save_failed] has already fired. **No
## SceneManager-side `await` is needed for correctness** under the
## synchronous-I/O architecture. Save/Load GDD Rule 5 row 5
## "async-signal pattern" is forward-looking guidance for a Sprint 12+
## optimization where file I/O moves off the main thread (avoids blocking
## the ~50 ms write duration). For MVP synchronous I/O, the chain is fully
## resolved before emit returns.
##
## In this handler's scope: trigger the full persist with the reason
## propagated. The save_completed / save_failed signal fires from
## [method request_full_persist]'s success / failure paths.
##
## [param reason]: Human-readable label from SceneManager for the boundary
##   event (e.g., "pre_dungeon_entry", "post_victory_exit").
##
## ADR-0007, TR-save-load-032, Story 012 / S11-M3
func _on_scene_boundary_persist(reason: String) -> void:
	request_full_persist("scene_boundary:" + reason)
