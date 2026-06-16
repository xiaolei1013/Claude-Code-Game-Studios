## DefaultCombatResolver — production impl of [CombatResolver].
##
## Sprint 7 Story M7 (replaces the Sprint 6 stub authored in S6-M8). This
## story implements the `action_cooldown_ticks` formula; subsequent Stories
## (S7-M8 DPS+HP, S7-M9 kill schedule, S7-M10 emit_events_in_range, S7-M11
## matchup-cache DI) build out the full resolver pipeline incrementally.
##
## Stateless invariant (TR-combat-001 + TR-027):
##   - Zero class-scope `var` declarations.
##   - Zero `signal` declarations.
##   - All tuning values fetched from CombatConfig at call time (no caching
##     across calls — keeps the resolver instance reusable across dispatches
##     even if the config is hot-reloaded mid-session).
##   - No RNG, no time-dependent reads, no float accumulation across calls.
##
## ADR-0010: Combat Resolver Snapshot + Parity
## ADR-0013: Single-source-of-truth tuning knobs (CombatConfig)
extends CombatResolver

const _STUB_MARKER: String = "DefaultCombatResolver — Sprint 7 production impl"

## Fallback SPEED_BASE used when DataRegistry cannot resolve combat_config
## (e.g., test environments where the config category isn't populated).
## Kept == the CombatConfig default (Phase 2: 90) so the resolve path and the
## fallback path agree; cooldown_formula_test Group G guards against drift.
const _FALLBACK_SPEED_BASE: int = 90


func _init() -> void:
	# No-op constructor — instance class with zero state.
	# Production wiring lazy-default-news this from DungeonRunOrchestrator._ready
	# per ADR-0003 Amendment #3 (autoload zero-arg invariant propagates to
	# the resolver instances orchestrator instantiates).
	pass


## Diagnostic accessor preserved from the Sprint 6 stub for the orchestrator's
## autoload_skeleton_and_di_test which checks `resolver.is_stub()` to verify
## the lazy-default produced a DefaultCombatResolver. The marker text now
## reflects the production-impl status; the substring "DefaultCombatResolver"
## remains for that test's `assert_str(...).contains(...)` predicate.
func is_stub() -> String:
	return _STUB_MARKER


## Computes the per-action cooldown (in ticks) for an actor with the given
## [param speed]. Used by Combat's kill-schedule arithmetic (Story 005)
## and exposed publicly so tests + UI can preview cooldown without going
## through the full schedule walk.
##
## Formula (TR-combat-005 + TR-combat-032):
##   - [param speed] <= 0 → returns 1 (pre-guard against div-by-zero / negative
##     cooldowns; clamps invalid speeds to the minimum-cooldown floor).
##   - Otherwise → [code]maxi(1, floori(SPEED_BASE / speed))[/code].
##     Result is bounded [1, SPEED_BASE]:
##       - speed=1 → SPEED_BASE (slowest unit; one action per SPEED_BASE ticks)
##       - speed=SPEED_BASE → 1 (one action per tick)
##       - speed > SPEED_BASE → still clamps to 1 (the maxi() floor)
##
## All integer arithmetic via [code]floori()[/code] / [code]maxi()[/code]
## (TR-combat-011: zero float intermediates leak into output).
##
## SPEED_BASE source: [code]DataRegistry.resolve("config", "combat_config")[/code]
## at call time. When config can't be resolved (e.g., unit-test env where
## DataRegistry is in ERROR), falls back to [constant _FALLBACK_SPEED_BASE]
## (= 90, the calibrated run-duration default per ADR-0021 Phase 2 — see
## [code]combat_config.tres[/code] SPEED_BASE=90). The fallback is silent — no push_warning —
## because per-call DataRegistry probing in a hot path would flood logs.
##
## TR-combat-005 / TR-combat-011 / TR-combat-032 — ADR-0010
func action_cooldown_ticks(speed: int) -> int:
	if speed <= 0:
		return 1
	var speed_base: int = _resolve_speed_base()
	return maxi(1, floori(float(speed_base) / float(speed)))


## Internal helper: fetches SPEED_BASE from CombatConfig with silent fallback.
##
## Returns [constant _FALLBACK_SPEED_BASE] when DataRegistry can't resolve the
## combat_config resource (test envs, missing config). Production paths
## (DataRegistry READY, combat_config.tres present) return the @export value.
##
## Duck-typed read via [code]"SPEED_BASE" in cfg[/code] + [code]cfg.get("SPEED_BASE")[/code]
## avoids referencing the [code]CombatConfig[/code] class_name at parse time
## (Sprint 6 autoload-cache lesson: class_name references in stateless
## utility code are fine, but this also keeps the resolver tolerant of
## CombatConfig schema mutations during development).
func _resolve_speed_base() -> int:
	var cfg: Resource = DataRegistry.resolve("config", "combat_config")
	if cfg == null or not ("SPEED_BASE" in cfg):
		return _FALLBACK_SPEED_BASE
	return int(cfg.get("SPEED_BASE"))


