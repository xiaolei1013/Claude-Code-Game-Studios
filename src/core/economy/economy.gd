extends Node

## Economy — rank-3 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton". The autoload is globally
## accessible as `Economy`; tests that need a fresh instance use
## `preload("res://src/core/economy/economy.gd").new()`.
##
## Owns the gold economy for Lantern Guild: gold balance, lifetime gold
## earned, the monotonic floor-clear ledger, and the offline-replay batch.
## Skeleton: signal declarations and public API stubs only.
## Bodies are filled in by neighbouring stories (003, 004, 005, 006, 010, 012).
##
## ADR-0013: Economy Autoload — State, Public API, Cost Curves, Offline Batch
## ADR-0003: Autoload Rank Table (rank 3; zero-arg _init invariant — Amendment #3)
## ADR-0002: Floor-Clear Bonus Monotonic-Credit Ledger

# ---------------------------------------------------------------------------
# Inline class: OfflineResult
# ---------------------------------------------------------------------------
## Returned by [method compute_offline_batch] after an offline replay pass.
##
## Declared inline per ADR-0013 NOTE #9. Fields are added in Story 010;
## for this skeleton the class is an empty RefCounted shell so
## [method compute_offline_batch] can be correctly typed at declaration time.
##
## ADR-0013 §NOTE #9
class OfflineResult extends RefCounted:
	pass  # fields added in Story 010

# ---------------------------------------------------------------------------
# Constants (structural engineering ceilings — NOT tuning knobs)
# ---------------------------------------------------------------------------

## Hard cap on the gold balance in int64 arithmetic (1 trillion).
##
## This is an engineering ceiling, NOT a tuning knob. It MUST NOT be changed
## without a superseding ADR. All tuning knobs (BASE_DRIP, BASE_RECRUIT,
## FLOOR_CLEAR_BONUS, etc.) live in [EconomyConfig] (`assets/data/config/
## economy_config.tres`) per ADR-0013 §Forbidden Patterns.
##
## ADR-0013 §E.1 — only two constants are allowlisted in this file:
## GOLD_SANITY_CAP and OFFLINE_REPLAY_REASON.
const GOLD_SANITY_CAP: int = 1_000_000_000_000

## Reason string passed to [signal gold_changed] for the single aggregate
## emission after an offline replay batch completes.
##
## Signal consumers (HUD, Return-to-App screen) use this string to
## distinguish offline-batch updates from foreground drip/kill emissions.
## ADR-0013 — only two constants are allowlisted in this file.
const OFFLINE_REPLAY_REASON: String = "offline_replay"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the gold balance changes in any faucet or drain path.
##
## [param new_balance]: Gold balance after the change (clamped to [constant GOLD_SANITY_CAP]).
## [param delta]: Signed delta applied to the balance (positive = gain, negative = spend).
## [param reason]: Human-readable string identifying the source ("add_gold",
##   "offline_replay", etc.). Consumers MUST NOT branch on reason for game-state
##   decisions — use it for display and telemetry only.
##
## SUPPRESSED during offline replay ([member _is_offline_replay] == true).
## One aggregate emission fires after [method compute_offline_batch] completes.
##
## ADR-0013 §Signals — GDD §F
signal gold_changed(new_balance: int, delta: int, reason: String)

## Emitted the FIRST time a floor is cleared within a save lifetime.
##
## [param floor_index]: The floor index (1..5) that was cleared for the first time.
## Emitted at most once per floor per save lifetime. Consumers (achievement
## system, Return-to-App screen) use this for first-clear UI celebrations.
##
## SUPPRESSED during offline replay ([member _is_offline_replay] == true).
##
## ADR-0013 §Signals — ADR-0002 monotonic-credit contract
signal first_clear_awarded(floor_index: int)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Current gold balance in int64. Clamped to [constant GOLD_SANITY_CAP] by
## [method add_gold]. Never goes negative — [method try_spend] guards this.
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — GDD §C.1
var _gold_balance: int = 0

