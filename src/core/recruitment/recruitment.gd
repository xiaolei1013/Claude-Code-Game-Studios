## Recruitment — Sprint 11 S11-X10 / Sprint 12 Story 1 implementation.
##
## Per design/gdd/recruitment-system.md §C.1 + ADR-0015: a thin coordinator
## that chains Economy.try_spend → HeroRoster.add_hero atomically. Owns the
## recruit pool: a deterministic, save-seeded Array[String] of class_ids
## generated via [RandomNumberGenerator] with seed = _save_pool_seed XOR
## _refresh_counter (ADR-0015 §OQ-RC-1 decision).
##
## Refresh cadence (ADR-0015 §OQ-RC-2): hybrid on-clear (free, via
## DungeonRunOrchestrator.floor_cleared_first_time) + paid on-demand (via
## refresh_pool_paid()). No real-time-interval refresh (FOMO + clock-tamper
## attack vector).
##
## Cost-curve interaction (ADR-0015 §OQ-RC-3): GLOBAL per-class. copies_owned
## reads HeroRoster.get_copies_owned(class_id), not a pool-internal counter.
## Same-class pool slots show the same cost.
##
## Save/Load consumer surface persists 3 fields: _save_pool_seed,
## _refresh_counter, _current_pool. _refreshes_today is session-only (resets
## on app boot per ADR-0015 OQ-0015-1 — V1.0 owns daily-reset semantics).
##
## Autoload name is `Recruitment` (rank 12 per ADR-0003 §Autoload Rank Table +
## Amendment #7). Sits between FormationAssignment (rank 11) and
## DungeonRunOrchestrator (rank 14); rank 13 (Hero Leveling) is currently
## VACANT.
##
## Governing GDD: design/gdd/recruitment-system.md
## Governing ADRs: ADR-0015 (pool determinism + refresh + cost), ADR-0013
## (recruit_cost signature), ADR-0012 (HeroRoster.add_hero), ADR-0003
## Amendment #7 (rank 12 lockstep).
##
## NOTE on class_name: omitted to avoid the "class_name hides an autoload
## singleton" parse error. The autoload name `Recruitment` is the canonical
## call-site identifier (`Recruitment.try_recruit(...)`); preload access for
## tests uses the script path. This matches the FormationAssignment +
## AudioRouter pattern. The GDD §C.1 example's `class_name Recruitment` is a
## design-spec stub, not a literal code prescription.
extends Node


# ---------------------------------------------------------------------------
# Public types — per recruitment-system.md §C.1
# ---------------------------------------------------------------------------

## Outcome of a try_recruit() attempt. Maps the failure-path taxonomy from
## §C.3 (atomic transaction discipline) to a single returned enum.
enum RecruitOutcome {
	SUCCESS,                 # Gold spent, hero added, signal emitted.
	INSUFFICIENT_GOLD,       # Economy.try_spend returned false; no mutations.
	ROSTER_FULL,             # HeroRoster.max_roster_size reached; no spend, no add.
	INVALID_POOL_INDEX,      # pool_index out of range; no mutations.
	UNRESOLVABLE_CLASS_ID,   # DataRegistry.resolve("classes", id) returned null;
	                         # no mutations. Also used as the closest non-success
	                         # outcome for the §C.4 add_hero contract-violation
	                         # refund path.
}


# ---------------------------------------------------------------------------
# Tuning knobs — designer-overridable via debug or config (Sprint 12+ tres)
# ---------------------------------------------------------------------------

## Number of class_ids in the pool per refresh. ADR-0015 §G default; the
## tuned value lives in a future recruitment_config.tres (analogous to
## economy_config.tres). MVP value matches the cozy-shop "3 picks" register.
const POOL_SIZE: int = 3

## Paid-refresh cost curve base + multiplier per ADR-0015 §OQ-RC-2:
##   refresh_cost(n) = BASE_REFRESH_COST × (1 + REFRESH_COST_MULT × n)
## where n is _refreshes_today. Examples: n=0 → 100; n=1 → 300; n=5 → 1100.
## Sprint 12+ playtest tunes via config.
const BASE_REFRESH_COST: int = 100
const REFRESH_COST_MULT: float = 2.0


