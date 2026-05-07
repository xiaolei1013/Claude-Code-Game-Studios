## DefaultMatchupResolver — production impl of [MatchupResolver].
##
## Sprint 7 Story M3 (replaces the Sprint 6 stub authored in S6-M8). Implements
## [method resolve_formation_matchup] per ADR-0009's strict-majority threshold:
## a formation is advantaged against an enemy archetype iff strictly more than
## [code]N_eligible / 2[/code] heroes counter that archetype (integer division).
## For MVP `FORMATION_SIZE = 3` this means at least 2 of 3 slots must counter.
##
## Crossing the threshold yields a SINGLE 1.5× boost (no per-hero stacking
## beyond threshold) — the specialist-vs-generalist decision the Pillar 3
## promise hinges on.
##
## Stateless invariant — zero class-scope vars/signals; pure function of
## inputs (formation snapshot + enemy archetype). Produces identical output
## for identical inputs (Pillar 1 offline-replay determinism per TR-021).
##
## Dependencies:
##   - DataRegistry.resolve("classes", class_id) at read time to fetch each
##     hero's HeroClass for `counter_archetype` lookup.
##   - HeroClass.counter_archetype — case-sensitive string equality is the
##     entire counter rule (TR-010 + TR-020).
##
## ADR-0009: Matchup Resolver DI + Majority Threshold
extends MatchupResolver

const _STUB_MARKER: String = "DefaultMatchupResolver — Sprint 7 production impl"


func _init() -> void:
	# No-op constructor — instance class with zero state.
	# Production wiring lazy-default-news this from DungeonRunOrchestrator._ready
	# per ADR-0003 Amendment #3 (autoload zero-arg invariant propagates to
	# the resolver instances orchestrator instantiates).
	pass


## Diagnostic accessor preserved from the Sprint 6 stub for the orchestrator's
## autoload_skeleton_and_di_test which checks `resolver.is_stub()` to verify
## the lazy-default produced a DefaultMatchupResolver. The marker text now
## reflects the production-impl status; the substring "DefaultMatchupResolver"
## remains for that test's `assert_str(...).contains(...)` predicate.
func is_stub() -> String:
	return _STUB_MARKER


## Returns a [MatchupResult] describing whether [param formation] has matchup
## advantage against a single [param enemy_archetype].
##
## Resolution algorithm (per ADR-0009 + TR-matchup-resolver-008..017):
##   1. Empty formation guard (TR-016) — return `{false, []}` immediately;
##      zero DataRegistry calls; no exceptions.
##   2. Empty/null [param enemy_archetype] guard (TR-018) — push_error +
##      return `{false, []}`. Defensive against caller formatting bugs.
##   3. Walk [param formation], resolve each entry's `class_id` via
##      DataRegistry. Null class_data is silently skipped (TR-017) — excluded
##      from threshold N (all-null formation behaves like empty).
##   4. Counter test: case-sensitive string equality between
##      `class_data.counter_archetype` and [param enemy_archetype] (TR-020).
##   5. Majority: `is_advantaged := counter_count > (N_eligible / 2)` —
##      strict majority via integer division (TR-011). For MVP
##      FORMATION_SIZE=3, this is "≥ 2 counters".
##   6. matched_archetypes: deduplicated + alphabetically sorted (TR-013).
##      In single-enemy resolution this is `[]` or `[enemy_archetype]`.
##
## TR-matchup-resolver-008/010/011/012/013/014/016/017/020 — ADR-0009
func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult:
	var result: MatchupResult = MatchupResult.new()

	# Guard: empty / null enemy_archetype (TR-018). Defensive against caller
	# bugs; resolver does NOT silently absorb the error — push_error so the
	# upstream issue is visible in logs.
	if enemy_archetype == null or enemy_archetype.is_empty():
		push_error("MatchupResolver: empty or null enemy_archetype")
		return result

	# Guard: empty formation (TR-016). Zero iteration, zero DataRegistry calls.
	if formation.is_empty():
		return result

	var n_eligible: int = 0    # heroes whose class_data resolved successfully
	var counter_count: int = 0  # subset of n_eligible that countered the archetype
	var matched: Array[String] = []

	for hero: Variant in formation:
		# Hero entries are HeroInstance refs (or duck-typed objects exposing
		# `class_id`). Defensive read — the resolver does NOT mandate a
		# specific HeroInstance type, only that it has a `class_id` String.
		if hero == null or not ("class_id" in hero):
			continue
		var class_id: String = str(hero.get("class_id"))
		var class_data: Resource = DataRegistry.resolve("classes", class_id)
		if class_data == null:
			# TR-017: silently skip null class_data; excluded from threshold N.
			continue
		n_eligible += 1
		if _is_class_counter(class_data, enemy_archetype):
			counter_count += 1
			if not matched.has(enemy_archetype):
				matched.append(enemy_archetype)

	# TR-011 strict-majority threshold (integer division). N_eligible/2 floored.
	# For N_eligible=3 → threshold 1; counter_count must be > 1 → ≥ 2 to win.
	# For N_eligible=2 → threshold 1; counter_count must be ≥ 2.
	# For N_eligible=1 → threshold 0; counter_count must be ≥ 1.
	# For N_eligible=0 → threshold 0; counter_count==0 → false (correct).
	@warning_ignore("integer_division")
	result.is_advantaged = counter_count > (n_eligible / 2)

	# TR-013 dedup + alphabetical sort (single-enemy case is already deduplicated;
	# explicit sort is a no-op for single-archetype but sets the contract for
	# Story 003's resolve_floor_matchup multi-archetype aggregation).
	matched.sort()
	result.matched_archetypes = matched

	# Story 004 / S8-S6: effectiveness_label population (S4-N1 quick-spec).
	#   - is_advantaged → "Strong" (formation crossed counter threshold)
	#   - non-empty eligible formation, zero counters → "Weak"
	#   - mixed (some counters but below threshold) OR empty eligible → "Even"
	#     (default, set during MatchupResult.new() — overwritten only if Strong/Weak)
	if result.is_advantaged:
		result.effectiveness_label = "Strong"
	elif n_eligible > 0 and counter_count == 0:
		result.effectiveness_label = "Weak"
	# else: leave "Even" default

	return result