## Computes raw formation damage-per-tick at DISPATCHING. Pure function over
## the formation snapshot — no mutation of inputs, no caching across calls.
##
## Formula (TR-combat-006): [code]sum(hero.attack(level) × hero.speed(level)) / SPEED_BASE[/code].
## Output range for MVP heroes (FORMATION_SIZE=3, max attack ≤ 11, max speed ≤ 7,
## SPEED_BASE=10): [0.0, 2.31].
##
## Empty formation returns 0.0 and emits [code]push_warning("[CombatResolver]
## empty formation")[/code] (TR-019). Heroes with unresolvable [code]class_id[/code]
## (DataRegistry returns null) contribute 0; if [param error_logger] is a valid
## Callable, the logger is invoked with a per-hero diagnostic message (TR-020).
## Silent skip remains the production default — pass [code]Callable()[/code]
## (the empty default) to suppress logging.
##
## TR-combat-006 / TR-019 / TR-020 — ADR-0010 §D.2 + Story 009
func formation_dps_per_tick(formation: Array, error_logger: Callable = Callable()) -> float:
	if formation.is_empty():
		push_warning("[CombatResolver] empty formation")
		return 0.0
	var raw_sum: int = 0
	for hero: Variant in formation:
		if hero == null or not ("class_id" in hero) or not ("current_level" in hero):
			continue
		var class_id: String = str(hero.get("class_id"))
		var class_data: Resource = DataRegistry.resolve("classes", class_id)
		if class_data == null or not class_data.has_method("stat_at_level"):
			# TR-020: silently skip; if logger is wired, invoke it with diagnostic.
			if error_logger.is_valid():
				error_logger.call(
					"[CombatResolver] formation_dps_per_tick: unresolvable class_id '%s'"
					% class_id
				)
			continue
		var level: int = int(hero.get("current_level"))
		var attack: int = int(class_data.call("stat_at_level", HeroClass.Stat.ATTACK, level))
		var speed: int = int(class_data.call("stat_at_level", HeroClass.Stat.SPEED, level))
		raw_sum += attack * speed
	# Float division for the final scaling — output is float by spec, but the
	# accumulator above is integer to honor TR-011 (no float intermediates).
	var speed_base: int = _resolve_speed_base()
	return float(raw_sum) / float(speed_base)


## Computes formation total HP at DISPATCHING. Pure function helper that
## yields the shared party HP pool consumed by the two-sided HP race in
## [method compute_run_outcome] (GDD #34 §D). Sums [code]stat_at_level(HP, level)[/code]
## across the formation; null class_data heroes contribute 0.
##
## Empty formation returns 0. Optional [param error_logger] follows the same
## DI contract as [method formation_dps_per_tick]: if Callable.is_valid() the
## logger is invoked with a per-hero diagnostic for unresolvable class_ids
## (TR-020). Default Callable() suppresses logging.
##
## (Not a TR-numbered requirement directly; building block for TR-008.)
func formation_total_hp(formation: Array, error_logger: Callable = Callable()) -> int:
	if formation.is_empty():
		return 0
	var total: int = 0
	for hero: Variant in formation:
		if hero == null or not ("class_id" in hero) or not ("current_level" in hero):
			continue
		var class_id: String = str(hero.get("class_id"))
		var class_data: Resource = DataRegistry.resolve("classes", class_id)
		if class_data == null or not class_data.has_method("stat_at_level"):
			if error_logger.is_valid():
				error_logger.call(
					"[CombatResolver] formation_total_hp: unresolvable class_id '%s'"
					% class_id
				)
			continue
		var level: int = int(hero.get("current_level"))
		total += int(class_data.call("stat_at_level", HeroClass.Stat.HP, level))
	return total


## Computes effective per-enemy kill DPS from the dispatch-time raw DPS and the
## matchup-throughput multiplier (advantage or disadvantage from the snapshot's
## matchup_cache).
##
## Formula (TR-combat-007, GDD #34 §C.3 — Phase 1 removed the survival-throttle
## term): [code]effective_dps = raw_dps * matchup_throughput_factor[/code].
##
## Both inputs are floats; the product is float. This is a pure-function scaling
## step — no rounding here (rounding happens in [method ticks_to_kill]). The
## party's survival is now resolved separately by the two-sided HP race in
## [method compute_run_outcome] rather than folded into the kill rate.
##
## TR-combat-007 — ADR-0010 §D.4 / ADR-0021
func effective_dps(raw_dps: float, matchup_throughput_factor: float) -> float:
	return raw_dps * matchup_throughput_factor