# ---------------------------------------------------------------------------
# Internal state — persisted (3 fields per ADR-0015) + session-only
# ---------------------------------------------------------------------------

## Per-save unique seed. Generated via [method randi] on first launch and
## persisted forever; never changes for the save's lifetime. XOR'd with
## _refresh_counter to drive the pool RNG (cross-save uniqueness guard +
## anti-save-scum). Persisted in get_save_data.
##
## STABLE-FOR-TEST-ACCESS: this private field is asserted directly by the
## skeleton-suite Group G round-trip tests.
var _save_pool_seed: int = 0

## Increments on each pool refresh trigger (free on-clear OR paid on-demand).
## Persisted. The XOR'd seed (_save_pool_seed ^ _refresh_counter) drives the
## RNG so every refresh produces a deterministic-but-distinct pool.
var _refresh_counter: int = 0

## Materialized pool snapshot — Array[String] of class_ids. Persisted (so
## reload-after-close shows the same pool until the next refresh trigger
## fires, per ADR-0015 cozy-UX rationale). Returned by get_recruit_pool() as
## a duplicate (mutation-isolation per AC-RC-10).
var _current_pool: Array[String] = []

## Session-only counter for the paid-refresh cost curve. Resets on app boot
## per ADR-0015 OQ-0015-1 MVP scope (V1.0 daily-reset signal owns the
## midnight-reset semantic). NOT persisted.
var _refreshes_today: int = 0

## Test-injection DI for warning logs per FloorUnlock S11-X1's pattern.
## Production defaults to push_warning; tests override with a capturing
## closure.
var _warning_logger: Callable = func(msg: String) -> void: push_warning(msg)

## Test-injection DI for error logs per FloorUnlock S11-X1's pattern.
var _error_logger: Callable = func(msg: String) -> void: push_error(msg)


# ---------------------------------------------------------------------------
# Signals — per recruitment-system.md §C.1 declaration block
# ---------------------------------------------------------------------------

## Emitted on successful recruit. Subscribers: RecruitScreen (Sprint 12+ UI —
## refresh row states), Telemetry (Sprint 13+ — recruit-event tracking).
##
## Order of operations within try_recruit(): Economy.try_spend completes →
## HeroRoster.add_hero completes → THIS signal emits. By the time subscribers
## handle this signal, gold balance is reduced AND the new hero exists in the
## roster.
##
## Note: this signal is distinct from HeroRoster.hero_recruited (1-arg, takes
## the HeroInstance) — they live on different nodes.
##
## recruitment-system.md §C.1 line 131.
signal hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int)

## Emitted when the recruit pool is refreshed (initial generation,
## refresh_pool() call, refresh_pool_paid() call, or floor_cleared_first_time
## handler). Subscribers: RecruitScreen (re-render rows).
##
## recruitment-system.md §C.1 line 140.
signal pool_refreshed(new_pool: Array[String])


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	# Zero-arg per ADR-0003 Amendment #3.
	pass


## First-launch seed init + initial pool generation + DungeonRunOrchestrator
## subscription per ADR-0015 §OQ-RC-2 (on-clear free refresh).
##
## Per ADR-0003 §Signal SUBSCRIPTION rule: rank 12 → rank 14 forward
## subscription is safe at _ready() time (signal objects exist on Node
## instantiation, before any _ready() fires; [VERIFIED]).
func _ready() -> void:
	# First-launch seed init: if load_save_data has not populated
	# _save_pool_seed (still zero), generate it now. SaveLoadSystem hydrates
	# consumers AFTER _ready in its LOADING state; in test envs without
	# SaveLoadSystem, this runs as the canonical first-launch path.
	if _save_pool_seed == 0:
		_first_launch_seed_init()

	# Initial pool generation (idempotent — sets _current_pool to the
	# RNG-deterministic snapshot for the current seed XOR counter pair).
	if _current_pool.is_empty():
		_regenerate_pool()

	# Subscribe to floor_cleared_first_time for the on-clear free refresh per
	# ADR-0015 §OQ-RC-2. Defensive — if the orchestrator autoload is absent
	# (test env), skip. Per ADR-0003 forward-subscription rule: signal objects
	# exist on Node instantiation; rank 12 → rank 14 connect at _ready is
	# safe.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch != null and orch.has_signal("floor_cleared_first_time"):
		if not orch.floor_cleared_first_time.is_connected(_on_floor_cleared_first_time):
			orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)


