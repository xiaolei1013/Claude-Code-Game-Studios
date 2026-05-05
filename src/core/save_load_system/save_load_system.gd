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
##   READY       → PERSISTING    (persist trigger: heartbeat, scene-boundary, graceful-exit)
##   READY       → MIGRATION     (schema version mismatch detected on load)
##   PERSISTING  → READY         (persist completes successfully)
##   PERSISTING  → PERSISTING    (overlap coalesce — drops new trigger + push_warning)
##   CORRUPT     is terminal (no exit transition in MVP)
##   MIGRATION   → LOADING       (migration completes; re-enter load pipeline)
##
## ADR-0003 Amendment #2, TR-save-load-045
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
signal corrupt_both_acknowledged()

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

	# --- SceneManager connection — DEFENSIVE (DEV-2: not yet implemented) ---
	# SceneManager is scheduled for the scene-manager Foundation epic (0/10 done).
	# Absence at boot is expected; connection is deferred with a push_warning.
	# ADR-0007, Sprint 4 deviation note DEV-2 in file header.
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.scene_boundary_persist.connect(_on_scene_boundary_persist)
	else:
		push_warning(
			"SaveLoadSystem._ready: SceneManager not present at /root/SceneManager. " +
			"scene_boundary_persist wiring deferred until scene-manager epic implements its autoload."
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

	# Sprint 11 Story 007a — happy-path implementation. Defers .bak rotation,
	# _meta sub-schema (slot_index / save_sequence_number), FLAGS bit, and
	# cross-tag rekey persistence to Story 007b. Existing primitives provide
	# all the cryptographic + envelope plumbing — this method orchestrates.

	_transition_to(State.PERSISTING)

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

	# 2. Encode the assembled dict to UTF-8 JSON bytes.
	var json_string: String = JSON.stringify(root_dict)
	var plaintext: PackedByteArray = json_string.to_utf8_buffer()

	# 3. Apply XOR mask per ADR-0004 §XOR mask layer (obfuscation, not encryption).
	var mask_seed: PackedByteArray = _derive_mask_seed(CURRENT_SAVE_VERSION)
	var mask: PackedByteArray = _generate_mask(mask_seed, plaintext.size())
	var masked_payload: PackedByteArray = _apply_xor_mask(plaintext, mask)

	# 4. Compose envelope (header + masked_payload + zero-padded HMAC placeholder).
	#    FLAGS = 0 in Story 007a (Story 007b adds FLAGS.bit0 tamper flag handling).
	var envelope: PackedByteArray = _compose_envelope(masked_payload, 0)

	# 5. Compute HMAC over (header + masked_payload) using current-build tag,
	#    then overwrite the zero-padded placeholder in the envelope footer.
	var tags: Array[PackedByteArray] = _derive_integrity_tags()
	var hmac_input: PackedByteArray = envelope.slice(0, envelope.size() - _HMAC_SIZE)
	var hmac: PackedByteArray = _integrity_wrap(tags[0], hmac_input)
	for i: int in _HMAC_SIZE:
		envelope.encode_u8(envelope.size() - _HMAC_SIZE + i, hmac.decode_u8(i))

	# 6. Atomic write: open .tmp, store_buffer with abort-on-false (per Save/Load
	#    GDD Rule 7), close (auto-flush), rename .tmp → final path. The .bak
	#    rotation is deferred to Story 007b.
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
			tick_system.set_last_persist_ts(now_ms_int / 1000)

	# 9. Success: transition back to READY + emit save_completed.
	_transition_to(State.READY)
	save_completed.emit(reason)


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

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Routes state machine transitions with a hardcoded transition table.
##
## Allowed transition table:
##   UNLOADED    → LOADING
##   LOADING     → READY
##   LOADING     → CORRUPT
##   READY       → PERSISTING
##   READY       → MIGRATION
##   PERSISTING  → READY
##   PERSISTING  → PERSISTING  (coalesce — push_warning; drops new trigger)
##   CORRUPT     → (terminal; any next value push_warning + no-op)
##   MIGRATION   → LOADING
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
			allowed = next == State.READY or next == State.CORRUPT
		State.READY:
			allowed = next == State.PERSISTING or next == State.MIGRATION
		State.PERSISTING:
			allowed = next == State.READY
		State.MIGRATION:
			allowed = next == State.LOADING

	if not allowed:
		push_warning(
			"SaveLoadSystem._transition_to: illegal transition %d → %d. " % [_state, next] +
			"Transition ignored."
		)
		return

	_state = next


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
## ADR-0004 §XOR mask derivation, TR-save-load-020
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
## wall clock (beyond rewind_tolerance_seconds). In Story 013, this handler
## sets tamper_flag on the in-flight envelope and emits [signal tamper_detected_on_load].
##
## STUB — body lands in Story 013 (tamper-detection).
##
## [param previous_ts]: The last trusted wall-clock timestamp (Unix seconds).
## [param current_ts]: The current suspicious wall-clock timestamp (Unix seconds).
##
## ADR-0007, TR-save-load-032, Story 013
func _on_flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int) -> void:
	pass  # Story 013 (tamper-detection)


## Handles [signal SceneManager.scene_boundary_persist].
##
## Sprint 11 S11-M3 — Story 012. Triggers a full persist with the reason
## prefixed [code]"scene_boundary:"[/code] so consumers (telemetry,
## sentinels, debug UI) can distinguish scene-boundary persists from
## heartbeat-triggered persists at the [signal save_completed] subscriber.
##
## SceneManager fires [signal SceneManager.scene_boundary_persist] before
## entering [code]dungeon_run_view[/code] AND after exiting
## [code]victory_moment[/code] (per Sprint 11 S11-M1 / Story 008). The
## current emission is synchronous; SceneManager does NOT yet
## [code]await[/code] the [signal save_completed] / [signal save_failed]
## response from this handler. The full async-signal pattern per Save/Load
## GDD Rule 5 row 5 ("scene-boundary persist = async-signal pattern —
## SceneManager `await`s `save_completed`/`save_failed` before committing
## transition") lands when SceneManager's emit-call gets the
## [code]await[/code] pair — that wiring is a SceneManager-side change in
## a follow-up story (S11-M3b).
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