## Computes how many ticks it takes to kill an enemy with [param base_hp]
## given a sustained per-tick damage of [param effective_dps_value].
##
## Formula (TR-combat-010): [code]ticks_to_kill = ceili(base_hp / effective_dps)[/code]
## with a floor of 1 (TR-combat-025: no instant-kill tick-0 events).
##
## Edge cases:
##   - [param effective_dps_value] <= 0 → returns a large sentinel (10000).
##     Defensive against zero-DPS formations (every-hero-unresolvable case);
##     callers that hit this should be auditing their dispatch validation.
##   - [param base_hp] <= 0 → returns 1 (instant-kill enemies still take
##     one tick to register a KillEvent).
##
## All integer arithmetic via [code]ceili[/code] (TR-combat-011: zero float
## accumulation across calls — the float division here is local, not stored).
##
## TR-combat-010 / TR-combat-011 / TR-combat-025 — ADR-0010 §D.4
func ticks_to_kill(base_hp: int, effective_dps_value: float) -> int:
	if effective_dps_value <= 0.0:
		# Defensive sentinel: a zero-DPS formation never kills anything.
		# Callers (Story 010 perf bench, Story 003 dispatch validation)
		# should reject this state earlier; we return a large finite int
		# rather than infinity so downstream tick math doesn't blow up.
		return 10000
	if base_hp <= 0:
		return 1
	# ceili(base_hp / effective_dps); maxi(1, ...) guarantees TR-025 floor.
	return maxi(1, ceili(float(base_hp) / effective_dps_value))


## Walks the snapshot's enemy_list ONCE and returns a per-enemy kill schedule.
##
## Each schedule entry is a [Dictionary] with these keys:
##   - [code]kill_tick[/code] (int): cumulative absolute tick (from
##     [code]snapshot.dispatched_at_tick[/code]) at which the enemy dies.
##     Always >= [code]dispatched_at_tick + 1[/code] (TR-025).
##   - [code]enemy_id[/code] (StringName): from the enemy_list entry.
##   - [code]archetype[/code] (StringName): from the enemy_list entry.
##   - [code]tier[/code] (int): from the enemy_list entry.
##   - [code]is_boss[/code] (bool): from the enemy_list entry — propagates
##     per-entry regardless of queue position (TR-028).
##
## Per-enemy effective_dps is computed by:
##   1. Looking up archetype in [code]snapshot.matchup_cache[/code] —
##      [code]true[/code] → use [code]MATCHUP_THROUGHPUT_FACTOR_ADV[/code];
##      [code]false[/code] (or absent) → [code]MATCHUP_THROUGHPUT_FACTOR_DIS[/code].
##   2. Multiplying [code]snapshot.formation_dps_per_tick * factor[/code].
##
## Schedule preserves [code]snapshot.enemy_list[/code] ordering — never
## reorders. Cumulative tick math anchors on [code]snapshot.dispatched_at_tick[/code]
## (TR-026: closed-form schedule is time-anchored; clock-rewind / frame-drop
## recovers via the range arg passed to [method emit_events_in_range]).
##
## TR-combat-007 / TR-combat-010 / TR-combat-011 / TR-combat-025 / TR-combat-028 — ADR-0010 §D.4
func _kill_schedule_for_loop(snapshot: CombatRunSnapshot) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	if snapshot == null or snapshot.enemy_list.is_empty():
		return schedule

	var raw_dps: float = snapshot.formation_dps_per_tick
	var factor_adv: float = _resolve_throughput_factor_adv()
	var factor_dis: float = _resolve_throughput_factor_dis()
	var cumulative_tick: int = snapshot.dispatched_at_tick

	for entry: Dictionary in snapshot.enemy_list:
		var archetype: StringName = entry.get("archetype", &"") as StringName
		var advantaged: bool = bool(snapshot.matchup_cache.get(archetype, false))
		var factor: float = factor_adv if advantaged else factor_dis
		var ed: float = effective_dps(raw_dps, factor)
		var base_hp: int = int(entry.get("base_hp", 0))
		var ttk: int = ticks_to_kill(base_hp, ed)
		cumulative_tick += ttk
		schedule.append({
			"kill_tick": cumulative_tick,
			"enemy_id": entry.get("id", &"") as StringName,
			"archetype": archetype,
			"tier": int(entry.get("tier", 1)),
			"is_boss": bool(entry.get("is_boss", false)),
		})

	return schedule