# ---------------------------------------------------------------------------
# Public API — per recruitment-system.md §C.1
# ---------------------------------------------------------------------------

## Atomic recruit transaction. Validates → looks up cost → spends gold via
## Economy.try_spend → adds hero via HeroRoster.add_hero → emits
## hero_recruited. Each step is gated; failure at any step returns the
## corresponding RecruitOutcome and performs ZERO mutations after the
## failure point.
##
## See recruitment-system.md §C.3 transaction flow + §C.4 atomic discipline.
##
## [param pool_index]: 0-based index into the current recruit pool. Caller
##   (recruit screen) supplies the index of the row the player tapped.
##
## Returns: [enum RecruitOutcome] enum value.
##
## ADR-0013 §recruit_cost contract; recruitment-system.md §C.4 atomic
## transaction; ADR-0015 §OQ-RC-3 cost-curve interaction.
func try_recruit(pool_index: int) -> RecruitOutcome:
	# STEP 0: Validate pool_index in [0, _current_pool.size()).
	if pool_index < 0 or pool_index >= _current_pool.size():
		_warning_logger.call(
			"Recruitment.try_recruit: pool_index %d out of range [0, %d)"
			% [pool_index, _current_pool.size()]
		)
		return RecruitOutcome.INVALID_POOL_INDEX

	# Snapshot the class_id from the pool BEFORE any mutation (defensive
	# against §E.10 mid-transaction refresh re-entrancy).
	var class_id: String = _current_pool[pool_index]

	# STEP 1: Resolve class_id via DataRegistry per §C.3.
	var data_registry: Node = get_node_or_null("/root/DataRegistry")
	if data_registry == null:
		_error_logger.call(
			"Recruitment.try_recruit: /root/DataRegistry absent — cannot resolve class_id '%s'"
			% class_id
		)
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID
	var class_data: Variant = data_registry.call("resolve", "classes", class_id)
	if class_data == null:
		_error_logger.call(
			"Recruitment.try_recruit: DataRegistry.resolve('classes', '%s') returned null — corrupt pool entry or content patch removed class"
			% class_id
		)
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID

	# STEP 2: Roster-capacity check per §C.3.
	var roster: Node = get_node_or_null("/root/HeroRoster")
	if roster == null:
		_error_logger.call("Recruitment.try_recruit: /root/HeroRoster absent — cannot capacity-check or add")
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID
	var roster_size: int = (roster.call("get_all_heroes") as Array).size()
	var max_size: int = int(roster.call("max_roster_size"))
	if roster_size >= max_size:
		return RecruitOutcome.ROSTER_FULL

	# STEP 3: Cost lookup. Delegates to Economy.recruit_cost per ADR-0013;
	# copies_owned is roster-count per ADR-0015 §OQ-RC-3.
	var economy: Node = get_node_or_null("/root/Economy")
	if economy == null:
		_error_logger.call("Recruitment.try_recruit: /root/Economy absent — cannot cost-lookup or spend")
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID
	var copies_owned: int = int(roster.call("get_copies_owned", class_id))
	var cost: int = int(economy.call("recruit_cost", class_id, copies_owned))
	if cost < 0:
		# ADR-0013 sentinel for unresolvable class. Defensive — should match
		# STEP 1 outcome.
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID

	# STEP 4: Atomic transaction — try_spend first.
	var spend_ok: bool = bool(economy.call("try_spend", cost, "recruit_" + class_id))
	if not spend_ok:
		return RecruitOutcome.INSUFFICIENT_GOLD

	# STEP 4b: add_hero second; refund + return UNRESOLVABLE_CLASS_ID on
	# contract violation (capacity-check passed but add_hero returned null).
	var instance: RefCounted = roster.call("add_hero", class_id) as RefCounted
	if instance == null:
		# Refund gold (Economy.add_gold takes a single amount arg per the
		# actual signature — the GDD example's reason arg is a forward
		# reference to a future Economy API).
		economy.call("add_gold", cost)
		_error_logger.call(
			"Recruitment.try_recruit: HeroRoster.add_hero('%s') returned null after capacity check passed — refunded %d gold. CONTRACT BUG."
			% [class_id, cost]
		)
		return RecruitOutcome.UNRESOLVABLE_CLASS_ID

	# STEP 5: Emit signal AFTER all mutations complete (post-mutation state
	# visible to subscribers per §C.4 ordering).
	var instance_id: int = int(instance.get("instance_id"))
	hero_recruited.emit(instance_id, class_id, cost)
	return RecruitOutcome.SUCCESS