## Private helper: true iff [param class_data] has a non-empty
## [code]counter_archetype[/code] field equal to [param enemy_archetype]
## via case-sensitive string equality (TR-020 — no `to_lower` normalization).
##
## TR-matchup-resolver-010 — ADR-0009
func _is_class_counter(class_data: Resource, enemy_archetype: String) -> bool:
	if class_data == null:
		return false
	if not ("counter_archetype" in class_data):
		return false
	var counter: String = str(class_data.get("counter_archetype"))
	# Empty counter (e.g., a class with `counter_archetype = ""`) does NOT
	# trivially match an empty enemy_archetype because the empty-archetype
	# guard in resolve_formation_matchup already rejected the latter.
	return counter == enemy_archetype


## Aggregates per-archetype matchup results across a floor's enemy list.
##
## [param formation] is the frozen dispatch snapshot (TR-015 — never a live
## HeroRoster read). [param floor_archetypes] is a typed list of archetype
## strings; the caller is responsible for deduplicating upstream (TR-009).
## This method itself does NOT dedup the input — duplicate archetype entries
## produce identical per-archetype results (deterministic), but matched
## archetypes are deduplicated in the aggregate output.
##
## Aggregation rule:
##   - [code]is_advantaged[/code]: true iff ANY per-archetype resolution
##     returned true. (Floor advantage means the formation has matchup
##     advantage against AT LEAST ONE archetype on the floor — the Pillar 3
##     "specialist-vs-generalist" decision; a single counter is the entire
##     economic hook.)
##   - [code]matched_archetypes[/code]: union of per-archetype
##     [code]matched_archetypes[/code], deduplicated and alphabetically
##     sorted (TR-013).
##
## Edge cases:
##   - Empty [param floor_archetypes] → returns default `{false, []}` (no
##     archetypes to test against; not an error).
##   - Empty/null entries within [param floor_archetypes] → forwarded to
##     [method resolve_formation_matchup] which logs push_error per TR-018
##     and returns `{false, []}` for that single entry (does not abort the
##     aggregate).
##   - Empty [param formation] → all per-archetype calls return `{false, []}`
##     via TR-016, aggregate returns `{false, []}`.
##
## TR-matchup-resolver-009/013/015 — ADR-0009
func resolve_floor_matchup(formation: Array, floor_archetypes: Array[String]) -> MatchupResult:
	var aggregate: MatchupResult = MatchupResult.new()
	var matched_union: Array[String] = []
	# Story 004 / S8-S6 label aggregation: track per-archetype labels to fold
	# into a single floor-level effectiveness_label.
	#   - any "Strong" → aggregate is "Strong"
	#   - all "Weak" (and at least one archetype tested) → aggregate is "Weak"
	#   - otherwise (mixed, all "Even", or empty floor_archetypes) → "Even"
	var any_strong: bool = false
	var all_weak: bool = true
	var any_archetype_tested: bool = false

	for archetype: String in floor_archetypes:
		var per: MatchupResult = resolve_formation_matchup(formation, archetype)
		any_archetype_tested = true
		if per.is_advantaged:
			aggregate.is_advantaged = true
		for s: String in per.matched_archetypes:
			if not matched_union.has(s):
				matched_union.append(s)
		if per.effectiveness_label == "Strong":
			any_strong = true
		if per.effectiveness_label != "Weak":
			all_weak = false

	# TR-013 dedup + alphabetical sort on the aggregate output.
	matched_union.sort()
	aggregate.matched_archetypes = matched_union

	# Floor effectiveness_label aggregate:
	if any_strong:
		aggregate.effectiveness_label = "Strong"
	elif any_archetype_tested and all_weak:
		aggregate.effectiveness_label = "Weak"
	# else: leave "Even" default (no archetypes tested OR mixed labels)

	return aggregate