## Computes the WIN / DEFEAT verdict for a single dungeon run — the two-sided
## HP race of GDD #34 §D. This is the SINGLE SOURCE OF TRUTH for the verdict:
## both the foreground dispatch path and the offline batch path call it, so
## the outcome is identical across both (parity by construction, ADR-0021).
##
## Model (GDD #34 §D):
##   - The party kills enemies SEQUENTIALLY via focus-fire — enemy `j` dies at
##     `rel_death[j] = Σ_{k<=j} ticks_to_kill(k)` (cumulative, relative to
##     dispatch), exactly as produced by [method _kill_schedule_for_loop].
##   - `T_clear` = the last enemy's relative death tick = the single-loop floor
##     clear.
##   - Each still-alive enemy deals
##     `dmg_rate[j] = (base_attack * base_speed) / SPEED_BASE * MATCHUP_PARTY_DISADVANTAGE`
##     per tick to the shared party HP pool.
##   - `party_damage_by(T) = Σ_j dmg_rate[j] * min(T, rel_death[j])`.
##   - DEFEAT iff `∃ T < T_clear: party_damage_by(T) >= party_hp`, else WIN.
##     Because `party_damage_by` is monotone non-decreasing in `T`, the
##     existence check collapses to evaluating at `T = T_clear - 1`.
##
## Single-loop scope: party HP resets each loop (GDD §E.3) and all loops are
## identical, so the run verdict equals the single-loop verdict — a party that
## survives one loop survives all; a party that wipes does so in loop 1. The
## verdict is therefore computed over the one-loop schedule.
##
## Tie rule (GDD §E.2): if party HP and the last enemy reach 0 on the SAME tick,
## the party WINS. This falls out automatically — the verdict is evaluated
## strictly before `T_clear` (at `T_clear - 1`), so damage landing exactly at
## the clear tick does not count as a defeat.
##
## Edge cases:
##   - null / empty enemy_list / empty schedule → trivial WIN (no threat).
##   - `T_clear <= 1` → no time elapses before the clear → WIN regardless of
##     enemy attack (even a lethal floor cannot land a tick of damage).
##   - `party_hp <= 0` (degenerate / unplumbed formation) → DEFEAT on the first
##     damaging tick.
##
## GDD #34 §D — ADR-0021
func compute_run_outcome(snapshot: CombatRunSnapshot) -> CombatRunOutcome:
	var outcome: CombatRunOutcome = CombatRunOutcome.new()
	if snapshot == null:
		return outcome  # default: won=true, clear_tick=0, defeat_tick=-1

	var dispatched_at: int = snapshot.dispatched_at_tick
	outcome.clear_tick = dispatched_at

	var schedule: Array[Dictionary] = _kill_schedule_for_loop(snapshot)
	if schedule.is_empty():
		# No enemies / unkillable formation → no race → trivial win.
		return outcome

	var party_hp: float = float(snapshot.formation_total_hp)

	# Per-enemy relative death tick + per-tick damage rate, in schedule order.
	# Shared with [method party_hp_remaining_at] so the verdict and the HP curve
	# read from byte-identical arrays (truthful bar/verdict parity, ADR-0021).
	var rel_death: Array[int] = []
	var dmg_rate: Array[float] = []
	_build_race_arrays(snapshot, schedule, rel_death, dmg_rate)

	var t_clear: int = rel_death[rel_death.size() - 1]
	outcome.clear_tick = dispatched_at + t_clear

	# No time for damage before the clear → win (handles T_clear of 0 or 1).
	if t_clear <= 1:
		return outcome

	# Monotone in T → max pre-clear damage is at T_clear - 1.
	if _party_damage_by(t_clear - 1, rel_death, dmg_rate) < party_hp:
		return outcome  # WIN

	# DEFEAT — binary-search the smallest T in [1, T_clear-1] that wipes the party.
	var lo: int = 1
	var hi: int = t_clear - 1
	while lo < hi:
		@warning_ignore("integer_division")
		var mid: int = (lo + hi) / 2
		if _party_damage_by(mid, rel_death, dmg_rate) >= party_hp:
			hi = mid
		else:
			lo = mid + 1
	outcome.won = false
	outcome.defeat_tick = dispatched_at + lo
	return outcome


## Internal: cumulative enemy → party damage at relative tick [param t].
## `Σ_j dmg_rate[j] * min(t, rel_death[j])` (GDD #34 §D). Pure helper for
## [method compute_run_outcome]; no state, no allocation beyond the loop scalar.
func _party_damage_by(t: int, rel_death: Array[int], dmg_rate: Array[float]) -> float:
	var total: float = 0.0
	for j: int in range(rel_death.size()):
		total += dmg_rate[j] * float(mini(t, rel_death[j]))
	return total