## Cumulative gold earned across all faucets this save lifetime (unbounded int64).
## Does NOT decrease when gold is spent — it is a statistic, not the balance.
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — GDD §C
var _lifetime_gold_earned: int = 0

## Monotonic floor-clear bonus ledger. Keys are floor indices (1..5); values
## are the highest bonus_amount credited for each floor.
##
## ADR-0002 credit-the-gap contract: only amounts EXCEEDING the stored value
## are credited. This prevents double-crediting when the same floor is cleared
## multiple times with different bonus amounts.
##
## Typed [Dictionary][int, int] (Godot 4.4+ syntax — precedent-verified via
## ADR-0009 / ADR-0012 landed usage).
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — ADR-0002
var _floor_clear_bonus_credited: Dictionary[int, int] = {}

## Transient flag: true only during the [method compute_offline_batch] call.
##
## When true, all [signal gold_changed] and [signal first_clear_awarded]
## emissions are suppressed inside [method add_gold] and
## [method try_award_floor_clear] to avoid blowing the 500 ms offline budget
## on signal dispatch (ADR-0013 §C.6 — 230 ms dispatch cost at 576k ticks).
## NOT persisted. Reset to false after compute_offline_batch completes.
## ADR-0013 §Requirements — GDD §C.6
var _is_offline_replay: bool = false

## Resolved EconomyConfig instance from DataRegistry. Populated in _ready().
## Null if DataRegistry has not yet reached READY state (e.g. during boot
## errors). Consumers (Stories 003+) call get_config() rather than reading
## this field directly.
## ADR-0013 §Requirements — single source of truth for tuning knobs.
var _config: EconomyConfig = null

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3.
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on _init would silently fail instantiation.
## Do NOT read or subscribe to other autoloads here — use _ready() instead.
func _init() -> void:
	pass


## Establishes the tick subscription and resolves EconomyConfig at boot.
##
## Rank-3 safety (ADR-0003 Amendment #1): DataRegistry (rank 1) and
## TickSystem (rank 0) have completed their _ready() calls by the time
## Economy's _ready() fires, so signal subscriptions and DataRegistry.resolve()
## calls here are safe.
##
## Resolved at boot below; null-check on miss. Story 006 wires the
## TickSystem.tick_fired subscription and the drip math (still pending).
##
## ADR-0003 Amendment #1, ADR-0013 §Requirements
func _ready() -> void:
	_config = DataRegistry.resolve("config", "economy_config") as EconomyConfig
	if _config == null:
		push_error("Economy._ready: failed to resolve EconomyConfig from DataRegistry. " +
			"DataRegistry should already be in ERROR state if config is missing.")
	# Tick subscription lands in Story 006.

# ---------------------------------------------------------------------------
# Public API — write methods
# ---------------------------------------------------------------------------

## Adds [param amount] gold to the balance and updates lifetime earned.
##
## Positive-only: [param amount] must be > 0; if not, calls [method push_error]
## and returns early without mutating state or emitting a signal.
##
## Sanity-cap-clamped: if [code]_gold_balance + amount > GOLD_SANITY_CAP[/code],
## [member _gold_balance] is set to [constant GOLD_SANITY_CAP]. The [param delta]
## carried by [signal gold_changed] reflects the actual increment applied to the
## balance, not the requested amount.
##
## Lifetime-unclamped: [member _lifetime_gold_earned] always increases by the full
## requested [param amount], regardless of clamp. It is an unbounded faucet statistic.
##
## Signal-suppressed during offline replay: when [member _is_offline_replay] is
## [code]true[/code], state mutations occur silently. One aggregate [signal gold_changed]
## fires after [method compute_offline_batch] completes (Story 010).
##
## Example:
##   Economy.add_gold(500)  # adds 500 to the gold balance
##
## ADR-0013 §Requirements — GDD §C.2, §D.1, §D.2
func add_gold(amount: int) -> void:
	if amount <= 0:
		push_error("Economy.add_gold: amount=%d must be positive" % amount)
		return
	var actual_delta: int = amount
	var projected: int = _gold_balance + amount
	if projected > GOLD_SANITY_CAP:
		actual_delta = GOLD_SANITY_CAP - _gold_balance
		_gold_balance = GOLD_SANITY_CAP
	else:
		_gold_balance = projected
	_lifetime_gold_earned += amount  # statistic — unclamped; takes the requested amount even if balance clamped
	if not _is_offline_replay:
		gold_changed.emit(_gold_balance, actual_delta, "add_gold")