## Returns the current recruit pool as an Array[String] of class_ids. The
## screen reads this to render rows. Order matches the pool_index argument
## to try_recruit. Returns a duplicate to satisfy AC-RC-10 mutation-isolation.
##
## recruitment-system.md §C.1 line 91 + §C.2 ownership rules.
func get_recruit_pool() -> Array[String]:
	return _current_pool.duplicate()


## Returns the number of paid pool refreshes performed this session.
## Read-side convenience accessor for the Recruit Screen UI's
## RefreshPoolButton cost label per Recruit Screen GDD #21 §C.6 step 1.
##
## Pairs with [method refresh_cost] — the screen reads this counter then
## passes it to refresh_cost to compute the player-facing "next refresh
## costs N gold" label without the screen needing to touch the private
## [member _refreshes_today] field.
##
## Session-only — resets to 0 on cold launch (the in-day refresh tally
## restarts each time the player relaunches the app). NOT persisted in
## get_save_data per ADR-0015 §OQ-RC-2 (paid-refresh resets daily-ish via
## the cold-launch boundary).
##
## Sprint 16 S16-N1 — closes Cross-GDD Consistency Sweep 2026-05-07
## §Self-documented gap; matches the existing public-accessor pattern
## ([method get_recruit_pool] / [method get_recruit_cost]).
func get_refreshes_today() -> int:
	return _refreshes_today


## Returns the cost (in gold) for the recruit at pool_index. Read-side
## convenience for screen UI per §C.1 + §D.1. Returns -1 for invalid
## pool_index OR if Economy/Roster autoloads are absent OR if the pool entry
## is unresolvable.
##
## Cost-stability invariant per AC-RC-11 + ADR-0015 §OQ-RC-3 cost-curve
## interaction.
func get_recruit_cost(pool_index: int) -> int:
	if pool_index < 0 or pool_index >= _current_pool.size():
		return -1
	var class_id: String = _current_pool[pool_index]
	var roster: Node = get_node_or_null("/root/HeroRoster")
	var economy: Node = get_node_or_null("/root/Economy")
	if roster == null or economy == null:
		return -1
	var copies_owned: int = int(roster.call("get_copies_owned", class_id))
	return int(economy.call("recruit_cost", class_id, copies_owned))


## Forces a free pool refresh (used by the on-clear floor_cleared signal
## handler + by debug tooling). Sprint 12+ recruit screen uses
## refresh_pool_paid() for the player-facing button. Calling this directly
## from production code outside the signal handler is a design smell — the
## paid path is the visible reroll mechanism.
##
## Increments _refresh_counter (so the new RNG seed differs from the prior
## pool's) + regenerates _current_pool + emits pool_refreshed.
##
## recruitment-system.md §C.1 line 109 + ADR-0015 §OQ-RC-2 cadence.
func refresh_pool() -> void:
	_refresh_counter += 1
	_regenerate_pool()
	pool_refreshed.emit(_current_pool.duplicate())