## Internal: fills the per-enemy race arrays — `rel_death` (relative death tick,
## anchored at dispatch) and `dmg_rate` (per-tick damage the enemy draws from the
## shared party HP pool while alive) — in [param schedule] order, indices aligned
## with [code]snapshot.enemy_list[/code].
##
## Out-param style ([param rel_death_out] / [param dmg_rate_out] mutated in place)
## so the two consumers — [method compute_run_outcome] (verdict) and
## [method party_hp_remaining_at] (HP curve) — build IDENTICAL arrays from one
## code path. dmg_rate formula (GDD #34 §D):
## [code](base_attack * base_speed) / SPEED_BASE * MATCHUP_PARTY_DISADVANTAGE[/code].
##
## Pure: reads config via the same silent-fallback accessors the rest of the
## resolver uses; no state, no caching across calls.
func _build_race_arrays(snapshot: CombatRunSnapshot, schedule: Array[Dictionary],
		rel_death_out: Array[int], dmg_rate_out: Array[float]) -> void:
	var dispatched_at: int = snapshot.dispatched_at_tick
	var speed_base: int = _resolve_speed_base()
	var disadvantage: float = _resolve_matchup_party_disadvantage()
	for idx: int in range(schedule.size()):
		rel_death_out.append(int(schedule[idx]["kill_tick"]) - dispatched_at)
		var entry: Dictionary = snapshot.enemy_list[idx] as Dictionary
		var atk: int = int(entry.get("base_attack", 0))
		var spd: int = int(entry.get("base_speed", 0))
		dmg_rate_out.append((float(atk * spd) / float(speed_base)) * disadvantage)


## Party HP remaining at relative tick [param rel_tick] (ticks since dispatch).
## Drives the watchable-battle HP bar (GDD #34 Phase 4) — a TRUTHFUL read from the
## same two-sided-race math as [method compute_run_outcome], so for a losing run
## the value reaches 0 at exactly the resolver's [code]defeat_tick[/code] (no faked
## interpolation; bar/verdict parity by construction, ADR-0021).
##
## Per-loop reset (GDD §E.3): the party HP pool refills at each loop boundary, so
## the result is the CURRENT loop's remaining HP via
## [code]rel_tick % ticks_per_loop[/code]. Clamp: [code]maxi(0, ceili(party_hp -
## damage))[/code] — ceili so a barely-alive party reads ≥ 1 (never an empty bar
## while still fighting), and exactly 0 only once damage ≥ party_hp (the wipe).
##
## Edge cases:
##   - null snapshot → 0 (no run → empty bar; callers should hide the bar).
##   - [param rel_tick] <= 0 → full [code]formation_total_hp[/code] (pre-dispatch /
##     clock-rewind reads show full HP, never a spurious wipe).
##   - empty / unkillable enemy_list → full HP (no threat).
##
## Pure, allocation-light (two transient arrays per call) — called at most once per
## 20 Hz UI tick by the dungeon-run-view, well within the idle-game frame budget.
##
## GDD #34 §D / Phase 4 — ADR-0021
func party_hp_remaining_at(snapshot: CombatRunSnapshot, rel_tick: int) -> int:
	if snapshot == null:
		return 0
	var party_hp: int = snapshot.formation_total_hp
	if rel_tick <= 0:
		return party_hp
	var schedule: Array[Dictionary] = _kill_schedule_for_loop(snapshot)
	if schedule.is_empty():
		return party_hp  # No enemies → no damage → full HP.
	var rel_death: Array[int] = []
	var dmg_rate: Array[float] = []
	_build_race_arrays(snapshot, schedule, rel_death, dmg_rate)
	var ticks_per_loop: int = rel_death[rel_death.size() - 1]
	if ticks_per_loop <= 0:
		return party_hp  # Degenerate single-tick clear → no damage window.
	var loop_tick: int = rel_tick % ticks_per_loop
	var damage: float = _party_damage_by(loop_tick, rel_death, dmg_rate)
	return maxi(0, ceili(float(party_hp) - damage))


## Internal: fetch MATCHUP_PARTY_DISADVANTAGE with silent fallback to 1.0
## (GDD #34 §D Phase-1 neutral default). Mirrors [method _resolve_speed_base]'s
## duck-typed read so the resolver tolerates config schema mutation + test envs
## where DataRegistry can't resolve combat_config.
func _resolve_matchup_party_disadvantage() -> float:
	var cfg: Resource = DataRegistry.resolve("config", "combat_config")
	if cfg == null or not ("MATCHUP_PARTY_DISADVANTAGE" in cfg):
		return 1.0
	return float(cfg.get("MATCHUP_PARTY_DISADVANTAGE"))


## Internal: fetch MATCHUP_THROUGHPUT_FACTOR_ADV with silent fallback to 1.5.
func _resolve_throughput_factor_adv() -> float:
	var cfg: Resource = DataRegistry.resolve("config", "combat_config")
	if cfg == null or not ("MATCHUP_THROUGHPUT_FACTOR_ADV" in cfg):
		return 1.5  # GDD §G default
	return float(cfg.get("MATCHUP_THROUGHPUT_FACTOR_ADV"))