## Attempts to deduct [param amount] gold from the balance atomically.
##
## Atomic: either the full deduction succeeds (returns [code]true[/code]) or
## nothing changes (returns [code]false[/code]). No partial mutations.
## Atomicity is guaranteed by GDScript's single-threaded main loop (ADR-0013 §E.6).
##
## Semantics:
## - [b]Negative amount[/b]: calls [method push_error] and returns [code]false[/code];
##   balance and signal are both unchanged.
## - [b]Zero amount[/b]: defined no-op — returns [code]true[/code] immediately;
##   no state mutation, no [signal gold_changed] emission (AC H-12).
## - [b]Insufficient balance[/b]: returns [code]false[/code]; no state mutation,
##   no signal (AC H-05).
## - [b]Sufficient balance[/b]: deducts [param amount] from [member _gold_balance],
##   emits [signal gold_changed]([code]_gold_balance, -amount, reason[/code]) UNLESS
##   [member _is_offline_replay] is [code]true[/code], and returns [code]true[/code]
##   (AC H-06).
##
## Signal-suppressed during offline replay: when [member _is_offline_replay] is
## [code]true[/code], the state mutation occurs silently. One aggregate
## [signal gold_changed] fires after [method compute_offline_batch] completes (Story 010).
##
## Note: [method try_spend] does NOT update [member _lifetime_gold_earned].
## That statistic tracks income only, not spending (ADR-0013 §State).
##
## [param amount]: Gold to spend. Must be >= 0.
## [param reason]: Telemetry label identifying the spend site (e.g. "recruit",
##   "level_up"). Propagated verbatim into [signal gold_changed]'s third argument.
##
## Example:
##   if Economy.try_spend(150, "recruit"):
##       HeroRoster.add_hero("warrior")
##
## ADR-0013 §Requirements — GDD §C.3, §H-05, §H-06, §H-12, §E.6
func try_spend(amount: int, reason: String) -> bool:
	if amount < 0:
		push_error("Economy.try_spend: amount=%d must be non-negative" % amount)
		return false
	if amount == 0:
		return true  # no-op true; no signal, no mutation (AC H-12)
	if _gold_balance < amount:
		return false  # insufficient — no signal, no mutation (AC H-05)
	_gold_balance -= amount
	if not _is_offline_replay:
		gold_changed.emit(_gold_balance, -amount, reason)
	return true