## Player-driven paid refresh per ADR-0015 §OQ-RC-2 (paid-on-demand cadence).
## Charges refresh_cost(_refreshes_today) gold via Economy.try_spend; on
## insufficient gold, returns false + no refresh + no pool_refreshed signal.
## On success, increments _refreshes_today + delegates to refresh_pool().
##
## Returns true on successful paid refresh, false on insufficient gold OR
## Economy autoload absent.
func refresh_pool_paid() -> bool:
	var economy: Node = get_node_or_null("/root/Economy")
	if economy == null:
		_error_logger.call("Recruitment.refresh_pool_paid: /root/Economy absent — cannot charge")
		return false
	var cost: int = refresh_cost(_refreshes_today)
	var spend_ok: bool = bool(economy.call("try_spend", cost, "recruit_pool_refresh"))
	if not spend_ok:
		return false
	_refreshes_today += 1
	refresh_pool()
	return true


## ADR-0015 §OQ-RC-2 paid-refresh cost curve. Pure function — no state read.
##
## Formula: BASE_REFRESH_COST × (1 + REFRESH_COST_MULT × n)
##
## [param refreshes_today]: how many paid refreshes the player has bought
##   today. MVP "today" resets on app boot.
##
## Returns: gold cost for the next paid refresh.
func refresh_cost(refreshes_today: int) -> int:
	# floori per the linear-with-base curve convention used by Economy
	# recruit_cost / level_cost.
	return int(floor(BASE_REFRESH_COST * (1.0 + REFRESH_COST_MULT * float(refreshes_today))))


# ---------------------------------------------------------------------------
# Save/Load consumer surface — ADR-0015 §Decision schema (3 persisted fields)
# ---------------------------------------------------------------------------

## Per Save/Load Rule 10 + ADR-0015: persists the deterministic-pool state.
##
## Schema:
##   {
##     "save_pool_seed": int,       # generated once on first launch
##     "refresh_counter": int,      # increments per refresh
##     "current_pool": Array[String] # materialized snapshot
##   }
##
## NOT persisted: _refreshes_today (session-only per ADR-0015 OQ-0015-1).
##
## recruitment-system.md §C.6 (superseded by ADR-0015 — schema is no longer
## empty Option A).
func get_save_data() -> Dictionary:
	return {
		"save_pool_seed": _save_pool_seed,
		"refresh_counter": _refresh_counter,
		"current_pool": _current_pool.duplicate(),
	}


## Per Save/Load §C MVP-default-on-missing-key contract: hydrates the 3
## persisted fields; falls back to first-launch init when fields are absent
## (e.g., loading a save written before Recruitment shipped).
##
## Per-field validation: type-guard then assign. Invalid types log a warning
## and use the default (anti-save-tamper resilience).
func load_save_data(d: Dictionary) -> void:
	# save_pool_seed — int. Missing → first-launch init at end of method.
	# JSON.parse_string returns numeric values as TYPE_FLOAT; accept both
	# TYPE_INT and TYPE_FLOAT and cast through int() per the FloorUnlock
	# S11-X1 canonical pattern.
	if d.has("save_pool_seed"):
		var raw_seed: Variant = d["save_pool_seed"]
		if typeof(raw_seed) in [TYPE_INT, TYPE_FLOAT]:
			_save_pool_seed = int(raw_seed)
		else:
			_warning_logger.call(
				"Recruitment.load_save_data: save_pool_seed not numeric (type=%d) — re-initializing"
				% typeof(raw_seed)
			)
			_save_pool_seed = 0  # re-init below

	# refresh_counter — int.
	if d.has("refresh_counter"):
		var raw_counter: Variant = d["refresh_counter"]
		if typeof(raw_counter) in [TYPE_INT, TYPE_FLOAT]:
			_refresh_counter = int(raw_counter)
		else:
			_warning_logger.call(
				"Recruitment.load_save_data: refresh_counter not numeric (type=%d) — defaulting to 0"
				% typeof(raw_counter)
			)
			_refresh_counter = 0

	# current_pool — Array[String]. Per-element type-guard.
	if d.has("current_pool"):
		var raw_pool: Variant = d["current_pool"]
		if raw_pool is Array:
			var validated: Array[String] = []
			for entry: Variant in raw_pool:
				if entry is String:
					validated.append(entry)
			_current_pool = validated
		else:
			_warning_logger.call(
				"Recruitment.load_save_data: current_pool not Array (got %s) — clearing"
				% typeof(raw_pool)
			)
			_current_pool = []

	# First-launch fallback if seed was missing or invalid.
	if _save_pool_seed == 0:
		_first_launch_seed_init()
	# Pool fallback: regenerate if hydration produced an empty pool but seed
	# is present. This handles upgrade-from-pre-Recruitment-saves cleanly.
	if _current_pool.is_empty():
		_regenerate_pool()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Generates _save_pool_seed via [method @GlobalScope.randi]. Called once on