## Internal: fetch MATCHUP_THROUGHPUT_FACTOR_DIS with silent fallback to 0.67.
func _resolve_throughput_factor_dis() -> float:
	var cfg: Resource = DataRegistry.resolve("config", "combat_config")
	if cfg == null or not ("MATCHUP_THROUGHPUT_FACTOR_DIS" in cfg):
		return 0.67  # GDD §G default
	return float(cfg.get("MATCHUP_THROUGHPUT_FACTOR_DIS"))


## Foreground per-tick emission entry point. Walks the multi-loop kill schedule
## (built per-loop by [method _kill_schedule_for_loop], replicated across
## [code]snapshot.loops_per_run[/code] iterations) and returns the
## [CombatTickEvents] whose kill_tick falls in the half-open range
## [code](tick_lo, tick_hi][/code].
##
## Half-open semantics:
##   - Kill at exactly [param tick_hi] IS included.
##   - Kill at exactly [param tick_lo] is NOT included (already emitted in a
##     prior call where it was the upper bound).
##   - This ensures non-overlapping consecutive calls produce a partition of
##     the full kill stream — sum of per-call kills == single full-range call
##     (TR-022 parity invariant).
##
## Loop completion: the last enemy of each loop (kill_tick for the last
## enemy_list entry of loop k) is the loop-completion tick. If it falls in
## the window, the tick is added to [member CombatTickEvents.loop_completed_ticks].
##
## First clear: when loop k reaches [code]loops_per_run[/code] (1-indexed —
## i.e., the [code]loops_per_run[/code]-th loop completes), the floor is
## cleared. [member CombatTickEvents.first_clear_in_range] is true iff that
## tick falls in [code](tick_lo, tick_hi][/code].
##
## Time-anchored (TR-026): the schedule is closed-form against
## [code]snapshot.dispatched_at_tick[/code]. Calling with [param tick_lo]
## that has already been emitted re-emits the kills in that range (clock-
## rewind safety).
##
## Defensive:
##   - [param tick_hi] <= [param tick_lo] → push_warning, returns empty
##     CombatTickEvents (no events; caller should recover with a valid range).
##   - Empty enemy_list / loops_per_run == 0 → returns empty events.
##   - Total run schedule (loops_per_run × ticks_per_loop) ends; ticks beyond
##     [code]final_tick[/code] produce no events.
##
## TR-combat-002 / TR-combat-014 / TR-combat-022 / TR-combat-026 / TR-combat-029 — ADR-0010 §C.3
func emit_events_in_range(snapshot: CombatRunSnapshot, tick_lo: int, tick_hi: int) -> CombatTickEvents:
	var result: CombatTickEvents = CombatTickEvents.new()

	if snapshot == null:
		return result

	if tick_hi <= tick_lo:
		push_warning(
			("[CombatResolver] emit_events_in_range: descending or zero-length range "
			+ "(tick_lo=%d, tick_hi=%d); returning empty events. "
			+ "Caller must recover via a valid (tick_lo < tick_hi) range.")
			% [tick_lo, tick_hi]
		)
		return result

	if snapshot.enemy_list.is_empty() or snapshot.loops_per_run <= 0:
		return result

	# Build the one-loop schedule once (per-enemy ticks_to_kill cumulative).
	var one_loop: Array[Dictionary] = _kill_schedule_for_loop(snapshot)
	if one_loop.is_empty():
		return result

	# Per-loop tick offset: difference between the last enemy's kill_tick and
	# dispatched_at_tick. Each subsequent loop adds this offset to its base.
	var ticks_per_loop: int = int(one_loop[-1]["kill_tick"]) - snapshot.dispatched_at_tick

	# Walk loops 1..loops_per_run; for each, walk each enemy and filter by range.
	var kills_in_range: Array[KillEvent] = []
	var loops_completed_in_range: Array[int] = []
	var first_clear_in_range: bool = false

	for loop_idx: int in range(1, snapshot.loops_per_run + 1):
		var loop_base_offset: int = (loop_idx - 1) * ticks_per_loop
		var enemy_count: int = one_loop.size()
		for i: int in range(enemy_count):
			var entry: Dictionary = one_loop[i]
			var kill_tick: int = int(entry["kill_tick"]) + loop_base_offset
			# Half-open range filter: tick_lo < kill_tick <= tick_hi.
			if kill_tick <= tick_lo:
				continue
			if kill_tick > tick_hi:
				# All subsequent kills in this loop AND subsequent loops are
				# even later — early-break for performance.
				return _finalize_tick_events(result, kills_in_range, loops_completed_in_range, first_clear_in_range)
			# Kill is in range — build a KillEvent.
			var ke: KillEvent = KillEvent.new()
			ke.enemy_id = entry["enemy_id"] as StringName
			ke.archetype = entry["archetype"] as StringName
			ke.tier = int(entry["tier"])
			ke.is_boss = bool(entry["is_boss"])
			ke.kill_tick = kill_tick
			kills_in_range.append(ke)
			# Loop completion is the LAST enemy of the loop.
			if i == enemy_count - 1:
				loops_completed_in_range.append(kill_tick)
				# First clear: the loops_per_run-th loop is the floor clear.
				if loop_idx == snapshot.loops_per_run:
					first_clear_in_range = true

	return _finalize_tick_events(result, kills_in_range, loops_completed_in_range, first_clear_in_range)


