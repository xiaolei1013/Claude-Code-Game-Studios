## MatchupResolver — base class for class-vs-enemy matchup resolution.
##
## Stateless instance class (NOT autoload, NOT static-only). Concrete impls
## (Story 002 [DefaultMatchupResolver], test spies) override the public
## `resolve_*` methods. The base class deliberately defines no method bodies
## — Godot 4 lacks `@abstract` on RefCounted, so the base is "interface by
## convention" enforced via code review + a structural CI lint (Story 008).
##
## Construction lifecycle: `MatchupResolver.new()` produces a usable RefCounted
## instance with automatic memory management (no manual `.free()` ever).
## Production wiring uses lazy-default-with-public-setters DI per ADR-0009 +
## ADR-0003 Amendment #3 — DungeonRunOrchestrator's `set_matchup_resolver(spy)`
## test seam runs BEFORE `_ready()`; lazy-default `DefaultMatchupResolver.new()`
## inside the orchestrator's `_ready()` for production.
##
## Stateless invariant (TR-matchup-resolver-005, TR-030):
##   - Zero class-scope `var` declarations.
##   - Zero `signal` declarations.
##   - No caches, no RNG, no time-dependent reads.
##
## ADR-0009: Matchup Resolver DI + Majority Threshold
## ADR-0003 Amendment #3: zero-arg `_init` (resolver is NOT an autoload, but
##   the lazy-default construction site IS — autoload constraint propagates
##   to consumers).
class_name MatchupResolver extends RefCounted

# DELIBERATELY EMPTY — no class-scope vars, no signals.
# Concrete subclasses (DefaultMatchupResolver in Story 002, test spies) provide:
#   func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult
#   func resolve_floor_matchup(formation: Array, floor_archetypes: Array[String]) -> MatchupResult
#
# Structural CI lint (Story 008) verifies this file remains free of `var ` /
# `signal ` declarations + `static func` on the public API.