## the canonical first-launch path (pre-load _ready entry) OR from
## load_save_data when the seed field is missing/invalid.
##
## ADR-0015 Decision §OQ-RC-1: the seed is generated fresh at first launch
## and persisted forever. Collision probability ~1 in 4 billion across
## different saves — not security-critical.
func _first_launch_seed_init() -> void:
	# randi() returns a non-zero int with overwhelming probability; loop
	# defensively to avoid the degenerate _save_pool_seed == 0 sentinel.
	while _save_pool_seed == 0:
		_save_pool_seed = randi()


## Regenerates _current_pool deterministically from
## (_save_pool_seed XOR _refresh_counter). Same inputs always produce the
## same output (ADR-0015 §Validation Criteria — two _regenerate_pool calls
## with the same _refresh_counter produce IDENTICAL pools).
##
## Pool composition: random-with-replacement draw of POOL_SIZE active
## class_ids from HeroClassDatabase. Deduplication policy is OQ-0015-2
## (Sprint 12+ Story 4 picks). MVP: with-replacement draw — same class can
## appear twice; the cost-curve interaction (§OQ-RC-3 global per-class)
## means duplicates show the same cost until one is recruited.
##
## Defensive against missing autoloads: if HeroClassDatabase is absent
## (test env), the pool is left empty. Production boot order
## (HeroClassDatabase rank 4 → Recruitment rank 12) guarantees presence.
func _regenerate_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _save_pool_seed ^ _refresh_counter
	rng.state = 0  # explicit per ADR-0015 reproducibility recipe

	var active_class_ids: Array[String] = _get_active_class_ids()
	var new_pool: Array[String] = []
	if active_class_ids.is_empty():
		# Soft degrade in test envs without HeroClassDatabase.
		_current_pool = new_pool
		return

	for _i: int in range(POOL_SIZE):
		var pick_index: int = rng.randi_range(0, active_class_ids.size() - 1)
		new_pool.append(active_class_ids[pick_index])
	_current_pool = new_pool


## Returns the list of active class_ids from DataRegistry. Mirrors
## FloorUnlockSystem's pattern — DataRegistry.get_all_by_type returns the
## resolved Resources directly; class_id comes off each Resource's `id`
## property.
func _get_active_class_ids() -> Array[String]:
	var ids: Array[String] = []
	var data_registry: Node = get_node_or_null("/root/DataRegistry")
	if data_registry == null or not data_registry.has_method("get_all_by_type"):
		return ids
	var all_classes: Array = data_registry.call("get_all_by_type", "classes")
	for cls_v: Variant in all_classes:
		var cls: Resource = cls_v as Resource
		if cls == null:
			continue
		# Filter by status="active" if the field exists; otherwise accept all
		# (defensive against partial Resource definitions in test fixtures).
		if "status" in cls and cls.get("status") != "active":
			continue
		if "id" in cls:
			var id: String = String(cls.get("id"))
			if not id.is_empty():
				ids.append(id)
	return ids


## Free on-clear refresh handler per ADR-0015 §OQ-RC-2 (subscribed at
## _ready). Floor-clear triggers a free pool refresh as a gameplay reward
## for clearing.
##
## Signature matches DungeonRunOrchestrator.floor_cleared_first_time per
## §F dependency reference.
func _on_floor_cleared_first_time(_floor_index: int, _biome_id: String, _losing_run: bool) -> void:
	refresh_pool()