## Awards a floor-clear bonus using the monotonic-credit-gap contract.
##
## Returns [code]true[/code] if any new gold was credited; [code]false[/code]
## if [param bonus_amount] is at or below the previously credited amount for
## this floor (no double-credit, per ADR-0002).
##
## Credit-the-gap semantic: only the DELTA above [member _floor_clear_bonus_credited]
## is added via [method add_gold]. This supports the LOSING-then-WIN reclaim path:
## a LOSING run credits the halved bonus first; a subsequent WIN credits only the
## remaining gap. The first-clear milestone ([signal first_clear_awarded]) fires only
## on the initial credit for each floor (when [code]already == 0[/code]) and is NOT
## re-emitted on reclaim deltas — the milestone already fired on the first credit.
##
## At-or-below-ceiling paths (zero-bonus, repeat-WIN, LOSING-after-WIN) return
## [code]false[/code] silently with no state mutation.
##
## [param floor_index]: Floor index (1..5). Out-of-range values call [method push_error]
##   and return [code]false[/code] without mutating the ledger.
## [param bonus_amount]: Total bonus to credit for this floor. Must be >= 0.
##   Negative values call [method push_error] and return [code]false[/code].
##   The DELTA above the stored ceiling is added via [method add_gold].
##
## Signal suppression: [signal first_clear_awarded] is suppressed when
##   [member _is_offline_replay] is [code]true[/code]. [method add_gold] already
##   self-suppresses [signal gold_changed] during offline replay.
##
## Example:
##   Economy.try_award_floor_clear(2, 1200)  # credits F2 first-clear bonus
##
## ADR-0013 §Requirements — ADR-0002 monotonic-credit contract — GDD §C.4, §D.5
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool:
	if floor_index < 1 or floor_index > 5:
		push_error("Economy.try_award_floor_clear: floor_index=%d out of range [1,5]" % floor_index)
		return false
	if bonus_amount < 0:
		push_error("Economy.try_award_floor_clear: bonus_amount=%d is negative (authoring bug)" % bonus_amount)
		return false
	var already: int = _floor_clear_bonus_credited.get(floor_index, 0)
	if bonus_amount <= already:
		return false  # at-or-below ceiling; covers zero-bonus, repeat-WIN, LOSING-after-WIN
	var delta: int = bonus_amount - already
	var is_first: bool = already == 0  # captured before add_gold mutates any state
	add_gold(delta)  # routes through the canonical mutation site; updates lifetime
	_floor_clear_bonus_credited[floor_index] = bonus_amount
	if is_first and not _is_offline_replay:
		first_clear_awarded.emit(floor_index)
	return true


## Computes the full offline gold batch for [param tick_budget] ticks.
##
## Sets [member _is_offline_replay] to true for signal suppression during replay,
## computes drip + kill totals via closed-form math, calls [method add_gold] and
## [method try_award_floor_clear] as needed, then emits one aggregate
## [signal gold_changed] after replay completes.
##
## Returns an [OfflineResult] with totals and event log. Returns [code]null[/code]
## for this skeleton (real OfflineResult fields land in Story 010).
##
## STUB — returns [code]null[/code]. Real batch logic lands in Story 010.
##
## [param tick_budget]: Number of offline ticks to replay (capped upstream by
##   TickSystem.offline_cap_seconds × TICKS_PER_SECOND).
##
## Example:
##   var result: Economy.OfflineResult = Economy.compute_offline_batch(3600 * 20)
##
## ADR-0013 §Requirements — GDD §C.5, §C.6, §D.6 — ADR-X02
func compute_offline_batch(tick_budget: int) -> OfflineResult:
	return null  # Story 010


## Returns the economy state for serialisation by SaveLoadSystem.
##
## Keys (fixed insertion order per ADR-0004):
##   "gold_balance" → [member _gold_balance]
##   "lifetime_gold_earned" → [member _lifetime_gold_earned]
##   "floor_clear_bonus_credited" → [member _floor_clear_bonus_credited]
##
## [member _is_offline_replay] is NOT included — it is transient.
##
## STUB — returns [code]{}[/code]. Real serialisation body lands in Story 012.
##
## Example:
##   var data: Dictionary = Economy.get_save_data()
##   # data == {"gold_balance": 500, "lifetime_gold_earned": 1200, "floor_clear_bonus_credited": {1: 500}}
##
## ADR-0013 §Requirements — ADR-0004 consumer contract
func get_save_data() -> Dictionary:
	return {}  # Story 012


## Restores economy state from a SaveLoadSystem envelope.
##
## Reads the 3 persisted keys with safe defaults (0 / 0 / {}).
## Clamps gold_balance to [constant GOLD_SANITY_CAP] on load (push_warning on
## invalid). MUST NOT emit [signal gold_changed] (ADR-0004 signal-suppression
## during boot validation).
##
## STUB — empty body. Real deserialisation + validation body lands in Story 012.
##
## [param data]: Dictionary as returned by [method get_save_data].
##
## Example:
##   Economy.load_save_data({"gold_balance": 500, "lifetime_gold_earned": 1200,
##       "floor_clear_bonus_credited": {1: 500}})
##
## ADR-0013 §Requirements — ADR-0004 consumer contract
func load_save_data(data: Dictionary) -> void:
	pass  # Story 012