## Internal: assembles the CombatTickEvents result from accumulated state.
## Extracted for the early-return path inside emit_events_in_range when an
## enemy's kill_tick exceeds tick_hi (no further enemies can be in range).
func _finalize_tick_events(result: CombatTickEvents, kills: Array[KillEvent],
		loop_ticks: Array[int], first_clear: bool) -> CombatTickEvents:
	result.kills = kills
	result.loop_completed_ticks = loop_ticks
	result.first_clear_in_range = first_clear
	return result


## Offline-replay aggregate entry point. Walks the SAME multi-loop schedule
## as [method emit_events_in_range] but folds events into per-archetype +
## per-tier counts instead of allocating an Array[KillEvent]. Used by the
## orchestrator on app-resume to fast-forward through long offline windows
## (15k+ kills) without retaining per-event detail (TR-combat-023).
##
## Range: aggregates events with [code]kill_tick[/code] in the half-open
## window [code](dispatched_at_tick, dispatched_at_tick + tick_budget][/code]
## — same semantic as [method emit_events_in_range] called with
## [code]tick_lo = dispatched_at_tick[/code] and
## [code]tick_hi = dispatched_at_tick + tick_budget[/code].
##
## Parity invariant (TR-combat-022): the union of N
## [method emit_events_in_range] calls with non-overlapping consecutive
## ranges that together cover [code](dispatched_at_tick,
## dispatched_at_tick + tick_budget][/code] produces a kill stream whose
## [code]kills_by_archetype[/code] + [code]kills_by_tier[/code] aggregates
## are byte-equal to a single [method compute_offline_batch] call covering
## the same total range. Both paths share [method _kill_schedule_for_loop]
## as the single source of truth (TR-combat-003).
##
## Determinism (TR-combat-021): repeated calls with identical args return
## field-equal CombatBatchResult; the input snapshot's enemy_list /
## matchup_cache references are NOT mutated.
##
## Field population (TR-combat-015):
##   - [code]kills_by_archetype[/code]: count per archetype encountered
##   - [code]kills_by_tier[/code]: count per tier (1, 2, 3) encountered
##   - [code]loops_completed[/code]: count of full enemy_list rotations whose
##     LAST enemy fell in range (loop completion is the last enemy's kill)
##   - [code]first_clear_tick[/code]: absolute tick of the first floor-clear
##     in this batch (loop_idx == loops_per_run, last enemy), or -1 if none
##   - [code]won[/code]: the run verdict from [method compute_run_outcome] —
##     the SAME two-sided HP-race source the foreground path uses, so the
##     offline batch and foreground dispatch agree by construction (ADR-0021).
##     [code]false[/code] = the party was defeated before the floor cleared;
##     the orchestrator forfeits all loot for a defeated offline batch (GDD #34
##     §F, AC-34-08).
##   - [code]final_tick[/code]: when budget is the limit → tick_hi; when
##     schedule is exhausted in range → the last enemy's kill_tick; on
##     empty/zero-budget paths → snapshot.dispatched_at_tick
##
## Defensive:
##   - [param tick_budget] <= 0 → empty result; final_tick = dispatched_at_tick
##   - Empty enemy_list / loops_per_run <= 0 → empty result
##   - null snapshot → empty default-constructed result (no crash)
##
## TR-combat-002 / 003 / 015 / 021 / 022 / 023 — ADR-0010 §C.4 + ADR-0014 §B4
func compute_offline_batch(snapshot: CombatRunSnapshot, tick_budget: int) -> CombatBatchResult:
	var result: CombatBatchResult = CombatBatchResult.new()
	if snapshot == null:
		return result
	# Verdict resolved up-front from the single-source-of-truth HP race so an
	# empty/invalid batch still carries a self-describing won flag (ADR-0021).
	result.won = compute_run_outcome(snapshot).won
	result.final_tick = snapshot.dispatched_at_tick

	if tick_budget <= 0:
		return result
	if snapshot.enemy_list.is_empty() or snapshot.loops_per_run <= 0:
		return result

	var one_loop: Array[Dictionary] = _kill_schedule_for_loop(snapshot)
	if one_loop.is_empty():
		return result

	var ticks_per_loop: int = int(one_loop[-1]["kill_tick"]) - snapshot.dispatched_at_tick
	var tick_lo: int = snapshot.dispatched_at_tick
	var tick_hi: int = snapshot.dispatched_at_tick + tick_budget

	var kills_by_archetype: Dictionary = {}
	var kills_by_tier: Dictionary = {}
	var loops_completed: int = 0
	var first_clear_tick: int = -1
	var last_event_tick: int = snapshot.dispatched_at_tick

	var enemy_count: int = one_loop.size()
	for loop_idx: int in range(1, snapshot.loops_per_run + 1):
		var loop_base_offset: int = (loop_idx - 1) * ticks_per_loop
		for i: int in range(enemy_count):
			var entry: Dictionary = one_loop[i]
			var kill_tick: int = int(entry["kill_tick"]) + loop_base_offset
			if kill_tick <= tick_lo:
				continue
			if kill_tick > tick_hi:
				# Budget consumed before schedule — final_tick = tick_hi.
				result.kills_by_archetype = kills_by_archetype
				result.kills_by_tier = kills_by_tier
				result.loops_completed = loops_completed
				result.first_clear_tick = first_clear_tick
				result.final_tick = tick_hi
				return result
			# In range — increment aggregate dicts.
			var archetype: StringName = entry["archetype"] as StringName
			var tier: int = int(entry["tier"])
			kills_by_archetype[archetype] = int(kills_by_archetype.get(archetype, 0)) + 1
			kills_by_tier[tier] = int(kills_by_tier.get(tier, 0)) + 1
			last_event_tick = kill_tick
			# Loop-completion tracking (TR-015 loops_completed): the LAST enemy
			# of a loop being in range means that loop completed in range.
			if i == enemy_count - 1:
				loops_completed += 1
				if loop_idx == snapshot.loops_per_run and first_clear_tick == -1:
					first_clear_tick = kill_tick

	# Schedule fully walked without hitting the budget cut — final_tick is
	# the last in-range event tick (or dispatched_at_tick if the schedule
	# produced no in-range kills, e.g. tick_budget < first kill_tick).
	result.kills_by_archetype = kills_by_archetype
	result.kills_by_tier = kills_by_tier
	result.loops_completed = loops_completed
	result.first_clear_tick = first_clear_tick
	result.final_tick = last_event_tick
	return result


