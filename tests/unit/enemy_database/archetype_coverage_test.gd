# Content-integrity guard — every hero class's counter_archetype (and therefore
# every matchup advantage + every class-synergy keyed to that archetype) MUST be
# backed by at least one shipped enemy carrying that archetype. Otherwise the
# class's matchup advantage and any archetype-conditional synergy are silently
# DEAD: the multiplier/advantage can never trigger because no enemy ever presents
# the archetype.
#
# Regression guard for the shipped "swarm" gap: Archer counters "swarm" and the
# Volley synergy rewards swarm kills (+25% gold), but NO enemy had
# archetype="swarm" until thornling_swarm was authored — so a player who built a
# 3-Archer Volley formation earned baseline gold on every kill, forever.
extends GdUnitTestSuite


func test_every_class_counter_archetype_is_backed_by_an_enemy() -> void:
	# Collect the distinct archetypes carried by shipped enemies.
	var enemy_archetypes: Dictionary = {}
	for r: Resource in DataRegistry.get_all_by_type("enemies"):
		if r == null or not ("archetype" in r):
			continue
		var a: String = String(r.get("archetype"))
		if not a.is_empty():
			enemy_archetypes[a] = true
	assert_int(enemy_archetypes.size()).override_failure_message(
		"no enemy archetypes found — DataRegistry not booted in the test env?"
	).is_greater(0)

	# Every class's counter_archetype must appear among them.
	var checked: int = 0
	for c: Resource in DataRegistry.get_all_by_type("classes"):
		if c == null or not ("counter_archetype" in c):
			continue
		var counter: String = String(c.get("counter_archetype"))
		if counter.is_empty():
			continue
		checked += 1
		var class_id: String = String(c.get("id")) if "id" in c else "?"
		assert_bool(enemy_archetypes.has(counter)).override_failure_message(
			"class '%s' counters archetype '%s', but NO enemy carries it — the "
			% [class_id, counter]
			+ "matchup advantage + any synergy keyed to '%s' are dead. "
			% counter
			+ "Author an enemy with archetype='%s' (or retarget the class)." % counter
		).is_true()
	assert_int(checked).override_failure_message(
		"no classes with a counter_archetype were checked — class data missing?"
	).is_greater(0)
