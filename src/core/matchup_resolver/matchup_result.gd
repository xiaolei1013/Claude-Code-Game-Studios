## MatchupResult — value type returned by all [MatchupResolver] resolve methods.
##
## Two-field RefCounted (no automatic .free() needed). Tests compare via
## field-by-field equality — RefCounted equality is reference-equality (NOT
## structural), so a helper `match_result_equals(a, b)` lives in test fixtures
## per Story 008 — TR-matchup-resolver-033.
##
## Field invariants:
##   - [member is_advantaged]: true iff the formation has matchup advantage
##     against the enemy/floor passed to the resolver. Threshold rule per
##     ADR-0009: strict majority (n > N/2 integer division). Crossing the
##     threshold yields a SINGLE 1.5× boost — no per-hero stacking beyond.
##   - [member matched_archetypes]: alphabetically-sorted, deduplicated list
##     of archetype strings the formation countered. NEVER contains
##     [HeroInstance] refs or instance_id ints (TR-matchup-resolver-007).
##     Empty Array when [member is_advantaged] is false.
##
## Story 004 (S8-S6 — landed 2026-04-27): added third field
## [code]effectiveness_label: String[/code] ∈ {"Weak", "Even", "Strong"} for UI
## consumers (Recruitment screen, Formation Assignment) to drive icon/colour
## without recomputing from [member is_advantaged].
##
## ADR-0009: Matchup Resolver DI + Majority Threshold (TR-006, TR-007)
class_name MatchupResult extends RefCounted

## True iff the formation has matchup advantage. Set by the resolver per
## the strict-majority rule (TR-matchup-resolver-011); never derived later.
var is_advantaged: bool = false

## Alphabetically-sorted, deduplicated list of archetype strings the formation
## countered. Empty when [member is_advantaged] is false. Typed `Array[String]`
## to make HeroInstance/int contamination a compile-time error (TR-007).
var matched_archetypes: Array[String] = []

## UI-facing effectiveness bucket — exactly one of {"Weak", "Even", "Strong"}.
##
## Population rule (set by resolver, never derived downstream):
##   - "Strong": [member is_advantaged] == true (formation crossed the strict-
##     majority counter threshold against the archetype/floor)
##   - "Weak": non-empty formation, zero counters across eligible heroes
##     (every hero's class_data resolved but none countered)
##   - "Even": default — empty formation, all-null class_data, or mixed
##     non-zero non-majority counters (1/3 counter against single archetype)
##
## Default "Even" so any code path that constructs MatchupResult without
## populating the label produces a valid UI string. Resolver methods overwrite
## this default after their majority computation.
##
## Story 004 / S8-S6 — S4-N1 quick-spec carryover.
var effectiveness_label: String = "Even"