## Builds the per-archetype matchup-advantage lookup table that lives in
## [member CombatRunSnapshot.matchup_cache]. Called ONCE at DISPATCHING by
## the orchestrator's snapshot-build code (Story 004 of orchestrator epic /
## S7-S4) — the cache then drives all per-enemy matchup decisions for the
## entire run via [code]snapshot.matchup_cache.get(archetype, false)[/code]
## reads inside [method _kill_schedule_for_loop].
##
## Stateless contract: [param matchup_resolver] is passed as a method
## parameter, not stored as instance state — preserves TR-combat-001
## (CombatResolver has zero class-scope vars). The orchestrator owns the
## resolver injection seam (S6-M8 [code]set_matchup_resolver(spy)[/code] on
## the autoload); this helper just consumes the reference at call time.
##
## Per-archetype call optimization (TR-012): dedupes [param floor_archetypes]
## before calling [code]resolve_formation_matchup[/code] — at most one call
## per DISTINCT archetype on the floor (≤5 calls per MVP floor). Caller may
## pre-dedup; this helper is defensive against duplicate entries.
##
## Returns [code]Dictionary[StringName, bool][/code]: archetype →
## is_advantaged. Empty input or null resolver → empty dict.
##
## TR-combat-004 / TR-combat-012 — ADR-0010 + ADR-0009
func build_matchup_cache(formation: Array, floor_archetypes: Array, matchup_resolver: RefCounted) -> Dictionary:
	var cache: Dictionary = {}
	if matchup_resolver == null:
		return cache
	if not matchup_resolver.has_method("resolve_formation_matchup"):
		push_error(
			"[CombatResolver] build_matchup_cache: injected resolver lacks "
			+ "`resolve_formation_matchup(formation, archetype)` method. "
			+ "Returning empty cache — all enemies will be treated as disadvantaged."
		)
		return cache
	# Dedup archetypes — TR-012 ≤5 calls per MVP floor.
	var distinct: Array = []
	for entry: Variant in floor_archetypes:
		var archetype: StringName = StringName(str(entry))
		if archetype == &"":
			continue
		if not distinct.has(archetype):
			distinct.append(archetype)
	# One MatchupResolver call per distinct archetype.
	for archetype: StringName in distinct:
		var result: Variant = matchup_resolver.call(
			"resolve_formation_matchup", formation, str(archetype)
		)
		# MatchupResult duck-type: has `is_advantaged: bool` field.
		var advantaged: bool = false
		if result != null and "is_advantaged" in result:
			advantaged = bool(result.get("is_advantaged"))
		cache[archetype] = advantaged
	return cache