# ---------------------------------------------------------------------------
# Public API — read methods (display surfaces)
# ---------------------------------------------------------------------------

## Returns the current gold balance.
##
## Read-only accessor for display surfaces (HUD, recruit button grey-out).
## Always call this rather than reading [member _gold_balance] directly from
## outside this script.
##
## Example:
##   label.text = str(Economy.get_gold_balance())
##
## ADR-0013 §Requirements — GDD §C.1
func get_gold_balance() -> int:
	return _gold_balance


## Returns the cumulative lifetime gold earned (unbounded statistic).
##
## Useful for analytics and "total gold earned" achievement tracking.
## Never decreases — it is not the current balance.
##
## Example:
##   var lifetime: int = Economy.get_lifetime_gold_earned()
##
## ADR-0013 §Requirements
func get_lifetime_gold_earned() -> int:
	return _lifetime_gold_earned


## Returns [code]true[/code] if the first-clear bonus for [param floor_index]
## has already been credited this save lifetime.
##
## Reads the [member _floor_clear_bonus_credited] ledger: a floor is considered
## first-cleared when its stored value is > 0 (ADR-0002 monotonic invariant).
## Presentation layer uses this to decide whether to show the "first clear!"
## celebration overlay on the floor card.
##
## [param floor_index]: Floor index to check (1..5).
##
## Example:
##   if Economy.is_first_clear_awarded(3):
##       show_first_clear_badge(3)
##
## ADR-0013 §Requirements — ADR-0002
func is_first_clear_awarded(floor_index: int) -> bool:
	return _floor_clear_bonus_credited.get(floor_index, 0) > 0


## Returns the resolved [EconomyConfig] instance or [code]null[/code] if
## DataRegistry failed to load it. Stories 003+ use this to read tuning knobs;
## consumers must null-check (DataRegistry should have already errored if
## the config is missing, but defensive checks remain valuable).
##
## Example:
##   var cfg: EconomyConfig = Economy.get_config()
##   if cfg != null:
##       var drip: int = cfg.BASE_DRIP[floor_index - 1]
##
## ADR-0013 §Requirements
func get_config() -> EconomyConfig:
	return _config

# ---------------------------------------------------------------------------
# Cost curve queries (pure functions — no state mutation)
# ---------------------------------------------------------------------------

## Returns the gold cost to recruit one more copy of [param class_id] given
## that [param copies_owned] copies are already owned.
##
## Formula: floori(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)
## (from EconomyConfig — resolved from DataRegistry in Story 002).
##
## Returns -1 if [param class_id] cannot be resolved (push_error on miss).
## STUB — returns [code]0[/code]. Real formula lands in Story 007.
##
## [param class_id]: Snake-case class identifier (e.g. "warrior_t1").
## [param copies_owned]: Number of copies already in the roster.
##
## Example:
##   var cost: int = Economy.recruit_cost("warrior_t1", 2)
##
## ADR-0013 §Requirements — GDD §D.3
func recruit_cost(class_id: String, copies_owned: int) -> int:
	return 0  # Story 007


## Returns the gold cost to level [param class_tier] hero from [param current_level].
##
## Formula: floori(BASE_LEVEL[class_tier] × LEVEL_RATIO^(current_level - 1))
## (from EconomyConfig — resolved from DataRegistry in Story 002).
##
## Returns -1 (sentinel) if [param current_level] >= LEVEL_CAP (past cap).
## STUB — returns [code]0[/code]. Real formula + sentinel logic lands in Story 008.
##
## [param class_tier]: Hero class tier (1..2).
## [param current_level]: Hero's current level (1..LEVEL_CAP).
##
## Example:
##   var cost: int = Economy.level_cost(1, 5)
##
## ADR-0013 §Requirements — GDD §D.4, §H-08
func level_cost(class_tier: int, current_level: int) -> int:
	return 0  # Story 008
